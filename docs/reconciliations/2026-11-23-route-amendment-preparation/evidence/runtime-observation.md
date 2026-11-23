# Current preparation runtime observation

Observed 2026-11-23, approximately 23:51–23:53 Asia/Jerusalem, against baseline `cffba65f08cd8898294c941a4a3291b2fdb7df38`. No app code, scheme, or real flight data changed. Xcode workspace device session `Route Amendment Reconciliation` built/installed/launched successfully and was closed after observation. No tests ran.

Device: iPad Pro 11-inch (M5) simulator, UUID `5D24EA92-83E2-4BE0-9A50-54AA1599984A`; portrait 834 × 1210 points and landscape 1210 × 834 points. Exact runtime OS was not independently established: sandboxed `simctl list devices -j` failed with CoreSimulatorService connection/permission errors. User-provided screenshots identify iPadOS 27.2, but that is not proof of this session's runtime version.

Temporary launch environment (not saved in scheme):

- `NAVIGATION_FLIGHT_UI_TEST_LIBRARY_ID=reconcile-amendment-20261123-observe`
- `NAVIGATION_FLIGHT_UI_TEST_PLAN`: base64 of compact JSON from `fixtures/FlightRecords/llhz-llib-via-jerusalem/flight-plan.fplnav` (49,396 base64 characters).

The library ID directs Flight Plans and recording persistence to disposable simulator temporary directories. The plan starts on original leg 1, שפיים → רידינג. This session did not reproduce the user's leg-2 completed-history scenario. An initial launch used truncated fixture encoding and showed the empty Flight Plans screen; relaunch with complete compact encoding loaded the fixture successfully. No real flight was loaded or modified.

## Inspected action transcript

Every listed state was inspected using its full screenshot and hierarchy. Sibling `*-hierarchy.txt` and `*-logs.txt` files retain tool output. Images are in `../assets/current/`.

| Capture | Action and observation |
| --- | --- |
| `01-entry-portrait` | Start leg at hierarchy hit point (710,1099.5), close checklist (771,167), open pencil (628,144). Console says Choose departure; dark timing strip, Pick a point, Inspect leg, Cancel, and separate header pause visible. Pencil is disabled while editor open. |
| `02-drawing-portrait` | Pick a point (687,1014), choose שפיים from list (417,776.5), then tap map's reported hit point (417,499). A Point 1 via is added. Horizontal departure/via chips, editing row, Move/Remove, Undo/Discard, Pick a return point visible. No leg values are shown while drawing. |
| `03-finish-here-portrait` | Open Pick a point again; choose תל יונה from fresh hierarchy (417,932.5). It initially becomes another Via chip. Finish here appears separately; route is not yet in review. |
| `04-review-portrait` | Tap Finish here (762.8,1164). Console becomes vertical Review legs with two rows, unset heading/time, per-row green Check buttons, Back to drawing, disabled Start now/Confirm for later, and bottom pause in addition to header pause. |
| `05-leg-editor-portrait` | Tap first leg row (363.2,1062). Floating on-map Manual editor opens. Heading text field with ±1°; minutes/seconds fields with ±5s; Inspect original leg, Optional cues, Cancel, Save leg values, Check. |
| `06-optional-cues-portrait` | Expand Optional cues (692,504). Altitude, frequency, visual-reference text fields appear. Modal grows close to map's bottom; action buttons remain visible in this portrait state. |
| `07-paused-cockpit-portrait` | Cancel modal (538,794.5), tap bottom pause (792,1159). Operational Cockpit returns; proposal overlay and legend hide. Disabled pencil says Draft paused and separate play control says Resume route amendment draft. |
| `08-resumed-review-portrait` | Tap resume (628,144). Same two-leg review returns with missing values unchanged. |
| `09-review-landscape` | Rotate landscapeLeft, recapture after transition. Navigation sidebar appears, map occupies middle, review occupies right sidebar. Timing strip stays dark. Review rows compress heading/time to dashes without portrait column labels. Header's leg-position text is partly obscured by the overlay legend in the observed layout. No crash or interaction failure observed. |

## Limits

This is current-product observation, not acceptance evidence for the proposed UX or a Figma match. Completed-leg muting, same-leg triangle rejoin, ambiguous occurrence selection, Manual value entry/save/check results, Assisted mode, arming, recovery, save failures, departure overtaking, flying execution, accessibility sizes and iPhone layout were not exercised. No conclusions about their runtime correctness follow from this chapter. Proposed wheel controls and pencil badge states do not exist in these captures.
