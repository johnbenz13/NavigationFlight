# RA-T05 · Rejoin the retained route with rebased timing and cues

Approved implementation contract · 2026-11-22. Cockpit reconciliation approved by John · 2026-11-23. Implementation requires separate authorization.

## Outcome

At rejoin, a pilot can continue on the retained part of the original route with the correct start, timing targets, and planned cues.

**Requirements** RA-02, RA-04, RA-05, RA-08, RA-15, RA-16, RA-18, RA-21, RA-22, RA-24. **Verification groups** T04, T05, T07, T10. [Product spec](../IN-FLIGHT-ROUTE-AMENDMENT_SPEC.md) · [Technical design](../../technical/IN-FLIGHT-ROUTE-AMENDMENT-TECHNICAL-DESIGN.md)

**Blocks on** [RA-T04](RA-T04-depart-and-fly.md)

**Tracker** GitHub `johnbenz13/NavigationFlight`. The listed prerequisites must be closed before implementation readiness. This planning effort has no parent issue.

## Behavior

- Only the pilot’s report establishes rejoin. On a partway rejoin the retained segment starts with six planned minutes in the fixture and its own timer and checklist according to progression policy.
- Use original planned altitude and radio values effective at rejoin. Rebase retained targets and future cues once, without replaying bypassed cue history or recording false target outcomes.
- Bind earlier revisions to their historical leg. Preserve original route behavior at a full waypoint and the final arrival plus explicit Navigation Complete sequence.
- Recover the same retained geometry, target order, timing baseline, and checklist from the saved transaction.
- The final replacement leg’s ordinary Reach reports the shared rejoin point. That occurrence is the last replacement leg’s arrival and the retained leg’s departure. The retained leg uses the same Ready or Active Cockpit, with its own values and cue provenance.

## Interface and source context

Inspected NavigationFlight revision `258a42cd060195a24086908fecee9bb44312ff30`. Relevant existing owners and adapters follow. [Flight.swift](../../../NavigationFlight/Domain/Flight/Flight.swift) · [NavigationTypes.swift](../../../NavigationFlight/Domain/Navigation/NavigationTypes.swift) · [CockpitPresentationAdapter.swift](../../../NavigationFlight/Features/Cockpit/CockpitPresentationAdapter.swift) · [AviationMapPresentation.swift](../../../NavigationFlight/Map/AviationMapPresentation.swift) · [CockpitOperationalCueProjector.swift](../../../NavigationFlight/Features/Cockpit/CockpitOperationalCueProjector.swift) · [FlightRecordingEngine.swift](../../../NavigationFlight/Domain/Recording/FlightRecordingEngine.swift) · [FlightRecordingEvent.swift](../../../NavigationFlight/Domain/Recording/FlightRecordingEvent.swift) · [FlightRecoveryCoordinator.swift](../../../NavigationFlight/Features/Recording/FlightRecoveryCoordinator.swift)

Proposed change. Resolve an operational retained segment using its immutable source interval and selected-mode timing. Give a separately timed remainder a stable ID. Reuse the same command transaction at the rejoin boundary, including ready or automatic start context.

## Visual contract

Compare iPad Pro 11-inch portrait (834 × 1194) first. Compare iPad landscape (1194 × 834) and iPhone 16 Pro portrait (402 × 874) using the [regular iPad landscape](https://www.figma.com/design/BjpTMuX6RmEE7Ifs59Al7M?node-id=26-2) and [regular iPhone portrait](https://www.figma.com/design/BjpTMuX6RmEE7Ifs59Al7M?node-id=26-176). Use the app’s existing native fonts, placement and spacing, 44-point interactive targets, and accessibility behavior. The reference route and values are illustrative.

| State or region | Figma or regular pattern | Visual acceptance |
| --- | --- | --- |
| Report the rejoin | [Destination Identified](https://www.figma.com/design/o6gfoVEgyzJ0UA51d9Vi9M?node-id=2-9) · [rejoin geometry and cues](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=14-664) | Give the last replacement leg the standard destination Reach in the usual action slot. Its end and the retained leg’s start are the same route occurrence. Use the legacy rejoin artwork for the retained geometry and cue example. |
| Retained successor | [Ready](https://www.figma.com/design/o6gfoVEgyzJ0UA51d9Vi9M?node-id=2-3) · [Active](https://www.figma.com/design/o6gfoVEgyzJ0UA51d9Vi9M?node-id=2-6) · [ETA editor pattern](https://www.figma.com/design/yvLXb8bUFBiZHqsag4hq6I?node-id=81-462) · [start checklist](https://www.figma.com/design/yvLXb8bUFBiZHqsag4hq6I?node-id=41-2) | Use the shared Cockpit and the retained endpoint and leg identity. Automatic shows the running timer and started checklist. Manual shows normal Ready and Start leg. The ETA, planned frequencies and altitude reflect the original values effective at the retained segment, with rebased targets. |
| Recovery and final arrival | [Ready](https://www.figma.com/design/o6gfoVEgyzJ0UA51d9Vi9M?node-id=2-3) · [Active](https://www.figma.com/design/o6gfoVEgyzJ0UA51d9Vi9M?node-id=2-6) · [final Navigation Complete](https://www.figma.com/design/yvLXb8bUFBiZHqsag4hq6I?node-id=63-275) | Restore the same normal shell from saved retained state. At a final route waypoint use the existing arrival and Navigation Complete sequence. Undo placement and behavior are delivered by #210. |

## Reproduction and acceptance

**Fixture.** Route A rejoins halfway along a 12-minute original leg, with before/at/after targets and altitude and radio cues. Additional fixtures rejoin at a full waypoint and at final arrival. Use disposable synthetic fixtures and controlled clocks in the NavigationFlight scheme.

- Flight route fixtures assert rebased duration, forward-only target membership, no bypassed outcomes, correct stable IDs, and initial and future cues with no replay.
- Replay tests reopen each rejoin form under both policies. XCUITest reports rejoin and resumes normal flight, with iPad portrait evidence for retained state and reused manual handoff.
- Regression checks preserve existing final completion, VOR/DME source references, timing and advisory cue behavior.

- Use the same normal Reach on the last replacement leg under both policies. Capture the rejoin approach and the Ready or Active successor, verify the shared map boundary, and exercise the retained leg’s normal revision, checklist and cue presentation. Include a final-waypoint path through Navigation Complete.

Tests and rendered comparisons belong to the separately authorized implementation. Record the exact Figma node, device, scenario, and resulting evidence.

## Scope and documentation

**Exclusions.** Cancel/replacement, Undo, and Debrief visuals. Amendment timed identification points remain deferred.

**Documentation on delivery.** Record split-leg interval, timing, and cue semantics in Flight and cue technical references.

**GitHub issue.** [#208](https://github.com/johnbenz13/NavigationFlight/issues/208).
