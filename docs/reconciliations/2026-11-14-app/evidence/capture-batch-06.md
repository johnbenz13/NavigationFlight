# Capture batch 06 — continuity and adaptations

[Current chapter](../current/continuity-and-adaptations.md) · [Manifest](batch-06/captures.json)

Captured/inspected 2026-11-14, baseline `1a2d7e7`, iPad Pro 11-inch (M5), iOS 27.0
(24A434), portrait 834 × 1210. Fifteen full images/hierarchies/logs are retained with
checksums and [exact plan bytes](batch-06/fixtures.json). Each manifest record gives
the launch environment; largest-text runs also use
`-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityXXXL`.

| Captures | Stories | Evidence |
| --- | --- | --- |
| 01–02 | S39 | Recovered active Flight through tab roundtrip. |
| 03–05 | S40 | Home for five seconds, foreground, settled wait, failed hierarchy-target tap. |
| 06–07 | S41 | Fresh Flight IP callout and reach result. |
| 08–12 | S42 | ETA draft/dismiss/reopen, heading draft/cancel. |
| 13 | S43 | Settings placeholder. |
| 14–15 | S44 | Accessibility XXXL inspection and ready Cockpit. |

Capture names are historical shorthand: 08's “check-available” does not mean Check was
shown, and 09's “editor” is actually the dismissed operational state. Stories use the
inspected image, not its filename, to describe behavior. The IP branch is a fresh run,
not recovery of the missing foreground annotations. UI tool hit coordinates differed
from the rendered IP label; a visible-coordinate fallback opened the fresh callout.

Foreground observations are simulator-specific. No full accessibility audit, spoken
VoiceOver, Reduce Motion, real sensor, or timing-internals verification is claimed.
No source/test changes or test suites were used.
