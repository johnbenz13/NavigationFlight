import UIKit

enum AviationMapMinuteMarkLevel: Equatable, Sendable {
    case odd
    case even
}

struct AviationMapCalloutOffset: Equatable, Sendable {
    let x: Double
    let y: Double

    func translated(x deltaX: Double, y deltaY: Double) -> AviationMapCalloutOffset {
        AviationMapCalloutOffset(x: x + deltaX, y: y + deltaY)
    }
}

struct AviationMapVisualStyle {
    static let `default` = AviationMapVisualStyle()

    let activeLegColor = UIColor.systemCyan
    let activeLegWidth: CGFloat = 6

    let destinationWaypointRadius: CGFloat = 17
    let destinationWaypointFillColor = UIColor.systemBackground
    let destinationWaypointFillOpacity: CGFloat = 0.20
    let destinationWaypointStrokeColor = UIColor.label
    let destinationWaypointStrokeOpacity: CGFloat = 1
    let destinationWaypointStrokeWidth: CGFloat = 3

    let oddMinuteTickLengthFraction = 0.014
    let evenMinuteTickLengthFraction = 0.026
    let minuteTickColor = UIColor.systemCyan
    let minuteTickWidth: CGFloat = 2.5
    let minuteTickCasingColor = UIColor.white
    let minuteTickCasingOpacity: CGFloat = 0.9
    let minuteTickCasingWidth: CGFloat = 5
    let minuteLabelFontSize: CGFloat = 14
    let minuteLabelFontWeight = UIFont.Weight.bold

    let etaCalloutBackgroundColor = UIColor.systemBackground
    let etaCalloutBackgroundOpacity: CGFloat = 0.20
    let etaCalloutBorderColor = UIColor.label
    let etaCalloutBorderOpacity: CGFloat = 1
    let etaCalloutBorderWidth: CGFloat = 1.5
    let etaCalloutNameFontSize: CGFloat = 11
    let etaCalloutNameFontWeight = UIFont.Weight.medium
    let etaCalloutDurationFontSize: CGFloat = 20
    let etaCalloutDurationFontWeight = UIFont.Weight.bold
    let etaCalloutTextOpacity: CGFloat = 1

    let defaultEtaCalloutOffset = AviationMapCalloutOffset(x: -95, y: -52)

    func minuteTickLengthFraction(for level: AviationMapMinuteMarkLevel) -> Double {
        switch level {
        case .odd: oddMinuteTickLengthFraction
        case .even: evenMinuteTickLengthFraction
        }
    }
}
