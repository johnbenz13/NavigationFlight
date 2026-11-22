# In-flight route amendment · Delivery plan

Approved by John for GitHub publication · 2026-11-22

John approved the product, detailed Figma design, and technical architecture. He subsequently approved deferring the planned-wind selector and the choice to keep a scheduled amendment pending or cancel it and record an explicit original-destination reach. Confirming a scheduled mid-leg departure now shortens the original leg and retargets its normal controls. The existing pencil is the management entry while pending, with a transient iPad popover or iPhone sheet and no extra console row. John approved the revised frames and nine-ticket breakdown on 2026-11-22.

[Product spec](IN-FLIGHT-ROUTE-AMENDMENT_SPEC.md) · [Technical design](../technical/IN-FLIGHT-ROUTE-AMENDMENT-TECHNICAL-DESIGN.md) · [Approved Figma coverage and dialog link](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=17-254)

## Implementation tickets

| Planning ticket | Outcome | Direct blockers | GitHub status |
| --- | --- | --- | --- |
| [RA-T01](route-amendment-tickets/RA-T01-plot-and-pause.md) | Plot, edit, and pause a route amendment draft | None | Approved for publication |
| [RA-T02](route-amendment-tickets/RA-T02-manual-review-and-check.md) | Enter and check Manual amendment leg values | RA-T01 | Approved for publication |
| [RA-T03](route-amendment-tickets/RA-T03-schedule-and-recover.md) | Confirm a future amendment and restore it with the Flight | RA-T02 | Approved for publication |
| [RA-T04](route-amendment-tickets/RA-T04-depart-and-fly.md) | Start the amendment and fly its replacement legs | RA-T03 | Approved for publication |
| [RA-T05](route-amendment-tickets/RA-T05-rejoin-and-rebase.md) | Rejoin the retained route with rebased timing and cues | RA-T04 | Approved for publication |
| [RA-T06](route-amendment-tickets/RA-T06-manage-and-missed-departure.md) | Replace or cancel a pending amendment and resolve a missed departure | RA-T03 | Approved for publication |
| [RA-T07](route-amendment-tickets/RA-T07-undo-route-transitions.md) | Undo a departure or rejoin with the previous timer and route intact | RA-T05 | Approved for publication |
| [RA-T08](route-amendment-tickets/RA-T08-assisted-estimates-and-aids.md) | Review and fly an amendment with Assisted estimates and map aids | RA-T04 | Approved for publication |
| [RA-T09](route-amendment-tickets/RA-T09-debrief-and-export.md) | Review the amendment in Flight History and diagnostic evidence | RA-T06, RA-T07 | Approved for publication |

Each ticket delivers an independently reviewable behavior through the necessary app layers. The slices land through the route-amendment integration branch. Draft-only, pending-only, and departure-only checkpoints are demonstrable with disposable fixtures before the feature as a whole is ready to release. Review the full flow, including durable recovery, rejoin and Undo, before making it available in a release. Normal flights stay regression-tested at each checkpoint.

GitHub destination is `johnbenz13/NavigationFlight`. A read-only search of existing issue titles for route amendment, reroute, and unplanned leg found no existing parent or duplicate. Publish the approved issues in dependency order with native blocking relationships if available and explicit issue references otherwise. The GitHub issues link to the immutable planning revision on the published feature branch.

## Coverage and verification

| Requirement | Planning tickets | Design entry point | Verification |
| --- | --- | --- | --- |
| RA-01 | [RA-T01](route-amendment-tickets/RA-T01-plot-and-pause.md) | [Pencil and mode entry](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=10-92) | T01, T10 |
| RA-02 | [RA-T01](route-amendment-tickets/RA-T01-plot-and-pause.md), [RA-T05](route-amendment-tickets/RA-T05-rejoin-and-rebase.md) | [Plot anchors and points](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=12-222) | T01, T02 |
| RA-03 | [RA-T02](route-amendment-tickets/RA-T02-manual-review-and-check.md), [RA-T08](route-amendment-tickets/RA-T08-assisted-estimates-and-aids.md) | [Manual and Assisted values](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=6-34) | T03 |
| RA-04 | [RA-T01](route-amendment-tickets/RA-T01-plot-and-pause.md), [RA-T04](route-amendment-tickets/RA-T04-depart-and-fly.md), [RA-T05](route-amendment-tickets/RA-T05-rejoin-and-rebase.md) | [Bypassed route and correction](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=13-114) | T02, T04 |
| RA-05 | [RA-T03](route-amendment-tickets/RA-T03-schedule-and-recover.md), [RA-T04](route-amendment-tickets/RA-T04-depart-and-fly.md), [RA-T05](route-amendment-tickets/RA-T05-rejoin-and-rebase.md), [RA-T06](route-amendment-tickets/RA-T06-manage-and-missed-departure.md) | [Confirm, activate, and follow](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=14-1236) | T04, T06 |
| RA-06 | [RA-T02](route-amendment-tickets/RA-T02-manual-review-and-check.md), [RA-T08](route-amendment-tickets/RA-T08-assisted-estimates-and-aids.md) | [Per-mode map aids](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=13-924) | T03, T10 |
| RA-07 | [RA-T09](route-amendment-tickets/RA-T09-debrief-and-export.md) | Outside release | T10 scope check |
| RA-08 | [RA-T03](route-amendment-tickets/RA-T03-schedule-and-recover.md), [RA-T04](route-amendment-tickets/RA-T04-depart-and-fly.md), [RA-T05](route-amendment-tickets/RA-T05-rejoin-and-rebase.md), [RA-T07](route-amendment-tickets/RA-T07-undo-route-transitions.md) | [Pilot departure and rejoin reports](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=14-484) | T04, T08 |
| RA-09 | [RA-T02](route-amendment-tickets/RA-T02-manual-review-and-check.md), [RA-T08](route-amendment-tickets/RA-T08-assisted-estimates-and-aids.md) | [Default and captured preference](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=14-230) | T03 |
| RA-10 | [RA-T02](route-amendment-tickets/RA-T02-manual-review-and-check.md), [RA-T08](route-amendment-tickets/RA-T08-assisted-estimates-and-aids.md) | [Required values and fallback](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=13-1068) | T03 |
| RA-11 | [RA-T02](route-amendment-tickets/RA-T02-manual-review-and-check.md) | [Optional cues and visual notes](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=13-485) | T05 |
| RA-12 | [RA-T03](route-amendment-tickets/RA-T03-schedule-and-recover.md), [RA-T06](route-amendment-tickets/RA-T06-manage-and-missed-departure.md) | [Manage pending and further amendments](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=26-266) | T02, T07 |
| RA-13 | [RA-T01](route-amendment-tickets/RA-T01-plot-and-pause.md), [RA-T03](route-amendment-tickets/RA-T03-schedule-and-recover.md), [RA-T06](route-amendment-tickets/RA-T06-manage-and-missed-departure.md), [RA-T07](route-amendment-tickets/RA-T07-undo-route-transitions.md) | [Draft lifetime and stale/recovered state](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=13-258) | T01, T02, T07 |
| RA-14 | [RA-T02](route-amendment-tickets/RA-T02-manual-review-and-check.md), [RA-T08](route-amendment-tickets/RA-T08-assisted-estimates-and-aids.md) | [Estimate inputs, provenance and map marks](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=13-659) | T03 |
| RA-15 | [RA-T04](route-amendment-tickets/RA-T04-depart-and-fly.md), [RA-T05](route-amendment-tickets/RA-T05-rejoin-and-rebase.md) | [Retained interval and timing](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=14-664) | T04, T05 |
| RA-16 | [RA-T04](route-amendment-tickets/RA-T04-depart-and-fly.md), [RA-T05](route-amendment-tickets/RA-T05-rejoin-and-rebase.md) | [Altitude and radio cue continuity](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=14-664) | T05 |
| RA-17 | [RA-T07](route-amendment-tickets/RA-T07-undo-route-transitions.md), [RA-T09](route-amendment-tickets/RA-T09-debrief-and-export.md) | [Amendment Undo](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=14-484) | T08 |
| RA-18 | [RA-T03](route-amendment-tickets/RA-T03-schedule-and-recover.md), [RA-T04](route-amendment-tickets/RA-T04-depart-and-fly.md), [RA-T05](route-amendment-tickets/RA-T05-rejoin-and-rebase.md), [RA-T07](route-amendment-tickets/RA-T07-undo-route-transitions.md), [RA-T09](route-amendment-tickets/RA-T09-debrief-and-export.md) | [History and diagnostic evidence](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=15-423) | T07, T09 |
| RA-19 | [RA-T01](route-amendment-tickets/RA-T01-plot-and-pause.md), [RA-T06](route-amendment-tickets/RA-T06-manage-and-missed-departure.md) | [Edit and suspend drawing](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=7-94) | T01, T10 |
| RA-20 | [RA-T01](route-amendment-tickets/RA-T01-plot-and-pause.md), [RA-T06](route-amendment-tickets/RA-T06-manage-and-missed-departure.md) | [Anchor validation and ambiguity](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=13-114) | T02 |
| RA-21 | [RA-T04](route-amendment-tickets/RA-T04-depart-and-fly.md), [RA-T05](route-amendment-tickets/RA-T05-rejoin-and-rebase.md), [RA-T07](route-amendment-tickets/RA-T07-undo-route-transitions.md) | [Checklists and leg-scoped revisions](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=14-579) | T04, T05, T08 |
| RA-22 | [RA-T03](route-amendment-tickets/RA-T03-schedule-and-recover.md), [RA-T04](route-amendment-tickets/RA-T04-depart-and-fly.md), [RA-T05](route-amendment-tickets/RA-T05-rejoin-and-rebase.md), [RA-T06](route-amendment-tickets/RA-T06-manage-and-missed-departure.md), [RA-T07](route-amendment-tickets/RA-T07-undo-route-transitions.md), [RA-T08](route-amendment-tickets/RA-T08-assisted-estimates-and-aids.md), [RA-T09](route-amendment-tickets/RA-T09-debrief-and-export.md) | [Durability and failure handling](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=14-751) | T06, T07 |
| RA-23 | [RA-T06](route-amendment-tickets/RA-T06-manage-and-missed-departure.md), [RA-T09](route-amendment-tickets/RA-T09-debrief-and-export.md) | [Explicit original-destination report](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=23-384) | T11 |

Ticket-specific frames and approved reused patterns are listed within each draft. Verification groups T01–T11 are defined in the technical design. The worktree baseline is `258a42cd060195a24086908fecee9bb44312ff30`. Publication is authorized. Implementation remains a separate decision.

## Scope exclusions
 The flight ruler, planned-wind selector, timed identification points on amendment legs, eraser, and iPhone landscape remain outside this release.
