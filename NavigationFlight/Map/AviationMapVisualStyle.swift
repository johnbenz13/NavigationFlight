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

    let currentLegAccentColor = UIColor.systemCyan
    let nextLegAccentColor = UIColor.systemOrange
    let previousLegAccentColor = UIColor.systemGray
    /// Semantic completion/progression action colors, kept here for future visual preferences.
    let cockpitProgressionActionBackgroundColor = UIColor(
        red: 8 / 255,
        green: 122 / 255,
        blue: 56 / 255,
        alpha: 1
    )
    let cockpitProgressionActionForegroundColor = UIColor.white
    var activeLegColor: UIColor { currentLegAccentColor }
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
    let etaCalloutBackgroundOpacity: CGFloat = 0.72
    let etaExpandedCalloutBackgroundOpacity: CGFloat = 0.90
    var etaCalloutBorderColor: UIColor { currentLegAccentColor }
    let etaCalloutBorderOpacity: CGFloat = 1
    let etaCalloutBorderWidth: CGFloat = 1.5
    let etaCalloutNameFontSize: CGFloat = 11
    let etaCalloutNameFontWeight = UIFont.Weight.medium
    let etaCalloutDurationFontSize: CGFloat = 20
    let etaCalloutDurationFontWeight = UIFont.Weight.bold
    let etaCalloutTextOpacity: CGFloat = 1

    let defaultEtaCalloutOffset = AviationMapCalloutOffset(x: -180, y: -72)

    let identificationPointSymbolSize: CGFloat = 19
    let identificationPointColor = UIColor.systemIndigo
    let identificationPointReachedColor = UIColor.systemGreen
    let identificationPointSymbolLineWidth: CGFloat = 2
    let identificationPointCalloutBackgroundColor = UIColor.systemBackground
    let identificationPointCollapsedCalloutBackgroundOpacity: CGFloat = 0.72
    let identificationPointExpandedCalloutBackgroundOpacity: CGFloat = 0.90
    var identificationPointCalloutBorderColor: UIColor { identificationPointColor }
    let identificationPointCalloutBorderOpacity: CGFloat = 0.95
    let identificationPointCalloutBorderWidth: CGFloat = 1.5
    let identificationPointCalloutTextOpacity: CGFloat = 1
    let identificationPointCalloutNameFontSize: CGFloat = 12
    let identificationPointCalloutTimeFontSize: CGFloat = 16
    let identificationPointPanelWidth: CGFloat = 300
    let etaAdjustmentStepSeconds = 5
    let defaultIdentificationPointCalloutOffset = AviationMapCalloutOffset(x: -112, y: -38)
    let identificationPointEllipseWidth: CGFloat = 34
    let identificationPointEllipseHeight: CGFloat = 20
    let identificationPointEllipseFillOpacity: CGFloat = 0.12
    let identificationPointEllipseOutlineOpacity: CGFloat = 0.95
    let identificationPointEllipseHaloColor = UIColor.white
    let identificationPointEllipseHaloOpacity: CGFloat = 0.90
    let identificationPointEllipseHaloWidth: CGFloat = 4
    let identificationPointReachedBadgeDiameter: CGFloat = 13

    func minuteTickLengthFraction(for level: AviationMapMinuteMarkLevel) -> Double {
        switch level {
        case .odd: oddMinuteTickLengthFraction
        case .even: evenMinuteTickLengthFraction
        }
    }
}
