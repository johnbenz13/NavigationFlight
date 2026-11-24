# Shared contract for amendment-preparation tasks

**Approved breakdown contract · John · 2026-11-24.** Product/design approval is recorded in
[D03](../design-revision-d03.md); John approved these technical contracts and ticket boundaries, including the
time-wheel first-edit semantics and scoped recovery-error reuse. Publication is
authorized; implementation remains separately requested.

## Authority and implementation gate

Use the [canonical approved-future scope](../../../../../docs/features/IN-FLIGHT-ROUTE-AMENDMENT_SPEC.md#approved-future-preparation-revision--2026-11-24),
[G01–G07](../preparing-an-amendment.md), [decisions](../decisions.md), D03
geometry/editor rules and retained D02 state content. Every ticket inherits this
contract. Historical designs and #204–#209 acceptance remain discoverable; this
approved future preparation behavior supersedes their conflicting preparation
controls only. Existing flying/rejoin/history behavior remains unchanged.

Before any ticket starts, the approved product/design checkpoint must be merged
to main through [PR #223](https://github.com/johnbenz13/NavigationFlight/pull/223)
or its explicit successor. Follow the repository ticket-workflow preflight and
verify every blocking ticket's PR has merged to main. Drafting or publishing
does not authorize implementing all tasks. Review each small outcome before
moving to the next requested task.

## Regular Cockpit is protected

Figma node 29:989 is contextual only. Implement only its pencil and small
amendment status text. Keep the current approved regular Cockpit instruments,
labels, buttons, colours, spacing, disclosures and progression interactions.
Use the actual existing approved regular patterns, including the accepted
[#207 Cockpit baseline](https://github.com/johnbenz13/NavigationFlight/issues/207#issuecomment-7095261415)
where applicable; verify its current authoritative references before editing.
The contextual frame cannot fill a missing regular-Cockpit design reference.

Share the current CockpitRestingLayoutPolicy between modes: 288 pt portrait,
278 pt compact and 370 pt landscape rail, with the same safe-area, operational,
window and accessibility adjustments. Preserve map camera/zoom and timing when
toggling or opening a leg editor. Legitimate pilot progression still works while
the workspace is hidden. Only explicit Arm changes the operational route.

## Inspected implementation and ownership

Source inspected at `46967c5d8bb3f15e27e00835572d7300c491364e`; no source changes
were made during planning. Reinspect the merged main head when implementing.

- `Domain/Flight/RouteAmendmentDraft.swift`: Step mixes drawing/review state;
  reviewLegs requires a rejoin; leg IDs include endpoint coordinates; history
  currently snapshots geometry rather than the complete value state.
- `Domain/Flight/RouteAmendmentLegValues.swift`: accepted values are all-or-nothing;
  entry uses strings; duration has no 60-minute cap; frequency accepts any
  positive decimal. Existing accepted/pending values are a compatibility boundary.
- `Features/Cockpit/CockpitFeatureState.swift` owns the draft by Flight ID;
  CockpitFeatureView coordinates saves, pending commands and estimator inputs.
- RouteAmendmentConsole, Review and ChartPanel own the existing staged UI;
  CockpitView currently enlarges the amendment console. Reuse native controls
  and existing semantic typography/colours; change amendment branches only.
- PendingRouteAmendment, FlightRecordingEngine and the recording coordinator/store
  already implement validated, atomic and idempotent scheduled confirmation and
  cancellation. Reuse these operations; do not create a second flight engine.
- Existing tests include amendment domain/lifecycle tests in
  NavigationFlightTests.swift, RouteAmendmentEstimateTests and UI fixtures in
  NavigationFlightUITests.swift. Extend those seams with focused new tests.

## Proposed interfaces and invariants

These are approved implementation contracts, not claims that types exist.

- Keep workspace visibility, plotting and lifecycle separate. Derive readiness
  from route eligibility and required values, not editor step. Unsaved status
  is independent. Keep presentation state outside Flight's operational route.
- Project adjacent formed segments before rejoin. Identify a directed leg by
  stable endpoint identities: original-route occurrence or plotted-point UUID.
  Track coordinates separately as a geometry signature. Moving a point retains
  logical adjacent legs/cues but invalidates their heading/time. Removing a point
  deletes adjacent legs and their cues; the new merged leg starts empty. Never
  migrate values or cues by row index. Undo restores geometry, partial values,
  selection, cues and estimate provenance together.
- Store independent optional heading and duration values plus unfinished wheel
  state. Keep a lossless adapter into existing complete RouteAmendmentLegValues
  only when valid. UI displays Not set until deliberate entry. Proposal for time
  interaction: the first deliberate minute/second change explicitly creates a
  duration with the other component at zero; opening alone creates nothing.
  Clearing either component preserves the other; clearing both leaves Not set.
  This detail was approved with AP-05.
- Preserve existing off-step/out-of-range cue values unchanged in a custom-value
  presentation until deliberately changed or cleared. New edits must use the
  agreed range/channel set. No implicit rounding. Use integer kHz channel IDs
  for 118000…136975 in 25 kHz steps; adapt at the existing MHz boundary.
- Capture mode per draft. Record per-field origin/override information; Check is
  a separate result, never a write into pilot entries. Geometry changes affect
  only changed segments. Existing estimator math and execution-mode inputs stay.
- Proposed draft persistence: a versioned, atomic, Flight-keyed local draft store
  separate from the operational recording journal and portable Flight evidence.
  Include route anchors, points, partial entries, cues, mode/provenance, selection,
  editor context and Undo snapshots. Do not persist transient open/plotting flags.
  Provide an injected in-memory/failing store with load/save/remove operations.
  Revisions prevent slow writes overwriting newer edits. Closing/deleting a Flight
  makes its draft unavailable; changing Flights never loads the prior draft.
- Unsupported/corrupt draft data never activates anything or silently overwrites
  the saved bytes. Preserve it, keep ordinary Cockpit usable and show a scoped
  recovery failure using the D02-F10 error pattern. This pattern reuse and draft
  storage design were approved with the breakdown. Existing armed recording recovery
  remains authoritative and wins over any stale unarmed draft snapshot.
- Arm revalidates the Flight generation/route and uses the existing scheduled
  transaction, operation ID and retry reconciliation. Never use startsImmediately.
  Remove an old draft only after confirmed arm success; failure retains it.
  Draft cleanup failure must not resurrect an armed amendment as an unarmed draft.
- Disarm uses existing durable pending cancellation, restoring the preceding
  operational route before exposing editable preparation. Keep a recoverable copy
  of the accepted values until draft persistence and cancellation outcomes are
  reconciled. Stage the draft with its source amendment/operation identity before
  cancellation; recovery exposes it only after that cancellation is confirmed.
  A discard intent is retained until deletion is reconciled, so a deletion failure
  cannot reopen discarded preparation. Failed/uncertain outcomes keep the last committed route and Retry;
  never show both an editable draft and an unresolved armed operation.

## Design and reproduction contract inherited by every UI ticket

Primary: iPad Pro 11 portrait 834 × 1194. Secondary: iPad landscape 1194 × 834
and iPhone 16 Pro portrait 402 × 874; no iPhone landscape. Other supported compact
sizes and Larger Text must wrap/scroll without losing actions. Native wheel and
material geometry follows the platform. All targets are at least 44 pt; statuses
have shape/text/VoiceOver meanings; Reduce Motion avoids route animations.

Use D03-A/C/D/E/F for geometry, D02's exact state nodes for state contents, and
the existing app for all excluded regular Cockpit regions. Use the existing map,
system fonts/semantic styles, native buttons/alerts, wheel pickers and existing
Map tools. Do not flatten Figma or hardcode its illustrative Flight values.

Fixture A: synthetic underway Flight, original leg 2 Kadima → Ramat, Timer 07:22,
planned leg time 04:23; departure 46%, Point 1, Point 2, rejoin Aviel. Values are
087°/03:20, 176°/02:15, 024°/04:10. Fixture B adds crossing occurrences, repeated
coordinates and a same-leg 30%→80% detour. Fixture C uses injected save failures,
restart, another Flight and stale progress. Fixture D uses Assisted available and
unavailable no-wind inputs plus domain-only planned-wind parity. Use both Manual
and Automatic progression at operational handoffs. Hebrew/RTL waypoint names
must retain directional isolation. Use disposable launch fixtures, not live Flights.

## Verification and delivery

Each ticket owns its domain/storage/UI tests and affected responsive/accessibility
evidence; there is no final all-tests or all-responsive ticket. During separately
authorized implementation: focused Swift Testing, relevant UI tests, Xcode build,
direct simulator interaction and exact-node visual comparison, then diff checks.
Use controlled clocks and injected stores; do not sleep to test timing/retries.
Document success, failure, cancellation/recovery and preserved operational state.

For each UI criterion retain exact Figma node/design rule + fixture + device +
simulator screenshot and comparison result. Visual acceptance remains unchecked
until John approves; missing evidence remains unverified. Update feature/technical
docs and scoped supersessions as each behavior lands. Never rewrite completed
issue acceptance or close issues before their implementation PR merges.

Publication was authorized and completed. This planning phase does not authorize
application builds, test runs, simulator sessions or implementation. Documentation links/whitespace
checks are checkpoint hygiene, not implementation validation.
