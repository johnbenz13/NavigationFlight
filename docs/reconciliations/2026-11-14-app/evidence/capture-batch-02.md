# Capture batch 02 — saved-plan management

[Current chapter](../current/manage-flight-plans.md) · [Machine-readable manifest](batch-02/captures.json)

Captured and inspected on 2026-11-14, baseline `1a2d7e7596667a39616fe3812f6a07326f30ca00`,
branch `reconcile/2026-11-14-app`. Device: iPad Pro 11-inch (M5), iOS 27.0 (24A434),
portrait 834 × 1210 points. Full PNGs, accessibility hierarchies and runtime logs are
retained. No source changes or test suites were used; runtime installation built the baseline.

Each record contains the exact action, environment and file checksums. Long encoded
fixture inputs are represented by `encoding: base64` plus `bytesFrom`: base64-encode
the exact retained file bytes to reconstruct that environment value. [Fixture checksums](batch-02/fixtures.json)
cover base/newer/older/invalid inputs. Newer/older fixtures vary the modification time
by one minute, retaining identity; the protected fixture uses a synthetic epoch-1000 start.

| Captures | Stories | Evidence |
| --- | --- | --- |
| 01 | S10 | Settled cancellation leaves empty library. |
| 02–03 | S11 | Import via debug input, then same library relaunch without import/seed. |
| 04 | S12 | Same-revision feedback. |
| 05–07 | S13 | Newer and older confirmation, both cancelled, original revision retained. |
| 08–09 | S14 | Malformed-input and injected save-failure messages. |
| 10 | S15 | Protected restart warning, cancelled. |
| 11–13 | S16 | Loaded-copy removal warning, empty library, active Cockpit retained. |

Real Files import remains unverified: `simctl get_app_container` could not connect to
CoreSimulator under the sandbox to stage a disposable file. No existing user file
was opened. The import hook exercises decoder/library behavior, not provider handoff.
One-row persistence is not a sorting check or an airplane-mode test. Fixture timers,
sensor statuses and white off-chart maps must not be interpreted as real flight data.

Original transient captures remain in `/tmp/navigationflight-reconcile-batch02` for
this session. The repository copies and normalized manifest are the durable record.
