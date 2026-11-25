# AP-05 · Leg time wheels

Implementation #229 on `feature/leg-time-minute-and-second-wheels`, based on
synchronized main `4c106bb`. **Implementation candidate for human visual approval; owner acceptance and merge
are separate decisions.**

## Authority and scope

Read G03/G04, shared task contract, D03 geometry, retained D02 state contents,
canonical preparation product/technical checkpoints and shared test/evidence
instructions. Retrieved high-fidelity contexts and directly inspected Figma
[D03-C29:1039](https://www.figma.com/design/JCyQhDDzCPfrrbv6SBcwKw?node-id=29-1039),
[D03-F29:1298](https://www.figma.com/design/JCyQhDDzCPfrrbv6SBcwKw?node-id=29-1298),
[D02-F0512:503](https://www.figma.com/design/JCyQhDDzCPfrrbv6SBcwKw?node-id=12-503).
#228 was CLOSED but GitHub's closing-reference field was empty. Owner explicitly
identified PR #241; independently verified MERGED to main, merge `27c8850`
ancestor of origin/main, then created branch from clean synchronized main.
No competing implementation PR. Excludes clock ETA revision, execution timers,
Assisted prefill, cue-wheel redesign, AP-09 persistence and AP-11 arming.

## Acceptance matrix and visual contract

| Criterion/state | Observable result / authority | Fixture | Evidence / disposition |
| --- | --- | --- | --- |
| 1 · Grouping | Heading separate; Minutes/Seconds together under Leg time · D03-C/F | A-progress-heading first leg | Primary/landscape/compact screenshots below; bounded native-style match, human approval pending |
| 2 · Range | 00–60/00–59, 59:59→60:00 forces seconds00, rejects60:01 · D02-F05 | Wheel-only flow | 7 boundary +2 selection cases; normal/landscape UI flows pass |
| 3 · Untouched/zero/partial | Opening accepts no default;00:00 blocks readiness; Done/pencil preserves partial entry · G03/shared contract | Missing time; clear minute; close/reopen; clear second | 6 readiness cases; full UI transitions and next permitted edit pass except compact maxtext automation bootstrap noted below |
| 4 · Independence/readiness | Heading/cues preserved; rows and pending validation share integer seconds · G03/G04 | Complete-route domain fixture and heading087 UI | Domain suites and cue/Check regressions pass; map/camera assertions retained |
| 5 · First edit/clear | First deliberate choice initializes other00; one Clear preserves other, both restore Not set · approved shared contract | Seconds-first and minutes-first | Parameterized domain tests; wheel-only UI; no wheel-center opening default |
| Compatibility | Accepted durations remain exact until edited · D02-F05 | Archived90:00 restored via existing adapter | 3 domain cases and legacy UI pass; unchanged message screenshot |
| Adaptation/accessibility | Reachable44pt actions, scrollable max Larger Text, distinct adjustable units, actual Reduce Motion · D03 adaptive rule/shared contract | iPad portrait/landscape, iPhone16Pro, other supported compact | See device ledger; scoped actual VoiceOver PASS; maxtext automation limitation retained |

D03-C: map-associated white editor width390, maximum height664, inset16,
radius18, shadow0/4/16 at18%; content gap8. Native time wheel intent110×108,
caption13 labels, gap18 between columns, Clear below each with44pt minimum
target. Heading/time separated by divider. System fonts, semantic surfaces,
native pickers/buttons and existing live map/route components are reused.
D03-F: x8, width386 at402pt; same hierarchy, adaptive scroll with pinned
Check/Done. Larger Text may stack columns while preserving their section and
reachable actions. Native wheel geometry adapts to platform/text size. Existing
map/console boundary and regular Cockpit remain protected. D02-F05 supplies
positive-duration error, ceiling guidance, Not set and unchanged legacy content.
No illustrative Figma map or route raster/SVG is a runtime asset.

## Verification ledger

Original results reside in
`DerivedData/NavigationFlight-dfguishsfjjxnvfpjmqicxhohumt/Logs/Test/` as
`Test-NavigationFlight-2026.11.25_<timestamp>-+0200.xcresult`.
Console/build logs and direct-device artifacts reside in ActionArtifacts session
`8F94BEAF-3946-4EA4-AECB-2558ACB9AEAD`. Export directories under [ap-05](ap-05/)
retain manifests, hashes and source provenance. Passing behavior checks are reused
when production inputs remain unchanged. Final production correction at15:04:
amber validation ink and option-level native-wheel accessibility labels.
Earlier red zero-state images are historical and superseded by final-amber.

| Check / revision | Device/settings/fixture | Result and retained evidence |
| --- | --- | --- |
| Pre-edit4c106bb14:33 | iPad portrait834×1210, A-progress-heading | Direct Figma comparison before editing; [baseline](ap-05/device/before-screenshot.png), card390×664, old text/±5s time controls |
| Build14:36 / final production15:04:51 / delivery15:29:02 | App + tests, Xcode BuildProject | All passed; delivery log BuildProject-Log-20261125-152902.txt includes current test helpers; changed production diagnostics clean |
| Focused14:37 /14:39 | Boundary/selection/legacy/readiness + primary UI |13 pass,6 new readiness cases fail (test omitted Done before constructing Pending); fixed test only, first parameter rerun passes |
| Broad14:40:08 | Both relevant domain suites +5 iPad UI |236/237 pass:232 domain cases all pass; landscape wheel, heading/Check, invalid cue retention and initial VO pass. Maxtext fixture Start fails before editor |
| iPad maxtext diagnosis14:45–14:49 | Maximum Larger Text, prior landscape sidebar | Repeat confirms sidebar scrim intercepts Start despite AX hittability. Direct capture identifies it; shared helper explicitly dismisses identified Hide Sidebar overlay. No app change |
| iPad14:50:09 | Maxtext wheel flow + archived90:00 |2/2 pass; [larger evidence](ap-05/ipad-larger/provenance.json), [legacy](ap-05/legacy/14A0F941-F503-4968-A9F1-72DD5C8B52AA.png) directly inspected. Legacy Done/reopen exact, deliberate60 replaces90 |
| Primary/landscape retained | Original14:37 and14:40 results | [Primary7 states](ap-05/primary/provenance.json), [landscape3](ap-05/landscape/provenance.json) directly inspected against D03-C/F and D02-F05; historical zero color superseded |
| iPhone14:54:44, actual Reduce Motion ON |402×874, A-progress-heading | Normal complete wheel flow and initial VO pass; maxtext Clear reveal and cue-button reveal fail. Direct15:01 diagnosis: viewport overshoot and native AX button hittability; app actions work. Shared helper gets bounded slow drags, measured visible-button path and failure attachments |
| Final app15:05:01 | iPhone normal flow/strict actual VO | Strict adjustable-unit VO passes; UI test expects old raw wheel AX strings and fails. Update test expectations only |
| iPhone15:09:14 | Final app; normal wheel + cue + maxtext + VO | Normal full wheel and invalid cue regression pass2/4, including Done/pencil/camera and amber feedback. Maxtext reveal budget insufficient (2346pt body,16 drags); increased measured bounded drags40. VO unit assertions pass; degree wording check fixed to accept spoken degree or° |
| Final actual VO15:16:01 | iPhone16Pro, real VoiceOver speech | PASS: heading001° then distinct adjustable Leg time minutes and seconds; [retained speech](ap-05/final-voiceover/C82ED12E-C8DB-448F-9650-77EBB09EE8A9.txt) inspected directly. Earlier test incorrectly matched Clear labels; strengthened and app option labels corrected |
| Final amber export | Passing15:09 normal flow, no rerun | [00:00 screenshot](ap-05/final-amber/58AAB8CD-63F2-46F0-9801-8A667BED2AB2.png) directly inspected against D02-F05 amber rule and D03-F grouping |
| Compact maxtext15:16,15:22,15:23 | Same fixture before editor | Start fails to disappear under XCUITest. Direct same-coordinate Start succeeds first tap, no overlay; VoiceOver OFF confirmed. Coordinate-tap experiment also fails and is reverted. Cause remains unresolved; no speculative app change |
| Compact direct15:21–15:22 | Maximum text; actual Motion restoredOFF | Minutes/Seconds both reachable240×216; each Clear119×63.3 works. [Minutes](ap-05/compact-larger-direct/minutes-screenshot.png), [Seconds](ap-05/compact-larger-direct/seconds-screenshot.png), [Motion restored](ap-05/compact-larger-direct/motion-restored-screenshot.png) inspected; transition coverage supplemented below |
| Additional compact15:24:30 | iPhone17e iOS27.2, final app |1/1 complete wheel-only UI flow passes including camera, exits and next edit; [3 final states](ap-05/extra-compact/provenance.json) directly inspected against D03-F/D02-F05 |
| Compact maxtext direct15:27–15:30 | Same final candidate, maximum text | Untouched/zero Done-reopen, positive, Clear minutes preserving seconds, Done/pencil, Clear both and nextedit00:01 observed; heading087 and map AXvalue unchanged. [Transition captures/hierarchies](ap-05/compact-larger-transitions/provenance.json) inspected.59:59→60:00 not repeated here; zero warning offscreen not inspected in this session. Those states have iPad maxtext and normal compact automated coverage |
| Final iPad15:31–15:34 / owner handoff | Normal text portrait834×1210 and landscape1210×834, final candidate | [Untouched portrait](ap-05/final-ipad/untouched-portrait-screenshot.png), [amber zero portrait](ap-05/final-ipad/zero-portrait-screenshot.png), [amber zero landscape](ap-05/final-ipad/zero-landscape-screenshot.png) retrieved and directly compared against D03-C/F + D02-F05. Matched within native/adaptive rules: card390wide, portrait~663high(max664), landscape reduced height; wheels110×108, gap18, Clear44×44. Bounded visual treatment judgment, human approval pending. [Candidate/provenance](ap-05/final-ipad/provenance.json); simctlPID27815, DeviceHub opened, app left portrait zero editor running |
| Delivery hygiene | Current staged changes | git diff --check and staged check pass; local documentation links and lossless patch archive hashes verified |

## Effort and avoidable reruns

Approximate effort: exploration/preflight10min, implementation9min, verification
25min, test/tool diagnosis and repairs20min, evidence/delivery12min (~76min total;
owner clarification wait excluded). Approximately14–17min of avoidable reruns
and coordination overhead are included, primarily the test/helper defects below. Avoidable reruns: new readiness test omitted Done; AX value assertions
lagged improved spoken labels; initial VoiceOver assertion matched Clear labels;
degree assertion assumed wording instead of native°; compact scroll helper first
overshot, then allowed too few measured drags. Compact Start remains a retained
unresolved automation failure after direct diagnosis and one reverted experiment.
No full domain-suite rerun after its232 passing cases because domain code stayed
unchanged. Two export selector mistakes were recovered from original results,
without UI reruns. Incomplete ActionArtifacts copies were recovered from original
DerivedData bundles. Initial device-session duplication and excessive short
polling were avoidable coordination overhead. Opening DeviceHub invalidated the interaction session; capture recovery cost~2min
without rebuild. A diagnostic video decode attempt also failed; direct runtime
captures were used instead. No coverage or assertion was silently removed.

Source patches are retained losslessly as source.patch.gz with uncompressed hashes
to preserve meaningful diff context blanks without whitespace-check failures.
They record export-time changes, not inferred exact test-time source;
new TimeSection source is retained in this PR. DEBUG legacy fixture uses a
previously accepted encoded archive and the existing complete-value adapter.
Native well shape/type is platform supplied; no pixel-perfect map or typography
match is claimed. iPad834×1210 versus design834×1194 differs in system chrome;
local card/component geometry is the comparison boundary. Human visual criteria
remain unchecked and issue remains open until merge.
