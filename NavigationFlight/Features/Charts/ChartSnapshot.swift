import Foundation

nonisolated struct ChartSnapshotPin: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let releaseId: String
    let sequence: Int
    let manifestSha256: String

    init(releaseId: String, sequence: Int, manifestSha256: String, schemaVersion: Int = 1) {
        self.schemaVersion = schemaVersion
        self.releaseId = releaseId
        self.sequence = sequence
        self.manifestSha256 = manifestSha256
    }

    var isSupported: Bool {
        schemaVersion == 1 && sequence > 0
            && releaseId.wholeMatch(of: /[a-z0-9][a-z0-9_-]{0,99}/) != nil
            && manifestSha256.wholeMatch(of: /[0-9a-f]{64}/) != nil
    }
}

/// A catalog and file root selected together. Keep the handle for as long as a viewer uses it.
nonisolated struct ChartSnapshot: Sendable {
    let pin: ChartSnapshotPin
    let catalog: ChartCatalog
    let resources: ChartResources
}
