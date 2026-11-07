# V9 chart-text project reader

Issue [#133](https://github.com/johnbenz13/NavigationFlight/issues/133) is the
NavigationFlight compatibility prerequisite for Editor T17. The shared V9
contract is proposed in [fplnav-spec PR #22](https://github.com/johnbenz13/fplnav-spec/pull/22).

The public `FPLNavDecoder.decode(_:)` interface explicitly accepts V9. It
validates `navigation.chartTexts` and the chart-text style additions before
the existing V7/V8 mapper constructs `FlightPlan` from source route and saved
execution. Chart text has no domain or cockpit representation: no reminder,
route event, timing, fuel, or operational cue is derived from its content.
Malformed chart text and unsupported future versions fail before projection.
V5, V7, and V8 continue through their existing reader paths.

The decoder module owns version dispatch. Its V9 validator owns the strict
chart-text source and style rules: UUID identity, entity uniqueness, exact
plain text, Unicode length, WGS84 coordinates, rotation, record count, sparse
style values, and chart-text style target ownership. The mapper's version
check allows V9 to reuse saved execution without recalculation.

The decoder test seam compares paired documents that differ only by the V9
chart-text source/style additions and version number. Complete `FlightPlan`
equality covers route, planned navigation, annotations, timing, fuel and the
inputs to cockpit cues. Shared valid and invalid goldens and local mutations
cover malformed records and style references; a V10 candidate proves explicit
future-version rejection. Fixture provenance is recorded in
[PROVENANCE-V9.md](../../NavigationFlightTests/Fixtures/FPLNav/V9/PROVENANCE-V9.md).

No UI behavior or visual design is included in this issue.
