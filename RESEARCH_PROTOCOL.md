# Deterministic Research Protocol

This database is evidence-first and append-only. The rules below are mandatory for every research pass.

## 1. Start every pass through the integrity gate

Do not begin by manually reconstructing state from chat history.

Call:

```sql
select public.begin_research_run(
  '<objective>',
  '<optional notes>',
  interval '30 minutes'
) as run_id;
```

`begin_research_run()` automatically:

- recovers stale interrupted runs;
- resets stale `working` queue items;
- refuses to start if any unquarantined `supported`/`verified` claim lacks supporting evidence;
- creates the new `research_runs` row.

For a cheap health check only:

```sql
select * from public.research_integrity_health(interval '30 minutes');
```

Expected healthy state before work:

- `stale_running_runs = 0`
- `stale_working_queue = 0`
- `unquarantined_supported_verified_without_evidence = 0`

Historical quarantined claims are allowed; they are excluded from trusted use and should be re-researched when relevant.

## 2. Read trusted facts from `trusted_claims`

For decision-making, filtering, ranking, elimination, report generation, and completion checks, use:

```sql
public.trusted_claims
```

Do not treat `claims.status = 'verified'` alone as sufficient. `trusted_claims` requires both:

- status `supported` or `verified`; and
- at least one `supports` evidence row; and
- no integrity-quarantine record.

Raw `claims` remains the immutable historical assertion ledger.

## 3. Commit accepted research atomically

Do not directly insert a `verified`/`supported` claim and later attach evidence in a separate operation.

Use:

```sql
select * from public.commit_research_fact(
  p_run_id := '<run uuid>',
  p_queue_id := '<queue uuid or null>',
  p_entity_id := '<exact entity uuid>',
  p_field := '<field>',
  p_value_num := <numeric value or null>,
  p_value_text := '<text value or null>',
  p_unit := '<unit or null>',
  p_qualifier := '<json qualifier>'::jsonb,
  p_status := 'verified',
  p_confidence := <0..1>,
  p_source_url := '<canonical source URL>',
  p_source_title := '<source title>',
  p_source_type := 'official_manufacturer',
  p_publisher := '<publisher>',
  p_evidence_kind := 'supports',
  p_excerpt := '<short exact/source-faithful excerpt>',
  p_locator := '<page/table/section locator>',
  p_observed_value := '<observed value>',
  p_independence_group := '<source independence group>',
  p_attempt_strategy := '<strategy>',
  p_attempt_query := '<query used>'
);
```

The function performs one PostgreSQL transaction containing:

1. source reuse/insert;
2. append-only claim insert;
3. evidence insert;
4. research-attempt insert;
5. queue completion;
6. change-event audit entry.

If any step fails, the whole fact rolls back.

A deferred database constraint also makes it impossible to commit a `supported` or `verified` claim without `supports` evidence, even if a caller bypasses the helper function.

## 4. Append-only means append-only

Never update or delete rows in:

- `claims`
- `evidence`
- `change_events`
- `claim_integrity_quarantine`

Corrections are new claims/evidence. Preserve contradictory evidence and create/resolve conflicts explicitly where appropriate.

The database enforces immutability with triggers.

## 5. Exact-system discipline

Evidence must map to the exact system/revision/suffix unless explicit equivalence evidence exists.

Do not transfer engineering values merely because products share:

- manufacturer;
- nominal capacity;
- indoor model family;
- similar suffix;
- previous revision.

Record uncertainty in qualifiers. If exact equivalence cannot be established, leave the field unresolved/blocked rather than infer it.

## 6. Queue/retry behaviour

An interrupted fact transaction leaves no half-fact.

An interrupted pass may leave a run or queue lease stale; the next `begin_research_run()` recovers those automatically.

`commit_research_fact()` uses a deterministic fact key and is idempotent for exact retries. If a retry disagrees with an existing claim's status/confidence, it fails rather than silently mutating history; create a new claim/fact key when the research conclusion genuinely changes.

Quarantined facts should be re-researched. Queue entries associated only with quarantined claims are reopened.

## 7. Parallelism policy

Optimise for deterministic reasoning, not maximum simultaneous searches.

Recommended default:

- Work one engineering family at a time.
- Retrieve up to roughly 3-4 independent/exact official documents or exact system pages in parallel when useful.
- Parse/map the family as one reasoning task.
- Commit accepted facts one at a time with `commit_research_fact()`.
- Do not perform parallel writes to the same entity/field.
- Separate agents may research different families, but each must use its own research run and the same atomic-write protocol.

Searching can be moderately parallel; reasoning and writes should remain narrow and deterministic.

## 8. End-of-pass checks

Before reporting completion, run:

```sql
select * from public.research_integrity_health(interval '30 minutes');
```

Then mark the current `research_runs` row `completed`, `stopped`, or `failed` with `ended_at` and concise notes.

Never report counts from chat memory. Re-query the live database, and use `trusted_claims` for facts used in decisions.

## Minimal prompt block for future research chats

Paste or include this near the top of any standalone research prompt:

> **Database integrity protocol — mandatory:** The live Supabase database is the source of truth. Start the pass with `public.begin_research_run(...)`; do not manually reconstruct state first. Use `public.trusted_claims`, not raw `claims.status`, for decision-making. All accepted facts must be written with `public.commit_research_fact(...)`, which atomically commits source + claim + evidence + attempt + queue update + audit event. Never directly create a `supported`/`verified` claim and attach evidence later. Claims/evidence/change history are append-only. Work one product family at a time; parallelise retrieval modestly, but commit facts sequentially. Exact suffix/revision evidence is required; do not transfer values across variants without explicit equivalence evidence. At the end, run `public.research_integrity_health(...)`, update the run status, and derive all reported counts from the live DB.
