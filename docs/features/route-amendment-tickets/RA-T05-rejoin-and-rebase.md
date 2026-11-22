# RA-T05 · Rejoin the retained route with rebased timing and cues

Approved implementation contract · 2026-11-22. Implementation requires separate authorization.

## Outcome

At rejoin, a pilot can continue on the retained part of the original route with the correct start, timing targets, and planned cues.

**Requirements** RA-02, RA-04, RA-05, RA-08, RA-15, RA-16, RA-18, RA-21, RA-22. **Verification groups** T04, T05, T07, T10. [Product spec](../IN-FLIGHT-ROUTE-AMENDMENT_SPEC.md) · [Technical design](../../technical/IN-FLIGHT-ROUTE-AMENDMENT-TECHNICAL-DESIGN.md)

**Blocks on** [RA-T04](RA-T04-depart-and-fly.md)

**Tracker** GitHub `johnbenz13/NavigationFlight`. The listed prerequisites must be closed before implementation readiness. This planning effort has no parent issue.

## Behavior

- Only the pilot’s report establishes rejoin. On a partway rejoin the retained segment starts with six planned minutes in the fixture and its own timer and checklist according to progression policy.
- Use original planned altitude and radio values effective at rejoin. Rebase retained targets and future cues once, without replaying bypassed cue history or recording false target outcomes.
- Bind earlier revisions to their historical leg. Preserve original route behavior at a full waypoint and the final arrival plus explicit Navigation Complete sequence.
- Recover the same retained geometry, target order, timing baseline, and checklist from the saved transaction.

## Interface and source context

Inspected NavigationFlight revision `258a42cd060195a24086908fecee9bb44312ff30`. Relevant existing owners and adapters follow. [Flight.swift](../../../NavigationFlight/Domain/Flight/Flight.swift) · [NavigationTypes.swift](../../../NavigationFlight/Domain/Navigation/NavigationTypes.swift) · [CockpitPresentationAdapter.swift](../../../NavigationFlight/Features/Cockpit/CockpitPresentationAdapter.swift) · [AviationMapPresentation.swift](../../../NavigationFlight/Map/AviationMapPresentation.swift) · [CockpitOperationalCueProjector.swift](../../../NavigationFlight/Features/Cockpit/CockpitOperationalCueProjector.swift) · [FlightRecordingEngine.swift](../../../NavigationFlight/Domain/Recording/FlightRecordingEngine.swift) · [FlightRecordingEvent.swift](../../../NavigationFlight/Domain/Recording/FlightRecordingEvent.swift) · [FlightRecoveryCoordinator.swift](../../../NavigationFlight/Features/Recording/FlightRecoveryCoordinator.swift)

Proposed change. Resolve an operational retained segment using its immutable source interval and selected-mode timing. Give a separately timed remainder a stable ID. Reuse the same command transaction at the rejoin boundary, including ready or automatic start context.

## Visual contract

The canonical comparison is iPad Pro 11-inch portrait (834 × 1194). Where this slice touches adaptive UI, use the approved 1194 × 834 iPad landscape and 402 × 874 iPhone 16 Pro portrait references. The Figma route and values are illustrative. Reuse the existing UIKit/SwiftUI integration and app typography, spacing, tap-target and localization patterns specified by the design.

| Region and state | Design target | Reuse and acceptance |
| --- | --- | --- |
| Rejoin, cues, and completion | [Retained segment with new timer](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=14-664) · [Manual ready treatment](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=14-579) | Reuse [original target and revision interactions](https://www.figma.com/design/yvLXb8bUFBiZHqsag4hq6I?node-id=201-921) and existing final-arrival flow. Undo shown in the rejoin frame is RA-T07. |
| Retained guidance and evidence | [Device/access treatment](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=15-301) | Use the retained route identity, ETA and checklist controls in the normal Cockpit shell rather than the draft-edit console. |

## Reproduction and acceptance

**Fixture.** Route A rejoins halfway along a 12-minute original leg, with before/at/after targets and altitude and radio cues. Additional fixtures rejoin at a full waypoint and at final arrival. Use disposable synthetic fixtures and controlled clocks in the NavigationFlight scheme.

- Flight route fixtures assert rebased duration, forward-only target membership, no bypassed outcomes, correct stable IDs, and initial and future cues with no replay.
- Replay tests reopen each rejoin form under both policies. XCUITest reports rejoin and resumes normal flight, with iPad portrait evidence for retained state and reused manual handoff.
- Regression checks preserve existing final completion, VOR/DME source references, timing and advisory cue behavior.

Tests and rendered comparisons belong to the separately authorized implementation. Record the exact Figma node, device, scenario, and resulting evidence.

## Scope and documentation

**Exclusions.** Cancel/replacement, Undo, and Debrief visuals. Amendment timed identification points remain deferred.

**Documentation on delivery.** Record split-leg interval, timing, and cue semantics in Flight and cue technical references.

**Publication status.** Approved for GitHub publication.
