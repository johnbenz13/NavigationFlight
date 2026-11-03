import Foundation

enum FlightPlanFileAccessError: Error, Equatable, Sendable {
    case unsupportedExtension
    case accessDenied
    case unreadable
}

actor FlightPlanFileReader {
    func data(from url: URL) throws -> Data {
        guard url.pathExtension.lowercased() == "fplnav" else {
            throw FlightPlanFileAccessError.unsupportedExtension
        }

        let hasSecurityScopedAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasSecurityScopedAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            return try Data(contentsOf: url, options: .mappedIfSafe)
        } catch CocoaError.fileReadNoPermission {
            throw FlightPlanFileAccessError.accessDenied
        } catch {
            throw FlightPlanFileAccessError.unreadable
        }
    }
}
