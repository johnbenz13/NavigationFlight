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

