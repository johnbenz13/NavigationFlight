# Charts V1 technical design

## Status and authority

John approved the technical design on 2026-11-21. He also approved the
[Charts product specification](../features/CHARTS_SPEC.md) and
[Figma Iteration 02](https://www.figma.com/design/WfBJGtbq2I37ODQZj44Yz1?node-id=13-825)
on 2026-11-21. The inspection baseline is NavigationFlight main at
`0723ec76b7018a956b6b6ccb771666528bd84447`. The specification and this proposal
are in the planning worktree. The shared repository permalink is pending
publication. John subsequently selected the shared `aviation-maps` package
as the snapshot owner. John approved the revised release handoff on 2026-11-21. The approved
product and Figma contracts govern the app.

## Inspected integration points

| Existing interface | Evidence and impact |
| --- | --- |
| [RootView](../../NavigationFlight/App/RootView.swift) and [AppFeatureState](../../NavigationFlight/App/AppFeatureState.swift) | RootView owns the native adaptive tab shell and binds section selection through AppFeatureState. AppFeatureState protects pending confirmations, creates a new Flight on accepted load or restart, and applies recovery. The recording task follows Flight ID. |
| [CockpitFeatureState](../../NavigationFlight/Features/Cockpit/CockpitFeatureState.swift), [CockpitFeatureView](../../NavigationFlight/Features/Cockpit/CockpitFeatureView.swift), and [CockpitPresentationState](../../NavigationFlight/Features/Cockpit/CockpitPresentationState.swift) | The value state owns the loaded Flight Plan and Flight. The feature view composes the cockpit with location and recording. Presentation state allows one disclosure at a time. The existing map panel and compact sheet provide Charts entry hosts. |
| [CockpitView](../../NavigationFlight/Features/Cockpit/CockpitView.swift) and [Map tools](../../NavigationFlight/Features/Cockpit/CockpitMapControls.swift) | Chart layers shows an unavailable alert. Section exit dismisses transient presentations. Active-leg changes clear leg-related disclosures and can update the underlying map. |
| [FlightPlan](../../NavigationFlight/Domain/Flight/FlightPlan.swift), [decoder](../../NavigationFlight/Data/FPLNav/FPLNavDecoder.swift), and [aerodrome references](../../NavigationFlight/Domain/Navigation/NavigationTypes.swift) | The loaded plan already carries optional departure and arrival references with catalog ID, name, location, and optional ICAO and local codes. The [Herzliya–Rosh Pina fixture](../../NavigationFlightTests/Fixtures/FPLNav/V7/Official/llhz-llib-via-jerusalem-v7.fplnav) supplies both. V9 chart text belongs to the Flight Plan. |
| [App target](../../NavigationFlight.xcodeproj/project.pbxproj) | iOS 27 deployment, synchronized groups, Swift 5 language mode and MainActor default isolation for the app. The Charts design follows the established portrait iPhone and both iPad orientations. The current target also declares iPhone landscape. Treat that as existing app configuration and preserve it. |

## Catalog and AIP snapshot

### Shared ownership and release

[aviation-maps](https://github.com/johnbenz13/fplnav-spec/tree/0b0c55c52c1beb8c7cce2df86d7b8db986326d7d/packages/aviation-maps)
owns the official source inventory, canonical chart and aerodrome associations,
original PDFs, and versioned metadata. Reuse the shared Israeli aviation
catalog IDs. The package produces one language-neutral, reviewed domestic AIP
snapshot that Navigation Flight can adopt first and another app can adopt later.

Reconcile the official Airports and Airfields chapters against the page
checklist at the chosen effective cutoff. Start from the existing inventory
and resolve source conflicts, unknown dates and document availability against
the publisher before claiming a complete release. Keep original PDF bytes
and reuse one asset for all chart records that reference it. The snapshot
edition and effective date are distinct from each published chart's printed
amendment or date. Record the source, canonical aerodrome ID, reviewed identifier
aliases, publisher order and category, exact chart name, procedure role tags,
and its ordered original pages. A page reference uses the asset SHA-256 and
zero-based source page index. Keep original source URLs and the publisher's
human-readable page references.

The current shared manifest already supports aerodrome chart records and PDF
artifacts. It does not express chapter and chart order, applicable procedure
roles, or selected pages with several charts sharing one PDF. Extend the
package-owned, language-neutral release contract to represent those facts
while keeping existing release pins installable. Bind the chart index to the
same reviewed manifest digest and artifact checksums as the PDFs. Design
source-page identity once in the shared package for later georeferencing.

Use the package's reviewed private GitHub Release transport for one separately
pinned chart snapshot. Keep large PDFs in release assets and small manifests,
pins and tools in Git. Adopt an explicit release ID and manifest SHA-256.
The shared installer verifies the release, chart index, sizes and checksums
before staging a complete app-specific resource directory. Keep retrieval,
credentials and release publication in developer or CI preparation. Preserve
a previously verified staging directory if a new install fails. Document
updates and rollback through explicit pin changes. A chart adoption updates
the app's charts without migrating its existing PMTiles. Later Editor adoption
can consume the same release and remains independently scheduled.

**Inspected upstream state.** The local reference for shared package main is
`0b0c55c52c1beb8c7cce2df86d7b8db986326d7d`. Main has the local release
installer. Pinned remote transport is proposed in [PR #16](https://github.com/johnbenz13/fplnav-spec/pull/16)
under [issue #10](https://github.com/johnbenz13/fplnav-spec/issues/10).
The link inventory and change reporting are proposed in
[PR #17](https://github.com/johnbenz13/fplnav-spec/pull/17) under
[issue #13](https://github.com/johnbenz13/fplnav-spec/issues/13).
Both PRs were open when checked. The chart release uses those tracks and is
proposed as a separate shared slice under
[issue #14](https://github.com/johnbenz13/fplnav-spec/issues/14).
GitHub transport acceptance and the exact PDF inventory remain upstream
release work. Owner-confirmed רת״א authorization is recorded. The shared release
review records its scope and reconciles the published notice referenced in #14
for the package and intended consumers. The historical Herzliya design sample
remains design evidence.

[Domestic AIP and checklist](https://www.gov.il/he/pages/aip?chapterIndex=1) ·
[Airports](https://www.gov.il/he/pages/aip?chapterIndex=7) ·
[Airfields](https://www.gov.il/he/pages/aip?chapterIndex=8) ·
[Existing chart inventory evidence](https://github.com/johnbenz13/fplnav-spec/blob/58e2946969cf15c282b9e2915ac489084fe8e421/docs/research/original-airport-charts-2026-11-06.md)

### Navigation Flight consumption

Bundle the staged snapshot at Xcode build time. Verify pin identity, expected
resources, casing, bundle paths and package size against the installed Release
build. The app reads the shared language-neutral data through one Swift catalog
adapter injected from RootView. Its interface exposes the library hierarchy,
one query for the loaded plan's two references, and document lookup by chart ID.
It owns the runtime lookup, cockpit ranking and handling of unavailable
resources. Use value data and an injected fixture location. Runtime PDFKit
reads the same installed originals for both entry points, without networking.
The app has no package publisher or installer at runtime.

Package checks establish completeness, duplicate IDs, alias resolution, source
hashes, page bounds and order. Consumer tests verify Swift decoding and exact
resource availability. A malformed or missing catalog presents an unavailable
state. A missing, unreadable or invalid PDF affects the requested document and
leaves other charts selectable.

### Cockpit selection contract

Use the departure and arrival from the loaded Flight Plan snapshot.
Normalize case and surrounding whitespace in each typed identifier namespace.
Resolve canonical ICAO, local codes and explicitly verified catalog aliases
against the manifest. A candidate requires a unique match and agreement among
recognized identifiers. A supplied code that conflicts with the candidate's
known code makes the reference unresolved. Use names as labels. Coordinates,
waypoint names, leg endpoints and location data have no role in resolution.

For each endpoint return an available aerodrome, an absent reference, an
unresolved reference, or a matched aerodrome without charts. Keep the two
roles independently usable. Collapse identical canonical aerodromes into one
set with both roles. For matched endpoints, keep procedure rows applicable to
their Flight Plan role first, circuits next, and all remaining charts last.
A chart tagged for both departure and arrival ranks with the procedures when
either role applies. Preserve published order within an aerodrome and rank.
For ties between different aerodromes, use departure before arrival for
procedures and other charts, and arrival before departure for circuits,
following Iteration 02. Deduplicate a chart within a shared endpoint. Both entry points use the same chart identity and
document lookup.

## Navigation, presentation, and Flight ownership

**App section.** Add Charts between Flights and Settings using the existing
`TabView` with `.sidebarAdaptable`. Keep Charts selection and the aerodrome
navigation path in app-owned state so a size-class or tab change does not
recreate them. Keep app section selection through the existing guard for
pending Flight, library and recording confirmations. Use native overflow
when it meets CH-01. Verify actual behavior at narrow widths and supported
text sizes early. If native overflow cannot keep the approved four sections
directly visible, use a native More tab on the constrained layout with a
Settings row. Keep More as tab presentation state and use the existing
Settings destination when widening or returning through it. Preserve section
order and disable customization. Apple documents a native size-class-specific
tab declaration if the fallback is needed.
[Adaptive tab style](https://developer.apple.com/documentation/SwiftUI/TabViewStyle/sidebarAdaptable?changes=lates_5_10) ·
[SwiftUI TabView](https://developer.apple.com/documentation/swiftui/tabview?changes=l__8&language=objc)

**Cockpit.** Replace the placeholder action and alert with a Charts list in
the existing mutually exclusive map disclosure. Use the established trailing
panel at regular width and transition Map tools to Charts within one compact
sheet host. Present the document full-screen from a stable cockpit host.
Serialize compact sheet dismissal and viewer presentation using presentation
callbacks. Retain an explicit return intent while the transition completes.
The viewer's Charts control returns to the filtered list. Close and equivalent
viewer dismissal return to the map. List dismissal returns to the map.
Rotation and resizing change the host layout while preserving the active route.

**Recall.** Keep the last successfully opened chart ID in transient
CockpitFeatureState, scoped to the running Flight ID. Record it only after
the current viewer has loaded the authorized pages. A failed open leaves the
previous successful selection available. Discard an unavailable remembered
selection and show the current Flight list. Clear recall on successful load,
restart, Flight removal or restoration. A canceled or failed replacement
preserves the old Flight's recall. A leg change and a tab round trip preserve
recall, and a leg change leaves an already visible viewer open. Opening from
the app library has independent navigation and recall. Reinitialize the viewer
to fit the page when invoking cockpit recall.

Chart presentation mutates presentation and recall state; existing Flight and
recording mutation paths remain responsible for flight events. Chart actions
send no navigation events or recording commands. Maintain the map hierarchy,
camera and active Flight ID during chart transitions. Apply the existing
Position Check rules on actual leg, app-section and scene changes.

## Shared PDF viewer

Use PDFKit through a focused SwiftUI representable as the proposed document
adapter. Keep PDFKit objects and view updates on the main actor. Prepare
manifest lookups and resource I/O away from the UI path when needed, returning
only value data. Open documents lazily for the selected chart, never on tab or
Flight load. Key the open request to its presentation and chart identity, and
ignore canceled or superseded results. A late result after dismissal or Flight
replacement cannot change recall or reopen a modal.

For a selected page subset, open the source read-only, validate the chosen
indices, and insert independent copies of those PDFPage objects into an
in-memory PDFDocument in catalog order. The app bundle retains the unchanged
source. Verify copy fidelity with the real Herzliya page and representative
multi-page and rotated charts, including published page bounds, legends,
annotations and typography. Honor the publisher’s page geometry in the fit
calculation and avoid adding any crop. If the projection fails fidelity checks, stop at
that implementation gate and evaluate a selected-page drawing adapter using
the original page objects behind the same viewer interface. Architect the
renderer as an internal seam. Start with PDFKit to reuse its vector rendering,
pinch, pan and accessibility support. Use public PDFKit interfaces for fit,
scale and page position. Keep unselected source pages inaccessible through
scroll, page jumps and PDF links. Route the visible official source link
through an explicit user action.

In-app chart rendering remains independent of the navigation map. Future
georeferencing can attach control points and a transform to the source-page
byte revision and page index, with page box and rotation in that contract.
A later overlay can use the same page reference whenever the underlying chart
revision is still valid.
[PDFView](https://developer.apple.com/documentation/pdfkit/pdfview) ·
[PDFPage](https://developer.apple.com/documentation/pdfkit/pdfpage?changes=__8_10) ·
[PDFDocument page insertion](https://developer.apple.com/documentation/pdfkit/pdfdocument/insert%28_%3Aat%3A%29)

## Verification contract

The following evidence is for implementation. This planning stage authorizes
documentation review and link checks. No implementation builds, tests or device
launches are part of this stage.

| Requirements | Observable evidence |
| --- | --- |
| CH-01, CH-02 | Extend [AppFeatureStateTests](../../NavigationFlightTests/AppFeatureStateTests.swift) for section order, selection and preservation of pending work. Use XCTests to check first launch, both AIP groups, preserved library path, Settings via More when required, and Charts remaining directly selectable. Inspect installed iPad portrait, iPad landscape and iPhone 16 Pro portrait plus a narrow window and larger text. |
| CH-03, CH-04 | Verify the shared release against the publisher checklist and original binary hashes, then verify the consumer pin and packaged output. Exercise the official Herzliya chart from both entry points and a fixture PDF with a neighboring unrelated page and selected multi-page range. Check page boundaries, rotation, sharpness, fit, zoom, pan, source date, and failed-file recovery. Use a fresh installed build with connectivity disabled and no prewarmed cache. |
| CH-05, CH-06 | Use a small catalog and the existing official V7 fixture for ranking and endpoint roles. Cover missing references, matching by typed alias/local code, conflicting identifiers, matching with no published charts, same-aerodrome deduplication, and absence of unrelated aerodromes. Pass representative currently supported decoded plans through the same resolver. |
| CH-07, CH-08 | Extend [CockpitPresentationStateTests](../../NavigationFlightTests/CockpitPresentationStateTests.swift) and [cockpit UI tests](../../NavigationFlightUITests/NavigationFlightUITests.swift). Prove first open, successful recall, retention on failed open, stale result suppression, tab round trip, active leg change, canceled replacement, successful restart/replacement, and relaunch with and without recovery. Verify Charts/Close, compact sheet sequencing, camera, running timer, recording continuity and Position Check behavior. |
| CH-01–CH-08 presentation | Compare the rendered views with exact [Iteration 02 frames](https://www.figma.com/design/WfBJGtbq2I37ODQZj44Yz1?node-id=13-825). Capture named device and OS, orientation or window width, fixture and screenshots. Verify VoiceOver focus and row announcements, toolbar labels, Dynamic Type wrapping, tap targets and safe areas. |
| CH-09 | Ensure the renderer exposes chart revision and page index as immutable value data. Confirm that opening Charts creates no map overlay or map configuration changes. |

Use Swift Testing for catalog, lookup and state transitions and existing
XCUITest patterns for app flows. Use deterministic fixture controls for
cancellation and late loads. Separate malformed fixture tests from the verified
release snapshot. A device smoke test after an app-update snapshot refresh
checks that users see the new edition and unaffected app data.

## Technical decision record

1. **Approved shared packaging.** Use a shared, pinned `aviation-maps`
   release and stage it into the app at preparation time. This keeps one
   source for multiple apps and retains offline first launch. App-specific
   PDF ownership would duplicate provenance and ingestion. Runtime downloading
   would add a connectivity and first-run availability contract.
2. Approved typed matching and transient Flight-ID recall in existing cockpit
   state. A broad name/coordinate match increases ambiguity. Persistent recall
   would affect the recovery contract already approved for V1.
3. Approved a shared PDFKit viewer with a release fidelity check on page
   subsets, and native adaptive tabs with a verified More fallback. A custom
   PDF renderer or tab bar would expand zoom, accessibility and device
   behavior ownership.

The [delivery plan](../features/CHARTS-DELIVERY-PLAN.md) records ticket
coverage, dependencies and publication status.
