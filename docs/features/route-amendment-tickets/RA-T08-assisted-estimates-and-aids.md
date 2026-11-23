# RA-T08 · Review and fly an amendment with Assisted estimates and map aids

Approved implementation contract · 2026-11-22. Cockpit reconciliation approved by John · 2026-11-23. Implementation requires separate authorization.

## Outcome

A pilot using Assisted mode sees editable defaults, minute marks and optional drift lines, and can enter any unavailable values.

**Requirements** RA-03, RA-06, RA-09, RA-10, RA-14, RA-22, RA-24. **Verification groups** T03, T06, T10. [Product spec](../IN-FLIGHT-ROUTE-AMENDMENT_SPEC.md) · [Technical design](../../technical/IN-FLIGHT-ROUTE-AMENDMENT-TECHNICAL-DESIGN.md)

**Blocks on** [RA-T04](RA-T04-depart-and-fly.md)

**Tracker** GitHub `johnbenz13/NavigationFlight`. The listed prerequisites must be closed before implementation readiness. This planning effort has no parent issue.

## Behavior

- Capture Assisted at draft entry and prefill available values. Allow edits and explicit entry for unavailable values before confirmation.
- Minute marks follow the editable duration during review and the confirmed one while active. Drift lines share the existing visibility control, and turning them off leaves minute marks in place.
- Manual amendment legs omit both aids after Check. Original legs retain their existing behavior. Reopening or restoring uses accepted values and provenance without recalculating them.
- Manual and Assisted use the same operational cockpit. Mode controls estimate inputs and eligibility of the minute marks and drift lines. The grey dashed bypass uses the same map reference treatment under both modes.

## Interface and source context

Inspected NavigationFlight revision `258a42cd060195a24086908fecee9bb44312ff30`. Relevant existing owners and adapters follow. [AppPreferences.swift](../../../NavigationFlight/Domain/Settings/AppPreferences.swift) · [SettingsFeatureView.swift](../../../NavigationFlight/Features/Settings/SettingsFeatureView.swift) · [NavigationTypes.swift](../../../NavigationFlight/Domain/Navigation/NavigationTypes.swift) · [CockpitFeatureState.swift](../../../NavigationFlight/Features/Cockpit/CockpitFeatureState.swift) · [CockpitPresentationAdapter.swift](../../../NavigationFlight/Features/Cockpit/CockpitPresentationAdapter.swift) · [AviationMapPresentation.swift](../../../NavigationFlight/Map/AviationMapPresentation.swift) · [OfflineAviationMapView.swift](../../../NavigationFlight/Map/OfflineAviationMapView.swift) · [FlightRecordingEngine.swift](../../../NavigationFlight/Domain/Recording/FlightRecordingEngine.swift)

Proposed change. Use the pure estimator from RA-T02. Persist confirmed working values and mode with the route from RA-T04. Mark minute and drift eligibility as per-leg map presentation data, using the current mode and existing drift visibility control.

## Visual contract

Compare iPad Pro 11-inch portrait (834 × 1194) first. Compare iPad landscape (1194 × 834) and iPhone 16 Pro portrait (402 × 874) using the [regular iPad landscape](https://www.figma.com/design/BjpTMuX6RmEE7Ifs59Al7M?node-id=26-2) and [regular iPhone portrait](https://www.figma.com/design/BjpTMuX6RmEE7Ifs59Al7M?node-id=26-176). Use the app’s existing native fonts, placement and spacing, 44-point interactive targets, and accessibility behavior. The reference route and values are illustrative.

| State or region | Figma or regular pattern | Visual acceptance |
| --- | --- | --- |
| Assisted review and fallback | [Assisted review](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=13-924) · [drift lines hidden](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=16-405) · [missing estimate](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=13-1068) · [editor/adaptation](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=42-4420) | Reuse the ordered review and field editor, editable values and missing-field fallback. Draft minute marks follow working duration. Keep the normal Map Tools drift toggle and leave marks visible when drift is off. |
| Active and recovered chart | [Ready](https://www.figma.com/design/o6gfoVEgyzJ0UA51d9Vi9M?node-id=2-3) · [Active](https://www.figma.com/design/o6gfoVEgyzJ0UA51d9Vi9M?node-id=2-6) · [Destination Identified](https://www.figma.com/design/o6gfoVEgyzJ0UA51d9Vi9M?node-id=2-9) · [chart accessibility](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=15-301) | Use the regular operational Cockpit from #207. Add eligible Assisted marks and drift lines to the map for the confirmed leg while preserving the grey dashed bypass. Under Manual, both aids are omitted even after Check. Timed identification points remain outside scope. |
| Adaptive review and flight | [iPad landscape review](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=15-90) · [iPhone portrait review](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=15-141) · [regular iPad landscape](https://www.figma.com/design/BjpTMuX6RmEE7Ifs59Al7M?node-id=26-2) and [regular iPhone portrait](https://www.figma.com/design/BjpTMuX6RmEE7Ifs59Al7M?node-id=26-176) | Use the appropriate existing review or operational shell. At larger text sizes keep the confirmation visible and distinguish chart roles by pattern and labels. |

## Reproduction and acceptance

**Fixture.** Route A in Assisted mode with two computable estimates, then a missing value and an edited duration. Use a separate active first amendment leg and both drift visibility settings. Use disposable synthetic fixtures and controlled clocks in the NavigationFlight scheme.

- Test Assisted field provenance, selective prefill and fallback, saved overrides through commit/recovery, minute placement from working and confirmed duration, and drift visibility independent of minute marks.
- XCUITest compares Manual and Assisted, edits duration, toggles drift lines, enters a missing value and confirms. Provide iPad portrait captures for each of the three Assisted nodes, and compact/landscape review comparisons.
- Use domain fixtures for the planned-wind path without adding a visible selector or requiring live weather, GPS, or real Flight recordings.

- Compare active Assisted with drift on/off and active Manual after Check in the same regular Cockpit. Verify marks follow the confirmed duration, drift visibility affects only drift lines, and no aids or actionable targets attach to the bypass. Capture the matching review, missing-value and operational states.

Tests and rendered comparisons belong to the separately authorized implementation. Record the exact Figma node, device, scenario, and resulting evidence.

## Scope and documentation

**Exclusions.** Planned-wind selector, flight ruler, deviation measurement, and timed amendment identification points.

**Documentation on delivery.** Document Assisted display and map projection behavior, preserving the agreed planned-wind follow-up.

**GitHub issue.** [#211](https://github.com/johnbenz13/NavigationFlight/issues/211).
