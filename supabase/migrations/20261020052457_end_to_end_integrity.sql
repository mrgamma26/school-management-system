BEGIN;

-- ---------------------------------------------------------------------------
-- Canonical teacher assignments -> legacy assessment identifiers
-- ---------------------------------------------------------------------------
-- Assessments and class-history still reference classsubject. Keep a durable
-- source link so a replaced teacher's historical row is retained but is no
-- longer treated as a current assignment.
ALTER TABLE public.classsubject
  ADD COLUMN IF NOT EXISTS teacher_assignment_id uuid
  REFERENCES public.teacher_assignments(teacher_assignment_id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS classsubject_teacher_assignment_idx
  ON public.classsubject(teacher_assignment_id);

CREATE OR REPLACE FUNCTION public.sync_academic_year_to_legacy(
  p_academic_year_id uuid
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_start_year integer;
BEGIN
  SELECT substring(name FROM '^[0-9]{4}')::integer
    INTO v_start_year
  FROM public.school_academic_years
  WHERE academic_year_id = p_academic_year_id;

  IF v_start_year IS NULL THEN RETURN; END IF;

  INSERT INTO public.academicyear (
    academicyear, term, termname, form, startdate, enddate, updatedat
  )
  SELECT
    v_start_year,
    td.code::public.term_type,
    td.code::public.term_enum,
    forms.form,
    ayt.start_date,
    ayt.end_date,
    now()
  FROM public.academic_year_terms ayt
  JOIN public.term_definitions td
    ON td.term_definition_id = ayt.term_definition_id
  CROSS JOIN (
    VALUES ('FORM_1'), ('FORM_2'), ('FORM_3'), ('FORM_4')
  ) AS forms(form)
  WHERE ayt.academic_year_id = p_academic_year_id
  ON CONFLICT (academicyear, term, form) WHERE form IS NOT NULL
  DO UPDATE SET
    startdate = EXCLUDED.startdate,
    enddate = EXCLUDED.enddate,
    updatedat = now();

  INSERT INTO public.classsubject (
    classid, subjectid, staffid, academicyearid,
    teacher_assignment_id, updatedat
  )
  SELECT
    csc.class_id,
    csc.subject_id,
    ta.staff_id,
    ay.academicyearid,
    ta.teacher_assignment_id,
    now()
  FROM public.teacher_assignments ta
  JOIN public.class_subject_catalog csc
    ON csc.class_subject_id = ta.class_subject_id AND csc.is_active
  JOIN public.class c ON c.classid = csc.class_id
  JOIN public.academicyear ay
    ON ay.academicyear = v_start_year AND ay.form = c.form
  WHERE ta.academic_year_id = p_academic_year_id
  ON CONFLICT (classid, subjectid, staffid, academicyearid)
  DO UPDATE SET
    teacher_assignment_id = EXCLUDED.teacher_assignment_id,
    updatedat = now();
END;
$$;

DO $$
DECLARE year_row record;
BEGIN
  FOR year_row IN SELECT academic_year_id FROM public.school_academic_years LOOP
    PERFORM public.sync_academic_year_to_legacy(year_row.academic_year_id);
  END LOOP;
END $$;

DROP POLICY IF EXISTS "authenticated staff read class assignments"
  ON public.classsubject;
CREATE POLICY "oversight staff read class assignments"
ON public.classsubject FOR SELECT TO authenticated
USING (
  public.current_app_role() IN (
    'SUPER_USER', 'SYSTEM_ADMIN', 'ADMINISTRATOR', 'HEAD_TEACHER', 'ACCOUNTANT'
  )
);

DROP POLICY IF EXISTS "staff can read own assignments" ON public.classsubject;
CREATE POLICY "staff can read own assignments"
ON public.classsubject FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.staff s
    WHERE s.staffid = classsubject.staffid AND s.userid = auth.uid()
  )
  AND (
    classsubject.teacher_assignment_id IS NULL
    OR EXISTS (
      SELECT 1 FROM public.teacher_assignments ta
      WHERE ta.teacher_assignment_id = classsubject.teacher_assignment_id
        AND ta.status = 'ACTIVE'
        AND ta.staff_id = classsubject.staffid
    )
  )
);

DROP POLICY IF EXISTS "teachers manage own assessments" ON public.assessment;
CREATE POLICY "teachers manage own assessments"
ON public.assessment FOR ALL TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.classsubject cs
    JOIN public.staff s ON s.staffid = cs.staffid
    LEFT JOIN public.teacher_assignments ta
      ON ta.teacher_assignment_id = cs.teacher_assignment_id
    WHERE cs.classsubjectid = assessment.classsubjectid
      AND s.userid = auth.uid()
      AND (cs.teacher_assignment_id IS NULL OR ta.status = 'ACTIVE')
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.classsubject cs
    JOIN public.staff s ON s.staffid = cs.staffid
    LEFT JOIN public.teacher_assignments ta
      ON ta.teacher_assignment_id = cs.teacher_assignment_id
    WHERE cs.classsubjectid = assessment.classsubjectid
      AND s.userid = auth.uid()
      AND (cs.teacher_assignment_id IS NULL OR ta.status = 'ACTIVE')
  )
);

DROP POLICY IF EXISTS "teacher manages grades for assigned assessments"
  ON public.grade;
CREATE POLICY "teacher manages grades for assigned assessments"
ON public.grade FOR ALL TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.assessment a
    JOIN public.classsubject cs ON cs.classsubjectid = a.classsubjectid
    JOIN public.staff s ON s.staffid = cs.staffid
    LEFT JOIN public.teacher_assignments ta
      ON ta.teacher_assignment_id = cs.teacher_assignment_id
    WHERE a.assessmentid = grade.assessmentid
      AND s.userid = auth.uid()
      AND grade.enteredby = s.staffid
      AND (cs.teacher_assignment_id IS NULL OR ta.status = 'ACTIVE')
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.assessment a
    JOIN public.classsubject cs ON cs.classsubjectid = a.classsubjectid
    JOIN public.staff s ON s.staffid = cs.staffid
    JOIN public.studentsubject ss
      ON ss.classsubjectid = cs.classsubjectid
     AND ss.studentid = grade.studentid
    LEFT JOIN public.teacher_assignments ta
      ON ta.teacher_assignment_id = cs.teacher_assignment_id
    WHERE a.assessmentid = grade.assessmentid
      AND s.userid = auth.uid()
      AND grade.enteredby = s.staffid
      AND (cs.teacher_assignment_id IS NULL OR ta.status = 'ACTIVE')
  )
);

DROP POLICY IF EXISTS "teachers read assigned class history"
  ON public.studentclasshistory;
CREATE POLICY "teachers read assigned class history"
ON public.studentclasshistory FOR SELECT TO authenticated
USING (
  public.current_app_role() = 'TEACHER'
  AND EXISTS (
    SELECT 1
    FROM public.staff s
    JOIN public.classsubject cs ON cs.staffid = s.staffid
    LEFT JOIN public.teacher_assignments ta
      ON ta.teacher_assignment_id = cs.teacher_assignment_id
    WHERE s.userid = auth.uid()
      AND cs.classid = studentclasshistory.classid
      AND cs.academicyearid = studentclasshistory.academicyearid
      AND (cs.teacher_assignment_id IS NULL OR ta.status = 'ACTIVE')
  )
);

DROP POLICY IF EXISTS "teachers read assigned student subjects"
  ON public.studentsubject;
CREATE POLICY "teachers read assigned student subjects"
ON public.studentsubject FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.classsubject cs
    JOIN public.staff s ON s.staffid = cs.staffid
    LEFT JOIN public.teacher_assignments ta
      ON ta.teacher_assignment_id = cs.teacher_assignment_id
    WHERE cs.classsubjectid = studentsubject.classsubjectid
      AND s.userid = auth.uid()
      AND (cs.teacher_assignment_id IS NULL OR ta.status = 'ACTIVE')
  )
);

CREATE OR REPLACE FUNCTION public.teacher_can_read_student(
  target_student_id uuid
) RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.staff staff_member
    JOIN public.classsubject assignment
      ON assignment.staffid = staff_member.staffid
    LEFT JOIN public.teacher_assignments canonical
      ON canonical.teacher_assignment_id = assignment.teacher_assignment_id
    JOIN public.studentclasshistory enrollment
      ON enrollment.classid = assignment.classid
     AND enrollment.academicyearid = assignment.academicyearid
    WHERE staff_member.userid = (SELECT auth.uid())
      AND enrollment.studentid = target_student_id
      AND (
        assignment.teacher_assignment_id IS NULL
        OR canonical.status = 'ACTIVE'
      )
  )
$$;

-- ---------------------------------------------------------------------------
-- Deposit evidence must identify the exact payment it supports
-- ---------------------------------------------------------------------------
ALTER TABLE public.deposit_slips
  ADD CONSTRAINT deposit_slips_payment_required
  CHECK (payment_id IS NOT NULL) NOT VALID;

CREATE OR REPLACE FUNCTION public.validate_deposit_slip_link()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, storage, pg_catalog
AS $$
DECLARE
  v_payment public.payment%ROWTYPE;
BEGIN
  IF NEW.payment_id IS NULL THEN
    RAISE EXCEPTION 'A deposit slip must be linked to its payment';
  END IF;

  SELECT * INTO v_payment
  FROM public.payment
  WHERE paymentid = NEW.payment_id;

  IF NOT FOUND THEN RAISE EXCEPTION 'Linked payment not found'; END IF;
  IF v_payment.studentid <> NEW.student_id THEN
    RAISE EXCEPTION 'Deposit slip student does not match linked payment';
  END IF;
  IF v_payment.method <> 'DEPOSIT' THEN
    RAISE EXCEPTION 'Deposit slip evidence requires a DEPOSIT payment';
  END IF;
  IF v_payment.amount <> NEW.amount THEN
    RAISE EXCEPTION 'Deposit slip amount does not match linked payment';
  END IF;
  IF v_payment.paymentdate <> NEW.deposit_date THEN
    RAISE EXCEPTION 'Deposit slip date does not match linked payment';
  END IF;
  IF v_payment.recordedby <> NEW.created_by THEN
    RAISE EXCEPTION 'Deposit slip creator does not match payment recorder';
  END IF;
  IF btrim(coalesce(v_payment.referencenumber, '')) <> btrim(NEW.reference) THEN
    RAISE EXCEPTION 'Deposit slip reference does not match linked payment';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM storage.objects o
    WHERE o.bucket_id = 'deposit-slips' AND o.name = NEW.storage_path
  ) THEN
    RAISE EXCEPTION 'Deposit slip file was not uploaded';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS validate_deposit_slip_link ON public.deposit_slips;
CREATE TRIGGER validate_deposit_slip_link
BEFORE INSERT OR UPDATE OF payment_id, student_id, amount, deposit_date,
  reference, storage_path, created_by
ON public.deposit_slips
FOR EACH ROW EXECUTE FUNCTION public.validate_deposit_slip_link();

-- ---------------------------------------------------------------------------
-- Payment arrangements reflect every partial payment and reversal
-- ---------------------------------------------------------------------------
ALTER TABLE public.payment_arrangements
  ADD COLUMN IF NOT EXISTS paid_amount numeric(14,2) NOT NULL DEFAULT 0
  CHECK (paid_amount >= 0);

ALTER TABLE public.payment
  ADD COLUMN IF NOT EXISTS payment_arrangement_id uuid
  REFERENCES public.payment_arrangements(arrangement_id) ON DELETE RESTRICT;

CREATE INDEX IF NOT EXISTS payment_arrangement_payment_idx
  ON public.payment(payment_arrangement_id)
  WHERE payment_arrangement_id IS NOT NULL;

CREATE OR REPLACE FUNCTION public.link_payment_to_active_arrangement()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
BEGIN
  IF NEW.payment_arrangement_id IS NULL THEN
    SELECT arrangement_id INTO NEW.payment_arrangement_id
    FROM public.payment_arrangements
    WHERE student_id = NEW.studentid AND status = 'ACTIVE'
    ORDER BY created_at DESC, arrangement_id DESC
    LIMIT 1;
  ELSIF NOT EXISTS (
    SELECT 1 FROM public.payment_arrangements pa
    WHERE pa.arrangement_id = NEW.payment_arrangement_id
      AND pa.student_id = NEW.studentid
  ) THEN
    RAISE EXCEPTION 'Payment arrangement does not belong to this student';
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.refresh_payment_arrangement(
  p_arrangement_id uuid
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_paid numeric(14,2);
  v_total numeric(14,2);
BEGIN
  IF p_arrangement_id IS NULL THEN RETURN; END IF;

  SELECT coalesce(sum(p.amount), 0)
    INTO v_paid
  FROM public.payment p
  WHERE p.payment_arrangement_id = p_arrangement_id
    AND NOT EXISTS (
      SELECT 1 FROM public.payment_reversals pr
      WHERE pr.payment_id = p.paymentid
    );

  SELECT total_amount INTO v_total
  FROM public.payment_arrangements
  WHERE arrangement_id = p_arrangement_id;
  IF v_total IS NULL THEN RETURN; END IF;

  WITH ordered AS (
    SELECT installment_id, due_date,
      sum(amount) OVER (ORDER BY due_date, installment_id) AS cumulative_amount
    FROM public.payment_arrangement_installments
    WHERE arrangement_id = p_arrangement_id
  )
  UPDATE public.payment_arrangement_installments i
  SET status = CASE
    WHEN o.cumulative_amount <= v_paid THEN 'PAID'
    WHEN o.due_date < current_date THEN 'MISSED'
    ELSE 'PENDING'
  END
  FROM ordered o
  WHERE i.installment_id = o.installment_id;

  UPDATE public.payment_arrangements pa
  SET paid_amount = v_paid,
      status = CASE
        WHEN pa.status IN ('CANCELLED', 'DEFAULTED') THEN pa.status
        WHEN v_paid >= pa.total_amount THEN 'COMPLETED'
        ELSE 'ACTIVE'
      END,
      next_follow_up_date = (
        SELECT min(due_date)
        FROM public.payment_arrangement_installments i
        WHERE i.arrangement_id = pa.arrangement_id AND i.status <> 'PAID'
      ),
      updated_at = now()
  WHERE pa.arrangement_id = p_arrangement_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.refresh_arrangement_after_payment()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
BEGIN
  IF TG_OP <> 'INSERT' THEN
    PERFORM public.refresh_payment_arrangement(OLD.payment_arrangement_id);
  END IF;
  IF TG_OP <> 'DELETE' THEN
    PERFORM public.refresh_payment_arrangement(NEW.payment_arrangement_id);
  END IF;
  IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS link_payment_to_active_arrangement ON public.payment;
CREATE TRIGGER link_payment_to_active_arrangement
BEFORE INSERT OR UPDATE OF studentid, payment_arrangement_id
ON public.payment
FOR EACH ROW EXECUTE FUNCTION public.link_payment_to_active_arrangement();

DROP TRIGGER IF EXISTS refresh_arrangement_after_payment ON public.payment;
CREATE TRIGGER refresh_arrangement_after_payment
AFTER INSERT OR UPDATE OF amount, payment_arrangement_id OR DELETE
ON public.payment
FOR EACH ROW EXECUTE FUNCTION public.refresh_arrangement_after_payment();

CREATE OR REPLACE FUNCTION public.refresh_arrangement_after_reversal()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_arrangement_id uuid;
BEGIN
  SELECT payment_arrangement_id INTO v_arrangement_id
  FROM public.payment
  WHERE paymentid = CASE
    WHEN TG_OP = 'DELETE' THEN OLD.payment_id
    ELSE NEW.payment_id
  END;
  PERFORM public.refresh_payment_arrangement(v_arrangement_id);
  IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS refresh_arrangement_after_reversal
  ON public.payment_reversals;
CREATE TRIGGER refresh_arrangement_after_reversal
AFTER INSERT OR UPDATE OR DELETE ON public.payment_reversals
FOR EACH ROW EXECUTE FUNCTION public.refresh_arrangement_after_reversal();

-- ---------------------------------------------------------------------------
-- Academic-year edits preserve term row identities and downstream history
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.save_academic_year(
  p_academic_year_id uuid,
  p_name text,
  p_start_date date,
  p_end_date date,
  p_terms jsonb,
  p_make_current boolean DEFAULT false
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_id uuid;
  v_term jsonb;
  v_definition uuid;
  v_code_count integer;
BEGIN
  IF auth.uid() IS NULL OR NOT (
    public.has_app_role('ADMINISTRATOR') OR public.has_app_role('SUPER_USER')
  ) THEN
    RAISE EXCEPTION 'Only an Administrator or Super User may manage academic years';
  END IF;
  IF p_start_date >= p_end_date THEN
    RAISE EXCEPTION 'Academic-year start date must be before end date';
  END IF;
  IF jsonb_typeof(p_terms) <> 'array' OR jsonb_array_length(p_terms) <> 3 THEN
    RAISE EXCEPTION 'All three academic terms are required';
  END IF;
  SELECT count(DISTINCT upper(value->>'code')) INTO v_code_count
  FROM jsonb_array_elements(p_terms);
  IF v_code_count <> 3 THEN
    RAISE EXCEPTION 'Term 1, Term 2, and Term 3 are each required once';
  END IF;

  IF p_academic_year_id IS NULL THEN
    INSERT INTO public.school_academic_years(
      name, start_date, end_date, created_by
    ) VALUES (
      public.canonical_academic_year_name(p_name),
      p_start_date, p_end_date, auth.uid()
    ) RETURNING academic_year_id INTO v_id;
  ELSE
    UPDATE public.school_academic_years
    SET name = public.canonical_academic_year_name(p_name),
        start_date = p_start_date,
        end_date = p_end_date,
        updated_at = now()
    WHERE academic_year_id = p_academic_year_id
    RETURNING academic_year_id INTO v_id;
    IF v_id IS NULL THEN RAISE EXCEPTION 'Academic year not found'; END IF;
  END IF;

  FOR v_term IN SELECT value FROM jsonb_array_elements(p_terms)
  LOOP
    SELECT term_definition_id INTO v_definition
    FROM public.term_definitions
    WHERE code = upper(v_term->>'code');
    IF v_definition IS NULL THEN RAISE EXCEPTION 'Invalid term definition'; END IF;
    IF (v_term->>'startDate')::date < p_start_date
       OR (v_term->>'endDate')::date > p_end_date
       OR (v_term->>'startDate')::date >= (v_term->>'endDate')::date THEN
      RAISE EXCEPTION 'Each term must be inside the academic year with valid dates';
    END IF;
    INSERT INTO public.academic_year_terms(
      academic_year_id, term_definition_id, start_date, end_date
    ) VALUES (
      v_id, v_definition,
      (v_term->>'startDate')::date,
      (v_term->>'endDate')::date
    )
    ON CONFLICT (academic_year_id, term_definition_id)
    DO UPDATE SET
      start_date = EXCLUDED.start_date,
      end_date = EXCLUDED.end_date,
      updated_at = now();
  END LOOP;

  IF EXISTS (
    SELECT 1
    FROM public.academic_year_terms earlier
    JOIN public.term_definitions earlier_definition
      ON earlier_definition.term_definition_id = earlier.term_definition_id
    JOIN public.academic_year_terms later
      ON later.academic_year_id = earlier.academic_year_id
    JOIN public.term_definitions later_definition
      ON later_definition.term_definition_id = later.term_definition_id
    WHERE earlier.academic_year_id = v_id
      AND earlier_definition.sequence < later_definition.sequence
      AND earlier.end_date >= later.start_date
  ) THEN
    RAISE EXCEPTION 'Terms must be ordered Term 1, Term 2, then Term 3 without overlap';
  END IF;

  IF p_make_current THEN
    UPDATE public.school_academic_years SET is_current = false WHERE is_current;
    UPDATE public.school_academic_years
    SET is_current = true, status = 'ACTIVE', updated_at = now()
    WHERE academic_year_id = v_id;
  END IF;
  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.validate_deposit_slip_link()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.link_payment_to_active_arrangement()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.refresh_payment_arrangement(uuid)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.refresh_arrangement_after_payment()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.refresh_arrangement_after_reversal()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.sync_academic_year_to_legacy(uuid)
  FROM PUBLIC, anon, authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
