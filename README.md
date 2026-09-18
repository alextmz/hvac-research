# HVAC Research

Evidence-first Australian ducted HVAC research.

Canonical structured evidence is stored in PostgreSQL/Supabase. This repository stores research protocols/stages, migrations, immutable historical/source snapshots and generated reports.

`historical/v21/` is historical evidence, not automatically verified truth. Claims/evidence/change history are append-only; contradictions remain explicit; corrections supersede rather than overwrite.

Start every research session at [`RESEARCH_INDEX.md`](RESEARCH_INDEX.md). Then read [`RESEARCH_PROTOCOL.md`](RESEARCH_PROTOCOL.md) and only the active stage file selected by live database state.

The live database is authoritative for systems, queues, evidence, dispositions and completion state. Work must be claimed through the database lease mechanism described in the protocol.

## New session prompt

> Read `https://github.com/alextmz/hvac-research/blob/main/README.md` and follow its instructions. Continue autonomously while useful claimable work remains.
