# RA-T01 · Plot, edit, and pause a route amendment draft

Approved implementation contract · 2026-11-22. Implementation requires separate authorization.

## Outcome

A pilot can sketch a continuous replacement on the Cockpit map and return to it after using normal navigation controls.

**Requirements** RA-01, RA-02, RA-04, RA-13, RA-19, RA-20. **Verification groups** T01, T02, T10. [Product spec](../IN-FLIGHT-ROUTE-AMENDMENT_SPEC.md) · [Technical design](../../technical/IN-FLIGHT-ROUTE-AMENDMENT-TECHNICAL-DESIGN.md)

**Blocks on** None.

**Tracker** GitHub `johnbenz13/NavigationFlight`. The listed prerequisites must be closed before implementation readiness. This planning effort has no parent issue.

## Behavior

- Pencil opens drawing during an underway Flight, including the untimed interval between legs. Draw through tapped existing or new points and preview each straight leg.
- Require an explicit rejoin strictly ahead in route order. Resolve overlaps by leg occurrence and make the bypassed interval visibly different from the retained and proposed path.
- Move or remove a point, undo the last plot, and confirm discarding a nonempty draft. Pause restores operational map and console input. Play resumes the exact draft step without adding a recorded navigation event.
- Invalidate an overtaken departure by pilot-reported progression and preserve the remaining draft. Clear drafts on a changed Flight or process restart.

## Interface and source context

Inspected NavigationFlight revision `258a42cd060195a24086908fecee9bb44312ff30`. Relevant existing owners and adapters follow. [CockpitFeatureState.swift](../../../NavigationFlight/Features/Cockpit/CockpitFeatureState.swift) · [CockpitView.swift](../../../NavigationFlight/Features/Cockpit/CockpitView.swift) · [Flight.swift](../../../NavigationFlight/Domain/Flight/Flight.swift) · [FlightPlan.swift](../../../NavigationFlight/Domain/Flight/FlightPlan.swift) · [AviationMapPresentation.swift](../../../NavigationFlight/Map/AviationMapPresentation.swift) · [OfflineAviationMapView.swift](../../../NavigationFlight/Map/OfflineAviationMapView.swift)

Proposed change. Flight-owned read projection over imported data for an untouched Flight. Cockpit owns an in-memory draft by Flight ID. MapLibre supplies viewport hit candidates and manually selected WGS84 coordinates. A shared draft intent handles taps, map-center placement, accessible point selection, and edit commands.

## Visual contract

The canonical comparison is iPad Pro 11-inch portrait (834 × 1194). Where this slice touches adaptive UI, use the approved 1194 × 834 iPad landscape and 402 × 874 iPhone 16 Pro portrait references. The Figma route and values are illustrative. Reuse the existing UIKit/SwiftUI integration and app typography, spacing, tap-target and localization patterns specified by the design.

| Region and state | Design target | Reuse and acceptance |
| --- | --- | --- |
| Entry, editing, and pause | [Pencil only](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=10-92) · [Pencil plus pause](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=6-34) · [Paused with play](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=7-94) | Reuse the reconciled Cockpit tab and leg strips, operational console, map gestures, and 44-point icon hit areas. Make edit/operational tap dispatch exclusive. |
| Drawing, corrections, and discard | [Empty drawing](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=12-90) · [Selected point](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=12-222) · [Explicit rejoin](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=17-296) · [Overlap choice](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=13-114) · [Stale departure](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=13-258) · [Discard dialog](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=13-388) | Use the existing full-width map and lower console. Keep the selected point, crossing choices, preview line styles, and cancel/error actions visible. |
| Adaptive map and access | [iPad landscape](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=15-90) · [iPhone portrait](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=15-141) · [Accessibility notes](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=15-301) | Keep native panel placement per width, scrolling, distinct line patterns, VoiceOver choices and accessible placement, and Reduce Motion. |

## Reproduction and acceptance

**Fixture.** Route A in progress on Kadima → Ramat, with a mid-leg departure, a free waypoint, and rejoin at Aviel. Route B has one crossing, adjacent endpoint occurrences, and a repeated coordinate. Use disposable synthetic fixtures and controlled clocks in the NavigationFlight scheme.

- Swift Testing proves same-leg and downstream splices, coincident/overlap choices, duplicate and reversed rejection, exact bypass, point removal, and unchanged operational state after draft edits.
- XCUITest plots and selects the sample points, pauses to use Frequency Plan or a point callout, resumes with original draft values and selection, handles a stale departure, and discards only after approval.
- Capture exact Figma comparisons for empty/selected/rejoin and paused Cockpit on iPad portrait, and representative entry and map editing in iPad landscape and iPhone portrait. Verify VoiceOver candidate labels and the 44-point controls.

Tests and rendered comparisons belong to the separately authorized implementation. Record the exact Figma node, device, scenario, and resulting evidence.

## Scope and documentation

**Exclusions.** Per-leg estimates and values, durable confirmation, new-leg progression, amendment-specific timed identification points, and flight ruler.

**Documentation on delivery.** Record draft projection and tap-intent ownership in the Cockpit and map technical references.

**Publication status.** Approved for GitHub publication.
