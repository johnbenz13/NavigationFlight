# Owner review and decision queue

[Back to the visual map](README.md)

**Recorded decision:** On 2026-11-14 John accepted Q1's recommendation: approve the
representative chapter's account/format and expand the map, keeping fixes pending.
That approval covers S01–S09 as an account, not the proposed behavior or implementation.

**Latest owner decision, 2026-11-14:** John has read all current stories and approves
the account S01–S56. He has also read all gaps and recommendations, and will decide
each gap only after reviewing the whole product. Reading a recommendation does not
approve it. Finish remaining exploration before opening those decision rounds.

## Remaining product exploration

The first pass visited every major journey family, but did not exhaust the meaningful
user-facing branches. The earlier phrase “app-wide observation pass complete” described
that broad pass, not completion of whole-product exploration. The following table records the requested follow-up scope. The live
[observation ledger](evidence/remaining-exploration.md) distinguishes completed branches
from explicit verification limits. The reachable follow-up pass is complete through S93;
S57–S93 still require account review. No outstanding row is silently counted as passed.

| Area | Follow-up scope | Evidence reference |
| --- | --- | --- |
| Flight Plans | Multiple-plan ordering; loaded-version badges after replacement; loading a different plan with protected work; preserving drafts/checklists on cancellation; save failure over existing data; real Files import. | E02 |
| Navigation | Starting-leg selection; reverting committed heading/ETA; rejecting an ETA behind elapsed time; expired/invalidated/duplicate Undo; map focus and VOR label movement. Manual handoff is a debug-only branch, not an assumed release feature. | E03 |
| Position Check | On-track, position-only, no-intercept and extreme-displacement guidance; ending disclosure on tab/background changes; permission loss/recovery; retry after acquisition failure. Natural expiry and synthetic signal loss are already observed. | E04 |
| Recordings and recovery | Action-only start-to-close; actual checkpoint relaunch; recovery expiry and stale Continue; selecting one of several candidates; retry after failed closure/export/deletion; inspecting the exported GPX. | E05 |
| Device and interaction variants | Representative active flows on the canonical iPhone and iPad landscape; a real-chart route; VoiceOver, Reduce Motion and resizing where supported. Existing largest-text observations are partial. | Shared planning configuration |

Complete reachable states using disposable data and existing runtime hooks. Distinguish
any environmental blocker from absent capability. Hardware sensor accuracy, real
landing/takeoff, extended background/lock durability, physical storage exhaustion and
exhaustive timing boundaries are deeper validation work: retain their limits explicitly,
without suggesting that screenshots establish those guarantees. If an important
user-visible state requires those conditions, seek a supported fixture first and mark
it unobserved if it cannot be reached faithfully.

The correction and product-choice queues below remain parked while John reviews the
expanded account and its explicit evidence limits. Completion of this observation pass
does not approve any recommendation.

## First: agree the correction outcomes

These recommendations retain existing capabilities and address observed discrepancies.
Each linked proposal includes current evidence, intended behavior and design limits.

| Priority group | Findings | Recommended outcome | Status |
| --- | --- | --- | --- |
| Keep navigation context usable | [G01](proposed/flight-plans-to-cockpit.md), [G14](proposed/continuity-and-adaptations.md), [G18](proposed/position-check.md), [G21](proposed/starting-and-correcting.md#g21--restore-a-usable-map-after-final-reach-undo) | Restore unobscured route information after inspection; restore visible annotations after foreground; restore map framing after Position Check cancel/loss and final reach Undo. | Pending owner decision. |
| Honor the ready selection | [G20](proposed/starting-and-correcting.md#g20--start-the-leg-the-pilot-selected) | Start the selected leg and calculation mode consistently across Cockpit and recording. | Pending owner decision. |
| Retry deliberate Position Check | [G22](proposed/position-check.md#g22--allow-a-new-acquisition-attempt-after-timeout) | Restart bounded acquisition after timeout and align the offered gesture. | Pending owner decision. |
| Preserve completed timing context | [G23](proposed/completed-history.md#g23--show-revised-and-requested-reference-timing-in-completed-history) | Show revised/reference values and name each comparison baseline. | Pending; full timing-history design unverified. |
| Make reach correction available | [G15](proposed/continuity-and-adaptations.md#g15--make-ip-reach-correction-discoverable) | Expose the approved twenty-second IP Undo; preserve working destination Undo. | Pending owner decision. |
| Make recording actions/results trustworthy | [G10–G13](proposed/flights-and-recovery.md), [G19](proposed/flights-and-recovery.md#g19--describe-recording-closure-truthfully) | Remove deleted rows, honor recovery destinations, confirm End All, identify candidates, and describe actual closure state. | Pending; some paired states still need design. |
| Preserve active phone route context | [G24](proposed/phone-context.md#g24--retain-active-leg-identity-and-map-tools-on-the-phone) | Retain active-leg identity and Map tools through Start/disclosure. | Pending; canonical16Pro unavailable. |
| Make operational information consistent/readable | [G03](proposed/flight-plans-to-cockpit.md), [G07–G08](proposed/fly-and-revise.md), [G17](proposed/continuity-and-adaptations.md) | Preserve readable labels, agree one frequency sequence, distinguish completed navigation from not started, and complete large-text layouts. | Pending; exact state/layout decisions remain. |

Recommendation: prioritize navigation restoration, IP correction and recording action
clarity before optional capability expansion. Preserve historical screenshots when fixes
are eventually observed. A product outcome may be agreed here without approving its
design, ticket publication or code implementation.

## Then: resolve competing intent and unfinished capability

| Decision | Recommendation | Other explicit choices | Prerequisite/limit |
| --- | --- | --- | --- |
| [G02 · Loaded-plan review](proposed/flight-plans-to-cockpit.md#g02--review-the-loaded-plan-consistently) | Integrate canonical review with the useful detailed planning information. | Preserve both deliberately, defer integration, or retire one after accounting for its capabilities. | Paired integration design required. |
| [G05 · Cockpit app navigation](proposed/navigation-and-frequency-authority.md#g05--choose-how-app-sections-coexist-with-cockpit) | Prefer Flying's App Sections cockpit direction if still intended, and explicitly reconcile native navigation requirements. | Preserve adaptive native tabs and revise Flying; defer shell change with a named authority decision. | Two approved contracts conflict; neither wins by date alone. |
| [G06 · Frequency hierarchy](proposed/navigation-and-frequency-authority.md#g06--distinguish-planned-frequencies-from-receiver-state) | Compact planned now/next plus full disclosure; planning disclaimer without unsupported tuned-state claims. | Preserve the full inline list and revise Flying; defer hierarchy while correcting misleading wording. | Align paired contracts and the same-state sequence from G07. |
| [G09 · Chart layers](proposed/fly-and-revise.md#g09--make-chart-tools-an-explicit-product-choice) | Deliberately defer the unfinished picker and make availability clear until a complete design exists. | Plan/design it now, explicitly preserve the temporary placeholder, or retire the capability by contract decision. | No complete authoritative picker found. |
| [G16 · Checklist selection](proposed/continuity-and-adaptations.md#g16--choose-a-bundled-start-checklist) | Retain bundled selection intent and complete its Settings design before delivery. | Defer with an explicit fixed default, preserve the placeholder temporarily, or retire selection. | Checklist rendering is designed; Settings selector is not verified. |
| [G04 · Supersession and acceptance trace](proposed/flight-plans-to-cockpit.md#g04--understand-which-navigation-contract-is-current) | Add approved supersession pointers and resolve ambiguous tracker acceptance records, preserving history. | Defer with this reconciliation as the temporary authority guide. | Contract/tracker edits require separate approval; no silent archival. |

## Retained verification work

[E01](proposed/flight-plans-to-cockpit.md#e01--finish-observing-import-and-state-preservation-branches)
is narrowed by the expanded map. [E02](proposed/manage-flight-plans.md),
[E03](proposed/fly-and-revise.md#e03--cover-remaining-navigation-branches),
[E04](proposed/position-check.md#e04--verify-the-full-disclosure-boundary), and
[E05](proposed/flights-and-recovery.md#e05--verify-lifecycle-and-durable-recovery-beyond-seeded-presentations)
retain specific unobserved branches. Missing evidence does not authorize invented
behavior or prove absent capability. The follow-up now includes real-provider import,
real-chart rendering, actual disk-checkpoint relaunch, active landscape and system
accessibility-setting observations. The ledger retains the precise unverified remainder.

All groups are pending. No remediation tickets, Figma writes, contract changes or
application fixes have been authorized by this map review. New design work, if approved,
will use one dedicated reconciliation file in the configured Figma project. Ticket
preparation/publication follows only after the relevant behavior and design decisions.
