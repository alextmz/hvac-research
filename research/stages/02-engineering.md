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



## Cross-market gap filling

For serious contenders, actively search authoritative foreign/regional datasets when Australian material lacks low-load measurements. Highest-value targets are:

- selectable/minimum indoor airflow and the conditions under which it applies;
- minimum and selectable external static pressure;
- automatic ESP / automatic airflow commissioning behaviour, distinguishing one-time calibration from continuous closed-loop constant-airflow control;
- published minimum cooling/heating electrical input;
- independently measured part-load cooling/heating capacity and EER/COP points;
- minimum continuous operation load ratio (`LRcontmin`) and its efficiency correction (`CcpLRcontmin`);
- standby, off, thermostat-off and crankcase-heater power.

Keep these concepts separate:

- catalogue minimum capacity;
- tested part-load capacity at a specified outdoor condition;
- minimum continuous compressor/load ratio;
- published minimum electrical input;
- tested part-load electrical input;
- selectable minimum fan airflow;
- commissioning auto-ESP/airflow calibration;
- continuous runtime constant-airflow control.

For cross-market quantitative transfer, first persist the source model as its own entity and its AU relationship in `entity_relationships`. Cooling/heating min-rated-max ranges, EER/COP and rated input should be equal or very close before treating a model as a regional equivalent. Also compare dimensions/weights, refrigerant charge, piping, compressor, airflow/ESP, sound and electrical supply. Use the provenance qualifier convention in `RESEARCH_PROTOCOL.md`.

Do not call a mild-temperature EN 14825 part-load electrical measurement a "minimum input" unless the source explicitly says it is the minimum. Store the test condition and measurement type.

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