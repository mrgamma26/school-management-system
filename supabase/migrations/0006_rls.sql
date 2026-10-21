-- 0006_rls.sql
-- Row Level Security policies for all application tables.
-- Run AFTER 0005_functions.sql.

-- ─────────────────────────────────────────────
-- Enable RLS on every application table
-- ─────────────────────────────────────────────
ALTER TABLE public.role              ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rolepermission    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.systemuser        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.guardian          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.auditlog          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.academicyear      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.class             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subject           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.classsubject      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.student           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.studentguardian   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.studentclasshistory ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assessment        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.grade             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.progressionreview ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.weedingreview     ENABLE ROW LEVEL SECURITY;
-- ─────────────────────────────────────────────
-- role table
-- ─────────────────────────────────────────────
CREATE POLICY "authenticated users can read roles"
ON public.role FOR SELECT TO authenticated
USING (true);
CREATE POLICY "admins can manage roles"
ON public.role FOR ALL TO authenticated
USING (public.current_app_role() = 'SYSTEM_ADMIN');
-- ─────────────────────────────────────────────
-- rolepermission
-- ─────────────────────────────────────────────
CREATE POLICY "admins can manage role permissions"
ON public.rolepermission FOR ALL TO authenticated
USING (public.current_app_role() = 'SYSTEM_ADMIN');
-- ─────────────────────────────────────────────
-- systemuser
-- ─────────────────────────────────────────────
CREATE POLICY "users can read own profile"
ON public.systemuser FOR SELECT TO authenticated
USING (userid = auth.uid());
CREATE POLICY "admins and registrars can read all users"
ON public.systemuser FOR SELECT TO authenticated
USING (public.current_app_role() IN ('SYSTEM_ADMIN', 'REGISTRAR'));
CREATE POLICY "admins can manage system users"
ON public.systemuser FOR ALL TO authenticated
USING (public.current_app_role() = 'SYSTEM_ADMIN');
-- ─────────────────────────────────────────────
-- staff
-- ─────────────────────────────────────────────
CREATE POLICY "staff can read own record"
ON public.staff FOR SELECT TO authenticated
USING (userid = auth.uid());
CREATE POLICY "privileged roles can read all staff"
ON public.staff FOR SELECT TO authenticated
USING (
  public.current_app_role() IN (
    'SYSTEM_ADMIN', 'REGISTRAR', 'HEAD_TEACHER', 'ICA_DIRECTOR'
  )
);
CREATE POLICY "admins and registrars can manage staff"
ON public.staff FOR ALL TO authenticated
USING (public.current_app_role() IN ('SYSTEM_ADMIN', 'REGISTRAR'));
-- ─────────────────────────────────────────────
-- guardian
-- ─────────────────────────────────────────────
CREATE POLICY "guardian reads own profile"
ON public.guardian FOR SELECT TO authenticated
USING (userid = auth.uid());
CREATE POLICY "privileged roles can read guardians"
ON public.guardian FOR SELECT TO authenticated
USING (
  public.current_app_role() IN (
    'SYSTEM_ADMIN', 'REGISTRAR', 'HEAD_TEACHER'
  )
);
CREATE POLICY "admins and registrars can manage guardians"
ON public.guardian FOR ALL TO authenticated
USING (public.current_app_role() IN ('SYSTEM_ADMIN', 'REGISTRAR'));
-- ─────────────────────────────────────────────
-- auditlog  (append-only; no DELETE/UPDATE allowed)
-- ─────────────────────────────────────────────
CREATE POLICY "system admin can read audit log"
ON public.auditlog FOR SELECT TO authenticated
USING (public.current_app_role() = 'SYSTEM_ADMIN');
CREATE POLICY "authenticated users can insert audit records"
ON public.auditlog FOR INSERT TO authenticated
WITH CHECK (userid = auth.uid());
-- ─────────────────────────────────────────────
-- academicyear
-- ─────────────────────────────────────────────
CREATE POLICY "authenticated users can read academic years"
ON public.academicyear FOR SELECT TO authenticated
USING (true);
CREATE POLICY "admins and registrars can manage academic years"
ON public.academicyear FOR ALL TO authenticated
USING (public.current_app_role() IN ('SYSTEM_ADMIN', 'REGISTRAR', 'HEAD_TEACHER'));
-- ─────────────────────────────────────────────
-- class
-- ─────────────────────────────────────────────
CREATE POLICY "authenticated users can read classes"
ON public.class FOR SELECT TO authenticated
USING (true);
CREATE POLICY "admins and registrars can manage classes"
ON public.class FOR ALL TO authenticated
USING (public.current_app_role() IN ('SYSTEM_ADMIN', 'REGISTRAR'));
-- ─────────────────────────────────────────────
-- subject
-- ─────────────────────────────────────────────
CREATE POLICY "authenticated users can read subjects"
ON public.subject FOR SELECT TO authenticated
USING (true);
CREATE POLICY "admins can manage subjects"
ON public.subject FOR ALL TO authenticated
USING (public.current_app_role() IN ('SYSTEM_ADMIN', 'REGISTRAR', 'HEAD_TEACHER'));
-- ─────────────────────────────────────────────
-- classsubject
-- ─────────────────────────────────────────────
CREATE POLICY "staff can read own assignments"
ON public.classsubject FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.staff s
    WHERE s.staffid = classsubject.staffid
      AND s.userid = auth.uid()
  )
);
CREATE POLICY "privileged roles can read all assignments"
ON public.classsubject FOR SELECT TO authenticated
USING (
  public.current_app_role() IN (
    'SYSTEM_ADMIN', 'REGISTRAR', 'HEAD_TEACHER', 'ICA_DIRECTOR'
  )
);
CREATE POLICY "admins and registrars can manage assignments"
ON public.classsubject FOR ALL TO authenticated
USING (public.current_app_role() IN ('SYSTEM_ADMIN', 'REGISTRAR'));
-- ─────────────────────────────────────────────
-- student
-- ─────────────────────────────────────────────
CREATE POLICY "guardians see linked students"
ON public.student FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.guardian g
    JOIN public.studentguardian sg ON sg.guardianid = g.guardianid
    WHERE g.userid = auth.uid()
      AND sg.studentid = student.studentid
  )
);
CREATE POLICY "staff can read all students"
ON public.student FOR SELECT TO authenticated
USING (
  public.current_app_role() IN (
    'SYSTEM_ADMIN', 'REGISTRAR', 'TEACHER',
    'HEAD_TEACHER', 'ICA_DIRECTOR'
  )
);
CREATE POLICY "registrars can manage students"
ON public.student FOR ALL TO authenticated
USING (public.current_app_role() IN ('SYSTEM_ADMIN', 'REGISTRAR'));
-- ─────────────────────────────────────────────
-- studentguardian
-- ─────────────────────────────────────────────
CREATE POLICY "registrars can manage guardian links"
ON public.studentguardian FOR ALL TO authenticated
USING (public.current_app_role() IN ('SYSTEM_ADMIN', 'REGISTRAR'));
CREATE POLICY "guardians can read own links"
ON public.studentguardian FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.guardian g
    WHERE g.guardianid = studentguardian.guardianid
      AND g.userid = auth.uid()
  )
);
-- ─────────────────────────────────────────────
-- studentclasshistory
-- ─────────────────────────────────────────────
CREATE POLICY "registrars can manage class history"
ON public.studentclasshistory FOR ALL TO authenticated
USING (public.current_app_role() IN ('SYSTEM_ADMIN', 'REGISTRAR'));
CREATE POLICY "staff can read class history"
ON public.studentclasshistory FOR SELECT TO authenticated
USING (
  public.current_app_role() IN (
    'SYSTEM_ADMIN', 'REGISTRAR', 'TEACHER', 'HEAD_TEACHER', 'ICA_DIRECTOR'
  )
);
CREATE POLICY "guardians see linked student history"
ON public.studentclasshistory FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.guardian g
    JOIN public.studentguardian sg ON sg.guardianid = g.guardianid
    WHERE g.userid = auth.uid()
      AND sg.studentid = studentclasshistory.studentid
  )
);
-- ─────────────────────────────────────────────
-- assessment
-- ─────────────────────────────────────────────
CREATE POLICY "teachers can manage own assessments"
ON public.assessment FOR ALL TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.classsubject cs
    JOIN public.staff s ON s.staffid = cs.staffid
    WHERE cs.classsubjectid = assessment.classsubjectid
      AND s.userid = auth.uid()
  )
);
CREATE POLICY "privileged roles can read all assessments"
ON public.assessment FOR SELECT TO authenticated
USING (
  public.current_app_role() IN (
    'SYSTEM_ADMIN', 'REGISTRAR', 'HEAD_TEACHER', 'ICA_DIRECTOR'
  )
);
-- ─────────────────────────────────────────────
-- grade
-- ─────────────────────────────────────────────
CREATE POLICY "teachers can manage grades for own assessments"
ON public.grade FOR ALL TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.assessment a
    JOIN public.classsubject cs ON cs.classsubjectid = a.classsubjectid
    JOIN public.staff s ON s.staffid = cs.staffid
    WHERE a.assessmentid = grade.assessmentid
      AND s.userid = auth.uid()
  )
);
CREATE POLICY "privileged roles can read all grades"
ON public.grade FOR SELECT TO authenticated
USING (
  public.current_app_role() IN (
    'SYSTEM_ADMIN', 'HEAD_TEACHER', 'ICA_DIRECTOR'
  )
);
CREATE POLICY "guardians see grades for linked students"
ON public.grade FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.guardian g
    JOIN public.studentguardian sg ON sg.guardianid = g.guardianid
    WHERE g.userid = auth.uid()
      AND sg.studentid = grade.studentid
  )
);
-- ─────────────────────────────────────────────
-- progressionreview
-- ─────────────────────────────────────────────
CREATE POLICY "head teacher can manage progression reviews"
ON public.progressionreview FOR ALL TO authenticated
USING (
  public.current_app_role() IN ('HEAD_TEACHER', 'SYSTEM_ADMIN', 'ICA_DIRECTOR')
);
CREATE POLICY "registrars can read progression reviews"
ON public.progressionreview FOR SELECT TO authenticated
USING (public.current_app_role() = 'REGISTRAR');
-- ─────────────────────────────────────────────
-- weedingreview
-- ─────────────────────────────────────────────
CREATE POLICY "head teacher can manage weeding reviews"
ON public.weedingreview FOR ALL TO authenticated
USING (
  public.current_app_role() IN ('HEAD_TEACHER', 'SYSTEM_ADMIN', 'ICA_DIRECTOR')
);
CREATE POLICY "registrars can read weeding reviews"
ON public.weedingreview FOR SELECT TO authenticated
USING (public.current_app_role() = 'REGISTRAR');
