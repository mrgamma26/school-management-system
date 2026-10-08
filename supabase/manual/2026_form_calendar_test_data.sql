-- Run after migrations 0038-0040 for the existing 2026 browser test data.
-- Existing 2026 periods belong to the current Form 1 cohort. The next-year
-- Term 1 period is the promotion destination for that cohort (Form 2).

UPDATE public.academicyear
SET form = 'FORM_1'
WHERE academicyear = 2026
  AND term IN ('TERM_1', 'TERM_2', 'TERM_3')
  AND form IS NULL;

UPDATE public.academicyear
SET form = 'FORM_2',
    startdate = DATE '2027-01-01',
    enddate = DATE '2027-04-30'
WHERE academicyear = 2027
  AND term = 'TERM_1'
  AND form IS NULL;

-- Return the configured rows so the SQL editor visibly confirms the setup.
SELECT academicyear, term, form, startdate, enddate
FROM public.academicyear
WHERE academicyear IN (2026, 2027)
ORDER BY academicyear, form, term;

NOTIFY pgrst, 'reload schema';
