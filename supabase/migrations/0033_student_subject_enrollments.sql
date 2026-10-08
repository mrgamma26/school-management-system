BEGIN;

CREATE TABLE IF NOT EXISTS public.studentsubject (
  studentsubjectid uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  studentid uuid NOT NULL REFERENCES public.student(studentid) ON DELETE CASCADE,
  classsubjectid uuid NOT NULL REFERENCES public.classsubject(classsubjectid) ON DELETE CASCADE,
  createdat timestamptz NOT NULL DEFAULT now(),
  UNIQUE (studentid, classsubjectid)
);

CREATE INDEX IF NOT EXISTS idx_studentsubject_studentid
  ON public.studentsubject(studentid);
CREATE INDEX IF NOT EXISTS idx_studentsubject_classsubjectid
  ON public.studentsubject(classsubjectid);

ALTER TABLE public.studentsubject ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "admins manage student subjects" ON public.studentsubject;
DROP POLICY IF EXISTS "teachers read assigned student subjects" ON public.studentsubject;

CREATE POLICY "admins manage student subjects"
ON public.studentsubject FOR ALL TO authenticated
USING ((SELECT public.current_app_role()) IN (
  'SUPER_USER', 'SYSTEM_ADMIN', 'ADMINISTRATOR', 'ADMIN', 'HEAD_TEACHER'
))
WITH CHECK ((SELECT public.current_app_role()) IN (
  'SUPER_USER', 'SYSTEM_ADMIN', 'ADMINISTRATOR', 'ADMIN', 'HEAD_TEACHER'
));

CREATE POLICY "teachers read assigned student subjects"
ON public.studentsubject FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.classsubject assignment
    JOIN public.staff staff_member ON staff_member.staffid = assignment.staffid
    WHERE assignment.classsubjectid = studentsubject.classsubjectid
      AND staff_member.userid = (SELECT auth.uid())
  )
);

NOTIFY pgrst, 'reload schema';
COMMIT;
