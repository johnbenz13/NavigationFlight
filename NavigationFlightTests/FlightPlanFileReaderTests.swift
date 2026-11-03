import Foundation
import Testing
@testable import NavigationFlight

@Suite("Flight Plan File Reader")
struct FlightPlanFileReaderTests {
    @Test("Copies fplnav bytes into memory")
    func readsFlightPlanBytes() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "plan.fplnav")
        let expected = Data("flight plan".utf8)
        try expected.write(to: url)

        let data = try await FlightPlanFileReader().data(from: url)

        #expect(data == expected)
    }

    @Test("Rejects files outside the fplnav boundary")
    func rejectsUnsupportedExtension() async {
        let url = URL.temporaryDirectory.appending(path: "plan.json")

        await #expect(throws: FlightPlanFileAccessError.unsupportedExtension) {
            try await FlightPlanFileReader().data(from: url)
        }
    }
}
