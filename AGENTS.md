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

Follow progressive disclosure:

1. Read the selected skill's SKILL.md.
2. Identify which reference documents are relevant.
3. Load only those references initially.
4. Read additional references as the task requires.

Avoid automatically loading every reference document in a skill.

Do not skip required skill instructions or mandatory verification.

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

Before completing a checkpoint:

- Build the application.
- Run the full relevant test suite.
- Run `git diff --check`.
- Verify affected user interactions in the simulator when UI,
  gestures, navigation, map rendering, or layout behavior changes.
- Validate relevant orientations when applicable.

If a validation step fails, fix the issue and repeat the necessary checks.

Do not claim verification succeeded unless it actually ran.

## Git and Checkpoints

- Preserve unrelated working-tree changes.
- Keep each checkpoint focused on the requested scope.
- Commit completed checkpoints when explicitly requested.
- Do not push changes unless explicitly requested.

## Final Report

Keep the final report concise and include:

- What was implemented.
- Important architectural decisions.
- Files changed.
- Tests and validation results.
- Remaining limitations or known issues.
- Commit hash, if committed.
