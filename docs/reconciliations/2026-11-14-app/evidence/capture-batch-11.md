# Capture batch 11 — library protection and settled Undo

[Manifest](batch-11/captures.json) · [Fixture hashes](batch-11/fixtures.json)

Fourteen captures inspected 2026-11-14 at `1a2d7e7`, iPad Pro 11-inch (M5), iOS 27.0
(24A434), portrait 834 × 1210. New library stories are [S66–S69](../current/library-protection.md).

| Captures | Story | Evidence |
| --- | --- | --- |
| 01 | S65 | Settled route collapse after final Undo. |
| 02 | S66 | Three plans ordered by seeded import recency. |
| 03–09 | S67 | Protected current Flight, draft, different-plan cancellation, later confirmed replacement. |
| 10–12 | S68 | Newer saved revision versus older loaded snapshot. |
| 13–14 | S69 | Failed replacement retains the existing saved revision. |

Supporting captures: [03 initial protected inspection](../assets/current/batch-11/03-protected-before.png),
[07 immediate cancellation](../assets/current/batch-11/07-cancel-preserves-draft.png),
[11 premature review tap](../assets/current/batch-11/11-newer-review-loaded-older.png).
Capture07 still shows Alpha review; only08 proves return/draft retention. Capture11
duplicates the success alert; only12 establishes the later review state. Filename
wording does not override these inspected limits. The protected fixture's historical
start time explains its unusually large elapsed timer.

No source edits, test suites or external writes occurred. Full durable recording
disposition during confirmed different-plan replacement remains outside these images.
