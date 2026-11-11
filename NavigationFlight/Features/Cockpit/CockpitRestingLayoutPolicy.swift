import CoreGraphics

struct CockpitRestingLayoutPolicy: Equatable, Sendable {
    enum HorizontalSizeClass: Equatable, Sendable {
        case compact
        case regular
    }

    enum Composition: Equatable, Sendable {
        case lowerConsole
        case sideRail
    }

    struct Context: Equatable, Sendable {
        let width: CGFloat
        let height: CGFloat
        let horizontalSizeClass: HorizontalSizeClass
    }

    let composition: Composition
    let mapExtent: CGFloat
    let consoleExtent: CGFloat

    static func layout(for context: Context) -> CockpitRestingLayoutPolicy {
        if context.horizontalSizeClass == .regular, context.width > context.height {
            let consoleExtent: CGFloat = min(370, context.width)
            return CockpitRestingLayoutPolicy(
                composition: .sideRail,
                mapExtent: max(0, context.width - consoleExtent),
                consoleExtent: consoleExtent
            )
        }

        if context.horizontalSizeClass == .compact {
            let consoleExtent: CGFloat = min(278, context.height)
            return CockpitRestingLayoutPolicy(
                composition: .lowerConsole,
                mapExtent: max(0, context.height - consoleExtent),
                consoleExtent: consoleExtent
            )
        }

        let consoleExtent: CGFloat = 288
        return CockpitRestingLayoutPolicy(
            composition: .lowerConsole,
            mapExtent: max(0, context.height - consoleExtent),
            consoleExtent: consoleExtent
        )
    }
}
