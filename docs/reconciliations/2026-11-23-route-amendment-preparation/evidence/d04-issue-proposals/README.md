# D04 approved issue contract changes

John approved the prepared patches, anchor recovery and accessible pattern on
2026-11-24. Scoped updates published to #227/#228/#231/#233; unchecked acceptance
criteria remain unchecked. The original patch draft below is retained as review
history, including its formerly pending language. No implementation is authorized.
Local documentation awaits authorized commit/push and immutable approval permalink.

# D04 issue contract patches · not published

Drafted 2026-11-24 against the current local task contracts and inspected live
#227/#228 bodies. Root review and John’s approval were completed before publication.
Retain unrelated body content, original approvals, historical references and
acceptance evidence. Add the D04 exact design link with proposed/approved status
matching the actual owner decision; do not mark criteria complete.

## #227 / AP-03

Replace scope sentence:

> Forward-order validation, crossing occurrence choice, direct drawing from an eligible departure and automatic final rejoin; remove Plot points, Done plotting, Continue plotting, Change return point and staged Finish here/Review legs gates.

Replace acceptance criterion 1:

> - [ ] Opening the editable workspace permits short-tap departure selection and subsequent point placement without Plot points or Done plotting. An eligible deliberate route tap rejoins automatically and retains the vertical leg rows; crossing a line without tapping does nothing.

Replace acceptance criterion 4:

> - [ ] Rejoin completes drawing. Subsequent free-map taps preserve the rejoined geometry and never extend it or begin another amendment. Continue plotting and Change return point are absent.

Replace UI test bullet:

> - UI fixture B exercises occurrence selection, automatic rejoin and no extension after rejoin; verify a line crossing alone does not rejoin. Short proposed-leg/row taps open values before and after rejoin under the agreed hit-priority rule.

Add criterion: while drawing with a departure, a short tap hitting both a proposed leg and eligible original route presents **Edit / Rejoin**; choosing Edit opens values without geometry mutation, choosing Rejoin applies current eligibility validation. After rejoin, proposed-leg taps only edit and original/free-map taps preserve geometry. Explicit deletion of rejoin reopens drawing.

## #228 / AP-04

Replace acceptance criterion 1:

> - [ ] A short tap on a proposed map leg or its row opens the same selected-leg modal while drawing and after rejoin, without shifting the underlying map/console or appending a point. Closing the modal preserves geometry and partial entries.

Replace UI entry bullet:

> - UI opens the same leg from map and row before and after rejoin, closes/reopens partial entries and checks unavailable estimates on iPad/compact. Cover the agreed overlap hit-priority rule without accidentally plotting or rejoining.

All heading ranges, independent saves, Check behavior and existing editor visuals
remain unchanged. On overlapping proposed/original legs while drawing with departure, present **Edit / Rejoin**. After rejoin, proposed-leg taps only edit with no Rejoin option; original/free-map taps leave geometry unchanged. Edit opens this same modal without geometry mutation.

## #231 / AP-07

Replace scope sentence:

> Point-versus-leg gesture dispatch, direct long-press drag movement, long-press release Delete, permitted anchor corrections, cue retention and full draft Undo.

Replace acceptance criterion 1:

> - [ ] Long press and drag any point, including departure and rejoin, to move it directly. Long press then release without dragging offers Delete. Short proposed-leg or row taps open values, including during drawing. Provide accessible equivalents for correction and value entry.

Replace UI fixture bullet:

> - UI fixture A long-press drags Point 1, sees only legs 1/2 cleared, then Undo restores exact values and cues. Long press/release exposes Delete without movement; cancellation leaves the prior draft intact.

Anchor drops must land on eligible original-route occurrences, with departure strictly before rejoin including same-leg fractions/current progress. Invalid drops roll back atomically with feedback. Movement/crossing alone never rejoins; retain pan/pinch and accessible Map tools equivalents.

**Proposed recovery criterion for approval:** deleting departure preserves vias/rejoin and unaffected values, marks geometry incomplete, and uses the next eligible route tap to replace departure. Deleting rejoin preserves departure/vias and unaffected values, marks geometry incomplete, and resumes drawing from the last surviving point until eligible rejoin. Arm remains unavailable until repaired; invalid choices are rejected atomically; Undo restores the complete draft. This recovery is an agent proposal, separate from the owner’s all-point gesture decision.

## #233 / AP-09

Replace recovery criterion:

> - [ ] Recover only with the same unfinished Flight into ordinary Cockpit, unarmed; preserve existing armed recovery. On pencil reopen, restore points, values and selection. Geometry determines whether direct drawing can continue or the route is already rejoined; reopening never adds a point, extends a rejoin or arms the amendment.

Do not change persistence, corruption, retry, mode capture or Flight ownership.

## Retained surrounding tasks

- #234: explicit Update departure is a stale-anchor recovery command; no plotting
  toggle assumption requires rewriting it. All-point correction must preserve this explicit recovery command.
- #236: Armed/Flying inspection remains read-only and Disarm remains explicit.
- #229/#230: value controls and cues remain unchanged.
- #225/#226: preserve historical delivery and evidence; describe D04 as a later
  scoped revision rather than rewriting what was delivered.

**Accessible pattern proposed for approval for #227/#231:** reuse Map tools waypoint/map-center placement and a native named Departure / Point N / Rejoin point-action list with Move / Delete. Accessible Move uses the next eligible-location tap as the alternative to dragging, applying the same constraints, rollback and Undo; no plotting toggle returns.
