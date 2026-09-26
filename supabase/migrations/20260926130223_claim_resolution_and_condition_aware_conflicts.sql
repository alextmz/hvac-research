
create table if not exists public.claim_resolutions (
  id uuid primary key default gen_random_uuid(),
  old_claim_id uuid not null references public.claims(id),
  new_claim_id uuid not null references public.claims(id),
  resolution_type text not null check (
    resolution_type in ('superseded','resolved_not_found','duplicate','model_mismatch','source_correction')
  ),
  reason text,
  run_id uuid references public.research_runs(id),
  created_at timestamptz not null default now(),
  constraint claim_resolutions_distinct_claims check (old_claim_id <> new_claim_id),
  constraint claim_resolutions_pair_uidx unique (old_claim_id,new_claim_id)
);

create index if not exists claim_resolutions_old_idx
  on public.claim_resolutions(old_claim_id);
create index if not exists claim_resolutions_new_idx
  on public.claim_resolutions(new_claim_id);

drop trigger if exists claim_resolutions_no_update_delete on public.claim_resolutions;
create trigger claim_resolutions_no_update_delete
before update or delete on public.claim_resolutions
for each row execute function public.prevent_update_delete_immutable();

create or replace function public.claim_condition_key(
  p_field text,
  p_qualifier jsonb
)
returns text
language sql
immutable
set search_path = ''
as $$
  select case
    when p_qualifier is null then 'default'
    when not (
      p_qualifier ? 'outdoor_db_c'
      or p_qualifier ? 'outdoor_wb_c'
      or p_qualifier ? 'indoor_db_c'
      or p_qualifier ? 'indoor_wb_c'
      or p_qualifier ? 'airflow_ls'
      or p_qualifier ? 'airflow_m3h'
      or p_qualifier ? 'load_pct'
      or p_qualifier ? 'compressor_frequency_hz'
      or p_qualifier ? 'compressor_operation'
      or p_qualifier ? 'operating_mode'
      or p_qualifier ? 'load_condition'
    ) then 'default'
    else concat_ws('|',
      'odb=' || coalesce(p_qualifier->>'outdoor_db_c','?'),
      'owb=' || coalesce(p_qualifier->>'outdoor_wb_c','?'),
      'idb=' || coalesce(p_qualifier->>'indoor_db_c','?'),
      'iwb=' || coalesce(p_qualifier->>'indoor_wb_c','?'),
      'als=' || coalesce(p_qualifier->>'airflow_ls','?'),
      'am3h=' || coalesce(p_qualifier->>'airflow_m3h','?'),
      'load=' || coalesce(p_qualifier->>'load_pct','?'),
      'hz=' || coalesce(p_qualifier->>'compressor_frequency_hz','?'),
      'comp=' || coalesce(p_qualifier->>'compressor_operation','?'),
      'mode=' || coalesce(p_qualifier->>'operating_mode','?'),
      'loadcond=' || coalesce(p_qualifier->>'load_condition','?')
    )
  end
$$;

create or replace view public.effective_claims as
select c.*,
       public.claim_condition_key(c.field,c.qualifier) as condition_key
from public.claims c
where not exists (
  select 1
  from public.claim_resolutions r
  where r.old_claim_id = c.id
);

create or replace function public.detect_material_numeric_claim_conflict()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_claim public.claims%rowtype;
  v_other record;
  v_condition_key text;
begin
  if new.evidence_kind <> 'supports' then
    return new;
  end if;

  select * into v_claim
  from public.claims
  where id = new.claim_id;

  if not found
     or v_claim.status not in ('supported','verified')
     or v_claim.value_num is null
     or exists (
       select 1 from public.claim_integrity_quarantine q
       where q.claim_id = v_claim.id
     )
     or exists (
       select 1 from public.claim_resolutions r
       where r.old_claim_id = v_claim.id
     ) then
    return new;
  end if;

  v_condition_key := public.claim_condition_key(v_claim.field,v_claim.qualifier);

  for v_other in
    select c.id,c.value_num,c.unit,c.qualifier
    from public.claims c
    where c.entity_id = v_claim.entity_id
      and c.field = v_claim.field
      and c.id <> v_claim.id
      and c.status in ('supported','verified')
      and c.value_num is not null
      and not exists (
        select 1 from public.claim_integrity_quarantine q
        where q.claim_id = c.id
      )
      and not exists (
        select 1 from public.claim_resolutions r
        where r.old_claim_id = c.id
      )
      and exists (
        select 1 from public.evidence e
        where e.claim_id = c.id
          and e.evidence_kind = 'supports'
      )
      and public.claim_condition_key(c.field,c.qualifier) = v_condition_key
      and (
        c.unit is not distinct from v_claim.unit
        or (
          lower(coalesce(c.unit,'')) in ('w/w','kwh/kwh')
          and lower(coalesce(v_claim.unit,'')) in ('w/w','kwh/kwh')
        )
      )
      and abs(c.value_num - v_claim.value_num)
          > greatest(
              0.01::numeric,
              0.005::numeric * greatest(abs(c.value_num), abs(v_claim.value_num))
            )
  loop
    insert into public.conflicts(
      entity_id,field,claim_a,claim_b,status,resolution,resolved_at
    )
    values(
      v_claim.entity_id,
      v_claim.field,
      least(v_claim.id,v_other.id),
      greatest(v_claim.id,v_other.id),
      'open',
      null,
      null
    )
    on conflict do nothing;
  end loop;

  return new;
end
$$;

create or replace function public.commit_research_fact_v2(
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
set search_path = ''
as $$
declare
  v_fact record;
  v_resolution_id uuid;
  v_old_entity uuid;
  v_old_field text;
begin
  select * into v_fact
  from public.commit_research_fact(
    p_run_id,p_queue_id,p_entity_id,p_field,p_value_text,p_value_num,p_unit,
    p_qualifier,p_status,p_confidence,p_source_url,p_source_title,p_source_type,
    p_publisher,p_published_at,p_content_sha256,p_source_metadata,p_evidence_kind,
    p_excerpt,p_locator,p_observed_value,p_independence_group,p_attempt_strategy,
    p_attempt_query,p_fact_key
  );

  if p_resolves_claim_id is not null then
    if p_resolution_type is null then
      raise exception 'resolution_type is required when resolves_claim_id is supplied';
    end if;

    select entity_id,field into v_old_entity,v_old_field
    from public.claims
    where id=p_resolves_claim_id;

    if not found then
      raise exception 'resolved claim % does not exist', p_resolves_claim_id;
    end if;
    if v_old_entity is distinct from p_entity_id or v_old_field is distinct from p_field then
      raise exception 'resolved claim % does not match entity/field', p_resolves_claim_id;
    end if;

    insert into public.claim_resolutions(
      old_claim_id,new_claim_id,resolution_type,reason,run_id
    )
    values(
      p_resolves_claim_id,v_fact.claim_id,p_resolution_type,p_resolution_reason,p_run_id
    )
    on conflict (old_claim_id,new_claim_id) do nothing
    returning id into v_resolution_id;

    if v_resolution_id is null then
      select id into v_resolution_id
      from public.claim_resolutions
      where old_claim_id=p_resolves_claim_id
        and new_claim_id=v_fact.claim_id;
    end if;

    if not exists (
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
  end if;

  return query
  select v_fact.claim_id,v_fact.evidence_id,v_fact.source_id,v_fact.fact_key,v_resolution_id;
end
$$;

comment on view public.effective_claims is
  'Current authoritative claim set: immutable claims excluding any claim resolved/superseded through claim_resolutions.';

comment on function public.commit_research_fact_v2 is
  'Atomic research fact commit with optional append-only resolution of a prior claim. Prefer this over commit_research_fact for corrections/not_found resolution.';

insert into public.claim_resolutions(old_claim_id,new_claim_id,resolution_type,reason,run_id)
select c.supersedes_claim_id,c.id,'superseded',
       'Backfilled from claims.supersedes_claim_id',
       c.run_id
from public.claims c
where c.supersedes_claim_id is not null
on conflict (old_claim_id,new_claim_id) do nothing;

insert into public.claim_resolutions(old_claim_id,new_claim_id,resolution_type,reason,run_id)
select (c.qualifier->>'resolves_prior_not_found_claim')::uuid,
       c.id,
       'resolved_not_found',
       'New verified exact-condition evidence resolves earlier terminal not_found claim.',
       c.run_id
from public.claims c
where c.qualifier ? 'resolves_prior_not_found_claim'
  and c.status in ('supported','verified')
  and nullif(c.qualifier->>'resolves_prior_not_found_claim','') is not null
on conflict (old_claim_id,new_claim_id) do nothing;

update public.conflicts cf
set status='resolved',
    resolution='Different documented operating conditions; condition-aware conflict detector does not treat these claims as contradictory.',
    resolved_at=now()
from public.claims a, public.claims b
where a.id=cf.claim_a
  and b.id=cf.claim_b
  and cf.status='open'
  and public.claim_condition_key(a.field,a.qualifier) <> 'default'
  and public.claim_condition_key(b.field,b.qualifier) <> 'default'
  and public.claim_condition_key(a.field,a.qualifier) <> public.claim_condition_key(b.field,b.qualifier);
