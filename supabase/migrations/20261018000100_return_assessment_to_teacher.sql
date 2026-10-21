-- Head Teacher "Return with reason": send a SUBMITTED, unpublished result sheet
-- back to the teacher as DRAFT so the marks can be corrected and resubmitted.
--
--   * RPC public.return_assessment_to_teacher(p_assessment_id, p_reason)
--   * append-only table public.assessment_returns (who returned what, and why)
--   * audit row + an in-app notification to the assessment's teacher
--
-- Authorisation matches publish_assessment_results (Head Teacher or Super
-- User), but through a private helper so the rule lives in one place.
-- Published marks are never touched: prevent_published_grade_mutation() only
-- guards rows with published_at set, and this RPC only updates rows where
-- published_at IS NULL. Idempotent: safe to run twice.
BEGIN;

-- ------------------------------------------------------------------ helpers
CREATE OR REPLACE FUNCTION private.can_review_results()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT public.current_user_is_active()
    AND (public.has_app_role('HEAD_TEACHER') OR public.has_app_role('SUPER_USER'))
$$;

CREATE OR REPLACE FUNCTION private.is_assessment_teacher(p_assessment_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT public.current_user_is_active()
    AND EXISTS (
      SELECT 1
      FROM public.assessment a
      JOIN public.classsubject cs ON cs.classsubjectid = a.classsubjectid
      JOIN public.staff st ON st.staffid = cs.staffid
      WHERE a.assessmentid = p_assessment_id
        AND st.userid = (SELECT auth.uid())
    )
$$;

REVOKE ALL ON FUNCTION private.can_review_results() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION private.is_assessment_teacher(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.can_review_results() TO authenticated;
GRANT EXECUTE ON FUNCTION private.is_assessment_teacher(uuid) TO authenticated;

-- ---------------------------------------------------------- append-only log
CREATE TABLE IF NOT EXISTS public.assessment_returns (
  return_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  assessment_id uuid NOT NULL
    REFERENCES public.assessment(assessmentid) ON DELETE RESTRICT,
  returned_by uuid NOT NULL
    REFERENCES public.systemuser(userid) ON DELETE RESTRICT,
  reason text NOT NULL
    CHECK (char_length(btrim(reason)) >= 10 AND char_length(reason) <= 500),
  grades_returned integer NOT NULL CHECK (grades_returned > 0),
  returned_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS assessment_returns_assessment_idx
  ON public.assessment_returns (assessment_id, returned_at DESC);

CREATE OR REPLACE FUNCTION public.prevent_assessment_return_change()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  RAISE EXCEPTION 'Assessment return history is append-only';
END;
$$;
REVOKE ALL ON FUNCTION public.prevent_assessment_return_change()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS assessment_returns_immutable ON public.assessment_returns;
CREATE TRIGGER assessment_returns_immutable
BEFORE UPDATE OR DELETE ON public.assessment_returns
FOR EACH ROW EXECUTE FUNCTION public.prevent_assessment_return_change();

ALTER TABLE public.assessment_returns ENABLE ROW LEVEL SECURITY;

-- Readable by the Head Teacher / Super User and by the teacher of that
-- assessment. There is deliberately no INSERT/UPDATE/DELETE policy: rows are
-- written only by the SECURITY DEFINER RPC below.
DROP POLICY IF EXISTS assessment_returns_read ON public.assessment_returns;
CREATE POLICY assessment_returns_read ON public.assessment_returns
FOR SELECT TO authenticated
USING (
  private.can_review_results()
  OR private.is_assessment_teacher(assessment_id)
);

REVOKE ALL ON public.assessment_returns FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.assessment_returns TO authenticated;

-- --------------------------------------------------------------------- RPC
CREATE OR REPLACE FUNCTION public.return_assessment_to_teacher(
  p_assessment_id uuid,
  p_reason text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_actor uuid := auth.uid();
  v_reason text := btrim(coalesce(p_reason, ''));
  v_actor_staff uuid;
  v_teacher_user uuid;
  v_name text;
  v_return_id uuid;
  v_count integer;
  v_notified boolean := false;
BEGIN
  IF v_actor IS NULL OR NOT private.can_review_results() THEN
    RAISE EXCEPTION 'Only a Head Teacher or Super User may return results to a teacher';
  END IF;
  IF char_length(v_reason) < 10 THEN
    RAISE EXCEPTION 'Give the teacher a reason of at least 10 characters';
  END IF;
  IF char_length(v_reason) > 500 THEN
    RAISE EXCEPTION 'The reason must be 500 characters or fewer';
  END IF;

  -- Lock the assessment so two reviewers cannot decide the same sheet at once.
  SELECT a.assessmentname, st.userid
    INTO v_name, v_teacher_user
  FROM public.assessment a
  LEFT JOIN public.classsubject cs ON cs.classsubjectid = a.classsubjectid
  LEFT JOIN public.staff st ON st.staffid = cs.staffid
  WHERE a.assessmentid = p_assessment_id
  FOR UPDATE OF a;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Assessment not found';
  END IF;

  -- Only SUBMITTED, unpublished marks go back. Published rows are untouched,
  -- so prevent_published_grade_mutation() is never involved.
  UPDATE public.grade
  SET submissionstatus = 'DRAFT'
  WHERE assessmentid = p_assessment_id
    AND submissionstatus = 'SUBMITTED'
    AND published_at IS NULL;
  GET DIAGNOSTICS v_count = ROW_COUNT;
  IF v_count = 0 THEN
    RAISE EXCEPTION 'This assessment has no submitted, unpublished marks to return';
  END IF;

  INSERT INTO public.assessment_returns(assessment_id, returned_by, reason, grades_returned)
  VALUES (p_assessment_id, v_actor, v_reason, v_count)
  RETURNING return_id INTO v_return_id;

  INSERT INTO public.auditlog(userid, recordid, actorrole, action, tablename, newvalue, reason)
  VALUES (
    v_actor, p_assessment_id, public.current_app_role(),
    'RESULTS_RETURNED_TO_TEACHER', 'assessment_returns',
    jsonb_build_object(
      'returnId', v_return_id,
      'assessmentId', p_assessment_id,
      'gradesReturned', v_count
    ),
    v_reason
  );

  -- In-app notification for the teacher. It uses the same columns and
  -- de-duplication key as private.enqueue_outcome_notifications(). A failure
  -- here must never undo the return, so it runs in its own sub-transaction.
  IF v_teacher_user IS NOT NULL THEN
    SELECT st.staffid INTO v_actor_staff
    FROM public.staff st WHERE st.userid = v_actor;
    BEGIN
      INSERT INTO public.notification(
        recipientuserid, guardianid, sentby, eventkey, subject, message,
        emailstatus, readstatus, sentat
      ) VALUES (
        v_teacher_user, NULL, v_actor_staff,
        'assessment-return:' || v_return_id::text,
        left('Result sheet returned: ' || coalesce(v_name, 'assessment'), 255),
        'Your result sheet "' || coalesce(v_name, 'assessment') || '" was returned '
          || 'for correction (' || v_count::text || ' mark(s) are drafts again). '
          || 'Reason: ' || v_reason,
        'NOT_APPLICABLE', 'UNREAD', now()
      );
      v_notified := true;
    EXCEPTION WHEN OTHERS THEN
      v_notified := false;
    END;
  END IF;

  RETURN jsonb_build_object(
    'returnId', v_return_id,
    'gradesReturned', v_count,
    'teacherNotified', v_notified
  );
END;
$$;

REVOKE ALL ON FUNCTION public.return_assessment_to_teacher(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.return_assessment_to_teacher(uuid, text) TO authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
