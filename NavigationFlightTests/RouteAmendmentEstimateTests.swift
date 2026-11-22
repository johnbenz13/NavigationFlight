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

    private func estimate(mode: NavigationMode, wind: Wind?, airspeed: Double = 90) -> RouteAmendmentEstimator.Result {
        RouteAmendmentEstimator.estimate(
            from: .init(latitudeDegrees: 0, longitudeDegrees: 0),
            to: .init(latitudeDegrees: 0.016655413136178444, longitudeDegrees: 0),
            inputs: .init(mode: mode, magneticVariationEast: .init(value: 5),
                          planningAirspeed: .init(value: airspeed), defaultWind: wind)
        )
    }
}
