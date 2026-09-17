# HVAC Research

Evidence-first Australian ducted HVAC research.

Canonical structured evidence is stored in PostgreSQL/Supabase. This repository stores research protocols/stages, migrations, immutable historical/source snapshots and generated reports.

`historical/v21/` is historical evidence, not automatically verified truth. Claims/evidence/change history are append-only; contradictions remain explicit; corrections supersede rather than overwrite.

Start every research session at [`RESEARCH_INDEX.md`](RESEARCH_INDEX.md). It is the small always-read index that selects the current stage. Then read [`RESEARCH_PROTOCOL.md`](RESEARCH_PROTOCOL.md) plus only the active stage file under `research/stages/`.

The live database remains authoritative for current systems, queues, evidence, dispositions and completion state.