# Cockpit Operational Cues — Product Specification

Status: complete paired product/design baseline approved.

## Summary

NavigationFlight keeps the display awake during a Flight and makes planned frequency and altitude changes understandable in the lower cockpit console. The cues describe the Flight Plan; they do not use GPS for normal progression, require pilot acknowledgement, or act as a checklist.

## Goals

- Prevent the device from sleeping while a Flight is ready or active.
- Make the planned current and next frequencies distinguishable without hiding the complete frequency list.
- Show the current and next planned altitude targets and clearly indicate when a planned change becomes due.
- Preserve the pilot as navigation authority and preserve Check Position as the only normal GPS disclosure.

## Non-goals

- Automatically detecting the aircraft's real position or whether a change was performed.
- Requiring confirmation, acknowledgement, or checklist completion.
- Adding sounds, haptics, notifications, modal alerts, or new map interactions.
- Changing Flight Plan data, route annotations, pilot progression controls, or Check Position behavior.
- Replaying cues that became due while the cockpit was not visible or after a leg was manually completed.

## Figma

- Stable proposal: [NavigationFlight — Cockpit Operational Cues](https://www.figma.com/design/ZTfeKXbhjsqvZMagg9JPyq)
- Main-screen direction: [Direction 01 · iPad portrait](https://www.figma.com/design/ZTfeKXbhjsqvZMagg9JPyq?node-id=2-7)
- Main-screen frame: [Active leg · change pending](https://www.figma.com/design/ZTfeKXbhjsqvZMagg9JPyq?node-id=2-8)
- Direction notes: [Review notes](https://www.figma.com/design/ZTfeKXbhjsqvZMagg9JPyq?node-id=2-76)
- Approved direction: `Direction 01 · iPad Pro 11-inch portrait` by John — 2026-11-03
- Approved complete iteration: [Iteration 02 · Complete operational cue coverage](https://www.figma.com/design/ZTfeKXbhjsqvZMagg9JPyq?node-id=5-2)
- Approved state flow:
    - [Accepted Flight · ready preview](https://www.figma.com/design/ZTfeKXbhjsqvZMagg9JPyq?node-id=5-8)
    - [Active leg · change pending](https://www.figma.com/design/ZTfeKXbhjsqvZMagg9JPyq?node-id=5-79)
    - [Simultaneous frequency and altitude change due](https://www.figma.com/design/ZTfeKXbhjsqvZMagg9JPyq?node-id=5-150)
    - [Resolved state and background return](https://www.figma.com/design/ZTfeKXbhjsqvZMagg9JPyq?node-id=5-222)
- Approved adaptive and accessibility coverage:
    - [iPad Pro 11-inch landscape](https://www.figma.com/design/ZTfeKXbhjsqvZMagg9JPyq?node-id=6-5)
    - [iPhone 16 Pro portrait](https://www.figma.com/design/ZTfeKXbhjsqvZMagg9JPyq?node-id=6-49)
    - [iPhone portrait · Larger Text](https://www.figma.com/design/ZTfeKXbhjsqvZMagg9JPyq?node-id=6-82)
    - [Reduce Motion · simultaneous change due](https://www.figma.com/design/ZTfeKXbhjsqvZMagg9JPyq?node-id=6-109)
- Coverage audit: [30 product invariants traced](https://www.figma.com/design/ZTfeKXbhjsqvZMagg9JPyq?node-id=6-139)
- Design status: `approved`
- Paired-baseline approver: John
- Paired-baseline approval date: 2026-11-03
- Approved product-spec revision: documentation checkpoint on `feature/cockpit-operational-cues`; its immutable commit permalink is recorded on GitHub issue #70 after checkpoint creation.

The primary design target is iPad Pro 11-inch portrait. Iteration 02 covers iPad Pro 11-inch landscape, iPhone 16 Pro portrait, Larger Text, and Reduce Motion. Supported iPhone portrait sizes use the same compact adaptation. iPhone landscape is unsupported.

The review file uses Inter as a preview-only fallback because SF Pro text layers did not render through the current Figma export path. Production continues to use native iOS system typography; the fallback is not a visual typography decision.

## Behavior

### Keep awake

1. From the moment a pilot accepts a Flight and enters its ready cockpit state, the device must not dim or sleep because of the system idle timer.

2. Keep-awake behavior continues while a leg is active and during ready transitions between legs in the same Flight.

3. Completing the final leg, abandoning the Flight, or otherwise leaving the accepted Flight lifecycle restores the normal system idle-timer behavior immediately.

4. Merely browsing, importing, or inspecting Flight Plans does not keep the device awake.

### Cue authority and timing

5. Frequency and altitude cues are advisory presentations of the Flight Plan. They never assert that the pilot contacted a service, tuned a radio, initiated a climb or descent, or reached an altitude.

6. GPS position never advances these cues. GPS remains available only through the deliberate Check Position safety feature.

7. A change inside an active leg becomes due when the active leg's elapsed time reaches the change's planned time in the selected navigation mode.

8. A change planned at the beginning of a leg is previewed throughout the preceding leg and becomes due when the pilot progresses to the new leg.

9. A change planned at the beginning of the first flown leg is previewed in the accepted Flight's ready state and becomes current when the pilot starts the leg.

10. A change later in a leg is previewed from the beginning of that same leg, giving the pilot the whole preceding portion of the leg to prepare.

11. If the pilot completes a leg before one of its timed changes becomes due, the new leg's correct planned values appear immediately. Missed cues do not animate or replay.

12. Returning to the cockpit after interruption immediately reconstructs the correct planned current and next values from Flight state and elapsed leg time. Changes that occurred while the cockpit was not visible do not replay their pulse.

13. Frequency and altitude changes due at the same time update and animate independently; neither suppresses the other.

### Frequencies

14. The lower console continues to display the complete ordered list of planned frequencies that it displays today.

15. At most one displayed frequency is marked `CURRENT` in green and at most one different frequency is marked `NEXT` in amber. Every other frequency retains the existing neutral treatment.

16. The `CURRENT` and `NEXT` text labels remain visible so that frequency state never depends on color alone.

17. Repeated occurrences of the same service and frequency do not create a false change. `NEXT` identifies the first later planned frequency that differs from the current one.

18. When a frequency change becomes due, the pending frequency automatically becomes `CURRENT`; the previous frequency becomes neutral and the following different frequency, when one exists, becomes `NEXT`.

19. Only the newly current frequency receives the due cue. The rest of the frequency console does not flash.

20. The newly current frequency pulses for five seconds while the cockpit is visible. No acknowledgement is required, and the new frequency remains current after the pulse ends.

### Altitude

21. The altitude instrument's primary value is the Flight Plan's current target altitude, not a measured aircraft altitude.

22. When a later altitude target exists, the instrument also shows one smaller next target with an up or down arrow indicating the planned direction of change.

23. Only the single next altitude target is shown in the lower console, even when the Flight Plan contains additional later altitude changes.

24. When an altitude change becomes due, the next target automatically becomes the primary current target and the corresponding up or down arrow pulses for five seconds.

25. After the pulse, the new target remains the primary value and the following target becomes the smaller preview when another change exists.

26. The altitude presentation never suggests that the aircraft has already reached the displayed target.

### Motion and accessibility

27. Cues are visual only. They produce no sound, haptic, system notification, modal presentation, or focus-stealing alert.

28. With Reduce Motion enabled, the five-second pulse is replaced by a static five-second highlight.

29. Current, next, direction, and due meaning remain understandable through text, value, arrow, and contrast rather than animation or color alone.

30. The frequency list and altitude values continue to support Dynamic Type without clipping operational values or hiding the `CURRENT` and `NEXT` meanings.
