# Sources, authority and proposed supersessions

Inspected on 2026-11-23 against `cffba65f08cd8898294c941a4a3291b2fdb7df38`.
The nine issues were read in full, including labels/comments, before inspecting
implementation. Their retained JSON snapshots are in `issues/`. No issue changed.

## Ticket scope

| Issue | State at review | Relationship to this slice |
| --- | --- | --- |
| [#204 · Plot/edit/pause](https://github.com/johnbenz13/NavigationFlight/issues/204) | Closed | Existing drawing lifecycle is the main current baseline. Replace separate pause/resume and drawing/review steps through a new scoped proposal. |
| [#205 · Manual values/Check](https://github.com/johnbenz13/NavigationFlight/issues/205) | Closed | Replace text/step entry and complete-leg saving with wheels and independent partial values; retain Check semantics. |
| [#206 · Confirm/recover pending](https://github.com/johnbenz13/NavigationFlight/issues/206) | Closed | Arm retains scheduled confirmation's durable operational effects. Add durable unarmed drafts as a separate capability. |
| [#207 · Depart/fly](https://github.com/johnbenz13/NavigationFlight/issues/207) | Closed | Keep other flight execution; owner removed Start now from the proposed flow on 2026-11-24. Reconsider immediate departure in the later flying reconciliation. |
| [#208 · Rejoin](https://github.com/johnbenz13/NavigationFlight/issues/208) | Closed | Preserve existing behavior; later flying reconciliation. |
| [#209 · Pending management](https://github.com/johnbenz13/NavigationFlight/issues/209) | Closed | Reconcile pencil entry, Disarm and edit, and Disarm and discard with existing durable cancellation/replacement; preserve missed-departure behavior. |
| [#210 · Undo transitions](https://github.com/johnbenz13/NavigationFlight/issues/210) | Open | Outside preparation slice; drawing Undo is distinct from Flight Undo. |
| [#211 · Assisted review/fly](https://github.com/johnbenz13/NavigationFlight/issues/211) | Open | Assisted preparation belongs here; flying/map-aid execution remains later. Propose splitting at ticket preparation; do not edit the issue yet. |
| [#212 · History/export](https://github.com/johnbenz13/NavigationFlight/issues/212) | Open | Outside this slice. Saving a draft must not fabricate operational amendment events. |

Closed means tracker status, not new acceptance of the UX. #204 and #207 contain
historical acceptance comments; those approvals and their limitations remain
intact. No reopened issue or replacement ticket is implied by this local review.

## Written contracts

- [Product spec](../../../features/IN-FLIGHT-ROUTE-AMENDMENT_SPEC.md), including
  RA-01–RA-24, earlier approvals, and exact Figma links.
- [Delivery plan](../../../features/IN-FLIGHT-ROUTE-AMENDMENT_DELIVERY-PLAN.md)
  and [technical design](../../../technical/IN-FLIGHT-ROUTE-AMENDMENT-TECHNICAL-DESIGN.md).
- [Glossary](../../../../GLOSSARY.md), particularly Route amendment, Operational
  route, Flight, Reference result and Revised ETA.
- [Shared setup](../../../architecture/planning-configuration.md) and
  [product/Figma workflow](../../../workflows/PRODUCT-SPEC-FIGMA-WORKFLOW.md).

| Existing rule | Proposal's explicit difference | Authority status |
| --- | --- | --- |
| RA-01/RA-19 open drawing directly and use separate pause/play | Pencil toggles workspace; plotting starts only through Plot points. | Owner-approved future behavior, design pending. |
| Drawing and Review legs are distinct UI stages | One vertical leg list from the first formed leg, editable before rejoin. | Owner-approved future behavior. |
| RA-03/RA-10 complete required leg values before accepting them | Save partial fields independently; require all values only at Arm. | Owner-approved future behavior. |
| RA-12 pending pencil clock opens management | Status pencil opens preparation/inspection; Armed editing requires Disarm and edit. | Owner-approved direction; migration and exact states need design. |
| RA-12 permits further amendment once underway | Flying pencil is read-only; further amendment editing is deferred in this slice. | Explicit scoped departure from earlier entry behavior. |
| RA-13 discards unconfirmed drafts on process restart | Persist/restore unfinished drafts per Flight, unarmed, with eligibility recheck. | Owner-approved new recovery behavior. |
| RA-05/RA-08 scheduled confirmation changes the operational route | Arm keeps that effect; readiness and draft persistence do not. | Preserve behavior with clearer vocabulary. |
| Existing review Start Now | Remove from the proposed flow; preparation ends at Arm → Cockpit. No relocated action in armed inspection. | Explicit owner decision, 2026-11-24. Immediate departure deferred to flying reconciliation. |
| Completed draft-map segments share retained styling | Add completed history treatment distinct from retained and dashed bypass. | Owner-approved visual requirement; target design needed. |
| Current dark timing block | Keep current-leg timing readable and distinct with a lighter/more elegant treatment. | Owner's Q28 refinement; exact appearance pending. |

Do not mark the old spec/Figma unapproved wholesale. Only the listed preparation
behaviors are proposed replacements, and none has shipped through this work.
When the owner approves contract edits, link this reconciliation and update the
affected rules and glossary, retaining original approval and delivery records.

## Source findings

| Source | Finding and consequence |
| --- | --- |
| `NavigationFlight/Domain/Flight/RouteAmendmentDraft.swift` | Separate Step drawing/review, reviewLegs requires departure and rejoin, openEditor requires review, and acceptsLegTap gates proposed-leg selection on review. Continuous partial-route editing needs a behavioral change across these boundaries. |
| Same file, `RouteAmendmentRoute.originalSegments` | Original segments outside the bypass are all retained. Completed history is not a separate draft-overlay segment role. This is source evidence, not a runtime proof of all map styles. |
| `NavigationFlight/Domain/Flight/RouteAmendmentLegValues.swift` | Heading already accepts 1–360 and displays three digits; duration is positive without the proposed 60-minute cap. Optional frequency currently accepts any positive decimal, rather than a COM channel list. |
| `NavigationFlight/Features/Cockpit/RouteAmendmentConsole.swift` | Horizontal drawing content, point/inspection links, explicit Finish here/Review legs, separate review footer and pause control. |
| `NavigationFlight/Features/Cockpit/RouteAmendmentReview.swift` | Vertical rows each have a green Check button. |
| `NavigationFlight/Features/Cockpit/RouteAmendmentChartPanel.swift` | Floating map editor already exists. Uses text fields, step controls, optional cues and comparison; location is responsive around selected endpoints. Reuse the map association while redesigning value entry. |
| `NavigationFlight/Features/Cockpit/CockpitView.swift` | Ordinary pencil is disabled once a draft exists; separate pause/play; pending pencil uses clock badge and management popover. |
| `NavigationFlight/Features/Cockpit/CockpitFeatureState.swift` | Owns in-memory draft captured for Flight and preference mode. Durable unarmed draft storage must be distinct from pending operational amendment. |
| `NavigationFlight/Domain/Flight/PendingRouteAmendment.swift` | Existing confirmed amendment validates eligibility and accepted values. Preserve its operational transaction contracts when introducing Arm. |

These observations do not prescribe a new architecture. Preserve Flight ownership
of the operational route and keep unarmed preparation separate. No new service,
event model, migration or persistence format has been selected in this review.

## Evidence provenance

**Owner batch:** five PNG attachments inspected in conversation, copied unmodified
under `../assets/current/owner-2026-11-23/`. File names map screenshot numbers 1–5
to `01-review`, `02-empty-drawing`, `03-horizontal-route`, `04-leg-editor`, and
`05-pencil`. Screenshot 2 displays iPad Pro 11-inch (M5), iPadOS 27.2. Other images
are crops. Exact app revision, complete viewports and interaction transcripts are
unavailable. Preserve as owner-reported dated evidence, not fresh acceptance.

**Fresh runtime batch:** [runtime-observation.md](runtime-observation.md), nine
inspected images plus hierarchies/logs. A workspace build/install/run succeeded;
no test suite ran. This is a read-only reconciliation observation of existing
code, not a build verification of proposed implementation. Device session closed.
Completed-leg scenario, Assisted, arming and restart recovery remain unobserved.

**Historical Figma batch:** exported and inspected 2026-11-23 from
`7RYloAn7AntwSMe3zz5F4B`, nodes 12:90 (empty drawing), 12:222 (selected point),
13:485 (value/cue editor), 6:34 (Manual review), 7:94 (paused draft).
PNG previews are under `../assets/figma/`. They retain earlier approval as source
references; none is the target design for this reconciliation. New proposals
are explicitly **Design needed**. No Figma writes or new file creation occurred.

## Radio reference

Q25's 25 kHz scope is an owner decision, not a claim about every radio or Israel's
current channel requirements. [EUROCONTROL's implementation handbook](https://www.eurocontrol.int/publication/833khz-voice-channel-spacing-vcs-implementation-handbook)
explains that 8.33 kHz channel designators differ from carrier frequencies.
Deferred 8.33 kHz support cannot be implemented as free decimal arithmetic.

## Validation

Documentation and assets only. Verify local links, image existence/dimensions,
retained capture hashes, and `git diff --check`. No application tests are needed
for documentation changes. The runtime build was necessary for the explicitly
authorized current-product observation, not a reason to rerun suites.
