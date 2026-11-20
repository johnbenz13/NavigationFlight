import Foundation

#if DEBUG
enum DebriefQAFlightTrack {
    private struct Point {
        let elapsed: TimeInterval
        let latitude: Double
        let longitude: Double
        let altitudeMeters: Double
    }

    static func duration(for planTitle: String) -> TimeInterval? {
        points(for: planTitle)?.last?.elapsed
    }

    static func samples(startedAt: Date, planTitle: String) -> [RecordedTrackSample]? {
        guard let points = points(for: planTitle) else { return nil }
        return points.enumerated().map { index, point in
            let previous = index > 0 ? points[index - 1] : nil
            let speed = previous.flatMap { previous -> Double? in
                let elapsed = point.elapsed - previous.elapsed
                guard elapsed > 0 else { return nil }
                return distance(from: previous, to: point) / elapsed
            }
            let course = previous.map { bearing(from: $0, to: point) }
            return RecordedTrackSample(
                coordinate: WGS84Coordinate(
                    latitudeDegrees: point.latitude,
                    longitudeDegrees: point.longitude
                ),
                observedAt: startedAt.addingTimeInterval(point.elapsed),
                horizontalAccuracyMeters: 5,
                altitudeMeters: point.altitudeMeters,
                verticalAccuracyMeters: 5,
                groundSpeedMetersPerSecond: speed,
                speedAccuracyMetersPerSecond: speed == nil ? nil : 1,
                courseDegrees: course,
                courseAccuracyDegrees: course == nil ? nil : 2,
                barometricAltitudeMeters: point.altitudeMeters,
                deviceHeadingDegrees: course,
                deviceHeadingAccuracyDegrees: course == nil ? nil : 3
            )
        }
    }

    private static func distance(from start: Point, to end: Point) -> Double {
        let radius = 6_371_000.0
        let latitudeDelta = radians(end.latitude - start.latitude)
        let longitudeDelta = radians(end.longitude - start.longitude)
        let startLatitude = radians(start.latitude)
        let endLatitude = radians(end.latitude)
        let value = sin(latitudeDelta / 2) * sin(latitudeDelta / 2)
            + cos(startLatitude) * cos(endLatitude)
            * sin(longitudeDelta / 2) * sin(longitudeDelta / 2)
        return radius * 2 * atan2(sqrt(value), sqrt(1 - value))
    }

    private static func bearing(from start: Point, to end: Point) -> Double {
        let startLatitude = radians(start.latitude)
        let endLatitude = radians(end.latitude)
        let longitudeDelta = radians(end.longitude - start.longitude)
        let y = sin(longitudeDelta) * cos(endLatitude)
        let x = cos(startLatitude) * sin(endLatitude)
            - sin(startLatitude) * cos(endLatitude) * cos(longitudeDelta)
        return (atan2(y, x) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }

    private static func radians(_ degrees: Double) -> Double {
        degrees * .pi / 180
    }

    private static func points(for planTitle: String) -> [Point]? {
        switch planTitle {
        case "LLHZ - LLIB via Jerusalem": llhzLLIBPoints
        case "LLHZ - LLMZ": llhzLLMZPoints
        default: nil
        }
    }

    // Deterministic downsample of the owner-provided 16 Nov 2026 LLHZ–LLIB KML flight.
    private static let llhzLLIBPoints: [Point] = [
        Point(elapsed: 0.0, latitude: 32.181418, longitude: 34.828641, altitudeMeters: 27.0),
        Point(elapsed: 125.92, latitude: 32.182247, longitude: 34.828411, altitudeMeters: 26.7),
        Point(elapsed: 251.92, latitude: 32.182249, longitude: 34.828405, altitudeMeters: 24.8),
        Point(elapsed: 376.92, latitude: 32.182251, longitude: 34.82841, altitudeMeters: 26.5),
        Point(elapsed: 501.92, latitude: 32.182252, longitude: 34.828405, altitudeMeters: 26.7),
        Point(elapsed: 626.92, latitude: 32.182246, longitude: 34.828402, altitudeMeters: 27.6),
        Point(elapsed: 751.92, latitude: 32.18224, longitude: 34.828404, altitudeMeters: 26.7),
        Point(elapsed: 876.92, latitude: 32.18093, longitude: 34.831237, altitudeMeters: 29.2),
        Point(elapsed: 1_002.92, latitude: 32.179162, longitude: 34.837232, altitudeMeters: 35.8),
        Point(elapsed: 1_128.92, latitude: 32.178803, longitude: 34.838514, altitudeMeters: 35.9),
        Point(elapsed: 1_254.92, latitude: 32.178805, longitude: 34.838522, altitudeMeters: 35.5),
        Point(elapsed: 1_380.92, latitude: 32.178811, longitude: 34.838525, altitudeMeters: 35.9),
        Point(elapsed: 1_506.92, latitude: 32.185855, longitude: 34.828294, altitudeMeters: 168.6),
        Point(elapsed: 1_632.92, latitude: 32.211424, longitude: 34.801764, altitudeMeters: 355.9),
        Point(elapsed: 1_758.92, latitude: 32.158299, longitude: 34.785678, altitudeMeters: 252.1),
        Point(elapsed: 1_884.92, latitude: 32.106163, longitude: 34.767504, altitudeMeters: 236.6),
        Point(elapsed: 2_010.92, latitude: 32.056668, longitude: 34.747318, altitudeMeters: 253.9),
        Point(elapsed: 2_136.92, latitude: 32.002867, longitude: 34.73705, altitudeMeters: 229.6),
        Point(elapsed: 2_262.92, latitude: 31.954299, longitude: 34.768148, altitudeMeters: 234.9),
        Point(elapsed: 2_388.92, latitude: 31.928214, longitude: 34.824136, altitudeMeters: 257.0),
        Point(elapsed: 2_514.92, latitude: 31.909212, longitude: 34.884666, altitudeMeters: 265.2),
        Point(elapsed: 2_640.92, latitude: 31.878902, longitude: 34.936454, altitudeMeters: 265.9),
        Point(elapsed: 2_767.92, latitude: 31.840046, longitude: 34.982486, altitudeMeters: 405.9),
        Point(elapsed: 2_893.92, latitude: 31.810638, longitude: 35.03626, altitudeMeters: 689.0),
        Point(elapsed: 3_019.92, latitude: 31.80053, longitude: 35.097678, altitudeMeters: 977.5),
        Point(elapsed: 3_145.92, latitude: 31.803975, longitude: 35.161685, altitudeMeters: 1_003.9),
        Point(elapsed: 3_271.92, latitude: 31.823902, longitude: 35.223702, altitudeMeters: 1_068.4),
        Point(elapsed: 3_397.92, latitude: 31.814498, longitude: 35.294851, altitudeMeters: 1_069.9),
        Point(elapsed: 3_523.92, latitude: 31.836932, longitude: 35.32886, altitudeMeters: 1_106.2),
        Point(elapsed: 3_649.92, latitude: 31.890562, longitude: 35.335947, altitudeMeters: 1_100.7),
        Point(elapsed: 3_775.92, latitude: 31.94343, longitude: 35.336716, altitudeMeters: 1_129.3),
        Point(elapsed: 3_901.92, latitude: 31.994046, longitude: 35.351782, altitudeMeters: 1_077.6),
        Point(elapsed: 4_027.92, latitude: 32.027487, longitude: 35.410253, altitudeMeters: 1_059.0),
        Point(elapsed: 4_153.92, latitude: 32.05571, longitude: 35.472816, altitudeMeters: 1_020.8),
        Point(elapsed: 4_279.91, latitude: 32.105742, longitude: 35.506001, altitudeMeters: 923.7),
        Point(elapsed: 4_405.91, latitude: 32.157056, longitude: 35.533087, altitudeMeters: 923.0),
        Point(elapsed: 4_530.91, latitude: 32.208794, longitude: 35.54976, altitudeMeters: 919.5),
        Point(elapsed: 4_655.91, latitude: 32.261769, longitude: 35.548831, altitudeMeters: 935.5),
        Point(elapsed: 4_780.91, latitude: 32.313516, longitude: 35.545713, altitudeMeters: 915.2),
        Point(elapsed: 4_905.91, latitude: 32.364224, longitude: 35.534747, altitudeMeters: 941.3),
        Point(elapsed: 5_030.91, latitude: 32.415136, longitude: 35.52076, altitudeMeters: 955.1),
        Point(elapsed: 5_155.91, latitude: 32.468055, longitude: 35.521478, altitudeMeters: 927.0),
        Point(elapsed: 5_280.91, latitude: 32.523016, longitude: 35.531021, altitudeMeters: 934.0),
        Point(elapsed: 5_405.91, latitude: 32.578156, longitude: 35.542645, altitudeMeters: 902.8),
        Point(elapsed: 5_531.92, latitude: 32.629416, longitude: 35.552514, altitudeMeters: 959.0),
        Point(elapsed: 5_657.92, latitude: 32.683939, longitude: 35.551277, altitudeMeters: 920.6),
        Point(elapsed: 5_783.92, latitude: 32.735684, longitude: 35.550176, altitudeMeters: 806.4),
        Point(elapsed: 5_909.92, latitude: 32.785943, longitude: 35.543012, altitudeMeters: 767.6),
        Point(elapsed: 6_035.92, latitude: 32.835209, longitude: 35.536618, altitudeMeters: 780.4),
        Point(elapsed: 6_161.92, latitude: 32.878367, longitude: 35.547216, altitudeMeters: 785.5),
        Point(elapsed: 6_287.92, latitude: 32.91787, longitude: 35.585807, altitudeMeters: 593.7),
        Point(elapsed: 6_413.92, latitude: 32.961, longitude: 35.585708, altitudeMeters: 430.1),
        Point(elapsed: 6_539.92, latitude: 32.980279, longitude: 35.572431, altitudeMeters: 266.1),
        Point(elapsed: 6_665.92, latitude: 32.977311, longitude: 35.573419, altitudeMeters: 263.7),
        Point(elapsed: 6_676.92, latitude: 32.977308, longitude: 35.573419, altitudeMeters: 263.6),
    ]

    // Deterministic downsample of the owner-provided 17 Nov 2026 KML flight.
    private static let llhzLLMZPoints: [Point] = [
        Point(elapsed: 0.0, latitude: 32.181228, longitude: 34.828135, altitudeMeters: 26.6),
        Point(elapsed: 126.39, latitude: 32.181551, longitude: 34.827877, altitudeMeters: 30.5),
        Point(elapsed: 251.39, latitude: 32.181549, longitude: 34.82785, altitudeMeters: 27.0),
        Point(elapsed: 376.39, latitude: 32.181549, longitude: 34.827854, altitudeMeters: 28.4),
        Point(elapsed: 501.39, latitude: 32.181212, longitude: 34.830413, altitudeMeters: 28.9),
        Point(elapsed: 626.4, latitude: 32.179408, longitude: 34.836401, altitudeMeters: 35.3),
        Point(elapsed: 751.4, latitude: 32.178801, longitude: 34.838513, altitudeMeters: 38.1),
        Point(elapsed: 877.4, latitude: 32.178804, longitude: 34.838516, altitudeMeters: 38.8),
        Point(elapsed: 1_003.4, latitude: 32.197094, longitude: 34.831119, altitudeMeters: 205.2),
        Point(elapsed: 1_129.4, latitude: 32.199362, longitude: 34.800326, altitudeMeters: 251.9),
        Point(elapsed: 1_255.4, latitude: 32.154162, longitude: 34.784016, altitudeMeters: 247.4),
        Point(elapsed: 1_380.4, latitude: 32.106882, longitude: 34.766749, altitudeMeters: 225.6),
        Point(elapsed: 1_505.4, latitude: 32.059031, longitude: 34.749432, altitudeMeters: 252.9),
        Point(elapsed: 1_630.4, latitude: 32.008774, longitude: 34.734661, altitudeMeters: 234.4),
        Point(elapsed: 1_755.4, latitude: 31.959062, longitude: 34.764509, altitudeMeters: 256.2),
        Point(elapsed: 1_881.4, latitude: 31.930668, longitude: 34.823757, altitudeMeters: 248.3),
        Point(elapsed: 2_007.4, latitude: 31.909673, longitude: 34.888026, altitudeMeters: 250.9),
        Point(elapsed: 2_133.4, latitude: 31.876138, longitude: 34.93984, altitudeMeters: 269.0),
        Point(elapsed: 2_259.4, latitude: 31.835115, longitude: 34.988503, altitudeMeters: 439.0),
        Point(elapsed: 2_385.4, latitude: 31.80626, longitude: 35.04627, altitudeMeters: 693.9),
        Point(elapsed: 2_511.4, latitude: 31.796606, longitude: 35.111115, altitudeMeters: 1_042.8),
        Point(elapsed: 2_637.4, latitude: 31.788103, longitude: 35.174862, altitudeMeters: 1_373.7),
        Point(elapsed: 2_763.4, latitude: 31.781426, longitude: 35.244243, altitudeMeters: 1_403.4),
        Point(elapsed: 2_889.4, latitude: 31.785404, longitude: 35.318741, altitudeMeters: 1_411.0),
        Point(elapsed: 3_015.4, latitude: 31.773732, longitude: 35.392782, altitudeMeters: 1_436.3),
        Point(elapsed: 3_140.4, latitude: 31.747024, longitude: 35.455185, altitudeMeters: 1_238.7),
        Point(elapsed: 3_265.4, latitude: 31.688652, longitude: 35.441657, altitudeMeters: 1_110.0),
        Point(elapsed: 3_390.4, latitude: 31.631315, longitude: 35.423411, altitudeMeters: 1_108.4),
        Point(elapsed: 3_515.4, latitude: 31.572712, longitude: 35.404164, altitudeMeters: 1_084.8),
        Point(elapsed: 3_640.4, latitude: 31.511183, longitude: 35.398021, altitudeMeters: 1_117.8),
        Point(elapsed: 3_765.4, latitude: 31.448722, longitude: 35.390106, altitudeMeters: 1_105.0),
        Point(elapsed: 3_890.4, latitude: 31.386088, longitude: 35.390945, altitudeMeters: 1_094.9),
        Point(elapsed: 4_015.4, latitude: 31.340159, longitude: 35.413199, altitudeMeters: 684.4),
        Point(elapsed: 4_140.4, latitude: 31.324819, longitude: 35.405285, altitudeMeters: 18.0),
        Point(elapsed: 4_265.4, latitude: 31.317954, longitude: 35.386543, altitudeMeters: -325.5),
        Point(elapsed: 4_390.4, latitude: 31.326651, longitude: 35.38826, altitudeMeters: -383.5),
        Point(elapsed: 4_515.4, latitude: 31.330306, longitude: 35.389412, altitudeMeters: -379.9),
        Point(elapsed: 4_640.4, latitude: 31.329125, longitude: 35.388156, altitudeMeters: -379.7),
        Point(elapsed: 4_765.4, latitude: 31.329103, longitude: 35.388134, altitudeMeters: -386.0),
        Point(elapsed: 4_891.4, latitude: 31.328752, longitude: 35.38768, altitudeMeters: -377.1),
        Point(elapsed: 5_064.41, latitude: 31.32869, longitude: 35.387465, altitudeMeters: -354.4),
        Point(elapsed: 5_186.41, latitude: 31.328694, longitude: 35.387494, altitudeMeters: -354.4),
    ]
}
#endif
