import Foundation
import Observation

@MainActor @Observable
final class AIPChartUpdates {
    typealias Offer = AIPChartUpdateIndex.Offer

    enum Discovery: Equatable { case idle, checking, current, failed }
    enum Transfer: Equatable {
        case idle
        case downloading(Offer, Int)
        case verifying(Offer)
        case cancelled
        case failed
        case verificationFailed
        case installed

        var isRunning: Bool {
            switch self {
            case .downloading, .verifying: true
            default: false
            }
        }
    }

    private(set) var discovery = Discovery.idle
    private(set) var transfer = Transfer.idle
    private(set) var installed: ChartSnapshot?

    var offer: Offer? { index?.offer(after: installed?.pin.sequence ?? 0) }

    private let store: ChartSnapshotStore
    private let service: AIPChartDownloadService
    private let cache: URL?
    private let now: () -> Date
    private var index: AIPChartUpdateIndex.Verified?
    private var lastCheck: Date?
    @ObservationIgnored private var hasLoadedCache = false
    @ObservationIgnored private var check: Task<Void, Never>?
    @ObservationIgnored private var download: Task<Void, Never>?

    init(
        store: ChartSnapshotStore,
        service: AIPChartDownloadService = AIPChartDownloadService(),
        cache: URL? = nil,
        now: @escaping () -> Date = Date.init
    ) {
        self.store = store
        self.service = service
        self.cache = cache
        self.now = now
    }

    func observeInstalled(_ snapshot: ChartSnapshot?) {
        if installed?.pin != snapshot?.pin, transfer == .installed { transfer = .idle }
        installed = snapshot
    }

    @discardableResult
    func refresh(force: Bool = false) -> Task<Void, Never>? {
        prepareDiscovery()
        guard check == nil, !transfer.isRunning,
              force || lastCheck.map({ now().timeIntervalSince($0) >= 300 }) != false else { return nil }
        lastCheck = now()
        discovery = .checking
        let work = Task {
            defer { check = nil }
            do {
                let bytes = try await service.fetchIndex()
                let verified = try AIPChartUpdateIndex.verify(bytes, after: index, publicKey: service.publicKey)
                if let cache {
                    try FileManager.default.createDirectory(at: cache.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try bytes.write(to: cache, options: .atomic)
                }
                let oldOffer = offer
                index = verified
                if oldOffer != offer, !transfer.isRunning { transfer = .idle }
                discovery = .current
            } catch {
                discovery = .failed
            }
        }
        check = work
        return work
    }

    @discardableResult
    func confirm(_ expected: Offer) -> Task<Void, Never>? {
        guard check == nil, download == nil, expected == offer else { return nil }
        transfer = .downloading(expected, 0)
        let work = Task {
            defer { download = nil }
            do {
                let snapshot = try await service.install(expected, in: store) { [weak self] event in
                    await self?.report(event, offer: expected)
                }
                installed = snapshot
                transfer = .installed
            } catch is CancellationError {
                transfer = .cancelled
            } catch AIPChartDownloadService.Failure.verification, AIPChartDownloadService.Failure.size {
                transfer = .verificationFailed
            } catch {
                transfer = Task.isCancelled ? .cancelled : .failed
            }
        }
        download = work
        return work
    }

    func cancel() { download?.cancel() }

    private func report(_ event: AIPChartDownloadService.Event, offer: Offer) {
        switch event {
        case .bytes(let count): transfer = .downloading(offer, count)
        case .verifying: transfer = .verifying(offer)
        }
    }

    private func prepareDiscovery() {
        guard !hasLoadedCache else { return }
        hasLoadedCache = true
        guard let cache, let size = try? cache.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              size <= AIPChartUpdateIndex.maximumBytes, let data = try? Data(contentsOf: cache) else { return }
        index = try? AIPChartUpdateIndex.verify(data, publicKey: service.publicKey)
    }
}
