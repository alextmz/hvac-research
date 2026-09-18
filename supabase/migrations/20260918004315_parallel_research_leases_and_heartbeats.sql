
alter table public.research_runs
  add column if not exists last_heartbeat_at timestamptz,
  add column if not exists heartbeat_count bigint not null default 0;

update public.research_runs
set last_heartbeat_at = coalesce(last_heartbeat_at, started_at)
where last_heartbeat_at is null;

alter table public.research_runs
  alter column last_heartbeat_at set default now(),
  alter column last_heartbeat_at set not null;

alter table public.research_queue
  add column if not exists stage smallint,
  add column if not exists work_scope text,
  add column if not exists claimed_run_id uuid references public.research_runs(id) on delete set null,
  add column if not exists claimed_at timestamptz,
  add column if not exists heartbeat_at timestamptz,
  add column if not exists lease_expires_at timestamptz;

create or replace function public.classify_research_stage(p_field text)
returns smallint
language sql
immutable
as $$
  select case
    when p_field is null then 2
    when p_field like 'audit_%'
      or p_field in ('full_verification_stability_pass') then 5
    when p_field in (
      'included_controller','native_zoning','third_party_zoning_compatibility',
      'home_assistant_path','feature_retention_third_party'
    ) then 3
    when p_field in (
      'current_price_aud','reliability_support','warranty'
    ) then 4
    when p_field like 'census_%'
      or p_field like 'exact_pairing%'
      or p_field in (
        'exact_indoor_outdoor_pairing','exact_engineering_pairing',
        'current_market_status','current_census_resolution'
      ) then 1
    else 2
  end::smallint
$$;

update public.research_queue
set stage = public.classify_research_stage(field)
where stage is null;

update public.research_queue
set work_scope =
  case
    when entity_id is not null then stage::text || ':entity:' || entity_id::text
    else stage::text || ':queue:' || id::text
  end
where work_scope is null;

alter table public.research_queue
  alter column stage set not null,
  alter column work_scope set not null;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'research_queue_stage_check'
      and conrelid = 'public.research_queue'::regclass
  ) then
    alter table public.research_queue
      add constraint research_queue_stage_check check (stage between 1 and 5);
  end if;
end $$;

create or replace function public.prepare_research_queue_coordination()
returns trigger
language plpgsql
as $$
begin
  if new.stage is null then
    new.stage := public.classify_research_stage(new.field);
  end if;
  if new.work_scope is null or new.work_scope = '' then
    new.work_scope := case
      when new.entity_id is not null then new.stage::text || ':entity:' || new.entity_id::text
      else new.stage::text || ':queue:' || new.id::text
    end;
  end if;
  return new;
end
$$;

drop trigger if exists research_queue_prepare_coordination on public.research_queue;
create trigger research_queue_prepare_coordination
before insert or update of field, entity_id, stage, work_scope
on public.research_queue
for each row execute function public.prepare_research_queue_coordination();

create table if not exists public.research_work_leases (
  scope_key text primary key,
  stage smallint not null check (stage between 1 and 5),
  run_id uuid not null references public.research_runs(id) on delete cascade,
  claimed_at timestamptz not null default now(),
  heartbeat_at timestamptz not null default now(),
  expires_at timestamptz not null,
  constraint research_work_leases_expiry_check check (expires_at > claimed_at)
);

create index if not exists research_work_leases_run_idx
  on public.research_work_leases(run_id, expires_at);
create index if not exists research_work_leases_expiry_idx
  on public.research_work_leases(expires_at);
create index if not exists research_queue_coordination_idx
  on public.research_queue(stage, status, priority desc, work_scope);
create index if not exists research_queue_claimed_run_idx
  on public.research_queue(claimed_run_id, lease_expires_at)
  where claimed_run_id is not null;

create or replace function public.heartbeat_research_run(p_run_id uuid)
returns timestamptz
language plpgsql
as $$
declare
  v_at timestamptz;
begin
  update public.research_runs
  set last_heartbeat_at = now(),
      heartbeat_count = heartbeat_count + 1
  where id = p_run_id and status = 'running'
  returning last_heartbeat_at into v_at;

  if v_at is null then
    raise exception 'research run % is missing or not running', p_run_id;
  end if;
  return v_at;
end
$$;

create or replace function public.heartbeat_research_work(
  p_run_id uuid,
  p_lease interval default interval '15 minutes'
)
returns table(heartbeat_at timestamptz, lease_expires_at timestamptz, leased_scopes integer, leased_items integer)
language plpgsql
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

  update public.research_work_leases
  set heartbeat_at = v_at,
      expires_at = v_expires
  where run_id = p_run_id
    and expires_at > v_at;
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

create or replace function public.claim_research_work(
  p_run_id uuid,
  p_stage smallint default null,
  p_lease interval default interval '15 minutes'
)
returns setof public.research_queue
language plpgsql
as $$
declare
  v_run_status text;
  v_scope text;
  v_stage smallint;
  v_claimed boolean;
  v_try integer := 0;
begin
  if p_stage is not null and (p_stage < 1 or p_stage > 5) then
    raise exception 'stage must be 1..5 or null';
  end if;
  if p_lease < interval '1 minute' or p_lease > interval '2 hours' then
    raise exception 'lease must be between 1 minute and 2 hours';
  end if;

  select status into v_run_status
  from public.research_runs
  where id = p_run_id
  for update;

  if v_run_status is null then
    raise exception 'research run % does not exist', p_run_id;
  end if;
  if v_run_status <> 'running' then
    raise exception 'research run % is %, expected running', p_run_id, v_run_status;
  end if;

  perform public.heartbeat_research_run(p_run_id);

  loop
    v_try := v_try + 1;
    exit when v_try > 25;

    select q.work_scope, q.stage
      into v_scope, v_stage
    from public.research_queue q
    left join public.research_work_leases l on l.scope_key = q.work_scope
    where q.status in ('pending','working')
      and (q.status = 'pending' or coalesce(q.lease_expires_at, '-infinity'::timestamptz) <= now())
      and (l.scope_key is null or l.expires_at <= now())
      and (p_stage is null or q.stage = p_stage)
      and (
        p_stage is not null
        or q.stage = (
          select min(q2.stage)
          from public.research_queue q2
          left join public.research_work_leases l2 on l2.scope_key = q2.work_scope
          where q2.status in ('pending','working')
            and (q2.status = 'pending' or coalesce(q2.lease_expires_at, '-infinity'::timestamptz) <= now())
            and (l2.scope_key is null or l2.expires_at <= now())
        )
      )
    order by q.priority desc, coalesce(q.last_attempt_at, '-infinity'::timestamptz), q.id
    for update of q skip locked
    limit 1;

    if v_scope is null then
      return;
    end if;

    v_claimed := false;
    insert into public.research_work_leases(scope_key, stage, run_id, claimed_at, heartbeat_at, expires_at)
    values(v_scope, v_stage, p_run_id, now(), now(), now() + p_lease)
    on conflict (scope_key) do update
      set stage = excluded.stage,
          run_id = excluded.run_id,
          claimed_at = excluded.claimed_at,
          heartbeat_at = excluded.heartbeat_at,
          expires_at = excluded.expires_at
      where public.research_work_leases.expires_at <= now()
    returning true into v_claimed;

    if coalesce(v_claimed,false) then
      update public.research_queue q
      set status = 'working',
          claimed_run_id = p_run_id,
          claimed_at = now(),
          heartbeat_at = now(),
          lease_expires_at = now() + p_lease,
          stop_reason = null
      where q.work_scope = v_scope
        and q.stage = v_stage
        and q.status in ('pending','working')
        and (q.status = 'pending' or coalesce(q.lease_expires_at, '-infinity'::timestamptz) <= now());

      return query
      select q.*
      from public.research_queue q
      where q.work_scope = v_scope
        and q.claimed_run_id = p_run_id
        and q.status = 'working'
      order by q.priority desc, q.field;
      return;
    end if;

    v_scope := null;
    v_stage := null;
  end loop;

  return;
end
$$;

create or replace function public.release_research_work(
  p_run_id uuid,
  p_scope_key text,
  p_reason text default 'Released by research agent'
)
returns integer
language plpgsql
as $$
declare
  v_count integer;
begin
  perform public.heartbeat_research_run(p_run_id);

  if not exists (
    select 1 from public.research_work_leases
    where scope_key = p_scope_key and run_id = p_run_id
  ) then
    raise exception 'run % does not own work scope %', p_run_id, p_scope_key;
  end if;

  update public.research_queue
  set status = 'pending',
      claimed_run_id = null,
      claimed_at = null,
      heartbeat_at = null,
      lease_expires_at = null,
      stop_reason = p_reason
  where work_scope = p_scope_key
    and claimed_run_id = p_run_id
    and status = 'working';
  get diagnostics v_count = row_count;

  delete from public.research_work_leases
  where scope_key = p_scope_key and run_id = p_run_id;

  return v_count;
end
$$;

create or replace function public.recover_stale_research(
  p_stale_after interval default interval '30 minutes'
)
returns table(failed_runs integer, reset_queue integer)
language plpgsql
as $$
declare
  v_failed integer := 0;
  v_reset integer := 0;
begin
  update public.research_runs
  set status = 'failed',
      ended_at = coalesce(ended_at, now()),
      notes = concat_ws(E'\n', notes, 'Automatically marked failed after heartbeat became stale.')
  where status = 'running'
    and coalesce(last_heartbeat_at, started_at) < now() - p_stale_after;
  get diagnostics v_failed = row_count;

  update public.research_queue q
  set status = case when exists (
        select 1 from public.claims c
        where c.entity_id = q.entity_id
          and c.field = q.field
          and c.status in ('supported','verified')
          and exists (
            select 1 from public.evidence e
            where e.claim_id = c.id and e.evidence_kind = 'supports'
          )
      ) then 'done' else 'pending' end,
      claimed_run_id = null,
      claimed_at = null,
      heartbeat_at = null,
      lease_expires_at = null,
      stop_reason = case when exists (
        select 1 from public.claims c
        where c.entity_id = q.entity_id
          and c.field = q.field
          and c.status in ('supported','verified')
          and exists (
            select 1 from public.evidence e
            where e.claim_id = c.id and e.evidence_kind = 'supports'
          )
      ) then null else 'Recovered expired work lease' end
  where q.status = 'working'
    and (
      coalesce(q.lease_expires_at, q.last_attempt_at + p_stale_after, q.claimed_at + p_stale_after, '-infinity'::timestamptz)
      <= now()
    );
  get diagnostics v_reset = row_count;

  delete from public.research_work_leases
  where expires_at <= now()
     or run_id in (
       select id from public.research_runs where status <> 'running'
     );

  return query select v_failed, v_reset;
end
$$;

create or replace function public.begin_research_run(
  p_objective text,
  p_notes text default null,
  p_stale_after interval default interval '30 minutes'
)
returns uuid
language plpgsql
as $$
declare
  v_run_id uuid;
  v_bad bigint;
begin
  perform * from public.recover_stale_research(p_stale_after);

  select count(*) into v_bad
  from public.claims c
  where c.status in ('supported','verified')
    and not exists (
      select 1 from public.evidence e
      where e.claim_id = c.id and e.evidence_kind = 'supports'
    )
    and not exists (
      select 1 from public.claim_integrity_quarantine q
      where q.claim_id = c.id
    );

  if v_bad > 0 then
    raise exception 'integrity gate failed: % unquarantined supported/verified claims lack supporting evidence', v_bad;
  end if;

  insert into public.research_runs(objective,status,notes,last_heartbeat_at)
  values(p_objective,'running',p_notes,now())
  returning id into v_run_id;

  insert into public.change_events(run_id,actor,event_type,table_name,record_id,new_data,reason)
  values(
    v_run_id,'research-agent','research_run_started','research_runs',v_run_id,
    jsonb_build_object('objective',p_objective),
    'Started through integrity-gated begin_research_run()'
  );

  return v_run_id;
end
$$;

create or replace function public.research_integrity_health(
  p_stale_after interval default interval '30 minutes'
)
returns table(metric text, value bigint)
language sql
as $$
  select 'running_runs', count(*)::bigint
    from public.research_runs where status='running'
  union all
  select 'stale_running_runs', count(*)::bigint
    from public.research_runs
    where status='running'
      and coalesce(last_heartbeat_at,started_at) < now()-p_stale_after
  union all
  select 'working_queue', count(*)::bigint
    from public.research_queue where status='working'
  union all
  select 'stale_working_queue', count(*)::bigint
    from public.research_queue
    where status='working'
      and coalesce(lease_expires_at,last_attempt_at+p_stale_after,claimed_at+p_stale_after,'-infinity'::timestamptz) <= now()
  union all
  select 'active_work_leases', count(*)::bigint
    from public.research_work_leases where expires_at > now()
  union all
  select 'expired_work_leases', count(*)::bigint
    from public.research_work_leases where expires_at <= now()
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
$$;

create or replace function public.commit_research_fact(
  p_run_id uuid,
  p_queue_id uuid,
  p_entity_id uuid,
  p_field text,
  p_value_text text default null,
  p_value_num numeric default null,
  p_unit text default null,
  p_qualifier jsonb default '{}'::jsonb,
  p_status text default 'verified',
  p_confidence numeric default 1.0,
  p_source_url text default null,
  p_source_title text default null,
  p_source_type text default 'official_manufacturer',
  p_publisher text default null,
  p_published_at timestamptz default null,
  p_content_sha256 text default null,
  p_source_metadata jsonb default '{}'::jsonb,
  p_evidence_kind text default 'supports',
  p_excerpt text default null,
  p_locator text default null,
  p_observed_value text default null,
  p_independence_group text default null,
  p_attempt_strategy text default 'official_source',
  p_attempt_query text default null,
  p_fact_key text default null
)
returns table(claim_id uuid, evidence_id uuid, source_id uuid, fact_key text)
language plpgsql
as $$
declare
  v_source_id uuid;
  v_claim_id uuid;
  v_evidence_id uuid;
  v_fact_key text;
  v_q_entity uuid;
  v_q_field text;
  v_q_status text;
  v_q_claimed_run uuid;
  v_q_lease_expires timestamptz;
  v_run_status text;
  v_existing_status text;
  v_existing_conf numeric;
  v_existing_entity uuid;
  v_existing_field text;
begin
  if p_run_id is null then raise exception 'run_id is required'; end if;
  select status into v_run_status
  from public.research_runs
  where id = p_run_id
  for update;

  if v_run_status is null then raise exception 'research run % does not exist', p_run_id; end if;
  if v_run_status <> 'running' then raise exception 'research run % is %, expected running', p_run_id, v_run_status; end if;

  update public.research_runs
  set last_heartbeat_at = now(),
      heartbeat_count = heartbeat_count + 1
  where id = p_run_id;

  if p_entity_id is null or p_field is null then raise exception 'entity_id and field are required'; end if;
  if p_status not in ('unverified','supported','verified','conflicting','superseded','not_found','rejected') then raise exception 'invalid claim status %', p_status; end if;
  if p_confidence < 0 or p_confidence > 1 then raise exception 'confidence must be 0..1'; end if;
  if p_status in ('supported','verified') and p_evidence_kind <> 'supports' then raise exception '% claim requires supports evidence', p_status; end if;
  if p_status in ('supported','verified') and p_source_url is null then raise exception '% claim requires a source URL', p_status; end if;

  if p_queue_id is not null then
    select entity_id, field, status, claimed_run_id, lease_expires_at
      into v_q_entity, v_q_field, v_q_status, v_q_claimed_run, v_q_lease_expires
    from public.research_queue
    where id = p_queue_id
    for update;

    if not found then raise exception 'queue item % does not exist', p_queue_id; end if;
    if v_q_entity is distinct from p_entity_id or v_q_field is distinct from p_field then
      raise exception 'queue item % does not match entity/field', p_queue_id;
    end if;

    -- New coordinated workers must own an unexpired lease. Legacy unclaimed
    -- queue items remain commit-compatible during migration.
    if v_q_claimed_run is not null then
      if v_q_claimed_run is distinct from p_run_id then
        raise exception 'queue item % is leased to another run', p_queue_id;
      end if;
      if v_q_lease_expires is null or v_q_lease_expires <= now() then
        raise exception 'queue item % lease has expired; reclaim work before committing', p_queue_id;
      end if;
      if v_q_status <> 'working' then
        raise exception 'queue item % is %, expected working for leased commit', p_queue_id, v_q_status;
      end if;
    end if;
  end if;

  v_fact_key := coalesce(p_fact_key, md5(
    coalesce(p_entity_id::text,'') || '|' || coalesce(p_field,'') || '|' ||
    coalesce(p_value_text,'') || '|' || coalesce(p_value_num::text,'') || '|' ||
    coalesce(p_unit,'') || '|' || coalesce(p_source_url,'') || '|' || coalesce(p_locator,'')
  ));

  select id into v_source_id
  from public.sources
  where url is not distinct from p_source_url
    and content_sha256 is not distinct from p_content_sha256
  order by retrieved_at desc, id
  limit 1;

  if v_source_id is null then
    insert into public.sources(url,title,source_type,publisher,published_at,content_sha256,metadata)
    values(
      p_source_url,p_source_title,p_source_type,p_publisher,p_published_at,p_content_sha256,
      coalesce(p_source_metadata,'{}'::jsonb) || jsonb_build_object('first_seen_run_id',p_run_id)
    )
    returning id into v_source_id;
  end if;

  select id,status,confidence,entity_id,field
    into v_claim_id,v_existing_status,v_existing_conf,v_existing_entity,v_existing_field
  from public.claims c
  where c.fact_key = v_fact_key
  limit 1;

  if v_claim_id is null then
    insert into public.claims(entity_id,field,value_text,value_num,unit,qualifier,status,confidence,run_id,fact_key)
    values(
      p_entity_id,p_field,p_value_text,p_value_num,p_unit,
      coalesce(p_qualifier,'{}'::jsonb) || jsonb_build_object('committed_run_id',p_run_id),
      p_status,p_confidence,p_run_id,v_fact_key
    )
    returning id into v_claim_id;
  else
    if v_existing_entity is distinct from p_entity_id or v_existing_field is distinct from p_field then
      raise exception 'fact_key collision for %', v_fact_key;
    end if;
    if v_existing_status is distinct from p_status or v_existing_conf is distinct from p_confidence then
      raise exception 'idempotent retry differs from existing claim % (status/confidence mismatch); create a new claim/fact key instead', v_claim_id;
    end if;
  end if;

  select e.id into v_evidence_id
  from public.evidence e
  where e.claim_id=v_claim_id
    and e.source_id=v_source_id
    and e.evidence_kind=p_evidence_kind
    and e.locator is not distinct from p_locator
  limit 1;

  if v_evidence_id is null then
    insert into public.evidence(claim_id,source_id,evidence_kind,excerpt,locator,observed_value,independence_group,run_id)
    values(v_claim_id,v_source_id,p_evidence_kind,p_excerpt,p_locator,p_observed_value,p_independence_group,p_run_id)
    returning id into v_evidence_id;
  end if;

  if p_queue_id is not null then
    if not exists (
      select 1 from public.research_attempts
      where queue_id=p_queue_id
        and run_id=p_run_id
        and outcome='verified'
        and notes = 'Atomic fact:'||v_fact_key
    ) then
      insert into public.research_attempts(queue_id,run_id,strategy,query,result_count,useful_sources,outcome,notes)
      values(p_queue_id,p_run_id,coalesce(p_attempt_strategy,'official_source'),p_attempt_query,1,1,'verified','Atomic fact:'||v_fact_key);

      update public.research_queue
      set status='done',
          attempts=attempts+1,
          last_attempt_at=now(),
          stop_reason=null,
          claimed_run_id=null,
          claimed_at=null,
          heartbeat_at=null,
          lease_expires_at=null
      where id=p_queue_id;
    elsif exists (select 1 from public.research_queue where id=p_queue_id and status<>'done') then
      update public.research_queue
      set status='done',
          stop_reason=null,
          claimed_run_id=null,
          claimed_at=null,
          heartbeat_at=null,
          lease_expires_at=null
      where id=p_queue_id;
    end if;

    delete from public.research_work_leases l
    where l.run_id = p_run_id
      and not exists (
        select 1 from public.research_queue q
        where q.work_scope = l.scope_key
          and q.claimed_run_id = p_run_id
          and q.status = 'working'
      );
  end if;

  if not exists (
    select 1 from public.change_events
    where event_type='research_fact_committed'
      and record_id=v_claim_id
      and run_id=p_run_id
  ) then
    insert into public.change_events(run_id,event_type,table_name,record_id,new_data,reason,evidence_ids)
    values(
      p_run_id,'research_fact_committed','claims',v_claim_id,
      jsonb_build_object('field',p_field,'status',p_status,'confidence',p_confidence,'fact_key',v_fact_key),
      'Atomic append-only research fact commit',array[v_evidence_id]
    );
  end if;

  return query select v_claim_id,v_evidence_id,v_source_id,v_fact_key;
end
$$;
