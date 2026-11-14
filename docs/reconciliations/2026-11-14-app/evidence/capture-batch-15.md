# Capture batch15 — durable action-only lifecycle and skipped IP

[Back to the map](../README.md) · [S79–S81](../current/durable-action-only-flight.md)

Baseline `1a2d7e7`, 2026-11-14, iPad Pro11-inch(M5), iOS27, portrait.
All fourteen retained screenshots were inspected. [Captures](batch-15/captures.json)
record the exact stable library ID and launch environments; [fixtures](batch-15/fixtures.json)
retain the synthetic route. No recovery or Flights package seed is supplied at relaunch.

| Captures | Observation |
| --- | --- |
| 01–04 | Start, heading356 commit, actual checkpoint discovery after clean relaunch, Continue. |
| 05–08 | Final reach bypasses IP; visible historical callout and completed heading history. |
| 09–11 | Navigation Complete, manual End confirmation and ended status. |
| 12–14 | Saved Manually Ended record, Complete/Manual/Unavailable detail, no export action. |

06's hierarchy hitpoint misses;07's visible-label fallback opens the IP.09's filename
says end-sheet but shows the cockpit after Navigation Complete, before the End dialog.
The retained action descriptions govern interpretation. This is bounded clean-relaunch
durability, not process-crash, device-reboot or prolonged background verification.
