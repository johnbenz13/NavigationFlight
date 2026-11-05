import Foundation

struct FlightsFeatureState: Equatable, Sendable {
    private(set) var rows: [FlightRecordingSummary] = []
    private(set) var inFlightRequestID: UUID?
    private(set) var pendingDeletionID: UUID?
    private(set) var deletionFailureID: UUID?

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

    mutating func requestDeletion(of id: UUID) {
        guard rows.contains(where: { $0.id == id && $0.canDelete }) else { return }
        pendingDeletionID = id
        deletionFailureID = nil
    }

    mutating func cancelDeletion() {
        pendingDeletionID = nil
    }

    @discardableResult
    mutating func completeDeletion(id: UUID) -> Bool {
        guard pendingDeletionID == id else { return false }
        rows.removeAll { $0.id == id }
        pendingDeletionID = nil
        deletionFailureID = nil
        return true
    }

    mutating func failDeletion(id: UUID) {
        guard pendingDeletionID == id else { return }
        pendingDeletionID = nil
        deletionFailureID = id
    }

    mutating func retryFailedDeletion() {
        guard let deletionFailureID else { return }
        requestDeletion(of: deletionFailureID)
    }

    mutating func dismissDeletionFailure() {
        deletionFailureID = nil
    }
}
