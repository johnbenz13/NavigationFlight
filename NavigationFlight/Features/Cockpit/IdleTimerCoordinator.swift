import Foundation
import UIKit

@MainActor
protocol IdleTimerControlling: AnyObject {
    var isIdleTimerDisabled: Bool { get set }
}

@MainActor
final class UIApplicationIdleTimerController: IdleTimerControlling {
    var isIdleTimerDisabled: Bool {
        get { UIApplication.shared.isIdleTimerDisabled }
        set { UIApplication.shared.isIdleTimerDisabled = newValue }
    }
}

@MainActor
final class IdleTimerCoordinator {
    private let controller: any IdleTimerControlling
    private var synchronizedValue: Bool?

    init(controller: any IdleTimerControlling) {
        self.controller = controller
    }

    func synchronize(isAcceptedFlightInProgress: Bool) {
        guard synchronizedValue != isAcceptedFlightInProgress else { return }
        controller.isIdleTimerDisabled = isAcceptedFlightInProgress
        synchronizedValue = isAcceptedFlightInProgress
    }

    func teardown() {
        controller.isIdleTimerDisabled = false
        synchronizedValue = false
    }
}
