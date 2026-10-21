-- Handbook rules enforced in PostgreSQL (not only in Flutter) plus
-- defence-in-depth grant hardening. Idempotent and safe to apply to a
-- project that already contains data.
BEGIN;

-- 1. Student minimum age (9 years) and no future birth dates.
--    A trigger (not a CHECK constraint) is used on purpose: it validates new
--    students and any change to the birth date, but never blocks unrelated
--    updates (e.g. a status change) on legacy rows that pre-date this rule.
CREATE OR REPLACE FUNCTION public.validate_student_birth_date()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_catalog
AS $$
BEGIN
  IF TG_OP = 'UPDATE' AND NEW.dateofbirth IS NOT DISTINCT FROM OLD.dateofbirth THEN
    RETURN NEW;
  END IF;
  IF NEW.dateofbirth IS NULL THEN
    RETURN NEW;
  END IF;
  IF NEW.dateofbirth > current_date THEN
    RAISE EXCEPTION 'A student date of birth cannot be in the future'
      USING ERRCODE = '23514';
  END IF;
  IF NEW.dateofbirth > (current_date - interval '9 years')::date THEN
    RAISE EXCEPTION 'A student must be at least 9 years old'
      USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.validate_student_birth_date()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS validate_student_birth_date_trigger ON public.student;
CREATE TRIGGER validate_student_birth_date_trigger
BEFORE INSERT OR UPDATE OF dateofbirth ON public.student
FOR EACH ROW EXECUTE FUNCTION public.validate_student_birth_date();

-- 2. Anonymous visitors only need the public branding RPC (login screen).
--    RLS already blocks anonymous table access; remove the grants as well.
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM anon;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM anon;
REVOKE ALL ON FUNCTION public.set_updated_at() FROM PUBLIC, anon, authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON TABLES FROM anon;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON SEQUENCES FROM anon;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON FUNCTIONS FROM anon;
GRANT EXECUTE ON FUNCTION public.get_public_school_branding() TO anon, authenticated;

-- 3. Signed-in users never need TRUNCATE, REFERENCES or TRIGGER (TRUNCATE
--    bypasses row-level security).
REVOKE TRUNCATE, REFERENCES, TRIGGER ON ALL TABLES IN SCHEMA public
  FROM authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
