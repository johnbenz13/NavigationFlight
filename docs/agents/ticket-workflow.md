# Ticket Implementation Workflow

Use this workflow whenever implementing a GitHub issue in this repository. One
ticket owns one focused branch and, when explicitly requested, one pull request.

## 1. Pass the readiness preflight

Run this preflight before planning, editing, or creating the ticket branch. It
is a fail-closed gate: missing or contradictory evidence blocks implementation.

1. Fetch current remote state with `git fetch origin --prune`.
2. Read the target issue's `blockedBy` relationships and every fallback
   `Blocked by: #<number>` reference in its body and comments. Treat the union
   as the complete blocker set.
3. For every blocker, use
   `gh issue view <number> --json state,closedByPullRequestsReferences` and
   verify all of the following:
   - the issue state is `CLOSED`;
   - at least one closing pull request is linked to the issue;
   - `gh pr view <pr> --json state,mergedAt,baseRefName,mergeCommit` reports
     `state` as `MERGED`, a non-null `mergedAt`, and `baseRefName` as `main`;
   - the PR's `mergeCommit.oid` is an ancestor of `origin/main`, verified with
     `git merge-base --is-ancestor <merge-oid> origin/main`.
4. Require a clean working tree, switch to `main`, and run
   `git pull --ff-only origin main`.
5. Verify `git rev-list --left-right --count main...origin/main` reports `0 0`.
6. Create the ticket's `feature/<kebab-case-feature-name>` branch from that
   synchronized local `main`.

If any check fails, stop before implementation and report the exact blocker,
issue, PR, or Git divergence. Resume only after the missing merge or repository
synchronization is resolved. The preflight is complete when every blocker has
traceable merged-PR evidence, both `main` refs contain every merge commit, and
the new ticket branch points at the synchronized `main` commit.

## 2. Establish the ticket boundary

1. Read the complete issue body, comments, labels, and native dependencies.
2. Confirm no open pull request already implements the ticket.
3. Read `AGENTS.md`, then locate the relevant glossary entries, architecture
   sections, technical/component documents, and source files with targeted
   searches. Start with the sections governing the ticket and expand when their
   references or correctness require it; do not repeatedly retrieve unchanged
   material.
4. Treat every acceptance criterion as part of the completion contract. Treat
   the issue's **Design evidence** as an entry point into the approved
   product-spec/Figma pair, not necessarily an exhaustive list of authoritative
   references.

The boundary is established when current behavior, required behavior, visual
states, exclusions, and closed blockers are all accounted for.

## 3. Load the Flying a Leg authority

For Flying a Leg issues #1–#16, use these authorities:

- [`docs/features/FLYING-A-LEG_SPEC.md`](../features/FLYING-A-LEG_SPEC.md)
- [`docs/technical/FLYING-A-LEG-TECHNICAL-DESIGN.md`](../technical/FLYING-A-LEG-TECHNICAL-DESIGN.md)
- [`docs/features/PROGRESSION-POLICY_SPEC.md`](../features/PROGRESSION-POLICY_SPEC.md)
- [`docs/workflows/PRODUCT-SPEC-FIGMA-WORKFLOW.md`](../workflows/PRODUCT-SPEC-FIGMA-WORKFLOW.md)
- [Approved Flying a Leg Figma file](https://www.figma.com/design/yvLXb8bUFBiZHqsag4hq6I)

First locate the ticket-relevant spec sections, invariants, technical-design
sections, and approved Figma references. Follow their cross-references and read
the complete behavior needed to implement the ticket before editing. Load
unrelated sections or supporting documents only when dependencies, architecture,
or correctness require them.

The product spec owns behavior, the technical design owns implementation
structure, and the affected approved Figma frames, components, variants, or
design rules discovered through the issue and governing product spec own layout,
hierarchy, and interaction presentation. A missing, ambiguous, or conflicting
required reference blocks implementation until the human owner reconciles the
paired baseline.

## 4. Inspect design before implementation

For every UI-affecting ticket:

1. Load `figma:figma-design-to-code` before reading design context and use
   `figma:figma-swiftui` for the SwiftUI translation.
2. Derive the affected UI states from each acceptance criterion, the governing
   product-spec sections and invariants, and every conditional UI branch touched
   by the transition. Reconcile those states with both the issue's **Design
   evidence** and the approved Figma references in the product spec.
3. In the implementation plan or working notes, record one compact trace per
   affected state: acceptance criterion, state, governing spec heading or
   invariant, authoritative approved frame, component, variant, or design rule,
   and deterministic reproduction path. Then record the visual contract:
   - the design-reference link or ID, UI state, device, orientation, and
     deterministic data needed to reproduce it;
   - component-level geometry: hierarchy, alignment, dimensions, insets,
     spacing, and spatial relationships;
   - visual treatment: text styles, semantic or exact colors, materials,
     borders, corner radii, shadows, symbols, and assets; and
   - which values are measured from Figma, supplied by a native component, or
     intentionally adaptive.
4. Compare the current simulator state with those design references before
   editing.
5. Confirm that every affected acceptance criterion and conditional branch
   appears in the trace. A Ready implementation does not satisfy the
   corresponding Active branch.
6. Implement the ticket's design now. Use the visual contract to select and
   configure native or project components; a generic component is acceptable
   only when its rendered result satisfies the contract. Do not defer the
   primary visual state to the later adaptive-conformance ticket.

Design inspection is complete when every affected state has a governing spec
reference, authoritative approved design reference, documented reproduction
path, and visual contract detailed enough to compare its rendered result. A
missing, ambiguous, or conflicting required reference blocks implementation; it
is not filled by issue evidence, a generic existing UI implementation, or
approximation.

## 5. Implement the vertical slice

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

## 6. Validate behavior and design

Follow the validation matrix in `AGENTS.md`. For SwiftUI work:

1. run focused deterministic tests;
2. refresh compiler diagnostics for changed Swift files;
3. build the application;
4. run relevant unit and UI tests;
5. verify the affected interaction in every issue-listed device/orientation;
6. reproduce each visual-contract state with deterministic fixture data, using
   existing launch arguments, fixtures, or UI automation where available;
7. capture a full-resolution simulator screenshot for each state and have the
   implementing agent inspect it directly beside the corresponding Figma
   reference;
8. compare measurable geometry against Figma values and the simulator hierarchy
   under the same device, orientation, content, and display settings. Record the
   measurements and any explicit tolerance. For visual treatment that cannot be
   measured reliably, record a bounded side-by-side judgment rather than calling
   it quantitatively verified;
9. record each state as matched, discrepant, or unverified, with the exact
   authoritative Figma frame, component, variant, or design-rule reference and
   an identifiable screenshot reference. `matched` requires direct retrieval and
   inspection of both artifacts during this validation. If either artifact is
   missing, inaccessible, ambiguous, or not inspected, record `unverified`;
   never infer a pass from the issue text, another state, the current
   implementation, or a validator's summary. Resolve discrepancies or report
   them explicitly; and
10. run `git diff --check`.

Post the acceptance-evidence comment required by `AGENTS.md`. Agents may check
objective criteria after evidence passes. Leave visual criteria unchecked until
the human owner explicitly approves the screenshots. Until then, report the work
as **implementation ready for human visual approval**, not complete. List every
unverified state and unresolved discrepancy in the handoff.

These visual gates are instruction-enforced: today no repository check proves
that the contract was derived from the approved design references, that the
implementer inspected the screenshots, or that a visual judgment is sound.
Builds, tests, and
`git diff --check` are mechanically enforceable. A future issue or pull-request
template check could require structured design-reference/screenshot evidence,
and CI could validate deterministic screenshot capture or numeric bounds; human
visual approval remains an explicit owner decision.

Do not delegate routine authority retrieval or repeat visual validation solely
to obtain a second agent summary. When the environment supports it, prefer
bounded, no-history delegation with a compact explicit handoff for independent
tasks whose parallel value exceeds duplicated context and tool output. Verify
the actual context-inheritance mechanism rather than assuming isolation, and
avoid nested delegation unless independently justified. The implementing agent
remains responsible for the state trace, direct design-reference/screenshot
comparison, and acceptance claims.

## 7. Deliver one ticket

Keep one issue per branch and pull request. Create the pull request only after
the human explicitly requests it, include `Closes #<number>`, and link the
product spec, technical design, and ticket-owned Figma nodes. Use
`mattpocock-skills:pr` when it is available.

The issue closes after its pull request merges. New requirements become a new
issue rather than silently expanding the current ticket.
