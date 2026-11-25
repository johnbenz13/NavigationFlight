import Foundation

nonisolated enum RouteAmendmentMode: String, CaseIterable, Sendable, Codable {
    case manual
    case assisted
}

nonisolated struct RouteAmendmentLegValues: Equatable, Sendable {
    let headingMagnetic: Int
    let durationSeconds: Int
    let altitude: AltitudeFeet?
    let frequency: FrequencyMHz?
    let visualReference: String?

    var headingText: String {
        String(format: "%03d", headingMagnetic == 0 ? 360 : headingMagnetic)
    }
}

nonisolated struct RouteAmendmentLegEntry: Equatable, Sendable {
    enum TimeComponent: String, CaseIterable, Sendable {
        case minutes, seconds
    }

    enum Field: String, Sendable {
        case heading, duration, minutes, seconds, altitude, frequency, visualReference
    }

    var heading = ""
    var minutes = ""
    var seconds = ""

    var duration: String {
        get { minutes.isEmpty && seconds.isEmpty ? "" : "\(minutes):\(seconds)" }
        set {
            let parts = newValue.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            if parts.count == 2 {
                minutes = String(parts[0])
                seconds = String(parts[1])
            } else {
                minutes = String(newValue.dropLast(2))
                seconds = String(newValue.suffix(2))
            }
        }
    }
    var altitude = ""
    var frequency = ""
    var visualReference = ""
    // Preserve accepted boundary values exactly, including legacy cue precision/spacing.
    private var acceptedValues: RouteAmendmentLegValues?
    private var durationWasEdited = false

    init(values: RouteAmendmentLegValues? = nil) {
        acceptedValues = values
        guard let values else { return }
        heading = values.headingText
        duration = Self.durationText(values.durationSeconds)
        altitude = values.altitude.map { $0.value.formatted(.number.grouping(.never)) } ?? ""
        frequency = values.frequency.map { $0.value.formatted(.number.grouping(.never)) } ?? ""
        visualReference = values.visualReference ?? ""
    }

    subscript(field: Field) -> String {
        get {
            switch field {
            case .heading: heading
            case .duration: duration
            case .minutes: minutes
            case .seconds: seconds
            case .altitude: altitude
            case .frequency: frequency
            case .visualReference: visualReference
            }
        }
        set {
            guard allowsInput(newValue, for: field) else { return }
            switch field {
            case .heading: heading = newValue
            case .duration:
                durationWasEdited = true
                duration = newValue
            case .minutes:
                durationWasEdited = true
                minutes = newValue
            case .seconds:
                durationWasEdited = true
                seconds = newValue
            case .altitude: altitude = newValue
            case .frequency: frequency = newValue
            case .visualReference: visualReference = newValue
            }
        }
    }

    var invalidFields: Set<Field> {
        var invalid = Set<Field>()
        if magneticHeading == nil { invalid.insert(.heading) }
        if durationSeconds == nil { invalid.insert(.duration) }
        if !trimmed(altitude).isEmpty, decimal(altitude) == nil { invalid.insert(.altitude) }
        if !trimmed(frequency).isEmpty, frequencyMHz == nil { invalid.insert(.frequency) }
        return invalid
    }

    /// Missing required fields are permitted in a partial draft; malformed entries still need feedback.
    var invalidEnteredFields: Set<Field> {
        invalidFields.filter { !trimmed(self[$0]).isEmpty }
    }

    var values: RouteAmendmentLegValues? {
        guard let magneticHeading, let durationSeconds, invalidFields.isEmpty else { return nil }
        let original = acceptedValues.map { Self(values: $0) }
        let note = trimmed(visualReference)
        return .init(
            headingMagnetic: magneticHeading,
            durationSeconds: durationSeconds,
            altitude: altitude == original?.altitude ? acceptedValues?.altitude : decimal(altitude).map(AltitudeFeet.init(value:)),
            frequency: frequency == original?.frequency ? acceptedValues?.frequency : frequencyMHz.map(FrequencyMHz.init(value:)),
            visualReference: visualReference == original?.visualReference ? acceptedValues?.visualReference : note.isEmpty ? nil : note
        )
    }

    static func durationText(_ seconds: Int) -> String {
        let minutes = seconds / 60
        return "\(minutes < 10 ? "0" : "")\(minutes):\(String(format: "%02d", seconds % 60))"
    }

    var magneticHeading: Int? {
        guard let value = integer(heading), (1...360).contains(value) else { return nil }
        return value
    }

    var durationSeconds: Int? {
        guard !minutes.isEmpty || !seconds.isEmpty,
              let minutes = minutes.isEmpty ? 0 : integer(minutes),
              let seconds = seconds.isEmpty ? 0 : integer(seconds),
              (0..<60).contains(seconds), minutes <= (Int.max - seconds) / 60 else { return nil }
        let total = minutes * 60 + seconds
        guard total > 0 else { return nil }
        return total <= 3600 || preservesAcceptedDuration ? total : nil
    }

    /// Only an unchanged accepted value can cross the new preparation boundary.
    var preservesAcceptedDuration: Bool {
        guard !durationWasEdited, let acceptedValues else { return false }
        return duration == Self.durationText(acceptedValues.durationSeconds)
    }

    func timeSelection(_ component: TimeComponent) -> Int? {
        let text = component == .minutes ? minutes : seconds
        return text.isEmpty ? nil : integer(text)
    }

    func timeOptions(_ component: TimeComponent) -> ClosedRange<Int> {
        component == .minutes ? 0...60 : 0...(timeSelection(.minutes) == 60 ? 0 : 59)
    }

    /// Opening sends no intent. A deliberate first choice initializes the other
    /// component to zero; later clears preserve the independently edited component.
    mutating func selectTime(_ component: TimeComponent, value: Int?) {
        if let value, !timeOptions(component).contains(value) { return }
        let untouched = minutes.isEmpty && seconds.isEmpty
        durationWasEdited = true
        let text = value.map { String(format: "%02d", $0) } ?? ""
        switch component {
        case .minutes:
            minutes = text
            if value == 60 || (untouched && value != nil) { seconds = "00" }
        case .seconds:
            seconds = text
            if untouched && value != nil { minutes = "00" }
        }
    }

    mutating func adjustHeading(by delta: Int) {
        guard delta == 1 || delta == -1 else { return }
        let value = (magneticHeading ?? 0) + delta
        let wrapped = (value % 360 + 360) % 360
        heading = String(format: "%03d", wrapped == 0 ? 360 : wrapped)
    }

    mutating func adjustFlightTime(by delta: Int) {
        guard delta == 5 || delta == -5 else { return }
        let adjustment = (durationSeconds ?? 0).addingReportingOverflow(delta)
        guard !adjustment.overflow, (1...3600).contains(adjustment.partialValue) else { return }
        durationWasEdited = true
        duration = Self.durationText(adjustment.partialValue)
    }

    func allowsInput(_ text: String, for field: Field) -> Bool {
        guard !text.isEmpty else { return true }
        switch field {
        case .heading: return acceptsHeadingInput(text)
        case .seconds: return acceptsSecondsInput(text)
        default: return true
        }
    }

    func finalizedText(for field: Field) -> String {
        switch field {
        case .heading:
            magneticHeading.map { String(format: "%03d", $0) } ?? ""
        case .seconds:
            integer(seconds).map { String(format: "%02d", $0) } ?? ""
        default:
            self[field]
        }
    }

    private func acceptsHeadingInput(_ text: String) -> Bool {
        guard text.count <= 3, text == trimmed(text), let value = integer(text) else { return false }
        // A leading zero is needed to type headings such as 001.
        return (1...360).contains(value) || (value == 0 && text.count < 3)
    }

    private func acceptsSecondsInput(_ text: String) -> Bool {
        guard text.count <= 2, text == trimmed(text), let value = integer(text) else { return false }
        return (0...59).contains(value)
    }

    private func integer(_ text: String) -> Int? {
        let input = trimmed(text)
        let digits = input.compactMap(\.wholeNumberValue)
        guard digits.count == input.count, digits.allSatisfy({ $0 < 10 }) else { return nil }
        return Int(digits.map(String.init).joined())
    }

    private var frequencyMHz: Double? {
        guard let value = decimal(frequency), value > 0 else { return nil }
        return value
    }

    private func decimal(_ text: String) -> Double? {
        let separator = Locale.current.decimalSeparator ?? "."
        let input = trimmed(text).replacingOccurrences(of: separator, with: ".")
        let normalized = input.map { character in
            character.wholeNumberValue.map(String.init) ?? String(character)
        }.joined()
        guard normalized.allSatisfy({ "0123456789.-".contains($0) }),
              let number = Double(normalized), number.isFinite else { return nil }
        return number
    }

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
