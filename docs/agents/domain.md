# Domain Docs

This repository uses a single-context domain-documentation layout.

## Before exploring

- Read `GLOSSARY.md` at the repository root.
- Read ADRs under `docs/adr/` that affect the area being changed.

If either location does not exist, proceed without flagging its absence. Create
or revise domain documentation only when terminology or architectural decisions
are actually resolved.

## Use the glossary's vocabulary

Use terms as defined in `GLOSSARY.md` when naming issue titles, acceptance
criteria, tests, refactor proposals, and implementation concepts. Avoid synonyms
that the glossary explicitly rejects.

If a required concept is missing, reconsider whether the project already has a
different term. If it is a genuine gap, record it for domain-modeling work.

## Flag ADR conflicts

Surface any conflict with an existing ADR explicitly instead of silently
overriding the recorded decision.
