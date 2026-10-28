# NavigationFlight — Agent Instructions

## Working Principles

- Follow the user's task requirements and existing repository conventions.
- Preserve established architecture, navigation semantics, and data contracts.
- Prefer focused, maintainable changes over broad refactoring.
- Do not modify unrelated functionality.
- Work autonomously, including implementation, testing, and verification.
- Do not sacrifice correctness or test coverage to reduce token usage.

## Repository Exploration

Explore progressively rather than loading the entire repository.

1. Read these instructions and any other applicable AGENTS.md files.
2. Inspect the current Git state and relevant repository structure.
3. Identify likely implementation files using filenames and targeted searches.
4. Read only the relevant files or sections initially.
5. Expand exploration when dependencies, architecture, or correctness require it.

Prefer:
- `rg --files` for locating files.
- `rg -n` for locating symbols and references.
- Targeted file sections rather than reading entire large files.

Avoid:
- Dumping large directory trees unnecessarily.
- Reading entire files when only a small section is relevant.
- Repeatedly reading unchanged files.
- Loading unrelated test files or documentation.

These are efficiency guidelines, not restrictions.
Read complete files whenever necessary for safe implementation.

## Skills

Use available skills when relevant to the task.

For work that creates, reviews, links, or implements a product spec and its
Figma proposal, follow
[`docs/workflows/PRODUCT-SPEC-FIGMA-WORKFLOW.md`](docs/workflows/PRODUCT-SPEC-FIGMA-WORKFLOW.md).

Follow progressive disclosure:

1. Read the selected skill's SKILL.md.
2. Identify which reference documents are relevant.
3. Load only those references initially.
4. Read additional references as the task requires.

Avoid automatically loading every reference document in a skill.

Do not skip required skill instructions or mandatory verification.

## Agent skills

### Issue tracker

Track work as GitHub issues in `johnbenz13/NavigationFlight`. See
`docs/agents/issue-tracker.md`.

### Ticket implementation

When implementing a GitHub issue, follow
[`docs/agents/ticket-workflow.md`](docs/agents/ticket-workflow.md). Its pre-edit
visual-contract and rendered-comparison gates are mandatory for every
Figma-driven UI ticket.

### Triage labels

Use the default Matt Pocock engineering-skill label vocabulary. See
`docs/agents/triage-labels.md`.

### Domain docs

Use the repository's single-context domain-documentation layout. See
`docs/agents/domain.md`.

## Implementation

- Follow existing Swift and SwiftUI patterns.
- Respect existing domain boundaries and state ownership.
- Preserve the established map and cockpit interaction behavior
  unless explicitly requested otherwise.
- Avoid speculative features or unrelated improvements.
- Add or update tests for changed behavior.
- Prefer deterministic tests for domain and timing logic.

## Validation

Use progressive verification during implementation.

1. Run focused checks for the components being modified.
2. Build when changes require compiler validation.
3. Fix detected issues before proceeding.
4. Avoid repeatedly running the complete test suite without a reason.

Keep the verification loop low-overhead:

- Run the smallest relevant tests while iterating. Run each required broad suite
  after the implementation is stable, and rerun it only after a relevant change
  or failure.
- For a long-running command, use the longest supported initial yield up to 60
  seconds. If it continues in a background cell or session, let it run and use
  one 30–60 second blocking wait; wait again only when the tool reports that it
  is still running. One-second polling is not an acceptable default.
- Keep successful test and build responses to status, counts, failures, and
  paths to retained logs. Read detailed logs only when a failure or diagnosis
  requires them.

Before completing a checkpoint:

- Run `git diff --check`.

Choose validation based on the files and behavior changed:

| Change | Required validation |
| --- | --- |
| Documentation only (`.md` files or files under `docs/`) | Review the changed documentation for accuracy, verify local links and referenced paths, and run `git diff --check`. Do not build the application or run tests. |
| Swift implementation | Run the relevant tests and build the application. |
| SwiftUI behavior | Build the application, run the relevant tests, and verify affected interactions in the simulator. Validate relevant orientations when applicable. |
| Project configuration or resources | Run the relevant configuration checks and build verification. Run affected tests when applicable. |

Treat a change as documentation-only only when it does not alter source code,
project configuration, generated inputs, resources consumed at runtime, or tests.

If a validation step fails, fix the issue and repeat the necessary checks.

Do not claim verification succeeded unless it actually ran.

## Acceptance and Delivery

Before declaring an issue complete, audit every acceptance criterion and post a
GitHub comment mapping each criterion to concrete test, build, simulator, or
review evidence.

- A visual result may be reported as matched only when its evidence identifies
  the exact authoritative Figma frame, component, variant, or design rule and
  corresponding simulator screenshot. Missing, ambiguous, or uninspected
  artifacts make the result unverified.
- Agents may check objective criteria after the cited evidence passes.
- Criteria requiring product, visual, or design judgment remain unchecked until
  the human owner explicitly approves them.
- Mixed criteria require both agent-produced evidence and explicit human
  approval before they are checked.
- An unchecked criterion blocks completion unless the issue records an explicit
  deferral approved by the human owner.
- Treat implementation approval, acceptance approval, PR approval, and issue
  closure as separate decisions.
- Close an implementation issue after its PR merges, unless the human owner
  explicitly chooses another closure point.

## Git and Checkpoints

- Preserve unrelated working-tree changes.
- Keep each checkpoint focused on the requested scope.
- Create the feature branch before editing source files. If the environment
  cannot write Git metadata, report the exact failure and ask whether to continue
  in the current working tree.
- Name feature branches `feature/<kebab-case-feature-name>` using the agreed product feature name (for example, `feature/in-flight-eta-and-heading-revision`).
- Commit completed checkpoints when explicitly requested.
- Do not push changes unless explicitly requested.
- Create a pull request only when explicitly requested. Include the acceptance
  evidence and identify any criterion still awaiting human approval.

## Final Report

Keep the final report concise and include:

- What was implemented.
- Important architectural decisions.
- Files changed.
- Tests and validation results.
- Remaining limitations or known issues.
- Commit hash, if committed.
