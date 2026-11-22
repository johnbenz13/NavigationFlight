# RA-T04 · Start the amendment and fly its replacement legs

Approved implementation contract · 2026-11-22. Implementation requires separate authorization.

## Outcome

A pilot can leave the current route at the selected departure and time the new legs under the Flight’s existing progression policy.

**Requirements** RA-04, RA-05, RA-08, RA-15, RA-16, RA-18, RA-21, RA-22. **Verification groups** T04, T05, T06, T07, T10. [Product spec](../IN-FLIGHT-ROUTE-AMENDMENT_SPEC.md) · [Technical design](../../technical/IN-FLIGHT-ROUTE-AMENDMENT-TECHNICAL-DESIGN.md)

**Blocks on** [RA-T03](RA-T03-schedule-and-recover.md)

**Tracker** GitHub `johnbenz13/NavigationFlight`. The listed prerequisites must be closed before implementation readiness. This planning effort has no parent issue.

## Behavior

- Start Now explicitly asserts departure at the chosen eligible current point. A scheduled departure activates when the pilot uses the normal Reach action for its current destination. At a mid-leg departure this is the shortened endpoint set by RA-T03. A prior identification of the original waypoint cannot identify the shortened endpoint. A partway departure records where the original leg ended and its elapsed time without fabricating original destination arrival.
- The same waypoint report can establish real arrival and activation in one transaction. Start the next leg immediately for automatic progression or show Ready and await Start Leg for manual progression.
- New legs use their confirmed values and optional advisory leg-start cues. Present the normal active-leg controls and observe identity, not index. Bypassed route and targets are inactive and excluded from advancement.
- Recovery can reopen the amended active or ready leg and its saved values, timer, and checklist. Use the existing separately requested Position Check with current operational geometry.

## Interface and source context

Inspected NavigationFlight revision `258a42cd060195a24086908fecee9bb44312ff30`. Relevant existing owners and adapters follow. [Flight.swift](../../../NavigationFlight/Domain/Flight/Flight.swift) · [CockpitFeatureView.swift](../../../NavigationFlight/Features/Cockpit/CockpitFeatureView.swift) · [CockpitFeatureState.swift](../../../NavigationFlight/Features/Cockpit/CockpitFeatureState.swift) · [CockpitPresentationAdapter.swift](../../../NavigationFlight/Features/Cockpit/CockpitPresentationAdapter.swift) · [AviationMapPresentation.swift](../../../NavigationFlight/Map/AviationMapPresentation.swift) · [CockpitOperationalCueProjector.swift](../../../NavigationFlight/Features/Cockpit/CockpitOperationalCueProjector.swift) · [FlightRecordingEngine.swift](../../../NavigationFlight/Domain/Recording/FlightRecordingEngine.swift) · [FlightRecordingEvent.swift](../../../NavigationFlight/Domain/Recording/FlightRecordingEvent.swift) · [FlightRecoveryCoordinator.swift](../../../NavigationFlight/Features/Recording/FlightRecoveryCoordinator.swift)

Proposed change. Make departure and amendment progression typed Flight actions using stable leg and boundary IDs. Extend the durable journal/replay seam with resolved departure, timing and checklist facts. Route projections carry target and cue eligibility.

## Visual contract

The canonical comparison is iPad Pro 11-inch portrait (834 × 1194). Where this slice touches adaptive UI, use the approved 1194 × 834 iPad landscape and 402 × 874 iPhone 16 Pro portrait references. The Figma route and values are illustrative. Reuse the existing UIKit/SwiftUI integration and app typography, spacing, tap-target and localization patterns specified by the design.

| Region and state | Design target | Reuse and acceptance |
| --- | --- | --- |
| Departure and active leg | [Shortened active leg](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=14-1236) · [Departure point identified](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=23-296) · [Start Now review](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=6-34) · [Active amendment leg](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=14-484) · [Manual handoff](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=14-579) | Reuse progress notices, cockpit timer, target reports, and [leg-start checklist](https://www.figma.com/design/yvLXb8bUFBiZHqsag4hq6I?node-id=41-2). The Undo affordance in the active frame is implemented by RA-T07. |
| Active route readout | [Active amendment leg](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=14-484) · [Map access](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=15-301) | Distinguish active and bypassed segments with pattern and color. Use stable labels and keep the first-leg start/checklist placement consistent across the approved shells. |

## Reproduction and acceptance

**Fixture.** Route A variants start now partway, report a scheduled partway point, and report a waypoint departure. A two-leg amendment allows successor checks with both automatic and manual progression. Use disposable synthetic fixtures and controlled clocks in the NavigationFlight scheme.

- Domain tests verify same-timestamp automatic start, ready manual start and later timing, protected old timers, source-leg ID scope, exactly one arrival fact when warranted, and no outcome for bypassed targets.
- Store/replay tests verify one logical transaction, activation retry and reopen. XCUITest exercises Start Now and scheduled start with an iPad portrait capture for active and manual-ready states.
- Keep original aid behavior, manual targets, cue rules and Position Check unchanged along an unamended route.

Tests and rendered comparisons belong to the separately authorized implementation. Record the exact Figma node, device, scenario, and resulting evidence.

## Scope and documentation

**Exclusions.** The return to the retained segment is RA-T05. Route-transition Undo is RA-T07. This slice is demonstrable at departure and on intermediate new legs before the feature integration release gate.

**Documentation on delivery.** Update Flight progression and operational map/cue projections to document the new departure and leg identity semantics.

**Publication status.** Approved for GitHub publication.
