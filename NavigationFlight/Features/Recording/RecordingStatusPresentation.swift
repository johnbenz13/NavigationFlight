import Foundation

nonisolated enum RecordingStatus: Equatable, Sendable {
    case ready
    case prepared
    case recording
    case partialRecording
    case gpsGap
    case gpsResumed
    case recordingGPSUnavailable
    case recordingDegraded
    case navigationCompleteRecordingContinues
    case landedAwaitingStop
    case physicalPhaseCorrected
    case closedComplete
    case closedIncomplete
}

nonisolated struct RecordingStatusPresentation: Equatable, Sendable {
    enum Tone: Equatable, Sendable {
        case neutral
        case caution
        case destructive
    }

    let title: LocalizedStringResource
    let compactTitle: LocalizedStringResource
    let detail: LocalizedStringResource
    let systemImage: String
    let tone: Tone
    let showsEndRecordingAction: Bool

    init(status: RecordingStatus) {
        switch status {
        case .ready:
            title = "Ready to record"
            compactTitle = "Ready"
            detail = "Recording begins when Start Leg is committed."
            systemImage = "record.circle"
            tone = .neutral
            showsEndRecordingAction = false
        case .prepared:
            title = "Prepared · Sensing"
            compactTitle = "PREPARED"
            detail = "Location is monitored and recent samples are held for up to two minutes. Position remains hidden."
            systemImage = "location.circle"
            tone = .caution
            showsEndRecordingAction = false
        case .recording:
            title = "Recording"
            compactTitle = "RECORDING"
            detail = "GPS track samples are being saved without displaying the aircraft position."
            systemImage = "record.circle.fill"
            tone = .neutral
            showsEndRecordingAction = true
        case .partialRecording:
            title = "Partial Recording"
            compactTitle = "REC · PARTIAL"
            detail = "Recording began after airborne movement was detected. Earlier track history is unavailable."
            systemImage = "exclamationmark.circle.fill"
            tone = .caution
            showsEndRecordingAction = true
        case .gpsGap:
            title = "Recording · GPS Gap"
            compactTitle = "REC · GPS GAP"
            detail = "Recording continues, but GPS samples are temporarily unavailable. The gap is not interpolated."
            systemImage = "location.slash.fill"
            tone = .caution
            showsEndRecordingAction = true
        case .gpsResumed:
            title = "Recording · GPS Resumed"
            compactTitle = "REC · GPS RESUMED"
            detail = "Fresh GPS samples are being saved in a new track segment."
            systemImage = "location.fill"
            tone = .neutral
            showsEndRecordingAction = true
        case .recordingGPSUnavailable:
            title = "Recording · No GPS"
            compactTitle = "REC · NO GPS"
            detail = "Navigation actions are recorded without coordinates or a GPS track."
            systemImage = "location.slash.fill"
            tone = .caution
            showsEndRecordingAction = true
        case .recordingDegraded:
            title = "Recording May Be Incomplete"
            compactTitle = "REC · WARNING"
            detail = "Some track data could not be saved. Navigation actions remain available."
            systemImage = "exclamationmark.triangle.fill"
            tone = .caution
            showsEndRecordingAction = true
        case .navigationCompleteRecordingContinues:
            title = "Navigation Complete · Recording Continues"
            compactTitle = "NAV COMPLETE · REC"
            detail = "Navigation is complete. End the action-only recording when the Flight is over."
            systemImage = "checkmark.circle.fill"
            tone = .neutral
            showsEndRecordingAction = true
        case .landedAwaitingStop:
            title = "Landed · Awaiting Stop"
            compactTitle = "LANDED · REC"
            detail = "Landing was detected. Recording continues until a sustained stop is confirmed."
            systemImage = "airplane.arrival"
            tone = .neutral
            showsEndRecordingAction = true
        case .physicalPhaseCorrected:
            title = "Recording · Phase Corrected"
            compactTitle = "REC · CORRECTED"
            detail = "New sustained evidence corrected the detected flight phase without changing recorded history."
            systemImage = "arrow.trianglehead.2.clockwise.rotate.90"
            tone = .caution
            showsEndRecordingAction = true
        case .closedComplete:
            title = "Recording ended · Complete"
            compactTitle = "Ended · Complete"
            detail = "Navigation and physical flight recording completed."
            systemImage = "checkmark.circle.fill"
            tone = .neutral
            showsEndRecordingAction = false
        case .closedIncomplete:
            title = "Recording ended · Incomplete"
            compactTitle = "Ended · Incomplete"
            detail = "The recording ended before navigation was completed."
            systemImage = "exclamationmark.circle.fill"
            tone = .destructive
            showsEndRecordingAction = false
        }
    }
}
