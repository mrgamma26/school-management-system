BEGIN;

ALTER TABLE public.grade
  ADD COLUMN IF NOT EXISTS published_at timestamptz,
  ADD COLUMN IF NOT EXISTS published_by uuid REFERENCES public.staff(staffid) ON DELETE SET NULL;

CREATE TABLE public.result_correction_requests (
  correction_request_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  grade_id uuid NOT NULL REFERENCES public.grade(gradeid) ON DELETE RESTRICT,
  requested_by uuid NOT NULL REFERENCES public.staff(staffid) ON DELETE RESTRICT,
  approved_by uuid REFERENCES public.staff(staffid) ON DELETE RESTRICT,
  reason text NOT NULL CHECK (btrim(reason) <> '' AND char_length(reason) <= 500),
  old_score numeric(6,2),
  new_score numeric(6,2),
  status text NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED', 'COMPLETED')),
  decision_reason text,
  requested_at timestamptz NOT NULL DEFAULT now(),
  decided_at timestamptz,
  completed_at timestamptz,
  CHECK (new_score IS NULL OR new_score >= 0),
  CHECK ((status = 'PENDING' AND approved_by IS NULL AND decided_at IS NULL) OR status <> 'PENDING')
);

CREATE UNIQUE INDEX result_correction_one_pending_idx
  ON public.result_correction_requests (grade_id) WHERE status = 'PENDING';
CREATE INDEX result_correction_requester_idx
  ON public.result_correction_requests (requested_by, status, requested_at DESC);

CREATE OR REPLACE FUNCTION public.prevent_published_grade_mutation()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF OLD.published_at IS NOT NULL AND (
    NEW.score IS DISTINCT FROM OLD.score OR
    NEW.gradestatus IS DISTINCT FROM OLD.gradestatus OR
    NEW.submissionstatus IS DISTINCT FROM OLD.submissionstatus OR
    NEW.enteredby IS DISTINCT FROM OLD.enteredby
  ) AND NOT EXISTS (
    SELECT 1 FROM public.result_correction_requests r
    WHERE r.grade_id = OLD.gradeid AND r.status = 'APPROVED'
  ) THEN
    RAISE EXCEPTION 'Published grades can only be changed through an approved correction request';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS prevent_published_grade_mutation_trigger ON public.grade;
CREATE TRIGGER prevent_published_grade_mutation_trigger
BEFORE UPDATE ON public.grade
FOR EACH ROW EXECUTE FUNCTION public.prevent_published_grade_mutation();

CREATE OR REPLACE FUNCTION public.publish_assessment_results(p_assessment_id uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_staff_id uuid; v_count integer;
BEGIN
  SELECT st.staffid INTO v_staff_id FROM public.staff st WHERE st.userid = auth.uid();
  IF v_staff_id IS NULL OR NOT (public.has_app_role('HEAD_TEACHER') OR public.has_app_role('SUPER_USER')) THEN
    RAISE EXCEPTION 'Only a Head Teacher or Super User may publish results';
  END IF;
  UPDATE public.grade
  SET submissionstatus = 'SUBMITTED', published_at = now(), published_by = v_staff_id
  WHERE assessmentid = p_assessment_id AND published_at IS NULL;
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

CREATE OR REPLACE FUNCTION public.request_result_correction(p_grade_id uuid, p_reason text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_staff_id uuid; v_id uuid;
BEGIN
  SELECT st.staffid INTO v_staff_id FROM public.staff st WHERE st.userid = auth.uid();
  IF v_staff_id IS NULL OR NOT public.has_app_role('TEACHER') THEN
    RAISE EXCEPTION 'Only a Teacher may request a result correction';
  END IF;
  INSERT INTO public.result_correction_requests(grade_id, requested_by, reason, old_score)
  SELECT g.gradeid, v_staff_id, btrim(p_reason), g.score
  FROM public.grade g
  WHERE g.gradeid = p_grade_id AND g.published_at IS NOT NULL
  RETURNING correction_request_id INTO v_id;
  IF v_id IS NULL THEN RAISE EXCEPTION 'Only a published grade may be corrected'; END IF;
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.decide_result_correction(
  p_request_id uuid, p_approved boolean, p_reason text DEFAULT NULL
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_staff_id uuid; v_status text;
BEGIN
  SELECT st.staffid INTO v_staff_id FROM public.staff st WHERE st.userid = auth.uid();
  IF v_staff_id IS NULL OR NOT (public.has_app_role('HEAD_TEACHER') OR public.has_app_role('SUPER_USER')) THEN
    RAISE EXCEPTION 'Only a Head Teacher or Super User may decide corrections';
  END IF;
  v_status := CASE WHEN p_approved THEN 'APPROVED' ELSE 'REJECTED' END;
  UPDATE public.result_correction_requests
  SET status = v_status, approved_by = v_staff_id, decision_reason = nullif(btrim(p_reason), ''), decided_at = now()
  WHERE correction_request_id = p_request_id AND status = 'PENDING';
  IF NOT FOUND THEN RAISE EXCEPTION 'Correction request is missing or already decided'; END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.complete_result_correction(p_request_id uuid, p_new_score numeric)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_staff_id uuid; v_grade_id uuid; v_max numeric;
BEGIN
  SELECT st.staffid INTO v_staff_id FROM public.staff st WHERE st.userid = auth.uid();
  IF v_staff_id IS NULL OR NOT public.has_app_role('TEACHER') THEN RAISE EXCEPTION 'Only a Teacher may complete a correction'; END IF;
  SELECT r.grade_id, a.maxscore INTO v_grade_id, v_max
  FROM public.result_correction_requests r JOIN public.grade g ON g.gradeid = r.grade_id
  JOIN public.assessment a ON a.assessmentid = g.assessmentid
  WHERE r.correction_request_id = p_request_id AND r.requested_by = v_staff_id AND r.status = 'APPROVED';
  IF v_grade_id IS NULL THEN RAISE EXCEPTION 'Approved correction request not found'; END IF;
  IF p_new_score IS NOT NULL AND (p_new_score < 0 OR p_new_score > v_max) THEN RAISE EXCEPTION 'Corrected score is outside the assessment range'; END IF;
  UPDATE public.grade SET score = p_new_score, submissionstatus = 'DRAFT', published_at = NULL, published_by = NULL
  WHERE gradeid = v_grade_id;
  UPDATE public.result_correction_requests SET new_score = p_new_score, status = 'COMPLETED', completed_at = now()
  WHERE correction_request_id = p_request_id;
END;
$$;

ALTER TABLE public.result_correction_requests ENABLE ROW LEVEL SECURITY;
CREATE POLICY result_corrections_read ON public.result_correction_requests FOR SELECT TO authenticated
USING (public.has_app_role('SUPER_USER') OR public.has_app_role('HEAD_TEACHER') OR
  EXISTS (SELECT 1 FROM public.staff st WHERE st.staffid = requested_by AND st.userid = auth.uid()));
GRANT SELECT ON public.result_correction_requests TO authenticated;
REVOKE ALL ON FUNCTION public.publish_assessment_results(uuid), public.request_result_correction(uuid, text),
  public.decide_result_correction(uuid, boolean, text), public.complete_result_correction(uuid, numeric) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.publish_assessment_results(uuid), public.request_result_correction(uuid, text),
  public.decide_result_correction(uuid, boolean, text), public.complete_result_correction(uuid, numeric) TO authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
