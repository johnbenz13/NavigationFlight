# RA-T06 · Replace or cancel a pending amendment and resolve a missed departure

Approved implementation contract · 2026-11-22. Implementation requires separate authorization.

## Outcome

A pilot can manage one pending amendment and explicitly report the original destination reached if they continued on the original route.

**Requirements** RA-05, RA-12, RA-13, RA-19, RA-20, RA-22, RA-23. **Verification groups** T02, T06, T07, T10, T11. [Product spec](../IN-FLIGHT-ROUTE-AMENDMENT_SPEC.md) · [Technical design](../../technical/IN-FLIGHT-ROUTE-AMENDMENT-TECHNICAL-DESIGN.md)

**Blocks on** [RA-T03](RA-T03-schedule-and-recover.md)

**Tracker** GitHub `johnbenz13/NavigationFlight`. The listed prerequisites must be closed before implementation readiness. This planning effort has no parent issue.

## Behavior

- Keep the saved amendment while reviewing replacement values. A confirmed replacement or cancellation changes the single pending record and creates the corresponding history fact.
- The explicit original-destination report from Manage opens the confirmation. The app compares route order after that pilot action. GPS, elapsed time, and passive map activity never cause the prompt. Keep pending records neither reach nor cancellation. Cancel and record reach commits both effects once and advances the current route under its existing policy.
- Expose the original-destination action only while the shortened leg is current. A report for its departure follows the normal transition and does not show this dialog. Retain earlier history and permit another draft on the remaining route after activation using RA-T01.
- Preserve the current route, pending amendment and requested intent on failure. Retry cannot apply only one part. Existing ordinary reach Undo retains atomic prior-state restoration when it applies.

## Interface and source context

Inspected NavigationFlight revision `258a42cd060195a24086908fecee9bb44312ff30`. Relevant existing owners and adapters follow. [Flight.swift](../../../NavigationFlight/Domain/Flight/Flight.swift) · [CockpitFeatureView.swift](../../../NavigationFlight/Features/Cockpit/CockpitFeatureView.swift) · [CockpitFeatureState.swift](../../../NavigationFlight/Features/Cockpit/CockpitFeatureState.swift) · [CockpitView.swift](../../../NavigationFlight/Features/Cockpit/CockpitView.swift) · [FlightRecordingCoordinator.swift](../../../NavigationFlight/Features/Recording/FlightRecordingCoordinator.swift) · [FlightRecordingEngine.swift](../../../NavigationFlight/Domain/Recording/FlightRecordingEngine.swift) · [FlightRecordingEvent.swift](../../../NavigationFlight/Domain/Recording/FlightRecordingEvent.swift) · [FlightRecoveryCoordinator.swift](../../../NavigationFlight/Features/Recording/FlightRecoveryCoordinator.swift)

Proposed change. Extend pending management on the existing route revision. Open the existing pencil as an accessible pending control, showing a popover in regular width and a native sheet in compact width. Dismissal is presentation only. Use one durable transaction for a replacement or cancellation and one indivisible cancel-plus-reach operation. Validate the expected pending identity and eligible target again at commit time.

## Visual contract

The canonical comparison is iPad Pro 11-inch portrait (834 × 1194). Where this slice touches adaptive UI, use the approved 1194 × 834 iPad landscape and 402 × 874 iPhone 16 Pro portrait references. The Figma route and values are illustrative. Reuse the existing UIKit/SwiftUI integration and app typography, spacing, tap-target and localization patterns specified by the design.

| Region and state | Design target | Reuse and acceptance |
| --- | --- | --- |
| Pending management | [Pending state](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=14-1236) · [iPad pencil popover](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=26-266) · [iPhone management sheet](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=26-461) · [Cancellation confirmation](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=26-362) · [Replacement review](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=15-743) | Reuse the existing pencil slot and Cockpit console. The pending management actions appear only while the anchored popover or compact sheet is open. Dismiss without changing the route. Reuse the review fields and confirmation dialog pattern.  |
| Explicit original-destination report | [Explicit original destination report](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=23-384) · [Exact dialog node](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=23-457) | Use a confirmable sheet/dialog over operational Cockpit with a clear destination example and both explicit actions. Keep pending must leave the existing Cockpit available.  |

## Reproduction and acceptance

**Fixture.** Route A with one pending departure partway along leg 2. Tap the pending pencil → Report original destination reached to report Ramat beyond the selected departure, then exercise both outcomes. Verify Ramat cannot be reported from the shortened leg’s normal controls. Repeat with a replacement draft, a reach at the departure itself, and a failed write. Use disposable synthetic fixtures and controlled clocks in the NavigationFlight scheme.

- Domain and transaction tests cover replace/cancel, both later-reach outcomes, the anchor equality branch, a stale prompt and persistence failure with no partial events.
- Verify that ordinary reach Undo restores the state before its atomic action when available, and recovery reconstructs pending or cancelled state from the same journal records.
- XCUITest opens and dismisses the pending pencil popover or compact sheet, checks both original-destination dialog paths, and verifies the normal Identify and Reach target is the departure point and proceeds without opening this dialog. Capture the updated iPad portrait path and the iPhone sheet and confirmation sizing. Verify VoiceOver announces Manage pending amendment and returns focus to the pencil on dismissal.

Tests and rendered comparisons belong to the separately authorized implementation. Record the exact Figma node, device, scenario, and resulting evidence.

## Scope and documentation

**Exclusions.** Future route destination changes, a second simultaneously pending amendment, and a freehand eraser.

**Documentation on delivery.** Record RA-23 and the approved confirmation copy and visual node after review.

**Publication status.** Approved for GitHub publication.
