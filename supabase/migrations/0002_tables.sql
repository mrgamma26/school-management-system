-- 0002_tables.sql
-- All application tables in dependency order.
-- Run AFTER 0001_types.sql.

-- ─────────────────────────────────────────────
-- role
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.role (
  roleid      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  rolename    TEXT NOT NULL UNIQUE,
  description TEXT,
  createdat   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updatedat   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ─────────────────────────────────────────────
-- rolepermission
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.rolepermission (
  permissionid   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  roleid         UUID NOT NULL REFERENCES public.role(roleid) ON DELETE CASCADE,
  permissionname TEXT NOT NULL,
  createdat      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ─────────────────────────────────────────────
-- systemuser  (linked to auth.users via userid)
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.systemuser (
  userid             UUID PRIMARY KEY,
  roleid             UUID NOT NULL REFERENCES public.role(roleid),
  username           TEXT NOT NULL UNIQUE,
  mustchangepassword BOOLEAN NOT NULL DEFAULT TRUE,
  isactive           BOOLEAN NOT NULL DEFAULT TRUE,
  createdat          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updatedat          TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ─────────────────────────────────────────────
-- staff
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.staff (
  staffid        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  userid         UUID NOT NULL UNIQUE REFERENCES public.systemuser(userid) ON DELETE CASCADE,
  employeenumber TEXT NOT NULL UNIQUE,
  firstname      TEXT NOT NULL,
  middlename     TEXT,
  lastname       TEXT NOT NULL,
  gender         public.gender_type NOT NULL,
  email          TEXT NOT NULL UNIQUE,
  createdat      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updatedat      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ─────────────────────────────────────────────
-- guardian
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.guardian (
  guardianid      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  userid          UUID NOT NULL UNIQUE REFERENCES public.systemuser(userid) ON DELETE CASCADE,
  firstname       TEXT NOT NULL,
  middlename      TEXT,
  lastname        TEXT NOT NULL,
  gender          public.gender_type NOT NULL,
  phonenumber     TEXT,
  physicaladdress TEXT,
  email           TEXT NOT NULL UNIQUE,
  createdat       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updatedat       TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ─────────────────────────────────────────────
-- auditlog
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.auditlog (
  auditid       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  userid        UUID REFERENCES public.systemuser(userid) ON DELETE SET NULL,
  recordid      TEXT,
  usertype      TEXT,
  action        TEXT NOT NULL,
  tablename     TEXT NOT NULL,
  previousvalue JSONB,
  newvalue      JSONB,
  reason        TEXT,
  createdat     TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ─────────────────────────────────────────────
-- academicyear
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.academicyear (
  academicyearid UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  academicyear   INTEGER NOT NULL,
  term           public.term_type NOT NULL,
  form           TEXT CHECK (form IN ('FORM_1', 'FORM_2', 'FORM_3', 'FORM_4')),
  startdate      DATE NOT NULL,
  enddate        DATE NOT NULL,
  createdat      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updatedat      TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (academicyear, term, form)
);

-- ─────────────────────────────────────────────
-- class
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.class (
  classid   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  classname TEXT NOT NULL UNIQUE,
  formlevel INTEGER,
  createdat TIMESTAMPTZ NOT NULL DEFAULT now(),
  updatedat TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ─────────────────────────────────────────────
-- subject
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.subject (
  subjectid   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  subjectname TEXT NOT NULL UNIQUE,
  description TEXT,
  createdat   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updatedat   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ─────────────────────────────────────────────
-- classsubject  (teaching assignment)
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.classsubject (
  classsubjectid UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  classid        UUID NOT NULL REFERENCES public.class(classid),
  subjectid      UUID NOT NULL REFERENCES public.subject(subjectid),
  staffid        UUID NOT NULL REFERENCES public.staff(staffid),
  academicyearid UUID NOT NULL REFERENCES public.academicyear(academicyearid),
  createdat      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updatedat      TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (classid, subjectid, academicyearid)
);

-- ─────────────────────────────────────────────
-- student
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.student (
  studentid        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  firstname        TEXT NOT NULL,
  middlename       TEXT,
  lastname         TEXT NOT NULL,
  gender           public.gender_type NOT NULL,
  dateofbirth      DATE NOT NULL,
  physicaladdress  TEXT,
  enrollmentstatus public.student_status_enum NOT NULL DEFAULT 'ENROLLED',
  createdat        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updatedat        TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ─────────────────────────────────────────────
-- studentguardian  (many-to-many)
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.studentguardian (
  studentguardianid UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  studentid         UUID NOT NULL REFERENCES public.student(studentid) ON DELETE CASCADE,
  guardianid        UUID NOT NULL REFERENCES public.guardian(guardianid),
  relationship      TEXT NOT NULL,
  createdat         TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (studentid, guardianid)
);

-- ─────────────────────────────────────────────
-- studentclasshistory
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.studentclasshistory (
  historyid      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  studentid      UUID NOT NULL REFERENCES public.student(studentid) ON DELETE CASCADE,
  classid        UUID NOT NULL REFERENCES public.class(classid),
  academicyearid UUID NOT NULL REFERENCES public.academicyear(academicyearid),
  enrollmentdate DATE NOT NULL,
  enddate        DATE,
  createdat      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updatedat      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ─────────────────────────────────────────────
-- assessment
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.assessment (
  assessmentid   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  classsubjectid UUID NOT NULL REFERENCES public.classsubject(classsubjectid) ON DELETE CASCADE,
  assessmentname TEXT NOT NULL,
  assessmenttype public.assessment_type NOT NULL,
  maxscore       NUMERIC(6,2) NOT NULL CHECK (maxscore > 0),
  createdat      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updatedat      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ─────────────────────────────────────────────
-- grade
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.grade (
  gradeid     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  assessmentid UUID NOT NULL REFERENCES public.assessment(assessmentid) ON DELETE CASCADE,
  studentid   UUID NOT NULL REFERENCES public.student(studentid) ON DELETE CASCADE,
  enteredby   UUID NOT NULL REFERENCES public.staff(staffid),
  score       NUMERIC(6,2),
  gradestatus public.grade_status NOT NULL DEFAULT 'PENDING',
  createdat   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updatedat   TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (assessmentid, studentid)
);

-- ─────────────────────────────────────────────
-- progressionreview
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.progressionreview (
  reviewid       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  studentid      UUID NOT NULL REFERENCES public.student(studentid) ON DELETE CASCADE,
  academicyearid UUID NOT NULL REFERENCES public.academicyear(academicyearid),
  averagescore   NUMERIC(6,2),
  decision       public.review_decision NOT NULL DEFAULT 'PENDING',
  approvedby     UUID REFERENCES public.staff(staffid),
  createdat      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updatedat      TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (studentid, academicyearid)
);

-- ─────────────────────────────────────────────
-- weedingreview
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.weedingreview (
  weedingid         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  studentid         UUID NOT NULL REFERENCES public.student(studentid) ON DELETE CASCADE,
  academicyearid    UUID NOT NULL REFERENCES public.academicyear(academicyearid),
  cumulativeaverage NUMERIC(6,2),
  decision          public.review_decision NOT NULL DEFAULT 'PENDING',
  decisionreason    TEXT,
  flaggeddate       DATE NOT NULL DEFAULT CURRENT_DATE,
  decisiondate      DATE,
  decidedby         UUID REFERENCES public.staff(staffid),
  createdat         TIMESTAMPTZ NOT NULL DEFAULT now(),
  updatedat         TIMESTAMPTZ NOT NULL DEFAULT now()
);
