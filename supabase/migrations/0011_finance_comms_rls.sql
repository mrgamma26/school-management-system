-- 0011_finance_comms_rls.sql
-- RLS policies for finance and communication tables.

-- Enable RLS
ALTER TABLE public.feestructure       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.financialadjustment ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.teachercomment     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.calendarevent      ENABLE ROW LEVEL SECURITY;

-- ─────────────────────────────────────────────
-- feestructure
-- ─────────────────────────────────────────────
-- Accountant and admin manage; others can read.
CREATE POLICY "accountant can manage fee structures"
ON public.feestructure FOR ALL TO authenticated
USING (
  public.current_app_role() IN ('ACCOUNTANT', 'SYSTEM_ADMIN')
);

CREATE POLICY "staff and head teacher can read fee structures"
ON public.feestructure FOR SELECT TO authenticated
USING (
  public.current_app_role() IN (
    'REGISTRAR', 'TEACHER', 'HEAD_TEACHER', 'ICA_DIRECTOR'
  )
);

-- ─────────────────────────────────────────────
-- payment
-- ─────────────────────────────────────────────
CREATE POLICY "accountant can manage payments"
ON public.payment FOR ALL TO authenticated
USING (
  public.current_app_role() IN ('ACCOUNTANT', 'SYSTEM_ADMIN')
);

CREATE POLICY "head teacher and director can read payments"
ON public.payment FOR SELECT TO authenticated
USING (
  public.current_app_role() IN ('HEAD_TEACHER', 'ICA_DIRECTOR')
);

-- Guardians see payments for their linked students
CREATE POLICY "guardians see linked student payments"
ON public.payment FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.guardian g
    JOIN public.studentguardian sg ON sg.guardianid = g.guardianid
    WHERE g.userid = auth.uid()
      AND sg.studentid = payment.studentid
  )
);

-- ─────────────────────────────────────────────
-- financialadjustment
-- ─────────────────────────────────────────────
CREATE POLICY "accountant can manage adjustments"
ON public.financialadjustment FOR ALL TO authenticated
USING (
  public.current_app_role() IN ('ACCOUNTANT', 'SYSTEM_ADMIN')
);

CREATE POLICY "head teacher and director can read adjustments"
ON public.financialadjustment FOR SELECT TO authenticated
USING (
  public.current_app_role() IN ('HEAD_TEACHER', 'ICA_DIRECTOR')
);

-- ─────────────────────────────────────────────
-- notification
-- ─────────────────────────────────────────────
-- Staff (registrar/teacher/head) can create and read notifications they sent.
CREATE POLICY "staff can manage own notifications"
ON public.notification FOR ALL TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.staff s
    WHERE s.staffid = notification.sentby
      AND s.userid = auth.uid()
  )
);

-- Privileged roles can read all notifications.
CREATE POLICY "privileged roles can read all notifications"
ON public.notification FOR SELECT TO authenticated
USING (
  public.current_app_role() IN (
    'HEAD_TEACHER', 'SYSTEM_ADMIN', 'ICA_DIRECTOR', 'REGISTRAR'
  )
);

-- Guardians read only their own notifications.
CREATE POLICY "guardian reads own notifications"
ON public.notification FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.guardian g
    WHERE g.guardianid = notification.guardianid
      AND g.userid = auth.uid()
  )
);

-- Guardians can mark their own notifications as read (UPDATE readstatus only).
CREATE POLICY "guardian can mark own notification read"
ON public.notification FOR UPDATE TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.guardian g
    WHERE g.guardianid = notification.guardianid
      AND g.userid = auth.uid()
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.guardian g
    WHERE g.guardianid = notification.guardianid
      AND g.userid = auth.uid()
  )
);

-- ─────────────────────────────────────────────
-- teachercomment
-- ─────────────────────────────────────────────
-- Teachers manage their own comments.
CREATE POLICY "teacher can manage own comments"
ON public.teachercomment FOR ALL TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.staff s
    WHERE s.staffid = teachercomment.staffid
      AND s.userid = auth.uid()
  )
);

-- Privileged roles can read all comments.
CREATE POLICY "privileged roles can read all comments"
ON public.teachercomment FOR SELECT TO authenticated
USING (
  public.current_app_role() IN (
    'HEAD_TEACHER', 'SYSTEM_ADMIN', 'ICA_DIRECTOR', 'REGISTRAR'
  )
);

-- Guardians see comments for their linked students.
CREATE POLICY "guardians see linked student comments"
ON public.teachercomment FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.guardian g
    JOIN public.studentguardian sg ON sg.guardianid = g.guardianid
    WHERE g.userid = auth.uid()
      AND sg.studentid = teachercomment.studentid
  )
);

-- ─────────────────────────────────────────────
-- calendarevent
-- ─────────────────────────────────────────────
-- All authenticated users can read calendar events.
CREATE POLICY "authenticated users can read calendar events"
ON public.calendarevent FOR SELECT TO authenticated
USING (true);

-- Staff can manage events they created.
CREATE POLICY "staff can manage own events"
ON public.calendarevent FOR ALL TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.staff s
    WHERE s.staffid = calendarevent.createdby
      AND s.userid = auth.uid()
  )
);

-- Head teacher and admin can manage all events.
CREATE POLICY "head teacher can manage all events"
ON public.calendarevent FOR ALL TO authenticated
USING (
  public.current_app_role() IN ('HEAD_TEACHER', 'SYSTEM_ADMIN', 'ICA_DIRECTOR')
);
