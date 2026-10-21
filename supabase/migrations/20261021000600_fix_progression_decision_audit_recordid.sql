-- decide_and_place_student wrote the review id into auditlog.recordid with a
-- ::text cast, but that column is uuid, so every Promote/Retain decision failed
-- with SQLSTATE 42804 ("column recordid is of type uuid but expression is of
-- type text") and the Head Teacher saw only "Something went wrong".
-- Same function as 0039_form_scoped_progression.sql with the cast removed.
BEGIN;
CREATE OR REPLACE FUNCTION public.decide_and_place_student(p_review_id uuid, p_decision text, p_target_period_id uuid, p_reason text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_review public.progressionreview%ROWTYPE;
  v_actor uuid;
  v_target_class uuid;
  v_current public.studentclasshistory%ROWTYPE;
  v_current_form text;
  v_next_form text;
  v_target_form text;
  v_target_start date;
BEGIN
  IF upper(coalesce(public.current_app_role(), '')) <> 'HEAD_TEACHER' THEN
    RAISE EXCEPTION 'Only a Head Teacher may decide progression';
  END IF;
  IF p_decision NOT IN ('PROMOTED', 'RETAINED')
     OR nullif(trim(p_reason), '') IS NULL THEN
    RAISE EXCEPTION 'Decision and reason are required';
  END IF;

  SELECT * INTO v_review
  FROM public.progressionreview
  WHERE reviewid = p_review_id
  FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Progression review not found'; END IF;
  IF v_review.decision <> 'PENDING' THEN
    RETURN jsonb_build_object(
      'reviewId', p_review_id,
      'decision', v_review.decision,
      'alreadyDecided', true
    );
  END IF;
  IF NOT (public.calculate_student_annual_result(
    v_review.studentid, v_review.schoolyear
  )->>'complete')::boolean THEN
    RAISE EXCEPTION 'Results are incomplete';
  END IF;

  SELECT staffid INTO v_actor FROM public.staff WHERE userid = auth.uid();
  SELECT h.* INTO v_current
  FROM public.studentclasshistory h
  WHERE h.studentid = v_review.studentid AND h.enddate IS NULL
  ORDER BY h.enrollmentdate DESC
  LIMIT 1
  FOR UPDATE OF h;
  IF NOT FOUND THEN RAISE EXCEPTION 'No active class placement exists'; END IF;

  SELECT c.form::text INTO v_current_form
  FROM public.class c
  WHERE c.classid = v_current.classid;

  IF p_decision = 'PROMOTED' THEN
    v_next_form := CASE v_current_form
      WHEN 'FORM_1' THEN 'FORM_2'
      WHEN 'FORM_2' THEN 'FORM_3'
      WHEN 'FORM_3' THEN 'FORM_4'
      ELSE NULL
    END;
    IF v_next_form IS NULL THEN
      RAISE EXCEPTION 'No next form exists after %', v_current_form;
    END IF;

    SELECT form, startdate INTO v_target_form, v_target_start
    FROM public.academicyear
    WHERE academicyearid = p_target_period_id AND term = 'TERM_1';
    IF v_target_form IS DISTINCT FROM v_next_form THEN
      RAISE EXCEPTION 'Target period must be % Term 1', v_next_form;
    END IF;

    SELECT c.classid INTO v_target_class
    FROM public.class c
    WHERE c.form::text = v_next_form
    ORDER BY c.classroomname
    LIMIT 1;
    IF v_target_class IS NULL THEN
      RAISE EXCEPTION 'No % class is configured', v_next_form;
    END IF;

    UPDATE public.studentclasshistory
    SET enddate = v_target_start - 1
    WHERE historyid = v_current.historyid;
    INSERT INTO public.studentclasshistory(
      studentid, classid, academicyearid, enrollmentdate
    ) VALUES (
      v_review.studentid, v_target_class, p_target_period_id, v_target_start
    );
    INSERT INTO public.studentsubject(studentid, classsubjectid)
      SELECT v_review.studentid, classsubjectid
      FROM public.classsubject
      WHERE classid = v_target_class
        AND academicyearid = p_target_period_id
      ON CONFLICT DO NOTHING;
  END IF;

  UPDATE public.progressionreview
  SET decision = p_decision,
      approvedby = v_actor,
      decisionreason = trim(p_reason),
      decisiondate = now(),
      targetacademicyearid = CASE WHEN p_decision = 'PROMOTED' THEN p_target_period_id END,
      targetclassid = v_target_class
  WHERE reviewid = p_review_id;

  INSERT INTO public.auditlog(
    userid, recordid, actorrole, action, tablename, newvalue, reason
  ) VALUES (
    auth.uid(), p_review_id, public.current_app_role(),
    'PROGRESSION_' || p_decision, 'progressionreview',
    jsonb_build_object(
      'oldClassId', v_current.classid,
      'newClassId', v_target_class,
      'annualAverage', v_review.averagescore
    ),
    trim(p_reason)
  );
  RETURN jsonb_build_object(
    'reviewId', p_review_id,
    'decision', p_decision,
    'targetClassId', v_target_class
  );
END $function$;
NOTIFY pgrst, 'reload schema';
COMMIT;
