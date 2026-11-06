import Foundation

/// V8's source-only addition, decoded in the same route order as the shared V7 fields.
/// Kept separate so V5/V7 retain their handling of unconsumed source properties.
nonisolated struct FPLNavV8SourceSpeeds: Decodable {
    let overrides: [Double?]

    private enum Keys: String, CodingKey {
        case navigation, route, legs, planningAirspeedOverrideKnots
    }

    private struct Leg: Decodable {
        let override: Double?

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: Keys.self)
            // Only omission inherits; present null or a non-number is invalid.
            override = container.contains(.planningAirspeedOverrideKnots)
                ? try container.decode(Double.self, forKey: .planningAirspeedOverrideKnots)
                : nil
        }
    }

    init(from decoder: any Decoder) throws {
        let root = try decoder.container(keyedBy: Keys.self)
        let navigation = try root.nestedContainer(keyedBy: Keys.self, forKey: .navigation)
        let route = try navigation.nestedContainer(keyedBy: Keys.self, forKey: .route)
        overrides = try route.decode([Leg].self, forKey: .legs).map(\.override)
    }
}
