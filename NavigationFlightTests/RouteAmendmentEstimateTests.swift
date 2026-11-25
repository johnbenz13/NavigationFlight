import Testing
@testable import NavigationFlight

@Suite("Route amendment estimate and value entry")
struct RouteAmendmentEstimateTests {
    private static let calm = Wind(directionFromTrue: .init(value: 0), speed: .init(value: 0))
    private static let crosswind = Wind(directionFromTrue: .init(value: 90), speed: .init(value: 45))

    // Representative v7 editor fixture. Its endpoints are one nautical mile apart on a northbound track.
    @Test(arguments: [
        (NavigationMode.noWind, Optional<Wind>.none, 355.0, 40, RouteAmendmentEstimator.Result.Provenance.noWind),
        (.wind, calm, 355.0, 40, .plannedWind(calm)),
        (.wind, crosswind, 25.0, 46, .plannedWind(crosswind))
    ])
    func editorTimingAndDirection(
        mode: NavigationMode, wind: Wind?, heading: Double, seconds: Int,
        provenance: RouteAmendmentEstimator.Result.Provenance
    ) {
        let result = estimate(mode: mode, wind: wind)
        guard case .available(let direction, let duration, let source) = result else {
            Issue.record("Expected an available estimate")
            return
        }
        #expect(abs(direction.value - heading) < 0.000000001)
        #expect(duration == seconds)
        #expect(source == provenance)
    }

    @Test(arguments: [
        Optional<Wind>.none,
        Wind(directionFromTrue: .init(value: 360), speed: .init(value: 0)),
        Wind(directionFromTrue: .init(value: 90), speed: .init(value: 90)),
        Wind(directionFromTrue: .init(value: 0), speed: .init(value: 100))
    ])
    func unavailablePlannedWind(_ wind: Wind?) {
        #expect(estimate(mode: .wind, wind: wind) == .unavailable)
    }

    @Test func unavailableWithoutPositiveDurationOrAirspeed() {
        #expect(estimate(mode: .noWind, wind: nil, airspeed: 0) == .unavailable)
        #expect(estimate(mode: .noWind, wind: nil, airspeed: 1_000_000) == .unavailable)
    }

    @Test(arguments: ["", "0", "00:00", "0:60", "-1:30", "1:-5", "999999999999999999999:01"])
    func rejectsInvalidTime(_ value: String) {
        var entry = RouteAmendmentLegEntry()
        entry.heading = "087"
        entry.duration = value
        #expect(entry.invalidFields == [.duration])
        #expect(entry.values == nil)
    }

    @Test func acceptsPilotValuesAndUntimedCues() throws {
        var entry = RouteAmendmentLegEntry()
        entry.heading = "087"
        entry.duration = "0320"
        entry.altitude = "2500"
        entry.frequency = "123"
        entry.visualReference = "  Look for the junction.  "
        let values = try #require(entry.values)
        #expect(values.headingMagnetic == 87)
        #expect(values.durationSeconds == 200)
        #expect(values.altitude?.value == 2500)
        #expect(values.frequency?.value == 123)
        #expect(values.visualReference == "Look for the junction.")
        #expect(RouteAmendmentLegEntry(values: values).values == values)
    }

    @Test func legacyCompleteValuesRemainLosslessWhileOtherFieldsChange() {
        let values = RouteAmendmentLegValues(
            headingMagnetic: 176, durationSeconds: 3901,
            altitude: .init(value: 2500.123456789), frequency: .init(value: 122.123456789),
            visualReference: "  Keep legacy spacing  "
        )
        var entry = RouteAmendmentLegEntry(values: values)
        #expect(entry.values == values)
        entry[.heading] = "087"
        #expect(entry.values?.altitude == values.altitude)
        #expect(entry.values?.frequency == values.frequency)
        #expect(entry.values?.visualReference == values.visualReference)
        #expect(entry.values?.durationSeconds == 3901)
        entry[.heading] = ""
        #expect(entry.values == nil)
        #expect(entry.durationSeconds == 3901)
        entry[.heading] = "176"
        #expect(entry.values == values)
        entry[.altitude] = ""
        #expect(entry.values?.altitude == nil)
        #expect(entry.values?.frequency == values.frequency)
    }

    @Test func headingEntryRejectsOutOfRangeEditsAndWrapsAtNorth() {
        var entry = RouteAmendmentLegEntry()
        entry[.heading] = "00"
        #expect(entry.magneticHeading == nil)
        #expect(entry.finalizedText(for: .heading).isEmpty)
        entry[.heading] = "000"
        #expect(entry.heading == "00")
        entry[.heading] = "001"
        entry[.heading] = "435"
        entry[.heading] = "36x"
        #expect(entry.heading == "001")
        entry.adjustHeading(by: -1)
        #expect(entry.heading == "360")
        entry.adjustHeading(by: 1)
        #expect(entry.heading == "001")
    }

    @Test func secondsEntryRejectsOutOfRangeEditsAndPadsSingleDigits() {
        var entry = RouteAmendmentLegEntry()
        entry[.seconds] = "7"
        entry[.seconds] = "78"
        #expect(entry.seconds == "7")
        #expect(entry.finalizedText(for: .seconds) == "07")
        entry[.seconds] = "00"
        #expect(entry.seconds == "00")
        entry[.seconds] = "59"
        entry[.seconds] = "60"
        entry[.seconds] = "123"
        #expect(entry.seconds == "59")
    }

    @Test func timeStepsRetainExactSecondsAndStayPositive() {
        var entry = RouteAmendmentLegEntry()
        entry.adjustFlightTime(by: -5)
        #expect(entry.duration.isEmpty)
        entry.minutes = "05"
        entry.seconds = "13"
        entry.adjustFlightTime(by: 5)
        #expect(entry.durationSeconds == 318)
        entry.adjustFlightTime(by: -5)
        #expect(entry.durationSeconds == 313)
        entry.minutes = "00"
        entry.seconds = "03"
        entry.adjustFlightTime(by: -5)
        #expect(entry.durationSeconds == 3)
    }

    @Test(arguments: [-1500, -1400, 0, 2500, 20000])
    func altitudeWheelSupportsNegativeAndBoundaryValues(_ altitude: Int) {
        var entry = RouteAmendmentLegEntry()
        entry.selectCue(.altitude, choice: .value(altitude))
        #expect(entry.altitude == String(altitude))
        #expect(entry.cueSelection(.altitude) == .value(altitude))
        entry.selectCue(.altitude, choice: .notSet)
        #expect(entry.altitude.isEmpty)
    }

    @Test(arguments: [-1600, 2550, 20100, Int.max])
    func altitudeWheelRejectsInvalidNewValues(_ altitude: Int) {
        var entry = RouteAmendmentLegEntry()
        entry.selectCue(.altitude, choice: .value(2500))
        entry.selectCue(.altitude, choice: .value(altitude))
        #expect(entry.altitude == "2500")
    }

    @Test(arguments: [-1550.0, 2550.0, 25000.0, 2500.123456789])
    func inheritedCustomAltitudeRemainsLossless(_ altitude: Double) {
        let original = RouteAmendmentLegValues(
            headingMagnetic: 176, durationSeconds: 135, altitude: .init(value: altitude),
            frequency: .init(value: 122.525), visualReference: "Road junction"
        )
        var entry = RouteAmendmentLegEntry(values: original)
        #expect(entry.cueSelection(.altitude) == .custom)
        #expect(entry.values == original)
        entry[.heading] = "087"
        entry.selectCue(.frequencyMHz, choice: .notSet)
        #expect(entry.values?.altitude == original.altitude)
        entry.selectCue(.altitude, choice: .value(2500))
        #expect(entry.values?.altitude?.value == 2500)
    }

    @Test func radioWheelsOnlyConstructValidChannels() {
        var entry = RouteAmendmentLegEntry()
        for mhz in 118...136 {
            for fraction in stride(from: 0, through: 975, by: 25) {
                entry.selectCue(.frequencyMHz, choice: .value(mhz))
                entry.selectCue(.frequencyFraction, choice: .value(fraction))
                #expect(entry.radioChannelKHz == mhz * 1000 + fraction)
            }
        }
        #expect(entry.frequency == "136.975")
        entry.selectCue(.frequencyMHz, choice: .value(118))
        entry.selectCue(.frequencyFraction, choice: .value(0))
        #expect(entry.frequency == "118.000")
        let before = entry
        entry.selectCue(.frequencyMHz, choice: .value(137))
        entry.selectCue(.frequencyFraction, choice: .value(5))
        #expect(entry == before)
    }

    @Test(arguments: ["122.52500000001", "117.975", "137", "122.50833", "122.123456789"])
    func customRadioIsNeverRoundedOnPresentation(_ frequency: String) {
        var entry = RouteAmendmentLegEntry()
        entry.frequency = frequency
        let before = entry
        #expect(entry.cueSelection(.frequencyMHz) == .custom)
        #expect(entry.cueSelection(.frequencyFraction) == .custom)
        #expect(entry == before)
        entry.selectCue(.frequencyFraction, choice: .value(525))
        #expect(entry.frequency == "118.525")
    }

    @Test(arguments: [122.52500000001, 117.975, 122.123456789])
    func inheritedRadioPresentationDoesNotUseRoundedAdapterText(_ frequency: Double) {
        let original = RouteAmendmentLegValues(
            headingMagnetic: 176, durationSeconds: 135, altitude: .init(value: 2500.123456789),
            frequency: .init(value: frequency), visualReference: nil
        )
        let entry = RouteAmendmentLegEntry(values: original)
        #expect(entry.cueSelection(.frequencyMHz) == .custom)
        #expect(entry.cueDisplayText(.frequencyMHz) == String(frequency))
        #expect(entry.cueDisplayText(.altitude) == "2500.123456789")
        #expect(entry.values == original)
    }

    @Test func cueClearsAndEditsPreserveOtherFieldsAndAcceptedPrecision() throws {
        let original = RouteAmendmentLegValues(
            headingMagnetic: 176, durationSeconds: 135,
            altitude: .init(value: 2550), frequency: .init(value: 122.123456789),
            visualReference: "  Road junction  "
        )
        var entry = RouteAmendmentLegEntry(values: original)
        #expect(entry.cueSelection(.altitude) == .custom)
        #expect(entry.values == original)
        entry.selectCue(.altitude, choice: .notSet)
        #expect(entry.values?.frequency == original.frequency)
        #expect(entry.values?.visualReference == original.visualReference)
        entry.selectCue(.altitude, choice: .value(-1500))
        #expect(entry.values?.altitude?.value == -1500)
        entry.selectCue(.frequencyMHz, choice: .notSet)
        #expect(entry.values?.altitude?.value == -1500)
        entry[.visualReference] = ""
        let result = try #require(entry.values)
        #expect(result.headingMagnetic == 176)
        #expect(result.durationSeconds == 135)
        #expect(result.frequency == nil)
        #expect(result.visualReference == nil)
    }

    @Test func deliberateCueChoiceReplacesCustomValueEvenWhenAdapterTextIsIdentical() {
        let original = RouteAmendmentLegValues(
            headingMagnetic: 176, durationSeconds: 135, altitude: .init(value: 2500.00000001),
            frequency: .init(value: 122.52500000001), visualReference: nil
        )
        var entry = RouteAmendmentLegEntry(values: original)
        #expect(entry.cueSelection(.altitude) == .custom)
        entry.selectCue(.altitude, choice: .value(2500))
        #expect(entry.cueSelection(.altitude) == .value(2500))
        #expect(entry.values?.altitude?.value == 2500)
        #expect(entry.values?.frequency == original.frequency)
        entry.selectCue(.frequencyMHz, choice: .value(122))
        entry.selectCue(.frequencyFraction, choice: .value(525))
        #expect(entry.cueSelection(.frequencyFraction) == .value(525))
        #expect(entry.values?.frequency?.value == 122.525)
    }

    private func estimate(mode: NavigationMode, wind: Wind?, airspeed: Double = 90) -> RouteAmendmentEstimator.Result {
        RouteAmendmentEstimator.estimate(
            from: .init(latitudeDegrees: 0, longitudeDegrees: 0),
            to: .init(latitudeDegrees: 0.016655413136178444, longitudeDegrees: 0),
            inputs: .init(mode: mode, magneticVariationEast: .init(value: 5),
                          planningAirspeed: .init(value: airspeed), defaultWind: wind)
        )
    }
}
