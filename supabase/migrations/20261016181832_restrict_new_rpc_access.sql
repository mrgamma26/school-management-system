BEGIN;

-- The linked project has explicit default EXECUTE grants for anon. Revoke
-- those grants on every newly introduced role-checked RPC, while preserving
-- the authenticated grants and each function's own role checks.
REVOKE ALL ON FUNCTION public.current_app_roles() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.has_app_role(text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.save_academic_year(uuid, text, date, date, jsonb, boolean) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.activate_academic_year(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.set_current_academic_term(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.configure_class_subjects(uuid, uuid[]) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.assign_teacher_to_class_subjects(uuid, uuid[], text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.is_current_teacher_for_class_subject(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.publish_assessment_results(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.request_result_correction(uuid, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.decide_result_correction(uuid, boolean, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.complete_result_correction(uuid, numeric) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.reverse_payment(uuid, text) FROM PUBLIC, anon;

-- Trigger functions are internal to the database and need no API grants.
REVOKE ALL ON FUNCTION public.set_foundation_updated_at() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.validate_academic_year_term() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.validate_user_role_pair() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.audit_school_settings_change() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.sync_student_subject_enrollments() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.prevent_published_grade_mutation() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.prevent_posted_payment_mutation() FROM PUBLIC, anon, authenticated;

-- The public branding RPC intentionally remains anonymous because the login
-- screen displays only school name, logo path and motto.
NOTIFY pgrst, 'reload schema';
COMMIT;
