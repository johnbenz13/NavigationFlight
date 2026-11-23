# Flight-owned pending route amendment

[#206](https://github.com/johnbenz13/NavigationFlight/issues/206) adds scheduling and recovery to the [Manual route amendment review](ROUTE-AMENDMENT-MANUAL-REVIEW.md). The [approved technical design](https://github.com/johnbenz13/NavigationFlight/blob/047ff3d0b57f035926829009a1cfba17aaf4fc73/docs/technical/IN-FLIGHT-ROUTE-AMENDMENT-TECHNICAL-DESIGN.md) defines the remaining activation, management, and Undo slices.

`Flight.pendingRouteAmendment` owns the committed departure and rejoin occurrences, stable replacement leg and stop IDs, accepted coordinates and Manual values, and captured modes and progression policy. Cockpit keeps the unconfirmed draft and any retry state in memory. Confirmation validates the draft against the current Flight and its pilot-reported progress. The imported Flight Plan and its captured source bytes remain the authority for the source route and planned values. Check estimates are transient.

When a partway departure becomes current, the operational leg keeps its source leg ID, timing origin, and original heading. Flight resolves its arrival to the committed departure point, with a planned elapsed ETA scaled by the original planned duration. Until that boundary, normal navigation still uses the original route. The departure point has an independent destination identification and ETA identity. Its original arrival identification remains in the journal. A waypoint departure keeps the existing arrival identity. A destination report uses that leg and target occurrence to activate the
scheduled amendment. A real waypoint report records arrival and activation
together. A partway report records departure and elapsed timing at the shortened
boundary and leaves the original waypoint unreported.

## Departure and replacement legs

[#207](https://github.com/johnbenz13/NavigationFlight/issues/207) adds the
departure handoff. Start Now confirms and starts the first replacement leg at
the selected current anchor, including a ready departure boundary. A scheduled
departure starts immediately under Automatic progression. Manual progression
presently selects the first replacement leg in Ready and captures its start
time and checklist only when the pilot starts it.

The Flight owns the retained timing and the active route's ordered leg IDs.
Replacement legs keep the identities assigned at confirmation. Arrival
identities, timing, pilot heading and ETA revisions, and checklist records use
those IDs. The imported route remains available as a separate source of
geometry. Its bypassed interval renders as a dashed route, with its targets and
cues excluded from advancement. New legs use the confirmed heading and duration,
with optional altitude and frequency as leg-start advisories. When omitted,
the last eligible reference remains visible. Manual amendments omit minute
marks and drift arms. Position Check takes the current leg's operational
geometry and remains a separate pilot action. Return to the retained route and
route-transition Undo are covered by later slices.

## Recording and recovery

The first route transaction upgrades the package manifest to schema 4. Its event is written in the existing checksummed `events.ndjson` journal. The first event ID identifies the operation. The expected sequence is the
journal's next event sequence at command preparation. A departure transaction
records the departure boundary, original elapsed timing, any actual waypoint
arrival, and the effective successor start with its checklist context. A Start
Now transaction also includes confirmation. The journal exposes every event in
the transaction together. An identical operation can be acknowledged again
without appending another event. Conflicting or stale operations fail.

The disk adapter writes and synchronizes a replacement journal in the package directory. It installs and synchronizes the manifest upgrade first, so an interrupted upgrade with the preceding journal is readable. It atomically renames the replacement into place, then synchronizes the directory before acknowledging success. Journal, checkpoint, and close mutations use the same recording writer lock. A write with an uncertain outcome is reconciled against the persisted operation and fenced in the recording engine until resolved. Cockpit only installs the pending route after the durable acknowledgment.

Schema 1–3 packages continue to decode. A legacy package keeps its prior cockpit-context baseline when upgrading. Route events carry the accepted geometry, inputs and checklist context. Neither recovery nor retry runs the estimate calculation again. Recovery replays confirmed facts against the recorded Flight Plan and verifies the anchor occurrences before restoring Cockpit. A readable recording with unsafe route replay can be ended as incomplete from the existing recovery gate. The track directory, GPX output, and captured Flight Plan are unaffected by the recording upgrade.
