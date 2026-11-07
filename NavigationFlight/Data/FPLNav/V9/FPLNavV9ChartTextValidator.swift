import CoreFoundation
import Foundation

/// Validates V9's chart-only source and style additions before the operational
/// V7/V8 mapper projects the unchanged execution contract into FlightPlan.
nonisolated struct FPLNavV9ChartTextValidator {
    func validate(_ data: Data) throws {
        let root = try object(JSONSerialization.jsonObject(with: data), "project")
        let navigation = try object(root["navigation"], "navigation")
        let notes = try array(navigation["chartTexts"], "navigation.chartTexts")
        try require(notes.count <= 100, "navigation.chartTexts", "must contain at most 100 records")

        var allIDs = sourceIDs(root: root, navigation: navigation)
        var chartTextIDs = Set<UUID>()
        for (index, value) in notes.enumerated() {
            let path = "navigation.chartTexts[\(index)]"
            let note = try object(value, path)
            try keys(note, allowed: ["id", "text", "position", "rotationDegrees"], path: path)
            let id = try uuid(note["id"], path + ".id")
            try require(allIDs.insert(id).inserted, path + ".id", "duplicates an entity ID")
            chartTextIDs.insert(id)
            guard let text = note["text"] as? String else { throw error(path + ".text", "must be a string") }
            try require(text.rangeOfCharacter(from: .whitespacesAndNewlines.inverted) != nil,
                        path + ".text", "must contain a non-whitespace character")
            try require(text.unicodeScalars.count <= 500, path + ".text", "must contain at most 500 Unicode code points")
            let position = try object(note["position"], path + ".position")
            try keys(position, allowed: ["latitude", "longitude"], path: path + ".position")
            try boundedNumber(position["latitude"], -90...90, path + ".position.latitude")
            try boundedNumber(position["longitude"], -180...180, path + ".position.longitude")
            try boundedNumber(note["rotationDegrees"], -180...180, path + ".rotationDegrees")
        }

        let presentation = try object(navigation["presentation"], "navigation.presentation")
        let globalStyles = try object(presentation["globalStyleOverrides"], "navigation.presentation.globalStyleOverrides")
        if let chartTextStyle = globalStyles["chartText"] {
            try style(chartTextStyle, "navigation.presentation.globalStyleOverrides.chartText")
        }
        let entries = try array(presentation["entityStyleOverrides"], "navigation.presentation.entityStyleOverrides")
        var styleTargets = Set<UUID>()
        for (index, value) in entries.enumerated() {
            let path = "navigation.presentation.entityStyleOverrides[\(index)]"
            let entry = try object(value, path)
            let target = try object(entry["target"], path + ".target")
            let overrides = try object(entry["overrides"], path + ".overrides")
            if target["kind"] as? String == "chart-text" {
                try keys(entry, allowed: ["target", "overrides"], path: path)
                try keys(target, allowed: ["kind", "id"], path: path + ".target")
                let id = try uuid(target["id"], path + ".target.id")
                try require(chartTextIDs.contains(id), path + ".target.id", "must reference a chart text")
                try require(styleTargets.insert(id).inserted, path + ".target", "duplicates a chart-text style target")
                try keys(overrides, allowed: ["chartText"], path: path + ".overrides")
                if let chartTextStyle = overrides["chartText"] {
                    try style(chartTextStyle, path + ".overrides.chartText")
                }
            } else {
                try require(overrides["chartText"] == nil, path + ".overrides.chartText",
                            "requires a chart-text target")
            }
        }
    }

    private func sourceIDs(root: [String: Any], navigation: [String: Any]) -> Set<UUID> {
        var ids = Set<UUID>()
        func collect(_ value: Any?) {
            guard let object = value as? [String: Any], let raw = object["id"] as? String,
                  let id = UUID(uuidString: raw) else { return }
            ids.insert(id)
        }
        func collectArray(_ value: Any?) {
            guard let values = value as? [Any] else { return }
            values.forEach(collect)
        }
        collect(root["project"])
        if let printDocument = root["printDocument"] as? [String: Any] {
            collect(printDocument)
            collectArray(printDocument["items"])
        }
        if let route = navigation["route"] as? [String: Any] {
            collectArray(route["waypoints"])
            collectArray(route["legs"])
        }
        for key in ["identificationPoints", "altitudeChanges", "radioFrequencyChanges", "vorDmeReferences"] {
            collectArray(navigation[key])
        }
        return ids
    }

    private func style(_ value: Any, _ path: String) throws {
        let fields = try object(value, path)
        try keys(fields, allowed: ["fontSizePagePixels", "fontWeight", "fontColor", "backgroundColor", "backgroundOpacity"], path: path)
        if let value = fields["fontSizePagePixels"] { try boundedNumber(value, 8...24, path + ".fontSizePagePixels") }
        if let value = fields["backgroundOpacity"] { try boundedNumber(value, 0...1, path + ".backgroundOpacity") }
        if let value = fields["fontWeight"] {
            let weight = try number(value, path + ".fontWeight")
            try require([400.0, 600.0, 700.0].contains(weight), path + ".fontWeight", "must be 400, 600, or 700")
        }
        for key in ["fontColor", "backgroundColor"] {
            guard let value = fields[key] else { continue }
            guard let color = value as? String,
                  color.range(of: "^#[0-9a-fA-F]{6}$", options: .regularExpression) != nil else {
                throw error(path + "." + key, "must be a six-digit hex color")
            }
        }
    }

    private func object(_ value: Any?, _ path: String) throws -> [String: Any] {
        guard let object = value as? [String: Any] else { throw error(path, "must be an object") }
        return object
    }

    private func array(_ value: Any?, _ path: String) throws -> [Any] {
        guard let array = value as? [Any] else { throw error(path, "must be an array") }
        return array
    }

    private func uuid(_ value: Any?, _ path: String) throws -> UUID {
        guard let raw = value as? String, let id = UUID(uuidString: raw) else {
            throw error(path, "must be a UUID")
        }
        return id
    }

    private func number(_ value: Any?, _ path: String) throws -> Double {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(),
              number.doubleValue.isFinite else { throw error(path, "must be a finite number") }
        return number.doubleValue
    }

    private func boundedNumber(_ value: Any?, _ range: ClosedRange<Double>, _ path: String) throws {
        try require(range.contains(number(value, path)), path, "must be within \(range)")
    }

    private func keys(_ value: [String: Any], allowed: Set<String>, path: String) throws {
        if let unknown = value.keys.first(where: { !allowed.contains($0) }) {
            throw error(path + "." + unknown, "unknown property")
        }
    }

    private func require(_ valid: Bool, _ path: String, _ reason: String) throws {
        if !valid { throw error(path, reason) }
    }

    private func error(_ path: String, _ reason: String) -> FPLNavDecoderError {
        .invalidV9Document(path + ": " + reason)
    }
}
