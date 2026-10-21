-- Close account lifecycle and authorization gaps discovered by tracing the
-- complete migration chain through 0044. This migration is intentionally
-- additive so deployed projects retain an auditable history.
BEGIN;
CREATE SCHEMA IF NOT EXISTS private;
REVOKE ALL ON SCHEMA private FROM PUBLIC;
GRANT USAGE ON SCHEMA private TO authenticated;
-- A deactivated account may still hold a valid JWT. Every protected table
-- therefore checks live account state instead of trusting session age.
CREATE OR REPLACE FUNCTION public.current_user_is_active()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.systemuser su
    WHERE su.userid = (SELECT auth.uid())
      AND su.isactive = true
  )
$$;
REVOKE ALL ON FUNCTION public.current_user_is_active() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.current_user_is_active() TO authenticated;
CREATE OR REPLACE FUNCTION private.can_assign_role(p_role_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT CASE public.current_app_role()
    WHEN 'SUPER_USER' THEN target.rolename IN (
      'SUPER_USER', 'ADMINISTRATOR', 'HEAD_TEACHER',
      'TEACHER', 'ACCOUNTANT', 'GUARDIAN'
    )
    WHEN 'ADMINISTRATOR' THEN target.rolename IN (
      'TEACHER', 'ACCOUNTANT', 'GUARDIAN'
    )
    ELSE false
  END
  FROM (
    SELECT upper(r.rolename) AS rolename
    FROM public.role r
    WHERE r.roleid = p_role_id
  ) target
$$;
CREATE OR REPLACE FUNCTION private.can_manage_account(p_target_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT p_target_user_id <> (SELECT auth.uid())
    AND CASE public.current_app_role()
      WHEN 'SUPER_USER' THEN true
      WHEN 'ADMINISTRATOR' THEN EXISTS (
        SELECT 1
        FROM public.systemuser target_user
        JOIN public.role target_role ON target_role.roleid = target_user.roleid
        WHERE target_user.userid = p_target_user_id
          AND upper(target_role.rolename) IN (
            'TEACHER', 'ACCOUNTANT', 'GUARDIAN'
          )
      )
      ELSE false
    END
$$;
REVOKE ALL ON FUNCTION private.can_assign_role(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION private.can_manage_account(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION private.can_assign_role(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION private.can_manage_account(uuid) TO authenticated;
-- Registrar was retired by 0026. Re-run the data cleanup defensively and
-- ensure no active policy or account can retain that obsolete role.
DO $$
DECLARE
  registrar_id uuid;
  guardian_id uuid;
BEGIN
  SELECT roleid INTO registrar_id
  FROM public.role
  WHERE upper(rolename) = 'REGISTRAR';

  IF registrar_id IS NOT NULL THEN
    SELECT roleid INTO guardian_id
    FROM public.role
    WHERE upper(rolename) = 'GUARDIAN';

    IF guardian_id IS NULL THEN
      RAISE EXCEPTION 'Cannot retire REGISTRAR without a GUARDIAN role';
    END IF;

    UPDATE public.systemuser
    SET roleid = guardian_id,
        isactive = false
    WHERE roleid = registrar_id;

    DELETE FROM public.rolepermission WHERE roleid = registrar_id;
    DELETE FROM public.role WHERE roleid = registrar_id;
  END IF;
END $$;
-- Account managers may update only lower-scope targets and may never change
-- their own role or active flag. Account creation remains an Edge Function
-- operation using the service role after independent authorization checks.
DROP POLICY IF EXISTS "privileged roles manage systemusers" ON public.systemuser;
DROP POLICY IF EXISTS "admins can manage system users" ON public.systemuser;
DROP POLICY IF EXISTS "account managers update permitted users" ON public.systemuser;
CREATE POLICY "account managers update permitted users"
ON public.systemuser
FOR UPDATE
TO authenticated
USING (private.can_manage_account(userid))
WITH CHECK (
  private.can_manage_account(userid)
  AND private.can_assign_role(roleid)
);
REVOKE INSERT, DELETE ON public.systemuser FROM authenticated;
REVOKE UPDATE ON public.systemuser FROM authenticated;
GRANT UPDATE (roleid, isactive) ON public.systemuser TO authenticated;
-- 0040 created this strict policy without removing the plural-named policy
-- from 0016. Permissive RLS policies are ORed, so the old policy defeated the
-- student-enrolment and entered-by checks.
DROP POLICY IF EXISTS "teachers manage grades" ON public.grade;
DROP POLICY IF EXISTS "teacher manages grades for assigned assessments" ON public.grade;
CREATE POLICY "teacher manages grades for assigned assessments"
ON public.grade
FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.assessment a
    JOIN public.classsubject cs ON cs.classsubjectid = a.classsubjectid
    JOIN public.staff s ON s.staffid = cs.staffid
    WHERE a.assessmentid = grade.assessmentid
      AND s.userid = (SELECT auth.uid())
      AND grade.enteredby = s.staffid
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
    WHERE a.assessmentid = grade.assessmentid
      AND s.userid = (SELECT auth.uid())
      AND grade.enteredby = s.staffid
  )
);
-- Audit rows must identify the authenticated actor; a client may not forge a
-- different user or role in the append-only audit trail.
DROP POLICY IF EXISTS "authenticated users insert audit log" ON public.auditlog;
CREATE POLICY "active users insert own audit log"
ON public.auditlog
FOR INSERT
TO authenticated
WITH CHECK (
  userid = (SELECT auth.uid())
  AND upper(actorrole) = public.current_app_role()
);
-- Preserve guardian product behaviour while ensuring the link belongs to the
-- active caller. Assessment metadata and progression outcomes are limited to
-- students linked to that guardian.
CREATE OR REPLACE FUNCTION private.guardian_is_linked_to_student(p_student_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT public.current_user_is_active()
    AND EXISTS (
      SELECT 1
      FROM public.guardian g
      JOIN public.studentguardian sg ON sg.guardianid = g.guardianid
      WHERE g.userid = (SELECT auth.uid())
        AND sg.studentid = p_student_id
    )
$$;
REVOKE ALL ON FUNCTION private.guardian_is_linked_to_student(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION private.guardian_is_linked_to_student(uuid) TO authenticated;
CREATE OR REPLACE FUNCTION private.guardian_can_read_assessment(
  p_assessment_id uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT public.current_user_is_active()
    AND EXISTS (
      SELECT 1
      FROM public.grade linked_grade
      JOIN public.studentguardian sg
        ON sg.studentid = linked_grade.studentid
      JOIN public.guardian g ON g.guardianid = sg.guardianid
      WHERE linked_grade.assessmentid = p_assessment_id
        AND g.userid = (SELECT auth.uid())
    )
$$;
REVOKE ALL ON FUNCTION private.guardian_can_read_assessment(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION private.guardian_can_read_assessment(uuid) TO authenticated;
DROP POLICY IF EXISTS "guardians read linked assessment metadata" ON public.assessment;
CREATE POLICY "guardians read linked assessment metadata"
ON public.assessment
FOR SELECT
TO authenticated
USING (
  private.guardian_can_read_assessment(assessmentid)
);
DROP POLICY IF EXISTS "guardians view linked progression reviews" ON public.progressionreview;
CREATE POLICY "guardians view linked progression reviews"
ON public.progressionreview
FOR SELECT
TO authenticated
USING (private.guardian_is_linked_to_student(studentid));
-- Restrictive policies are ANDed with every table-specific permissive policy.
-- This immediately blocks a deactivated user's existing JWT from all school
-- data, including guardian ownership policies and globally readable catalogs.
DO $$
DECLARE
  table_name text;
  protected_tables constant text[] := ARRAY[
    'role', 'rolepermission', 'systemuser', 'staff', 'guardian', 'auditlog',
    'academicyear', 'class', 'subject', 'classsubject', 'student',
    'studentguardian', 'studentclasshistory', 'studentsubject', 'assessment',
    'grade', 'progressionreview', 'progressionrule', 'weedingreview',
    'feestructure', 'paymentchannel', 'payment', 'financialadjustment',
    'notification', 'teachercomment', 'calendarevent'
  ];
BEGIN
  FOREACH table_name IN ARRAY protected_tables LOOP
    IF to_regclass(format('public.%I', table_name)) IS NOT NULL THEN
      EXECUTE format(
        'ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', table_name
      );
      EXECUTE format(
        'DROP POLICY IF EXISTS "active accounts only" ON public.%I', table_name
      );
      EXECUTE format(
        'CREATE POLICY "active accounts only" ON public.%I AS RESTRICTIVE '
        'FOR ALL TO authenticated USING ((SELECT public.current_user_is_active())) '
        'WITH CHECK ((SELECT public.current_user_is_active()))',
        table_name
      );
    END IF;
  END LOOP;
END $$;
-- The raw progression calculators are SECURITY DEFINER functions. Move them
-- behind role-checking wrappers so arbitrary authenticated users cannot bypass
-- RLS by calling the RPC directly for another learner.
ALTER FUNCTION public.calculate_student_annual_result(uuid, integer)
  SET SCHEMA private;
ALTER FUNCTION public.refresh_progression_review(uuid, integer)
  SET SCHEMA private;
REVOKE ALL ON FUNCTION private.calculate_student_annual_result(uuid, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION private.calculate_student_annual_result(uuid, integer) FROM authenticated;
REVOKE ALL ON FUNCTION private.refresh_progression_review(uuid, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION private.refresh_progression_review(uuid, integer) FROM authenticated;
CREATE FUNCTION public.calculate_student_annual_result(
  p_student_id uuid,
  p_school_year integer
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF public.current_app_role() <> 'HEAD_TEACHER' THEN
    RAISE EXCEPTION 'Only a Head Teacher may calculate progression.'
      USING ERRCODE = '42501';
  END IF;
  RETURN private.calculate_student_annual_result(p_student_id, p_school_year);
END $$;
CREATE FUNCTION public.refresh_progression_review(
  p_student_id uuid,
  p_school_year integer
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF public.current_app_role() <> 'HEAD_TEACHER' THEN
    RAISE EXCEPTION 'Only a Head Teacher may refresh progression.'
      USING ERRCODE = '42501';
  END IF;
  RETURN private.refresh_progression_review(p_student_id, p_school_year);
END $$;
REVOKE ALL ON FUNCTION public.calculate_student_annual_result(uuid, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.refresh_progression_review(uuid, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.calculate_student_annual_result(uuid, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.refresh_progression_review(uuid, integer) TO authenticated;
NOTIFY pgrst, 'reload schema';
COMMIT;
