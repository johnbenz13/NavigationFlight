# Cockpit Operational Cues — Technical Design

## Status and authority

This design implements [Cockpit Operational Cues](../features/COCKPIT-OPERATIONAL-CUES_SPEC.md). Direction 01 and the complete paired product-spec/Figma baseline represented by Iteration 02 were approved by John on 2026-11-03. The immutable product-spec permalink is recorded on GitHub issue #70 after documentation checkpoint creation.

Behavior is authoritative in the product specification. Layout and visual hierarchy become authoritative only after the Figma direction and subsequent coverage are approved.

## Scope

The implementation has three focused responsibilities:

1. Manage the system idle timer for the accepted Flight lifecycle.
2. Project planned frequency and altitude changes into deterministic current, next, and due presentation values.
3. Render those values and transient visual emphasis in the existing lower cockpit console.

It does not alter Flight Plan decoding, route geometry, GPS services, Check Position, pilot-reported progression, or map annotations.

## Architectural fit

The feature should add one deep presentation module rather than spreading timing rules through SwiftUI:

```text
Flight + Flight Plan + selected mode + timestamp
                    │
                    ▼
       CockpitOperationalCueProjector
          small deterministic interface
                    │
                    ▼
        CockpitOperationalCueState
          current / next / due values
                    │
                    ▼
        CockpitFeatureView / CockpitView
          lifecycle + visual presentation
```

`CockpitOperationalCueProjector` is the seam. Its interface accepts the existing execution snapshot, Flight lifecycle state, selected navigation mode, and a timestamp, and returns a value-only projection. Its implementation owns ordering, preview windows, repeated-frequency suppression, start-of-leg rules, and elapsed-time comparisons. Callers do not learn those rules.

The deletion test is meaningful: without this module, the same ordering and timing logic would reappear in the feature state, view, animation code, and tests. Keeping it behind one interface provides locality and makes the interface the test surface.

No protocol is introduced for the projector because only one deterministic implementation is expected. Tests call the same value interface as production.

## Planned cue model

The projection should expose values equivalent to:

```swift
struct CockpitOperationalCueState: Equatable, Sendable {
    let frequencies: [FrequencyCue]
    let currentAltitude: AltitudeFeet
    let nextAltitude: AltitudeCue?
    let dueEvents: Set<DueEvent>
}

struct FrequencyCue: Identifiable, Equatable, Sendable {
    enum Status: Equatable, Sendable {
        case current
        case next
        case other
    }

    let frequency: CockpitPresentationData.DisplayFrequency
    let status: Status
}

struct AltitudeCue: Equatable, Sendable {
    let target: AltitudeFeet
    let direction: AltitudeChangeDirection
}

enum DueEvent: Hashable, Sendable {
    case frequency(UUID)
    case altitude(UUID)
}
```

Exact nesting may follow existing presentation conventions, but the view receives already classified values. It must not search annotations or compare elapsed times itself.

## Timeline construction

The projector builds ordered per-leg timelines from existing domain data:

- `FrequencyChange` supplies the service, frequency, leg, and fractional progress.
- `AltitudeChange` supplies the target, explicit direction, and leg-progress, waypoint, or identification-point anchor.
- `PlannedNavigationAnnotation` supplies no-wind and optional with-wind time from leg start for each change entity.
- `PlannedNavigation.frequenciesByPhase` remains the authoritative complete console list.
- `PlannedLegNavigation.initialAltitudeMsl` supplies the initial target before later altitude changes become due.

Entity identifiers join changes to their planned annotations. The selected navigation mode selects `noWindTimeFromLegStartSeconds` or `withWindTimeFromLegStartSeconds`. Missing required timing is treated as unavailable cue timing rather than guessed from GPS or wall-clock route progress.

Changes sort by leg order, planned time, and stable source order. A start-of-leg change has planned time zero. Coincident frequency and altitude changes remain distinct events.

## Projection rules

For a ready first leg, the projector returns its initial frequency and altitude plus any changes at time zero as pending previews.

For an active leg, elapsed seconds come from the existing `Flight.elapsedTime(at:)` path and its display-second normalization. The most recent change whose planned time is less than or equal to elapsed time determines the current value. The first later different value determines the next preview.

When a change becomes current, its identifier appears in `dueEvents` only for the rendering interval that observes the transition while the cockpit is visible. The durable projection itself does not store an acknowledgement or checklist state.

When the pilot progresses to another leg, the new leg identity invalidates transient due-event presentation from the completed leg. The new projection is resolved directly from the new leg.

The full frequency list remains in existing display order. The projector matches planned changes to display entries by the domain identity available from the mapped data, not by formatted text. If the current planned frequency cannot be represented by a display entry, all rows remain neutral and the mismatch is testable; the UI must not highlight a guessed row.

## Transient emphasis

`CockpitFeatureView` owns only the short-lived observation of transitions between two projections. When the active scene observes a newly inserted `dueEvent`, it records a five-second presentation deadline for that event. The deadline drives the relevant local pulse or static highlight.

Transient emphasis is not persisted. On initial appearance or return from background, the view seeds its previous projection without animating already-due events. A leg identity change also seeds the new baseline before animation comparison, preventing missed events from replaying.

The animation uses SwiftUI state scoped to the cockpit view. `@Environment(\.accessibilityReduceMotion)` selects a static highlight instead of repeated scale or opacity animation. Frequency and altitude events have independent transient state so simultaneous changes can render together.

## Keep-awake lifecycle

UIKit's `UIApplication.isIdleTimerDisabled` is the platform seam. Apple requires resetting it when no longer necessary, so ownership belongs at the application/feature coordination layer rather than inside a reusable metric card.

The derived condition is true when an accepted Flight exists in ready or active execution, including ready handoffs between legs. It becomes false on completion, abandonment, replacement by a non-flight flow, or teardown of the owning scene.

An `IdleTimerControlling` interface is justified because there are two adapters:

- a production main-actor adapter that writes `UIApplication.shared.isIdleTimerDisabled`;
- a recording test adapter that verifies lifecycle transitions without touching global process state.

The application coordinator synchronizes the adapter whenever the derived condition changes and defensively restores `false` when the owning scene is removed. Scene phase does not redefine Flight activity; it only prevents UI animation from replaying after background return.

## SwiftUI composition

`CockpitView` retains the existing console hierarchy.

- Every frequency remains present in the existing order.
- A frequency row receives a semantic status and renders neutral, green/current, or amber/next treatment plus visible text.
- The altitude card renames its meaning to target altitude, retains the large current target, and adds one compact next target with an arrow.
- The due animation attaches only to the newly current frequency content or altitude arrow, not to the whole console.
- No new button, tap target, acknowledgement action, modal, or navigation path is added.

Semantic colors should adapt to light/dark appearance while meeting sufficient contrast. The final color values, spacing, and type treatment are governed by approved Figma nodes and must be checked in both iPad orientations and the supported iPhone portrait layout.

## Accessibility

- `CURRENT` and `NEXT` are exposed as text and accessibility values, not color-only state.
- The altitude accessibility value includes current target and, when present, the next target and direction.
- A due transition updates the value without moving VoiceOver focus or posting an interrupting announcement.
- Reduce Motion replaces pulse animation with a static highlight for the same five-second duration.
- Dynamic Type may reflow or stack frequency cards; it must preserve complete frequency values and state labels.

## File plan

Expected implementation locations are intentionally narrow:

- `NavigationFlight/Features/Cockpit/CockpitOperationalCueProjector.swift` — deterministic projection module and value models.
- `NavigationFlight/Features/Cockpit/CockpitPresentationAdapter.swift` — provide the projector with existing mapped frequency and annotation identities if a small presentation mapping extension is required.
- `NavigationFlight/Features/Cockpit/CockpitFeatureState.swift` — expose the current execution inputs and derived keep-awake condition without storing visual animation state.
- `NavigationFlight/Features/Cockpit/CockpitFeatureView.swift` — coordinate idle-timer synchronization and visible transition observation.
- `NavigationFlight/Features/Cockpit/CockpitView.swift` — render frequency and altitude cue states.
- `NavigationFlightTests/CockpitOperationalCueProjectorTests.swift` — deterministic timeline and edge-case coverage.
- Existing cockpit state, presentation, and UI test files — lifecycle and rendered interaction coverage.

The exact file split may be reduced if existing nearby types provide a deeper interface, but cue rules must remain outside SwiftUI rendering code.

## Test strategy

### Projection tests

- Ready first-leg preview for time-zero frequency and altitude changes.
- Mid-leg preview from leg start and automatic transition at the exact planned second.
- Start-of-next-leg preview during the previous leg.
- No-wind and with-wind annotation timing.
- Repeated identical frequency suppression.
- Complete frequency list ordering with one current and one next status.
- Multiple altitude changes with only one next preview.
- Coincident frequency and altitude events.
- Early manual leg completion and new-leg baseline resolution.
- Missing or unmatched change data fails neutral rather than guessing.

### Lifecycle tests

- Idle timer enables on accepted Flight ready state.
- It remains enabled across active and ready handoff states.
- It disables on completion, abandonment, replacement, and teardown.
- Browsing and inspecting Flight Plans never enables it.

### Presentation and UI tests

- Current, next, and neutral frequency treatments include visible labels.
- Current and next altitude values and arrows render without clipping.
- Only the affected local cue pulses for five seconds.
- Reduce Motion uses a static highlight.
- Background return and early leg progression do not replay missed cues.
- Simultaneous frequency and altitude changes both render.
- VoiceOver values identify state and direction without focus interruption.
- iPad portrait and landscape, iPhone portrait, and Larger Text match approved design coverage.

## Delivery sequence and gates

1. Obtain explicit approval of the Direction 01 main-screen hierarchy.
2. Expand Figma coverage for due, ready, simultaneous, adaptive-layout, and accessibility states.
3. Reconcile and approve the paired product-spec/Figma baseline.
4. Implement and test the cue projector.
5. Implement idle-timer coordination.
6. Implement console styling and transient emphasis.
7. Run focused tests, full application build, and simulator interaction checks in required orientations.
8. Audit every acceptance criterion against test, build, simulator, and exact Figma evidence before completion.

Implementation must not begin while either Figma approval gate remains open.

## Tracking issues

- [#69 — Cockpit operational cues: keep awake and planned change guidance](https://github.com/johnbenz13/NavigationFlight/issues/69)
- [#70 — Expand and approve Cockpit Operational Cues Figma coverage](https://github.com/johnbenz13/NavigationFlight/issues/70)
- [#71 — Keep the display awake during the accepted Flight lifecycle](https://github.com/johnbenz13/NavigationFlight/issues/71)
- [#72 — Project planned current, next, and due frequency and altitude cues](https://github.com/johnbenz13/NavigationFlight/issues/72)
- [#73 — Render cockpit frequency and altitude cues with accessible due emphasis](https://github.com/johnbenz13/NavigationFlight/issues/73)

## Rejected alternatives

### Drive cues from GPS position

Rejected because it would silently change the product from pilot-driven navigation to automatic position progression and would violate the Check Position boundary.

### Store acknowledgements

Rejected because the feature is informational and not a checklist. Planned time determines current state.

### Put timing comparisons in each SwiftUI card

Rejected because it creates shallow duplicated logic, makes background and leg-transition behavior inconsistent, and expands the view interface.

### Hide non-current frequencies

Rejected because the complete frequency list is existing useful context and was explicitly retained.
