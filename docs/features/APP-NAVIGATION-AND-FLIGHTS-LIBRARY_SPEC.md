# App Navigation and Flights Library — Product Specification

Status: approved paired product and design baseline. Scope was confirmed on 2026-11-01, and the feature owner approved the complete Figma design and paired baseline on 2026-11-02. This describes desired behavior, not the current implementation.

## Summary

Provide persistent navigation between Cockpit, an offline Flights library, and Settings. Pilots import prepared navigation plans into Flights, inspect them, and explicitly load them into Cockpit without losing an existing session merely by switching destinations.

## Scope and terminology

Use the definitions of Navigation plan, Flights, Cockpit, and Flight session in the [domain glossary](../../GLOSSARY.md).

Included: app navigation, local plan storage, import, inspection, loading, replacement, removal, restart, and an explanatory Settings placeholder.

Excluded: plan creation or editing, actual settings, Charts, History, cloud synchronization, and restoring flight sessions after app termination. Plans continue to be prepared in the external Navigation Editor. No inactive destinations advertise future features.

Existing cockpit behavior remains governed by [Flying a Leg](FLYING-A-LEG_SPEC.md) and the [current progression policy](PROGRESSION-POLICY_SPEC.md). This feature does not add a progression-policy setting or change the pilot's navigation authority.

## Figma

- Design status: `approved`.
- Stable file: [**App Navigation and Flights Library**](https://www.figma.com/design/FDSRcz1yl7bkSoziKvGzQ1), file key `FDSRcz1yl7bkSoziKvGzQ1`, in the **Navigation Flight** Figma project. The feature owner independently verified the project location on 2026-11-02.
- Approved iteration **02 · Adaptive Navigation Direction**: [iPad Pro 11-inch portrait](https://www.figma.com/design/FDSRcz1yl7bkSoziKvGzQ1?node-id=8-38) `8:38`, [iPad Pro 11-inch landscape](https://www.figma.com/design/FDSRcz1yl7bkSoziKvGzQ1?node-id=8-90) `8:90`, [iPhone 16 Pro portrait](https://www.figma.com/design/FDSRcz1yl7bkSoziKvGzQ1?node-id=8-146) `8:146`, review index `8:209`, and local row component `8:197`. Iteration **01 · Populated Flights** remains as superseded historical evidence.
- Required location: one stable feature file in the [Navigation Flight Figma project](https://www.figma.com/files/folder/676737789).
- Approved complete expansion: [coverage](https://www.figma.com/design/FDSRcz1yl7bkSoziKvGzQ1?node-id=11-35) `11:35`, [library/import](https://www.figma.com/design/FDSRcz1yl7bkSoziKvGzQ1?node-id=16-181) `16:181`, [inspection/session](https://www.figma.com/design/FDSRcz1yl7bkSoziKvGzQ1?node-id=16-34) `16:34`, and [shell/removal/accessibility](https://www.figma.com/design/FDSRcz1yl7bkSoziKvGzQ1?node-id=16-330) `16:330`.
- Approved spec revision: [`3c035f2dedd1dfce6a3b1354ba62d2d3eceb69c5`](https://github.com/johnbenz13/NavigationFlight/blob/3c035f2dedd1dfce6a3b1354ba62d2d3eceb69c5/docs/features/APP-NAVIGATION-AND-FLIGHTS-LIBRARY_SPEC.md). Direction, complete-design, and paired-baseline approver: feature owner; approval date: 2026-11-02.
- Follow the [Product Spec + Figma Workflow](../workflows/PRODUCT-SPEC-FIGMA-WORKFLOW.md). The repository spec owns behavior; approved Figma nodes own visual presentation. Resolve conflicts through the feature owner.
- First direction proposal: the populated Flights list and native adaptive app navigation on iPad Pro 11-inch portrait. Show the floating top tab bar with Flights selected, plus the title, route, import date, loaded-plan indication, and + Add action. Defer complete state coverage until explicit main-screen direction approval.
- Direction brief confirmed by the feature owner on 2026-11-01:
  - Use native iOS styling: a clear title, restrained grouped rows, SF Symbols, and a prominent **+ Add** toolbar action.
  - Use a single-column list. Each row presents the plan title first, departure → destination second, and last-imported date third. Identify the loaded plan with a text-and-icon **Loaded in Cockpit** badge. Omit map thumbnails and additional metadata from this first proposal.
  - Show several saved plans, including one currently loaded, to review hierarchy and the loaded-plan distinction. Use the native iPad floating top tab bar with Flights selected. Keep the Flights navigation title and prominent **+ Add** toolbar action distinct from the app-level tab shell.
  - Use native adaptive tab presentation rather than custom navigation chrome. Regular-width iPad presents a floating top tab bar that can adapt into a leading sidebar; iPhone portrait and compact-width iPad present a bottom tab bar. The system owns the exact material, geometry, spacing, and transition animation.
  - Keep the three destinations fixed, labeled, non-customizable, and ordered **Cockpit**, **Flights**, **Settings**. Use the semantic SF Symbols `airplane`, `folder`, and `gearshape`; selection combines system tint, a filled-symbol variant where available, visible labels, and the platform selected state.
  - These decisions establish the proposal brief; they do not approve an unseen main-screen design. Empty states, inspection, confirmations, and secondary layouts remain deferred until explicit main-screen direction approval.
- Direction-draft limitations: the feature owner approved **Inter** as a draft font because Figma lists SF Pro but renders it as missing. Editable vector icons stand in for the intended named SF Symbols. Implementation retains native system typography and SF Symbols. Apple library imports were denied, so rows and styling use local editable elements.
- Draft verification: iteration 02 was rendered and inspected on 2026-11-02. The primary portrait frame shows the native floating top-tab direction, the canonical wide frame shows the expanded sidebar, and the compact portrait frame shows bottom navigation. All three retain the Flights title, prominent **+ Add** action, populated plan hierarchy, and text-and-icon loaded state. Structural inspection found editable text/vector layers, no image-filled nodes, no empty or zero-width text, and consistent use of the approved Inter draft substitution. The feature owner approved this main-screen direction on 2026-11-02.
- Shared baseline: the approved Figma nodes and approved spec revision above form the paired baseline for implementation.
- Design coverage is mapped on Figma page **03 · Design Coverage**, node `11:35`, with 18 checklist rows covering §§1–35, adaptive layouts, accessibility, protected-work confirmations, errors, cancellation, and traceability. The approved complete expansion is represented on **04 · Library and import flows** (`16:181`, content root `16:182`), **05 · Inspection and session flows** (`16:34`, content root `16:35`), and **06 · Shell removal and accessibility** (`16:330`, content root `16:331`).
- Implementation must use the approved spec revision and exact approved Figma nodes above. Any behavioral or visual change starts a new named iteration under the paired-artifact workflow.

## Behavior

### App navigation and launch

1. The app exposes three top-level destinations in this order: **Cockpit**, **Flights**, **Settings**. Every destination has a text label and icon, with the selected destination clearly identifiable.
2. Navigation remains available in Cockpit, including during an active flight. Selecting a destination never ends, replaces, restarts, or resets the current session.
3. Switching destinations preserves the loaded plan, progress, pilot edits, ongoing timing, and Cockpit presentation state, including the pilot's current map and interaction context. Returning shows the same session; elapsed time does not pause or restart because Cockpit was not visible.
4. Switching destinations preserves each destination's place, including the Flights list position or open inspection. Loading a plan switches to Cockpit; returning to Flights returns to that plan's inspection.
5. A fresh app launch opens Flights. Previously saved navigation plans remain available, but the prior flight session is not restored. Returning to an app that remains running is not a fresh launch and must preserve its current session and destination.
6. With no plan loaded, Cockpit explains the empty state and offers **Choose a Flight**, which selects Flights. Plan import is offered through Flights rather than a separate Cockpit import flow.
7. Settings presents an explanatory placeholder that settings will be available there. It contains no functional settings in this feature.

### Devices and adaptive presentation

8. The primary design target is **iPad Pro 11-inch portrait**. Secondary references are **iPad Pro 11-inch landscape** and **iPhone 16 Pro portrait**, with compact-layout coverage across other supported iPhone 16-generation-or-later sizes. iPhone landscape is outside the design baseline.
9. Navigation uses the platform's native adaptive tab presentation. Regular-width iPad presents a floating top tab bar that can adapt into a leading sidebar. iPhone portrait and compact-width iPad present a bottom tab bar. Available width and the system presentation determine the shell; orientation alone must not force a sidebar. The canonical wide iPad landscape Figma frame shows the expanded sidebar, while the primary iPad portrait frame shows the floating top tab bar.
10. Every presentation exposes the same fixed destinations and ordering, with customization and reordering disabled. Rotation, window resizing, or changing between tab bar and sidebar preserves selection, navigation position, session state, and timing. Adapting the shell must not obscure essential Cockpit actions or information. The Cockpit map may extend visually beneath floating system material, but essential flight controls, status information, and tap targets remain outside its occlusion region.
11. Destination labels, plan information, and actions must remain understandable with VoiceOver and supported Dynamic Type sizes. Selection and the loaded-plan state must not rely on color alone. Destructive confirmations must identify the action and provide a clear cancellation path.

### Flights library and import

12. Flights contains imported navigation plans, not records of previous sessions. Saved plans are available offline across launches without requiring continued access to the original imported file. This is a plan-storage promise, not a new promise about offline map coverage.
13. An empty library explains how to add a plan and offers **+ Add**. The same action remains available in a populated library.
14. Each list item shows the plan title, departure → destination, and last-imported date. Sort most recently imported first. Clearly indicate the plan currently loaded in Cockpit, when its library entry still exists.
15. **+ Add** opens a file picker for one `.fplnav` file at a time. Selecting a file validates it against the app's supported plan requirements before saving. This feature does not relax existing compatibility or execution-data requirements.
16. Successful import saves the plan to the library and makes it available for inspection and loading. Import alone does not select Cockpit, replace a session, or start flight timing.
17. Cancelling the picker changes neither library nor session. An unreadable, malformed, unsupported, or otherwise invalid file produces an understandable error and leaves existing library contents and the current session unchanged. A failed save must not be reported as a successful import.
18. Importing a different revision of a plan already in the library requires confirmation before replacing its saved copy. Cancellation preserves the previous copy. Successful replacement refreshes its import date and list ordering. Replacement must not create a second library entry for that same plan.
19. Updating a library copy never changes the version already loaded in Cockpit. The loaded session continues using its original plan until the pilot explicitly loads the update.
20. A plan's identity is its `.fplnav` **project.id**. Different identifiers represent distinct plans even when titles match. For the same identifier, **project.modifiedAt** identifies the revision: equal timestamps represent the same revision, a later timestamp a newer revision, and an earlier timestamp an older revision. **project.createdAt** records the plan's creation date rather than its revision. The imported modification date is distinct from the library's last-imported date. A same-revision reimport shows **Already imported** without replacing the saved copy or refreshing its import date. A newer revision requires replacement confirmation. An older revision may replace the saved copy only after confirmation explicitly warns that it is an older revision. None of these imports changes the loaded Cockpit session.
21. Importing from a remote file provider may require connectivity to obtain the source file. Once successfully saved locally, using the plan must not require the provider or a network connection.

### Inspection and loading

22. Selecting a library item opens plan inspection before loading. Inspection presents the selected plan for review and offers **Load in Cockpit** when that saved version is not already loaded.
23. Loading selects Cockpit with a fresh session for the chosen plan. It does not start a leg timer; starting timing remains an explicit pilot action under existing Cockpit behavior.
24. When there is no current session, or the current session is untouched, another plan may load directly. If the current session contains recorded progress or pilot edits, loading a different plan requires confirmation that the current session will end and its progress and edits will be discarded.
25. Protection is not limited to a running timer. Recorded progress or edits still require confirmation when timing is stopped or navigation is complete. Merely switching tabs never triggers session replacement.
26. Cancelling replacement leaves the original session unchanged, including its ongoing timing. Confirming successfully replaces the session and selects Cockpit. A failed load must preserve the original session and explain the failure.
27. Inspecting the same plan version already loaded offers **Return to Cockpit** as the primary action. This selects Cockpit without creating a fresh session or resetting progress.
28. If the library holds an updated version of the loaded plan, inspection offers **Return to Cockpit** and **Load Updated Plan**. Return preserves the existing version and session; loading the update creates a fresh session and follows the same recorded-work confirmation rule.
29. The loaded plan's inspection includes a separate **Restart Flight** action. Restarting creates a fresh session without starting timing. If progress or pilot edits would be discarded, require confirmation; cancellation preserves the session. Return to Cockpit remains the primary action for the already loaded version.
30. When an updated library version exists, **Restart Flight** restarts the original loaded version. **Load Updated Plan** explicitly loads the saved update. Restarting never silently updates the plan being flown.
31. Protected pilot work includes recorded timing and progress, committed edits, uncommitted ETA/heading drafts, and checklist acknowledgements. Replacing or restarting a session containing any of that work requires confirmation. Map movement, opening panels, and selecting a leg do not alone require confirmation.

### Removing plans

32. A pilot can remove a saved plan from Flights after confirmation. Cancellation preserves it. Confirmed removal deletes the library copy; a failed removal is explained without falsely reporting success.
33. Removing a loaded plan does not end or change its current Cockpit session. The confirmation explains that the library copy is removed while the loaded session remains usable until replacement or app closure.
34. If the last plan is removed, Flights shows its empty state. No removed library item remains offered for inspection or loading, while Cockpit remains accessible if its session is still loaded.
35. After removal of the loaded plan's library copy, Cockpit retains access to that loaded version's inspection and **Restart Flight**. Neither inspecting nor restarting recreates the saved library entry; adding the plan to Flights again requires reimporting it.

## Baseline readiness

The behavioral questions raised during discovery are resolved, including the import policy confirmed on 2026-11-01. Additional uncovered gaps must remain visible rather than being decided through visual invention.

Figma direction and complete design approval remain human-owned gates. Scope confirmation does not approve a visual proposal or authorize implementation against unreviewed nodes.
