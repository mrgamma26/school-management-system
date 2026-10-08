-- Keep academic-year creation compatible with the older termname column.

ALTER TABLE public.academicyear
  ADD COLUMN IF NOT EXISTS termname TEXT NOT NULL DEFAULT 'TERM_1';

ALTER TABLE public.academicyear
  ALTER COLUMN termname SET DEFAULT 'TERM_1';

UPDATE public.academicyear
SET term = CASE termname
  WHEN 'TERM_1' THEN 'TERM_1'::public.term_type
  WHEN 'TERM_2' THEN 'TERM_2'::public.term_type
  WHEN 'TERM_3' THEN 'TERM_3'::public.term_type
  ELSE 'TERM_1'::public.term_type
END;
