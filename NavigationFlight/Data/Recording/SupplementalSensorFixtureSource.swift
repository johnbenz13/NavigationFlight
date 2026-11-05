import Foundation

@MainActor
final class SupplementalSensorFixtureSource: SupplementalSensorSource {
    enum FixtureError: Error {
        case failed
    }

    private let events: [SupplementalSensorEvent]
    private let shouldFail: Bool

    init(events: [SupplementalSensorEvent], shouldFail: Bool = false) {
        self.events = events
        self.shouldFail = shouldFail
    }

    func updates() -> AsyncThrowingStream<SupplementalSensorEvent, Error> {
        let (stream, continuation) = AsyncThrowingStream.makeStream(
            of: SupplementalSensorEvent.self,
            bufferingPolicy: .bufferingNewest(max(1, events.count))
        )
        for event in events {
            continuation.yield(event)
        }
        shouldFail ? continuation.finish(throwing: FixtureError.failed) : continuation.finish()
        return stream
    }
}
