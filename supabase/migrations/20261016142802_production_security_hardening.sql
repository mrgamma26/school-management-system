BEGIN;

-- This migration is safe to replay on a brand-new database AND on the linked
-- project. Some objects below (performance_summary_mv, rls_auto_enable,
-- update_updatedat_column, update_timestamp) only ever existed on the hosted
-- project, so each statement is applied only when its target exists.
DO $$
DECLARE
  v_sig text;
  v_fn  regprocedure;
BEGIN
  -- Keep student performance aggregates out of the public Data API.
  IF to_regclass('public.performance_summary_mv') IS NOT NULL THEN
    EXECUTE 'REVOKE ALL PRIVILEGES ON TABLE public.performance_summary_mv FROM anon, authenticated';
  END IF;

  -- Legacy trigger functions are only for database triggers.
  FOREACH v_sig IN ARRAY ARRAY[
    'audit_payment_channel_change()',
    'rls_auto_enable()'
  ] LOOP
    v_fn := to_regprocedure('public.' || v_sig);
    IF v_fn IS NOT NULL THEN
      EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC, anon, authenticated', v_fn);
    END IF;
  END LOOP;

  -- Existing application RPCs are for signed-in users only.
  FOREACH v_sig IN ARRAY ARRAY[
    'current_app_role()',
    'current_user_is_active()',
    'is_app_role(text)',
    'teacher_can_read_student(uuid)',
    'get_student_status_values()',
    'close_current_class_placement(uuid)',
    'complete_current_user_password_change()',
    'calculate_student_annual_result(uuid, integer)',
    'refresh_progression_review(uuid, integer)',
    'decide_and_place_student(uuid, text, uuid, text)',
    'continue_student_to_term(uuid, uuid, uuid)',
    'finalize_student_school_year(uuid, integer)',
    'record_payment_v2(uuid, uuid, numeric, date, text, uuid, text, numeric, jsonb)'
  ] LOOP
    v_fn := to_regprocedure('public.' || v_sig);
    IF v_fn IS NOT NULL THEN
      EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC, anon', v_fn);
    END IF;
  END LOOP;

  -- Pin the search_path of helper functions.
  FOREACH v_sig IN ARRAY ARRAY[
    'update_updatedat_column()',
    'close_current_class_placement(uuid)',
    'set_updated_at()',
    'update_timestamp()'
  ] LOOP
    v_fn := to_regprocedure('public.' || v_sig);
    IF v_fn IS NOT NULL THEN
      EXECUTE format('ALTER FUNCTION %s SET search_path = public, pg_catalog', v_fn);
    END IF;
  END LOOP;
END
$$;

NOTIFY pgrst, 'reload schema';
COMMIT;
