# Amendment preparation · Approved and published tasks

## D04 scoped approval · John · 2026-11-24

[Approved D04 frame/notes](https://www.figma.com/design/JCyQhDDzCPfrrbv6SBcwKw?node-id=48-409)
supersede conflicting plotting/continuation controls, plotting-off value gating and
short-point correction only; D03 geometry/unaffected D02 and dated history remain.
Approved [product contract](https://github.com/johnbenz13/NavigationFlight/blob/5b934ef47c70366d5078995657af2373c675e015/docs/features/IN-FLIGHT-ROUTE-AMENDMENT_SPEC.md) and [D04 revision](https://github.com/johnbenz13/NavigationFlight/blob/5b934ef47c70366d5078995657af2373c675e015/docs/reconciliations/2026-11-23-route-amendment-preparation/proposed/design-revision-d04.md) are fixed at `5b934ef`; merge is pending. Design and
behavior approval does not authorize implementation or check acceptance criteria.

The earlier descriptions below are retained as dated history where D04 supersedes them.


**Status:** approved by John · 2026-11-24, reviewing checkpoint cd6aa2b.
Approval covers the 12 slices, interfaces, time-wheel first-edit semantics,
recovery-error reuse and dependencies. GitHub publication is authorized;
implementation remains separately requested one small task at a time.

Read the [shared contract](contract.md), [approved behavior](../preparing-an-amendment.md)
and [D03 scope/approval](../design-revision-d03.md). Each task includes behavior,
source ownership, exact design targets, deterministic fixtures and acceptance/
test contracts; all inherit the shared preservation and verification rules.

## Approved slices and blocking edges

| Task | Independently reviewable outcome | Blocked by |
| --- | --- | --- |
| [AP-01](ap-01.md) | Pencil toggles a stable workspace; regular Cockpit stays unchanged. | Baseline merged to main |
| [AP-02](ap-02.md) | Plot points into a growing list; stop plotting before rejoin. | AP-01 |
| [AP-03](ap-03.md) | Deliberate forward rejoin, occurrence choices and same-leg detours. | AP-02 |
| [AP-04](ap-04.md) | Open the map/row editor and save heading independently. | AP-02 |
| [AP-05](ap-05.md) | Set bounded leg time with minute/second wheels. | AP-04 |
| [AP-06](ap-06.md) | Add/clear optional altitude, radio and visual cues. | AP-04 |
| [AP-07](ap-07.md) | Correct points and Undo geometry/values/cues together. | AP-05 |
| [AP-08](ap-08.md) | Assisted estimates and preparation map aids with editable values. | AP-07 |
| [AP-09](ap-09.md) | Persist/recover per-Flight work, retry saves and discard safely. | AP-07 |
| [AP-10](ap-10.md) | Warn once about an overtaken unarmed departure and update it. | AP-07 |
| [AP-11](ap-11.md) | Explicit Arm commits once through existing scheduled confirmation. | AP-03, AP-09, AP-10 |
| [AP-12](ap-12.md) | Inspect accepted values; explicitly disarm before pending edits. | AP-11 |

All tasks also require the approved product/design checkpoint merged to main
through PR #223 or an explicit successor, followed by ticket-workflow readiness
checks. AP-08/AP-06 need not block Manual arming: all accepted values share the
same typed entry contract. UI controls retained temporarily between tasks must
continue working; no ticket may claim the entire preparation flow is complete.

Recommended review order follows the numbers, but the dependency graph does not
invent blockers merely to enforce that order. Each task includes its own affected
device, accessibility, tests and visual acceptance. There is no deferred all-UI,
all-schema, all-tests or final responsive ticket. Begin with AP-01 only when its
implementation is requested and the baseline gate passes.

## Requirement → task → design → verification coverage

D03 owns layout/grouping; D02 supplies retained state contents. Every D02 console
inherits D03 sizing. The regular Cockpit is an existing-pattern preservation
contract; node 29:989 is never its general visual target.

| Requirement | Task coverage | Exact design target/rule | Verification contract |
| --- | --- | --- | --- |
| G01 visibility, untouched/edited exit, plotting-off resume, statuses | AP-01, AP-09, AP-12 | D03 29:883/29:1238/29:1167; D02 13:639 | Toggle/state tests; timer/camera and regular-Cockpit comparisons; persisted resume and pending/Flying fixtures |
| G02 departure, partial rows and exclusive map input | AP-02 | D02 20:1370/11:73 with D03 geometry | Partial-route projection, duplicate rejection, plotting/selection UI tests |
| G02 forward/same-leg rejoin, crossings, continuation, completed anchors | AP-03 | D02 13:595 | Route-order/canonicalization tests and explicit occurrence/continuation UI paths |
| G02/G03 correction, cue association and complete Undo | AP-07, AP-08 | D02 11:245/13:595 | Stable-edge tests; selective invalidation/recalculation; snapshot Undo UI evidence |
| G03 map/row editor, partial heading, Check unchanged/unavailable | AP-04 | D03 29:1039/29:1298; D02 12:503 | Shared editor intent, nil/entered state, Check comparison and Manual no-aid tests |
| G03 duration wheels/ranges, no initial acceptance | AP-05 | D03 29:1039/29:1298; D02 12:503 | 00:00/00:01/59:59/60:00 boundaries; clear/partial UI paths |
| G03 optional cues, valid channels and custom-value preservation | AP-06, AP-07 | D02 12:503; D03 29:1298 | Channel/range/clear/custom-value tests; note keyboard and surviving/removed-edge cues |
| G03/G06 Manual/Assisted capture, missing estimates, provenance/aids | AP-08, AP-09 | D02 11:591/12:503 | Estimator parity, exact minute fractions, independent drift toggle and recovery |
| G04 derived readiness, explicit/durable Arm, failures, no Start now | AP-11 | D03 29:883; D02 13:806/13:639 | Readiness matrix; pre/post-write failure/retry and one event; timer continuity |
| G04/G05 armed read-only/disarm/discard | AP-12 | D02 11:959/13:806 under D03 | Cancellation and draft-store failure boundaries; recoverable edit/discard UI paths |
| G05 per-Flight restart, unsaved status, corruption/version safety | AP-09 | D02 13:806/13:639; approved shared error pattern | Injected storage/revisions; cold reopen, other Flight and legacy recording compatibility |
| G05 overtaken departure warning, Later/Update, no GPS/time heuristic | AP-10 | D02 13:806/13:595 | Controlled reported-progress tests; once-per-invalidation alert and persistent warning |
| G06 completed/retained/bypassed/proposed roles; no operational draft effects | AP-01–AP-03, AP-07–AP-08 | D03 map/legend rule; D02 route state nodes | Map projection, role patterns/labels and unchanged Flight/event assertions |
| G06 stable geometry and protected regular Cockpit | Every UI task, owned initially by AP-01 | D03 geometry rules; regular current approved patterns; 29:989 pencil/text only | Same-state viewport/camera and unchanged instruments/actions/clock checks |
| G07 grey awaiting Start leg, green Flying read-only | AP-01, AP-12 | D02 13:639 plus read-only D02-F09 pattern | Existing progression-policy fixtures and rejection of edit intents |
| Accessibility/platform constraints | Every affected task | D03 adaptive/native rules; D02 20:1165 accessibility study | 44 pt controls, wrapping/scrolling, VoiceOver meaning/order, Reduce Motion and exact-node screenshots |

## Approved technical details

The [shared contract](contract.md#proposed-interfaces-and-invariants) proposes
stable logical edges plus geometry signatures, complete Undo snapshots, a
separate versioned per-Flight draft store, retry/revision guards and safe
disarm coordination. These resolve code-level gaps without redesigning Flight.

One wheel detail is explicit for review: the first deliberate minute/second edit
sets the other component to zero; merely opening does not set a duration. AP-05
will not infer a different behavior silently. AP-09 also proposes reusing D02-F10's
scoped recovery-error presentation for corrupt/unsupported draft data. These
details were approved by John with this enriched breakdown.

## Existing tracker treatment and publication plan

Published parent #224 and 12 sub-issues #225–#236 in dependency order, using
native parent/blocker relationships and the enhancement label. All retain the
baseline PR gate and are not labelled ready-for-agent. Publication does not
authorize implementation.

Read full bodies/comments of #204–#212 on 2026-11-24. #204–#209 are closed:
retain their delivery history, reuse their operational code and do not reopen
them. This is a preparation refinement, not a reimplementation of flying.

| Existing work | Proposed disposition |
| --- | --- |
| #204/#205 preparation UI | New tasks implement approved scoped supersessions; keep completed acceptance/history. |
| #206/#209 confirmation and pending management | Reuse durable operations in AP-11/AP-12; preserve existing armed missed-departure behavior. |
| #207/#208 flying and rejoin | Regression boundary only; no new flying/rejoin UX in these tasks. |
| #210 Flight Undo | Remains deferred/out of scope; preparation Undo in AP-07 is a different operation. |
| #211 Assisted preparation + flying | AP-08/#232 covers only preparation; #211 links that overlap and retains its flying remainder for later reconciliation. It remains open. |
| #212 History/Debrief | Remains deferred/out of scope; no changes to replay/export semantics. |

Read back published bodies and native relationships before recording publication
complete. Planning PR merge and implementation remain separate decisions.

**Owner approval recorded:** John approved the numbered tasks, interfaces,
first-edit time semantics and blocking edges. No further feature or flying scope
is introduced. Publication records follow below.

## Publication record

Parent: [#224](https://github.com/johnbenz13/NavigationFlight/issues/224).

| Task | GitHub issue | Native blockers |
| --- | --- | --- |
| AP-01 | [#225](https://github.com/johnbenz13/NavigationFlight/issues/225) | None; baseline PR gate applies |
| AP-02 | [#226](https://github.com/johnbenz13/NavigationFlight/issues/226) | #225 |
| AP-03 | [#227](https://github.com/johnbenz13/NavigationFlight/issues/227) | #226 |
| AP-04 | [#228](https://github.com/johnbenz13/NavigationFlight/issues/228) | #226 |
| AP-05 | [#229](https://github.com/johnbenz13/NavigationFlight/issues/229) | #228 |
| AP-06 | [#230](https://github.com/johnbenz13/NavigationFlight/issues/230) | #228 |
| AP-07 | [#231](https://github.com/johnbenz13/NavigationFlight/issues/231) | #229 |
| AP-08 | [#232](https://github.com/johnbenz13/NavigationFlight/issues/232) | #231 |
| AP-09 | [#233](https://github.com/johnbenz13/NavigationFlight/issues/233) | #231 |
| AP-10 | [#234](https://github.com/johnbenz13/NavigationFlight/issues/234) | #231 |
| AP-11 | [#235](https://github.com/johnbenz13/NavigationFlight/issues/235) | #227, #233, #234 |
| AP-12 | [#236](https://github.com/johnbenz13/NavigationFlight/issues/236) | #235 |
