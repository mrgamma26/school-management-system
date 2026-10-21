-- 0012_calendar_event_type.sql
-- Converts calendarevent.eventtype from free-text VARCHAR to a proper enum.
-- Also updates RLS so ADMINISTRATOR (renamed from REGISTRAR) can manage all events.
-- Run AFTER 0011_finance_comms_rls.sql.

-- ─────────────────────────────────────────────
-- 1. Create the enum type
-- ─────────────────────────────────────────────
DO $$ BEGIN
  CREATE TYPE public.calendar_event_type AS ENUM (
    'PUBLIC_HOLIDAY',   -- national/public holiday, no school
    'EXAM',             -- examination day(s)
    'TIMETABLE',        -- class timetable event / lesson schedule
    'SCHOOL_EVENT',     -- sports day, open day, parent-teacher meeting, etc.
    'TERM_DATE'         -- term start / end / half-term break
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
-- ─────────────────────────────────────────────
-- 2. Migrate existing rows — map any old free-text to the closest enum value.
--    Unknown values default to SCHOOL_EVENT so nothing is lost.
-- ─────────────────────────────────────────────
UPDATE public.calendarevent
SET eventtype = CASE
  WHEN UPPER(eventtype) LIKE '%HOLIDAY%'  THEN 'PUBLIC_HOLIDAY'
  WHEN UPPER(eventtype) LIKE '%EXAM%'     THEN 'EXAM'
  WHEN UPPER(eventtype) LIKE '%TIMETABLE%'THEN 'TIMETABLE'
  WHEN UPPER(eventtype) LIKE '%TERM%'     THEN 'TERM_DATE'
  ELSE 'SCHOOL_EVENT'
END;
-- ─────────────────────────────────────────────
-- 3. Alter the column to use the new enum
-- ─────────────────────────────────────────────
ALTER TABLE public.calendarevent
  ALTER COLUMN eventtype TYPE public.calendar_event_type
  USING eventtype::public.calendar_event_type;
-- ─────────────────────────────────────────────
-- 4. Add allday flag and optional class label
--    (useful for full-day events like public holidays)
-- ─────────────────────────────────────────────
ALTER TABLE public.calendarevent
  ADD COLUMN IF NOT EXISTS allday BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE public.calendarevent
  ADD COLUMN IF NOT EXISTS academicyearid UUID
    REFERENCES public.academicyear(academicyearid) ON DELETE SET NULL;
-- Index for filtering by academic year
CREATE INDEX IF NOT EXISTS idx_calendarevent_academicyearid
  ON public.calendarevent(academicyearid);
-- ─────────────────────────────────────────────
-- 5. Fix RLS — add ADMINISTRATOR role to management policies.
--    Drop the old head-teacher policy and recreate it to include ADMINISTRATOR.
-- ─────────────────────────────────────────────
DROP POLICY IF EXISTS "head teacher can manage all events" ON public.calendarevent;
CREATE POLICY "privileged roles can manage all events"
ON public.calendarevent FOR ALL TO authenticated
USING (
  public.current_app_role() IN (
    'HEAD_TEACHER',
    'SYSTEM_ADMIN',
    'ADMINISTRATOR',
    'REGISTRAR'        -- legacy alias kept for safety
  )
);
