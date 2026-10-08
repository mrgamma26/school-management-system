-- 0001_types.sql
-- Custom enum types used across the schema.
-- Run this migration FIRST before any table creation.

-- Gender enum
DO $$ BEGIN
  CREATE TYPE public.gender_type AS ENUM ('MALE', 'FEMALE');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Enrollment status enum
DO $$ BEGIN
  CREATE TYPE public.student_status_enum AS ENUM (
    'ENROLLED',
    'WITHDRAWN',
    'GRADUATED',
    'TRANSFERRED',
    'SUSPENDED'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Academic term enum
DO $$ BEGIN
  CREATE TYPE public.term_type AS ENUM ('TERM_1', 'TERM_2', 'TERM_3');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Assessment type enum
DO $$ BEGIN
  CREATE TYPE public.assessment_type AS ENUM (
    'QUIZ',
    'TEST',
    'EXAM',
    'ASSIGNMENT',
    'PROJECT',
    'PRACTICAL'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Grade status enum
DO $$ BEGIN
  CREATE TYPE public.grade_status AS ENUM (
    'PENDING',
    'PRESENT',
    'ABSENT',
    'MISSING',
    'INCOMPLETE',
    'FINAL'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Progression / weeding decision enum
DO $$ BEGIN
  CREATE TYPE public.review_decision AS ENUM (
    'PENDING',
    'APPROVED',
    'RETAINED',
    'REJECTED'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
