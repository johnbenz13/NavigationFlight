# RA-T09 · Review the amendment in Flight History and diagnostic evidence

Approved implementation contract · 2026-11-22. Implementation requires separate authorization.

## Outcome

A pilot can reconstruct the confirmed and flown route changes, including bypassed portions and Undo, from a closed Flight.

**Requirements** RA-07, RA-17, RA-18, RA-22, RA-23. **Verification groups** T07, T08, T09, T10, T11. [Product spec](../IN-FLIGHT-ROUTE-AMENDMENT_SPEC.md) · [Technical design](../../technical/IN-FLIGHT-ROUTE-AMENDMENT-TECHNICAL-DESIGN.md)

**Blocks on** [RA-T06](RA-T06-manage-and-missed-departure.md), [RA-T07](RA-T07-undo-route-transitions.md)

**Tracker** GitHub `johnbenz13/NavigationFlight`. The listed prerequisites must be closed before implementation readiness. This planning effort has no parent issue.

## Behavior

- Show original, bypassed, operational amendment, and available recorded track geometry with distinct legend entries.
- Timeline exposes confirmation, replacement or cancellation, departure, rejoin and Undo as distinct actions. A bundled missed-departure decision contains the cancellation and ordinary reach facts. An unconfirmed draft produces no amendment event.
- Debug/diagnostic evidence round-trips the normalized route and event values. Preserve GPX as observed track evidence and keep action-only evidence useful without inferring a recorded location.

## Interface and source context

Inspected NavigationFlight revision `258a42cd060195a24086908fecee9bb44312ff30`. Relevant existing owners and adapters follow. [FlightDebrief.swift](../../../NavigationFlight/Features/Flights/FlightDebrief.swift) · [FlightDebriefView.swift](../../../NavigationFlight/Features/Flights/FlightDebriefView.swift) · [FlightEvidenceMapper.swift](../../../NavigationFlight/Data/Recording/FlightEvidenceMapper.swift) · [FlightRecordingEvent.swift](../../../NavigationFlight/Domain/Recording/FlightRecordingEvent.swift) · [FlightRecordingStore.swift](../../../NavigationFlight/Data/Recording/FlightRecordingStore.swift) · [AviationMapPresentation.swift](../../../NavigationFlight/Map/AviationMapPresentation.swift)

Proposed change. Project operational route facts and ordered journal events into Debrief and the portable diagnostic mapper. Resolve route by event sequence with stable IDs. Preserve recorded aircraft tracks and correlation semantics independently from planning geometry.

## Visual contract

The canonical comparison is iPad Pro 11-inch portrait (834 × 1194). Where this slice touches adaptive UI, use the approved 1194 × 834 iPad landscape and 402 × 874 iPhone 16 Pro portrait references. The Figma route and values are illustrative. Reuse the existing UIKit/SwiftUI integration and app typography, spacing, tap-target and localization patterns specified by the design.

| Region and state | Design target | Reuse and acceptance |
| --- | --- | --- |
| Amendment route and events | [Debrief map and replay console](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=15-423) | Reuse the [approved compact replay](https://www.figma.com/design/OSPuLyy5Qtde2iajUNeWDL?node-id=73-321), action selection, legend treatment, and [action-only layout](https://www.figma.com/design/OSPuLyy5Qtde2iajUNeWDL?node-id=95-522). |
| Responsive history | [Accessibility coverage](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=15-301) | Retain [approved iPad landscape replay](https://www.figma.com/design/OSPuLyy5Qtde2iajUNeWDL?node-id=95-1088) and [iPhone portrait replay](https://www.figma.com/design/OSPuLyy5Qtde2iajUNeWDL?node-id=95-1288) layout; the new legend and event labels must wrap and retain reading order. |

## Reproduction and acceptance

**Fixture.** Closed synthetic Flight with confirmed and replaced amendment, partway departure, rejoin, a later reach cancelling a pending change and a linked Undo. Verify another recording with action-only evidence and an untouched legacy package. Use disposable synthetic fixtures and controlled clocks in the NavigationFlight scheme.

- Synthetic debrief projection and portable export tests round-trip ordered actions, route geometries, stable selection and Undo links, with and without track. Verify untouched and legacy evidence compatibility and existing GPX output.
- XCUITest opens a closed Flight, selects amendment and Undo events and reviews the affected route. Capture the approved iPad portrait replay and the reused compact, landscape, and action-only patterns with amendment data.
- Verify the ordinary route, partial evidence styling, diagnostic package validation and GPX regression suites.

Tests and rendered comparisons belong to the separately authorized implementation. Record the exact Figma node, device, scenario, and resulting evidence.

## Scope and documentation

**Exclusions.** Changes to playback transport, GPS inference/correlation policy, detector thresholds, or private Flight fixtures.

**Documentation on delivery.** Add amendment fact mappings and legend semantics to the Debrief and diagnostic-export technical references.

**GitHub issue.** [#212](https://github.com/johnbenz13/NavigationFlight/issues/212).
