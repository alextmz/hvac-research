create extension if not exists pg_cron;

create unique index if not exists conflicts_claim_pair_uidx
on public.conflicts (
  least(claim_a, claim_b),
  greatest(claim_a, claim_b)
);

create or replace view public.canonical_claims as
select distinct on (tc.entity_id, tc.field)
  tc.id,
  tc.entity_id,
  tc.subject_text,
  tc.field,
  tc.value_text,
  tc.value_num,
  tc.unit,
  tc.qualifier,
  tc.status,
  tc.confidence,
  tc.created_at,
  tc.supersedes_claim_id
from public.trusted_claims tc
where not exists (
  select 1
  from public.conflicts cf
  where cf.entity_id = tc.entity_id
    and cf.field = tc.field
    and cf.status = 'open'
)
order by tc.entity_id, tc.field, tc.confidence desc, tc.created_at desc, tc.id desc;

create or replace function public.heartbeat_research_work(
  p_run_id uuid,
  p_lease interval default interval '15 minutes'
)
returns table(
  heartbeat_at timestamptz,
  lease_expires_at timestamptz,
  leased_scopes integer,
  leased_items integer
)
language plpgsql
set search_path = ''
as $$
declare
  v_at timestamptz;
  v_expires timestamptz;
  v_scopes integer;
  v_items integer;
begin
  if p_lease < interval '1 minute' or p_lease > interval '2 hours' then
    raise exception 'lease must be between 1 minute and 2 hours';
  end if;

  v_at := public.heartbeat_research_run(p_run_id);
  v_expires := v_at + p_lease;

  delete from public.research_work_leases l
  where l.run_id = p_run_id
    and not exists (
      select 1
      from public.research_queue q
      where q.work_scope = l.scope_key
        and q.claimed_run_id = p_run_id
        and q.status = 'working'
    );

  update public.research_work_leases l
  set heartbeat_at = v_at,
      expires_at = v_expires
  where l.run_id = p_run_id
    and l.expires_at > v_at
    and exists (
      select 1
      from public.research_queue q
      where q.work_scope = l.scope_key
        and q.claimed_run_id = p_run_id
        and q.status = 'working'
    );
  get diagnostics v_scopes = row_count;

  update public.research_queue q
  set heartbeat_at = v_at,
      lease_expires_at = v_expires
  where q.claimed_run_id = p_run_id
    and q.status = 'working'
    and exists (
      select 1
      from public.research_work_leases l
      where l.scope_key = q.work_scope
        and l.run_id = p_run_id
        and l.expires_at = v_expires
    );
  get diagnostics v_items = row_count;

  return query select v_at, v_expires, v_scopes, v_items;
end
$$;

create or replace function public.recover_stale_research(
  p_stale_after interval default interval '10 minutes'
)
returns table(failed_runs integer, reset_queue integer)
language plpgsql
set search_path = ''
as $$
declare
  v_failed integer := 0;
  v_reset integer := 0;
begin
  if p_stale_after < interval '6 minutes' then
    raise exception 'stale threshold must be at least 6 minutes';
  end if;

  delete from public.research_work_leases l
  where not exists (
    select 1
    from public.research_queue q
    where q.work_scope = l.scope_key
      and q.claimed_run_id = l.run_id
      and q.status = 'working'
  );

  update public.research_runs
  set status = 'failed',
      ended_at = coalesce(ended_at, now()),
      notes = concat_ws(E'\n', notes, 'Automatically marked failed after heartbeat became stale.')
  where status = 'running'
    and coalesce(last_heartbeat_at, started_at) < now() - p_stale_after;
  get diagnostics v_failed = row_count;

  update public.research_queue q
  set status = case when exists (
        select 1
        from public.trusted_claims c
        where c.entity_id = q.entity_id
          and c.field = q.field
      ) then 'done' else 'pending' end,
      claimed_run_id = null,
      claimed_at = null,
      heartbeat_at = null,
      lease_expires_at = null,
      stop_reason = case when exists (
        select 1
        from public.trusted_claims c
        where c.entity_id = q.entity_id
          and c.field = q.field
      ) then null else 'Recovered abandoned or expired work lease' end
  where q.status = 'working'
    and (
      coalesce(q.lease_expires_at, '-infinity'::timestamptz) <= now()
      or not exists (
        select 1
        from public.research_runs r
        where r.id = q.claimed_run_id
          and r.status = 'running'
      )
      or not exists (
        select 1
        from public.research_work_leases l
        where l.scope_key = q.work_scope
          and l.run_id = q.claimed_run_id
          and l.expires_at > now()
      )
    );
  get diagnostics v_reset = row_count;

  delete from public.research_work_leases l
  where l.expires_at <= now()
     or not exists (
       select 1
       from public.research_runs r
       where r.id = l.run_id
         and r.status = 'running'
     )
     or not exists (
       select 1
       from public.research_queue q
       where q.work_scope = l.scope_key
         and q.claimed_run_id = l.run_id
         and q.status = 'working'
     );

  update public.research_runs r
  set status = 'stopped',
      ended_at = coalesce(r.ended_at, now()),
      notes = concat_ws(E'\n', r.notes, 'Automatically stopped after becoming idle with no active leased work.')
  where r.status = 'running'
    and coalesce(r.last_heartbeat_at, r.started_at) < now() - interval '5 minutes'
    and not exists (
      select 1
      from public.research_work_leases l
      join public.research_queue q
        on q.work_scope = l.scope_key
       and q.claimed_run_id = l.run_id
       and q.status = 'working'
      where l.run_id = r.id
        and l.expires_at > now()
    );

  return query select v_failed, v_reset;
end
$$;

create or replace function public.research_integrity_health(
  p_stale_after interval default interval '10 minutes'
)
returns table(metric text, value bigint)
language sql
set search_path = ''
as $$
  select 'running_runs', count(*)::bigint
    from public.research_runs where status='running'
  union all
  select 'effective_active_runs', count(distinct r.id)::bigint
    from public.research_runs r
    join public.research_work_leases l on l.run_id=r.id
    join public.research_queue q
      on q.work_scope=l.scope_key
     and q.claimed_run_id=r.id
     and q.status='working'
    where r.status='running'
      and coalesce(r.last_heartbeat_at,r.started_at) >= now()-p_stale_after
      and l.expires_at > now()
  union all
  select 'stale_running_runs', count(*)::bigint
    from public.research_runs
    where status='running'
      and coalesce(last_heartbeat_at,started_at) < now()-p_stale_after
  union all
  select 'idle_running_runs', count(*)::bigint
    from public.research_runs r
    where r.status='running'
      and coalesce(r.last_heartbeat_at,r.started_at) < now()-interval '5 minutes'
      and not exists (
        select 1
        from public.research_work_leases l
        join public.research_queue q
          on q.work_scope=l.scope_key
         and q.claimed_run_id=l.run_id
         and q.status='working'
        where l.run_id=r.id and l.expires_at>now()
      )
  union all
  select 'working_queue', count(*)::bigint
    from public.research_queue where status='working'
  union all
  select 'stale_working_queue', count(*)::bigint
    from public.research_queue
    where status='working'
      and coalesce(lease_expires_at,last_attempt_at+p_stale_after,claimed_at+p_stale_after,'-infinity'::timestamptz) <= now()
  union all
  select 'working_queue_without_active_lease', count(*)::bigint
    from public.research_queue q
    where q.status='working'
      and not exists (
        select 1 from public.research_work_leases l
        where l.scope_key=q.work_scope
          and l.run_id=q.claimed_run_id
          and l.expires_at>now()
      )
  union all
  select 'active_work_leases', count(*)::bigint
    from public.research_work_leases where expires_at > now()
  union all
  select 'orphan_active_work_leases', count(*)::bigint
    from public.research_work_leases l
    where l.expires_at > now()
      and not exists (
        select 1 from public.research_queue q
        where q.work_scope=l.scope_key
          and q.claimed_run_id=l.run_id
          and q.status='working'
      )
  union all
  select 'expired_work_leases', count(*)::bigint
    from public.research_work_leases where expires_at <= now()
  union all
  select 'open_conflicts', count(*)::bigint
    from public.conflicts where status='open'
  union all
  select 'unquarantined_supported_verified_without_evidence', count(*)::bigint
    from public.claims c
    where c.status in ('supported','verified')
      and not exists (select 1 from public.evidence e where e.claim_id=c.id and e.evidence_kind='supports')
      and not exists (select 1 from public.claim_integrity_quarantine q where q.claim_id=c.id)
  union all
  select 'quarantined_claims', count(*)::bigint
    from public.claim_integrity_quarantine
  union all
  select 'trusted_claims', count(*)::bigint
    from public.trusted_claims
  union all
  select 'canonical_claims', count(*)::bigint
    from public.canonical_claims
$$;

do $$
declare
  v_jobid bigint;
begin
  for v_jobid in
    select jobid from cron.job where jobname='hvac-research-runtime-reconcile'
  loop
    perform cron.unschedule(v_jobid);
  end loop;

  perform cron.schedule(
    'hvac-research-runtime-reconcile',
    '*/5 * * * *',
    'select public.recover_stale_research(interval ''10 minutes'');'
  );
end
$$;
