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

Controller-platform specialists may claim Stage 3 explicitly:

```sql
select * from public.claim_research_work('<run uuid>', 3);
```

Use explicit Stage 3 only when the returned entity is `controller`; otherwise release it without research. Generic and system-specific workers continue to use `null`.

Treat each claim result as one immutable `current_work` bundle:

- Keep `work_scope`, `queue_id`, `entity_id` and `field` together exactly as returned.
- For every commit, take `p_queue_id`, `p_entity_id` and `p_field` from the same row of `current_work`.
- Before committing, verify those three values still match that row. On mismatch, stop and re-read the current claim; never guess or reuse an identifier.
- After completing, blocking, or releasing the scope, discard `current_work` before claiming another scope.

Do not research queue work before claiming it. Legacy unclaimed commits remain accepted only for backward compatibility.

## 2. Keep leases alive

A run has no maximum age. Effective liveness requires a recent heartbeat plus an active lease backed by `working` queue rows; `research_runs.status='running'` alone is not proof that an agent still exists.

Default work leases are 15 minutes. While searching/reasoning for claimed work, refresh at least every 5 minutes and before any long retrieval batch:

```sql
select * from public.heartbeat_research_work('<run uuid>');
```

`claim_research_work()` and `commit_research_fact()` also heartbeat the run. Heartbeat removes orphan leases before extending valid ones. If a lease expires, reclaim the work before committing.

If abandoning a still-actionable bundle:

```sql
select public.release_research_work('<run uuid>','<work_scope>','<reason>');
```

A DB cron job runs runtime reconciliation every 5 minutes. It recovers expired/abandoned work, removes orphan leases, and closes idle/stale run markers. `begin_research_run()` also invokes stale recovery.

## 3. Read authoritative state

The live Supabase database is authoritative.

- Use `public.canonical_claims` for single-value decisions, comparisons, elimination, completion checks and reports.
- Use `public.canonical_condition_claims` for condition-dependent performance points; it is keyed by entity + field + condition identity and excludes incomplete conditioned evidence.
- Use `public.trusted_claims` for the full currently effective trusted evidence set and conflict investigation.
- Use `public.effective_claims` when inspecting all current assertions, including non-trusted statuses; resolved/superseded historical claims are excluded.
- Use raw `public.claims` only for audit/history. Never use it for current-state decisions.
- An open conflict suppresses that entity/field from `canonical_claims` until resolved.

Use `research_queue`, `research_attempts`, conflicts and stopping rules for work selection. Do not reconstruct state from chat history or prompt counts.

Cheap health check:

```sql
select * from public.research_integrity_health();
```

Healthy means at least:

- `stale_running_runs = 0`
- `idle_running_runs = 0`
- `stale_working_queue = 0`
- `working_queue_without_active_lease = 0`
- `orphan_active_work_leases = 0`
- `expired_work_leases = 0`
- `open_conflicts = 0`
- `unquarantined_supported_verified_without_evidence = 0`

For external status, use `effective_active_runs`, not raw `running_runs`.

Quarantined historical claims are allowed but are not trusted facts.

## 4. Commit accepted facts atomically

Use `public.commit_research_fact(...)` for accepted entity/field facts. It atomically records source, append-only claim, evidence, attempt, queue completion and audit event, and can atomically resolve/supersede a prior immutable claim.

Atomic unit: **one accepted fact for one exact entity/system**. Retrieval and reasoning may cover the whole claimed bundle, but facts commit independently.

For claimed work, every coordinated commit must use `p_queue_id`, `p_entity_id` and `p_field` from one row of the active `current_work` claim result. Never combine identifiers from different claims or scopes.

A coordinated queue commit is accepted only from the run that owns its unexpired lease. Exact retries are idempotent through the deterministic fact key.

Never insert a trusted claim first and attach evidence later.

For accepted facts discovered outside a claimed queue item (for example, a forensic follow-up or resurrection check), still use `public.commit_research_fact(...)` atomically with `p_queue_id := null`. The function is designed to permit queue-less accepted facts while preserving the same source/claim/evidence/change-event integrity guarantees. Do **not** manually insert into `claims` and then try to attach evidence in a later transaction: the deferred evidence-integrity trigger is checked at transaction end, and `claims` are immutable after insertion.

If an accidental/manual `unverified` claim already exists, leave it as immutable audit history and append the accepted evidence-backed assertion through `commit_research_fact()` with a new deterministic fact key. Do not disable triggers, mutate the old claim, or bypass evidence integrity.

Supported numeric evidence is checked against existing effective trusted numeric assertions for the same entity/field and canonical operating-condition identity. Different documented temperatures/airflows/load states do not conflict merely because their values differ. Condition-keyed expanded-performance fields require outdoor DB, indoor DB/WB and airflow metadata before supported/verified commits are accepted. A material disagreement under the same condition identity creates an open conflict; resolve it explicitly before using that field canonically.

## 5. Preserve evidence history

Never update/delete:

- `claims`
- `evidence`
- `change_events`
- `claim_integrity_quarantine`

Corrections are new assertions/evidence. Preserve contradictions and resolve conflicts explicitly. `public.commit_research_fact(...)` is the only supported fact-write API; direct INSERT/UPDATE/DELETE/TRUNCATE on claims/evidence/resolutions is structurally blocked. Exact-scope `not_found` claims are automatically retired when supported/verified evidence is committed. For other replacements, pass `p_resolves_claim_id`, `p_resolution_type` and `p_resolution_reason`. Do not encode resolution only in free-form qualifiers.

## 6. Evidence, identity and context privacy

For decisive engineering facts/elimination prefer:

1. official Australian engineering/service/specification document;
2. official Australian manufacturer product page;
3. official regional material only when exact hardware/revision equivalence is established.

Retailers, snippets, historical v21, model-number inference and different revisions are discovery/corroboration only.

Never transfer specs merely because products share manufacturer, family, nominal capacity, indoor unit or suffix. Exact pairing/revision/phase/refrigerant generation matters. Unknown is not negative evidence.

Keep factual reliability separate from interpretation. Useful dimensions include source authority/market relevance, exact model match, directness, independent-source count, material conflict and semantic certainty.

Project context may record only the coarse Australian climate region needed for analysis. Do not store or introduce precise user location, person names, email addresses or other personally identifiable information in prompts, notes, reports or research context.

## 7. Elimination discipline

Never delete an unattractive system. Set research disposition only when the active stage's evidence rule permits it.

Project-level hard exclusions: exact authoritative evidence confirming either **R410/R410A refrigerant** or **3-phase power** is sufficient to set `metadata.research_disposition = "DO NOT PROGRESS"`, with the exact evidence and a specific disposition reason. Do not infer refrigerant or phase from family/model similarity.

Existing `DO NOT PROGRESS` systems stay out of normal candidate work unless fresh sufficiently authoritative evidence disproves the decisive basis. Every elimination must trace to exact canonical evidence.

## 8. Attempts and interruption recovery

Record meaningful retrieval attempts. Before external retrieval, check existing sources/evidence and prior attempts for the same document or URL; reuse them when freshness is not material. During a session, locally cache downloaded documents by URL/content hash and reuse them. Local cache is non-authoritative and never replaces source provenance.

Before repeating a search path, inspect prior attempts and change strategy unless a new source/version justifies retrying it.

Interrupted fact transactions leave no half-fact. Interrupted research leaves an expiring lease; scheduled reconciliation recovers it automatically. A run marker may briefly remain `running` after a client disappears, so use effective lease-backed liveness for external monitoring.

## 9. Parallelism

Parallelise by **non-overlapping claimed work scopes**. Each agent uses its own research run.

Default pattern:

- claim one entity-stage bundle and bind it as `current_work`;
- retrieve roughly 3–4 useful exact/independent sources in parallel when helpful;
- reason over the bundle coherently;
- commit accepted facts independently using only identifiers from `current_work`;
- heartbeat during research;
- complete, block/exhaust or release the scope;
- discard `current_work`;
- only then claim another bundle.

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
select * from public.commit_research_fact_v2(
  p_run_id := '<run uuid>',
  p_queue_id := '<queue uuid from the same current_work row>',
  p_entity_id := '<entity uuid from that current_work row>',
  p_field := '<field from that current_work row>',
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
  p_attempt_query := '<query>',
  p_fact_key := '<stable deterministic fact key>', -- mandatory; implicit keys are rejected
  p_resolves_claim_id := <prior claim uuid or null>,
  p_resolution_type := <'resolved_not_found'|'superseded'|'duplicate'|'model_mismatch'|'source_correction' or null>,
  p_resolution_reason := '<concise reason or null>'
);
```

The deployed schema/functions are authoritative if this document ever drifts.