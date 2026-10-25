# Issue tracker: GitHub

Issues and specs for this repository live as GitHub issues in
`johnbenz13/NavigationFlight`. Use the `gh` CLI for all operations.

## Conventions

- Create issues with `gh issue create --title "..." --body "..."`.
- Read an issue and its discussion with
  `gh issue view <number> --json number,title,body,labels,comments`.
- List issues with `gh issue list`, applying appropriate state and label filters.
- Make implementation tickets sub-issues of their source issue when one exists.
  Use `gh issue create --parent <parent> ...` or attach the child afterwards.
- Apply and remove labels with `gh issue edit`.
- Comment with `gh issue comment` and close with `gh issue close`.

Infer the repository from `git remote -v`; `gh` resolves it automatically when
run inside this clone.

## Pull requests as a triage surface

**PRs as a request surface: no.** External pull requests do not enter the issue
triage queue unless this setting is changed explicitly.

## Publishing and fetching

- When a skill says to publish to the issue tracker, create a GitHub issue.
- When a skill says to fetch a ticket, read the complete issue body, labels, and
  comments.
- Publish approved ticket sets in dependency order so blocker references can use
  real issue numbers.

## Blocking relationships

Use GitHub's native issue dependencies when available. The blocked issue is the
child and each prerequisite issue is a blocker. If native dependencies are not
available, add `Blocked by: #<number>` references to the issue body.

A ticket is ready for implementation only when all its blockers are closed.
Claim ready work by assigning the issue to the implementing developer or agent.

## Wayfinding operations

When `/wayfinder` is used, its map is one issue labelled `wayfinder:map` and its
tickets are sub-issues. Type labels use `wayfinder:<type>` where the type is
`research`, `prototype`, `grilling`, or `task`. Prefer native dependencies for
blocking edges and fall back to textual `Blocked by` references when necessary.
