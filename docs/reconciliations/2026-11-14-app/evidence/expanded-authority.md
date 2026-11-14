# Authority for the expanded reconciliation

[Back to the map](../README.md) · [Earlier authority record](authority.md)

Read on 2026-11-14 at `1a2d7e7`. These are written requirements and design references,
not fresh runtime verification. No original contract or approval record was changed.

## Explicit precedence and historical limits

- [Flying a Leg](../../../features/FLYING-A-LEG_SPEC.md) records John’s approval of
  Iterations 09–10 on November 6. Its earlier frames retain behavioral examples but
  do not override the current cockpit hierarchy. Its old “current implementation”
  table is a dated discovery record, not evidence of today's missing capabilities.
- [Operational Cues](../../../features/COCKPIT-OPERATIONAL-CUES_SPEC.md) records an
  approved complete paired baseline. Its timing, advisory-only and no-clipping rules
  remain relevant even where its frequency hierarchy conflicts with Flying a Leg.
- [Position Check](../../../features/POSITION-CHECK_SPEC.md) records paired approval
  on November 3, product revision `68e68e7`. “Implementation not started” and
  “candidate” wording elsewhere in that document is not proof of current absence.
- [Recording and Recovery](../../../features/AUTOMATIC-FLIGHT-RECORDING-AND-RECOVERY_SPEC.md)
  records approval of Iteration 03 on November 5, revision `14f2ed9`; some linked
  coverage is still labelled “under review.” Preserve both statements and reconcile
  their status rather than silently revoking the explicit approval.
- Recording explicitly supersedes fresh-launch non-restoration, Flying's recovery
  non-goal, and Position Check's volatile-only location restrictions. Time-bounded
  cockpit GPS disclosure remains required. Final waypoint completion stops navigation
  timing; it does not by itself end physical-flight recording.
- [Progression Policy](../../../features/PROGRESSION-POLICY_SPEC.md) describes
  reverse-engineered behavior dated October 22. Flying explicitly incorporates the
  automatic/manual behaviors; that does not approve a public progression preference.
  Release behavior is automatic; manual is a debug/test variant.

## Conflicting intent requiring a decision

| Topic | Explicit requirements | Interpretation |
| --- | --- | --- |
| Cockpit navigation | App Navigation §§8–10: native adaptive tabs/sidebar, unobscured essential controls. Flying §127: App Sections disclosure, no persistent cockpit tab bar. | No explicit shell supersession located. Four destinations are established; their cockpit presentation remains a cross-contract conflict. |
| Planned frequencies | Cues §§14–20: complete lower-console list, CURRENT/NEXT. Flying §§102, 104, 128: only Planned now/next in fixed console, complete list in Frequency Plan, no assertion about tuned state. | Hierarchy and wording need an explicit decision. Timing cues and advisory-only meaning can remain shared. |
| Section naming | Flying §127: Flight History. Recording §72: Flights. Glossary calls Flights future. | Recording establishes desired Flights; synchronize references without deleting historical wording. |
| Arrival action naming | Position Check preserves Waypoint Identified. Flying §105: Report Destination Identified / Report Destination Reached. | Preserve separate identification and reach observations while agreeing current names. |

## Coverage guide, not implementation claims

| Journey | Behavior to observe | Important limit |
| --- | --- | --- |
| Start/progress | Explicit Start; selected checklist; automatic successor at identical reach timestamp; manual successor stays ready; final navigation completion. | Manual is debug-only; sensor-driven recording remains a separate lifecycle. |
| Reports/undo | Identify differs from reach; skipping earlier IPs does not fabricate Actual ETA; 20-second undo restores whole prior state and expires during background. | A screenshot alone cannot prove atomic restoration or timestamp identity. |
| ETA/heading | Explicit drafts and commits; five-second ETA steps and moving timer floor; Check needs committed revision and preceding reached IP; heading revisions independent from reach. | Heading Check/Reference Heading is deferred, not missing delivery. |
| Map/disclosures | Track-up, distinct focus controls, auto-hide after four seconds, drift toggle, preview-only next leg, review-only history, independently available closed chips. | Synthetic off-chart route cannot verify real chart alignment. |
| Position Check | Deliberate approximately one-second hold; ten-second acquisition limit; ten-second disclosure from usable fix; cancel/expiry/context restore; immediate removal of unusable position. | Real permission, live sensor quality, haptics and VoiceOver need explicit evidence. |
| Recording | Loading arms; Start or credible takeoff promotes; no-location manual navigation; gaps not interpolated; physical closure separate from navigation complete. | Fixtures can show states without proving sensor classification or durable data quality. |
| Recovery | Blocking launch gate; captured five-minute default; relaunch does not refresh freshness; restore committed state, not drafts/camera/undo. | Seeded candidate presentation is not proof of a genuine crash/relaunch checkpoint. |
| Flights | Active/recoverable cannot export/delete; closed readable tracks can export GPX; detail preserves partial/gap information. | Opening share sheet alone does not verify exported GPX bytes. |
| Settings/accessibility | Bundled checklist selection; Larger Text and Reduce Motion; meaningful VoiceOver; no clipped cue values. | Future recovery-window preferences and template editor are not first-release requirements. |

Explicitly deferred: automatic CFI/off-track intervention, heading Check, configurable
recording, replay, cloud sync, rename/retention tools, JSON/CSV export. Their absence
must not be described as defects in this reconciliation.

## Expanded inspected design references

Read-only previews were downloaded and inspected on 2026-11-14. The exact node links
below are stable; downloaded bytes are retained with checksums. Figma did not provide
an immutable version identifier. A preview is desired presentation, never current-app evidence.

| Reference | Scope and caveat | Preview |
| --- | --- | --- |
| [Flying 198:118](https://www.figma.com/design/yvLXb8bUFBiZHqsag4hq6I?node-id=198-118) | Current App Sections design; conflicts with adaptive-tab contract. | [Image](../assets/figma/expanded/sections-198-118.png) |
| [Flying 198:182](https://www.figma.com/design/yvLXb8bUFBiZHqsag4hq6I?node-id=198-182) | Current full Frequency Plan disclosure and compact fixed references. | [Image](../assets/figma/expanded/frequency-198-182.png) |
| [Position Check 9:382](https://www.figma.com/design/hllTgfGTAG4cEXyqiDesSu?node-id=9-382) | Approved active disclosure; surrounding cockpit predates Flying's later hierarchy. | [Image](../assets/figma/expanded/position-active-9-382.png) |
| [Position Check 16:9](https://www.figma.com/design/hllTgfGTAG4cEXyqiDesSu?node-id=16-9) | Approved state/flow coverage; volatile-only footer is explicitly superseded by recording. | [Image](../assets/figma/expanded/position-states-16-9.png) |
| [Recording 11:97](https://www.figma.com/design/ZrGA7ZuOACWtXA4mR7cwdc?node-id=11-97) | Populated Flights panel; not complete large-screen chrome. | [Image](../assets/figma/expanded/recordings-11-97.png) |
| [Recording 38:275](https://www.figma.com/design/ZrGA7ZuOACWtXA4mR7cwdc?node-id=38-275) | Approved Iteration 03 fresh recovery gate. | [Image](../assets/figma/expanded/recovery-38-275.png) |
| [Flying 198:250](https://www.figma.com/design/yvLXb8bUFBiZHqsag4hq6I?node-id=198-250) | Current expanded checklist with selected-template title and noting disclaimer. | [Image](../assets/figma/expanded/checklist-198-250.png) |
| [Flying 206:984](https://www.figma.com/design/yvLXb8bUFBiZHqsag4hq6I?node-id=206-984) | Current closed disclosures coexist in a compact strip. | [Image](../assets/figma/expanded/closed-disclosures-206-984.png) |
| [Flying 199:918](https://www.figma.com/design/yvLXb8bUFBiZHqsag4hq6I?node-id=199-918) | Final-navigation state; numeric instruments retained, but reused active header is internally inconsistent and action is extended by Recording. | [Image](../assets/figma/expanded/final-complete-199-918.png) |
| [Recording 42:38](https://www.figma.com/design/ZrGA7ZuOACWtXA4mR7cwdc?node-id=42-38) | Approved recovery End confirmation, preserved-history explanation. | [Image](../assets/figma/expanded/recovery-end-42-38.png) |
| [Cues 6:82](https://www.figma.com/design/ZTfeKXbhjsqvZMagg9JPyq?node-id=6-82) | Larger Text stacking/no-clipping rule; full-list hierarchy conflicts with later Flying direction. | [Image](../assets/figma/expanded/cue-accessibility-6-82.png) |

Checksums and captured dimensions: [expanded design manifest](expanded-figma-assets.json).

### Additional inspected state references

| Reference | Exact node | Use |
| --- | --- | --- |
| Multiple recovery | [42:96](https://www.figma.com/design/ZrGA7ZuOACWtXA4mR7cwdc?node-id=42-96) | Gate identities and earliest continuation window; does not establish a confirmation layout. |
| Recorded detail | [11:127](https://www.figma.com/design/ZrGA7ZuOACWtXA4mR7cwdc?node-id=11-127) | General saved detail; Complete sample is not the Incomplete recovery variant. |
| IP reach and Undo | [199:442](https://www.figma.com/design/yvLXb8bUFBiZHqsag4hq6I?node-id=199-442) | Intended bounded correction affordance; compare current IP follow-up. |

All fourteen expanded previews are retained with hashes in the
[design manifest](expanded-figma-assets.json); six initial previews remain in batch01.

## Remaining-exploration source guidance

Read-only inspection on the unchanged baseline supports the next runtime observations:

- Starting-leg and calculation-mode selections are operational ready-Flight state,
  not merely inspection focus: `CockpitFeatureState.selectNextLeg/selectMode` call
  `Flight.selectReadyLeg`. Flying §§2–3 requires the selected ready leg to start.
  `RootView` arms the recording engine in a task keyed by Flight identity; the existing
  engine retains a private Flight. Reusing it at Start without synchronizing the new
  ready selection is a likely mechanism for a selection reset. This is a source-based
  hypothesis, not a replacement for the before/after runtime evidence or a verified fix.
- Position Check has existing synthetic inputs for on-track, position-only,
  no-sensible-intercept, extreme-displacement and permission-revoked states. Their
  coordinates match the near-zero official regression plan, not a real-chart route.
  The acquiring input never yields a fix, so retry can show another acquisition attempt
  but cannot establish successful sensor recovery.
- Stable disposable library IDs use disk recording storage when seeded Flights/recovery
  overrides are absent. Reusing the ID across actual process relaunches can observe
  checkpoint recovery; seeded gates alone cannot establish it.
- The single recovery seed is about one minute old in a five-minute window. No short
  recovery-window launch override was found. A countdown must actually expire before
  calling its result an observed expiry.
- Multiple-candidate selection directly calls Continue in the view and the coordinator
  closes other candidates as superseded. Recording §70 requires confirmation of that
  consequence. Runtime must establish whether an intervening confirmation exists.
- No supported checkpoint/closure-write-failure launch override was identified.
  A failure screen's source or a test expectation is not an observed runtime state.
- GPX export writes a generated file under the application's temporary directory.
  Reading that artifact after UI export can establish XML contents without sending it
  to another app or person. Seeded track contents still do not validate sensor capture.
- Debug import bypasses the system file importer. No app Documents file-sharing route
  was established. Real-provider import must be reached through a supported provider;
  copying a fixture into a private container alone is not equivalent.

These are observation aids. Application source, requirements and designs remain unchanged.

## Additional follow-up design inspection

- Recovery expiry [42:67](https://www.figma.com/design/ZrGA7ZuOACWtXA4mR7cwdc?node-id=42-67)
  explicitly explains Incomplete closure and offers View Flight/Continue to App.
  [Retained preview](../assets/figma/expanded/recovery-expired-42-67.png) supports G11's
  natural-expiry extension; observed S78 skips this result.
- Flying Iteration10 [Previous Leg198:320](https://www.figma.com/design/yvLXb8bUFBiZHqsag4hq6I?node-id=198-320)
  shows target outcomes and heading revision with time. Its example has no explicit
  revised-ETA/reference history, so it cannot establish the complete layout required by
  Flying §§70/74. [Retained preview](../assets/figma/expanded/previous-leg-198-320.png)
  is context, not proof that those missing variants are designed.
