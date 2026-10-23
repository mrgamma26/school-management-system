-- Continue to next term from Term 3: the Administrator sends a class to the
-- Head Teacher for year-end progression. Each student gets a PENDING
-- progression review (annual average, or the average so far), and every
-- active Head Teacher is notified. Promotion then places the student in the
-- next form for Term 1 (decide_and_place_student).

CREATE OR REPLACE FUNCTION public.request_progression_reviews(
  p_class_id uuid,
  p_school_year integer
)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_role text := public.current_app_role();
  v_class_name text;
  v_form text;
  v_term3 uuid;
  v_student uuid;
  v_result jsonb;
  v_students integer := 0;
  v_recorded integer := 0;
  v_actor_staff uuid;
BEGIN
  IF NOT public.current_user_is_active()
     OR v_role NOT IN ('SUPER_USER', 'SYSTEM_ADMIN', 'ADMINISTRATOR') THEN
    RAISE EXCEPTION 'Only an administrator may send a class for progression.'
      USING ERRCODE = '42501';
  END IF;

  SELECT c.classroomname, c.form::text INTO v_class_name, v_form
  FROM public.class c WHERE c.classid = p_class_id;
  IF v_form IS NULL THEN RAISE EXCEPTION 'Class not found'; END IF;

  SELECT ay.academicyearid INTO v_term3
  FROM public.academicyear ay
  WHERE ay.academicyear = p_school_year
    AND ay.form::text = v_form
    AND ay.term::text = 'TERM_3';
  IF v_term3 IS NULL THEN
    RAISE EXCEPTION 'Term 3 is not set up for this form and year';
  END IF;

  FOR v_student IN
    SELECT DISTINCT h.studentid
    FROM public.studentclasshistory h
    WHERE h.classid = p_class_id AND h.academicyearid = v_term3
  LOOP
    v_students := v_students + 1;
    BEGIN
      v_result := private.refresh_progression_review(v_student, p_school_year);
      IF v_result ? 'reviewId' THEN
        v_recorded := v_recorded + 1;
      END IF;
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;
  END LOOP;

  IF v_students = 0 THEN
    RAISE EXCEPTION 'No students are placed in % for Term 3', v_class_name;
  END IF;

  SELECT s.staffid INTO v_actor_staff
  FROM public.staff s WHERE s.userid = auth.uid() LIMIT 1;

  INSERT INTO public.notification(
    recipientuserid, guardianid, sentby, eventkey, subject, message,
    emailstatus, readstatus, sentat
  )
  SELECT su.userid, NULL, v_actor_staff,
    'progression-request:' || p_class_id::text || ':' || p_school_year::text
      || ':' || su.userid::text || ':' || extract(epoch FROM now())::bigint::text,
    left('Progression review requested: ' || v_class_name, 255),
    v_class_name || ' (' || p_school_year::text || '/'
      || (p_school_year + 1)::text || ') has finished Term 3. '
      || v_recorded::text || ' of ' || v_students::text
      || ' student review(s) are waiting in Progression Reviews.',
    'NOT_APPLICABLE', 'UNREAD', now()
  FROM public.systemuser su
  JOIN public.role r ON r.roleid = su.roleid
  WHERE r.rolename::text = 'HEAD_TEACHER' AND su.isactive;

  INSERT INTO public.auditlog(
    userid, recordid, actorrole, action, tablename, newvalue, reason
  ) VALUES (
    auth.uid(), p_class_id, v_role, 'PROGRESSION_REVIEWS_REQUESTED', 'class',
    jsonb_build_object('schoolYear', p_school_year, 'students', v_students,
      'recorded', v_recorded),
    'Class sent to the Head Teacher for year-end progression.'
  );

  RETURN jsonb_build_object(
    'students', v_students,
    'recorded', v_recorded,
    'className', v_class_name
  );
END
$function$;

REVOKE ALL ON FUNCTION public.request_progression_reviews(uuid, integer)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.request_progression_reviews(uuid, integer)
  TO authenticated;
