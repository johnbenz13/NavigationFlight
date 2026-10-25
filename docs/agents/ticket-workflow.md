# Ticket Implementation Workflow

Use this workflow whenever implementing a GitHub issue in this repository. One
ticket owns one focused branch and, when explicitly requested, one pull request.

## 1. Establish the ticket boundary

1. Read the complete issue body, comments, labels, and native dependencies.
2. Confirm every blocker is closed and no open pull request already implements
   the ticket.
3. Read `AGENTS.md`, `GLOSSARY.md`, and relevant architecture records.
4. Treat every acceptance criterion and the issue's **Design evidence** section
   as the completion contract.

The boundary is established when current behavior, required behavior, visual
states, exclusions, and closed blockers are all accounted for.

## 2. Load the Flying a Leg authority

For Flying a Leg issues #1–#16, read:

- [`docs/features/FLYING-A-LEG_SPEC.md`](../features/FLYING-A-LEG_SPEC.md)
- [`docs/technical/FLYING-A-LEG-TECHNICAL-DESIGN.md`](../technical/FLYING-A-LEG-TECHNICAL-DESIGN.md)
- [`docs/features/PROGRESSION-POLICY_SPEC.md`](../features/PROGRESSION-POLICY_SPEC.md)
- [`docs/workflows/PRODUCT-SPEC-FIGMA-WORKFLOW.md`](../workflows/PRODUCT-SPEC-FIGMA-WORKFLOW.md)
- [Approved Flying a Leg Figma file](https://www.figma.com/design/yvLXb8bUFBiZHqsag4hq6I)

The product spec owns behavior, the technical design owns implementation
structure, and the exact Figma nodes linked by the issue own layout, hierarchy,
and interaction presentation. A conflict blocks implementation until the human
owner reconciles the paired baseline.

## 3. Inspect design before implementation

For every UI-affecting ticket:

1. Load `figma:figma-design-to-code` before reading design context and use
   `figma:figma-swiftui` for the SwiftUI translation.
2. Inspect every linked state, annotation, device, and orientation in **Design
   evidence**.
3. Compare the current simulator state with those nodes before editing.
4. Identify every conditional UI branch affected by the transition. A Ready
   implementation does not satisfy the corresponding Active branch.
5. Implement the ticket's design now. Do not defer its primary visual state to
   the later adaptive-conformance ticket.

Design inspection is complete when the implementation plan names the current UI
branch, the target Figma state, and the observable visual delta.

## 4. Implement the vertical slice

Carry the ticket through every layer needed for observable completion:

1. domain state and validated commands;
2. feature coordination and error propagation;
3. presentation projections;
4. SwiftUI and map rendering;
5. deterministic tests and UI automation.

Views render values and send typed intents. They do not calculate eligibility,
navigation outcomes, Reference ETA, operational heading, or undo validity.

The slice is complete when behavior and its ticket-owned visual state are both
implemented. A passing state transition with a legacy UI branch is incomplete.

## 5. Validate behavior and design

Follow the validation matrix in `AGENTS.md`. For SwiftUI work:

1. run focused deterministic tests;
2. refresh compiler diagnostics for changed Swift files;
3. build the application;
4. run relevant unit and UI tests;
5. verify the affected interaction in every issue-listed device/orientation;
6. capture simulator evidence and compare it with every linked Figma node;
7. run `git diff --check`.

Post the acceptance-evidence comment required by `AGENTS.md`. Agents may check
objective criteria after evidence passes. Leave visual criteria unchecked until
the human owner explicitly approves the screenshots.

## 6. Deliver one ticket

Keep one issue per branch and pull request. Create the pull request only after
the human explicitly requests it, include `Closes #<number>`, and link the
product spec, technical design, and ticket-owned Figma nodes. Use
`mattpocock-skills:pr` when it is available.

The issue closes after its pull request merges. New requirements become a new
issue rather than silently expanding the current ticket.
