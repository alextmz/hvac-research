create or replace function public.detect_material_numeric_claim_conflict()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_claim public.claims%rowtype;
  v_other record;
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
     ) then
    return new;
  end if;

  for v_other in
    select c.id,c.value_num,c.unit
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
      and exists (
        select 1 from public.evidence e
        where e.claim_id = c.id
          and e.evidence_kind = 'supports'
      )
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

drop trigger if exists detect_material_numeric_claim_conflict_after_evidence
on public.evidence;

create trigger detect_material_numeric_claim_conflict_after_evidence
after insert on public.evidence
for each row
execute function public.detect_material_numeric_claim_conflict();

alter function public.assert_claim_evidence_integrity() set search_path = '';
alter function public.prevent_update_delete_quarantine() set search_path = '';
