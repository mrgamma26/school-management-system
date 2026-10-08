-- Restore columns required by the Flutter academic-management screens.
-- These are additive changes for projects created from an older schema baseline.

ALTER TABLE public.academicyear
  ADD COLUMN IF NOT EXISTS term public.term_type NOT NULL DEFAULT 'TERM_1';

ALTER TABLE public.subject
  ADD COLUMN IF NOT EXISTS description TEXT;
