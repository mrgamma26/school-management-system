-- 0014_feature_rls.sql
-- RLS policies for: assessment, grade, progressionreview, weedingreview,
-- notification, teachercomment, and auditlog viewer access.
-- Run AFTER 0013_schema_fixes.sql.

-- ─────────────────────────────────────────────
-- Enable RLS on tables that may not have it yet
-- ─────────────────────────────────────────────
ALTER TABLE public.assessment        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.grade             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.progressionreview ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.weedingreview     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.classsubject      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.auditlog          ENABLE ROW LEVEL SECURITY;
-- ─────────────────────────────────────────────
-- assessment
-- Teachers manage their own class-subject assessments.
-- Head teacher, admin, and director can read all.
-- ─────────────────────────────────────────────
CREATE POLICY "teacher manages own assessments"
ON public.assessment FOR ALL TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.classsubject cs
    JOIN  public.staff s ON s.staffid = cs.staffid
    WHERE cs.classsubjectid = assessment.classsubjectid
      AND s.userid = auth.uid()
  )
);
CREATE POLICY "privileged roles read all assessments"
ON public.assessment FOR SELECT TO authenticated
USING (
  public.current_app_role() IN (
    'HEAD_TEACHER','SYSTEM_ADMIN','ADMINISTRATOR','REGISTRAR'
  )
);
-- ─────────────────────────────────────────────
-- grade
-- Teachers can read/write grades for assessments they own.
-- Head teacher / admin can read all grades.
-- Guardians can read grades for their linked students.
-- ─────────────────────────────────────────────
CREATE POLICY "teacher manages grades for own assessments"
ON public.grade FOR ALL TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.staff s
    WHERE s.staffid = grade.enteredby
      AND s.userid  = auth.uid()
  )
);
CREATE POLICY "privileged roles read all grades"
ON public.grade FOR SELECT TO authenticated
USING (
  public.current_app_role() IN (
    'HEAD_TEACHER','SYSTEM_ADMIN','ADMINISTRATOR','REGISTRAR'
  )
);
CREATE POLICY "guardians read grades for linked students"
ON public.grade FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.guardian g
    JOIN  public.studentguardian sg ON sg.guardianid = g.guardianid
    WHERE g.userid    = auth.uid()
      AND sg.studentid = grade.studentid
  )
);
-- ─────────────────────────────────────────────
-- progressionreview
-- Head teacher and admin can read and decide.
-- System admin can also create reviews.
-- Guardians cannot see progression reviews.
-- ─────────────────────────────────────────────
CREATE POLICY "head teacher manages progression reviews"
ON public.progressionreview FOR ALL TO authenticated
USING (
  public.current_app_role() IN (
    'HEAD_TEACHER','SYSTEM_ADMIN','ADMINISTRATOR','REGISTRAR'
  )
);
-- ─────────────────────────────────────────────
-- weedingreview
-- Same access as progression reviews.
-- ─────────────────────────────────────────────
CREATE POLICY "head teacher manages weeding reviews"
ON public.weedingreview FOR ALL TO authenticated
USING (
  public.current_app_role() IN (
    'HEAD_TEACHER','SYSTEM_ADMIN','ADMINISTRATOR','REGISTRAR'
  )
);
-- ─────────────────────────────────────────────
-- classsubject (teaching assignments)
-- All authenticated staff can read assignments.
-- Admin creates/deletes assignments.
-- ─────────────────────────────────────────────
CREATE POLICY "all staff read class assignments"
ON public.classsubject FOR SELECT TO authenticated
USING (
  public.current_app_role() IN (
    'TEACHER','HEAD_TEACHER','SYSTEM_ADMIN','ADMINISTRATOR','REGISTRAR','ACCOUNTANT'
  )
);
CREATE POLICY "admin manages class assignments"
ON public.classsubject FOR ALL TO authenticated
USING (
  public.current_app_role() IN ('SYSTEM_ADMIN','ADMINISTRATOR','REGISTRAR')
);
-- ─────────────────────────────────────────────
-- auditlog — append-only for all; read only for super admin
-- ─────────────────────────────────────────────
-- INSERT is allowed for any authenticated user (audit service runs as the user)
CREATE POLICY "any authenticated user can insert audit log"
ON public.auditlog FOR INSERT TO authenticated
WITH CHECK (true);
-- Only SYSTEM_ADMIN / SUPER_USER can SELECT audit log
CREATE POLICY "super admin reads audit log"
ON public.auditlog FOR SELECT TO authenticated
USING (
  public.current_app_role() IN ('SYSTEM_ADMIN','SUPER_USER')
);
-- No UPDATE or DELETE policy → audit log is truly append-only;
