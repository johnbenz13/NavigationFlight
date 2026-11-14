# Capture batch20 — available iPhone active flows

[Back to the map](../README.md) · [S90](../current/phone-and-resizing.md#s90--start-and-use-the-available-iphone-cockpit)

Baseline `1a2d7e7`,2026-11-14, **iPhone17**,iOS27(24A434),402×874 portrait.
All five screenshots were inspected. [Captures](batch-20/captures.json) retain inputs,
actions and hashes; [fixtures](batch-20/fixtures.json) retain exact synthetic bytes.
The normalized device header corrects the agent's default iPad template, explicitly
identified as wrong in its notes.

| Captures | Observation |
| --- | --- |
| 01 | Ready header present; initial map collapsed, not settled ready acceptance. |
| 02 | Start checklist sheet. |
| 03–04 | Active instruments and Position Check; route header absent. |
| 05 | Cancel Position Check, open heading editor; map collapsed. |

The interaction tool rejected iPhone16Pro and listed17/17e/18Pro/18ProMax/Air/Duo on
available iOS27/27.2 runtimes. This is substitution evidence, not iPhone16Pro verification.
No phone heading commit or full adaptation matrix is claimed.
