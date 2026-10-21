-- Keep annual progression evidence inside the learner's source form calendar
-- and use the renamed class columns when creating the next placement.
BEGIN;
CREATE OR REPLACE FUNCTION public.calculate_student_annual_result(
  p_student_id uuid,
  p_school_year integer
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_rule public.progressionrule%ROWTYPE;
  v_form text;
  v_terms jsonb := '[]'::jsonb;
  v_missing jsonb := '[]'::jsonb;
  v_term record;
  v_subject record;
  v_term_sum numeric := 0;
  v_term_count integer := 0;
  v_enrolled boolean;
  v_subject_score numeric;
  v_subject_max numeric;
  v_term_average numeric;
  v_annual numeric;
BEGIN
  SELECT * INTO v_rule
  FROM public.progressionrule
  WHERE active
  ORDER BY createdat DESC
  LIMIT 1;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'No active progression rule is configured';
  END IF;

  SELECT c.form::text INTO v_form
  FROM public.studentclasshistory h
  JOIN public.class c ON c.classid = h.classid
  JOIN public.academicyear ay ON ay.academicyearid = h.academicyearid
  WHERE h.studentid = p_student_id
    AND ay.academicyear = p_school_year
  ORDER BY h.enrollmentdate DESC
  LIMIT 1;

  IF v_form IS NULL THEN
    RAISE EXCEPTION 'No class placement exists for this learner in %', p_school_year;
  END IF;

  FOR v_term IN
    SELECT academicyearid, term, startdate, enddate
    FROM public.academicyear
    WHERE academicyear = p_school_year
      AND form = v_form
    ORDER BY CASE term WHEN 'TERM_1' THEN 1 WHEN 'TERM_2' THEN 2 ELSE 3 END
  LOOP
    SELECT EXISTS (
      SELECT 1
      FROM public.studentclasshistory h
      JOIN public.class c ON c.classid = h.classid
      WHERE h.studentid = p_student_id
        AND c.form::text = v_form
        AND h.enrollmentdate <= v_term.enddate
        AND (h.enddate IS NULL OR h.enddate >= v_term.startdate)
    ) INTO v_enrolled;

    IF NOT v_enrolled THEN
      v_terms := v_terms || jsonb_build_array(jsonb_build_object(
        'term', v_term.term,
        'enrolled', false,
        'average', null
      ));
      CONTINUE;
    END IF;

    v_term_sum := 0;
    v_term_count := 0;
    FOR v_subject IN
      SELECT DISTINCT cs.classsubjectid, s.subjectname
      FROM public.studentsubject ss
      JOIN public.classsubject cs ON cs.classsubjectid = ss.classsubjectid
      JOIN public.subject s ON s.subjectid = cs.subjectid
      WHERE ss.studentid = p_student_id
        AND cs.academicyearid = v_term.academicyearid
    LOOP
      SELECT sum(g.score), sum(a.maxscore)
      INTO v_subject_score, v_subject_max
      FROM public.grade g
      JOIN public.assessment a ON a.assessmentid = g.assessmentid
      WHERE g.studentid = p_student_id
        AND a.classsubjectid = v_subject.classsubjectid
        AND g.submissionstatus = 'SUBMITTED'
        AND g.gradestatus = 'PRESENT'
        AND g.score IS NOT NULL;

      IF v_subject_max IS NULL OR v_subject_max = 0 THEN
        v_missing := v_missing || jsonb_build_array(jsonb_build_object(
          'term', v_term.term,
          'subject', v_subject.subjectname,
          'reason', 'No submitted result'
        ));
      ELSE
        v_term_sum := v_term_sum + (v_subject_score / v_subject_max * 100);
        v_term_count := v_term_count + 1;
      END IF;
    END LOOP;

    IF v_term_count = 0 THEN
      v_missing := v_missing || jsonb_build_array(jsonb_build_object(
        'term', v_term.term,
        'reason', 'No eligible submitted subject results'
      ));
      v_term_average := NULL;
    ELSE
      v_term_average := round(v_term_sum / v_term_count, 2);
    END IF;
    v_terms := v_terms || jsonb_build_array(jsonb_build_object(
      'term', v_term.term,
      'enrolled', true,
      'average', v_term_average
    ));
  END LOOP;

  IF jsonb_array_length(v_terms) = 0 THEN
    RAISE EXCEPTION 'No academic periods are configured for % in %', v_form, p_school_year;
  END IF;

  SELECT round(avg((value->>'average')::numeric), 2) INTO v_annual
  FROM jsonb_array_elements(v_terms) value
  WHERE (value->>'enrolled')::boolean
    AND value->>'average' IS NOT NULL;

  RETURN jsonb_build_object(
    'studentId', p_student_id,
    'schoolYear', p_school_year,
    'form', v_form,
    'terms', v_terms,
    'missing', v_missing,
    'complete', jsonb_array_length(v_missing) = 0 AND v_annual IS NOT NULL,
    'annualAverage', v_annual,
    'passThreshold', v_rule.passpercentage,
    'ruleVersion', v_rule.version,
    'recommendation', CASE
      WHEN jsonb_array_length(v_missing) > 0 OR v_annual IS NULL THEN 'INCOMPLETE'
      WHEN v_annual >= v_rule.passpercentage THEN 'PROMOTE'
      ELSE 'RETAIN'
    END
  );
END $$;
CREATE OR REPLACE FUNCTION public.refresh_progression_review(
  p_student_id uuid,
  p_school_year integer
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_result jsonb;
  v_period uuid;
  v_review uuid;
BEGIN
  v_result := public.calculate_student_annual_result(p_student_id, p_school_year);
  SELECT academicyearid INTO v_period
  FROM public.academicyear
  WHERE academicyear = p_school_year
    AND form = v_result->>'form'
  ORDER BY CASE term WHEN 'TERM_3' THEN 1 WHEN 'TERM_2' THEN 2 ELSE 3 END
  LIMIT 1;

  IF NOT (v_result->>'complete')::boolean THEN
    RETURN v_result;
  END IF;

  SELECT reviewid INTO v_review
  FROM public.progressionreview
  WHERE studentid = p_student_id AND schoolyear = p_school_year
  FOR UPDATE;

  IF v_review IS NULL THEN
    INSERT INTO public.progressionreview(
      studentid, academicyearid, schoolyear, averagescore, decision,
      calculationsnapshot
    ) VALUES (
      p_student_id, v_period, p_school_year,
      (v_result->>'annualAverage')::numeric, 'PENDING', v_result
    ) RETURNING reviewid INTO v_review;
  ELSE
    UPDATE public.progressionreview
    SET averagescore = (v_result->>'annualAverage')::numeric,
        calculationsnapshot = v_result,
        updatedat = now()
    WHERE reviewid = v_review AND decision = 'PENDING';
  END IF;
  RETURN v_result || jsonb_build_object('reviewId', v_review);
END $$;
CREATE OR REPLACE FUNCTION public.decide_and_place_student(
  p_review_id uuid,
  p_decision text,
  p_target_period_id uuid,
  p_reason text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
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
    auth.uid(), p_review_id::text, public.current_app_role(),
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
END $$;
REVOKE ALL ON FUNCTION public.decide_and_place_student(uuid, text, uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.calculate_student_annual_result(uuid, integer),
  public.refresh_progression_review(uuid, integer),
  public.decide_and_place_student(uuid, text, uuid, text) TO authenticated;
NOTIFY pgrst, 'reload schema';
COMMIT;
