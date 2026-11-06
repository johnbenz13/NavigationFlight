# V8 per-leg planning speed reader

Approved scope: issue #128 and the cross-repository T11 contract plan. Read V8
through the existing FPLNavDecoder interface, preserve V5/V7 behavior, and consume
saved execution values without recalculating flight mathematics or changing UI.

The decoder owns version dispatch and V8-only source override decoding. The
existing execution mapper owns retained source identity/order, wind, annotations,
and execution validation. A V8-only optional speed list in source route order
supplies effective speed validation; domain models remain unchanged. Missing
source speed inherits the global value; present values must be positive finite
numbers (null, booleans, strings and nonpositive values are invalid).

Acceptance and tests at the approved public decoder seam:
- Exact shared V8 golden maps inherited 90 kt/40 s and overridden 60 kt/60 s.
- Exact shared invalid fixtures reject nonpositive override, mismatched effective
  speed and incomplete wind; malformed overrides and unknown versions reject.
- Saved values reach planned navigation without recalculation.
- Existing V5/V7 fixtures and rejection coverage continue passing.
- Record exact vendored provenance and unpublished package status honestly.

TDD starts with one golden decoder test failing for unsupported V8, then minimal
reader support, followed by rejection tests and targeted fixes. Run focused
simulator decoder/mapper tests, app build, and git diff --check. No UI scope or
Figma evidence applies. Update integration documentation for V8 support.

## Validation evidence (2026-11-07)

- Readiness: issue #128 has no native blockers or fallback comments; no open PR
  implemented it. The isolated branch started at synchronized `origin/main`
  `3074b88f7ccb0e33127f464a78cc2221d076892e`, preserving the owner's dirty checkout.
- TDD red: the first golden test failed with `unsupportedFormatVersion(8)`;
  after the decoder change the same one test passed. Initial iPhone 18 Pro test
  launch stalled, so that process was stopped and retried on booted iPhone 17
  with simulator parallelism disabled. Retained logs: `/tmp/flight-v8-red-retry.log`
  and `/tmp/flight-v8-green.log`.
- Focused compatibility run passed 14 test functions / 63 cases: exact V8 saved
  speeds and durations, three invalid shared fixtures, malformed/null/string/bool/
  nonfinite/nonpositive override candidates, unknown versions, no recalculation,
  20 retained invariant cases under V8 and V7, V5 mapping, typed legacy errors,
  official V7, three Editor V7 vectors, empty V7, and V7 ignoring the V8 source
  addition. Log: `/tmp/flight-v8-focused-final.log`.
- Independently passed all four vendored files through the built merged shared
  `navigationProjectV8Schema` from source commit `49f6153`: golden accepted;
  nonpositive override, mismatched speed and missing wind solution rejected.
  Byte hashes and source paths are in [fixture provenance](../../NavigationFlightTests/Fixtures/FPLNav/V8/PROVENANCE-V8.md).

Successful focused command (iPhone 17, iOS 27 simulator):

```sh
xcodebuild test -project NavigationFlight.xcodeproj -scheme NavigationFlight \
  -destination 'platform=iOS Simulator,id=6627D21B-1C30-41AC-B43E-08B525640BDA' \
  -parallel-testing-enabled NO -derivedDataPath /tmp/flight-v8-derived \
  -only-testing:NavigationFlightTests/FPLNavV8DecoderTests \
  '-only-testing:NavigationFlightTests/NavigationFlightTests/representativeV5MapsIntoDomain()' \
  '-only-testing:NavigationFlightTests/NavigationFlightTests/unsupportedVersionIsTyped()' \
  '-only-testing:NavigationFlightTests/NavigationFlightTests/brokenWaypointRelationshipIsTyped()' \
  '-only-testing:NavigationFlightTests/NavigationFlightTests/officialV7MapsSavedExecutionWithoutRecalculation()' \
  '-only-testing:NavigationFlightTests/NavigationFlightTests/editorV7VectorsDecode(_:)' \
  '-only-testing:NavigationFlightTests/NavigationFlightTests/validEmptyV7IsDecodedButNotFlightEligible()' \
  '-only-testing:NavigationFlightTests/NavigationFlightTests/invalidV7ExecutionIsRejected(_:)' \
  > /tmp/flight-v8-focused-final.log 2>&1
```

Application build passed with existing actor-isolated conformance warnings in
unchanged domain/map code. No new concurrency work is included. Build log:
`/tmp/flight-v8-build.log`.

```sh
xcodebuild build -project NavigationFlight.xcodeproj -scheme NavigationFlight \
  -destination 'platform=iOS Simulator,id=6627D21B-1C30-41AC-B43E-08B525640BDA' \
  -derivedDataPath /tmp/flight-v8-build > /tmp/flight-v8-build.log 2>&1
git diff --check
```

Whitespace check passed. No UI behavior, simulator visual claim, npm publication,
or V8 coverage by the existing npm contract verification command is claimed.
