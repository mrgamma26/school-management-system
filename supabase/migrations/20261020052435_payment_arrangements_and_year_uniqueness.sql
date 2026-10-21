BEGIN;

-- Equivalent inputs such as 2026 and 2026/2027 must identify one year.
-- Existing canonical rows already have a UNIQUE name constraint; the RPC now
-- stores only the canonical label and rejects a conflicting edit clearly.
CREATE OR REPLACE FUNCTION public.canonical_academic_year_name(p_name text)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public
AS $$
DECLARE v_start integer; v_end integer;
BEGIN
  IF btrim(p_name) ~ '^[0-9]{4}$' THEN
    v_start := btrim(p_name)::integer;
  ELSIF btrim(p_name) ~ '^[0-9]{4}[[:space:]]*/[[:space:]]*[0-9]{4}$' THEN
    v_start := substring(btrim(p_name) FROM '^([0-9]{4})')::integer;
    v_end := substring(btrim(p_name) FROM '([0-9]{4})$')::integer;
    IF v_end <> v_start + 1 THEN
      RAISE EXCEPTION 'Academic year must use consecutive years';
    END IF;
  ELSE
    RAISE EXCEPTION 'Academic year must be YYYY or YYYY/YYYY';
  END IF;
  RETURN v_start::text || '/' || (v_start + 1)::text;
END;
$$;

CREATE OR REPLACE FUNCTION public.canonicalize_academic_year_name_trigger()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  NEW.name := public.canonical_academic_year_name(NEW.name);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS canonicalize_academic_year_name
  ON public.school_academic_years;
CREATE TRIGGER canonicalize_academic_year_name
BEFORE INSERT OR UPDATE OF name ON public.school_academic_years
FOR EACH ROW EXECUTE FUNCTION public.canonicalize_academic_year_name_trigger();

-- Never rewrite existing plans silently. Stop with a precise diagnostic if a
-- pre-existing database needs a human reconciliation before the invariant can
-- be installed.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM public.payment_arrangements
    WHERE status = 'ACTIVE'
    GROUP BY student_id
    HAVING count(*) > 1
  ) THEN
    RAISE EXCEPTION
      'Duplicate active payment arrangements exist; reconcile them before applying this migration';
  END IF;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS payment_arrangements_one_active_student_idx
  ON public.payment_arrangements(student_id) WHERE status = 'ACTIVE';

ALTER TABLE public.payment_arrangement_history
  DROP CONSTRAINT IF EXISTS payment_arrangement_history_arrangement_id_fkey;
ALTER TABLE public.payment_arrangement_history
  ADD CONSTRAINT payment_arrangement_history_arrangement_id_fkey
  FOREIGN KEY (arrangement_id)
  REFERENCES public.payment_arrangements(arrangement_id) ON DELETE CASCADE;

CREATE OR REPLACE FUNCTION public.create_payment_arrangement(
  p_student_id uuid,
  p_installments jsonb,
  p_notes text DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_staff_id uuid;
  v_id uuid;
  v_total numeric(14,2);
  v_next date;
BEGIN
  SELECT staffid INTO v_staff_id
  FROM public.staff
  WHERE userid = auth.uid();
  IF v_staff_id IS NULL OR NOT public.has_app_role('ACCOUNTANT') THEN
    RAISE EXCEPTION 'Only an Accountant may create payment arrangements';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.student WHERE studentid = p_student_id) THEN
    RAISE EXCEPTION 'Student not found';
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.payment_arrangements
    WHERE student_id = p_student_id AND status = 'ACTIVE'
  ) THEN
    RAISE EXCEPTION 'This student already has an active payment arrangement';
  END IF;
  IF jsonb_typeof(p_installments) <> 'array' OR jsonb_array_length(p_installments) = 0 THEN
    RAISE EXCEPTION 'At least one installment is required';
  END IF;

  SELECT sum((item->>'amount')::numeric), min((item->>'dueDate')::date)
    INTO v_total, v_next
  FROM jsonb_array_elements(p_installments) item;
  IF v_total IS NULL OR v_total <= 0 THEN
    RAISE EXCEPTION 'Installment amounts must be positive';
  END IF;

  INSERT INTO public.payment_arrangements(
    student_id, total_amount, next_follow_up_date, notes, created_by
  ) VALUES (
    p_student_id, v_total, v_next, nullif(btrim(p_notes), ''), v_staff_id
  ) RETURNING arrangement_id INTO v_id;

  INSERT INTO public.payment_arrangement_installments(
    arrangement_id, due_date, amount
  )
  SELECT v_id, (item->>'dueDate')::date, (item->>'amount')::numeric
  FROM jsonb_array_elements(p_installments) item;

  INSERT INTO public.payment_arrangement_history(
    arrangement_id, action, note, actor_staff_id
  ) VALUES (v_id, 'CREATED', 'Payment arrangement created', v_staff_id);
  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.canonical_academic_year_name(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.canonical_academic_year_name(text) TO authenticated;
REVOKE ALL ON FUNCTION public.canonicalize_academic_year_name_trigger()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.create_payment_arrangement(uuid, jsonb, text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_payment_arrangement(uuid, jsonb, text)
  TO authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
