-- DESTRUCTIVE CLEAN TEST RESET
-- Run in Supabase Dashboard > SQL Editor.
-- Keeps only the Auth account admin@school.com and the role/permission setup.
-- Removes all test users, students, academic setup, finance, grades, reviews,
-- notifications, calendar events, and audit records.

BEGIN;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM auth.users WHERE lower(email) = 'admin@school.com'
  ) THEN
    RAISE EXCEPTION 'Reset cancelled: admin@school.com does not exist.';
  END IF;
END;
$$;

-- Delete child records before their parent records.
DELETE FROM public.notification;
DELETE FROM public.teachercomment;
DELETE FROM public.calendarevent;
DELETE FROM public.payment;
DELETE FROM public.financialadjustment;
DELETE FROM public.grade;
DELETE FROM public.assessment;
DELETE FROM public.studentsubject;
DELETE FROM public.classsubject;
DELETE FROM public.progressionreview;
DELETE FROM public.weedingreview;
DELETE FROM public.studentguardian;
DELETE FROM public.studentclasshistory;
DELETE FROM public.student;
DELETE FROM public.feestructure;
DELETE FROM public.subject;
DELETE FROM public.class;
DELETE FROM public.academicyear;
DELETE FROM public.auditlog;

-- Remove every staff/guardian/system account except the exact preserved admin.
DELETE FROM public.systemuser
WHERE userid NOT IN (
  SELECT id FROM auth.users WHERE lower(email) = 'admin@school.com'
);

DELETE FROM auth.users
WHERE lower(email) <> 'admin@school.com';

COMMIT;

-- Verification: each count should be zero except auth_users and system_users,
-- which should each be one.
SELECT
  (SELECT count(*) FROM auth.users) AS auth_users,
  (SELECT count(*) FROM public.systemuser) AS system_users,
  (SELECT count(*) FROM public.staff) AS staff,
  (SELECT count(*) FROM public.guardian) AS guardians,
  (SELECT count(*) FROM public.student) AS students,
  (SELECT count(*) FROM public.class) AS classes,
  (SELECT count(*) FROM public.subject) AS subjects,
  (SELECT count(*) FROM public.academicyear) AS academic_years,
  (SELECT count(*) FROM public.assessment) AS assessments,
  (SELECT count(*) FROM public.grade) AS grades;
