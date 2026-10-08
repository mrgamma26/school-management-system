-- Trusted three-term progression. This is forward-only and keeps the legacy
-- grade attendance status separate from the new grade submission state.
BEGIN;

DO $$ BEGIN
  CREATE TYPE public.grade_submission_status AS ENUM ('DRAFT', 'SUBMITTED');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- The legacy enum cannot be safely extended and used in one forward migration.
-- Convert the column to the canonical text values instead.
ALTER TABLE public.progressionreview
  ALTER COLUMN decision TYPE text USING CASE decision::text
    WHEN 'APPROVED' THEN 'PROMOTED'
    WHEN 'REJECTED' THEN 'RETAINED'
    ELSE decision::text
  END;
ALTER TABLE public.progressionreview
  DROP CONSTRAINT IF EXISTS progressionreview_decision_check,
  ADD CONSTRAINT progressionreview_decision_check
    CHECK (decision IN ('PENDING', 'PROMOTED', 'RETAINED'));

ALTER TABLE public.grade
  ADD COLUMN IF NOT EXISTS submissionstatus public.grade_submission_status NOT NULL DEFAULT 'DRAFT';

ALTER TABLE public.progressionreview
  ADD COLUMN IF NOT EXISTS schoolyear integer,
  ADD COLUMN IF NOT EXISTS decisionreason text,
  ADD COLUMN IF NOT EXISTS decisiondate timestamptz,
  ADD COLUMN IF NOT EXISTS calculationsnapshot jsonb,
  ADD COLUMN IF NOT EXISTS targetacademicyearid uuid REFERENCES public.academicyear(academicyearid),
  ADD COLUMN IF NOT EXISTS targetclassid uuid REFERENCES public.class(classid);

-- Existing rows remain historical term reviews. New annual rows are unique.
CREATE UNIQUE INDEX IF NOT EXISTS uq_progressionreview_annual
  ON public.progressionreview(studentid, schoolyear)
  WHERE schoolyear IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uq_active_class_placement
  ON public.studentclasshistory(studentid, academicyearid)
  WHERE enddate IS NULL;

CREATE TABLE IF NOT EXISTS public.progressionrule (
  ruleid uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  passpercentage numeric(5,2) NOT NULL DEFAULT 50 CHECK (passpercentage BETWEEN 0 AND 100),
  version text NOT NULL DEFAULT 'v1',
  active boolean NOT NULL DEFAULT true,
  createdat timestamptz NOT NULL DEFAULT now()
);
INSERT INTO public.progressionrule (passpercentage, version)
SELECT 50, 'v1'
WHERE NOT EXISTS (SELECT 1 FROM public.progressionrule WHERE active);

-- The result is a JSON document so Flutter cannot alter calculation evidence.
CREATE OR REPLACE FUNCTION public.calculate_student_annual_result(
  p_student_id uuid,
  p_school_year integer
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_rule public.progressionrule%ROWTYPE;
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
  SELECT * INTO v_rule FROM public.progressionrule WHERE active ORDER BY createdat DESC LIMIT 1;
  IF NOT FOUND THEN RAISE EXCEPTION 'No active progression rule is configured'; END IF;

  FOR v_term IN
    SELECT academicyearid, term, startdate, enddate
    FROM public.academicyear WHERE academicyear = p_school_year
    ORDER BY CASE term WHEN 'TERM_1' THEN 1 WHEN 'TERM_2' THEN 2 ELSE 3 END
  LOOP
    SELECT EXISTS (
      SELECT 1 FROM public.studentclasshistory h
      WHERE h.studentid = p_student_id
        AND h.enrollmentdate <= v_term.enddate
        AND (h.enddate IS NULL OR h.enddate >= v_term.startdate)
    ) INTO v_enrolled;

    IF NOT v_enrolled THEN
      v_terms := v_terms || jsonb_build_array(jsonb_build_object('term', v_term.term, 'enrolled', false, 'average', null));
      CONTINUE;
    END IF;

    v_term_sum := 0; v_term_count := 0;
    FOR v_subject IN
      SELECT DISTINCT cs.classsubjectid, s.subjectname
      FROM public.studentsubject ss
      JOIN public.classsubject cs ON cs.classsubjectid = ss.classsubjectid
      JOIN public.subject s ON s.subjectid = cs.subjectid
      WHERE ss.studentid = p_student_id AND cs.academicyearid = v_term.academicyearid
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
        v_missing := v_missing || jsonb_build_array(jsonb_build_object('term', v_term.term, 'subject', v_subject.subjectname, 'reason', 'No submitted result'));
      ELSE
        v_term_sum := v_term_sum + (v_subject_score / v_subject_max * 100);
        v_term_count := v_term_count + 1;
      END IF;
    END LOOP;
    IF v_term_count = 0 THEN
      v_missing := v_missing || jsonb_build_array(jsonb_build_object('term', v_term.term, 'reason', 'No eligible submitted subject results'));
      v_term_average := NULL;
    ELSE
      v_term_average := round(v_term_sum / v_term_count, 2);
    END IF;
    v_terms := v_terms || jsonb_build_array(jsonb_build_object('term', v_term.term, 'enrolled', true, 'average', v_term_average));
  END LOOP;

  SELECT round(avg((value->>'average')::numeric), 2) INTO v_annual
  FROM jsonb_array_elements(v_terms) value
  WHERE (value->>'enrolled')::boolean AND value->>'average' IS NOT NULL;

  RETURN jsonb_build_object(
    'studentId', p_student_id, 'schoolYear', p_school_year, 'terms', v_terms,
    'missing', v_missing, 'complete', jsonb_array_length(v_missing) = 0 AND v_annual IS NOT NULL,
    'annualAverage', v_annual, 'passThreshold', v_rule.passpercentage,
    'ruleVersion', v_rule.version,
    'recommendation', CASE WHEN jsonb_array_length(v_missing) > 0 OR v_annual IS NULL THEN 'INCOMPLETE'
      WHEN v_annual >= v_rule.passpercentage THEN 'PROMOTE' ELSE 'RETAIN' END
  );
END $$;

CREATE OR REPLACE FUNCTION public.refresh_progression_review(p_student_id uuid, p_school_year integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_result jsonb; v_period uuid; v_review uuid;
BEGIN
  v_result := public.calculate_student_annual_result(p_student_id, p_school_year);
  SELECT academicyearid INTO v_period FROM public.academicyear
    WHERE academicyear = p_school_year ORDER BY CASE term WHEN 'TERM_3' THEN 1 ELSE 2 END LIMIT 1;
  IF NOT (v_result->>'complete')::boolean THEN RETURN v_result; END IF;
  SELECT reviewid INTO v_review FROM public.progressionreview
    WHERE studentid = p_student_id AND schoolyear = p_school_year FOR UPDATE;
  IF v_review IS NULL THEN
    INSERT INTO public.progressionreview(studentid, academicyearid, schoolyear, averagescore, decision, calculationsnapshot)
    VALUES (p_student_id, v_period, p_school_year, (v_result->>'annualAverage')::numeric, 'PENDING', v_result)
    RETURNING reviewid INTO v_review;
  ELSE
    UPDATE public.progressionreview SET averagescore = (v_result->>'annualAverage')::numeric,
      calculationsnapshot = v_result, updatedat = now()
      WHERE reviewid = v_review AND decision = 'PENDING';
  END IF;
  RETURN v_result || jsonb_build_object('reviewId', v_review);
END $$;

CREATE OR REPLACE FUNCTION public.decide_and_place_student(
  p_review_id uuid, p_decision text, p_target_period_id uuid, p_reason text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_review public.progressionreview%ROWTYPE; v_actor uuid; v_target_class uuid; v_current public.studentclasshistory%ROWTYPE; v_target_year integer;
BEGIN
  IF upper(coalesce(public.current_app_role(), '')) NOT IN ('HEAD_TEACHER', 'SUPER_USER', 'SYSTEM_ADMIN') THEN
    RAISE EXCEPTION 'Only a Head Teacher may decide progression';
  END IF;
  IF p_decision NOT IN ('PROMOTED', 'RETAINED') OR nullif(trim(p_reason), '') IS NULL THEN RAISE EXCEPTION 'Decision and reason are required'; END IF;
  SELECT * INTO v_review FROM public.progressionreview WHERE reviewid = p_review_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Progression review not found'; END IF;
  IF v_review.decision <> 'PENDING' THEN RETURN jsonb_build_object('reviewId', p_review_id, 'decision', v_review.decision, 'alreadyDecided', true); END IF;
  IF NOT (public.calculate_student_annual_result(v_review.studentid, v_review.schoolyear)->>'complete')::boolean THEN RAISE EXCEPTION 'Results are incomplete'; END IF;
  SELECT staffid INTO v_actor FROM public.staff WHERE userid = auth.uid();
  SELECT * INTO v_current FROM public.studentclasshistory WHERE studentid = v_review.studentid AND enddate IS NULL ORDER BY enrollmentdate DESC LIMIT 1 FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'No active class placement exists'; END IF;
  IF p_decision = 'PROMOTED' THEN
    SELECT academicyear INTO v_target_year FROM public.academicyear WHERE academicyearid = p_target_period_id;
    SELECT c.classid INTO v_target_class FROM public.class c WHERE c.formlevel = (SELECT formlevel + 1 FROM public.class WHERE classid = v_current.classid) ORDER BY classname LIMIT 1;
    IF v_target_class IS NULL THEN RAISE EXCEPTION 'No next-form class is configured'; END IF;
    UPDATE public.studentclasshistory SET enddate = current_date WHERE historyid = v_current.historyid;
    INSERT INTO public.studentclasshistory(studentid, classid, academicyearid, enrollmentdate) VALUES (v_review.studentid, v_target_class, p_target_period_id, current_date);
    INSERT INTO public.studentsubject(studentid, classsubjectid)
      SELECT v_review.studentid, classsubjectid FROM public.classsubject WHERE classid = v_target_class AND academicyearid = p_target_period_id
      ON CONFLICT DO NOTHING;
  END IF;
  UPDATE public.progressionreview SET decision = p_decision, approvedby = v_actor, decisionreason = trim(p_reason), decisiondate = now(), targetacademicyearid = p_target_period_id, targetclassid = v_target_class WHERE reviewid = p_review_id;
  INSERT INTO public.auditlog(userid, recordid, usertype, action, tablename, newvalue, reason)
    VALUES (auth.uid(), p_review_id::text, public.current_app_role(), 'PROGRESSION_' || p_decision, 'progressionreview', jsonb_build_object('oldClassId', v_current.classid, 'newClassId', v_target_class, 'annualAverage', v_review.averagescore), p_reason);
  RETURN jsonb_build_object('reviewId', p_review_id, 'decision', p_decision, 'targetClassId', v_target_class);
END $$;

REVOKE ALL ON FUNCTION public.decide_and_place_student(uuid, text, uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.calculate_student_annual_result(uuid, integer), public.refresh_progression_review(uuid, integer), public.decide_and_place_student(uuid, text, uuid, text) TO authenticated;
NOTIFY pgrst, 'reload schema';
COMMIT;
