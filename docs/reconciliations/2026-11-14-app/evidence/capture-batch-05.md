# Capture batch 05 — Flights and recovery

[Current chapter](../current/flights-and-recovery.md) · [Manifest](batch-05/captures.json)

Captured/inspected 2026-11-14, baseline `1a2d7e7`, iPad Pro 11-inch (M5), iOS 27.0
(24A434), portrait 834 × 1210 points. Nineteen full images retain their original 08–26
capture identifiers; numbering continues the device session, not the story numbering.
Hierarchies, logs and checksums accompany exact [fixture bytes](batch-05/fixtures.json).

| Captures | Stories | Evidence |
| --- | --- | --- |
| 08–09, 12 | S30–S31 | Populated library, closed detail, lower evidence/deletion. |
| 10–11 | S32 | Export result and native share; no external destination selected. |
| 13–15 | S33 | Confirm deletion, stale row, unavailable reopen in same process. |
| 16 | S34 | Action-only closed recording, unavailable GPS. |
| 17–18, 26 | S35 | Fresh gate, immediate transition, settled active Cockpit. |
| 24–25 | S36 | Single-End confirmation and settled Plan Inspection destination. |
| 19–20 | S37 | Multiple gate, direct End All result (filename “confirmation” is not an observed dialog). |
| 21–23 | S38 | Unsupported gate/handoff and corrupt gate. |

The populated library hook bypasses recovery bootstrap and seeds otherwise exceptional
rows. Do not infer production recovery flow from its Recovery Required entry. Each
fresh recovery scenario instead uses its dedicated hook. Seeded stores are recreated
on relaunch; the deletion finding explicitly uses the same process without relaunch.

Read-only source investigation found removal is not a fixture no-op: the in-memory
store removes the entry, the library delegates removal, and view state is intended to
drop the row. The existing `testConfirmedClosedFlightDeletionReturnsToListAfterRemoval`
expects the Jerusalem fixture to disappear. These facts support treating the runtime
result as a discrepancy; they do not diagnose its cause or count as a test run.
Recovery End's existing UI test expects Flight Plans, while the approved contract §68
requires saved detail; the observed loaded-fixture result is Plan Inspection. Keep
historical tests distinct from intended behavior.

No GPX bytes were inspected and no export was sent. No real sensor recording or OS
termination recovery was exercised. Runtime build/install supported the captures;
no source changes or test suites were used.
