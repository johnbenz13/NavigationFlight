# Position Check — Technical Design

Status: approved technical baseline; implementation has not started.

## Authorities

- Product behavior: [Position Check — Product Specification](../features/POSITION-CHECK_SPEC.md)
- Cockpit behavior: [Flying a Leg — Product Specification](../features/FLYING-A-LEG_SPEC.md)
- Existing cockpit design: [Flying a Leg technical design](FLYING-A-LEG-TECHNICAL-DESIGN.md)
- Visual presentation: the approved Position Check nodes linked from the product
  specification.

## Design objectives

The implementation must keep GPS acquisition independent from GPS disclosure.
Location data is an input capability; Position Check is one scene-owned consumer
that decides whether and when any derived information becomes visible. This
boundary allows a future flight recorder and a future CFI safety policy to reuse
validated fixes without inheriting manual Position Check presentation state.

The vertical slice has four modules:

1. location acquisition and quality classification;
2. deterministic recovery calculation;
3. scene-owned Position Check state and timing;
4. cockpit/map presentation.

None of these modules writes `Flight` observations or progression state.

## Platform foundation

Use Core Location's Swift concurrency API:

```swift
for try await update in CLLocationUpdate.liveUpdates(.airborne) {
    // Reduce authorization and location events into LocationReadiness.
}
```

Apple documents `.airborne` specifically for activities in the air. The live
update sequence reports location and authorization changes together and avoids a
delegate-to-Combine bridge. The acquisition task runs only while an active
cockpit flight needs readiness monitoring and is cancelled when that scope ends.

The first release uses foreground, When-In-Use access only:

- no `CLBackgroundActivitySession`;
- no location background mode;
- no Always authorization request; and
- no durable or analytics sink for fixes.

The app must include a focused `NSLocationWhenInUseUsageDescription` explaining
Position Check. Permission education is app-owned; the system prompt remains
system-owned.

## Location domain boundary

Introduce a feature-independent location input under `Domain/Location`:

```swift
struct AircraftLocationSample: Equatable, Sendable {
    let coordinate: GeoCoordinate
    let observedAt: Date
    let horizontalAccuracyMeters: Double
    let trueCourseDegrees: Double?
    let courseAccuracyDegrees: Double?
    let groundSpeedMetersPerSecond: Double?
    let speedAccuracyMetersPerSecond: Double?
}

enum LocationAvailability: Equatable, Sendable {
    case ready(AircraftLocationSample)
    case acquiring
    case unavailable(LocationUnavailabilityReason)
    case permissionRequired
}

protocol AircraftLocationSource: Sendable {
    func updates() -> AsyncThrowingStream<LocationSourceEvent, Error>
}
```

`CoreLocationAircraftLocationSource` is the data adapter. It converts
`CLLocationUpdate` and `CLLocation` into project-owned sendable values immediately
so Core Location types do not spread into cockpit, map, or recovery code.

`AircraftLocationService` owns the single acquisition task and publishes the
latest classified availability. It supports multiple read-only consumers without
making any consumer responsible for starting a second hardware stream. It does
not retain a sample history.

A future recorder may subscribe to accepted samples through a separately
authorized sink. No recorder protocol or no-op persistence layer is added now.

## Quality policy

`PositionCheckQualityPolicy` centralizes all first-release thresholds. Initial
implementation values are:

| Input | Usable policy |
| --- | --- |
| Sample age | At most 5 elapsed seconds |
| Horizontal accuracy | Positive and at most 100 m |
| Groundspeed for guidance | At least 5 m/s with nonnegative reported accuracy |
| Course for directional symbol/guidance | Valid true course with course accuracy at most 20° |
| Disclosure duration | 10 elapsed seconds |
| Acquisition timeout | 10 elapsed seconds |

Position may remain usable when speed or course is not. Classification therefore
produces separate position and guidance eligibility rather than one all-or-nothing
Boolean.

Age comparisons use an injected wall-time source only to compare the Core
Location observation timestamp with receipt time. Disclosure and acquisition
deadlines use an injected `ContinuousClock` so wall-clock changes cannot alter
their duration.

## Recovery calculation

`ActiveLegRecoveryCalculator` is a pure, sendable domain service. Its input is:

- accepted aircraft sample;
- active-leg start and end coordinates;
- imported active-leg magnetic course; and
- `PositionCheckRecoveryPolicy`.

Its structured output is:

```swift
enum ActiveLegRecoveryOutcome: Equatable, Sendable {
    case onTrack(crossTrackMeters: Double)
    case guidance(RecoveryGuidance)
    case unavailable(RecoveryUnavailabilityReason)
}
```

Unavailable reasons include `insufficientPositionQuality`,
`insufficientMovementQuality`, `noActiveLeg`, `activeLegPassed`,
`insufficientRemainingLeg`, and `extremeDisplacement`.

### Geometry

Calculations use great-circle bearings and distances over WGS84-compatible
coordinates. For the short VFR legs represented by current flight plans, compute
cross-track and along-track distance using spherical navigation formulas, while
normalizing all angular differences into `-180°...180°`.

The on-track half-width is:

```text
max(0.2 NM, 2 × horizontal accuracy)
```

If absolute cross-track distance is within that corridor, return `onTrack` and
do not create a vector.

For a recoverable displacement, select an intercept angle based on cross-track
time at current groundspeed:

- up to 30 seconds: 20°;
- 30–120 seconds: interpolate linearly from 20° to 45°; and
- over 120 seconds: 45°.

The forward look-ahead distance is `crossTrack / tan(interceptAngle)`. The
intercept point is the corresponding along-track point ahead of the aircraft's
perpendicular projection. Reject a point behind the current along-track position.
If the computed point exceeds the leg endpoint, use the endpoint only when it
still produces a forward course with an intercept angle no greater than 45°.

Classify displacement as extreme when absolute cross-track distance exceeds the
larger of 10 NM and the active leg's total length, or when no bounded forward
solution exists for geometry that is not simply past the endpoint. This value is
a named policy, not a UI constant.

Estimated rejoin time is distance from aircraft to intercept divided by current
groundspeed. Presentation rounds course to the nearest whole degree and time to:

- nearest 5 seconds below one minute;
- nearest 10 seconds from one through five minutes; and
- nearest whole minute above five minutes.

### Magnetic conversion

Core Location course is treated as true course. The current flight-plan contract
already provides imported magnetic course but no standalone magnetic-variation
model. Derive the active leg's local true-to-magnetic correction from:

```text
true bearing(active-leg endpoints) − imported magnetic course
```

Apply the normalized correction to the true recovery bearing. This keeps the
suggested course in the same magnetic reference as cockpit planning data without
claiming a device compass heading. A future navigation-wide geomagnetic service
may replace this derivation behind the same conversion interface.

## Position Check state machine

Add `PositionCheckState` to scene-owned cockpit presentation state, not to
`Flight`:

```swift
enum PositionCheckState: Equatable, Sendable {
    case idle
    case acquiring(request: Request)
    case active(session: Session)
    case signalLost(session: Session)
    case transientFailure(Failure)
}
```

The state machine accepts typed intents:

- `holdCompleted`;
- `cancel`;
- `restartHoldCompleted`;
- `locationAvailabilityChanged`;
- `activeLegChanged`;
- `sceneBecameInactive`;
- `cockpitDismissed`; and
- `deadlineReached`.

`Request` and `Session` carry opaque generation IDs. Deadline tasks send their ID
back with the event; stale task completions are ignored. Starting, restarting,
cancelling, terminating, or replacing a session cancels its existing task.

`Session` holds only the disclosure deadline, current eligible projection, and
pre-check `CockpitMapRestoration`. It does not write the GPS sample into `Flight`
or history.

Each `CockpitFeatureView` scene owns its `PositionCheckCoordinator`. The shared
location service may feed several coordinators, but each coordinator owns its
own state machine, clock tasks, camera snapshot, and disclosure decision.

## App and permission coordination

The app-level composition root owns the location service and injects it into the
cockpit feature. Start monitoring only when all are true:

- the cockpit section is presented;
- a flight exists; and
- the app scene is active.

Stop the stream when those conditions cease. Scene transition away from `.active`
first terminates disclosure and then stops foreground acquisition.

Permission education is a small pre-cockpit presentation controlled by app state.
The Core Location adapter remains responsible only for requesting When-In-Use
authorization and reporting its result. Opening system Settings is a view-level
environment action triggered by a typed intent.

## Presentation projection

Add a `PositionCheckPresentation` projection beside existing cockpit/map
presentation data. It contains display-ready state only:

- readiness label, symbol, and control eligibility;
- hold-progress semantics;
- countdown value;
- aircraft coordinate, uncertainty radius, and optional true course;
- structured recovery result with rounded magnetic course, time, and distance;
- intercept coordinate and vector eligibility; and
- transient explanation and remedy.

Views do not classify quality, select an intercept, convert magnetic course, or
calculate time.

## Map integration

Extend `AviationMapPresentation` with an optional GPS disclosure overlay that is
`nil` outside an active check. Extend `OfflineAviationMapView` source and layer
management with stable IDs for:

- restrained uncertainty area;
- compact aircraft position/directional symbol;
- dashed recovery line; and
- intercept marker.

The overlay must not introduce a large opaque aircraft-position container. Its
symbol and uncertainty treatment preserve chart legibility and coexist with the
existing right-side map toolbar, drift-line toggle, leg header, chart action, and
map callouts.

No MapLibre user-location puck is enabled. The app owns these layers so their
visibility is governed strictly by Position Check state rather than MapLibre's
continuous location presentation.

On activation, capture the existing `CockpitMapRestoration` values before issuing
a Position Check focus request. Fit aircraft and intercept with safe insets that
exclude cockpit instruments. On every termination path, restore the snapshot
atomically and change the map identity only when the existing map bridge requires
it.

The overlay update path updates GeoJSON/source data without rebuilding the whole
map style for every fix.

## SwiftUI integration

Add a dedicated `PositionCheckControl` and `PositionCheckStatus` rather than
growing `CockpitView`'s existing map-control helper with state-machine logic.
Place them in the lower cockpit control panel beside the established arrival
actions, including `Waypoint Identified`; do not add Position Check to the map
toolbar. The controls receive projection values and send intents.

The normal-state control communicates readiness and the hold requirement without
revealing position. During disclosure, the same console location carries the
countdown and explicit end action, so activation does not add another floating
map button.

The hold gesture uses a zero-distance long press with an approximately one-second
minimum duration and visible progress driven by gesture state. Only successful
completion sends `holdCompleted`. Haptics run after the state machine accepts the
request.

The active overlay and guidance card follow the approved Figma hierarchy. They
must use semantic colors and SF Symbols, retain text labels, support Dynamic Type,
and expose a stable accessibility order. VoiceOver announcements are emitted only
for state changes and materially changed rounded guidance.

## Determinism and testing

All domain policies accept plain values and have no dependency on Core Location,
MapLibre, SwiftUI, global clocks, or device state.

Required unit coverage:

- every quality boundary, including negative Core Location accuracy values;
- stale and out-of-order fixes;
- on-track corridor expansion from horizontal accuracy;
- left and right shallow intercepts;
- 20°, interpolated, and 45° intercept selections;
- endpoint fallback and rejection;
- past-leg and extreme-displacement outcomes;
- true-to-magnetic normalization across 0°/360°;
- guidance suppression with position still available;
- every state-machine transition and stale deadline event;
- exact acquisition and disclosure deadlines with a controllable clock;
- active-leg, scene, and cockpit termination; and
- independent disclosure state across two coordinators.

Use `AircraftLocationSource` test doubles to feed deterministic samples and
authorization events. UI tests use launch arguments or an injected fixture source
to reproduce Ready, Acquiring, Active guidance, On track, Signal lost, Permission
Required, and Unavailable states without relying on live simulator GPS.

Simulator validation covers the product-spec device/orientation matrix and
compares each required state with the exact approved Figma node. Hardware
verification is still required before release for real airborne acquisition,
haptics, permission changes, and signal degradation.

## Delivery slices

After paired product/Figma approval, implementation should be split into focused
tickets in dependency order:

1. location acquisition, quality policy, and permission readiness;
2. deterministic active-leg recovery calculation;
3. Position Check state machine and scene lifecycle;
4. MapLibre disclosure overlays and camera restoration;
5. SwiftUI control, countdown, failures, and accessibility;
6. deterministic UI fixtures, complete simulator matrix, and hardware checklist.

The first four tickets may establish internal seams, but no ticket is considered
product-complete until the approved visual state it owns is implemented and
validated.
