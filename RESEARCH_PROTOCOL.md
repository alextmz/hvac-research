# Deterministic Research Protocol

Mandatory for every research stage. Stage-specific scope lives under `research/stages/`; do not duplicate it here.

## 1. Start through the integrity gate

Do not reconstruct state from chat history or run broad startup audits.

```sql
select public.begin_research_run(
  '<objective>',
  '<optional notes>',
  interval '30 minutes'
) as run_id;
```

This recovers stale interrupted runs/queue work, rejects unsafe unquarantined trusted claims, and creates the new run.

Cheap health check:

```sql
select * from public.research_integrity_health(interval '30 minutes');
```

Healthy before/after work means at least:

- `stale_running_runs = 0`
- `stale_working_queue = 0`
- `unquarantined_supported_verified_without_evidence = 0`

Quarantined historical claims are allowed but are not trusted facts.

## 2. Read live trusted state

Use `public.trusted_claims` for filtering, comparison, elimination, completion checks and reports.

Do not treat raw `claims.status = 'verified'` as sufficient. Raw claims are the immutable assertion ledger and may include quarantined/historical assertions.

Use live `research_queue`, `research_attempts`, conflicts and stopping rules to determine work. Prompt/chat counts and candidate lists are never authoritative.

## 3. Commit accepted facts atomically

Never insert a trusted claim first and attach evidence later.

Use `public.commit_research_fact(...)` for accepted entity/field facts. It atomically performs source reuse/insert, append-only claim insert, evidence insert, research-attempt insert, queue completion and audit event. If any step fails, the fact rolls back.

A deferred DB constraint independently prevents committing a `supported` or `verified` claim without `supports` evidence.

Atomic unit: **one accepted fact for one exact entity/system**. Search/retrieval may be batched by family, but accepted facts should commit independently.

## 4. Append-only history

Never update/delete:

- `claims`
- `evidence`
- `change_events`
- `claim_integrity_quarantine`

Corrections are new assertions/evidence. Preserve contradictions and create/resolve conflicts explicitly. Never erase inconvenient prior evidence.

## 5. Evidence authority and exact identity

Engineering facts require explicit `source -> claim -> evidence` provenance. Entity metadata is not evidence.

For decisive engineering facts/elimination, prefer:

1. official Australian engineering/service/specification document;
2. official Australian manufacturer product page;
3. official regional manufacturer material only when exact hardware/revision equivalence is established.

Retailers, search snippets, historical v21, model-number inference and different revisions are discovery/corroboration sources, not sufficient alone for decisive elimination.

Never transfer specs merely because products share manufacturer, family, nominal capacity, indoor unit or a similar suffix. Exact pairing/revision/phase/refrigerant generation matters. If equivalence is not evidenced, leave the fact unresolved/blocked.

Unknown is not negative evidence.

## 6. Evidence interpretation and reliability

Keep factual reliability separate from interpretation reliability.

Useful derived dimensions include:

- source authority and Australian-market relevance;
- model match: exact pair / exact model / family / inferred;
- directness: direct / derived / inferred;
- independent source count;
- material-conflict flag;
- semantic certainty.

Do not create a second manually maintained “truth” flag when these can be derived from provenance. `claims.confidence` is useful metadata, not a replacement for evidence.

When a value's meaning is limited (for example a published capacity-range endpoint that is not a proven compressor modulation floor), record that limitation in qualifiers rather than silently upgrading its meaning.

## 7. DNP / elimination discipline

Never delete a system because it is unattractive. Retain it and set the appropriate research disposition/reason only when the active stage's evidence rule permits it.

Existing `DO NOT PROGRESS` systems remain excluded from normal candidate work unless fresh sufficiently authoritative evidence disproves the decisive basis. Do not repeatedly re-research them merely to reconfirm them.

Any elimination must be traceable to exact trusted evidence. Secondary discovery evidence cannot silently become the elimination basis.

## 8. Queue, attempt memory and interruption recovery

Record meaningful retrieval/research attempts. Before repeating a search path, inspect prior attempts and change strategy unless there is a reason to retry (new revision, new document, changed site/index, etc.).

An interrupted fact transaction leaves no half-fact. An interrupted pass may leave a stale run/queue lease; the next `begin_research_run()` recovers it.

`commit_research_fact()` is idempotent for an exact retry through its deterministic fact key. A genuinely changed conclusion must be appended as new research, not mutate history.

Quarantined facts should be re-researched when material; queues relying only on quarantined facts should remain/reopen unresolved.

## 9. Tool selection and parallelism

Optimise for deterministic reasoning and research yield, not maximum concurrency or maximum tool use.

When connected and economical:

- use **ordinary web search/fetch** for straightforward discovery and exact official pages;
- use **Exa** for broader/deeper discovery when normal search is weak, for locating technical PDFs/manuals, and for finding independent corroboration efficiently;
- use **Firecrawl** when structured extraction, crawling, or retrieval from awkward manufacturer/document sites materially reduces effort;
- use **GitHub** for project instructions/artifacts and **Supabase** for authoritative structured research state.

Do not run the same query through multiple search providers by default. Escalate tools only when the current method misses needed evidence, retrieval is difficult, or independent corroboration is required. Tool availability/pricing may change; evidence standards must not.

Default concurrency:

- one engineering/product family per reasoning task;
- retrieve roughly 3–4 useful exact/independent documents/pages in parallel when helpful;
- map the family coherently;
- commit facts sequentially;
- never parallel-write the same entity/field;
- separate agents may handle non-overlapping families, each with its own research run.

Parallelise retrieval more readily than semantic mapping and writes.

## 10. End of pass

Run:

```sql
select * from public.research_integrity_health(interval '30 minutes');
```

Mark the current run `completed`, `stopped` or `failed` with `ended_at` and concise notes.

Re-query the live DB for all reported counts/status. Report material changes, blockers and next action; do not dump large already-known lists unless needed.

## Function call template

When an exact accepted fact is ready:

```sql
select * from public.commit_research_fact(
  p_run_id := '<run uuid>',
  p_queue_id := '<queue uuid or null>',
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

The exact deployed function/schema is authoritative if this example ever drifts; inspect it only when an operation fails or the interface changes.