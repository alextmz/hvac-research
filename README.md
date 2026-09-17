# HVAC Research — Autonomous Execution Instruction

Evidence-first Australian ducted HVAC research.

## MANDATORY EXECUTION BEHAVIOUR

**This README is an instruction to execute the research autonomously, not merely documentation to read.**

When asked to read/follow this README, immediately begin or resume the research project and **LOOP CONTINUOUSLY** through the live research state until **THE PROJECT IS DONE** according to the live database, stage stopping rules and final completion/materiality audit.

### Do not stop between steps

Until the project is complete:

- **Do not stop after one search, one product, one queue item, one family, one pass, or one stage.**
- **Do not stop merely because the current stage became complete.** Re-query live state and immediately advance to the next unfinished stage.
- **Do not ask the user what to do next.** Select the next action from the live database, queue, conflicts, stopping rules and stage instructions.
- **Do not return control just to report progress.** Continue researching and committing useful work.
- **Do not wait for another prompt to continue.** Treat completion of each action as a trigger to select and execute the next highest-value valid action.
- Process **all research stages and state transitions autonomously**, including reopening work when new evidence invalidates an earlier assumption.
- If a search/retrieval path is exhausted, record the attempt as required, choose another unresolved/high-value item or strategy, and continue.
- If one item is blocked, record the blocker and continue with other actionable work rather than ending the run.
- Use available tools autonomously when they improve quality, speed or cost-efficiency while preserving the evidence rules.

The intended control flow is explicitly:

```text
read live state / begin or resume run
    ↓
select earliest unfinished stage + highest-value actionable work
    ↓
research → verify → commit atomically → update state
    ↓
re-query authoritative live state
    ↓
project complete? ── yes → final integrity/completion checks → STOP
    │ no
    └──────────────────────────────→ LOOP AGAIN
```

**Default assumption: KEEP GOING.** A completed item, completed pass, completed stage, tool failure, blocked candidate, or concise progress summary is **not** a stopping condition.

## Project authority

Canonical structured evidence is stored in PostgreSQL/Supabase. This repository stores research protocols/stages, migrations, immutable historical/source snapshots and generated reports.

`historical/v21/` is historical evidence, not automatically verified truth. Claims/evidence/change history are append-only; contradictions remain explicit; corrections supersede rather than overwrite.

The live database remains authoritative for current systems, queues, evidence, dispositions and completion state.

## Mandatory startup and loop

At the start of every run:

1. Read [`RESEARCH_INDEX.md`](RESEARCH_INDEX.md).
2. Read [`RESEARCH_PROTOCOL.md`](RESEARCH_PROTOCOL.md).
3. Start/resume using the project's live-database research-run mechanism.
4. Inspect authoritative live state and determine the earliest unfinished stage.
5. Read only the active stage file under `research/stages/`, except where a dependency requires another stage document.
6. Execute useful research work under the protocol.
7. Commit accepted facts/state changes deterministically and atomically as specified by the protocol.
8. Re-query live state.
9. If the current stage is complete, advance immediately to the next unfinished stage.
10. If research changes eligibility, identity or another earlier assumption, reopen/revisit the affected work as required by live state.
11. Repeat steps 4–10 continuously until the project is complete.

Do not reconstruct authoritative state from chat history, previous summaries or old prompts. Do not use a fixed candidate list when the database says otherwise.

## Completion

“Done” means the live database and [`research/stages/05-audit-report.md`](research/stages/05-audit-report.md) completion/materiality rules indicate that further research is not expected to materially improve the result, with required integrity checks passing. It does **not** mean merely that a single stage, queue batch, candidate family or search pass has finished.

For all detailed evidence, atomic-write, integrity, retry, exact-model, elimination, queue and tool-selection rules, follow [`RESEARCH_PROTOCOL.md`](RESEARCH_PROTOCOL.md) and the active stage file selected through [`RESEARCH_INDEX.md`](RESEARCH_INDEX.md).
