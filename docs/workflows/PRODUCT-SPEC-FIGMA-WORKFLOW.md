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
   - design status: `not started`, `direction review`, `direction approved`,
     `in review`, `approved`, or `changes requested`;
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

### 2. Select the Main-Screen Slice

Choose one representative main screen before designing the complete feature. It
should show the feature in its most important normal-use state and expose the
decisions most likely to invalidate the overall direction: information hierarchy,
primary actions, navigation model, terminology, density, and platform treatment.

Read enough of the complete spec to avoid contradicting later requirements, but
keep this slice narrow. List the deferred flows and states without designing them.
For a feature with multiple plausible main screens, ask the developer which one to
use before drawing.

Complete this step when the developer and agent can name the single main screen,
the product behaviors visible on it, the design questions it will answer, and the
use cases intentionally deferred until after direction approval.

### 3. Design and Review the Main Screen

Create the main screen as the first named iteration in the stable Figma file.
Start with structure and interaction hierarchy, using only enough visual detail to
make the direction understandable. Existing UI snapshots are contextual input
unless explicitly approved as a pixel contract.

Set the design status to `direction review`, then show the resulting Figma node or
a faithful preview to the developer. Ask for feedback on the basic decisions
before expanding the design. Iterate on this main screen in small, bounded passes
until the developer either rejects the direction, requests another pass, or
explicitly approves it. Record the decisions and the reason for material changes
with the iteration.

This is the **main-screen direction gate**. The agent must stop and wait for
explicit human approval. Approval must be unambiguous, such as “main-screen
direction approved”; silence, checklist completion, or a Figma write succeeding
does not count. Set the design status to `direction approved` when granted.

Complete this step only when the developer has seen the main screen, the recorded
basic decisions reflect the feedback, and the developer has explicitly approved
the direction. Full use-case design begins only after this criterion is met.

### 4. Build Design Coverage

After main-screen direction approval, derive a design coverage checklist from the
entire spec. At minimum cover:

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

### 5. Expand the Approved Direction

Create subsequent named iterations inside the same stable Figma file and preserve
previously reviewed iterations. Extend the approved main-screen direction across
the design coverage checklist. Each iteration contains:

- a short intent and list of questions being tested;
- the spec revision used as input;
- the approved main-screen direction it extends;
- an end-to-end flow;
- a state matrix for important components and screens;
- annotations that cite the relevant product-spec headings or invariant numbers;
- reusable components and variables where repetition justifies them; and
- a change summary from the previous iteration.

If a later use case exposes a problem with an approved basic decision, return to
the main-screen direction gate and obtain renewed human approval before propagating
the new direction.

Complete this step when the design coverage checklist is represented in the
iteration and the stable file plus candidate-node links are ready for review.

### 6. Review the Complete Iteration

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

### 7. Approve the Paired Baseline

Approval is an explicit human action. Checklist completion by an agent does not
approve an iteration. The approver confirms the product-spec revision and the
selected Figma nodes as one paired baseline.

Record the approval in the product spec's `## Figma` section and on the Figma
cover or index page. Include the iteration identifier, spec permalink, approver,
and date. Set the design status to `approved`.

Complete this step only when both artifacts point to each other, all approved node
links resolve, and the human approval metadata matches on both sides.

### 8. Hand Off to Implementation

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

### 9. Iterate After Approval

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
6. Present the main screen and stop at the main-screen direction gate before
   designing the full state and use-case set.
7. Treat both direction and paired-baseline approval as human-owned and stop at
   either approval gate when it has not been granted.
8. Verify every link and changed artifact before completing the phase.

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
- Has the developer seen and explicitly approved the main-screen direction?
- Which basic decisions were made before expanding into all use cases?
- Which user-visible states remain uncovered?
- What changed since the previous iteration, and why?
- Does any Figma interaction imply behavior the product spec does not define?
- Does any product invariant lack an understandable visual or interaction state?
- Are the exact spec revision and Figma nodes ready for human approval together?
