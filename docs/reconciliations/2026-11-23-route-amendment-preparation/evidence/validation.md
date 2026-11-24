# Reconciliation checkpoint validation

2026-11-23. No application implementation, configuration or runtime resource was
changed by this reconciliation. The pre-existing Xcode project/scheme changes
remain outside its scope.

- Reviewed issues #204–#212, including complete bodies, labels and comments.
- Inspected the relevant draft, values, console, review, chart-panel, pencil,
  estimator and pending-route code against the recorded baseline.
- Inspected and retained five owner screenshots, nine fresh simulator screenshots,
  and five historical Figma previews. SHA-256 image manifest is retained.
- Disposable simulator app build/install/launch succeeded for observation through
  Xcode device tools. This is runtime inspection authorized by reconcile-product,
  not compiler validation of an implementation change. No test suite ran.
- Observed portrait drawing, explicit Finish here, review, editor/cues, pause/resume
  and landscape. See runtime-observation.md for device, actions and limits.
- Checked 73 local documentation/image links, including local heading targets:
  no missing targets.
- Confirmed all 19 image assets have PNG signatures.
- `git diff --check` and `git diff --cached --check` passed.
- New UX design, runtime acceptance of proposed behavior and implementation tests
  remain pending. Existing contract and tracker documents were not rewritten.

The source map and proposal remain separate. Current evidence does not approve
existing behavior, and the owner's behavioral direction does not approve a new
visual design. Remaining product boundaries are recorded in proposed/decisions.md.

## All-changes checkpoint · 2026-11-24

John explicitly authorized committing all current files, including the pre-existing
Xcode project and scheme changes, pushing the feature branch, and opening a PR.
The branch was renamed to `feature/route-amendment-preparation` for this delivery.
The normal Run scheme removes fixture launch environment; a separate user scheme
retains populated Flights. User scheme ordering and package scheme management are
included as requested. No application source changed.

Xcode BuildProject succeeded with zero errors on 2026-11-24 (2.044 seconds).
Retained build log: `/var/folders/37/w2lgd8v96_348s1hxcxgwlcr0000gn/T/ActionArtifacts/34473A2D-5903-405B-84F3-51B3121C66C0/BuildProject/BuildProject-Log-20261124-001909.txt`.
Scheme XML and changed scheme-management plists parse successfully. No tests ran;
these changes affect documentation, scheme setup and project serialization.

## D01 design direction · 2026-11-24

Created the first main-screen proposal in Figma and inspected the final 834 × 1194
preview after targeted badge contrast and app-name fixes. The main screen is
node 3:2 in file JCyQhDDzCPfrrbv6SBcwKw; all text uses SF Pro and the sole raster
inside the screen is the discrete chart background. Detailed node counts, reuse
and coverage limits are recorded in proposed/design-proposal.md. This is design
inspection, not simulator verification of the future UX. John approved the D01 main-screen direction on 2026-11-24; the approval
was recorded in the next design checkpoint. Subsequent repository changes are documentation/assets only; no new
build or tests were run for them.

## D02 detailed design · 2026-11-24

Recorded John’s explicit main-screen direction approval at D01 checkpoint 95f03bf.
D01 node 3:2 remains visually unchanged. Created D02 frames F00–F15, index/flow,
reusable pencil lifecycle variants and wheel columns in the same Figma file.
Exact nodes and retained previews are mapped in proposed/design-coverage.md.

Inspected all 16 views, correcting map coordinate offsets, missing-value styling,
pencil statuses, alert action labels, duration-based Assisted marks, compact map
labels, Larger Text timing clipping, and reachable compact Undo/Discard. Used
smaller inline Figma renders when high-resolution preview calls intermittently
failed. Retained previews match the inspected final design states; they have
different export scales and are not simulator screenshots.

D02 remains in review. Flying execution, simulator accessibility compliance,
keyboard avoidance, native wheel feel and implementation acceptance are unverified.
No source/configuration/runtime-resource changes; no application build or tests
were run for this documentation/design checkpoint.

Structural Figma audit: 406 editable text nodes across the detailed page; all
font families and mixed native font runs resolve to SF Pro. All 11 image-filled
nodes are named chart backgrounds. All 16 candidate nodes and the index resolve.
Repository checks: 98 local links/anchors resolve; all 37 PNG signatures and
SHA-256 entries verified; git diff --check passed.
