# Stage 3 — Controls, Zoning and Home Assistant

## Goal

Determine what each serious contender can actually do with native controls, manufacturer options, third-party zoning and Home Assistant, including what is lost when control paths are changed.

## Research targets

For each serious contender, establish:

- included factory controller and meaningful optional manufacturer controllers;
- temperature sensing options and sensor placement;
- number/type of zones and whether zoning is temperature-aware;
- proportional damper capability versus simple open/closed zoning;
- minimum-airflow enforcement, spill-zone/bypass behaviour and interactions with small-zone operation;
- third-party controller compatibility, especially iZone, Advantage Air/MyAir/zone10e and AirTouch where applicable;
- whether native and third-party controls can coexist;
- retained/lost functions with each third-party gateway/controller;
- Home Assistant control path: local network, wired bus, serial/Modbus, bridge/gateway, or cloud;
- controllable features: mode, setpoint, fan, zones, zone setpoints, temperatures, schedules and status feedback;
- local versus cloud dependency and integration maturity/stability.

## Feature-retention matrix

For important third-party integrations, record a compact matrix rather than only saying “compatible”. Distinguish at minimum:

- unit on/off;
- mode;
- central setpoint;
- fan speed/auto;
- zone open/close;
- proportional zone control;
- per-zone temperature/setpoint;
- native fault/status visibility;
- schedules/timers;
- special manufacturer modes/features;
- Home Assistant exposure;
- local versus cloud operation.

Unknown means unknown; do not infer retained features from generic compatibility claims.

## Evidence hierarchy

Prefer manufacturer controller manuals, official compatibility lists and third-party vendor technical documentation for concrete capabilities. Home Assistant documentation/source code and well-supported community reports can establish integration behaviour/maturity, but distinguish documented capability from anecdotal reliability.

## Research strategy

Research controller paths by platform where they genuinely share hardware/protocol, but map conclusions back to exact compatible systems. Avoid repeatedly researching the same controller platform for every system when compatibility is already evidenced.

## Stopping rule

This stage is ready when the serious contender set has sufficiently resolved control/zoning/HA paths to compare real small-zone/night operation and automation, and remaining unknowns are either low-materiality or explicitly blocked after reasonable attempts.