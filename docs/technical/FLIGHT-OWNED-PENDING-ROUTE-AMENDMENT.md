# Flight-owned pending route amendment

[#206](https://github.com/johnbenz13/NavigationFlight/issues/206) adds scheduling and recovery to the [Manual route amendment review](ROUTE-AMENDMENT-MANUAL-REVIEW.md). The [approved technical design](https://github.com/johnbenz13/NavigationFlight/blob/047ff3d0b57f035926829009a1cfba17aaf4fc73/docs/technical/IN-FLIGHT-ROUTE-AMENDMENT-TECHNICAL-DESIGN.md) defines the remaining activation, management, and Undo slices.

`Flight.pendingRouteAmendment` owns the committed departure and rejoin occurrences, stable replacement leg and stop IDs, accepted coordinates and Manual values, and captured modes and progression policy. Cockpit keeps the unconfirmed draft and any retry state in memory. Confirmation validates the draft against the current Flight and its pilot-reported progress. The imported Flight Plan and its captured source bytes remain the authority for the source route and planned values. Check estimates are transient.

When a partway departure becomes current, the operational leg keeps its source leg ID, timing origin, and original heading. Flight resolves its arrival to the committed departure point, with a planned elapsed ETA scaled by the original planned duration. Until that boundary, normal navigation still uses the original route. The departure point has an independent destination identification and ETA identity. Its original arrival identification remains in the journal. A waypoint departure keeps the existing arrival identity. The reaching command fails safely at the scheduled boundary until the departure activation slice delivers the handoff.

## Recording and recovery

The first route transaction upgrades the package manifest to schema 4. Its event is written in the existing checksummed `events.ndjson` journal. The operation ID is the confirmation event ID. The expected sequence is the journal's next event sequence at command preparation. An identical operation can be acknowledged again without appending another event. Conflicting or stale operations fail.

The disk adapter writes and synchronizes a replacement journal in the package directory. It installs and synchronizes the manifest upgrade first, so an interrupted upgrade with the preceding journal is readable. It atomically renames the replacement into place, then synchronizes the directory before acknowledging success. Journal, checkpoint, and close mutations use the same recording writer lock. A write with an uncertain outcome is reconciled against the persisted operation and fenced in the recording engine until resolved. Cockpit only installs the pending route after the durable acknowledgment.

Schema 1–3 packages continue to decode. A legacy package keeps its prior cockpit-context baseline when upgrading. Route events carry the accepted geometry, inputs and checklist context. Neither recovery nor retry runs the estimate calculation again. Recovery replays confirmed facts against the recorded Flight Plan and verifies the anchor occurrences before restoring Cockpit. A readable recording with unsafe route replay can be ended as incomplete from the existing recovery gate. The track directory, GPX output, and captured Flight Plan are unaffected by the recording upgrade.

## Manage a pending amendment

[#209](https://github.com/johnbenz13/NavigationFlight/issues/209) keeps one saved amendment while the pilot edits a replacement draft. Keeping the saved route or dismissing the management controls leaves the journal unchanged. Confirming a replacement or cancellation revalidates the expected pending amendment and writes a dedicated history event.

RA-23 exposes **Report original destination reached…** in the [pending pencil menu](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=26-266) only while the shortened leg is active. The original destination must be the end of the same leg, ahead of its partway departure. The pilot is the source of this report. The normal Identify and Reach actions still target the departure point. The [approved confirmation](https://www.figma.com/design/7RYloAn7AntwSMe3zz5F4B?node-id=23-457) interpolates the original waypoint into “You’re reporting [waypoint] reached on the original route. Confirming cancels the pending amendment and records this reach.”

- **Keep pending** dismisses the confirmation without writing an event.
- **Cancel and record reach** appends linked cancellation, waypoint reach and any progression events together in the checksummed journal. The recording actor revalidates the destination identity and applies the Flight’s existing progression policy. Recovery requires the full event group, and ordinary Reach Undo restores the pending route, timer and checklist context together.
- A failed write leaves the confirmed route visible and keeps the operation and event IDs for retry. An unresolved write is reconciled before other recording mutations continue.
