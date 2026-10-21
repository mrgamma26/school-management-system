BEGIN;

-- 20261021000300 added a classsubject policy that queried assessment, while the
-- assessment policies already query classsubject: Postgres raised
-- "infinite recursion detected in policy for relation classsubject" (SQLSTATE
-- 42P17) for every reader. Replace it with a SECURITY DEFINER helper, the same
-- pattern as private.guardian_can_read_assessment, so the lookup bypasses row
-- security and cannot recurse. It reuses that function, so a guardian still sees
-- a classsubject only behind a published result of their own linked student whose
-- fee balance allows viewing results.
DROP POLICY IF EXISTS "guardians read classsubject of visible assessments"
  ON public.classsubject;

CREATE OR REPLACE FUNCTION private.guardian_can_read_classsubject(p_classsubject_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.assessment a
    WHERE a.classsubjectid = p_classsubject_id
      AND private.guardian_can_read_assessment(a.assessmentid)
  )
$$;
REVOKE ALL ON FUNCTION private.guardian_can_read_classsubject(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.guardian_can_read_classsubject(uuid) TO authenticated;

CREATE POLICY "guardians read classsubject of visible assessments"
ON public.classsubject FOR SELECT TO authenticated
USING (private.guardian_can_read_classsubject(classsubjectid));

NOTIFY pgrst, 'reload schema';
COMMIT;
