# Progression Policy — As-Is Product Specification

Status: reverse-engineered specification of the current work-in-progress behavior as of 2026-10-22.

This document describes the behavior that Navigation Flight currently implements. Normative language such as **must** records observed behavior; it does not approve that behavior as the final product design. Original intent and historical context are explicitly non-normative.

## Scope

This specification covers the progression policy applied when a pilot completes a navigation leg at an intermediate waypoint. It covers:

- automatic and manual progression;
- leg selection, state, and timing transitions;
- Planned, Revised, Reference, and Actual ETA behavior relevant to completing a leg;
- cockpit, map, checklist, and previous-leg-summary effects;
- current configuration and availability;
- rejected transitions and edge cases; and
- confirmed differences between the original intent and the current implementation.

The specification is intentionally focused. It may later be incorporated into a broader cockpit or flight-execution specification.

It does not define a future settings experience, a future per-flight preference model, persistence requirements, or changes to the existing feature.

## Terminology

In Navigation Flight, **ETA** refers to elapsed time from the beginning of a leg to a target, not a clock time of arrival.

- **Leg**: A planned flight segment from a departure waypoint to an arrival waypoint.
- **Initial leg**: The first leg flown in a navigation session.
- **Intermediate waypoint**: A waypoint that is both the arrival waypoint of the departing leg and the departure waypoint of a successor leg.
- **Final waypoint**: The arrival waypoint of the final leg. It has no successor leg.
- **Current/displayed leg**: The leg whose course, heading, altitude, timing, map, and other information the cockpit presents.
- **Actively timed leg**: A leg whose timer is running and whose session state is active.
- **Planned ETA**: The imported, precomputed elapsed time from leg start to a target. The app selects the no-wind or with-wind value belonging to the current execution mode.
- **Revised ETA**: An optional elapsed time manually calculated, adjusted, and committed by the pilot during the flight.
- **Reference ETA**: An elapsed time independently computed by the app and displayed only when the pilot requests a comparison. It is not the pilot's Revised ETA.
- **Actual ETA**: The elapsed time actually taken to reach a target, derived from the target's reach timestamp minus the leg's start timestamp.
- **Destination identification**: The pilot's report that the arrival waypoint has been visually identified. This is distinct from reaching that waypoint.

## Operational rationale — original intent (non-normative)

The progression policy was introduced to model the two procedures a pilot may use when handing off from one leg to the next with a physical map and timer.

In both procedures, the pilot reports reaching the arrival waypoint. This stops the departing leg's timer, completes that leg, and gives the pilot its Actual ETA for later comparison with the Planned ETA or an optional Revised ETA.

With automatic progression, the successor leg's timer starts at the exact moment the departing leg's timer stops. The waypoint is treated as a single, atomic timing boundary.

With manual progression, the intended procedure is:

1. The pilot reports reaching the arrival waypoint, completing the departing leg and stopping its timer.
2. The cockpit displays the successor leg, but its timer is not running.
3. The pilot maneuvers around the waypoint and establishes the next heading.
4. When crossing the waypoint as the successor leg's departure point, the pilot explicitly starts that leg's timer.

The initial leg has no preceding-leg handoff, so the pilot explicitly starts its timer at the departure waypoint. The final leg has no successor, so reaching its arrival waypoint stops timing and completes navigation.

The original intent also anticipated a user preference in settings and a possible per-flight preference. Neither preference surface currently exists.

## Current configuration and availability

The current feature supports two policies:

- **Automatic next leg**
- **Manual next leg**

The selected policy must remain unchanged during a flight.

Current release builds always select automatic progression. A user cannot currently select or change the policy through the product UI.

The current implementation selects the policy when the cockpit feature state is created. That immutable selection is passed into every flight session subsequently created by that feature state. It is therefore currently reused across newly imported flights within the same feature-state lifetime, rather than being selected independently for each flight.

Debug builds may select manual progression through a process environment override. Tests may inject either policy directly. These are development mechanisms, not user-facing capabilities.

## Current behavioral requirements

### Applicability

The progression policy must be consulted only after a successful reach report for an active, non-final leg.

It must not affect:

- starting the initial leg;
- reaching an identification point within a leg;
- identifying the destination;
- recording completion of the departing leg;
- selecting the successor as the current/displayed leg; or
- completing the final leg.

### Shared intermediate-waypoint behavior

For either policy, successfully reporting the active leg's arrival waypoint reached must:

1. Record the supplied timestamp as the departing leg's reach timestamp.
2. Complete timing for the departing leg without modifying its start timestamp.
3. Preserve whether a separate destination-identification timestamp exists.
4. Derive the departing leg's Actual ETA from its reach timestamp minus its start timestamp.
5. Advance the successor leg to become the current/displayed leg.
6. Update the cockpit and map to present the successor leg's flight information.
7. Hide the departing leg's start checklist without marking an unnoted checklist as noted.
8. Preserve all previously recorded leg and target timing information.

### Automatic progression

After the shared intermediate-waypoint behavior, automatic progression must:

1. Start the successor leg using the same timestamp that completed the departing leg.
2. Make the successor leg actively timed immediately.
3. Create a timing record for the successor leg.
4. Create the successor leg's pending start checklist immediately.
5. Continue displaying a running elapsed timer without an untimed interval between legs.

The departing leg's reach timestamp and the successor leg's start timestamp must be equal.

### Manual progression

After the shared intermediate-waypoint behavior, manual progression must:

1. Make the successor the current/displayed leg immediately.
2. Leave the successor ready rather than actively timed.
3. Create no timing record for the successor until the pilot explicitly starts it.
4. Display Start Leg instead of a running successor timer.
5. Create no successor start checklist until the pilot explicitly starts the leg.

When the pilot later starts the successor leg, the app must use that new start timestamp, make the leg actively timed, and create its pending start checklist. The interval between the departing leg's reach timestamp and the successor leg's start timestamp is intentionally untimed.

The manual policy provides the timing pause. It does not itself observe aircraft maneuvering, detect a waypoint crossing, or provide controls for changing flight parameters.

### Final-leg completion

When the pilot reports the final waypoint reached, the app must:

1. Record the final leg's reach timestamp.
2. Derive its Actual ETA.
3. Complete navigation.
4. Start no successor timing.
5. Display Navigation Complete.

The selected progression policy must have no effect because no successor leg exists.

## State-transition table

| Boundary | Trigger | Departing leg result | Current/displayed leg | Timing state after transition |
| --- | --- | --- | --- | --- |
| Initial leg | Pilot selects Start Leg | Not applicable | Initial leg | Initial leg becomes actively timed at the supplied start timestamp |
| Intermediate waypoint, automatic | Pilot reports the waypoint reached | Completed with Actual ETA | Successor leg | Successor becomes actively timed at the departing leg's reach timestamp |
| Intermediate waypoint, manual | Pilot reports the waypoint reached | Completed with Actual ETA | Successor leg | Successor remains ready with no timer until Start Leg |
| Manual successor start | Pilot selects Start Leg | Previous leg remains completed | Successor leg | Successor becomes actively timed at the new start timestamp |
| Final waypoint | Pilot reports the waypoint reached | Final leg completed with Actual ETA | Final leg/navigation completion | Navigation is completed; no leg timer runs |

## Timing and ETA behavior

### Actual ETA

The pilot reports that a target has been reached; the app must measure Actual ETA automatically. The app must store the absolute reach timestamp and derive Actual ETA as:

```text
Actual ETA = target reach timestamp - leg start timestamp
```

For a destination, reaching the waypoint completes the leg regardless of progression policy. For an identification point, the observation does not complete the leg.

### Planned ETA

Planned ETA must come from the imported execution data for the current mode. The app currently consumes precomputed no-wind or with-wind timing rather than calculating flight-plan wind timing in the cockpit.

### Revised ETA

Revised ETA must remain a pilot-authored value. The app initializes an editable value from Planned ETA, permits the pilot to adjust it, and records it only when the pilot commits it. A Revised ETA may not exist if the pilot never commits one.

### Reference ETA and on-demand comparison

After the pilot reports an identification point reached, the app knows the identification point's Actual ETA. For a later target, the app can independently calculate a Reference ETA by proportionally applying observed schedule performance:

```text
Reference ETA = Planned target ETA × Actual identification-point ETA
                ----------------------------------------------------
                       Planned identification-point ETA
```

The pilot remains solely responsible for calculating and entering Revised ETA. The app must reveal its Reference ETA only when the pilot requests **Check**. The comparison must display:

- the pilot's Revised ETA;
- the app's Reference ETA; and
- the difference between them.

The Reference ETA must not overwrite, commit, or otherwise modify the pilot's Revised ETA. The current computation is a proportional timing reference; it is not a new wind calculation.

### Completed-leg comparison

The previous-leg summary must display:

- Planned ETA;
- Revised ETA, when one was committed for the destination;
- Actual ETA; and
- the applicable difference.

Actual ETA must be compared with Revised ETA when a committed Revised ETA exists. Otherwise, Actual ETA must be compared with Planned ETA.

## Cockpit-visible effects

### Destination identification and reach

Destination identification and waypoint reach are separate pilot observations.

While an active destination has not been identified, the cockpit must offer both:

- **Waypoint Identified**, which records identification without completing the leg; and
- **Reached now**, which completes the leg without recording a separate identification timestamp.

After the pilot selects Waypoint Identified, the cockpit must replace those actions with **Waypoint Reached**. Selecting Waypoint Reached completes the leg.

Both reach paths must record Actual ETA and apply the selected progression policy. Reaching without prior identification must leave the destination-identification timestamp absent; the app must not infer or fabricate it from the reach timestamp.

### Successor presentation

Under both policies, completing an intermediate leg must immediately make the successor the current/displayed leg so that the pilot can focus on its heading, altitude, course, map, and other flight information.

Under automatic progression, the successor must also be actively timed and have its pending start checklist available immediately.

Under manual progression, the successor must display Start Leg, have no running timer, and have no successor start checklist until the pilot starts it.

## Rejected transitions and edge cases

The app must reject a waypoint-reach transition when:

- there is no active leg;
- the active leg has no timing record;
- the active leg's waypoint has already been reached; or
- the supplied reach timestamp precedes the leg's start timestamp.

A rejected transition must not advance the current/displayed leg or replace recorded timing.

Starting a leg that is already active or has already been started must be rejected. Attempting to start another leg after final navigation completion must also be rejected.

## Session lifetime and persistence boundary

The current flight session holds progression state, leg start and reach timestamps, derived Actual ETA values, and pilot Revised ETA state in memory.

This specification makes no claim that those values survive app termination, feature-state recreation, or flight-session recreation. Product requirements for durable session persistence have not yet been defined.

## Confirmed intent/current-implementation discrepancies

These observations describe the current WIP boundary. They are not defect classifications, recommendations, or promises of future behavior.

| Original intent | Current implementation |
| --- | --- |
| The pilot may eventually choose a general progression preference. | Release builds always use automatic progression; no settings control exists. |
| A flight may eventually override the general preference. | No per-flight selection exists. The feature-state policy is reused for subsequently imported flights. |
| The policy remains stable during a flight. | The policy is immutable for the broader feature-state lifetime, which is stricter than the intended per-flight rule. |
| Manual progression gives the pilot time to maneuver and establish the next heading before starting timing. | The timing pause exists, but the policy itself neither observes the maneuver nor supplies parameter-editing controls. |
| The pilot uses identification-point timing and in-flight conditions to calculate Revised ETA. | The pilot manually adjusts and commits Revised ETA. The app supplies Actual ETA and an optional on-demand proportional Reference ETA; it does not perform a new wind calculation. |

## History and provenance (non-normative)

`FlightSession` was created on 2026-10-11 in commit `2976515f97ca8bbc5e2bee25612fd7e2ee5ebdaa` (`Add flight session leg timer foundation`). It initially supported only ready/active state, selecting a leg, starting a timer, and reading elapsed time. It had no progression policy, waypoint completion, timing history, or multi-leg advancement.

The progression policy was introduced on 2026-10-13 in commit `74bb3e554247e0ba8e8adbea05d478baa1cda853` (`Add waypoint progression and map turn transition`). That commit added both policies, waypoint completion, leg timing history, multi-leg advancement, map transition behavior, the automatic default, the debug override, and the original policy tests.

Commit `72c35655b6f7588e369fdc9007e897a9c2556559` on 2026-10-16 (`Add start-of-leg checklist`) integrated progression with the successor checklist. Commit `5a4507058eae21ca54fe2a200eeafcdf05b1feb4` later that day (`Refine leg start checklist`) refined the corresponding manual-progression behavior and tests.

The policy's core contract has not changed since its introduction.

## Implementation and test traceability (non-normative)

Future technical documentation under `docs/tech` or `docs/components` may describe these implementations in detail and link back to this product specification.

Current implementation sources:

- `NavigationFlight/Domain/Flight/FlightSession.swift`
- `NavigationFlight/Features/Cockpit/CockpitFeatureState.swift`
- `NavigationFlight/Features/Cockpit/CockpitFeatureView.swift`
- `NavigationFlight/Features/Cockpit/CockpitPresentationAdapter.swift`
- `NavigationFlight/Features/Cockpit/CockpitView.swift`
- `NavigationFlight/Map/AviationMapPresentation.swift`
- `NavigationFlight/Map/OfflineAviationMapView.swift`

Representative behavioral tests in `NavigationFlightTests/NavigationFlightTests.swift`:

- `automaticWaypointProgressionUsesOneAtomicTimestamp`
- `manualWaypointProgressionWaitsForASecondStartTimestamp`
- `reachingWithoutIdentificationDoesNotFabricateIdentification`
- `cockpitFeatureStateAdvancesPresentationInManualMode`
- `automaticProgressionCreatesFreshPendingChecklistForNewLeg`
- `manualProgressionWaitsUntilStartBeforeCreatingChecklist`
- `reachedNowHidesPendingChecklistWithoutFabricatingNoted`

The UI path for Waypoint Identified, Reached now, Waypoint Reached, and final completion is exercised in `NavigationFlightUITests/NavigationFlightUITests.swift`.
