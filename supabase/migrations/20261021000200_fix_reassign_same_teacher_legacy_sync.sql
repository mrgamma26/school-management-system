BEGIN;

-- Re-assigning a teacher to a class subject after an earlier assignment ended (Remove teacher, or a
-- change that is later switched back) failed with "That value already exists": the legacy bridge
-- copied EVERY assignment of the year into classsubject, so an ended row and the new active row for the
-- same teacher produced two source rows with one conflict key inside a single INSERT.
-- Keep one row per key and prefer the ACTIVE assignment (then the latest). Mark-entry access follows the
-- linked assignment, so an ended-only key stays revoked and a re-assigned teacher regains access.
CREATE OR REPLACE FUNCTION public.sync_academic_year_to_legacy(p_academic_year_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
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
  SELECT DISTINCT ON (csc.class_id, csc.subject_id, ta.staff_id, ay.academicyearid)
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
  ORDER BY csc.class_id, csc.subject_id, ta.staff_id, ay.academicyearid,
    (ta.status = 'ACTIVE') DESC, ta.assigned_at DESC
  ON CONFLICT (classid, subjectid, staffid, academicyearid)
  DO UPDATE SET
    teacher_assignment_id = EXCLUDED.teacher_assignment_id,
    updatedat = now();
END;
$function$
;

REVOKE ALL ON FUNCTION public.sync_academic_year_to_legacy(uuid) FROM PUBLIC, anon, authenticated;

-- Re-run the bridge for every year so existing rows link to the right assignment.
DO $$
DECLARE year_row record;
BEGIN
  FOR year_row IN SELECT academic_year_id FROM public.school_academic_years LOOP
    PERFORM public.sync_academic_year_to_legacy(year_row.academic_year_id);
  END LOOP;
END;
$$;

NOTIFY pgrst, 'reload schema';
COMMIT;
