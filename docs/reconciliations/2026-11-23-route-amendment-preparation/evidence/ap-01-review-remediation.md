# AP-01 review remediation

Review: [R1/R2 at reviewed head 3a40d1b](https://github.com/johnbenz13/NavigationFlight/pull/237#issuecomment-7128050583).
The originally supplied link was the preceding background-containment fix report;
the subsequent consolidated review supplies the remediation checklist.

## Dispositions

| Finding | Disposition | Scope / change |
| --- | --- | --- |
| R1 · Larger Text editor viewport | Owner-deferred, not fixed or accepted | Review records the owner's 2026-11-24 decision to defer accessibility-specific remediation and focus on regular text sizes on iPad/iPhone Pro. No R1 placement/layout changes in this checkpoint. |
| R2 · Retained replacement review resets manual camera | Fixed and verified | Remove the nil-to-value bypass from the automatic replacement-review focus callback. All automatic replacement-review focus now respects manual camera ownership. Initial automatic focus remains available when the camera is not manually controlled. |

The change is confined to `CockpitView` and the existing UI-test target. Debug-only,
opt-in accessibility telemetry reads the actual camera received from MapLibre:
latitude, longitude, zoom, bearing, pitch and manual ownership. It neither sets nor
mocks the camera. No production accessibility value is changed.

## Verification design

`testReplacementReviewPreservesManualCameraAcrossPresentationChanges` creates a
disposable pending amendment using existing launch fixtures, opens replacement
review, pinches/rotates/pans the real map and waits for camera deceleration to settle.
It asserts that all three gestures changed the observed center/zoom/bearing and
that manual ownership is set. It then compares the camera through hiding, reopening,
opening an editor, panning beside that editor and cancelling it. Each preservation
assertion observes for at least one second to catch asynchronously scheduled fits.
Numeric tolerance: 0.000001 per component; ownership remains exactly 1.

The settled-camera regression passes with the fix and fails when only the reviewed
callback is restored: expected latitude 32.175718528248346, observed
32.18761985313274 after the presentation transition. Early test-harness iterations
that sampled before inertial deceleration settled are not counted as a defect
reproduction; the retained red result uses the settled-camera helper.

## Design and acceptance boundaries

Authority: AP-01 / issue #225 and G06's stable-camera rule, approved D03 revision.
Directly retrieved Figma design context and inspected screenshots for portrait
29:883, landscape 29:1167 and compact 29:1238 during remediation. R2 changes camera behavior, not
layout or illustrative route geometry. Captures use the existing imported fixture
and pending-replacement controls, not a same-content Figma pixel-match fixture.
No broad design conformance or human acceptance is inferred from camera equality.

## Results and retained evidence

- Final Xcode BuildProject including test targets passed (12:34); focused live
  diagnostics in CockpitView found no issues. The final screen-capture-only test
  adjustment was compiled by the passing 12:38 run.
- [Reviewed callback red result](../assets/ap-01-review/reviewed-callback-red-summary.txt):
  the settled-camera regression fails when the original callback is restored.
- [iPhone 16 Pro / iOS 27.2 / 402 × 874](../assets/ap-01-review/iphone-green-summary.txt):
  camera preservation and existing pending management both passed (2/2).
- [iPad / iOS 27.2 / portrait 834 × 1194 and landscape 1194 × 834](../assets/ap-01-review/ipad-cameras-green-summary.txt):
  camera preservation passed in both layouts (2/2).
- [Final landscape capture rerun](../assets/ap-01-review/ipad-landscape-final-summary.txt):
  passed (1/1), using the full screen rather than a stale portrait app snapshot.
- [Existing iPad boundary check](../assets/ap-01-review/ipad-boundary-and-zoom-limit-summary.txt):
  passed. The camera test in that earlier run hit the map's maximum zoom during
  setup; the final helper zooms out when already near that limit and passed above.
- `git diff --check` passed. No domain/Flight/storage code changed; the previous
  237 unit-test result was not rerun or reattributed to this checkpoint.

All five states below were directly inspected for each device. The screenshots
show chart landmarks remaining in place across presentation transitions; numeric
camera assertions establish center/zoom/bearing/pitch equality. Panning in the
editor intentionally changes the center; cancelling preserves that new center.
This is a matched result for the **G06 camera-preservation rule only**, not a new
pixel-fidelity or complete accessibility claim. The approved D03 frames above
remain the layout authority; retained replacement controls use the existing app
contract. Raw captures and tuples have provenance/hashes in the
[manifest](../assets/ap-01-review/manifest.json).

| Device / reference | Manual camera | Hidden | Reopened | Editor after pan | Editor cancelled |
| --- | --- | --- | --- | --- | --- |
| iPhone / D03 29:1238 + G06 | [Capture](../assets/ap-01-review/iphone-r2-manual-camera.png) | [Capture](../assets/ap-01-review/iphone-r2-hidden-camera.png) | [Capture](../assets/ap-01-review/iphone-r2-reopened-camera.png) | [Capture](../assets/ap-01-review/iphone-r2-editor-camera.png) | [Capture](../assets/ap-01-review/iphone-r2-editor-closed-camera.png) |
| iPad portrait / D03 29:883 + G06 | [Capture](../assets/ap-01-review/ipad-portrait-r2-manual-camera.png) | [Capture](../assets/ap-01-review/ipad-portrait-r2-hidden-camera.png) | [Capture](../assets/ap-01-review/ipad-portrait-r2-reopened-camera.png) | [Capture](../assets/ap-01-review/ipad-portrait-r2-editor-camera.png) | [Capture](../assets/ap-01-review/ipad-portrait-r2-editor-closed-camera.png) |
| iPad landscape / D03 29:1167 + G06 | [Capture](../assets/ap-01-review/ipad-landscape-r2-manual-camera.png) | [Capture](../assets/ap-01-review/ipad-landscape-r2-hidden-camera.png) | [Capture](../assets/ap-01-review/ipad-landscape-r2-reopened-camera.png) | [Capture](../assets/ap-01-review/ipad-landscape-r2-editor-camera.png) | [Capture](../assets/ap-01-review/ipad-landscape-r2-editor-closed-camera.png) |

No existing design acceptance box is changed. R2 is ready for independent re-review.

R1, human visual acceptance, Reduce Motion runtime coverage and the existing
state-during-update warning remain separate; this remediation does not approve,
merge or close the PR/issue.
