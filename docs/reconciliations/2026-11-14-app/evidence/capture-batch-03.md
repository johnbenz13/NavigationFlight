# Capture batch 03 — active navigation

[Current chapter](../current/fly-and-revise.md) · [Manifest](batch-03/captures.json)

Captured and inspected 2026-11-14 at baseline `1a2d7e7`, same reconciliation branch.
iPad Pro 11-inch (M5), iOS 27.0 (24A434), portrait 834 × 1210 points.
Thirteen full screenshots, hierarchies and logs are retained with checksums; exact
[fixture bytes and hashes](batch-03/fixtures.json) reconstruct base64 environment inputs.

| Captures | Stories | Sequence |
| --- | --- | --- |
| 01 | S17 | Explicit Start opens checklist; note collapses it. |
| 02–03 | S18 | Heading editor, +1°, commit 356°. |
| 04–05 | S19 | ETA editor, +5 sec, commit 00:45; Check unavailable. |
| 06 | S20 | Full Frequency Plan and live console in the same screenshot. |
| 07–09 | S21–S22 | Identify, final reach, Undo before expiry. |
| 10 | S23 | Drift Off, Chart layers message. |
| 11–13 | S24–S25 | Separate two-leg fixture: preview, reach, automatic successor, previous history. |

The two-leg fixture mirrors the existing UI-test helper and clones saved execution
data. It establishes UI/progression paths, not valid real-world course calculations.
All routes are synthetic and outside chart coverage. No radio/sensor/physical-flight
claims follow from these captures. Runtime installation/build was used; no tests or
source modifications were made. Timing observations use visible before/after values,
not an instrumented assertion of internal timestamp equality.
