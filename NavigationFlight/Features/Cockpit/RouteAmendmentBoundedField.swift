import SwiftUI
import UIKit

struct RouteAmendmentBoundedField: UIViewRepresentable {
    let label: String
    let placeholder: String
    let keyboard: UIKeyboardType
    let field: RouteAmendmentLegEntry.Field
    @Binding var focus: RouteAmendmentLegEntry.Field?
    @Binding var text: String
    let accepts: (String) -> Bool

    func makeCoordinator() -> Coordinator { Coordinator(field: self) }

    func makeUIView(context: Context) -> UITextField {
        let view = UITextField()
        view.delegate = context.coordinator
        view.addTarget(context.coordinator, action: #selector(Coordinator.textChanged(_:)), for: .editingChanged)
        view.textAlignment = .center
        view.autocorrectionType = .no
        view.autocapitalizationType = .none
        view.font = UIFontMetrics(forTextStyle: .title2).scaledFont(
            for: .monospacedDigitSystemFont(ofSize: 22, weight: .bold)
        )
        view.adjustsFontForContentSizeCategory = true
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.accessibilityIdentifier = "amendment-field-\(field.rawValue)"
        return view
    }

    func updateUIView(_ view: UITextField, context: Context) {
        context.coordinator.field = self
        view.placeholder = placeholder
        view.keyboardType = keyboard
        view.accessibilityLabel = label
        if view.text != text { view.text = text }
        if focus != field, view.isFirstResponder { view.resignFirstResponder() }
    }

    @MainActor
    final class Coordinator: NSObject, UITextFieldDelegate {
        var field: RouteAmendmentBoundedField

        init(field: RouteAmendmentBoundedField) {
            self.field = field
        }

        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange,
                       replacementString replacement: String) -> Bool {
            let current = textField.text ?? ""
            guard let change = Range(range, in: current) else { return false }
            return field.accepts(current.replacingCharacters(in: change, with: replacement))
        }

        @objc func textChanged(_ textField: UITextField) {
            field.text = textField.text ?? ""
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            field.focus = field.field
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            if field.focus == field.field { field.focus = nil }
        }
    }
}
