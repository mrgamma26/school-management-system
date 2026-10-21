-- 0004_indexes.sql
-- Performance and uniqueness indexes.
-- Run AFTER 0002_tables.sql.

-- systemuser
CREATE INDEX IF NOT EXISTS idx_systemuser_roleid
  ON public.systemuser(roleid);
-- staff
CREATE INDEX IF NOT EXISTS idx_staff_userid
  ON public.staff(userid);
-- guardian
CREATE INDEX IF NOT EXISTS idx_guardian_userid
  ON public.guardian(userid);
-- studentguardian
CREATE INDEX IF NOT EXISTS idx_studentguardian_guardianid
  ON public.studentguardian(guardianid);
CREATE INDEX IF NOT EXISTS idx_studentguardian_studentid
  ON public.studentguardian(studentid);
-- studentclasshistory
CREATE INDEX IF NOT EXISTS idx_studentclasshistory_studentid
  ON public.studentclasshistory(studentid);
CREATE INDEX IF NOT EXISTS idx_studentclasshistory_academicyearid
  ON public.studentclasshistory(academicyearid);
-- classsubject
CREATE INDEX IF NOT EXISTS idx_classsubject_staffid
  ON public.classsubject(staffid);
CREATE INDEX IF NOT EXISTS idx_classsubject_academicyearid
  ON public.classsubject(academicyearid);
-- assessment
CREATE INDEX IF NOT EXISTS idx_assessment_classsubjectid
  ON public.assessment(classsubjectid);
-- grade
CREATE INDEX IF NOT EXISTS idx_grade_studentid
  ON public.grade(studentid);
CREATE INDEX IF NOT EXISTS idx_grade_assessmentid
  ON public.grade(assessmentid);
CREATE INDEX IF NOT EXISTS idx_grade_enteredby
  ON public.grade(enteredby);
-- progressionreview
CREATE INDEX IF NOT EXISTS idx_progressionreview_studentid
  ON public.progressionreview(studentid);
CREATE INDEX IF NOT EXISTS idx_progressionreview_academicyearid
  ON public.progressionreview(academicyearid);
-- weedingreview
CREATE INDEX IF NOT EXISTS idx_weedingreview_studentid
  ON public.weedingreview(studentid);
-- auditlog
CREATE INDEX IF NOT EXISTS idx_auditlog_userid
  ON public.auditlog(userid);
CREATE INDEX IF NOT EXISTS idx_auditlog_tablename
  ON public.auditlog(tablename);
CREATE INDEX IF NOT EXISTS idx_auditlog_createdat
  ON public.auditlog(createdat DESC);
