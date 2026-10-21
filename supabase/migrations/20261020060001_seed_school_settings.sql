BEGIN;

-- Data-only companion migration for the singleton removed by an earlier test
-- reset. It is idempotent and does not overwrite an existing school's values.
INSERT INTO public.school_settings (settings_id)
VALUES ('00000000-0000-0000-0000-000000000001')
ON CONFLICT (settings_id) DO NOTHING;

COMMIT;
