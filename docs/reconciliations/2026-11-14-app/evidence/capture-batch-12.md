# Capture batch 12 — Position Check outcome branches

[Manifest](batch-12/captures.json) · [Fixture hashes](batch-12/fixtures.json)

Twelve captures inspected on 2026-11-14 at `1a2d7e7`, iPad Pro 11-inch (M5),
iOS 27.0 (24A434), portrait 834 × 1210. [Stories S71–S74](../current/position-check-outcomes.md).

| Captures | Story | Evidence |
| --- | --- | --- |
| 01, 05–07 | S71 | On-track, position-only, no-intercept and extreme-displacement presentations. |
| 02–04 | S72 | Original expired tab attempt, fresh background and fresh tab-return sequences. |
| 08–10 | S73 | Acquisition timeout and unchanged result after hold/tap attempts. |
| 11–12 | S74 | Delayed permission revocation removes disclosed position and guidance. |

Capture02 does not prove tab cancellation: its disclosure already expired. Capture04
is the fresh under-ten-second transition. Permission revocation uses a twelve-second
delay from launch; the six-second wait follows an accepted disclosure, and the post-loss
leg timer shows ten seconds versus three before loss. No real permission, sensor or
spoken-announcement guarantee follows. No source edits, tests or external writes occurred.
