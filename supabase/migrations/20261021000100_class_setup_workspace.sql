BEGIN;

-- Class Setup workspace support:
--   * which subjects each teacher is marked as teaching (staff_subjects),
--   * removing a teacher / unlinking a subject without losing history,
--   * assignment now refuses a teacher who is not marked for the subject.

-- ---------------------------------------------------------------------------
-- 1. Subjects a staff member teaches
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.staff_subjects (
  staff_id uuid NOT NULL REFERENCES public.staff(staffid) ON DELETE CASCADE,
  subject_id uuid NOT NULL REFERENCES public.subject(subjectid) ON DELETE CASCADE,
  created_by uuid REFERENCES public.systemuser(userid) ON DELETE SET NULL DEFAULT auth.uid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (staff_id, subject_id)
);

CREATE INDEX IF NOT EXISTS staff_subjects_subject_idx
  ON public.staff_subjects (subject_id);

ALTER TABLE public.staff_subjects ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS staff_subjects_read ON public.staff_subjects;
CREATE POLICY staff_subjects_read ON public.staff_subjects
FOR SELECT TO authenticated
USING (
  public.has_app_role('ADMINISTRATOR')
  OR public.has_app_role('SUPER_USER')
  OR public.has_app_role('HEAD_TEACHER')
  OR EXISTS (
    SELECT 1 FROM public.staff st
    WHERE st.staffid = staff_subjects.staff_id AND st.userid = auth.uid()
  )
);

-- Writes go through set_staff_subjects(); no direct INSERT/UPDATE/DELETE.
REVOKE ALL ON public.staff_subjects FROM PUBLIC, anon;
GRANT SELECT ON public.staff_subjects TO authenticated;

-- Existing active and past assignments stay valid: whoever already teaches a
-- subject is marked as teaching it.
INSERT INTO public.staff_subjects (staff_id, subject_id)
SELECT DISTINCT ta.staff_id, csc.subject_id
FROM public.teacher_assignments ta
JOIN public.class_subject_catalog csc ON csc.class_subject_id = ta.class_subject_id
ON CONFLICT DO NOTHING;

CREATE OR REPLACE FUNCTION public.set_staff_subjects(
  p_staff_id uuid,
  p_subject_ids uuid[]
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_new uuid[] := coalesce(p_subject_ids, ARRAY[]::uuid[]);
  v_old uuid[];
  v_blocked text;
BEGIN
  IF auth.uid() IS NULL OR NOT (public.has_app_role('ADMINISTRATOR') OR public.has_app_role('SUPER_USER')) THEN
    RAISE EXCEPTION 'Only an Administrator or Super User may change the subjects a teacher teaches';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.staff WHERE staffid = p_staff_id) THEN
    RAISE EXCEPTION 'Staff member not found';
  END IF;

  SELECT coalesce(array_agg(subject_id), ARRAY[]::uuid[]) INTO v_old
  FROM public.staff_subjects WHERE staff_id = p_staff_id;

  -- A subject cannot be un-marked while the teacher currently teaches it.
  SELECT string_agg(DISTINCT s.subjectname, ', ') INTO v_blocked
  FROM public.teacher_assignments ta
  JOIN public.class_subject_catalog csc ON csc.class_subject_id = ta.class_subject_id
  JOIN public.subject s ON s.subjectid = csc.subject_id
  WHERE ta.staff_id = p_staff_id
    AND ta.status = 'ACTIVE'
    AND NOT (csc.subject_id = ANY(v_new));
  IF v_blocked IS NOT NULL THEN
    RAISE EXCEPTION 'This teacher still teaches % in Class Setup. Reassign or remove those first.', v_blocked;
  END IF;

  DELETE FROM public.staff_subjects
  WHERE staff_id = p_staff_id AND NOT (subject_id = ANY(v_new));

  INSERT INTO public.staff_subjects (staff_id, subject_id)
  SELECT p_staff_id, chosen.subject_id
  FROM unnest(v_new) AS chosen(subject_id)
  JOIN public.subject s ON s.subjectid = chosen.subject_id
  ON CONFLICT DO NOTHING;

  INSERT INTO public.auditlog(userid, recordid, actorrole, action, tablename, previousvalue, newvalue)
  VALUES (auth.uid(), p_staff_id, public.current_app_role(), 'STAFF_SUBJECTS_UPDATED', 'staff_subjects',
    jsonb_build_object('subject_ids', to_jsonb(v_old)),
    jsonb_build_object('subject_ids', to_jsonb(v_new)));
END;
$$;

-- ---------------------------------------------------------------------------
-- 2. Assignment only accepts a teacher marked for the subject
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.assign_teacher_to_class_subjects(
  p_staff_id uuid,
  p_class_subject_ids uuid[],
  p_replacement_reason text DEFAULT NULL
) RETURNS SETOF public.teacher_assignments
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_year_id uuid;
  v_class_subject_id uuid;
  v_old public.teacher_assignments%ROWTYPE;
  v_new public.teacher_assignments%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL OR NOT (public.has_app_role('ADMINISTRATOR') OR public.has_app_role('SUPER_USER')) THEN
    RAISE EXCEPTION 'Only an Administrator or Super User may assign teachers';
  END IF;
  SELECT academic_year_id INTO v_year_id FROM public.school_academic_years WHERE is_current;
  IF v_year_id IS NULL THEN RAISE EXCEPTION 'Set a current academic year before assigning teachers'; END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.staff st
    JOIN public.user_roles ur ON ur.user_id = st.userid
    JOIN public.role r ON r.roleid = ur.role_id
    WHERE st.staffid = p_staff_id AND upper(r.rolename) IN ('TEACHER', 'HEAD_TEACHER')
  ) THEN RAISE EXCEPTION 'The selected staff member is not an active teacher'; END IF;

  FOREACH v_class_subject_id IN ARRAY coalesce(p_class_subject_ids, ARRAY[]::uuid[])
  LOOP
    IF NOT EXISTS (SELECT 1 FROM public.class_subject_catalog WHERE class_subject_id = v_class_subject_id AND is_active) THEN
      RAISE EXCEPTION 'A selected class subject is not active';
    END IF;
    IF NOT EXISTS (
      SELECT 1
      FROM public.class_subject_catalog csc
      JOIN public.staff_subjects ss ON ss.subject_id = csc.subject_id
      WHERE csc.class_subject_id = v_class_subject_id AND ss.staff_id = p_staff_id
    ) THEN
      RAISE EXCEPTION 'This teacher is not marked as teaching that subject. Mark it on the teacher''s staff profile first';
    END IF;
    SELECT * INTO v_old FROM public.teacher_assignments
    WHERE class_subject_id = v_class_subject_id AND academic_year_id = v_year_id AND status = 'ACTIVE'
    FOR UPDATE;
    IF v_old.teacher_assignment_id IS NOT NULL AND v_old.staff_id = p_staff_id THEN
      CONTINUE;
    END IF;
    IF v_old.teacher_assignment_id IS NOT NULL THEN
      UPDATE public.teacher_assignments
      SET status = 'REPLACED', ended_at = now(), replacement_reason = nullif(btrim(p_replacement_reason), '')
      WHERE teacher_assignment_id = v_old.teacher_assignment_id;
    END IF;
    INSERT INTO public.teacher_assignments(class_subject_id, academic_year_id, staff_id, assigned_by)
    VALUES (v_class_subject_id, v_year_id, p_staff_id, auth.uid()) RETURNING * INTO v_new;
    IF v_old.teacher_assignment_id IS NOT NULL THEN
      UPDATE public.teacher_assignments SET replaced_by_assignment_id = v_new.teacher_assignment_id
      WHERE teacher_assignment_id = v_old.teacher_assignment_id;
    END IF;
    INSERT INTO public.auditlog(userid, recordid, actorrole, action, tablename, previousvalue, newvalue, reason)
    VALUES (auth.uid(), v_new.teacher_assignment_id, public.current_app_role(),
      CASE WHEN v_old.teacher_assignment_id IS NULL THEN 'TEACHER_ASSIGNED' ELSE 'TEACHER_REPLACED' END,
      'teacher_assignments', CASE WHEN v_old.teacher_assignment_id IS NULL THEN NULL ELSE to_jsonb(v_old) END,
      to_jsonb(v_new), nullif(btrim(p_replacement_reason), ''));
    RETURN NEXT v_new;
  END LOOP;
END;
$$;

-- ---------------------------------------------------------------------------
-- 3. Remove a teacher from a class subject (keeps the subject linked)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.end_teacher_assignment(
  p_class_subject_id uuid,
  p_reason text DEFAULT NULL
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_year_id uuid;
  v_old public.teacher_assignments%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL OR NOT (public.has_app_role('ADMINISTRATOR') OR public.has_app_role('SUPER_USER')) THEN
    RAISE EXCEPTION 'Only an Administrator or Super User may remove a teacher';
  END IF;
  SELECT academic_year_id INTO v_year_id FROM public.school_academic_years WHERE is_current;
  IF v_year_id IS NULL THEN RAISE EXCEPTION 'Set a current academic year first'; END IF;

  SELECT * INTO v_old FROM public.teacher_assignments
  WHERE class_subject_id = p_class_subject_id AND academic_year_id = v_year_id AND status = 'ACTIVE'
  FOR UPDATE;
  IF v_old.teacher_assignment_id IS NULL THEN
    RAISE EXCEPTION 'This subject has no teacher to remove';
  END IF;

  -- The row is kept as history. Mark-entry access follows ACTIVE status, so
  -- the removed teacher loses access to the class subject immediately.
  UPDATE public.teacher_assignments
  SET status = 'ENDED', ended_at = now(), replacement_reason = nullif(btrim(p_reason), '')
  WHERE teacher_assignment_id = v_old.teacher_assignment_id;

  INSERT INTO public.auditlog(userid, recordid, actorrole, action, tablename, previousvalue, reason)
  VALUES (auth.uid(), v_old.teacher_assignment_id, public.current_app_role(),
    'TEACHER_REMOVED', 'teacher_assignments', to_jsonb(v_old), nullif(btrim(p_reason), ''));
END;
$$;

-- ---------------------------------------------------------------------------
-- 4. Unlink a subject from a class (blocked once assessments exist)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.unlink_class_subject(
  p_class_subject_id uuid
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row public.class_subject_catalog%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL OR NOT (public.has_app_role('ADMINISTRATOR') OR public.has_app_role('SUPER_USER')) THEN
    RAISE EXCEPTION 'Only an Administrator or Super User may unlink a subject';
  END IF;
  SELECT * INTO v_row FROM public.class_subject_catalog
  WHERE class_subject_id = p_class_subject_id AND is_active
  FOR UPDATE;
  IF v_row.class_subject_id IS NULL THEN
    RAISE EXCEPTION 'That subject is not linked to the class';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.assessment a
    JOIN public.classsubject cs ON cs.classsubjectid = a.classsubjectid
    WHERE cs.classid = v_row.class_id AND cs.subjectid = v_row.subject_id
  ) THEN
    RAISE EXCEPTION 'This subject already has assessments or marks in this class, so it cannot be unlinked';
  END IF;

  UPDATE public.teacher_assignments
  SET status = 'ENDED', ended_at = now(), replacement_reason = 'Subject unlinked from class'
  WHERE class_subject_id = p_class_subject_id AND status = 'ACTIVE';

  UPDATE public.student_subject_enrollments
  SET is_active = false, ended_at = now()
  WHERE class_subject_id = p_class_subject_id AND is_active;

  UPDATE public.class_subject_catalog
  SET is_active = false
  WHERE class_subject_id = p_class_subject_id;

  INSERT INTO public.auditlog(userid, recordid, actorrole, action, tablename, previousvalue)
  VALUES (auth.uid(), p_class_subject_id, public.current_app_role(),
    'CLASS_SUBJECT_UNLINKED', 'class_subject_catalog', to_jsonb(v_row));
END;
$$;

-- ---------------------------------------------------------------------------
-- 5. Permissions (same convention as 20261016181832_restrict_new_rpc_access)
-- ---------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.set_staff_subjects(uuid, uuid[]) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.end_teacher_assignment(uuid, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.unlink_class_subject(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.assign_teacher_to_class_subjects(uuid, uuid[], text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_staff_subjects(uuid, uuid[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.end_teacher_assignment(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.unlink_class_subject(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.assign_teacher_to_class_subjects(uuid, uuid[], text) TO authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
