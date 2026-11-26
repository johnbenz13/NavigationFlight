import Foundation

/// Unwrapped presentation angle; only `heading` crosses the domain boundary.
nonisolated struct RouteAmendmentHeadingMotion {
    var degrees: Double = 360
    private var previousAngle: Double?
    private var origin: Double = 360
    private var hasMoved = false

    var heading: Int {
        let value = ((Int(degrees.rounded()) % 360) + 360) % 360
        return value == 0 ? 360 : value
    }

    mutating func begin(angle: Double, heading: Int?) {
        degrees = heading.map(Double.init) ?? 360
        origin = degrees
        hasMoved = false
        previousAngle = angle
    }

    mutating func move(angle: Double) -> Int? {
        guard let previousAngle else { return nil }
        var delta = (angle - previousAngle).truncatingRemainder(dividingBy: 360)
        if delta > 180 { delta -= 360 }
        if delta < -180 { delta += 360 }
        degrees -= delta
        self.previousAngle = angle
        hasMoved = hasMoved || abs(degrees - origin) >= 0.5
        return hasMoved ? heading : nil
    }

    static func coastTravel(velocity: Double, reduceMotion: Bool) -> Double {
        guard !reduceMotion, abs(velocity) >= 90 else { return 0 }
        return min(90, max(-90, velocity * 0.15))
    }
}
