# Real flight record fixtures

These fixtures preserve two owner-supplied flight plans with their corresponding
recorded KML executions. They are intended for deterministic QA, debrief
development, map rendering, and future recording-import tests.

The files contain real flight paths and timestamps. Treat them as project test
data, do not publish them independently, and do not infer operational guidance
from them.

## Fixture catalog

### LLHZ–LLIB via Jerusalem

Path: `llhz-llib-via-jerusalem/`

- `flight-plan.fplnav`: FPLNav V7 plan already maintained at
  `NavigationFlightTests/Fixtures/FPLNav/V7/Official/llhz-llib-via-jerusalem-v7.fplnav`.
- `track.kml`: execution recorded on 16 November 2026.
- Track interval: `2026-11-16T11:15:39.08Z` through
  `2026-11-16T13:06:56.00Z` (`6,676.92` seconds).
- Samples: `6,637`.
- Latitude bounds: `31.798367...32.981206`.
- Longitude bounds: `34.733552...35.592421`.
- Altitude bounds: `17.0...1,146.7` metres.

SHA-256:

```text
87eded11437736e5efbe434b56e66e441174df29946be621f72ded8ae1069e89  flight-plan.fplnav
509ba3205c15c65e0308b483b1f20d4f04c58df48a1b38199c6652c62429d0e0  track.kml
```

### LLHZ–LLMZ

Path: `llhz-llmz/`

- `flight-plan.fplnav`: FPLNav V9 plan supplied with the corrected fixture
  mapping.
- `track.kml`: execution recorded on 17 November 2026.
- Track interval: `2026-11-17T10:07:07.60Z` through
  `2026-11-17T11:33:34.01Z` (`5,186.41` seconds).
- Samples: `5,025`.
- Latitude bounds: `31.305109...32.216192`.
- Longitude bounds: `34.734661...35.455269`.
- Altitude bounds: `-395.6...1,436.6` metres. Negative altitude near
  Metzada is expected because the KML uses metres above mean sea level.

SHA-256:

```text
ead46e2525aa93ded955289b801f6bc48eb17926e04fce16799d870e2a6dfdff  flight-plan.fplnav
133af4403fe141c29ad2ec95748d4a231283584e937a9a9b0d8efa42ad0f9a65  track.kml
```

## QA flight-record generation

Debug builds convert either pair into the completed recording with identifier
`03000000-0000-0000-0000-000000000003`. `DebriefQAFlightTrack` selects the
matching deterministic track by decoded plan title:

| Plan title | Recorded execution | Downsampled QA samples | Duration |
| --- | --- | ---: | ---: |
| `LLHZ - LLIB via Jerusalem` | 16 Nov KML | 55 | 1:51:16.92 |
| `LLHZ - LLMZ` | 17 Nov KML | 42 | 1:26:26.41 |

The QA representation retains the first and final points and samples the source
approximately every 125 positions. It preserves coordinates, relative timing,
and GPS altitude. Ground speed and course are derived from adjacent retained
points. The raw KML remains the authority when full-resolution evidence is
needed.

To launch either completed flight manually, set these Run-scheme environment
variables:

```text
NAVIGATION_FLIGHT_UI_TEST_INITIAL_SECTION=flights
NAVIGATION_FLIGHT_UI_TEST_FLIGHTS_STATE=populated
NAVIGATION_FLIGHT_UI_TEST_PLAN=<base64 flight-plan.fplnav>
```

For example, copy the LLHZ–LLMZ plan payload on macOS:

```bash
base64 -i fixtures/FlightRecords/llhz-llmz/flight-plan.fplnav | tr -d '\n' | pbcopy
```

Paste that value into `NAVIGATION_FLIGHT_UI_TEST_PLAN`, launch the app, open the
completed row, and choose **Open Debrief**. The fixture uses in-memory recording
storage and does not modify the simulator's normal flight library.

## Provenance and transformation rules

- Both plan/track mappings were explicitly confirmed by the fixture owner on
  19 November 2026.
- Source files are preserved byte-for-byte; use the checksums above to detect
  accidental modification.
- The app does not parse KML at runtime. The debug-only Swift fixture contains
  a deterministic downsample so UI automation stays fast and independent of
  external files.
- These fixtures contain GPS altitude only. Derived QA speed/course values are
  not claims about the original recorder's sensor measurements.
