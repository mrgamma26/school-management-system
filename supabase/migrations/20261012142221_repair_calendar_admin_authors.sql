BEGIN;
-- Migration 0031 was committed as plain text, so deployed databases may be
-- missing all or part of the intended calendar-author changes. Repair the
-- schema forward without rewriting migration history or deleting events.
ALTER TABLE public.calendarevent
  ALTER COLUMN createdby DROP NOT NULL,
  ADD COLUMN IF NOT EXISTS createdbyuser uuid;
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'calendarevent_createdbyuser_fkey'
      AND conrelid = 'public.calendarevent'::regclass
  ) THEN
    ALTER TABLE public.calendarevent
      ADD CONSTRAINT calendarevent_createdbyuser_fkey
      FOREIGN KEY (createdbyuser)
      REFERENCES public.systemuser(userid)
      ON DELETE SET NULL;
  END IF;
END
$$;
-- Preserve legacy staff authors while linking them to their system user when
-- the relationship is available.
UPDATE public.calendarevent AS event
SET createdbyuser = staff_member.userid
FROM public.staff AS staff_member
WHERE event.createdby = staff_member.staffid
  AND event.createdbyuser IS NULL;
CREATE INDEX IF NOT EXISTS idx_calendarevent_createdbyuser
  ON public.calendarevent(createdbyuser);
ALTER TABLE public.calendarevent ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "authenticated users can read calendar events"
  ON public.calendarevent;
DROP POLICY IF EXISTS "staff can manage own events"
  ON public.calendarevent;
DROP POLICY IF EXISTS "head teacher can manage all events"
  ON public.calendarevent;
DROP POLICY IF EXISTS "privileged roles can manage all events"
  ON public.calendarevent;
DROP POLICY IF EXISTS "administrators create calendar events"
  ON public.calendarevent;
DROP POLICY IF EXISTS "administrators update calendar events"
  ON public.calendarevent;
DROP POLICY IF EXISTS "administrators delete calendar events"
  ON public.calendarevent;
DROP POLICY IF EXISTS "admins manage calendar events"
  ON public.calendarevent;
DROP POLICY IF EXISTS "calendar insert admin guard"
  ON public.calendarevent;
DROP POLICY IF EXISTS "calendar update admin guard"
  ON public.calendarevent;
DROP POLICY IF EXISTS "calendar delete admin guard"
  ON public.calendarevent;
DROP POLICY IF EXISTS "calendar administrators can insert events"
  ON public.calendarevent;
DROP POLICY IF EXISTS "calendar administrators can update events"
  ON public.calendarevent;
DROP POLICY IF EXISTS "calendar administrators can delete events"
  ON public.calendarevent;
CREATE POLICY "authenticated users can read calendar events"
ON public.calendarevent
FOR SELECT
TO authenticated
USING (true);
CREATE POLICY "calendar administrators can insert events"
ON public.calendarevent
FOR INSERT
TO authenticated
WITH CHECK (
  (SELECT upper(coalesce(public.current_app_role(), ''))) IN (
    'SUPER_USER', 'SYSTEM_ADMIN', 'ADMINISTRATOR', 'ADMIN'
  )
  AND createdby IS NULL
  AND createdbyuser = (SELECT auth.uid())
);
CREATE POLICY "calendar administrators can update events"
ON public.calendarevent
FOR UPDATE
TO authenticated
USING (
  (SELECT upper(coalesce(public.current_app_role(), ''))) IN (
    'SUPER_USER', 'SYSTEM_ADMIN', 'ADMINISTRATOR', 'ADMIN'
  )
)
WITH CHECK (
  (SELECT upper(coalesce(public.current_app_role(), ''))) IN (
    'SUPER_USER', 'SYSTEM_ADMIN', 'ADMINISTRATOR', 'ADMIN'
  )
);
CREATE POLICY "calendar administrators can delete events"
ON public.calendarevent
FOR DELETE
TO authenticated
USING (
  (SELECT upper(coalesce(public.current_app_role(), ''))) IN (
    'SUPER_USER', 'SYSTEM_ADMIN', 'ADMINISTRATOR', 'ADMIN'
  )
);
GRANT SELECT, INSERT, UPDATE, DELETE
  ON TABLE public.calendarevent
  TO authenticated;
-- The live repair function may return void. PostgreSQL cannot change a
-- function's return type through CREATE OR REPLACE, so replace it atomically.
DROP FUNCTION IF EXISTS public.create_calendar_events(jsonb);
CREATE OR REPLACE FUNCTION public.create_calendar_events(events jsonb)
RETURNS SETOF public.calendarevent
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  actor_id uuid := (SELECT auth.uid());
  actor_role text := (SELECT upper(coalesce(public.current_app_role(), '')));
BEGIN
  IF actor_id IS NULL THEN
    RAISE EXCEPTION USING
      ERRCODE = '42501',
      MESSAGE = 'Authentication is required to create calendar events';
  END IF;

  IF actor_role NOT IN (
    'SUPER_USER', 'SYSTEM_ADMIN', 'ADMINISTRATOR', 'ADMIN'
  ) THEN
    RAISE EXCEPTION USING
      ERRCODE = '42501',
      MESSAGE = 'Only administrators can create calendar events';
  END IF;

  IF events IS NULL
     OR jsonb_typeof(events) <> 'array'
     OR jsonb_array_length(events) = 0
     OR jsonb_array_length(events) > 366 THEN
    RAISE EXCEPTION USING
      ERRCODE = '22023',
      MESSAGE = 'Select between 1 and 366 calendar event dates';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM jsonb_array_elements(events) AS requested_event(value)
    WHERE jsonb_typeof(requested_event.value) <> 'object'
  ) THEN
    RAISE EXCEPTION USING
      ERRCODE = '22023',
      MESSAGE = 'Each calendar event must be a JSON object';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM jsonb_array_elements(events) AS requested_event(value)
    WHERE nullif(btrim(requested_event.value->>'eventname'), '') IS NULL
       OR length(btrim(requested_event.value->>'eventname')) > 255
  ) THEN
    RAISE EXCEPTION USING
      ERRCODE = '22023',
      MESSAGE = 'Each calendar event must have a name of 255 characters or fewer';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM jsonb_array_elements(events) AS requested_event(value)
    WHERE NOT EXISTS (
      SELECT 1
      FROM unnest(enum_range(NULL::public.calendar_event_type)) AS allowed(value)
      WHERE allowed.value::text = requested_event.value->>'eventtype'
    )
  ) THEN
    RAISE EXCEPTION USING
      ERRCODE = '22023',
      MESSAGE = 'Each calendar event must have a valid event type';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM jsonb_array_elements(events) AS requested_event(value)
    WHERE nullif(requested_event.value->>'starttime', '') IS NULL
       OR nullif(requested_event.value->>'endtime', '') IS NULL
       OR (requested_event.value->>'endtime')::timestamptz
          <= (requested_event.value->>'starttime')::timestamptz
  ) THEN
    RAISE EXCEPTION USING
      ERRCODE = '22023',
      MESSAGE = 'Each calendar event must end after it starts';
  END IF;

  RETURN QUERY
  INSERT INTO public.calendarevent (
    classid,
    createdbyuser,
    eventname,
    eventtype,
    description,
    starttime,
    endtime,
    allday,
    academicyearid
  )
  SELECT
    nullif(requested_event.value->>'classid', '')::uuid,
    actor_id,
    btrim(requested_event.value->>'eventname'),
    (requested_event.value->>'eventtype')::public.calendar_event_type,
    nullif(requested_event.value->>'description', ''),
    (requested_event.value->>'starttime')::timestamptz,
    (requested_event.value->>'endtime')::timestamptz,
    coalesce((requested_event.value->>'allday')::boolean, false),
    nullif(requested_event.value->>'academicyearid', '')::uuid
  FROM jsonb_array_elements(events) WITH ORDINALITY
    AS requested_event(value, position)
  ORDER BY requested_event.position
  RETURNING *;
END;
$$;
REVOKE ALL
  ON FUNCTION public.create_calendar_events(jsonb)
  FROM PUBLIC;
REVOKE ALL
  ON FUNCTION public.create_calendar_events(jsonb)
  FROM anon;
GRANT EXECUTE
  ON FUNCTION public.create_calendar_events(jsonb)
  TO authenticated;
NOTIFY pgrst, 'reload schema';
COMMIT;
