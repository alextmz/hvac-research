# Research Index

This is the only project document that should be read on every research session.

## Authority

- GitHub owner/account: `alextmz`
- Repository: `alextmz/hvac-research`
- Supabase project: `hvac-research-supabase`
- Supabase ref: `oqaeycpbvdvlnmrrjyat`
- The live Supabase database is the source of truth.
- `historical/v21/` and old reports/prompts are historical evidence/context only, never verified truth by themselves.

## Tool availability

Use connected tools when they improve quality or reduce research cost/time, but do not make project correctness depend on a particular search vendor.

Preferred roles when available:

- **Supabase** — authoritative structured state, queues, claims/evidence and atomic writes.
- **GitHub** — project instructions, migrations, historical/source snapshots and reports.
- **Exa** — broad/deep discovery, especially when ordinary search is missing technical documents or independent sources.
- **Firecrawl** — retrieval/extraction/crawling when manufacturer sites, technical pages or document collections are awkward to fetch systematically.
- **Normal web search/fetch** — quick discovery and direct official-page verification where sufficient.

Use the cheapest/simplest tool that preserves quality. Do not repeat the same discovery work across Exa, Firecrawl and ordinary web search unless corroboration or retrieval failure justifies it.

Tool availability and pricing may change. If Exa or Firecrawl is unavailable or no longer economical, fall back without changing evidence standards.

## Required loading rule

For any research session:

1. Read this file.
2. Read [`RESEARCH_PROTOCOL.md`](RESEARCH_PROTOCOL.md).
3. Start through `public.begin_research_run(...)`.
4. Claim work through `public.claim_research_work(run_id, null)`; the DB selects the earliest claimable stage and exclusively leases one entity-stage scope.
5. Treat the complete claim result as one immutable work bundle. Use queue/entity/field identifiers only from the same returned row.
6. Read **only that stage file** unless another stage is directly needed to resolve a dependency.
7. Work the claimed scope, calling `heartbeat_research_work(run_id)` at least every 5 minutes during research.
8. Resolve/release the scope, discard the work bundle, re-query live state, then claim the next scope. Advance stages automatically when earlier-stage work is exhausted.

Do not reconstruct project state from chat history or copy counts/candidate lists from prompts.

## Stage order

1. [`research/stages/01-census.md`](research/stages/01-census.md) — eligible-system census and exact engineering-system decomposition.
2. [`research/stages/02-engineering.md`](research/stages/02-engineering.md) — engineering verification, cheap triage, low-load behaviour and elimination.
3. [`research/stages/03-controls.md`](research/stages/03-controls.md) — native controls, zoning, third-party controllers and Home Assistant.
4. [`research/stages/04-market.md`](research/stages/04-market.md) — reliability/service evidence and Australian pricing.
5. [`research/stages/05-audit-report.md`](research/stages/05-audit-report.md) — completion/materiality audit and final report readiness.

Earlier-stage discoveries can reopen later work. Never force monotonic progress when new evidence changes system identity, eligibility, or a decisive engineering fact.

## Global research objective

Evaluate current Australian single-split reverse-cycle whole-home ducted systems relevant to roughly 7–13 kW rated cooling, with emphasis on systems that can serve the intended whole-home load while performing well at low load and with small/night zones. Optimise decision usefulness, not raw data volume.

Primary decision dimensions:

- low-load cooling and small-zone/overnight behaviour;
- efficiency;
- zoning/control quality and Home Assistant integration;
- reliability, serviceability and parts/support in Australia;
- market pricing/value.

Exact model/revision identity always outranks family-level similarity.

## Minimal evolving prompt

Use this for new sessions:

> Continue the Australian ducted HVAC research project in `alextmz/hvac-research` with live Supabase as source of truth. Read `RESEARCH_INDEX.md`, `RESEARCH_PROTOCOL.md`, then only the active stage file. Start with `begin_research_run()`, claim work with `claim_research_work(run_id, null)`, and work only the returned leased scope. Treat each claim result as one immutable work bundle: commit queue/entity/field only from the same returned row, then discard the bundle before claiming another scope. Heartbeat at least every 5 minutes while researching. Use `canonical_claims` for single-value decisions and `trusted_claims` for evidence/history; commit accepted facts with `commit_research_fact()`. Follow exact-model/revision evidence rules, prior attempt memory and stage stopping criteria. Use Exa/Firecrawl only when they improve retrieval or economics. Resolve or release each scope before claiming another. Before reporting, run the integrity health check and derive status from effective active leases, queue state and the live DB rather than `research_runs.status` alone. Report only material changes, blockers, current stage and next action.

That prompt is intended to remain stable while this index and the stage documents evolve.