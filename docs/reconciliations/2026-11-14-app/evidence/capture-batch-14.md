# Capture batch14 — recovery selection and natural expiry

[Back to the map](../README.md) · [S77–S78](../current/recovery-selection-and-expiry.md)

Baseline `1a2d7e7`, 2026-11-14, iPad Pro11-inch(M5), iOS27, portrait.
All twelve retained captures were visually inspected. [Captures](batch-14/captures.json)
retain action order, environments, screenshot/hierarchy/log hashes; [fixtures](batch-14/fixtures.json)
retain synthetic bytes.

| Captures | Observation |
| --- | --- |
| 01–04 | Select one candidate without confirmation; other closes as superseded. |
| 07–11 | Uninterrupted untouched countdown from4:00 through0:09. |
| 12–14 | Expiry opens Plan Inspection; manual Flights visit finds Incomplete/Recovery expired. |

05–06 are excluded: tool idle session cleanup invalidated that first attempt. The second
attempt keeps the device session active through bounded waits without pressing recovery
actions. No app source or clock was changed. Exact competing Continue/expiry and background
expiry races are not established. Partially captured countdown glyphs are not classified
as a new product discrepancy.
