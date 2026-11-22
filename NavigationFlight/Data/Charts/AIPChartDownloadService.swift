import Foundation

nonisolated struct AIPChartDownloadService: Sendable {
    enum Failure: Error {
        case response
        case size
        case verification
    }

    enum Event: Sendable {
        case bytes(Int)
        case verifying
    }

    typealias Progress = @Sendable (Int) async -> Void
    typealias Read = @Sendable (URL, Int, Progress) async throws -> Data

    let publicKey: Data
    let read: Read

    init(
        publicKey: Data = AIPChartUpdateIndex.trustedPublicKey,
        read: @escaping Read = { url, limit, progress in try await Self.readHTTPS(url, limit, progress) }
    ) {
        self.publicKey = publicKey
        self.read = read
    }

    func fetchIndex() async throws -> Data {
        try await read(AIPChartUpdateIndex.endpoint, AIPChartUpdateIndex.maximumBytes, { _ in })
    }

    @concurrent
    func install(
        _ offer: AIPChartUpdateIndex.Offer,
        in store: ChartSnapshotStore,
        onEvent: @escaping @Sendable (Event) async -> Void
    ) async throws -> ChartSnapshot {
        guard let manifestURL = URL(string: offer.manifestUrl) else { throw Failure.verification }
        let index = try await read(manifestURL, 1024 * 1024, { _ in })
        let catalog = try validatedCatalog(index, offer: offer)
        let root = try await store.makeDownloadStagingDirectory()
        let pdf = root.appending(path: "AIPCharts/pdf", directoryHint: .isDirectory)
        let resources = ChartResources(bundleRoot: root)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: pdf, withIntermediateDirectories: true)
        try index.write(to: root.appending(path: "AIPCharts/index.json"))

        var received = 0
        for asset in catalog.artifacts {
            try Task.checkCancellation()
            guard let id = asset.id, let destination = try? resources.assetURL(for: asset) else {
                throw Failure.verification
            }
            let assetURL = manifestURL.deletingLastPathComponent().appending(path: "artifact-\(id)")
            let previous = received
            let bytes = try await read(assetURL, asset.bytes) { count in
                await onEvent(.bytes(previous + count))
            }
            guard bytes.count == asset.bytes, ChartSnapshotVerification.digest(bytes) == asset.sha256 else {
                throw Failure.verification
            }
            try bytes.write(to: destination)
            received += bytes.count
            await onEvent(.bytes(received))
        }
        await onEvent(.verifying)
        do {
            return try await store.install(from: resources, pin: offer.pin)
        } catch is CancellationError {
            throw CancellationError()
        } catch is ChartSnapshotStoreError {
            throw Failure.verification
        } catch is ChartResourceError {
            throw Failure.verification
        }
    }

    private func validatedCatalog(_ data: Data, offer: AIPChartUpdateIndex.Offer) throws -> ChartCatalog {
        guard data.count <= 1024 * 1024, ChartSnapshotVerification.digest(data) == offer.manifestSha256,
              let catalog = try? ChartResources.decodeCatalog(data), catalog.releaseId == offer.releaseId,
              catalog.schemaVersion == offer.manifestSchemaVersion,
              catalog.snapshot.amendment == offer.amendment, catalog.snapshot.effectiveDate == offer.effectiveDate,
              catalog.artifacts.count <= 256 else { throw Failure.verification }

        var ids = Set<String>()
        var destinations = Set<String>()
        var bytes = 0
        for asset in catalog.artifacts {
            guard let id = asset.id, id.wholeMatch(of: /[a-z0-9][a-z0-9_-]{0,99}/) != nil,
                  ids.insert(id).inserted, destinations.insert(asset.destination).inserted,
                  (1...128 * 1024 * 1024).contains(asset.bytes),
                  asset.sha256.wholeMatch(of: /[0-9a-f]{64}/) != nil else { throw Failure.verification }
            bytes += asset.bytes
            guard bytes <= offer.totalPdfBytes else { throw Failure.verification }
        }
        guard bytes == offer.totalPdfBytes else { throw Failure.verification }
        return catalog
    }

    @concurrent
    private static func readHTTPS(_ url: URL, _ limit: Int, _ progress: Progress) async throws -> Data {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 120
        let redirect = ReleaseRedirectPolicy(allowsAssetRedirects: url.host == "github.com")
        let session = URLSession(configuration: config, delegate: redirect, delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        let (body, response) = try await session.bytes(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw Failure.response }
        guard http.expectedContentLength <= Int64(limit) else { throw Failure.size }
        var data = Data()
        if http.expectedContentLength > 0 { data.reserveCapacity(Int(http.expectedContentLength)) }
        for try await byte in body {
            guard data.count < limit else { throw Failure.size }
            data.append(byte)
            if data.count.isMultiple(of: 256 * 1024) {
                try Task.checkCancellation()
                await progress(data.count)
            }
        }
        try Task.checkCancellation()
        return data
    }
}

private nonisolated final class ReleaseRedirectPolicy: NSObject, URLSessionTaskDelegate {
    let allowsAssetRedirects: Bool

    init(allowsAssetRedirects: Bool) {
        self.allowsAssetRedirects = allowsAssetRedirects
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        let hosts = ["release-assets.githubusercontent.com", "objects.githubusercontent.com", "github-releases.githubusercontent.com"]
        guard allowsAssetRedirects, let url = request.url, url.scheme == "https",
              url.user == nil, url.password == nil, url.port == nil,
              let host = url.host, hosts.contains(host) else {
            completionHandler(nil)
            return
        }
        completionHandler(request)
    }
}
