import Testing
@testable import NavigationFlight

@Suite("Position Check permission education")
struct PositionCheckPermissionStateTests {
    @Test("Education can request When In Use authorization")
    func educationRequestsAuthorization() {
        var state = AppFeatureState()
        state.presentPositionCheckPermissionEducation()

        let effect = state.handlePositionCheckPermissionIntent(.requestWhenInUse)

        #expect(effect == .requestWhenInUseAuthorization)
        #expect(state.positionCheckPermissionEducation == .completed)
    }

    @Test("Declining education continues manually without blocking cockpit")
    func decliningContinuesManually() {
        var state = AppFeatureState(selectedAppSection: .cockpit)
        state.presentPositionCheckPermissionEducation()

        let effect = state.handlePositionCheckPermissionIntent(.continueManually)

        #expect(effect == nil)
        #expect(state.selectedAppSection == .cockpit)
        #expect(state.positionCheckPermissionEducation == .completed)
    }

    @Test("Denied permission can route to Settings without changing cockpit state")
    func deniedPermissionOpensSettings() {
        var state = AppFeatureState(selectedAppSection: .cockpit)

        let effect = state.handlePositionCheckPermissionIntent(.openSettings)

        #expect(effect == .openSystemSettings)
        #expect(state.selectedAppSection == .cockpit)
    }
}
