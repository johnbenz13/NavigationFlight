# Flight Evidence Export and Debrief — Delivery Plan

Status: **approved and published on 2026-11-17**

Slice 1 detector-policy retention expansion approved on 2026-11-19.

Authoritative contracts:

- [Approved product specification](FLIGHT-EVIDENCE-EXPORT-AND-DEBRIEF_SPEC.md)
- [Approved technical design](../technical/FLIGHT-EVIDENCE-EXPORT-AND-DEBRIEF_TECHNICAL.md)
- [Approved Figma file](https://www.figma.com/design/OSPuLyy5Qtde2iajUNeWDL)

Every slice delivers a usable pilot or engineering outcome. Required schema, projection, replay, persistence, UI, and tests land with the first outcome that needs them rather than as separate horizontal tickets. Implementation is not authorized by this plan.

## Slice 1 — Export diagnostic evidence from a closed Flight

**User story:** As a pilot reviewing a completed, incomplete, or manually ended Flight, I can choose Diagnostic Bundle or GPX and deliberately share the resulting file.

**Product result:** Flight Detail exports a validated `.nflightbundle` from a closed readable recording while preserving the separate GPX export.

**Requirements:** FE-001, FE-005–FE-006, FE-009–FE-017, FE-026, FE-047–FE-050.

**End-to-end scope:**

- Add the minimum `FlightEvidenceCore` package, portable v1 values, and deterministic codec required by this export.
- Evolve the recording manifest compatibly so every newly created recording retains the exact versioned detector-policy snapshot used at its start; keep existing schema-v1 recordings readable with unavailable policy context.
- Map recording, plan, closure, events, segmented track, accuracy, supplemental evidence, and the retained detector-policy snapshot into the portable bundle.
- Generate, validate, atomically publish, clean up, cancel, retry, and share diagnostic files.
- Add Flight Detail format choice, progress, failure, retry, and system-share presentation.
- Preserve recording behavior and GPX export.

**Design:** [format choice](https://www.figma.com/design/OSPuLyy5Qtde2iajUNeWDL?node-id=16-15), [progress](https://www.figma.com/design/OSPuLyy5Qtde2iajUNeWDL?node-id=16-269), [failure](https://www.figma.com/design/OSPuLyy5Qtde2iajUNeWDL?node-id=16-392), and [share handoff](https://www.figma.com/design/OSPuLyy5Qtde2iajUNeWDL?node-id=16-515). Reuse native SwiftUI controls, `ShareLink`, and existing Flight Detail navigation.

**Acceptance and verification:**

- Every payload/measurement round-trips; order, gaps, missing values, and plan bytes remain unchanged.
- Unsupported or malformed portable versions fail explicitly.
- Cancellation/failure leaves no publishable partial file and permits retry.
- Export does not mutate the source recording.
- A newly created recording round-trips its immutable detector-policy snapshot through disk persistence, closure, and recovery; a schema-v1 recording exports no detector policy rather than the current policy.
- Swift Testing covers codec/file lifecycle; XCUITest covers choice, cancellation, retry, and share boundary.
- Existing recording/disk/GPX tests pass; app builds and iPad portrait matches the cited frames.

**Exclusions:** Active/recoverable snapshot export, debrief, analyzer, private recordings, and changes to detector thresholds or behavior.

**Blockers:** None.

## Slice 2 — Export a provisional active or recoverable snapshot

**User story:** As a pilot with a Flight still recording or awaiting recovery, I can export a clearly labelled point-in-time snapshot without changing that Flight.

**Product result:** Slice 1 export works for active and recoverable evidence with explicit provisional timing and mutation safety.

**Requirements:** FE-002–FE-003, FE-006–FE-008, FE-013, FE-015–FE-016, FE-043, FE-047.

**End-to-end scope:**

- Extend snapshots with `capturedAt` and closed/active/recoverable state.
- Return a consistent store snapshot after pending actor-isolated writes.
- Add active/recoverable availability and confirmation UI.
- Preserve capture, navigation, recovery freshness, device wake behavior, and later evidence collection.

**Design:** [active snapshot disclosure](https://www.figma.com/design/OSPuLyy5Qtde2iajUNeWDL?node-id=16-144), reusing Slice 1 progress/failure/share states.

**Acceptance and verification:**

- Bundle identifies snapshot time/state and excludes later evidence.
- Export never closes, checkpoints, continues, or navigates the Flight.
- Recording accepts later samples/events after success, failure, or cancellation.
- Actor-isolated tests prove consistency under ingestion; XCUITest verifies disclosure and continued active status.

**Blockers:** Slice 1.

## Slice 3 — Debrief a completed Flight on iPad

**User story:** As a pilot, I can compare actual versus planned flight, inspect telemetry and reached actions at a selected time, and play or scrub historical evidence.

**Product result:** A complete closed Flight has an interactive iPad portrait debrief on the real offline aviation chart.

**Requirements:** FE-027–FE-041, FE-044, FE-051–FE-063.

**End-to-end scope:**

- Add the pure projector, indexed segments, route metrics, altitude observations, and event-position correlation required by the screen.
- Add a main-actor Observation model for loading, selection, and playback.
- Present map, Cockpit-equivalent planned-leg geometry and minute marks, toggleable drift references, paths, telemetry, timeline/events, selected evidence, seeking, playback-rate menu, historical aircraft, Follow Aircraft and Free Look camera states, North-up and Track-up orientations, Recenter, and Fit full flight.
- Provide the canonical compact replay console and full-analysis mode. Both retain current altitude, ground speed, course, playback controls, and selection; analysis expands plots and event cards vertically without changing the horizontal playback-control grammar.
- Cancel loading/projection/playback when leaving.

**Design:** [Direction 07 compact replay console](https://www.figma.com/design/OSPuLyy5Qtde2iajUNeWDL?node-id=73-321) and [Direction 07 full analysis](https://www.figma.com/design/OSPuLyy5Qtde2iajUNeWDL?node-id=73-487) are the canonical completed-Flight Debrief targets. [Direction 06 Revision 02](https://www.figma.com/design/OSPuLyy5Qtde2iajUNeWDL?node-id=57-271) and its approved derivatives remain authoritative for replay-camera branches not redrawn in Direction 07; they inherit Direction 07's toolbar, legend, and replay-console treatment. The earlier [Direction 01 debrief](https://www.figma.com/design/OSPuLyy5Qtde2iajUNeWDL?node-id=2-676) and [Direction 03 event disclosure](https://www.figma.com/design/OSPuLyy5Qtde2iajUNeWDL?node-id=19-628) are historical context only for this slice.

**Acceptance and verification:**

- Time, event, and track selection synchronize all evidence regions.
- Correlation never crosses gaps or replaces recorded event time.
- Paths/gaps remain distinguishable without color alone; metrics are objective and deterministic.
- Playback rate changes advancement only, never evidence.
- Aircraft, camera, track progression, and telemetry remain synchronized with selected evidence time during playback and seeking.
- Manual map inspection, refocusing, orientation changes, gaps, unreliable course, and unavailable-position states follow FE-054–FE-061.
- Compact/full-analysis transitions preserve replay and camera state; current altitude, ground speed, and course remain visible in both modes; Leg/Track/Action legend swatches and Fit full flight placement match the canonical Direction 07 nodes.
- Injected-clock Swift Testing covers projection and transport without sleeps.
- XCUITest covers entry, selection, seeking, playback, rate, exit, and absence of operational commands.
- Simulator comparison cites the renewed approved iPad portrait replay-camera frames.

**Exclusions:** Limited states beyond the no-trustworthy-position replay-camera state, secondary layouts, full-screen accessibility coverage beyond replay-camera controls and equivalent evidence, and analyzer.

**Blockers:** Slice 1.

## Slice 4 — Debrief every retained state across supported layouts

**User story:** As a pilot, I can understand available and missing evidence for incomplete, active, partial-GPS, action-only, unsupported, or unreadable Flights on supported devices and with accessibility features.

**Product result:** Slice 3 honestly covers every approved state, iPad landscape, iPhone portrait, Dynamic Type, VoiceOver, and Reduce Motion.

**Requirements:** FE-003, FE-005, FE-014–FE-016, FE-029–FE-031, FE-034, FE-041–FE-050.

**End-to-end scope:**

- Extend projection/presentation for incomplete/manual, active/recoverable, partial GPS, action-only, unsupported, and unreadable evidence.
- Preserve available actions when track evidence is limited.
- Adapt by available width; add textual map equivalents, semantic reading order/traits, accessibility-size layout, and Reduce Motion behavior.
- Preserve deletion boundaries and successful-closure device idling.

**Design:** Direction 08 is the approved Slice 4 authority: [index](https://www.figma.com/design/OSPuLyy5Qtde2iajUNeWDL?node-id=95-11), [incomplete](https://www.figma.com/design/OSPuLyy5Qtde2iajUNeWDL?node-id=95-24), [active](https://www.figma.com/design/OSPuLyy5Qtde2iajUNeWDL?node-id=95-148), [recoverable](https://www.figma.com/design/OSPuLyy5Qtde2iajUNeWDL?node-id=95-272), [partial GPS](https://www.figma.com/design/OSPuLyy5Qtde2iajUNeWDL?node-id=95-396), [action-only/no GPS](https://www.figma.com/design/OSPuLyy5Qtde2iajUNeWDL?node-id=95-522), [unsupported](https://www.figma.com/design/OSPuLyy5Qtde2iajUNeWDL?node-id=95-648), [unreadable](https://www.figma.com/design/OSPuLyy5Qtde2iajUNeWDL?node-id=95-776), [shared full analysis](https://www.figma.com/design/OSPuLyy5Qtde2iajUNeWDL?node-id=95-904), [iPad landscape](https://www.figma.com/design/OSPuLyy5Qtde2iajUNeWDL?node-id=95-1088), [iPhone collapsed](https://www.figma.com/design/OSPuLyy5Qtde2iajUNeWDL?node-id=95-1288), [iPhone expanded](https://www.figma.com/design/OSPuLyy5Qtde2iajUNeWDL?node-id=99-55), and [accessibility contract](https://www.figma.com/design/OSPuLyy5Qtde2iajUNeWDL?node-id=95-1346). Direction 03 `19:*` and Direction 04 `24:*` nodes are historical behavioral context only and are not implementation authority for this slice.

**Acceptance and verification:**

- Named synthetic fixtures reproduce every state and preserve all available evidence.
- No gap gains invented geometry and no unsupported evidence claims completeness.
- Layout responds to available width without global device/orientation assumptions.
- Text grows and scrolls; VoiceOver follows the approved order and map graphics become decorative after their textual equivalent.
- Simulator evidence covers iPad portrait/landscape and iPhone portrait; manual evidence covers VoiceOver, Dynamic Type, contrast, and Reduce Motion.

**Blockers:** Slice 3. Slice 2 is not a blocker because active debrief can use a synthetic snapshot fixture.

## Slice 5 — Explain one Flight's detector decisions locally

**User story:** As an engineer, I can load one diagnostic bundle locally and see why takeoff, landing, and sustained-stop candidates began, continued, reset, corrected, or completed.

**Product result:** A macOS command-line analyzer emits a self-contained offline HTML report for one Flight with synchronized evidence and explainable replay.

**Requirements:** FE-001, FE-004, FE-018, FE-020–FE-024, FE-026, FE-047.

**End-to-end scope:**

- Extract one pure evaluator shared by production detection and replay without changing production policy behavior.
- Consume the retained versioned policy snapshot and define per-sample explanations; report replay as unavailable when the required historical policy context is absent.
- Add one-bundle CLI validation and self-contained HTML generation.
- Distinguish recorded history from replay and disclose missing-context assumptions.

**Design:** Single-flight subset of [the analyzer](https://www.figma.com/design/OSPuLyy5Qtde2iajUNeWDL?node-id=26-14); comparison controls remain hidden for one bundle.

**Acceptance and verification:**

- Production and replay emit identical transitions for identical input/retained policy.
- Explanations include measurements/accuracy, thresholds, timing, resets, ground reference, and emitted transition.
- Same bundle/policy produces deterministic replay/report output.
- Report works offline, escapes evidence text, distinguishes recorded/replayed results, and names invalid input.
- Swift Testing covers takeoff, landing, stop, correction, partial launch, jitter, gaps, and elevation; both app and analyzer build.

**Exclusions:** Multi-flight comparison, private diagnosis, and production policy changes.

**Blockers:** Slice 1.

## Slice 6 — Compare Flights and produce a detector recommendation

**User story:** As an engineer and product owner, we can compare the failed outbound Flight, successful return Flight, alternative policies, and adverse scenarios locally to decide whether a detector change is justified.

**Product result:** The analyzer supports one or many bundles, comparative replay, an adverse-scenario gate, and a private evidence-backed recommendation using the owner's two Flights.

**Requirements:** FE-018–FE-026, FE-047.

**End-to-end scope:**

- Extend Slice 5 to many inputs and validated alternative-policy JSON.
- Synchronize map, telemetry, events, and replay explanations across selected Flights.
- Add deterministic comparison and adverse-scenario matrix.
- Analyze the owner's two local bundles plus privacy-safe synthetic taxi-stop, stationary-noise, GPS-gap, elevation, and recovery cases.
- Review conclusions without committing or attaching private evidence.

**Design:** [comparative analyzer](https://www.figma.com/design/OSPuLyy5Qtde2iajUNeWDL?node-id=26-14) and [evidence gate](https://www.figma.com/design/OSPuLyy5Qtde2iajUNeWDL?node-id=26-108).

**Acceptance and verification:**

- One and many inputs produce deterministic offline reports without a two-flight limit.
- Recorded/current/alternative results remain distinct; invalid inputs are never silently omitted.
- Report explains both private Flights and every replay assumption.
- Recommendation cites failed, successful, and adverse scenarios.
- Any policy change becomes a new approved decision and ticket; this slice changes no production thresholds.
- Private evidence stays outside Git/issues unless separately sanitized and authorized.

**Blockers:** Slice 5. Label `ready-for-human` because completion requires private recordings and owner judgment.

## Blocking graph

```text
Slice 1 · Closed-flight export
├── Slice 2 · Active/recoverable export
├── Slice 3 · Completed iPad debrief
│   └── Slice 4 · All states, devices, accessibility
└── Slice 5 · Single-flight detector explanation
    └── Slice 6 · Comparative diagnosis and recommendation
```

## Requirement coverage

| Requirements | Primary slice | Supporting slices | Approved design |
| --- | --- | --- | --- |
| FE-001 | 1 | 3, 5 | Nonvisual invariant plus Directions 01/05 |
| FE-002–FE-005 | 2 | 1, 4, 5 | Directions 02–03 |
| FE-006–FE-017 | 1 | 2 | Direction 02 |
| FE-018–FE-026 | 5 | 6 | Direction 05 |
| FE-027–FE-031 | 3 | 4 | Direction 07, extended by Direction 08 |
| FE-032–FE-040 | 3 | 4 | Directions 07–08 |
| FE-041–FE-046 | 4 | 3 | Direction 08 |
| FE-047–FE-050 | 1 | 2, 4, 5, 6 | Directions 02–05 as applicable |
| FE-051–FE-053 | 3 | 4 | Directions 07–08 |

## Published issues

| Slice | GitHub issue | Readiness | Blocker |
| --- | --- | --- | --- |
| 1 | [#175 — Export diagnostic evidence from a closed Flight](https://github.com/johnbenz13/NavigationFlight/issues/175) | `ready-for-agent` | None |
| 2 | [#176 — Export a provisional active or recoverable snapshot](https://github.com/johnbenz13/NavigationFlight/issues/176) | `ready-for-agent` | #175 |
| 3 | [#177 — Debrief a completed Flight on iPad](https://github.com/johnbenz13/NavigationFlight/issues/177) | `ready-for-agent` | #175 |
| 4 | [#178 — Debrief every retained state across supported layouts](https://github.com/johnbenz13/NavigationFlight/issues/178) | `ready-for-agent` | #177 |
| 5 | [#179 — Explain one Flight's detector decisions locally](https://github.com/johnbenz13/NavigationFlight/issues/179) | `ready-for-agent` | #175 |
| 6 | [#180 — Compare Flights and produce a detector recommendation](https://github.com/johnbenz13/NavigationFlight/issues/180) | `ready-for-human` | #179 |

GitHub native dependency editing was not used; each blocked issue contains an explicit `Blocked by: #…` reference. Published bodies and labels were read back and verified after creation.
