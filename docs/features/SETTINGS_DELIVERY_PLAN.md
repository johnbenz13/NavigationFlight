# Settings — Delivery Agreement

Readiness update, 2026-11-21: John approved the existing Cockpit warning geometry
with “Checklist changes could not be saved. Navigation remains available. After
restarting, the checklist may return to its last saved state.” He authorized #161
implementation and marking it `ready-for-agent`; see
[the recorded decision](https://github.com/johnbenz13/NavigationFlight/issues/161#issuecomment-7052413098).
This supersedes the earlier S1 warning-treatment and implementation-approval gates
preserved below. It does not approve implementation acceptance or other slices.

Status: breakdown and GitHub publication approved by John, 2026-11-21 (“I approve”).
All four implementation contracts are published and read back. Product, Iteration 01
direction, Iteration 02 design, and technical design are approved. Implementation
is not approved; the Cockpit warning-treatment gate remains.

Authorities: [product](SETTINGS_SPEC.md), [design review and retained images](SETTINGS_DESIGN_REVIEW.md),
[technical design](../technical/SETTINGS_TECHNICAL.md). Baseline inspected:
`3c59aa835aeff27c558c7279ea649faa5c2439c0`.

## Approved breakdown and published relationships

| Draft | Outcome | GitHub action after approval | Genuine blockers |
| --- | --- | --- | --- |
| S1 | Choose either bundled checklist or No checklist; persist it and preserve started-leg/recovered state | Updated [#161](https://github.com/johnbenz13/NavigationFlight/issues/161) | Approved Cockpit persistence-warning treatment (published baseline resolved) |
| S2 | Save a drift-line default for new/restarted Flights, retaining current-Flight override | [#190](https://github.com/johnbenz13/NavigationFlight/issues/190) | S1’s shared preference composition, storage and recording context |
| S3 | Save Automatic/Manual progression for new/restarted Flights and recover it correctly | [#191](https://github.com/johnbenz13/NavigationFlight/issues/191) | S1’s shared preference composition, storage and recording context |
| S4 | Choose 1/2/5/10-minute recovery for new recordings | [#192](https://github.com/johnbenz13/NavigationFlight/issues/192) | S1’s shared preference composition and storage |

Published parent: [#189 · Settings](https://github.com/johnbenz13/NavigationFlight/issues/189).
Issue #161 had no existing parent (GitHub returned 404 for its parent endpoint),
so it was attached to #189 with its original reconciliation trace preserved.
The three new issues are also native children of #189, each natively blocked by
#161. Bodies, labels, parents and blocking edges were read back and verified.

S2, S3 and S4 have no dependencies on one another. They can be reviewed independently
once S1 lands; landing order alone is not a blocker. No separate schema-only,
all-UI, or all-tests ticket is proposed. Each ticket includes its storage, consumer
integration, compatibility, and tests. Overall acceptance is audited in the parent,
not deferred to a catch-all testing ticket.

## Shared ticket contract

The sections below preserve the approved source contracts published into the
issues above. Each issue includes this shared contract and its scoped behavior.
The parent preserves the full approved product and technical contracts while
the immutable repository baseline is now published at `9d2628a5cf1db9a551f1852271f2b48f33747efd`.

- Link product requirements, exact approved Figma nodes and the technical design.
  Replace local links with published immutable repository permalinks before marking
  any ticket ready. Figma file: `HludOIJu7Ko46X4pmkGvTx`.
- Review baseline: iPad Pro 11-inch portrait; iPad landscape and iPhone 16 Pro
  portrait; compact portrait, Larger Text, dark, VoiceOver and resizing branches.
  No iPhone landscape or new localization. Native system shell geometry retains
  its established platform rule.
- Reuse Apple iOS/iPadOS 27 Row and Switch instances, imported semantic backgrounds,
  labels and SF Pro text styles from the approved Settings frames. Implement native
  SwiftUI equivalents; do not add a custom visual framework or raster UI.
- Use isolated existing FPLNav fixtures, explicit clocks, and debug-only temporary
  settings/recording directories. Existing launch helpers live in
  `NavigationFlightUITests/NavigationFlightUITests.swift`; do not depend on personal
  device preferences or recordings. Extend fixtures only for required states.
- Every implementation ticket must run focused Swift Testing suites, Xcode build,
  affected simulator interactions and exact Figma comparison, and `git diff --check`.
  These are future implementation requirements, not checks run during planning.
- Acceptance checkboxes stay unchecked until their evidence passes. Human visual
  judgment remains unchecked until John explicitly accepts the implementation.
  Post criterion-to-evidence mapping on GitHub before claiming completion.
- Implementation approval: **not granted**. No commit, push, PR, merge or closure
  authorization follows from ticket specification or readiness.

## S1 — Choose a bundled start checklist or No checklist

Destination: update [#161](https://github.com/johnbenz13/NavigationFlight/issues/161).
Proposed title: **Choose a start checklist or No checklist in device Settings**.
Preserve its G16 reconciliation traceability, prior owner decisions, and existing
checklist rendering authority.

**Outcome and scope.** Pilots can select **צא כיוון**, **Establish Heading**, or
**No checklist** and see it take effect on subsequent explicit or automatic leg
starts. Establish the reusable typed preference ownership and independent device
storage, but expose only this completed behavior in the first slice. Do not show
placeholder rows or empty future groups. Initial default is **צא כיוון**. Exclude
custom editing and the other three settings’ user-facing integrations.

**Requirements.** SET-01–08, SET-12–17 as applicable to this setting; SET-09–11 remain
for later slices. No checklist is explicit captured absence, never a fabricated
Noted acknowledgement. Active checklist choice/content and state do not change
when the device default changes. Dynamic values continue resolving from the leg.

**Technical contract.** Proposed `AppPreferences`, `PreferenceChange`,
`SettingsStore`, `DiskSettingsStore`, and app-owned `SettingsController` follow the
approved technical document. Stable checklist IDs are `tze-kivun-gamad`,
`establish-heading-cruise-check`, and `none`. Retain existing value-type Cockpit
state; pass narrow captured inputs rather than reading storage from render code.
Wire both explicit starts and automatic successor transitions. Include template
identity/definition revision in committed leg context; undo restores the original
choice and state, including absence.

This slice introduces the schema-3 recording-context envelope and readers while
keeping historical defaults for settings not yet exposed. Define the complete
typed envelope needed by the approved feature; do not migrate every consumer
prematurely. Subsequent additive fields/events must follow that schema contract;
if older schema-3 readers cannot safely interpret an extension, version the format
again rather than silently claiming compatibility. Preserve schema 1/2 readers.
Recovery restores durable checklist state, with SET-16 legacy fallback. Presentation
write failure cannot block navigation; memory can retain an unsaved presentation
choice, but recovery must not invent its persistence.

**Design inventory.**

| Region/state | Exact target / reuse | Reproduction |
| --- | --- | --- |
| Settings entry/group/current value | [3:628](https://www.figma.com/design/HludOIJu7Ko46X4pmkGvTx?node-id=3-628), relevant checklist row; other not-yet-delivered rows omitted | Launch isolated library with and without a loaded Flight; open Settings |
| Three choices/current/default | [7:42](https://www.figma.com/design/HludOIJu7Ko46X4pmkGvTx?node-id=7-42), [7:127](https://www.figma.com/design/HludOIJu7Ko46X4pmkGvTx?node-id=7-127), [7:204](https://www.figma.com/design/HludOIJu7Ko46X4pmkGvTx?node-id=7-204) | Open selector; select each option; Back without selecting |
| Save failure/retained value/retry | [7:845](https://www.figma.com/design/HludOIJu7Ko46X4pmkGvTx?node-id=7-845) | Fail one save from Hebrew to No checklist; retry successfully and separately dismiss |
| Adaptive and accessible controls | [7:435](https://www.figma.com/design/HludOIJu7Ko46X4pmkGvTx?node-id=7-435), [8:381](https://www.figma.com/design/HludOIJu7Ko46X4pmkGvTx?node-id=8-381), [7:657](https://www.figma.com/design/HludOIJu7Ko46X4pmkGvTx?node-id=7-657), [7:1007](https://www.figma.com/design/HludOIJu7Ko46X4pmkGvTx?node-id=7-1007) | Rotate iPad; use iPhone portrait, Larger Text and VoiceOver |
| Cockpit checklist rendering/absence | Existing [198:250](https://www.figma.com/design/yvLXb8bUFBiZHqsag4hq6I?node-id=198-250), plus approved SET-08 omission rule | Start eligible leg using each template; No checklist omits only checklist UI; unrelated disclosures remain |
| Cockpit presentation-write failure warning | **Blocked:** existing warning geometry with accurate copy needs approval | Inject failed presentation journal write; track data remains intact |

**Acceptance and test contract.**

- [ ] Grouped Settings exposes all three exclusive choices with the documented
  default; selecting saves and returns; Back does not change the choice.
- [ ] Preference survives relaunch; malformed/missing/unknown values independently
  fall back; failed create/replace leaves prior saved/effective value intact;
  Retry, Dismiss, rapid choices and unrelated queued changes behave correctly.
- [ ] Explicit and automatic starts capture each choice once. Re-render and device
  preference edits never replace active checklist state; No checklist stays absent.
- [ ] Undo restores captured state exactly. Durable state recovers after relaunch;
  legacy fixtures use historical fallback without invented acknowledgements;
  mismatched/corrupt required schema-3 context follows the corrupt recovery route.
- [ ] Presentation failure leaves navigation available and exposes only approved,
  accurate recording-warning treatment; no false durable acknowledgement.
- [ ] Parameterized store/controller tests, Cockpit transition/adapter tests,
  recording/recovery round-trips and isolated relaunch/failure UI tests pass.
- [ ] Build and simulator evidence cover the design inventory, including both
  templates, No checklist, Larger Text, VoiceOver, dark and affected orientations.
  Human presentation acceptance is recorded separately.

**Delivery docs.** Update checklist selection/capture/recovery descriptions and
storage-format compatibility, preserving original delivery history. Record real
schema decisions and extension steps. Do not mark other settings delivered.

**Blocker.** Cockpit warning-copy/design decision. Published paired baseline resolved.
Label stays `needs-info` until external blockers clear; do not retain the obsolete
claim that the Settings selector itself lacks approval.

## S2 — Save the default drift-line visibility

**Outcome.** A pilot saves whether new/restarted Flights initially show drift lines.
The existing cockpit toggle remains a current-Flight override and never writes the
device default. Requirements SET-01–02, SET-04–07, SET-09, SET-12–17.

**Technical contract.** Reuse S1’s store/controller/bootstrap. Add the typed Boolean
change and Settings Toggle; default true. `AppFeatureState` builds load/restart
candidates from the latest saved snapshot instead of unconditional true. Confirmation
preserves the candidate snapshot and the prior Flight. Recover captured visibility
through recording context; legacy visibility defaults true regardless of today’s
device setting. Failed presentation persistence uses the approved S1 warning path.

**Design inventory.** Toggle on and timing text: [3:628](https://www.figma.com/design/HludOIJu7Ko46X4pmkGvTx?node-id=3-628).
Off/dark: [7:734](https://www.figma.com/design/HludOIJu7Ko46X4pmkGvTx?node-id=7-734).
Adaptive/Larger Text: [7:435](https://www.figma.com/design/HludOIJu7Ko46X4pmkGvTx?node-id=7-435),
[8:381](https://www.figma.com/design/HludOIJu7Ko46X4pmkGvTx?node-id=8-381),
[7:1007](https://www.figma.com/design/HludOIJu7Ko46X4pmkGvTx?node-id=7-1007).
Settings save failure reuses [7:845](https://www.figma.com/design/HludOIJu7Ko46X4pmkGvTx?node-id=7-845)
with the affected setting/value substituted. Cockpit keeps its existing drift
overlay/toggle pattern; geometry and imported drift angle do not change.

**Reproduction.** Load a fixture with a nonzero imported drift angle, toggle cockpit
visibility, change the device default in Settings, return to the same Flight, then
load/restart and separately interrupt/recover it. Repeat On/Off, failure and relaunch.

**Acceptance and tests.**

- [ ] On/Off persist with default On, exclusive saved-value presentation and
  failure/retry behavior inherited from S1; other saved settings are untouched.
- [ ] Existing Flight visibility stays unchanged after a Settings edit. Its cockpit
  toggle does not change the default; newly loaded/restarted Flights use that default.
- [ ] Recovery restores durable override visibility; legacy state uses historical
  On. Undo preserves the original Flight’s presentation without changing route,
  geometry, timing or pilot-authored navigation values.
- [ ] Store tests, AppFeatureState/candidate tests, Cockpit/recording round-trips,
  and isolated simulator transitions pass; cited visual/device evidence and human
  presentation acceptance are recorded.

**Blocker.** S1. **Docs:** explicitly supersede the unconditional new-Flight On rule
with the saved default, preserve current-Flight override semantics. Implementation
approval remains not granted.

## S3 — Choose Automatic or Manual progression for new Flights

**Outcome.** Save a general progression default without changing a Flight already
loaded. Requirements SET-01–02, SET-04–07, SET-10, SET-12–17. No per-Flight selector.

**Technical contract.** Reuse S1’s storage/ownership and typed `Flight.ProgressionPolicy`
conversion. New/restarted candidates use current saved policy; confirmation never
rewrites the old Flight. Recording captures immutable policy before any arrivals;
replay constructs the Flight with it before processing the journal. This closes the
inspected automatic-default recovery gap. Do not change pilot reporting authority,
map handoff, final-leg behavior, timestamps or recording windows. Legacy missing
policy stays Automatic, independent of device defaults.

**Design inventory.** Choices/help: [7:281](https://www.figma.com/design/HludOIJu7Ko46X4pmkGvTx?node-id=7-281).
Saved Automatic: [3:628](https://www.figma.com/design/HludOIJu7Ko46X4pmkGvTx?node-id=3-628);
saved Manual/dark: [7:734](https://www.figma.com/design/HludOIJu7Ko46X4pmkGvTx?node-id=7-734).
Use shared adaptive, Larger Text and failure targets from S1 with setting-specific
text. Success/Back reuse the approved native selector-to-main pattern; no new modal.

**Reproduction.** Use the same multi-leg fixture at a fixed arrival timestamp under
both policies, change preference during a loaded Flight, and separately load/restart
and interrupt/recover a Manual Flight. Exercise arrival undo and final completion.

**Acceptance and tests.**

- [ ] Both choices persist, default Automatic, with correct retained-value failure,
  retry/dismiss and relaunch behavior; existing Flight policy never changes.
- [ ] New/restarted Flights use the saved value. Automatic successor starts at
  arrival; Manual successor stays ready until Start Leg. Final leg does not invent
  a successor. Arrival/map/undo/checklist behavior remains consistent in both modes.
- [ ] Manual Flight replay remains Manual despite changed device defaults;
  legacy missing policy remains Automatic; corrupt required policy is not guessed.
- [ ] Parameterized AppFeatureState/Flight, journal/recovery and cross-setting
  checklist tests pass, with isolated simulator evidence for both policies, Back,
  relaunch, iPad/iPhone and Larger Text. Human visual acceptance remains separate.

**Blocker.** S1. **Docs:** promote the historical general preference into delivered
behavior while preserving the as-is spec’s history and excluding a per-Flight
override. Implementation approval remains not granted.

## S4 — Choose the recovery window for new recordings

**Outcome.** Choose a bounded 1/2/5/10-minute window for new recordings without
changing an existing recording’s eligibility. Requirements SET-01–02, SET-04–07,
SET-11–17. Default five minutes; never unlimited or recording disabled.

**Technical contract.** Reuse S1’s typed settings/store/controller. Read the saved
duration at actual promotion, not when merely arming: explicit Start Leg, automatic
takeoff, partial-start, and fallback engine creation all receive a narrow captured
value. Continuing/recovering a recording retains its captured duration. Settings
edits neither append Flight activity nor refresh durable liveness. Preserve expiry,
fail-closed behavior, journal timestamps, segment handling and detector thresholds.

**Design inventory.** Four choices: [7:335](https://www.figma.com/design/HludOIJu7Ko46X4pmkGvTx?node-id=7-335).
Recording & Recovery group and default: [3:628](https://www.figma.com/design/HludOIJu7Ko46X4pmkGvTx?node-id=3-628).
One-minute selection/dark: [7:734](https://www.figma.com/design/HludOIJu7Ko46X4pmkGvTx?node-id=7-734).
Ten-minute/Larger Text: [7:1007](https://www.figma.com/design/HludOIJu7Ko46X4pmkGvTx?node-id=7-1007).
Reuse adaptive and failure patterns from S1 with setting-specific values; existing
recovery gate presentation is unchanged.

**Reproduction.** In isolated recording fixtures, choose each duration, arm a Flight,
change preference before promotion, create via each promotion path, edit preference
again, and relaunch at explicit times just before, at and after the captured deadline.

**Acceptance and tests.**

- [ ] Exactly four choices persist with five-minute default and shared save-failure,
  retry/dismiss/relaunch behavior, without resetting other preferences.
- [ ] All promotion paths capture the then-saved duration, including changes after
  arming. Existing recordings never gain a new deadline from Settings edits.
- [ ] Countdown/continuation/expiration use the captured duration and prior durable
  evidence. Legacy missing duration uses 300 seconds; unlimited or malformed values
  are never accepted. No change to physical detection or recording-disable behavior.
- [ ] Deterministic engine/coordinator/store/recovery tests cover every duration
  and clock boundary; isolated simulator evidence covers Settings, countdown,
  expiry and affected layouts/accessibility. Build and visual acceptance are recorded.

**Blocker.** S1. **Docs:** activate the existing future bounded-choice contract and
retain historical defaults/compatibility descriptions. Implementation approval
remains not granted.

## Coverage audit for the parent

| Requirement | Owning slices | Design | Required evidence |
| --- | --- | --- | --- |
| SET-01–02, SET-05–07, SET-12–13, SET-15 | S1 foundation; each later slice completes its rows | Approved main/adaptations, selectors, failure and Larger Text in each ticket | Independent persistence, failure, navigation/relaunch and rendered device evidence |
| SET-03, SET-08, checklist parts of SET-14/16 | S1 / #161 | Checklist choices, existing rendering and omission rule | Starts, absent state, undo, definition identity, durable/legacy replay |
| SET-09, visibility parts of SET-14/16 | S2 | Toggle On/Off and current-Flight overlay reuse | Capture, override separation and recovery |
| SET-10, policy parts of SET-14/16 | S3 | Progression selector and saved values | Both policies, candidate timing, arrival/undo/final leg, replay |
| SET-11, recovery-window parts of SET-14/16 | S4 | Duration choices and existing recovery gate reuse | Every promotion path, clock boundaries and immutable deadlines |
| SET-04, SET-17 | S1 convention; S2–S4 demonstrate extension | Established groups, no empty/placeholder categories | Technical review plus unchanged unrelated saved-value tests |

No approved requirement is deferred to an unowned future issue. The parent’s final
acceptance requires all four slices plus a criterion-to-evidence audit. Human visual
criteria stay open until implementation acceptance. Issue closure follows merged PRs
under repository policy, not planning approval.

## Publication/readiness gates

1. **Done:** John approved slice sizes, S1 dependencies, #161 reuse and GitHub publication.
2. Approve Cockpit presentation-failure warning copy/design. Recommended direction:
   retain existing recording warning geometry, but use accurate cause-specific copy
   that says saved checklist/display state may be incomplete; do not say GPS track
   data was lost when it was not. This recommendation is not an approval.
3. **Done:** John authorized commit/push/PR/merge on 2026-11-21; the approved
   artifact checkpoint `9d2628a5cf1db9a551f1852271f2b48f33747efd` is pushed and its product
   permalink is recorded in both Figma indexes.
4. **Done:** published #189 and #190–192, updated #161, and verified native
   child and blocker relationships.
5. **Done:** read back bodies, labels and relationships; real issue IDs recorded.
   Use `needs-info` while external gates remain; `ready-for-agent` only when its
   contracts and actual blockers are resolved. Readiness still does not authorize code.

Publication completed on 2026-11-21: created #189, #190, #191 and #192; updated
#161; verified exact published body text, enhancement/needs-info labels, native
parents and native blocking edges. No issue is marked ready-for-agent or closed.
The issue publication approval is separate from implementation acceptance.

No application code, builds, tests or simulator runs were performed. Local links
and staged/unstaged whitespace checks passed. Planning remains partial until the Cockpit warning-treatment gate is resolved.
John subsequently authorized commit, push, PR creation and merge on 2026-11-21.
Published checkpoint: [`9d2628a`](https://github.com/johnbenz13/NavigationFlight/blob/9d2628a5cf1db9a551f1852271f2b48f33747efd/docs/features/SETTINGS_SPEC.md).
The PR publication and merge record is available in Git history and the linked tracker.
