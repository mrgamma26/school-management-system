-- Reassert the calendar authorization contract after repairing the historical
-- 0031 source file. This migration is intentionally safe on databases where
-- the structural portion of 0031 was applied manually.

ALTER TABLE public.calendarevent
  ALTER COLUMN createdby DROP NOT NULL;
ALTER TABLE public.calendarevent
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
CREATE INDEX IF NOT EXISTS idx_calendarevent_createdbyuser
  ON public.calendarevent(createdbyuser);
DROP POLICY IF EXISTS "staff can manage own events" ON public.calendarevent;
DROP POLICY IF EXISTS "privileged roles can manage all events" ON public.calendarevent;
DROP POLICY IF EXISTS "administrators create calendar events" ON public.calendarevent;
DROP POLICY IF EXISTS "administrators update calendar events" ON public.calendarevent;
DROP POLICY IF EXISTS "administrators delete calendar events" ON public.calendarevent;
CREATE POLICY "administrators create calendar events"
ON public.calendarevent
FOR INSERT
TO authenticated
WITH CHECK (
  public.current_app_role() IN ('SUPER_USER', 'SYSTEM_ADMIN', 'ADMINISTRATOR')
  AND createdbyuser = auth.uid()
);
CREATE POLICY "administrators update calendar events"
ON public.calendarevent
FOR UPDATE
TO authenticated
USING (
  public.current_app_role() IN ('SUPER_USER', 'SYSTEM_ADMIN', 'ADMINISTRATOR')
)
WITH CHECK (
  public.current_app_role() IN ('SUPER_USER', 'SYSTEM_ADMIN', 'ADMINISTRATOR')
);
CREATE POLICY "administrators delete calendar events"
ON public.calendarevent
FOR DELETE
TO authenticated
USING (
  public.current_app_role() IN ('SUPER_USER', 'SYSTEM_ADMIN', 'ADMINISTRATOR')
);
CREATE OR REPLACE FUNCTION public.create_calendar_events(events jsonb)
RETURNS void
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
DECLARE
  event_count integer;
BEGIN
  IF auth.uid() IS NULL OR public.current_app_role() NOT IN (
    'SUPER_USER', 'SYSTEM_ADMIN', 'ADMINISTRATOR'
  ) THEN
    RAISE EXCEPTION 'Not authorized to manage calendar events'
      USING ERRCODE = '42501';
  END IF;

  IF jsonb_typeof(events) <> 'array' THEN
    RAISE EXCEPTION 'Calendar events must be a JSON array'
      USING ERRCODE = '22023';
  END IF;

  event_count := jsonb_array_length(events);
  IF event_count < 1 OR event_count > 366 THEN
    RAISE EXCEPTION 'Calendar event batch must contain between 1 and 366 items'
      USING ERRCODE = '22023';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM jsonb_array_elements(events) AS item
    WHERE jsonb_typeof(item) <> 'object'
      OR BTRIM(COALESCE(item->>'eventname', '')) = ''
      OR item->>'eventtype' IS NULL
      OR item->>'starttime' IS NULL
      OR item->>'endtime' IS NULL
      OR (item->>'endtime')::timestamptz < (item->>'starttime')::timestamptz
  ) THEN
    RAISE EXCEPTION 'Each calendar event requires valid details and an end time after its start time'
      USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.calendarevent (
    classid,
    createdby,
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
    NULLIF(item->>'classid', '')::uuid,
    NULL,
    auth.uid(),
    BTRIM(item->>'eventname'),
    (item->>'eventtype')::public.calendar_event_type,
    NULLIF(BTRIM(item->>'description'), ''),
    (item->>'starttime')::timestamptz,
    (item->>'endtime')::timestamptz,
    COALESCE((item->>'allday')::boolean, false),
    NULLIF(item->>'academicyearid', '')::uuid
  FROM jsonb_array_elements(events) AS item;
END;
$$;
REVOKE ALL ON FUNCTION public.create_calendar_events(jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.create_calendar_events(jsonb) FROM anon;
GRANT EXECUTE ON FUNCTION public.create_calendar_events(jsonb) TO authenticated;
