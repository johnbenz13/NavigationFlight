# RA-T02 · Enter and check Manual amendment leg values

Approved implementation contract · 2026-11-22. Implementation requires separate authorization.

## Outcome

A pilot can finish a Manual route review, record operational cues, and compare each leg with an app estimate without changing the pilot’s entries.

**Requirements** RA-03, RA-06, RA-09, RA-10, RA-11, RA-14. **Verification groups** T01, T03, T10. [Product spec](../IN-FLIGHT-ROUTE-AMENDMENT_SPEC.md) · [Technical design](../../technical/IN-FLIGHT-ROUTE-AMENDMENT-TECHNICAL-DESIGN.md)

**Blocks on** [RA-T01](RA-T01-plot-and-pause.md)

**Tracker** GitHub `johnbenz13/NavigationFlight`. The listed prerequisites must be closed before implementation readiness. This planning effort has no parent issue.

## Behavior

- Provide editable heading, flight time, altitude, frequency, and visual-reference note. Heading and positive duration are required for each accepted leg. Notes supply no target or timing event.
- Default missing Settings to Manual. Existing or edited drafts keep their captured preference. Check displays the available reference beside the entered values, using magnetic course in no-wind and magnetic heading in a planned-wind fixture.
- An unavailable estimate is explicitly labeled. Preserve entered values, and omit both minute marks and drift lines on Manual amendment legs even after Check.
- Implement both calculation paths with editor-parity fixtures. The current product rollout exposes no new planned-wind selector.

## Interface and source context

Inspected NavigationFlight revision `258a42cd060195a24086908fecee9bb44312ff30`. Relevant existing owners and adapters follow. [NavigationTypes.swift](../../../NavigationFlight/Domain/Navigation/NavigationTypes.swift) · [AppPreferences.swift](../../../NavigationFlight/Domain/Settings/AppPreferences.swift) · [SettingsFeatureView.swift](../../../NavigationFlight/Features/Settings/SettingsFeatureView.swift) · [CockpitFeatureState.swift](../../../NavigationFlight/Features/Cockpit/CockpitFeatureState.swift) · [CockpitView.swift](../../../NavigationFlight/Features/Cockpit/CockpitView.swift) · [CockpitPresentationAdapter.swift](../../../NavigationFlight/Features/Cockpit/CockpitPresentationAdapter.swift)

Proposed change. Extend the existing per-key preferences and save-then-apply controller. Capture the mode in the draft. Add a pure estimate interface accepting the two plotted points, captured execution mode, and plan-wide inputs. Keep pilot values and Check output in separate fields.

## Visual contract

The canonical comparison is iPad Pro 11-inch portrait (834 × 1194). Where this slice touches adaptive UI, use the approved 1194 × 834 iPad landscape and 402 × 874 iPhone 16 Pro portrait references. The Figma route and values are illustrative. Reuse the existing UIKit/SwiftUI integration and app typography, spacing, tap-target and localization patterns specified by the design.

| Region and state | Design target | Reuse and acceptance |
| --- | --- | --- |
| Manual working values and checks | [Manual review](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=6-34) · [Edit values and cues](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=13-485) · [Required values missing](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=15-610) · [Check result](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=13-659) · [Check unavailable](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=13-794) | Reuse the reviewed lower console, per-leg value fields, native text entry and Check action. Keep entered values visually identifiable in the comparison. |
| Mode preference and access | [Settings](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=14-230) · [iPad landscape](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=15-90) · [iPhone portrait](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=15-141) · [Numeric keyboard](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=15-198) · [Larger Text](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=15-254) · [Accessibility](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=15-301) | Reuse the Settings navigation/treatment and error pattern. Keep active field and Done visible, allow wrapping and scrolling, and retain named controls. |

## Reproduction and acceptance

**Fixture.** Route A with two plotted legs and no-wind planning inputs. Enter two whole-degree headings, positive durations, optional altitude and frequency, and a landmark note. Use a separate fixture with unavailable estimate inputs and a representative planned-wind domain fixture. Use disposable synthetic fixtures and controlled clocks in the NavigationFlight scheme.

- Parameterize the pure estimator for editor fixtures, default wind missing, calm wind, impossible wind, positive duration, and label/provenance. Check affects presentation only.
- Swift Testing verifies saved preference, failed save, legacy default, and draft capture. XCUITest exercises editing, required-value validation, keyboard Done, Check and unavailable Check.
- Provide iPad portrait Check and cue-editor screenshots plus iPad landscape and iPhone portrait review evidence, including Larger Text and keyboard layout.

Tests and rendered comparisons belong to the separately authorized implementation. Record the exact Figma node, device, scenario, and resulting evidence.

## Scope and documentation

**Exclusions.** Assisted prefill/aids, flight-ruler UI, timed identification points, planned-wind selector, and recording commands.

**Documentation on delivery.** Document the estimator interface and per-key preference behavior in the technical design and Settings reference.

**Publication status.** Approved for GitHub publication.
