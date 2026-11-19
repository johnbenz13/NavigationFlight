// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "FlightEvidenceCore",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "FlightEvidenceCore", targets: ["FlightEvidenceCore"]),
    ],
    targets: [
        .target(name: "FlightEvidenceCore"),
        .testTarget(name: "FlightEvidenceCoreTests", dependencies: ["FlightEvidenceCore"]),
    ]
)
