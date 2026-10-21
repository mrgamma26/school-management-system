-- 0007_finance_comms_types.sql
-- New enum types for Finance (ERD 3) and Communications (ERD 5).
-- Run AFTER 0006_rls.sql.

-- Payment method
DO $$ BEGIN
  CREATE TYPE public.payment_method_enum AS ENUM (
    'CASH',
    'BANK_TRANSFER',
    'MOBILE_MONEY',
    'CHEQUE',
    'OTHER'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
-- Email delivery status
DO $$ BEGIN
  CREATE TYPE public.email_status_enum AS ENUM (
    'PENDING',
    'SENT',
    'FAILED',
    'NOT_APPLICABLE'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
-- Notification read status
DO $$ BEGIN
  CREATE TYPE public.read_status_enum AS ENUM (
    'UNREAD',
    'READ'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
