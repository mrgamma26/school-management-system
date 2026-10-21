-- Handbook finance/communication extensions: private deposit-slip evidence,
-- formal payment arrangements (installments + history) and the email
-- delivery log. All tables use RLS; only the Accountant writes finance data.
BEGIN;

-- ---------------------------------------------------------------- deposit slips
CREATE TABLE IF NOT EXISTS public.deposit_slips (
  deposit_slip_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id uuid NOT NULL REFERENCES public.student(studentid),
  payment_id uuid REFERENCES public.payment(paymentid),
  bank_name text NOT NULL CHECK (btrim(bank_name) <> '' AND char_length(bank_name) <= 120),
  deposit_date date NOT NULL CHECK (deposit_date <= current_date),
  reference text NOT NULL CHECK (btrim(reference) <> '' AND char_length(reference) <= 80),
  amount numeric(14,2) NOT NULL CHECK (amount > 0),
  storage_path text NOT NULL,
  status text NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING','VERIFIED','REJECTED')),
  verified_by uuid REFERENCES public.staff(staffid),
  verified_at timestamptz,
  rejection_reason text,
  created_by uuid NOT NULL REFERENCES public.staff(staffid),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT deposit_slips_reference_unique UNIQUE (reference),
  CONSTRAINT deposit_slips_decision_check CHECK (
    (status = 'PENDING' AND verified_by IS NULL AND verified_at IS NULL)
    OR (status = 'VERIFIED' AND verified_by IS NOT NULL AND verified_at IS NOT NULL)
    OR (status = 'REJECTED' AND verified_by IS NOT NULL AND verified_at IS NOT NULL
        AND btrim(coalesce(rejection_reason, '')) <> '')
  )
);
CREATE INDEX IF NOT EXISTS deposit_slips_student_idx ON public.deposit_slips(student_id);
CREATE INDEX IF NOT EXISTS deposit_slips_status_idx ON public.deposit_slips(status);

-- ----------------------------------------------------- payment arrangements
CREATE TABLE IF NOT EXISTS public.payment_arrangements (
  arrangement_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id uuid NOT NULL REFERENCES public.student(studentid),
  total_amount numeric(14,2) NOT NULL CHECK (total_amount > 0),
  status text NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','COMPLETED','DEFAULTED','CANCELLED')),
  next_follow_up_date date,
  notes text,
  created_by uuid NOT NULL REFERENCES public.staff(staffid),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS payment_arrangements_student_idx ON public.payment_arrangements(student_id);

CREATE TABLE IF NOT EXISTS public.payment_arrangement_installments (
  installment_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  arrangement_id uuid NOT NULL REFERENCES public.payment_arrangements(arrangement_id) ON DELETE CASCADE,
  due_date date NOT NULL,
  amount numeric(14,2) NOT NULL CHECK (amount > 0),
  status text NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING','PAID','MISSED')),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS arrangement_installments_idx
  ON public.payment_arrangement_installments(arrangement_id, due_date);

CREATE TABLE IF NOT EXISTS public.payment_arrangement_history (
  history_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  arrangement_id uuid NOT NULL REFERENCES public.payment_arrangements(arrangement_id),
  action text NOT NULL,
  note text,
  actor_staff_id uuid REFERENCES public.staff(staffid),
  created_at timestamptz NOT NULL DEFAULT now()
);

-- History is append-only.
CREATE OR REPLACE FUNCTION public.prevent_arrangement_history_change()
RETURNS trigger LANGUAGE plpgsql SET search_path = public, pg_catalog AS $$
BEGIN
  RAISE EXCEPTION 'Payment arrangement history is append-only';
END $$;
REVOKE ALL ON FUNCTION public.prevent_arrangement_history_change() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS arrangement_history_immutable ON public.payment_arrangement_history;
CREATE TRIGGER arrangement_history_immutable
BEFORE UPDATE OR DELETE ON public.payment_arrangement_history
FOR EACH ROW EXECUTE FUNCTION public.prevent_arrangement_history_change();

-- ------------------------------------------------------- email delivery log
CREATE TABLE IF NOT EXISTS public.email_delivery_log (
  email_log_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  recipient_user_id uuid,
  recipient_address text NOT NULL,
  subject text NOT NULL,
  rendered_message text NOT NULL,
  message_type text NOT NULL,
  related_entity text,
  related_id uuid,
  queued_at timestamptz NOT NULL DEFAULT now(),
  sent_at timestamptz,
  status text NOT NULL DEFAULT 'QUEUED' CHECK (status IN ('QUEUED','SENT','FAILED')),
  retry_count integer NOT NULL DEFAULT 0 CHECK (retry_count >= 0),
  failure_reason text
);
CREATE INDEX IF NOT EXISTS email_delivery_log_status_idx ON public.email_delivery_log(status, queued_at);

-- ---------------------------------------------------------------------- RLS
ALTER TABLE public.deposit_slips ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_arrangements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_arrangement_installments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_arrangement_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.email_delivery_log ENABLE ROW LEVEL SECURITY;

-- Accountant: full control of deposit slips and arrangements.
-- Administrator, Head Teacher, Super User: read-only oversight.
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['deposit_slips','payment_arrangements',
                           'payment_arrangement_installments'] LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', t || '_accountant_all', t);
    EXECUTE format($p$CREATE POLICY %I ON public.%I FOR ALL TO authenticated
      USING (public.current_user_is_active() AND public.has_app_role('ACCOUNTANT'))
      WITH CHECK (public.current_user_is_active() AND public.has_app_role('ACCOUNTANT'))$p$,
      t || '_accountant_all', t);
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', t || '_oversight_read', t);
    EXECUTE format($p$CREATE POLICY %I ON public.%I FOR SELECT TO authenticated
      USING (public.current_user_is_active() AND (public.has_app_role('ADMINISTRATOR')
        OR public.has_app_role('HEAD_TEACHER') OR public.has_app_role('SUPER_USER')))$p$,
      t || '_oversight_read', t);
  END LOOP;
END $$;

DROP POLICY IF EXISTS arrangement_history_accountant_insert ON public.payment_arrangement_history;
CREATE POLICY arrangement_history_accountant_insert ON public.payment_arrangement_history
FOR INSERT TO authenticated
WITH CHECK (public.current_user_is_active() AND public.has_app_role('ACCOUNTANT'));
DROP POLICY IF EXISTS arrangement_history_read ON public.payment_arrangement_history;
CREATE POLICY arrangement_history_read ON public.payment_arrangement_history
FOR SELECT TO authenticated
USING (public.current_user_is_active() AND (public.has_app_role('ACCOUNTANT')
  OR public.has_app_role('ADMINISTRATOR') OR public.has_app_role('HEAD_TEACHER')
  OR public.has_app_role('SUPER_USER')));

-- Email log: Super User reads; writes come from Edge Functions (service role).
DROP POLICY IF EXISTS email_delivery_log_super_read ON public.email_delivery_log;
CREATE POLICY email_delivery_log_super_read ON public.email_delivery_log
FOR SELECT TO authenticated
USING (public.current_user_is_active() AND public.has_app_role('SUPER_USER'));

REVOKE ALL ON public.deposit_slips, public.payment_arrangements,
  public.payment_arrangement_installments, public.payment_arrangement_history,
  public.email_delivery_log FROM anon;
REVOKE UPDATE, DELETE, TRUNCATE ON public.payment_arrangement_history FROM authenticated;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.email_delivery_log FROM authenticated;
REVOKE TRUNCATE, REFERENCES, TRIGGER ON public.deposit_slips,
  public.payment_arrangements, public.payment_arrangement_installments
  FROM authenticated;

-- ----------------------------------------------------- private storage bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('deposit-slips', 'deposit-slips', false, 5242880,
        ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf'])
ON CONFLICT (id) DO UPDATE SET public = false,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS deposit_slips_objects_accountant ON storage.objects;
CREATE POLICY deposit_slips_objects_accountant ON storage.objects
FOR ALL TO authenticated
USING (bucket_id = 'deposit-slips' AND public.has_app_role('ACCOUNTANT'))
WITH CHECK (bucket_id = 'deposit-slips' AND public.has_app_role('ACCOUNTANT'));
DROP POLICY IF EXISTS deposit_slips_objects_oversight_read ON storage.objects;
CREATE POLICY deposit_slips_objects_oversight_read ON storage.objects
FOR SELECT TO authenticated
USING (bucket_id = 'deposit-slips' AND (public.has_app_role('ADMINISTRATOR')
  OR public.has_app_role('HEAD_TEACHER') OR public.has_app_role('SUPER_USER')));

NOTIFY pgrst, 'reload schema';
COMMIT;
