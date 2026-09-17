# Stage 5 — Stability Audit and Report Readiness

## Goal

Decide whether more research is likely to materially change the decision, then produce/report from the live evidence rather than from chat summaries.

## Audit dimensions

Check:

- census saturation and exact pairing/revision integrity;
- trusted engineering evidence for serious contenders;
- unresolved conflicts and quarantined facts that could affect decisions;
- low-load/small-zone/night behaviour evidence;
- controller/zoning/Home Assistant feature-retention confidence;
- reliability evidence scope and recurring-risk signals;
- current pricing comparability and freshness;
- blocked/exhausted queue items and prior research attempts;
- DNP decisions for exact evidence and valid reasons;
- database integrity health.

Do not require arbitrary completeness for fields that cannot realistically affect the decision. Focus on material uncertainty.

## Materiality test

Ask:

> If another substantial, well-targeted research pass were performed, is there a realistic chance it would materially change which systems are attractive for low-load/night comfort, zoning/control, reliability or value?

If yes, identify the smallest focused research work that could resolve that uncertainty and return it to the appropriate earlier stage/queue.

If no, mark the research report-ready even if explicitly documented low-materiality unknowns remain.

## Confidence discipline

Do not reduce evidence quality to a single opaque score. Use the evidence graph and qualifiers. When useful, derive/display these dimensions separately:

- evidence status: VERIFIED / SUPPORTED / WEAK / UNVERIFIED / CONFLICTING;
- source authority/market relevance;
- exact model/revision match;
- direct versus derived/inferred evidence;
- independent source count;
- material conflict flag;
- semantic certainty.

A numerical claim confidence may support this but must not replace the underlying provenance.

## Reporting

Reports and candidate counts must be generated from current live DB state and `trusted_claims`.

Clearly distinguish:

- verified facts;
- qualified interpretations;
- recurring anecdotal evidence;
- unresolved material uncertainty;
- explicitly low-materiality gaps.

Do not silently reintroduce DNP systems into normal candidate comparisons.

## Completion

Research is report-ready when database integrity is healthy, material conflicts/unknowns are either resolved or explicitly bounded, and the materiality test indicates another substantial pass is unlikely to change the practical decision.