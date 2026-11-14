# Capture batch 01 — Flight Plans to Cockpit

Date: 2026-11-14, Asia/Jerusalem; screenshots approximately 13:39–13:43 local time.
Baseline: `1a2d7e7596667a39616fe3812f6a07326f30ca00` on `reconcile/2026-11-14-app`.
The source tree was unchanged. Xcode workspace build/install succeeded for runtime
inspection. No test suites were run. All interaction sessions were closed afterward.

## Reproduction and retained evidence

- [Capture manifest](batch-01/captures.json): actions, per-run environments, original
  capture paths/timestamps, rebased screenshot/hierarchy/log paths, and SHA-256 hashes.
- [Exact fixture](batch-01/representative-v7.fplnav), copied without modification from
  `NavigationFlightTests/Fixtures/FPLNav/V7/Official/representative-v7.fplnav`.
  SHA-256: `3d301bef0e685555afc6de8c34827955cf366edf67abef22dd86ab18973b3e4d`;
  size: 10,852 bytes. [Fixture provenance in repository](../../../../NavigationFlightTests/Fixtures/FPLNav/V7/Official/PROVENANCE-OFFICIAL-V7.md).
- Launch with the existing debug hooks in the manifest. `NAVIGATION_FLIGHT_UI_TEST_LIBRARY_ID`
  isolates each disposable library. Fixture-bearing environment entries in the manifest
  mean base64 of the retained file, not the literal JSON reference object. Use a new
  unique library ID to reproduce a fresh run rather than reusing this batch's data.
- Captures 01–02 use an empty library. Captures 03–08 use a separately seeded library.
  Capture 09 uses another seeded phone library. Captures 10–11 use a new iPad library
  with both saved and loaded plan seeded, then exercise Continue → Flight Plans → Continue.
- [Figma preview checksums](batch-01/figma-assets.json) and [authority record](authority.md)
  retain exact node identities and approval limitations. All 11 app screenshots and
  six design previews were visually inspected.

| Device | OS | Viewport in points | Capture pixels | Coverage limit |
| --- | --- | --- | --- | --- |
| iPad Pro 11-inch (M5) | iOS 27.0 (24A434) | 834 × 1210 portrait; 1210 × 834 landscape | 2× viewport | No split-screen/resizing, accessibility sizes, VoiceOver or Reduce Motion runs. |
| iPhone 17 | iOS 27.0 (24A434) | 402 × 874 portrait | 3× viewport | Supported secondary-generation coverage; canonical iPhone 16 Pro not captured. |

The synthetic route is near (0, 0), outside bundled chart coverage. These captures
verify shell, controls, and transitions, not geographic chart rendering. Location
permission/simulator GPS state influenced visible Prepared/Sensing and Position Check
messages; no controlled Position Check or recording scenario was run.

## Story and requirement crosswalk

| Story / gap | Contract or design reference | Capture | What the evidence establishes |
| --- | --- | --- | --- |
| [S01](../current/flight-plans-to-cockpit.md#s01--open-an-empty-flight-plans-library) | Library §13; recording §72 | 01 | Empty explanation, Add actions, four sections. |
| [S02 / E01](../current/flight-plans-to-cockpit.md#s02--open-the-file-picker) | Library §§15, 17 | 02 | Picker opens. No proof of completed cancellation/import. |
| [S03](../current/flight-plans-to-cockpit.md#s03--choose-a-saved-flight-plan) | Library §14; Figma 28:187 | 03 | One row's hierarchy; no sort/duplicate/loaded-badge proof. |
| [S04](../current/flight-plans-to-cockpit.md#s04--review-a-plan-before-loading) | Library §22; state card 28:513 | 04 | Unloaded review offers Load; no removal execution. |
| [S05](../current/flight-plans-to-cockpit.md#s05--load-a-ready-flight) | Library §23; Flying a Leg lifecycle | 05 | Explicit load reaches ready/unstarted Cockpit. |
| [S06](../current/flight-plans-to-cockpit.md#s06--use-the-ready-cockpit-in-landscape-or-on-a-phone) | Library §§8–10 | 06, 09 | Ready-state rotation and compact presentation, not active timing or all device variants. |
| [S07 / G02](../current/flight-plans-to-cockpit.md#s07--inspect-planning-details-from-map-tools) | Library §22; Flying a Leg cross-feature review authority | 07 | Separate detailed Plan Inspection remains reachable from Map Tools. |
| [S08 / G01](../current/flight-plans-to-cockpit.md#s08--return-from-plan-inspection) | Library §10; cockpit hierarchy 190:96 | 06 → 07 → 08 | Return-specific overlap. Initial strip at y117, returned strip y53. |
| [S09 / G02](../current/flight-plans-to-cockpit.md#s09--return-through-the-flight-plans-review) | Library §§4, 27, 29; Figma 41:76 | 10 → 11 | Retained loaded review, Continue/Restart hierarchy, unobscured ready-state return. Internal Flight identity and active progress not instrumented. |
| [G03](../proposed/flight-plans-to-cockpit.md#g03--read-complete-operational-labels-and-frequencies) | Flying a Leg §102; cockpit hierarchy 190:96 | 05, 06, 09, 11 | Portrait next-frequency and landscape title truncation. Exact long-content target design unresolved. |
| [G04](../proposed/flight-plans-to-cockpit.md#g04--understand-which-navigation-contract-is-current) | Recording Scope and §72; historical library references | 01, 03, 10 + authority appendix | Four-section extension has explicit written authority; older references need clear supersession navigation. |

## Unverified branches and next evidence

- Picker cancellation: retry with observed hierarchy, then capture settled library and
  compare contents; do not count the interrupted attempt as a pass or app defect.
- Real import: choose a disposable copied file through Files; observe success, saved
  row, no automatic Flight creation, and offline persistence after process relaunch.
- Revisions, invalid inputs, storage failures and removal: capture each meaningful
  confirmation/cancellation/error branch with unchanged loaded-state evidence.
- Active-flight protection/continuity: use a running timer and pilot edits/checklist
  work; record before/after. Ready screenshots cannot prove this invariant.
- Geographic map, recording/recovery, Position Check, Settings, accessibility and
  remaining navigation actions: separate chapters after representative-map review.
- Design coverage: exact long-content and integrated detailed-review states remain
  unverified. No final visual acceptance is inferred from matching labels or hierarchy.

The source/test references and historical tracker evidence in [authority.md](authority.md)
are supporting context. None replaces runtime evidence for an unobserved branch.
