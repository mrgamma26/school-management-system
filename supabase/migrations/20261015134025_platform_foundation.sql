BEGIN;

-- Normalized, school-wide academic calendar. The live project already has a
-- distinct legacy public.academic_years table referenced by other tables, so
-- the new setup calendar uses its own name without changing those references.
CREATE TABLE public.school_academic_years (
  academic_year_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE CHECK (name = btrim(name) AND name <> '' AND char_length(name) <= 30),
  start_date date NOT NULL,
  end_date date NOT NULL,
  status text NOT NULL DEFAULT 'DRAFT' CHECK (status IN ('DRAFT', 'ACTIVE', 'CLOSED')),
  is_current boolean NOT NULL DEFAULT false,
  created_by uuid REFERENCES public.systemuser(userid) ON DELETE SET NULL DEFAULT auth.uid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (start_date < end_date),
  CHECK (NOT is_current OR status = 'ACTIVE')
);

CREATE UNIQUE INDEX academic_years_one_current_idx
  ON public.school_academic_years (is_current) WHERE is_current;

CREATE TABLE public.term_definitions (
  term_definition_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text NOT NULL UNIQUE CHECK (code IN ('TERM_1', 'TERM_2', 'TERM_3')),
  name text NOT NULL UNIQUE CHECK (name IN ('Term 1', 'Term 2', 'Term 3')),
  sequence smallint NOT NULL UNIQUE CHECK (sequence BETWEEN 1 AND 3),
  created_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.term_definitions (code, name, sequence)
VALUES ('TERM_1', 'Term 1', 1), ('TERM_2', 'Term 2', 2), ('TERM_3', 'Term 3', 3)
ON CONFLICT (code) DO UPDATE
SET name = EXCLUDED.name, sequence = EXCLUDED.sequence;

CREATE TABLE public.academic_year_terms (
  academic_year_term_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  academic_year_id uuid NOT NULL REFERENCES public.school_academic_years(academic_year_id) ON DELETE CASCADE,
  term_definition_id uuid NOT NULL REFERENCES public.term_definitions(term_definition_id),
  start_date date NOT NULL,
  end_date date NOT NULL,
  is_current boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (academic_year_id, term_definition_id),
  CHECK (start_date < end_date)
);

CREATE UNIQUE INDEX academic_year_terms_one_current_idx
  ON public.academic_year_terms (is_current) WHERE is_current;
CREATE INDEX academic_year_terms_year_dates_idx
  ON public.academic_year_terms (academic_year_id, start_date, end_date);

CREATE OR REPLACE FUNCTION public.set_foundation_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER academic_years_updated_at
BEFORE UPDATE ON public.school_academic_years
FOR EACH ROW EXECUTE FUNCTION public.set_foundation_updated_at();

CREATE TRIGGER academic_year_terms_updated_at
BEFORE UPDATE ON public.academic_year_terms
FOR EACH ROW EXECUTE FUNCTION public.set_foundation_updated_at();

CREATE OR REPLACE FUNCTION public.validate_academic_year_term()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_year public.school_academic_years%ROWTYPE;
BEGIN
  SELECT * INTO v_year
  FROM public.school_academic_years
  WHERE academic_year_id = NEW.academic_year_id;

  IF NEW.start_date < v_year.start_date OR NEW.end_date > v_year.end_date THEN
    RAISE EXCEPTION 'Term dates must be inside the academic year';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.academic_year_terms other
    WHERE other.academic_year_id = NEW.academic_year_id
      AND other.academic_year_term_id <> coalesce(NEW.academic_year_term_id, gen_random_uuid())
      AND daterange(other.start_date, other.end_date, '[]') && daterange(NEW.start_date, NEW.end_date, '[]')
  ) THEN
    RAISE EXCEPTION 'Academic terms cannot overlap';
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER validate_academic_year_term_trigger
BEFORE INSERT OR UPDATE ON public.academic_year_terms
FOR EACH ROW EXECUTE FUNCTION public.validate_academic_year_term();

-- One public school-settings record. Academic year/term are read from the
-- normalized calendar and deliberately are not duplicated here.
CREATE TABLE public.school_settings (
  settings_id uuid PRIMARY KEY DEFAULT '00000000-0000-0000-0000-000000000001',
  school_name text NOT NULL DEFAULT 'School Management System'
    CHECK (school_name = btrim(school_name) AND school_name <> '' AND char_length(school_name) <= 120),
  logo_path text,
  motto text CHECK (motto IS NULL OR (motto = btrim(motto) AND motto <> '' AND char_length(motto) <= 180)),
  physical_address text CHECK (physical_address IS NULL OR btrim(physical_address) <> ''),
  postal_address text CHECK (postal_address IS NULL OR btrim(postal_address) <> ''),
  phone_number text,
  email_address text,
  website text,
  default_currency text NOT NULL DEFAULT 'MWK' CHECK (default_currency ~ '^[A-Z]{3}$'),
  receipt_footer text,
  student_minimum_age smallint NOT NULL DEFAULT 9 CHECK (student_minimum_age = 9),
  student_maximum_age smallint CHECK (student_maximum_age IS NULL OR student_maximum_age >= student_minimum_age),
  staff_minimum_age smallint NOT NULL DEFAULT 18 CHECK (staff_minimum_age = 18),
  accepted_payment_methods text[] NOT NULL DEFAULT ARRAY['CASH', 'BANK_DEPOSIT']::text[],
  balance_carry_forward_policy text NOT NULL DEFAULT 'NEXT_TERM'
    CHECK (balance_carry_forward_policy IN ('NONE', 'NEXT_TERM', 'NEXT_ACADEMIC_YEAR')),
  overdue_day_of_term smallint CHECK (overdue_day_of_term IS NULL OR overdue_day_of_term BETWEEN 1 AND 180),
  deposit_slip_max_bytes integer NOT NULL DEFAULT 5242880
    CHECK (deposit_slip_max_bytes BETWEEN 1024 AND 10485760),
  deposit_slip_mime_types text[] NOT NULL DEFAULT ARRAY['image/jpeg', 'image/png', 'image/webp']::text[],
  updated_by uuid REFERENCES public.systemuser(userid) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.school_settings (settings_id)
VALUES ('00000000-0000-0000-0000-000000000001')
ON CONFLICT (settings_id) DO NOTHING;

CREATE TRIGGER school_settings_updated_at
BEFORE UPDATE ON public.school_settings
FOR EACH ROW EXECUTE FUNCTION public.set_foundation_updated_at();

-- Support the only permitted role pair while retaining systemuser.roleid as
-- the primary-role compatibility field until all consumers are migrated.
CREATE TABLE public.user_roles (
  user_id uuid NOT NULL REFERENCES public.systemuser(userid) ON DELETE CASCADE,
  role_id uuid NOT NULL REFERENCES public.role(roleid) ON DELETE RESTRICT,
  is_primary boolean NOT NULL DEFAULT false,
  created_by uuid REFERENCES public.systemuser(userid) ON DELETE SET NULL DEFAULT auth.uid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, role_id)
);

CREATE UNIQUE INDEX user_roles_one_primary_idx
  ON public.user_roles (user_id) WHERE is_primary;

INSERT INTO public.user_roles (user_id, role_id, is_primary)
SELECT userid, roleid, true FROM public.systemuser
ON CONFLICT (user_id, role_id) DO UPDATE SET is_primary = true;

CREATE OR REPLACE FUNCTION public.validate_user_role_pair()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_roles text[];
BEGIN
  SELECT array_agg(upper(r.rolename) ORDER BY upper(r.rolename)) INTO v_roles
  FROM (
    SELECT role_id FROM public.user_roles WHERE user_id = NEW.user_id
    UNION
    SELECT NEW.role_id
  ) chosen
  JOIN public.role r ON r.roleid = chosen.role_id;

  IF cardinality(v_roles) > 2 OR
     (cardinality(v_roles) = 2 AND v_roles <> ARRAY['HEAD_TEACHER', 'TEACHER']::text[]) THEN
    RAISE EXCEPTION 'Only the Teacher and Head Teacher dual-role combination is permitted';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER validate_user_role_pair_trigger
BEFORE INSERT OR UPDATE ON public.user_roles
FOR EACH ROW EXECUTE FUNCTION public.validate_user_role_pair();

CREATE OR REPLACE FUNCTION public.current_app_roles()
RETURNS text[]
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT coalesce(array_agg(upper(r.rolename)), ARRAY[]::text[])
  FROM public.systemuser su
  JOIN public.user_roles ur ON ur.user_id = su.userid
  JOIN public.role r ON r.roleid = ur.role_id
  WHERE su.userid = auth.uid() AND su.isactive
$$;

CREATE OR REPLACE FUNCTION public.has_app_role(expected text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT upper(expected) = ANY(public.current_app_roles())
$$;

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
SET search_path = public
AS $$
DECLARE
  v_id uuid;
  v_term jsonb;
  v_definition uuid;
BEGIN
  IF auth.uid() IS NULL OR NOT (public.has_app_role('ADMINISTRATOR') OR public.has_app_role('SUPER_USER')) THEN
    RAISE EXCEPTION 'Only an Administrator or Super User may manage academic years';
  END IF;
  IF p_start_date >= p_end_date THEN RAISE EXCEPTION 'Academic-year start date must be before end date'; END IF;
  IF jsonb_typeof(p_terms) <> 'array' OR jsonb_array_length(p_terms) <> 3 THEN
    RAISE EXCEPTION 'All three academic terms are required';
  END IF;

  IF p_academic_year_id IS NULL THEN
    INSERT INTO public.school_academic_years(name, start_date, end_date, created_by)
    VALUES (btrim(p_name), p_start_date, p_end_date, auth.uid())
    RETURNING academic_year_id INTO v_id;
  ELSE
    UPDATE public.school_academic_years
    SET name = btrim(p_name), start_date = p_start_date, end_date = p_end_date
    WHERE academic_year_id = p_academic_year_id
    RETURNING academic_year_id INTO v_id;
    IF v_id IS NULL THEN RAISE EXCEPTION 'Academic year not found'; END IF;
  END IF;

  DELETE FROM public.academic_year_terms WHERE academic_year_id = v_id;
  FOR v_term IN SELECT value FROM jsonb_array_elements(p_terms)
  LOOP
    SELECT term_definition_id INTO v_definition
    FROM public.term_definitions WHERE code = upper(v_term->>'code');
    IF v_definition IS NULL THEN RAISE EXCEPTION 'Invalid term definition'; END IF;
    INSERT INTO public.academic_year_terms(
      academic_year_id, term_definition_id, start_date, end_date
    ) VALUES (
      v_id, v_definition, (v_term->>'startDate')::date, (v_term->>'endDate')::date
    );
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
    SET is_current = true, status = 'ACTIVE'
    WHERE academic_year_id = v_id;
  END IF;
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.activate_academic_year(p_academic_year_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count integer;
  v_sequences smallint[];
BEGIN
  IF auth.uid() IS NULL OR NOT (public.has_app_role('ADMINISTRATOR') OR public.has_app_role('SUPER_USER')) THEN
    RAISE EXCEPTION 'Only an Administrator or Super User may activate an academic year';
  END IF;
  SELECT count(*), array_agg(td.sequence ORDER BY td.sequence)
  INTO v_count, v_sequences
  FROM public.academic_year_terms ayt
  JOIN public.term_definitions td USING (term_definition_id)
  WHERE ayt.academic_year_id = p_academic_year_id;
  IF v_count <> 3 OR v_sequences <> ARRAY[1,2,3]::smallint[] THEN
    RAISE EXCEPTION 'An academic year requires valid Term 1, Term 2, and Term 3 dates';
  END IF;
  UPDATE public.school_academic_years SET is_current = false WHERE is_current;
  UPDATE public.school_academic_years
  SET is_current = true, status = 'ACTIVE'
  WHERE academic_year_id = p_academic_year_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Academic year not found'; END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.set_current_academic_term(p_academic_year_term_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT (public.has_app_role('ADMINISTRATOR') OR public.has_app_role('SUPER_USER')) THEN
    RAISE EXCEPTION 'Only an Administrator or Super User may change the current term';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.academic_year_terms ayt
    JOIN public.school_academic_years ay USING (academic_year_id)
    WHERE ayt.academic_year_term_id = p_academic_year_term_id AND ay.is_current
  ) THEN RAISE EXCEPTION 'The current term must belong to the current academic year'; END IF;
  UPDATE public.academic_year_terms SET is_current = false WHERE is_current;
  UPDATE public.academic_year_terms SET is_current = true
  WHERE academic_year_term_id = p_academic_year_term_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_public_school_branding()
RETURNS TABLE (school_name text, logo_path text, motto text)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT s.school_name, s.logo_path, s.motto
  FROM public.school_settings s
  WHERE s.settings_id = '00000000-0000-0000-0000-000000000001'
$$;

CREATE OR REPLACE FUNCTION public.audit_school_settings_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.auditlog(userid, recordid, actorrole, action, tablename, previousvalue, newvalue, reason)
  VALUES (auth.uid(), NEW.settings_id, public.current_app_role(), 'SCHOOL_SETTINGS_UPDATED',
    'school_settings', to_jsonb(OLD), to_jsonb(NEW),
    CASE WHEN public.has_app_role('SUPER_USER') THEN 'Super User settings update or override' ELSE 'Administrator settings update' END);
  RETURN NEW;
END;
$$;

CREATE TRIGGER audit_school_settings_change_trigger
AFTER UPDATE ON public.school_settings
FOR EACH ROW EXECUTE FUNCTION public.audit_school_settings_change();

ALTER TABLE public.school_academic_years ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.term_definitions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.academic_year_terms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.school_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;

CREATE POLICY academic_years_read ON public.school_academic_years FOR SELECT TO authenticated USING (true);
CREATE POLICY term_definitions_read ON public.term_definitions FOR SELECT TO authenticated USING (true);
CREATE POLICY academic_year_terms_read ON public.academic_year_terms FOR SELECT TO authenticated USING (true);
CREATE POLICY school_settings_read ON public.school_settings FOR SELECT TO authenticated USING (true);
CREATE POLICY school_settings_manage ON public.school_settings FOR UPDATE TO authenticated
USING (public.has_app_role('ADMINISTRATOR') OR public.has_app_role('SUPER_USER'))
WITH CHECK (public.has_app_role('ADMINISTRATOR') OR public.has_app_role('SUPER_USER'));
CREATE POLICY user_roles_read_own_or_admin ON public.user_roles FOR SELECT TO authenticated
USING (user_id = auth.uid() OR public.has_app_role('SUPER_USER') OR public.has_app_role('ADMINISTRATOR'));
CREATE POLICY user_roles_manage ON public.user_roles FOR ALL TO authenticated
USING (public.has_app_role('SUPER_USER') OR public.has_app_role('ADMINISTRATOR'))
WITH CHECK (public.has_app_role('SUPER_USER') OR public.has_app_role('ADMINISTRATOR'));

-- Explicit Data API grants for the 2026 opt-in exposure model.
GRANT SELECT ON public.school_academic_years, public.term_definitions, public.academic_year_terms,
  public.school_settings, public.user_roles TO authenticated;
GRANT UPDATE ON public.school_settings TO authenticated;
GRANT INSERT, UPDATE, DELETE ON public.user_roles TO authenticated;

REVOKE ALL ON FUNCTION public.current_app_roles(), public.has_app_role(text),
  public.save_academic_year(uuid, text, date, date, jsonb, boolean),
  public.activate_academic_year(uuid), public.set_current_academic_term(uuid),
  public.get_public_school_branding() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.current_app_roles(), public.has_app_role(text),
  public.save_academic_year(uuid, text, date, date, jsonb, boolean),
  public.activate_academic_year(uuid), public.set_current_academic_term(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_public_school_branding() TO anon, authenticated;

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('school-branding', 'school-branding', true, 2097152, ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/svg+xml'])
ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

CREATE POLICY school_branding_admin_insert ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'school-branding' AND (public.has_app_role('ADMINISTRATOR') OR public.has_app_role('SUPER_USER')));
CREATE POLICY school_branding_admin_update ON storage.objects FOR UPDATE TO authenticated
USING (bucket_id = 'school-branding' AND (public.has_app_role('ADMINISTRATOR') OR public.has_app_role('SUPER_USER')))
WITH CHECK (bucket_id = 'school-branding' AND (public.has_app_role('ADMINISTRATOR') OR public.has_app_role('SUPER_USER')));
CREATE POLICY school_branding_admin_delete ON storage.objects FOR DELETE TO authenticated
USING (bucket_id = 'school-branding' AND (public.has_app_role('ADMINISTRATOR') OR public.has_app_role('SUPER_USER')));

NOTIFY pgrst, 'reload schema';
COMMIT;
