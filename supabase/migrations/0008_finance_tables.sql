-- 0008_finance_tables.sql
-- Finance tables from ERD 3: feestructure, payment, financialadjustment.
-- Run AFTER 0007_finance_comms_types.sql.

-- ─────────────────────────────────────────────
-- feestructure
-- Defines what amount is owed per class + academic year + fee type.
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.feestructure (
  feestructureid UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  classid        UUID        NOT NULL REFERENCES public.class(classid),
  academicyearid UUID        NOT NULL REFERENCES public.academicyear(academicyearid),
  feetype        VARCHAR(255) NOT NULL,
  amount         DECIMAL(10,2) NOT NULL CHECK (amount >= 0),
  createdat      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updatedat      TIMESTAMPTZ NOT NULL DEFAULT now(),
  -- One fee type per class per academic year
  UNIQUE (classid, academicyearid, feetype)
);

-- ─────────────────────────────────────────────
-- payment
-- Records a fee payment made by/for a student.
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.payment (
  paymentid       UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  studentid       UUID          NOT NULL REFERENCES public.student(studentid),
  feestructureid  UUID          NOT NULL REFERENCES public.feestructure(feestructureid),
  recordedby      UUID          NOT NULL REFERENCES public.staff(staffid),
  amount          DECIMAL(10,2) NOT NULL CHECK (amount > 0),
  paymentdate     DATE          NOT NULL,
  method          public.payment_method_enum NOT NULL,
  referencenumber VARCHAR(255),
  receiptnumber   VARCHAR(255) UNIQUE,
  createdat       TIMESTAMPTZ   NOT NULL DEFAULT now(),
  updatedat       TIMESTAMPTZ   NOT NULL DEFAULT now()
);

-- ─────────────────────────────────────────────
-- financialadjustment
-- Discounts, waivers or penalties applied to a student's account.
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.financialadjustment (
  adjustmentid UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  studentid    UUID          NOT NULL REFERENCES public.student(studentid),
  approvedby   UUID          NOT NULL REFERENCES public.staff(staffid),
  amount       DECIMAL(10,2) NOT NULL, -- negative = discount/waiver
  reason       TEXT          NOT NULL,
  createdat    TIMESTAMPTZ   NOT NULL DEFAULT now(),
  updatedat    TIMESTAMPTZ   NOT NULL DEFAULT now()
);
