-- 0010_finance_comms_indexes.sql
-- Performance indexes for the finance and communication tables.

-- feestructure
CREATE INDEX IF NOT EXISTS idx_feestructure_classid
  ON public.feestructure(classid);
CREATE INDEX IF NOT EXISTS idx_feestructure_academicyearid
  ON public.feestructure(academicyearid);
-- payment
CREATE INDEX IF NOT EXISTS idx_payment_studentid
  ON public.payment(studentid);
CREATE INDEX IF NOT EXISTS idx_payment_feestructureid
  ON public.payment(feestructureid);
CREATE INDEX IF NOT EXISTS idx_payment_recordedby
  ON public.payment(recordedby);
CREATE INDEX IF NOT EXISTS idx_payment_paymentdate
  ON public.payment(paymentdate DESC);
-- financialadjustment
CREATE INDEX IF NOT EXISTS idx_financialadjustment_studentid
  ON public.financialadjustment(studentid);
CREATE INDEX IF NOT EXISTS idx_financialadjustment_approvedby
  ON public.financialadjustment(approvedby);
-- notification
CREATE INDEX IF NOT EXISTS idx_notification_guardianid
  ON public.notification(guardianid);
CREATE INDEX IF NOT EXISTS idx_notification_sentby
  ON public.notification(sentby);
CREATE INDEX IF NOT EXISTS idx_notification_readstatus
  ON public.notification(readstatus);
-- teachercomment
CREATE INDEX IF NOT EXISTS idx_teachercomment_studentid
  ON public.teachercomment(studentid);
CREATE INDEX IF NOT EXISTS idx_teachercomment_staffid
  ON public.teachercomment(staffid);
CREATE INDEX IF NOT EXISTS idx_teachercomment_academicyearid
  ON public.teachercomment(academicyearid);
-- calendarevent
CREATE INDEX IF NOT EXISTS idx_calendarevent_classid
  ON public.calendarevent(classid);
CREATE INDEX IF NOT EXISTS idx_calendarevent_starttime
  ON public.calendarevent(starttime);
CREATE INDEX IF NOT EXISTS idx_calendarevent_createdby
  ON public.calendarevent(createdby);
-- Attach updatedat triggers to new tables
DO $$
DECLARE
  tbl TEXT;
BEGIN
  FOREACH tbl IN ARRAY ARRAY[
    'feestructure', 'payment', 'financialadjustment',
    'notification', 'teachercomment', 'calendarevent'
  ]
  LOOP
    EXECUTE format(
      'DROP TRIGGER IF EXISTS trg_set_updated_at ON public.%I;
       CREATE TRIGGER trg_set_updated_at
         BEFORE UPDATE ON public.%I
         FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();',
      tbl, tbl
    );
  END LOOP;
END;
$$;
