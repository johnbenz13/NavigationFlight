# Capture batch 10 — map controls, revision and Undo

[Manifest](batch-10/captures.json) · [Fixture hashes](batch-10/fixtures.json)

Eleven captures inspected on 2026-11-14 at `1a2d7e7`, iPad Pro 11-inch (M5),
iOS 27.0 (24A434), portrait 834 × 1210. [Stories S62–S65](../current/starting-and-correcting.md#s62--move-a-vor-label-and-restore-whole-leg-framing).

| Captures | Story | Evidence |
| --- | --- | --- |
| 01–05 | S62 | Hitpoint drag pans map; grip fallback moves label; destination/whole-leg focus attempts. |
| 06–08 | S63 | Baseline-valued committed ETA, dismissal and reopened editor. |
| 09 | S64 | Successor heading commit invalidates earlier Undo at elapsed 00:03. |
| 10–11 | S65 | Final Undo restores active leg; collapsed route; duplicate Undo-location tap. |

[Intermediate destination-focus capture03](../assets/current/batch-10/03-focus-destination.png)
is retained alongside the settled attempt. Capture06's filename says 45, but the
actual value is 40: the attempted step hit a stale position. Use inspected pixels and
the action record, not filenames, as evidence. Full captions retain those limitations.

No source changes, tests or external writes occurred. Marker collapse needs settled
follow-up before being treated as more than a transient frame; the next batch supplies it.
