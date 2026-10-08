create or replace function public.get_student_status_values()
returns text[]
language sql
stable
security definer
set search_path = public
as $$
  select array_agg(e.enumlabel order by e.enumsortorder)
  from pg_enum e
  join pg_type t on t.oid = e.enumtypid
  where t.typname = 'student_status_enum';
$$;

grant execute on function public.get_student_status_values() to authenticated;