-- Handbook: a Guardian cannot see results or report-card content while the
-- linked student has an outstanding fee balance, and only PUBLISHED marks are
-- ever visible. Enforced in RLS (not just hidden in the UI).
--
-- balance = applicable fees - non-reversed payments + adjustments
-- (same convention as FinanceRepository.outstandingBalance in the app).
BEGIN;

CREATE OR REPLACE FUNCTION private.student_outstanding_balance(p_student_id uuid)
RETURNS numeric
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT
    COALESCE((
      SELECT sum(f.amount)
      FROM public.feestructure f
      WHERE EXISTS (
        SELECT 1 FROM public.studentclasshistory h
        WHERE h.studentid = p_student_id
          AND h.academicyearid = f.academicyearid
          AND (f.classid IS NULL OR f.classid = h.classid)
      )
    ), 0)
    - COALESCE((
      SELECT sum(p.amount)
      FROM public.payment p
      WHERE p.studentid = p_student_id
        AND NOT EXISTS (
          SELECT 1 FROM public.payment_reversals r WHERE r.payment_id = p.paymentid
        )
    ), 0)
    + COALESCE((
      SELECT sum(a.amount)
      FROM public.financialadjustment a
      WHERE a.studentid = p_student_id
    ), 0)
$$;

CREATE OR REPLACE FUNCTION private.guardian_can_view_results(p_student_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT private.guardian_is_linked_to_student(p_student_id)
    AND private.student_outstanding_balance(p_student_id) <= 0
$$;

REVOKE ALL ON FUNCTION private.student_outstanding_balance(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION private.guardian_can_view_results(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.student_outstanding_balance(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION private.guardian_can_view_results(uuid) TO authenticated;

-- Safe RPC for the Guardian screens: says whether results are open and, if
-- not, the amount owed. Returns no marks.
CREATE OR REPLACE FUNCTION public.get_guardian_report_access(p_student_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE v_balance numeric;
BEGIN
  IF NOT private.guardian_is_linked_to_student(p_student_id) THEN
    RAISE EXCEPTION 'Student is not linked to this account' USING ERRCODE = '42501';
  END IF;
  v_balance := private.student_outstanding_balance(p_student_id);
  RETURN jsonb_build_object(
    'allowed', v_balance <= 0,
    'outstandingBalance', greatest(v_balance, 0),
    'message', CASE WHEN v_balance > 0
      THEN 'Pay the balance to view the report card' ELSE NULL END
  );
END;
$$;
REVOKE ALL ON FUNCTION public.get_guardian_report_access(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_guardian_report_access(uuid) TO authenticated;

-- Results: published marks only, and only when the balance is cleared.
DROP POLICY IF EXISTS "guardians read grades for their students" ON public.grade;
CREATE POLICY "guardians read grades for their students"
ON public.grade FOR SELECT TO authenticated
USING (
  published_at IS NOT NULL
  AND private.guardian_can_view_results(studentid)
);

DROP POLICY IF EXISTS "guardians see linked student comments" ON public.teachercomment;
CREATE POLICY "guardians see linked student comments"
ON public.teachercomment FOR SELECT TO authenticated
USING (private.guardian_can_view_results(studentid));

DROP POLICY IF EXISTS "guardians view linked progression reviews" ON public.progressionreview;
CREATE POLICY "guardians view linked progression reviews"
ON public.progressionreview FOR SELECT TO authenticated
USING (private.guardian_can_view_results(studentid));

-- Assessment metadata is only visible through a grade the Guardian may see.
CREATE OR REPLACE FUNCTION private.guardian_can_read_assessment(p_assessment_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT public.current_user_is_active()
    AND EXISTS (
      SELECT 1
      FROM public.grade linked_grade
      WHERE linked_grade.assessmentid = p_assessment_id
        AND linked_grade.published_at IS NOT NULL
        AND private.guardian_can_view_results(linked_grade.studentid)
    )
$$;

NOTIFY pgrst, 'reload schema';
COMMIT;
