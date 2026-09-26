
create schema if not exists research_internal;
revoke all on schema research_internal from public, anon, authenticated, service_role;

alter function public.commit_research_fact(uuid,uuid,uuid,text,text,numeric,text,jsonb,text,numeric,text,text,text,text,timestamp with time zone,text,jsonb,text,text,text,text,text,text,text,text)
  rename to "LEGACY_DO_NOT_USE_commit_research_fact";
alter function public."LEGACY_DO_NOT_USE_commit_research_fact"(uuid,uuid,uuid,text,text,numeric,text,jsonb,text,numeric,text,text,text,text,timestamp with time zone,text,jsonb,text,text,text,text,text,text,text,text)
  set schema research_internal;

alter function public.commit_research_fact_v2(uuid,uuid,uuid,text,text,numeric,text,jsonb,text,numeric,text,text,text,text,timestamp with time zone,text,jsonb,text,text,text,text,text,text,text,text,uuid,text,text)
  rename to commit_research_fact;

create or replace function research_internal.enforce_managed_append()
returns trigger
language plpgsql
set search_path=''
as $$
begin
  if coalesce(current_setting('hvac.managed_append',true),'') <> 'on' then
    raise exception 'direct INSERT into % is forbidden; use public.commit_research_fact()', tg_table_name;
  end if;
  return new;
end
$$;

drop trigger if exists claims_managed_insert_only on public.claims;
create trigger claims_managed_insert_only
before insert on public.claims
for each row execute function research_internal.enforce_managed_append();

drop trigger if exists evidence_managed_insert_only on public.evidence;
create trigger evidence_managed_insert_only
before insert on public.evidence
for each row execute function research_internal.enforce_managed_append();

drop trigger if exists claim_resolutions_managed_insert_only on public.claim_resolutions;
create trigger claim_resolutions_managed_insert_only
before insert on public.claim_resolutions
for each row execute function research_internal.enforce_managed_append();

drop trigger if exists claims_no_truncate on public.claims;
create trigger claims_no_truncate before truncate on public.claims
for each statement execute function public.prevent_update_delete_immutable();

drop trigger if exists evidence_no_truncate on public.evidence;
create trigger evidence_no_truncate before truncate on public.evidence
for each statement execute function public.prevent_update_delete_immutable();

drop trigger if exists claim_resolutions_no_truncate on public.claim_resolutions;
create trigger claim_resolutions_no_truncate before truncate on public.claim_resolutions
for each statement execute function public.prevent_update_delete_immutable();

drop trigger if exists change_events_no_truncate on public.change_events;
create trigger change_events_no_truncate before truncate on public.change_events
for each statement execute function public.prevent_update_delete_immutable();

drop trigger if exists claim_integrity_quarantine_no_truncate on public.claim_integrity_quarantine;
create trigger claim_integrity_quarantine_no_truncate before truncate on public.claim_integrity_quarantine
for each statement execute function public.prevent_update_delete_quarantine();

drop trigger if exists conflicts_no_truncate on public.conflicts;
create trigger conflicts_no_truncate before truncate on public.conflicts
for each statement execute function public.prevent_update_delete_immutable();

create unique index if not exists claim_resolutions_one_successor_uidx
  on public.claim_resolutions(old_claim_id);

create or replace function research_internal.prevent_resolution_cycle()
returns trigger
language plpgsql
set search_path=''
as $$
begin
  if exists (
    with recursive walk(id) as (
      select new.new_claim_id
      union
      select r.new_claim_id
      from public.claim_resolutions r
      join walk w on r.old_claim_id=w.id
    )
    select 1 from walk where id=new.old_claim_id
  ) then
    raise exception 'claim resolution would create a cycle: % -> %',new.old_claim_id,new.new_claim_id;
  end if;
  return new;
end
$$;

drop trigger if exists claim_resolutions_no_cycles on public.claim_resolutions;
create trigger claim_resolutions_no_cycles
before insert on public.claim_resolutions
for each row execute function research_internal.prevent_resolution_cycle();

create table if not exists public.condition_keyed_fields(
  field text primary key,
  required_qualifier_keys text[] not null default '{}'::text[],
  require_airflow boolean not null default false,
  description text not null
);

insert into public.condition_keyed_fields(field,required_qualifier_keys,require_airflow,description)
values
 ('cooling_capacity_high_ambient_kw',array['outdoor_db_c','indoor_db_c','indoor_wb_c','load_condition'],true,
  'Generic expanded-performance cooling capacity. Condition identity is mandatory.'),
 ('cooling_input_high_ambient_w',array['outdoor_db_c','indoor_db_c','indoor_wb_c','load_condition'],true,
  'Generic expanded-performance cooling input. Condition identity is mandatory.')
on conflict(field) do update
set required_qualifier_keys=excluded.required_qualifier_keys,
    require_airflow=excluded.require_airflow,
    description=excluded.description;

revoke all on public.condition_keyed_fields from anon, authenticated;
grant select on public.condition_keyed_fields to service_role;

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
  p_fact_key text default null,
  p_resolves_claim_id uuid default null,
  p_resolution_type text default null,
  p_resolution_reason text default null
)
returns table(claim_id uuid,evidence_id uuid,source_id uuid,fact_key text,resolution_id uuid)
language plpgsql
security definer
set search_path=''
as $$
declare
  v_fact record;
  v_resolution_id uuid;
  v_old_entity uuid;
  v_old_field text;
  v_old_qualifier jsonb;
  v_old_condition text;
  v_new_condition text;
  v_prev_guard text;
  v_cfg public.condition_keyed_fields%rowtype;
  v_key text;
  v_nf record;
begin
  if p_fact_key is null or btrim(p_fact_key)='' then
    raise exception 'p_fact_key is mandatory; implicit fact keys are forbidden';
  end if;

  p_qualifier := coalesce(p_qualifier,'{}'::jsonb);
  v_new_condition := public.claim_condition_key(p_field,p_qualifier);

  select * into v_cfg
  from public.condition_keyed_fields
  where field=p_field;

  if found then
    foreach v_key in array v_cfg.required_qualifier_keys loop
      if not (p_qualifier ? v_key)
         or nullif(btrim(coalesce(p_qualifier->>v_key,'')),'') is null then
        raise exception 'field % requires qualifier key %',p_field,v_key;
      end if;
    end loop;
    if v_cfg.require_airflow
       and not (
         (p_qualifier ? 'airflow_ls' and nullif(btrim(coalesce(p_qualifier->>'airflow_ls','')),'') is not null)
         or
         (p_qualifier ? 'airflow_m3h' and nullif(btrim(coalesce(p_qualifier->>'airflow_m3h','')),'') is not null)
       ) then
      raise exception 'field % requires airflow_ls or airflow_m3h',p_field;
    end if;
  end if;

  if p_status='not_found' and exists(
    select 1
    from public.effective_claims c
    where c.entity_id=p_entity_id
      and c.field=p_field
      and c.status in ('supported','verified')
      and public.claim_condition_key(c.field,c.qualifier)=v_new_condition
  ) then
    raise exception 'cannot commit not_found: effective supported/verified evidence already exists for same entity/field/condition';
  end if;

  if p_resolves_claim_id is not null then
    if p_resolution_type is null then
      raise exception 'resolution_type is required when resolves_claim_id is supplied';
    end if;

    select entity_id,field,qualifier
      into v_old_entity,v_old_field,v_old_qualifier
    from public.claims
    where id=p_resolves_claim_id;

    if not found then
      raise exception 'resolved claim % does not exist',p_resolves_claim_id;
    end if;
    if v_old_entity is distinct from p_entity_id or v_old_field is distinct from p_field then
      raise exception 'resolved claim % does not match entity/field',p_resolves_claim_id;
    end if;

    v_old_condition := public.claim_condition_key(v_old_field,v_old_qualifier);
    if v_old_condition is distinct from v_new_condition then
      raise exception 'resolved claim % condition identity differs from replacement claim',p_resolves_claim_id;
    end if;
  elsif p_resolution_type is not null or p_resolution_reason is not null then
    raise exception 'resolution type/reason supplied without p_resolves_claim_id';
  end if;

  v_prev_guard := current_setting('hvac.managed_append',true);
  perform set_config('hvac.managed_append','on',true);

  select * into v_fact
  from research_internal."LEGACY_DO_NOT_USE_commit_research_fact"(
    p_run_id,p_queue_id,p_entity_id,p_field,p_value_text,p_value_num,p_unit,
    p_qualifier,p_status,p_confidence,p_source_url,p_source_title,p_source_type,
    p_publisher,p_published_at,p_content_sha256,p_source_metadata,p_evidence_kind,
    p_excerpt,p_locator,p_observed_value,p_independence_group,p_attempt_strategy,
    p_attempt_query,p_fact_key
  );

  if p_resolves_claim_id is not null then
    insert into public.claim_resolutions(
      old_claim_id,new_claim_id,resolution_type,reason,run_id
    )
    values(
      p_resolves_claim_id,v_fact.claim_id,p_resolution_type,p_resolution_reason,p_run_id
    )
    on conflict (old_claim_id) do nothing
    returning id into v_resolution_id;

    if v_resolution_id is null then
      select id into v_resolution_id
      from public.claim_resolutions
      where old_claim_id=p_resolves_claim_id
        and new_claim_id=v_fact.claim_id;
      if v_resolution_id is null then
        raise exception 'prior claim % is already resolved by a different claim',p_resolves_claim_id;
      end if;
    end if;
  end if;

  if p_status in ('supported','verified') then
    for v_nf in
      select c.id
      from public.effective_claims c
      where c.entity_id=p_entity_id
        and c.field=p_field
        and c.status='not_found'
        and c.id<>v_fact.claim_id
        and public.claim_condition_key(c.field,c.qualifier)=v_new_condition
        and (p_resolves_claim_id is null or c.id<>p_resolves_claim_id)
    loop
      insert into public.claim_resolutions(
        old_claim_id,new_claim_id,resolution_type,reason,run_id
      )
      values(
        v_nf.id,v_fact.claim_id,'resolved_not_found',
        'Automatically resolved by new supported/verified evidence for identical entity/field/condition.',
        p_run_id
      )
      on conflict (old_claim_id) do nothing;
    end loop;
  end if;

  if v_resolution_id is not null and not exists (
    select 1 from public.change_events
    where event_type='claim_resolution_created'
      and record_id=v_resolution_id
      and run_id=p_run_id
  ) then
    insert into public.change_events(
      run_id,event_type,table_name,record_id,new_data,reason,evidence_ids
    )
    values(
      p_run_id,'claim_resolution_created','claim_resolutions',v_resolution_id,
      jsonb_build_object(
        'old_claim_id',p_resolves_claim_id,
        'new_claim_id',v_fact.claim_id,
        'resolution_type',p_resolution_type
      ),
      coalesce(p_resolution_reason,'Claim resolution created atomically with research fact'),
      array[v_fact.evidence_id]
    );
  end if;

  perform set_config('hvac.managed_append',coalesce(v_prev_guard,''),true);

  return query
  select v_fact.claim_id,v_fact.evidence_id,v_fact.source_id,v_fact.fact_key,v_resolution_id;
end
$$;

comment on function public.commit_research_fact(uuid,uuid,uuid,text,text,numeric,text,jsonb,text,numeric,text,text,text,text,timestamp with time zone,text,jsonb,text,text,text,text,text,text,text,text,uuid,text,text) is
'ONLY supported research fact write API. Enforces explicit fact keys, condition metadata, exact-condition resolution semantics, automatic not_found retirement, append-only guards and atomic evidence writes.';

comment on function research_internal."LEGACY_DO_NOT_USE_commit_research_fact"(uuid,uuid,uuid,text,text,numeric,text,jsonb,text,numeric,text,text,text,text,timestamp with time zone,text,jsonb,text,text,text,text,text,text,text,text) is
'LEGACY_DO_NOT_USE internal implementation. Not a supported API; inaccessible to research callers.';

revoke all on function research_internal."LEGACY_DO_NOT_USE_commit_research_fact"(uuid,uuid,uuid,text,text,numeric,text,jsonb,text,numeric,text,text,text,text,timestamp with time zone,text,jsonb,text,text,text,text,text,text,text,text) from public, anon, authenticated, service_role;
revoke all on function public.commit_research_fact(uuid,uuid,uuid,text,text,numeric,text,jsonb,text,numeric,text,text,text,text,timestamp with time zone,text,jsonb,text,text,text,text,text,text,text,text,uuid,text,text) from public, anon, authenticated;
grant execute on function public.commit_research_fact(uuid,uuid,uuid,text,text,numeric,text,jsonb,text,numeric,text,text,text,text,timestamp with time zone,text,jsonb,text,text,text,text,text,text,text,text,uuid,text,text) to service_role;

revoke insert,update,delete,truncate on public.claims from service_role;
revoke insert,update,delete,truncate on public.evidence from service_role;
revoke insert,update,delete,truncate on public.claim_resolutions from service_role;

alter table public.claim_resolutions enable row level security;
revoke all on public.claim_resolutions from anon, authenticated;
grant select on public.claim_resolutions to service_role;

revoke execute on function public.begin_research_run(text,text,interval) from public, anon, authenticated;
revoke execute on function public.claim_research_work(uuid,smallint,interval) from public, anon, authenticated;
revoke execute on function public.heartbeat_research_work(uuid,interval) from public, anon, authenticated;
revoke execute on function public.release_research_work(uuid,text,text) from public, anon, authenticated;

create or replace view public.canonical_condition_claims
with (security_invoker=true)
as
select distinct on (tc.entity_id,tc.field,public.claim_condition_key(tc.field,tc.qualifier))
  tc.id,tc.entity_id,tc.subject_text,tc.field,tc.value_text,tc.value_num,tc.unit,
  tc.qualifier,tc.status,tc.confidence,tc.created_at,tc.supersedes_claim_id,
  tc.run_id,tc.fact_key,
  public.claim_condition_key(tc.field,tc.qualifier) as condition_key
from public.trusted_claims tc
where not exists(
  select 1
  from public.conflicts cf
  join public.claims a on a.id=cf.claim_a
  join public.claims b on b.id=cf.claim_b
  where cf.entity_id=tc.entity_id
    and cf.field=tc.field
    and cf.status='open'
    and public.claim_condition_key(a.field,a.qualifier)=public.claim_condition_key(tc.field,tc.qualifier)
    and public.claim_condition_key(b.field,b.qualifier)=public.claim_condition_key(tc.field,tc.qualifier)
)
order by tc.entity_id,tc.field,public.claim_condition_key(tc.field,tc.qualifier),
         tc.confidence desc,tc.created_at desc,tc.id desc;

create or replace view public.canonical_claims
with (security_invoker=true)
as
select distinct on (tc.entity_id,tc.field)
  tc.id,tc.entity_id,tc.subject_text,tc.field,tc.value_text,tc.value_num,tc.unit,
  tc.qualifier,tc.status,tc.confidence,tc.created_at,tc.supersedes_claim_id
from public.trusted_claims tc
where not exists(
  select 1 from public.condition_keyed_fields k where k.field=tc.field
)
and not exists(
  select 1 from public.conflicts cf
  where cf.entity_id=tc.entity_id
    and cf.field=tc.field
    and cf.status='open'
)
order by tc.entity_id,tc.field,tc.confidence desc,tc.created_at desc,tc.id desc;

do $$
declare v text;
begin
  select pg_get_viewdef('public.low_airflow_proxy_v1'::regclass,true) into v;
  v := replace(v,'FROM (claims c','FROM (effective_claims c');
  v := replace(v,'FROM claims c','FROM effective_claims c');
  execute 'create or replace view public.low_airflow_proxy_v1 as '||v;
end
$$;

create or replace function public.research_integrity_health(p_stale_after interval default '00:10:00'::interval)
returns table(metric text,value bigint)
language sql
set search_path=''
as $$
  select 'running_runs',count(*)::bigint from public.research_runs where status='running'
  union all
  select 'effective_active_runs',count(distinct r.id)::bigint
    from public.research_runs r
    join public.research_work_leases l on l.run_id=r.id
    join public.research_queue q on q.work_scope=l.scope_key and q.claimed_run_id=r.id and q.status='working'
    where r.status='running' and coalesce(r.last_heartbeat_at,r.started_at)>=now()-p_stale_after and l.expires_at>now()
  union all
  select 'stale_running_runs',count(*)::bigint from public.research_runs
    where status='running' and coalesce(last_heartbeat_at,started_at)<now()-p_stale_after
  union all
  select 'idle_running_runs',count(*)::bigint from public.research_runs r
    where r.status='running'
      and coalesce(r.last_heartbeat_at,r.started_at)<now()-interval '5 minutes'
      and not exists(
        select 1 from public.research_work_leases l
        join public.research_queue q on q.work_scope=l.scope_key and q.claimed_run_id=l.run_id and q.status='working'
        where l.run_id=r.id and l.expires_at>now()
      )
  union all
  select 'working_queue',count(*)::bigint from public.research_queue where status='working'
  union all
  select 'stale_working_queue',count(*)::bigint from public.research_queue
    where status='working'
      and coalesce(lease_expires_at,last_attempt_at+p_stale_after,claimed_at+p_stale_after,'-infinity'::timestamptz)<=now()
  union all
  select 'working_queue_without_active_lease',count(*)::bigint from public.research_queue q
    where q.status='working'
      and not exists(select 1 from public.research_work_leases l
                     where l.scope_key=q.work_scope and l.run_id=q.claimed_run_id and l.expires_at>now())
  union all
  select 'active_work_leases',count(*)::bigint from public.research_work_leases where expires_at>now()
  union all
  select 'orphan_active_work_leases',count(*)::bigint from public.research_work_leases l
    where l.expires_at>now()
      and not exists(select 1 from public.research_queue q
                     where q.work_scope=l.scope_key and q.claimed_run_id=l.run_id and q.status='working')
  union all
  select 'expired_work_leases',count(*)::bigint from public.research_work_leases where expires_at<=now()
  union all
  select 'open_conflicts',count(*)::bigint from public.conflicts where status='open'
  union all
  select 'open_cross_condition_conflicts',count(*)::bigint
    from public.conflicts cf
    join public.effective_claims a on a.id=cf.claim_a
    join public.effective_claims b on b.id=cf.claim_b
    where cf.status='open'
      and a.condition_key<>'default' and b.condition_key<>'default'
      and a.condition_key<>b.condition_key
  union all
  select 'effective_supported_verified_without_evidence',count(*)::bigint
    from public.effective_claims c
    where c.status in ('supported','verified')
      and not exists(select 1 from public.evidence e where e.claim_id=c.id and e.evidence_kind='supports')
      and not exists(select 1 from public.claim_integrity_quarantine q where q.claim_id=c.id)
  union all
  select 'resolved_claims_leaking_into_trusted',count(*)::bigint
    from public.trusted_claims tc
    where exists(select 1 from public.claim_resolutions r where r.old_claim_id=tc.id)
  union all
  select 'condition_keyed_claims_missing_required_metadata',count(*)::bigint
    from public.effective_claims c
    join public.condition_keyed_fields k on k.field=c.field
    where c.status in ('supported','verified','not_found')
      and (
        exists(select 1 from unnest(k.required_qualifier_keys) rk where not (c.qualifier ? rk)
               or nullif(btrim(coalesce(c.qualifier->>rk,'')),'') is null)
        or (k.require_airflow and not (
          (c.qualifier ? 'airflow_ls' and nullif(btrim(coalesce(c.qualifier->>'airflow_ls','')),'') is not null)
          or (c.qualifier ? 'airflow_m3h' and nullif(btrim(coalesce(c.qualifier->>'airflow_m3h','')),'') is not null)
        ))
      )
  union all
  select 'quarantined_claims',count(*)::bigint from public.claim_integrity_quarantine
  union all
  select 'trusted_claims',count(*)::bigint from public.trusted_claims
  union all
  select 'canonical_claims',count(*)::bigint from public.canonical_claims
$$;
