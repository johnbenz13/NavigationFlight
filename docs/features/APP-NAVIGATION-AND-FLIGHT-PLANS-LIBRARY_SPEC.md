# App Navigation and Flight Plans Library — Product Specification

Status: approved paired product and design baseline. The feature owner approved corrective iteration **03 · Flight Plans Terminology Correction** with this corrected product specification on 2026-11-02. This describes desired behavior, not the current implementation.

## Summary

Provide persistent navigation between the Cockpit, Flight Plans, and Settings app sections. Pilots import prepared Flight Plans into the offline Flight Plans library, inspect them, and explicitly load them into Cockpit without losing an existing Flight merely by switching app sections.

## Scope and terminology

Use the definitions of Flight Plan, Flight Plans, Flight, Cockpit, and App section in the [domain glossary](../../GLOSSARY.md). Reserve destination for the aviation endpoint of a Flight Plan rather than an app-navigation concept.

Included: app navigation, local Flight Plan storage, import, inspection, loading, replacement, removal, restart, and an explanatory Settings placeholder.

Excluded: Flight Plan creation or editing, actual settings, Charts, Flights history, cloud synchronization, and restoring Flights after app termination. Flight Plans continue to be prepared in the external Navigation Editor. No inactive app sections advertise future features.

Existing cockpit behavior remains governed by [Flying a Leg](FLYING-A-LEG_SPEC.md) and the [current progression policy](PROGRESSION-POLICY_SPEC.md). This feature does not add a progression-policy setting or change the pilot's navigation authority.

## Figma

- Design status: `approved`.
- Stable file: [**App Navigation and Flights Library**](https://www.figma.com/design/FDSRcz1yl7bkSoziKvGzQ1), file key `FDSRcz1yl7bkSoziKvGzQ1`, in the **Navigation Flight** Figma project. Rename the stable file to **App Navigation and Flight Plans Library** in the corrective iteration. The feature owner independently verified the project location on 2026-11-02.
- Approved iteration **02 · Adaptive Navigation Direction**: [iPad Pro 11-inch portrait](https://www.figma.com/design/FDSRcz1yl7bkSoziKvGzQ1?node-id=8-38) `8:38`, [iPad Pro 11-inch landscape](https://www.figma.com/design/FDSRcz1yl7bkSoziKvGzQ1?node-id=8-90) `8:90`, [iPhone 16 Pro portrait](https://www.figma.com/design/FDSRcz1yl7bkSoziKvGzQ1?node-id=8-146) `8:146`, review index `8:209`, and local row component `8:197`. Iteration **01 · Populated Flights** remains as superseded historical evidence.
- Required location: one stable feature file in the [Navigation Flight Figma project](https://www.figma.com/files/folder/676737789).
- Approved complete expansion: [coverage](https://www.figma.com/design/FDSRcz1yl7bkSoziKvGzQ1?node-id=11-35) `11:35`, [library/import](https://www.figma.com/design/FDSRcz1yl7bkSoziKvGzQ1?node-id=16-181) `16:181`, [inspection/session](https://www.figma.com/design/FDSRcz1yl7bkSoziKvGzQ1?node-id=16-34) `16:34`, and [shell/removal/accessibility](https://www.figma.com/design/FDSRcz1yl7bkSoziKvGzQ1?node-id=16-330) `16:330`.
- Previously approved spec revision: [`3c035f2dedd1dfce6a3b1354ba62d2d3eceb69c5`](https://github.com/johnbenz13/NavigationFlight/blob/3c035f2dedd1dfce6a3b1354ba62d2d3eceb69c5/docs/features/APP-NAVIGATION-AND-FLIGHTS-LIBRARY_SPEC.md). Direction, complete-design, and paired-baseline approver: feature owner; approval date: 2026-11-02. This remains historical approval evidence and is no longer the implementation baseline.
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
- Historical baseline: the previously approved Figma nodes and spec revision above remain review evidence but no longer form an implementation baseline.
- Terminology correction requested by the feature owner on 2026-11-02: rename the current app section and library from **Flights** to **Flight Plans**; use **Flight Plan** for preparation imported from `.fplnav`; use **Flight** for an actual execution created by loading or restarting a Flight Plan; use **app section** rather than **destination** for top-level app navigation. Preserve **destination** for the aviation endpoint. The prior layout direction remains relevant, but all visible and annotated terminology must be corrected in a new named Figma iteration before renewed approval.
- Approved corrective iteration **03 · Flight Plans Terminology Correction**: [iPad Pro 11-inch portrait](https://www.figma.com/design/FDSRcz1yl7bkSoziKvGzQ1?node-id=28-187) `28:187`, [iPad Pro 11-inch landscape](https://www.figma.com/design/FDSRcz1yl7bkSoziKvGzQ1?node-id=28-239) `28:239`, [iPhone 16 Pro portrait](https://www.figma.com/design/FDSRcz1yl7bkSoziKvGzQ1?node-id=28-295) `28:295`, [review index](https://www.figma.com/design/FDSRcz1yl7bkSoziKvGzQ1?node-id=28-358) `28:358`, and local Flight Plan row component `28:346`.
- Corrective complete-coverage pages are [design coverage](https://www.figma.com/design/FDSRcz1yl7bkSoziKvGzQ1?node-id=28-371) `28:371`, [library/import](https://www.figma.com/design/FDSRcz1yl7bkSoziKvGzQ1?node-id=28-34) `28:34`, [inspection/Flight protection](https://www.figma.com/design/FDSRcz1yl7bkSoziKvGzQ1?node-id=28-502) `28:502`, and [shell/removal/accessibility](https://www.figma.com/design/FDSRcz1yl7bkSoziKvGzQ1?node-id=28-649) `28:649`.
- Historical design coverage is mapped on Figma page **03 · Design Coverage**, node `11:35`, with 18 checklist rows covering §§1–35, adaptive layouts, accessibility, protected-work confirmations, errors, cancellation, and traceability. The previously approved complete expansion is represented on **04 · Library and import flows** (`16:181`, content root `16:182`), **05 · Inspection and session flows** (`16:34`, content root `16:35`), and **06 · Shell removal and accessibility** (`16:330`, content root `16:331`).
- Paired-baseline approval: corrective iteration **03**, this corrected product-spec working revision, feature owner, 2026-11-02. The immutable GitHub permalink must be added to this record and the Figma review index when these documentation changes are committed. The exact corrective nodes above and this specification are the implementation baseline. Any later behavioral or visual change starts another named iteration under the paired-artifact workflow.

## Behavior

### App navigation and launch

1. The app exposes three top-level app sections in this order: **Cockpit**, **Flight Plans**, **Settings**. Every app section has a text label and icon, with the selected section clearly identifiable.
2. App navigation remains available in Cockpit, including during an active Flight. Selecting an app section never ends, replaces, restarts, or resets the current Flight.
3. Switching app sections preserves the loaded Flight Plan, Flight progress, pilot edits, ongoing timing, and Cockpit presentation state, including the pilot's current map and interaction context. Returning shows the same Flight; elapsed time does not pause or restart because Cockpit was not visible.
4. Switching app sections preserves each section's place, including the Flight Plans list position or open inspection. Loading a Flight Plan switches to Cockpit; returning to Flight Plans returns to that Flight Plan's inspection.
5. A fresh app launch opens Flight Plans. Previously saved Flight Plans remain available, but the prior Flight is not restored. Returning to an app that remains running is not a fresh launch and must preserve its current Flight and app section.
6. With no Flight loaded, Cockpit explains the empty state and offers **Choose a Flight Plan**, which selects Flight Plans. Flight Plan import is offered through Flight Plans rather than a separate Cockpit import flow.
7. Settings presents an explanatory placeholder that settings will be available there. It contains no functional settings in this feature.

### Devices and adaptive presentation

8. The primary design target is **iPad Pro 11-inch portrait**. Secondary references are **iPad Pro 11-inch landscape** and **iPhone 16 Pro portrait**, with compact-layout coverage across other supported iPhone 16-generation-or-later sizes. iPhone landscape is outside the design baseline.
9. Navigation uses the platform's native adaptive tab presentation. Regular-width iPad presents a floating top tab bar that can adapt into a leading sidebar. iPhone portrait and compact-width iPad present a bottom tab bar. Available width and the system presentation determine the shell; orientation alone must not force a sidebar. The canonical wide iPad landscape Figma frame shows the expanded sidebar, while the primary iPad portrait frame shows the floating top tab bar.
10. Every presentation exposes the same fixed app sections and ordering, with customization and reordering disabled. Rotation, window resizing, or changing between tab bar and sidebar preserves selection, navigation position, Flight state, and timing. Adapting the shell must not obscure essential Cockpit actions or information. The Cockpit map may extend visually beneath floating system material, but essential flight controls, status information, and tap targets remain outside its occlusion region.
11. App-section labels, Flight Plan information, and actions must remain understandable with VoiceOver and supported Dynamic Type sizes. Selection and the loaded-Flight-Plan state must not rely on color alone. Destructive confirmations must identify the action and provide a clear cancellation path.

### Flight Plans library and import

12. Flight Plans contains imported Flight Plans, not records of Flights. Saved Flight Plans are available offline across launches without requiring continued access to the original imported file. This is a Flight-Plan-storage promise, not a new promise about offline map coverage.
13. An empty library explains how to add a Flight Plan and offers **+ Add**. The same action remains available in a populated library.
14. Each list item shows the Flight Plan title, departure → destination, and last-imported date. Sort most recently imported first. Clearly indicate the Flight Plan currently loaded in Cockpit, when its library entry still exists.
15. **+ Add** opens a file picker for one `.fplnav` file at a time. Selecting a file validates it against the app's supported Flight Plan requirements before saving. This feature does not relax existing compatibility or planned-navigation requirements.
16. Successful import saves the Flight Plan to the library and makes it available for inspection and loading. Import alone does not select Cockpit, create or replace a Flight, or start Flight timing.
17. Cancelling the picker changes neither library nor Flight. An unreadable, malformed, unsupported, or otherwise invalid file produces an understandable error and leaves existing library contents and the current Flight unchanged. A failed save must not be reported as a successful import.
18. Importing a different revision of a Flight Plan already in the library requires confirmation before replacing its saved copy. Cancellation preserves the previous copy. Successful replacement refreshes its import date and list ordering. Replacement must not create a second library entry for that same Flight Plan.
19. Updating a library copy never changes the version already loaded in Cockpit. The loaded Flight continues using its original Flight Plan until the pilot explicitly loads the update.
20. A Flight Plan's identity is its `.fplnav` **project.id**. Different identifiers represent distinct Flight Plans even when titles match. For the same identifier, **project.modifiedAt** identifies the revision: equal timestamps represent the same revision, a later timestamp a newer revision, and an earlier timestamp an older revision. **project.createdAt** records the Flight Plan's creation date rather than its revision. The imported modification date is distinct from the library's last-imported date. A same-revision reimport shows **Already imported** without replacing the saved copy or refreshing its import date. A newer revision requires replacement confirmation. An older revision may replace the saved copy only after confirmation explicitly warns that it is an older revision. None of these imports changes the loaded Flight.
21. Importing from a remote file provider may require connectivity to obtain the source file. Once successfully saved locally, using the Flight Plan must not require the provider or a network connection.

### Inspection and loading

22. Selecting a library item opens Flight Plan inspection before loading. Inspection presents the selected Flight Plan for review and offers **Load in Cockpit** when that saved version is not already loaded.
23. Loading creates a distinct ready Flight from the chosen Flight Plan and selects Cockpit. It does not start a leg timer; starting timing remains an explicit pilot action under existing Cockpit behavior.
24. When there is no current Flight, or the current Flight is untouched, another Flight Plan may load directly. If the current Flight contains recorded progress or pilot edits, loading a different Flight Plan requires confirmation that the current Flight will end and its progress and edits will be discarded.
25. Protection is not limited to a running timer. Recorded progress or edits still require confirmation when timing is stopped or navigation is complete. Merely switching app sections never triggers Flight replacement.
26. Cancelling replacement leaves the original Flight unchanged, including its ongoing timing. Confirming successfully replaces the Flight and selects Cockpit. A failed load must preserve the original Flight and explain the failure.
27. Inspecting the same Flight Plan version already loaded offers **Return to Cockpit** as the primary action. This selects Cockpit without creating a fresh Flight or resetting progress.
28. If the library holds an updated version of the loaded Flight Plan, inspection offers **Return to Cockpit** and **Load Updated Plan**. Return preserves the existing version and Flight; loading the update creates a distinct ready Flight and follows the same recorded-work confirmation rule.
29. The loaded Flight Plan's inspection includes a separate **Restart Flight** action. Restarting creates a distinct ready Flight with a new identity without starting timing. If progress or pilot edits would be discarded, require confirmation; cancellation preserves the current Flight. Return to Cockpit remains the primary action for the already loaded version.
30. When an updated library version exists, **Restart Flight** restarts from the original loaded Flight Plan version. **Load Updated Plan** explicitly loads the saved update. Restarting never silently updates the Flight Plan being flown.
31. Protected pilot work includes recorded timing and progress, committed edits, uncommitted ETA/heading drafts, and checklist acknowledgements. Replacing or restarting a Flight containing any of that work requires confirmation. Map movement, opening panels, and selecting a leg do not alone require confirmation.

### Removing plans

32. A pilot can remove a saved Flight Plan from Flight Plans after confirmation. Cancellation preserves it. Confirmed removal deletes the library copy; a failed removal is explained without falsely reporting success.
33. Removing a loaded Flight Plan does not end or change the current Flight. The confirmation explains that the library copy is removed while the Flight remains usable until replacement or app closure.
34. If the last Flight Plan is removed, Flight Plans shows its empty state. No removed library item remains offered for inspection or loading, while Cockpit remains accessible if a Flight is still loaded.
35. After removal of the loaded Flight Plan's library copy, Cockpit retains access to that loaded version's inspection and **Restart Flight**. Neither inspecting nor restarting recreates the saved library entry; adding the Flight Plan to Flight Plans again requires reimporting it.

## Baseline readiness

The behavioral questions raised during discovery are resolved, including the import policy confirmed on 2026-11-01. Additional uncovered gaps must remain visible rather than being decided through visual invention.

The feature owner approved the corrected product specification and complete corrective Figma iteration together on 2026-11-02. Implementation may proceed from that paired baseline, beginning with the terminology-migration prerequisite.
