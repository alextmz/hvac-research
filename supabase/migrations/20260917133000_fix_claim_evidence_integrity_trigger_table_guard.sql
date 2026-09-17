create or replace function public.assert_claim_evidence_integrity()
returns trigger
language plpgsql
as $function$
declare
  v_claim_id uuid;
  v_status text;
begin
  if tg_table_name = 'claims' then
    v_claim_id := new.id;
  else
    v_claim_id := case when tg_op = 'DELETE' then old.claim_id else coalesce(new.claim_id, old.claim_id) end;
  end if;

  select status into v_status from public.claims where id = v_claim_id;
  if v_status in ('supported','verified') and not exists (
    select 1 from public.evidence e
    where e.claim_id = v_claim_id and e.evidence_kind = 'supports'
  ) then
    raise exception 'claim % cannot be % without supporting evidence', v_claim_id, v_status;
  end if;

  if tg_table_name = 'evidence' then
    if tg_op = 'UPDATE' and old.claim_id is distinct from new.claim_id then
      select status into v_status from public.claims where id = old.claim_id;
      if v_status in ('supported','verified') and not exists (
        select 1 from public.evidence e
        where e.claim_id = old.claim_id and e.evidence_kind = 'supports'
      ) then
        raise exception 'claim % cannot be % without supporting evidence', old.claim_id, v_status;
      end if;
    end if;
  end if;

  return coalesce(new, old);
end;
$function$;
