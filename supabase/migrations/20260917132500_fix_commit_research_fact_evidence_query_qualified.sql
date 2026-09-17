do $$
declare
  v_oid oid;
  v_def text;
  v_new text;
begin
  select p.oid into v_oid
  from pg_proc p
  join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='commit_research_fact'
  order by p.oid desc limit 1;
  v_def := pg_get_functiondef(v_oid);
  v_new := replace(v_def,
$old$select id into v_evidence_id
  from public.evidence
  where claim_id=v_claim_id and source_id=v_source_id and evidence_kind=p_evidence_kind
    and locator is not distinct from p_locator
  limit 1;$old$,
$new$select e.id into v_evidence_id
  from public.evidence e
  where e.claim_id=v_claim_id and e.source_id=v_source_id and e.evidence_kind=p_evidence_kind
    and e.locator is not distinct from p_locator
  limit 1;$new$);
  if v_new = v_def then raise exception 'Evidence query patch did not match'; end if;
  execute v_new;
end $$;
