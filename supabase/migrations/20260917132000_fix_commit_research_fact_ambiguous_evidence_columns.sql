do $$
declare
  v_oid oid;
  v_def text;
begin
  select p.oid into v_oid
  from pg_proc p
  join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='commit_research_fact'
  order by p.oid desc
  limit 1;

  if v_oid is null then raise exception 'public.commit_research_fact not found'; end if;
  v_def := pg_get_functiondef(v_oid);

  if position('from public.evidence' in v_def)=0 then
    raise exception 'Expected evidence query not found';
  end if;

  v_def := replace(
    v_def,
    'from public.evidence
  where claim_id=v_claim_id and source_id=v_source_id and evidence_kind=p_evidence_kind
    and locator is not distinct from p_locator',
    'from public.evidence e
  where e.claim_id=v_claim_id and e.source_id=v_source_id and e.evidence_kind=p_evidence_kind
    and e.locator is not distinct from p_locator'
  );
  execute v_def;
end $$;
