# Choose how to start and correct navigation

[Back to the map](../README.md) · [Starting-leg discrepancy](../proposed/starting-and-correcting.md)

**Status:** new observations awaiting account review; S01–S56 approval is unchanged.
Observed 2026-11-14 on the same `1a2d7e7` baseline, iPad Pro 11-inch (M5), iOS 27.0
(24A434), portrait 834 × 1210. [Batch09](../evidence/capture-batch-09.md) retains actions,
exact synthetic two-leg input, screenshots, hierarchy and logs.

## S57 · Choose a later starting leg, then Start

In ready Plan Inspection, choose No wind. The inspection shows saved magnetic course
355° and explicitly says magnetic heading is unavailable in that mode. Choose starting
leg from Cockpit to return to inspection, then Next: the inspection selects Leg 2,
Synthetic waypoint 2 → Third waypoint. Returning to Cockpit shows Ready · Leg 2 of 2
and the same route. Tap Start directly, without loading or restarting a Flight:
the cockpit instead becomes Active · Leg 1 of 2 and opens the first leg's checklist.

![Ready inspection with No wind selected](../assets/current/batch-09/01-no-wind-selected.png)

![Next selects the second starting leg](../assets/current/batch-09/03-second-leg-inspection.png)

![Cockpit visibly ready on the selected second leg](../assets/current/batch-09/04-second-leg-ready.png)

![Direct Start begins the first leg instead](../assets/current/batch-09/05-start-second-leg.png)

The selected starting leg is not honored in this observed sequence. The synthetic
fixture's 355° no-wind course and planned heading do not distinguish the operational
mode numerically, so these captures alone do not prove which mode Start used.
See [G20](../proposed/starting-and-correcting.md#g20--start-the-leg-the-pilot-selected).

## S58 · Recommit the imported heading after a revision

On the active first leg, open the heading editor, increase 355° to 356°, and commit.
Reopening begins at the committed 356° and retains imported baseline 355°. No separate
Revert action appears. Decrease to 355° and commit: operational heading becomes 355°,
still labelled Revised. This is a new pilot-authored revision equal to the baseline,
not deletion of the revision history. No requirement for a dedicated Revert control
has been established merely by looking for one.

![Heading editor before the first revision](../assets/current/batch-09/06-heading-editor.png)

![Reopened editor retains the committed revision and imported comparison](../assets/current/batch-09/07-heading-revert-option.png)

![Recommitting baseline value remains explicitly Revised](../assets/current/batch-09/08-heading-baseline-recommitted.png)

## S59 · Leave an ETA draft open until it becomes too early

Open the ETA editor while the timer runs. Initially the planned 00:40 draft is above
the displayed minimum. In the definitive later observation, draft 01:10 is left open
until the timer reads 01:21 and Minimum now becomes 01:25. Commit and decrement are
disabled; tapping the current Commit hitpoint does not install the stale draft.
Operational ETA remains the earlier 00:40. Cancel leaves that value unchanged.

![Editor initially permits a draft above its elapsed-time floor](../assets/current/batch-09/09-eta-editor.png)

![Stale draft cannot commit after the minimum advances](../assets/current/batch-09/11-stale-draft-commit.png)

An earlier attempt used a stale hitpoint after the editor moved and dismissed the
callout. Its [capture](../assets/current/batch-09/10-behind-elapsed-rejected.png) is
retained, but does not establish rejection despite its historical filename.

## S60 · Let destination Undo expire

Report the first destination reached. The successor starts automatically, and the
reach banner offers Undo · 00:20 under the expanded checklist. Close the checklist
and wait twenty-one seconds. The banner and Undo disappear while leg 2 continues
timing. This observes expiry in the foreground; it does not establish every race at
the deadline or background expiry.

![Destination reach offers bounded Undo and starts the successor](../assets/current/batch-09/12-destination-reach-undo.png)

![Undo disappears after the wait while the successor stays active](../assets/current/batch-09/13-undo-expired.png)

## S61 · Inspect calculation choices while a leg is active

From Map Tools, open Inspect flight plan during active leg 2. Previous and Next are
disabled. Inspection still shows No wind selected; tapping Wind does not change the
selection or displayed values. The visible restriction is observed even though the
hierarchy does not mark the Wind control disabled. Whether the selection shown here
matches the engine's operational mode cannot be resolved by this equal-values fixture.
[S76](provider-and-calculation-mode.md#s76--select-no-wind-then-start-without-reloading)
now provides the separate distinct-values observation and establishes the Start mismatch.

![Map Tools leads to inspection during active navigation](../assets/current/batch-09/14-map-tools.png)

![Active inspection shows disabled leg selection](../assets/current/batch-09/15-active-inspection-mode.png)

![Tapping Wind during active navigation leaves the selection unchanged](../assets/current/batch-09/16-active-mode-tap.png)

## S62 · Move a VOR label and restore whole-leg framing

In a fresh ready two-leg Flight, drag the VOR hierarchy hitpoint: the map pans instead.
After verifying that result, drag the visible grip. The VOR label moves relative to
the route. Tap Show Destination Waypoint twice using the newly captured control;
no visible framing change follows in this bounded sequence. Show Whole Active Leg
does visibly recenter the route. Timing stays Ready 00:00 throughout.

![First drag pans the map](../assets/current/batch-10/01-vor-drag-hitpoint.png)

![Dragging the visible grip moves the VOR label relative to the route](../assets/current/batch-10/02-vor-label-drag.png)

![Destination focus attempt leaves the observed framing unchanged](../assets/current/batch-10/04-focus-destination-settled.png)

![Whole Active Leg restores central route framing](../assets/current/batch-10/05-focus-whole-leg.png)

The distinction between the semantic hitpoint and the visible grip matters for further
accessibility inspection. These captures establish neither full focus-control correctness
nor the exact auto-hide interval. [Batch10](../evidence/capture-batch-10.md) retains the
intermediate destination-focus capture and input sequence.

## S63 · Reopen a committed ETA and look for a revert action

Start, commit ETA 00:40, then inspect its target and Edit Revision. The target labels
00:40 Revised even though it equals Planned 00:40. The editor permits a new draft and
Cancel; no dedicated Revert action appears in either presentation. Tapping the console
ETA while the callout is open dismisses it. As with heading, committing a baseline-valued
revision does not clear its pilot-authored identity. No new revert feature is inferred.

![Baseline-valued ETA remains labelled Revised](../assets/current/batch-10/06-eta-committed45.png)

![The console retains the revised ETA after dismissal](../assets/current/batch-10/07-eta-revert-inspection.png)

![Edit Revision exposes draft, step controls, commit and cancel](../assets/current/batch-10/08-eta-revision-editor.png)

The original capture filename says 45, but the inspected committed value is 40. The
attempted step used an old editor position; the filename is not evidence of a 45-second commit.

## S64 · Close the reach-Undo window with a successor revision

Report the first destination reached to start leg 2, then commit successor heading
356° within the twenty-second window. At successor elapsed 00:03 the heading is Revised
and the reach Undo banner is gone. This observes invalidation by a later state-changing
action, distinct from the elapsed expiry in S60.

![A successor heading revision closes the earlier reach-Undo window](../assets/current/batch-10/09-undo-invalidated-by-heading.png)

## S65 · Undo final reach and inspect the restored leg

Reach the final destination, then select its offered Undo. The cockpit returns to
Active leg 2, retains revised heading 356°, and timing resumes with elapsed time included.
The map, however, collapses the two leg markers into nearly the same position. Tapping
the former Undo location again exposes no repeat Undo and leaves the active state intact.

![Final Undo restores active navigation but collapses route framing](../assets/current/batch-10/10-final-reach-undone.png)

![A second tap at the former Undo location does not repeat the operation](../assets/current/batch-10/11-duplicate-undo-no-action.png)

This is an observed duplicate-Undo attempt, not a proof that simultaneous duplicate
reach commands are idempotent. The next batch's additional settled capture still has
collapsed markers at elapsed 00:58, compared with 00:38 immediately after Undo.

![Collapsed framing persists in the settled follow-up](../assets/current/batch-11/01-undo-camera-settled.png)

See [G21](../proposed/starting-and-correcting.md#g21--restore-a-usable-map-after-final-reach-undo).
