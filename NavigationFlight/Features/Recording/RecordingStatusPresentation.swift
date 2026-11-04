import Foundation

nonisolated enum RecordingStatus: Equatable, Sendable {
    case ready
    case recordingGPSUnavailable
    case recordingDegraded
    case navigationCompleteRecordingContinues
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
        case .closedComplete:
            title = "Recording ended · Complete"
            compactTitle = "Ended · Complete"
            detail = "Navigation was completed before the action-only recording ended."
            systemImage = "checkmark.circle.fill"
            tone = .neutral
            showsEndRecordingAction = false
        case .closedIncomplete:
            title = "Recording ended · Incomplete"
            compactTitle = "Ended · Incomplete"
            detail = "The action-only recording was ended manually."
            systemImage = "exclamationmark.circle.fill"
            tone = .destructive
            showsEndRecordingAction = false
        }
    }
}
