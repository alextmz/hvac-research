# HVAC Research

Evidence-first Australian ducted HVAC research.

Canonical structured evidence is stored in PostgreSQL/Supabase. This repository stores migrations, immutable historical/source snapshots, research-loop specifications, and generated reports.

`historical/v21/` is historical evidence, not automatically verified truth. Claims are append-only; contradictions remain explicit; corrections supersede rather than overwrite.

For every research pass, follow [`RESEARCH_PROTOCOL.md`](RESEARCH_PROTOCOL.md). It defines the integrity-gated run start, `trusted_claims` read path, atomic `commit_research_fact()` write path, interruption recovery, and parallelism rules.
