-- Rename the legacy enrollment enum type to the canonical student status type.
-- Existing databases that already use student_status_enum are unchanged.

DO $$
BEGIN
  IF to_regtype('public.enrollment_status') IS NOT NULL
     AND to_regtype('public.student_status_enum') IS NULL THEN
    ALTER TYPE public.enrollment_status RENAME TO student_status_enum;
  END IF;
END $$;