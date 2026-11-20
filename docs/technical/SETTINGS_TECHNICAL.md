# Settings — Technical Design

Status: technically approved by John on 2026-11-21 (“approved”). Product and
Iteration 02 presentation are approved. That technical approval did not authorize implementation or publication. John
subsequently approved issue publication, then separately authorized commit, push,
PR creation and merge of the planning artifacts on 2026-11-21.

Authorities: [product SET-01–17](../features/SETTINGS_SPEC.md) and
[approved design inventory](../features/SETTINGS_DESIGN_REVIEW.md).
Inspected source revision: `3c59aa835aeff27c558c7279ea649faa5c2439c0`.

## Inspected implementation and required changes

| Existing seam | Observed behavior | Proposed extension |
| --- | --- | --- |
| `RootView`, `AppFeatureState` | Root composes dependencies; app state owns value-type Cockpit state. Flight-change candidates copy the old cockpit progression policy. | Share saved preference ownership at app composition; pass a value snapshot to new-Flight creation instead of copying old policy. |
| `SettingsFeatureView` | Placeholder only. | Native grouped Form/List, typed navigation destinations, choices, Toggle, save-error state. |
| `CockpitFeatureState` | Constructor takes progression policy. `accept` and `restore` reset drift visibility; checklist entries have review/presentation/phase but no template identity. | Capture Flight defaults and per-leg checklist selection; restore captured state instead of resetting it. |
| `CockpitPresentationAdapter.makeLegStartChecklist` | Defaults every render to `.tzeKivun`; two bundled definitions exist. | Resolve the active leg’s captured identity and definition revision. No checklist returns no presentation. |
| `FlightRecordingCoordinator`, `FlightRecordingEngine` | Main-actor coordinator and actor engine commit navigation before publishing. Both explicit start and physical takeoff can create a recording. | Supply recovery preference at actual recording creation in both paths; enrich committed leg starts with checklist capture. |
| `FlightRecoveryCoordinator.replayFlight` | Reconstructs `Flight` with the constructor’s automatic default. `RecoveredFlight` contains no Cockpit settings state. | Replay with captured progression; return separately projected Cockpit settings state. |
| `FlightRecordingManifestDTO`, `FlightRecordingStore` | Manifest schema 2; schema 1/2 supported; recovery window already captured with historical 300-second fallback. | Add immutable policy metadata and versioned presentation journal data; retain legacy readers and defaults. |

`docs/architecture.md` records useful dependency rules but predates current app
sections and recording code. Use current inspected seams for this feature, without
rewriting unrelated historical architecture documentation.

## Architecture and ownership

Keep existing SwiftUI, value-state, coordinator, domain, and data-adapter structure.
Do not introduce MVVM/TCA, Combine, a global mutable singleton, or a setting registry.

- **App preferences**: a proposed `@MainActor @Observable SettingsController`,
  created once at app composition and passed to scene roots, owns the last
  successfully saved `AppPreferences`, startup readiness, serialized changes, and
  retryable errors. Scene navigation remains scene-owned. This is a proposed
  addition, not an existing type.
- **Settings presentation**: local navigation path and attempted selection belong
  to Settings. Views issue typed change commands; they cannot mutate the saved
  snapshot before persistence succeeds.
- **Flight**: progression policy remains immutable in `Flight`; new-Flight drift
  default initializes Cockpit visibility. Device-default edits never mutate either.
- **Leg**: Cockpit owns a captured checklist choice, definition revision, and review,
  presentation, and phase state per started leg. A disabled checklist is explicit
  state, not a missing dictionary entry.
- **Recording**: the engine owns its captured recovery duration and recording policy
  metadata. Domain/recording receives values, never `SettingsController`, SwiftUI,
  `UserDefaults`, or filesystem preference access.

Use `Equatable` and `Sendable` value types. Because the app uses MainActor default
isolation and Swift language mode 5, mark cross-actor DTOs/protocols `nonisolated`
as existing code does. Do not change project concurrency or language settings.

## Proposed preference interface

Names below are a proposed interface contract, not source code already delivered.

| Type | Responsibility |
| --- | --- |
| `AppPreferences` | Four typed values with explicit defaults; no display strings in storage. |
| `StartChecklistSelection` | `tzeKivun`, `establishHeading`, `none`; stable IDs mapped to existing template IDs. |
| `RecoveryWindow` | Finite cases for 60, 120, 300, 600 seconds; reject arbitrary durations. |
| `PreferenceChange` | Typed enum for changing exactly one preference; prevents unrelated-value replacement. |
| `SettingsStore` | Injected Sendable interface: `load() async -> SettingsLoadResult`, `save(_ change: PreferenceChange) async throws`. |
| `DiskSettingsStore` | Actor adapter: independent decoding, validation and atomic replacement of one preference file. |
| `SettingsController` | Publishes saved values, accepts ordered changes, and owns failed attempts/retry/dismissal. |

Production disk and isolated in-memory/fault-injecting test adapters give this seam
actual variation. Do not add protocols around pure enum conversions or every row.
Pass narrow value inputs into consumers; the map never needs the settings model.

### Storage choice and alternatives

Recommend one small file per preference under the app’s Application Support
`Settings` directory. This matches existing actor-based disk adapters and supports
a throwing save operation. For example:

| Stable key/file stem | Stored value | Missing/invalid default |
| --- | --- | --- |
| `cockpit.startChecklist` | `tze-kivun-gamad`, `establish-heading-cruise-check`, or `none` | `tze-kivun-gamad` |
| `cockpit.showDriftLines` | Boolean | `true` |
| `cockpit.progression` | `automatic` or `manual` | `automatic` |
| `recording.recoveryWindowSeconds` | 60, 120, 300, 600 | 300 |

Both template IDs above were inspected in `CockpitPresentationAdapter.swift`;
never derive a persisted ID from its translated display name.

Each file has a small versioned envelope. Decode and validate each independently;
one malformed value cannot erase the other three. Unknown files/fields are left
untouched. Missing, malformed, or unreadable individual files resolve to their
default in memory; loading never overwrites the original file. A deliberate save
can replace that preference’s invalid file. Unknown future envelope versions also
resolve without destructive rewrite during load. No automatic global reset.

Encode before replacing; use a same-directory temporary/atomic replacement and
clean up abandoned temporary files. Success means the platform write/replace
operation completed; it does not promise survival of hardware failure. A failed
replacement leaves the previous file and effective published value intact. Test
both existing-file replacement and first-file creation failures.

`UserDefaults`/`@AppStorage` is simpler for ordinary preferences, but direct setters
do not supply the throwing commit result required for this feature’s failure
contract. Do not use `synchronize()` as a durability protocol. A single JSON file
is also viable, but needs independent field decoding plus careful read-modify-write
to preserve unrelated/unknown values; separate files keep those invariants local.
No database or new dependency is justified for four preferences.

Apple references checked through Xcode DocumentationSearch on 2026-11-21:
[throwing Data write](https://developer.apple.com/documentation/foundation/data/write(to:options:)),
[atomic replacement option](https://developer.apple.com/documentation/foundation/nsdata/writingoptions/atomic),
and [UserDefaults.synchronize guidance](https://developer.apple.com/documentation/foundation/userdefaults/synchronize()).

### Save ordering and lifetime

Initialize preferences once during existing app bootstrap before accepting new
Flight/leg/recording creation. Reuse the existing startup/recovery loading phase;
do not show false default selections while stored values are still being read.
Missing values finish immediately with defaults. Loading does not alter recovery
eligibility or restart its countdown.

Serialize change commands in request order. A disk adapter performs the small file
transaction without suspension inside its isolated mutation. The controller keeps
the old effective value until the write succeeds; then publishes the new value and
completes selector navigation. No optimistic default reaches a Flight on failure.
While a write is in flight, repeated requests remain ordered; only the newest failed
attempt is retryable. A newer deliberate choice supersedes the old retry target,
without cancelling an already-committing write or losing unrelated changes.

Leaving Settings does not cancel an accepted save. Avoid attaching persistence
lifetime to the chooser’s `.task`. Revalidate request identity after each await;
an older completion must not dismiss a newer chooser or replace its error. Retry
creates a fresh ordered command; Dismiss clears only the error/attempt. The
controller retains tasks until completion and handles teardown explicitly.

## Consumer integration and capture rules

| Action | Input captured | Publication rule |
| --- | --- | --- |
| Load/restart request accepted | Latest successfully saved progression and drift defaults | Build the candidate with explicit values; retain existing replacement confirmation. |
| Replacement confirmation | Candidate values fixed by the initiating request | Do not re-read preferences or mutate the old Flight while confirming. Settings is already gated while replacement is pending. |
| Manual Start Leg | Latest saved checklist selection at command acceptance | Install choice with the successful committed leg start, never on render. |
| Automatic successor start | Latest saved checklist at the arrival command’s acceptance | Attach to successor start; preserve timestamp, timer and undo behavior. Manual progression captures nothing until its later Start Leg. |
| Recording creation | Latest saved recovery duration at promotion acceptance | Covers explicit Start Leg, automatic takeoff, partial-start and fallback engine creation. Prepared/armed state does not freeze a future recording’s window. |
| Continue existing recording/Flight | Its captured values | Never copy today’s recovery/progression defaults into it. |

Use a main-actor value provider at the coordinator seam for physical promotion;
sample it before crossing into the engine actor. Do not inject a mutable provider
into domain code. Preferences changed after command acceptance apply to a later
eligible command, not the already captured one.

Separate **not started**, **started with no checklist**, and **started with a
template**. Otherwise `installCommittedFlight` would recreate a checklist merely
because its dictionary entry was nil. Keep explicit absence through ordinary
re-render, selection edits, arrival transitions, undo, and recovery.

Template identity belongs to captured leg state. The adapter looks up that identity
and validates variables, then resolves current dynamic values. It must not call
the default `.tzeKivun` path unconditionally. Retain definition revisions for any
template used in a recoverable recording; changing bundled text later must not
reinterpret the captured definition. Use a framework-independent definition DTO
or a versioned immutable catalog, not serialization of SwiftUI `LayoutDirection`.

## Recovery and compatibility

Promote the recording package format to schema 3 and retain explicit readers for
1 and 2. Older app versions must reject schema 3 as unsupported rather than
silently replay new events incorrectly. Existing exports/evidence readers must
recognize the new schema; do not change exported track geometry or detector rules.

Persist immutable progression policy at recording creation alongside the existing
recovery window. Add optional versioned Cockpit-context metadata to the appropriate
durable navigation journal entries: starting a leg captures its checklist choice;
arrival/automatic transition carries successor context; undo carries restored
context. Metadata and its governing event are encoded in the same journal record,
not in a best-effort sidecar written after publishing the navigation transition.
Physical promotion before the first leg captures policy/visibility but no invented
leg-start choice. Validate Flight and leg identities and definition revisions.

Record later visibility and checklist review/presentation changes as typed
system/pilot presentation events in the same journal. Recovery projects these
separately from navigation; they must not change timers, target eligibility,
physical detection or route values. Checkpoint/replay logic must handle them
explicitly. Device-default edits alone never append Flight activity or refresh a
recovery deadline.

Navigation still uses existing persist-before-publish behavior. On recording-write
failure, do not publish a newly started leg/checklist as committed. A presentation
event write failure preserves the prior durable presentation state while retaining
the current in-memory presentation choice; recovery can restore only the last
successful durable state. Follow the existing non-blocking recording degradation
contract (Recording spec §§59,95); do not fabricate a durable Noted acknowledgement.
No presentation write may block an operational navigation action. Newly required
warning presentation, if existing recording status cannot express this failure,
returns to design review before implementation.

Replay `Flight` with the persisted progression policy before replaying any arrivals.
Extend `RecoveredFlight` with the recovered Cockpit settings projection; restoration
must install it instead of resetting visibility and clearing every checklist entry.
Keep current recording freshness checks, segment reopening and expiry behavior.

Legacy SET-16 fallback is independent of current device defaults: automatic
progression where historical records lack policy, five-minute recovery where the
legacy manifest lacks its window, drift lines visible, and the historical Hebrew
template for an active leg without a recorded choice. Do not invent acknowledgements
or undo offers across a restart. New successor starts use current saved selection.
Unknown/corrupt required schema-3 operational metadata must not silently switch a
Flight from Manual to Automatic: use the existing unavailable/corrupt recovery
route. Missing optional legacy presentation fields use SET-16 defaults.

## UI and extension convention

Use native `NavigationStack`, grouped Form/List sections, a Toggle and exclusive
choice rows with stable enum identity. Own scene paths separately from the shared
saved snapshot. Use real text styles, wrapping and scrolling; errors announce the
retained value and Retry/Dismiss. Programmatic rollback must not enqueue another
save. Keep hardware keyboard/VoiceOver interaction native. No fixed font multiplier,
custom control framework or global environment observation is needed.

To add a future setting: define its typed value/default, stable key and envelope
version, owning feature and category, allowed choices, capture/application timing,
failure/compatibility behavior and test contract. Add a row to the owning group and
pass its narrow value to its consumer. A new key never rewrites existing keys.

## Implementation test contract — not executed

| Scope | Existing or proposed test seam | Required assertions |
| --- | --- | --- |
| Preferences | New `SettingsControllerTests`, `DiskSettingsStoreTests`; isolated temporary directories and controllable adapters | All defaults/choices; process-style reload; invalid/missing/unknown versions individually; untouched unknown files; failed create/replace; previous value retained; retry/dismiss; competing choices and unrelated queued writes. |
| App composition | Extend `AppFeatureStateTests` | New/restarted candidate captures latest saved defaults, old Flight and pending replacement preserved, switching app sections never changes timing. |
| Checklist lifecycle | Extend Cockpit state/presentation tests in existing suites | Every selection for explicit and automatic starts; disabled vs uninitialized; definition identity; dynamic values; failed leg commit; active template unchanged; undo restores exact prior choice/state; final leg and manual successor regression. |
| Recording capture | Extend `FlightRecordingEngineTests`, `FlightRecordingCoordinatorTests` | All four windows on both promotion paths, edits after arm/before promotion, fallback engine creation, edits after creation cannot extend recovery; explicit immutable progression metadata. |
| Persistence/replay | Extend `DiskFlightRecordingStoreTests`, `FlightRecoveryCoordinatorTests` | Schema 1/2 fixtures and schema 3 round-trip, unknown schema/corruption, manual progression replay, checklist/no-checklist and visibility/ack restoration, undo context and mismatched IDs, definition revisions, failed presentation writes, unchanged expiry. |
| UI | Existing `NavigationFlightUITests` helpers with separate test settings directory | Groups, selectors/Back, relaunch, failed save/retry, no Flight/active Flight navigation; drift override unchanged; No checklist absent at next start. |
| Rendered acceptance | Exact frames in approved design inventory | iPad portrait/landscape, iPhone 16 Pro and compact portrait, Larger Text, dark, VoiceOver, resizing/rotation, visible error and accessible actions. Retain screenshots plus transitions; static Figma is not runtime evidence. |

Use Swift Testing for unit/integration work and XCUIAutomation for UI work, keeping
current UI test structure. Inject timestamps and clocks; use controllable suspended
adapters for interleavings, never arbitrary sleeps. UI fixtures must isolate both
recordings and settings, and relaunch tests reuse only their own settings directory.
Preserve existing debug progression override behavior only for explicit debug
fixtures; production always uses saved defaults for new Flights.

During implementation, run the smallest affected suites, then build with Xcode
BuildProject and perform required simulator interactions. Run `git diff --check`
at each checkpoint. This planning phase runs none of those runtime checks.

## Approval and remaining handoff constraints

John approved file-backed independent preferences, app-owned Observation state,
explicit capture inputs, and schema-3 recording/replay additions.
No broad domain or map refactor is proposed.

Before implementation tickets are ready: resolve the recording degradation-state
design gap noted below. The approved spec/design permalink baseline is published
at `9d2628a5cf1db9a551f1852271f2b48f33747efd` under John’s separate 2026-11-21
commit/push/PR/merge authorization. The approved tickets are
published under #189; #161 was updated in place to the three-choice contract.


### Delivery-preparation finding

Inspection of `RecordingStatusPresentation.swift` confirms that
`.recordingDegraded` currently says “Some track data could not be saved.” That is
inaccurate for a checklist/presentation journal failure with intact track data.
Before #161 becomes ready, obtain approval of accurate presentation-failure copy
using the existing warning-control geometry, or approve a separately designed
warning variant. The approved Settings save-error frame does not govern the Cockpit
warning. This is a scoped design blocker, not permission to rewrite that control.
