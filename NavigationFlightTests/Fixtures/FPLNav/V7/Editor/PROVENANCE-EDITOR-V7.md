# Editor-produced V7 handoff fixtures

Synthetic regression/training inputs; never operational flight plans.
Generated 2026-10-11 through the approved production
`project/mapping/project-v7-from-editor.ts` writer and native V7 encoder, using
published @johnbenz13/fplnav-spec@0.2.0. Execution values were not written by hand.
Generation itself passes the shared V7 runtime validator before encoding.
No Playwright tests, typecheck, lint or build were run for this handoff.

Seed: `tests/fixtures/navigation-project-fixture.ts`. Projected coordinates were
set from WGS84 [34.5,32.1] and [34.7,32.3] using OpenLayers EPSG:3857. The actual
catalog supplies station frequency/elevation and aerodrome frequency inventories;
editable source references use the seed's snapshots. Aerodrome IDs were set to
llhz/llmg. Print items were cleared; their presentation is not Flight execution.
A synthetic departure frequency override/reorder exercises final list ownership.

- editor-wind.fplnav: project default wind 270° true FROM / 12 kt; explicit leg
  override 250° / 8 kt takes precedence. Includes both calculation modes.
- editor-no-wind.fplnav: stored wind inputs retained, wind planning disabled;
  only no-wind execution exists.
- editor-calm.fplnav: explicit project default 0 kt, no leg override; wind mode
  remains present and has heading while no-wind heading remains unset.

Each contains one leg, one laterally offset identification point, all three
altitude anchor kinds, one frequency change, an automatic and a manual accepted
VOR/DME reference. Manual slant range remains 12.4 NM and radial 270° FROM.
Initial altitude is distinct from subsequent change targets; all altitudes MSL.
These are Editor regression fixtures, not the official package example. Flight
should additionally stage the package's official V7 representative example.

Calculation version:
editor-execution-1/editor-navigation-1/editor-annotations-1/editor-vor-dme-slant-1.
