import Testing
@testable import NavigationFlight

@Suite("Cockpit activity indicator")
struct CockpitActivityIndicatorTests {
    @Test(
        "Recording status maps to the approved shell indicator",
        arguments: [
            (RecordingStatus.ready, false, CockpitActivityIndicator.none),
            (.prepared, true, .none),
            (.recording, true, .active),
            (.recording, false, .none),
            (.gpsResumed, true, .active),
            (.navigationCompleteRecordingContinues, false, .active),
            (.landedAwaitingStop, false, .active),
            (.partialRecording, true, .warning),
            (.gpsGap, true, .warning),
            (.recordingGPSUnavailable, true, .warning),
            (.recordingDegraded, true, .warning),
            (.recordingLowStorage, true, .warning),
            (.physicalPhaseCorrected, true, .warning),
            (.closedComplete, true, .none),
            (.closedIncomplete, true, .none),
        ]
    )
    func mapping(
        status: RecordingStatus,
        isNavigationActive: Bool,
        expected: CockpitActivityIndicator
    ) {
        #expect(
            CockpitActivityIndicator(
                isNavigationActive: isNavigationActive,
                recordingStatus: status
            ) == expected
        )
    }
}
