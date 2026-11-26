# AP-08 Assisted preparation — acceptance and verification

Issue: [#232](https://github.com/johnbenz13/NavigationFlight/issues/232).
Base: `b093fc9fea6143e0ada5001857abe2e9f2d21551`; prerequisite #231 closed
through merged PR #249, merge verified in synchronized `main`.

## Authority and owner decision

G03/G06, RA-03/06/09/10/14 and the shared preparation contract govern behavior.
D03 owns geometry; D04 supersedes drawing/correction interactions. The approved
D05.2 [main screen](https://www.figma.com/design/JCyQhDDzCPfrrbv6SBcwKw?node-id=67-146)
and [gesture rules](https://www.figma.com/design/JCyQhDDzCPfrrbv6SBcwKw?node-id=67-554)
supersede D03's heading wheel and time ceiling: reuse the existing compass and
cyclic 00–59 time controls, with new durations 1–3599 seconds. Both current
references were retrieved and their renders directly inspected during this slice.
Regular
Cockpit, flying Assisted, estimator math, weather, wind selection and ruler are excluded.
On 2026-11-26 John approved reusing F06's secondary row text style for
**Estimates updated** on recalculated Assisted legs. Undo restores the previous
values and labels/provenance. This approves that design treatment; implementation
acceptance remains separate.

## Compact acceptance matrix

| Criterion/state | Observable result and next interaction | Fixture | Authority / verification |
| --- | --- | --- | --- |
| Captured mode | Settings initially Manual; existing draft retains its mode after Settings changes; next draft uses new setting | D, disposable Flight | RA-09; domain/settings and UI |
| Available / missing estimates | Formed Assisted legs prefill usable estimates; missing inputs leave required entries Not set; deliberate overrides survive Done/reopen | D no-wind available/unavailable; domain planned-wind | G03; F06 [11:591](https://www.figma.com/design/JCyQhDDzCPfrrbv6SBcwKw?node-id=11-591), F05 [12:503](https://www.figma.com/design/JCyQhDDzCPfrrbv6SBcwKw?node-id=12-503) |
| Duration / drift | 02:15 → 03:00 changes exact minute fractions; drift off removes arms but keeps marks | D, Manual/Assisted × on/off | RA-06/14; F06; projection tests and screenshots |
| Geometry / Undo | Moving Point 1 recalculates only adjacent legs, shows Estimates updated; third leg unchanged; Undo restores exact partial values, cues and provenance | D, move/invalid move/cancel/Undo | G02/G03; owner decision above; deterministic and UI |
| Manual / operational preservation | Manual has neither aid after Check; original aids, map boundary/camera and operational Flight unchanged | A/D Manual | RA-06; regression tests, simulator |

Primary iPad portrait 834×1194; secondary iPad landscape 1194×834, iPhone Pro
portrait 402×874 and another supported compact width. iPhone landscape and maximum
accessibility text on small iPhones are excluded by the supported cockpit contract.
Changed controls require supported Larger Text, actual VoiceOver, Reduce Motion,
legibility/contrast and ≥44 pt targets. D03 [29:883](https://www.figma.com/design/JCyQhDDzCPfrrbv6SBcwKw?node-id=29-883)
and its landscape/compact/editor references govern adaptive geometry.

Fixture D reuses the shared crossing-plan/`A` workspace geometry with
`NAVIGATION_FLIGHT_UI_TEST_ASSISTED=1`; it does not hardcode Figma's illustrative
estimated values. The unavailable variant reuses the complete existing Manual
input transform (planning airspeed and matching execution ground speeds).

## Verification ledger

| Revision / check | Fixture/device/settings | Result / artifact |
| --- | --- | --- |
| Base preflight | Clean checkout; fetched origin; ff-only main; refs 0/0 | Passed; feature branch created at base above |
| Initial baseline launch | UIEvidence-iPad, portrait, disposable crossing A | Build/launch passed (~29 sec); ordinary Cockpit captured; amendment not yet opened. No conformance claim |
| Design inspection | F06 11:591, F05 12:503, D03 29:883, F02 11:245 | Retrieved design context and directly inspected renders; missing recalculation label resolved by explicit owner decision above |
| Pre-edit workspace | UIEvidence-iPad, 834×1210 runtime screen, A Manual | Directly inspected screenshot `Issue 232 Workspace Baseline-17_48_28_105-screenshot.png` under ActionArtifacts action `204A6E7F-7A38-4388-9F23-E9B67568FC62`; D03 shared console, scrolling third row, fixed actions retained. One avoidable fixture relaunch reused an old disposable library; fresh UUID resolved it |
| 17:52 build | Initial production implementation plus initial tests | Xcode BuildProject including tests passed, 46.6 sec, no errors; log `BuildProject-Log-20261126-175225.txt` |
| 17:52 focused domain | No-wind prefill, selective geometry, override/Undo, saved metadata, unavailable/range, both map modes | 4/4 passed; original `Test-NavigationFlight-2026.11.26_17-52-37-+0200.xcresult` |
| 17:54 initial UI | Primary iPad; prefill → 02:15 → 03:00 | New assertion used visual readout text instead of existing accessibility label. Fixture/test defect, corrected expectation; app unchanged. Two early renders recovered from original result without rerun |
| 17:56 primary UI | Primary iPad; override, drift off, move Point 1, Undo, pencil round trip | 1/1 passed; [six retained captures and provenance](../assets/ap-08/ipad-portrait/). Full source at export includes later test/doc additions; production source unchanged since 17:52. Original `Test-NavigationFlight-2026.11.26_17-56-55-+0200.xcresult` |
| Export recovery | Original 17:54 and 17:56 bundles | TestReport cache needed filesystem access; initial selector used output labels instead of required orientation. Correct selectors recovered original captures. No tests rerun for exports |
| 18:01 domain/settings regression | NavigationFlightTests, RouteAmendmentEstimateTests, SettingsTests; 187 selected test identifiers | 220 passed, one newly expanded archive fixture failed because Undo returns to drawing and accepted construction requires review. Added explicit review step; corrected case passed at 18:33. All 221 unique cases now pass across the retained runs |
| Interrupted adaptive batch | M5 iPad, planned landscape/Larger Text/unavailable/VoiceOver | Xcode cancelled execution while the live preview was being installed through the same workspace. No completed result bundle was retained; no checks from this batch are counted as passed. Avoidable coordination error: build/install and tests must run sequentially. Owner explicitly resumed work; unfinished checks rerun sequentially |
| 18:05 unobscured direct state | M5 iPad, prefilled → real Point 1 drag | [Original full-screen captures/hierarchies and provenance](../assets/ap-08/primary-direct/) directly inspected. Only legs 1–2 show Estimates updated. Map `{0,96,834,806}` and list viewport `{20,1014,794,128}` unchanged (0 pt transition tolerance). Rows 794×50, pencil 48×48 and Map tools 132×44. Existing footer AX bounds do not prove 44 pt targets and are not counted as passing |
| 18:33 resumed batch | M5 iPad landscape, maximum Larger Text, actual VoiceOver; corrected archive case and extended editor parity | 7 passed: archive/restore, no-wind/calm-wind/crosswind prefill+override (3), landscape, Larger Text and VoiceOver. Unavailable fixture failed at launch; its new transform changed planning speed without matching execution ground speed. Extracted the existing complete Manual transformation for both callers. Production code unchanged. [Summary](../assets/ap-08/adaptive-summary.txt) |
| 18:33 evidence recovery | Original DerivedData result; ActionArtifacts copy incomplete | [Landscape](../assets/ap-08/ipad-landscape/), [Larger Text](../assets/ap-08/ipad-larger-text/), [VoiceOver capture and actual speech](../assets/ap-08/ipad-voiceover/) exported without rerunning tests; original result retained under DerivedData/Logs/Test. Original filename `Test-NavigationFlight-2026.11.26_18-33-24-+0200.xcresult` |
| 18:46 iPhone Pro | AP01-iPhone-16-Pro, 402×874 portrait; available/override/move/Undo, unavailable/pilot entry, existing Manual Check regression | 3/3 passed, no skips; [summary](../assets/ap-08/iphone-summary.txt), [Assisted states](../assets/ap-08/iphone-pro/), [unavailable recovery](../assets/ap-08/iphone-unavailable/), [Manual after Check](../assets/ap-08/iphone-manual/). Original `Test-NavigationFlight-2026.11.26_18-46-27-+0200.xcresult` retained in DerivedData |
| 19:03 preview integration build | Debug, including tests; drag-preview drift visibility propagation | Passed, 15.2 sec, no errors; [summary and retained log path](../assets/ap-08/build-preview-summary.json). Passes the current drift visibility into the disposable held-drag presentation; direct verification covers the released path, with the held-capture limitation recorded below |
| Canonical iPad direct | AP01-iPad-11-Reference, 834×1194 portrait and 1194×834 landscape; fixture D available, working 03:00, drift Off, real move/Undo, Reduce Motion On | [Original full-screen captures, hierarchies and provenance](../assets/ap-08/canonical-ipad/) directly inspected: prefill/editor, saved 03:00, unobscured teal minute ticks with drift Off, adjacent updates and exact Undo; actual Settings On and update/Undo retained, then original Off restored |
| 19:15 removal edge | Final domain source; delete via → merged logical edge → Undo → archive restore | 1/1 passed; [summary](../assets/ap-08/removal-summary.txt). Source review found that merged edges need the update label despite their new ID. One initial compile attempt used fileprivate geometry in the new assertion; changed it to public endpoints, with no production workaround |
| 19:17 final build | Debug including tests, final removal and preview integration | Passed, 2.9 sec, no errors; [summary](../assets/ap-08/build-final-summary.json). Earlier successful checks remain valid for their unchanged paths; focused removal and final direct checks cover the additions |
| Compact launch recovery | iPhone 17e; first device run tracking failed with no compiler errors; subsequent shell install returned no output for 515.9 sec | Aborted stalled path. Switched Xcode's active destination to the session's iPhone 17e, used a fresh workspace session and Xcode InstallAndRun: launch passed in 13 sec. Target alignment resolved the failure; attributing the original tracking issue specifically to a mismatch remains an inference. No application workaround |
| 21:18 final compact | iPhone 17e, 390×844 portrait, final source | Prefill/editor, 02:03 override/Done, adjacent move updates and exact Undo passed; [original captures and provenance](../assets/ap-08/compact-direct/) directly inspected against D03-E/F, F06 and D05.2. Map 390×388, list 358×116.3, rows 358×66.7, pencil 48×48. Changed text remains readable and actions reachable |
| 21:20 final iPad / handoff | Exact primary iPad, final source, fresh Xcode install/run | [Merged-leg update](../assets/ap-08/canonical-ipad/final-delete-merged-screenshot.png) and [exact Undo / running preview](../assets/ap-08/canonical-ipad/final-undo-handoff-screenshot.png) directly inspected. Merged 007°/01:38 shows Estimates updated; unaffected 277°/01:11 retained; Undo restores three legs. Separate final provenance identifies the final build |

Landscape captures were directly inspected against D03-D [29:1167](https://www.figma.com/design/JCyQhDDzCPfrrbv6SBcwKw?node-id=29-1167)
and F06: existing right rail, separate values, readable secondary update/override
text, fixed actions, working-duration ticks and unobscured geometry/Undo are
retained. Maximum Larger Text wraps the changed status and keeps the editor
scrolling and Done reachable. The existing map-label overlap and legend/timing
clipping remain visible; this is not a full accessibility-conformance claim.
The runtime warning “Modifying state during view update” occurred at bootstrap,
before Start. The identical warning is retained on main in
[AP-07 maximum-iPad results](../assets/ap-07/ipad-max-final-summary.txt) and
[AP-07 final gesture results](../assets/ap-07/anchored-ipad-summary.txt).
No new production fix or unexplained rerun is attributed to that baseline warning.
The unchanged console source explicitly gives Undo, Discard and Arm a 44 pt
minimum frame (`RouteAmendmentConsole.workspaceEditingActions` / footer).
The smaller AX label bounds noted above are not a measured touch-frame failure;
the retained interaction tests exercise Undo. No blanket target-size audit of
excluded regular Cockpit controls is claimed.
VoiceOver actually spoke the proposed-leg identity, magnetic heading, leg time
and **Estimates updated**, as retained in `ipad-voiceover/speech.txt`.

The iPhone Pro captures were directly inspected against F06/F05 state content,
[D03-E compact console](https://www.figma.com/design/JCyQhDDzCPfrrbv6SBcwKw?node-id=29-1238),
[D03-F compact editor](https://www.figma.com/design/JCyQhDDzCPfrrbv6SBcwKw?node-id=29-1298)
and D05.2's compass/time direction. Prefill, 02:15,
03:00, unavailable recovery, update and Undo retain readable secondary text and
separated values. The list scrolls: the update screenshot intentionally shows
the bottom of row 1 and all of row 2; it is not evidence that every row is visible
at once. The full-screen Map tools attachment establishes Off; the subsequent
unobscured map establishes retained minute marks. Manual's post-Check map has no
teal minute/drift aids while original marks remain. These are bounded visual
comparisons, pending owner acceptance. iPhone exports record the source at export;
their patch includes the later preview visibility propagation described above,
which was not part of those already-compiled tests. Their covered released-drag,
entry and Undo paths are unchanged.

The initial simulator is an M5 iPad with an 834×1210 runtime screen. Its results
are additional modern-iPad coverage. The exact 834×1194 portrait / 1194×834
landscape reference is `AP01-iPad-11-Reference` (11-inch fourth generation);
canonical-device verification is recorded in the ledger. Initial selection
of the newer screen was an avoidable setup mismatch, not a design exemption.

Canonical comparisons use F06's content/status style, D03-A/C's shared console
and D05.2's current editor. Portrait map `{0,96,834,790}` and list viewport
`{20,998,794,128}` remain unchanged across override/move/Undo (0 pt tolerance).
Rows are 794×50. Changed editor Clear controls are 44×44 and Done 175×58.
Landscape D03-D's boundary is exactly x=824; its 370 pt rail retains 16 pt
insets and 338 pt content. The rendered map `{0,96,824,718}` retains the native
20 pt bottom safe area relative to Figma's illustrative 738 pt map height.
The map and console remain stable through the changed states. These are bounded
comparisons of ticket-owned geometry/content, not a claim that illustrative
chart geography or excluded regular Cockpit content is identical.

Visual result: the scoped prefill, working-time override, adjacent update, Undo
and adaptive states are **matched within the native/adaptive rules** of the cited
references and owner-approved text treatment. Human visual acceptance remains
separate and unchecked. The held-drag preview is **unverified as an in-progress
screenshot**: device synthesis captures after touch release. Passing drift visibility
into that disposable presentation is source-checked; released sustained drags and
unchanged Off state are exercised. No mid-gesture capture or full contrast audit
of excluded Cockpit regions is claimed.

Primary direct comparison: F06 state content with D03-A/C geometry and the
owner-approved update text. Prefill, edited 02:15/03:00, drift off, changed adjacent
values and exact Undo are visible. Teal marks follow the second leg; drift-off
keeps its ticks. Existing map/chart data differ from illustrative Figma geography.
The 17:56 drift-off/updated/Undo captures retain Map tools; tapping its trigger
does not dismiss that popover. The test now uses its native Close and asserts
dismissal; later adaptive runs and live handoff verify the unobscured map. This
is a fixture/evidence correction, not an application change or a fully unobscured
primary visual-match claim.

Implementation is ready for human visual approval. Required automated and scoped
direct checks passed; visual acceptance remains unchecked until John reviews the
evidence. Merge and issue closure remain separate owner decisions.

The final Debug candidate runs on **AP01-iPad-11-Reference**, PID 3751, bundle
`com.bensaidj.NavigationFlight`, session `AP08 Final iPad Handoff`. It was built
from this working tree before commit; no production changes followed. Select the
device in **Device Hub → View Screen**, then tap a proposed leg to edit it.
The app process and current screenshot are verified; the host foreground window
is unverified. The installed/build paths are recorded in canonical provenance.

## Effort and reruns

Approximate phase effort, excluding owner decision/pause time: exploration and
authority reconciliation 30–40 min; implementation 25–35 min; fixture/tool repair
20–30 min; automated verification, direct interaction and visual comparison
2–3 hours (automation/device waits, coordination and artifact comparison);
delivery/documentation 10–20 min.
These are estimates rather than tracked billable time.

Avoidable reruns came from the initial accessibility-label expectation, the new
archive fixture's missing review transition, the incomplete unavailable-input
fixture, a late assertion attempting to read fileprivate geometry, and a concurrent
preview install cancelling the adaptive batch. The
newer-iPad selection also required a separate exact-reference comparison. Passing
domain checks and successful rendered states were retained; evidence-export
permission/selector/result-copy problems were recovered without test reruns.
Avoidable test re-execution was approximately 10–20 min, included in the phases
above; exact-device setup/comparison added further direct-verification time.
Direct wheel calibration and device reactivation delays were tooling overhead,
not application failures or test reruns. The later silent simulator-install stall
added about 8½ min of avoidable tooling wait before the Xcode-only recovery.
