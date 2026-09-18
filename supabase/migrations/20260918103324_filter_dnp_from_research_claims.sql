create or replace function public.claim_research_work(
  p_run_id uuid,
  p_stage smallint default null::smallint,
  p_lease interval default '00:15:00'::interval
)
returns setof public.research_queue
language plpgsql
set search_path to ''
as $function$
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
      and not (
        q.stage > 1
        and exists (
          select 1
          from public.entities e
          where e.id = q.entity_id
            and e.entity_type = 'system'
            and e.metadata->>'research_disposition' = 'DO NOT PROGRESS'
        )
      )
      and (
        p_stage is not null
        or q.stage = (
          select min(q2.stage)
          from public.research_queue q2
          left join public.research_work_leases l2 on l2.scope_key = q2.work_scope
          where q2.status in ('pending','working')
            and (q2.status = 'pending' or coalesce(q2.lease_expires_at, '-infinity'::timestamptz) <= now())
            and (l2.scope_key is null or l2.expires_at <= now())
            and not (
              q2.stage > 1
              and exists (
                select 1
                from public.entities e2
                where e2.id = q2.entity_id
                  and e2.entity_type = 'system'
                  and e2.metadata->>'research_disposition' = 'DO NOT PROGRESS'
              )
            )
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
$function$;
