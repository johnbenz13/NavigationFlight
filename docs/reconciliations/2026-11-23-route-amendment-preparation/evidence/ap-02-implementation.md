# AP-02 implementation and verification ledger

Issue #226; branch `feature/continuously-growing-amendment-leg-list`.
[Published acceptance-evidence comment](https://github.com/johnbenz13/NavigationFlight/issues/226#issuecomment-7131320237).
Owner subsequently authorized committing, pushing and opening the implementation PR.
Human visual acceptance remains separate and pending.
Baseline `7978220cddfcc899d627d135bc8bb4a664ca407c`: AP-01 PR #237 merged to main,
#225 closed, native/fallback blockers inspected, clean synchronized main verified.
Owner clarification: show separate heading/time Not set states; retain complete-value
saving until AP-04. No partial-value storage or wheel implementation in AP-02.

## Pre-edit acceptance matrix

| Criterion | Observable result | Fixture | Verification |
| --- | --- | --- | --- |
| Explicit plotting/departure | Entry off; Plot points chooses eligible departure then adds existing/free points | A, B occurrence candidates | Domain transitions; rendered empty/departure/plotting |
| Incomplete rows | Every formed segment immediately has a stable row and separate missing heading/time displays | A: one, two and many legs | Projection/identity assertions; direct design comparison and scrolling |
| Edit before rejoin | Done plotting enables row/map-leg editor; resume requires explicit Plot points | A without rejoin | Feature routing and complete-value save; rendered stop/edit/close/resume |
| Safe input | Plotting taps cannot open editor; off taps cannot place; pan/zoom works | A | Feature/overlay assertions; simulator tap, pan and zoom |
| Route invariants/access | Final destination, duplicate rejection, map-center and occurrence input retained | A/B | Final-route/domain regressions; accessible input interactions |

Domain assertions establish data/transition correctness. Frame equality, row counts
and panel existence do not establish visual correctness or usability.

## Visual contract and state trace

Authority: G02/G06 and shared contract; Figma file `JCyQhDDzCPfrrbv6SBcwKw`.
Direct context/screenshots inspected: D02 empty `20:1370`, partial `11:73`;
D03 portrait `29:883`, compact `29:1238`, landscape `29:1167`.
Empty/off, departure/on, partial/on, partial/off, partial/editor and resumed/on
share these content rules and D03 geometry. Existing native editor stays until AP-04/05;
automatic rejoin completion remains AP-03. Existing explicit rejoin/occurrence
operations remain available without the removed Finish here/Review legs gates.

Reuse AP-01 shell: 288 pt portrait/278 pt compact/370 pt rail shared resting policy,
including safe-area/operational/accessibility adaptations; fixed light timing strip,
44 pt heading/plot action, fixed footer, internally scrolling rows. Portrait inset
20 pt, row min-height 50 pt, gaps 4 pt, radius 12 pt; compact/rail inset 16 pt,
row min-height 60 pt. SF semantic typography, semantic secondary surfaces,
existing amendment teal selection with 1.5 pt outline. Missing fields have separate
named labels/values. Native buttons use >=44 pt targets. Adaptive text wraps/scrolls.
No new route/list animation; Reduce Motion must still be checked at runtime.
Regular Cockpit and chart/map assets remain existing approved implementation.

Primary iPad 834×1194 portrait first; then iPhone 402×874 portrait and iPad
1194×834 landscape. Changed controls require Larger Text, VoiceOver and Reduce
Motion evidence. All visual acceptance remains human-owned.

Pre-edit baseline directly inspected on reference iPad: A ready list switches to
Pick a point and horizontal chips when Plot points turns on, removing formed rows.
Xcode ActionArtifacts session B4CDBB61-6570-4B9D-A564-27F90D453B0F,
DeviceInteractionSynthesize `AP02 Pre Edit Baseline-13_35_47_403` (off) and
`AP02 Pre Edit Baseline-13_36_07_359` (on). Both include full screenshot/hierarchy.

## Verification ledger

All dates below are 2026-11-24; run times are local UTC+02. Retained artifacts are
under `../assets/ap-02/`; `manifest.json` records source bundles and SHA-256 hashes.

| Check | Result | Evidence / reuse boundary |
| --- | --- | --- |
| Readiness | Passed | #225 closed by merged PR #237, main ancestor `7978220`; synchronized clean main before branch/edit |
| Five new domain/feature tests | 5 passed at 13:40 | Partial projection, stable append/Undo/move identities, geometry invalidation, complete-only saving, routing, stop transient choices |
| Domain/recovery/estimate regressions | 250 passed at 13:49 | NavigationFlightTests, RouteAmendmentEstimateTests, FlightRecoveryCoordinatorTests; later presentation/helper edits do not invalidate these |
| iPad portrait core + accessible inputs | 2 passed at 13:49 | One/two/seven rows; stop/edit/save/resume; empty departure, map-center, explicit occurrence input |
| iPad landscape / VoiceOver / AP-01 boundaries | 4 passed at 13:51 | Landscape list and last-row editing; spoken independent missing fields; portrait/landscape protected boundary regression |
| iPhone accessible inputs / VoiceOver / AP-01 boundary | 3 passed at 13:57 | Passing tests retained independently of two other failures in that run |
| iPhone core | Passed at 14:08 | Seven-leg list, exact complete-value save, last-row selection, plot routing, camera/timer, close/reopen |
| iPhone maximum Larger Text | Passed at 14:10 | Final heading adaptation, seven legs, scrolling and editor Cancel; does not certify the excluded editor's full accessibility conformance |
| Reduce Motion runtime | Exercised | Actual Settings ON, append/Done/editor/Cancel/pencil, restored OFF; still images cannot certify all animation timing |
| iPad final Larger Text / affected legacy flows | 8 passed at 14:12; corrected map-center assertion passed at 14:17; 2 lifecycle/accessibility checks passed at 14:18 | Seven-leg Larger Text, crossing choices, interior rotation, Undo, map-center, Check unavailable, incomplete pencil, move/remove/stale recovery/discard |
| Build / diagnostics / diff check | Passed | BuildProject including tests at 14:17 (3.281 s), zero errors; changed application diagnostics clean; final console diagnostic clean; local documentation links and git diff --check passed |

Final retained coverage: 250 domain/recovery/estimate tests and 22 passing device-specific UI checks (17 iPad, 5 iPhone). Mixed-run failures are retained transparently and superseded only by their named passing targeted reruns.

No full UI suite was run. Relevant domain suites and the affected UI paths were
selected progressively; no passing result was rerun solely to recapture evidence.
The unrelated legacy manual chart inspection tests refer to controls already absent
on the AP-01 baseline; this ticket does not claim those tests pass.

### Acceptance audit

| Criterion | Concrete evidence | Acceptance state |
| --- | --- | --- |
| Entry off; eligible departure then existing/free points | Empty/input UI test on both devices; partial core map placement; occurrence tests; domain eligible departure/duplicate regressions | Objective behavior evidenced; rendered acceptance awaits owner |
| Immediate incomplete rows and separate missing values; no operational mutation | Projection/identity tests, feature flight/events assertions, partial-on captures, VoiceOver speech on iPad/iPhone | Objective behavior evidenced; rendered acceptance awaits owner |
| Done enables editing before rejoin; explicit resume | Core UI stop/edit/save/resume tests; complete-only save and no-rejoin final validation domain assertions | Objective behavior evidenced; rendered acceptance awaits owner |
| Safe map routing; pan/zoom retained | Feature routing test; core UI no editor while plotting/no point off; direct portrait device pan+pinch changed camera without adding rows | Objective behavior evidenced; rendered acceptance awaits owner |
| Final destination/duplicate/accessibility routes | Final PendingRouteAmendment validation unchanged; passing domain regression suites; map-center/explicit return and occurrence UI checks | Objective behavior evidenced; rendered acceptance awaits owner |

All five mixed issue criteria remain unchecked. Implementation approval, human
visual acceptance, PR approval, merge and closure remain separate decisions.

### Rendered comparison

Implementing agent directly inspected the authoritative Figma artifacts and the
retained screenshots. D02 `20:1370` owns empty/departure content; `11:73` owns
partial plotting/off content. D03 `29:883` (iPad portrait), `29:1167` (iPad rail),
`29:1238` (iPhone) own geometry and separate field grouping. F14 `20:1165` supplies
wrapping/scrolling and reachable control rules; it is not a claim of native runtime
conformance. F03 `13:595` supplies incomplete-route validity guidance; AP-03's
automatic rejoin flow is excluded.

| State | Screenshot group | Comparison |
| --- | --- | --- |
| Empty off / departure on / accessible input | iPad + iPhone empty, accessible partial, explicit return | Bounded content match to `20:1370`, D03 shell; retained explicit occurrence confirmation is interim until AP-03 |
| Partial off / on | iPad portrait, iPad landscape, iPhone portrait partial-off/on | Bounded match to `11:73` + respective D03 frame: leg rows remain visible, independent missing fields readable, fixed timing/actions; no chip/review-stage gate |
| Selected leg/editor | Normal portrait/rail editor captures | Selected teal row/outline and stable shell match D03 rule; existing native text editor intentionally retained until AP-04/05, not claimed as wheel-design match |
| Growing list | Three normal device/orientation groups | Internal scrolling, last leg selection and fixed controls observed; clipped offscreen rows are scroll content, not evidence of complete readability by themselves |
| Maximum Larger Text | iPad/iPhone larger captures | Controls reachable and scroll/Cancel tests pass. On iPhone the fixed shared shell leaves a narrow list viewport; an entire wrapped row cannot fit simultaneously. No full visual/usability conformance claim; explicit owner assessment remains required |
| Reduce Motion | Settings-on, appended, editor, reopened | Content/state retained with actual setting ON; timing/animation absence remains bounded by still-capture tooling |

Identifiable full-resolution evidence (paths relative to this ledger):

| Reference | Concrete simulator artifact |
| --- | --- |
| D02 `20:1370` + D03 `29:883` | [iPad empty](../assets/ap-02/ipad-portrait/Route-amendment---ap02-empty-portrait.png) |
| D02 `11:73` + D03 `29:883` | [iPad partial off](../assets/ap-02/ipad-portrait/Route-amendment---ap02-partial-off-portrait.png), [on](../assets/ap-02/ipad-portrait/Route-amendment---ap02-partial-on-portrait.png), [editor](../assets/ap-02/ipad-portrait/Route-amendment---ap02-editor-portrait.png), [growing](../assets/ap-02/ipad-portrait/Route-amendment---ap02-growing-list-portrait.png) |
| D02 `11:73` + D03 `29:1167` | [Landscape off](../assets/ap-02/ipad-landscape/Route-amendment---ap02-partial-off-landscape.png), [on](../assets/ap-02/ipad-landscape/Route-amendment---ap02-partial-on-landscape.png), [growing](../assets/ap-02/ipad-landscape/Route-amendment---ap02-growing-list-landscape.png) |
| D02 `11:73` + D03 `29:1238` | [iPhone off](../assets/ap-02/iphone-portrait/Route-amendment---ap02-partial-off-portrait.png), [on](../assets/ap-02/iphone-portrait/Route-amendment---ap02-partial-on-portrait.png), [editor](../assets/ap-02/iphone-portrait/Route-amendment---ap02-editor-portrait.png), [growing](../assets/ap-02/iphone-portrait/Route-amendment---ap02-growing-list-portrait.png) |
| F14 `20:1165` adaptive rule | [iPad Larger Text](../assets/ap-02/ipad-final/Route-amendment---ap02-partial-off-larger-portrait.png), [iPhone Larger Text](../assets/ap-02/iphone-larger/Route-amendment---ap02-partial-off-larger-portrait.png) — constrained, owner assessment required |
| Reduce Motion rule | [Settings ON](../assets/ap-02/device/reduce-motion-on-screenshot.png), [reopened draft](../assets/ap-02/device/reduce-motion-reopened-screenshot.png), [restored setting](../assets/ap-02/device/reduce-motion-restored-screenshot.png) |

[Artifact provenance and hashes](../assets/ap-02/manifest.json) identify every additional screenshot, hierarchy, speech attachment and retained result.

Measured iPad portrait console inset 20 pt, row 794×50 pt, gap 4 pt. Reference
834×1194; map/console remained unchanged through toggles/editor. Compact inset
16 pt, normal row >=60 pt; rail width uses shared 370 pt policy. Plot action has
asserted >=44 pt height; Map tools input uses >=44 pt. Source-defined corners
12 pt and selection stroke 1.5 pt were visually inspected, not pixel-certified.
Native SF weights, semantic secondary surfaces and readable teal selection were
compared side by side; no quantitative pixel/color equality is claimed.

Fixture A uses the existing crossing plan with 25 route legs, planned 04:17 and
07:22 injected elapsed time, rather than Figma's illustrative 2-of-5 / 04:23.
Those data differences and existing chart labels are not visual conformance claims.
Protected regular-Cockpit maximum-text header/legend overlap and AP-01 deferred
maximum-text editor limitations remain visible; AP-02 does not change that scope.

### Failure classification and repairs

- **Application:** disabled rows over-faded; custom button style restored readable
  plotting rows. Plot target initially <44 pt; label frame corrected. Accessibility
  heading scrolled away or consumed list space; kept plot action fixed and exposed
  mode through the accessibility label at maximum text.
- **Fixture/test:** first maximum-text bootstrap reused the normal checklist helper;
  corrected to established AP-01 bootstrap. Hard-coded map placements landed under
  enlarged protected headers or inside existing-point selection radii; retain a
  normal free-map placement and use the established waypoint input for long lists.
- **Fixture/test:** the repeated iPhone waypoint lookup failure was investigated
  after two failures. Direct hierarchy inspection proved medium-sheet lazy loading
  hid the cells; expand/scroll before lookup. No speculative app change was made.
- **Tooling:** modern xcresult attachment export failed twice writing TestReport.
  Investigated permissions/help, then exported original attachment payloads with
  the legacy object API. No tests were rerun for export repair. RunSomeTests' copied
  bundle path was absent; original DerivedData bundle was used. Device simctl
  access failed once in sandbox; Settings UI fallback succeeded.
- **Application:** final iPhone maximum-text list viewport was 37 pt. One-line
  heading restored a usable scroll/tap viewport; targeted rerun passed. Full-row
  simultaneous visibility remains constrained by the shared accessibility shell.

## Time and reruns

Approximate active/waiting allocation (categories overlap only where noted):
exploration/readiness/spec/Figma 14 min; implementation 10 min; test/tool repair
12 min; verification including simulator/test waits 18 min; evidence/delivery 6 min.
Total approximately 60 min, including about 10 min from the initial turn.

Avoidable reruns: normal bootstrap at maximum text; hard-coded long-list placement
on adaptive maps; unexpanded lazy waypoint sheet. Each required a targeted rerun;
the repeated sheet failures triggered cause investigation before further code edits.
One migrated map-center assertion incorrectly expected the name formerly supplied by Finish here; corrected to the unnamed partial point and reran only that test. Renamed test discovery required the already-planned final build. Application changes discovered by direct rendered checks required new affected runs.
The passing 250-test regression result was reused throughout later UI-only work.
