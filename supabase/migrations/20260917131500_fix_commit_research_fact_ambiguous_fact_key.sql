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

  if v_oid is null then
    raise exception 'public.commit_research_fact not found';
  end if;

  v_def := pg_get_functiondef(v_oid);
  if position('from public.claims where fact_key = v_fact_key' in v_def)=0 then
    raise exception 'Expected ambiguous fact_key fragment not found; inspect deployed function before changing';
  end if;

  v_def := replace(
    v_def,
    'from public.claims where fact_key = v_fact_key limit 1;',
    'from public.claims c where c.fact_key = v_fact_key limit 1;'
  );
  execute v_def;
end $$;
