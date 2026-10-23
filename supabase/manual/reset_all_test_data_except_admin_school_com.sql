-- DESTRUCTIVE CLEAN TEST RESET
-- Run in Supabase Dashboard > SQL Editor.
-- Keeps only the linked admin@school.com Auth/system account and the
-- role/permission setup. Removes all other users and all school data.
-- REQUIRED FIRST: run preflight_reset_test_data_except_admin.sql, take a
-- database backup, and empty the listed Storage buckets through the Storage
-- API/Dashboard. This script refuses to continue while those objects exist.

BEGIN;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM auth.users au
    JOIN public.systemuser su ON su.userid = au.id
    WHERE lower(au.email) = 'admin@school.com'
  ) THEN
    RAISE EXCEPTION
      'Reset cancelled: admin@school.com must exist in auth.users and public.systemuser.';
  END IF;
  IF (SELECT count(*) FROM auth.users WHERE lower(email) = 'admin@school.com') <> 1 THEN
    RAISE EXCEPTION
      'Reset cancelled: exactly one admin@school.com Auth account is required.';
  END IF;
  IF EXISTS (
    SELECT 1 FROM storage.objects
    WHERE bucket_id IN ('deposit-slips', 'staff-profiles', 'school-branding')
  ) THEN
    RAISE EXCEPTION
      'Reset cancelled: empty deposit-slips, staff-profiles and school-branding through the Storage API first.';
  END IF;
END;
$$;

-- Delete child records before their parent records.
DELETE FROM public.notification;
DELETE FROM public.teachercomment;
DELETE FROM public.calendarevent;
DELETE FROM public.email_delivery_log;
DELETE FROM public.deposit_slips;
DELETE FROM public.payment_reversals;
-- Posted payments are immutable during normal application use. The reset is
-- the one controlled maintenance operation that may remove them, so disable
-- only that guard for this transaction and restore it immediately afterward.
ALTER TABLE public.payment
  DISABLE TRIGGER prevent_posted_payment_mutation_trigger;
DELETE FROM public.payment;
ALTER TABLE public.payment
  ENABLE TRIGGER prevent_posted_payment_mutation_trigger;
ALTER TABLE public.payment_arrangement_history
  DISABLE TRIGGER arrangement_history_immutable;
DELETE FROM public.payment_arrangement_history;
ALTER TABLE public.payment_arrangement_history
  ENABLE TRIGGER arrangement_history_immutable;
DELETE FROM public.payment_arrangement_installments;
DELETE FROM public.payment_arrangements;
DELETE FROM public.financialadjustment;
ALTER TABLE public.assessment_returns
  DISABLE TRIGGER assessment_returns_immutable;
DELETE FROM public.assessment_returns;
ALTER TABLE public.assessment_returns
  ENABLE TRIGGER assessment_returns_immutable;
DELETE FROM public.result_correction_requests;
ALTER TABLE public.grade
  DISABLE TRIGGER prevent_published_grade_mutation_trigger;
DELETE FROM public.grade;
ALTER TABLE public.grade
  ENABLE TRIGGER prevent_published_grade_mutation_trigger;
DELETE FROM public.assessment;
DELETE FROM public.studentsubject;
DELETE FROM public.student_subject_enrollments;
DELETE FROM public.teacher_assignments;
DELETE FROM public.class_subject_catalog;
DELETE FROM public.classsubject;
DELETE FROM public.progressionreview;
DELETE FROM public.weedingreview;
DELETE FROM public.studentguardian;
DELETE FROM public.studentclasshistory;
DELETE FROM public.student;
DELETE FROM public.feestructure;
DELETE FROM public.paymentchannel;
-- public.progressionrule is reference data (the default pass-mark rule is created
-- only by migration 0036 and has no screen), so it is kept like roles and permissions.
DELETE FROM public.subject;
DELETE FROM public.class;
DELETE FROM public.academic_year_terms;
DELETE FROM public.school_academic_years;
DELETE FROM public.academicyear;
DELETE FROM public.auditlog;
DELETE FROM public.staff;
DELETE FROM public.guardian;

-- Remove every application/Auth account except the exact preserved admin.
DELETE FROM public.systemuser
WHERE userid <> (
  SELECT id FROM auth.users WHERE lower(email) = 'admin@school.com'
);

DELETE FROM auth.users
WHERE id <> (
  SELECT id FROM auth.users WHERE lower(email) = 'admin@school.com'
);

ALTER SEQUENCE IF EXISTS public.payment_receipt_number_seq RESTART WITH 1;

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
  (SELECT count(*) FROM public.progressionrule) AS progression_rules,
  (SELECT count(*) FROM public.paymentchannel) AS payment_channels,
  (SELECT count(*) FROM public.assessment) AS assessments,
  (SELECT count(*) FROM public.grade) AS grades,
  (SELECT count(*) FROM public.deposit_slips) AS deposit_slips,
  (SELECT count(*) FROM public.payment_arrangements) AS payment_arrangements;
