-- Live-schema compatibility: auditlog.recordid is UUID in the deployed project.
-- Run after 0043 when channel creation reports error 42804 for recordid.

CREATE OR REPLACE FUNCTION public.audit_payment_channel_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_role text;
BEGIN
  SELECT upper(r.rolename) INTO v_role
  FROM public.systemuser su
  JOIN public.role r ON r.roleid = su.roleid
  WHERE su.userid = auth.uid();

  INSERT INTO public.auditlog (
    userid, recordid, actorrole, action, tablename, previousvalue, newvalue
  ) VALUES (
    auth.uid(), NEW.channelid, v_role,
    CASE WHEN TG_OP = 'INSERT' THEN 'PAYMENT_CHANNEL_CREATED' ELSE 'PAYMENT_CHANNEL_UPDATED' END,
    'paymentchannel',
    CASE WHEN TG_OP = 'UPDATE' THEN to_jsonb(OLD) ELSE NULL END,
    to_jsonb(NEW)
  );
  RETURN NEW;
END;
$$;
CREATE OR REPLACE FUNCTION public.record_payment_v2(
  p_student_id uuid,
  p_fee_structure_id uuid,
  p_amount numeric,
  p_payment_date date,
  p_method text,
  p_channel_id uuid DEFAULT NULL,
  p_external_reference text DEFAULT NULL,
  p_processing_fee numeric DEFAULT 0,
  p_transaction_details jsonb DEFAULT '{}'::jsonb
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_method text := upper(trim(p_method));
  v_role text;
  v_staff_id uuid;
  v_channel_type text;
  v_channel_active boolean;
  v_payment_id uuid;
  v_receipt text;
  v_reference text := nullif(trim(p_external_reference), '');
  v_details jsonb := coalesce(p_transaction_details, '{}'::jsonb);
BEGIN
  SELECT upper(r.rolename), s.staffid INTO v_role, v_staff_id
  FROM public.systemuser su
  JOIN public.role r ON r.roleid = su.roleid
  JOIN public.staff s ON s.userid = su.userid
  WHERE su.userid = auth.uid() AND su.isactive;

  IF v_role IS NULL OR v_role NOT IN ('ACCOUNTANT', 'SUPER_USER', 'SYSTEM_ADMIN') THEN
    RAISE EXCEPTION 'Only an active accountant may record payments.' USING ERRCODE = '42501';
  END IF;
  IF p_amount IS NULL OR p_amount <= 0 THEN RAISE EXCEPTION 'Payment amount must be greater than zero.'; END IF;
  IF p_payment_date IS NULL OR p_payment_date > current_date THEN RAISE EXCEPTION 'Payment date cannot be in the future.'; END IF;
  IF coalesce(p_processing_fee, 0) < 0 THEN RAISE EXCEPTION 'Processing fee cannot be negative.'; END IF;
  IF v_method NOT IN ('CASH', 'BANK_TRANSFER', 'MOBILE_MONEY', 'CARD', 'CHEQUE', 'OTHER') THEN RAISE EXCEPTION 'Unsupported payment method.'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.student WHERE studentid = p_student_id) THEN RAISE EXCEPTION 'Student was not found.'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.feestructure WHERE feestructureid = p_fee_structure_id) THEN RAISE EXCEPTION 'Fee structure was not found.'; END IF;

  IF p_channel_id IS NOT NULL THEN
    SELECT channeltype, isactive INTO v_channel_type, v_channel_active
    FROM public.paymentchannel WHERE channelid = p_channel_id;
    IF v_channel_type IS NULL THEN RAISE EXCEPTION 'The selected receiving channel was not found.'; END IF;
    IF NOT v_channel_active THEN RAISE EXCEPTION 'The selected receiving channel is inactive.'; END IF;
    IF v_channel_type <> v_method THEN RAISE EXCEPTION 'The selected receiving channel does not match the payment method.'; END IF;
  END IF;

  CASE v_method
    WHEN 'CASH' THEN
      IF p_channel_id IS NOT NULL THEN RAISE EXCEPTION 'Cash payments cannot use a receiving channel.'; END IF;
    WHEN 'BANK_TRANSFER' THEN
      IF p_channel_id IS NULL THEN RAISE EXCEPTION 'Select the receiving business account.'; END IF;
      IF coalesce(trim(v_details->>'payerBankName'), '') = '' THEN RAISE EXCEPTION 'Payer bank name is required.'; END IF;
      IF v_reference IS NULL THEN RAISE EXCEPTION 'Transaction reference / UTR is required.'; END IF;
      IF coalesce(trim(v_details->>'clearanceDate'), '') = '' THEN RAISE EXCEPTION 'Value / clearance date is required.'; END IF;
    WHEN 'CHEQUE' THEN
      IF p_channel_id IS NOT NULL THEN RAISE EXCEPTION 'Cheque payments cannot use a receiving channel.'; END IF;
      IF coalesce(v_details->>'chequeNumber', '') !~ '^[0-9]{6}$' THEN RAISE EXCEPTION 'Cheque number must contain exactly 6 digits.'; END IF;
      IF coalesce(trim(v_details->>'draweeBankBranch'), '') = '' THEN RAISE EXCEPTION 'Drawee bank and branch are required.'; END IF;
      IF coalesce(trim(v_details->>'chequeDate'), '') = '' THEN RAISE EXCEPTION 'Cheque date is required.'; END IF;
      IF coalesce(trim(v_details->>'depositDate'), '') = '' THEN RAISE EXCEPTION 'Deposit date is required.'; END IF;
      IF coalesce(v_details->>'chequeStatus', '') NOT IN ('PENDING_CLEARANCE', 'CLEARED', 'POST_DATED', 'BOUNCED_RETURNED') THEN RAISE EXCEPTION 'Select a valid cheque status.'; END IF;
      v_reference := v_details->>'chequeNumber';
    WHEN 'CARD' THEN
      IF p_channel_id IS NULL THEN RAISE EXCEPTION 'Select the payment gateway / POS terminal.'; END IF;
      IF coalesce(v_details->>'cardNetwork', '') NOT IN ('VISA', 'MASTERCARD', 'AMERICAN_EXPRESS', 'LOCAL_DEBIT') THEN RAISE EXCEPTION 'Select a valid card network.'; END IF;
      IF coalesce(v_details->>'lastFourDigits', '') !~ '^[0-9]{4}$' THEN RAISE EXCEPTION 'Card ending must contain exactly 4 digits.'; END IF;
      IF coalesce(trim(v_details->>'approvalCode'), '') = '' THEN RAISE EXCEPTION 'Authorization / approval code is required.'; END IF;
      v_reference := coalesce(v_reference, v_details->>'approvalCode');
    WHEN 'MOBILE_MONEY' THEN
      IF p_channel_id IS NULL THEN RAISE EXCEPTION 'Select the receiving merchant wallet.'; END IF;
      IF v_reference IS NULL THEN RAISE EXCEPTION 'Transaction reference / SMS ID is required.'; END IF;
      IF coalesce(v_details->>'senderPhone', '') !~ '^\+?[0-9]{9,15}$' THEN RAISE EXCEPTION 'Enter a valid sender mobile number.'; END IF;
      IF coalesce(trim(v_details->>'transactionTimestamp'), '') = '' THEN RAISE EXCEPTION 'Exact transaction timestamp is required.'; END IF;
    WHEN 'OTHER' THEN
      IF p_channel_id IS NOT NULL THEN RAISE EXCEPTION 'Other payments cannot use a receiving channel.'; END IF;
      IF coalesce(trim(v_details->>'description'), '') = '' THEN RAISE EXCEPTION 'Payment description is required.'; END IF;
      IF v_reference IS NULL THEN RAISE EXCEPTION 'External reference is required.'; END IF;
  END CASE;

  v_receipt := 'SCH-' || to_char(current_date, 'YYYY') || '-' || to_char(nextval('public.payment_receipt_number_seq'), 'FM000000');
  INSERT INTO public.payment (
    studentid, feestructureid, recordedby, amount, paymentdate, method,
    referencenumber, receiptnumber, channelid, transactiondetails, processingfee
  ) VALUES (
    p_student_id, p_fee_structure_id, v_staff_id, p_amount, p_payment_date,
    v_method, v_reference, v_receipt, p_channel_id, v_details, coalesce(p_processing_fee, 0)
  ) RETURNING paymentid INTO v_payment_id;

  INSERT INTO public.auditlog (userid, recordid, actorrole, action, tablename, newvalue)
  VALUES (
    auth.uid(), v_payment_id, v_role, 'PAYMENT_RECORDED', 'payment',
    jsonb_build_object(
      'studentid', p_student_id, 'feestructureid', p_fee_structure_id,
      'amount', p_amount, 'method', v_method, 'channelid', p_channel_id,
      'reference', v_reference, 'receipt', v_receipt,
      'processingFee', coalesce(p_processing_fee, 0)
    )
  );
  RETURN jsonb_build_object('paymentId', v_payment_id, 'receiptNumber', v_receipt);
EXCEPTION WHEN unique_violation THEN
  RAISE EXCEPTION 'This transaction reference or receipt has already been recorded.';
END;
$$;
NOTIFY pgrst, 'reload schema';
