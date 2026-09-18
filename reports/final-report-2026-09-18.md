# Australian Ducted HVAC Research — Final Stage 5 Decision Report

**Snapshot:** 18 September 2026, 23:13 AEST  
**Authority:** live Supabase `canonical_claims` / `trusted_claims` state  
**Scope:** current Australian single-split reverse-cycle ducted systems relevant to roughly 7–13 kW rated cooling, prioritising low-load/night operation, Hot-climate seasonal efficiency, zoning/Home Assistant, reliability/serviceability and value.

> **Stage 5 scope note:** this is the requested final decision report from evidence currently accepted in the live database. The three pending Stage 5 audit/discovery/stability passes were intentionally not executed and are not marked complete.

## 1. Executive decision

### Primary recommendation: Rinnai B1A R32

The **Rinnai B1A R32 family is the strongest all-round decision from the current evidence**.

- **DINLR09B1A / DONSR09B1LA (9.0 kW rated)** is the best fit where the design load allows it: 2.30 kW published cooling minimum, 11.61 kW maximum, 139 L/s minimum indoor airflow and residential Hot-region TCSPF 5.817.
- **DINLR11B1A / DONSR11B1LA (10.5 kW rated)** is the stronger choice where the load requires more nominal capacity: 2.61 kW published minimum, 11.99 kW maximum, 167 L/s minimum airflow and TCSPF Hot 5.935.
- Native Rinnai Home zoning provides up to 8 zones, individual zone temperature sensing/control, 5% airflow adjustment and automatic fan response.
- Exact current B1A compatibility is documented for iZone C325R2, giving a local Home Assistant path through the built-in iZone integration.
- Current equipment-only pricing is unusually competitive: roughly **A$2.4–2.8k for 9 kW**, **A$2.7–3.1k for 11 kW** and **A$3.1–3.7k for 13 kW** before controller, ducting and installation.
- Current residential warranty is **7 years parts and labour**.

The main limitation is important: the published minimum cooling figures are **capacity-range endpoints, not proven continuous compressor modulation floors**. Exact behaviour below those loads remains unpublished. The same caveat applies to most competing systems.

### Strong alternatives

**MHI FDU100VH / FDCA100VNP-W** has the lowest published cooling endpoint among the decision-ready shortlist at **2.1 kW**, with 317 L/s minimum airflow, strong native/third-party control options and a local Home Assistant path via AirTouch 5. It is an excellent low-capacity alternative, but its published maximum is only 10.2 kW and no canonical residential Hot TCSPF is available, so capacity headroom and seasonal efficiency are less certain.

**Hitachi airCore 700 PPIM-4.0UFA1NQ / PAS-4.0UFASNQ1** is the most balanced alternative: 10.0 kW rated, 3.2–12.0 kW published range, 350 L/s minimum airflow, TCSPF Hot 5.09, strong 8-zone native control, local iZone/Home Assistant integration, good Australian support evidence and a 6-year warranty. Current 10 kW equipment pricing clusters around **A$3.64–3.71k**.

**Fujitsu ARTH30KMTAP / AOTH30KBTA** is attractive for zoning/automation: 2.8–10.3 kW published range, 336 L/s minimum airflow, anywAiR VAV zoning in 5% increments and a built-in local Home Assistant integration path. Its TCSPF Hot of 4.781 is materially below Rinnai's, and its 8.5 kW rating / 10.3 kW maximum gives less whole-home headroom.

### Value and controls alternatives

**Carrier QSH105** is the strongest value wildcard. The 10.05 kW system publishes 2.4–11.7 kW, around 333 L/s minimum airflow, exact iZone compatibility, local Home Assistant and a 7-year warranty. Equipment pricing is only about **A$2.79–3.20k**. It remains below the primary shortlist because a residential Hot TCSPF is not canonical and native zoning capability is not established in the accepted evidence.

**Toshiba RAV-GM high-static / Super Digital** has unusually capable native T-Zone control—up to 14 zones, individual temperature control, wireless sensors and automatic airflow response—and a qualified local AirTouch/Home Assistant route. The current DTP-A1/GP exact-revision record still has gaps in rated/max capacity and TCSPF, and its known minimum airflow is relatively high (466 L/s), making it less compelling for the smallest night zones.

**Panasonic PF3** has good Hot-region efficiency (TCSPF Hot 5.12 for the 9.5 kW Compact pairing), 350 L/s minimum airflow and strong native CONEX zoning. However, the exact cooling minimum is unresolved, exact third-party compatibility is only brand-level in current evidence, and the native Home Assistant route is cloud/custom rather than a clearly established local core integration.

## 2. Decision table

| Candidate | Rated / published cooling range | Min airflow | TCSPF Hot | Zoning / Home Assistant | Current equipment price | Warranty | Decision note |
|---|---:|---:|---:|---|---:|---:|---|
| **Rinnai DINLR09B1A / DONSR09B1LA** | 9.0 / 2.30–11.61 kW | **139 L/s** | **5.817** | Rinnai Home 8-zone; exact iZone; local HA | **A$2.4–2.8k** | 7 yr | Best low-load/value/control balance if 9 kW rated is sufficient |
| **Rinnai DINLR11B1A / DONSR11B1LA** | 10.5 / 2.61–11.99 kW | **167 L/s** | **5.935** | Same B1A control stack | **A$2.7–3.1k** | 7 yr | Preferred if design load needs ~10 kW nominal |
| **MHI FDU100VH / FDCA100VNP-W** | 10.0 / 2.1–10.2 kW | 317 L/s | unknown | FlexiZone/Airzone; AirTouch 5 local HA | ~A$3.5–3.7k | 5 yr | Excellent published minimum; narrow capacity headroom and TCSPF gap |
| **Hitachi PPIM-4.0 / PAS-4.0** | 10.0 / 3.2–12.0 kW | 350 L/s | 5.09 | Premium Zoning 8-zone; exact iZone local HA | A$3.64–3.71k | 6 yr | Strong balanced alternative |
| **Fujitsu ARTH30KMTAP / AOTH30KBTA** | 8.5 / 2.8–10.3 kW | 336 L/s | 4.781 | anywAiR 10-zone VAV; local HA | 10 kW family listings ~A$4.26–4.68k | 5 yr | Strong control stack; lower efficiency/headroom |
| **Carrier QSH105** | 10.05 / 2.4–11.7 kW | 333 L/s | unknown | exact iZone; local HA; native zoning not established | **A$2.79–3.20k** | 7 yr | Excellent value; seasonal-efficiency/control gaps |
| **Panasonic PF3 9.5 Compact** | 9.5 / min unknown–11.4 kW | 350 L/s | 5.12 | CONEX 8-zone; HA cloud/custom unless third-party exact match proven | ~A$4.57k | 5 yr | Solid native system, but low-load and HA evidence weaker |
| **Toshiba RAV-GM DTP-A1 / GP 10 kW class** | exact current revision has canonical rated/max gaps; min 2.6 kW | 466 L/s | unknown | T-Zone 14-zone; qualified AirTouch local HA | Super Digital high-static ~A$4.20k | 7 yr | Controls-rich but less convincing for tiny-zone airflow |
| **ActronAir ASPIRE LRE-100DS / URC-100DS** | 10.2 / 2.3–11.61 kW | **139 L/s** | **5.61** | NEXUS requires constant-zone/bypass strategy; Stage 3/4 family evidence incomplete | unresolved | unresolved | Engineering standout, but not decision-ready in current DB |

Prices are equipment-only unless noted and are not directly comparable with installed quotes.

## 3. Low-load and night-zone findings

Published minimum cooling capacity must not be treated as a demonstrated compressor modulation floor. For the leading systems, exact manufacturer material generally does **not** establish the load below which the compressor begins cycling, minimum on/off times or stable duty cycle.

The strongest directly useful low-load indicator in the current evidence is therefore the combination of:

1. published cooling-range endpoint;
2. selectable/credible minimum indoor airflow;
3. zoning behaviour as zones close;
4. required constant/spill/bypass airflow.

On those observable dimensions, Rinnai B1A is unusually strong because both the published capacity endpoint and indoor airflow are low. MHI FDU VNP has the lowest published capacity endpoint but materially higher minimum airflow. Hitachi and Fujitsu remain credible but require more airflow. Panasonic's cooling minimum is unresolved. Toshiba's high-static branch has substantially higher minimum airflow.

A notable warning is **MHI FDUA**: its FlexiZone guidance calls for a common or automatic spill zone carrying roughly 50% of total airflow, which works against the goal of conditioning a very small bedroom zone alone. This is why the FDU slimline VNP system is preferred over FDUA for this objective.

## 4. Seasonal efficiency

Residential **TCSPF Hot** remains the primary seasonal cooling metric. Among relevant live canonical values:

- ActronAir UltraSlim 2 LRE-100CS / LRC-100CS: **7.30**, but with 4.0 kW published minimum, 400 L/s minimum airflow and incomplete later-stage evidence.
- Rinnai B1A 11 kW: **5.935**.
- Rinnai B1A 9 kW: **5.817**.
- ActronAir ASPIRE 10.2 kW: **5.61**.
- Panasonic PF3 9.5 Compact: **5.12**.
- Hitachi airCore 700 PPIM 10 kW: **5.09**.
- Fujitsu ARTH30 KMTAP: **4.781**.

The missing Hot TCSPF values for MHI FDU VNP, Carrier QSH and Toshiba remain material comparison gaps. EER is not used to substitute for those missing seasonal values.

## 5. Zoning and Home Assistant

The strongest currently evidenced paths are:

- **Rinnai B1A:** native Rinnai Home up to 8 zones with individual temperature control; exact iZone C325R2 compatibility; Home Assistant core via local iZone.
- **MHI FDU:** FlexiZone or MHIAA Airzone; AirTouch 5 retains core unit controls and can coexist with the MHI wall controller; Home Assistant core uses Local Push.
- **Fujitsu KMTAP:** exact anywAiR UTY-ANY2 compatibility, up to 10 zones and VAV control; built-in Home Assistant integration over local LAN.
- **Hitachi airCore 700:** official Premium Zoning up to 8 zones; exact iZone support on listed variants; local Home Assistant path.
- **Carrier QSH:** exact iZone compatibility and local Home Assistant are verified, but native zoning is not established.
- **Toshiba DTP:** T-Zone is exceptionally feature-rich; AirTouch/Home Assistant is viable but exact RAV model enumeration and native-feature retention through the third-party path remain qualified.
- **Panasonic PF3:** native CONEX zoning is strong, but the currently established Home Assistant path is less attractive because native Comfort Cloud is internet-dependent and the HA integration is custom/HACS; exact local third-party PF3 compatibility remains unverified.

Third-party “compatible” must not be read as “all native features retained”. Schedules, fault/status detail, special modes and native zoning logic remain unknown on several third-party paths.

## 6. Reliability, serviceability and warranty

No repeated exact-current hardware failure pattern was established for the primary shortlist. That is **not evidence that failures do not occur**; it means the current evidence is stronger for serviceability/support than for statistically meaningful exact-model failure rates.

Current support/warranty evidence favours:

- **Rinnai:** national 1st Care network, commonly used genuine spares carried, 7-year residential parts/labour; peak-season lead times can vary.
- **Carrier:** Australia-wide service-agent and installer technical support, service documents and parts information; 7-year parts/labour.
- **Toshiba:** dedicated warranty/service, dealer/installer support and spare-parts channel; 7-year parts/labour.
- **Hitachi/Temperzone:** documented technical/warranty/spares support and mobile service capability; 6-year parts/labour.
- **MHI:** current Australian manufacturer support; 5-year parts/labour.
- **Fujitsu:** General Assist and current technical support; 5-year parts/labour.
- **Panasonic:** authorised service and 5-year parts/labour; exact PF3 long-run fault evidence is comparatively thin.

## 7. Value

For equipment-only pricing, the strongest observed value is currently:

1. **Rinnai B1A** — especially the 9 and 11 kW systems.
2. **Carrier QSH** — similarly aggressive pricing with 7-year warranty, but with greater efficiency/control uncertainty.
3. **MHI FDU VNP / Hitachi airCore 700** — mid-priced, with stronger control/support evidence than many alternatives.
4. **Toshiba** — middle-to-upper range depending Digital vs Super Digital.
5. **Fujitsu / Panasonic** — generally higher equipment pricing in the current observations.

Installed-price comparisons remain configuration-sensitive and are not sufficiently standardised to override the engineering/control conclusions.

## 8. Material uncertainties retained

These gaps are explicitly retained rather than guessed:

- no demonstrated continuous compressor floor / below-minimum cycling behaviour for most systems;
- Hot TCSPF missing for MHI FDU VNP, Carrier QSH and Toshiba RAV;
- ActronAir ASPIRE has excellent engineering evidence but insufficient canonical Stage 3/4 control, reliability and price coverage to elevate it;
- Panasonic PF3 exact cooling minimum is unresolved;
- exact third-party feature retention remains incomplete for several brands;
- installed prices are not normalised across duct design, outlet count, zoning hardware and electrical work;
- three Stage 5 audit/discovery/stability queue items remain pending by explicit instruction.

These gaps matter chiefly to confidence around secondary contenders. They do not presently displace Rinnai B1A as the best-supported all-round choice.

## 9. Practical selection

For quotation/design work:

- If the calculated whole-home load can be met by the 9 kW nominal system, start with **Rinnai DINLR09B1A / DONSR09B1LA**.
- If closer to 10 kW nominal is required, start with **Rinnai DINLR11B1A / DONSR11B1LA** and compare directly with **MHI FDU100 VNP** and **Hitachi PPIM-4.0**.
- Require the installer to document the actual ducted minimum-airflow strategy for the smallest intended night zone, including any constant/spill/bypass zone.
- If Home Assistant is important, quote the exact controller/gateway path rather than accepting generic “Wi-Fi compatible” wording.
- Compare installed quotes only after normalising zone count, sensors, controller, damper type, duct sizes, return-air design, electrical work and commissioning.

## 10. Stage 5 status

At report generation, database integrity was healthy:

- open conflicts: **0**
- unquarantined supported/verified claims without supporting evidence: **0**
- stale/idle research runs or orphan/expired work leases: **0**
- trusted claims: **3,073**
- canonical claims: **3,002**
- quarantined historical claims: **118**
- system entities: **180**
- DO NOT PROGRESS systems: **112**
- surviving systems: **68**
- current objective-fit survivors under the report query: **56 systems across 23 families**

This report is therefore a valid final decision snapshot from the accepted evidence, while **not asserting that the three intentionally skipped Stage 5 audit passes are complete**.

## 11. Key exact-system engineering sources

- Rinnai current product page: https://www.rinnai.com.au/online/air-conditioning/ducted-air-conditioning/duct-ac-7-18-r32a/
- Rinnai R32 installation manual: https://www.rinnai.com.au/wp-content/uploads/AC-Ducted-R32-2603-IM.pdf
- Rinnai ducted brochure: https://www.rinnai.com.au/wp-content/uploads/AC-Ducted-2606-BRO.pdf
- Rinnai Home controller manual: https://www.rinnai.com.au/wp-content/uploads/CON-AC-Home-OM.pdf
- MHI FDU series: https://www.mhiaa.com.au/products/series/ducted-air-conditioning-fdu-series/
- Fujitsu ARTH30 KMTAP: https://www.fujitsugeneral.com.au/product/set-arth30kmtap
- Fujitsu KMTAP installation material: https://assist.fujitsugeneral.com.au/support/solutions/articles/6000282815-installation-manual-ducted-indoor-arth18-24-30-36-45-54kmtap-outdoor-aoth30-36-45-54kbta-aoth24
- Hitachi airCore 700 specifications: https://www.hitachiaircon.com/au/download_datatable/19
- Carrier QSM/QSH brochure: https://www.carrierair.com.au/wp/wp-content/uploads/2024/09/Carrier-Ducted-Systems_.pdf
- Panasonic R32 Adaptive Ducted: https://www.panasonic.com/au/hvac/products/air-conditioner/single-split-packaged-air-conditioner/ducted/r32-inverter-nx-series-adaptive-ducted.html
- Toshiba Australia ducted technical brochure: https://toshiba-aircon.com.au/techdocs/api/files/1622
- ActronAir ASPIRE technical catalogue: https://docs.actronair.com.au/wp-content/uploads/9590-0031-01-Aspire-DS-Series-Catalogue-ver-05.pdf

Full claim/evidence provenance remains in the live Supabase database and should take precedence over this generated snapshot if later evidence changes.
