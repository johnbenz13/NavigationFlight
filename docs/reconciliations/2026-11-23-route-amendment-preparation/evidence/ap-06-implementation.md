# AP-06 acceptance and verification ledger

Implementation for [#230](https://github.com/johnbenz13/NavigationFlight/issues/230).
Human visual acceptance, merge and issue closure remain separate owner decisions.

## Readiness and remembered dependency

John identified **#228 → merged PR #241** on 2026-11-25 and explicitly asked
that this be remembered. Do not ask for that mapping again. GitHub's empty
`closedByPullRequestsReferences` does not override the supplied closing PR.
[PR #241](https://github.com/johnbenz13/NavigationFlight/pull/241) merged into main
at `27c88505e788aff9ead568f6b4408be11bc99dcd`; ancestry against origin/main passed.
#228 is the only native/body blocker for #230. No competing open PR was found.
Clean main was synchronized (`0 0`) before creating
`feature/optional-altitude-radio-and-visual-cues` at `8942869d89b5e0dbdf017b066bf3a2a3d18766ce`.

Scope: optional preparation cues on the logical directed leg; native altitude and
radio wheels, inherited-value preservation, native note and independent clears.
Exclusions: 8.33 kHz, tuning, new operational cue semantics/identification targets,
durable draft storage, protected Regular Cockpit redesign and map replacement.

## Acceptance matrix

All UI reproduction uses shared disposable A-progress (operational Leg2,
Kadima→Ramat, frozen 07:22 / planned 04:23; first proposed leg 087°/03:20).
A-progress-cues restores accepted 2550 ft  / 122.123456789 MHz through the existing
archive adapter. No owner Flight data is modified.

| Criterion / affected state | Authority | Observable result / evidence | Status |
| --- | --- | --- | --- |
| D05.2 heading | [67:146](https://www.figma.com/design/JCyQhDDzCPfrrbv6SBcwKw?node-id=67-146), [67:554](https://www.figma.com/design/JCyQhDDzCPfrrbv6SBcwKw?node-id=67-554); product D05.2 | Unset/selected, slow1°, fast/repeated north crossings, stop-on-contact, clear, Check/Done/pencil; shared A-progress-heading | Primary/precision/north/clear/retention passed; stop-on-contact timing unverified; human acceptance pending |
| D05.2 duration | Same direction; owner confirmed symmetric boundaries in conversation |00…59 cycles, carry/borrow/full wrap, partial/zero/legacy, independent clear, VoiceOver units/actions | Domain and rendered interaction checks passed; [boundaries](ap-06/d052-cyclic-boundaries/), [range](ap-06/d052-range-ipad/), [legacy](ap-06/d052-legacy-ipad/); human visual acceptance pending |
| A1 altitude, selected / unset/cleared | G03; [F05 12:503](https://www.figma.com/design/JCyQhDDzCPfrrbv6SBcwKw?node-id=12-503) | 216 options −1500…20000 in 100 ft steps; boundary/negative/rejected-new tests; native wheel and clear in portrait/landscape/phone exports | Domain and rendered cue audit passed; human visual approval pending |
| A2 radio, selected / unset/cleared | G03/Q25; F05 | Exhaustive 760 integer-kHz combinations plus118.000/136.975 endpoints; invalid choices rejected; whole/fraction wheels and entire-frequency clear | Domain and rendered cue audit passed; human visual approval pending |
| A3 inherited custom, open→Done→reopen→deliberate edit/clear | Shared contract; F05 custom rule | Out-of-range/off-step and near-grid Doubles retain exact values; explicit replacement tracked even when legacy strings coincide; [phone accepted custom](ap-06/iphone-custom/) | Domain/UI passed, including exact custom frequency after reopen |
| A4 native note, keyboard and maximum Larger Text | G03; F05 12:540/12:578; [D03-F 29:1298](https://www.figma.com/design/JCyQhDDzCPfrrbv6SBcwKw?node-id=29-1298) | Road junction retained; actual Done dismissal; [final normal phone](ap-06/iphone-notification-normal/D980284C-B25E-4F39-B3E2-7929AE5BCAB8.png), [final maximum-text phone](ap-06/iphone-notification-larger/57749C57-B51A-4C38-B154-169504544130.png) | Software keyboard passed on both devices/orientations; human visual approval pending |
| A5 omission/readiness and operational isolation | G03/Q34 | `optionalCueWheelsNeverChangeReadinessOrOperationalFlight`: omitted/populated cues both Ready; pending leg count unchanged; heading/time preserved; complete Flight equality and no amendment save/event | Passed; no new target/timer/navigation semantics |
| Adaptive/accessibility states | [D03-C 29:1039](https://www.figma.com/design/JCyQhDDzCPfrrbv6SBcwKw?node-id=29-1039), [D03-D 29:1167](https://www.figma.com/design/JCyQhDDzCPfrrbv6SBcwKw?node-id=29-1167), D03-F | Exact iPad834×1194 and1194×834; phone402×874; maximum text; actual [iPad VoiceOver](ap-06/ipad-voiceover/speech.txt), [phone VoiceOver](ap-06/iphone-voiceover/speech.txt); actual Reduce Motion on both | AP-06 coverage passed; current D05.2 evidence and timing limitation below; human visual approval pending |

All product/visual judgment remains **unchecked pending John’s approval**.

## Visual contract and rendered comparison

Figma file `JCyQhDDzCPfrrbv6SBcwKw`, session
`6f93e203-e579-42e1-9fc0-c02fe5fbab34`: full contexts and screenshots for
12:503,29:1039,29:1167,29:1298 were retrieved and directly inspected before edits.
Baseline [native text cue inputs](ap-06/baseline/) was rendered and inspected first.

F05 owns cue contents:16 pt inset/8 pt vertical spacing; native110×108 wheels;
two radio columns14 pt apart; explicit units/range/Not set; optional note on
86 pt minimum secondary surface with10 pt radius; advisory text. D03-C/F own
390 pt iPad/386 pt phone maximum width,16 pt inset,18 pt editor radius and664 pt
scrolling editor extent. Native text/control geometry adapts at accessibility
sizes; clear/actions keep44 pt minimum targets. D03-D owns landscape adaptation.
Existing live chart, camera, map assets, typography and semantic surfaces are reused.

Direct hierarchy measured exact iPad wheel110×108, editor width390,
scroll viewport571.5 and Done175×58; focused native Done358×44. Phone normal
width386 and the [full selected cues](ap-06/iphone-complete/20F498C3-380D-413D-82B0-5B1606ECABB7.png)
were inspected against F05 inside D03-C. The early note styling discrepancy was
fixed to the approved label/86 pt secondary surface before final iPad evidence.
Comparison is bounded to these cue contents/adaptive rules, not universal
whole-screen pixel equality. Protected Cockpit chrome and live map differ from
illustrative Figma context; they were not redesigned. The Check regression
capture is at a scroll offset with its title partly above the viewport; it proves
Check behavior and retained values, not full Check-state visual conformance.

## Verification ledger

All runs below use base 8942869 plus the scoped working patch current at invocation.
Original bundles are `Test-NavigationFlight-2026.11.25_<time>-+0200.xcresult` in
`/Users/john/Library/Developer/Xcode/DerivedData/NavigationFlight-dfguishsfjjxnvfpjmqicxhohumt/Logs/Test/`.
ActionArtifacts root is
`/var/folders/37/w2lgd8v96_348s1hxcxgwlcr0000gn/T/ActionArtifacts/82465A44-9693-45FB-A1D0-D37A209BD38C/`.
Each export retains original bundle, attachment manifest, hashes and source/test
provenance. Export source patches describe export time; they are not represented
as invocation-time commits. Original results are reused, never rerun just to export.

| Time / inputs | Check / result | Evidence or diagnosis |
| --- | --- | --- |
| 17:09:50 main, UIEvidence-iPad | Existing manual cue/Check baseline1/1 passed | [baseline](ap-06/baseline/); initially inspected before editing |
| 17:15:46 initial implementation | Xcode test-target build passed,0 errors | BuildProject-Log-20261125-171546.txt |
| 17:17:17 initial wheels | 36 value executions passed; first UI failed | Test selector omitted spoken units; corrected helper |
| 17:18:28 cue UI | Failed after successful entry | Test assumed disclosure survives editor close; explicit reopen preserves assertion |
| 17:21:04 cue UI | 1/1 passed | Entry/Done/reopen/independent clear; required fields and elapsed unchanged |
| 17:23:08 newer iPad | 4/4 passed | Readiness/nonmutation, custom, landscape, maximum-text full flow; supplemental834×1210 device, not exact reference |
| 17:36:20 exact iPad | 213 lifecycle/domain executions passed;3 UI failed | Actual VO exposed missing item-level units on Not set; fixed app label; bootstrap failure occurred before editor |
| 17:44:44 exact iPad | 4 inherited-altitude cases and actual VO passed;3 bootstrap UI failed | [iPad speech/screenshot](ap-06/ipad-voiceover/); original bundle recovered when ActionArtifacts copy lacked Info.plist |
| 17:41–17:44 direct exact iPad | Native note/Done, landscape note and actual Reduce Motion transitions passed | [direct-reference](ap-06/direct-reference/); hardware keyboard, no software-keyboard claim from this session |
| 17:50:40 exact iPad, repaired bootstrap | 4/4 passed | [portrait](ap-06/ipad-portrait/), [landscape](ap-06/ipad-landscape/), [maximum software keyboard](ap-06/ipad-larger-keyboard/), [manual Check](ap-06/ipad-check/) |
| 17:59:07 phone, accepted-value classification | 46/47 passed | 43 value cases + normal/custom/actual VO passed; maximum-text keyboard Done failed, not waived |
| 18:11:42 phone, explicit-edit flags | 46/47 passed | 44 value cases + nonmutation + normal full UI passed; first keyboard-safe conditional alone insufficient; [complete cue capture](ap-06/iphone-complete/) |
| 18:19 direct phone geometry | Measured actual occlusion | Focused geometry402×654.297,bottom inset157.703; note620.3/Done702.3 behind keyboard; original failure recording inspected before changing layout |
| 18:22–18:24 intermediate direct phone | Note and Done reachable; actual tap dismissed keyboard; actual Reduce Motion ON/disclosure/reopen/restored OFF | [paired captures/hierarchies](ap-06/iphone-direct/); temporary geometry logging removed |

| 19:36:47 final notification observer, phone | 2/2 passed | Custom full entry/reopen/independent clears and maximum-text note, actual software keyboard/full Done dismissal; [normal](ap-06/iphone-notification-normal/), [maximum](ap-06/iphone-notification-larger/) |
| 19:42:07 final exact iPad | 4/4 passed | Portrait full cue flow, landscape, maximum-text note and full cue flow; [portrait](ap-06/ipad-notification-portrait/), [landscape](ap-06/ipad-notification-landscape/), [maximum](ap-06/ipad-notification-larger/) |
| 19:53:53 final Xcode test-target build | Passed, zero errors | BuildProject-Log-20261125-195353.txt; unchanged final application source |
| 19:53:57 final phone maximum full flow | 1/1 passed | All cue entry, actual software-keyboard Done, reopen and independent clear assertions; [final captures](ap-06/iphone-notification-full-larger/) |
| 20:00 final diagnostics and documentation | Zero issues in chart panel, cue section and leg-entry domain file; local links valid; `git diff --check` passed | Final source unchanged since passing build/tests |

Passing 213 lifecycle checks remain valid: operational paths and data contracts were
not changed afterward. The 44 value cases and repeated nonmutation assertion pass
after deliberate-edit flags. Earlier normal/custom/VO evidence remains valid for
unchanged wheel labeling and accepted-value preservation; final focused keyboard
checks cover the viewport correction. No full repository test-suite claim is made.

## Failure diagnosis and reuse limits

- UIEvidence-iPad is834×1210, so it is supplemental. Exact-device evidence uses
  AP01-iPad-11-Reference, UDID07C2B017-8241-45BD-B859-E82C930C634F.
- XCTest clones retain settings independently of the visible device. Clone2
  `3C4CDCFD-AFFB-49D6-AAC3-D6B2F9B12BC6` had VoiceOver enabled; its failure
  recording showed a focus ring on Start. Visible-device Settings was OFF.
  Shared bootstrap now disables inherited VO before ordinary taps; speech tests
  explicitly enable/restore it. Start/sidebar assertions remain intact.
- Maximum-text phone note/Done were genuinely behind the software keyboard;
  actual swipes and hierarchy proved it. An initial inset subtraction was superseded after normal-text inspection
  exposed double subtraction. The current viewport observes native keyboard frames
  in local coordinates and clips, preserving the parent’s existing map sizing. Native AX still reports oversized scroll bounds, so the shared helper
  clips touch geometry to keyboard/accessory bounds and verifies actual dismissal.
- Direct corrected phone field(36,400),330×59 and Done(24,482),354×64.7 were usable
  above keyboard accessory y546. The Motion reopened screenshot precedes the
  hierarchy update; its hierarchy proves the transition, not a static visual match.
  Actual settings ON (value 1) and restored OFF (value 0) were inspected on both devices.
- A high-CPU observation during the first larger-text run prompted a sample attempt;
  the process ended and tests passed. No hang/performance regression was established.
- Avoidable work: two export selector corrections, two early UI reruns for spoken
  units/disclosure assumptions, initial use of the newer iPad requiring exact-device
  rechecks, and one insufficient keyboard fix rerun. Original bundles recovered
  export/cache failures without test reruns. Clone diagnosis and real app repairs
  are reported separately rather than hidden as generic flaky tests.

Additional retained outcomes:

- 18:24:27 phone run: custom test failed on a transient empty native picker value;
  full maximum-text test passed through actual keyboard Done, then was stopped by
  the implementing agent after repeated60-second missing animation-completion
  notifications during an optional screenshot scroll. This was not an owner
  cancellation and is not a passing test. Original result remains retained.
- Runner sample showed XCTest waiting for pre-event animation quiescence; app
  sample was predominantly idle. Runner symbol processing unexpectedly took
  about13 minutes (overlapping the stalled run); no performance claim is made.
- 19:11:33 custom phone rerun passed1/1 with a bounded4-second value-settle
  expectation. Exact custom value after Done/reopen and deliberate replacement/
  independent clearing remain asserted. [Selected/custom screenshots](ap-06/iphone-final-custom/).
- The extra full-section capture is now normal-text only; maximum-text controls
  and keyboard have separate captures. All maximum-text entry/reopen/clear
  assertions remain. The reveal helper requires the full Done frame above the
  keyboard before capture/action, then asserts actual keyboard dismissal.
- A subsequent maximum-text run was stopped when direct inspection of a normal
  note capture exposed double-counted safe-area space. A native layout-guide
  attempt then failed to report the software keyboard in this overlay (19:24:47:
  custom passed, maximum note failed). It was replaced with UIKit keyboard-frame
  notifications, converted through the posting screen into local bounds.
- 19:33:19 notification-observer candidate built successfully, zero errors. Final
  live diagnostics after an explicit-self warning repair: zero issues.
- 19:34–19:36 default/maximum phone direct probes passed note entry and actual
  Done dismissal. Both used a hardware keyboard; software behavior is unverified
  by these probes and is being checked separately by XCTest.

Final phone maximum full-cue flow passed; its complete note and Done screenshot
was directly inspected. No required device/accessibility check remains unverified.
Human visual acceptance remains pending; protected Cockpit chrome is excluded.

Final phone screenshots above were directly inspected: full note and full Done
above the software keyboard at normal and maximum text. F05 selected-cue content
was inspected in `iphone-notification-normal/B7786063-AE66-4D94-8457-DD4FDEC70F4C.png`.
Older keyboard photos are historical, superseded by these notification-observer
exports; they are not final A4 evidence. Protected maximum-text Cockpit chrome
wraps/clips outside the cue scope and remains a stated limitation.

Final exact-iPad screenshots were directly inspected against F05 within D03:
portrait `ipad-notification-portrait/245B2D3E-3431-4046-B189-0A9616A92307.png`
shows 2500 / 122.525 / Road junction, native wheel grouping, secondary note surface,
and pinned actions. Landscape `ipad-notification-landscape/AE7D8356-3A48-4AFC-B74F-BAC2105017D2.png`
shows the same native wheels in the constrained scrolling editor. The paired
keyboard captures show the complete note and Done above the software keyboard.
Maximum-text `ipad-notification-larger/1BFC58D6-8A14-4D92-94FF-09251649541E.png`
shows wrapped native labels, complete note and Done; the companion wheel image
shows stacked MHz/fraction controls and reachable pinned actions. This is a
bounded cue/adaptation comparison, with owner visual approval still pending.

## Effort and delivery boundary

Approximate elapsed allocation, including test/build/tool waiting: exploration and
contract/Figma inspection15 min; implementation25 min; test/tool diagnosis and
repair85 min; final verification/comparison40 min; delivery/handoff25 min
(about3 hours10 minutes overall; phase boundaries are estimates, overlapping sampling is
not counted twice). No owner-wait time is counted as implementation.

Avoidable reruns include early selectors/disclosure assumptions, initial use of
the newer iPad, intermediate keyboard-inset/layout-guide attempts, and the
44-minute stalled optional maximum-text capture. Sampling symbol processing took
about13 minutes within that stall. Export-name corrections (three total) reused
original results without rerunning tests. The final full-section screenshot is
normal-text only; maximum-text control, keyboard, reopen and clear assertions all
remain and pass. Real app fixes (VoiceOver item units, exact accepted-value edit,
keyboard overlap) and clone/bootstrap diagnosis are separately recorded above.

The PR and issue acceptance comment carry this ledger. Product/visual criteria
remain unchecked pending John; merge and issue closure are not performed.

Staging exposed expected single-space blank context lines inside exported unified
`source.patch` files. A narrowly scoped `.gitattributes` whitespace rule preserves
the original patch bytes/hashes; source whitespace remains checked normally.
The initial local commit ran despite that check failure; it was corrected and
amended before publication, with the full base-to-candidate check rerun.

## Live owner handoff

Verified source candidate `16cc861`, scheme NavigationFlight, Debug simulator app:
`/Users/john/Library/Developer/Xcode/DerivedData/NavigationFlight-dfguishsfjjxnvfpjmqicxhohumt/Build/Products/Debug-iphonesimulator/NavigationFlight.app`.
Installed/launched on exact AP01-iPad-11-Reference (UDID above), bundle
`com.bensaidj.NavigationFlight`, process1781. A new disposable UUID library uses
the canonical synthetic A-progress plan. [Current screenshot](ap-06/handoff/running-reference-ipad.png)
was directly inspected: usable Ready Cockpit in landscape, Start leg available.
The live app remains running. Device Hub from the active Xcode was opened;
select **AP01-iPad-11-Reference** there. Start leg, dismiss its checklist if shown,
then pencil → first proposed leg → Optional cues. Rotate to portrait if desired.

The delegated install/launch/interaction sequence stalled without intermediate
output and was interrupted after about6 minutes. Separate explicit simctl steps
then verified installation, launch and screenshot. Final touch navigation and
DeviceHub device selection are unverified handoff details, not missing acceptance
coverage: final automated cue/keyboard flows passed on both exact devices.
No application changes or test reruns followed the final passing verification.

## D05.2 revision contract and verification

Authority: owner-authorized extension of PR248 fromb0ff6b3 on its existing
feature branch; #228→merged PR241 remains remembered. Exact Figma67:146/67:554
contexts/screenshots were retrieved and inspected before source edits, session
`a424eef1-ba1e-4f76-bb38-2f889dd4f836`. Latest owner instruction waives another
pre-implementation design approval, not implemented visual acceptance. Owner
explicitly confirmed symmetric full-duration cycling (“yes”). Product/technical
checkpoints document the boundaries before coding.

Normal contract:390×643 editor,16pt insets/18pt radius,176pt vector compass,
fixed teal index, upright scalable magnetic value, paired152pt groups/14pt gap,
110×108 native wheels and independent44pt Clear. Retain Inspect original and the
live map/Cockpit context. This is a scoped comparison with Figma67:146/67:554,
not a whole-screen pixel-equality claim. F05 cues and keyboard contracts remain.
Accessibility adaptation:360pt compass, readout above arc, cardinal labels;
stacked time groups and scrollable content. Only the upper44pt arc band accepts
angular touch; upright value/surrounding space permit parent scrolling.

### Current results

All original bundles below remain in the DerivedData Logs/Test location above.
New ActionArtifacts root is `8DE462E9-8E3D-4177-BA12-039F74DE9602` under the same
ActionArtifacts parent. Dates are local:2026-11-25 before midnight,2026-11-26 after.
Tests usedb0ff6b3 plus the scoped patch at invocation; no app source changed after
Build00:39:45. Later changes are test capture/helper and documentation only.

| Invocation / exact inputs | Result | Retained evidence / valid reuse |
| --- | --- | --- |
|23:29:23, exact iPad, pre-edit heading/partial baseline|1/1 passed|Original result, `/private/tmp/d052-baseline`; directly compared before editing|
|23:39:28, iPad primary/north|1/1 UI passed|[Unset/176°02:15](ap-06/d052-primary-ipad/); visual geometry unchanged afterward|
|00:02:26, domain class + real-touch boundary|218/218 domain and1/1 carry UI passed; separate range UI failed before fixture repair|[03:59→04:00,00:00,reverse59:59](ap-06/d052-cyclic-boundaries/); all21,600 numeric transitions, unset±, partial/legacy and motion assertions pass|
|23:39:28, estimate class|44/44 passed|Reused: estimator/inputs unchanged; no rerun solely for new screenshots|
|23:47:43, exact iPad actual VoiceOver|1/1 passed|[Speech and screenshot](ap-06/d052-voiceover-ipad/);176→177°,02→03min,15→16sec|
|00:20:53, exact iPad landscape|Full landscape flow passed; following max test agent-cancelled|[Carry/Check/keyboard/clear](ap-06/d052-landscape-ipad/); source normal geometry unchanged; final arc touch spot-check below|
|00:42:21, exact iPad max/range/legacy|3/3 passed, no skips|[Maximum](ap-06/d052-max-ipad/), [range](ap-06/d052-range-ipad/), [90:00 unchanged→59:00 edit](ap-06/d052-legacy-ipad/)|
|07:39:45, exact phone primary/max/actual VoiceOver|3/3 passed, no skips|[Primary](ap-06/d052-primary-phone/), [maximum](ap-06/d052-max-phone/), [speech](ap-06/d052-voiceover-phone/)|
|08:52:14, final Xcode test-target build|Passed, zero errors|BuildProject-Log-20261126-085214.txt; live diagnostics0 in compass, cyclic wheel and leg-entry domain|

Current UI flows cover Check/back, note/software-keyboard/full Done, save/reopen,
independent clears, pencil retention, next-leg isolation and unchanged camera/map.
The final iPad max carry capture partly clips seconds00 at its scroll offset;
it is not full-wheel visual evidence. [Complementary direct maximum captures](ap-06/d052-direct-max/)
fully reveal selected02/15 with labels/Clear above the footer, values unchanged.
They also show177°/MAGNETIC above the arc and the complete cardinal/index view
at a complementary scroll offset. Phone maximum selected00 and native keyboard
Done were directly inspected. These adaptations await owner visual acceptance.

[Native motion evidence](ap-06/d052-motion/) retains paired screenshots/hierarchies
on both exact devices: Reduce Motion ON, actual fast and1° slow input, restored
OFF, slow north crossing and stable later readout, exact camera preservation.
Normal fast drags travelled~58–59°; same reduced-motion drags~32°. Direct max
outer scrolling preserved176°, then a slow arc drag selected175°.

**Unverified:** precise touch-during-coast cancellation timing. Multi-lift `mt`
commands produced no motion; supported chained swipe/wait/touch ended with the
same travel as a plain swipe. Video `/private/tmp/d052-phone-contact.mp4` and
OCR `/private/tmp/d052-contact-ocr.txt` show bounded settling but cannot establish
when the second touch was delivered. Code cancels the stored MainActor task on
new contact/clear/disappearance/Reduce Motion change; code inspection and final
values are not represented as runtime timing proof. This criterion and human
visual/gesture judgment remain unchecked; the issue is not declared complete.

**Existing runtime limitation:** interrupted max run reports “Modifying state
during view update”. The identical warning occurs twice in the earlier19:42:07
pre-D05.2 exact-iPad AP-06 adaptive result (4/4 passed). No speculative picker
change was made; no warning-free runtime claim is made. Protected Cockpit chrome
is unchanged and is outside the scoped Figma match.

### Diagnosis and rerun ledger

| Failure / classification | Diagnosis and disposition |
| --- | --- |
|First fixture empty payload — fixture|Read canonical `/private/tmp/ap06-plan-base64.txt` explicitly, new disposable library; no app change|
|23:39 motion unit — application|Returning exactly to drag origin suppressed selection; retained deliberate-movement state, repaired assertion passed|
|Direct AX59→00 boundary — fixture|Value search conveys no direction; replaced with actual one-row touch, preserving carry/borrow assertions|
|23:47 touch did not move — fixture|`.slow` is250pt/s,32pt lasted128ms. Retained event plist/video inspected; direct32pt/1s and80pt/1s probes succeeded. Set one-row velocity from row distance; kept working native110×108 size|
|Unset numeric row — application, then fixture|Nil had replaced0; separate transient row now starts forward00/backward59. XCTest repeated-row search still carried minutes during setup; shared helper now enters cycle with actual one-row touch|
|Max readout/arc overlap and scroll stealing — application|Stopped max test after rendered diagnosis.360pt/readout-above/cardinal adaptation and44pt arc-only hit shape fixed it; direct rendered/scroll/1° checks passed before focused rerun|
|Reveal lane and AX geometry — fixture|94% lane crossed full-width dial;98% uses panel inset. AX follows310×155 arc after hit-shape fix; helper now targets actual arc point10pt inside rim|
|Incorrect existing test identifier — invocation|Rejected before tests executed; corrected identifier, no app change|
|Two parallel exports — tooling|xcresulttool SQLite cache initialization raced. Sequential exports recovered original passing results; zero test reruns|
|Sandbox simctl access / expired foreground fixture — tooling/fixture|Service access failed; explicit permitted launch recovered canonical disposable fixtures. No owner flight data used or changed|

Original result exports preserve full-screen screenshots, manifests and provenance.
Published source patches omit only the owner-owned research diff; provenance
records excluded path, full/published hashes and retained local original. Other
unified-diff sections and original export-time status remain unchanged. New-source
files were staged before later exports. Early exports list untracked files rather
than claiming to archive them; delivered commit supplies the complete source.
Owner research/assets remain untouched and uncommitted. Successful results were
reused; no test was rerun merely to recover screenshots.

Approximate D05.2 active effort, excluding extended approval/service waits:
contract/Figma15min; implementation40min; diagnosis/tool repair45min;
verification40min; delivery15min (about2½–3h). Avoidable repeat/diagnosis overhead
about15–25min: gesture-velocity assumption, cyclic AX fixture search and late
recognition of full-width dial scrolling. Export retries took seconds and did
not repeat tests. Earlier AP-06 effort remains recorded above.

Final post-hit-shape landscape spot-check08:56 passed:176→175° slow precision,
outer scroll preserves175° and exact camera. [Final paired evidence and live
handoff](ap-06/d052-handoff/). Exact reference iPad returned to portrait, process
19854, second-leg175°/02:15 open. This complements the passing full landscape
flow without repeating unchanged Check/cue/keyboard assertions.
