# Stage 1 — Census and Exact System Decomposition

## Goal

Establish a saturated census of current Australian eligible systems and decompose them into exact engineering pairings before deeper comparison.

## Scope

Include current Australian single-split reverse-cycle whole-home ducted systems with nominal/rated cooling broadly 7–13 kW, including nominal systems below 10 kW when maximum cooling reaches at least 10 kW.

Exclude VRF/VRV, multi-split, rooftop packaged, cassette-only, close-control and clearly non-whole-home systems.

## Work

- Discover current manufacturer families from official Australian catalogues/product ranges first; use GEMS/distributors/broad web as discovery aids.
- Resolve exact indoor + outdoor pairings, phase variants, refrigerant revisions, suffixes, package aliases and materially different generations.
- Store exact systems/components/aliases rather than treating a family name as the engineering unit.
- When multiple branded/regional systems are verified as the same physical assembly, create/reuse one canonical `hardware_platform`, register each marketed system in `hardware_platform_memberships`, and keep the marketed system entities intact for brand/model/market identity.
- Use 2% as the default allowable numeric variation for same-hardware collapse only after several physical fingerprints agree. Similar nominal capacity alone is never sufficient.
- Keep materially different electrical/chassis/performance variants as `platform_sibling` relationships rather than forcing them into one hardware platform.
- Treat manufacturer or distributor package names as aliases unless they define a distinct engineering combination.
- Re-check any newly discovered exact system against scope before adding downstream work.

Do not spend significant time on controls, reliability, opinions or pricing in this stage unless needed to establish identity/current sale status.

## Evidence standard

Current official Australian manufacturer material is preferred for existence/pairing. Secondary sources can discover candidates but must not silently establish exact engineering equivalence.

## Saturation rule

Census is complete only after **two consecutive independent discovery passes** produce zero new eligible exact systems/families, with the searches/attempts recorded.

If a later stage discovers a genuinely new eligible current system or materially different revision, reopen this stage for that item and propagate downstream queues.

## Output state

Stage complete when the eligible current-system census is saturated and exact pairings/revisions are represented sufficiently for exact evidence mapping.