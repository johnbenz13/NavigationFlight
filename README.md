# Navigation Flight

Navigation Flight is a SwiftUI application for iPhone and iPad. The project is currently in its bootstrap phase; product behavior, persistence, map integration, and UI/UX are intentionally not established yet.

## Architecture boundaries

Production code is organized by responsibility:

- `App` contains the application entry point and root composition.
- `Features` contains user-facing feature modules. A feature owns its presentation and feature-specific coordination.
- `Domain/Flight` contains flight concepts and rules that are independent of presentation, storage, and external data formats.
- `Domain/Navigation` contains navigation concepts and rules with the same independence requirements.
- `Data/FPLNav` is the boundary for adapting FPLNav contract data to and from domain concepts.
- `Map` contains map-facing integration code and must not define domain or shared wire contracts.
- `Persistence` contains local storage implementations. Domain and feature code should not depend on a concrete persistence technology.
- `DesignSystem` contains reusable visual foundations shared by features.
- `Resources` contains bundled charts, fixtures, maps, and styles. Fixtures are test or development inputs, not authoritative contracts.

Dependencies should point inward: app and features may compose domain capabilities; infrastructure folders such as `Data`, `Map`, and `Persistence` implement boundary concerns without moving those concerns into the domain. Cross-boundary dependencies should be explicit and kept narrow.

## Shared contract

`fplnav-spec` is the authoritative shared contract for FPLNav interchange. Contract definitions, field semantics, and compatibility decisions belong there. Navigation Flight consumes that contract through the `Data/FPLNav` boundary and must not create a competing wire schema or treat application implementation details as part of the shared contract.

The dependency direction for flight-plan data is:

```text
.fplnav JSON -> FPLNavDecoder -> version-specific DTO -> version-specific mapper -> Domain
```

- `fplnav-spec` owns the serialized contract.
- `Data/FPLNav` owns parsing, supported wire versions, compatibility, and mapping.
- `Domain` owns immutable Navigation Flight application semantics.
- `Features` consume Domain types only and must never import versioned DTOs.

Navigation Flight currently reads format version 5 and does not write `.fplnav`.
The v5 contract contains planned waypoint altitude, east-positive magnetic
variation, true wind direction, and manual VOR/DME radial/distance. It does not
serialize a planned leg course/heading or planned leg duration, so the app does
not derive or invent those values at this boundary.

## Shared-contract development tooling

Development tooling pins the private GitHub npm package
`@johnbenz13/fplnav-spec@0.1.1` (`gitHead`
`f8dc139057e088552a83d92882ebd3b0052392a3`, package integrity recorded in
`package-lock.json`) and follows its declared Node 24.18.1 toolchain. That release
has no corresponding Git tag. Its published
package includes `schemas/v5/fplnav.schema.json`, the compatibility/versioning
documentation, and `examples/v5/representative.fplnav`. Repository validation
fixtures are not included in the package.

Authenticate temporarily with the GitHub CLI and refresh the generated unit-test
vector:

```sh
gh auth refresh -h github.com -s read:packages
export FPLNAV_PACKAGES_TOKEN="$(gh auth token)"
npm run contract:refresh
unset FPLNAV_PACKAGES_TOKEN
```

The checked-in `.npmrc` contains only an environment-variable reference. Never
put a real token in `.npmrc`, source control, logs, or Xcode settings. The refresh
script checks the published npm `gitHead`, installs the exact lockfile, copies the
official v5 representative example unchanged into
`NavigationFlightTests/Fixtures`, and validates it with the package's v5 runtime
validator. Run the offline verification again after installation with:

```sh
npm run contract:verify
```

The fixture is synchronized under the unit-test target, not under the application
source tree, so it is not bundled in the shipping app. CI should provide a
short-lived package-read credential as the `FPLNAV_PACKAGES_TOKEN` environment
variable, run `npm ci --ignore-scripts`, `npm run contract:verify`, and then run
the Xcode tests. CI must mask that credential.

Run the application and Swift tests from Xcode using the `NavigationFlight`
scheme, or use the equivalent build/test actions in CI.

To add format v6, create `Data/FPLNav/V6` DTOs and a dedicated v6 mapper based on
an exact released `fplnav-spec` version, add a v6 case only to `FPLNavDecoder`'s
dispatch, and stage official version-pinned v6 test vectors. Callers and Domain
must remain free of wire-version switches. If v6 adds semantics, model them in
Domain independently of their JSON layout.
