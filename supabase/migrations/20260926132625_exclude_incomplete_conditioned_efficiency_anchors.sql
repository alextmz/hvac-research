
create or replace function public.efficiency_measured_anchors(p_entity_id uuid default null)
returns table(
  entity_id uuid,
  canonical_name text,
  manufacturer text,
  anchor_type text,
  outdoor_db_c numeric,
  cooling_capacity_kw numeric,
  cooling_input_w numeric,
  eer numeric,
  capacity_confidence numeric,
  input_confidence numeric,
  anchor_confidence numeric,
  capacity_claim_id uuid,
  input_claim_id uuid,
  capacity_qualifier jsonb,
  input_qualifier jsonb
)
language sql
stable
set search_path to 'public'
as $$
with ranked as (
  select
    c.*,
    case
      when c.field in ('rated_cooling_kw','rated_cooling_input_w') then 'rated'
      when c.field in ('gems_t1_half_cooling_capacity_kw','gems_t1_half_cooling_input_w') then 'gems_t1_half'
      when c.field in ('gems_t1_min_cooling_capacity_kw','gems_t1_min_cooling_input_w') then 'gems_t1_min'
      when c.field in ('gems_low_temp_min_cooling_capacity_kw','gems_low_temp_min_cooling_input_w') then 'gems_low_temp_min'
      when c.field in ('cooling_capacity_high_ambient_kw','cooling_input_high_ambient_w') then 'high_ambient'
    end as anchor_type,
    case
      when c.qualifier ? 'outdoor_db_c'
       and (c.qualifier->>'outdoor_db_c') ~ '^-?[0-9]+([.][0-9]+)?$'
      then (c.qualifier->>'outdoor_db_c')::numeric
      else null
    end as outdoor_db_c,
    row_number() over (
      partition by c.entity_id,
        case
          when c.field in ('rated_cooling_kw','rated_cooling_input_w') then 'rated'
          when c.field in ('gems_t1_half_cooling_capacity_kw','gems_t1_half_cooling_input_w') then 'gems_t1_half'
          when c.field in ('gems_t1_min_cooling_capacity_kw','gems_t1_min_cooling_input_w') then 'gems_t1_min'
          when c.field in ('gems_low_temp_min_cooling_capacity_kw','gems_low_temp_min_cooling_input_w') then 'gems_low_temp_min'
          when c.field in ('cooling_capacity_high_ambient_kw','cooling_input_high_ambient_w') then 'high_ambient'
        end,
        case
          when c.qualifier ? 'outdoor_db_c'
           and (c.qualifier->>'outdoor_db_c') ~ '^-?[0-9]+([.][0-9]+)?$'
          then (c.qualifier->>'outdoor_db_c')::numeric
          else null
        end,
        case when c.field like '%capacity%' or c.field='rated_cooling_kw' then 'capacity' else 'input' end
      order by c.confidence desc nulls last, c.created_at desc, c.id desc
    ) as rn
  from public.effective_claims c
  where c.status='verified'
    and c.value_num is not null
    and (p_entity_id is null or c.entity_id=p_entity_id)
    and not exists (
      select 1
      from public.condition_keyed_fields k
      where k.field=c.field
        and (
          exists (
            select 1
            from unnest(k.required_qualifier_keys) rk
            where not (c.qualifier ? rk)
               or nullif(btrim(coalesce(c.qualifier->>rk,'')),'') is null
          )
          or (
            k.require_airflow and not (
              (c.qualifier ? 'airflow_ls' and nullif(btrim(coalesce(c.qualifier->>'airflow_ls','')),'') is not null)
              or
              (c.qualifier ? 'airflow_m3h' and nullif(btrim(coalesce(c.qualifier->>'airflow_m3h','')),'') is not null)
            )
          )
        )
    )
    and c.field in (
      'rated_cooling_kw','rated_cooling_input_w',
      'gems_t1_half_cooling_capacity_kw','gems_t1_half_cooling_input_w',
      'gems_t1_min_cooling_capacity_kw','gems_t1_min_cooling_input_w',
      'gems_low_temp_min_cooling_capacity_kw','gems_low_temp_min_cooling_input_w',
      'cooling_capacity_high_ambient_kw','cooling_input_high_ambient_w'
    )
),
cap as (
 select * from ranked
 where rn=1 and (field like '%capacity%' or field='rated_cooling_kw')
),
inp as (
 select * from ranked
 where rn=1 and field like '%input%'
)
select
 e.id, e.canonical_name, e.manufacturer,
 cap.anchor_type, cap.outdoor_db_c,
 cap.value_num,
 inp.value_num,
 round((cap.value_num * 1000.0 / nullif(inp.value_num,0))::numeric, 4),
 cap.confidence, inp.confidence,
 least(cap.confidence,inp.confidence),
 cap.id, inp.id, cap.qualifier, inp.qualifier
from cap
join inp on inp.entity_id=cap.entity_id
 and inp.anchor_type=cap.anchor_type
 and inp.outdoor_db_c is not distinct from cap.outdoor_db_c
join public.entities e on e.id=cap.entity_id
where
  cap.unit='kW' and inp.unit='W'
  and (
    cap.anchor_type <> 'high_ambient'
    or public.claim_condition_key(cap.field,cap.qualifier)
       = public.claim_condition_key(inp.field,inp.qualifier)
  )
order by e.canonical_name, cap.anchor_type, cap.outdoor_db_c nulls first
$$;
