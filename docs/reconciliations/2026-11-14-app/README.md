# NavigationFlight product reconciliation

**Baseline:** local `main`, `1a2d7e7596667a39616fe3812f6a07326f30ca00`, agreed with John on 2026-11-14.
**Working branch:** `reconcile/2026-11-14-app`.
**Status:** John approved the current account S01–S56 on 2026-11-14 and has read all
G01–G19 findings and recommendations. Each gap decision remains pending until the
whole-product review is finished. The reachable follow-up exploration is now complete:
93 stories, 24 gap proposals, and explicit partial/unverified limits in the
[exploration checklist](evidence/remaining-exploration.md). S57–S93 await account review;
no gap recommendation has been approved.

This map explains what a pilot can do in the running app, compares those observations
with approved intent, and keeps decisions about changes separate from observations.
Use [shared setup](../../architecture/planning-configuration.md) for platforms,
authority, destinations, and permissions.

## Story tree and coverage

### Choose a Flight Plan and enter Cockpit — first chapter

Start with the [current visual chapter](current/flight-plans-to-cockpit.md), then
[its proposed reconciliation](proposed/flight-plans-to-cockpit.md). Eleven inspected
app captures cover nine stories; six inspected Figma previews support the comparison.

- [S01 · Open an empty library](current/flight-plans-to-cockpit.md#s01--open-an-empty-flight-plans-library)
  - [S02 · Open Add's file picker](current/flight-plans-to-cockpit.md#s02--open-the-file-picker); settled cancellation and fixture-driven import are covered in S10–S11; real-provider import follows in S75.
- [S03 · Choose a saved Flight Plan](current/flight-plans-to-cockpit.md#s03--choose-a-saved-flight-plan)
  - [S04 · Review before loading](current/flight-plans-to-cockpit.md#s04--review-a-plan-before-loading)
  - [S05 · Load a ready Flight](current/flight-plans-to-cockpit.md#s05--load-a-ready-flight)
  - [S06 · Rotate or use a phone](current/flight-plans-to-cockpit.md#s06--use-the-ready-cockpit-in-landscape-or-on-a-phone)
- [S07 · Inspect through Map Tools](current/flight-plans-to-cockpit.md#s07--inspect-planning-details-from-map-tools)
  - [S08 · Return with route-strip overlap](current/flight-plans-to-cockpit.md#s08--return-from-plan-inspection)
- [S09 · Return through the retained Flight Plans review](current/flight-plans-to-cockpit.md#s09--return-through-the-flight-plans-review)
  - Continue returns to a ready Cockpit with the route strip unobscured.

John approved this chapter's account and format on 2026-11-14, accepting the recommendation
to expand the remaining journeys while retaining proposed fixes as pending decisions.
This is map approval, not acceptance of implementation or proposed behavior. Current captures use iPad Pro
11-inch (M5) portrait/landscape and iPhone 17 portrait; canonical iPhone 16 Pro,
expanded accessibility and active-flight observations follow below; broader device coverage remains unverified.

### Manage saved Flight Plans — account approved

[Current chapter](current/manage-flight-plans.md) · [Remaining evidence](proposed/manage-flight-plans.md)

- [S10 · Cancel Files](current/manage-flight-plans.md#s10--leave-files-without-adding-a-plan).
- [S11 · Save and retain a plan after relaunch](current/manage-flight-plans.md#s11--save-a-valid-plan-and-find-it-after-relaunch), using debug import input.
- [S12 · Reimport the same revision](current/manage-flight-plans.md#s12--reimport-the-same-revision).
- [S13 · Cancel newer/older replacement](current/manage-flight-plans.md#s13--review-newer-or-older-replacement-and-cancel).
- [S14 · Understand invalid-input and save failures](current/manage-flight-plans.md#s14--understand-why-a-plan-was-not-added).
- [S15 · Cancel protected restart](current/manage-flight-plans.md#s15--cancel-a-restart-that-would-discard-flight-work).
- [S16 · Remove saved copy, retain active Flight](current/manage-flight-plans.md#s16--remove-the-saved-copy-and-keep-using-the-loaded-flight).

Confirmed replacement/restart and removal failure follow in S47–S49. Library protection
and ordering follow in S66–S69; real-provider import follows in S75.
[E02](proposed/manage-flight-plans.md) records the remaining limits.

### Fly and revise navigation — account approved

[Current chapter](current/fly-and-revise.md) · [Differences and evidence](proposed/fly-and-revise.md)

- [S17 · Start and note checklist](current/fly-and-revise.md#s17--start-navigation-and-note-the-checklist).
- [S18 · Commit heading](current/fly-and-revise.md#s18--commit-a-revised-magnetic-heading) and [S19 · Commit ETA](current/fly-and-revise.md#s19--commit-a-revised-eta-and-understand-unavailable-check).
- [S20 · Consult Frequency Plan](current/fly-and-revise.md#s20--consult-the-full-frequency-plan).
- [S21 · Identify destination](current/fly-and-revise.md#s21--identify-the-destination-without-reporting-arrival), then [S22 · Reach and Undo](current/fly-and-revise.md#s22--complete-the-final-leg-and-undo-the-reach-report).
- [S23 · Toggle drift and try Chart layers](current/fly-and-revise.md#s23--toggle-drift-aids-and-try-chart-layers).
- [S24 · Preview and advance automatically](current/fly-and-revise.md#s24--preview-the-next-leg-and-progress-automatically), then [S25 · Review history](current/fly-and-revise.md#s25--review-the-previous-leg-while-the-current-timer-continues).

Remaining navigation branches are explicit in [E03](proposed/fly-and-revise.md#e03--cover-remaining-navigation-branches),
with later IP, valid reference Check, cancellation and background observations linked there.
Manual progression is observed later in S82; precise residual limits remain in the ledger.

### Request a Position Check — account approved

[Current chapter](current/position-check.md) · [Design and limits](proposed/position-check.md)

- [S26 · Read location/recording education](current/position-check.md#s26--read-the-location-explanation-before-cockpit).
- [S27 · Tap, hold, inspect and end](current/position-check.md#s27--tap-for-a-hint-hold-to-reveal-then-end-the-check).
- [S28 · Wait for acquisition and timeout](current/position-check.md#s28--wait-for-acquisition-and-understand-timeout).
- [S29 · Follow permission route to Settings](current/position-check.md#s29--follow-the-permission-required-route-to-settings), transition-only evidence.

Remaining disclosure, loss, camera, real permissions and accessibility branches are
explicit in [E04](proposed/position-check.md#e04--verify-the-full-disclosure-boundary).

### Review Flights and recovery — account approved

[Current chapter](current/flights-and-recovery.md) · [Differences and limits](proposed/flights-and-recovery.md)

- [S30 · Distinguish executions](current/flights-and-recovery.md#s30--distinguish-recorded-executions-in-flights) and [S31 · Inspect evidence](current/flights-and-recovery.md#s31--inspect-a-closed-flight-and-its-evidence-summary).
- [S32 · Open GPX sharing](current/flights-and-recovery.md#s32--prepare-gpx-and-open-the-system-share-sheet).
- [S33 · Delete and encounter a stale row](current/flights-and-recovery.md#s33--confirm-deletion-then-encounter-a-stale-row).
- [S34 · Read action-only recording](current/flights-and-recovery.md#s34--review-a-flight-without-gps-track-data).
- [S35 · Continue recovery](current/flights-and-recovery.md#s35--continue-a-recently-interrupted-flight) or [S36 · End incomplete](current/flights-and-recovery.md#s36--end-recovery-as-incomplete).
- [S37 · Resolve multiple candidates](current/flights-and-recovery.md#s37--resolve-multiple-recovery-candidates).
- [S38 · Unsupported/corrupt recovery](current/flights-and-recovery.md#s38--handle-unsupported-or-corrupt-recovery-safely).

UI recording lifecycle and injected error follow-ups appear in S50–S56. Real sensors,
durability, expiry boundaries and storage exhaustion remain explicit in [E05](proposed/flights-and-recovery.md#e05--verify-lifecycle-and-durable-recovery-beyond-seeded-presentations).

### Continuity, Settings and adaptations — account approved

[Current chapter](current/continuity-and-adaptations.md) · [Differences](proposed/continuity-and-adaptations.md)

- [S39 · Active tab roundtrip](current/continuity-and-adaptations.md#s39--visit-flight-plans-without-pausing-navigation).
- [S40 · Background return](current/continuity-and-adaptations.md#s40--return-from-background-with-timing-intact-but-labels-missing).
- [S41 · Report an IP](current/continuity-and-adaptations.md#s41--report-an-identification-point-reached).
- [S42 · Dismiss ETA and cancel heading](current/continuity-and-adaptations.md#s42--dismiss-eta-work-and-cancel-a-heading-draft).
- [S43 · Settings placeholder](current/continuity-and-adaptations.md#s43--open-settings).
- [S44 · Largest accessibility text](current/continuity-and-adaptations.md#s44--use-the-largest-accessibility-text-size).

### Follow-up branches — account approved

- Position Check: [S45 · settled cancel versus expiry](current/position-check.md#s45--compare-settled-cancellation-with-natural-expiry), [S46 · signal loss](current/position-check.md#s46--lose-gps-during-a-check).
- Library: [S47 · confirmed newer/older replacement](current/manage-flight-plans.md#s47--confirm-a-newer-revision-and-an-older-rollback), [S48 · removal cancel/failure](current/manage-flight-plans.md#s48--cancel-removal-and-understand-an-injected-removal-failure), [S49 · confirmed restart](current/manage-flight-plans.md#s49--confirm-a-protected-restart).

### Recording lifecycle and final branches — account approved

[Current chapter](current/recording-lifecycle.md) · [Closure discrepancy](proposed/flights-and-recovery.md#g19--describe-recording-closure-truthfully)

- [S50 · Empty Flights](current/recording-lifecycle.md#s50--open-flights-before-any-recording).
- [S51 · Recording status and End cancellation](current/recording-lifecycle.md#s51--inspect-recording-status-and-keep-recording).
- [S52 · IP Undo search and successful ETA Check](current/recording-lifecycle.md#s52--search-for-ip-undo-and-check-a-committed-eta).
- [S53 · Navigation completion, End and saved result](current/recording-lifecycle.md#s53--end-after-navigation-completion-and-inspect-the-saved-flight).
- [S54 · Recording failure/degradation](current/recording-lifecycle.md#s54--understand-recording-failure-and-degradation).
- [S55 · Active recording restrictions](current/recording-lifecycle.md#s55--review-an-active-recording-without-export-or-deletion).
- [S56 · Export/delete errors](current/recording-lifecycle.md#s56--understand-export-and-deletion-failures).

This named observation pass covers 56 stories, with 113 app screenshots and 20 Figma
previews across eight capture batches. These are observations, not implementation
acceptance. At that first-pass checkpoint, provider import, durability and expanded
device coverage remained open. The follow-up below resolves specific branches while
retaining physical-sensor and broader accessibility limits.

### Remaining exploration — new observations awaiting account review

The owner requested completion of the [remaining exploration ledger](evidence/remaining-exploration.md)
before individual gap decisions. S01–S56 retain their account approval.

- [S57 · Choose starting leg, then Start](current/starting-and-correcting.md#s57--choose-a-later-starting-leg-then-start).
- [S58 · Recommit baseline heading](current/starting-and-correcting.md#s58--recommit-the-imported-heading-after-a-revision).
- [S59 · Stale ETA draft](current/starting-and-correcting.md#s59--leave-an-eta-draft-open-until-it-becomes-too-early).
- [S60 · Undo expiry](current/starting-and-correcting.md#s60--let-destination-undo-expire).
- [S61 · Active mode restriction](current/starting-and-correcting.md#s61--inspect-calculation-choices-while-a-leg-is-active).

- [S62 · VOR label and map framing](current/starting-and-correcting.md#s62--move-a-vor-label-and-restore-whole-leg-framing).
- [S63 · Reopen committed ETA](current/starting-and-correcting.md#s63--reopen-a-committed-eta-and-look-for-a-revert-action).
- [S64 · Invalidate Undo with a revision](current/starting-and-correcting.md#s64--close-the-reach-undo-window-with-a-successor-revision).
- [S65 · Final Undo and restored state](current/starting-and-correcting.md#s65--undo-final-reach-and-inspect-the-restored-leg).

- [S66 · Plan recency ordering](current/library-protection.md#s66--find-several-plans-by-import-recency).
- [S67 · Protected different-plan replacement](current/library-protection.md#s67--cancel-or-confirm-loading-a-different-plan-over-protected-work).
- [S68 · Saved versus loaded revision](current/library-protection.md#s68--save-a-newer-revision-while-retaining-the-older-loaded-snapshot).
- [S69 · Failed replacement retains saved data](current/library-protection.md#s69--fail-to-replace-a-saved-revision-and-inspect-what-remains).

- [S70 · Inspect generated GPX contents](current/export-artifact.md#s70--export-a-closed-flight-and-inspect-the-generated-track).
- [S71 · Position and guidance outcomes](current/position-check-outcomes.md#s71--distinguish-supported-position-and-guidance-outcomes).
- [S72 · Fresh disclosure exits](current/position-check-outcomes.md#s72--leave-cockpit-during-a-fresh-disclosure).
- [S73 · Retry acquisition timeout](current/position-check-outcomes.md#s73--try-again-after-acquisition-times-out).
- [S74 · Permission revoked during disclosure](current/position-check-outcomes.md#s74--lose-permission-during-an-active-disclosure).
- [S75 · Real Files import and chart](current/provider-and-calculation-mode.md#s75--add-a-plan-through-the-real-files-provider).
- [S76 · No wind selection at Start](current/provider-and-calculation-mode.md#s76--select-no-wind-then-start-without-reloading).

- [S77 · Select a recovery candidate](current/recovery-selection-and-expiry.md#s77--choose-one-recoverable-flight-and-inspect-the-others).
- [S78 · Natural recovery expiry](current/recovery-selection-and-expiry.md#s78--leave-recovery-untouched-until-its-window-expires).

- [S79 · Resume an actual disk checkpoint](current/durable-action-only-flight.md#s79--resume-a-checkpoint-created-by-actual-navigation-actions).
- [S80 · Skip an IP and inspect history](current/durable-action-only-flight.md#s80--reach-the-destination-without-reporting-an-earlier-ip).
- [S81 · Close an action-only Flight](current/durable-action-only-flight.md#s81--close-completed-navigation-with-no-gps-track).

- [S82 · Manual successor Start](current/progression-history-and-cues.md#s82--wait-for-explicit-successor-start-under-manual-progression).
- [S83 · Completed revisions and reference history](current/progression-history-and-cues.md#s83--review-a-completed-leg-with-heading-eta-and-requested-reference).
- [S84 · Operational cue transitions](current/progression-history-and-cues.md#s84--follow-altitude-and-frequency-changes-across-elapsed-time).
- [S85 · Map-control auto-hide](current/progression-history-and-cues.md#s85--reveal-map-controls-and-leave-them-untouched).

- [S86 · Repeated hold and active landscape](current/landscape-and-accessibility.md#s86--hold-again-during-a-position-check-and-rotate-while-active).
- [S87 · System Reduce Motion](current/landscape-and-accessibility.md#s87--use-position-check-with-system-reduce-motion-enabled).
- [S88 · Actual VoiceOver focus and activation attempt](current/landscape-and-accessibility.md#s88--focus-position-check-with-voiceover-enabled).

- [S89 · Bounded window-resize attempt](current/phone-and-resizing.md#s89--attempt-a-system-window-resize).
- [S90 · Available phone active workflows](current/phone-and-resizing.md#s90--start-and-use-the-available-iphone-cockpit).

[Batch19](evidence/capture-batch-19.md) records the resize limit; [batch20](evidence/capture-batch-20.md) covers iPhone17.
New finding: [G24 · Active phone route header](proposed/phone-context.md#g24--retain-active-leg-identity-and-map-tools-on-the-phone).
[Batch18](evidence/capture-batch-18.md) covers active landscape and accessibility settings.
[Batch17](evidence/capture-batch-17.md) confirms settled history and timeout retry.
[Batch16](evidence/capture-batch-16.md) covers progression, history, cues and auto-hide.
[Batch15](evidence/capture-batch-15.md) covers durable action-only recording and skipped IP.
[Batch14](evidence/capture-batch-14.md) covers recovery selection and expiry.
[Batch12](evidence/capture-batch-12.md) covers Position Check outcomes;
[batch13](evidence/capture-batch-13.md) covers real-provider import and distinct mode values.
[Batch10](evidence/capture-batch-10.md) covers map/revision/Undo follow-ups;
[batch11](evidence/capture-batch-11.md) covers library protection and settled Undo.
New findings: [G22 · Acquisition retry](proposed/position-check.md#g22--allow-a-new-acquisition-attempt-after-timeout),
[G23 · Complete timing history](proposed/completed-history.md#g23--show-revised-and-requested-reference-timing-in-completed-history).
New finding: [G21 · Map restoration after Undo](proposed/starting-and-correcting.md#g21--restore-a-usable-map-after-final-reach-undo).
New finding: [G20 · Start the selected leg](proposed/starting-and-correcting.md#g20--start-the-leg-the-pilot-selected).
[Batch09 evidence](evidence/capture-batch-09.md) preserves the new transitions.

### Final library and permission branches — awaiting account review

[S91–S92](current/final-library-and-permission-checks.md) cover updated-plan replacement
and the bounded real-permission attempt. [S93](current/repeated-recording-errors.md)
covers repeated recording errors and their verification limits.

## Designs and decisions

| Finding | Classification | Recommendation | Owner status |
| --- | --- | --- | --- |
| [G01 · Overlap after inspection return](proposed/flight-plans-to-cockpit.md#g01--return-to-cockpit-with-route-information-unobscured) | Observed presentation defect against unobscured-controls requirement | Plan a focused correction and compare both return paths. | Pending; no implementation authorization. |
| [G02 · Two loaded-plan review experiences](proposed/flight-plans-to-cockpit.md#g02--review-the-loaded-plan-consistently) | Observed contract difference; integration design incomplete/unverified | Reconcile canonical review with preserved planning capabilities. | Behavior/design decision pending. |
| [G03 · Truncated frequency and instrument labels](proposed/flight-plans-to-cockpit.md#g03--read-complete-operational-labels-and-frequencies) | Observed presentation difference; long-content policy unresolved | Plan long-content/adaptive design review. | Decision pending. |
| [G04 · Superseded navigation references](proposed/flight-plans-to-cockpit.md#g04--understand-which-navigation-contract-is-current) | Documentation/acceptance-traceability drift | Add explicit supersession pointers; preserve history. | Contract/tracker edits not approved. |
| [E01 · Incomplete import/continuity evidence](proposed/flight-plans-to-cockpit.md#e01--finish-observing-import-and-state-preservation-branches) | Missing evidence | See expanded library observations and the reduced E02 remainder. | Original account approved; follow-up observed with explicit limits. |
| [G05 · Cockpit navigation shell](proposed/navigation-and-frequency-authority.md#g05--choose-how-app-sections-coexist-with-cockpit) | Conflicting approved intent | Choose one cross-feature shell and align paired contracts. | Behavior/design decision pending. |
| [G06 · Planned-frequency hierarchy and wording](proposed/navigation-and-frequency-authority.md#g06--distinguish-planned-frequencies-from-receiver-state) | Conflicting intent and legacy wording difference | Prefer compact references/full disclosure with explicit planning disclaimer. | Behavior/contract decision pending. |
| [E02 · Remaining library branches](proposed/manage-flight-plans.md#e02--complete-the-import-and-replacement-journey) | Missing evidence | Retain the explicit provider and edge-case limits. | Original account approved; follow-up observed with explicit limits. |

Additional cockpit findings: [G07 · inconsistent frequency sequence](proposed/fly-and-revise.md#g07--read-one-consistent-planned-frequency-sequence),
[G08 · completed versus unstarted console](proposed/fly-and-revise.md#g08--keep-completed-navigation-distinct-from-not-started),
and [G09 · chart-tools scope](proposed/fly-and-revise.md#g09--make-chart-tools-an-explicit-product-choice).
Recording findings: [G10 · stale deleted row](proposed/flights-and-recovery.md#g10--remove-a-deleted-flight-from-the-visible-library),
[G11 · recovery destination](proposed/flights-and-recovery.md#g11--finish-recovery-in-the-promised-place),
[G12 · missing End All confirmation](proposed/flights-and-recovery.md#g12--confirm-ending-multiple-recoverable-flights),
and [G13 · recovery identity](proposed/flights-and-recovery.md#g13--identify-the-single-recovery-candidate-clearly).
Continuity/adaptation findings: [G14–G17](proposed/continuity-and-adaptations.md)
cover missing foreground annotations, IP Undo visibility, checklist selection and
large-text reading; [G18](proposed/position-check.md#g18--restore-the-map-after-cancellation-or-signal-loss)
covers settled Position Check map restoration. [G19](proposed/flights-and-recovery.md#g19--describe-recording-closure-truthfully)
covers misleading manual-End confirmation and stale recording-continuation wording.
All recommendations remain pending owner decisions.

**Owner review recorded:** John approved S01–S56 and read G01–G19 and their
recommendations. Review S57–S93 and the explicit evidence limits before requesting
individual gap decisions. No recommendation is approved by this account approval.

Supporting records: [capture manifest and crosswalk](evidence/capture-batch-01.md),
[authority and historical evidence](evidence/authority.md),
[library batch](evidence/capture-batch-02.md), [navigation batch](evidence/capture-batch-03.md),
[Position Check batch](evidence/capture-batch-04.md), [recordings/recovery batch](evidence/capture-batch-05.md),
[continuity batch](evidence/capture-batch-06.md), [settled follow-ups](evidence/capture-batch-07.md), [final lifecycle batch](evidence/capture-batch-08.md), and
[expanded authority/precedence](evidence/expanded-authority.md).

Existing feature designs remain in their original files. New reconciliation design file:
**not created; no design-write scope approved**. If needed, use the
[Navigation Flight Figma project](https://www.figma.com/files/folder/676737789) and reuse
one file across this effort.

Map accuracy, desired behavior, design approval, and implementation authorization are
separate decisions. S01–S56 have owner account approval; new follow-up stories await review. All gap
decisions remain pending until John finishes reviewing the expanded account.
No remediation tickets or source changes are part of this review.

## Batch verification

On 2026-11-14, local links/anchors, retained-evidence hashes, and both working-tree and
staged whitespace checks passed. The final pass retains252 app screenshots and23 Figma
previews. Runtime sessions are closed; VoiceOver and Reduce Motion restored Off.
No test suite was run for this documentation reconciliation. Application source,
feature specifications, Figma files and GitHub issues were not changed.
Reconciliation documents are uncommitted.
