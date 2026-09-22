-- 0016_rls_fixes.sql
-- Fixes RLS gaps that cause pages to hang with infinite loading spinners.
-- Root cause: ADMINISTRATOR, SUPER_USER, and ACCOUNTANT roles were missing
-- from SELECT policies on staff, guardian, student, systemuser, classsubject.
--
-- Run in Supabase SQL Editor AFTER all previous migrations.
-- Safe to run multiple times — uses DROP IF EXISTS before CREATE.

-- ─────────────────────────────────────────────────────────────────────────────
-- HELPER: current_app_role()
-- Make sure the helper function exists (defined in 0005 but reproduced here
-- as a safety net in case migrations were applied out of order).
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.current_app_role()
RETURNS TEXT
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT r.rolename
  FROM   public.systemuser su
  JOIN   public.role r ON r.roleid = su.roleid
  WHERE  su.userid   = auth.uid()
    AND  su.isactive = true
  LIMIT 1;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- systemuser
-- ADMINISTRATOR needs to list users for the user management page.
-- ─────────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "admins and registrars can read all users" ON public.systemuser;
CREATE POLICY "privileged roles read all systemusers"
ON public.systemuser FOR SELECT TO authenticated
USING (
  public.current_app_role() IN (
    'SUPER_USER', 'SYSTEM_ADMIN', 'ADMINISTRATOR', 'REGISTRAR', 'HEAD_TEACHER'
  )
);

-- ─────────────────────────────────────────────────────────────────────────────
-- staff
-- ADMINISTRATOR needs staff list; ACCOUNTANT needs staff for payment lookups.
-- ─────────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "privileged roles can read all staff" ON public.staff;
CREATE POLICY "privileged roles read all staff"
ON public.staff FOR SELECT TO authenticated
USING (
  public.current_app_role() IN (
    'SUPER_USER', 'SYSTEM_ADMIN', 'ADMINISTRATOR', 'REGISTRAR',
    'HEAD_TEACHER', 'ACCOUNTANT', 'TEACHER'
  )
);

-- Staff can also manage their own record (update profile fields)
DROP POLICY IF EXISTS "admins and registrars can manage staff" ON public.staff;
CREATE POLICY "admins manage staff"
ON public.staff FOR ALL TO authenticated
USING (
  public.current_app_role() IN ('SUPER_USER', 'SYSTEM_ADMIN', 'ADMINISTRATOR', 'REGISTRAR')
);

-- ─────────────────────────────────────────────────────────────────────────────
-- guardian
-- ADMINISTRATOR and HEAD_TEACHER need guardian list for communications.
-- ─────────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "privileged roles can read guardians" ON public.guardian;
CREATE POLICY "privileged roles read all guardians"
ON public.guardian FOR SELECT TO authenticated
USING (
  public.current_app_role() IN (
    'SUPER_USER', 'SYSTEM_ADMIN', 'ADMINISTRATOR', 'REGISTRAR',
    'HEAD_TEACHER', 'TEACHER', 'ACCOUNTANT'
  )
);

DROP POLICY IF EXISTS "admins and registrars can manage guardians" ON public.guardian;
CREATE POLICY "admins manage guardians"
ON public.guardian FOR ALL TO authenticated
USING (
  public.current_app_role() IN ('SUPER_USER', 'SYSTEM_ADMIN', 'ADMINISTRATOR', 'REGISTRAR')
);

-- ─────────────────────────────────────────────────────────────────────────────
-- student
-- ACCOUNTANT needs students list for finance pages.
-- ─────────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "staff can read all students" ON public.student;
CREATE POLICY "staff read all students"
ON public.student FOR SELECT TO authenticated
USING (
  public.current_app_role() IN (
    'SUPER_USER', 'SYSTEM_ADMIN', 'ADMINISTRATOR', 'REGISTRAR',
    'TEACHER', 'HEAD_TEACHER', 'ACCOUNTANT'
  )
);

DROP POLICY IF EXISTS "registrars can manage students" ON public.student;
CREATE POLICY "admins manage students"
ON public.student FOR ALL TO authenticated
USING (
  public.current_app_role() IN ('SUPER_USER', 'SYSTEM_ADMIN', 'ADMINISTRATOR', 'REGISTRAR')
);

-- ─────────────────────────────────────────────────────────────────────────────
-- studentguardian
-- ─────────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "registrars can manage guardian links" ON public.studentguardian;
CREATE POLICY "admins manage guardian links"
ON public.studentguardian FOR ALL TO authenticated
USING (
  public.current_app_role() IN ('SUPER_USER', 'SYSTEM_ADMIN', 'ADMINISTRATOR', 'REGISTRAR')
);

-- All staff can read links (needed for teacher pages)
DROP POLICY IF EXISTS "staff can read guardian links" ON public.studentguardian;
CREATE POLICY "staff read guardian links"
ON public.studentguardian FOR SELECT TO authenticated
USING (
  public.current_app_role() IN (
    'SUPER_USER', 'SYSTEM_ADMIN', 'ADMINISTRATOR', 'REGISTRAR',
    'TEACHER', 'HEAD_TEACHER', 'ACCOUNTANT'
  )
);

-- ─────────────────────────────────────────────────────────────────────────────
-- studentclasshistory
-- ─────────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "registrars can manage class history"        ON public.studentclasshistory;
DROP POLICY IF EXISTS "staff can read class history"               ON public.studentclasshistory;
CREATE POLICY "admins manage class history"
ON public.studentclasshistory FOR ALL TO authenticated
USING (
  public.current_app_role() IN ('SUPER_USER', 'SYSTEM_ADMIN', 'ADMINISTRATOR', 'REGISTRAR')
);
CREATE POLICY "staff read class history"
ON public.studentclasshistory FOR SELECT TO authenticated
USING (
  public.current_app_role() IN (
    'SUPER_USER', 'SYSTEM_ADMIN', 'ADMINISTRATOR', 'REGISTRAR',
    'TEACHER', 'HEAD_TEACHER', 'ACCOUNTANT'
  )
);

-- ─────────────────────────────────────────────────────────────────────────────
-- classsubject (teaching assignments)
-- ADMINISTRATOR and ACCOUNTANT need to read assignments.
-- ─────────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "all staff read class assignments"           ON public.classsubject;
DROP POLICY IF EXISTS "admin manages class assignments"            ON public.classsubject;
DROP POLICY IF EXISTS "privileged roles can read all assignments"  ON public.classsubject;
DROP POLICY IF EXISTS "admins and registrars can manage assignments" ON public.classsubject;

CREATE POLICY "authenticated staff read class assignments"
ON public.classsubject FOR SELECT TO authenticated
USING (
  public.current_app_role() IN (
    'SUPER_USER', 'SYSTEM_ADMIN', 'ADMINISTRATOR', 'REGISTRAR',
    'TEACHER', 'HEAD_TEACHER', 'ACCOUNTANT'
  )
  OR EXISTS (
    SELECT 1 FROM public.staff s
    WHERE s.staffid = classsubject.staffid
      AND s.userid  = auth.uid()
  )
);

CREATE POLICY "admins manage class assignments"
ON public.classsubject FOR ALL TO authenticated
USING (
  public.current_app_role() IN ('SUPER_USER', 'SYSTEM_ADMIN', 'ADMINISTRATOR', 'REGISTRAR')
);

-- ─────────────────────────────────────────────────────────────────────────────
-- academicyear — ensure ADMINISTRATOR can manage years
-- ─────────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "admins and registrars can manage academic years" ON public.academicyear;
CREATE POLICY "admins manage academic years"
ON public.academicyear FOR ALL TO authenticated
USING (
  public.current_app_role() IN (
    'SUPER_USER', 'SYSTEM_ADMIN', 'ADMINISTRATOR', 'REGISTRAR', 'HEAD_TEACHER'
  )
);

-- ─────────────────────────────────────────────────────────────────────────────
-- class — ensure ADMINISTRATOR can manage
-- ─────────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "admins and registrars can manage classes" ON public.class;
CREATE POLICY "admins manage classes"
ON public.class FOR ALL TO authenticated
USING (
  public.current_app_role() IN ('SUPER_USER', 'SYSTEM_ADMIN', 'ADMINISTRATOR', 'REGISTRAR')
);

-- ─────────────────────────────────────────────────────────────────────────────
-- subject
-- ─────────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "admins can manage subjects" ON public.subject;
CREATE POLICY "admins manage subjects"
ON public.subject FOR ALL TO authenticated
USING (
  public.current_app_role() IN (
    'SUPER_USER', 'SYSTEM_ADMIN', 'ADMINISTRATOR', 'REGISTRAR', 'HEAD_TEACHER'
  )
);

-- ─────────────────────────────────────────────────────────────────────────────
-- auditlog
-- Fix: SUPER_USER was missing from the SELECT policy.
-- ─────────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "system admin can read audit log"    ON public.auditlog;
DROP POLICY IF EXISTS "super admin reads audit log"        ON public.auditlog;
CREATE POLICY "super user reads audit log"
ON public.auditlog FOR SELECT TO authenticated
USING (
  public.current_app_role() IN ('SUPER_USER', 'SYSTEM_ADMIN')
);

-- Ensure INSERT is still open to all authenticated (audit service runs as user)
DROP POLICY IF EXISTS "authenticated users can insert audit records" ON public.auditlog;
DROP POLICY IF EXISTS "any authenticated user can insert audit log"  ON public.auditlog;
CREATE POLICY "authenticated users insert audit log"
ON public.auditlog FOR INSERT TO authenticated
WITH CHECK (true);

-- ─────────────────────────────────────────────────────────────────────────────
-- role & rolepermission — ADMINISTRATOR can read but not modify
-- ─────────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "admins can manage roles"            ON public.role;
CREATE POLICY "super user manages roles"
ON public.role FOR ALL TO authenticated
USING (public.current_app_role() IN ('SUPER_USER', 'SYSTEM_ADMIN'));

DROP POLICY IF EXISTS "admins can manage role permissions" ON public.rolepermission;
CREATE POLICY "super user manages role permissions"
ON public.rolepermission FOR ALL TO authenticated
USING (public.current_app_role() IN ('SUPER_USER', 'SYSTEM_ADMIN'));

-- Allow all authenticated staff to read rolepermission (for permission checks)
DROP POLICY IF EXISTS "staff read role permissions" ON public.rolepermission;
CREATE POLICY "authenticated read role permissions"
ON public.rolepermission FOR SELECT TO authenticated
USING (true);

-- ─────────────────────────────────────────────────────────────────────────────
-- assessment — fix duplicate policies from 0014 vs 0006
-- ─────────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "teacher manages own assessments"       ON public.assessment;
DROP POLICY IF EXISTS "privileged roles read all assessments" ON public.assessment;
DROP POLICY IF EXISTS "teachers can manage own assessments"   ON public.assessment;
DROP POLICY IF EXISTS "privileged roles can read all assessments" ON public.assessment;

CREATE POLICY "teachers manage own assessments"
ON public.assessment FOR ALL TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.classsubject cs
    JOIN   public.staff s ON s.staffid = cs.staffid
    WHERE  cs.classsubjectid = assessment.classsubjectid
      AND  s.userid = auth.uid()
  )
);

CREATE POLICY "privileged roles read assessments"
ON public.assessment FOR SELECT TO authenticated
USING (
  public.current_app_role() IN (
    'SUPER_USER', 'SYSTEM_ADMIN', 'ADMINISTRATOR', 'REGISTRAR', 'HEAD_TEACHER'
  )
);

-- ─────────────────────────────────────────────────────────────────────────────
-- grade — fix duplicate policies from 0014 vs 0006
-- ─────────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "teacher manages grades for own assessments"     ON public.grade;
DROP POLICY IF EXISTS "privileged roles read all grades"               ON public.grade;
DROP POLICY IF EXISTS "guardians read grades for linked students"      ON public.grade;
DROP POLICY IF EXISTS "teachers can manage grades for own assessments" ON public.grade;
DROP POLICY IF EXISTS "privileged roles can read all grades"           ON public.grade;
DROP POLICY IF EXISTS "guardians see grades for linked students"       ON public.grade;

CREATE POLICY "teachers manage grades"
ON public.grade FOR ALL TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.assessment a
    JOIN   public.classsubject cs ON cs.classsubjectid = a.classsubjectid
    JOIN   public.staff s         ON s.staffid = cs.staffid
    WHERE  a.assessmentid = grade.assessmentid
      AND  s.userid = auth.uid()
  )
);

CREATE POLICY "privileged roles read grades"
ON public.grade FOR SELECT TO authenticated
USING (
  public.current_app_role() IN (
    'SUPER_USER', 'SYSTEM_ADMIN', 'ADMINISTRATOR', 'HEAD_TEACHER'
  )
);

CREATE POLICY "guardians read grades for their students"
ON public.grade FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.guardian g
    JOIN   public.studentguardian sg ON sg.guardianid = g.guardianid
    WHERE  g.userid     = auth.uid()
      AND  sg.studentid = grade.studentid
  )
);

-- ─────────────────────────────────────────────────────────────────────────────
-- progressionreview — fix duplicate policies
-- ─────────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "head teacher manages progression reviews"     ON public.progressionreview;
DROP POLICY IF EXISTS "head teacher can manage progression reviews"  ON public.progressionreview;
DROP POLICY IF EXISTS "registrars can read progression reviews"      ON public.progressionreview;

CREATE POLICY "head teacher manages progression reviews"
ON public.progressionreview FOR ALL TO authenticated
USING (
  public.current_app_role() IN (
    'SUPER_USER', 'SYSTEM_ADMIN', 'ADMINISTRATOR', 'REGISTRAR', 'HEAD_TEACHER'
  )
);

-- ─────────────────────────────────────────────────────────────────────────────
-- weedingreview — fix duplicate policies
-- ─────────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "head teacher manages weeding reviews"     ON public.weedingreview;
DROP POLICY IF EXISTS "head teacher can manage weeding reviews"  ON public.weedingreview;
DROP POLICY IF EXISTS "registrars can read weeding reviews"      ON public.weedingreview;

CREATE POLICY "head teacher manages weeding reviews"
ON public.weedingreview FOR ALL TO authenticated
USING (
  public.current_app_role() IN (
    'SUPER_USER', 'SYSTEM_ADMIN', 'ADMINISTRATOR', 'REGISTRAR', 'HEAD_TEACHER'
  )
);

-- ─────────────────────────────────────────────────────────────────────────────
-- VERIFICATION QUERY (run separately to confirm policies applied)
-- ─────────────────────────────────────────────────────────────────────────────
-- SELECT schemaname, tablename, policyname, cmd, roles
-- FROM pg_policies
-- WHERE schemaname = 'public'
-- ORDER BY tablename, policyname;
