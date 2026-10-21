-- Allow accountant-recorded bank deposits as a normal payment method.
ALTER TABLE public.payment DROP CONSTRAINT IF EXISTS payment_method_check;
ALTER TABLE public.payment ADD CONSTRAINT payment_method_check CHECK (
  method IN ('CASH', 'DEPOSIT', 'BANK_TRANSFER', 'MOBILE_MONEY', 'CARD', 'CHEQUE', 'OTHER')
);

-- Update the already-deployed payment RPC without duplicating its full body.
-- DEPOSIT uses the same generic ledger path as CASH; its evidence is stored
-- separately in deposit_slips by the client after the payment is created.
DO $$
DECLARE fn text;
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO fn
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.proname = 'record_payment_v2'
    AND pg_get_function_identity_arguments(p.oid) =
      'p_student_id uuid, p_fee_structure_id uuid, p_amount numeric, p_payment_date date, p_method text, p_channel_id uuid, p_external_reference text, p_processing_fee numeric, p_transaction_details jsonb';
  IF fn IS NOT NULL THEN
    fn := replace(
      fn,
      $methods$'CASH', 'BANK_TRANSFER', 'MOBILE_MONEY', 'CARD', 'CHEQUE', 'OTHER'$methods$,
      $methods$'CASH', 'DEPOSIT', 'BANK_TRANSFER', 'MOBILE_MONEY', 'CARD', 'CHEQUE', 'OTHER'$methods$
    );
    fn := replace(
      fn,
      $branch$WHEN 'BANK_TRANSFER' THEN$branch$,
      $branch$WHEN 'DEPOSIT' THEN
      IF p_channel_id IS NOT NULL THEN RAISE EXCEPTION 'Deposits cannot use a receiving channel.'; END IF;
      IF coalesce(trim(v_details->>'depositBankName'), '') = '' THEN RAISE EXCEPTION 'Bank name is required.'; END IF;
      IF v_reference IS NULL THEN RAISE EXCEPTION 'Deposit reference number is required.'; END IF;
    WHEN 'BANK_TRANSFER' THEN$branch$
    );
    EXECUTE fn;
  END IF;
END $$;

NOTIFY pgrst, 'reload schema';
