# Flight Evidence Export and Debrief — Technical Design

Status: **approved by John on 2026-11-17**

Product baseline: [approved specification revision `5b8ff5e`](https://github.com/johnbenz13/NavigationFlight/blob/5b8ff5e982450edde72ff9d18bdfd18215b24a36/docs/features/FLIGHT-EVIDENCE-EXPORT-AND-DEBRIEF_SPEC.md)

Design baseline: [approved Figma Directions 01–05](https://www.figma.com/design/OSPuLyy5Qtde2iajUNeWDL)

Source inspected at: `fb5e925` on `feature/flight-evidence-export-and-debrief`

## Decision summary

- Preserve the existing recording domain and `FlightRecordingStore` as the source of truth.
- Use one immutable `FlightRecordingReadSnapshot` as the seam for export, debrief projection, and detector replay.
- Encode diagnostic evidence as a versioned, single-file JSON document with the `.nflightbundle` extension. Do not introduce a ZIP dependency.
- Generate exports in a temporary location and publish only after validation and an atomic final move.
- Add a pure, shared detector replay module that exposes candidate evidence without changing recorded events.
- Keep production recording actor-isolated; export, projection, and replay operate on sendable value snapshots outside the recording actor.
- Use feature-owned `@MainActor @Observable` models for debrief/export presentation. Views remain state expressions.
- Deliver the engineering analyzer as a local macOS command-line target that emits a self-contained HTML report and imports the same evidence/replay module as the iOS app.
- Implement vertical slices in this order: portable schema and export, debrief projections, debrief UI, detector replay, comparative analyzer, then any separately approved detector-policy change.

## Inspected architecture

The existing implementation already contains useful deep modules:

- `FlightRecording` owns legal recording transitions, ordered event creation, physical/navigation state, and closure semantics.
- `FlightRecordingEngine` orchestrates domain transitions and persistence.
- `FlightRecordingCoordinator` owns live location and supplemental-sensor consumption, recovery checkpointing, and application-facing recording status.
- `FlightRecordingStore` is an async, sendable persistence interface. `readSnapshot(id:)` returns the recording, complete event journal, segmented track, approximate size, and evidence summary as values.
- `DiskFlightRecordingStore` and `InMemoryFlightRecordingStore` are existing adapters at that seam.
- `PhysicalFlightDetector` is a pure value type driven by samples and monotonic time. Its state transition results are deterministic, but candidate start, interruption, and reset details are private.
- `FlightRecordingLibrary` is an actor that projects stored snapshots into list/detail presentation and currently delegates GPX export.
- `FlightDetailView` is a SwiftUI presentation surface with an async GPX action and existing unavailable/active distinctions.

The current persisted manifest is schema version 1. Event envelopes are payload version 1; track envelopes currently read versions 1–2. New diagnostic bundle versioning must remain independent of these internal storage versions.

## Module design

### 1. Flight evidence snapshot

`FlightRecordingReadSnapshot` remains the external interface of the storage module for readable evidence. Callers receive one value and never traverse package files directly.

Required extension:

```swift
nonisolated struct FlightEvidenceContext: Codable, Equatable, Sendable {
    let appVersion: String
    let appBuild: String
    let platform: String
    let osVersion: String
    let detectorPolicy: PhysicalFlightDetectionPolicySnapshot?
}

nonisolated struct FlightEvidenceSnapshot: Equatable, Sendable {
    let capturedAt: Date
    let sourceState: SourceState
    let recording: FlightRecordingReadSnapshot
    let context: FlightEvidenceContext
}
```

`SourceState` distinguishes closed, active, and recoverable evidence. Snapshot construction reads the recording package once and captures context without mutating recovery freshness or recording state.

The store interface does not gain export-specific methods. Snapshot consistency is a storage responsibility already represented by `readSnapshot(id:)`; the disk adapter must complete pending in-actor writes before returning.

### 2. Portable diagnostic bundle

The diagnostic bundle is a compact JSON file with exported UTType `app.navigationflight.diagnostic-bundle` and extension `.nflightbundle`.

Top-level structure:

```text
FlightEvidenceBundleV1
├── schemaVersion
├── bundleIdentifier
├── capturedAt
├── sourceState
├── applicationContext
├── detectorPolicyContext?
├── recordingManifest
├── flightPlan
├── closure?
├── orderedEvents[]
└── trackSegments[]
    └── samples[]
```

Rules:

- `schemaVersion` versions the portable document, not disk persistence.
- Every enum is encoded with stable explicit strings; unknown values fail safely rather than defaulting.
- Durations use integer nanoseconds and dates use RFC 3339 with fractional seconds.
- Optional measurements remain absent. They are never encoded as zero or `NaN`.
- Original plan `sourceData` is base64-encoded alongside its identity and title.
- Segment identifiers and boundaries are retained. No samples are synthesized.
- Events retain identifier, sequence, recorded time, elapsed time, origin, and payload.
- JSON keys are sorted for deterministic fixtures and diffs. Array order remains evidentiary order.
- The complete encoded document is decoded and structurally validated before publication.

`DiagnosticBundleEncoder` is a deep module:

```swift
nonisolated struct DiagnosticBundleEncoder: Sendable {
    func encode(_ snapshot: FlightEvidenceSnapshot) throws -> Data
    func decode(_ data: Data) throws -> FlightEvidenceBundle
}
```

It owns DTO mapping, version checks, validation, and stable encoding. UI and storage callers do not know individual DTO types.

### 3. Diagnostic export

`DiagnosticBundleExporter` owns file lifecycle:

```swift
actor DiagnosticBundleExporter {
    func export(_ snapshot: FlightEvidenceSnapshot) async throws -> DiagnosticExportResult
}
```

The implementation:

1. Checks cancellation.
2. Encodes to a uniquely named file inside an export-specific temporary directory.
3. Decodes and validates the completed file.
4. Atomically moves it to its final temporary share URL.
5. Returns metadata and the URL only after success.
6. Removes work-in-progress files on cancellation or error.

The exporter never owns or calls the live coordinator. It cannot close, refresh, continue, or otherwise mutate a recording.

GPX remains a separate `GPXExporter`. `FlightRecordingLibrary` exposes an export choice and delegates to the appropriate exporter rather than merging formats.

### 4. Debrief projection

`FlightDebriefProjector` is a pure module whose interface accepts evidence and returns one immutable presentation model:

```swift
nonisolated struct FlightDebriefProjector: Sendable {
    func project(_ evidence: FlightEvidenceSnapshot) -> FlightDebrief
}
```

It owns:

- planned route decoding;
- segmented actual tracks and explicit gap intervals;
- deterministic event-to-position correlation;
- selected-time telemetry lookup;
- reached-point evidence;
- derived cross-track, along-track, closest-approach, climb, and descent observations;
- textual equivalents for map relationships; and
- limited/unavailable state classification.

Correlation policy is explicit and versioned independently from detector policy. It searches only inside the event's containing track segment, applies a maximum time delta and accuracy requirement, and returns one of `direct`, `correlated`, or `unavailable`. It never rewrites the event.

Large sample arrays remain value data but projections should build indexed segment views once per snapshot. Selection changes query those indexes rather than re-projecting the entire flight.

### 5. Debrief presentation

Use the repository's existing SwiftUI MV style, not a new app-wide framework.

```swift
@MainActor
@Observable
final class FlightDebriefModel {
    private(set) var state: State
    var selectedTime: Duration
    var playbackRate: PlaybackRate

    func load() async
    func play()
    func pause()
    func seek(to time: Duration)
    func select(eventID: UUID)
}
```

The model owns presentation loading, selection, and playback. The projector owns evidence interpretation. Export remains a separate model so cancelling export cannot cancel debrief loading or playback.

Playback uses an injected continuous clock and one structured child task. Pause, navigation away, a new seek, and deinitialization cancel it. Recorded timestamps and projections are never rescaled; rate changes only selection advancement.

Views use semantic text styles, stable event identifiers, `ViewThatFits` or available-width composition for adaptations, and scrollable vertical layouts at accessibility sizes. The map is hidden from VoiceOver after an equivalent textual relationship summary. The timeline exposes adjustable semantics; play/pause and rate remain standard controls.

### 6. Explainable detector replay

Do not create a second implementation of the detector algorithm.

Extract the current transition logic into a pure internal state machine that returns both transitions and evaluations:

```swift
nonisolated struct PhysicalFlightDetectionStep: Equatable, Sendable {
    let sampleIndex: Int
    let monotonicTime: Duration
    let stateBefore: PhysicalFlightState
    let stateAfter: PhysicalFlightState
    let candidate: CandidateEvaluation?
    let emittedEvents: [PhysicalFlightDetector.Event]
}

nonisolated struct PhysicalFlightReplay: Sendable {
    func run(
        samples: [RecordedTrackSample],
        policy: PhysicalFlightDetectionPolicy
    ) -> [PhysicalFlightDetectionStep]
}
```

The production `PhysicalFlightDetector.process` delegates to the same evaluator and discards explanation details. Replay collects them. This keeps threshold comparisons, interruption tolerance, ground reference, and state transitions identical.

Replay output is derived evidence. It is never appended to `RecordedFlightEvent`, persisted into the source recording, or presented as recorded history.

Policy values gain a stable versioned snapshot for export and display. Historical recordings without a captured policy use an explicit analyzer assumption; they are not labelled exact reconstructions.

### 7. Local comparative analyzer

Add a macOS command-line target, `FlightEvidenceAnalyzer`, importing the portable evidence and replay module. It accepts one or more bundle paths and an output directory:

```text
FlightEvidenceAnalyzer bundle1.nflightbundle [bundle2...] --output report/
```

It emits a self-contained `index.html` with embedded escaped JSON and local CSS/JavaScript assets. The report requires no server, account, or network request.

One bundle supports inspection and policy replay. Multiple bundles add comparison and regression views. The analyzer assigns a stable color/label per input bundle and never assumes exactly two flights.

Alternative policy input is a separate JSON policy file validated against the policy schema. The analyzer never writes into a bundle.

## Shared module and target placement

Introduce a local Swift package `FlightEvidenceCore` with no UIKit or SwiftUI dependency. It contains:

- portable bundle schema and codec;
- shared evidence value types needed outside the app;
- detector policy snapshots and pure replay;
- deterministic debrief/correlation projections that do not require MapKit.

The iOS target and macOS analyzer target depend on this package. App-specific adapters map current recording-domain values into the package's portable values. Initially, the existing production detector stays in the app target while its evaluator is extracted behind tests; target movement happens in one tested slice rather than a broad domain migration.

Rejected alternatives:

- **Duplicate detector logic in JavaScript:** rejected because replay would drift from production.
- **Upload bundles to a hosted analyzer:** rejected by the local-only privacy contract.
- **ZIP bundle with a third-party dependency:** rejected because a single versioned JSON document preserves all required evidence and keeps the first format auditable.
- **Put export methods on `FlightRecordingCoordinator`:** rejected because it would couple read-only diagnostics to live operational state.
- **Adopt TCA or an app-wide architecture migration:** rejected; existing actor-backed domain modules plus focused observable presentation models are sufficient.

## Concurrency and cancellation

- Live mutation remains inside existing actors.
- Snapshot, bundle, projection, and replay values conform to `Sendable`.
- No `@unchecked Sendable` is introduced.
- Export and replay check cancellation between meaningful batches; no detached tasks are required.
- The UI starts operations with view/model-owned structured tasks and cancels them when the presentation leaves.
- Actor state is revalidated after every suspension before publishing results.
- The analyzer processes multiple flights with a throwing task group only after each input has independently decoded and validated; output ordering is restored deterministically by input index.

## Persistence and compatibility

- Existing disk packages remain schema version 1 and are not rewritten merely to support export.
- Portable bundle schema starts at version 1 and has its own decoder compatibility table.
- Older readable recordings export available fields and explicit missing context.
- Unsupported disk packages remain unsupported; preserved raw material may use a separately labelled limited export and never masquerades as a v1 complete bundle.
- Deleting a recording removes only app-owned source evidence and cached projections, not previously shared files.
- Debrief projections are regenerated from source evidence. Persistent caches, if later needed, must be disposable and keyed by recording identity, source fingerprint, projector version, and correlation policy version.

## Error model

Errors are classified at module interfaces:

- snapshot: missing, corrupt, unsupported, or operation failed;
- bundle codec: unsupported version, malformed structure, invalid ordering, invalid measurement, or checksum/fingerprint mismatch;
- export: cancelled, temporary-storage unavailable, encoding failed, validation failed, or publication failed;
- debrief: no usable GPS and partial evidence are presentation states, not thrown errors;
- replay: unsupported policy, missing required context, or invalid sample order;
- analyzer: one invalid bundle does not silently remove that flight from a multi-flight report.

UI-facing errors are mapped to localized presentation values outside the domain modules.

## Test contract

New unit tests use Swift Testing and run independently in parallel. XCUITest remains the UI automation framework.

### Bundle and export

- Round-trip every event payload and every optional measurement.
- Preserve event sequence, sample order, segment boundaries, missing values, and plan source bytes.
- Reject unknown versions and malformed order without partial decoding.
- Verify active/recoverable snapshot labels and captured time.
- Verify cancellation and every failure path leave no publishable partial file.
- Verify export does not call close, checkpoint, or any live-coordinator operation.
- Keep golden v1 bundle fixtures small, synthetic, and privacy-safe.

### Debrief

- Parameterize direct, correlated, and unavailable event positions.
- Prove correlation never crosses a segment boundary.
- Prove selection synchronizes map, telemetry, and timeline time.
- Verify partial, unavailable, action-only, active, unsupported, and unreadable projections.
- Verify deterministic route metrics and altitude-source disclosure.
- Use an injected clock for playback; do not sleep in tests.

### Detector replay

- Run production and replay evaluators over the same synthetic samples and assert identical transition events.
- Assert candidate start, bounded interruption, reset, completion, correction, and ground-reference evidence.
- Assert identical bundle plus identical policy produces byte-for-byte equivalent ordered replay output.
- Include known-failure characteristics, known-success characteristics, taxi stop, stationary jitter, GPS gap, different ground elevation, partial launch, and recovery cases.
- A detector-policy change requires explicit expected-result updates for the full matrix; fixing one fixture is insufficient.

### UI and accessibility

- XCUITest covers export choice, cancellation, retry, system share presentation boundary, debrief limited states, playback controls, and iPhone/iPad layout entry points.
- Accessibility identifiers describe semantics rather than geometry.
- Simulator review compares the approved Figma nodes on iPad portrait, iPad landscape, and iPhone portrait.
- Manual evidence records VoiceOver order, accessibility Dynamic Type, sufficient contrast, and Reduce Motion behavior.

### Analyzer

- One and many bundle inputs produce deterministic reports.
- Recorded, current-policy, and alternative-policy results remain distinguishable in generated HTML.
- HTML escapes bundle-provided text and performs no network requests.
- Invalid input is reported with its filename and does not become a silently missing comparison.

## Incremental delivery seams

1. Portable evidence schema, codec, synthetic fixtures, and compatibility tests.
2. Diagnostic snapshot/export pipeline and Flight Detail export choice.
3. Pure debrief projector and event-position correlation.
4. iPad portrait debrief with selection and playback.
5. Limited states, iPad landscape, iPhone portrait, and accessibility coverage.
6. Shared detector evaluator and explainable replay.
7. Local analyzer and comparative/adverse-scenario report.
8. Separately proposed detector-policy revision, only after real-bundle analysis and regression approval.

Each slice leaves existing GPX export and recording behavior operational.

## Approval questions

Technical approval should explicitly confirm:

1. `.nflightbundle` is a single versioned JSON file rather than a ZIP archive.
2. A local `FlightEvidenceCore` Swift package is acceptable as the shared portable/replay module.
3. The engineering analyzer is a macOS command-line target that emits a self-contained HTML report.
4. Detector-policy changes remain outside this implementation baseline until comparative evidence is reviewed.
