-- The live public.email_status_enum only had PENDING, SENT and FAILED, but the
-- code that writes notifications relies on a fourth value, NOT_APPLICABLE:
--   * trigger queue_notification_email() (20261017000400) compares against it,
--     so EVERY insert into public.notification failed with SQLSTATE 22P02
--     ("invalid input value for enum email_status_enum"), including the
--     Send Notification dialog;
--   * the year-end outcome and return-assessment-to-teacher functions insert it.
-- 0007_finance_comms_types.sql defines the value, but the type already existed
-- in this project without it, so the definition was skipped.
ALTER TYPE public.email_status_enum ADD VALUE IF NOT EXISTS 'NOT_APPLICABLE';
