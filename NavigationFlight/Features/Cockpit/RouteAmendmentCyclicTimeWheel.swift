import SwiftUI
import UIKit

/// Native picker mechanics with distinct physical rows for repeated logical values.
/// Recenter only after selection settles; recentering never emits a draft intent.
struct RouteAmendmentCyclicTimeWheel: UIViewRepresentable {
    let selection: Int?
    let component: RouteAmendmentLegEntry.TimeComponent
    let onStep: (Int) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UIPickerView {
        let picker = UIPickerView()
        picker.dataSource = context.coordinator
        picker.delegate = context.coordinator
        picker.accessibilityIdentifier = "amendment-field-\(component.rawValue)"
        picker.accessibilityLabel = "Leg time \(component.rawValue)"
        context.coordinator.synchronize(picker, selection: selection)
        return picker
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UIPickerView, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? 110, height: proposal.height ?? 108)
    }

    func updateUIView(_ picker: UIPickerView, context: Context) {
        context.coordinator.parent = self
        if context.coordinator.selection != selection {
            context.coordinator.synchronize(picker, selection: selection)
        }
    }

    static func dismantleUIView(_ picker: UIPickerView, coordinator: Coordinator) {
        picker.delegate = nil
        picker.dataSource = nil
    }

    final class Coordinator: NSObject, UIPickerViewDataSource, UIPickerViewDelegate {
        var parent: RouteAmendmentCyclicTimeWheel
        var selection: Int?
        private var selectedRow = 3000
        private var specialRow = 3000

        init(_ parent: RouteAmendmentCyclicTimeWheel) { self.parent = parent }

        func synchronize(_ picker: UIPickerView, selection: Int?) {
            self.selection = selection
            selectedRow = 3000 + (selection ?? 0) % 60
            specialRow = selectedRow
            picker.reloadAllComponents()
            picker.selectRow(selectedRow, inComponent: 0, animated: false)
        }

        func numberOfComponents(in pickerView: UIPickerView) -> Int { 1 }
        func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int { 6001 }
        func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
            max(32, UIFont.preferredFont(forTextStyle: .title3).lineHeight + 8)
        }

        func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int,
                        reusing view: UIView?) -> UIView {
            let label = (view as? UILabel) ?? UILabel()
            let value = (selection == nil && row > specialRow ? row - 1 : row) % 60
            let displayed = row == specialRow ? selection : value
            label.text = displayed.map { String(format: "%02d", $0) } ?? "Not set"
            label.font = .preferredFont(forTextStyle: .title3)
            label.adjustsFontForContentSizeCategory = true
            label.textAlignment = .center
            label.textColor = .label
            label.accessibilityLabel = displayed.map { "Leg time \(parent.component.rawValue), \($0) \(parent.component.rawValue)" }
                ?? "Leg time \(parent.component.rawValue), Not set"
            return label
        }

        func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
            let steps = row - selectedRow
            guard steps != 0 else { return }
            // Update the cached selection before emitting; SwiftUI may immediately
            // synchronize the carried component in the other wheel.
            let delta = selection == nil && steps > 0 ? steps - 1 : steps
            let next = (((selection ?? 0) % 60 + delta % 60) % 60 + 60) % 60
            synchronize(pickerView, selection: next)
            parent.onStep(steps)
        }
    }
}
