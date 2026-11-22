import CoreGraphics
import Foundation
import PDFKit
import Testing
@testable import NavigationFlight

@MainActor
@Suite("Offline chart snapshots")
struct ChartSnapshotStoreTests {
    @Test("The bundled chart seed has a checked pin and is usable without a downloaded receipt")
    func shippedSeed() async throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = ChartSnapshotStore(directory: root.appending(path: "releases"))
        let snapshot = try #require(await store.currentSnapshot())
        #expect(snapshot.pin.releaseId == "domestic-aip-01-2026")
        #expect(snapshot.pin.sequence == 1)
        #expect(snapshot.catalog.artifacts.count == 65)
    }

    @Test("A newer edition survives relaunch while an existing handle keeps the original PDF")
    func installAndReopen() async throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let seed = try fixture(in: root, sequence: 1)
        let first = try fixture(in: root, sequence: 2, chartIDs: ["retained", "retired"])
        let latest = try fixture(in: root, sequence: 3)
        let storage = root.appending(path: "storage")
        let store = ChartSnapshotStore(directory: storage, bundledResources: seed.resources)

        let open = try await store.install(from: first.resources, pin: first.pin)
        _ = try await store.install(from: latest.resources, pin: latest.pin)
        let oldChart = try #require(open.catalog.selection(for: "retained")?.chart)
        let oldAsset = try #require(open.catalog.artifacts.first)
        let openPDF = try ChartPDFDocument.open(oldChart, in: open.catalog, resources: open.resources)
        #expect(openPDF.pageCount == 1)
        #expect(try open.resources.assetData(for: oldAsset, chartID: oldChart.id) == first.pdfs["retained"])
        #expect(open.catalog.selection(for: "retired") != nil)

        let reopened = ChartSnapshotStore(directory: storage, bundledResources: seed.resources)
        let selected = try #require(await reopened.currentSnapshot())
        #expect(selected.pin == latest.pin)
        #expect(selected.catalog.selection(for: "retired") == nil)
        let newChart = try #require(selected.catalog.selection(for: "retained")?.chart)
        let newAsset = try #require(selected.catalog.artifacts.first)
        #expect(try selected.resources.assetData(for: newAsset, chartID: newChart.id) == latest.pdfs["retained"])
        #expect(try ChartPDFDocument.open(newChart, in: selected.catalog, resources: selected.resources).pageCount == 1)
    }

    @Test("Refreshing Charts preserves surviving navigation and clears removed IDs")
    func refreshNavigation() async throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let seed = try fixture(in: root, sequence: 1, chartIDs: ["retained", "retired"])
        let latest = try fixture(in: root, sequence: 2)
        let store = ChartSnapshotStore(directory: root.appending(path: "storage"), bundledResources: seed.resources)
        let selected = try await store.install(from: latest.resources, pin: latest.pin)

        var surviving = ChartLibraryState(aerodromePath: ["home"])
        surviving.showChart("retained")
        surviving.presentedChartID = nil
        surviving.didDismissChart()
        surviving.reconcile(with: selected.catalog)
        #expect(surviving.aerodromePath == ["home"])
        #expect(surviving.returnFocusChartID == "retained")

        var removed = ChartLibraryState(aerodromePath: ["retired-field"])
        removed.showChart("retired")
        removed.presentedChartID = nil
        removed.didDismissChart()
        removed.reconcile(with: selected.catalog)
        #expect(removed.aerodromePath.isEmpty)
        #expect(removed.returnFocusChartID == nil)
    }

    @Test("A corrupt download falls back to its predecessor and a newer app bundle takes precedence")
    func fallbackAndUpgrade() async throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let seed = try fixture(in: root, sequence: 1)
        let prior = try fixture(in: root, sequence: 2)
        let current = try fixture(in: root, sequence: 3)
        let upgraded = try fixture(in: root, sequence: 4)
        let storage = root.appending(path: "storage")
        let store = ChartSnapshotStore(directory: storage, bundledResources: seed.resources)
        let previous = try await store.install(from: prior.resources, pin: prior.pin)
        let active = try await store.install(from: current.resources, pin: current.pin)
        let asset = try #require(active.catalog.artifacts.first)
        let content = try active.resources.assetURL(for: asset)
        try Data(repeating: 0, count: asset.bytes).write(to: content)

        let reopened = ChartSnapshotStore(directory: storage, bundledResources: seed.resources)
        #expect(await reopened.currentSnapshot()?.pin == prior.pin)
        let upgradedStore = ChartSnapshotStore(directory: storage, bundledResources: upgraded.resources)
        #expect(await upgradedStore.currentSnapshot()?.pin == upgraded.pin)
        await #expect(throws: ChartSnapshotStoreError.outdatedEdition) {
            try await upgradedStore.install(from: current.resources, pin: current.pin)
        }
        try FileManager.default.removeItem(at: previous.resources.bundleRoot)
        #expect(await reopened.currentSnapshot()?.pin == seed.pin)
    }

    @Test("Paths, manifest relationships, inventory, and page bounds are verified before selection")
    func rejectsBrokenSnapshots() async throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let seed = try fixture(in: root, sequence: 1)
        let store = ChartSnapshotStore(directory: root.appending(path: "storage"), bundledResources: seed.resources)

        let badPath = try fixture(in: root, sequence: 2) { index in
            var assets = (index["artifacts"] as? [[String: Any]]) ?? []
            assets[0]["destination"] = "AIPCharts/pdf/../retained.pdf"
            index["artifacts"] = assets
        }
        await #expect(throws: ChartResourceError.self) {
            try await store.install(from: badPath.resources, pin: badPath.pin)
        }

        let duplicate = try fixture(in: root, sequence: 3) { index in
            var assets = (index["artifacts"] as? [[String: Any]]) ?? []
            assets.append(assets[0])
            index["artifacts"] = assets
        }
        await #expect(throws: ChartSnapshotStoreError.invalidManifest) {
            try await store.install(from: duplicate.resources, pin: duplicate.pin)
        }

        let wrongPageCount = try fixture(in: root, sequence: 4) { index in
            var assets = (index["artifacts"] as? [[String: Any]]) ?? []
            assets[0]["pageCount"] = 2
            index["artifacts"] = assets
        }
        await #expect(throws: ChartSnapshotStoreError.invalidPDF) {
            try await store.install(from: wrongPageCount.resources, pin: wrongPageCount.pin)
        }

        let missing = try fixture(in: root, sequence: 5)
        try FileManager.default.removeItem(at: missing.resources.bundleRoot.appending(path: "AIPCharts/pdf/retained.pdf"))
        await #expect(throws: (any Error).self) {
            try await store.install(from: missing.resources, pin: missing.pin)
        }
        let wrongSchema = try fixture(in: root, sequence: 6) { $0["schemaVersion"] = 3 }
        await #expect(throws: ChartResourceError.self) {
            try await store.install(from: wrongSchema.resources, pin: wrongSchema.pin)
        }
        #expect(await store.currentSnapshot()?.pin == seed.pin)
    }

    @Test("A receipt write failure preserves the previous edition and can be retried")
    func rollbackOnWriteFailure() async throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let seed = try fixture(in: root, sequence: 1)
        let first = try fixture(in: root, sequence: 2)
        let latest = try fixture(in: root, sequence: 3)
        let storage = root.appending(path: "storage")
        let initial = ChartSnapshotStore(directory: storage, bundledResources: seed.resources)
        _ = try await initial.install(from: first.resources, pin: first.pin)

        let failing = ChartSnapshotStore(directory: storage, bundledResources: seed.resources) {
            throw CocoaError(.fileWriteOutOfSpace)
        }
        let receipt = storage.appending(path: "installed.json")
        let before = try Data(contentsOf: receipt)
        await #expect(throws: CocoaError.self) {
            try await failing.install(from: latest.resources, pin: latest.pin)
        }
        #expect(try Data(contentsOf: receipt) == before)
        #expect(await failing.currentSnapshot()?.pin == first.pin)

        let retry = ChartSnapshotStore(directory: storage, bundledResources: seed.resources)
        #expect(try await retry.install(from: latest.resources, pin: latest.pin).pin == latest.pin)
    }

    @Test("Cancellation before the receipt commit keeps the old selection")
    func cancelledCommit() async throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let seed = try fixture(in: root, sequence: 1)
        let next = try fixture(in: root, sequence: 2)
        let entered = DispatchSemaphore(value: 0)
        let release = DispatchSemaphore(value: 0)
        let storage = root.appending(path: "storage")
        let store = ChartSnapshotStore(directory: storage, bundledResources: seed.resources) {
            entered.signal()
            if release.wait(timeout: .now() + 5) == .timedOut {
                throw CocoaError(.fileWriteUnknown)
            }
        }
        defer { release.signal() }
        let installation = Task.detached {
            try await store.install(from: next.resources, pin: next.pin)
        }
        let reachedCommit = await Task.detached {
            entered.wait(timeout: .now() + 5) == .success
        }.value
        try #require(reachedCommit)
        installation.cancel()
        release.signal()

        await #expect(throws: CancellationError.self) { try await installation.value }
        #expect(await store.currentSnapshot()?.pin == seed.pin)
        #expect(!FileManager.default.fileExists(atPath: storage.appending(path: "installed.json").path))
    }

    @Test("Retired release directories stay reachable during a session and are cleaned on startup")
    func retention() async throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let seed = try fixture(in: root, sequence: 1)
        let first = try fixture(in: root, sequence: 2)
        let prior = try fixture(in: root, sequence: 3)
        let latest = try fixture(in: root, sequence: 4)
        let storage = root.appending(path: "storage")
        let store = ChartSnapshotStore(directory: storage, bundledResources: seed.resources)
        let retiredFolder = try await store.install(from: first.resources, pin: first.pin).resources.bundleRoot
        let previousFolder = try await store.install(from: prior.resources, pin: prior.pin).resources.bundleRoot
        let activeFolder = try await store.install(from: latest.resources, pin: latest.pin).resources.bundleRoot
        #expect(FileManager.default.fileExists(atPath: retiredFolder.path))

        let abandoned = storage.appending(path: "staging-\(UUID())")
        try FileManager.default.createDirectory(at: abandoned, withIntermediateDirectories: true)
        let activeDownload = try await store.makeDownloadStagingDirectory()
        let partialPDF = activeDownload.appending(path: "partial.pdf")
        try Data([1, 2, 3]).write(to: partialPDF)
        #expect(await store.currentSnapshot()?.pin == latest.pin)
        #expect(FileManager.default.fileExists(atPath: partialPDF.path))
        let nextProcess = ChartSnapshotStore(directory: storage, bundledResources: seed.resources)
        #expect(await nextProcess.currentSnapshot()?.pin == latest.pin)
        #expect(!FileManager.default.fileExists(atPath: retiredFolder.path))
        #expect(!FileManager.default.fileExists(atPath: abandoned.path))
        #expect(!FileManager.default.fileExists(atPath: activeDownload.path))
        #expect(FileManager.default.fileExists(atPath: previousFolder.path))
        #expect(FileManager.default.fileExists(atPath: activeFolder.path))
    }

    private struct Fixture {
        let resources: ChartResources
        let pin: ChartSnapshotPin
        let pdfs: [String: Data]
    }

    private func temporaryDirectory() throws -> URL {
        let root = URL.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func fixture(
        in parent: URL,
        sequence: Int,
        chartIDs: [String] = ["retained"],
        change: (inout [String: Any]) -> Void = { _ in }
    ) throws -> Fixture {
        let id = "fixture-\(sequence)"
        let root = parent.appending(path: id, directoryHint: .isDirectory)
        let chartsRoot = root.appending(path: "AIPCharts", directoryHint: .isDirectory)
        let folder = chartsRoot.appending(path: "pdf", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        var assets: [[String: Any]] = []
        var aerodromes: [[String: Any]] = []
        var pdfs: [String: Data] = [:]
        for (offset, chartID) in chartIDs.enumerated() {
            let pdf = try makePDF(shade: Double(sequence * 10 + offset) / 100)
            let hash = ChartSnapshotVerification.digest(pdf)
            pdfs[chartID] = pdf
            try pdf.write(to: folder.appending(path: "\(chartID).pdf"))
            assets.append([
                "id": chartID, "file": "artifacts/\(chartID).pdf", "representation": "pdf", "consumer": "shared",
                "destination": "AIPCharts/pdf/\(chartID).pdf", "sha256": hash, "bytes": pdf.count, "pageCount": 1,
            ])
            let aerodrome = offset == 0 ? "home" : "retired-field"
            aerodromes.append([
                "id": aerodrome, "name": "Fixture \(aerodrome)", "group": "airfields",
                "identifiers": [["namespace": "catalog", "value": aerodrome]],
                "charts": [[
                    "id": chartID, "title": "Edition \(sequence) \(chartID)", "roles": [],
                    "sourceUrl": "https://www.gov.il/example.pdf", "edition": [:],
                    "pages": [[
                        "assetSha256": hash, "index": 0, "mediaBox": [0, 0, 100, 100],
                        "cropBox": [0, 0, 100, 100], "rotation": 0,
                    ]],
                ]],
            ])
        }
        var index: [String: Any] = [
            "schemaVersion": 2, "releaseId": id,
            "snapshot": ["amendment": "\(sequence)", "effectiveDate": "2026-08-06"],
            "aerodromes": aerodromes, "artifacts": assets,
        ]
        change(&index)
        let json = try JSONSerialization.data(withJSONObject: index, options: [.sortedKeys])
        try json.write(to: chartsRoot.appending(path: "index.json"))
        let pin = ChartSnapshotPin(releaseId: id, sequence: sequence, manifestSha256: ChartSnapshotVerification.digest(json))
        try JSONEncoder().encode(pin).write(to: root.appending(path: "aip-charts-pin.json"))
        return Fixture(resources: ChartResources(bundleRoot: root), pin: pin, pdfs: pdfs)
    }

    private func makePDF(shade: Double) throws -> Data {
        let stream = NSMutableData()
        let consumer = try #require(CGDataConsumer(data: stream))
        var bounds = CGRect(x: 0, y: 0, width: 100, height: 100)
        let context = try #require(CGContext(consumer: consumer, mediaBox: &bounds, nil))
        context.beginPDFPage(nil)
        context.setFillColor(gray: shade, alpha: 1)
        context.fill(bounds)
        context.endPDFPage()
        context.closePDF()
        return stream as Data
    }
}
