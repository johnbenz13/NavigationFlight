# Prepare and arm a route amendment

John approved the behavioral direction through Q1–Q31 on 2026-11-23, with an
additional request to improve the current-leg timing strip. On 2026-11-24 John
approved Q33–Q36 and explicitly removed Start now from the proposed flow (Q32).
Preparation ends at **Arm → return to Cockpit**; immediate departure will be
reconsidered only during the flying-amendment reconciliation. **D01 was direction-approved by John
on 2026-11-24. D02 detailed coverage is in review. Implementation is not authorized by this reconciliation.**

**Baseline:** local `main`, `cffba65f08cd8898294c941a4a3291b2fdb7df38`.
**Branch:** `feature/route-amendment-preparation` (renamed at John’s request on 2026-11-24).
This is a separate, bounded review of amendment preparation after flight use,
not an expansion of the earlier [whole-app review](../2026-11-14-app/README.md).
Use the existing [planning configuration](../../architecture/planning-configuration.md).

## Read the experience

1. [What the pilot sees today](current/preparing-an-amendment.md), with John's
   five screenshots and separately identified fresh runtime observations. The new observation pass
   covers nine portrait/landscape states; see its [transcript](evidence/runtime-observation.md).
2. [The agreed preparation experience](proposed/preparing-an-amendment.md):
   one workspace for plotting and entering values, followed by explicit arming.
3. [First design direction](proposed/design-proposal.md), with its editable Figma
   frame and inspected preview, approved by John.
4. [Decisions and terminology](proposed/decisions.md), including the complete
   interview record and distinctions between ready, armed and flying.
5. [Detailed state coverage](proposed/design-coverage.md), including exact Figma nodes and preview evidence.
6. [Sources, existing tickets and contract changes](evidence/source-crosswalk.md).

## Story tree

- Open and leave amendment mode
  - [S01 · Enter from the pencil](current/preparing-an-amendment.md#s01--open-amendment-mode).
  - [G01 · Toggle the workspace and understand its status](proposed/preparing-an-amendment.md#g01--open-leave-and-resume-with-the-pencil).
  - [G05 · Save, recover or discard preparation](proposed/preparing-an-amendment.md#g05--preserve-work-and-handle-progression).
- Draw a replacement route
  - [S02 · Choose a departure](current/preparing-an-amendment.md#s02--choose-a-departure).
  - [S03 · Draw, select and review](current/preparing-an-amendment.md#s03--draw-select-and-review).
  - [G02 · Plot with a growing leg list](proposed/preparing-an-amendment.md#g02--draw-and-review-in-one-workspace).
  - [G06 · Keep operational context readable](proposed/preparing-an-amendment.md#g06--read-the-map-and-current-leg-context).
- Enter heading, leg time and optional cues
  - [S04 · Edit a proposed leg](current/preparing-an-amendment.md#s04--edit-a-proposed-leg).
  - [G03 · Enter values directly on the map](proposed/preparing-an-amendment.md#g03--enter-values-on-the-selected-leg).
- Commit to a prepared amendment
  - [S05 · Review confirmation choices](current/preparing-an-amendment.md#s05--review-confirmation-choices).
  - [G04 · Arm only when ready](proposed/preparing-an-amendment.md#g04--arm-a-ready-amendment).
  - [G07 · Inspect a flown amendment](proposed/preparing-an-amendment.md#g07--inspect-without-redesigning-flight-execution).

Fresh runtime branches: [S06 · Draw and finish](current/preparing-an-amendment.md#s06--enter-drawing-and-finish-at-a-route-point),
[S07 · Edit/cues](current/preparing-an-amendment.md#s07--open-the-leg-editor-and-optional-cues),
[S08 · Pause/resume](current/preparing-an-amendment.md#s08--pause-and-resume-the-review),
[S09 · Landscape](current/preparing-an-amendment.md#s09--review-in-landscape).

## Scope and progress

The slice includes pencil entry/exit/status, plotting and correction, partial
leg values, Manual and Assisted preparation, optional cues, draft recovery,
arming/disarming, and the preparation timing strip. Flying the amendment,
departure/rejoin execution, Flight Undo and Debrief remain outside this review.
Their existing behavior is retained; this document does not approve it anew.

The owner-approved preparation direction is recorded for the design pass, subject
to the [remaining boundary decisions](proposed/decisions.md#boundaries-to-resolve-before-ticket-contracts)
and evidence limits. Existing
Figma nodes are historical references, not the target for this iteration.

**Reconciliation Figma file:** [Amendment preparation](https://www.figma.com/design/JCyQhDDzCPfrrbv6SBcwKw),
created in Navigation Flight project `676737789` on 2026-11-24.
Review [D01 main-screen proposal and preview](proposed/design-proposal.md) or open
[the exact Figma frame](https://www.figma.com/design/JCyQhDDzCPfrrbv6SBcwKw?node-id=3-2).
It shows iPad Pro 11-inch portrait, plotted legs with missing values, plotting off,
and the lighter timing strip. **John approved D01 on 2026-11-24.** Expand its direction across the
remaining states, iPad landscape and iPhone portrait in D02; detailed design
approval remains separate.
iPhone landscape remains excluded.

## Review gates and limits

- Behavioral direction: approved by John in this conversation, Q1–Q31; timing
  treatment added with the final answer. Exact visual treatments await design.
- Current-map accuracy: the attached images are inspected owner evidence;
  complete interactive/device coverage is not implied.
- Detailed design approval, paired contract approval, ticket breakdown/publication
  and implementation authorization: pending separate stages.
- Existing specs, glossary, delivery plan and GitHub issues remain unchanged.
  Proposed supersessions are mapped in the supporting crosswalk.
- John authorized commits, pushing this feature branch and PR #223 in the conversation.
  Ticket publication, merge and issue closure remain separate decisions.
