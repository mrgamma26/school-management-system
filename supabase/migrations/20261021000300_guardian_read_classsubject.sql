BEGIN;

-- Guardian report cards could never show results. The report card reads
--   grade -> assessment -> classsubject -> subject / class
-- A guardian is allowed to read the published grade and the assessment, but the
-- classsubject row between them was readable only by oversight staff and the
-- assigned teacher (migration 20261020052457), so the embed came back null and
-- the page showed "No grades recorded for this student yet".
--
-- Let a guardian read exactly the classsubject rows behind assessments they can
-- already see. The subquery on assessment runs under the guardian's own row
-- security, so it is limited to published results of their linked students whose
-- fees allow viewing results.
DROP POLICY IF EXISTS "guardians read classsubject of visible assessments"
  ON public.classsubject;
CREATE POLICY "guardians read classsubject of visible assessments"
ON public.classsubject FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.assessment a
    WHERE a.classsubjectid = classsubject.classsubjectid
  )
);

NOTIFY pgrst, 'reload schema';
COMMIT;
