# Capture batch17 — settled history and fresh timeout retry

[Back to the map](../README.md)

Baseline `1a2d7e7`, 2026-11-14, iPad Pro11-inch(M5), iOS27, portrait.
All six screenshots were inspected. [Captures](batch-17/captures.json) retain exact
inputs, actions, hierarchies and hashes; [fixtures](batch-17/fixtures.json) retain bytes.

| Captures | Observation |
| --- | --- |
| 01 | Recovered completed Flight; scrolling Previous panel reveals no added revision/reference fields. |
| 02–03 | Completed ETA console and destination hitpoint/visible-label attempts do not reopen a callout. |
| 04–06 | Fresh acquisition timeout; exact current control tap and1.2-second hold both leave timeout visible. |

These support S83/G23 and S73/G22. They do not prove completed historical edits are
possible, successful live GPS recovery, or behavior under every gesture/timing race.
