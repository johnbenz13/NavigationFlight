# Position Check — Product Specification

Status: approved paired product/design baseline; implementation not started.

## Summary

Position Check gives a pilot an explicitly requested, time-bounded view of the
device's GPS position during an active flight without turning NavigationFlight's
normal cockpit into a moving-map navigator. When trustworthy data is available,
the check also provides a conservative suggested course and estimated time to
rejoin the active leg.

Position Check is a situational-awareness aid. It is not certified navigation
equipment, an emergency function, or a guarantee of aircraft position.

## Goals

- Preserve manual map, timer, and heading navigation as the default experience.
- Let the pilot deliberately reveal GPS position for ten seconds when needed.
- Communicate whether Position Check is ready before the pilot needs it.
- Offer conservative, uncertainty-aware guidance toward the active leg.
- Leave clean extension points for future flight recording and an opt-in CFI
  safety mode without shipping either behavior now.

## Non-goals

This release does not:

- show GPS position, course, groundspeed, accuracy, or recovery information
  during normal navigation;
- automatically reveal position or intervene when the aircraft is off track;
- mark a navigation target reached or change flight progression from GPS data;
- provide an aircraft heading, wind correction, turn path, or aircraft-performance
  model;
- record, persist, export, analyze, or retrospectively display GPS fixes or
  Position Check activations;
- request background location access;
- expose settings for check duration or recovery-policy thresholds; or
- provide Position Check outside an active cockpit flight.

## Figma

- Stable proposal: [NavigationFlight — Position Check](https://www.figma.com/design/hllTgfGTAG4cEXyqiDesSu)
- Before activation: [Iteration 02A · Before Position Check · Complete Cockpit · iPad Pro 11-inch Portrait](https://www.figma.com/design/hllTgfGTAG4cEXyqiDesSu?node-id=9-271)
- Active disclosure: [Iteration 02B · Active Position Check · Complete Cockpit · iPad Pro 11-inch Portrait](https://www.figma.com/design/hllTgfGTAG4cEXyqiDesSu?node-id=9-382)
- State, transition, recovery, accessibility, and responsive coverage:
  [Iteration 03 · Position Check State & Flow Coverage](https://www.figma.com/design/hllTgfGTAG4cEXyqiDesSu?node-id=16-9)
- Secondary layout:
  [Iteration 03 · Active Position Check · iPad Pro 11-inch Landscape](https://www.figma.com/design/hllTgfGTAG4cEXyqiDesSu?node-id=17-54)
- Compact layout:
  [Iteration 03 · Active Position Check · iPhone 16 Pro Portrait](https://www.figma.com/design/hllTgfGTAG4cEXyqiDesSu?node-id=17-112)
- Permission, failure, and Dynamic Type presentations:
  [Iteration 03 · Edge Presentations](https://www.figma.com/design/hllTgfGTAG4cEXyqiDesSu?node-id=18-6)
- Review cover: [Position Check review status](https://www.figma.com/design/hllTgfGTAG4cEXyqiDesSu?node-id=3-10)
- Approved product-spec revision:
  [68e68e7](https://github.com/johnbenz13/NavigationFlight/blob/68e68e79e3013aa240fe12a2046b57dc227722ae/docs/features/POSITION-CHECK_SPEC.md)
- Main-screen slice: the complete cockpit immediately before activation, paired
  with the same cockpit during an active ten-second Position Check.
- Design status: `approved`.
- Approved direction: Iteration 02A/02B, covering the complete cockpit before
  activation and during active disclosure.
- Direction approver: John (feature owner), 2026-11-03.
- Candidate complete iteration: Iteration 03, extending the approved Iteration
  02 direction across all specified states, outcomes, accessibility behavior,
  and supported device-orientation baselines.
- Paired-baseline approval: approved by John (feature owner), 2026-11-03.
- Approved product revision:
  [68e68e7](https://github.com/johnbenz13/NavigationFlight/blob/68e68e79e3013aa240fe12a2046b57dc227722ae/docs/features/POSITION-CHECK_SPEC.md).

## Device and orientation baseline

| Priority | Device class | Orientation | Purpose |
| --- | --- | --- | --- |
| Primary | iPad Pro 11-inch | Portrait | Main design, review, and implementation target. |
| Secondary reference | iPad Pro 11-inch | Landscape | Canonical wide-layout adaptation. |
| Secondary reference | iPhone 16 Pro | Portrait | Canonical compact-width adaptation. |
| Secondary coverage | Other supported iPhones in the iPhone 16 generation or later | Portrait only | Confirm compact-layout adaptation. |

iPhone landscape is intentionally unsupported by this design baseline.

## Terminology

- **Position Check** is the deliberate, temporary disclosure of GPS-derived
  position and any eligible recovery guidance.
- **GPS fix** is a device-reported location with an observation time and
  horizontal accuracy.
- **GPS course** is course over ground derived from trustworthy movement data.
  It is not aircraft heading.
- **Recovery course** is a suggested magnetic course toward an appropriate
  forward intercept on the active leg. The pilot remains responsible for wind
  correction and aircraft control.
- **Intercept point** is the selected forward point on the active leg used for
  recovery guidance. It is not necessarily the geometrically closest point.
- **On-track corridor** is the uncertainty-aware area in which no recovery
  correction is recommended.
- **CFI safety mode** is a possible future opt-in feature that may detect
  sustained loss of track and intervene automatically. It is not Position Check.

## Behavior

### Normal cockpit behavior and readiness

1. Normal cockpit navigation does not show or expose GPS-derived position,
   course, groundspeed, accuracy, cross-track displacement, recovery course,
   recovery time, or intercept point.

2. The app may acquire location while an active cockpit flight is visible so it
   can evaluate Position Check readiness and respond promptly to a request.
   Acquisition starts for the active cockpit flight and stops when that flight
   ends or the cockpit is dismissed.

3. This release requests only **While Using the App** location authorization.
   Permission is explained and requested before cockpit use rather than at the
   moment of an urgent Position Check request. Declining permission does not
   prevent manual cockpit navigation.

4. A persistent, non-position-revealing status remains visible in the active
   cockpit and communicates one of four actionable states: **Ready**,
   **Acquiring**, **Unavailable**, or **Permission Required**.

5. **Ready** means the app has a recent fix satisfying the Position Check quality
   policy. Enabled location services or authorization alone are insufficient.

6. Airplane mode, disabled location services, denied or restricted permission,
   temporary signal loss, stale data, and insufficient accuracy remain distinct
   causes even when several causes share the same concise pilot-facing state.

7. The readiness status does not reveal raw accuracy, location, movement, or
   deviation information before activation.

8. Status and control states use symbols and text in addition to color. The
   experience does not rely on a red/green distinction.

9. The feature is named **Position Check**. **GPS** appears in readiness and
   failure explanations when it identifies the underlying cause.

### Activation and acquisition

10. Position Check is available only within an active cockpit flight. It is not
    present on flight-plan library, inspection, or preview maps.

11. The Position Check control remains visible when GPS is unavailable. Its
    unavailable presentation explains the cause and any remedy instead of hiding
    the feature.

    The control is integrated into the lower cockpit console alongside the
    existing arrival actions. It is not part of the map toolbar and does not
    cover the chart in the normal cockpit state. Existing cockpit actions,
    including **Waypoint Identified**, remain present and retain their established
    hierarchy.

12. When permission is denied or restricted, the explanation offers a route to
    system Settings and does not repeatedly show permission prompts during flight.

13. Activation requires an approximately one-second press and hold. The control
    visibly communicates hold progress and gives haptic confirmation when the
    request is accepted. Sound is not required.

14. A tap, an incomplete hold, map interaction, or any other cockpit action does
    not disclose GPS-derived information.

15. If a usable fix already exists, accepted activation begins a ten-second
    Position Check immediately.

16. If GPS is still acquiring, accepted activation shows a cancellable
    **Acquiring GPS…** state. The ten-second disclosure countdown does not begin
    until a usable fix arrives.

17. Acquisition fails after ten seconds without a usable fix. The app returns to
    the normal undisclosed cockpit, explains that GPS is unavailable, and allows
    the pilot to try again.

18. The pilot may cancel acquisition at any time. Cancellation reveals no
    position and restores the normal cockpit presentation.

### Active Position Check

19. A successful Position Check lasts exactly ten elapsed seconds unless the
    pilot ends it or a terminating condition occurs earlier.

20. The active presentation visibly counts down the remaining disclosure time
    using a restrained label such as **Position Check · 8s**.

21. During the window, the map shows the current GPS position and reported
    uncertainty. When uncertainty is materially significant, it is represented
    by an accuracy area around the position.

22. When trustworthy GPS course is available, the aircraft symbol points along
    course over ground. Otherwise the map uses a neutral, non-directional
    position marker and does not imply aircraft heading.

    The directional presentation uses a compact aircraft symbol with a restrained
    accuracy halo. It must not use a large opaque position card, block, or marker
    that obscures operational chart detail.

23. Position, uncertainty, recovery solution, and displayed estimates update
    from fresh valid fixes throughout the disclosure window. Presentation is
    stabilized so ordinary measurement noise does not cause distracting jumps.

24. The map automatically frames the aircraft and applicable intercept point
    while preserving a snapshot of the pilot's pre-check camera, orientation,
    focus, and callout context.

25. The pilot may pan and zoom during the check. Interaction does not pause or
    extend the deadline, and map changes made in this temporary mode are discarded
    when the check ends.

26. A visible close action ends the check immediately, removes every GPS-derived
    element, and restores the complete pre-check map context.

27. Another completed press and hold during an active check deliberately restarts
    one ten-second window. Timers do not stack.

28. Expiration removes GPS-derived information at the ten-second boundary. A
    brief transition may soften the visual change but must not leave the position
    or guidance readable beyond the deadline.

29. Expiration restores the exact pre-check map context, including after the
    pilot panned or zoomed during the check.

30. Moving the app to the background, locking the device, leaving the cockpit,
    losing the active flight, or changing the active leg ends the check
    immediately. Returning requires a new deliberate activation.

31. The disclosure deadline is based on elapsed time and is unaffected by
    wall-clock changes, UI redraws, or temporary rendering stalls.

32. Each cockpit scene owns its own activation, countdown, temporary camera
    state, and restoration snapshot. One iPad window does not disclose or dismiss
    Position Check in another window.

### GPS degradation during a check

33. If the current fix becomes stale or unusable during an active check, the app
    immediately removes the stale position and recovery vector rather than
    presenting them until expiration.

34. After degradation, the active check shows **GPS signal lost** and continues
    its original countdown. A later valid fix may restore the active presentation
    only within that same unextended window.

35. If position remains usable but movement data cannot support stable guidance,
    the map may continue showing position and uncertainty while stating
    **Position available — recovery guidance unavailable**.

36. A detailed transient failure message may clear after a short period, but the
    persistent readiness indicator continues to communicate the underlying state.

### Recovery guidance

37. Recovery guidance is evaluated only against the active leg. The app never
    chooses a geographically closer previous or future leg.

38. The preferred intercept is an appropriate point ahead on the active leg, not
    automatically the perpendicular closest point. Small deviations produce a
    shallow correction; larger recoverable deviations may produce a stronger
    correction.

39. The suggested intercept angle never exceeds 45 degrees. Modest deviations
    ordinarily use an intercept of approximately 20–30 degrees so a nearby
    aircraft is not directed into an unnecessary 90-degree return.

40. The intercept policy accounts for cross-track displacement, current
    groundspeed, remaining active-leg geometry, reported uncertainty, and the need
    for a prompt but stable rejoin.

41. Inside the on-track corridor, the app shows **On track** instead of a recovery
    vector. The corridor is at least a fixed practical width and expands when GPS
    uncertainty would make a narrower recommendation misleading.

42. When guidance is valid, the map draws a clearly differentiated dashed vector
    from the aircraft to the selected intercept point. It does not draw or imply a
    simulated aircraft turn path.

43. Text guidance identifies the recommendation as **Steer** or **Suggested
    course**, not as measured aircraft heading.

44. Recovery course is shown as magnetic, with an explicit `°M` suffix. The pilot
    remains responsible for wind correction and aircraft control.

45. **Rejoin in** means estimated time to the selected intercept point at current
    GPS groundspeed. It is not time to destination or a guarantee of becoming
    stabilized on the planned course.

46. Recovery time is prioritized in the active presentation. Distance may appear
    as supporting information in nautical miles.

47. Course and time use pilot-friendly rounding and update only when changes are
    meaningful. The vector may move more smoothly than the textual values.

48. Guidance is withheld when the fix is stale, horizontal accuracy is
    insufficient, directional quality is poor, groundspeed is too low, or any
    required input cannot support a trustworthy solution.

49. If no active leg can be resolved, Position Check may still show usable
    position for the remainder of its window but explicitly states that recovery
    guidance is unavailable.

50. Near the active-leg endpoint, an intercept may target the endpoint only when
    it remains a sensible forward solution within the 45-degree limit. Position
    Check does not automatically advance flight progression.

51. If the aircraft has passed the active leg or no sensible forward intercept
    remains, the app does not direct the pilot backward. It shows **Active leg
    passed — review flight plan** or an equivalent explicit unavailable state.

52. At extreme displacement, Position Check still shows a usable position but
    withholds tactical **Steer** and time guidance. It shows **Outside
    recovery-guidance range — review navigation** rather than manufacturing a
    confident solution.

53. Position Check never identifies or reports an identification point or
    waypoint reached, changes a timer, edits a heading or ETA, advances a leg, or
    modifies pilot-authored and historical observations.

### Accessibility and pilot feedback

54. The Position Check control has an explicit accessibility label and hint that
    describe the hold requirement and temporary GPS disclosure.

55. VoiceOver announces accepted activation, acquisition, meaningful guidance
    changes, restrained countdown milestones, GPS loss, and dismissal. It does not
    announce every location update.

56. Symbols, labels, guidance, countdown, errors, and close controls remain usable
    with supported Dynamic Type sizes and sufficient contrast.

57. The control is visually separated from ordinary map controls but is not styled
    as destructive, certified emergency equipment, or the primary means of
    navigation. It remains in the lower cockpit console while established map
    controls, the drift-line toggle, and adjacent cockpit actions remain
    available. A shield/location treatment may communicate its safety-aid role.

58. The feature remains operable in iPad portrait and landscape and in supported
    iPhone portrait layouts. All layouts preserve the same activation and
    disclosure semantics.

### Privacy and future extension

59. This release keeps fixes in volatile memory only. It does not create a GPS
    track, activation history, analytics event, debrief record, or exported data.

60. The absence of recording in this release must not prevent a future,
    explicitly enabled flight recorder from consuming the same location stream.
    Future recording consent, persistence, background access, and debrief behavior
    require their own product contract.

61. The ten-second disclosure duration and GPS/recovery thresholds are named
    product policies that can become configurable later. This release exposes no
    settings UI and always uses the fixed approved policies.

62. Automatic CFI intervention is separate from manual Position Check. This
    release contains no dormant threshold that automatically reveals position,
    alerts the pilot, or enters safety mode.

63. Recovery outcomes preserve structured reasons such as on track, insufficient
    data, no active leg, active leg passed, insufficient remaining leg, and
    extreme displacement so a future safety policy can respond without deriving
    meaning from display text.

64. A future CFI safety mode may consume the same location, active-flight, and
    recovery capabilities, but it requires explicit pilot enablement and its own
    visible intervention, disclosure, exit, and acceptance rules.
