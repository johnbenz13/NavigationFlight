# Issue #161 implementation evidence

Branch: `feature/start-checklist-settings`. Baseline: PR #193 merge
`0723ec76b7018a956b6b6ccb771666528bd84447`; synchronized main, clean tree.

John approved implementation and the existing Cockpit warning geometry with:
“Checklist changes could not be saved. Navigation remains available. After
restarting, the checklist may return to its last saved state.” Track failures
retain their existing accurate warning. Approval is recorded in
[#161](https://github.com/johnbenz13/NavigationFlight/issues/161#issuecomment-7052413098).

## Pre-edit visual contract

Figma Settings file: `HludOIJu7Ko46X4pmkGvTx`; approved product revision `9d2628a`.
Design context and screenshots retrieved and directly inspected before editing.
Native navigation/TabView shell geometry follows the approved platform rule in
`7:1029`; content rows, hierarchy, typography and spacing follow the frames.
Only the checklist row ships in this slice; no empty future groups.

| Acceptance / state | Authority | Reproduction and contract |
| --- | --- | --- |
| Settings, no Flight / loaded Flight, saved values | SET-01–08,12,15; `3:628` | Isolated empty/loaded library; Settings. Grouped primary background, secondary grouped row, large-title heading, body secondary device explanation, footnote COCKPIT header. iPad portrait 72pt content inset, 82pt minimum row, trailing saved value; native chevron. |
| Hebrew / English / none selected; Back | SET-08,12; `7:42`, `7:127`, `7:204` | Open selector with each saved choice. Three exclusive rows, 76pt minimum, 16pt inner inset, 14pt grouped corners; body title, checkmark, footnote explanation; 24pt content inset. Select saves and returns; Back leaves saved value. |
| Failed save, Retry, Dismiss | SET-13; `7:845` | Fail one Hebrew→none save. Error above Cockpit group, retained/attempted values, 76pt Retry/Dismiss rows with body title and secondary subheadline, footnote explanation. No alert replacement. |
| Landscape / phone / compact / Larger Text / dark | SET-15; `7:435`, `8:381`, `7:657`, `7:1007`, `7:734` | Rotate iPad; iPhone portrait; system text/appearance. 72pt landscape and 20pt phone main inset; compact main value in secondary line; 76pt minimum rows grow for wrapping. Larger Text stacks value/timing and scrolls. Semantic colors and text styles, no fixed multiplier. |
| Both active templates, collapsed/noted, phase hiding, undo | SET-08,14; existing `yvLXb8bUFBiZHqsag4hq6I` / `198:250` | Isolated loaded plan; explicit/automatic start; close/reopen/note; arrival/undo. Reuse existing checklist renderer and controls, preserve dynamic leg values. |
| No checklist, including undo/recovery | SET-08,14,16; omission rule `7:1029` | Start with none, arrive/undo/relaunch. Omit only checklist UI/chip, keep all other disclosures/timers. |
| Presentation persistence warning | Owner approval above; existing recording warning geometry | Inject failed presentation write with intact track, retain memory state and navigation. Track+presentation failure retains track warning priority. |

SF Pro body 17/22, large title 34/41 bold, footnote 13/18, semantic label and
grouped background tokens are measured design values translated to native text
styles. Row heights are minima, adaptive for text. Native system shell geometry
is not a pixel equality claim. No new static image assets are required: existing
map/checklist assets remain reused, SF Symbols use names from design context.

Pre-edit iPad Pro 11-inch (M5), iOS 27.0 portrait (834×1210 pt): existing Settings
is a placeholder, with no selector. Directly inspected screenshot:
`/var/folders/37/w2lgd8v96_348s1hxcxgwlcr0000gn/T/ActionArtifacts/6F4D46EF-8B79-4078-901B-1195F7CE06F6/DeviceInteractionSynthesize/Issue 161 Baseline-00_44_25_401-screenshot.png`.

## Validation

The implementation uses one app-owned observable controller, independent atomic
preference files, and narrow checklist inputs at explicit/automatic starts.
Schema 3 retains definition revision, captured absence, review/presentation/phase
state, visibility, and progression policy. Schema 1/2 remains readable; interrupted
legacy upgrades retain the historical fallback. Presentation-only entries are
excluded from the navigation debrief timeline. No other Settings rows ship.

Retained screenshots and accessibility hierarchies are in
[`settings-161-evidence`](settings-161-evidence). These use isolated temporary
libraries and preferences, not personal data. The primary implementing agent
directly inspected the referenced Figma artifacts and screenshots. Human visual
acceptance remains pending.

| Rendered state | Exact authority | Evidence / comparison |
| --- | --- | --- |
| iPad portrait main | `3:628`, delivered-row omission rule `7:1029` | [Screenshot](settings-161-evidence/ipad-main-portrait.png): matched content structure, 72pt inset, 82pt row, 14pt corner, trailing value. Native shell follows platform rule. |
| iPad landscape main / selector, including Back | `7:435`, `7:1029` | [Main](settings-161-evidence/ipad-main-landscape.png), [selector](settings-161-evidence/ipad-selector-landscape.png): matched 72/24pt content insets relative to native detail area, 76pt rows, subtitle value, stable title after Back. |
| Exact iPhone 16 Pro portrait main | `8:381`, `7:1029` | [Screenshot](settings-161-evidence/iphone16-main.png): matched 20pt content inset, 76pt row, secondary-line value, no extra groups. Native title/tab shell positions are platform-owned. |
| Hebrew / English / none selection | `7:42`, `7:127`, `7:204`, compact rule `7:657` | [Hebrew](settings-161-evidence/iphone16-selector-hebrew.png), [English](settings-161-evidence/ipad-selector-english.png), [none](settings-161-evidence/iphone16-selector-none.png): matched 24pt inset, three 76pt minimum rows, black selected checkmark, 14pt group corners, choice-specific footer. |
| iPad portrait selector | `7:42`, native shell rule `7:1029` | [Screenshot](settings-161-evidence/ipad-selector-portrait.png): row content matches; native iPad top-tab navigation uses a compact centered title despite explicit large-title preference. Figma shows a large title. This shell variation is recorded for owner review, not claimed as exact title matching. |
| Failed save / Retry / relaunch | `7:845`, SET-13 | [Failure](settings-161-evidence/iphone16-save-failure.png), [saved main after retry/relaunch](settings-161-evidence/iphone16-relaunch.png): matched error hierarchy and retained/attempted copy; Retry saved none and relaunch retained it. |
| Dark | `7:734`, semantic-color rule `7:1029` | [Screenshot](settings-161-evidence/iphone16-dark.png): matched semantic dark grouped surfaces and label hierarchy by bounded visual comparison. |
| Accessibility XXXL | `7:1007`, adaptive rule `7:1029` | [Main](settings-161-evidence/iphone16-xxxl-main.png), [selector](settings-161-evidence/iphone16-xxxl-selector.png), [scrolled footer](settings-161-evidence/iphone16-xxxl-footer.png): body rows expand and wrap; all choices/footer reachable. Native large selector title truncates at this extreme size; collapsed title is complete. Body clipping/overlap was not observed. |
| Hebrew, collapsed, Noted, device-default edit | Existing Cockpit `yvLXb8bUFBiZHqsag4hq6I` / `198:250`, SET-08/14 | [Expanded](settings-161-evidence/cockpit-hebrew-expanded.png), [collapsed](settings-161-evidence/cockpit-collapsed.png), [after default edit](settings-161-evidence/cockpit-capture-after-default-change.png), [Noted](settings-161-evidence/cockpit-noted.png): reused 380pt checklist surface, existing course/timer/body/controls; changing default to English retains Hebrew capture. Bounded visual comparison matches existing component treatment; fixture text differs from design. |
| English successor | Existing Cockpit `198:250`, template reuse SET-08 | [Screenshot](settings-161-evidence/cockpit-english-successor.png): same renderer with English template and dynamic leg values; new leg captures English. Automated parameterized tests separately exercise automatic starts. |
| No checklist | SET-08 omission rule in `7:1029` | [Screenshot](settings-161-evidence/cockpit-none.png): checklist and chip absent; timing, navigation, and next-leg disclosure remain. Matches the omission rule. |
| Presentation journal failure | Owner-approved copy and existing Cockpit warning geometry | [Screenshot](settings-161-evidence/cockpit-presentation-warning.png): exact approved detail, retained in-memory chip, navigation controls enabled. No track-loss claim. Track-warning priority is separately unit tested. |

Measurements use simulator hierarchy coordinates in points. Insets and minimum
heights agree within 1pt rounding; no pixel equality is claimed for native shell
chrome, font rasterization, or semantic-color rendering. Phone viewport is
402×874pt; iPad is 834×1210pt portrait and 1210×834pt landscape, iOS 27.
Selected traits, control labels, saved values and navigation hints were inspected
in retained hierarchies. Actual spoken VoiceOver remains unverified.

Final build-for-testing passed (`BuildProject-Log-20261121-072355.txt`). The final
expanded regression passed **313/313**
(`RunSomeTests/B7E3CB69-E5C9-467C-983B-DDECE99BB551.txt`). It covers Settings,
recording engine/coordinator/store/recovery, app state, Cockpit adapters, debrief,
diagnostic export and GPX export. The earlier six-suite focused pass was 118/118
(`RunSomeTests/DB9ABF92-CA31-4A31-B77D-6D3417DD69F8.txt`).
The new manual-policy test exposed stale sequence metadata in the in-memory store;
the store now updates its sequence on every event, consistent with disk replay.
Both final UI tests passed (`RunSomeTests/E5A7B25D-DB0D-414E-9AF1-F7D2EA296B28.txt`):
`testChecklistSettingsSaveBackRelaunchAndFailureRetry` and
`testNoChecklistStartAndRecoveryStayAbsent`.
Live diagnostics are clear for all changed Swift files, including the final
spacing/warning-lifetime changes. Main group spacing is 30pt on iPad portrait and
24pt on phone/landscape, measured from the respective Figma frames. A successful
later navigation commit carrying durable checklist context clears an earlier
presentation warning; the regression checks both that clearing and subsequent
track-warning priority.

Actual spoken VoiceOver, a separate compact 393pt viewport, freeform window
resizing, and Reduced Motion runtime validation remain unverified. The available
interaction API has no VoiceOver focus/audio interface; the optional combined
simulator interaction timed out without returning artifacts. Rotation and exact
iPhone16 portrait are verified; they are not substitutes for the unverified cases.
Exact undo state is unit-tested for all choices, but a separate post-undo screenshot
was not produced by that timed-out interaction. These are acceptance limitations,
not passes or approved deferrals. The issue remains open for review.

Acceptance mapping posted to
[#161](https://github.com/johnbenz13/NavigationFlight/issues/161#issuecomment-7057941609).
No commit, push, pull request or issue closure was performed.
