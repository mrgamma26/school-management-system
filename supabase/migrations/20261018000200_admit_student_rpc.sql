-- Transactional student admission.
--
-- public.admit_student() creates, in ONE transaction:
--   student  ->  guardian links (existing guardians, by id + relationship)
--            ->  NEW guardian records (no login yet)
--            ->  class placement (studentclasshistory)
--            ->  subject enrolments from the class setup (studentsubject)
--            ->  audit rows
-- If any step fails nothing is saved. This replaces the multi-step client flow
-- in StudentFormPage, where a failure part-way left a half-registered student.
--
-- Guardian LOGINS are not created here: Supabase Auth accounts can only be
-- created by an Edge Function using the service role. The RPC returns the new
-- guardian ids; the app then calls the invite-user Edge Function with
-- `guardianId` so the invited account is attached to the guardian row that
-- already exists (invite-user fills in guardian.userid).
--
-- Rules mirrored from the existing client code and policies:
--   * who may register students: the 'admins manage students' / class-history /
--     guardian-link policies (SUPER_USER, SYSTEM_ADMIN, ADMINISTRATOR; the
--     retired REGISTRAR role is not carried over)
--   * date of birth required, not in the future, student at least 9 years old
--     (same rule as trigger validate_student_birth_date)
--   * at least one guardian, no guardian twice, relationship from the form list
--   * new guardian emails must be unique (and not already used by a guardian,
--     a staff member or an auth account), because the login is created from them
--   * new admissions take the column default enrolment status (the client
--     always sent 'enrolled'; the enum labels differ between databases)
--   * placement needs both a class and an academic year; enrolment date is
--     today; the class form must match the academic period form
--   * subject enrolments come from classsubject rows for that class and year,
--     ON CONFLICT DO NOTHING (same as StudentRepository.enrolInClassSubjects)
-- Idempotent: safe to run twice.
BEGIN;

-- A guardian record can exist before the guardian has a login. The FK to
-- systemuser and the UNIQUE constraint stay; NULLs are distinct in UNIQUE.
ALTER TABLE public.guardian ALTER COLUMN userid DROP NOT NULL;

CREATE OR REPLACE FUNCTION private.can_admit_students()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT public.current_user_is_active()
    AND upper(coalesce(public.current_app_role(), ''))
      IN ('SUPER_USER', 'SYSTEM_ADMIN', 'ADMINISTRATOR')
$$;
REVOKE ALL ON FUNCTION private.can_admit_students() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.can_admit_students() TO authenticated;

CREATE OR REPLACE FUNCTION public.admit_student(
  p_student jsonb,
  p_guardians jsonb,
  p_class_id uuid DEFAULT NULL,
  p_academic_year_id uuid DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_actor uuid := auth.uid();
  v_role text := public.current_app_role();
  v_today date := current_date;
  v_first text;
  v_middle text;
  v_last text;
  v_gender public.gender_type;
  v_dob_text text;
  v_dob date;
  v_address text;
  v_enrol_date date;
  v_student_id uuid;
  v_history_id uuid;
  v_subjects integer := 0;
  v_year_form text;
  v_class_form text;
  v_g jsonb;
  v_idx integer := 0;
  v_gid uuid;
  v_rel text;
  v_email text;
  v_gfirst text;
  v_glast text;
  v_ggender public.gender_type;
  v_seen_ids uuid[] := ARRAY[]::uuid[];
  v_seen_emails text[] := ARRAY[]::text[];
  v_results jsonb := '[]'::jsonb;
BEGIN
  IF v_actor IS NULL OR NOT private.can_admit_students() THEN
    RAISE EXCEPTION 'Only an Administrator or Super User may register students';
  END IF;

  -- ------------------------------------------------------------ the student
  IF p_student IS NULL OR jsonb_typeof(p_student) <> 'object' THEN
    RAISE EXCEPTION 'Student details are required';
  END IF;
  v_first := btrim(coalesce(p_student->>'firstname', ''));
  v_middle := nullif(btrim(coalesce(p_student->>'middlename', '')), '');
  v_last := btrim(coalesce(p_student->>'lastname', ''));
  v_address := nullif(btrim(coalesce(p_student->>'physicaladdress', '')), '');
  IF v_first = '' OR v_last = '' THEN
    RAISE EXCEPTION 'The student first name and last name are required';
  END IF;

  IF upper(coalesce(p_student->>'gender', '')) NOT IN ('MALE', 'FEMALE') THEN
    RAISE EXCEPTION 'The student gender must be Male or Female';
  END IF;
  v_gender := upper(p_student->>'gender')::public.gender_type;

  v_dob_text := btrim(coalesce(p_student->>'dateofbirth', ''));
  IF v_dob_text !~ '^\d{4}-\d{2}-\d{2}$' THEN
    RAISE EXCEPTION 'Date of birth is required (YYYY-MM-DD)';
  END IF;
  v_dob := v_dob_text::date;
  IF v_dob > v_today THEN
    RAISE EXCEPTION 'A student date of birth cannot be in the future';
  END IF;
  IF v_dob > (v_today - interval '9 years')::date THEN
    RAISE EXCEPTION 'A student must be at least 9 years old';
  END IF;

  -- The client sends today's date; allow a day either side for time zones.
  v_enrol_date := v_today;
  IF coalesce(p_student->>'enrollmentdate', '') ~ '^\d{4}-\d{2}-\d{2}$'
     AND (p_student->>'enrollmentdate')::date BETWEEN v_today - 1 AND v_today + 1 THEN
    v_enrol_date := (p_student->>'enrollmentdate')::date;
  END IF;

  -- ----------------------------------------------------------- the guardians
  IF p_guardians IS NULL OR jsonb_typeof(p_guardians) <> 'array'
     OR jsonb_array_length(p_guardians) < 1 THEN
    RAISE EXCEPTION 'Link an existing parent or guardian, or enter a new guardian';
  END IF;
  IF jsonb_array_length(p_guardians) > 10 THEN
    RAISE EXCEPTION 'A student can be registered with at most 10 guardians';
  END IF;

  -- Validate everything before the first insert so errors read cleanly.
  FOR v_g IN SELECT value FROM jsonb_array_elements(p_guardians)
  LOOP
    IF jsonb_typeof(v_g) <> 'object' THEN
      RAISE EXCEPTION 'Each guardian must be an object';
    END IF;
    v_rel := upper(btrim(coalesce(v_g->>'relationship', '')));
    IF v_rel NOT IN ('PARENT', 'GUARDIAN', 'SIBLING', 'GRANDPARENT', 'UNCLE/AUNT', 'OTHER') THEN
      RAISE EXCEPTION 'Choose a relationship for every guardian';
    END IF;

    IF nullif(v_g->>'guardianId', '') IS NOT NULL THEN
      BEGIN
        v_gid := (v_g->>'guardianId')::uuid;
      EXCEPTION WHEN invalid_text_representation THEN
        RAISE EXCEPTION 'A selected guardian id is not valid';
      END;
      IF v_gid = ANY(v_seen_ids) THEN
        RAISE EXCEPTION 'The same guardian was selected twice';
      END IF;
      v_seen_ids := v_seen_ids || v_gid;
      IF NOT EXISTS (SELECT 1 FROM public.guardian WHERE guardianid = v_gid) THEN
        RAISE EXCEPTION 'A selected guardian no longer exists';
      END IF;
    ELSE
      v_email := lower(btrim(coalesce(v_g->>'email', '')));
      IF btrim(coalesce(v_g->>'firstname', '')) = ''
         OR btrim(coalesce(v_g->>'lastname', '')) = '' OR v_email = '' THEN
        RAISE EXCEPTION 'Enter a first name, last name and email for each new guardian';
      END IF;
      IF v_email !~ '^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$' THEN
        RAISE EXCEPTION 'Enter a valid email address for each new guardian';
      END IF;
      IF upper(coalesce(v_g->>'gender', '')) NOT IN ('MALE', 'FEMALE') THEN
        RAISE EXCEPTION 'The guardian gender must be Male or Female';
      END IF;
      IF v_email = ANY(v_seen_emails) THEN
        RAISE EXCEPTION 'Use a different email address for each guardian';
      END IF;
      v_seen_emails := v_seen_emails || v_email;
      IF EXISTS (SELECT 1 FROM public.guardian WHERE lower(email) = v_email)
         OR EXISTS (SELECT 1 FROM public.staff WHERE lower(email) = v_email)
         OR EXISTS (SELECT 1 FROM auth.users WHERE lower(email) = v_email) THEN
        RAISE EXCEPTION 'The email % is already registered. Link that guardian instead of creating a new one', v_email;
      END IF;
    END IF;
  END LOOP;

  -- ---------------------------------------------------------- class placement
  IF p_class_id IS NOT NULL AND p_academic_year_id IS NOT NULL THEN
    SELECT c.form INTO v_class_form FROM public.class c WHERE c.classid = p_class_id;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'The selected class does not exist';
    END IF;
    SELECT ay.form INTO v_year_form
    FROM public.academicyear ay WHERE ay.academicyearid = p_academic_year_id;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'The selected academic year does not exist';
    END IF;
    IF v_year_form IS NOT NULL AND v_class_form IS NOT NULL
       AND v_year_form <> v_class_form THEN
      RAISE EXCEPTION 'The class and the academic period belong to different forms';
    END IF;
  END IF;

  -- -------------------------------------------------------------- the writes
  -- enrollmentstatus is left to the column default (see header comment).
  INSERT INTO public.student(
    firstname, middlename, lastname, gender, dateofbirth, physicaladdress
  ) VALUES (v_first, v_middle, v_last, v_gender, v_dob, v_address)
  RETURNING studentid INTO v_student_id;

  INSERT INTO public.auditlog(userid, recordid, actorrole, action, tablename)
  VALUES (v_actor, v_student_id, v_role, 'STUDENT_CREATED', 'student');

  IF p_class_id IS NOT NULL AND p_academic_year_id IS NOT NULL THEN
    -- A brand-new student has no open placement, so there is nothing to close
    -- (the client called close_current_class_placement here).
    INSERT INTO public.studentclasshistory(studentid, classid, academicyearid, enrollmentdate)
    VALUES (v_student_id, p_class_id, p_academic_year_id, v_enrol_date)
    RETURNING historyid INTO v_history_id;

    INSERT INTO public.studentsubject(studentid, classsubjectid)
    SELECT v_student_id, cs.classsubjectid
    FROM public.classsubject cs
    WHERE cs.classid = p_class_id AND cs.academicyearid = p_academic_year_id
    ON CONFLICT (studentid, classsubjectid) DO NOTHING;
    GET DIAGNOSTICS v_subjects = ROW_COUNT;

    INSERT INTO public.auditlog(userid, recordid, actorrole, action, tablename, newvalue)
    VALUES (
      v_actor, v_history_id, v_role, 'STUDENT_CLASS_ASSIGNED', 'studentclasshistory',
      jsonb_build_object(
        'studentid', v_student_id,
        'classid', p_class_id,
        'academicyearid', p_academic_year_id,
        'enrollmentdate', v_enrol_date,
        'subjectsEnrolled', v_subjects
      )
    );
  END IF;

  v_idx := 0;
  FOR v_g IN SELECT value FROM jsonb_array_elements(p_guardians)
  LOOP
    v_rel := upper(btrim(v_g->>'relationship'));

    IF nullif(v_g->>'guardianId', '') IS NOT NULL THEN
      v_gid := (v_g->>'guardianId')::uuid;
      INSERT INTO public.studentguardian(studentid, guardianid, relationship)
      VALUES (v_student_id, v_gid, v_rel);

      INSERT INTO public.auditlog(userid, recordid, actorrole, action, tablename, newvalue)
      VALUES (
        v_actor, v_student_id, v_role, 'EXISTING_GUARDIAN_LINKED_TO_STUDENT',
        'studentguardian',
        jsonb_build_object('studentId', v_student_id, 'guardianId', v_gid, 'relationship', v_rel)
      );

      v_results := v_results || jsonb_build_object(
        'index', v_idx, 'guardianId', v_gid, 'relationship', v_rel, 'created', false
      );
    ELSE
      v_email := lower(btrim(v_g->>'email'));
      v_gfirst := btrim(v_g->>'firstname');
      v_glast := btrim(v_g->>'lastname');
      v_ggender := upper(v_g->>'gender')::public.gender_type;

      -- phonenumber / physicaladdress fall back to 'N/A' exactly as the
      -- create-user Edge Function does for guardians.
      INSERT INTO public.guardian(
        userid, firstname, lastname, gender, phonenumber, physicaladdress, email
      ) VALUES (
        NULL, v_gfirst, v_glast, v_ggender,
        coalesce(nullif(btrim(coalesce(v_g->>'phonenumber', '')), ''), 'N/A'),
        coalesce(nullif(btrim(coalesce(v_g->>'physicaladdress', '')), ''), 'N/A'),
        v_email
      ) RETURNING guardianid INTO v_gid;

      INSERT INTO public.studentguardian(studentid, guardianid, relationship)
      VALUES (v_student_id, v_gid, v_rel);

      INSERT INTO public.auditlog(userid, recordid, actorrole, action, tablename, newvalue)
      VALUES (
        v_actor, v_gid, v_role, 'GUARDIAN_CREATED_FOR_STUDENT', 'guardian',
        jsonb_build_object('studentId', v_student_id, 'email', v_email)
      );

      v_results := v_results || jsonb_build_object(
        'index', v_idx, 'guardianId', v_gid, 'relationship', v_rel,
        'created', true, 'email', v_email
      );
    END IF;
    v_idx := v_idx + 1;
  END LOOP;

  RETURN jsonb_build_object(
    'studentId', v_student_id,
    'placementId', v_history_id,
    'subjectsEnrolled', v_subjects,
    'guardians', v_results
  );
END;
$$;

REVOKE ALL ON FUNCTION public.admit_student(jsonb, jsonb, uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admit_student(jsonb, jsonb, uuid, uuid) TO authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
