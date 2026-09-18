# Deterministic Research Protocol

Mandatory for every stage. Stage-specific scope lives under `research/stages/`.

## 1. Start and claim work

Start through the integrity gate:

```sql
select public.begin_research_run('<objective>','<optional notes>') as run_id;
```

Then claim one entity-stage work bundle:

```sql
select * from public.claim_research_work('<run uuid>', null);
```

With `p_stage = null`, the database selects the earliest claimable stage. The returned rows share one `work_scope`; another run cannot own that scope while its lease is active.

Do not research queue work before claiming it. Legacy unclaimed commits remain accepted only for backward compatibility.

## 2. Keep leases alive

A run has no maximum age. Staleness is based on heartbeat, not `started_at`.

Default work leases are 15 minutes. While searching/reasoning for claimed work, refresh at least every 5 minutes and before any long retrieval batch:

```sql
select * from public.heartbeat_research_work('<run uuid>');
```

`claim_research_work()` and `commit_research_fact()` also heartbeat the run. If a lease expires, reclaim the work before committing.

If abandoning a still-actionable bundle:

```sql
select public.release_research_work('<run uuid>','<work_scope>','<reason>');
```

Expired leases are recoverable by other agents. `begin_research_run()` recovers stale runs/queue state using heartbeat/lease age.

## 3. Read authoritative state

The live Supabase database is authoritative. Use `public.trusted_claims` for decisions, comparisons, elimination, completion checks and reports.

Use `research_queue`, `research_attempts`, conflicts and stopping rules for work selection. Do not reconstruct state from chat history or prompt counts.

Cheap health check:

```sql
select * from public.research_integrity_health();
```

Healthy means at least:

- `stale_running_runs = 0`
- `stale_working_queue = 0`
- `expired_work_leases = 0`
- `unquarantined_supported_verified_without_evidence = 0`

Quarantined historical claims are allowed but are not trusted facts.

## 4. Commit accepted facts atomically

Use `public.commit_research_fact(...)` for accepted entity/field facts. It atomically records source, append-only claim, evidence, attempt, queue completion and audit event.

Atomic unit: **one accepted fact for one exact entity/system**. Retrieval and reasoning may cover the whole claimed bundle, but facts commit independently.

A coordinated queue commit is accepted only from the run that owns its unexpired lease. Exact retries are idempotent through the deterministic fact key.

Never insert a trusted claim first and attach evidence later.

## 5. Preserve evidence history

Never update/delete:

- `claims`
- `evidence`
- `change_events`
- `claim_integrity_quarantine`

Corrections are new assertions/evidence. Preserve contradictions and resolve conflicts explicitly.

## 6. Evidence and identity

For decisive engineering facts/elimination prefer:

1. official Australian engineering/service/specification document;
2. official Australian manufacturer product page;
3. official regional material only when exact hardware/revision equivalence is established.

Retailers, snippets, historical v21, model-number inference and different revisions are discovery/corroboration only.

Never transfer specs merely because products share manufacturer, family, nominal capacity, indoor unit or suffix. Exact pairing/revision/phase/refrigerant generation matters. Unknown is not negative evidence.

Keep factual reliability separate from interpretation. Useful dimensions include source authority/market relevance, exact model match, directness, independent-source count, material conflict and semantic certainty.

## 7. Elimination discipline

Never delete an unattractive system. Set research disposition only when the active stage's evidence rule permits it.

Existing `DO NOT PROGRESS` systems stay out of normal candidate work unless fresh sufficiently authoritative evidence disproves the decisive basis. Every elimination must trace to exact trusted evidence.

## 8. Attempts and interruption recovery

Record meaningful retrieval attempts. Before repeating a search path, inspect prior attempts and change strategy unless a new source/version justifies retrying it.

Interrupted fact transactions leave no half-fact. Interrupted research leaves an expiring lease; another agent may reclaim it after expiry.

## 9. Parallelism

Parallelise by **non-overlapping claimed work scopes**. Each agent uses its own research run.

Default pattern:

- claim one entity-stage bundle;
- retrieve roughly 3–4 useful exact/independent sources in parallel when helpful;
- reason over the bundle coherently;
- commit accepted facts independently;
- heartbeat during research;
- claim another bundle only after the current one is completed, blocked/exhausted, or released.

Parallelise retrieval more readily than semantic mapping. Never manually bypass an active lease or parallel-write the same entity/field.

Use ordinary web search/fetch for straightforward work, Exa for deeper discovery, and Firecrawl for awkward structured retrieval. Do not duplicate the same search across providers without a reason.

## 10. End of pass

Resolve or release all work owned by the run, then run:

```sql
select * from public.research_integrity_health();
```

Finish the run directly:

```sql
update public.research_runs
set status = '<completed|stopped|failed>',
    ended_at = now(),
    notes = '<concise notes>'
where id = '<run uuid>' and status = 'running';
```

Re-query live DB state for all reported counts/status.

Report only material changes, blockers, current stage and next action.

## Fact commit template

```sql
select * from public.commit_research_fact(
  p_run_id := '<run uuid>',
  p_queue_id := '<claimed queue uuid or null>',
  p_entity_id := '<exact entity uuid>',
  p_field := '<field>',
  p_value_num := <numeric or null>,
  p_value_text := '<text or null>',
  p_unit := '<unit or null>',
  p_qualifier := '<json>'::jsonb,
  p_status := 'verified',
  p_confidence := <0..1>,
  p_source_url := '<canonical source URL>',
  p_source_title := '<source title>',
  p_source_type := 'official_manufacturer',
  p_publisher := '<publisher>',
  p_evidence_kind := 'supports',
  p_excerpt := '<short source-faithful excerpt>',
  p_locator := '<page/table/section>',
  p_observed_value := '<observed value>',
  p_independence_group := '<independence group>',
  p_attempt_strategy := '<strategy>',
  p_attempt_query := '<query>'
);
```

The deployed schema/functions are authoritative if this document ever drifts.