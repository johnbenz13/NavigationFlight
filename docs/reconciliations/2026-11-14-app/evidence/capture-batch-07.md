# Capture batch 07 — settled exits and destructive branches

[Manifest](batch-07/captures.json) · [Exact fixture hashes](batch-07/fixtures.json)

Captured/inspected 2026-11-14, same `1a2d7e7` baseline and iPad Pro 11-inch (M5),
iOS 27.0 (24A434), portrait 834 × 1210. Sixteen images, hierarchies and logs retained.

| Captures | Stories | Evidence |
| --- | --- | --- |
| 01–05 | S45 | Ready before check, hold, cancel+2 sec, +3 sec, second hold+natural expiry. |
| 06–07 | S46 | Separate synthetic signal-loss run before/after loss. |
| 08–11 | S47 | Newer Replace saved 12:01; same persisted library older Replace saved 11:59. |
| 12–14 | S48 | Removal cancelled; separate injected removal-failure presentation. |
| 15–16 | S49 | Protected Restart confirmed, ready 00:00. |

The original cancel frame remains in batch04; new settled evidence narrows its ambiguity
without rewriting history. No real GPS or Files-provider import is claimed. Exact
environment inputs are in the manifest, with long base64 values reconstructed from
retained fixture bytes. No source changes, test suites or external mutations occurred.
