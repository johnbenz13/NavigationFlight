import SwiftUI

nonisolated enum FlightDebriefPlotPath {
    static func make(
        observations: [FlightDebriefObservation],
        size: CGSize,
        maximum: Double,
        total: TimeInterval
    ) -> Path {
        guard maximum > 0, total > 0 else { return Path() }
        var path = Path()
        // GPS and barometric altitude are independent series, each retaining
        // its recorded segment boundaries even when samples share a timestamp.
        for source in [FlightDebriefObservation.Source.gpsAltitude, .barometricAltitude, .groundSpeed] {
            var previousSegmentID: UUID?
            for observation in observations where observation.source == source {
                let elapsed = observation.elapsed.components
                let seconds = Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18
                let point = CGPoint(
                    x: size.width * seconds / total,
                    y: size.height * (1 - observation.value / maximum)
                )
                if observation.segmentID == previousSegmentID {
                    path.addLine(to: point)
                } else {
                    path.move(to: point)
                }
                previousSegmentID = observation.segmentID
            }
        }
        return path
    }
}
