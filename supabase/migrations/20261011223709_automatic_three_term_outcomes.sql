-- Complete the three-term enrollment and outcome workflow at the database
-- boundary. All multi-table operations are atomic and safe to retry.
BEGIN;
-- Keep internal calculation helpers outside the Data API. This migration is
-- self-contained because some hosted projects may not yet have applied the
-- earlier account-authorization migration that originally created it.
CREATE SCHEMA IF NOT EXISTS private;
REVOKE ALL ON SCHEMA private FROM PUBLIC;
-- The original baseline stored class.form as an integer, while deployed
-- databases and Flutter use FORM_1..FORM_4. Normalize both histories to the
-- canonical text contract before comparing classes with academic periods.
ALTER TABLE public.class
  ALTER COLUMN form TYPE text USING CASE form::text
    WHEN '1' THEN 'FORM_1'
    WHEN '2' THEN 'FORM_2'
    WHEN '3' THEN 'FORM_3'
    WHEN '4' THEN 'FORM_4'
    ELSE form::text
  END;
ALTER TABLE public.class
  DROP CONSTRAINT IF EXISTS class_form_check,
  ADD CONSTRAINT class_form_check
    CHECK (form IN ('FORM_1', 'FORM_2', 'FORM_3', 'FORM_4'));
-- One learner has one placement per academic period. This also gives the
-- continuation RPC a deterministic ON CONFLICT target.
CREATE UNIQUE INDEX IF NOT EXISTS uq_studentclasshistory_student_period
  ON public.studentclasshistory(studentid, academicyearid);
-- Normalize the weeding decisions used by Flutter and retain annual evidence.
ALTER TABLE public.weedingreview
  ALTER COLUMN decision DROP DEFAULT;
ALTER TABLE public.weedingreview
  ALTER COLUMN decision TYPE text USING CASE decision::text
    WHEN 'APPROVED' THEN 'WEED_OUT'
    WHEN 'RETAINED' THEN 'RETAIN'
    WHEN 'REJECTED' THEN 'RETAIN'
    ELSE decision::text
  END;
ALTER TABLE public.weedingreview
  ALTER COLUMN decision SET DEFAULT 'PENDING',
  DROP CONSTRAINT IF EXISTS weedingreview_decision_check,
  ADD CONSTRAINT weedingreview_decision_check
    CHECK (decision IN ('PENDING', 'WEED_OUT', 'RETAIN')),
  ADD COLUMN IF NOT EXISTS schoolyear integer,
  ADD COLUMN IF NOT EXISTS calculationsnapshot jsonb;
CREATE UNIQUE INDEX IF NOT EXISTS uq_weedingreview_annual
  ON public.weedingreview(studentid, schoolyear)
  WHERE schoolyear IS NOT NULL;
-- Existing notifications remain compatible. Automatic outcomes can now be
-- addressed to any system user and deduplicated by an immutable event key.
ALTER TABLE public.notification
  ALTER COLUMN guardianid DROP NOT NULL,
  ALTER COLUMN sentby DROP NOT NULL,
  ADD COLUMN IF NOT EXISTS recipientuserid uuid
    REFERENCES public.systemuser(userid) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS studentid uuid
    REFERENCES public.student(studentid) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS eventkey text;
UPDATE public.notification n
SET recipientuserid = g.userid
FROM public.guardian g
WHERE n.recipientuserid IS NULL
  AND g.guardianid = n.guardianid;
CREATE UNIQUE INDEX IF NOT EXISTS uq_notification_recipient_event
  ON public.notification(recipientuserid, eventkey)
  WHERE eventkey IS NOT NULL;
CREATE INDEX IF NOT EXISTS ix_notification_recipient_created
  ON public.notification(recipientuserid, createdat DESC);
-- Historical assessment pages must remain readable after a learner continues
-- to a later term. Access is still limited to a teacher's own assignments.
CREATE OR REPLACE FUNCTION public.teacher_can_read_student(
  target_student_id uuid
) RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.staff staff_member
    JOIN public.classsubject assignment
      ON assignment.staffid = staff_member.staffid
    JOIN public.studentclasshistory enrollment
      ON enrollment.classid = assignment.classid
     AND enrollment.academicyearid = assignment.academicyearid
    WHERE staff_member.userid = (SELECT auth.uid())
      AND enrollment.studentid = target_student_id
  )
$$;
REVOKE ALL ON FUNCTION public.teacher_can_read_student(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.teacher_can_read_student(uuid)
  TO authenticated;
CREATE INDEX IF NOT EXISTS ix_studentclasshistory_class_period_student
  ON public.studentclasshistory(classid, academicyearid, studentid);
DROP POLICY IF EXISTS "staff read class history"
  ON public.studentclasshistory;
DROP POLICY IF EXISTS "teachers read assigned class history"
  ON public.studentclasshistory;
DROP POLICY IF EXISTS "privileged roles read class history"
  ON public.studentclasshistory;
CREATE POLICY "privileged roles read class history"
ON public.studentclasshistory FOR SELECT TO authenticated
USING (
  public.current_app_role() IN (
    'SUPER_USER', 'SYSTEM_ADMIN', 'ADMINISTRATOR', 'HEAD_TEACHER', 'ACCOUNTANT'
  )
);
CREATE POLICY "teachers read assigned class history"
ON public.studentclasshistory FOR SELECT TO authenticated
USING (
  public.current_app_role() = 'TEACHER'
  AND EXISTS (
    SELECT 1
    FROM public.staff s
    JOIN public.classsubject cs ON cs.staffid = s.staffid
    WHERE s.userid = (SELECT auth.uid())
      AND cs.classid = studentclasshistory.classid
      AND cs.academicyearid = studentclasshistory.academicyearid
  )
);
-- Calculate only from the student's exact term placement and the complete set
-- of subjects assigned to that class in that term. A partial subject or term
-- can never produce an eligible annual result.
CREATE OR REPLACE FUNCTION private.calculate_student_annual_result(
  p_student_id uuid,
  p_school_year integer
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
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

    v_term_average := CASE
      WHEN v_term_complete AND v_term_subjects = v_required_subjects
        THEN round(v_term_sum / v_term_subjects, 2)
      ELSE NULL
    END;
    v_terms := v_terms || jsonb_build_array(jsonb_build_object(
      'term', v_term.term,
      'enrolled', true,
      'average', v_term_average
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

  RETURN jsonb_build_object(
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
$$;
REVOKE ALL ON FUNCTION private.calculate_student_annual_result(uuid, integer)
  FROM PUBLIC, authenticated;
-- Continue a learner into a term without allowing class history and subject
-- enrollment to drift apart.
CREATE OR REPLACE FUNCTION public.continue_student_to_term(
  p_student_id uuid,
  p_class_id uuid,
  p_academic_year_id uuid
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_role text := public.current_app_role();
  v_period public.academicyear%ROWTYPE;
  v_class_form text;
  v_history_id uuid;
  v_existing_class_id uuid;
  v_subject_count integer;
BEGIN
  IF NOT public.current_user_is_active()
     OR v_role NOT IN ('SUPER_USER', 'SYSTEM_ADMIN', 'ADMINISTRATOR') THEN
    RAISE EXCEPTION 'Only an administrator may continue a student to a term.'
      USING ERRCODE = '42501';
  END IF;

  PERFORM pg_advisory_xact_lock(
    hashtextextended(p_student_id::text || ':' || p_academic_year_id::text, 0)
  );

  SELECT * INTO v_period
  FROM public.academicyear
  WHERE academicyearid = p_academic_year_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Academic period not found'; END IF;

  SELECT c.form::text INTO v_class_form
  FROM public.class c
  WHERE c.classid = p_class_id;
  IF v_class_form IS NULL THEN RAISE EXCEPTION 'Class not found'; END IF;
  IF v_period.form IS DISTINCT FROM v_class_form THEN
    RAISE EXCEPTION 'The class and academic period must use the same form';
  END IF;

  SELECT count(*) INTO v_subject_count
  FROM public.classsubject cs
  WHERE cs.classid = p_class_id
    AND cs.academicyearid = p_academic_year_id;
  IF v_subject_count = 0 THEN
    RAISE EXCEPTION 'Assign subjects and teachers before continuing students';
  END IF;

  SELECT h.classid INTO v_existing_class_id
  FROM public.studentclasshistory h
  WHERE h.studentid = p_student_id
    AND h.academicyearid = p_academic_year_id;

  UPDATE public.studentclasshistory h
  SET enddate = v_period.startdate - 1,
      updatedat = now()
  WHERE h.studentid = p_student_id
    AND h.academicyearid <> p_academic_year_id
    AND h.enddate IS NULL
    AND h.enrollmentdate < v_period.startdate;

  INSERT INTO public.studentclasshistory(
    studentid, classid, academicyearid, enrollmentdate
  ) VALUES (
    p_student_id, p_class_id, p_academic_year_id, v_period.startdate
  )
  ON CONFLICT (studentid, academicyearid) DO UPDATE
  SET classid = EXCLUDED.classid,
      enrollmentdate = EXCLUDED.enrollmentdate,
      enddate = NULL,
      updatedat = now()
  RETURNING historyid INTO v_history_id;

  INSERT INTO public.studentsubject(studentid, classsubjectid)
  SELECT p_student_id, cs.classsubjectid
  FROM public.classsubject cs
  WHERE cs.classid = p_class_id
    AND cs.academicyearid = p_academic_year_id
  ON CONFLICT (studentid, classsubjectid) DO NOTHING;

  IF v_existing_class_id IS DISTINCT FROM p_class_id THEN
    INSERT INTO public.auditlog(
      userid, recordid, actorrole, action, tablename, previousvalue, newvalue,
      reason
    ) VALUES (
      auth.uid(), v_history_id, v_role, 'STUDENT_CONTINUED_TO_TERM',
      'studentclasshistory',
      CASE WHEN v_existing_class_id IS NULL THEN NULL
        ELSE jsonb_build_object('classId', v_existing_class_id) END,
      jsonb_build_object(
        'studentId', p_student_id,
        'classId', p_class_id,
        'academicYearId', p_academic_year_id,
        'subjectCount', v_subject_count
      ),
      'Class placement and term subject enrollment updated atomically.'
    );
  END IF;

  RETURN jsonb_build_object(
    'historyId', v_history_id,
    'studentId', p_student_id,
    'academicYearId', p_academic_year_id,
    'classId', p_class_id,
    'subjectCount', v_subject_count
  );
END
$$;
CREATE OR REPLACE FUNCTION private.enqueue_outcome_notifications(
  p_student_id uuid,
  p_event_key text,
  p_subject text,
  p_message text
) RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_count integer;
BEGIN
  WITH recipients AS (
    SELECT su.userid, NULL::uuid AS guardianid
    FROM public.systemuser su
    JOIN public.role r ON r.roleid = su.roleid
    WHERE su.isactive
      AND upper(r.rolename) IN (
        'SUPER_USER', 'SYSTEM_ADMIN', 'ADMINISTRATOR', 'HEAD_TEACHER'
      )
    UNION
    SELECT g.userid, g.guardianid
    FROM public.studentguardian sg
    JOIN public.guardian g ON g.guardianid = sg.guardianid
    JOIN public.systemuser su ON su.userid = g.userid AND su.isactive
    WHERE sg.studentid = p_student_id
  ), inserted AS (
    INSERT INTO public.notification(
      recipientuserid, guardianid, studentid, eventkey, subject, message,
      emailstatus, readstatus, sentat
    )
    SELECT r.userid, r.guardianid, p_student_id, p_event_key,
      p_subject, p_message, 'NOT_APPLICABLE', 'UNREAD', now()
    FROM recipients r
    WHERE r.userid IS NOT NULL
    ON CONFLICT (recipientuserid, eventkey)
      WHERE eventkey IS NOT NULL DO NOTHING
    RETURNING 1
  )
  SELECT count(*) INTO v_count FROM inserted;
  RETURN v_count;
END
$$;
REVOKE ALL ON FUNCTION private.enqueue_outcome_notifications(
  uuid, text, text, text
) FROM PUBLIC, authenticated;
-- The explicit year-end action immediately applies the trusted recommendation.
CREATE OR REPLACE FUNCTION public.finalize_student_school_year(
  p_student_id uuid,
  p_school_year integer
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_role text := public.current_app_role();
  v_result jsonb;
  v_average numeric;
  v_threshold numeric;
  v_form text;
  v_next_form text;
  v_source_period uuid;
  v_target_period public.academicyear%ROWTYPE;
  v_target_class uuid;
  v_review_id uuid;
  v_weeding_id uuid;
  v_history_result jsonb;
  v_notification_count integer;
  v_student_name text;
  v_event_key text;
BEGIN
  IF NOT public.current_user_is_active()
     OR v_role NOT IN ('SUPER_USER', 'SYSTEM_ADMIN', 'ADMINISTRATOR') THEN
    RAISE EXCEPTION 'Only an administrator may finalize a school year.'
      USING ERRCODE = '42501';
  END IF;

  PERFORM pg_advisory_xact_lock(
    hashtextextended(p_student_id::text || ':' || p_school_year::text, 0)
  );

  v_result := private.calculate_student_annual_result(
    p_student_id, p_school_year
  );
  IF NOT (v_result->>'complete')::boolean THEN
    RETURN v_result || jsonb_build_object('outcome', 'PENDING');
  END IF;

  v_average := (v_result->>'annualAverage')::numeric;
  v_threshold := (v_result->>'passThreshold')::numeric;
  v_form := v_result->>'form';
  SELECT trim(concat_ws(' ', s.firstname, s.lastname)) INTO v_student_name
  FROM public.student s WHERE s.studentid = p_student_id;

  SELECT ay.academicyearid INTO v_source_period
  FROM public.academicyear ay
  WHERE ay.academicyear = p_school_year
    AND ay.form = v_form
    AND ay.term::text = 'TERM_3';
  IF v_source_period IS NULL THEN
    RAISE EXCEPTION 'Term 3 is not configured for this form';
  END IF;

  IF v_average >= v_threshold THEN
    v_next_form := CASE v_form
      WHEN 'FORM_1' THEN 'FORM_2'
      WHEN 'FORM_2' THEN 'FORM_3'
      WHEN 'FORM_3' THEN 'FORM_4'
      ELSE NULL
    END;
    IF v_next_form IS NULL THEN
      RAISE EXCEPTION 'No automatic promotion target exists after %', v_form;
    END IF;

    SELECT * INTO v_target_period
    FROM public.academicyear ay
    WHERE ay.academicyear = p_school_year + 1
      AND ay.form = v_next_form
      AND ay.term::text = 'TERM_1';
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Configure % Term 1 for % before finalizing',
        p_school_year + 1, v_next_form;
    END IF;

    SELECT c.classid INTO v_target_class
    FROM public.class c
    WHERE c.form::text = v_next_form
    ORDER BY c.classroomname
    LIMIT 1;
    IF v_target_class IS NULL THEN
      RAISE EXCEPTION 'Configure a class for % before finalizing', v_next_form;
    END IF;

    v_history_result := public.continue_student_to_term(
      p_student_id, v_target_class, v_target_period.academicyearid
    );

    INSERT INTO public.progressionreview(
      studentid, academicyearid, schoolyear, averagescore, decision,
      decisionreason, decisiondate, calculationsnapshot,
      targetacademicyearid, targetclassid
    ) VALUES (
      p_student_id, v_source_period, p_school_year, v_average, 'PROMOTED',
      'Automatically promoted at or above the configured pass threshold.',
      now(), v_result, v_target_period.academicyearid, v_target_class
    )
    ON CONFLICT (studentid, schoolyear) WHERE schoolyear IS NOT NULL
    DO UPDATE SET
      averagescore = EXCLUDED.averagescore,
      decision = 'PROMOTED',
      decisionreason = EXCLUDED.decisionreason,
      decisiondate = EXCLUDED.decisiondate,
      calculationsnapshot = EXCLUDED.calculationsnapshot,
      targetacademicyearid = EXCLUDED.targetacademicyearid,
      targetclassid = EXCLUDED.targetclassid,
      updatedat = now()
    RETURNING reviewid INTO v_review_id;

    v_event_key := format('progression:%s:%s', p_student_id, p_school_year);
    v_notification_count := private.enqueue_outcome_notifications(
      p_student_id,
      v_event_key,
      'Student promoted',
      format('%s was promoted with an annual average of %s%%.',
        v_student_name, to_char(v_average, 'FM990.00'))
    );

    INSERT INTO public.auditlog(
      userid, recordid, actorrole, action, tablename, newvalue, reason
    ) VALUES (
      auth.uid(), v_review_id, v_role, 'AUTOMATIC_PROMOTION',
      'progressionreview',
      jsonb_build_object(
        'studentId', p_student_id,
        'annualAverage', v_average,
        'targetClassId', v_target_class,
        'targetAcademicYearId', v_target_period.academicyearid
      ),
      'Completed three-term result met the configured pass threshold.'
    );

    RETURN v_result || jsonb_build_object(
      'outcome', 'PROMOTED',
      'reviewId', v_review_id,
      'placement', v_history_result,
      'notificationsCreated', v_notification_count
    );
  END IF;

  INSERT INTO public.weedingreview(
    studentid, academicyearid, schoolyear, cumulativeaverage,
    decision, calculationsnapshot, flaggeddate
  ) VALUES (
    p_student_id, v_source_period, p_school_year, v_average,
    'PENDING', v_result, current_date
  )
  ON CONFLICT (studentid, schoolyear) WHERE schoolyear IS NOT NULL
  DO UPDATE SET
    cumulativeaverage = EXCLUDED.cumulativeaverage,
    calculationsnapshot = EXCLUDED.calculationsnapshot,
    updatedat = now()
  RETURNING weedingid INTO v_weeding_id;

  v_event_key := format('weeding:%s:%s', p_student_id, p_school_year);
  v_notification_count := private.enqueue_outcome_notifications(
    p_student_id,
    v_event_key,
    'Student requires academic review',
    format('%s was flagged for review with an annual average of %s%%.',
      v_student_name, to_char(v_average, 'FM990.00'))
  );

  INSERT INTO public.auditlog(
    userid, recordid, actorrole, action, tablename, newvalue, reason
  ) VALUES (
    auth.uid(), v_weeding_id, v_role, 'AUTOMATIC_WEEDING_FLAG',
    'weedingreview',
    jsonb_build_object(
      'studentId', p_student_id,
      'annualAverage', v_average,
      'threshold', v_threshold
    ),
    'Completed three-term result was below the configured pass threshold.'
  );

  RETURN v_result || jsonb_build_object(
    'outcome', 'WEEDING_REVIEW',
    'weedingId', v_weeding_id,
    'notificationsCreated', v_notification_count
  );
END
$$;
-- Broaden trusted calculation visibility for administrators while keeping all
-- result application inside the separately protected finalization function.
CREATE OR REPLACE FUNCTION public.calculate_student_annual_result(
  p_student_id uuid,
  p_school_year integer
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NOT public.current_user_is_active()
     OR public.current_app_role() NOT IN (
       'SUPER_USER', 'SYSTEM_ADMIN', 'ADMINISTRATOR', 'HEAD_TEACHER'
     ) THEN
    RAISE EXCEPTION 'You may not calculate this annual result.'
      USING ERRCODE = '42501';
  END IF;
  RETURN private.calculate_student_annual_result(p_student_id, p_school_year);
END
$$;
REVOKE ALL ON FUNCTION public.continue_student_to_term(uuid, uuid, uuid)
  FROM PUBLIC;
REVOKE ALL ON FUNCTION public.finalize_student_school_year(uuid, integer)
  FROM PUBLIC;
REVOKE ALL ON FUNCTION public.calculate_student_annual_result(uuid, integer)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.continue_student_to_term(uuid, uuid, uuid)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.finalize_student_school_year(uuid, integer)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.calculate_student_annual_result(uuid, integer)
  TO authenticated;
-- Administrators apply calculated outcomes only through the audited finalizer.
-- Head Teachers make the human review decisions. Replace legacy broad ALL
-- policies, including references to the retired REGISTRAR role.
DROP POLICY IF EXISTS "head teacher manages progression reviews"
  ON public.progressionreview;
DROP POLICY IF EXISTS "head teacher can manage progression reviews"
  ON public.progressionreview;
DROP POLICY IF EXISTS "registrars can read progression reviews"
  ON public.progressionreview;
DROP POLICY IF EXISTS "annual progression reviewers read"
  ON public.progressionreview;
DROP POLICY IF EXISTS "head teacher manages annual progression reviews"
  ON public.progressionreview;
CREATE POLICY "annual progression reviewers read"
ON public.progressionreview FOR SELECT TO authenticated
USING (
  public.current_app_role() IN (
    'SUPER_USER', 'SYSTEM_ADMIN', 'ADMINISTRATOR', 'HEAD_TEACHER'
  )
);
CREATE POLICY "head teacher manages annual progression reviews"
ON public.progressionreview FOR ALL TO authenticated
USING (public.current_app_role() = 'HEAD_TEACHER')
WITH CHECK (public.current_app_role() = 'HEAD_TEACHER');
DROP POLICY IF EXISTS "head teacher manages weeding reviews"
  ON public.weedingreview;
DROP POLICY IF EXISTS "head teacher can manage weeding reviews"
  ON public.weedingreview;
DROP POLICY IF EXISTS "registrars can read weeding reviews"
  ON public.weedingreview;
DROP POLICY IF EXISTS "annual weeding reviewers read"
  ON public.weedingreview;
DROP POLICY IF EXISTS "head teacher manages annual weeding reviews"
  ON public.weedingreview;
CREATE POLICY "annual weeding reviewers read"
ON public.weedingreview FOR SELECT TO authenticated
USING (
  public.current_app_role() IN (
    'SUPER_USER', 'SYSTEM_ADMIN', 'ADMINISTRATOR', 'HEAD_TEACHER'
  )
);
CREATE POLICY "head teacher manages annual weeding reviews"
ON public.weedingreview FOR ALL TO authenticated
USING (public.current_app_role() = 'HEAD_TEACHER')
WITH CHECK (public.current_app_role() = 'HEAD_TEACHER');
DROP POLICY IF EXISTS "recipient reads own automatic notifications"
  ON public.notification;
CREATE POLICY "recipient reads own automatic notifications"
ON public.notification FOR SELECT TO authenticated
USING (recipientuserid = (SELECT auth.uid()));
DROP POLICY IF EXISTS "recipient marks own automatic notifications read"
  ON public.notification;
CREATE POLICY "recipient marks own automatic notifications read"
ON public.notification FOR UPDATE TO authenticated
USING (recipientuserid = (SELECT auth.uid()))
WITH CHECK (recipientuserid = (SELECT auth.uid()));
DROP POLICY IF EXISTS "privileged roles can read all notifications"
  ON public.notification;
CREATE POLICY "privileged roles can read all notifications"
ON public.notification FOR SELECT TO authenticated
USING (
  public.current_app_role() IN (
    'SUPER_USER', 'SYSTEM_ADMIN', 'ADMINISTRATOR', 'HEAD_TEACHER'
  )
);
NOTIFY pgrst, 'reload schema';
COMMIT;
