create table if not exists public.hardware_platform_memberships (
  id uuid primary key default gen_random_uuid(),
  platform_id uuid not null references public.entities(id),
  member_entity_id uuid not null references public.entities(id),
  member_role text not null default 'branded_variant'
    check (member_role in ('reference_implementation','branded_variant','oem_variant','regional_variant')),
  equivalence_class text not null default 'within_2pct'
    check (equivalence_class in ('exact','within_2pct')),
  confidence numeric not null check (confidence >= 0 and confidence <= 1),
  numeric_tolerance_pct numeric not null default 2.0
    check (numeric_tolerance_pct >= 0 and numeric_tolerance_pct <= 5),
  basis jsonb not null default '{}'::jsonb,
  status text not null default 'active'
    check (status in ('active','superseded','rejected')),
  run_id uuid references public.research_runs(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint hardware_platform_memberships_distinct check (platform_id <> member_entity_id),
  constraint hardware_platform_memberships_unique unique (platform_id, member_entity_id)
);

create unique index if not exists hardware_platform_memberships_one_active_platform_per_member
  on public.hardware_platform_memberships(member_entity_id)
  where status='active';

alter table public.hardware_platform_memberships enable row level security;

comment on table public.hardware_platform_memberships is
'Maps branded/regional system entities to one canonical physical hardware platform. Active membership means the hardware is materially the same; numeric differences up to numeric_tolerance_pct (normally 2%) are acceptable only when multiple physical fingerprints agree. Branding/model entities remain distinct.';

create or replace function public.relative_difference_pct(a numeric, b numeric)
returns numeric
language sql
immutable
parallel safe
as $$
  select case
    when a is null or b is null then null
    when a = 0 and b = 0 then 0
    when greatest(abs(a),abs(b)) = 0 then 0
    else abs(a-b) / greatest(abs(a),abs(b)) * 100
  end
$$;

create or replace function public.hardware_values_within_tolerance(
  a numeric,
  b numeric,
  tolerance_pct numeric default 2.0
)
returns boolean
language sql
immutable
parallel safe
as $$
  select public.relative_difference_pct(a,b) <= tolerance_pct
$$;

create or replace function public.hardware_platform_field_inheritable(p_field text)
returns boolean
language sql
immutable
parallel safe
as $$
  select p_field is not null
     and p_field !~* '(price|cost|warranty|market_status|availability|dealer|service_network|support_network|controller|gateway|airtouch|izone|myair|home_assistant|wifi|app_)'
$$;

create or replace function public.register_hardware_platform_member(
  p_platform_id uuid,
  p_member_entity_id uuid,
  p_member_role text,
  p_equivalence_class text,
  p_confidence numeric,
  p_numeric_tolerance_pct numeric default 2.0,
  p_basis jsonb default '{}'::jsonb,
  p_run_id uuid default null
)
returns uuid
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_id uuid;
  v_platform_type text;
begin
  select entity_type into v_platform_type
  from public.entities
  where id=p_platform_id;

  if v_platform_type is distinct from 'hardware_platform' then
    raise exception 'platform % must be an entity_type=hardware_platform', p_platform_id;
  end if;

  if not exists (select 1 from public.entities where id=p_member_entity_id) then
    raise exception 'member entity % does not exist', p_member_entity_id;
  end if;

  if p_numeric_tolerance_pct < 0 or p_numeric_tolerance_pct > 5 then
    raise exception 'numeric tolerance must be between 0 and 5 percent';
  end if;

  insert into public.hardware_platform_memberships(
    platform_id, member_entity_id, member_role, equivalence_class,
    confidence, numeric_tolerance_pct, basis, status, run_id
  )
  values (
    p_platform_id, p_member_entity_id, p_member_role, p_equivalence_class,
    p_confidence, p_numeric_tolerance_pct, coalesce(p_basis,'{}'::jsonb), 'active', p_run_id
  )
  on conflict (platform_id,member_entity_id)
  do update set
    member_role=excluded.member_role,
    equivalence_class=excluded.equivalence_class,
    confidence=excluded.confidence,
    numeric_tolerance_pct=excluded.numeric_tolerance_pct,
    basis=excluded.basis,
    status='active',
    run_id=coalesce(excluded.run_id,public.hardware_platform_memberships.run_id),
    updated_at=now()
  returning id into v_id;

  return v_id;
end
$$;

create or replace view public.hardware_platform_equivalents
with (security_invoker=true)
as
select
  m.platform_id,
  p.canonical_name as platform_name,
  m.member_entity_id,
  e.manufacturer,
  e.model_code,
  e.canonical_name as member_name,
  m.member_role,
  m.equivalence_class,
  m.confidence,
  m.numeric_tolerance_pct,
  m.basis,
  m.status,
  m.run_id,
  m.created_at,
  m.updated_at
from public.hardware_platform_memberships m
join public.entities p on p.id=m.platform_id
join public.entities e on e.id=m.member_entity_id;

create or replace view public.decision_input_claims
with (security_invoker=true)
as
with direct_claims as (
  select
    c.id,c.entity_id,c.subject_text,c.field,c.value_text,c.value_num,c.unit,
    c.qualifier,c.status,c.confidence,c.created_at,c.supersedes_claim_id,
    c.entity_id as source_entity_id,
    null::uuid as platform_id,
    'exact_entity'::text as origin_scope,
    null::text as equivalence_class,
    1::numeric as equivalence_confidence
  from public.canonical_claims c
),
platform_claims as (
  select
    pc.id,
    m.member_entity_id as entity_id,
    pc.subject_text,
    pc.field,
    pc.value_text,
    pc.value_num,
    pc.unit,
    pc.qualifier || jsonb_build_object(
      'evidence_scope','hardware_platform_inherited',
      'hardware_platform_id',m.platform_id,
      'source_claim_entity_id',pc.entity_id,
      'membership_id',m.id,
      'member_role',m.member_role,
      'equivalence_class',m.equivalence_class,
      'equivalence_confidence',m.confidence,
      'numeric_tolerance_pct',m.numeric_tolerance_pct,
      'exact_market_sku_value',false
    ) as qualifier,
    pc.status,
    least(1::numeric, pc.confidence * m.confidence) as confidence,
    pc.created_at,
    pc.supersedes_claim_id,
    pc.entity_id as source_entity_id,
    m.platform_id,
    'hardware_platform'::text as origin_scope,
    m.equivalence_class,
    m.confidence as equivalence_confidence
  from public.hardware_platform_memberships m
  join public.canonical_claims pc on pc.entity_id=m.platform_id
  where m.status='active'
    and public.hardware_platform_field_inheritable(pc.field)
    and not exists (
      select 1 from public.canonical_claims dc
      where dc.entity_id=m.member_entity_id
        and dc.field=pc.field
    )
)
select * from direct_claims
union all
select * from platform_claims;

create or replace view public.decision_input_condition_claims
with (security_invoker=true)
as
with direct_claims as (
  select
    c.id,c.entity_id,c.subject_text,c.field,c.value_text,c.value_num,c.unit,
    c.qualifier,c.status,c.confidence,c.created_at,c.supersedes_claim_id,
    c.run_id,c.fact_key,c.condition_key,
    c.entity_id as source_entity_id,
    null::uuid as platform_id,
    'exact_entity'::text as origin_scope,
    null::text as equivalence_class,
    1::numeric as equivalence_confidence
  from public.canonical_condition_claims c
),
platform_claims as (
  select
    pc.id,
    m.member_entity_id as entity_id,
    pc.subject_text,
    pc.field,
    pc.value_text,
    pc.value_num,
    pc.unit,
    pc.qualifier || jsonb_build_object(
      'evidence_scope','hardware_platform_inherited',
      'hardware_platform_id',m.platform_id,
      'source_claim_entity_id',pc.entity_id,
      'membership_id',m.id,
      'member_role',m.member_role,
      'equivalence_class',m.equivalence_class,
      'equivalence_confidence',m.confidence,
      'numeric_tolerance_pct',m.numeric_tolerance_pct,
      'exact_market_sku_value',false
    ) as qualifier,
    pc.status,
    least(1::numeric, pc.confidence * m.confidence) as confidence,
    pc.created_at,
    pc.supersedes_claim_id,
    pc.run_id,
    pc.fact_key,
    pc.condition_key,
    pc.entity_id as source_entity_id,
    m.platform_id,
    'hardware_platform'::text as origin_scope,
    m.equivalence_class,
    m.confidence as equivalence_confidence
  from public.hardware_platform_memberships m
  join public.canonical_condition_claims pc on pc.entity_id=m.platform_id
  where m.status='active'
    and public.hardware_platform_field_inheritable(pc.field)
    and not exists (
      select 1 from public.canonical_condition_claims dc
      where dc.entity_id=m.member_entity_id
        and dc.field=pc.field
        and dc.condition_key=pc.condition_key
    )
)
select * from direct_claims
union all
select * from platform_claims;

comment on view public.decision_input_claims is
'Decision-facing claims. Exact entity/SKU canonical claims always win. Missing fields may inherit canonical hardware-platform facts with explicit provenance and confidence reduction.';

comment on view public.decision_input_condition_claims is
'Condition-keyed decision-facing claims. Exact entity/SKU condition claims win; missing condition points may inherit from the canonical hardware platform with explicit provenance.';

do $$
declare
  v_def text;
begin
  select pg_get_functiondef('public.refresh_unit_decision_v6()'::regprocedure) into v_def;
  if v_def is not null and v_def like '%public.canonical_claims%' then
    v_def := replace(v_def,'public.canonical_claims','public.decision_input_claims');
    execute v_def;
  end if;
end
$$;
