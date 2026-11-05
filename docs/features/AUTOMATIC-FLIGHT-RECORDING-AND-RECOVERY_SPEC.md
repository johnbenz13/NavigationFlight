# Automatic Flight Recording and Recovery — Product Specification

Status: bounded-recovery paired baseline approved for implementation.

## Summary

NavigationFlight automatically records the physical track and navigation execution of a loaded Flight, preserves interrupted Flights so the pilot can continue them, and provides an offline **Flights** library for reviewing recording status, exporting GPX track data, and deleting recordings. Recording remains a background safety and debrief foundation: it never reveals live GPS position during normal navigation or replaces the pilot as navigation authority.

## Scope

This specification covers automatic recording from pre-takeoff movement through landing and stop, navigation-event history, background collection, interruption recovery, a persistent Flights app section, GPX export, deletion, permission and failure behavior, and recording-status disclosure.

It extends the product contract in the following deliberate ways:

- It adds **Flights** as a fourth app section after **Flight Plans** and before **Settings**.
- It supersedes the fresh-launch non-restoration behavior in [App Navigation and Flight Plans Library](APP-NAVIGATION-AND-FLIGHT-PLANS-LIBRARY_SPEC.md) for recoverable Flights.
- It supersedes the active-Flight non-restoration non-goal in [Flying a Leg](FLYING-A-LEG_SPEC.md).
- It supersedes the volatile-only, no-recording location behavior in [Position Check](POSITION-CHECK_SPEC.md), while preserving every Position Check disclosure boundary.

Where this specification does not explicitly change behavior, those existing specifications remain authoritative.

## Non-goals

The first release does not provide graphical replay, debrief analysis, cloud upload or synchronization, configurable recording settings, automatic retention cleanup, recording rename, JSON or CSV event export, or continuous raw accelerometer and gyroscope recording. It does not turn the Cockpit into a GPS navigation display, infer that the aircraft has reached a navigation target, or automatically revise pilot-authored navigation values.

## Figma

- Stable proposal: [NavigationFlight — Automatic Flight Recording and Recovery](https://www.figma.com/design/ZrGA7ZuOACWtXA4mR7cwdc).
- Design status: `approved` for Iteration 03 bounded recovery.
- Approved iteration: Iteration 03 — bounded recovery.
- Approved Iteration 03 main-screen direction: [single fresh Flight recovery gate on iPad portrait](https://www.figma.com/design/ZrGA7ZuOACWtXA4mR7cwdc?node-id=38-275).
- Iteration 03 recovery states under review: [end-incomplete confirmation](https://www.figma.com/design/ZrGA7ZuOACWtXA4mR7cwdc?node-id=42-38), [expired result](https://www.figma.com/design/ZrGA7ZuOACWtXA4mR7cwdc?node-id=42-67), [multiple-candidate selection](https://www.figma.com/design/ZrGA7ZuOACWtXA4mR7cwdc?node-id=42-96), [legacy reconciliation summary](https://www.figma.com/design/ZrGA7ZuOACWtXA4mR7cwdc?node-id=42-125), and [checkpoint failure](https://www.figma.com/design/ZrGA7ZuOACWtXA4mR7cwdc?node-id=42-154).
- Iteration 03 adaptive references under review: [iPad landscape](https://www.figma.com/design/ZrGA7ZuOACWtXA4mR7cwdc?node-id=42-183), [iPhone portrait](https://www.figma.com/design/ZrGA7ZuOACWtXA4mR7cwdc?node-id=42-202), and [Larger Text and VoiceOver](https://www.figma.com/design/ZrGA7ZuOACWtXA4mR7cwdc?node-id=42-221).
- Product-spec revision reviewed: [`14f2ed9`](https://github.com/johnbenz13/NavigationFlight/blob/14f2ed9/docs/features/AUTOMATIC-FLIGHT-RECORDING-AND-RECOVERY_SPEC.md).
- Iteration 02 human approver and approval date: John, 2026-11-04. Iteration 03 paired baseline approved by John, 2026-11-05.
- Approved main-screen direction: [Flights on iPad Pro 11-inch portrait](https://www.figma.com/design/ZrGA7ZuOACWtXA4mR7cwdc?node-id=6-2).
- Approved behavioral coverage: [product-spec coverage map](https://www.figma.com/design/ZrGA7ZuOACWtXA4mR7cwdc?node-id=11-39).
- Approved Flights states: [library](https://www.figma.com/design/ZrGA7ZuOACWtXA4mR7cwdc?node-id=11-97) and [complete Flight detail](https://www.figma.com/design/ZrGA7ZuOACWtXA4mR7cwdc?node-id=11-127).
- Approved operational states: [Cockpit recording lifecycle](https://www.figma.com/design/ZrGA7ZuOACWtXA4mR7cwdc?node-id=12-5) and [Flight recovery](https://www.figma.com/design/ZrGA7ZuOACWtXA4mR7cwdc?node-id=12-114).
- Approved adaptive references: [iPad landscape](https://www.figma.com/design/ZrGA7ZuOACWtXA4mR7cwdc?node-id=13-5), [iPhone portrait](https://www.figma.com/design/ZrGA7ZuOACWtXA4mR7cwdc?node-id=13-28), and [Larger Text](https://www.figma.com/design/ZrGA7ZuOACWtXA4mR7cwdc?node-id=13-51).
- Design decisions and authoring constraints: [approved baseline notes](https://www.figma.com/design/ZrGA7ZuOACWtXA4mR7cwdc?node-id=13-71).

## Device and orientation baseline

- Primary target: iPad Pro 11-inch in portrait.
- Canonical wide adaptation: iPad Pro 11-inch in landscape.
- Canonical compact adaptation: iPhone 16 Pro in portrait.
- Secondary compact coverage: other supported iPhone 16-generation-or-later sizes in portrait.
- iPhone landscape is outside the design baseline.

## Behavior

### Recording principles and privacy

1. Recording is automatic for a loaded Flight. The first release exposes no setting that disables recording globally or on a per-Flight basis.

2. Recording a Flight and disclosing live position are separate capabilities. Outside an explicitly activated Position Check, the Cockpit never displays recorded or current GPS position, actual track, recovery guidance, raw coordinates, or raw sensor values.

3. Position Check remains the only normal-navigation interaction that deliberately reveals live GPS-derived position. Starting, continuing, exporting, or viewing the status of a recording never activates Position Check.

4. Recordings remain on the device unless the pilot deliberately initiates export for a selected Flight. The app performs no automatic upload, synchronization, analytics transmission, or background export.

5. A recording preserves an immutable copy of the Flight Plan used by that Flight. Editing, replacing, or deleting the library copy cannot change an existing or recoverable recording.

6. The recording distinguishes the physical Flight from navigation execution. Takeoff, airborne movement, landing, and stop describe the physical Flight; starting a leg, reaching targets, revising values, and completing navigation describe navigation execution. Navigation may begin before or after takeoff and may end before or after landing.

7. The app records committed operational actions and automatic navigation transitions, not incidental interface activity. Map pan, zoom, span, app-section changes, opening or cancelling editors, focus changes, and viewing menus or history are not recording events.

8. Checklist interactions are outside the recording history unless a checklist action directly commits a navigation-state transition owned by another recorded event.

9. Every user-facing recording state and action remains understandable with VoiceOver and supported Dynamic Type sizes. Recording, GPS availability, completion, and destructive states never rely on color alone.

### Arming and provisional preflight capture

10. Loading a Flight Plan into Cockpit arms automatic flight detection for its ready Flight when location access is available. Merely browsing or inspecting a Flight Plan does not arm recording.

11. While armed, the app clearly indicates that automatic flight detection is active and location is being monitored. This disclosure appears before a durable recording exists and does not reveal the location itself.

12. While armed, the app retains a rolling two-minute pre-movement sensor buffer so that a promoted recording can include the beginning of ground movement.

13. The rolling buffer is temporary and does not appear in Flights. If no recording is promoted, it is discarded when the Flight is replaced, the Flight Plan is unloaded, permission is revoked, or the app exits.

14. Credible ground movement creates a provisional recording. A provisional recording remains hidden from Flights and is not yet considered an attempted Flight.

15. A provisional recording becomes a durable Flight recording when either credible takeoff is detected or the pilot chooses **Start Leg**, whichever occurs first.

16. Promotion includes the available rolling-buffer samples so the durable track begins before the exact promotion moment when those samples exist.

17. If ground movement ends without takeoff or navigation starting, the app discards the provisional recording after a conservative timeout. This does not create an incomplete Flight.

18. If the app opens with a loaded Flight while sensor evidence indicates that the aircraft is already airborne, the app starts a durable partial recording. Missing earlier movement remains an explicit limitation and is never reconstructed.

19. Automatic detection remains disabled when no Flight Plan is loaded, even when aircraft-like movement is observed.

### Physical-flight and navigation phases

20. A durable recording communicates its current phase without exposing position. Pilot-facing states include preparing, recording, GPS gap, navigation complete while recording continues, awaiting stop, and recovery required.

21. Takeoff, landing, and sustained-stop detection use conservative evidence over time. A single speed, altitude, heading, or position sample never starts or closes a Flight.

22. Temporary taxi stops, holding short, GPS drift, a zero-speed sample, signal loss, or a brief poor-quality interval do not close a recording.

23. When evidence contradicts an earlier automatic phase detection, the recording retains the original detection and adds a correction. The visible current phase reflects the corrected result without rewriting history.

24. Starting the first leg begins navigation-event recording if it is not already active and promotes any provisional physical recording.

25. Reaching the final waypoint ends active leg navigation but does not close the recording or stop physical-flight data collection.

26. After the final waypoint is reached, the existing passive **Navigation Complete** presentation becomes an explicit action. Navigation revisions are unavailable in this terminal navigation state, while physical-flight recording continues.

27. Choosing **Navigation Complete** commits the end of navigation execution. It does not stop physical-flight recording before landing and sustained stop are established.

28. A Flight is **Complete** after navigation has been explicitly completed and the physical recording has ended following landing and sustained stop. These two conditions may occur in either order.

29. If the pilot completes navigation after landing and sustained stop have already been established, the recording closes immediately as Complete.

30. If landing and sustained stop are established without **Navigation Complete**, the recording closes automatically as **Incomplete**.

31. If navigation is complete but the process stops before landing and sustained stop are established, the recording may be recovered only within the recording's captured recovery window. After that window it closes as Incomplete rather than being declared Complete.

32. The Cockpit provides a secondary **End Recording** action when automatic closure has not occurred. It requires confirmation and records that closure was manual.

33. A manual end is Complete when navigation is complete and available evidence indicates landing. Otherwise it is Incomplete. Manual closure remains visible as part of the recording status.

34. The currently active or recoverable recording cannot be exported or deleted. The pilot must first complete it or end it as incomplete.

### Navigation-event history

35. The recording maintains one ordered operational history across pilot actions, automatic navigation transitions, physical-phase changes, GPS availability changes, and recovery events.

36. Recorded navigation events include recording start, leg start, destination identification, identification-point reach, waypoint reach, automatic next-leg transition, ETA revision, heading revision, reach undo, Position Check request and completion, navigation completion, manual recording end, and recording closure.

37. Each committed ETA or heading revision records the affected navigation target or leg and the prior and committed values. Uncommitted drafts and cancelled edits are not recorded as revisions.

38. Undo is recorded as a distinct event linked to the action it reverses. The original action remains in history; undo never deletes or rewrites it.

39. Automatic leg recovery, automatic successor-leg progression, and other automatic navigation transitions are recorded and visibly distinguishable from pilot-initiated actions.

40. Rejected, cancelled, invalid, or no-op actions are not operational-history events. A Position Check request is the exception because the deliberate request is operationally meaningful even when acquisition later fails.

41. A Position Check event records that the pilot deliberately requested and completed or ended the check, including the quality-qualified position sample used when a disclosure succeeds. This does not extend disclosure beyond the Position Check window.

42. Events retain wall-clock time, elapsed time relative to recording start, and deterministic ordering. A device clock change never reorders already-recorded events.

43. Recording events do not alter navigation behavior. In particular, automatic physical-flight detection never reports a navigation target reached, identifies a destination, changes a leg, or commits a pilot-authored value.

### Sensor data and gaps

44. The durable physical track records every structurally valid location update delivered during recording, including timestamp, latitude, longitude, altitude, speed, course over ground, and available accuracy information.

45. Track collection is independent of Position Check readiness. A valid low-accuracy or stationary sample may be retained in the track even when it is unsuitable for Position Check.

46. Exact duplicate deliveries and malformed samples are not added to the track. Valid stationary samples, low-accuracy samples, and repeated positions at different times remain part of the record.

47. GPS altitude and course are measurements with their reported validity and accuracy, not authoritative aircraft height or heading. Invalid measurements are absent rather than represented as zero.

48. Barometric altitude may supplement the track when the device supports it and motion access is available. Its absence never prevents recording.

49. Compass heading may be retained as device-relative supplemental information when available. It is never represented as authoritative aircraft heading because device orientation and magnetic interference may differ from the aircraft.

50. Raw high-frequency accelerometer and gyroscope streams are not durably recorded in this release.

51. Location recording continues during ordinary app switching, screen locking, and supported background execution. Supplemental compass and barometric channels are best effort when the operating system does not continue them.

52. The permission explanation states that NavigationFlight records the aircraft track during an active Flight, may continue location collection in the background, keeps recordings on-device, and exports only through a deliberate pilot action.

53. The app explains that deliberately force-quitting it may stop sensor collection until it is reopened. It does not promise uninterrupted tracking while the process is unavailable.

54. Permission denial, restriction, revocation, disabled services, signal loss, and later resumption are explicit recording-availability events. A gap is never presented as the aircraft remaining stationary.

55. Missing track intervals remain gaps. The app never interpolates, estimates, or draws a fictional path through missing samples.

56. When location is unavailable, navigation remains usable and navigation actions continue to be recorded. The Flight visibly indicates absent or partial GPS coverage.

57. Without location permission, recording begins when the pilot chooses **Start Leg**. Because physical takeoff and landing cannot be established reliably, the pilot ends recording manually after completing navigation.

58. An action-only recording may be Complete when navigation is complete and the pilot manually ends it. Its GPS coverage remains explicitly unavailable.

59. Temporary sensor or storage degradation does not block an operational navigation action. The app gives a restrained warning when recording may be incomplete. Recovery-checkpoint failure follows the stricter bounded-recovery rules below when durable protection cannot be restored before its window expires.

### Recovery and continuation

60. Every committed navigation action is durably recoverable before the app presents that action as successful. High-frequency sensor data may have a bounded loss of approximately five seconds after an unexpected interruption.

61. At most one Flight is operationally active or recoverable. Starting or loading another Flight is unavailable until an existing recoverable Flight is continued or ended. A healthy recording owned by the running process remains active through ordinary foreground/background transitions and does not enter recovery.

62. Every durable recording captures the recovery window effective when it starts. The default is five minutes. A later Settings feature may offer bounded choices of 1, 2, 5, or 10 minutes, but never unlimited recovery; changing that preference does not alter an existing recording.

63. While a recording is active, the app periodically preserves a lightweight recovery checkpoint even when GPS and navigation events are unavailable. The checkpoint is recovery evidence only: it is not a GPX point, waypoint, or navigation-history event.

64. An orphaned recording is recoverable only until its captured window has elapsed since the latest valid evidence written by the previous process session. Relaunch bookkeeping never refreshes freshness. When no later evidence exists, the recording start time is the fallback. A future-dated timestamp or wall-clock rollback fails closed for continuation.

65. Bootstrap reconciles every unclosed package before the normal app becomes interactive:
   - expired recordings close automatically as **Incomplete — Recovery Expired** at their latest valid evidence time, not the later discovery time;
   - legacy recordings without captured policy or checkpoints use the default five-minute window and their latest valid stored evidence;
   - routine cleanup produces one summary rather than one alert per recording; and
   - failure to persist a required closure blocks normal progress with **Retry** rather than pretending the one-Flight invariant was restored.

66. One fresh orphan presents a non-dismissible recovery gate before the tab interface. It shows Flight Plan identity, route, last durable activity, and **Continue Flight** availability as a visible countdown. It offers only **Continue Flight** and confirmed **End Flight as Incomplete**; it does not show summaries, map data, export, or deletion.

67. Choosing **Continue Flight** revalidates freshness atomically. A stale command closes the recording as recovery-expired instead of reopening Cockpit. A valid command restores committed navigation state, opens Cockpit, preserves the original timing basis, and begins a new track segment so the interruption is never bridged by a fictional path.

68. Choosing **End Flight as Incomplete** requires confirmation that continuation will become unavailable while evidence remains saved and exportable. Success opens the saved Flight detail. Retrying Continue or End after interruption is idempotent and cannot create duplicate events or conflicting closure state.

69. If the recovery window expires while its gate is visible or backgrounded, the app revalidates on foreground, saves the Flight as incomplete, and explains the result with **View Flight** and **Continue to App** actions. VoiceOver announces the initial remaining time, one-minute threshold, and expiration rather than every visual countdown tick.

70. If more than one fresh orphan unexpectedly exists, the app never chooses silently. The pilot may select one to continue—after confirming that the others will close as **Incomplete — Superseded During Recovery**—or confirm **End All as Incomplete**. Unsupported or corrupt state is never continued; preserved readable evidence becomes exportable only after the package is durably closed.

71. Recovery excludes transient presentation state: open editors, unsaved drafts, menus, sheets, alerts, map camera, focus, and short-lived undo opportunities are not restored. Recovery always uses the immutable Flight Plan copy captured by the recording. Repeated checkpoint failure warns immediately; if the last durable checkpoint ages beyond the captured window, recording ends incomplete and the app presents a blocking storage failure.

### Flights app section

72. The app exposes four top-level app sections in this order: **Cockpit**, **Flight Plans**, **Flights**, **Settings**. **Flight Plans** contains imported preparation; **Flights** contains actual executions and recordings.

73. Flights is available offline and lists recordings newest first. Repeated executions of the same Flight Plan remain distinct Flights.

74. An empty Flights state explains that recorded Flights will appear automatically after takeoff detection or starting navigation. It does not offer a manual import action.

75. Each row identifies the Flight using its Flight Plan name and recording start date and time. It also shows duration, completion state, GPS coverage, and approximate recording size.

76. Flight duration describes the physical recording interval. Navigation timing remains available as separate recorded information and is not substituted for physical duration.

77. During a healthy running session, the single active Flight appears first as **In Progress** and selecting it offers **Return to Cockpit** without export or deletion. A recoverable orphan is resolved by the launch recovery gate before the Flights library is available and never appears as an ordinary library action row.

78. Completed, incomplete, manually ended, partial-GPS, GPS-unavailable, and unavailable or corrupt states are distinguishable in text and accessibility semantics.

79. A corrupt recording remains visible as unavailable and can be deleted. One corrupt recording never prevents healthy Flights from loading.

80. Selecting a healthy Flight opens a detail view containing its identity, route summary, start and end information, duration, completion and closure status, GPS coverage, derived distance and altitude summary when available, and actions eligible for that lifecycle state. Export and deletion are available only after durable closure.

81. This release does not display the historical track on an in-app map and does not expose the navigation-event timeline as a debrief interface.

82. Distance, maximum recorded altitude, duration, and coverage summaries reflect the stored evidence. Missing or invalid measurements are described as unavailable rather than shown as zero.

83. Recordings use automatic titles based on Flight Plan name and start time. The pilot cannot rename them in this release.

84. The app applies no automatic storage quota, expiry, or cleanup. Low storage stops further recording safely, preserves already committed data, and warns the pilot without deleting another Flight.

### GPX export

85. A pilot may export any readable track from a durably closed complete, incomplete, manually ended, recovery-expired, or superseded recording. Active and recoverable recordings cannot be exported.

86. Export uses an explicit system share or save interaction initiated from the selected Flight. Cancellation leaves the recording unchanged.

87. GPX export contains the stored coordinates and timestamps plus valid elevation, speed, and course information in broadly interoperable GPX 1.1 form.

88. Known GPS interruptions produce separate GPX track segments so external software does not connect a gap with a misleading straight line.

89. GPX metadata identifies the Flight Plan and the recording's complete or incomplete status and closure cause. Partial coverage remains explicit.

90. Unavailable or invalid values are omitted from GPX rather than exported as zero. Navigation events remain internal and are not encoded as misleading track points or waypoints.

91. Exported filenames use a sanitized Flight Plan name and recording start timestamp, adding a stable disambiguator when needed to avoid collisions.

92. Export failure explains that no file was shared and leaves the recording intact and available for another attempt.

### Deletion and failure handling

93. Deleting a closed recording requires confirmation that identifies the selected Flight and states that its action history and track will be permanently removed.

94. Cancelling deletion changes nothing. Successful deletion removes the complete local recording. A failed deletion keeps the Flight visible and explains the failure.

95. Recording persistence failure never reports a Flight as safely captured when it is not. The app preserves already committed evidence, retries when safe, and shows a non-blocking warning during navigation.

96. If location permission changes during a Flight, the recording continues with navigation events, records the availability transition, and resumes the track only when fresh location updates return.

97. App-section switching never starts, ends, pauses, replaces, or exposes a recording. Returning to Cockpit preserves operational navigation context subject to the recovery rules above.

98. Closing a Position Check, leaving Cockpit, locking the device, or ending its disclosure timer removes live GPS-derived presentation as defined by Position Check, even though background recording may continue.

99. The recording-status indicator communicates state without competing with time-critical Cockpit controls, obscuring the map, or implying that the app is navigating automatically.

100. Future replay and debrief features may consume the preserved track and operational history, but they must not retroactively change the evidence recorded by this release.
