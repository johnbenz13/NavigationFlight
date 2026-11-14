# Batch 01 authority and limits

Inspected on 2026-11-14 against baseline `1a2d7e7596667a39616fe3812f6a07326f30ca00`.
This appendix supports the user stories; it does not certify the full feature.

## Written contracts and supersession

| Source | Role in this chapter |
| --- | --- |
| [App Navigation and Flight Plans Library](../../../features/APP-NAVIGATION-AND-FLIGHT-PLANS-LIBRARY_SPEC.md) | §§4, 13–17, 22–23, 27–29 define library, inspection, load, return, and continuation; §§8–11 define adaptations and unobscured controls. |
| [Automatic Flight Recording and Recovery](../../../features/AUTOMATIC-FLIGHT-RECORDING-AND-RECOVERY_SPEC.md#scope) | Explicitly adds Flights as the fourth section and supersedes fresh-launch non-restoration for recoverable Flights. Four sections are expected, not a defect against the older spec. Recovery itself is unobserved in this chapter. |
| [Flying a Leg](../../../features/FLYING-A-LEG_SPEC.md) | Ready does not start timing. Current Figma authority is Iterations 09–10; the cross-feature loaded-review hierarchy is owned by library iteration 04. |
| [Product/Figma workflow](../../../workflows/PRODUCT-SPEC-FIGMA-WORKFLOW.md) | Written behavior and approved visual authority remain distinct; native system chrome owns its precise geometry. |
| [Glossary](../../../../GLOSSARY.md) | Flight Plan is imported preparation; Flight is one execution. |

The older library specification still says three sections and no restoration on fresh
launch. The recording spec explicitly resolves both points. Recommend adding short
supersession pointers to the older text; do not change behavior to match it. The root
README also describes a bootstrap app and v5-only reading; that is a candidate for a
later documentation pass, not an assertion about all currently supported formats.

## Inspected design previews

All previews below were downloaded through a read-only Figma session and visually
inspected on 2026-11-14. Stable node URLs, not temporary asset URLs, are the references.
Their design revision is the named approved iteration in the repository spec; the
tools did not supply an immutable Figma version identifier.

| Exact node | Meaning and status | Retained preview |
| --- | --- | --- |
| [FDSRcz1yl7bkSoziKvGzQ1 / 28:187](https://www.figma.com/design/FDSRcz1yl7bkSoziKvGzQ1?node-id=28-187) | Iteration 03 iPad portrait library, approved 2026-11-02; three-section shell predates recording extension. | [PNG](../assets/figma/batch-01/library-ipad-28-187.png) |
| [28:239](https://www.figma.com/design/FDSRcz1yl7bkSoziKvGzQ1?node-id=28-239) | Same approved iteration, canonical expanded iPad landscape sidebar; orientation alone does not mandate sidebar. | [PNG](../assets/figma/batch-01/library-landscape-28-239.png) |
| [28:295](https://www.figma.com/design/FDSRcz1yl7bkSoziKvGzQ1?node-id=28-295) | Same approved iteration, iPhone portrait library. | [PNG](../assets/figma/batch-01/library-phone-28-295.png) |
| [28:513](https://www.figma.com/design/FDSRcz1yl7bkSoziKvGzQ1?node-id=28-513) | Not-loaded behavioral state card under approved coverage page 28:502; not a complete screen layout. | [PNG](../assets/figma/batch-01/not-loaded-28-513.png) |
| [41:76](https://www.figma.com/design/FDSRcz1yl7bkSoziKvGzQ1?node-id=41-76) | Iteration 04 loaded review, approved 2026-11-03; Continue primary, Restart separated and destructive. Supersedes 28:521's older action hierarchy. | [PNG](../assets/figma/batch-01/loaded-review-41-76.png) |
| [yvLXb8bUFBiZHqsag4hq6I / 190:96](https://www.figma.com/design/yvLXb8bUFBiZHqsag4hq6I?node-id=190-96) | Current iPad portrait cockpit direction from Iteration 09, within Iteration 10 approved baseline dated 2026-11-06. Active-state hierarchy reference, not a pixel contract for the ready state. | [PNG](../assets/figma/batch-01/cockpit-portrait-190-96.png) |

Figma metadata for page 28:502 retains an `IN REVIEW` frame label. The later explicit
owner approval in the specification and issue comment is retained as approval evidence;
the stale label is not interpreted as revoking approval. Existing three-section Figma
screens are historical presentation references with the recording extension applied.

## Tracker evidence

- [Parent #34](https://github.com/johnbenz13/NavigationFlight/issues/34) is open.
  Its body says changes requested, but the [2026-11-02 approval comment](https://github.com/johnbenz13/NavigationFlight/issues/34#issuecomment-6586084963)
  explicitly approves corrective iteration 03. This chapter does not close the issue
  or infer final acceptance from child status.
- [Library/import #39](https://github.com/johnbenz13/NavigationFlight/issues/39) is closed.
  Its implementation evidence includes historical tests and device checks, followed
  by corrections for persistence timestamps and percent-encoded paths. Those are
  historical reports, not rerun evidence. One visual checklist item is marked checked
  while its prose says it remains unchecked; preserve that ambiguity until the owner
  reconciles acceptance records.

No tracker mutations were made. Other ticket bodies have not been audited in this batch.

## Implementation and test discovery

- [FlightPlansFeatureView](../../../../NavigationFlight/Features/FlightPlans/FlightPlansFeatureView.swift)
  owns library navigation, the one-file picker, and the library inspection screen.
- [RootView](../../../../NavigationFlight/App/RootView.swift) composes four app sections,
  recording/recovery, and isolated debug fixtures.
- [AppFeatureState](../../../../NavigationFlight/App/AppFeatureState.swift) owns app-section
  selection and Flight commands.
- [UI tests](../../../../NavigationFlightUITests/NavigationFlightUITests.swift) contain
  discovery scenarios for empty/populated library, inspection/load, returning, protected
  restart, import cancellation, revision handling, and removal. Their existence does
  not prove current runtime conformance. No test suites were run for this reconciliation.

The earlier cockpit checkpoint build and tests belong to the baseline's validation,
not this chapter. The runtime build/install used for captures is recorded in the
capture manifest. Source inspection never substitutes for an observed screen.
