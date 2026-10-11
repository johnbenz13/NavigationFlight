# FPLNav V7 integration

Status: `@johnbenz13/fplnav-spec@0.2.0` is published and Navigation Flight reads
V5 and V7. The pinned registry artifact has gitHead
`c6c904aedad0cf72192b4e0b02e6edce52fd2e70`. The package's generic decoder and
current-version facade intentionally remain V6; development tooling imports the
explicit `schema/navigation-project-v7` validator.

## Runtime boundary

`FPLNavDecoder` reads metadata first. V5 continues through its frozen DTO/mapper
and is explicitly unavailable for execution. V6 and unknown versions are rejected.
V7 maps source navigation plus the saved execution snapshot into immutable,
`Equatable`/`Sendable` domain values. An empty V7 is represented separately from
a nonempty execution-eligible V7.

Flight consumes saved course, distance, initial MSL altitude, no-wind timing,
optional complete wind solutions, resolved annotation positions and timings,
final ordered frequencies, and accepted VOR/DME results. It does not recalculate
geometry, wind triangles, marker placement, catalog frequencies, radials, or
slant ranges. No-wind mode has no heading. Wind mode is the default only when the
snapshot contains it. Pilot heading corrections remain future session state.

The Swift boundary enforces the consumed V7 structure and semantic relationships:
strict execution objects; finite/ranged source and execution values; exact leg
order and one-to-one source records; wind-mode and effective-wind consistency;
bounded integer timings; MSL; automatic elevation; unchanged manual radial/range;
and required route/user frequency entries with phase-local unique identities.
Errors identify a field path and reason. This is intentionally described as
consumed-boundary validation, not a complete Swift implementation of JSON Schema.
The published runtime validator remains authoritative in development tooling.

## Development tooling and fixtures

`npm run contract:refresh` verifies the published gitHead, performs `npm ci`,
refreshes byte-identical official V5 and V7 examples, and runs verification.
`npm run contract:verify` compares official fixture bytes and validates the
official V7 plus all three Editor-produced handoff vectors with the published V7
runtime validator. Official and Editor provenance are kept separately. Xcode's
synchronized resources flatten names, so the official V7 resource is staged as
`representative-v7.fplnav` without changing its bytes.

Node dependencies, scripts, schemas, and all synthetic fixtures are development
or unit-test inputs only; none are members of the application target. The fixtures
are regression/training data and never operational flight plans.

## Delivery boundary

This delivery does not change Cockpit presentation and does not add import UI,
mode-switch UI, timers, GPS, reminders, or safety assistance. The next delivery
is Cockpit wiring to these domain execution values; whole-plan mode switching and
session behavior remain later work.
