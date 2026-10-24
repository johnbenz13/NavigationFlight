# Product Spec + Figma Workflow

Use this workflow for a user-facing feature that needs both a repository product
specification and a Figma proposal. It defines how humans and coding agents move
from product behavior to an approved design and then to implementation without
allowing either artifact to silently override the other.

The Flying a Leg specification is the pilot for this workflow:
[`FLYING-A-LEG_SPEC.md`](../features/FLYING-A-LEG_SPEC.md).

## Contract Between Artifacts

The repository product spec and Figma have split authority:

| Concern | Authority |
| --- | --- |
| User goals, scope, non-goals, terminology, behavioral invariants, states, transitions, and edge cases | Repository product spec |
| Approved layout, visual hierarchy, component treatment, spatial relationships, and interaction presentation | Approved Figma nodes |
| Platform behavior, accessibility, and feasibility constraints discovered during design or implementation | Reconciled in both artifacts before approval or implementation continues |

A conflict is a blocked decision, not an instruction to choose one artifact. The
feature owner must resolve the conflict, the owning artifact must be updated, and
the affected counterpart must be reviewed again.

Neither artifact should duplicate the other in full. The product spec links to
the precise Figma nodes that clarify it. Figma links back to a portable repository
URL for the product spec. A machine-local path is useful during authoring but is
not an acceptable shared Figma link.

## Required Artifacts

Each designed feature has:

1. One product spec under `docs/features/` describing observable product behavior.
2. One stable Figma file for the feature's proposal and iterations.
3. A `## Figma` section in the product spec containing:
   - the stable Figma file URL;
   - deep links to the currently approved flow, state set, and shared components;
   - design status: `not started`, `in review`, `approved`, or `changes requested`;
   - the approved iteration name or identifier; and
   - the date and identity of the human approver.
4. A Figma cover or index page containing:
   - a link to the product spec at a shareable repository URL;
   - the product-spec revision or commit reviewed for the iteration;
   - the current design status; and
   - links to the approved nodes.

Use a repository permalink to a commit when recording an approval. A branch link
may be used while work is in review, but it must be replaced or supplemented by a
permalink at approval.

## Workflow

### 1. Establish the Behavioral Baseline

Read the product spec, linked domain terminology, overlapping feature specs, the
current application flow, and any existing UI reference. Separate current
behavior, proposed behavior, and non-goals. Record ambiguities as questions; do
not resolve product decisions through visual invention.

Complete this step when every design-relevant behavior can be traced to a product
spec section or is listed as an open question.

### 2. Build Design Coverage

Before drawing screens, derive a design coverage checklist from the spec. At
minimum cover:

- entry, happy path, completion, and exit;
- every user-visible state and transition;
- drafts, committed values, history, undo, cancellation, errors, and empty states;
- concurrent or time-sensitive states;
- accessibility, Dynamic Type, orientation, and relevant device-size behavior;
- safety-sensitive distinctions and actions requiring explicit user intent; and
- interactions with adjacent features named by the spec.

For Flying a Leg, coverage must preserve the pilot as navigation authority and
must make planned, revised, reference, and actual values distinguishable. It must
also cover target progression, passed-without-report targets, ETA and heading
editing, cross-check disclosure, drift-line visibility, bounded undo, completed
history, and automatic versus manual leg handoff.

Complete this step when each checklist item cites the governing spec section and
has a planned Figma flow or state. Open product questions remain visibly blocked.

### 3. Create an Iteration in the Stable Figma File

Create each proposal as a named iteration inside the feature's stable Figma file,
not as an unrelated file. Preserve previously reviewed iterations. An iteration
contains:

- a short intent and list of questions being tested;
- the spec revision used as input;
- an end-to-end flow;
- a state matrix for important components and screens;
- annotations that cite the relevant product-spec headings or invariant numbers;
- reusable components and variables where repetition justifies them; and
- a change summary from the previous iteration.

Start with structure and interaction flow, then refine visual treatment. Existing
UI snapshots are contextual input unless explicitly approved as a pixel contract.

Complete this step when the design coverage checklist is represented in the
iteration and the stable file plus candidate-node links are ready for review.

### 4. Review the Iteration

Review product correctness and design quality together. Compare the proposal to
the spec and current app; do not review only screenshots. Check:

- every required state is present and traceable;
- visual emphasis matches operational importance;
- irreversible, timing, and safety-sensitive actions are explicit;
- labels use canonical domain terminology;
- the proposal does not introduce behavior absent from the spec;
- platform conventions and accessibility remain viable in SwiftUI; and
- node links resolve to the exact content under review.

Classify every finding as one of:

| Finding | Required action |
| --- | --- |
| Design correction | Revise Figma and retain the product behavior. |
| Product decision | Update and re-review the product spec before Figma approval. |
| Cross-artifact conflict | Pause approval, decide with the feature owner, then update and re-review both artifacts. |
| Implementation constraint | Confirm the constraint, decide its product impact, and update both artifacts when user-visible behavior changes. |

Complete this step when findings are resolved or explicitly assigned to the next
iteration, with no unresolved conflict hidden in comments.

### 5. Approve the Paired Baseline

Approval is an explicit human action. Checklist completion by an agent does not
approve an iteration. The approver confirms the product-spec revision and the
selected Figma nodes as one paired baseline.

Record the approval in the product spec's `## Figma` section and on the Figma
cover or index page. Include the iteration identifier, spec permalink, approver,
and date. Set the design status to `approved`.

Complete this step only when both artifacts point to each other, all approved node
links resolve, and the human approval metadata matches on both sides.

### 6. Hand Off to Implementation

Implementation begins from the approved pair. The implementer must read the full
product behavior and inspect the approved nodes, including annotations and state
variants. Figma-generated code is structural reference only; implement the design
with project conventions, native SwiftUI patterns, semantic system styling, and
the repository's accessibility and validation requirements.

Maintain a trace from implemented states and tests to product invariants. Validate
the result against both authorities: behavioral tests against the product spec and
simulator interaction/visual review against the approved Figma nodes.

Complete this step when the implementation and relevant tests satisfy the product
spec, the affected interactions have been compared with approved Figma in the
simulator, and deviations are resolved or approved and documented.

### 7. Iterate After Approval

Any change to approved behavior or design starts a new named iteration. Update the
owning artifact first, mark the paired baseline `changes requested`, and review the
impact on the counterpart. Small corrections may reuse the stable file and spec;
they still require a change summary and renewed human approval when they alter the
approved contract.

Keep the product spec current with shipped behavior. Preserve Figma history using
named iterations, version history, or archived pages while keeping the product
spec linked only to the current approved nodes.

## Agent Operating Rules

When an agent is asked to use this workflow:

1. Confirm the requested phase and whether it authorizes product-spec edits,
   Figma edits, implementation, or review only.
2. Read the product spec and only the linked supporting documents needed for the
   phase.
3. Ask focused questions for decisions that change scope, authority, approval, or
   user-visible behavior.
4. Load the relevant skills before acting; follow their current instructions.
5. Report uncovered spec gaps and cross-artifact conflicts instead of inventing a
   resolution.
6. Treat approval as human-owned and stop at the approval gate when it has not
   been granted.
7. Verify every link and changed artifact before completing the phase.

## Skill Routing

Use the smallest relevant set of skills available in the current environment:

| Work | Skill |
| --- | --- |
| Draft or revise observable product behavior | `write-product-spec` |
| Read, create, edit, review, or comment on a native Figma spec | `figma-spec` |
| Operate on a Figma file through the Figma API | `figma-use` |
| Turn an application flow or multi-section view into Figma | `figma-generate-design` with `figma-use` |
| Build or update reusable Figma variables and components | `figma-generate-library` with `figma-use` |
| Translate between Figma and this SwiftUI project | `figma-swiftui` plus its direction-specific prerequisite |
| Inspect Figma for implementation | `figma-design-to-code` before design-context tools |
| Verify implemented interactions | `device-interaction` |
| Create or modify reusable agent guidance | `writing-for-agents` |

Skill availability and instructions may change. Resolve current skill names and
read their complete instructions at the start of the relevant phase.

## Review Prompts

Use these prompts to keep iterations bounded:

- Which product invariants does this iteration test?
- Which user-visible states remain uncovered?
- What changed since the previous iteration, and why?
- Does any Figma interaction imply behavior the product spec does not define?
- Does any product invariant lack an understandable visual or interaction state?
- Are the exact spec revision and Figma nodes ready for human approval together?
