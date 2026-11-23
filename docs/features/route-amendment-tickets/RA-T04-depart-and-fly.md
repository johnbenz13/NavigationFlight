# RA-T04 · Start the amendment and fly its replacement legs

Approved implementation contract · 2026-11-22. Cockpit reconciliation approved by John · 2026-11-23. Implementation requires separate authorization.

## Outcome

A pilot can leave the current route at the selected departure and time the new legs under the Flight’s existing progression policy.

**Requirements** RA-04, RA-05, RA-08, RA-15, RA-16, RA-18, RA-21, RA-22, RA-24. **Verification groups** T04, T05, T06, T07, T10. [Product spec](../IN-FLIGHT-ROUTE-AMENDMENT_SPEC.md) · [Technical design](../../technical/IN-FLIGHT-ROUTE-AMENDMENT-TECHNICAL-DESIGN.md)

**Blocks on** [RA-T03](RA-T03-schedule-and-recover.md)

**Tracker** GitHub `johnbenz13/NavigationFlight`. The listed prerequisites must be closed before implementation readiness. This planning effort has no parent issue.

## Behavior

- Start Now explicitly asserts departure at the chosen eligible current point. A scheduled departure activates when the pilot uses the normal Reach action for its current destination. At a mid-leg departure this is the shortened endpoint set by RA-T03. A prior identification of the original waypoint cannot identify the shortened endpoint. A partway departure records where the original leg ended and its elapsed time without fabricating original destination arrival.
- The same waypoint report can establish real arrival and activation in one transaction. Start the next leg immediately for automatic progression or show Ready and await Start Leg for manual progression.
- New legs use their confirmed values and optional advisory leg-start cues. Keep target, timing and successor relationships scoped to the stable operational leg identity. Bypassed route and targets are inactive and excluded from advancement.
- Recovery can reopen the amended active or ready leg and its saved values, timer, and checklist. Use the existing separately requested Position Check with current operational geometry.
- Fly each replacement leg in the same Ready, Active and Destination Identified Cockpit as a regular leg. Resolve values and actions from the current operational leg. The grey dashed bypass supplies map context and never supplies an actionable destination. Use the scheduled shared departure as the prior leg’s end and the first replacement leg’s start. Start Now starts timing immediately, including under a Manual progression setting.

## Interface and source context

Inspected NavigationFlight revision `258a42cd060195a24086908fecee9bb44312ff30`. Relevant existing owners and adapters follow. [Flight.swift](../../../NavigationFlight/Domain/Flight/Flight.swift) · [CockpitFeatureView.swift](../../../NavigationFlight/Features/Cockpit/CockpitFeatureView.swift) · [CockpitFeatureState.swift](../../../NavigationFlight/Features/Cockpit/CockpitFeatureState.swift) · [CockpitPresentationAdapter.swift](../../../NavigationFlight/Features/Cockpit/CockpitPresentationAdapter.swift) · [AviationMapPresentation.swift](../../../NavigationFlight/Map/AviationMapPresentation.swift) · [CockpitOperationalCueProjector.swift](../../../NavigationFlight/Features/Cockpit/CockpitOperationalCueProjector.swift) · [FlightRecordingEngine.swift](../../../NavigationFlight/Domain/Recording/FlightRecordingEngine.swift) · [FlightRecordingEvent.swift](../../../NavigationFlight/Domain/Recording/FlightRecordingEvent.swift) · [FlightRecoveryCoordinator.swift](../../../NavigationFlight/Features/Recording/FlightRecoveryCoordinator.swift)

Proposed change. Make departure and amendment progression typed Flight actions using stable leg and boundary IDs. Extend the durable journal/replay seam with resolved departure, timing and checklist facts. Route projections carry target and cue eligibility.

## Visual contract

Compare iPad Pro 11-inch portrait (834 × 1194) first. Compare iPad landscape (1194 × 834) and iPhone 16 Pro portrait (402 × 874) using the [regular iPad landscape](https://www.figma.com/design/BjpTMuX6RmEE7Ifs59Al7M?node-id=26-2) and [regular iPhone portrait](https://www.figma.com/design/BjpTMuX6RmEE7Ifs59Al7M?node-id=26-176). Use the app’s existing native fonts, placement and spacing, 44-point interactive targets, and accessibility behavior. The reference route and values are illustrative.

| State or region | Figma or regular pattern | Visual acceptance |
| --- | --- | --- |
| Review and scheduled departure | [Start Now action](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=6-34) · [current floating editor](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=42-342) · [shortened active](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=14-1236) · [departure identified](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=23-296) | Keep the ordinary timer running. Before activation, the normal Identify and Reach controls refer to the shared departure point on a shortened leg. Show Start now only on eligible current departures. |
| Replacement leg and disclosures | [Ready](https://www.figma.com/design/o6gfoVEgyzJ0UA51d9Vi9M?node-id=2-3) · [Active](https://www.figma.com/design/o6gfoVEgyzJ0UA51d9Vi9M?node-id=2-6) · [Destination Identified](https://www.figma.com/design/o6gfoVEgyzJ0UA51d9Vi9M?node-id=2-9) · [ETA editor pattern](https://www.figma.com/design/yvLXb8bUFBiZHqsag4hq6I?node-id=81-462) · [heading instrument](https://www.figma.com/design/yvLXb8bUFBiZHqsag4hq6I?node-id=87-3) · [start checklist](https://www.figma.com/design/yvLXb8bUFBiZHqsag4hq6I?node-id=41-2) · [regular closed disclosures](https://www.figma.com/design/yvLXb8bUFBiZHqsag4hq6I?node-id=206-984) | Reuse the regular Cockpit route strip, instrument scan line, heading and Next ETA editors, Planned now/next and Frequency Plan, altitude, Position Check, checklist, Previous/Next and destination controls. Ready has Start leg and an untimed display. Active has Identify and Reach. Once identified, Reach is primary and timing continues. |
| Map and recovery | [Ready](https://www.figma.com/design/o6gfoVEgyzJ0UA51d9Vi9M?node-id=2-3) · [Active](https://www.figma.com/design/o6gfoVEgyzJ0UA51d9Vi9M?node-id=2-6) · [Destination Identified](https://www.figma.com/design/o6gfoVEgyzJ0UA51d9Vi9M?node-id=2-9) · [Continue Flight](https://www.figma.com/design/ZrGA7ZuOACWtXA4mR7cwdc?node-id=38-275) · [accessibility](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=15-301) | Solid operational route in the ordinary map styling. The grey dashed bypass stays legible and inactive without adding another console or changing normal report order. Recovery reopens the same regular Ready or Active shell with saved data. |

## Reproduction and acceptance

**Fixture.** Route A variants start now partway, report a scheduled partway point, and report a waypoint departure. A two-leg amendment allows successor checks with both automatic and manual progression. Use disposable synthetic fixtures and controlled clocks in the NavigationFlight scheme.

- Domain tests verify same-timestamp automatic start, ready manual start and later timing, protected old timers, source-leg ID scope, exactly one arrival fact when warranted, and no outcome for bypassed targets.
- Store/replay tests verify one logical transaction, activation retry and reopen. XCUITest exercises Start Now and scheduled start with an iPad portrait capture for active and manual-ready states.
- Keep original aid behavior, manual targets, cue rules and Position Check unchanged along an unamended route.

- Compare Ready, Active and Destination Identified against the approved portraits with the same route fixture. Exercise heading and ETA revisions, the frequency/Position Check/checklist disclosures and both standard destination actions. Confirm autonomous location updates never advance the leg, the dashed bypass cannot be reported, and recovered Ready and Active reuse the same console. Capture the same states in the regular adaptive shells.

Tests and rendered comparisons belong to the separately authorized implementation. Record the exact Figma node, device, scenario, and resulting evidence.

## Scope and documentation

**Exclusions.** The return to the retained segment is #208. Route-transition Undo is #210. Assisted map aids are #211. The new portrait frames supersede the dedicated amendment console. This slice is demonstrable at departure and on intermediate new legs before the feature integration release gate.

**Documentation on delivery.** Update Flight progression and operational map/cue projections to document the new departure and leg identity semantics.

**GitHub issue.** [#207](https://github.com/johnbenz13/NavigationFlight/issues/207).
