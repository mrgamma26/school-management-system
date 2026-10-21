-- 0009_comms_tables.sql
-- Communication tables from ERD 5: notification, teachercomment, calendarevent.
-- Run AFTER 0008_finance_tables.sql.

-- ─────────────────────────────────────────────
-- notification
-- A message sent from staff to a guardian.
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.notification (
  notificationid UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  guardianid     UUID        NOT NULL REFERENCES public.guardian(guardianid),
  sentby         UUID        NOT NULL REFERENCES public.staff(staffid),
  subject        VARCHAR(255) NOT NULL,
  message        TEXT        NOT NULL,
  emailstatus    public.email_status_enum  NOT NULL DEFAULT 'PENDING',
  readstatus     public.read_status_enum   NOT NULL DEFAULT 'UNREAD',
  sentat         TIMESTAMPTZ,
  readat         TIMESTAMPTZ,
  createdat      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updatedat      TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- ─────────────────────────────────────────────
-- teachercomment
-- A narrative comment written by a teacher about a student for a term.
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.teachercomment (
  commentid      UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  studentid      UUID        NOT NULL REFERENCES public.student(studentid),
  staffid        UUID        NOT NULL REFERENCES public.staff(staffid),
  academicyearid UUID        NOT NULL REFERENCES public.academicyear(academicyearid),
  comment        TEXT        NOT NULL,
  createdat      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updatedat      TIMESTAMPTZ NOT NULL DEFAULT now(),
  -- One comment per student per teacher per term
  UNIQUE (studentid, staffid, academicyearid)
);
-- ─────────────────────────────────────────────
-- calendarevent
-- A school event attached to a class (or school-wide when classid is null).
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.calendarevent (
  eventid     UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  classid     UUID        REFERENCES public.class(classid) ON DELETE SET NULL,
  createdby   UUID        NOT NULL REFERENCES public.staff(staffid),
  eventname   VARCHAR(255) NOT NULL,
  eventtype   VARCHAR(50)  NOT NULL,
  description TEXT,
  starttime   TIMESTAMPTZ NOT NULL,
  endtime     TIMESTAMPTZ NOT NULL CHECK (endtime > starttime),
  createdat   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updatedat   TIMESTAMPTZ NOT NULL DEFAULT now()
);
