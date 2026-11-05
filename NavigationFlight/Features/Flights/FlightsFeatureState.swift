import Foundation

struct FlightsFeatureState: Equatable, Sendable {
    private(set) var rows: [FlightRecordingSummary] = []
    private(set) var inFlightRequestID: UUID?

    var isLoading: Bool {
        inFlightRequestID != nil
    }

    mutating func beginLoading(requestID: UUID) {
        inFlightRequestID = requestID
    }

    @discardableResult
    mutating func completeLoading(
        requestID: UUID,
        rows: [FlightRecordingSummary]
    ) -> Bool {
        guard inFlightRequestID == requestID else { return false }
        self.rows = rows
        inFlightRequestID = nil
        return true
    }
}
