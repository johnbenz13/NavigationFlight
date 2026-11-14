# Capture batch 04 — Position Check

[Current chapter](../current/position-check.md) · [Manifest](batch-04/captures.json)

Captured/inspected 2026-11-14, baseline `1a2d7e7`, iPad Pro 11-inch (M5), iOS 27.0
(24A434), portrait 834 × 1210 points. Seven full screenshots, hierarchies and logs
are retained with checksums. [Exact fixture bytes](batch-04/fixtures.json) reconstruct
encoded plan inputs. Existing location scenarios supply recovery-available, acquiring
and permission-required states; no real GPS or permission manipulation was used.

| Captures | Stories | Evidence |
| --- | --- | --- |
| 01 | S26 | Education including recording disclosure. |
| 02–04 | S27 | Tap hint, 1.2-second hold, visible disclosure, tap to end. |
| 05–06 | S28 | Acquiring, then timeout after eleven-second observation interval. |
| 07 | S29 | Settings launch transition only. |

The manifest records exact launch environments. No duration override was supplied in
these runs. Camera restoration is not certified from the immediate post-cancel frame;
the route is visibly compressed and may be mid-transition. The Settings capture is
explicitly retained as incomplete evidence rather than silently discarded.
No test suite ran; runtime installation/build supported interaction. Source and designs
were not changed. Additional location outcomes and real sensor behavior remain unverified.
