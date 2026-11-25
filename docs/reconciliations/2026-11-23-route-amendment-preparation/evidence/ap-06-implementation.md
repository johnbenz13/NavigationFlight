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
| A1 altitude, selected / unset/cleared | G03; [F05 12:503](https://www.figma.com/design/JCyQhDDzCPfrrbv6SBcwKw?node-id=12-503) | 216 options −1500…20000 in 100 ft steps; boundary/negative/rejected-new tests; native wheel and clear in portrait/landscape/phone exports | Domain and rendered cue audit passed; human visual approval pending |
| A2 radio, selected / unset/cleared | G03/Q25; F05 | Exhaustive 760 integer-kHz combinations plus118.000/136.975 endpoints; invalid choices rejected; whole/fraction wheels and entire-frequency clear | Domain and rendered cue audit passed; human visual approval pending |
| A3 inherited custom, open→Done→reopen→deliberate edit/clear | Shared contract; F05 custom rule | Out-of-range/off-step and near-grid Doubles retain exact values; explicit replacement tracked even when legacy strings coincide; [phone accepted custom](ap-06/iphone-custom/) | Domain/UI passed, including exact custom frequency after reopen |
| A4 native note, keyboard and maximum Larger Text | G03; F05 12:540/12:578; [D03-F 29:1298](https://www.figma.com/design/JCyQhDDzCPfrrbv6SBcwKw?node-id=29-1298) | Road junction retained; actual Done dismissal; [final normal phone](ap-06/iphone-notification-normal/D980284C-B25E-4F39-B3E2-7929AE5BCAB8.png), [final maximum-text phone](ap-06/iphone-notification-larger/57749C57-B51A-4C38-B154-169504544130.png) | Software keyboard passed on both devices/orientations; human visual approval pending |
| A5 omission/readiness and operational isolation | G03/Q34 | `optionalCueWheelsNeverChangeReadinessOrOperationalFlight`: omitted/populated cues both Ready; pending leg count unchanged; heading/time preserved; complete Flight equality and no amendment save/event | Passed; no new target/timer/navigation semantics |
| Adaptive/accessibility states | [D03-C 29:1039](https://www.figma.com/design/JCyQhDDzCPfrrbv6SBcwKw?node-id=29-1039), [D03-D 29:1167](https://www.figma.com/design/JCyQhDDzCPfrrbv6SBcwKw?node-id=29-1167), D03-F | Exact iPad834×1194 and1194×834; phone402×874; maximum text; actual [iPad VoiceOver](ap-06/ipad-voiceover/speech.txt), [phone VoiceOver](ap-06/iphone-voiceover/speech.txt); actual Reduce Motion on both | Required device/accessibility coverage passed; human visual approval pending |

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
repair85 min; final verification/comparison40 min; delivery/handoff15 min
(about3 hours overall; phase boundaries are estimates, overlapping sampling is
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
