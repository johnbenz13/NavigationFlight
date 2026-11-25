# Cockpit UI test setup

The helpers live in `NavigationFlightUITests/NavigationFlightUITests.swift`.
Keep UI automation in XCUITest; these helpers do not change production behavior.

Chart-panel reveal uses the measured keyboard and native accessory boundary
while typing: native AX can report clipped scroll bounds behind the keyboard.
Keep scroll gestures inside the uncovered viewport and assert the resulting
action (including actual keyboard dismissal), rather than relying only on
`isHittable` for native scroll-content buttons.

- `launchCockpit` installs a supplied plan in a new UUID-scoped disposable library.
  Pass content size and existing fixture switches through its named options and
  `fixtureEnvironment`; configure them before launch, not by relaunching into a
  partially initialized state. Additional switches should not override the library
  ID or plan. The helper waits for the ready cockpit's Start control.
- `startAmendmentFixture` explicitly disables inherited VoiceOver on the XCTest
  worker before ordinary touch setup. Worker clones can retain accessibility
  settings independently of the visible simulator; speech tests enable VoiceOver
  after bootstrap. It starts the leg and waits for Start to disappear, then
  dismisses the checklist when present. Progress fixtures can advance beyond the
  first checklist; readiness accepts the operational amendment control too.
  It explicitly closes an identified system sidebar overlay before Start: after
  rotation, that overlay can intercept a tap even when AX reports Start hittable.
  `launchPartialAmendment` uses this path for existing empty, partial, progress,
  heading and overlap fixtures, including accessibility text sizes.
- `launchPendingAmendmentForManagement` uses the existing `armed` workspace fixture.
  It starts and saves through the app's normal recording path and waits for the
  pending pencil. It injects the management failure required by its callers, but
  does not inject an unrelated confirmation-save failure. The dedicated future
  amendment tests still contain saving, failure/retry and recovery assertions,
  but are currently owner-deferred with an explicit AP-11 (#235) skip; this change
  does not reactivate them or claim active UI coverage for that flow.
- `chooseAmendmentWaypoint` opens the existing map input sheet and scrolls its lazy
  collection until the named waypoint is hittable and fully inside the viewport.
  It scopes the list by its map-center action so regular-width sidebar collections
  cannot receive the sheet scroll.
  It checks sheet dismissal after selection. Use this semantic route input for
  list/setup work; keep real chart taps in tests of direct drawing.
- Reuse `tapAmendmentControl` for the adaptive console and `tapChartPanelControl`
  for the editor's scroll viewport and pinned footer. After cancellation, assert
  the next allowed interaction's result, not just that a panel exists.
  Editor scrolling uses measured, bounded slow drags beside the wheels to avoid
  overshooting controls in the compact accessibility viewport. Fully visible,
  enabled buttons may use their measured center when native AX incorrectly reports
  them unhittable; callers must still assert the resulting action. A failed reveal
  retains the panel hierarchy and a full-screen screenshot for diagnosis.

Fixtures establish a starting state; they do not replace interaction coverage.
Use observable UI outcomes and bounded predicate/existence waits rather than
sleeps. Keep disposable library IDs for every new test launch.

For retained screenshots and result-bundle export, see [UI-EVIDENCE.md](UI-EVIDENCE.md).

## Validation (2026-11-25)

Xcode `BuildProject(buildForTesting: true)` passed. Existing UI tests were run
with `RunSomeTests` on dedicated `UIEvidence-iPad` and `AP01-iPhone-16-Pro`,
iOS 27.2. Production source, camera tolerances and existing deferred tests are
unchanged. No complete-suite or visual-design conformance claim is made.

Retained results are under:
`/var/folders/37/w2lgd8v96_348s1hxcxgwlcr0000gn/T/ActionArtifacts/686D1221-2AF5-4D4E-A0CE-3CA381D7969E/RunSomeTests/`.

- `13-35-53`: initial regular-width pending management, partial list and empty
  semantic-input tests passed (3/3).
- `13-39-06`: heading editor landscape and cancellation followed by actual next
  map interactions passed. Partial-list landscape exposed the wrong-sidebar
  scroll and was fixed by scoping the collection; `13-43-29` passed its rerun.
  Future amendment retry/recovery was explicitly skipped by its existing AP-11
  owner deferral.
- `13-45-17`: compact accessibility heading editor and pending confirmation
  passed. Partial-list accessibility failed its unchanged camera assertion.
  `13-48-59` reproduced the identical failure with the complete test file from
  unmodified main `bce95a7`: latitude 32.14736930121979 versus 32.1615532232374.
  This baseline limitation is tracked in [#244](https://github.com/johnbenz13/NavigationFlight/issues/244).
- `13-50-52`: compact empty semantic-input test passed after the list-scoping fix.
- `13-51-59`: final stable regular-width run passed partial-list portrait,
  empty semantic input and pending-management landscape (3/3). These recheck
  the portrait sheet paths after the list-scoping correction.

Each timestamp identifies `Test-NavigationFlight-2026.11.25_<timestamp>-+0200.xcresult`
and the corresponding timestamped console log. These are local retained artifacts;
the issue/PR records the findings and limits. The known camera failure is not
masked or counted as a passing test.
