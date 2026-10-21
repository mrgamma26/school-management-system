BEGIN;

-- Slice 2 separates the reusable class/subject configuration from the teacher
-- assigned to teach it in a particular normalized academic year.
ALTER TABLE public.class
  ALTER COLUMN classroomname SET NOT NULL,
  ALTER COLUMN form SET NOT NULL;

ALTER TABLE public.class
  DROP CONSTRAINT IF EXISTS class_form_check,
  ADD CONSTRAINT class_form_check CHECK (form IN ('FORM_1', 'FORM_2', 'FORM_3', 'FORM_4')),
  DROP CONSTRAINT IF EXISTS class_name_not_blank,
  ADD CONSTRAINT class_name_not_blank CHECK (
    classroomname = btrim(classroomname)
    AND classroomname <> ''
    AND char_length(classroomname) <= 80
  );

CREATE TABLE public.class_subject_catalog (
  class_subject_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  class_id uuid NOT NULL REFERENCES public.class(classid) ON DELETE CASCADE,
  subject_id uuid NOT NULL REFERENCES public.subject(subjectid) ON DELETE RESTRICT,
  is_active boolean NOT NULL DEFAULT true,
  created_by uuid REFERENCES public.systemuser(userid) ON DELETE SET NULL DEFAULT auth.uid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (class_id, subject_id)
);

CREATE TABLE public.teacher_assignments (
  teacher_assignment_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  class_subject_id uuid NOT NULL REFERENCES public.class_subject_catalog(class_subject_id) ON DELETE RESTRICT,
  academic_year_id uuid NOT NULL REFERENCES public.school_academic_years(academic_year_id) ON DELETE RESTRICT,
  staff_id uuid NOT NULL REFERENCES public.staff(staffid) ON DELETE RESTRICT,
  status text NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'REPLACED', 'ENDED')),
  assigned_at timestamptz NOT NULL DEFAULT now(),
  ended_at timestamptz,
  replaced_by_assignment_id uuid REFERENCES public.teacher_assignments(teacher_assignment_id) ON DELETE SET NULL,
  assigned_by uuid REFERENCES public.systemuser(userid) ON DELETE SET NULL DEFAULT auth.uid(),
  replacement_reason text,
  CHECK ((status = 'ACTIVE' AND ended_at IS NULL) OR (status <> 'ACTIVE' AND ended_at IS NOT NULL))
);

CREATE UNIQUE INDEX teacher_assignments_one_active_idx
  ON public.teacher_assignments (class_subject_id, academic_year_id)
  WHERE status = 'ACTIVE';
CREATE INDEX teacher_assignments_teacher_year_idx
  ON public.teacher_assignments (staff_id, academic_year_id, status);

CREATE TABLE public.student_subject_enrollments (
  student_subject_enrollment_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id uuid NOT NULL REFERENCES public.student(studentid) ON DELETE CASCADE,
  class_subject_id uuid NOT NULL REFERENCES public.class_subject_catalog(class_subject_id) ON DELETE RESTRICT,
  academic_year_id uuid NOT NULL REFERENCES public.school_academic_years(academic_year_id) ON DELETE RESTRICT,
  source text NOT NULL DEFAULT 'CLASS_PLACEMENT' CHECK (source IN ('CLASS_PLACEMENT', 'MANUAL')),
  is_active boolean NOT NULL DEFAULT true,
  enrolled_by uuid REFERENCES public.systemuser(userid) ON DELETE SET NULL DEFAULT auth.uid(),
  enrolled_at timestamptz NOT NULL DEFAULT now(),
  ended_at timestamptz,
  UNIQUE (student_id, class_subject_id, academic_year_id),
  CHECK ((is_active AND ended_at IS NULL) OR (NOT is_active AND ended_at IS NOT NULL))
);

CREATE INDEX student_subject_enrollments_student_year_idx
  ON public.student_subject_enrollments (student_id, academic_year_id, is_active);

CREATE TRIGGER class_subject_catalog_updated_at
BEFORE UPDATE ON public.class_subject_catalog
FOR EACH ROW EXECUTE FUNCTION public.set_foundation_updated_at();

-- Staff profile expansion. Existing rows stay valid; the create/edit workflow
-- requires the fields that are operationally mandatory.
ALTER TABLE public.staff
  ADD COLUMN IF NOT EXISTS dateofbirth date,
  ADD COLUMN IF NOT EXISTS nationalid text,
  ADD COLUMN IF NOT EXISTS phonenumber text,
  ADD COLUMN IF NOT EXISTS alternativephone text,
  ADD COLUMN IF NOT EXISTS physicaladdress text,
  ADD COLUMN IF NOT EXISTS profilepicturepath text,
  ADD COLUMN IF NOT EXISTS jobtitle text,
  ADD COLUMN IF NOT EXISTS department text,
  ADD COLUMN IF NOT EXISTS employmenttype text,
  ADD COLUMN IF NOT EXISTS employmentstatus text NOT NULL DEFAULT 'ACTIVE',
  ADD COLUMN IF NOT EXISTS employmentstartdate date,
  ADD COLUMN IF NOT EXISTS professionalqualifications text,
  ADD COLUMN IF NOT EXISTS highestacademicqualification text,
  ADD COLUMN IF NOT EXISTS yearsofexperience smallint,
  ADD COLUMN IF NOT EXISTS emergencycontactname text,
  ADD COLUMN IF NOT EXISTS emergencycontactphone text,
  ADD COLUMN IF NOT EXISTS emergencycontactrelationship text;

ALTER TABLE public.staff
  DROP CONSTRAINT IF EXISTS staff_employment_status_check,
  ADD CONSTRAINT staff_employment_status_check CHECK (employmentstatus IN ('ACTIVE', 'ON_LEAVE', 'SUSPENDED', 'FORMER')),
  DROP CONSTRAINT IF EXISTS staff_experience_check,
  ADD CONSTRAINT staff_experience_check CHECK (yearsofexperience IS NULL OR yearsofexperience BETWEEN 0 AND 70),
  DROP CONSTRAINT IF EXISTS staff_age_check,
  ADD CONSTRAINT staff_age_check CHECK (dateofbirth IS NULL OR dateofbirth <= (current_date - interval '18 years')::date),
  DROP CONSTRAINT IF EXISTS staff_email_check,
  ADD CONSTRAINT staff_email_check CHECK (email = lower(btrim(email)) AND email ~* '^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$'),
  DROP CONSTRAINT IF EXISTS staff_names_check,
  ADD CONSTRAINT staff_names_check CHECK (
    firstname = btrim(firstname) AND firstname <> '' AND char_length(firstname) <= 80
    AND lastname = btrim(lastname) AND lastname <> '' AND char_length(lastname) <= 80
    AND (middlename IS NULL OR (middlename = btrim(middlename) AND middlename <> '' AND char_length(middlename) <= 80))
  ),
  DROP CONSTRAINT IF EXISTS staff_phone_check,
  ADD CONSTRAINT staff_phone_check CHECK (
    phonenumber IS NULL OR phonenumber ~ '^(([+]265)|(0))(88|89|98|99)[0-9]{7}$'
  ),
  DROP CONSTRAINT IF EXISTS staff_alternative_phone_check,
  ADD CONSTRAINT staff_alternative_phone_check CHECK (
    alternativephone IS NULL OR alternativephone ~ '^(([+]265)|(0))(88|89|98|99)[0-9]{7}$'
  ),
  DROP CONSTRAINT IF EXISTS staff_emergency_phone_check,
  ADD CONSTRAINT staff_emergency_phone_check CHECK (
    emergencycontactphone IS NULL OR emergencycontactphone ~ '^(([+]265)|(0))(88|89|98|99)[0-9]{7}$'
  );

CREATE UNIQUE INDEX IF NOT EXISTS staff_national_id_unique_idx
  ON public.staff (lower(nationalid)) WHERE nationalid IS NOT NULL;

CREATE OR REPLACE FUNCTION public.configure_class_subjects(
  p_class_id uuid,
  p_subject_ids uuid[]
) RETURNS SETOF public.class_subject_catalog
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT (public.has_app_role('ADMINISTRATOR') OR public.has_app_role('SUPER_USER')) THEN
    RAISE EXCEPTION 'Only an Administrator or Super User may configure class subjects';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.class WHERE classid = p_class_id) THEN
    RAISE EXCEPTION 'Class not found';
  END IF;

  UPDATE public.class_subject_catalog
  SET is_active = false
  WHERE class_id = p_class_id AND NOT (subject_id = ANY(coalesce(p_subject_ids, ARRAY[]::uuid[])));

  INSERT INTO public.class_subject_catalog(class_id, subject_id, is_active, created_by)
  SELECT p_class_id, chosen.subject_id, true, auth.uid()
  FROM unnest(coalesce(p_subject_ids, ARRAY[]::uuid[])) AS chosen(subject_id)
  JOIN public.subject s ON s.subjectid = chosen.subject_id
  ON CONFLICT (class_id, subject_id) DO UPDATE SET is_active = true;

  RETURN QUERY
  SELECT * FROM public.class_subject_catalog c
  WHERE c.class_id = p_class_id AND c.is_active
  ORDER BY c.created_at;
END;
$$;

CREATE OR REPLACE FUNCTION public.assign_teacher_to_class_subjects(
  p_staff_id uuid,
  p_class_subject_ids uuid[],
  p_replacement_reason text DEFAULT NULL
) RETURNS SETOF public.teacher_assignments
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_year_id uuid;
  v_class_subject_id uuid;
  v_old public.teacher_assignments%ROWTYPE;
  v_new public.teacher_assignments%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL OR NOT (public.has_app_role('ADMINISTRATOR') OR public.has_app_role('SUPER_USER')) THEN
    RAISE EXCEPTION 'Only an Administrator or Super User may assign teachers';
  END IF;
  SELECT academic_year_id INTO v_year_id FROM public.school_academic_years WHERE is_current;
  IF v_year_id IS NULL THEN RAISE EXCEPTION 'Set a current academic year before assigning teachers'; END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.staff st
    JOIN public.user_roles ur ON ur.user_id = st.userid
    JOIN public.role r ON r.roleid = ur.role_id
    WHERE st.staffid = p_staff_id AND upper(r.rolename) IN ('TEACHER', 'HEAD_TEACHER')
  ) THEN RAISE EXCEPTION 'The selected staff member is not an active teacher'; END IF;

  FOREACH v_class_subject_id IN ARRAY coalesce(p_class_subject_ids, ARRAY[]::uuid[])
  LOOP
    IF NOT EXISTS (SELECT 1 FROM public.class_subject_catalog WHERE class_subject_id = v_class_subject_id AND is_active) THEN
      RAISE EXCEPTION 'A selected class subject is not active';
    END IF;
    SELECT * INTO v_old FROM public.teacher_assignments
    WHERE class_subject_id = v_class_subject_id AND academic_year_id = v_year_id AND status = 'ACTIVE'
    FOR UPDATE;
    IF v_old.teacher_assignment_id IS NOT NULL AND v_old.staff_id = p_staff_id THEN
      CONTINUE;
    END IF;
    IF v_old.teacher_assignment_id IS NOT NULL THEN
      UPDATE public.teacher_assignments
      SET status = 'REPLACED', ended_at = now(), replacement_reason = nullif(btrim(p_replacement_reason), '')
      WHERE teacher_assignment_id = v_old.teacher_assignment_id;
    END IF;
    INSERT INTO public.teacher_assignments(class_subject_id, academic_year_id, staff_id, assigned_by)
    VALUES (v_class_subject_id, v_year_id, p_staff_id, auth.uid()) RETURNING * INTO v_new;
    IF v_old.teacher_assignment_id IS NOT NULL THEN
      UPDATE public.teacher_assignments SET replaced_by_assignment_id = v_new.teacher_assignment_id
      WHERE teacher_assignment_id = v_old.teacher_assignment_id;
    END IF;
    INSERT INTO public.auditlog(userid, recordid, actorrole, action, tablename, previousvalue, newvalue, reason)
    VALUES (auth.uid(), v_new.teacher_assignment_id, public.current_app_role(),
      CASE WHEN v_old.teacher_assignment_id IS NULL THEN 'TEACHER_ASSIGNED' ELSE 'TEACHER_REPLACED' END,
      'teacher_assignments', CASE WHEN v_old.teacher_assignment_id IS NULL THEN NULL ELSE to_jsonb(v_old) END,
      to_jsonb(v_new), nullif(btrim(p_replacement_reason), ''));
    RETURN NEXT v_new;
  END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION public.sync_student_subject_enrollments()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_year_id uuid;
BEGIN
  IF NEW.enddate IS NOT NULL THEN RETURN NEW; END IF;
  SELECT academic_year_id INTO v_year_id FROM public.school_academic_years WHERE is_current;
  IF v_year_id IS NULL THEN RETURN NEW; END IF;
  INSERT INTO public.student_subject_enrollments(student_id, class_subject_id, academic_year_id, source, enrolled_by)
  SELECT NEW.studentid, csc.class_subject_id, v_year_id, 'CLASS_PLACEMENT', auth.uid()
  FROM public.class_subject_catalog csc
  WHERE csc.class_id = NEW.classid AND csc.is_active
  ON CONFLICT (student_id, class_subject_id, academic_year_id)
  DO UPDATE SET is_active = true, ended_at = NULL;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS sync_student_subject_enrollments_trigger ON public.studentclasshistory;
CREATE TRIGGER sync_student_subject_enrollments_trigger
AFTER INSERT OR UPDATE OF classid, enddate ON public.studentclasshistory
FOR EACH ROW EXECUTE FUNCTION public.sync_student_subject_enrollments();

CREATE OR REPLACE FUNCTION public.is_current_teacher_for_class_subject(p_class_subject_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.teacher_assignments ta
    JOIN public.school_academic_years ay ON ay.academic_year_id = ta.academic_year_id AND ay.is_current
    JOIN public.staff st ON st.staffid = ta.staff_id
    WHERE ta.class_subject_id = p_class_subject_id AND ta.status = 'ACTIVE' AND st.userid = auth.uid()
  )
$$;

ALTER TABLE public.class_subject_catalog ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.teacher_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.student_subject_enrollments ENABLE ROW LEVEL SECURITY;

CREATE POLICY class_subject_catalog_read ON public.class_subject_catalog FOR SELECT TO authenticated USING (true);
CREATE POLICY class_subject_catalog_admin ON public.class_subject_catalog FOR ALL TO authenticated
USING (public.has_app_role('ADMINISTRATOR') OR public.has_app_role('SUPER_USER'))
WITH CHECK (public.has_app_role('ADMINISTRATOR') OR public.has_app_role('SUPER_USER'));
CREATE POLICY teacher_assignments_read ON public.teacher_assignments FOR SELECT TO authenticated
USING (public.has_app_role('ADMINISTRATOR') OR public.has_app_role('SUPER_USER') OR public.has_app_role('HEAD_TEACHER') OR
  EXISTS (SELECT 1 FROM public.staff st WHERE st.staffid = staff_id AND st.userid = auth.uid()));
CREATE POLICY student_subject_enrollments_staff_read ON public.student_subject_enrollments FOR SELECT TO authenticated
USING (public.has_app_role('ADMINISTRATOR') OR public.has_app_role('SUPER_USER') OR public.has_app_role('HEAD_TEACHER') OR
  public.is_current_teacher_for_class_subject(class_subject_id));
CREATE POLICY student_subject_enrollments_admin_manage ON public.student_subject_enrollments FOR ALL TO authenticated
USING (public.has_app_role('ADMINISTRATOR') OR public.has_app_role('SUPER_USER'))
WITH CHECK (public.has_app_role('ADMINISTRATOR') OR public.has_app_role('SUPER_USER'));

GRANT SELECT ON public.class_subject_catalog, public.teacher_assignments, public.student_subject_enrollments TO authenticated;
GRANT INSERT, UPDATE, DELETE ON public.class_subject_catalog, public.student_subject_enrollments TO authenticated;
REVOKE ALL ON FUNCTION public.configure_class_subjects(uuid, uuid[]),
  public.assign_teacher_to_class_subjects(uuid, uuid[], text),
  public.is_current_teacher_for_class_subject(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.configure_class_subjects(uuid, uuid[]),
  public.assign_teacher_to_class_subjects(uuid, uuid[], text),
  public.is_current_teacher_for_class_subject(uuid) TO authenticated;

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('staff-profiles', 'staff-profiles', false, 3145728, ARRAY['image/jpeg', 'image/png', 'image/webp'])
ON CONFLICT (id) DO UPDATE SET public = false, file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

CREATE POLICY staff_profiles_admin_manage ON storage.objects FOR ALL TO authenticated
USING (bucket_id = 'staff-profiles' AND (public.has_app_role('ADMINISTRATOR') OR public.has_app_role('SUPER_USER')))
WITH CHECK (bucket_id = 'staff-profiles' AND (public.has_app_role('ADMINISTRATOR') OR public.has_app_role('SUPER_USER')));
CREATE POLICY staff_profiles_owner_read ON storage.objects FOR SELECT TO authenticated
USING (bucket_id = 'staff-profiles' AND EXISTS (
  SELECT 1 FROM public.staff st WHERE st.userid = auth.uid() AND (storage.foldername(name))[1] = st.staffid::text
));

NOTIFY pgrst, 'reload schema';
COMMIT;
