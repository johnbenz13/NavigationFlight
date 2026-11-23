# RA-T09 · Review the amendment in Flight History and diagnostic evidence

Approved implementation contract · 2026-11-22. Cockpit reconciliation approved by John · 2026-11-23. Implementation requires separate authorization.

## Outcome

A pilot can reconstruct the confirmed and flown route changes, including bypassed portions and Undo, from a closed Flight.

**Requirements** RA-07, RA-17, RA-18, RA-22, RA-23. **Verification groups** T07, T08, T09, T10, T11. [Product spec](../IN-FLIGHT-ROUTE-AMENDMENT_SPEC.md) · [Technical design](../../technical/IN-FLIGHT-ROUTE-AMENDMENT-TECHNICAL-DESIGN.md)

**Blocks on** [RA-T06](RA-T06-manage-and-missed-departure.md), [RA-T07](RA-T07-undo-route-transitions.md)

**Tracker** GitHub `johnbenz13/NavigationFlight`. The listed prerequisites must be closed before implementation readiness. This planning effort has no parent issue.

## Behavior

- Show original, bypassed, operational amendment, and available recorded track geometry with distinct legend entries.
- Timeline exposes confirmation, replacement or cancellation, departure, rejoin and Undo as distinct actions. A bundled missed-departure decision contains the cancellation and ordinary reach facts. An unconfirmed draft produces no amendment event.
- Debug/diagnostic evidence round-trips the normalized route and event values. Preserve GPX as observed track evidence and keep action-only evidence useful without inferring a recorded location.
- In historical route geometry, the preceding leg ends at the first replacement leg’s departure, and the final replacement leg ends at the retained leg’s start. Reconstruct these shared points even when no track is available. The regular flight Cockpit revision changes no replay interaction or evidence meaning.

## Interface and source context

Inspected NavigationFlight revision `258a42cd060195a24086908fecee9bb44312ff30`. Relevant existing owners and adapters follow. [FlightDebrief.swift](../../../NavigationFlight/Features/Flights/FlightDebrief.swift) · [FlightDebriefView.swift](../../../NavigationFlight/Features/Flights/FlightDebriefView.swift) · [FlightEvidenceMapper.swift](../../../NavigationFlight/Data/Recording/FlightEvidenceMapper.swift) · [FlightRecordingEvent.swift](../../../NavigationFlight/Domain/Recording/FlightRecordingEvent.swift) · [FlightRecordingStore.swift](../../../NavigationFlight/Data/Recording/FlightRecordingStore.swift) · [AviationMapPresentation.swift](../../../NavigationFlight/Map/AviationMapPresentation.swift)

Proposed change. Project operational route facts and ordered journal events into Debrief and the portable diagnostic mapper. Resolve route by event sequence with stable IDs. Preserve recorded aircraft tracks and correlation semantics independently from planning geometry.

## Visual contract

Compare iPad Pro 11-inch portrait (834 × 1194) first, with 1194 × 834 iPad landscape and 402 × 874 iPhone 16 Pro portrait adaptations. Use the standard Debrief layout, labels, target sizes and VoiceOver reading order. The reference route and values are illustrative.

| State or region | Figma or regular pattern | Visual acceptance |
| --- | --- | --- |
| Route and event selection | [amendment Debrief](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=15-423) · [standard replay](https://www.figma.com/design/OSPuLyy5Qtde2iajUNeWDL?node-id=73-321) | Reuse existing replay transport, route legend and event selection. Distinguish original, bypassed, operational replacement/retained and recorded track. A dashed bypass is planned route evidence. Preserve shared departure and rejoin occurrences and individual event facts when selecting events. |
| No recorded track | [action-only replay](https://www.figma.com/design/OSPuLyy5Qtde2iajUNeWDL?node-id=95-522) | Show the no-usable-track treatment and action timeline. Keep route evidence readable and independent of any location or track inferred from a recorded action. |
| Responsive Debrief | [iPad landscape replay](https://www.figma.com/design/OSPuLyy5Qtde2iajUNeWDL?node-id=95-1088) · [iPhone portrait replay](https://www.figma.com/design/OSPuLyy5Qtde2iajUNeWDL?node-id=95-1288) | Use the regular Debrief layout. Keep the legend, selected event, action reading order and replay controls available at the supported sizes. |

## Reproduction and acceptance

**Fixture.** Closed synthetic Flight with confirmed and replaced amendment, partway departure, rejoin, a later reach cancelling a pending change and a linked Undo. Verify another recording with action-only evidence and an untouched legacy package. Use disposable synthetic fixtures and controlled clocks in the NavigationFlight scheme.

- Synthetic debrief projection and portable export tests round-trip ordered actions, route geometries, stable selection and Undo links, with and without track. Verify untouched and legacy evidence compatibility and existing GPX output.
- XCUITest opens a closed Flight, selects amendment and Undo events and reviews the affected route. Capture the approved iPad portrait replay and the reused compact, landscape, and action-only patterns with amendment data.
- Verify the ordinary route, partial evidence styling, diagnostic package validation and GPX regression suites.

- In the closed fixture, select departure and rejoin in the timeline and inspect the shared points consistently with and without recorded track. Verify that the bypass and operational route remain legible in the amendment-specific legend and the existing responsive and action-only replay shells.

Tests and rendered comparisons belong to the separately authorized implementation. Record the exact Figma node, device, scenario, and resulting evidence.

## Scope and documentation

**Exclusions.** Changes to playback transport, GPS inference/correlation policy, detector thresholds, or private Flight fixtures.

**Documentation on delivery.** Add amendment fact mappings and legend semantics to the Debrief and diagnostic-export technical references.

**GitHub issue.** [#212](https://github.com/johnbenz13/NavigationFlight/issues/212).
