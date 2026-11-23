# RA-T07 · Undo a departure or rejoin with the previous timer and route intact

Approved implementation contract · 2026-11-22. Cockpit reconciliation approved by John · 2026-11-23. Implementation requires separate authorization.

## Outcome

A pilot can reverse a recent route boundary report within the existing Undo window.

**Requirements** RA-08, RA-13, RA-17, RA-18, RA-21, RA-22, RA-24. **Verification groups** T06, T07, T08, T10. [Product spec](../IN-FLIGHT-ROUTE-AMENDMENT_SPEC.md) · [Technical design](../../technical/IN-FLIGHT-ROUTE-AMENDMENT-TECHNICAL-DESIGN.md)

**Blocks on** [RA-T05](RA-T05-rejoin-and-rebase.md)

**Tracker** GitHub `johnbenz13/NavigationFlight`. The listed prerequisites must be closed before implementation readiness. This planning effort has no parent issue.

## Behavior

- Undo scheduled departure restores the pending amendment and its shortened active leg with the same target and timer, Undo Start Now restores the previous operational route and reopens the saved inputs in review, and Undo rejoin restores the prior leg and its continuous timer.
- A later flight-state action or the established expiration ends the offer. Panning, inspecting or reading references uses the existing passive interaction policy.
- The original event remains visible and the linked Undo records the reversal. A failure to persist leaves the last committed route and eligibility intact under the existing error model.
- Route-transition Undo uses the normal reach notice over the current regular Cockpit. On Undo, restore the prior operational shell, including the visible target state and continuously running timer wherever appropriate.

## Interface and source context

Inspected NavigationFlight revision `258a42cd060195a24086908fecee9bb44312ff30`. Relevant existing owners and adapters follow. [Flight.swift](../../../NavigationFlight/Domain/Flight/Flight.swift) · [CockpitFeatureState.swift](../../../NavigationFlight/Features/Cockpit/CockpitFeatureState.swift) · [CockpitFeatureView.swift](../../../NavigationFlight/Features/Cockpit/CockpitFeatureView.swift) · [FlightRecordingEngine.swift](../../../NavigationFlight/Domain/Recording/FlightRecordingEngine.swift) · [FlightRecordingEvent.swift](../../../NavigationFlight/Domain/Recording/FlightRecordingEvent.swift) · [FlightRecordingCoordinator.swift](../../../NavigationFlight/Features/Recording/FlightRecordingCoordinator.swift) · [FlightRecoveryCoordinator.swift](../../../NavigationFlight/Features/Recording/FlightRecoveryCoordinator.swift)

Proposed change. Extend the existing reach Undo mechanism with a route action token and prior Flight, timer, context and map restoration. Journal a compensating event linked to the actual committed transition. Replay restores effects without recreating the transient undo offer.

## Visual contract

Compare iPad Pro 11-inch portrait (834 × 1194) first. Compare iPad landscape (1194 × 834) and iPhone 16 Pro portrait (402 × 874) using the [regular iPad landscape](https://www.figma.com/design/BjpTMuX6RmEE7Ifs59Al7M?node-id=26-2) and [regular iPhone portrait](https://www.figma.com/design/BjpTMuX6RmEE7Ifs59Al7M?node-id=26-176). Use the app’s existing native fonts, placement and spacing, 44-point interactive targets, and accessibility behavior. The reference route and values are illustrative.

| State or region | Figma or regular pattern | Visual acceptance |
| --- | --- | --- |
| Notice while the successor is Ready or Active | [Ready](https://www.figma.com/design/o6gfoVEgyzJ0UA51d9Vi9M?node-id=2-3) · [Active](https://www.figma.com/design/o6gfoVEgyzJ0UA51d9Vi9M?node-id=2-6) · [Destination Identified](https://www.figma.com/design/o6gfoVEgyzJ0UA51d9Vi9M?node-id=2-9) · [ordinary reach Undo](https://www.figma.com/design/yvLXb8bUFBiZHqsag4hq6I?node-id=63-90) · [ordinary disclosures](https://www.figma.com/design/yvLXb8bUFBiZHqsag4hq6I?node-id=206-984) | Place the bounded Undo notice in the normal reach-notice region. Keep the instruments, destination controls and independent Checklist, Previous Leg and Next Leg disclosures usable. The historical [departure](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=14-484) and [rejoin](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=14-664) notices supply transition copy and context. |
| After Undo | [restored pending](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=14-1236) · [Start Now action](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=6-34) · [current floating editor](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=42-342) · [Destination Identified](https://www.figma.com/design/o6gfoVEgyzJ0UA51d9Vi9M?node-id=2-9) | Scheduled departure restores the shortened leg and pending pencil. Start Now returns to the accepted input review over the restored route. Undo rejoin restores the replacement leg’s ordinary layout, pre-report target state, continuous elapsed timer and map focus. |
| Expiry, failure and reopen | [ordinary reach Undo](https://www.figma.com/design/yvLXb8bUFBiZHqsag4hq6I?node-id=63-90) · [retry pattern](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=14-751) · [Active](https://www.figma.com/design/o6gfoVEgyzJ0UA51d9Vi9M?node-id=2-6) | Use the ordinary offer countdown and dismissal. Failed persistence preserves the last committed instruments and available action under the existing error model. Reconstructed flights use the restored regular Cockpit with no expired transient offer. |

## Reproduction and acceptance

**Fixture.** Route A with separate scheduled departure, Start Now, and partway-rejoin setups. Use injected wall and monotonic clocks at 19 and 20 seconds, later flight-state mutation, and a recovered package. Use disposable synthetic fixtures and controlled clocks in the NavigationFlight scheme.

- Inject time and storage outcomes and assert availability, exact expiry, next action invalidation, and all three restored states without sleeps.
- Assert the stable original event ID and Undo reference in disk replay. Restore route and timer after reopening without a transient offer.
- XCUITest captures the notice and the three resulting states on iPad portrait. Include evidence of continuous time and prior map context, not only identical layout.

- Capture the standard Undo notice and restored Cockpit for scheduled departure, Start Now and rejoin. Show normal disclosure placement, the correct map role and target identity, and original timer continuity at the restored leg.

Tests and rendered comparisons belong to the separately authorized implementation. Record the exact Figma node, device, scenario, and resulting evidence.

## Scope and documentation

**Exclusions.** An unlimited route history editor or undo after the established window.

**Documentation on delivery.** Update the Flight Undo and recovery contracts with amendment transitions and restoration rules.

**GitHub issue.** [#210](https://github.com/johnbenz13/NavigationFlight/issues/210).
