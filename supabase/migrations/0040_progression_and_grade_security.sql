-- Enforce the security edge cases at the database boundary. UI route guards
-- are not sufficient because authenticated users can call PostgREST directly.
BEGIN;
DROP POLICY IF EXISTS "teacher manages grades for own assessments" ON public.grade;
CREATE POLICY "teacher manages grades for assigned assessments"
ON public.grade FOR ALL TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.assessment a
    JOIN public.classsubject cs ON cs.classsubjectid = a.classsubjectid
    JOIN public.staff s ON s.staffid = cs.staffid
    WHERE a.assessmentid = grade.assessmentid
      AND s.userid = auth.uid()
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
      AND s.userid = auth.uid()
      AND grade.enteredby = s.staffid
  )
);
DROP POLICY IF EXISTS "head teacher manages progression reviews"
  ON public.progressionreview;
DROP POLICY IF EXISTS "privileged roles view progression reviews"
  ON public.progressionreview;
CREATE POLICY "head teacher manages progression reviews"
ON public.progressionreview FOR ALL TO authenticated
USING (public.current_app_role() = 'HEAD_TEACHER')
WITH CHECK (public.current_app_role() = 'HEAD_TEACHER');
CREATE POLICY "privileged roles view progression reviews"
ON public.progressionreview FOR SELECT TO authenticated
USING (
  public.current_app_role() IN (
    'SUPER_USER', 'SYSTEM_ADMIN', 'ADMINISTRATOR'
  )
);
NOTIFY pgrst, 'reload schema';
COMMIT;
