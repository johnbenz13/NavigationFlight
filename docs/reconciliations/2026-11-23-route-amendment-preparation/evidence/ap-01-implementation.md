# AP-01 implementation evidence

Branch: `feature/amendment-workspace-toggle`, baseline `f690d07`.
Owner clarification in this implementation session: Arm is a disabled placeholder
with no effect until AP-11. No preparation Start now action is retained.

## State trace and visual contract

| Criterion / state | Authority | Reproduction |
| --- | --- | --- |
| Untouched open/closed | G01, D02 13:639 None; D03 29:883/29:1238/29:1167 geometry | Start disposable Flight; toggle pencil twice |
| Edited open/closed/reopened | G01/G06, D02 13:639 Incomplete/Ready; same D03 frames | Select departure and plot; edit values; toggle pencil twice |
| Modal open / long content | G06, D03 stable viewport rule; existing editors retained until AP-04/05 | Review existing route, select leg, enter values, toggle pencil |
| Pending / Manual first leg Ready / Flying | G01/G07, D02 13:639 Armed/Awaiting Start leg/Flying | Existing domain-confirmed amendment fixtures; report departure, then Start leg |
| Unsaved | G01, D02 13:639 independent status rule | Existing failed confirmation state; draft persistence remains AP-09 |
| Ordinary Cockpit | Protected regular-Cockpit rule; accepted #207 patterns | Same Flight before/open/closed; only pencil/status may change |

Directly retrieved and inspected Figma context and screenshots: `JCyQhDDzCPfrrbv6SBcwKw`
nodes 29:883, 29:1238, 29:1167 and 13:639. The map remains the existing interactive
map; chart raster, illustrative geometry and device chrome are not implementation assets.
SF/system typography, semantic surfaces and native buttons follow the approved rule.

Measured contract: share CockpitRestingLayoutPolicy (288 pt portrait, 278 pt compact,
370 pt rail), including the existing operational Reach adjustment and safe areas in
both modes. D03 portrait content inset 20 pt, 60 pt quiet timing strip, 44 pt workspace
heading, 50 pt rows / 4 pt row gaps, fixed action row. Compact/rail inset 16 pt, timing
68 pt baseline, 60 pt rows. Native button geometry and Dynamic Type are adaptive;
44 pt minimum targets. Quiet timing surface #f2f7fa in light appearance, semantic
dark surface; selected rows use existing amendment teal at 10% and a 1.5 pt border.
No animation is introduced by the workspace toggle. Arm deliberately differs from
enabled Figma examples per the owner's AP-11 deferral.

## Before implementation

Inspected live baseline on iPad Pro 11-inch (M5), iOS 27.2, 834 × 1210 portrait
(available device height differs from the 834 × 1194 design). Full-width portrait map
frame was `(0,96,834,806)` before/open/closed. Timer continued 00:54 → 01:02 → 01:15.
Landscape with sidebar had map `(280,32,560,782)` unchanged through the toggle;
the old legend overlapped lower header metadata. The old timing strip was dark and
the pencil used separate pause/resume controls. Review-specific extent overrides
exist in source and require removal for the populated state.

Baseline artifacts: Xcode ActionArtifacts session `C24CE27C-A2FC-42CB-A543-5FFAACF47750`,
DeviceInteractionSynthesize `Amendment Workspace Baseline-09_53_41_854`,
`09_53_49_451`, `09_54_03_327` (portrait regular/open/closed), and
`09_52_55_128`, `09_53_04_150`, `09_53_18_810` (landscape with sidebar).

## Validation

Implementation ready for human visual review, **not accepted or complete**. No issue
checkbox is checked by this report. Reduce Motion runtime evidence is still missing.

### Automated verification

- Xcode BuildProject, including test targets: passed, 2026-11-24 10:57:34.
- [237 focused Swift Testing results](../assets/ap-01/unit-summary.txt): all passed.
  Covers Cockpit feature/domain behavior, recovery, resting layout and amendment estimates.
  New cases cover untouched/edited toggles, retained editor/selection, plotting reset,
  failed-save reopening, lifecycle projection and existing geometry Undo from review.
- iPhone 16 Pro / iOS 27.2 / 402 × 874: six focused UI checks passed, then
  [final portrait/Larger Text rerun](../assets/ap-01/iphone-final-summary.txt):
  two passed, Reduce Motion prerequisite skipped. Pending management and existing
  Manual Check-unavailable behavior passed in the six-test run.
- iPad 11-inch fourth generation / iOS 27.2 / 834 × 1194 and 1194 × 834:
  portrait, landscape, Larger Text and lifecycle checks passed. The
  [additional run](../assets/ap-01/ipad-additional-summary.txt) passed six checks
  (VoiceOver speech, stale departure recovery, unsaved, incomplete, untouched and
  landscape); its Reduce Motion prerequisite failed. The
  [final Larger Text rerun](../assets/ap-01/ipad-larger-text-final-summary.txt) passed.
- Boundary tests assert exact equality (0 pt tolerance) of the map accessibility
  frame before/open/editor/closed/reopened, with the same Flight/window/settings.
  Operational Identify/Reach controls remain reachable after closing. Domain tests
  assert unchanged Flight state; baseline live interaction observed timer continuity.
- Existing legacy UI helpers that require preparation arming explicitly skip with
  an AP-11 explanation. Arm is deliberately disabled by owner instruction; engine,
  activation and pending-management tests remain active. This is not a full-suite pass.
- `git diff --check`: passed before commit.

### Retained rendered comparisons

All images are raw full-resolution simulator captures; [manifest](../assets/ap-01/manifest.json)
records test, simulator, time, original attachment name and SHA-256. The implementing
agent directly inspected the referenced renders and the authoritative Figma context
and reference screenshots. These are bounded visual judgments, not pixel-diff passes.

| State / criterion | Authoritative reference | Simulator evidence | Outcome |
| --- | --- | --- | --- |
| None open/closed; untouched exit | D02 [13:639](https://www.figma.com/design/JCyQhDDzCPfrrbv6SBcwKw?node-id=13-639), G01 | [Open](../assets/ap-01/ipad-ap01-none-open.png), [closed](../assets/ap-01/ipad-ap01-none-closed.png) | Matched absence of a lifecycle badge and independent highlight; objective exit/plot-off tests pass; human visual approval pending |
| Incomplete open/closed | D02 13:639, G01 | [Open](../assets/ap-01/ipad-ap01-incomplete-open.png), [closed](../assets/ap-01/ipad-ap01-incomplete-closed.png) | Matched orange lower badge independent of highlight; retained draft/no-discard tests pass; human approval pending |
| Ready portrait / retained editor | D03 [29:883](https://www.figma.com/design/JCyQhDDzCPfrrbv6SBcwKw?node-id=29-883), G06 | [Open](../assets/ap-01/ipad-ap01-open-portrait.png), [editor](../assets/ap-01/ipad-ap01-editor-portrait.png), [closed](../assets/ap-01/ipad-ap01-closed-portrait.png) | Matched light strip, fixed actions and internally clipped/scrolling rows; native metrics and fixture variations below; legacy editor deliberately retained until AP-04/05 |
| Compact Ready / modal / closed | D03 [29:1238](https://www.figma.com/design/JCyQhDDzCPfrrbv6SBcwKw?node-id=29-1238), G06 | [Open](../assets/ap-01/iphone-ap01-open-portrait.png), [editor](../assets/ap-01/iphone-ap01-editor-portrait.png), [closed](../assets/ap-01/iphone-ap01-closed-portrait.png) | Matched shell hierarchy and stable boundary; all three values remain available through list scrolling; human approval pending |
| Landscape Ready / modal / closed | D03 [29:1167](https://www.figma.com/design/JCyQhDDzCPfrrbv6SBcwKw?node-id=29-1167), G06 | [Open](../assets/ap-01/ipad-ap01-open-landscape.png), [editor](../assets/ap-01/ipad-ap01-editor-landscape.png), [closed](../assets/ap-01/ipad-ap01-closed-landscape.png) | Matched 370 pt rail policy, fixed footer and light strip; legacy Back to drawing retained until AP-02; human approval pending |
| Armed / awaiting Manual Start / Flying | D02 13:639, G01/G07 | [Armed](../assets/ap-01/ipad-ap01-armed.png), [awaiting Start](../assets/ap-01/ipad-ap01-awaiting-start-leg.png), [Flying](../assets/ap-01/ipad-ap01-flying.png) | Matched grey/grey/green pencil progression; UI/domain tests pass. Accepted-amendment inspection commands belong to AP-12 |
| Ready plus failed save, open/closed | D02 13:639 independent unsaved rule | [Open](../assets/ap-01/ipad-ap01-ready-unsaved-open.png), [closed](../assets/ap-01/ipad-ap01-ready-unsaved-closed.png) | Matched independent upper orange dot with Ready lower badge; legacy save panel retained. No draft disk recovery claim (AP-09) |
| Ordinary Cockpit preserved | Owner-approved regular-Cockpit limitation in D03; contextual 29:989 excluded | [Before](../assets/ap-01/ipad-ap01-before-portrait.png), [closed](../assets/ap-01/ipad-ap01-closed-portrait.png); [iPhone before](../assets/ap-01/iphone-ap01-before-portrait.png), [closed](../assets/ap-01/iphone-ap01-closed-portrait.png) | Bounded comparison matches existing instruments/actions/spacing; only pencil highlight changes in same-data pair. No regular-Cockpit redesign |
| Larger Text | D03 adaptive wrapping/scrolling rule | [iPad](../assets/ap-01/ipad-larger-text-ap01-open-portrait.png), [iPhone](../assets/ap-01/iphone-larger-text-ap01-open-portrait.png), corresponding editor/closed captures in manifest | Partial: boundary/actions and opening the modal pass in tests; timing and legend horizontally scroll. At maximum size iPhone header wraps/truncates, initial list viewport is occupied by scrolling heading, and retained legacy modal shows very little entry content. Full field reachability and visual ergonomics remain unverified, not declared matched |
| VoiceOver | D02 13:639 spoken status; shared native accessibility rules | [Retained speech](../assets/ap-01/ipad-manual-amendment-voiceover-speech.txt), lifecycle UI assertions | Field-order test passed. Pencil labels/value assertions passed; no claim of a complete accessibility audit |
| Reduce Motion | G06 / shared accessibility contract | [Settings ON](../assets/ap-01/reduce-motion-settings.png), [hierarchy](../assets/ap-01/reduce-motion-settings-hierarchy.txt) | **Unverified app interaction**: Settings value 1, runner reports disabled; device activation failed. No new workspace animation is introduced, but source inspection does not establish runtime conformance |

### Scope, differences and limitations

The fixture uses disposable imported route data, 46% departure, three manual values
087°/03:20, 176°/02:15, 024°/04:10 and an injected display-only elapsed time of
07:22. Its actual first leg is Kadima → Ramat, planned 04:17, rejoin West; the
illustrative design has leg 2 of 5, 04:23 and rejoin Aviel. Geographic/chart values
are illustrative per D03, but this variation prevents a same-content pixel-match
claim. Production Flight timing and navigation timestamps are not injected.

The approved baseline console extents remain 288/278/370 pt. Actual map extents
include runtime safe areas and the existing compact operational Reach adjustment,
applied equally in both modes. Insets/rows use the contract values above; native
text/button metrics can exceed minimum dimensions. No tolerance was invented for
unmeasured styling. Light surface/teal selection and badge comparisons are direct
visual judgments awaiting owner acceptance.

Arm has no callback/effect and remains disabled until AP-11 (#235), per explicit
owner clarification. Existing route operations, entry panels, Check and replacement
confirmation are reused. New plotting semantics (AP-02), independent wheels
(AP-04/05), full history (AP-07), disk recovery (AP-09), arming (AP-11) and accepted
inspection/disarm (AP-12) are outside this slice.

Xcode reported “Modifying state during view update, this will cause undefined
behavior” during Larger Text tests, including the final iPad run. The test passed,
but the warning is unresolved and this report does not claim warning-free runtime
validation. The existing regular header and map-label overlap at maximum text size
remain visible in retained evidence; changing protected Cockpit regions requires
separate scope/owner direction.

All five issue acceptance criteria remain unchecked pending human visual approval;
Reduce Motion and the noted Larger Text concerns also block acceptance. PR creation
is a review handoff, not issue closure. No merge or closure is requested here.


## Follow-up: visible portrait boundary (owner screenshots, 2026-11-24)

The earlier map-frame equality checks missed regular-console background overflow.
The regular portrait panel's intrinsic content is slightly taller than its fixed
288 pt allocation; its background painted above that allocation while the amendment
panel stayed inside it. The map itself did not resize. This produced a visible
8.5 pt shift on the reference iPad and invalidated the earlier visual-boundary claim.

`CockpitView` now clips the regular portrait console to its existing allocation.
Control geometry, spacing and resting-layout policy are unchanged; the background
can no longer cover the bottom of the map. This is scoped containment of the shared
boundary, not a redesign of regular Cockpit.

Measured raw 1668 × 2388 captures at x = 5 px: before the fix, the ordinary white
console started at y = 1755 px while amendment started at y = 1772 px. After the
fix both start at y = 1772 px (886 pt, delta 0). The old render is retained as
[before containment](../assets/ap-01/ipad-before-background-containment-fix.png).
The portrait before/open/editor/closed links above now point to corrected captures
from the 11:31 run; their manifest provenance and hashes were refreshed. The
implementing agent inspected the corrected ordinary/open pair directly against the
D03 shared-boundary rule (29:883 plus the existing-Cockpit preservation rule).

Xcode build including tests passed at 11:31. The focused iPad workspace-toggle UI
test passed, then passed again with an added rendered-pixel regression at 11:39:
[summary](../assets/ap-01/ipad-rendered-boundary-regression-summary.txt). The new
assertion compares the deterministic chart edge 2 pt above the map boundary with
the console edge 2 pt below in both modes (maximum RGB-channel difference > 12/255). This supplements,
rather than replaces, exact map-frame equality assertions. `git diff --check` passed.
Other outstanding acceptance limitations above remain unchanged.


## Review follow-up

[R1/R2 remediation record](ap-01-review-remediation.md): R1 is owner-deferred;
R2's manual-camera preservation is corrected and verified on regular-text iPhone
Pro and iPad portrait/landscape. Historical results above are retained as recorded.
