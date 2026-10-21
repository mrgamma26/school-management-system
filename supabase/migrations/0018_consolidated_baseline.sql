-- 0018_consolidated_baseline.sql
-- ============================================================================
-- CONSOLIDATED RLS BASELINE for Mai Halima School Management System
-- ============================================================================
-- Purpose: Documents the complete, production-ready RLS policy state after
--          Phase 4 cleanup. This is the canonical reference for all 9 user
--          roles and their table permissions.
--
-- DO NOT RUN THIS MIGRATION if 0001-0017 are already applied.
-- This file serves as:
--   1. Documentation of current RLS state
--   2. Reference for new developers
--   3. Baseline for future RLS audits
--   4. Recovery script if RLS needs to be rebuilt
--
-- To rebuild RLS from scratch (destructive):
--   1. Drop all existing policies
--   2. Run this migration
--
-- Last audit: September 15, 2026 (Phase 4)
-- ============================================================================

-- ============================================================================
-- ROLE HIERARCHY (reference only)
-- ============================================================================
-- SUPER_USER          → Full platform access (system owner)
-- SYSTEM_ADMIN        → Full administrative access
-- ADMINISTRATOR       → School administrative access
-- REGISTRAR           → Student/staff/guardian CRUD
-- HEAD_TEACHER        → Academic oversight, reviews
-- TEACHER             → Own classes/assessments/grades
-- ACCOUNTANT          → Finance operations
-- GUARDIAN            → Own children's data only
-- GUEST               → (not in database; unauthenticated)
-- ============================================================================

-- ============================================================================
-- SECTION 1: CORE USER TABLES
-- ============================================================================

-- ────────────────────────────────────────────────────────────────────────────
-- TABLE: role
-- ────────────────────────────────────────────────────────────────────────────
-- All authenticated users read roles (for dropdown lists, permission checks)
-- Only SUPER_USER/SYSTEM_ADMIN can modify roles

-- NOTE: RLS already enabled in 0006_rls.sql
-- ALTER TABLE public.role ENABLE ROW LEVEL SECURITY;

-- DROP POLICY IF EXISTS "authenticated users can read roles" ON public.role;
-- CREATE POLICY "authenticated users can read roles"
-- ON public.role FOR SELECT TO authenticated
-- USING (true);

-- DROP POLICY IF EXISTS "super user manages roles" ON public.role;
-- CREATE POLICY "super user manages roles"
-- ON public.role FOR ALL TO authenticated
-- USING (public.current_app_role() IN ('SUPER_USER', 'SYSTEM_ADMIN'));

-- ────────────────────────────────────────────────────────────────────────────
-- TABLE: rolepermission
-- ────────────────────────────────────────────────────────────────────────────
-- All authenticated can read permissions (for permission checks)
-- Only SUPER_USER/SYSTEM_ADMIN can modify

-- DROP POLICY IF EXISTS "authenticated read role permissions" ON public.rolepermission;
-- CREATE POLICY "authenticated read role permissions"
-- ON public.rolepermission FOR SELECT TO authenticated
-- USING (true);

-- DROP POLICY IF EXISTS "super user manages role permissions" ON public.rolepermission;
-- CREATE POLICY "super user manages role permissions"
-- ON public.rolepermission FOR ALL TO authenticated
-- USING (public.current_app_role() IN ('SUPER_USER', 'SYSTEM_ADMIN'));

-- ────────────────────────────────────────────────────────────────────────────
-- TABLE: systemuser
-- ────────────────────────────────────────────────────────────────────────────
-- Users read own profile
-- Privileged roles read all users (for user management pages)
-- Only SUPER_USER/SYSTEM_ADMIN/ADMINISTRATOR can create/update/delete users

-- DROP POLICY IF EXISTS "users can read own profile" ON public.systemuser;
-- CREATE POLICY "users can read own profile"
-- ON public.systemuser FOR SELECT TO authenticated
-- USING (userid = auth.uid());

-- DROP POLICY IF EXISTS "privileged roles read all systemusers" ON public.systemuser;
-- CREATE POLICY "privileged roles read all systemusers"
-- ON public.systemuser FOR SELECT TO authenticated
-- USING (
--   public.current_app_role() IN (
--     'SUPER_USER', 'SYSTEM_ADMIN', 'ADMINISTRATOR', 'REGISTRAR', 'HEAD_TEACHER'
--   )
-- );

-- DROP POLICY IF EXISTS "admins can manage system users" ON public.systemuser;
-- DROP POLICY IF EXISTS "privileged roles manage systemusers" ON public.systemuser;
-- CREATE POLICY "privileged roles manage systemusers"
-- ON public.systemuser FOR ALL TO authenticated
-- USING (
--   public.current_app_role() IN (
--     'SUPER_USER', 'SYSTEM_ADMIN', 'ADMINISTRATOR'
--   )
-- );

-- ────────────────────────────────────────────────────────────────────────────
-- TABLE: staff
-- ────────────────────────────────────────────────────────────────────────────
-- Staff read own record
-- All roles (except GUARDIAN) read all staff
-- Only SUPER_USER/SYSTEM_ADMIN/ADMINISTRATOR/REGISTRAR can manage

-- DROP POLICY IF EXISTS "staff can read own record" ON public.staff;
-- CREATE POLICY "staff can read own record"
-- ON public.staff FOR SELECT TO authenticated
-- USING (userid = auth.uid());

-- DROP POLICY IF EXISTS "privileged roles read all staff" ON public.staff;
-- CREATE POLICY "privileged roles read all staff"
-- ON public.staff FOR SELECT TO authenticated
-- USING (
--   public.current_app_role() IN (
--     'SUPER_USER', 'SYSTEM_ADMIN', 'ADMINISTRATOR', 'REGISTRAR',
--     'HEAD_TEACHER', 'ACCOUNTANT', 'TEACHER'
--   )
-- );

-- DROP POLICY IF EXISTS "admins manage staff" ON public.staff;
-- CREATE POLICY "admins manage staff"
-- ON public.staff FOR ALL TO authenticated
-- USING (
--   public.current_app_role() IN (
--     'SUPER_USER', 'SYSTEM_ADMIN', 'ADMINISTRATOR', 'REGISTRAR'
--   )
-- );

-- ────────────────────────────────────────────────────────────────────────────
-- TABLE: guardian
-- ────────────────────────────────────────────────────────────────────────────
-- Guardians read own profile
-- All staff roles read all guardians (for communications, finance lookups)
-- Only SUPER_USER/SYSTEM_ADMIN/ADMINISTRATOR/REGISTRAR can manage

-- DROP POLICY IF EXISTS "guardian reads own profile" ON public.guardian;
-- CREATE POLICY "guardian reads own profile"
-- ON public.guardian FOR SELECT TO authenticated
-- USING (userid = auth.uid());

-- DROP POLICY IF EXISTS "privileged roles read all guardians" ON public.guardian;
-- CREATE POLICY "privileged roles read all guardians"
-- ON public.guardian FOR SELECT TO authenticated
-- USING (
--   public.current_app_role() IN (
--     'SUPER_USER', 'SYSTEM_ADMIN', 'ADMINISTRATOR', 'REGISTRAR',
--     'HEAD_TEACHER', 'TEACHER', 'ACCOUNTANT'
--   )
-- );

-- DROP POLICY IF EXISTS "admins manage guardians" ON public.guardian;
-- CREATE POLICY "admins manage guardians"
-- ON public.guardian FOR ALL TO authenticated
-- USING (
--   public.current_app_role() IN (
--     'SUPER_USER', 'SYSTEM_ADMIN', 'ADMINISTRATOR', 'REGISTRAR'
--   )
-- );

-- ────────────────────────────────────────────────────────────────────────────
-- TABLE: auditlog
-- ────────────────────────────────────────────────────────────────────────────
-- APPEND-ONLY TABLE — No UPDATE or DELETE policies
-- All authenticated can INSERT (audit service runs as the user)
-- Only SUPER_USER/SYSTEM_ADMIN can SELECT (audit trail viewer)

-- DROP POLICY IF EXISTS "authenticated users insert audit log" ON public.auditlog;
-- CREATE POLICY "authenticated users insert audit log"
-- ON public.auditlog FOR INSERT TO authenticated
-- WITH CHECK (true);

-- DROP POLICY IF EXISTS "super user reads audit log" ON public.auditlog;
-- CREATE POLICY "super user reads audit log"
-- ON public.auditlog FOR SELECT TO authenticated
-- USING (
--   public.current_app_role() IN ('SUPER_USER', 'SYSTEM_ADMIN')
-- );

-- ============================================================================
-- SECTION 2: ACADEMIC TABLES
-- ============================================================================

-- ────────────────────────────────────────────────────────────────────────────
-- TABLE: academicyear
-- ────────────────────────────────────────────────────────────────────────────
-- All authenticated read academic years
-- Privileged roles can create/update academic years

-- DROP POLICY IF EXISTS "authenticated users can read academic years" ON public.academicyear;
-- CREATE POLICY "authenticated users can read academic years"
-- ON public.academicyear FOR SELECT TO authenticated
-- USING (true);

-- DROP POLICY IF EXISTS "admins manage academic years" ON public.academicyear;
-- CREATE POLICY "admins manage academic years"
-- ON public.academicyear FOR ALL TO authenticated
-- USING (
--   public.current_app_role() IN (
--     'SUPER_USER', 'SYSTEM_ADMIN', 'ADMINISTRATOR', 'REGISTRAR', 'HEAD_TEACHER'
--   )
-- );

-- ────────────────────────────────────────────────────────────────────────────
-- TABLE: class
-- ────────────────────────────────────────────────────────────────────────────
-- All authenticated read classes
-- Only SUPER_USER/SYSTEM_ADMIN/ADMINISTRATOR/REGISTRAR can manage

-- DROP POLICY IF EXISTS "authenticated users can read classes" ON public.class;
-- CREATE POLICY "authenticated users can read classes"
-- ON public.class FOR SELECT TO authenticated
-- USING (true);

-- DROP POLICY IF EXISTS "admins manage classes" ON public.class;
-- CREATE POLICY "admins manage classes"
-- ON public.class FOR ALL TO authenticated
-- USING (
--   public.current_app_role() IN (
--     'SUPER_USER', 'SYSTEM_ADMIN', 'ADMINISTRATOR', 'REGISTRAR'
--   )
-- );

-- ────────────────────────────────────────────────────────────────────────────
-- TABLE: subject
-- ────────────────────────────────────────────────────────────────────────────
-- All authenticated read subjects
-- Privileged roles can manage subjects

-- DROP POLICY IF EXISTS "authenticated users can read subjects" ON public.subject;
-- CREATE POLICY "authenticated users can read subjects"
-- ON public.subject FOR SELECT TO authenticated
-- USING (true);

-- DROP POLICY IF EXISTS "admins manage subjects" ON public.subject;
-- CREATE POLICY "admins manage subjects"
-- ON public.subject FOR ALL TO authenticated
-- USING (
--   public.current_app_role() IN (
--     'SUPER_USER', 'SYSTEM_ADMIN', 'ADMINISTRATOR', 'REGISTRAR', 'HEAD_TEACHER'
--   )
-- );

-- ────────────────────────────────────────────────────────────────────────────
-- TABLE: classsubject (teaching assignments)
-- ────────────────────────────────────────────────────────────────────────────
-- Teachers read own assignments
-- All staff roles can read assignments (for cross-class coordination)
-- Only admins can create/update/delete assignments

-- DROP POLICY IF EXISTS "staff can read own assignments" ON public.classsubject;
-- DROP POLICY IF EXISTS "authenticated staff read class assignments" ON public.classsubject;
-- CREATE POLICY "authenticated staff read class assignments"
-- ON public.classsubject FOR SELECT TO authenticated
-- USING (
--   public.current_app_role() IN (
--     'SUPER_USER', 'SYSTEM_ADMIN', 'ADMINISTRATOR', 'REGISTRAR',
--     'TEACHER', 'HEAD_TEACHER', 'ACCOUNTANT'
--   )
--   OR EXISTS (
--     SELECT 1 FROM public.staff s
--     WHERE s.staffid = classsubject.staffid
--       AND s.userid  = auth.uid()
--   )
-- );

-- DROP POLICY IF EXISTS "admins manage class assignments" ON public.classsubject;
-- CREATE POLICY "admins manage class assignments"
-- ON public.classsubject FOR ALL TO authenticated
-- USING (
--   public.current_app_role() IN (
--     'SUPER_USER', 'SYSTEM_ADMIN', 'ADMINISTRATOR', 'REGISTRAR'
--   )
-- );

-- ============================================================================
-- SECTION 3: STUDENT TABLES
-- ============================================================================

-- ────────────────────────────────────────────────────────────────────────────
-- TABLE: student
-- ────────────────────────────────────────────────────────────────────────────
-- Guardians see only linked students
-- All staff read all students
-- Only SUPER_USER/SYSTEM_ADMIN/ADMINISTRATOR/REGISTRAR can manage

-- DROP POLICY IF EXISTS "guardians see linked students" ON public.student;
-- CREATE POLICY "guardians see linked students"
-- ON public.student FOR SELECT TO authenticated
-- USING (
--   EXISTS (
--     SELECT 1
--     FROM public.guardian g
--     JOIN public.studentguardian sg ON sg.guardianid = g.guardianid
--     WHERE g.userid = auth.uid()
--       AND sg.studentid = student.studentid
--   )
-- );

-- DROP POLICY IF EXISTS "staff read all students" ON public.student;
-- CREATE POLICY "staff read all students"
-- ON public.student FOR SELECT TO authenticated
-- USING (
--   public.current_app_role() IN (
--     'SUPER_USER', 'SYSTEM_ADMIN', 'ADMINISTRATOR', 'REGISTRAR',
--     'TEACHER', 'HEAD_TEACHER', 'ACCOUNTANT'
--   )
-- );

-- DROP POLICY IF EXISTS "admins manage students" ON public.student;
-- CREATE POLICY "admins manage students"
-- ON public.student FOR ALL TO authenticated
-- USING (
--   public.current_app_role() IN (
--     'SUPER_USER', 'SYSTEM_ADMIN', 'ADMINISTRATOR', 'REGISTRAR'
--   )
-- );

-- ────────────────────────────────────────────────────────────────────────────
-- TABLE: studentguardian
-- ────────────────────────────────────────────────────────────────────────────
-- Guardians read own links
-- All staff read guardian links (for cross-reference)
-- Only admins can create/update/delete links

-- DROP POLICY IF EXISTS "guardians can read own links" ON public.studentguardian;
-- CREATE POLICY "guardians can read own links"
-- ON public.studentguardian FOR SELECT TO authenticated
-- USING (
--   EXISTS (
--     SELECT 1 FROM public.guardian g
--     WHERE g.guardianid = studentguardian.guardianid
--       AND g.userid = auth.uid()
--   )
-- );

-- DROP POLICY IF EXISTS "staff read guardian links" ON public.studentguardian;
-- CREATE POLICY "staff read guardian links"
-- ON public.studentguardian FOR SELECT TO authenticated
-- USING (
--   public.current_app_role() IN (
--     'SUPER_USER', 'SYSTEM_ADMIN', 'ADMINISTRATOR', 'REGISTRAR',
--     'TEACHER', 'HEAD_TEACHER', 'ACCOUNTANT'
--   )
-- );

-- DROP POLICY IF EXISTS "admins manage guardian links" ON public.studentguardian;
-- CREATE POLICY "admins manage guardian links"
-- ON public.studentguardian FOR ALL TO authenticated
-- USING (
--   public.current_app_role() IN (
--     'SUPER_USER', 'SYSTEM_ADMIN', 'ADMINISTRATOR', 'REGISTRAR'
--   )
-- );

-- ────────────────────────────────────────────────────────────────────────────
-- TABLE: studentclasshistory
-- ────────────────────────────────────────────────────────────────────────────
-- Guardians see linked student history
-- All staff read class history
-- Only admins can manage class history

-- DROP POLICY IF EXISTS "guardians see linked student history" ON public.studentclasshistory;
-- CREATE POLICY "guardians see linked student history"
-- ON public.studentclasshistory FOR SELECT TO authenticated
-- USING (
--   EXISTS (
--     SELECT 1
--     FROM public.guardian g
--     JOIN public.studentguardian sg ON sg.guardianid = g.guardianid
--     WHERE g.userid = auth.uid()
--       AND sg.studentid = studentclasshistory.studentid
--   )
-- );

-- DROP POLICY IF EXISTS "staff read class history" ON public.studentclasshistory;
-- CREATE POLICY "staff read class history"
-- ON public.studentclasshistory FOR SELECT TO authenticated
-- USING (
--   public.current_app_role() IN (
--     'SUPER_USER', 'SYSTEM_ADMIN', 'ADMINISTRATOR', 'REGISTRAR',
--     'TEACHER', 'HEAD_TEACHER', 'ACCOUNTANT'
--   )
-- );

-- DROP POLICY IF EXISTS "admins manage class history" ON public.studentclasshistory;
-- CREATE POLICY "admins manage class history"
-- ON public.studentclasshistory FOR ALL TO authenticated
-- USING (
--   public.current_app_role() IN (
--     'SUPER_USER', 'SYSTEM_ADMIN', 'ADMINISTRATOR', 'REGISTRAR'
--   )
-- );

-- ============================================================================
-- SECTION 4: ASSESSMENT & GRADING TABLES
-- ============================================================================

-- ────────────────────────────────────────────────────────────────────────────
-- TABLE: assessment
-- ────────────────────────────────────────────────────────────────────────────
-- Teachers manage assessments for classes they teach
-- Privileged roles read all assessments

-- DROP POLICY IF EXISTS "teachers manage own assessments" ON public.assessment;
-- CREATE POLICY "teachers manage own assessments"
-- ON public.assessment FOR ALL TO authenticated
-- USING (
--   EXISTS (
--     SELECT 1
--     FROM public.classsubject cs
--     JOIN public.staff s ON s.staffid = cs.staffid
--     WHERE cs.classsubjectid = assessment.classsubjectid
--       AND s.userid = auth.uid()
--   )
-- );

-- DROP POLICY IF EXISTS "privileged roles read assessments" ON public.assessment;
-- CREATE POLICY "privileged roles read assessments"
-- ON public.assessment FOR SELECT TO authenticated
-- USING (
--   public.current_app_role() IN (
--     'SUPER_USER', 'SYSTEM_ADMIN', 'ADMINISTRATOR', 'REGISTRAR', 'HEAD_TEACHER'
--   )
-- );

-- ────────────────────────────────────────────────────────────────────────────
-- TABLE: grade
-- ────────────────────────────────────────────────────────────────────────────
-- Teachers manage grades for their own assessments
-- Privileged roles read all grades
-- Guardians read grades for linked students

-- DROP POLICY IF EXISTS "teachers manage grades" ON public.grade;
-- CREATE POLICY "teachers manage grades"
-- ON public.grade FOR ALL TO authenticated
-- USING (
--   EXISTS (
--     SELECT 1
--     FROM public.assessment a
--     JOIN public.classsubject cs ON cs.classsubjectid = a.classsubjectid
--     JOIN public.staff s ON s.staffid = cs.staffid
--     WHERE a.assessmentid = grade.assessmentid
--       AND s.userid = auth.uid()
--   )
-- );

-- DROP POLICY IF EXISTS "privileged roles read grades" ON public.grade;
-- CREATE POLICY "privileged roles read grades"
-- ON public.grade FOR SELECT TO authenticated
-- USING (
--   public.current_app_role() IN (
--     'SUPER_USER', 'SYSTEM_ADMIN', 'ADMINISTRATOR', 'HEAD_TEACHER'
--   )
-- );

-- DROP POLICY IF EXISTS "guardians read grades for their students" ON public.grade;
-- CREATE POLICY "guardians read grades for their students"
-- ON public.grade FOR SELECT TO authenticated
-- USING (
--   EXISTS (
--     SELECT 1
--     FROM public.guardian g
--     JOIN public.studentguardian sg ON sg.guardianid = g.guardianid
--     WHERE g.userid = auth.uid()
--       AND sg.studentid = grade.studentid
--   )
-- );

-- ────────────────────────────────────────────────────────────────────────────
-- TABLE: progressionreview
-- ────────────────────────────────────────────────────────────────────────────
-- HEAD_TEACHER and admins can create/approve progression decisions
-- Guardians CANNOT see progression reviews (sensitive)

-- DROP POLICY IF EXISTS "head teacher manages progression reviews" ON public.progressionreview;
-- CREATE POLICY "head teacher manages progression reviews"
-- ON public.progressionreview FOR ALL TO authenticated
-- USING (
--   public.current_app_role() IN (
--     'SUPER_USER', 'SYSTEM_ADMIN', 'ADMINISTRATOR', 'REGISTRAR', 'HEAD_TEACHER'
--   )
-- );

-- ────────────────────────────────────────────────────────────────────────────
-- TABLE: weedingreview
-- ────────────────────────────────────────────────────────────────────────────
-- HEAD_TEACHER and admins can create/approve weeding decisions
-- Guardians CANNOT see weeding reviews (sensitive)

-- DROP POLICY IF EXISTS "head teacher manages weeding reviews" ON public.weedingreview;
-- CREATE POLICY "head teacher manages weeding reviews"
-- ON public.weedingreview FOR ALL TO authenticated
-- USING (
--   public.current_app_role() IN (
--     'SUPER_USER', 'SYSTEM_ADMIN', 'ADMINISTRATOR', 'REGISTRAR', 'HEAD_TEACHER'
--   )
-- );

-- ============================================================================
-- SECTION 5: FINANCE TABLES
-- ============================================================================

-- ────────────────────────────────────────────────────────────────────────────
-- TABLE: feestructure
-- ────────────────────────────────────────────────────────────────────────────
-- ACCOUNTANT and admins manage fee structures
-- Other staff roles can read fee structures

-- DROP POLICY IF EXISTS "accountant can manage fee structures" ON public.feestructure;
-- CREATE POLICY "accountant can manage fee structures"
-- ON public.feestructure FOR ALL TO authenticated
-- USING (
--   public.current_app_role() IN ('ACCOUNTANT', 'SYSTEM_ADMIN', 'SUPER_USER')
-- );

-- DROP POLICY IF EXISTS "staff and head teacher can read fee structures" ON public.feestructure;
-- CREATE POLICY "staff and head teacher can read fee structures"
-- ON public.feestructure FOR SELECT TO authenticated
-- USING (
--   public.current_app_role() IN (
--     'REGISTRAR', 'TEACHER', 'HEAD_TEACHER', 'ADMINISTRATOR'
--   )
-- );

-- ────────────────────────────────────────────────────────────────────────────
-- TABLE: payment
-- ────────────────────────────────────────────────────────────────────────────
-- ACCOUNTANT and admins manage payments
-- HEAD_TEACHER reads all payments (oversight)
-- Guardians read payments for linked students

-- DROP POLICY IF EXISTS "accountant can manage payments" ON public.payment;
-- CREATE POLICY "accountant can manage payments"
-- ON public.payment FOR ALL TO authenticated
-- USING (
--   public.current_app_role() IN ('ACCOUNTANT', 'SYSTEM_ADMIN', 'SUPER_USER')
-- );

-- DROP POLICY IF EXISTS "head teacher and director can read payments" ON public.payment;
-- CREATE POLICY "head teacher and director can read payments"
-- ON public.payment FOR SELECT TO authenticated
-- USING (
--   public.current_app_role() IN ('HEAD_TEACHER', 'ADMINISTRATOR')
-- );

-- DROP POLICY IF EXISTS "guardians see linked student payments" ON public.payment;
-- CREATE POLICY "guardians see linked student payments"
-- ON public.payment FOR SELECT TO authenticated
-- USING (
--   EXISTS (
--     SELECT 1
--     FROM public.guardian g
--     JOIN public.studentguardian sg ON sg.guardianid = g.guardianid
--     WHERE g.userid = auth.uid()
--       AND sg.studentid = payment.studentid
--   )
-- );

-- ────────────────────────────────────────────────────────────────────────────
-- TABLE: financialadjustment
-- ────────────────────────────────────────────────────────────────────────────
-- ACCOUNTANT and admins manage adjustments
-- HEAD_TEACHER reads adjustments (oversight)

-- DROP POLICY IF EXISTS "accountant can manage adjustments" ON public.financialadjustment;
-- CREATE POLICY "accountant can manage adjustments"
-- ON public.financialadjustment FOR ALL TO authenticated
-- USING (
--   public.current_app_role() IN ('ACCOUNTANT', 'SYSTEM_ADMIN', 'SUPER_USER')
-- );

-- DROP POLICY IF EXISTS "head teacher and director can read adjustments" ON public.financialadjustment;
-- CREATE POLICY "head teacher and director can read adjustments"
-- ON public.financialadjustment FOR SELECT TO authenticated
-- USING (
--   public.current_app_role() IN ('HEAD_TEACHER', 'ADMINISTRATOR')
-- );

-- ============================================================================
-- SECTION 6: COMMUNICATION TABLES
-- ============================================================================

-- ────────────────────────────────────────────────────────────────────────────
-- TABLE: notification
-- ────────────────────────────────────────────────────────────────────────────
-- Staff manage notifications they send
-- Privileged roles read all notifications
-- Guardians read + mark read their own notifications

-- DROP POLICY IF EXISTS "staff can manage own notifications" ON public.notification;
-- CREATE POLICY "staff can manage own notifications"
-- ON public.notification FOR ALL TO authenticated
-- USING (
--   EXISTS (
--     SELECT 1 FROM public.staff s
--     WHERE s.staffid = notification.sentby
--       AND s.userid = auth.uid()
--   )
-- );

-- DROP POLICY IF EXISTS "privileged roles can read all notifications" ON public.notification;
-- CREATE POLICY "privileged roles can read all notifications"
-- ON public.notification FOR SELECT TO authenticated
-- USING (
--   public.current_app_role() IN (
--     'HEAD_TEACHER', 'SYSTEM_ADMIN', 'SUPER_USER', 'ADMINISTRATOR', 'REGISTRAR'
--   )
-- );

-- DROP POLICY IF EXISTS "guardian reads own notifications" ON public.notification;
-- CREATE POLICY "guardian reads own notifications"
-- ON public.notification FOR SELECT TO authenticated
-- USING (
--   EXISTS (
--     SELECT 1 FROM public.guardian g
--     WHERE g.guardianid = notification.guardianid
--       AND g.userid = auth.uid()
--   )
-- );

-- DROP POLICY IF EXISTS "guardian can mark own notification read" ON public.notification;
-- CREATE POLICY "guardian can mark own notification read"
-- ON public.notification FOR UPDATE TO authenticated
-- USING (
--   EXISTS (
--     SELECT 1 FROM public.guardian g
--     WHERE g.guardianid = notification.guardianid
--       AND g.userid = auth.uid()
--   )
-- )
-- WITH CHECK (
--   EXISTS (
--     SELECT 1 FROM public.guardian g
--     WHERE g.guardianid = notification.guardianid
--       AND g.userid = auth.uid()
--   )
-- );

-- ────────────────────────────────────────────────────────────────────────────
-- TABLE: teachercomment
-- ────────────────────────────────────────────────────────────────────────────
-- Teachers manage their own comments
-- Privileged roles read all comments
-- Guardians read comments for linked students

-- DROP POLICY IF EXISTS "teacher can manage own comments" ON public.teachercomment;
-- CREATE POLICY "teacher can manage own comments"
-- ON public.teachercomment FOR ALL TO authenticated
-- USING (
--   EXISTS (
--     SELECT 1 FROM public.staff s
--     WHERE s.staffid = teachercomment.staffid
--       AND s.userid = auth.uid()
--   )
-- );

-- DROP POLICY IF EXISTS "privileged roles can read all comments" ON public.teachercomment;
-- CREATE POLICY "privileged roles can read all comments"
-- ON public.teachercomment FOR SELECT TO authenticated
-- USING (
--   public.current_app_role() IN (
--     'HEAD_TEACHER', 'SYSTEM_ADMIN', 'SUPER_USER', 'ADMINISTRATOR', 'REGISTRAR'
--   )
-- );

-- DROP POLICY IF EXISTS "guardians see linked student comments" ON public.teachercomment;
-- CREATE POLICY "guardians see linked student comments"
-- ON public.teachercomment FOR SELECT TO authenticated
-- USING (
--   EXISTS (
--     SELECT 1
--     FROM public.guardian g
--     JOIN public.studentguardian sg ON sg.guardianid = g.guardianid
--     WHERE g.userid = auth.uid()
--       AND sg.studentid = teachercomment.studentid
--   )
-- );

-- ────────────────────────────────────────────────────────────────────────────
-- TABLE: calendarevent
-- ────────────────────────────────────────────────────────────────────────────
-- All authenticated read calendar events
-- Staff manage events they created
-- Privileged roles manage all events

-- DROP POLICY IF EXISTS "authenticated users can read calendar events" ON public.calendarevent;
-- CREATE POLICY "authenticated users can read calendar events"
-- ON public.calendarevent FOR SELECT TO authenticated
-- USING (true);

-- DROP POLICY IF EXISTS "staff can manage own events" ON public.calendarevent;
-- CREATE POLICY "staff can manage own events"
-- ON public.calendarevent FOR ALL TO authenticated
-- USING (
--   EXISTS (
--     SELECT 1 FROM public.staff s
--     WHERE s.staffid = calendarevent.createdby
--       AND s.userid = auth.uid()
--   )
-- );

-- DROP POLICY IF EXISTS "privileged roles can manage all events" ON public.calendarevent;
-- CREATE POLICY "privileged roles can manage all events"
-- ON public.calendarevent FOR ALL TO authenticated
-- USING (
--   public.current_app_role() IN (
--     'HEAD_TEACHER', 'SYSTEM_ADMIN', 'SUPER_USER', 'ADMINISTRATOR'
--   )
-- );

-- ============================================================================
-- END OF CONSOLIDATED RLS BASELINE
-- ============================================================================
-- All policies documented above are ALREADY APPLIED via migrations 0001-0017.
-- This file serves as canonical reference documentation.
--
-- To verify current policies in your database, run:
--   SELECT schemaname, tablename, policyname, cmd, roles
--   FROM pg_policies
--   WHERE schemaname = 'public'
--   ORDER BY tablename, policyname;
-- ============================================================================;
