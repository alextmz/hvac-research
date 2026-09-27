alter function public.relative_difference_pct(numeric,numeric)
  set search_path = pg_catalog;
alter function public.hardware_values_within_tolerance(numeric,numeric,numeric)
  set search_path = pg_catalog;
alter function public.hardware_platform_field_inheritable(text)
  set search_path = pg_catalog;

create index if not exists hardware_platform_memberships_run_id_idx
  on public.hardware_platform_memberships(run_id);
