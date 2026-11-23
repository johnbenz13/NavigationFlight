# RA-T08 · Review and fly an amendment with Assisted estimates and map aids

Approved implementation contract · 2026-11-22. Implementation requires separate authorization.

## Outcome

A pilot using Assisted mode sees editable defaults, minute marks and optional drift lines, and can enter any unavailable values.

**Requirements** RA-03, RA-06, RA-09, RA-10, RA-14, RA-22. **Verification groups** T03, T06, T10. [Product spec](../IN-FLIGHT-ROUTE-AMENDMENT_SPEC.md) · [Technical design](../../technical/IN-FLIGHT-ROUTE-AMENDMENT-TECHNICAL-DESIGN.md)

**Blocks on** [RA-T04](RA-T04-depart-and-fly.md)

**Tracker** GitHub `johnbenz13/NavigationFlight`. The listed prerequisites must be closed before implementation readiness. This planning effort has no parent issue.

## Behavior

- Capture Assisted at draft entry and prefill available values. Allow edits and explicit entry for unavailable values before confirmation.
- Minute marks follow the editable duration during review and the confirmed one while active. Drift lines share the existing visibility control, and turning them off leaves minute marks in place.
- Manual amendment legs omit both aids after Check. Original legs retain their existing behavior. Reopening or restoring uses accepted values and provenance without recalculating them.

## Interface and source context

Inspected NavigationFlight revision `258a42cd060195a24086908fecee9bb44312ff30`. Relevant existing owners and adapters follow. [AppPreferences.swift](../../../NavigationFlight/Domain/Settings/AppPreferences.swift) · [SettingsFeatureView.swift](../../../NavigationFlight/Features/Settings/SettingsFeatureView.swift) · [NavigationTypes.swift](../../../NavigationFlight/Domain/Navigation/NavigationTypes.swift) · [CockpitFeatureState.swift](../../../NavigationFlight/Features/Cockpit/CockpitFeatureState.swift) · [CockpitPresentationAdapter.swift](../../../NavigationFlight/Features/Cockpit/CockpitPresentationAdapter.swift) · [AviationMapPresentation.swift](../../../NavigationFlight/Map/AviationMapPresentation.swift) · [OfflineAviationMapView.swift](../../../NavigationFlight/Map/OfflineAviationMapView.swift) · [FlightRecordingEngine.swift](../../../NavigationFlight/Domain/Recording/FlightRecordingEngine.swift)

Proposed change. Use the pure estimator from RA-T02. Persist confirmed working values and mode with the route from RA-T04. Mark minute and drift eligibility as per-leg map presentation data, using the current mode and existing drift visibility control.

## Visual contract

The canonical comparison is iPad Pro 11-inch portrait (834 × 1194). Where this slice touches adaptive UI, use the approved 1194 × 834 iPad landscape and 402 × 874 iPhone 16 Pro portrait references. The Figma route and values are illustrative. Reuse the existing UIKit/SwiftUI integration and app typography, spacing, tap-target and localization patterns specified by the design.

| Region and state | Design target | Reuse and acceptance |
| --- | --- | --- |
| Assisted review, aids, and fallback | [Assisted values and aids](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=13-924) · [Drift lines hidden](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=16-405) · [Missing estimate](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=13-1068) | Share map overlay grammar and the normal Map Tools drift control. Match the leg editor fields and visible missing-value fallback rather than showing an invented estimate. |
| Adaptive rendering | [iPad landscape shell](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=15-90) · [iPhone portrait shell](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=15-141) · [Accessibility contract](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=15-301) | Use the approved responsive review treatment and accessible labels. Keep the two line patterns and labels distinguishable over chart content. |

## Reproduction and acceptance

**Fixture.** Route A in Assisted mode with two computable estimates, then a missing value and an edited duration. Use a separate active first amendment leg and both drift visibility settings. Use disposable synthetic fixtures and controlled clocks in the NavigationFlight scheme.

- Test Assisted field provenance, selective prefill and fallback, saved overrides through commit/recovery, minute placement from working and confirmed duration, and drift visibility independent of minute marks.
- XCUITest compares Manual and Assisted, edits duration, toggles drift lines, enters a missing value and confirms. Provide iPad portrait captures for each of the three Assisted nodes, and compact/landscape review comparisons.
- Use domain fixtures for the planned-wind path without adding a visible selector or requiring live weather, GPS, or real Flight recordings.

Tests and rendered comparisons belong to the separately authorized implementation. Record the exact Figma node, device, scenario, and resulting evidence.

## Scope and documentation

**Exclusions.** Planned-wind selector, flight ruler, deviation measurement, and timed amendment identification points.

**Documentation on delivery.** Document Assisted display and map projection behavior, preserving the agreed planned-wind follow-up.

**GitHub issue.** [#211](https://github.com/johnbenz13/NavigationFlight/issues/211).
