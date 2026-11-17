# Flight Evidence Export and Debrief — Product Specification

Status: product specification approved; experience and technical design not started.

Product approver: John, 2026-11-17.

## Summary

NavigationFlight lets a pilot privately export the complete evidence retained for a Flight, compare the planned route with the recorded execution, and understand why automatic physical-flight detection did or did not recognize takeoff, landing, taxiing, and sustained stop. The same trustworthy evidence supports an eventual in-app debrief and local engineering analysis without uploading flight data or rewriting recorded history.

## Scope

This specification covers a lossless diagnostic export, local comparative analysis, evidence-based detector evaluation, and an in-app Flight debrief. It extends [Automatic Flight Recording and Recovery](AUTOMATIC-FLIGHT-RECORDING-AND-RECOVERY_SPEC.md) while preserving that specification's navigation authority, recording, recovery, and privacy principles.

This specification deliberately supersedes Automatic Flight Recording and Recovery behavior 34 only for export: an active or recoverable recording may be exported as a read-only diagnostic snapshot without ending, deleting, continuing, or otherwise changing it. Existing restrictions on deleting an active or recoverable recording remain in force.

## Goals

- Let the pilot preserve and privately inspect all available evidence for any readable recording, including a recording that did not close automatically.
- Show where the aircraft was relative to the planned route and where recorded operational actions occurred, without presenting inferred positions as exact facts.
- Explain automatic physical-flight decisions from the recorded evidence and compare the outcomes of alternative detector policies before product behavior changes.
- Provide a shared evidence foundation for a local engineering report and a later in-app pilot debrief.

## Non-goals

- The feature does not upload, synchronize, or share recordings without an explicit pilot action.
- It does not display live GPS position in Cockpit or change the Position Check disclosure contract.
- It does not infer that a navigation target was reached, grade pilot performance, or declare operational compliance.
- It does not edit, repair, or replace the evidence originally recorded for a Flight.
- It does not initially import exported recordings back into the production app or provide cross-device restoration.
- It does not make detector thresholds configurable by pilots.

## Figma

- Stable proposal: [NavigationFlight — Flight Evidence Export and Debrief](https://www.figma.com/design/OSPuLyy5Qtde2iajUNeWDL).
- Design status: `approved`.
- Current iteration: Directions 01–05 — complete coverage candidate.
- Direction cover: [Direction 01 cover](https://www.figma.com/design/OSPuLyy5Qtde2iajUNeWDL?node-id=2-671).
- Main-screen direction: [completed Flight debrief on iPad portrait](https://www.figma.com/design/OSPuLyy5Qtde2iajUNeWDL?node-id=2-676).
- Diagnostic-export candidate flow: [Direction 02 export states](https://www.figma.com/design/OSPuLyy5Qtde2iajUNeWDL?node-id=16-10).
- Debrief-state candidate set: [Direction 03 state variants](https://www.figma.com/design/OSPuLyy5Qtde2iajUNeWDL?node-id=19-10).
- Responsive and accessibility candidate set: [Direction 04 adaptations](https://www.figma.com/design/OSPuLyy5Qtde2iajUNeWDL?node-id=24-10).
- Comparative-analysis candidate: [Direction 05 detector analysis](https://www.figma.com/design/OSPuLyy5Qtde2iajUNeWDL?node-id=26-10).
- Direction scope: real offline aviation-map context with planned route versus actual track, selected reached event with correlation uncertainty, synchronized altitude and ground-speed traces, elapsed-time scrubber, separate play/pause transport, separate ×1/×2/×5 playback-rate selector, and ordered action/phase timeline.
- Revision 02 incorporates owner feedback from 2026-11-17: the schematic map was replaced by a real app-rendered aviation chart, and the turtle/rabbit slider was replaced by controls that distinguish seeking from playback rate.
- Deferred until direction approval: diagnostic-export states, active/recoverable snapshots, partial or unavailable GPS, comparative engineering report, error states, accessibility variants, iPad landscape, and iPhone portrait.
- Required primary design target: iPad Pro 11-inch in portrait.
- Required adaptations: iPad Pro 11-inch landscape and iPhone 16 Pro portrait.
- iPhone landscape remains outside the design baseline.
- Human direction approvals: Directions 01–05 approved by John, 2026-11-17.
- Paired baseline approval: product specification revision 02 and Figma Directions 01–05 approved by John, 2026-11-17.
- Approved specification revision: [commit `5b8ff5e`](https://github.com/johnbenz13/NavigationFlight/blob/5b8ff5e982450edde72ff9d18bdfd18215b24a36/docs/features/FLIGHT-EVIDENCE-EXPORT-AND-DEBRIEF_SPEC.md).

### Design coverage checklist

The approved main-screen direction is the visual and interaction baseline for the following full-coverage work:

- **Entry and exit:** Flight detail entry, loading cancellation, return to Flight detail, and deleted-source behavior (FE-032, FE-041, FE-049).
- **Completed debrief happy path:** synchronized map, telemetry, events, seeking, playback, playback rate, and reached-point inspection (FE-027–FE-039, FE-040, FE-051–FE-053).
- **Evidence distinctions:** planned versus actual, segment gaps, direct versus correlated positions, unavailable positions, recorded versus derived observations, and historical versus live navigation (FE-001, FE-004, FE-027–FE-034, FE-039, FE-044).
- **Recording states:** Complete, Incomplete, manually ended, active snapshot, recoverable snapshot, and historical recordings with unavailable context (FE-005–FE-008, FE-024, FE-042–FE-043, FE-050).
- **Limited and failure states:** no usable GPS, partial GPS, action-only evidence, unreadable evidence, unsupported evidence or bundle version, export cancellation, and export failure with retry (FE-014–FE-016, FE-030, FE-034, FE-042).
- **Export flow:** distinct GPX and diagnostic actions, deliberate bundle generation, progress/cancellation, system share presentation, snapshot timing disclosure, and post-export retention boundary (FE-006–FE-017, FE-047–FE-048).
- **Comparative engineering analysis:** two-Flight comparison, synchronized evidence, detector-candidate explanations, recorded/current/alternative-policy distinctions, missing-context assumptions, and adverse scenarios (FE-018–FE-026).
- **Safety and privacy:** no operational Flight commands in historical review, no automatic transmission, immutable evidence, explicit provisional state, and private recordings excluded from fixtures by default (FE-001, FE-007, FE-009, FE-026, FE-043–FE-044, FE-047).
- **Accessibility:** equivalent textual map relationships, VoiceOver ordering and labels, supported Dynamic Type, sufficient contrast, Reduce Motion playback behavior, and non-color-only evidence distinctions (FE-033, FE-045).
- **Adaptive layouts:** iPad Pro 11-inch portrait baseline, iPad Pro 11-inch landscape adaptation, iPhone 16 Pro portrait adaptation, and compact-width checks across supported iPhones; iPhone landscape remains excluded (FE-046).

## Behavior

### Evidence and recording semantics

1. **FE-001 — Recorded evidence remains immutable.** Export, analysis, replay, and debrief never add to, delete from, reorder, correct, or reinterpret the stored event journal or track as if the derived result had been recorded during the Flight.

2. **FE-002 — Navigation and physical completion remain distinct.** Choosing **Navigation Complete** records the end of navigation execution. Physical recording continues until landing and sustained stop are established or the pilot manually ends recording.

3. **FE-003 — Successful physical closure restores normal device idling.** When a recording closes, it no longer keeps the device awake as an active Flight. Export and debrief do not themselves keep the device awake beyond normal platform behavior.

4. **FE-004 — Objective observations and operational labels are distinguished.** Preparing, ground movement, airborne, landed awaiting stop, and stopped are recorded or replayed physical observations. Taxi-out and taxi-in are derived labels based on the ordering of ground movement around takeoff and landing; they are never presented as directly sensed pilot intent.

5. **FE-005 — Existing incomplete results remain valid evidence.** A manually ended Flight remains Complete or Incomplete according to the recording contract effective when it closed. Later analysis may explain missing evidence but does not retroactively change the stored outcome.

### Diagnostic export

6. **FE-006 — Every readable recording offers diagnostic export.** Flight detail offers **Export Diagnostic Bundle** for Complete, Incomplete, manually ended, active, and recoverable recordings when their retained evidence can be read.

7. **FE-007 — Active export is a snapshot.** Exporting an active or recoverable recording captures a consistent read-only snapshot labelled as active or recoverable. It does not stop location capture, close the recording, refresh recovery freshness, change navigation state, or prevent subsequent evidence from being recorded.

8. **FE-008 — Snapshot timing is disclosed.** An active or recoverable bundle identifies when the snapshot was taken and makes clear that later Flight evidence is not included.

9. **FE-009 — Diagnostic export is deliberate and local.** The app creates a bundle only after the pilot chooses the export action for a specific Flight. It then presents the normal system sharing experience, including compatible local destinations such as Files and AirDrop. The app performs no automatic transmission.

10. **FE-010 — The bundle is lossless for available evidence.** It includes the recording identity and state, closure information when present, original Flight Plan evidence, complete ordered event journal, all retained track segments and samples, and every validity or accuracy value retained with those samples.

11. **FE-011 — Supplemental measurements retain their meaning.** GPS altitude, barometric altitude, GPS course over ground, and device-relative heading remain separately identified. Missing or invalid values remain absent rather than being exported as zero.

12. **FE-012 — Segment boundaries and gaps are preserved.** The bundle retains the distinction between recorded track segments. Export never inserts estimated samples or a fictional path through a gap.

13. **FE-013 — Interpretation context accompanies evidence.** The bundle identifies its portable schema version and the available app, build, platform, and physical-flight detector policy context needed to interpret or replay it. Context that was not recorded at Flight time is labelled unavailable rather than reconstructed as fact.

14. **FE-014 — Export is forward-manageable.** A bundle identifies unsupported versions clearly. A newer analyzer may read older supported bundles without silently dropping evidence; an analyzer that cannot safely interpret a bundle reports that limitation without modifying the file.

15. **FE-015 — Export failure is non-destructive.** Cancellation or failure shares no incomplete file, leaves the recording unchanged, explains that export did not complete, and permits another attempt.

16. **FE-016 — Unreadable evidence is not misrepresented.** A corrupt or unsupported recording does not offer a bundle described as complete. If preserved raw diagnostic material can safely be exported, the action and resulting bundle explicitly identify its limited or unsupported status.

17. **FE-017 — Diagnostic and GPX exports remain distinct.** Existing GPX export remains a track-oriented interoperability format. The diagnostic bundle is the complete evidence format; neither format is described as a substitute for the other.

### Local analysis and detector replay

18. **FE-018 — Analysis remains local by default.** The supported developer analysis workflow consumes selected bundles and produces its report without uploading their contents or requiring a remote account.

19. **FE-019 — Multiple Flights can be compared.** The analyst can load at least two compatible bundles in one report and distinguish every displayed track, event, recorded outcome, and replay result by Flight.

20. **FE-020 — The report synchronizes evidence.** Selecting a time, sample, or event synchronizes the planned route, recorded track, aircraft position when available, telemetry, and event timeline.

21. **FE-021 — Physical detection is explainable.** Detector replay shows the evidence evaluated for phase candidates, when a candidate began, completed, was interrupted, or reset, and which recorded measurement or quality condition caused each result.

22. **FE-022 — Recorded and replayed results are distinct.** The report never presents a replayed transition as an event that occurred during the Flight. Recorded transitions, current-policy replay, and alternative-policy replay are visually and textually distinguishable.

23. **FE-023 — Policy comparisons are deterministic.** Replaying the same bundle with the same identified policy produces the same ordered results. Reports identify the policy used for each result.

24. **FE-024 — Missing historical context is explicit.** When an older recording lacks a policy version, captured detector reference, or other diagnostic context, the report identifies the assumption required for replay and does not claim an exact reconstruction of the original internal decision.

25. **FE-025 — Detector changes require comparative evidence.** A proposed physical-flight detection change is not accepted solely because it closes a previously incomplete Flight. Review includes the known failed Flight, a known successful Flight, and adverse scenarios such as taxi stops, noisy stationary samples, GPS gaps, differing airport elevations, and interrupted recovery.

26. **FE-026 — Private recordings are not test fixtures by default.** Exact routes, timestamps, and operational actions remain local. Repository fixtures use private recordings only after explicit owner approval and sanitization, or use derived synthetic evidence that preserves the relevant detector characteristics.

### Event-to-position correlation

27. **FE-027 — Actions retain their recorded time and origin.** The debrief shows when each recorded pilot, automatic, recovery, or system event occurred and does not replace that time with a correlated sample time.

28. **FE-028 — Correlated positions disclose uncertainty.** When an event did not record an exact position, the debrief may associate it with a nearby sample from the same track segment. It displays that the location is correlated, the difference between event and sample time, and the available positional accuracy.

29. **FE-029 — Correlation never crosses a gap.** An event is not assigned a map position by interpolating between track segments or across a known recording gap.

30. **FE-030 — Unlocated events remain visible.** When no sufficiently trustworthy sample is close enough, the event remains in the timeline without a map position and explains why no position is shown.

31. **FE-031 — Directly recorded positions remain distinct.** An event that already contains a disclosed position, such as a successful Position Check result, uses that recorded position and identifies it as direct evidence rather than correlation.

### In-app debrief

32. **FE-032 — Debrief is historical, not live navigation.** Flight detail provides entry to a debrief for retained evidence. Its map and aircraft marker are explicitly historical and cannot be mistaken for live Cockpit position guidance.

33. **FE-033 — Planned and actual paths are distinguishable.** The map presents the immutable recorded Flight Plan and the available recorded track using treatments that remain distinguishable without relying on color alone.

34. **FE-034 — Gaps remain visible.** Track rendering stops at segment boundaries and makes partial or unavailable GPS coverage understandable. It never draws a connecting line through missing evidence.

35. **FE-035 — Timeline, map, and telemetry share selection.** Scrubbing the timeline or selecting an event updates the map and available telemetry to the same evidence time. Selecting a track position updates the timeline and telemetry correspondingly.

36. **FE-036 — Debrief exposes relevant measurements.** When available, the pilot can inspect recorded position, GPS altitude, barometric altitude, ground speed, course over ground, device-relative heading, and their associated accuracy or validity information.

37. **FE-037 — Reached actions are inspectable.** For every recorded destination, identification-point, or waypoint reach action, the pilot can select the event and see its correlated position or the explicit absence of a trustworthy position.

38. **FE-038 — Route following uses objective measurements.** Debrief may show cross-track distance, along-track progress, closest approach to navigation points, and actual-versus-planned course or altitude. These are measurements, not a pass/fail grade.

39. **FE-039 — Altitude changes are derived observations.** Climbs and descents derived from telemetry identify their source as GPS altitude, barometric altitude, or both. They are not represented as recorded pilot actions, and disagreement or missing coverage remains visible.

40. **FE-040 — Recorded actions remain complete and ordered.** The timeline includes relevant navigation actions, revisions, undo, automatic transitions, physical-phase changes, availability changes, recovery events, manual end, and closure in deterministic order.

41. **FE-041 — Loading and generation are cancellable.** Leaving debrief while evidence is loading or projections are being generated cancels presentation work without changing the recording. Returning starts a fresh read of retained evidence.

42. **FE-042 — Empty and limited states are explicit.** Debrief distinguishes no usable GPS, partial GPS, action-only recording, active snapshot, unsupported evidence, and unreadable evidence. Available action history remains reviewable when track evidence is absent.

43. **FE-043 — Active evidence is visibly provisional.** A debrief opened from an active snapshot identifies that the Flight is still recording and that duration, track, events, outcome, and detector analysis may change after the snapshot.

44. **FE-044 — Historical review cannot operate the Flight.** Debrief offers no Start Leg, reach, revise, undo, navigation-complete, end-recording, recovery, or other operational command.

45. **FE-045 — Accessibility is equivalent.** Map-only relationships have an equivalent textual presentation. Events, gaps, planned versus actual paths, selection, telemetry validity, and recorded versus replayed states are understandable with VoiceOver, supported Dynamic Type, sufficient contrast, and Reduce Motion.

46. **FE-046 — Layout adapts without changing meaning.** iPad portrait is the primary experience; iPad landscape and iPhone portrait may rearrange map, timeline, telemetry, and event list, but preserve the same evidence, terminology, selection, and disclosure rules.

### Privacy, deletion, and compatibility

47. **FE-047 — Recordings remain on-device unless deliberately exported.** Opening debrief, generating derived metrics, or replaying detection does not transmit evidence or create a shared copy.

48. **FE-048 — Exported files are outside app retention.** After the pilot shares or saves a bundle, deleting the in-app recording does not claim to delete copies held by Files, AirDrop recipients, backups, or other destinations.

49. **FE-049 — Deleting the source ends in-app access.** Existing deletion confirmation continues to identify that the retained track and action history will be removed. After successful deletion, the app cannot open its debrief or regenerate exports from that recording.

50. **FE-050 — Existing recordings degrade honestly.** Recordings created before this feature remain eligible for export and debrief to the extent their retained schema can be read. Newly introduced context is shown as unavailable when it was not captured historically.

### Historical playback

51. **FE-051 — Playback is explicitly controlled.** Historical playback advances the shared map, telemetry, and timeline selection only while Play is active. Pause stops advancement at the selected evidence time. Neither control performs or replays an operational Flight command.

52. **FE-052 — Playback rate is separate from timeline position.** The playback-rate selector offers ×1, ×2, and ×5 independently of the elapsed-time scrubber. Changing rate affects only how quickly historical selection advances; it does not alter recorded timestamps, measurements, correlations, or derived results.

53. **FE-053 — Timeline seeking uses time semantics.** The scrubber presents selected elapsed time and total Flight duration without slow/fast transport symbols. Dragging or selecting it seeks to evidence time and remains available while playback is paused.

## Planning status

- Product discovery: completed through owner-approved grilling decisions on 2026-11-16 and 2026-11-17.
- Product specification: revision 02 approved by John on 2026-11-17.
- Experience design: Figma Directions 01–05 and the paired product/design baseline approved by John on 2026-11-17.
- Technical design: [technical agreement](../technical/FLIGHT-EVIDENCE-EXPORT-AND-DEBRIEF_TECHNICAL.md) approved by John on 2026-11-17.
- Delivery tickets: [six-slice vertical breakdown](FLIGHT-EVIDENCE-EXPORT-AND-DEBRIEF_DELIVERY-PLAN.md) approved by John on 2026-11-17; not published.
- Implementation: not authorized by this specification draft.

## Approved product decisions captured

- One evidence foundation supports both pilot debrief and engineering diagnosis.
- Lossless export precedes the polished in-app debrief.
- Active and recoverable recordings are exportable as read-only snapshots.
- Navigation completes manually at the final waypoint flow; physical recording continues through landing, taxi, and sustained stop.
- A failed and a successful real Flight should be compared before detector behavior changes.
- Analysis remains local and produces a portable self-contained report.
- Derived positions, phases, altitude changes, and route measurements disclose uncertainty and provenance.
- Private Flight data stays outside repository history unless explicitly approved and sanitized.
- The portable evidence format is versioned for future analyzers but does not initially add production-app import.
- Implementation and issue publication require separate approval after product, design, and technical gates.
