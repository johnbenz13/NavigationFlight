# UI screenshot evidence

`captureEvidence` in `NavigationFlightUITests.swift` captures `XCUIScreen.main`,
normalizes rotation metadata at the original image scale, checks screenshot pixel dimensions against the current device orientation, and
keeps the attachment in the result bundle. Use it after UI assertions/rotation;
app screenshots can retain portrait bounds after a landscape rotation. The
existing `testAdaptiveCockpitKeepsOperationalActionsAvailableAcrossOrientations`
keeps `Evidence portrait` and `Evidence landscape` attachments.

Retain the **original** `.xcresult` from the test run (normally in
`DerivedData/Logs/Test`, or an explicit `xcodebuild -resultBundlePath`). Record the
checkout and test command when running tests. Export without running tests again:

```sh
python3 scripts/export-ui-evidence.py \
  --result /absolute/path/original.xcresult \
  --test-id 'NavigationFlightUITests/testAdaptiveCockpitKeepsOperationalActionsAvailableAcrossOrientations()' \
  --select 'Evidence portrait=portrait' \
  --select 'Evidence landscape=landscape' \
  --source /absolute/path/test-checkout \
  --output /absolute/path/new-evidence-directory
```

Requires Xcode's `xcresulttool export attachments` and Python 3; no packages.
`--result` also accepts a directory containing exactly one bundle with
`Info.plist`; ambiguous directories fail. Incomplete ActionArtifacts copies are
rejected. Select exact attachment names (the generated Xcode repetition/UUID PNG suffix is also accepted automatically); duplicates (including repeated runs)
fail clearly. Each selected PNG is checked for its expected pixel orientation.
The destination must be new. Export uses temporary staging, so a failed export
can be retried with the same destination after fixing permissions/selection.
Repeat with another destination to recover evidence from the same result.

The output includes selected screenshots, the original export manifest, and
`provenance.json`: original result path/Info.plist hash, test summary,
attachment/test/device metadata, screenshot dimensions/hashes, and source HEAD
and working-tree status. `source.patch` preserves tracked changes at export.
Source state is recorded **at export time**, not inferred as the test-time
revision: use the unchanged test checkout and retain the invocation alongside
the export. Untracked file contents are not archived. Keep the original result
for future export; provenance does not make an incomplete copy recoverable.

Tool regression checks: `python3 scripts/test-ui-evidence.py`.

## Verification (2026-11-25)

The existing orientation test passed (1 test, 0 failures) on dedicated
`UIEvidence-iPad`, iPad Pro 11-inch (M5), iOS 27.2, device
`0F915431-D1D4-4A72-A07C-19BF5914ABD6`. The test command built the app and UI test
bundle in `/private/tmp/UIEvidence-DerivedData`, with parallel testing disabled.
Original result: `/private/tmp/UIEvidence-normalized.xcresult`; build/test log:
`/private/tmp/UIEvidence-normalized.log`. Checkout:
`/private/tmp/NavigationFlight-evidence`, base `27c8850`, plus uncommitted
helper changes preserved in the export's source patch; new tooling files are
listed as untracked in its status.

The command above exported both screenshots twice into
`/private/tmp/UIEvidence-export-1` and `/private/tmp/UIEvidence-export-2` from
that same result, without another test run. Actual exported PNG pixels:
portrait **1668 × 2420**, landscape **2420 × 1668**. Both images were inspected
and contain the entire screen, including system status/navigation chrome.
These are capture checks, not product/design acceptance.

An initial export hit the real xcresulttool TestReport cache permission error;
repeating the export with appropriate filesystem access recovered the original
result without a test rerun. A nonexistent bundle produced the documented
original-bundle/path recovery error. Two Python regression tests passed,
covering incomplete copies, wrong orientation, repeat/recovered exports,
provenance, and overwrite protection. `git diff --check` passed.

During verification, raw screenshot PNG/CGImage storage retained portrait pixels
with orientation metadata even though UIImage.size was landscape. Rendering the
full captured screen at its existing scale normalizes that metadata before
attaching; the exported file dimensions above verify the final payload.
