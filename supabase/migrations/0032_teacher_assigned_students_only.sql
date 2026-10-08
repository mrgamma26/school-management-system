-- Teachers may read only students actively enrolled in a class and academic
-- year where that teacher has a classsubject assignment. Privileged school
-- roles and guardians retain their existing student access.
BEGIN;

-- This security-definer helper avoids RLS recursion while keeping the
-- assignment lookup indexed and scoped to the signed-in teacher.
CREATE OR REPLACE FUNCTION public.teacher_can_read_student(
  target_student_id uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.staff AS staff_member
    JOIN public.classsubject AS assignment
      ON assignment.staffid = staff_member.staffid
    JOIN public.studentclasshistory AS enrollment
      ON enrollment.classid = assignment.classid
     AND enrollment.academicyearid = assignment.academicyearid
    WHERE staff_member.userid = (SELECT auth.uid())
      AND enrollment.studentid = target_student_id
      AND enrollment.enrollmentdate <= CURRENT_DATE
      AND (enrollment.enddate IS NULL OR enrollment.enddate >= CURRENT_DATE)
  );
$$;

REVOKE ALL ON FUNCTION public.teacher_can_read_student(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.teacher_can_read_student(uuid) TO authenticated;

-- Support the exact joins used by the RLS helper.
CREATE INDEX IF NOT EXISTS idx_classsubject_teacher_class_year
  ON public.classsubject(staffid, classid, academicyearid);
CREATE INDEX IF NOT EXISTS idx_studentclasshistory_class_year_student_active
  ON public.studentclasshistory(classid, academicyearid, studentid)
  WHERE enddate IS NULL;

ALTER TABLE public.student ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "staff can read all students" ON public.student;
DROP POLICY IF EXISTS "staff read all students" ON public.student;
DROP POLICY IF EXISTS "privileged roles read all students" ON public.student;
DROP POLICY IF EXISTS "teachers read assigned subject students" ON public.student;

CREATE POLICY "privileged roles read all students"
ON public.student FOR SELECT TO authenticated
USING (
  (SELECT public.current_app_role()) IN (
    'SUPER_USER', 'SYSTEM_ADMIN', 'ADMINISTRATOR', 'HEAD_TEACHER', 'ACCOUNTANT'
  )
);

CREATE POLICY "teachers read assigned subject students"
ON public.student FOR SELECT TO authenticated
USING (
  (SELECT public.current_app_role()) = 'TEACHER'
  AND (SELECT public.teacher_can_read_student(studentid))
);

NOTIFY pgrst, 'reload schema';
COMMIT;
