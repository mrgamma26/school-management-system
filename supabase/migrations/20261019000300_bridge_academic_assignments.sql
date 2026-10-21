BEGIN;

-- Assessments still reference legacy form/term rows. Keep them synchronized
-- from the normalized academic setup until the assessment schema is migrated.
-- This older live-project index predates form-scoped periods and incorrectly
-- permits only one row per term/year across all four forms.
ALTER TABLE public.academicyear
  DROP CONSTRAINT IF EXISTS uq_academicyear_term;

CREATE OR REPLACE FUNCTION public.sync_academic_year_to_legacy(
  p_academic_year_id uuid
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
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
    classid, subjectid, staffid, academicyearid, updatedat
  )
  SELECT
    csc.class_id,
    csc.subject_id,
    ta.staff_id,
    ay.academicyearid,
    now()
  FROM public.teacher_assignments ta
  JOIN public.class_subject_catalog csc
    ON csc.class_subject_id = ta.class_subject_id AND csc.is_active
  JOIN public.class c ON c.classid = csc.class_id
  JOIN public.academicyear ay
    ON ay.academicyear = v_start_year AND ay.form = c.form
  WHERE ta.academic_year_id = p_academic_year_id
    AND ta.status = 'ACTIVE'
  ON CONFLICT (classid, subjectid, staffid, academicyearid)
  DO UPDATE SET updatedat = now();
END;
$$;

CREATE OR REPLACE FUNCTION public.sync_academic_year_to_legacy_trigger()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM public.sync_academic_year_to_legacy(NEW.academic_year_id);
  RETURN NEW;
END;
$$;

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

DO $$
DECLARE year_row record;
BEGIN
  FOR year_row IN SELECT academic_year_id FROM public.school_academic_years LOOP
    PERFORM public.sync_academic_year_to_legacy(year_row.academic_year_id);
  END LOOP;
END;
$$;

REVOKE ALL ON FUNCTION public.sync_academic_year_to_legacy(uuid)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.sync_academic_year_to_legacy_trigger()
  FROM PUBLIC, anon, authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
