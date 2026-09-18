
delete from public.research_work_leases
where run_id = '3e6d0ab2-4ca0-4f2e-afff-34c73a224de9'::uuid;

create or replace function public.cleanup_finished_research_run()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if old.status = 'running' and new.status <> 'running' then
    update public.research_queue
    set status = 'pending',
        claimed_run_id = null,
        claimed_at = null,
        heartbeat_at = null,
        lease_expires_at = null,
        stop_reason = coalesce(stop_reason, 'Released automatically when research run ended')
    where claimed_run_id = new.id
      and status = 'working';

    delete from public.research_work_leases
    where run_id = new.id;
  end if;

  return new;
end
$$;

drop trigger if exists research_run_cleanup_finished on public.research_runs;
create trigger research_run_cleanup_finished
after update of status on public.research_runs
for each row
when (old.status is distinct from new.status)
execute function public.cleanup_finished_research_run();
