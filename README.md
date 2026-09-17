# HVAC Research — Autonomous Execution Instruction

Evidence-first Australian ducted HVAC research.

## MANDATORY EXECUTION BEHAVIOUR

**This README is an instruction to execute the research autonomously, not merely documentation to read.**

When asked to read/follow this README, immediately begin or resume the research project and **LOOP CONTINUOUSLY** through the live research state until **one** of these two conditions occurs:

1. **THE PROJECT IS DONE** according to the live database, stage stopping rules and final completion/materiality audit; or
2. **54 MINUTES OF WALL-CLOCK TIME HAVE ELAPSED** since the start of the current session/run.

Whichever happens first is the hard stopping condition.

### Do not stop between steps

Until one of the two hard stopping conditions above is reached:

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
START WALL CLOCK
    ↓
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
    ↓
50 minutes elapsed? ── yes → ENTER CLOSEOUT MODE
    │ no                         ↓
    │                    finish pending/atomic work,
    │                    persist state, integrity check,
    │                    avoid starting long new work
    │                            ↓
    │                    54 minutes elapsed? ── yes → HARD STOP
    │                            │ no
    │                            └──── continue closeout only
    │
    └──────────────────────────────→ LOOP AGAIN
```

**Default assumption: KEEP GOING.** A completed item, completed pass, completed stage, tool failure, blocked candidate, or concise progress summary is **not** a stopping condition.

## Project authority

Canonical structured evidence is stored in PostgreSQL/Supabase. This repository stores research protocols/stages, migrations, immutable historical/source snapshots and generated reports.

`historical/v21/` is historical evidence, not automatically verified truth. Claims/evidence/change history are append-only; contradictions remain explicit; corrections supersede rather than overwrite.

The live database remains authoritative for current systems, queues, evidence, dispositions and completion state.

## Mandatory startup and loop

At the start of every run:

1. Record/retain the run's wall-clock start time so both the **50-minute closeout threshold** and **54-minute hard limit** can be enforced.
2. Read [`RESEARCH_INDEX.md`](RESEARCH_INDEX.md).
3. Read [`RESEARCH_PROTOCOL.md`](RESEARCH_PROTOCOL.md).
4. Start/resume using the project's live-database research-run mechanism.
5. Inspect authoritative live state and determine the earliest unfinished stage.
6. Read only the active stage file under `research/stages/`, except where a dependency requires another stage document.
7. Execute useful research work under the protocol.
8. Commit accepted facts/state changes deterministically and atomically as specified by the protocol.
9. Re-query live state.
10. If the current stage is complete, advance immediately to the next unfinished stage.
11. If research changes eligibility, identity or another earlier assumption, reopen/revisit the affected work as required by live state.
12. Repeat steps 5–11 continuously until the project is complete or the run reaches the 50-minute closeout threshold.
13. At 50 minutes, enter closeout mode as defined below and remain in closeout mode until work is safely wrapped or the 54-minute hard cutoff is reached.

Do not reconstruct authoritative state from chat history, previous summaries or old prompts. Do not use a fixed candidate list when the database says otherwise.

## At 50 minutes — mandatory closeout mode

When **50 minutes of wall-clock time** have elapsed and the project is not already complete, **stop initiating substantial new research work and begin closing out the run**.

From minute 50 onward:

- finish any currently in-flight atomic fact commit, bounded verification, retrieval, queue update or state transition that can reasonably complete before minute 54;
- do not start a new broad search, new product/family investigation, new crawl, deep research branch, or other task likely to run past the hard cutoff;
- commit any already-supported facts that are ready to be committed;
- record meaningful failed/exhausted attempts and blockers that have already been discovered;
- release/complete/requeue any claimed queue work as appropriate so the next run can resume deterministically;
- persist required heartbeat/run/activity markers and any other authoritative state needed for interruption recovery;
- re-query the live database for current stage, actionable queue and completion state;
- perform required integrity/consistency checks;
- prepare the research run for a clean stop, including concise notes describing what changed and the next live action.

**Closeout mode is not an early stop.** Continue useful bounded cleanup, commits, reconciliation and integrity work between minutes 50 and 54. The purpose of this four-minute window is to leave no avoidable half-finished state while still enforcing the hard deadline.

If the project becomes fully complete during closeout, perform the final completion/integrity checks and stop immediately rather than waiting for minute 54.

## At the 54-minute cutoff — HARD STOP

At **54 minutes of wall-clock time**, stop the run even if research remains unfinished.

At the hard cutoff:

- do not initiate any new operation;
- finish or rollback only an operation that is already atomic/in-flight and cannot safely be abandoned mid-transaction;
- persist any required attempt, queue, heartbeat/run, blocker and state information that can be recorded immediately;
- ensure the research run is marked with the appropriate `stopped`, `completed` or `failed` state and `ended_at`/notes according to the protocol;
- derive final status from the live database;
- report concisely what materially changed, current stage/state, blockers if any, and the next live action for the next run.

The **54-minute limit is absolute**. Do not continue discretionary research beyond it. The next invocation must resume from persisted live state rather than repeating completed work.

## Completion

“Done” means the live database and [`research/stages/05-audit-report.md`](research/stages/05-audit-report.md) completion/materiality rules indicate that further research is not expected to materially improve the result, with required integrity checks passing. It does **not** mean merely that a single stage, queue batch, candidate family or search pass has finished.

For all detailed evidence, atomic-write, integrity, retry, exact-model, elimination, queue and tool-selection rules, follow [`RESEARCH_PROTOCOL.md`](RESEARCH_PROTOCOL.md) and the active stage file selected through [`RESEARCH_INDEX.md`](RESEARCH_INDEX.md).