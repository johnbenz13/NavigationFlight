# Capture batch 08 — recording lifecycle and final branches

[Manifest](batch-08/captures.json) · [Exact fixture hashes](batch-08/fixtures.json)

Captured and inspected on 2026-11-14 at baseline `1a2d7e7`, iPad Pro 11-inch (M5),
iOS 27.0 (24A434), portrait 834 × 1210. Nineteen images, hierarchies and logs retained.
All screenshots are embedded in [S50–S56](../current/recording-lifecycle.md).

| Captures | Story | Evidence |
| --- | --- | --- |
| 01 | S50 | Empty Flights. |
| 02–04 | S51 | Start, GPS gap/resumption status, End confirmation cancelled. |
| 05–08 | S52 | Immediate/dismissed IP without Undo; committed ETA reference Check. |
| 09–13 | S53 | Final reach, manual End, newly created saved Flight/detail. |
| 14–15 | S54 | Recording failure and track degradation injections. |
| 16–17 | S55 | Full active-record detail without export/delete. |
| 18–19 | S56 | Export/delete error presentations. |

No real landing, low-storage exhaustion, background acquisition, relaunch durability,
export bytes or retry outcome is established by these captures. A separate low-storage
status override remains unobserved. File name `11-closed-complete` was chosen before
inspection; it is preserved historically and does not describe the observed Incomplete
result. Exact environment values are retained; base64 inputs refer to hashed fixture bytes.
The observation session is closed. No source edits, test suites or external writes occurred.
