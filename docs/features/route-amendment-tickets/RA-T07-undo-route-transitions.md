# RA-T07 · Undo a departure or rejoin with the previous timer and route intact

Approved implementation contract · 2026-11-22. Implementation requires separate authorization.

## Outcome

A pilot can reverse a recent route boundary report within the existing Undo window.

**Requirements** RA-08, RA-13, RA-17, RA-18, RA-21, RA-22. **Verification groups** T06, T07, T08, T10. [Product spec](../IN-FLIGHT-ROUTE-AMENDMENT_SPEC.md) · [Technical design](../../technical/IN-FLIGHT-ROUTE-AMENDMENT-TECHNICAL-DESIGN.md)

**Blocks on** [RA-T05](RA-T05-rejoin-and-rebase.md)

**Tracker** GitHub `johnbenz13/NavigationFlight`. The listed prerequisites must be closed before implementation readiness. This planning effort has no parent issue.

## Behavior

- Undo scheduled departure restores the pending amendment and its shortened active leg with the same target and timer, Undo Start Now restores the previous operational route and reopens the saved inputs in review, and Undo rejoin restores the prior leg and its continuous timer.
- A later flight-state action or the established expiration ends the offer. Panning, inspecting or reading references uses the existing passive interaction policy.
- The original event remains visible and the linked Undo records the reversal. A failure to persist leaves the last committed route and eligibility intact under the existing error model.

## Interface and source context

Inspected NavigationFlight revision `258a42cd060195a24086908fecee9bb44312ff30`. Relevant existing owners and adapters follow. [Flight.swift](../../../NavigationFlight/Domain/Flight/Flight.swift) · [CockpitFeatureState.swift](../../../NavigationFlight/Features/Cockpit/CockpitFeatureState.swift) · [CockpitFeatureView.swift](../../../NavigationFlight/Features/Cockpit/CockpitFeatureView.swift) · [FlightRecordingEngine.swift](../../../NavigationFlight/Domain/Recording/FlightRecordingEngine.swift) · [FlightRecordingEvent.swift](../../../NavigationFlight/Domain/Recording/FlightRecordingEvent.swift) · [FlightRecordingCoordinator.swift](../../../NavigationFlight/Features/Recording/FlightRecordingCoordinator.swift) · [FlightRecoveryCoordinator.swift](../../../NavigationFlight/Features/Recording/FlightRecoveryCoordinator.swift)

Proposed change. Extend the existing reach Undo mechanism with a route action token and prior Flight, timer, context and map restoration. Journal a compensating event linked to the actual committed transition. Replay restores effects without recreating the transient undo offer.

## Visual contract

The canonical comparison is iPad Pro 11-inch portrait (834 × 1194). Where this slice touches adaptive UI, use the approved 1194 × 834 iPad landscape and 402 × 874 iPhone 16 Pro portrait references. The Figma route and values are illustrative. Reuse the existing UIKit/SwiftUI integration and app typography, spacing, tap-target and localization patterns specified by the design.

| Region and state | Design target | Reuse and acceptance |
| --- | --- | --- |
| Undo and restoration | [Active Undo](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=14-484) · [Rejoin Undo](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=14-664) · [Restored pending](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=14-1236) · [Start Now return to review](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=6-34) | Reuse the normal Undo notice position, expiration and map-restoration behavior. Preserve the cockpit timer, checklist and camera during rollback. |

## Reproduction and acceptance

**Fixture.** Route A with separate scheduled departure, Start Now, and partway-rejoin setups. Use injected wall and monotonic clocks at 19 and 20 seconds, later flight-state mutation, and a recovered package. Use disposable synthetic fixtures and controlled clocks in the NavigationFlight scheme.

- Inject time and storage outcomes and assert availability, exact expiry, next action invalidation, and all three restored states without sleeps.
- Assert the stable original event ID and Undo reference in disk replay. Restore route and timer after reopening without a transient offer.
- XCUITest captures the notice and the three resulting states on iPad portrait. Include evidence of continuous time and prior map context, not only identical layout.

Tests and rendered comparisons belong to the separately authorized implementation. Record the exact Figma node, device, scenario, and resulting evidence.

## Scope and documentation

**Exclusions.** An unlimited route history editor or undo after the established window.

**Documentation on delivery.** Update the Flight Undo and recovery contracts with amendment transitions and restoration rules.

**GitHub issue.** [#210](https://github.com/johnbenz13/NavigationFlight/issues/210).
