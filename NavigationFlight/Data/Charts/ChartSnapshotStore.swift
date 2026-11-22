import Foundation

nonisolated enum ChartSnapshotStoreError: Error, Equatable {
    case invalidPin
    case invalidManifest
    case invalidInventory
    case invalidPDF
    case outdatedEdition
}

/// Own one store for the application. All filesystem work and commit checks are serialized here.
actor ChartSnapshotStore {
    private struct Reference: Codable, Sendable {
        let folder: UUID
        let pin: ChartSnapshotPin
    }

    private struct Receipt: Codable {
        let schemaVersion: Int
        let current: Reference
        let previous: Reference?
    }

    private let directory: URL
    private let bundledResources: ChartResources
    private let beforeCommit: @Sendable () throws -> Void
    private var cleanedOnStartup = false
    private var bundled: ChartSnapshot?

    init(
        directory: URL,
        bundledResources: ChartResources = .bundled,
        beforeCommit: @escaping @Sendable () throws -> Void = {}
    ) {
        self.directory = directory
        self.bundledResources = bundledResources
        self.beforeCommit = beforeCommit
    }

    func currentSnapshot() -> ChartSnapshot? {
        let receipt = loadReceipt()
        cleanOnStartup(retaining: receipt)
        return newestSnapshot(downloaded: bestDownload(receipt)?.snapshot)
    }

    /// The expected pin comes from an already trusted release offer or a controlled fixture.
    @discardableResult
    func install(from staged: ChartResources, pin: ChartSnapshotPin) throws -> ChartSnapshot {
        try Task.checkCancellation()
        let receipt = loadReceipt()
        cleanOnStartup(retaining: receipt)
        let priorDownload = bestDownload(receipt)
        if let current = newestSnapshot(downloaded: priorDownload?.snapshot) {
            try Task.checkCancellation()
            if pin == current.pin { return current }
            guard pin.sequence > current.pin.sequence else { throw ChartSnapshotStoreError.outdatedEdition }
        }

        let incoming = try ChartSnapshotVerification.inspect(staged, pin: pin)
        try createStorage()
        let id = UUID()
        let temporary = directory.appending(path: "staging-\(id.uuidString)", directoryHint: .isDirectory)
        let destination = releaseDirectory(id)
        let files = FileManager.default
        defer { try? files.removeItem(at: temporary) }
        try copy(incoming, to: temporary)
        let verified = try ChartSnapshotVerification.inspect(ChartResources(bundleRoot: temporary), pin: pin)
        try ChartSnapshotVerification.verifyPDFs(in: verified)
        try Task.checkCancellation()

        try files.moveItem(at: temporary, to: destination)
        do {
            let next = Receipt(
                schemaVersion: 1,
                current: Reference(folder: id, pin: pin),
                previous: priorDownload?.reference
            )
            let data = try JSONEncoder().encode(next)
            try beforeCommit()
            try Task.checkCancellation()
            try data.write(to: receiptURL, options: .atomic)
        } catch {
            try? files.removeItem(at: destination)
            throw error
        }
        return ChartSnapshot(pin: pin, catalog: verified.catalog, resources: ChartResources(bundleRoot: destination))
    }

    private var receiptURL: URL { directory.appending(path: "installed.json") }

    private func releaseDirectory(_ id: UUID) -> URL {
        directory.appending(path: "release-\(id.uuidString)", directoryHint: .isDirectory)
    }

    private func loadReceipt() -> Receipt? {
        guard let values = try? receiptURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]),
              values.isRegularFile == true, values.isSymbolicLink == false, let size = values.fileSize, size <= 8192,
              let data = try? Data(contentsOf: receiptURL),
              let receipt = try? JSONDecoder().decode(Receipt.self, from: data), receipt.schemaVersion == 1 else { return nil }
        return receipt
    }

    private func loadBundle() -> ChartSnapshot? {
        if let bundled { return bundled }
        let pinURL = bundledResources.bundleRoot.appending(path: "aip-charts-pin.json")
        guard let data = try? Data(contentsOf: pinURL),
              let pin = try? JSONDecoder().decode(ChartSnapshotPin.self, from: data),
              let result = try? ChartSnapshotVerification.inspect(bundledResources, pin: pin),
              (try? ChartSnapshotVerification.verifyPDFs(in: result)) != nil else { return nil }
        bundled = result
        return result
    }

    private func newestSnapshot(downloaded: ChartSnapshot?) -> ChartSnapshot? {
        guard let bundled = loadBundle() else { return downloaded }
        guard let downloaded, downloaded.pin.sequence > bundled.pin.sequence else { return bundled }
        return downloaded
    }

    private func bestDownload(_ receipt: Receipt?) -> (snapshot: ChartSnapshot, reference: Reference)? {
        guard let receipt else { return nil }
        let candidates = [receipt.current, receipt.previous].compactMap { $0 }
            .sorted { $0.pin.sequence > $1.pin.sequence }
        for candidate in candidates {
            let resources = ChartResources(bundleRoot: releaseDirectory(candidate.folder))
            if let snapshot = try? ChartSnapshotVerification.inspect(resources, pin: candidate.pin),
               (try? ChartSnapshotVerification.verifyPDFs(in: snapshot)) != nil {
                return (snapshot, candidate)
            }
        }
        return nil
    }

    private func createStorage() throws {
        var root = directory
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try root.setResourceValues(values)
    }

    private func copy(_ snapshot: ChartSnapshot, to destination: URL) throws {
        let charts = destination.appending(path: "AIPCharts", directoryHint: .isDirectory)
        let pdfs = charts.appending(path: "pdf", directoryHint: .isDirectory)
        let files = FileManager.default
        try files.createDirectory(at: pdfs, withIntermediateDirectories: true)
        let index = snapshot.resources.bundleRoot.appending(path: "AIPCharts/index.json")
        try files.copyItem(at: index, to: charts.appending(path: "index.json"))
        for asset in snapshot.catalog.artifacts {
            try Task.checkCancellation()
            let source = try snapshot.resources.assetURL(for: asset)
            try files.copyItem(at: source, to: pdfs.appending(path: source.lastPathComponent))
        }
    }

    private func cleanOnStartup(retaining receipt: Receipt?) {
        guard !cleanedOnStartup else { return }
        cleanedOnStartup = true
        let retained = Set([receipt?.current.folder, receipt?.previous?.folder].compactMap { $0 })
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else { return }

        // A running viewer can still hold any release selected during this process.
        for name in names {
            let parts = name.split(separator: "-", maxSplits: 1)
            guard parts.count == 2, let id = UUID(uuidString: String(parts[1])) else { continue }
            if parts[0] == "staging" || (parts[0] == "release" && !retained.contains(id)) {
                try? FileManager.default.removeItem(at: directory.appending(path: name))
            }
        }
    }
}
