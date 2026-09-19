# HVAC Research

Evidence-first Australian ducted HVAC research.

Canonical structured evidence is stored in PostgreSQL/Supabase. This repository stores research protocols/stages, migrations, immutable historical/source snapshots and generated reports.

`historical/v21/` is historical evidence, not automatically verified truth. Claims/evidence/change history are append-only; contradictions remain explicit; corrections supersede rather than overwrite.

## Research objectives

The project aims to identify the most suitable current Australian whole-home ducted reverse-cycle systems, with emphasis on practical performance rather than brochure feature counts.

1. **Whole-home cooling capability** — prioritise systems in the roughly 9 kW+ useful cooling class, while retaining adjacent systems where their maximum cooling output can comfortably serve the target whole-home load.
2. **Strong low-load performance** — prefer systems with a genuinely low cooling minimum, wide inverter/modulation range and behaviour suited to overnight use, small active zones and mild-weather loads. Distinguish published capacity-range endpoints from proven compressor modulation floors.
3. **High seasonal efficiency** — use residential **Hot-climate TCSPF** as the primary cooling-efficiency metric. Treat EER/AEER as secondary rated-point indicators rather than the main ranking or elimination measure.
4. **Low and controllable airflow** — evaluate selectable indoor fan range, minimum airflow, external static-pressure capability and behaviour when only small zones are active. Low minimum airflow is important for comfort, noise and avoiding unnecessary bypass/spill air.
5. **Good native zoning and controls** — assess included and optional controllers, number of zones, per-zone temperature sensing/control, proportional damper control, fan-speed behaviour, spill/bypass requirements and how well the system handles changing active-zone demand.
6. **Open-source and Home Assistant compatibility** — strongly prefer systems/controllers that can integrate reliably with Home Assistant or other open-source automation through documented local interfaces such as Modbus, serial/wired protocols, local network APIs or mature community integrations. Cloud-only control and undocumented proprietary lock-in are disadvantages.
7. **Third-party controller compatibility** — evaluate platforms such as AirTouch and other Australian zoning systems, including exact model compatibility, proportional control, sensor options and the features retained or lost when replacing or supplementing the manufacturer's controller.
8. **Control-path transparency** — document whether unit, zone and sensor control is local or cloud-dependent; what gateways/adapters are required; whether native controllers can coexist; and whether faults, operating mode, fan, setpoint, zone state and other useful functions remain exposed.
9. **Reliability and engineering robustness** — investigate exact-generation or shared-platform fault patterns, compressor/inverter/fan/control hardware, design maturity, serviceability and evidence of robust engineering rather than relying on generic brand reputation.
10. **Australian service, parts and warranty** — compare warranty term and coverage, service-network depth, technical support, parts availability and credible evidence of repair/parts lead times in Australia.
11. **Current market availability and value** — confirm that exact systems are genuinely current Australian products, gather comparable equipment and installed pricing where possible, and judge value using performance, controls and ownership risk rather than lowest sticker price alone.
12. **Exact evidence and decision usefulness** — compare exact indoor/outdoor pairings, revisions, refrigerant and phase variants. Prefer authoritative Australian evidence, preserve uncertainty explicitly, and spend research effort only where another finding could materially change the practical shortlist or final decision.

Start every research session at [`RESEARCH_INDEX.md`](RESEARCH_INDEX.md). Then read [`RESEARCH_PROTOCOL.md`](RESEARCH_PROTOCOL.md) and only the active stage file selected by live database state.

The live database is authoritative for systems, queues, evidence, dispositions and completion state. Work must be claimed through the database lease mechanism described in the protocol.

## New session prompt

> Read `https://github.com/alextmz/hvac-research/blob/main/README.md` and follow its instructions. Continue autonomously while useful claimable work remains.
