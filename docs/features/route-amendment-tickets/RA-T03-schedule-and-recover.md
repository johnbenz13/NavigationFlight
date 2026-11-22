# RA-T03 · Confirm a future amendment and restore it with the Flight

Approved implementation contract · 2026-11-22. Implementation requires separate authorization.

## Outcome

A pilot can save a future departure, keep using normal Cockpit, and recover the same pending amendment after interruption.

**Requirements** RA-05, RA-08, RA-12, RA-13, RA-18, RA-22. **Verification groups** T04, T06, T07, T10. [Product spec](../IN-FLIGHT-ROUTE-AMENDMENT_SPEC.md) · [Technical design](../../technical/IN-FLIGHT-ROUTE-AMENDMENT-TECHNICAL-DESIGN.md)

**Blocks on** [RA-T02](RA-T02-manual-review-and-check.md)

**Tracker** GitHub `johnbenz13/NavigationFlight`. The listed prerequisites must be closed before implementation readiness. This planning effort has no parent issue.

## Behavior

- Confirm for later validates current route and draft, writes one durable transaction, and publishes the pending departure only after a confirmed commit. Keep the operational timer running. A scheduled partway anchor shortens the active leg when it becomes current, retargets Identify and Reach and planned ETA, and excludes the original arrival from normal actions.
- Subsequent inputs and competing writers respect expected sequence and operation ID. Retry cannot duplicate a pending amendment or events. Uncertain post-write outcomes reconcile before another conflicting mutation.
- Restore a valid pending amendment through the existing Flight recovery path with one stable route and departure. Exclude unsaved draft data. Route data that cannot be safely replayed cannot fall back to an apparently active original route.
- Preserve schema 1–3 recordings, GPX/track layout, captured Flight Plan bytes, existing checklist context, and ordinary Cockpit behavior.

## Interface and source context

Inspected NavigationFlight revision `258a42cd060195a24086908fecee9bb44312ff30`. Relevant existing owners and adapters follow. [Flight.swift](../../../NavigationFlight/Domain/Flight/Flight.swift) · [FlightRecordingEngine.swift](../../../NavigationFlight/Domain/Recording/FlightRecordingEngine.swift) · [FlightRecordingEvent.swift](../../../NavigationFlight/Domain/Recording/FlightRecordingEvent.swift) · [FlightRecordingCoordinator.swift](../../../NavigationFlight/Features/Recording/FlightRecordingCoordinator.swift) · [FlightRecordingStorageDTO.swift](../../../NavigationFlight/Data/Recording/FlightRecordingStorageDTO.swift) · [FlightRecordingStore.swift](../../../NavigationFlight/Data/Recording/FlightRecordingStore.swift) · [DiskFlightRecordingStore.swift](../../../NavigationFlight/Data/Recording/DiskFlightRecordingStore.swift) · [FlightRecoveryCoordinator.swift](../../../NavigationFlight/Features/Recording/FlightRecoveryCoordinator.swift) · [CockpitFeatureState.swift](../../../NavigationFlight/Features/Cockpit/CockpitFeatureState.swift)

Proposed change. Add the Flight-owned pending route facts and the same-recording atomic, idempotent command seam to disk and in-memory recording stores. Record accepted geometry, values, identities, captures, and context. Recovery replays exact committed facts and recognizes compatible older journals.

## Visual contract

The canonical comparison is iPad Pro 11-inch portrait (834 × 1194). Where this slice touches adaptive UI, use the approved 1194 × 834 iPad landscape and 402 × 874 iPhone 16 Pro portrait references. The Figma route and values are illustrative. Reuse the existing UIKit/SwiftUI integration and app typography, spacing, tap-target and localization patterns specified by the design.

| Region and state | Design target | Reuse and acceptance |
| --- | --- | --- |
| Normal operation, saving, and retry | [Confirm for later](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=6-34) · [Pending Cockpit](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=14-1236) · [Saving](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=14-883) · [Failed save](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=14-751) | Keep the map, Frequency Plan and timer available. The active-leg strip, map endpoint, ETA and normal destination actions all reflect the shorter leg. [Departure point identified](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=23-296) shows the identified target state. A waypoint departure retains the original destination controls. [Pending pencil](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=14-1274) uses the existing slot and a 44-point target. There is no persistent management row. The management presentation is RA-T06. |
| Recovery | [Recovered pending](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=14-1070) · [Unrecoverable route](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=14-1011) | Reuse the [approved Flight recovery gate](https://www.figma.com/design/ZrGA7ZuOACWtXA4mR7cwdc?node-id=38-275) and existing incomplete confirmation. Keep draft and amendment lifecycle states visually distinct. |

## Reproduction and acceptance

**Fixture.** Route A with a complete Manual draft, current leg already timed, and departure ahead. Use a reopenable synthetic disk package, legacy schema 1–3 fixtures, and write failure before install, uncertain acknowledgement, and readable-but-unreplayable data fixtures. Use disposable synthetic fixtures and controlled clocks in the NavigationFlight scheme.

- Fake-store and temporary-directory tests prove publish-after-durability, interrupted upgrade, retry identity, context/checkpoint serialization, and compatibility. Reopen using the normal recovery interface.
- XCUITest confirms for later, demonstrates normal Cockpit functions and Identify and Reach retargeted to the departure point, retries a forced write failure, and reopens with the same shortened leg, running timer and pending pencil. Verify the normal console retains its established layout. Include iPad portrait success, saving, failure, and restored state captures.
- Check unaffected normal leg progression, captured checklist state, recording read/write behavior and GPX evidence with existing suites.

Tests and rendered comparisons belong to the separately authorized implementation. Record the exact Figma node, device, scenario, and resulting evidence.

## Scope and documentation

**Exclusions.** Departure activation, replacement/cancellation controls, and review of a later reach. Out-of-date pending actions fail safely until their visible decision is delivered.

**Documentation on delivery.** Update recording schema/recovery technical references and the Flight-owned route contract.

**GitHub issue.** [#206](https://github.com/johnbenz13/NavigationFlight/issues/206).
