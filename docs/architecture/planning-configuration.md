# Product planning and reconciliation configuration

Setup agreed with John on 2026-11-14. Existing repository policies remain authoritative.

## Product and review scope

NavigationFlight is a native iPhone/iPad app. Use the device and orientation baseline in
[the product/Figma workflow](../workflows/PRODUCT-SPEC-FIGMA-WORKFLOW.md#1-establish-the-behavioral-baseline):
iPad Pro 11-inch portrait first, iPad landscape and iPhone 16 Pro portrait next.
iPhone landscape is excluded. Other supported iPhone sizes, Dynamic Type, VoiceOver,
Reduce Motion, and window resizing are coverage branches; record what is actually
observed. This review introduces no new localization or device-support policy.

## Authority and destinations

- Product behavior: feature specifications under [features](../features/), interpreted
  with explicit supersession statements and owner decisions. Approved future behavior
  is distinct from observed delivery.
- Presentation: exact approved Figma nodes linked by those specifications. Native
  system-owned geometry is governed by the written platform rule, not pixel equality.
- Architecture: [architecture.md](../architecture.md), feature documents under
  `docs/technical/`, and [domain conventions](../agents/domain.md).
- Terminology: [GLOSSARY.md](../../GLOSSARY.md). Preserve historical approvals and
  validation evidence when proposing updates.
- Reconciliations: `docs/reconciliations/<date>-<scope>/README.md`, with `current/`,
  `proposed/`, `assets/current/`, `assets/figma/`, and `evidence/`. Reuse one folder per
  effort. Markdown with embedded local images is the review format; no documentation
  renderer was identified during initial setup.
- Figma project for new design files: [Navigation Flight, 676737789](https://www.figma.com/files/folder/676737789).
  Existing feature files remain source references. Create one new file per reconciliation
  only after design work is agreed; record its URL in that effort's index. Library and
  component references remain those documented in each feature specification.
- Ticket destination: GitHub `johnbenz13/NavigationFlight`; follow
  [tracker policy](../agents/issue-tracker.md) and [label mappings](../agents/triage-labels.md).
  Reconciliation observations are local until ticket publication is requested.
- No separate numbered feature-plan root or archive destination is established here.
  Resolve those only when the relevant work is requested.

## Git and permissions

Start reconciliation from the agreed local `main` revision on a dedicated
`reconcile/<date>-<scope>` branch. The index records the immutable baseline and branch.
Resume that branch across chapters. Commit and push permissions remain explicit.

For the 2026-11-14 app effort, John approved the setup and requested the cockpit
checkpoint be committed and merged first. That checkpoint authorization does not
authorize committing reconciliation documents. The current invocation authorizes
local runtime inspection, required build/install, disposable fixtures, screenshots,
and reading existing Figma designs. Application changes, design writes, contract
rewrites, remediation tickets, and archive changes require their own authorization.

## Skills and evidence setup

Resolve installed skills through the current catalog: `reconcile-product`,
`plan-new-feature`'s shared configuration reference, `grilling`, `domain-modeling`,
`codebase-design`, `device-interaction`, `writing-for-agents`, and `plan-feature-tickets`.
Use relevant SwiftUI/platform guidance when its stage requires it. Read Figma skill
prerequisites before design-context or authoring operations. Read-only screenshots
and metadata use a Figma file session.

Use the `NavigationFlight` Xcode scheme and the existing disposable debug fixture
launch hooks documented by [UI test helpers](../../NavigationFlightUITests/NavigationFlightUITests.swift)
and [RootView](../../NavigationFlight/App/RootView.swift). Retain fixture identity,
device/OS, viewport, date, revision, action transcripts, and screenshot hashes in each
effort's evidence folder. Simulator screenshots establish visible states; persistence,
timing, and recovery require separately observed transitions. Test runs from earlier
implementation checkpoints are historical evidence, not new reconciliation observations.
