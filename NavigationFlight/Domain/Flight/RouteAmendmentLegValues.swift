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
    var estimateProvenance: RouteAmendmentLegEntry.EstimateProvenance? = nil

    var headingText: String {
        String(format: "%03d", headingMagnetic == 0 ? 360 : headingMagnetic)
    }
}

nonisolated struct RouteAmendmentLegEntry: Equatable, Sendable {
    struct EstimateProvenance: Codable, Equatable, Sendable {
        enum Source: String, Codable, Sendable { case noWind, plannedWind, unavailable }
        var source: Source
        var headingOverridden = false
        var durationOverridden = false
        var geometryUpdated = false
    }

    private(set) var estimateProvenance: EstimateProvenance?

    var estimateStatus: String? {
        guard let provenance = estimateProvenance else { return nil }
        if provenance.geometryUpdated { return "Estimates updated" }
        if provenance.headingOverridden && provenance.durationOverridden { return "Heading and time edited" }
        if provenance.headingOverridden { return "Heading edited" }
        if provenance.durationOverridden { return "Time edited" }
        switch provenance.source {
        case .noWind: return "Estimates · no wind"
        case .plannedWind: return "Estimates · planned wind"
        case .unavailable: return "Estimates unavailable · enter values"
        }
    }

    /// Called once for newly formed/changed geometry. Reopening, Check and Undo
    /// never invoke this path, so accepted overrides retain their exact values.
    mutating func prefill(_ result: RouteAmendmentEstimator.Result, geometryUpdated: Bool) {
        heading = ""
        minutes = ""
        seconds = ""
        durationWasEdited = true
        switch result {
        case .available(let direction, let duration, let source):
            let degrees = Int(direction.value.rounded()) % 360
            heading = String(format: "%03d", degrees == 0 ? 360 : degrees)
            // New estimates obey the preparation time range. Never wrap or clamp
            // an out-of-range estimate into a plausible pilot duration.
            if (1..<3600).contains(duration) { self.duration = Self.durationText(duration) }
            estimateProvenance = .init(source: source == .noWind ? .noWind : .plannedWind,
                                       geometryUpdated: geometryUpdated)
        case .unavailable:
            estimateProvenance = .init(source: .unavailable, geometryUpdated: geometryUpdated)
        }
    }

    enum TimeComponent: String, CaseIterable, Sendable {
        case minutes, seconds
    }

    enum CueComponent: String, CaseIterable, Sendable {
        case altitude, frequencyMHz, frequencyFraction
    }

    enum CueChoice: Hashable, Sendable {
        case notSet, custom, value(Int)
    }

    static let altitudeOptions = Array(stride(from: -1500, through: 20000, by: 100))
    static let radioMHzOptions = Array(118...136)
    static let radioFractionOptions = Array(stride(from: 0, through: 975, by: 25))

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
    private var altitudeWasEdited = false
    private var frequencyWasEdited = false

    init(values: RouteAmendmentLegValues? = nil) {
        acceptedValues = values
        estimateProvenance = values?.estimateProvenance
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
            markOverride(field)
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
            altitude: !altitudeWasEdited && altitude == original?.altitude ? acceptedValues?.altitude : decimal(altitude).map(AltitudeFeet.init(value:)),
            frequency: !frequencyWasEdited && frequency == original?.frequency ? acceptedValues?.frequency : frequencyMHz.map(FrequencyMHz.init(value:)),
            visualReference: visualReference == original?.visualReference ? acceptedValues?.visualReference : note.isEmpty ? nil : note,
            estimateProvenance: estimateProvenance
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
        return total < 3600 || preservesAcceptedDuration ? total : nil
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
        0...59
    }

    /// Opening sends no intent. A deliberate first choice initializes the other
    /// component to zero; later clears preserve the independently edited component.
    mutating func selectTime(_ component: TimeComponent, value: Int?) {
        if let value, !timeOptions(component).contains(value) { return }
        markOverride(.duration)
        let untouched = minutes.isEmpty && seconds.isEmpty
        durationWasEdited = true
        let text = value.map { String(format: "%02d", $0) } ?? ""
        switch component {
        case .minutes:
            minutes = text
            if untouched && value != nil { seconds = "00" }
        case .seconds:
            seconds = text
            if untouched && value != nil { minutes = "00" }
        }
    }

    /// Physical wheel deltas retain direction across the cyclic boundary.
    /// Missing components remain missing after independent clearing.
    mutating func advanceTime(_ component: TimeComponent, steps: Int) {
        guard steps != 0 else { return }
        // Unset sits outside the numeric cycle: forward starts at 00, backward at 59.
        guard let old = timeSelection(component) else {
            let first = steps > 0 ? steps - 1 : steps
            selectTime(component, value: ((first % 60) + 60) % 60)
            return
        }
        let untouched = minutes.isEmpty && seconds.isEmpty
        let sum = old % 60 + steps % 3600
        let value = ((sum % 60) + 60) % 60
        let carry = (sum - value) / 60
        selectTime(component, value: value)
        if component == .seconds, !untouched, let minute = timeSelection(.minutes) {
            minutes = String(format: "%02d", ((minute % 60 + carry % 60) % 60 + 60) % 60)
        }
    }

    /// Integer kHz identifies a 25 kHz channel; conversion never rounds custom input.
    var radioChannelKHz: Int? {
        guard let value = originalCueValue(.frequencyMHz) ?? decimal(frequency) else { return nil }
        let scaled = value * 1000
        guard (118000...136975).contains(scaled),
              Double(Int(scaled.rounded())) / 1000 == value else { return nil }
        let channel = Int(scaled.rounded())
        return channel % 25 == 0 ? channel : nil
    }

    func cueOptions(_ component: CueComponent) -> [Int] {
        switch component {
        case .altitude: Self.altitudeOptions
        case .frequencyMHz: Self.radioMHzOptions
        case .frequencyFraction: Self.radioFractionOptions
        }
    }

    func cueSelection(_ component: CueComponent) -> CueChoice {
        switch component {
        case .altitude:
            guard !trimmed(altitude).isEmpty else { return .notSet }
            guard let value = originalCueValue(.altitude) ?? decimal(altitude), Self.altitudeOptions.contains(where: { Double($0) == value }) else {
                return .custom
            }
            return .value(Int(value))
        case .frequencyMHz, .frequencyFraction:
            guard !trimmed(frequency).isEmpty else { return .notSet }
            guard let channel = radioChannelKHz else { return .custom }
            return .value(component == .frequencyMHz ? channel / 1000 : channel % 1000)
        }
    }

    /// The legacy text adapter may format fewer digits than the accepted Double.
    /// Classification and custom presentation must consult the original value too.
    func cueDisplayText(_ component: CueComponent) -> String {
        originalCueValue(component).map { String($0) }
            ?? (component == .altitude ? altitude : frequency)
    }

    private func originalCueValue(_ component: CueComponent) -> Double? {
        guard let acceptedValues else { return nil }
        let original = Self(values: acceptedValues)
        if component == .altitude {
            guard !altitudeWasEdited else { return nil }
            return altitude == original.altitude ? acceptedValues.altitude?.value : nil
        }
        guard !frequencyWasEdited else { return nil }
        return frequency == original.frequency ? acceptedValues.frequency?.value : nil
    }

    mutating func selectCue(_ component: CueComponent, choice: CueChoice) {
        switch choice {
        case .custom: return
        case .notSet:
            if component == .altitude {
                altitudeWasEdited = true
                altitude = ""
            } else {
                frequencyWasEdited = true
                frequency = ""
            }
        case .value(let value):
            guard cueOptions(component).contains(value) else { return }
            if component == .altitude {
                altitudeWasEdited = true
                altitude = String(value)
            } else {
                // A deliberate edit of a custom/unset radio starts a valid channel;
                // the other wheel contributes zero fractional kHz or the lower MHz endpoint.
                let previous = radioChannelKHz ?? 118000
                let channel = component == .frequencyMHz
                    ? value * 1000 + previous % 1000
                    : previous / 1000 * 1000 + value
                frequencyWasEdited = true
                frequency = String(format: "%d.%03d", channel / 1000, channel % 1000)
            }
        }
    }

    mutating func adjustHeading(by delta: Int) {
        guard delta == 1 || delta == -1 else { return }
        markOverride(.heading)
        let value = (magneticHeading ?? 0) + delta
        let wrapped = (value % 360 + 360) % 360
        heading = String(format: "%03d", wrapped == 0 ? 360 : wrapped)
    }

    mutating func adjustFlightTime(by delta: Int) {
        guard delta == 5 || delta == -5 else { return }
        let adjustment = (durationSeconds ?? 0).addingReportingOverflow(delta)
        guard !adjustment.overflow, (1...3600).contains(adjustment.partialValue) else { return }
        markOverride(.duration)
        durationWasEdited = true
        duration = Self.durationText(adjustment.partialValue)
    }

    private mutating func markOverride(_ field: Field) {
        guard estimateProvenance != nil else { return }
        switch field {
        case .heading: estimateProvenance?.headingOverridden = true
        case .duration, .minutes, .seconds: estimateProvenance?.durationOverridden = true
        default: return
        }
        estimateProvenance?.geometryUpdated = false
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
