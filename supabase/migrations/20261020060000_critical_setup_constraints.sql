BEGIN;

-- Administrators must be able to recreate the singleton if it is absent.
-- UPDATE remains the normal path; INSERT is constrained to the fixed key.
GRANT INSERT ON public.school_settings TO authenticated;

DROP POLICY IF EXISTS school_settings_insert ON public.school_settings;
CREATE POLICY school_settings_insert
ON public.school_settings FOR INSERT TO authenticated
WITH CHECK (
  settings_id = '00000000-0000-0000-0000-000000000001'::uuid
  AND (
    public.has_app_role('ADMINISTRATOR')
    OR public.has_app_role('SUPER_USER')
  )
);

-- A student roster is joined by exact class and legacy academic-period IDs.
-- Reject mismatched form combinations at the database boundary so a stale or
-- malicious client cannot create a placement that disappears from mark entry.
CREATE OR REPLACE FUNCTION public.validate_student_class_period_form()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_class_form text;
  v_period_form text;
BEGIN
  SELECT c.form INTO v_class_form
  FROM public.class c
  WHERE c.classid = NEW.classid;

  SELECT ay.form INTO v_period_form
  FROM public.academicyear ay
  WHERE ay.academicyearid = NEW.academicyearid;

  IF v_class_form IS NULL THEN
    RAISE EXCEPTION 'The selected class has no form configured';
  END IF;
  IF v_period_form IS NULL THEN
    RAISE EXCEPTION 'The selected academic period has no form configured';
  END IF;
  IF v_class_form IS DISTINCT FROM v_period_form THEN
    RAISE EXCEPTION
      'Class form % does not match academic period form %',
      v_class_form, v_period_form;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS validate_student_class_period_form_trigger
  ON public.studentclasshistory;
CREATE TRIGGER validate_student_class_period_form_trigger
BEFORE INSERT OR UPDATE OF classid, academicyearid
ON public.studentclasshistory
FOR EACH ROW EXECUTE FUNCTION public.validate_student_class_period_form();

REVOKE ALL ON FUNCTION public.validate_student_class_period_form()
  FROM PUBLIC, anon, authenticated;

-- Reassert the normalized-to-legacy bridges. These triggers make academic
-- periods available to fees, placement, and assessment immediately, and make
-- canonical teacher assignments available to the legacy mark workspace.
DROP TRIGGER IF EXISTS sync_academic_year_terms_to_legacy
  ON public.academic_year_terms;
CREATE TRIGGER sync_academic_year_terms_to_legacy
AFTER INSERT OR UPDATE ON public.academic_year_terms
FOR EACH ROW EXECUTE FUNCTION public.sync_academic_year_to_legacy_trigger();

DROP TRIGGER IF EXISTS sync_teacher_assignments_to_legacy
  ON public.teacher_assignments;
CREATE TRIGGER sync_teacher_assignments_to_legacy
AFTER INSERT OR UPDATE ON public.teacher_assignments
FOR EACH ROW EXECUTE FUNCTION public.sync_academic_year_to_legacy_trigger();

NOTIFY pgrst, 'reload schema';
COMMIT;
