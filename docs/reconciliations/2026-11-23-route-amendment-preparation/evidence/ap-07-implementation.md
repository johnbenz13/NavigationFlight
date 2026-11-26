# AP-07 implementation and evidence

Issue: [#231](https://github.com/johnbenz13/NavigationFlight/issues/231).
Branch: `feature/correct-route-points-and-undo`, synchronized main baseline.
Readiness: #229 closed through #247, merge `8942869` is on origin/main.
Baseline: `27a22f44962bb2db616d0ebc3a64829454673dab`.
Checkpoint: implementation ready for final delivery; human visual acceptance remains pending.
Owner scope and presentation decisions are recorded below. No acceptance is inferred.

Owner clarification in implementation conversation: use D04 drag; long press and
release without dragging offers Delete. Do not retain the F02 persistent point
card. Named Move/Delete alternatives remain in Map tools.

## Acceptance matrix and visual contract

All references use Figma file `JCyQhDDzCPfrrbv6SBcwKw`. D04 `48:565`
owns gestures, recovery and native actions; `48:409` owns direct-drawing state.
D03 `29:883`, `29:1167`, `29:1238` own portrait/landscape/compact shell.
F02 `11:245` owns changed adjacent rows, superseded point-card presentation above;
F03 `13:595` owns occurrence/order validation. Named corrections use native alerts;
direct Delete adapts from popover to alert at accessibility sizes.
Retain existing SF typography, semantic surfaces, teal proposed geometry, 44 pt
minimum touch targets and shared resting layout (288 pt portrait, 370 pt rail,
278 pt compact). No amendment-specific viewport resizing. Geometry is geographic,
not copied from illustrative Figma coordinates.

| Criterion/state | Reproduction and authority | Evidence/status |
| --- | --- | --- |
| Drag via/departure/rejoin; release Delete; cancel | A complete + B occurrences; D04 item 4/native dialog | Domain and regular-size iPad/iPhone touch checks passed; [point-anchored Delete](../assets/ap-07/held-marker-final/released-delete.png), [enlarged hold](../assets/ap-07/held-marker-final/held.png). Maximum-text phone direct drag is excluded by explicit owner decision. Human visual approval pending. |
| Only changed adjacent Manual headings/time clear | A distinct entries/cues; move first/middle/last via; F02 rows | Three-index domain cases and portrait/landscape/Larger Text UI passed. |
| Surviving cues retained; removed/merged edges empty | A correction and deletion; G02/shared edge contract | Domain lossless cue assertions and portrait cue editor verification passed. |
| Complete Undo incl. partial fields and selection | Edit/correct/Undo/re-edit/Undo; shared snapshot contract | Domain snapshots and UI exact-value comparisons passed; [restored](../assets/ap-07/ipad-reference/delete-undone-screenshot.png). |
| Invalid edit atomic; operational Flight unchanged | Invalid anchor order/completed/free drop, duplicate via; F03/D04 | Domain isolation/order/canonical-occurrence tests and real invalid anchor drops passed. |
| Delete/replace departure; delete/rejoin recovery | A anchors independently removed; D04 recovery | iPad, 402 pt and 390 pt phones passed deletion, incomplete state, replacement and both Undo paths; maximum-text iPad/phone named recovery also passed. |
| Named Map tools Move/Delete and placement | A route/map-center input; D04 accessible pattern | Final native alerts and semantic Move passed on all reference layouts/390 pt phone; actual iPad/phone VoiceOver passed. [Final native actions](../assets/ap-07/ipad-named-final/6786F0FB-3906-4A62-AD38-1DA9308EBFE9.png), [final speech](../assets/ap-07/ipad-named-final/voiceover-speech.txt). |

Coverage: reference iPad portrait first, iPad landscape, iPhone 16 Pro portrait;
secondary supported compact width; Larger Text, VoiceOver, Reduce Motion. iPhone
landscape, Flight Undo/history, Assisted recalculation and active route editing
are excluded by AP-07. Arm remains under AP-11; missing anchors must stay unready.
Human visual acceptance remains pending independently of automated results.

## Verification ledger

| Revision / check | Device, fixture, settings | Result / retained artifact |
| --- | --- | --- |
| Pre-edit readiness | Clean synchronized main; blocker ancestry | Passed |
| Pre-edit design retrieval | D04, F02, F03, D03 portrait | Retrieved; owner resolved point-card ambiguity |
| Pre-edit app render | UIEvidence-iPad, A, 834×1210 | Build/install passed; implementing agent inspected retained baseline screenshot (`Issue 231 Pre Edit Baseline-11_46_17_499`) beside D04. This newer iPad is additional coverage, not the 834×1194 reference. |
| 11:49 focused domain | 3 via indices + 2 anchors, deterministic partial fields/cues | 5/5 passed; `RunSomeTests/Test-NavigationFlight-2026.11.26_11-49-45-+0200.xcresult` |
| 11:52 first UI | UIEvidence-iPad, A + distinct cues | Drag/selective clearing/Undo cue checks and Delete/cancel passed before deletion assertion failed. Export recovered from original result after documented TestReport permission error; no export-driven rerun. |
| 12:00 diagnosis UI | Same device/fixture | 2 failures: Map tools drawing-only gate hid input after rejoin; Delete dismissed but did not commit. Semantic row query plus directly inspected screenshot disproved initial row-order hypothesis. Stable native dialog presentation data fixed Delete. |
| 12:05 compiler | Current test helper | Duplicate helper declaration found and removed; subsequent build passed. |
| 12:06 focused UI | UIEvidence-iPad, A + distinct cues | Drag/Delete/cancel/Undo **passed**. Map tools input now reachable; named-menu activation still under diagnosis. Original `Test-NavigationFlight-2026.11.26_12-06-28-+0200.xcresult`. [Retained captures and provenance](../assets/ap-07/ipad-m5-portrait/). |
| 12:12 compiler diagnostics | Draft, console, map adapter, UI tests | No errors. UI test file retains 2 unrelated pre-existing unused-local warnings. |
| 12:12 named-menu diagnosis | Exact 834×1194 iPad; hierarchy and direct taps | Full-row AX center did nothing twice; nested text hit opened native Move/Delete. Menu label now fills the row with a rectangular touch shape. Native action rows use platform-supplied geometry. |
| 12:13 domain regression | `NavigationFlightTests` suite, including 6 new correction cases | **224/224 passed**, no failures/skips. Original `Test-NavigationFlight-2026.11.26_12-13-08-+0200.xcresult`; reused while domain inputs remain unchanged. |
| 12:18 reference iPad batch | 834×1194 / 1194×834, A, maximum Larger Text, actual VoiceOver | **6/6 passed**: new progress/occurrence domain case, anchor drag rollback/Undo, named anchor recovery, VoiceOver, landscape, Larger Text correction. Original `Test-NavigationFlight-2026.11.26_12-18-54-+0200.xcresult`; [landscape](../assets/ap-07/landscape/), [anchor drops](../assets/ap-07/ipad-anchor/), [Map tools](../assets/ap-07/ipad-tools/), [actual speech](../assets/ap-07/ipad-voiceover/2295F540-FF92-421C-818F-0CAAC3A96E66.txt). Larger Text screenshot inspection subsequently exposed the native offer clipping below; its presentation check is superseded by the final rerun. |
| 12:13–12:16 direct touch | Exact reference iPad, A, actual Settings Reduce Motion ON | Move, release Delete, outside cancel, deletion and both Undo paths passed. [Captures/hierarchies/provenance](../assets/ap-07/ipad-reference/); Settings restored OFF. One reinstall followed concurrent Xcode testing replacing the debugger session; isolated verification had no reproduced app crash. |
| 12:24 phone batch | Reference iPhone 402×874, A/B, regular/max text, actual VoiceOver | 3 passed (anchor drag, regular Map tools recovery, deliberate rejoin); 5 failed. [Original summary](../assets/ap-07/phone-initial-summary.txt). Diagnoses: max readiness text uses capitalized `Incomplete`; VoiceOver initially focuses Move (forward-only sampling skipped it); existing 44 pt overlap target reports `43.99999999999997`; maximum-text direct drag hits the existing header; regular second-offer Delete dismissed without changing the draft, still under diagnosis. |
| 12:34 rendered max-text diagnosis | Original iPad/phone captures and original phone video | Native iPad Delete popover clips its action; changed to native alert at accessibility sizes and added alert/44 pt assertions. Phone header/legend hides map points: owner scope clarification requested because AP07 excludes regular Cockpit layout changes. No maximum-text direct-drag pass claimed (subsequently excluded explicitly by owner). |
| 12:44 build | Current alert adaptation and focused test fixes | Build including tests passed in 20.3 sec, no errors. `BuildProject-Log-20261126-124443.txt`. |
| 12:44 focused phone rerun | Regular Delete sequence, actual VoiceOver, max Map tools, overlap short tap | 2 passed (VoiceOver, overlap); 2 failed. Added second-offer capture did not resolve regular Delete, disproving capture/settlement delay as a sufficient explanation. Maximum Map tools progressed through deletion/replacement, then failed to find a lazily materialized later correction row. Shared waypoint reveal logic now serves named corrections too. Original `Test-NavigationFlight-2026.11.26_12-44-50-+0200.xcresult`. |
| 12:51 diagnostic build | Temporary DEBUG fixture-only deletion intent logging; shared input-list reveal | Build including tests passed, no errors, 8.1 sec. Logging will be removed after diagnosis. |
| 12:51 application trace | Original app stdout recovered via `xcresulttool export diagnostics` | Delete reaches the draft in drawing, panel nil, not paused; row query follows about 2 ms later. [Narrow trace](../assets/ap-07/phone-delete-diagnostic-trace.txt). Added rendered row-count expectation and native sheet-dismissal checks; diagnostic logging removed. No regular Delete behavior change was needed. |
| 12:57 phone confirmation | Regular correction + maximum-text named actions | Regular drag/Delete/cancel/Undo **passed** with the rendered-state wait. [Directly inspected captures](../assets/ap-07/phone-correction-pass/). Maximum-text Move still left its menu/sheet visible after tapping its reported native target; this is distinct from the prior lazy-row issue. |
| 13:04 build | Adaptive native alerts for new correction actions at accessibility text sizes | Build including tests passed, 23.5 sec, no errors. Regular native menus retained. Maximum-text alert interactions require final verification. |
| 13:04 max phone iteration | New native correction alert | Deletion/replacement passed; immediate post-Undo row query failed. Shared correction Undo helper now waits for changed rendered row contents, preserving exact final value assertions. |
| 13:07 final max phone | Maximum Larger Text, fixture A with distinct cues | **Passed**: named Delete/replacement of both anchors, Move/next eligible waypoint, all Undo/value checks. [Native alert and restored state captures](../assets/ap-07/phone-max-pass/) directly inspected: Move/Delete/Cancel readable and operable; baseline header/legend clipping remains. `Test-NavigationFlight-2026.11.26_13-07-05-+0200.xcresult`. |
| 13:09 final max iPad | Reference iPad, maximum Larger Text | **2/2 passed**: real drag, native Delete alert/cancel/Undo; named anchor recovery and Move/Undo. [Delete alert/restored](../assets/ap-07/ipad-max-final/), [named action alert/restored](../assets/ap-07/ipad-tools-max-final/) directly inspected. Labels/actions fit; underlying existing legend/timing clipping remains. `Test-NavigationFlight-2026.11.26_13-09-58-+0200.xcresult`. |
| 13:16 live handoff | Actual primary iPad, regular text, disposable fixture A/cues | Final production build installed and process verified; DeviceHub opened. [Ready screen](../assets/ap-07/handoff/primary-ready.png) inspected. [Exact build/process/device metadata](../assets/ap-07/handoff/provenance.json). Start leg → dismiss checklist if shown → pencil opens the candidate. Preview left running, separate from test clones. |
| 13:14 narrower compact | iPhone 17e, 390×844, regular text | Anchor drag/rejection/Undo passed. Native Rejoin/Delete menu remained open after tapping its reported action, reproducing the native-menu issue beyond maximum text. Incomplete ActionArtifacts result export recovered from intact DerivedData original, without a rerun. Named choices now use native alerts at all sizes under D04's approved native action-list pattern. |
| 13:21 compiler | Uniform native alert for named corrections | Build including tests passed in 6.8 sec, no errors. Final regular-size checks and live preview refresh are recorded below; maximum-text alert paths remain unchanged. |
| 13:23 final narrower compact | iPhone 17e, 390×844 | Named correction recovery/Move/Undo passed with uniform native alert. [Summary](../assets/ap-07/narrow-final-summary.txt), [captures](../assets/ap-07/narrow-alert-pass/). |
| 13:24 final reference phone | iPhone 16 Pro | Named recovery and actual VoiceOver **2/2 passed**. [Summary](../assets/ap-07/phone-named-final-summary.txt). |
| 13:30 final reference iPad | 834×1194 | Named recovery and actual VoiceOver **2/2 passed**. [Summary](../assets/ap-07/ipad-named-final-summary.txt), [native actions and speech](../assets/ap-07/ipad-named-final/). |
| 13:35 live preview refresh | Actual primary iPad | Final 13:21 production build running with disposable fixture, normal text, Reduce Motion OFF. Retained Ready screenshot and provenance refreshed. Start leg → dismiss checklist if shown → pencil. |
| 13:38 landscape fixture diagnosis | 1194×834 | Immediate pencil tap after rotation missed; capture showed ordinary Cockpit, so no amendment inputs existed. Shared workspace entry now waits for landscape geometry and amendment console; no production change. Build passed in 5.1 sec. |
| 13:41 final landscape named actions | 1194×834 | **1/1 passed**. [Summary](../assets/ap-07/landscape-tools-final-summary.txt), [native actions/restored values](../assets/ap-07/landscape-tools-final/) inspected against D04 item 4 and D03 29:1167: readable native choices, existing right rail and exact restored values. |
| 14:02 final presentation build | Point-anchored native Delete + immediate held marker | Build including tests passed, 21.4 sec, no errors. Domain validator/snapshots and named action paths unchanged. |
| 14:02–14:07 final iPad gestures | 834×1194, 1194×834, maximum iPad text | **3/3 passed**: drag, release offer, cancellation, deletion, exact-value/cue Undo. [Summary](../assets/ap-07/anchored-ipad-summary.txt), [portrait](../assets/ap-07/anchored-delete-portrait/), [landscape](../assets/ap-07/anchored-delete-landscape/). [Native alert at maximum text](../assets/ap-07/anchored-delete-ipad-max/) remains readable. |
| 14:06 rendered pickup + point anchor | Primary iPad, real 3 sec long press | [Held frame](../assets/ap-07/held-marker-final/held.png) shows 30 pt marker versus resting 10 pt; [released offer](../assets/ap-07/held-marker-final/released-delete.png) points at Point 1, not console. Video seconds12/14; [provenance](../assets/ap-07/held-marker-final/provenance.json). Compared to D04 item4 plus explicit owner 13:55 correction. Human approval pending. |
| 14:06 Reduce Motion | Actual primary Settings ON then restored OFF | Static pickup and anchored offer verified ON; Delete target 256×48 pt; outside cancellation leaves all 3 legs. [Captures/hierarchies](../assets/ap-07/held-marker-final/). |

| 14:10 final iPhone Pro | 402×874, normal text | Direct drag/Delete/cancel/Undo **passed**; maximum-text direct gesture test **explicitly skipped** before launch under owner exclusion. [Summary](../assets/ap-07/anchored-phone-summary.txt), [native offer/restored values](../assets/ap-07/anchored-delete-phone/) inspected against D03 compact and D04 native adaptation. No failed assertion counted as passing. |
| Final checkpoint | Current source and documentation | Build14:02 passed, phone run recompiled final test guard; `git diff --check` and all4 changed Markdown documents' local links passed. Domain224+1 checks and unaffected named-action/VoiceOver results reused as above. Retained raw source patches contain unified-diff blank context lines; the existing AP06 scoped whitespace attribute is repeated for AP07 so provenance bytes remain unchanged. Live primary iPad uses14:02 build, process6562, clean amendment ready for owner review. |

All originals above remain under the Xcode ActionArtifacts `RunSomeTests` directory
for action `98CE93E2-ACA4-4ADF-8599-1DCACF428B5D`. Exports record original hashes,
device/test identity, attachment names and export-time source patches. Domain inputs are unchanged across the final passing checks. The 14:02
point-anchored offer/pickup-feedback change supersedes older direct Delete
presentation captures, while named actions and domain checks remain valid. The additional domain case passes on top of the reused 224.

Direct comparison: D04 [48:565](https://www.figma.com/design/JCyQhDDzCPfrrbv6SBcwKw?node-id=48-565)
item 4 governs the native Delete offer and named correction actions. F02
[11:245](https://www.figma.com/design/JCyQhDDzCPfrrbv6SBcwKw?node-id=11-245)
governs changed adjacent rows, with its persistent card superseded by the owner's
D04 decision. Reference iPad portrait captures show changed rows empty and Undo
restoring exact values; missing-anchor states retain unaffected rows. D03
[29:883](https://www.figma.com/design/JCyQhDDzCPfrrbv6SBcwKw?node-id=29-883)
uses a 288 pt console base: observed map `{0,96,834,790}` ends at y886, current-leg
strip `{20,886,794,60}`, scroll viewport `{20,998,794,128}`. The 20 pt native safe-area
adaptation differs from the illustrative y906 boundary; no new correction-driven
resize occurs (UI asserts exact before/after frame equality, tolerance 0 pt).
Initial named rows were 548×74 and direct native Delete 256×48. Intermediate
system context-menu actions measured 224×38; these are superseded by native
alerts for named choices. Final tests assert at least 44 pt action heights.

Landscape captures were directly inspected against D03
[29:1167](https://www.figma.com/design/JCyQhDDzCPfrrbv6SBcwKw?node-id=29-1167):
the existing 370 pt right rail, operational strip, separate value rows and fixed
Undo remain. Move, Delete offer, merged empty edge and exact-value Undo are visible.
Regular typography/surfaces/teal geometry are consistent by bounded visual
inspection; this is not a pixel identity claim for geographic chart content.

Maximum Larger Text correction interactions pass, including Delete/Undo. The
existing oversized map labels overlap and the legend/timing status clip. The same
legend/timing clipping is visible in the retained pre-AP07
[AP03 Larger Text capture](../assets/ap-03/d04/Route%20amendment%20-%20d04-rejoined-larger-portrait.png).
No map-label, legend or timing layout code is changed here. This remains a visible
baseline limitation, not a full accessibility conformance claim or a new deferral.
The new correction controls receive their own Larger Text and VoiceOver checks.

Phone anchor/recovery captures were directly inspected against D03
[29:1238](https://www.figma.com/design/JCyQhDDzCPfrrbv6SBcwKw?node-id=29-1238)
and F03 [13:595](https://www.figma.com/design/JCyQhDDzCPfrrbv6SBcwKw?node-id=13-595):
[invalid/valid anchor drags](../assets/ap-07/phone-anchor/) preserve or clear the
expected rows; [missing-anchor and restored states](../assets/ap-07/phone-tools/)
retain unaffected entries and keep recovery input available. Existing compact
console scrolling remains necessary to see all three rows. No correction-driven
map/console resizing is introduced. Human visual acceptance remains pending.

**Owner decision (2026-11-26, 13:55):** maximum accessibility text on small iPhone
cockpit screens is excluded. Prior obstruction [snapshot](../assets/ap-07/phone-max-diagnosis/map-obscured.png)
is retained as the diagnosed baseline, not a passing gesture. Normal iPhone Pro and
iPad remain covered. `AGENTS.md` records this support boundary; the direct maximum-text
phone test has an explicit owner-decision skip. Existing maximum-text named-action
checks remain useful supplementary evidence.

The owner also rejected the console-anchored native Delete screenshot and required
its arrow at the selected map point, plus an enlarged held/draggable marker. Prior
Delete placement screenshots are superseded. The map coordinator now anchors the
native offer using the projected point rectangle; the overlay uses an immediate
15 pt held radius without animation. Final verification is recorded below.

Passing 12:06 portrait states were directly inspected: moved Point 1 clears rows
1–2, deleted Point 1 produces an empty merged edge while 024°/04:10 survives, and
Undo restores 087°/03:20, 176°/02:15, 024°/04:10. D04 item 4's native Delete popover
is visible without an F02 persistent card. Geometry remains at the baseline map/
console boundary; the fixture's geographic chart/route differs from illustrative
Figma content. Human visual approval remains pending; final comparisons and measurements are recorded above.

## Effort and reruns

Approximate active effort: exploration/authority 15 min; implementation 20 min;
diagnosis and fixture/tool repairs 40 min; device/test verification 60 min;
evidence and delivery 15 min (about 2.5 hours, excluding owner waiting).

Avoidable reruns: initial full-editor cue scrolling (~4 min); duplicate helper
compiler failure; immediate post-Delete/Undo queries, initial VoiceOver focus,
case-sensitive readiness, floating-point 44 pt comparison, lazy-list materialization,
and rotation-entry timing. The final phone maximum-text skip was initially placed
after fixture setup, which entered the excluded layout before skipping; that run
was stopped and the guard moved before launch. Native presentation defects were
application fixes, verified after diagnosis. One delegated manual diagnosis
waited ~7 min for tool approval without a result. Evidence export permission and
incomplete-copy recovery used original bundles and caused no test reruns.
