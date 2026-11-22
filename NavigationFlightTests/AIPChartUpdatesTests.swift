#if DEBUG && targetEnvironment(simulator)
import Foundation
import Testing
@testable import NavigationFlight

@MainActor
@Suite("AIP chart updates")
struct AIPChartUpdatesTests {
    @Test("Refresh throttles foreground requests and restores a known offer after a failed refresh or relaunch")
    func knownOffer() async throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = ChartSnapshotStore(directory: root)
        let fixture = AIPChartDownloadFixture.makeService(mode: "available", assetDelay: .zero)
        let control = ControlledRead(read: fixture.read)
        let service = AIPChartDownloadService(publicKey: fixture.publicKey) { url, limit, progress in
            try await control.read(url, limit, progress)
        }
        let cache = root.appending(path: "index.json")
        var time = Date(timeIntervalSince1970: 1000)
        let owner = AIPChartUpdates(store: store, service: service, cache: cache, now: { time })
        owner.observeInstalled(await store.currentSnapshot())

        let check = try #require(owner.refresh())
        #expect(owner.refresh(force: true) == nil)
        await check.value
        #expect(owner.discovery == .current)
        let offer = try #require(owner.offer)
        #expect(owner.refresh() == nil)

        await control.goOffline()
        time.addTimeInterval(301)
        await owner.refresh()?.value
        #expect(owner.discovery == .failed)
        #expect(owner.offer == offer)

        let reopened = AIPChartUpdates(store: store, service: service, cache: cache)
        reopened.observeInstalled(await store.currentSnapshot())
        await reopened.refresh()?.value
        #expect(reopened.discovery == .failed)
        #expect(reopened.offer == offer)
    }

    @Test("A bad PDF leaves the bundled edition selected and retry activates the verified snapshot")
    func verificationFailureAndRetry() async throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = ChartSnapshotStore(directory: root)
        let service = AIPChartDownloadFixture.makeService(mode: "verification-failure", assetDelay: .zero)
        let owner = AIPChartUpdates(store: store, service: service)
        let original = try #require(await store.currentSnapshot())
        owner.observeInstalled(original)
        await owner.refresh()?.value

        let offer = try #require(owner.offer)
        let update = try #require(owner.confirm(offer))
        #expect(owner.confirm(offer) == nil)
        await update.value
        #expect(owner.transfer == .verificationFailed)
        #expect(await store.currentSnapshot()?.pin == original.pin)
        #expect(owner.offer == offer)

        await owner.confirm(offer)?.value
        #expect(owner.transfer == .installed)
        #expect(owner.offer == nil)
        #expect(await store.currentSnapshot()?.pin == offer.pin)
    }

    @Test("Cancellation before commit keeps the previous edition and the offer")
    func cancelledDownload() async throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = ChartSnapshotStore(directory: root)
        let service = AIPChartDownloadFixture.makeService(mode: "available", assetDelay: .seconds(60))
        let owner = AIPChartUpdates(store: store, service: service)
        let original = try #require(await store.currentSnapshot())
        owner.observeInstalled(original)
        await owner.refresh()?.value
        let offer = try #require(owner.offer)
        let download = try #require(owner.confirm(offer))
        owner.cancel()
        await download.value
        #expect(owner.transfer == .cancelled)
        #expect(owner.offer == offer)
        #expect(await store.currentSnapshot()?.pin == original.pin)
    }

    private func temporaryDirectory() -> URL {
        URL.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
    }

    private actor ControlledRead {
        let readOnline: AIPChartDownloadService.Read
        var offline = false

        init(read: @escaping AIPChartDownloadService.Read) { readOnline = read }
        func goOffline() { offline = true }

        func read(_ url: URL, _ limit: Int, _ progress: AIPChartDownloadService.Progress) async throws -> Data {
            guard !offline else { throw URLError(.notConnectedToInternet) }
            return try await readOnline(url, limit, progress)
        }
    }
}
#endif
