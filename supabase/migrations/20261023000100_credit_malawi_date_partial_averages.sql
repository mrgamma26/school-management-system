-- 1. Malawi calendar date (Africa/Blantyre) instead of the UTC date for
--    arrangement MISSED status, receipt numbers and placement end dates.
-- 2. Mother and Father as guardian relationships.
-- 3. Annual results record the average so far (terms with results), and a
--    progression review is stored even before all three terms are complete.
--    Promotion decisions still require complete results.

DO $mig$
DECLARE
  d text;
BEGIN
  d := pg_get_functiondef('public.refresh_payment_arrangement(uuid)'::regprocedure);
  d := replace(d, 'o.due_date < current_date', 'o.due_date < (now() AT TIME ZONE ''Africa/Blantyre'')::date');
  EXECUTE d;

  d := pg_get_functiondef('public.record_payment_v2(uuid,uuid,numeric,date,text,uuid,text,numeric,jsonb)'::regprocedure);
  d := replace(d, 'to_char(current_date, ''YYYY'')', 'to_char((now() AT TIME ZONE ''Africa/Blantyre'')::date, ''YYYY'')');
  EXECUTE d;

  d := pg_get_functiondef('public.close_current_class_placement(uuid)'::regprocedure);
  d := replace(d, 'enddate   = CURRENT_DATE', 'enddate   = (now() AT TIME ZONE ''Africa/Blantyre'')::date');
  EXECUTE d;

  d := pg_get_functiondef('public.admit_student(jsonb,jsonb,uuid,uuid)'::regprocedure);
  d := replace(d, '''UNCLE/AUNT'', ''OTHER'')', '''UNCLE/AUNT'', ''MOTHER'', ''FATHER'', ''OTHER'')');
  IF position('''MOTHER''' IN d) = 0 THEN
    RAISE EXCEPTION 'admit_student relationship list not found';
  END IF;
  EXECUTE d;
END
$mig$;

CREATE OR REPLACE FUNCTION private.calculate_student_annual_result(p_student_id uuid, p_school_year integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_rule public.progressionrule%ROWTYPE;
  v_form text;
  v_terms jsonb := '[]'::jsonb;
  v_missing jsonb := '[]'::jsonb;
  v_term record;
  v_subject record;
  v_class_id uuid;
  v_required_subjects integer;
  v_assessment_count integer;
  v_valid_grade_count integer;
  v_subject_score numeric;
  v_subject_max numeric;
  v_term_sum numeric;
  v_term_subjects integer;
  v_term_complete boolean;
  v_term_average numeric;
  v_annual numeric;
  v_period_count integer;
  v_so_far numeric;
  v_terms_with_results integer;
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
  ORDER BY CASE ay.term::text
    WHEN 'TERM_3' THEN 1 WHEN 'TERM_2' THEN 2 ELSE 3 END
  LIMIT 1;

  IF v_form IS NULL THEN
    RAISE EXCEPTION 'No class placement exists for this learner in %',
      p_school_year;
  END IF;

  SELECT count(*) INTO v_period_count
  FROM public.academicyear ay
  WHERE ay.academicyear = p_school_year
    AND ay.form = v_form
    AND ay.term::text IN ('TERM_1', 'TERM_2', 'TERM_3');

  IF v_period_count <> 3 THEN
    v_missing := v_missing || jsonb_build_array(jsonb_build_object(
      'reason', 'All three academic periods must be configured',
      'configuredPeriods', v_period_count
    ));
  END IF;

  FOR v_term IN
    SELECT ay.academicyearid, ay.term::text AS term,
      ay.startdate, ay.enddate
    FROM public.academicyear ay
    WHERE ay.academicyear = p_school_year
      AND ay.form = v_form
      AND ay.term::text IN ('TERM_1', 'TERM_2', 'TERM_3')
    ORDER BY CASE ay.term::text
      WHEN 'TERM_1' THEN 1 WHEN 'TERM_2' THEN 2 ELSE 3 END
  LOOP
    SELECT h.classid INTO v_class_id
    FROM public.studentclasshistory h
    WHERE h.studentid = p_student_id
      AND h.academicyearid = v_term.academicyearid
    LIMIT 1;

    IF v_class_id IS NULL THEN
      v_missing := v_missing || jsonb_build_array(jsonb_build_object(
        'term', v_term.term,
        'reason', 'No class enrollment for this term'
      ));
      v_terms := v_terms || jsonb_build_array(jsonb_build_object(
        'term', v_term.term,
        'enrolled', false,
        'average', null
      ));
      CONTINUE;
    END IF;

    v_term_sum := 0;
    v_term_subjects := 0;
    v_required_subjects := 0;
    v_term_complete := true;

    FOR v_subject IN
      SELECT cs.classsubjectid, s.subjectname
      FROM public.classsubject cs
      JOIN public.subject s ON s.subjectid = cs.subjectid
      WHERE cs.classid = v_class_id
        AND cs.academicyearid = v_term.academicyearid
      ORDER BY s.subjectname
    LOOP
      v_required_subjects := v_required_subjects + 1;

      IF NOT EXISTS (
        SELECT 1
        FROM public.studentsubject ss
        WHERE ss.studentid = p_student_id
          AND ss.classsubjectid = v_subject.classsubjectid
      ) THEN
        v_term_complete := false;
        v_missing := v_missing || jsonb_build_array(jsonb_build_object(
          'term', v_term.term,
          'subject', v_subject.subjectname,
          'reason', 'Student is not enrolled in this subject'
        ));
        CONTINUE;
      END IF;

      SELECT
        count(a.assessmentid)::integer,
        count(g.gradeid) FILTER (
          WHERE g.submissionstatus::text = 'SUBMITTED'
            AND g.gradestatus::text = 'PRESENT'
            AND g.score IS NOT NULL
        )::integer,
        sum(g.score) FILTER (
          WHERE g.submissionstatus::text = 'SUBMITTED'
            AND g.gradestatus::text = 'PRESENT'
            AND g.score IS NOT NULL
        ),
        sum(a.maxscore) FILTER (
          WHERE g.submissionstatus::text = 'SUBMITTED'
            AND g.gradestatus::text = 'PRESENT'
            AND g.score IS NOT NULL
        )
      INTO v_assessment_count, v_valid_grade_count,
        v_subject_score, v_subject_max
      FROM public.assessment a
      LEFT JOIN public.grade g
        ON g.assessmentid = a.assessmentid
       AND g.studentid = p_student_id
      WHERE a.classsubjectid = v_subject.classsubjectid;

      IF v_assessment_count = 0
         OR v_valid_grade_count <> v_assessment_count
         OR coalesce(v_subject_max, 0) = 0 THEN
        v_term_complete := false;
        v_missing := v_missing || jsonb_build_array(jsonb_build_object(
          'term', v_term.term,
          'subject', v_subject.subjectname,
          'reason', CASE WHEN v_assessment_count = 0
            THEN 'No assessment configured'
            ELSE 'A required grade is missing or not submitted' END
        ));
      ELSE
        v_term_sum := v_term_sum + (v_subject_score / v_subject_max * 100);
        v_term_subjects := v_term_subjects + 1;
      END IF;
    END LOOP;

    IF v_required_subjects = 0 THEN
      v_term_complete := false;
      v_missing := v_missing || jsonb_build_array(jsonb_build_object(
        'term', v_term.term,
        'reason', 'No class subjects are configured'
      ));
    END IF;

    -- Average of the subjects that have results, even when the term is
    -- not complete yet; 'complete' says whether it counts for promotion.
    v_term_average := CASE
      WHEN v_term_subjects > 0 THEN round(v_term_sum / v_term_subjects, 2)
      ELSE NULL
    END;
    v_terms := v_terms || jsonb_build_array(jsonb_build_object(
      'term', v_term.term,
      'enrolled', true,
      'average', v_term_average,
      'complete', v_term_complete AND v_term_subjects = v_required_subjects
        AND v_required_subjects > 0
    ));
  END LOOP;

  IF jsonb_array_length(v_missing) = 0
     AND jsonb_array_length(v_terms) = 3 THEN
    SELECT round(avg((item->>'average')::numeric), 2)
    INTO v_annual
    FROM jsonb_array_elements(v_terms) item;
  ELSE
    v_annual := NULL;
  END IF;

  SELECT round(avg((item->>'average')::numeric), 2), count(item->>'average')
  INTO v_so_far, v_terms_with_results
  FROM jsonb_array_elements(v_terms) item
  WHERE item->>'average' IS NOT NULL;

  RETURN jsonb_build_object(
    'averageSoFar', v_so_far,
    'termsWithResults', coalesce(v_terms_with_results, 0),
    'studentId', p_student_id,
    'schoolYear', p_school_year,
    'form', v_form,
    'terms', v_terms,
    'missing', v_missing,
    'complete', jsonb_array_length(v_missing) = 0
      AND jsonb_array_length(v_terms) = 3
      AND v_annual IS NOT NULL,
    'annualAverage', v_annual,
    'passThreshold', v_rule.passpercentage,
    'ruleVersion', v_rule.version,
    'recommendation', CASE
      WHEN jsonb_array_length(v_missing) > 0 OR v_annual IS NULL
        THEN 'INCOMPLETE'
      WHEN v_annual >= v_rule.passpercentage THEN 'PROMOTE'
      ELSE 'WEEDING_REVIEW'
    END
  );
END
$function$;

CREATE OR REPLACE FUNCTION private.refresh_progression_review(p_student_id uuid, p_school_year integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_result jsonb;
  v_period uuid;
  v_review uuid;
  v_average numeric;
BEGIN
  v_result := public.calculate_student_annual_result(p_student_id, p_school_year);
  SELECT academicyearid INTO v_period
  FROM public.academicyear
  WHERE academicyear = p_school_year
    AND form = v_result->>'form'
  ORDER BY CASE term WHEN 'TERM_3' THEN 1 WHEN 'TERM_2' THEN 2 ELSE 3 END
  LIMIT 1;

  -- Complete: the annual average. Incomplete: the average so far, so the
  -- term 1 and term 2 results are recorded before term 3 is finished.
  v_average := coalesce(
    (v_result->>'annualAverage')::numeric,
    (v_result->>'averageSoFar')::numeric
  );
  IF v_average IS NULL OR v_period IS NULL THEN
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
      p_student_id, v_period, p_school_year, v_average, 'PENDING', v_result
    ) RETURNING reviewid INTO v_review;
  ELSE
    UPDATE public.progressionreview
    SET averagescore = v_average,
        calculationsnapshot = v_result,
        updatedat = now()
    WHERE reviewid = v_review AND decision = 'PENDING';
  END IF;
  RETURN v_result || jsonb_build_object('reviewId', v_review);
END $function$;
