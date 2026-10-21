BEGIN;

CREATE TABLE public.payment_reversals (
  reversal_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_id uuid NOT NULL REFERENCES public.payment(paymentid) ON DELETE RESTRICT,
  reversed_by uuid NOT NULL REFERENCES public.staff(staffid) ON DELETE RESTRICT,
  reason text NOT NULL CHECK (btrim(reason) <> '' AND char_length(reason) <= 500),
  reversed_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (payment_id)
);

CREATE OR REPLACE FUNCTION public.prevent_posted_payment_mutation()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  RAISE EXCEPTION 'Posted payments are immutable; create an authorized reversal instead';
END;
$$;

DROP TRIGGER IF EXISTS prevent_posted_payment_mutation_trigger ON public.payment;
CREATE TRIGGER prevent_posted_payment_mutation_trigger
BEFORE UPDATE OR DELETE ON public.payment
FOR EACH ROW EXECUTE FUNCTION public.prevent_posted_payment_mutation();

CREATE OR REPLACE FUNCTION public.reverse_payment(p_payment_id uuid, p_reason text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_staff_id uuid; v_id uuid;
BEGIN
  SELECT st.staffid INTO v_staff_id FROM public.staff st WHERE st.userid = auth.uid();
  IF v_staff_id IS NULL OR NOT public.has_app_role('ACCOUNTANT') THEN
    RAISE EXCEPTION 'Only an Accountant may reverse a payment';
  END IF;
  INSERT INTO public.payment_reversals(payment_id, reversed_by, reason)
  SELECT p.paymentid, v_staff_id, btrim(p_reason)
  FROM public.payment p WHERE p.paymentid = p_payment_id
  RETURNING reversal_id INTO v_id;
  IF v_id IS NULL THEN RAISE EXCEPTION 'Payment not found or already reversed'; END IF;
  INSERT INTO public.auditlog(userid, recordid, actorrole, action, tablename, newvalue, reason)
  VALUES (auth.uid(), p_payment_id, public.current_app_role(), 'PAYMENT_REVERSED', 'payment_reversals',
    jsonb_build_object('reversalId', v_id, 'paymentId', p_payment_id), btrim(p_reason));
  RETURN v_id;
END;
$$;

ALTER TABLE public.payment_reversals ENABLE ROW LEVEL SECURITY;
CREATE POLICY payment_reversals_read ON public.payment_reversals FOR SELECT TO authenticated
USING (public.has_app_role('ACCOUNTANT') OR public.has_app_role('ADMINISTRATOR') OR public.has_app_role('SUPER_USER'));
GRANT SELECT ON public.payment_reversals TO authenticated;
REVOKE ALL ON FUNCTION public.reverse_payment(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.reverse_payment(uuid, text) TO authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
