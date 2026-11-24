# In-flight route amendment

Product approved by John · 2026-11-22. Shared operational Cockpit revision approved by John · 2026-11-23.

Planning baseline: NavigationFlight `258a42cd060195a24086908fecee9bb44312ff30` (local `origin/main` at checkout creation).

## Approved future preparation revision · 2026-11-24

John approved the [preparation behavior](../reconciliations/2026-11-23-route-amendment-preparation/proposed/preparing-an-amendment.md)
and [D03 plus retained D02 states](../reconciliations/2026-11-23-route-amendment-preparation/proposed/design-revision-d03.md),
reviewing checkpoint [46967c5](https://github.com/johnbenz13/NavigationFlight/commit/46967c5d8bb3f15e27e00835572d7300c491364e).
This is approved future behavior, not a claim of delivery. The earlier contract
and completed acceptance remain historical evidence. The scoped preparation
revision takes precedence where it conflicts with the rows below:

| Earlier scope | Approved preparation replacement |
| --- | --- |
| RA-01/RA-19 entry and pause/play | G01/G02: pencil toggles a single workspace; plotting is explicit and off on return. No separate pause/play or staged Finish here/review gate. |
| RA-03/RA-10/RA-11 field presentation | G03: separate heading and leg-time wheel sections, partial independent values and bounded cue wheels; Check never overwrites entries. |
| RA-05 preparation confirmation | G04: readiness is derived; explicit Arm commits via existing scheduled confirmation. Start now is removed from preparation and armed inspection. Existing flying execution contracts remain outside this revision. |
| RA-12 pending indicator/edit entry | G01/G04/G07: status badges, read-only Armed/Flying inspection and explicit disarm before pending edits. Creating another amendment while already flying is deferred from this slice. |
| RA-13 unconfirmed recovery | G05: persist unfinished per-Flight work, recover unarmed into regular Cockpit, preserve partial entries and warn on stale departure. |
| Preparation layout | G06/D03: stable shared Cockpit extent, fixed timing/actions and scrolling leg list. Contextual node 29:989 approves only pencil/status text; all other regular Cockpit UI remains its existing approved design. |

Other flying, rejoin, Flight Undo, recording/history and Debrief requirements
remain unchanged. See the [approved published task breakdown](../reconciliations/2026-11-23-route-amendment-preparation/proposed/tasks/README.md)
for approved implementation boundaries. Publication is complete under #224;
implementation still needs a separate request.

## AP-01 implementation scope · 2026-11-24

The #225 implementation introduces the pencil toggle, separate transient plotting
flag, in-memory draft/editor retention, light current-leg timing strip and fixed
workspace actions under the shared Cockpit layout. Untouched exit removes the empty
draft; edited exit preserves work and reentry turns plotting off. Lifecycle badges
are derived independently from existing draft, pending and activated Flight facts.
The first replacement leg remains grey while awaiting Manual Start leg.

Owner clarification during implementation: **Arm is a disabled placeholder with no
operational effect until AP-11**. The preparation workspace exposes neither Start now
nor separate pause/resume controls. Existing domain confirmation, progression,
recording and recovery operations retain their contracts. The staged route commands
and existing field editor remain until AP-02 and AP-04/05 respectively; disk draft
recovery remains AP-09 and Armed management remains AP-12. Activated amendment
status is projected here; accepted-amendment inspection commands remain AP-12.

Only this scope supersedes the earlier delivered preparation UI. Runtime visual
acceptance remains separate; see [AP-01 evidence](../reconciliations/2026-11-23-route-amendment-preparation/evidence/ap-01-implementation.md).

## AP-02 implementation scope · 2026-11-24

Issue #226 projects every formed adjacent segment before a rejoin, with stable
plotted-point/route-occurrence identities. Plot points and Done plotting control
placement independently from leg selection. The vertical list remains visible
while plotting; stopping permits the existing leg editor before rejoin. Plotting
map taps cannot open the value editor, and plotting-off taps cannot add points.
The removed horizontal chips and Finish here/Review legs workspace gates are
superseded by the continuous list. Existing accessible waypoint, map-center and
explicit return/occurrence inputs are retained under Map tools while plotting.

Owner scope clarification: heading and leg time have separate Not set displays,
but saving still requires complete valid values until AP-04. Automatic rejoin
completion remains AP-03; point correction, wheels, Assisted defaults, persistence
and arming remain their dedicated tasks. Final-route validation still requires a
valid later rejoin and preserves the original destination. Preparation does not
change Flight timing, route or recording events. Runtime evidence and pending
human acceptance are tracked in the [AP-02 ledger](../reconciliations/2026-11-23-route-amendment-preparation/evidence/ap-02-implementation.md).

## Pilot outcome

From Cockpit, the pilot can quickly prepare and confirm a different route for the current Flight when weather, a controller instruction, or a shortcut changes the route they intend to fly. They can use existing waypoints and map points, including a departure partway along a leg.

## Existing behavior

- [Flying a Leg](FLYING-A-LEG_SPEC.md) includes heading and ETA revisions within an active leg. Those values are scoped to that leg and retain their existing behavior.
- [Progression policy](PROGRESSION-POLICY_SPEC.md) determines whether the successor starts automatically after a reach report or awaits an explicit start. The amendment changes which leg is the successor where applicable.
- [Cockpit operational cues](COCKPIT-OPERATIONAL-CUES_SPEC.md) define when planned altitude and frequency changes become due. RA-16 defines how those cues extend to amendment legs and rejoin.
- [Automatic recording and recovery](AUTOMATIC-FLIGHT-RECORDING-AND-RECOVERY_SPEC.md) and [Flight evidence export and debrief](FLIGHT-EVIDENCE-EXPORT-AND-DEBRIEF_SPEC.md) are affected by any change to the flown route and its history.
- The [architecture](../architecture.md) describes RouteAmendment as a placeholder. The [glossary](../../GLOSSARY.md) establishes manual-navigation primacy and uses Reference result for an explicit cross-check.

## Agreed scope and behavior

Product decisions from John across rounds 1 through 4 on 2026-11-22 and the Cockpit reconciliation on 2026-11-23.

| ID | Observable behavior |
| --- | --- |
| RA-01 | A one-tap pencil icon with the accessible name Amend Route opens map drawing mode from Cockpit while a Flight is underway, including between legs. Its exact placement is reviewed in Figma with the existing Cockpit layout. |
| RA-02 | The pilot selects a departure on the active or remaining route and a rejoin point farther along that route. Either point can be an existing waypoint or partway along a leg, including two points on the same leg. The pilot taps intermediate map points or existing waypoints in order and the app connects consecutive points with straight legs. Anchors and transitions use the pilot's map selection and actions. The amendment does not use GPS to place anchors, determine arrival, or advance navigation. The original destination remains the destination. |
| RA-03 | In Manual mode, the pilot enters a heading and flight time per new leg. Check reveals the app's estimates for comparison without changing the pilot's entries. In Assisted mode, the app pre-fills editable heading and flight time per new leg. Review shows the working values in either mode. The pilot selects the mode in Settings. |
| RA-04 | The app calculates the continuous original-route interval between the departure and rejoin points and shows it in grey dashes in operational Cockpit. The pilot can correct its extent by editing the anchors or selecting the intended leg when ambiguous. There is no eraser in the first release. |
| RA-05 | The draft does not affect the flight. Confirmation accepts the amendment. For an immediate departure the pilot explicitly chooses to start now. Confirming a future departure partway along a leg makes that point the destination of the shortened leg when it is current. The amended legs wait until the pilot reports reaching that destination and follow the Flight’s progression policy. The bypassed portions are inactive for normal Cockpit navigation. The imported Flight Plan and recorded flight history are preserved. |
| RA-06 | New amendment legs show minute marks and can show drift lines in Assisted mode. Manual amendment legs show neither aid, including after Check. Existing original-leg behavior continues. |
| RA-07 | Timed identification points on amendment legs and the flight ruler are deferred to follow-up releases. |
| RA-08 | The preceding operational leg ends at the departure point of the first replacement leg. The final replacement leg arrives where the first retained leg departs. Partway anchors are pilot-reported navigation boundaries. Before a scheduled mid-leg departure, the normal destination Identify and Reach actions apply to the departure point. The original destination is excluded from normal Identify and Reach while the amendment is pending. A departure at an existing arrival waypoint keeps that waypoint and the normal actions. A scheduled departure and rejoin apply the captured progression policy after a reach report. Start Now asserts departure at the selected anchor and starts timing immediately. A partway departure preserves elapsed time on the leg being left and records departure at the anchor without recording arrival at the original destination. |
| RA-09 | Manual is the initial Settings default for new and existing installs. The app captures the selected mode when the pilot starts a draft. It stays with the draft and the confirmed amendment. Assisted uses the existing Cockpit drift visibility control. |
| RA-10 | Confirmation requires a heading and flight time for every new leg. If the app cannot estimate either, it identifies the missing value and accepts pilot entry in either mode. |
| RA-11 | Each amendment leg supports optional altitude, frequency, and a visual-reference note. The note can describe departure, en-route and arrival references without creating navigation targets or timing events. |
| RA-12 | One amendment can await departure. While pending, the existing Cockpit pencil shows a clock badge. Tapping it opens amendment management without adding a console row. The pilot can replace or cancel the amendment before departure. Once underway, the pilot can create a further amendment from the remaining route, with flown portions preserved in Flight history. |
| RA-13 | An open draft survives leaving and returning to Cockpit while the Flight continues in the app. After app restart, confirmed amendments and pending departures are recovered with the Flight and unconfirmed drafts are discarded. If progression makes the draft departure unavailable, confirmation requires an updated departure. |
| RA-14 | Manual Check and Assisted estimates use the Flight's selected navigation mode, imported magnetic variation, and plan-wide planning airspeed. Planned-wind estimates use the plan-wide wind. New legs do not inherit per-leg wind or speed overrides. The no-wind result is labeled magnetic course and identifies the no-wind assumption. The planned-wind result is labeled magnetic heading. The app supports both estimate contracts. The planned-wind selector is deferred, and the current Cockpit workflow remains no-wind. Unavailable estimates follow RA-10. Assisted minute marks use the working duration in review and the confirmed duration during navigation. |
| RA-15 | At a partway departure, the old leg's timer remains continuous until departure. On a partway rejoin, the retained segment starts a new timer under the Flight's progression policy. Its planned duration is scaled by the remaining fraction of the original leg. Retained targets ahead use times relative to the new start. Bypassed targets do not receive reached or passed-without-report outcomes. |
| RA-16 | Entered altitude and frequency are advisory leg-start cues. An omitted value leaves the last planned value visible as a reference. At rejoin, show the original plan's values for that point and resume upcoming cues on the retained route. Bypassed changes do not replay. |
| RA-17 | The pilot can undo a departure or rejoin report, including Start Now, during the existing 20-second window until another flight-state action occurs. Undo restores the prior active route and continuous timer. Undoing scheduled departure leaves the amendment pending. Undoing Start Now returns the amendment to review. Pending future departures can also be cancelled before departure. |
| RA-18 | Preserve the imported route and record confirmation, cancellation or replacement, departure, rejoin, and undo as distinct events. Flight History and Debrief show the operational route and bypassed portions separately from the recorded aircraft track. Unconfirmed drawings produce no amendment events. |
| RA-19 | Drawing mode is visibly distinct. Taps add or select draft points, and pan, zoom, and rotation remain available. The pilot can edit or remove draft points, undo the last plotting action, or explicitly discard a nonempty draft. Plotting does not report a point reached. With a draft open, a separate pause icon beside the pencil restores the operational Cockpit and hides draft plotting and overlays. A play triangle then identifies the paused draft and reopens the same drawing or review step with its values. |
| RA-20 | Anchor validity follows operational route order. When lines overlap or cross, the pilot selects the intended leg. A new leg can cross the route without rejoining it. Confirmation requires an explicit rejoin strictly ahead of departure, distinct consecutive points, and a replaced section of the operational route. Invalid points are explained in context and the rest of the draft is preserved. |
| RA-21 | New legs and retained portions after a partway rejoin begin with their own confirmed or rebased original values. Prior heading and ETA revisions stay with the leg on which they were made. The configured checklist is captured when each leg starts, according to the current automatic or manual progression rules. |
| RA-22 | A confirmed route or boundary change is recoverable before the app reports success. A failed save leaves the last confirmed route operational. Cockpit preserves the draft or pending amendment as appropriate and offers retry without duplicating a route or timing event. Unrecoverable confirmed route state follows the existing incomplete-Flight flow. |
| RA-23 | While a shortened leg is current, the pilot can explicitly report the original destination reached from the pending pencil’s management menu if they continued along the original route. Ask them to keep the amendment pending or cancel it and record the declared original destination reach. The app uses that explicit report and route order, with no automatic missed-departure detection. Keeping pending records neither action. Cancelling and recording the reach is one durable action. A report for the actual departure uses normal amendment activation. |
| RA-24 | Fly a replacement leg in the regular Cockpit. Ready, Active and Destination Identified use the standard route strip, leg identity, instruments, cue and frequency presentation, checklist, Position Check, and Identify/Reach placement and sequence. Use the current leg’s confirmed heading, destination and elapsed-time baseline, with ordinary heading and ETA revision scoped to that leg. At a scheduled departure, Manual progression leaves the first replacement leg Ready and untimed until Start leg. Automatic progression starts timing at the reach report. Start Now starts timing immediately. The bypassed original interval is a chart reference in grey dashes and remains unavailable as a navigation target. RA-06 and RA-07 govern which aids and targets are available. |

The app-computed heading in RA-03 applies to amendment legs. The existing Flying a Leg heading revision and Position Check contracts continue in their own workflows.

## Product acceptance examples

These scenarios illustrate the agreed behavior. Their values are examples.

- **Scheduled Manual departure** (RA-02–06, RA-08, RA-14). The pilot plots a departure halfway along the active leg, one new waypoint, and a downstream rejoin. After Check, the manual entries remain in force and the new legs show neither minute marks nor drift lines. Confirming the future mid-leg departure shortens the active leg and replaces its destination with the departure point. The timer continues from the original start. Identify and Reach apply to the departure point. Reporting it reached preserves elapsed time without recording arrival at the bypassed waypoint.
- **Assisted shortcut and partway rejoin** (RA-05, RA-08, RA-10, RA-14–16, RA-21). An adjusted duration changes the draft's minute marks. When the pilot reports rejoining exactly halfway through a planned 12-minute leg, the retained portion has a six-minute planned duration and a fresh timing origin when started. Original targets beyond the rejoin use the new origin and bypassed cues do not replay.
- **Correcting an ambiguous route** (RA-04, RA-19–20). At a crossing, the pilot can select the intended existing leg. A crossing by a new leg creates no connection until the pilot sets a rejoin. An invalid departure or rejoin can be corrected while retaining the other points and inputs.
- **Interrupted confirmation and Undo** (RA-12–13, RA-17–18, RA-22). A failed save preserves the current route and allows a retry. After a successful save, normal Flight recovery restores the confirmed amendment. Undoing an immediate departure within the available window restores the prior timer and route and opens the draft in review. The committed action and its undo remain visible in history.

## Figma

Status: approved. John approved the product, detailed design, shortened-leg controls, explicit original-destination reporting, and revised pending-pencil management on 2026-11-22.

On 2026-11-23 John approved the [Cockpit revision](https://www.figma.com/design/o6gfoVEgyzJ0UA51d9Vi9M?node-id=2-2) for iPad Pro 11-inch portrait (834 × 1194) and the shared arrival/departure points. The new Ready, Active and Destination Identified frames supersede the dedicated amendment flight console in [14:484](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=14-484) and [14:579](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=14-579), and the console treatment in [14:664](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=14-664). Earlier frames retain their transition-notice, rejoin-geometry and cue references where those are relevant. Apply the [regular iPad landscape](https://www.figma.com/design/BjpTMuX6RmEE7Ifs59Al7M?node-id=26-2) and [regular iPhone portrait](https://www.figma.com/design/BjpTMuX6RmEE7Ifs59Al7M?node-id=26-176) to the same replacement-leg states. Drawing, pending management, and Debrief keep their approved surfaces.

- [Detailed design coverage index](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=17-254) in the [stable design file](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B). The pages group [Drawing and review](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=11-90), [Flight, recovery and history](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=11-91), and [Layouts and accessibility](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=11-92).
- The [approved direction index](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=6-137) refers to the [reconciliation Ready Cockpit](https://www.figma.com/design/BjpTMuX6RmEE7Ifs59Al7M?node-id=1-7) and [Active Cockpit companion](https://www.figma.com/design/BjpTMuX6RmEE7Ifs59Al7M?node-id=25-122). The same reference file provides the [landscape](https://www.figma.com/design/BjpTMuX6RmEE7Ifs59Al7M?node-id=26-2) and [iPhone](https://www.figma.com/design/BjpTMuX6RmEE7Ifs59Al7M?node-id=26-176) shells. All reference screenshots were inspected on 2026-11-22. The chart and route data are illustrative.

| Workflow | Requirements | Inspectable design |
| --- | --- | --- |
| Entry, pause, resume and preserve the current editing step | RA-01, RA-13, RA-19 | [Pencil only](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=10-92) · [Editing and pause](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=6-34) · [Operational Cockpit with paused draft](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=7-94) |
| Plot, edit, remove, undo the last plot and explicitly rejoin | RA-02, RA-04, RA-19, RA-20 | [Choose departure](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=12-90) · [Edit selected point](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=12-222) · [Choose rejoin](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=17-296) · [Disambiguate overlap](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=13-114) |
| Discard or correct an unavailable departure | RA-13, RA-19, RA-20 | [Discard confirmation](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=13-388) · [Departure validation](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=13-258) |
| Manual leg values, optional cues and comparison | RA-03, RA-06, RA-10, RA-11, RA-14 | [Review](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=6-34) · [Edit leg values and cues](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=13-485) · [Required values missing](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=15-610) · [Check result](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=13-659) · [Check unavailable](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=13-794) |
| Assisted values and map aids | RA-03, RA-06, RA-09, RA-10, RA-14 | [Mode preference](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=14-230) · [Assisted review](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=13-924) · [Drift lines off](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=16-405) · [Missing estimate](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=13-1068) |
| Scheduled departure and a pending amendment | RA-04, RA-05, RA-08, RA-12 | [Shortened active leg](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=14-1236) · [Departure point identified](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=23-296) · [Pending pencil](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=14-1274) · [iPad pencil popover](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=26-266) · [iPhone management sheet](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=26-461) · [Cancel confirmation](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=26-362) · [Review replacement](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=15-743) |
| Immediate departure, start policies and rejoin | RA-05, RA-08, RA-15–RA-17, RA-21, RA-24 | [Ready](https://www.figma.com/design/o6gfoVEgyzJ0UA51d9Vi9M?node-id=2-3) · [Active](https://www.figma.com/design/o6gfoVEgyzJ0UA51d9Vi9M?node-id=2-6) · [Destination Identified](https://www.figma.com/design/o6gfoVEgyzJ0UA51d9Vi9M?node-id=2-9). Use the regular handoff and the [retained interval and cue reference](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=14-664) at rejoin. The former amendment panels are historical. |
| Durable saves and recovery | RA-13, RA-22 | [Saving](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=14-883) · [Retry with draft preserved](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=14-751) · [Recovered pending amendment](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=14-1070) · [Unrecoverable amendment](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=14-1011) |
| History and route evidence | RA-12, RA-17, RA-18 | [Debrief routes and timeline](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=15-423) |
| Device, input and accessibility variants | RA-01–RA-06, RA-19, RA-24 | [iPad landscape](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=15-90) · [iPhone portrait](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=15-141) · [Numeric keyboard](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=15-198) · [Compact Larger Text](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=15-254) · [VoiceOver and responsive contract](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=15-301) |
| Explicit original destination report | RA-23 | [Manage · report original destination](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=26-266) · [Explicit original-destination report](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=23-384) |

### Existing patterns and scope

- Reuse the approved [Flight recovery entry](https://www.figma.com/design/ZrGA7ZuOACWtXA4mR7cwdc?node-id=38-275) before showing a recovered amendment. Existing end-as-incomplete confirmation applies. Successful recovery of an active amended leg uses the same operational state as an active amendment; it has no restored Undo action or draft.
- Retain the approved [leg-start checklist](https://www.figma.com/design/yvLXb8bUFBiZHqsag4hq6I?node-id=41-2), [original-leg ETA and heading interactions](https://www.figma.com/design/yvLXb8bUFBiZHqsag4hq6I?node-id=201-921), [Settings treatment](https://www.figma.com/design/HludOIJu7Ko46X4pmkGvTx?node-id=3-628), and [Debrief replay shell](https://www.figma.com/design/OSPuLyy5Qtde2iajUNeWDL?node-id=73-321). A no-GPS Debrief inherits the [action-only layout](https://www.figma.com/design/OSPuLyy5Qtde2iajUNeWDL?node-id=95-522). The amendment and bypassed route remain meaningful with or without a recorded aircraft track.
- A further amendment on the remaining route uses the same drawing and review states. Undo returns to the pending amendment, pre-departure Cockpit or draft review as specified by RA-17. Rejoin under Manual progression uses the same ready-to-start treatment before timing the retained portion.
- The last replacement leg uses the ordinary Reach action for its shared rejoin point when RA-T05 delivers the transition. Rejoin restores the retained route’s own timing, targets and cues in the regular shell. At the final route destination, use the existing Navigation Complete sequence.
- The flight ruler, timed identification points on amendment legs, and iPhone landscape remain outside this release.

The original detailed design contains 31 visually inspected frames and design notes in addition to the three approved direction frames. The revised shortened-leg controls, pending-pencil management, and explicit original-destination path were rendered and approved. The pending pencil opens a transient popover on iPad and a native sheet on iPhone. Dismissing either returns to the same operational Cockpit. The original-destination reporting action appears only while a shortened leg is current. It includes keyboard, Larger Text, VoiceOver order, reduced motion, and window sizing as design evidence. Runtime behavior and accessibility verification are pending implementation. The Figma coverage index links to the approved product spec.

## Delivery state

Product, main-screen direction, and detailed design are approved. The [technical design](../technical/IN-FLIGHT-ROUTE-AMENDMENT-TECHNICAL-DESIGN.md) is approved, including the planned-wind selector deferral and the cancellation-plus-reach transaction. The shortened-leg and explicit-report details reflect the latest clarification. The [approved delivery plan](IN-FLIGHT-ROUTE-AMENDMENT_DELIVERY-PLAN.md) records the GitHub publication.
