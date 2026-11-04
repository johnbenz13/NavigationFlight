import Foundation

actor AircraftLocationService {
    enum MonitoringScope: Hashable, Sendable {
        case positionCheck
        case recording
    }

    private let source: any AircraftLocationSource
    private let qualityPolicy: PositionCheckQualityPolicy
    private var acquisitionTask: Task<Void, Never>?
    private var acquisitionID: UUID?
    private var continuations: [UUID: AsyncStream<LocationAvailability>.Continuation] = [:]
    private var recordingContinuations: [UUID: AsyncStream<LocationSourceEvent>.Continuation] = [:]
    private var monitoringScopes: Set<MonitoringScope> = []
    private var lastAcceptedObservation: Date?
    private(set) var availability: LocationAvailability = .acquiring

    init(
        source: any AircraftLocationSource,
        qualityPolicy: PositionCheckQualityPolicy = PositionCheckQualityPolicy()
    ) {
        self.source = source
        self.qualityPolicy = qualityPolicy
    }

    func startMonitoring() async {
        await startMonitoring(scope: .positionCheck)
    }

    func startMonitoring(scope: MonitoringScope) async {
        monitoringScopes.insert(scope)
        if scope == .recording {
            await source.beginRecordingActivity()
        }
        guard acquisitionTask == nil else { return }
        publish(.acquiring)
        let acquisitionID = UUID()
        self.acquisitionID = acquisitionID
        acquisitionTask = Task { [source] in
            do {
                for try await event in source.updates() {
                    if Task.isCancelled { return }
                    consume(event)
                }
                finishAcquisition(id: acquisitionID)
            } catch is CancellationError {
                return
            } catch {
                consumeFailure(id: acquisitionID)
            }
        }
    }

    func stopMonitoring() async {
        await stopMonitoring(scope: .positionCheck)
    }

    func stopMonitoring(scope: MonitoringScope) async {
        monitoringScopes.remove(scope)
        if scope == .recording {
            await source.endRecordingActivity()
        }
        guard monitoringScopes.isEmpty else { return }
        acquisitionTask?.cancel()
        acquisitionTask = nil
        acquisitionID = nil
        lastAcceptedObservation = nil
    }

    func requestWhenInUseAuthorization() async {
        await source.requestWhenInUseAuthorization()
    }

    func availabilityUpdates() -> AsyncStream<LocationAvailability> {
        let id = UUID()
        return AsyncStream { continuation in
            continuations[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeContinuation(id) }
            }
        }
    }

    func recordingUpdates() -> AsyncStream<LocationSourceEvent> {
        let id = UUID()
        let (stream, continuation) = AsyncStream.makeStream(
            of: LocationSourceEvent.self,
            bufferingPolicy: .bufferingNewest(256)
        )
        recordingContinuations[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeRecordingContinuation(id) }
        }
        return stream
    }

    private func consume(_ event: LocationSourceEvent) {
        recordingContinuations.values.forEach { $0.yield(event) }
        switch event {
        case .authorization(.notDetermined):
            publish(.permissionRequired(.notDetermined))
        case .authorization(.denied):
            publish(.permissionRequired(.denied))
        case .authorization(.restricted):
            publish(.permissionRequired(.restricted))
        case .authorization(.whenInUse):
            publish(.acquiring)
        case .servicesDisabled:
            publish(.unavailable(.servicesDisabled))
        case .signalLost:
            publish(.unavailable(.signalLost))
        case .sample(let sample, let receivedAt):
            let quality = qualityPolicy.classify(
                sample,
                receivedAt: receivedAt,
                lastAcceptedObservation: lastAcceptedObservation
            )
            switch quality.position {
            case .eligible:
                lastAcceptedObservation = sample.observedAt
                publish(.ready(sample))
            case .ineligible(let reason):
                publish(.unavailable(reason.locationReason))
            }
        }
    }

    private func consumeFailure(id: UUID) {
        guard acquisitionID == id else { return }
        acquisitionTask = nil
        acquisitionID = nil
        publish(.unavailable(.sourceFailure))
    }

    private func finishAcquisition(id: UUID) {
        guard acquisitionID == id else { return }
        acquisitionTask = nil
        acquisitionID = nil
    }

    private func publish(_ availability: LocationAvailability) {
        self.availability = availability
        continuations.values.forEach { $0.yield(availability) }
    }

    private func removeContinuation(_ id: UUID) {
        continuations[id] = nil
    }

    private func removeRecordingContinuation(_ id: UUID) {
        recordingContinuations[id] = nil
    }
}

nonisolated private extension PositionCheckQuality.PositionIneligibilityReason {
    var locationReason: LocationUnavailabilityReason {
        switch self {
        case .stale: .stale
        case .invalidAccuracy: .invalidAccuracy
        case .insufficientAccuracy: .insufficientAccuracy
        case .outOfOrder: .outOfOrder
        }
    }
}
