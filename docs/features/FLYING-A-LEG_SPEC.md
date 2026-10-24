# Flying a Leg — Product Specification

Status: approved through Iteration 07; complete paired product/design baseline awaiting final approval.

## Summary

NavigationFlight lets pilots practise visual navigation using the same responsibilities they have with a paper map, heading, and timer. During normal flight, the pilot remains the navigation authority: the app records pilot reports, presents planned and observed information, and offers explicitly requested cross-checks without silently navigating for the pilot.

This specification defines the complete lifecycle of flying one leg, including pilot-reported position fixes, in-flight ETA and heading revision, target history, drift-line aids, bounded undo, and integration with the existing progression policy.

## Product philosophy

NavigationFlight is a manual-navigation training aid, not an automated GPS navigation app.

The pilot is solely responsible for:

- starting each leg;
- identifying identification points and waypoints;
- reporting when an identification point or waypoint has been reached;
- calculating and committing Revised ETA values;
- calculating and committing Revised Heading values; and
- deciding which heading and timing values to use operationally.

The app may:

- record timestamps resulting from explicit pilot reports;
- show planned, revised, and actual values;
- calculate simple differences between those values;
- provide graphical manual-calculation aids;
- reveal an independently calculated Reference ETA only after the pilot explicitly requests a cross-check; and
- provide a short undo opportunity for an erroneous reach report.

During normal navigation, the app must not infer that the aircraft has reached a target, silently revise a value, or present GPS-derived position as though it were a pilot observation.

## Scope

This specification covers:

- the complete active-leg lifecycle;
- identification-point and arrival-waypoint reporting;
- ordering and missed identification points;
- ETA presentation, editing, commitment, and cross-checking;
- first-release Revised Heading behavior;
- configurable drift-line presentation;
- completed-leg timing and heading history;
- a 20-second undo window for reach reports; and
- the boundary between first-release behavior and future GPS safety assistance.

Detailed automatic and manual handoff behavior is owned by [Progression Policy — As-Is Product Specification](PROGRESSION-POLICY_SPEC.md). Where the two specifications overlap, this document defines the broader leg lifecycle and the progression-policy specification defines the detailed handoff semantics.

## Non-goals

The first release does not:

- derive or display a wind direction, wind speed, headwind, tailwind, or crosswind;
- calculate a Reference Heading;
- recommend or automatically apply a heading;
- track the aircraft with GPS during normal navigation;
- reveal a live aircraft position;
- detect that the pilot is lost;
- implement automatic safety mode;
- provide unrestricted editing of historical flight events; or
- durably restore an active flight after app termination.

## Figma

- Stable proposal: [NavigationFlight — Flying a Leg](https://www.figma.com/design/yvLXb8bUFBiZHqsag4hq6I)
- Current main-screen direction: [Iteration 02 — real-chart iPad portrait cockpit](https://www.figma.com/design/yvLXb8bUFBiZHqsag4hq6I?node-id=16-2)
- Main-screen frame: [iPad Pro 11-inch portrait — IP2 reached](https://www.figma.com/design/yvLXb8bUFBiZHqsag4hq6I?node-id=16-3)
- Direction notes: [Iteration 02 review decisions](https://www.figma.com/design/yvLXb8bUFBiZHqsag4hq6I?node-id=16-96)
- Design coverage: [Iteration 03 coverage plan](https://www.figma.com/design/yvLXb8bUFBiZHqsag4hq6I?node-id=24-4)
- Iteration 03 flow: [Ready to Start — iPad portrait](https://www.figma.com/design/yvLXb8bUFBiZHqsag4hq6I?node-id=31-3)
- Iteration 03 flow: [Active Leg — start checklist expanded](https://www.figma.com/design/yvLXb8bUFBiZHqsag4hq6I?node-id=41-2)
- Iteration 03 flow: [Active Leg — checklist noted and collapsed](https://www.figma.com/design/yvLXb8bUFBiZHqsag4hq6I?node-id=60-2)
- Iteration 03 flow: [Destination Identified](https://www.figma.com/design/yvLXb8bUFBiZHqsag4hq6I?node-id=63-2)
- Iteration 03 flow: [Arrival Reached — automatic successor start](https://www.figma.com/design/yvLXb8bUFBiZHqsag4hq6I?node-id=63-90)
- Iteration 03 flow: [Arrival Reached — manual successor handoff](https://www.figma.com/design/yvLXb8bUFBiZHqsag4hq6I?node-id=63-191)
- Iteration 03 flow: [Final Leg — navigation complete](https://www.figma.com/design/yvLXb8bUFBiZHqsag4hq6I?node-id=63-275)
- Iteration 03 flow: [Previous Leg — expanded history](https://www.figma.com/design/yvLXb8bUFBiZHqsag4hq6I?node-id=74-158)
- Iteration 03 flow: [Successor active — Previous Leg and checklist noted](https://www.figma.com/design/yvLXb8bUFBiZHqsag4hq6I?node-id=78-6)
- Iteration 04 flow: [IP2 callout — future target](https://www.figma.com/design/yvLXb8bUFBiZHqsag4hq6I?node-id=81-3)
- Iteration 04 flow: [IP2 ETA revision — draft](https://www.figma.com/design/yvLXb8bUFBiZHqsag4hq6I?node-id=81-114)
- Iteration 04 flow: [IP2 ETA revision — committed, Check unavailable](https://www.figma.com/design/yvLXb8bUFBiZHqsag4hq6I?node-id=81-231)
- Iteration 04 flow: [IP1 reached — timing result and undo](https://www.figma.com/design/yvLXb8bUFBiZHqsag4hq6I?node-id=81-345)
- Iteration 04 flow: [Revise Next ETA — IP2 focused editor](https://www.figma.com/design/yvLXb8bUFBiZHqsag4hq6I?node-id=81-462)
- Iteration 04 flow: [IP2 ETA Check — Reference ETA revealed](https://www.figma.com/design/yvLXb8bUFBiZHqsag4hq6I?node-id=81-583)
- Iteration 04 flow: [Later IP reached — earlier IP passed without report](https://www.figma.com/design/yvLXb8bUFBiZHqsag4hq6I?node-id=81-703)
- Iteration 05 flow: [Heading instrument — imported baseline](https://www.figma.com/design/yvLXb8bUFBiZHqsag4hq6I?node-id=87-3)
- Iteration 05 flow: [Heading editor — opened from baseline](https://www.figma.com/design/yvLXb8bUFBiZHqsag4hq6I?node-id=87-107)
- Iteration 05 flow: [Heading editor — uncommitted 087-degree draft](https://www.figma.com/design/yvLXb8bUFBiZHqsag4hq6I?node-id=87-224)
- Iteration 05 flow: [Revised Heading — committed and operational](https://www.figma.com/design/yvLXb8bUFBiZHqsag4hq6I?node-id=87-343)
- Iteration 05 flow: [Heading editor — reopened with earlier commits](https://www.figma.com/design/yvLXb8bUFBiZHqsag4hq6I?node-id=87-446)
- Iteration 05 flow: [Identification point reached — Revised Heading continues](https://www.figma.com/design/yvLXb8bUFBiZHqsag4hq6I?node-id=87-566)
- Iteration 05 flow: [Heading editor — 360-degree normalization](https://www.figma.com/design/yvLXb8bUFBiZHqsag4hq6I?node-id=87-678)
- Iteration 06 flow: [Undo expired — action removed](https://www.figma.com/design/yvLXb8bUFBiZHqsag4hq6I?node-id=95-3)
- Iteration 06 flow: [Undo invalidated — later state action](https://www.figma.com/design/yvLXb8bUFBiZHqsag4hq6I?node-id=95-111)
- Iteration 06 flow: [Duplicate reach — rejected without mutation](https://www.figma.com/design/yvLXb8bUFBiZHqsag4hq6I?node-id=95-215)
- Iteration 06 flow: [ETA draft discarded — target reached](https://www.figma.com/design/yvLXb8bUFBiZHqsag4hq6I?node-id=95-324)
- Iteration 06 flow: [ETA Check — unavailable](https://www.figma.com/design/yvLXb8bUFBiZHqsag4hq6I?node-id=95-438)
- Iteration 06 flow: [Arrival without VOR/DME — optional data omitted](https://www.figma.com/design/yvLXb8bUFBiZHqsag4hq6I?node-id=95-548)
- Iteration 06 flow: [First leg — no Previous Leg history](https://www.figma.com/design/yvLXb8bUFBiZHqsag4hq6I?node-id=95-652)
- Iteration 06 flow: [Drift lines hidden — current-flight preference](https://www.figma.com/design/yvLXb8bUFBiZHqsag4hq6I?node-id=95-756)
- Iteration 06 flow: [Returned from background — timers continued](https://www.figma.com/design/yvLXb8bUFBiZHqsag4hq6I?node-id=95-860)
- Iteration 07 adaptation: [iPad Pro 11-inch — landscape active leg](https://www.figma.com/design/yvLXb8bUFBiZHqsag4hq6I?node-id=102-5)
- Iteration 07 adaptation: [iPhone 16 Pro — portrait active leg](https://www.figma.com/design/yvLXb8bUFBiZHqsag4hq6I?node-id=102-71)
- Iteration 07 accessibility: [iPhone portrait — Larger Text active leg](https://www.figma.com/design/yvLXb8bUFBiZHqsag4hq6I?node-id=102-119)
- Iteration 07 notes: [Adaptive-layout and accessibility rules](https://www.figma.com/design/yvLXb8bUFBiZHqsag4hq6I?node-id=102-156)
- Final review: [Design coverage audit — 125 invariants covered](https://www.figma.com/design/yvLXb8bUFBiZHqsag4hq6I?node-id=106-3)
- Previous direction: [Iteration 01 — abstract-map iPad portrait cockpit](https://www.figma.com/design/yvLXb8bUFBiZHqsag4hq6I?node-id=9-2)
- Archived exploration: [iPhone portrait direction draft](https://www.figma.com/design/yvLXb8bUFBiZHqsag4hq6I?node-id=1-19)
- Archive note: [Device priority corrected](https://www.figma.com/design/yvLXb8bUFBiZHqsag4hq6I?node-id=1-72)
- Product-spec status: `approved through Iteration 07` by John — 2026-10-25
- Design status: `approved · Iteration 07 adaptive layout and accessibility`
- Approved design checkpoints:
    - Iteration 02 — iPad portrait main-screen direction;
    - Iteration 03 — Ready to Start; and
    - Iteration 03 — Active Leg with selected start-checklist template expanded;
    - Iteration 03 — arrival progression, previous-leg history, checklist coexistence, and final completion; and
    - Iteration 04 — identification-point progression, ETA revision, Reference ETA disclosure, passed-without-report, and bounded undo; and
    - Iteration 05 — Revised Heading lifecycle, including IP continuity and arrival-only reset; and
    - Iteration 06 — exceptions, unavailable actions, empty states, preference visibility, and background return; and
    - Iteration 07 — iPad landscape, iPhone portrait, Larger Text, and accessibility interaction order.
- Human approver: John — 2026-10-25
- Coverage-audit result: all 125 behavioral invariants and the workflow's device and accessibility requirements are traced to approved design evidence; no unresolved product/design conflicts remain.
- Final paired-baseline status: ready for explicit approval after the stable product-spec permalink is recorded on the Figma cover.

The Navigation Editor screenshot supplied during product discovery remains a contextual example of drift-line intent, not a pixel-accurate UI contract.

## Terminology

The canonical domain terms are defined in [GLOSSARY.md](../../GLOSSARY.md). In particular:

- **ETA** means elapsed time from the start of the active leg to a navigation target, not a wall-clock arrival time.
- **Navigation target** means an identification point or arrival waypoint within a leg.
- **Pilot-reported position fix** is the known map position of a target that the pilot explicitly reports reaching. It is not independently verified.
- **Passed without report** describes an identification point overtaken by a later pilot-reported position fix without having been reported reached itself.
- **Revised ETA** and **Revised Heading** are pilot-authored operational values.
- **Reference ETA** is an app-computed cross-check revealed only on explicit request.
- **Drift lines** are manual-calculation aids and do not represent an actual or GPS-derived aircraft track.

## Current implemented flow

The current work in progress behaves as follows:

1. The pilot imports a flight plan, inspects it, selects an eligible starting leg, and selects the whole-plan no-wind or planned-wind mode before beginning flight.
2. Entering the cockpit does not start timing. The pilot explicitly starts the initial leg.
3. Starting a leg begins its elapsed timer and presents its start checklist.
4. The cockpit displays imported course, optional planned-wind heading, altitude, timing, map annotations, and target callouts for the active leg.
5. The pilot may report an identification point reached. The app records its Actual ETA from the leg start time.
6. Reaching an identification point currently initializes an ETA editor for the following target from that target's Planned ETA.
7. The pilot may edit and commit a Revised ETA in five-second increments.
8. The pilot may request **Check** to compare a committed Revised ETA with a proportional Reference ETA when the editor is associated with a reached identification point.
9. The pilot separately reports destination identification and destination reach. Identification does not complete the leg; reach does.
10. Reaching the arrival waypoint records Actual ETA, completes the leg, and applies the configured automatic or manual progression policy.
11. The previous-leg panel currently summarizes completed-leg timing, but the app does not yet provide the complete target-by-target and heading history required below.
12. The app does not yet support pilot-authored Revised Heading, drift-line visibility control, passed-without-report state, or bounded undo.

The imported V7 execution snapshot remains the source of planned course, distance, target positions, target timings, and optional planned-wind heading. As described by [FPLNAV V7 Integration](../FPLNAV-V7-INTEGRATION.md), NavigationFlight consumes these resolved values rather than recalculating plan geometry.

## Behavior

### Leg lifecycle

1. Importing and inspecting a flight plan does not begin a flight timer or make an observation on behalf of the pilot.

2. The pilot can select a starting leg and an available calculation mode only before timing begins, subject to the existing plan-eligibility rules.

3. Entering the cockpit leaves the selected leg ready. The pilot must explicitly choose **Start Leg** before the leg becomes active.

4. Starting the leg establishes the time origin for every Planned, Revised, Reference, and Actual ETA on that leg.

5. While the leg is active, the cockpit presents its planned navigation information, current operational heading, running elapsed time, map, navigation targets, and applicable checklist.

6. All normal navigation state changes originate in explicit pilot actions. Merely panning the map, opening a callout, changing focus, or viewing historical information must not start a leg, identify a target, report a target reached, or commit a revision.

7. Destination identification and destination reach remain separate observations. Identifying the destination does not stop timing, complete the leg, or prevent the pilot from revising its ETA.

8. Reporting the arrival waypoint reached completes the leg even when one or more identification points were not reported.

9. After arrival reach, the existing progression policy determines whether the successor leg starts at the same timestamp or remains ready for an explicit start. The pilot must experience the cockpit, map, timing, and checklist effects defined by the progression-policy specification.

10. Completing the final leg ends navigation and starts no successor timing.

### Navigation targets and pilot reports

11. Identification points are ordered along the active leg using their resolved planned positions and timings.

12. The pilot may report any unreached identification point ahead as reached. Reporting a later point must not be blocked merely because an earlier identification point was never reported.

13. A reach report asserts that the aircraft is at the target's resolved map position according to the pilot. The app treats it as a pilot-reported position fix without claiming independent verification.

14. When a later identification point is reported reached, every earlier unreached identification point on that leg becomes passed without report.

15. A passed-without-report point has no fabricated reach timestamp, Actual ETA, or position-fix claim.

16. Reached and passed-without-report targets are historical and cannot be revised. Only targets ahead of the latest pilot-reported position fix remain editable.

17. Before a target is reported reached, the app must not infer reach from elapsed time, map position, expected schedule, or callout focus.

18. Reporting the arrival waypoint reached changes all remaining unreached identification points on that leg to passed without report before the leg is finalized.

### ETA callouts and revision

19. Every unreached identification point and the unreached arrival waypoint on the active leg has its own ETA callout.

20. A target's ETA may be revised directly from that target's own callout at any time while the target remains in the future. Reaching an identification point is not a prerequisite for ETA revision.

21. Opening ETA revision for a target with no committed Revised ETA initializes the editable value from that target's Planned ETA.

22. Opening ETA revision for a target with an existing committed Revised ETA initializes the editable value from the committed value.

23. The pilot adjusts Revised ETA in five-second increments and must explicitly commit it before it becomes operational.

24. A draft ETA is not a Revised ETA. Closing, abandoning, or losing eligibility for an uncommitted draft must not present that draft as a committed operational or historical value.

25. Each target has at most one currently committed Revised ETA. A later commit for the same future target replaces its current operational revision while preserving earlier commits in flight history.

26. An unreached target's compact ETA callout displays its committed Revised ETA when one exists; otherwise it displays Planned ETA. The label must make the displayed value's kind clear.

27. When the pilot reports an identification point reached, its callout displays the applicable expected ETA, Actual ETA, and signed difference:
    - when a Revised ETA was committed, the applicable expectation and primary difference are Revised ETA and Actual-versus-Revised;
    - otherwise, they are Planned ETA and Actual-versus-Planned.

28. Reaching an identification point also offers **Revise Next ETA** when another future target exists.

29. **Revise Next ETA** selects the first unreached target after the reached point, focuses the map on it, expands its own ETA callout, and enters that callout's ordinary edit mode.

30. **Revise Next ETA** does not create a separate editor or automatically change, calculate, or commit a value.

31. If the pilot reports a target reached while its ETA editor contains an uncommitted draft, the draft is discarded and the target's history records no new revision.

32. Planned, Revised, Reference, and Actual ETA always remain elapsed times measured from the active leg's start, including after intermediate position fixes.

### ETA observation and cross-check

33. After an identification point is reported reached, its timing result includes Planned ETA, Actual ETA, and a signed early-or-late difference.

34. Difference presentation must communicate direction in pilot language, such as `10 seconds late` or `5 seconds early`, rather than requiring the pilot to infer meaning from an unsigned number.

35. The app must not automatically transfer the reached point's difference into any future target's Revised ETA.

36. ETA revision remains available before any identification point is reached, but **Check** is unavailable until the active leg has a reached identification point that precedes the target being checked.

37. The pilot can request **Check** only after committing a Revised ETA for that target.

38. When **Check** is requested, the app uses the latest reached identification point preceding the target, regardless of when the target's editor was first opened or when its Revised ETA was committed.

39. The Reference ETA applies the exact observed timing ratio:

    ```text
    Reference target ETA =
        Planned target ETA × Actual reached-point ETA
        ------------------------------------------------
                      Planned reached-point ETA
    ```

40. The Reference ETA calculation retains full available precision and its displayed value is rounded to the nearest second.

41. The Reference ETA, the pilot's committed Revised ETA, and their signed difference appear only after the pilot explicitly requests **Check** in that target's ETA callout.

42. Revealing Reference ETA must not overwrite the draft or committed Revised ETA, change the current operational ETA, or apply a new value to another target.

43. Hiding the check result returns the callout to its normal operational presentation without deleting the pilot's committed revision.

44. A later reached identification point changes the observation basis for future checks. A subsequent **Check** uses the newest eligible position fix rather than an observation captured when the editor was created.

### Drift lines

45. The active-leg map displays drift lines by default.

46. Drift lines use the imported navigation parameter's drift angle. A 10-degree angle produces the 10-degree reference geometry shown in the Navigation Editor example; the first release must not hard-code 10 degrees when the imported value differs.

47. One dashed reference arm begins at the departure waypoint and is offset to the right of the planned track by the configured drift angle.

48. A second dashed reference arm begins at the arrival waypoint and is offset to the opposite side when viewed back along the leg by the configured drift angle.

49. The two arms terminate at their intersection around the middle of the leg, creating the familiar manual drift-estimation aid.

50. Drift lines remain fixed to planned leg geometry. They do not move in response to elapsed time, a reach report, map interaction, or a Revised Heading.

51. Drift lines must be visually distinguishable from the planned track and must never be described as the aircraft's actual track.

52. The pilot can toggle drift-line visibility on demand from the cockpit.

53. The visibility choice persists while the pilot moves between legs in the currently open flight. A newly opened flight defaults to visible until a future app preference is introduced.

54. Toggling drift lines affects presentation only. It must not modify imported plan data, target eligibility, timing, heading values, or cross-check calculations.

### Revised Heading — first-release partial feature

55. Revised Heading is available only while a leg is active.

56. The pilot may open heading revision at any time during the active leg; reaching an identification point is not a prerequisite.

57. Before any revision, the heading editor begins from:
    - the imported planned magnetic heading in planned-wind mode; or
    - the imported magnetic course in no-wind mode.

58. After a Revised Heading has been committed for the active leg, reopening the editor begins from that committed value.

59. Operational headings are magnetic whole degrees, adjusted in one-degree steps and normalized for display from `001°` through `360°`.

60. A heading draft does not become operational until the pilot explicitly commits it.

61. After commitment, the cockpit's primary heading display shows the Revised Heading instead of the imported baseline and labels it clearly as revised.

62. The heading editor continues to make the imported planned heading or no-wind magnetic-course baseline available for comparison.

63. A later heading commit on the same active leg replaces the currently applicable Revised Heading while preserving earlier commits in that leg's heading history.

64. Reporting an identification point reached does not end or reset the active leg's heading state. The current Revised Heading remains operational and any open, uncommitted heading draft remains available after the reach report.

65. Reporting the arrival waypoint reached ends the completed leg's heading history. Any uncommitted heading draft for that completed leg is discarded.

66. A Revised Heading must not carry from a completed leg into its successor. The successor leg begins from its own imported planned magnetic heading, or magnetic course in no-wind mode, until the pilot commits a Revised Heading for that leg.

67. The first release provides no heading **Check**, Reference Heading, correctness result, suggested heading, or app-computed heading formula.

68. Drift lines provide visual assistance only. The pilot interprets them and calculates the Revised Heading.

### Completed-leg history

69. The existing previous-leg panel remains available from the left side of the cockpit and remains toggleable.

70. For every reached identification point and the reached arrival waypoint on the completed leg, the panel displays:
    - Planned ETA;
    - every committed Revised ETA, when revisions exist;
    - Actual ETA;
    - Actual-versus-Planned difference; and
    - Actual-versus-Revised difference for each applicable committed revision.

71. For every identification point passed without report, the panel shows that status and does not fabricate Actual ETA or timing differences.

72. Heading history is grouped by completed leg. Identification-point reports remain timing and position observations inside that leg and do not split its heading history into new operational segments.

73. For each completed leg, heading history displays:
    - its imported planned magnetic heading or no-wind magnetic-course baseline;
    - every committed Revised Heading in order; and
    - the final heading applicable when the arrival waypoint was reached.

74. ETA Reference results appear in history only when the pilot explicitly requested that check during the active leg.

75. The app must not calculate or reveal a historical Reference ETA retroactively when the pilot never requested **Check**.

76. Reference Heading is absent from first-release history because the first release defines no heading cross-check.

### Twenty-second reach undo

77. After an identification-point or waypoint reach report succeeds, the cockpit presents an undo action with a visible 20-second availability window.

78. Only the most recent eligible reach report can be undone. The product does not expose general historical editing or multi-level undo.

79. The undo deadline is based on real elapsed time. It continues while another screen is open or the app is backgrounded and does not pause with UI visibility.

80. Passive interaction—including panning the map, opening a callout, changing map focus, or viewing previous-leg information—does not close the undo window early.

81. A later flight-state action closes the undo window immediately. Such actions include another reach report, explicitly starting a manually progressed successor leg, or committing a revision on the successor leg.

82. Undo restores the complete flight state from immediately before the reach report, not merely the reported target's timestamp.

83. Undoing an identification-point reach:
    - removes its reach timestamp and Actual ETA;
    - restores earlier points that the action changed to passed without report;
    - restores the affected targets' eligibility;
    - discards focus or editing changes caused by the reach action; and
    - preserves state that existed before the reach action.

84. Undoing an arrival-waypoint reach:
    - removes its reach timestamp and Actual ETA;
    - reactivates the completed leg from its original start timestamp;
    - restores identification-point states changed by the reach action;
    - reverses successor selection, timing, and checklist effects caused by progression; and
    - restores the departing leg's cockpit and map presentation.

85. When an arrival reach is undone, the original leg timer behaves as though it never stopped. Time spent inside the undo window remains part of that leg's elapsed time.

86. Under automatic progression, merely allowing the automatically started successor timer to run does not itself close undo. If undo is selected in time and no later pilot flight-state action occurred, the successor timing created by the mistaken reach is removed atomically.

87. When the 20-second deadline expires, the undo action disappears and the reach report can no longer be reversed through this feature.

### Session and presentation invariants

88. Switching between cockpit and plan inspection without replacing the active session does not reset leg timing, revisions, history, drift-line visibility, or an unexpired undo deadline.

89. Backgrounding without process termination does not pause leg timing or the undo deadline.

90. If the app process terminates, the current first-release session may be lost. The product must not claim durable active-flight recovery until persistence is separately specified and implemented.

91. All active-leg controls and results described in this specification must remain usable in the cockpit's supported portrait and landscape presentations.

92. Labels must distinguish Planned, Revised, Reference, and Actual values. Color alone must not communicate value kind, early/late direction, reached state, passed-without-report state, or undo availability.

93. Focus movement caused by **Revise Next ETA** must expose the destination target and its expanded editor without committing a value or hiding the user's ability to return to the current position context.

94. A rejected or unavailable action must not partially modify timing, revision, target, progression, checklist, focus, or history state.

### Cockpit map and instrument presentation

95. The cockpit map presents the application's aviation chart as its geographic base. Planned-track, drift-line, navigation-target, VOR/DME, and callout graphics remain distinct overlays on that chart rather than replacing it with an abstract map illustration.

96. The active leg's planned-track line connects the resolved departure and arrival waypoint positions exactly. Identification points and timing targets appear at their resolved positions without changing the planned track's endpoints.

97. Target callouts are closed by default. Tapping an identification point or waypoint opens that target's callout, opening another target replaces the current callout, and tapping unobstructed map space or beginning a map pan closes the callout.

98. At most one target callout is open at a time. Opening or dismissing a callout changes presentation only and does not identify, reach, revise, or otherwise modify a navigation target.

99. An identification point's **Reached** action is available only from that identification point's open callout. The lower cockpit console does not provide an identification-point reach action.

100. The map provides distinct controls for focusing the active leg, focusing the applicable waypoint, showing the route overview, and opening plan inspection. It does not present a current-aircraft-position control while the product has no live aircraft-position source.

101. Magnetic reference is communicated as part of the label for each applicable heading, course, or radial value. The cockpit does not present a standalone **Magnetic** control or status chip.

102. The portrait lower console is organized into three rows:
    - **Active Leg Instruments**, containing operational heading, leg timer, next ETA, and altitude;
    - **Planned Frequencies**, containing imported communication and applicable navigation-aid frequencies; and
    - an arrival-waypoint call-to-action row.

103. The leg timer is visually distinguishable from the adjacent Next ETA value without suggesting a warning or abnormal condition. Its distinction does not rely on color alone.

104. Planned frequencies do not claim that a frequency is tuned, active, or inactive unless a future feature introduces an explicit trustworthy source for that state. The cockpit does not display **Not tuned** based only on imported plan data.

105. Before the arrival waypoint is identified, the lower-console arrival action presents **Waypoint Identified** and a subordinate **Reached now** action. After identification, it presents **Waypoint Reached**. These actions apply only to the arrival waypoint and preserve the separate identification and reach observations defined above.

106. When the arrival waypoint has an imported VOR/DME reference, the cockpit displays:
    - the station identifier, service, and frequency in **Planned Frequencies**;
    - a compact station, magnetic radial, and DME-distance label beside the arrival waypoint on the map; and
    - the complete station, frequency, magnetic radial, and DME distance in the arrival waypoint's callout.

107. VOR/DME values are planned waypoint-confirmation information, not live avionics measurements. The presentation must not imply that the app receives, tunes, or verifies the station signal or current aircraft distance.

108. When an arrival waypoint has no imported VOR/DME reference, the map, waypoint callout, and Planned Frequencies row omit the corresponding VOR/DME presentation without showing an error or placeholder.

### Active-leg map orientation and checklist templates

109. Starting a leg focuses the active leg in a canonical track-up presentation: the departure waypoint is at the bottom, the arrival waypoint is at the top, and the planned track is vertical from bottom to top.

110. A pilot may subsequently pan or rotate the map. Those manual changes persist until the pilot chooses **Focus Leg**, which restores the canonical track-up presentation for the active leg.

111. Track-up presentation aligns the imported planned leg for visual navigation. It does not claim a live aircraft heading, position, or ground track.

112. The pilot selects a start-checklist template in Settings. The first release provides two or three bundled templates; template selection is not performed from the cockpit checklist.

113. The expanded cockpit checklist displays the selected template's title and rendered ordered content. Its title, sections, and items are not hard-coded into the cockpit view.

114. A template may contain static instructional text and dynamic variables resolved from current leg or session state, including values such as the running timer, planned or operational heading, and planned altitude. The rendered checklist does not visually distinguish static content from resolved variables.

115. The first-release implementation does not require a user-facing template editor, persistence format for user-authored templates, or a complete public variable language. It must nevertheless separate template definition, dynamic-value resolution, and checklist rendering so future user-authored templates can reuse the cockpit presentation without restructuring cockpit state or view code.

116. Bundled templates are validated application data. A bundled template must not silently display an unresolved variable as operational checklist content.

### Arrival transition, history, and map aids

117. Reporting an arrival waypoint reached transitions the map to the successor leg's canonical track-up presentation under both automatic and manual progression. Automatic progression starts the successor timer at the arrival timestamp; manual progression leaves the successor ready and untimed until the pilot chooses **Start Leg**.

118. The transition to the successor track-up presentation visibly rotates the map in the shortest angular direction from the departing leg's orientation to the successor leg's planned heading. The animation communicates the turn to the next leg without implying a live aircraft heading or position.

119. Undoing an arrival-reach transition restores the departing leg, its timer, target state, checklist state, map focus, and pre-transition map orientation atomically. The successor leg and its rotated map presentation are removed together.

120. After a leg completes, the cockpit presents a compact **Previous Leg** chip by default. The chip identifies the completed leg without covering the active navigation instruments and opens a detailed history panel on explicit pilot request. It is independent from the current leg's checklist: after that checklist is noted, its folded checklist chip and the **Previous Leg** chip remain simultaneously visible and independently actionable. When bounded undo is also visible, the two chips occupy a separate row above the undo banner rather than replacing or covering one another.

121. The expanded Previous Leg panel is review-only. It presents the completed route, planned and actual completion timing, target-by-target outcomes, and applicable heading history; opening, closing, or collapsing it does not change the current leg, timer, map orientation, target state, or progression policy.

122. Previous Leg remains available after final-leg completion. When no leg has yet completed in the current flight, the cockpit omits the chip rather than showing an empty or disabled history panel.

123. The compact VOR/DME radial-and-distance label beside an arrival waypoint is draggable. Dragging changes only that label's presentation offset so the pilot can uncover chart content; it does not change the waypoint, planned radial, planned distance, frequency, or map focus.

124. A visible map control toggles drift-line overlays. Drift lines are visible by default for each newly opened flight, the control indicates whether they are currently visible, and using it does not alter the planned track, target state, or any timing value.

125. Arrival-state badges and their corresponding actions use the same semantic color while retaining explicit text labels: **Identified** and its waypoint-identification action are blue; **Complete** and **Navigation Complete** are green. The badge shape, spacing, and contrast distinguish status from ordinary map labels, and color is not the sole carrier of state.

## Complete desired leg flow

The intended happy path is:

1. The pilot inspects the flight plan and enters the cockpit.
2. The pilot explicitly starts the leg.
3. The pilot flies the imported heading or course using the map, timer, and visible drift-line aids.
4. The pilot visually identifies an identification point and explicitly reports it reached.
5. The app records Actual ETA and shows the applicable expected ETA and signed difference.
6. The pilot may select **Revise Next ETA**, which focuses and opens the next target's own ETA editor.
7. The pilot mentally calculates, enters, and commits a Revised ETA.
8. The pilot may explicitly request **Check** to compare the committed revision with the app's proportional Reference ETA.
9. Independently, the pilot may use drift lines to calculate and commit a Revised Heading. The app displays it as the current operational heading but does not verify it.
10. The flow repeats for later identification points. Missing a point does not block reporting a later one.
11. The pilot identifies and later reports the arrival waypoint reached.
12. The leg is completed, its detailed history becomes available, and the established progression policy governs the successor leg.

The pilot may deviate from this happy path by revising any future target ETA or the active-leg heading at any time. The app must preserve the same authorship, commitment, history, and cross-check rules.

## Progression-policy integration

The following behaviors remain governed by the existing progression-policy specification:

- explicit start of the initial leg;
- destination identification versus reach;
- atomic completion and successor start under automatic progression;
- the untimed handoff under manual progression;
- final-leg completion;
- checklist effects; and
- rejection of invalid leg-start and waypoint-reach transitions.

This feature adds the requirement that arrival-reach effects remain atomically reversible during the 20-second undo window. After that window closes—or after a later flight-state action closes it early—the progression result becomes final for the first-release product.

## Future safety architecture

GPS assistance is intentionally deferred until the complete manual-navigation experience is implemented and tested.

A future product specification may define:

- an explicit pilot request to reveal GPS position when lost;
- automatic detection that the aircraft is dangerously off track;
- entry into a visibly distinct safety mode;
- guidance while safety mode is active; and
- conditions for returning to manual-navigation mode.

That future design must preserve these constraints:

1. Normal navigation remains based on pilot actions and pilot-reported position fixes.
2. GPS-confirmed position is visually and semantically distinct from a pilot-reported position fix.
3. GPS must not silently mark an identification point or waypoint reached.
4. Safety automation must be visibly active whenever it influences the pilot's navigation.
5. Adding GPS later must not change the meaning of historical non-GPS observations.

The future GPS behavior creates no first-release acceptance requirement beyond maintaining a product boundary that does not falsely imply GPS verification.

## Acceptance scenarios

### Normal timing revision

Given an active leg with an identification point planned at `2:33` and a later target planned at `5:10`, when the pilot reports the identification point reached at `2:43`, the app shows that the pilot is 10 seconds late. If the pilot commits `5:30` as Revised ETA, **Check** shows the exact proportional Reference ETA rounded to the nearest second—approximately `5:30`—without changing the committed revision.

### Early ETA revision

Given an active leg with no reached identification point, the pilot can revise any future target's ETA. The app commits the pilot's value but does not offer **Check** until an eligible identification point has been reported reached.

### Latest observation wins

Given a future target whose Revised ETA was committed before two identification points were reached, requesting **Check** after the second reach uses the second, latest eligible identification point as the proportional observation basis.

### Missed identification point

Given two ordered identification points, when the pilot reports the second reached without reporting the first, the second receives Actual ETA and the first becomes passed without report. The first has no Actual ETA and cannot be revised.

### Manual heading revision

Given an active no-wind leg, opening heading revision begins from magnetic course. After the pilot commits a new magnetic whole-degree heading, the cockpit displays it as Revised Heading. The app provides no heading check or recommendation.

### Heading continuity through an identification point

Given an active leg with a committed Revised Heading and an open heading draft, when the pilot reports an identification point reached, the committed Revised Heading remains operational and the draft remains open and unchanged. When the pilot later reports the arrival waypoint reached, the completed leg's heading history closes, its remaining draft is discarded, and any successor leg begins from its own imported baseline.

### Arrival undo under automatic progression

Given an active leg using automatic progression, when the pilot reports arrival reached, the leg completes and the successor starts. If the pilot chooses undo within 20 seconds before any later flight-state action, the successor timing and checklist are removed, the departing leg is restored, and its timer remains continuous from its original start.

### Successor map transition

Given two legs with different planned headings, when the pilot reports the first leg's arrival reached, the map animates through the shortest angular turn and ends with the successor leg track-up. In automatic mode the successor timer is running from the arrival timestamp; in manual mode the same track-up map is shown while the successor timer remains stopped until **Start Leg**.

### Previous-leg review

Given a completed leg and a current successor leg, the cockpit shows a compact **Previous Leg** chip. Opening it reveals the completed leg's timing, target outcomes, and heading history; collapsing it returns to the unobstructed map without changing the successor leg or its timer.

### Undo expiration

Given a successful reach report, when 20 real seconds pass—even while the app is backgrounded—the undo action expires and the report can no longer be reversed through bounded undo.

### Completed history

Given a completed leg with reached, revised, checked, and passed-without-report targets plus several committed headings, the previous-leg panel shows the full target and leg-wide heading history. It does not fabricate Actual ETA for missed points or reveal reference results that the pilot never requested.

## As-is gaps and delivery phases

| Area | Current behavior | Required first-release behavior |
| --- | --- | --- |
| Product authority | Pilot actions drive existing timing transitions, but no product-wide principle is documented. | Manual-navigation primacy governs the complete flow. |
| Identification-point ordering | A reached point is recorded, without a complete passed-without-report lifecycle. | Later points may be reached; earlier unreported points become historical missed observations. |
| ETA revision entry | Reaching a point initializes the next editor; targets can also be opened directly. | Every future target remains directly revisable, and **Revise Next ETA** is only a focus/edit shortcut. |
| Reached ETA presentation | Timing and Reference ETA behavior exist in partial form. | Compact callouts show applicable expected versus actual timing; history shows complete comparisons. |
| Reference ETA context | Reference context is retained when an editor is initialized. | Every check uses the latest eligible reached identification point. |
| Heading revision | Imported planned-wind heading can be displayed; pilot corrections are absent. | Pilot-authored magnetic Revised Heading is editable, operational, and historical. |
| Heading cross-check | Not implemented. | Explicitly deferred; no first-release Reference Heading or check action. |
| Drift lines | Not present in the flight map. | Imported-angle reference arms are visible by default and toggleable per open flight. |
| Previous-leg panel | Primarily summarizes destination timing. | Shows target-by-target timing and leg-wide heading history. |
| Undo | Reach reports and progression are final. | Most recent reach is atomically reversible for up to 20 seconds. |
| GPS | No normal-flight GPS position behavior is specified. | Remains out of scope; future safety constraints are documented. |
| Persistence | Flight session is held in memory. | Remains in memory for the first release and is disclosed as a limitation. |

Recommended delivery sequence:

1. Complete target ordering, passed-without-report state, and target-specific ETA interaction.
2. Complete Reference ETA selection using the latest eligible observation and expand completed timing history.
3. Add drift lines and their per-flight visibility toggle.
4. Add pilot-authored Revised Heading and leg-wide heading history without automated checking.
5. Add atomic 20-second undo across identification-point reach and waypoint progression.
6. Validate the complete flow in flight before specifying Reference Heading or GPS safety behavior.
