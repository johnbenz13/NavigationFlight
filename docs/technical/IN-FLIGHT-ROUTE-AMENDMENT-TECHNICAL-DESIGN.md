# In-flight route amendment · Technical design

Approved baseline · John · 2026-11-22. Shared operational Cockpit direction approved · John · 2026-11-23.

- Product and detailed visual design approved by John on 2026-11-22. [Product spec](../features/IN-FLIGHT-ROUTE-AMENDMENT_SPEC.md) · [Figma coverage](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=17-254)
- Inspected NavigationFlight revision `258a42cd060195a24086908fecee9bb44312ff30`. Navigation Editor comparison revision `7abb0d1c5551af401ef5d403252bc864e3679040`.
- Scope is a local Flight amendment, including confirmed-route recovery and export/debrief context. No implementation, build, simulator, or test run was performed.

## D04 direct drawing · approved technical scope · 2026-11-24

John explicitly approved D04 on 2026-11-24, including anchor recovery and accessible
actions. Earlier dated approvals and delivery remain historical. Approved
[documentation baseline](https://github.com/johnbenz13/NavigationFlight/blob/5b934ef47c70366d5078995657af2373c675e015/docs/features/IN-FLIGHT-ROUTE-AMENDMENT_SPEC.md) is committed at `5b934ef`; merge is pending.

[Approved product behavior and Figma review](../reconciliations/2026-11-23-route-amendment-preparation/proposed/design-revision-d04.md)
intentionally revise the preparation input contract; this section records future
scope, not implementation or delivery. Earlier approved/delivered sections remain
historical. John approved the D04 design; implementation authorization remains separate.

- Replace the user-controlled plotting toggle with geometry-derived interaction:
  missing departure selects departure; open replacement appends points; eligible
  deliberate return closes drawing. Ordinary taps after rejoin never extend it.
- Proposed-leg and row short taps share the value-editor intent before and after
  rejoin. An eligible original/proposed overlap presents **Edit / Rejoin** and
  revalidates the chosen intent against current progress before applying it. Offer
  Rejoin only while drawing with a departure. After closure, proposed-leg taps
  only edit and original/free-map taps preserve geometry; deleting rejoin is an
  explicit correction that reopens drawing.
- All points include departure/rejoin. Long-press drag moves; long-press release
  without drag offers Delete. Anchor placement resolves eligible original-route
  occurrences and strict forward order, including same-leg fractions. Reject an
  invalid drop atomically with feedback; movement/crossing alone never rejoins.
  Preserve map pan/pinch and require long press before moving a point.
- **Approved recovery:** deletion of departure retains vias,
  rejoin and unaffected values, awaiting eligible replacement departure; deletion
  of rejoin explicitly restores open drawing from the last surviving point.
  Preserve unaffected edge values/cues and complete Undo snapshots. Incomplete
  anchors prevent readiness. These agent-origin recovery details were approved with D04; no new APIs are
  claimed as implemented.
- Keep state ownership/domain boundaries and Flight isolation. Nondestructive
  pencil leave/resume restores geometry and entries; Map tools exposes accessible
  typed equivalents without requiring precision or removed mode controls.
  **Approved accessible presentation:** retain waypoint/map-center inputs and a
  native Departure / Point N / Rejoin action list with Move / Delete; accessible
  Move selects the next eligible-location tap under the same domain constraints.
  No operational-route/event mutation or regular Cockpit redesign is introduced.

Approved scoped issue-text updates were published to #227/#228/#231/#233. Relevant domain/UI tests, build and simulator checks belong to a
later authorized implementation; none ran for this documentation/design revision.

### AP-03 implementation checkpoint · D04 · 2026-11-24

`RouteAmendmentDraft` owns typed overlap resolution and validates original-route
occurrences on selection. Map input carries both hit-tested proposed legs and
original anchors; the feature forwards the same intent without a plotting-mode
gate. After rejoin, proposed hits edit while other short taps preserve geometry.
The console renders Drawing/Rejoined status; rows reuse the existing value editor
and map panel. At compact accessibility sizes, new Edit / Rejoin and proposed-leg
choice use a persistent native confirmation dialog followed, when needed, by a
scrollable native sheet/list so the protected operational header cannot
leave their actions in a sub-44pt chart viewport. This is an adaptive native
presentation under the approved reachability rule, not revised approved geometry.
Presentation dismissal changes visibility; typed Edit/Rejoin/Cancel intents own
the draft transition, preventing native dismissal from cancelling a successor.
Existing AP-01/AP-02 shell, stable geometry identities, atomic plot
history and Flight isolation remain. Disposable DEBUG fixtures exercise completed
first-leg progress and coincident-route input through the existing preparation helper.
No AP-07 gesture/anchor-correction, AP-04 wheel/partial-save or AP-11 arming behavior
is claimed. [Verification ledger](../reconciliations/2026-11-23-route-amendment-preparation/evidence/ap-03-implementation.md)
contains scoped acceptance and remaining human approval.

## Preparation revision planning · 2026-11-24

The [approved future preparation revision](../features/IN-FLIGHT-ROUTE-AMENDMENT_SPEC.md#approved-future-preparation-revision--2026-11-24)
supersedes conflicting preparation behavior only. Its [approved published task contracts](../reconciliations/2026-11-23-route-amendment-preparation/proposed/tasks/README.md)
and [approved shared preparation interfaces](../reconciliations/2026-11-23-route-amendment-preparation/proposed/tasks/contract.md)
were approved by John on 2026-11-24 and published under #224. They apply to
preparation only; the remaining operational decisions below are retained. Reuse existing operational transactions and preserve
flying/rejoin/recovery evidence contracts. Each implementing task updates only
its delivered technical section after the approved planning baseline lands.

## AP-01 workspace ownership · 2026-11-24

`CockpitFeatureState` owns `isAmendmentWorkspaceVisible` and
`isAmendmentPlotting`, separately from its Flight-keyed `routeAmendmentDraft`.
The toggle commands only change presentation/draft state. The existing draft pause
flag is a compatibility adapter for the retained route/value commands. Empty exit
clears the draft; edited exit keeps selection and the current unfinished editor.
Opening/resuming always resets plotting. Failed-save presentation can be reopened
without resubmitting a navigation command.

`AmendmentLifecycleStatus` projects None/Incomplete/Ready/Armed/Awaiting Start leg/
Flying from existing facts. A first replacement leg timing record is required for
Flying; merely activating the route into a Manual Ready leg does not turn it green.
Workspace highlight and failed-save indication remain independent of lifecycle.

`CockpitView` reuses `CockpitRestingLayoutPolicy` and the same compact direct-Reach
adjustment in both modes; amendment-specific console extents are removed. The map
keeps its identity and camera bindings. Automatic replacement-review focus respects
manual camera ownership even when visibility or editor presentation restores the
focus projection from nil; those transitions are not explicit camera commands.
Keyboard avoidance is scoped to the editor
instead of resizing the underlying viewport. `RouteAmendmentConsole` fixes the light
timing strip, title/plot control and actions around an internally scrolling region.
The map overlay gates placement using the independent plotting flag. Existing
route/value operations remain behind that shell until their dedicated AP tasks.

Arm is disabled by explicit owner direction until AP-11; no callback or recording
operation is wired to it. Existing engine/storage transactions are unchanged. The
DEBUG workspace fixture seeds a hidden three-leg draft and injects a display date
(07:22) without changing operational timestamps. The fixture uses disposable Flight
data; it is not a second navigation clock.

## AP-02 partial projection and input routing · 2026-11-24

`RouteAmendmentDraft.reviewLegs` zips the departure, plotted points and optional
rejoin; projection no longer requires a completed route. Directed leg identity
uses anchor occurrence or plotted UUID only. `LegGeometry` separately keys saved
complete values by identity and endpoint coordinates, preserving the existing
geometry-invalidates-values behavior and geometry Undo without identity churn.
Full value/selection/cue Undo remains AP-07.

`CockpitFeatureState` owns plotting intent: on placement it strips leg-hit choices;
off placement accepts only explicit leg hits. Row/editor commands are unavailable
while plotting. `stopPlotting` cancels transient anchor/placement choices into
an editable partial workspace without asserting a rejoin or Flight transition.
The legacy review step remains a compatibility state; `PendingRouteAmendment`
still independently validates rejoin, ordering, geometry and complete values.

`RouteAmendmentConsole` always renders `RouteAmendmentReview`, within the AP-01
fixed shell. New formed legs scroll into view without animation; selected editors
reuse the same IDs. During plotting rows remain readable but disabled. Map tools
provides the retained waypoint/map-center picker only while plotting; regular
Cockpit tools are unchanged. Native editor and complete-value saving remain until
AP-04/05. DEBUG `A-partial` extends fixture A with departure+Point 1, no rejoin or
values, and the existing display-only 07:22 clock. It produces no operational
route mutation. See the [AP-02 ledger](../reconciliations/2026-11-23-route-amendment-preparation/evidence/ap-02-implementation.md).

## Code at the planning baseline

| Area | Inspected interface and constraint |
| --- | --- |
| Flight and import | [FlightPlan](../../NavigationFlight/Domain/Flight/FlightPlan.swift) stores the ordered, resolved imported route. [Flight](../../NavigationFlight/Domain/Flight/Flight.swift) retains immutable source leg IDs and times the active index. Ordinary waypoint reach marks arrival, closes outstanding targets, and applies progression. That transition cannot represent leaving partway without asserting an arrival. |
| Cockpit and map | [CockpitFeatureView](../../NavigationFlight/Features/Cockpit/CockpitFeatureView.swift) gets the ordered identification-point keys from the map before committing reach. [CockpitFeatureState](../../NavigationFlight/Features/Cockpit/CockpitFeatureState.swift) and [CockpitPresentationAdapter](../../NavigationFlight/Features/Cockpit/CockpitPresentationAdapter.swift) assume the Flight index maps to the imported plan. [AviationMapPresentation](../../NavigationFlight/Map/AviationMapPresentation.swift) and [CockpitOperationalCueProjector](../../NavigationFlight/Features/Cockpit/CockpitOperationalCueProjector.swift) independently resolve original geometry, targets, and cues. |
| Settings and navigation mode | [AppPreferences](../../NavigationFlight/Domain/Settings/AppPreferences.swift) carries the local setting defaults. The domain supports no-wind and planned-wind execution, but current Cockpit accept, ready selection and restore paths use no-wind. [Flying a Leg](../features/FLYING-A-LEG_SPEC.md) describes a preflight mode choice. Its approved behavior is broader than this checkout's executable path. |
| Recording and recovery | The [main-actor coordinator](../../NavigationFlight/Features/Recording/FlightRecordingCoordinator.swift) and [recording actor](../../NavigationFlight/Domain/Recording/FlightRecordingEngine.swift) guard mutations and publish after storage succeeds. The current multi-event commit writes each record separately. The [disk store](../../NavigationFlight/Data/Recording/DiskFlightRecordingStore.swift) checks next sequence and appends NDJSON. [Recovery](../../NavigationFlight/Features/Recording/FlightRecoveryCoordinator.swift) replays against imported leg IDs, creates a no-wind Flight, and validates contexts against the resulting leg ID list. |
| History | [Flight Debrief](../../NavigationFlight/Features/Flights/FlightDebrief.swift) consumes the captured plan, recorded events, and track segments. Event-to-track correlation has distinct evidence semantics. |

## Decision 1 · One operational route owned by Flight

**Approved.** Keep the imported Flight Plan immutable. Let Flight own a single committed route revision and its pending amendment. Make that route available through a read module that delegates to the original resolved plan for an untouched Flight. Cockpit, the map, cues, and recording share its ordered legs and target facts. Recording replay applies the same domain transitions to the same captured imported plan.

| Alternative | Tradeoff |
| --- | --- |
| Route state in Flight with one read module | Requires migrating index-dependent callers once. Keeps route order, target eligibility, and source provenance local to the same module. |
| Amend the Flight Plan copy in memory | Reuses some index-based adapters at first. Split and new legs would have to satisfy imported-plan invariants, and recovery and history would need a second identity scheme to distinguish that copy from the original plan. |
| Store overlays and project a route independently in each caller | Adds little to Flight initially. The map, progression, and replay each have to interpret the same amendment and can disagree on which destination or cue is next. |

Proposed domain interface. Existing Flight commands can delegate into this seam during migration.

```swift
// Illustrative interface, approved design.
Flight.operationalRoute(in: FlightPlan) -> OperationalRouteView
Flight.reviewAmendment(_ draft: AmendmentDraft, in: FlightPlan) -> AmendmentReview
Flight.applying(_ action: RouteAction, in: FlightPlan, at: FlightActionTime)
    throws -> RouteTransition
```

- The read value resolves the active or ready leg, successor, identified and reportable targets, valid route anchors, pending departure, and the bypassed intervals. It exposes planned data and stable IDs. Presentation adapters own formatting, display roles, and view geometry.
- An operational leg has a stable ID and an immutable source interval, which is either an imported leg or a previously confirmed amendment leg. Original unsplit legs preserve their UUIDs for existing history. Each replacement leg and each resumed remainder with a fresh timer has its own ID. An already-timed leg keeps its identity and start at a partway exit, while its history records the actual departure boundary.
- Anchor order uses route occurrence and along-leg position. Equivalent endpoint/startpoint occurrences on the same boundary are canonicalized. Intersections, reused waypoints, and equal coordinates on different occurrences stay distinct. Map proximity proposes candidates. Route order validates the selection.
- Scope timings, pilot revisions, checklist context, and target identity by operational leg ID. Keep source IDs for provenance and immutable imported references. Historical and undone leg IDs remain resolvable in the journal at the revision where they existed.
- A review returns an ordered replacement and field-specific issues. Confirmation revalidates the current Flight, the anchor order and known progress, geometry, and leg values. A missing, inactive, or stale occurrence fails with a typed error and preserves the rest of the draft. Revision checks account for progression even if geometry itself has stayed the same.

### Progression and timing

1. **Pending departure.** Accepting a scheduled partway departure projects the retained prefix as the operational leg when it is current. Reuse the existing leg ID, original timing origin, and current operational heading. Bind normal Identify and Reach, current target callouts and planned ETA to the new destination occurrence at the departure anchor. Compute its planned elapsed ETA from the original start and selected-mode leg timing. Exclude the original destination and downstream targets from normal Cockpit actions and due cues. Store destination identification by leg and destination occurrence so earlier identification of the original arrival remains historical and never identifies the new boundary. At a waypoint departure, the existing arrival waypoint and actions continue. Reporting it records waypoint arrival and activation together. Reporting a partway destination ends the timed leg at the anchor without recording original destination arrival. Use pilot-reported progress only. Cancel restores the original leg extent and target state without restarting the timer.
2. **Start Now and handoff.** Resolve one departure occurrence as the preceding operational leg’s endpoint and the first replacement leg’s start. Resolve one rejoin occurrence as the last replacement leg’s endpoint and, where a retained leg follows, the start of that leg. Canonicalize the shared boundaries by route occurrence, including a split within an imported leg. Start Now is the pilot's immediate departure assertion and starts the first amendment leg at the selected anchor. Scheduled departures use the captured progression policy. An automatic successor starts at the report timestamp. A manual successor is ready and untimed until Start Leg. Apply the same distinction at rejoin and capture the checklist at the actual start. If rejoin coincides with the final waypoint, preserve the existing final reach and explicit Navigation Complete sequence.
3. **Retained portions.** Compute remaining duration from the saved selected-mode duration and source interval. Rebase retained annotation times from the same origin and round once. Use the source attachment and ordered position to determine membership, including annotations displaced laterally on the chart. Bypassed targets gain no reached or passed-without-report outcome. Restore original planned cue values effective at the rejoin, then expose only its retained upcoming cues. Optional amendment cues use the last displayed value as a reference when omitted. Prior revisions remain available in history and the new timed segment starts with its own planned values.
4. **Later changes.** Replace or cancel a pending amendment explicitly. A subsequent amendment selects from the remaining operational route, including prior amendment legs. Re-slice from each confirmed source interval and preserve earlier events. If a later splice bypasses a previous amendment's unreported rejoin, drop that boundary from operational progression and preserve the prior amendment facts.
5. **Undo.** Reuse the 20-second reach window and its next-action invalidation. Associate it with the last effective operation and a snapshot of route, timing, checklists, and map restoration. Scheduled departure Undo restores the pending amendment. Start Now Undo restores the old Flight and the draft in review. Rejoin Undo restores the prior timing and route. Replay applies the linked Undo event without reissuing a transient Undo offer.

### Shared operational Cockpit

The [approved Cockpit revision](https://www.figma.com/design/o6gfoVEgyzJ0UA51d9Vi9M?node-id=2-2) governs the replacement leg in Ready, Active and Destination Identified. Reach on the final replacement leg resolves through RA-T05. Keep draft review, pending management and replay presentation at their existing boundaries.

- Feed the existing Cockpit shell and its Ready and Active presentation from the operational-route read value. Reuse the route strip and next-leg disclosure, the heading and ETA editors, timer, altitude and frequency projection, Frequency Plan, existing checklist and Position Check, and normal destination controls. Resolve target identities, eligible actions and successor from the operational read value. Imported plan indices alone cannot resolve replacement and retained legs.
- Bind heading and ETA revisions, cue provenance, and the actual checklist start to the operational leg ID. Render Manual Ready untimed. A scheduled Automatic start uses the reach timestamp, and Start Now uses the assertion timestamp. Recovery provides the same shared state and saved values.
- Keep the bypassed interval as a grey dashed map-only role. Exclude it from target hit testing, due cues, Next ETA and progression. Manual replacement legs omit minute marks and drift lines. Assisted legs use their confirmed duration and the existing drift toggle. Timed amendment identification points stay deferred.
- Reuse the regular portrait layout in [Ready](https://www.figma.com/design/o6gfoVEgyzJ0UA51d9Vi9M?node-id=2-3) · [Active](https://www.figma.com/design/o6gfoVEgyzJ0UA51d9Vi9M?node-id=2-6) · [Destination Identified](https://www.figma.com/design/o6gfoVEgyzJ0UA51d9Vi9M?node-id=2-9), adapting through the [regular iPad landscape](https://www.figma.com/design/BjpTMuX6RmEE7Ifs59Al7M?node-id=26-2) and [regular iPhone portrait](https://www.figma.com/design/BjpTMuX6RmEE7Ifs59Al7M?node-id=26-176). Keep standard action ordering, Dynamic Type, VoiceOver labels and target sizes. At rejoin, bind the active control to the shared boundary and reuse the regular shell for the retained Ready or Active leg with rebased time, targets and original cue values. The historic rejoin frame supplies geometry and cue examples.

## Draft, map, and estimates

- Store the draft in the existing `CockpitFeatureState` owner, scoped by Flight ID and outside recording. Preserve sketch points, local undo, selected step, working values, and the Manual or Assisted mode captured at entry. Pause hides plotting and restores operational map and console input. Resume reopens the same step and revalidates the anchors against current progression. Leaving Cockpit preserves the draft for the same running Flight. Load, restart, or process loss clears it. Amend Route remains available in an underway Flight between manually progressed legs.
- Add the preference through [PreferenceChange](../../NavigationFlight/Domain/Settings/PreferenceChange.swift), the [Settings controller](../../NavigationFlight/Features/Settings/SettingsController.swift), and [disk preferences](../../NavigationFlight/Data/Settings/DiskSettingsStore.swift). A missing key defaults to Manual. A failed settings save leaves the last saved preference in use. The preference is separate from Flight execution mode.
- Use one tap-intent dispatcher in [OfflineAviationMapView](../../NavigationFlight/Map/OfflineAviationMapView.swift). While editing, route and waypoint hit testing uses screen-space proximity, and free taps use the map conversion to WGS84. Select the intended occurrence for crossings. Gestures for panning, zoom, and rotation remain MapLibre-owned. Coordinate choice, move, and accessible map-center placement all feed the same typed edit intent. Pausing restores normal target taps without simultaneously plotting or reporting a reach. SwiftUI keeps field focus, numeric input, and orientation layout local to presentation.
- Introduce a pure estimate module for new legs. Match the Navigation Editor's stored route conventions for projected track course, geodesic distance, east-positive magnetic variation, and planned-wind solution. Use the imported plan-wide speed and default wind. Reject unusable inputs or impossible solutions, represent each display result as available or unavailable, and keep positive whole-second durations and typed direction provenance. No-wind estimates are magnetic course. Planned-wind estimates are magnetic heading. Use shared conventions and verified fixtures from the owner-controlled editor, with an offline Swift implementation. [Editor geometry](https://github.com/johnbenz13/ppl-navigation-editor/blob/7abb0d1c5551af401ef5d403252bc864e3679040/src/features/navigation/navigation-calculations.ts) · [Editor wind model](https://github.com/johnbenz13/ppl-navigation-editor/blob/7abb0d1c5551af401ef5d403252bc864e3679040/src/features/navigation/wind-calculations.ts)
- Manual Check computes the explicit reference without changing the working entry. Assisted prefill is editable. Confirmation stores the working values and their provenance. Reopening or replaying a confirmed route uses those saved values. Assisted minute marks follow the working or committed duration. Its drift lines respect the existing visibility toggle. Manual amendment legs omit both. A deliberately requested existing Position Check remains separate and resolves the current operational geometry. The amendment path never requests location or uses a Position Check result to activate, place, or estimate a leg.

The existing pencil position projects the pending state with a clock badge. Give the button the accessible name **Manage pending amendment** and a 44-point target. Open a transient presentation aligned to the pencil in regular width, adapting to the existing compact sheet pattern. Follow the Cockpit’s disclosure behavior and dismiss without changing Flight state. Expose the explicit original-destination report only when the active pending departure has shortened the current leg. [iPad pencil popover](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=26-266) · [iPhone management sheet](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=26-461)

## Decision 2 · Commit each route action as a single journal transaction

**Approved.** Extend the existing recording store interface with an idempotent route transaction. Keep logical confirmation, departure, automatic progression, rejoin, replacement, cancellation, and Undo events individually identifiable. Commit their effects, normalized route geometry and inputs, and required checklist context together with an operation ID and expected sequence.

The rejoin transaction starts with the pilot's distinct rejoin event identifying the saved amendment, last replacement leg, shared occurrence and optional retained successor. Its companions record ordinary arrival and, where applicable, automatic successor start or final arrival. All facts share the saved checklist context. Replay checks the companion sequence and reconstructs the source interval and timings from the saved confirmation and imported execution snapshot.

| Alternative | Tradeoff |
| --- | --- |
| Atomic replacement of the event journal with a complete transaction | Proposed concrete disk adapter. Existing recordings and track data retain their layout. Copies the small events journal on a route transaction. It gives recovery either the old or complete new sequence. |
| Single framed append record containing all logical events | Avoids the journal copy. Requires a new self-validating append frame, durable sequence proof, and explicit handling of an incomplete tail without losing previously committed evidence. |
| Multiple ordinary appends or a sidecar route snapshot | Reuses more of the existing writer. Separate writes leave a crash window where route data, timing, and checklists describe different Flights. |

- The existing recording actor owns command serialization. At command admission it captures current Flight and route, explicit wall time and monotonic time, durable sequence, and a stable operation/event ID set. It prepares a candidate with the domain transition. After the durable transaction, it publishes the Flight, pending state, and cockpit context together. Map pan and other presentation actions can continue. Route changes and reach reports must resolve through the same ordering. The same-recording writer fence also covers context saves, checkpoint expiry, and closure, including the coordinator path that currently writes directly to the store. A cancelled view task cannot discard a transaction with a possible durable outcome.
- Reuse the store's disk and in-memory adapters. Stage the next complete event journal in the same package directory, synchronize it, atomically replace the prior journal, and confirm the durability outcome before publishing. Capture affected event IDs, timestamps, and route IDs once per command. If a write reports error after a possible commit, resolve the operation ID against durable data. An exact durable match publishes once. A confirmed absent action can retry with the same IDs. An unresolved result blocks incompatible writes to that recording until reconciled and keeps the last published route visible.
- Version new persisted semantics. Recommend recording schema 4 for the first amendment transaction, with schema 1–3 events still readable in continued packages. Read schema support before attempting to decode new event kinds. An older installed reader can classify a newer package as unsupported or unreadable, depending on its existing validation order. Upgrade ordering must tolerate a crash before any new event has committed. Unknown or malformed amendment data must follow the existing unavailable recovery path without silently reconstructing the imported route as active. For structurally readable packages whose amended route cannot be replayed, reuse End Flight as Incomplete and preserve readable evidence. Structurally corrupt packages follow existing evidence-preservation policy without claiming a successful close.
- Persist route facts sufficient to replay the exact confirmed geometry and values without consulting Figma, current settings, or the estimator. Include execution mode where needed for rebased original times and cues. Validate event identities and checklist and target IDs against route history at each sequence, rather than only against final visible legs. Unamended legacy packages retain their current recovery behavior. Track samples and GPX export keep their existing meaning. Debrief and the diagnostic export use the same durable route events to distinguish the original, bypassed, amended, and recorded aircraft tracks.

## Implementation verification contract

Use synthetic fixtures and injected clocks. Retain the existing Swift Testing domain/store tests and XCUITest coverage of platform input. Run the approved implementation entry points in the NavigationFlight Xcode scheme during ticket work. No test command is authorized by this planning step.

| ID | Observable checks and test seam | Requirements |
| --- | --- | --- |
| T01 | Shared draft interface with an in-memory Flight. Place, move, remove, undo a plot, pause and reopen drawing or review, and navigate away and back. Confirm that draft identity and inputs survive without committing, and that process recovery and a different Flight do not inherit the draft. Check map tap routing and accessibility actions against the same commands. | RA-01, RA-02, RA-13, RA-19 |
| T02 | Pure route review with same-leg shortcut, endpoint canonicalization, crossing, repeat waypoint, a reversed pair, coincident consecutive points, and a further amendment on previously amended legs. Verify the exact bypass interval and no change on invalid selection. Exercise revalidation after intervening progression. | RA-02, RA-04, RA-12, RA-13, RA-20 |
| T03 | Parameterized estimate fixtures from the Navigation Editor baseline for no wind, calm wind, directional wind, invalid or absent default wind, and no positive ground speed. Assert direction kind, duration and provenance. Verify initial Manual, capture and save failure, Manual Check isolation, Assisted editable fallback, and both modes' confirmation gating. Assert map minute marks and drift behavior by mode, duration and visibility. | RA-03, RA-06, RA-09, RA-10, RA-14 |
| T04 | Flight domain progression with scheduled, immediate, waypoint and partway departures. Verify the timer origin, end reason, next effective ID, automatic versus ready successor, and exact checklist start. Confirm Identify and Reach target the active shortened destination, including an earlier identification of the original arrival. Compare its planned elapsed ETA, timer continuity, original target restoration on cancel, both progression policies and no synthetic original arrival. Verify shared departure occurrence and the ordinary controls on a replacement leg. | RA-04, RA-05, RA-08, RA-21, RA-24 |
| T05 | Fixture with a retained interval and annotations before, at, and after rejoin. Check planned duration, ordered target time origins, optional altitude/frequency reference, correct planned cues at rejoin, and new revisions scoped to the new leg. Confirm bypassed targets stay inactive without fabricated outcomes. Verify the last normal Reach targets the retained leg’s shared start. | RA-11, RA-15, RA-16, RA-21, RA-24 |
| T06 | Coordinator, engine, and store tests with suspension gates and explicit clocks. Inject failure before replacement, after durable commit before acknowledgement, and in acknowledgement reconciliation. Check prior Cockpit continuity, same-ID retry, duplicate suppression, and that concurrent reach, contextual writes, or checkpoint activity cannot publish conflicting route revisions. | RA-05, RA-12, RA-22 |
| T07 | Disk reopen through Flight recovery. Replay pending, activated, replaced, cancelled, and undone states. Verify original and active route identities, history, selected mode, saved values, and checklist context. Exercise schema-1–3 compatibility, interrupted upgrade, malformed geometry, an unreadable package, and a readable but unreplayable amendment. | RA-12, RA-13, RA-17, RA-18, RA-22 |
| T08 | Exercise Undo just before and at expiry and after a later action. Assert the appropriate pending or draft state, continuous prior timer, historical original and Undo events, and map-focus restoration. Assert no stale token after process restart. | RA-17, RA-18 |
| T09 | Debrief and export projections for the original route, effective amendment route, bypassed spans, and amendment events with or without track evidence. Verify stable event selection, linked Undo, and unchanged GPX evidence behavior. | RA-18 |
| T10 | Existing untouched Flight regressions for automatic and manual progression, cues, checklist capture, existing Position Check, and legacy restore. Map and UI evidence at the approved Figma nodes for iPad portrait and landscape, iPhone portrait and Larger Text, numeric input, sufficient touch areas, VoiceOver order, Reduce Motion and resizing. Confirm timed amendment identification points, flight ruler, and iPhone landscape are excluded. Compare an ordinary leg and replacement leg in the same Ready, Active and Destination Identified states. Exercise the same instruments, editors, cue/checklist and destination flows; verify the inactive bypass and mode-specific aids separately. | RA-01–RA-24 |
| T11 | Pending departure fixture with an explicit original-destination report from Manage Amendment. Verify the normal map and Identify/Reach never offer the bypassed original target, and passive elapsed time and map activity never prompt a missed-departure dialog. Keeping pending leaves both pending and reach state unchanged. Cancelling and recording the reach commits both effects once and applies normal progression. Exercise stale intent, storage failure, retry, recovery, and reporting the actual departure. Verify the pending pencil and menu on iPad, the iPhone compact sheet, and the original-destination dialog against the approved Figma state. | RA-12, RA-22–RA-23 |

## Owner decisions

- John approved the Flight-owned operational route and a single durable transaction for each route-changing action.
- Defer the pilot-facing planned-wind selector. Implement and verify both estimate paths against the captured Flight mode. User-facing acceptance for this release uses the current no-wind Cockpit path, and planned-wind validation uses domain fixtures.
- The pilot explicitly chooses Report original destination reached from Manage Amendment when the shortened leg is current. Compare the selected original destination and departure by route order, and ask whether to keep pending or cancel and record the declared reach. There is no GPS input or time-based missed-departure inference. The first option saves neither action. The second records both facts atomically and applies existing progression. Reaching the actual departure uses the normal amendment handoff. Limit Start Now to a valid point on the current leg or its ready departure boundary, with scheduled confirmation available for later legs. [Shortened active leg](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=14-1236) · [Departure point identified](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=23-296) · [Explicit original-destination report](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=23-384)

The [approved implementation ticket plan](../features/IN-FLIGHT-ROUTE-AMENDMENT_DELIVERY-PLAN.md) records the approved breakdown and GitHub publication.
