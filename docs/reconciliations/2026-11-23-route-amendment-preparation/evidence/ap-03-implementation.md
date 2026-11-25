# AP-03 implementation and verification ledger

## Review R1 · cancel automatic rejoin · 2026-11-25

Origin: [P2 review](https://github.com/johnbenz13/NavigationFlight/pull/240#issuecomment-7146569986),
reviewed/current starting revision `5efab638d79deb6d45ff1e5bfbaa502e6905225b`.
Authority retrieved and inspected: D04 notes `48:565`, especially `48:569–570`:
open drawing accepts free points and proposed-leg value editing; no return-mode toggle.
No geometry/style/assets change is proposed. Existing Drawing console, growing rows,
native occurrence controls and editor remain the visual contract. The review's
iPad reproduction is the pre-fix rendered baseline; new domain regression reproduces
both entry paths and all three reported symptoms (2 failures, 07:15:25).

| Criterion | Observable result | Fixture | Verification |
| --- | --- | --- | --- |
| Cancel automatic rejoin | Exact pre-choice draft restored, including drawing step | Forward/reverse overlap, direct and Edit/Rejoin paths | Domain parameterized regression |
| Continue plotting | Free tap adds point/leg, existing identity retained, no rejoin | Same domain fixture; rendered B-overlap-occurrences | Domain assertions + actual chart interaction/rows |
| Edit proposed leg | Short chart hit opens existing editor after cancellation | Same fixtures | Domain typed hit + rendered map hit/editor/Cancel |
| Preserve departure choice | Back from departure occurrence remains departure selection | Crossing departure fixture | Existing/focused domain boundary |
| Usable cancellation presentation | Single Back to map restores Drawing; obsolete return prompts absent | iPad portrait first; iPhone portrait and iPad landscape | UI regression/screenshots inspected; D04 behavior comparison |

Failure classification: application state-transition defect, not fixture or tooling.
Earlier passing checks remain retained except this newly covered cancellation path.

**Disposition: fixed and verified.** `RouteAmendmentDraft.update(.back)` now returns
rejoin occurrence cancellation to `.drawing`; departure occurrence cancellation
still returns to `.departure`. No presentation, fixture or map adapter source changed.

| Run · 2026-11-25 local time | Result | Retained provenance |
| --- | --- | --- |
| 07:15:25 | New two-case regression red: exact draft recovery, point append and chart editor all fail | Original DerivedData `Test-NavigationFlight-2026.11.25_07-15-25-+0200.xcresult` |
| 07:17:12 | 5 domain cases + iPad portrait UI passed | `r1/ipad-portrait/manifest.json` |
| 07:17:57 | iPad landscape interactions passed; screenshot capture rejected | Replaced by 07:20:16 evidence |
| 07:18:37 | iPhone portrait UI passed | `r1/iphone-portrait/manifest.json` |
| 07:20:16 | iPad landscape UI + corrected full-screen capture passed | `r1/ipad-landscape/manifest.json` |

Final BuildProject (including test targets) passed at 07:20:15 (2.859s),
changed domain-file diagnostics: zero. Final diff and local evidence links checked.
Tests use actual map taps after cancellation, not an injected map-input override.
Domain cases cover both direct-anchor and overlap-chooser entries, unchanged draft
and first-leg identity, free append and proposed-leg editor, plus departure and
current-progress boundaries. Existing broader passes remain valid; this change
adds no controls and preserves prior Larger Text/VoiceOver/Reduce Motion coverage.

The implementing agent directly inspected all retained R1 captures. D04 `48:569`
interaction rule matches the restored Drawing prompt, actual editor and appended
Point 2/second row. This is a bounded behavior comparison, not a new quantitative
visual approval of the inherited shell. Full-resolution captures:

- [iPad Drawing](<../assets/ap-03/r1/ipad-portrait/Route amendment - r1-back-to-drawing.png>),
  [chart editor](<../assets/ap-03/r1/ipad-portrait/Route amendment - r1-map-values-after-back.png>),
  [free point](<../assets/ap-03/r1/ipad-portrait/Route amendment - r1-free-point-after-back.png>).
- [iPhone Drawing](<../assets/ap-03/r1/iphone-portrait/Route amendment - r1-back-to-drawing.png>),
  [chart editor](<../assets/ap-03/r1/iphone-portrait/Route amendment - r1-map-values-after-back.png>),
  [free point](<../assets/ap-03/r1/iphone-portrait/Route amendment - r1-free-point-after-back.png>).
- [Landscape Drawing](<../assets/ap-03/r1/ipad-landscape/Route amendment - r1-back-to-drawing-landscape.png>),
  [chart editor](<../assets/ap-03/r1/ipad-landscape/Route amendment - r1-map-values-after-back-landscape.png>),
  [free point](<../assets/ap-03/r1/ipad-landscape/Route amendment - r1-free-point-after-back-landscape.png>).

Human visual acceptance remains pending. Existing scrollable-console behavior
can clip below-viewport prompt/Back content until scrolled; the UI test uses the
established scroll helper to activate Back. This fix does not redesign that layout.

Approximate effort: exploration/spec/review 4min; implementation/tests 3min;
test/tool repair 2min; verification/comparison 4min; delivery 2min.
Avoidable reruns: one test build used an incorrect helper name (test defect), and
one landscape evidence run used app rather than full-screen screenshot (test
capture defect, corrected using existing helper convention). No application edits
followed either failure; the production change remained one line. The independent
device helper's optional cold-launch check was blocked by CoreSimulatorService
permissions (tooling); its ordinary persisted-app screen is not R1 evidence and
no independent live pass is claimed. Xcode-driven UI passes above remain valid;
no broad/evidence-only rerun was performed. Helper session closed.

Issue #227; branch `feature/deliberate-forward-route-tap`.
Baseline `bfe4b068064d075fdef0644cb003af68ad9b7fd3`: #226 closed through
PR #238, merged to main; fetched ancestry, clean tree and synchronized main
verified before branch creation. Its prerequisite #225 closed through merged
PR #237 (`7978220`), also verified in origin/main. No open #227 PR found.
AP-02 visual acceptance remains pending independently of its authorized merge.

## Pre-edit acceptance matrix

| Criterion | Observable result | Fixture | Verification |
| --- | --- | --- | --- |
| Deliberate eligible rejoin | Tap ends plotting; existing rows stay; an untapped crossing adds no connection | A partial, B crossing | Domain/feature transitions and Flight invariance; rendered tap/row/edit checks |
| Forward order | Same-leg 30%→80% succeeds; equal, earlier and completed occurrences fail atomically | B triangle and progress variants | Parameterized domain assertions, final-route validation; rendered invalid feedback |
| Occurrence choice | Choices identify leg and fraction; selection rechecks current progress | B coincident/repeated coordinates | Domain deduplication/revalidation; rendered chooser/readability and selection |
| Continue/change return | Continue converts return to via; Change removes return and retains intermediate work | A closed, B crossing | Identity/value/geometry assertions; rendered continuation and changed-return checks |
| Removed gates | No Finish here, Review legs, Pick a point or Inspect leg preparation gate | A/B | Source and relevant UI assertions; accessible waypoint/map-center routes retained |

Domain assertions establish state/data correctness. Row counts, frame equality
and panel existence alone cannot establish visual correctness or usability.

## Authority and visual contract

G02/G06 and shared task contract; D02 F03 `13:595` owns rejoin, continuation,
occurrence and invalid-state content. D03 portrait `29:883`, landscape `29:1167`,
compact `29:1238` own geometry. All four contexts and screenshots retrieved
directly from Figma before editing. F03's three topology diagrams are explanatory
design illustrations, not application raster assets; reuse live map rendering.

Reproduce with disposable existing A/A-partial and B crossing fixtures, controlled
display clock 07:22. AP-02 projects adjacent rows with stable point UUID/anchor
occurrence identities; reuse it, AP-01 shell and existing verification helpers.
Retain the shared 288 pt portrait/278 pt compact/370 pt rail policy and environment
adaptations, fixed timing/actions and internally scrolling leg list. Existing
20 pt portrait/16 pt compact insets, 4 pt row gaps, 12 pt row corners, semantic
SF typography/surfaces, teal selection and 1.5 pt outline remain. Native bordered
Continue plotting and borderless Change return point use >=44 pt targets;
occurrence choices expose leg/fraction and route names, with text beyond color.
Adaptive wrapping/scrolling follows the shared accessibility shell. No new motion.

Affected states: partial plotting; rejoined/off; crossing chooser; invalid tap;
continued/via/on; changed-return/on; stopped/editable and reopened/off. Each uses
F03 content within D03 geometry. Primary iPad portrait 834×1194 first; after
stabilization iPhone portrait 402×874 and iPad landscape 1194×834. Changed controls
require Larger Text, VoiceOver and actual Reduce Motion evidence. Regular Cockpit,
execution, wheels, partial-value persistence and Assisted defaults are excluded.

## Verification ledger

| Check | Result | Evidence/reuse boundary |
| --- | --- | --- |
| Readiness | Passed | Merge/ancestry/synchronization above |
| Mandatory skills | Loaded | Figma MCP resource skills design-to-code and swiftui plus design-to-code reference; local SwiftUI, Swift Testing, device-interaction skills |
| Pre-edit simulator comparison | Inspected | iPad A-partial on/off, ActionArtifacts A5191CA3, DeviceInteractionSynthesize AP03 Pre Edit Baseline 18:38:13/18:38:27; implementing agent directly inspected ON screenshot against retrieved D03/F03 |
| Domain and routing | Passed | Seven new cases passed at 19:49; 257 regression cases at 19:52 produced 251 passes and six obsolete-gate expectation failures; six migrated cases passed at 19:52:58. Reused 251 passing results; no application change for those failures |
| Build/diagnostics | Passed for current source | BuildProject including tests at 19:52:58, 10.841 s; draft/console diagnostics clean |
| Rendered interactions/design | Preliminary functional pass; presentation discrepancy | iPad portrait continuation/change-return UI test passed 19:50. F03 actions below visible rows require scrolling, disabled Plot points gives no obvious next step. Direct screenshot inspection caught this despite test pass; owner placement decision requested |
| Accessibility | Pending | Larger Text, VoiceOver, Reduce Motion |
| Delivery | Pending | Documentation, links, diff check, issue evidence comment; no commit/push/PR authorization |

## Failures, reruns and time

Tool discovery: initial search missed Figma MCP resource skills, causing an
avoidable handoff. User corrected it; skills loaded without reducing gates.
No implementation/test rerun resulted. Investigate after two failures with the
same unexplained cause before further implementation changes.

Approximate time allocation and consolidated evidence will be recorded here.
Human visual/product acceptance remains separate and unchecked.

### Presentation decision checkpoint

Directly inspected passing-run screenshots retained under `../assets/ap-03/`:
[rejoined](../assets/ap-03/Route%20amendment%20-%20ap03-rejoined-portrait.png),
[continued](../assets/ap-03/Route%20amendment%20-%20ap03-continued-rejoined-portrait.png),
[changed return](../assets/ap-03/Route%20amendment%20-%20ap03-changed-return-portrait.png).
Authority: F03 `13:595` + D03 portrait `29:883`. Rows and fixed timing/actions
remain, but Continue plotting and Change return point are below the initial
viewport. This is discrepant/unaccepted, not a visual match. Native scrolling
makes the actions reachable in the test, but does not establish discoverability.

Asked owner whether to use the established on-map panel geometry, put Continue
in the heading with Change in a menu, or retain the scrolling arrangement.
No dependent presentation changes or secondary-device acceptance claims until
that decision. Accessibility and required secondary layouts remain outstanding.

Failure classification: six regression failures were fixture/test defects caused
by superseded gate expectations; updated to immediate rejoin and retained their
original geometry/order/Undo assertions. Test-name discovery is cached until
build/refresh; two rejected requests ran no tests (one new name, one renamed name).
Build plus GetTestList resolves it. First GetTestList response was truncated to
100 entries; use its retained full list for later identifiers. Modern xcresult
attachment export attempted to write a read-only source bundle and failed once;
the known AP-02 legacy object-export path succeeded without rerunning tests.
An old device session was unavailable after UI testing; no application fix made.

Approximate checkpoint allocation: exploration/readiness/design 10 min,
implementation 8 min, test/tool repair 4 min, verification 5 min, checkpoint
evidence/reporting 2 min (~29 min). Avoidable tool requests: missing MCP resource
discovery, truncated-list lookup, cached-name requests, modern attachment export.
No repeated unexplained application failure; no broad passing-suite rerun.

## D04 implementation revision · 2026-11-24

This revision supersedes the earlier AP-03 continuation expectations above. D04
PR #239 merged at `3eadbee`; approved paired baseline `5b934ef`. Existing dirty
implementation and historical evidence preserved. Mandatory SwiftUI, Swift Testing,
Figma design-to-code/SwiftUI and device skills loaded.

| Acceptance/state | Authority | Deterministic reproduction | Required evidence |
| --- | --- | --- | --- |
| Pencil/direct departure, growing rows | D04 spec items 1–2; notes 48:568–570 | A-empty then eligible route tap and free point | Domain + primary portrait interaction |
| Automatic forward rejoin; equal/earlier/completed rejected | D04 item 1; retained F03 13:595 | Same-leg 30%/80%; B repeated occurrences | Parameterized order/canonicalization tests + chooser |
| Proposed leg/row values before/after closure | D04 item 2; 48:569 | A-partial row/map hit; close values; rejoin and repeat | Feature/domain preservation + rendered editor |
| Open overlap Edit / Rejoin; choice revalidation | D04 item 2; 48:569 | B proposed/original hit during drawing | Typed domain choices + rendered chooser |
| Closed original/free taps inert; removed gates absent | D04 items 1–2; 48:572; frame48:409 | A-partial rejoin then original/free taps | Geometry equality + rendered no controls |

Visual contract: directly retrieved high-fidelity D04 frame48:409 and notes48:565,
inspected exported reference `/tmp/d04-reference.png`. Preserve AP01/AP02 native
shell and live map; chart/route illustration assets are explanatory geography,
not runtime raster replacements. D04 uses noninteractive Rejoined status in the
heading instead of the Plot button. SF semantic text/surfaces, 20pt portrait inset,
288pt console, fixed timing/actions and scrolling rows retained; secondary D03
landscape29:1167 and compact29:1238 geometry unchanged. Existing native chooser /
editor panel supplies adaptive spacing and >=44pt action targets. Corrections remain
AP07; wheel/partial-value changes AP04. No new animation.

Pre-edit comparison: directly inspected iPad834×1194 screenshot
`ActionArtifacts/A5191CA3-A605-4CBD-8E72-A063C51F7BD6/DeviceInteractionSynthesize/ap03-d04-22_44_14_725-screenshot.png`
against D04. Existing rejoined four-leg draft visibly has disabled Plot points,
Continue plotting and Change return point, all superseded by D04. Geometry uses
existing D03 shell; final visual match remains unverified until new passing captures.
Old session was closed; replacement `ap03-d04` opened. This is tooling lifecycle,
not an application failure. No build/test rerun caused.

### D04 progressive verification

- Main `NavigationFlightTests`: 179 cases, 176 passed initially; three superseded
  mode/closed-overlap expectations migrated and passed in a focused three-test rerun.
  Reused the other 176 passes. New Edit/Rejoin choices, forward ordering,
  endpoint normalization, closed-tap invariance and Flight isolation passed.
- Primary direct-drawing UI passed, then reran once after direct screenshot review
  found redundant lower Rejoined text clipped under rows. Removed it; D04's heading
  status supplies the information. Focused rerun passed. Retained screenshots under
  `assets/ap-03/d04/`; first screenshot is historical before that small correction.
- Landscape, Larger Text and actual VoiceOver missing-value regression: 3/3 passed.
  Directly inspected landscape and Larger Text captures. Landscape retains 370pt
  rail and fixed controls; Larger Text keeps editable content in an independently
  scrollable native panel. VoiceOver transcript includes Drawing and both missing
  values on the proposed-leg button. This alone does not verify new chooser actions.
- Eight migrated UI checks: 7 passed (accessible departure/map-center/automatic
  return; departure and return occurrence choices; continuous rows/Undo; partial
  drawing/edit/save/resume; untouched workspace; retained incomplete pencil draft).
  Overlap test required two test corrections: Rejoin first opens original-route
  occurrence choice; closed coincident proposed legs first open the existing leg
  chooser. Camera equality across Edit passed. Neither failure justified an app
  camera change. Retained failed diagnostic captures separately in `/tmp/d04-diagnose`;
  final acceptance captures must come from the passing run.
- Exact completed-first-leg/leg-2 fixture uses the real Flight progression rules
  in the existing disposable DEBUG preparation helper. Its first run exposed a
  helper assertion requiring the old start checklist after progression; made that
  expectation optional only for this fixture.
- ActionArtifacts' copied xcresult lacked Info.plist. Original DerivedData bundle
  remained valid; legacy object export recovered passing artifacts with no rerun.
  The earlier proposed retention diagnosis was corrected after inspecting originals.


### Compact accessibility adaptation

Compact normal direct drawing passed. Largest Text exposed a relevant app defect:
the unchanged operational header left the new chart chooser a 39.3pt viewport,
smaller than its required 44pt actions. The new drawing overlap and noninspection
proposed-leg choices now use a persistent native confirmation dialog and a
scrollable native sheet/list successor only for compact accessibility sizes. The protected header, shell, map and regular-size presentation
remain unchanged; authority is D04 native Edit/Rejoin choice plus shared reachable
44pt/native-alert adaptation rule. Apple DocumentationSearch and SwiftUI navigation
reference consulted. Presentation dismissal owns visibility only; Edit/Rejoin/Cancel
send typed draft intents. Dismissal must not erase a successor leg chooser.

First native run exposed duplicate native accessibility Button nodes (firstMatch
query correction). A visibility callback then cleared the pending choice before
the native action; an attempted one-turn deferred dismissal was insufficient and
was removed, with the concurrency guidance consulted. No delay or new animation
was added. Typed domain overlap tests remained passing; native chained-choice and
cancel behavior are tested directly, not inferred from domain results.

The Arm-enabled assertion was an incorrect test expectation: AP-01 intentionally
keeps Arm disabled until AP-11. Production `.disabled(true)` was never changed.
Corrected the test to disabled plus Ready projection. Exact A fixture now names
leg 2 Kadima → Ramat, completes leg 1, departs46%, and shows07:22/04:23 with the
three specified leg values. Fixture progress chooses activeLegIndex because the
canonical firstAvailable can be the completed preceding leg's100% endpoint.

### Final D04 verification and acceptance audit

Domain coverage: **259 passing cases** (179 main cases, combining176 retained
passes with3 corrected expectations;80 estimate/recovery cases). No domain code
changed after these passes. The old AP-02 total is historical: its mode/continuation
checks were replaced by direct-input, automatic-return, closed-tap and explicit
inspection checks. Unrelated AP-04/05 editor wheels/partial saving, AP-07 full
corrections and AP-09 persistence are outside this slice; Arm remains disabled
until AP-11.

| Run (original xcresult local timestamp) | Focus | Result/reuse |
| --- | --- | --- |
|22:46:45 +22:48:09|Main domain and corrected D04 expectations|179 passing cases combined;176 passes reused|
|22:49:24|Primary direct input/value editing/rejoin|Passed after removing redundant lower status|
|22:50:12|Landscape, Larger Text, actual VoiceOver missing values|3 passed; retained|
|22:53:39|Migrated input, occurrence, rows, save/resume, pencil|7 passed; overlap successor assumptions corrected separately|
|23:01:18|Rendered map overlap Edit/Rejoin, Larger Text, new VoiceOver actions|3 passed; subsequent native adaptation has its own compact checks|
|23:04:30|Estimate + recovery domain|80 passed|
|23:06:14|Explicit original inspection/occurrence + expanded Larger Text|3 passed; corrected wrong Arm expectation separately|
|23:08:44|Exact A leg2/departure46% + completed-return rejection|2 passed|
|23:09:54|Compact normal direct drawing|Passed; compact Largest Text defect investigated|
|23:25:34|Compact native Rejoin -> occurrence -> chosen return|Passed; successor visibility wait and tiny-viewport helper corrected|
|23:27:49|Compact Largest Text Edit/editor/Cancel, Rejoin, outside cancel; multi-leg sheet/editor/Cancel; actual VoiceOver|3 passed|
|23:29:58|AP-01 untouched/edited workspace boundary|Passed; new44pt chooser assertion exposed label-frame defect|
|23:30:54|Primary rendered overlap, map editor, stable camera,338pt panel/44pt targets|Passed after moving target frame inside labels|

All timestamps refer to `Test-NavigationFlight-2026.11.24_HH-MM-SS-+0200.xcresult`
in the original DerivedData `Logs/Test` directory. Successful artifacts were
exported with legacy xcresult object/export; no passing suite was rerun for
copied-bundle retention. Export manifests are per-export inventories; this table
is the authoritative combined provenance ledger.

| Acceptance mapping | Concrete evidence under `../assets/ap-03/d04/` | Status |
| --- | --- | --- |
|Direct departure/free point; growing row; automatic forward rejoin|`Route amendment - d04-accessible-return-portrait.png`; main input/order tests; crossing chart UI checks|Objective passed|
|Same-leg/endpoints/equal/earlier/completed return constraints|Main parameterized order/anchor tests; `Route amendment - d04-invalid-completed-return.png`|Objective passed|
|Open and closed proposed values via rows and actual chart hits|`d04-open-values-portrait`, `d04-closed-values-portrait`, `d04-closed-map-editor` PNGs; primary UI assertions|Objective passed|
|Open Edit/Rejoin and actual occurrence selection|`d04-overlap-choice`, `d04-overlap-occurrences`, `d04-overlap-rejoined` PNGs; compact `iphone/d04-native-return-*` PNGs|Objective passed|
|Native adaptive choices actionable and cancelable|`iphone/Route amendment - d04-native-proposed-choice.png`; `iphone/Route amendment - d04-overlap-larger-*` PNGs; compact actual VoiceOver transcript|Objective passed|
|Closed free/original taps inert; Flight/camera/draft retained|Domain geometry/Flight assertions; primary settled-camera equality; AP-01 boundary regression|Objective passed|
|Removed Plot/Continue/Change gates absent|Primary UI absence assertions; Drawing/Rejoined screenshots|Objective passed|
|Exact A completed leg1 / leg2 departure46%,3 valued rows|`Route amendment - d04-reference-leg2-portrait.png` (23:08:44); Arm disabled + Ready asserted|Objective fixture passed; visual approval pending|
|Primary/secondary rendered contract|D04 frame48:409 + notes48:565; D03 landscape29:1167 and compact29:1238; corresponding portrait/landscape/iphone PNGs directly inspected|Human visual approval pending|

Direct visual comparison is bounded: D04 status/control semantics and inherited
shell geometry are represented; live geographic/chart content differs from Figma's
illustrative route. The exact A fixture carries approved progress/time/values;
B captures deliberately use crossing/coincident geometry to exercise ambiguous
occurrences. Largest Text preserves the established operational header; native
choice adaptation makes this slice's new actions reachable. No claim is made that
unchanged AP-04/05 editor content is redesigned. Native sheet Edit leads to the
actual existing editor and its Cancel returns successfully.

Failures were classified before changes: superseded/early assertions and query/
scroll helpers were test defects;39.3pt chooser viewport and20.5pt accessible
button target were app defects; copied xcresult absence was a tool-path issue.
Repeated native failures triggered lifecycle diagnosis: conditional presenter and
chained native dialog were replaced by a persistent host plus native sheet.
No sleep-based presentation delay, camera workaround or broad refactor was added.
Timing (wall-clock approximate,22:42–23:33): preparation/baseline3min;
implementation/domain migration7min; focused UI/accessibility diagnosis24min;
verification/export/comparison17min. Native adaptation caused focused reruns only;
passing domain, landscape and other primary checks were retained.

Human owner visual acceptance is **unchecked**. Implementation verification and
merge authorization do not satisfy that separate gate. Do not mark #227 complete
or merge until the owner approves the cited visual evidence (or explicitly records
an approved deferral).


Final bounded device-interaction verification (23:32–23:33) independently exercised
Edit→editor→Cancel, subsequent proposed-row editing, and pencil close/reopen with
the same one-leg Drawing draft. Actual Settings Accessibility→Motion reports
`REDUCE_MOTION value: 1`; original ON state was retained, no settings restoration
was needed. Retained `reduce-motion-editor`, `reduce-motion-retained` and
`reduce-motion-settings` screenshots/hierarchies identify the actual primary
simulator state. No new animation was introduced. Final source build passed at
23:30:54; chart-panel live diagnostics0; local Markdown links and `git diff --check`
passed. Byte-identical new D04 screenshots were deduplicated; historical AP-03
assets remain preserved. Mapped issue comment:
https://github.com/johnbenz13/NavigationFlight/issues/227#issuecomment-7145081090
