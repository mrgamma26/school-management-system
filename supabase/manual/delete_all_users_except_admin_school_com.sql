-- DESTRUCTIVE TEST ACCOUNT RESET
-- Run this in Supabase Dashboard > SQL Editor only when you are ready to
-- remove every account except the exact auth account admin@school.com.
--
-- This keeps school master data such as classes, subjects, academic years,
-- students, and fee structures. It removes staff/guardian-linked operational
-- records because they cannot remain after their account is deleted.

BEGIN;

-- Stop immediately if the account that must survive is missing.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM auth.users
    WHERE lower(email) = 'admin@school.com'
  ) THEN
    RAISE EXCEPTION 'Reset cancelled: auth user admin@school.com was not found.';
  END IF;
END;
$$;

CREATE TEMP TABLE users_to_remove ON COMMIT DROP AS
SELECT su.userid
FROM public.systemuser su
LEFT JOIN auth.users au ON au.id = su.userid
WHERE lower(coalesce(au.email, '')) <> 'admin@school.com';

CREATE TEMP TABLE staff_to_remove ON COMMIT DROP AS
SELECT s.staffid, s.userid
FROM public.staff s
WHERE s.userid IN (SELECT userid FROM users_to_remove);

CREATE TEMP TABLE guardians_to_remove ON COMMIT DROP AS
SELECT g.guardianid, g.userid
FROM public.guardian g
WHERE g.userid IN (SELECT userid FROM users_to_remove);

-- Remove records whose staff or guardian reference is mandatory.
DELETE FROM public.notification n
WHERE n.sentby IN (SELECT staffid FROM staff_to_remove)
   OR n.guardianid IN (SELECT guardianid FROM guardians_to_remove);

DELETE FROM public.teachercomment tc
WHERE tc.staffid IN (SELECT staffid FROM staff_to_remove);

DELETE FROM public.grade g
WHERE g.enteredby IN (SELECT staffid FROM staff_to_remove);

DELETE FROM public.payment p
WHERE p.recordedby IN (SELECT staffid FROM staff_to_remove);

DELETE FROM public.financialadjustment fa
WHERE fa.approvedby IN (SELECT staffid FROM staff_to_remove);

-- These columns are optional review-history references, so retain the review
-- but clear the removed staff member's name from it.
UPDATE public.progressionreview
SET approvedby = NULL
WHERE approvedby IN (SELECT staffid FROM staff_to_remove);

UPDATE public.weedingreview
SET decidedby = NULL
WHERE decidedby IN (SELECT staffid FROM staff_to_remove);

-- Assessments attached to a removed teacher's assignment cascade away with
-- their grades and student-subject enrolments.
DELETE FROM public.classsubject cs
WHERE cs.staffid IN (SELECT staffid FROM staff_to_remove);

DELETE FROM public.studentguardian sg
WHERE sg.guardianid IN (SELECT guardianid FROM guardians_to_remove);

-- Migration 0031 permits these author columns to be NULL.
UPDATE public.calendarevent
SET createdby = NULL,
    createdbyuser = NULL
WHERE createdby IN (SELECT staffid FROM staff_to_remove)
   OR createdbyuser IN (SELECT userid FROM users_to_remove);

-- Deleting systemuser cascades to its staff or guardian profile.
DELETE FROM public.systemuser
WHERE userid IN (SELECT userid FROM users_to_remove);

-- Also remove any Auth account that has no systemuser row, while preserving
-- admin@school.com exactly.
DELETE FROM auth.users
WHERE lower(email) <> 'admin@school.com';

COMMIT;

-- Optional verification: this should return exactly one row.
SELECT id, email
FROM auth.users
ORDER BY email;
