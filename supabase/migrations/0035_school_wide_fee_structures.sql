-- Fee structures are school-wide and belong to an academic-year/term record,
-- not to an individual class. The academicyear table already holds the term.
BEGIN;

ALTER TABLE public.feestructure
  ALTER COLUMN classid DROP NOT NULL;

-- Existing class-specific fee records become school-wide records.
UPDATE public.feestructure
SET classid = NULL
WHERE classid IS NOT NULL;

DROP POLICY IF EXISTS "accountant can manage fee structures" ON public.feestructure;
DROP POLICY IF EXISTS "staff and head teacher can read fee structures" ON public.feestructure;
DROP POLICY IF EXISTS "finance managers manage fee structures" ON public.feestructure;
DROP POLICY IF EXISTS "authenticated users read fee structures" ON public.feestructure;

CREATE POLICY "finance managers manage fee structures"
ON public.feestructure FOR ALL TO authenticated
USING ((SELECT public.current_app_role()) IN (
  'SUPER_USER', 'SYSTEM_ADMIN', 'ADMINISTRATOR', 'ADMIN', 'ACCOUNTANT'
))
WITH CHECK ((SELECT public.current_app_role()) IN (
  'SUPER_USER', 'SYSTEM_ADMIN', 'ADMINISTRATOR', 'ADMIN', 'ACCOUNTANT'
));

CREATE POLICY "authenticated users read fee structures"
ON public.feestructure FOR SELECT TO authenticated
USING (true);

CREATE INDEX IF NOT EXISTS idx_feestructure_year_feetype
  ON public.feestructure(academicyearid, feetype);

NOTIFY pgrst, 'reload schema';
COMMIT;
