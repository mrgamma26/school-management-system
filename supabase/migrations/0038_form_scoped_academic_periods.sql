-- Academic calendars are scoped to a form level. Sections such as Form 1A
-- and Form 1B share the FORM_1 calendar, while another form can use different
-- dates for the same academic year and term.

ALTER TABLE public.academicyear
  ADD COLUMN IF NOT EXISTS form text;

DO $$
BEGIN
  ALTER TABLE public.academicyear
    ADD CONSTRAINT academicyear_form_check
    CHECK (form IS NULL OR form IN ('FORM_1', 'FORM_2', 'FORM_3', 'FORM_4'));
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

ALTER TABLE public.academicyear
  DROP CONSTRAINT IF EXISTS academicyear_academicyear_term_key;

CREATE UNIQUE INDEX IF NOT EXISTS uq_academicyear_year_term_form
  ON public.academicyear (academicyear, term, form)
  WHERE form IS NOT NULL;

CREATE INDEX IF NOT EXISTS ix_academicyear_active_form_dates
  ON public.academicyear (form, startdate, enddate);

NOTIFY pgrst, 'reload schema';
