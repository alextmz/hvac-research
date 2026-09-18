# Stage 2 — Engineering Verification and Low-Load Behaviour

## Goal

Verify the engineering facts that materially affect low-load comfort, small/night-zone operation, efficiency and early elimination. Spend cheap research effort before expensive behavioural research.

## Priority fields

Cheap/core fields:

- `refrigerant`
- cooling minimum/rated/maximum kW
- `cooling_min_interpretation`
- minimum/low and maximum indoor airflow in L/s where the manufacturer actually exposes them
- static-pressure range where useful
- residential `tcspf_hot` as the primary seasonal cooling-efficiency field
- residential `tcspf_average` / `tcspf_cold` only as supplementary context
- EER/AEER only as rated-point secondary warning indicators
- rated cooling input power
- indoor sound/noise where decision-relevant

Then, for realistic contenders, investigate low-load behaviour that cannot be captured by catalogue values alone:

- published capacity-range endpoint versus demonstrated compressor modulation floor;
- selectable fan minimum versus nominal/test airflow;
- controller fan-speed override/auto behaviour;
- minimum active-zone airflow/area constraints;
- spill-zone or bypass requirements;
- behaviour when requested airflow is below indoor-unit minimum;
- compressor cycling implications at small/night loads.

## Semantic rules

Never conflate:

- published capacity-range endpoint with a proven compressor modulation floor;
- nominal/test airflow with a selectable operating minimum;
- commercial TCSPF with residential TCSPF;
- Hot/Average/Cold TCSPF climate regions;
- seasonal TCSPF with rated-point EER/AEER;
- family/revision data with an exact pairing unless equivalence is established.

For cooling-efficiency comparison and pruning, use **residential `tcspf_hot`** consistently. EER/AEER can flag an anomaly worth checking but must not rank or eliminate a system by themselves.

Qualify the interpretation explicitly when the manufacturer's published minimum is only a range endpoint.

## Evidence priority

For decisive engineering facts and elimination:

1. official Australian engineering/service/specification document;
2. official Australian product page;
3. official regional document only with explicit exact hardware/revision equivalence.

Retailers, snippets, historical reports and model-number inference are discovery/corroboration only and cannot by themselves drive elimination.

## Elimination / DNP

Retain every system in the database. Do not delete it.

Hard rules, each sufficient for `metadata.research_disposition = "DO NOT PROGRESS"` when confirmed by exact authoritative evidence:

- refrigerant is R410 or R410A;
- electrical supply is 3-phase;
- exact official manufacturer evidence confirms `cooling_min_kw > 5.0`;
- exact official manufacturer Australian market status is `Not for sale` or equivalent unavailable-for-new-sale status.

Record the exact evidence and a specific disposition reason. Do not infer refrigerant, phase or market status from family/model similarity.

Efficiency pruning must compare residential `tcspf_hot` against similar-capacity current survivors. EER/AEER are secondary warnings only and are never sufficient for DNP. Treat roughly bottom-quartile Hot TCSPF as a review trigger, not an automatic threshold; retain borderline systems when low-load, airflow, controls or another meaningful advantage compensates.

Dominance review: systems around cooling minimum >=4.0 kW and credible/selectable minimum airflow >=450 L/s deserve comparison against similar-capacity survivors. Apply DNP only when they lack a meaningful compensating advantage such as materially better Hot-region seasonal efficiency or another decision-relevant benefit.

Existing DNP systems remain excluded unless fresh official evidence disproves the decisive basis. Do not routinely re-research them.

## Research strategy

Work one manufacturer engineering family at a time. Retrieve a small number of exact official sources in parallel, map the family carefully, then commit each accepted entity/field fact atomically.

Use prior `research_attempts` as search memory. Do not repeat an exhausted retrieval path unless there is a new reason/source/version to try.

## Stopping rule

This stage is ready when every active engineering family has the cheap/core triage completed **or** has a recorded blocker/exhaustion reason after reasonable official-source attempts, and the remaining serious contenders have enough low-load evidence for the controls stage to be decision-useful.

Do not delay progress indefinitely for low-value fields that are unlikely to change the candidate set; leave them explicitly unresolved/blocked.