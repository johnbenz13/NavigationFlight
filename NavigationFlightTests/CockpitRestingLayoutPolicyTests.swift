import CoreGraphics
import Testing
@testable import NavigationFlight

@Suite("Cockpit resting layout policy")
struct CockpitRestingLayoutPolicyTests {
    @Test("iPad portrait uses a fixed lower console and gives the map the remaining height")
    func iPadPortraitUsesFixedLowerConsole() {
        let layout = CockpitRestingLayoutPolicy.layout(
            for: .init(width: 834, height: 1_146, horizontalSizeClass: .regular)
        )

        #expect(layout.composition == .lowerConsole)
        #expect(layout.consoleExtent == 288)
        #expect(layout.mapExtent == 858)
    }

    @Test("iPad landscape uses the approved map and fixed side rail hierarchy")
    func iPadLandscapeUsesFixedSideRail() {
        let layout = CockpitRestingLayoutPolicy.layout(
            for: .init(width: 1_210, height: 802, horizontalSizeClass: .regular)
        )

        #expect(layout.composition == .sideRail)
        #expect(layout.consoleExtent == 370)
        #expect(layout.mapExtent == 840)
    }

    @Test("iPhone portrait keeps approximately two thirds of usable height for the map")
    func iPhonePortraitKeepsMapPrimary() {
        let layout = CockpitRestingLayoutPolicy.layout(
            for: .init(width: 402, height: 826, horizontalSizeClass: .compact)
        )

        #expect(layout.composition == .lowerConsole)
        #expect(layout.consoleExtent == 278)
        #expect(layout.mapExtent == 548)
        #expect(layout.mapExtent / 826 > 0.66)
    }
}
