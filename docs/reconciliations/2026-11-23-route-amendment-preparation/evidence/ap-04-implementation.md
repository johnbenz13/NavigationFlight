# AP-04 implementation and verification ledger

Issue [#228](https://github.com/johnbenz13/NavigationFlight/issues/228).
Started 2026-11-25 approximately 06:48 UTC. Branch
`feature/on-map-leg-heading-editor`, synchronized main `954254e`.
Readiness: #227 closed through merged PR #240 (`954254e`), #226 through
PR #238 (`bfe4b06`), D04 documentation through PR #239 (`3eadbee`). All merge
commits verified ancestors of fetched origin/main; main divergence 0/0, clean tree.
No competing open implementation PR. User explicitly discarded the obsolete
AP-02 implementation sequence in the initial prompt.

## Pre-edit acceptance matrix

| Criterion | Observable result | Fixture | Verification |
| --- | --- | --- | --- |
| Shared editor before/after rejoin | Row and short proposed-map hit select identical leg; open overlap offers Edit/Rejoin, closed overlap only edits; closing keeps geometry/entries and camera/console | A-progress, A-partial, B overlap | Domain typed routing and Flight invariance; rendered actual map/row interactions and retained screenshots |
| Independent heading | Separate labelled magnetic heading wheel, nil/Not set initially, 001°–360° with degree units and Clear | A-partial untouched, A-progress leg 2 duration only | Domain nil/range/clear assertions; native wheel selection, clear and reopen; direct D03-C/F comparison |
| Partial save and exit | Heading survives Done and pencil exit with missing duration/cues; duration and cue strings survive heading clear | A partial combinations | Parameterized domain assertions, complete legacy adapter; rendered close/reopen and pencil retention |
| Check inside modal | No row Check; pilot and reference cards distinct; available/unavailable Check changes no field | A, D available/unavailable | Domain snapshots including cues and aid eligibility; rendered Check/back/Done and missing displays |
| Manual map aids | Check leaves Manual proposed minute marks/drift lines absent; missing fields remain Not set | Manual A/D | Existing aid projection plus explicit before/after Check regression; rendered route-role/entry comparison |
| Responsive/accessibility | Reachable wheel, Clear, Check and Done; labelled adjustable value, wrapping/scrolling; reduced-motion interactions | iPad 834×1194 first, iPhone 402×874, iPad 1194×834, Larger Text | Focused UI automation plus direct device verification/VoiceOver/Reduce Motion; exact-node screenshots |

Domain assertions establish data/transition correctness. Frame equality and panel
existence are preservation checks; they do not establish visual correctness or usability.

## Authority and visual contract

Read G03/G06, shared task contract, canonical product/technical preparation
sections, D03 and D04 scoped supersessions. Directly retrieved design context and
inspected screenshots for D03-C `29:1039`, D03-F `29:1298`, D02-F05 `12:503`,
D04 `48:409` on 2026-11-25 before source edits.

- D03-C editor: left map-associated white surface, x20, map-relative y98,
  width390, height664, inset16, radius18, shadow 0/4/16 at18%; content gap8.
  Manual/leg/magnetic caption12, route title21 semibold, heading section17,
  native degree wheel intent110×108 with Clear beside it; divider before time.
- D03-F: x8, width386 on402pt screen, same separated hierarchy; scroll when
  available viewport is smaller. Protected operational header/pencil remains
  reachable and underlying map/console never shifts. Native wheel geometry and
  typography adapt to platform and Dynamic Type.
- AP-04 explicitly retains current minutes/seconds input and optional cue controls
  until AP-05/AP-06; their wheels/caps are excluded. Preserve the separated time
  section. No estimator, persistence or arming changes.
- D02-F05: pilot card on secondary surface, distinct teal reference card;
  available course/heading provenance labelled, unavailable explanation and
  unchanged pilot fields; Back to values. Unknown values read Not set.
- Existing live map, geographic overlays, system typography/semantic surfaces,
  native buttons and SF symbols are reused. Illustrative Figma map raster and
  route SVGs are explanatory data, not runtime assets.
- Pre-edit A-partial screenshot inspected: old panel x446/y232/w338/h417,
  heading text/step buttons, time text/step buttons, Cancel/Save and green Check.
  Source artifact: ActionArtifacts/5F7A1490-DA0B-451C-ABB2-DF334152B03B,
  `AP04 Pre Edit Baseline-08_57_56_711-screenshot.png`; corresponding hierarchy.
  It differs from approved heading/control hierarchy and panel placement.

## Verification runs and failures

Implementation checkpoint; acceptance remains incomplete. Reuse each passing run unless later changes invalidate it.
Classify failures before code edits; investigate after two unexplained repeats.

- Tooling: initial git fetch denied FETCH_HEAD; approved elevated fetch succeeded.
- Tooling: fuzzy device name rejected; exact existing AP01 reference UUID used.
  Neither failure caused application edits or test reruns.

| Run (local +0200) | Result | Classification / retained provenance |
| --- | --- | --- |
| 09:01:01 | Build including test targets passed; heading/panel diagnostics clean | BuildProject log in ActionArtifacts/5F7A1490-DA0B-451C-ABB2-DF334152B03B; draft diagnostics retrieval failed (tooling), build supplied compiler validation |
| 09:03:14 | 9/12 focused domain cases passed | Test defects: new aid fixture used ineligible fraction0 in active leg; historical raw-string normalization assertion incompatible with lossless raw entry. Initial diagnostics also caught incorrect test API names, corrected before this run |
| 09:03:41 | Focused failed tests passed | Corrected fixture to fraction0.3 and assert numeric heading; earlier partial-combination passes reused |
| 09:05:35 | UI failed to locate heading wheel | App AX identifier defect: section identifier propagated over picker/Clear identifiers; removed ancestor ID. Test targets native Picker child wheel |
| 09:06:46 | Primary editor UI passed | Exported /tmp/ap04-primary-pass; screenshot comparison found Check retained old scroll offset and clipped title, corrected with state-specific scroll identity. Applied approved 664pt maximum panel extent |
| 09:08:54 | 214/215 passed, including both domain suites, partial-list UI, unavailable Check UI | One primary picker adjust returned empty value; investigating native hierarchy/session before further app changes. Exported /tmp/ap04-stable-primary. Domain passes remain valid |
| 09:12 exclusive device | Ordinary wheel swipe Not set→001°, Clear, Done, reopen passed; app stayed Running | Native Picker owns identifier; child PickerWheel has no identifier. Wheel110×108, Clear44×44, Done175×44. No new app crash report found. Evidence `AP04 Exclusive Wheel Check-09_12_39_993` and `09_12_53_264` |
| 09:13:46 | Primary heading/Check/clear/pencil retention passed | Test uses first deliberate001° choice; no application change for the prior jump176° failure. Native long-jump automation result remains a test/tool-path limitation; ordinary input and domain range cases verified |
| 09:14:52 | Landscape, actual map editor, actual VoiceOver passed; Larger Text failed | Application layout defect: protected header+footer left8pt scroll viewport. Reused212 passing domain cases and unavailable Check/partial-list passes |
| 09:18:50 | Build failed on extracted helper's landscape variable scope | Implementation compile error, fixed by passing landscape explicitly; diagnostics then clean |
| 09:19:10 | Final iPad portrait, landscape and maximum Larger Text flows all passed | Editor moved to overlay across available Cockpit height under D03-F, leaving underlying layout unchanged; final captures `/tmp/ap04-ipad-overlay-final` directly inspected |
| 09:21:45 | iPhone portrait, unavailable Check, actual VoiceOver passed; maximum text test stopped on Done helper | Test helper defect, confirmed by exclusive native hitpoint check. Tool-reported xcresult copy was absent; original DerivedData bundle exported successfully to `/tmp/ap04-iphone-first` |
| 09:28 exclusive iPhone | Done closed/reopened, wheel selected001°, Clear restored Not set, app Running | Done24/581/354/44 is pinned outside content viewport8/357.3/386/168.7 and inside panel0/62/402/729. Existing helper's isHittable guard rejected it. Repaired footer tap uses measured visible center; subsequent state assertion verifies actual outcome |

Avoidable tooling conflict: a bounded device helper launched while a primary UI
run was active; its app disappeared and stdout closed. That helper result is
invalidated, not evidence of an application crash. Subsequent device work and
tests use exclusive simulator windows. No application edits were made for it.

The editor overlay may cover the lower console in compact/accessibility layouts
without resizing it, as D03-F shows. Its maximum extent is664pt; the scroll body
and pinned Check/Done share the space below the protected operational header.
At maximum Larger Text, deliberate scrolling exposes heading/Clear/time while
the footer and pencil remain reachable. The screenshot after wheel selection
is intentionally scrolled; the heading caption remains available above it.
Native iPhone wheel is216pt at maximum text; the initial viewport was168.7pt.
The explanatory Done hint now scrolls with content at accessibility sizes,
leaving only Check/Done pinned and making room for the wheel. Normal-size hint
placement remains below the actions. Direct comparison also corrected the
reference-card fill to use the teal surface directly instead of layering grey
over it. These scoped visual changes do not invalidate domain or earlier input
results; refreshed captures are required for their affected visual states.

## Effort and delivery

Approximate exploration to pre-edit contract: 12 minutes. Implementation,
test/tool repair, verification and delivery will be recorded below. No commit,
push or PR requested. Human visual acceptance remains a separate pending gate.

## Publication checkpoint — 2026-11-25 10:00 +0200

Owner requested commit, push and PR at this checkpoint. Publish as a draft;
this is not acceptance approval or issue completion.

| Run | Result | Disposition |
| --- | --- | --- |
| 09:29:23 iPhone | Manual entry/Check/pencil and maximum-text overlap passed | Heading maximum-text helper failed; repaired native wheel activation/scroll handling |
| 09:33–09:38 iPhone | Repeated maximum-text automation failures | Test-helper defects: wheel activation changed selection, offscreen native children needed scrolling, and offscreen Clear was misclassified as pinned Done. Restricted footer handling to known action identifiers; no application change for these failures |
| 09:47:50 iPhone | Maximum-text full heading flow passed | Final native-footer flow, including Check/back/pencil/Clear/retained time |
| 09:49:10 iPad | 4/6 passed | Portrait, landscape, maximum text and optional-cue/Check flows passed. Overlap test failed finding a ScrollView; range test native wheel returned empty instead of360°. Both remain unresolved; do not infer application correctness or defect from these failures |
| 10:00:25 | BuildProject including test targets passed, no errors | BuildProject-Log-20261125-100025.txt in session ActionArtifacts |
| Publication | git diff --check passed | No whitespace errors |

The 212 domain cases from09:08:54 remain passing and were not rerun after
presentation/test-helper-only changes. Actual VoiceOver passed on iPad and
iPhone in the runs above. Reduce Motion interaction verification remains pending.
Final passing screenshot consolidation and final authoritative-frame comparison
remain pending; earlier inspected screenshots are identified above but do not
establish acceptance of subsequent visual changes. Human visual/design approval
has not been given. All mixed visual criteria remain unchecked and #228 stays open.

Approximate active effort through publication: exploration12min,
implementation15min, test/tool repair20min, verification19min, delivery5min
(about71min total; excludes the conversation pause). Avoidable reruns arose from
fixture/API mismatches, concurrent simulator use, and generic helper assumptions
about native wheel activation, scroll exposure and pinned actions. These are
recorded above rather than counted as application regressions.

Deferred by approved AP-04 scope: AP-05 time wheels/cap, AP-06 cue controls,
AP-09 persistence and AP-11 arming. Final-route completeness validation remains
unchanged. The outstanding verification listed here is not a scope deferral.

## Review remediation contract (R1–R3)

| Criterion | Observable result | Fixture | Verification |
| --- | --- | --- | --- |
| R1 invalid entered cues | Invalid nonempty altitude/frequency retain Done/pencil exit, reopen expanded with errors; correction restores complete values; blank required values remain allowed | Otherwise valid heading/time plus invalid cue | Domain parameterized regression and rendered cue correction/reopen |
| R2 retained Check guidance | Unavailable explains inability to calculate and continue own values; no-wind course clearly reference only; pilot values unchanged | Existing available/unavailable Check fixtures | Domain nonmutation reused; rendered D02-F05 12:557/12:563 comparison |
| R3 full overlap flow | Stable exposed action container measured; Edit/close/Rejoin/post-rejoin edit all reached | B-open-overlap | Complete existing UI test plus captures, D04 48:409 |

Pre-edit inspected reviewer Figma D02-F05 image and unavailable simulator render.
The unavailable title/metrics lack guidance; available metric layout remains a
separate reported design discrepancy requiring owner acceptance.

### R1–R3 remediation results

| Finding | Disposition | Verification / evidence |
| --- | --- | --- |
| R1 | Fixed and behavior verified | `invalidEnteredFields` excludes missing required fields but includes malformed nonempty entries. Reopen expands invalid cues. New parameterized domain regression confirms valid heading/time plus invalid frequency/altitude blocks Pending conversion, correction restores it, missing heading remains retainable. UI repeats Done/reopen/correction for both cues on iPad and iPhone. [Frequency](../assets/ap-04-review/ipad-invalid-frequency.png), [altitude](../assets/ap-04-review/ipad-invalid-altitude.png), [compact frequency](../assets/ap-04-review/iphone-invalid-frequency.png) |
| R2 | Guidance and metric-layout fixes verified; human visual acceptance pending | D02-F05 12:557/12:563 directly retrieved and inspected. Unavailable copy describes inability to calculate with current inputs (not falsely absent inputs), directs own-value entry. No-wind course explicitly reference only. Horizontal headline metrics with narrow-space stacked fallback restore hierarchy. [iPad available](../assets/ap-04-review/ipad-check-available.png), [unavailable](../assets/ap-04-review/ipad-check-unavailable.png), [landscape](../assets/ap-04-review/ipad-landscape-check.png), [iPhone available](../assets/ap-04-review/iphone-check-available.png), [unavailable](../assets/ap-04-review/iphone-check-unavailable.png) |
| R3 | Test defect fixed and complete flow verified | Exposed Edit/Rejoin controls measure shared300pt content width (338pt card minus19pt each side), aligned x and44pt minimum height; no assumption of ScrollView existence. Full original remaining Edit/close/Rejoin/post-rejoin editor sequence passes. [Overlap choice](../assets/ap-04-review/ipad-overlap-choice.png), [post-rejoin editor](../assets/ap-04-review/ipad-post-rejoin-editor.png). No application routing change |

Run provenance: session ActionArtifacts `4342E0E2-E728-4F71-861B-48E15514BBBF`.

| Local run (+0200) | Results | Reuse / limits |
| --- | --- | --- |
| 11:01:20 | Build including tests passed | Compiler validation before focused run |
| 11:01:31 iPad | 6/6 passed | Two new domain argument cases; overlap, cue validation, available and unavailable UI. Captures exported `/tmp/ap04-remediation-ipad` |
| 11:05:55 iPhone | 3/3 passed | Cue validation, unavailable, full heading/Check flow. Export `/tmp/ap04-remediation-iphone` |
| 11:08:39 iPhone | 2/2 passed | After horizontal metric change: normal and maximum-text heading/Check flows. Export `/tmp/ap04-remediation-iphone-final` |
| 11:10:50 iPad | 5/5 reported passed | Portrait, landscape, maximum text and selected partial/nonmutation domain results. Tool reports selected parameter results, not all argument combinations; no new212-case claim. Export `/tmp/ap04-remediation-ipad-final` |
| 11:13:32 | Final BuildProject including tests passed, no errors | `BuildProject-Log-20261125-111332.txt` |

All retained images were directly viewed. Device/OS: AP01 iPad11 and iPhone16Pro,
iOS27.2; full-resolution originals, fixture/test timestamps and SHA256 hashes
in [provenance](../assets/ap-04-review/provenance.json). Fixture recipes are
existing `launchManualAmendmentReview`, `A-progress-heading`, `B-open-overlap`.
Metric/content comparison is bounded: D02 guidance, card distinction and
horizontal hierarchy observed; native font/control treatment is adaptive.
Portrait captures show a partly obscured mode caption; maximum-text Check
captures at initial scroll position do not expose all metrics. No whole-screen
visual match or usability approval is claimed. Human visual acceptance remains
pending, including these capture limitations.

No test failure occurred during remediation. The initial test-tool response was
empty, so BuildProject established compilation before the actual focused run.
Attachment export first failed on result-bundle filesystem permissions (tooling);
approved elevated export succeeded. No application changes followed either tool
problem. The only repeated UI flows were needed after the metric-layout change.
Approximate remediation effort: exploration5min, implementation5min, test/tool
repair1min, verification12min, delivery4min (27min total). Original issue-wide
Reduce Motion verification and human acceptance remain pending; this remediation
does not mark #228 complete, merge the PR or close the issue.
