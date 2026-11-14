# Capture batch13 — real provider and calculation selection

[Back to the map](../README.md) · [Current stories S75–S76](../current/provider-and-calculation-mode.md)

Baseline `1a2d7e7`, 2026-11-14, iPad Pro 11-inch (M5), iOS27(24A434), portrait.
All eleven retained screenshots were inspected. Exact capture metadata, hierarchy and
logs are in [captures.json](batch-13/captures.json); exact synthetic inputs and hashes
are in [fixtures.json](batch-13/fixtures.json).

| Captures | Observation |
| --- | --- |
| 01–02 | Safari downloads the disposable localhost attachment. |
| 08–11 | Fresh empty library, settled Downloads, successful real provider import, review. |
| 12 | Loaded route renders over bundled chart. |
| 13–16 | No wind selection, ready values, direct Start and settled mixed operational values. |

03–07 belong to an unintended existing-item import caused by a stale picker hitpoint.
They are excluded from retained review evidence; no existing provider file bytes were
copied. Subsequent import uses a new disposable library and the exact synthetic file.
The server has been stopped. This establishes one actual provider path, not every
provider or file-security failure case. Screenshots show synthetic, nonoperational data.
