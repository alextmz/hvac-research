
alter table public.research_work_leases enable row level security;

do $$
declare
  r record;
begin
  for r in
    select p.oid::regprocedure as signature
    from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public'
      and p.proname in (
        'classify_research_stage',
        'prepare_research_queue_coordination',
        'heartbeat_research_run',
        'heartbeat_research_work',
        'claim_research_work',
        'release_research_work',
        'recover_stale_research',
        'begin_research_run',
        'research_integrity_health',
        'commit_research_fact'
      )
  loop
    execute format('alter function %s set search_path = %L', r.signature, '');
  end loop;
end
$$;
