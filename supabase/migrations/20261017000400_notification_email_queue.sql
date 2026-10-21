-- Every notification with a recipient is emailed to that recipient's address.
-- Notifications created by the app or by database workflows (e.g. year-end
-- outcomes) were stored with emailstatus NOT_APPLICABLE and never emailed.
-- This trigger queues them (PENDING); the send-notification-email Edge
-- Function delivers the queue and records every attempt in email_delivery_log.
BEGIN;

CREATE OR REPLACE FUNCTION public.queue_notification_email()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_catalog
AS $$
BEGIN
  IF NEW.emailstatus = 'NOT_APPLICABLE'
     AND (NEW.guardianid IS NOT NULL OR NEW.recipientuserid IS NOT NULL) THEN
    NEW.emailstatus := 'PENDING';
  END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.queue_notification_email()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS queue_notification_email_trigger ON public.notification;
CREATE TRIGGER queue_notification_email_trigger
BEFORE INSERT ON public.notification
FOR EACH ROW EXECUTE FUNCTION public.queue_notification_email();

CREATE INDEX IF NOT EXISTS notification_pending_email_idx
  ON public.notification(createdat) WHERE emailstatus = 'PENDING';

NOTIFY pgrst, 'reload schema';
COMMIT;
