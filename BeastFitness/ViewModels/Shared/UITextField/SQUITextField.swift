//
//  SQUITextField.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 1/6/26.
//

import SwiftUI
import UIKit

@MainActor
struct SQUITextField: View {

    @ObservedObject var viewModel: SQUITextFieldViewModel
    @State private var borderWidth: CGFloat = 0

    /// Optional fixed width applied to the field. Prefer this over `.frame(width:)` on the call site.
    var width: CGFloat? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {

            if let errorText = viewModel.textFieldState.errorText {
                Text(errorText)
                    .sqFont(.bodySmall)
                    .sqForegroundColor(.colorErrorRed)
                    .transition(.opacity)
            }

            ZStack(alignment: .bottomTrailing) {
                SQUITextFieldRepresentable(viewModel: viewModel, fixedWidth: width)
                    .sqForegroundColor(viewModel.uiConfig.textColor)
                    .sqTintColor(viewModel.uiConfig.tintColor)
                    .sqBackgroundColor(viewModel.uiConfig.backgroundColor)
                    .cornerRadius(.SQCornerRadius.m)
                    .sqBorder(
                        viewModel.borderColor ?? .border(1),
                        width: borderWidth,
                        cornerRadius: viewModel.uiConfig.cornerRadius
                    )
                    .onChange(of: viewModel.textFieldState) { _, newState in
                        withAnimation {
                            borderWidth = newState.isFocused
                                ? (viewModel.uiConfig.borderWidth)
                                : 0
                        }
                    }

                if let max = viewModel.maxCharacterCountToShow {
                    Text(viewModel.characterCountText)
                        .sqFont(.bodySmall)
                        .sqForegroundColor(.textTertiary)
                        .padding(.trailing, 8)
                        .padding(.bottom, 6)
                        .transition(.opacity)
                        .accessibilityLabel("Character count \(viewModel.characterCountText) of \(max)")
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.textFieldState)
    }
}

private final class SQPaddedTextField: UITextField {
    var textInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)

    override func textRect(forBounds bounds: CGRect) -> CGRect {
        bounds.inset(by: textInsets)
    }

    override func editingRect(forBounds bounds: CGRect) -> CGRect {
        bounds.inset(by: textInsets)
    }

    override func placeholderRect(forBounds bounds: CGRect) -> CGRect {
        bounds.inset(by: textInsets)
    }
}

private struct SQUITextFieldRepresentable: UIViewRepresentable {

    let viewModel: SQUITextFieldViewModel
    var fixedWidth: CGFloat? = nil

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextField, context: Context) -> CGSize? {
        guard let fixedWidth else { return nil }
        let height = uiView.intrinsicContentSize.height // 20 = top + bottom insets
        return CGSize(width: fixedWidth, height: height)
    }

    func makeUIView(context: Context) -> UITextField {
        let tf = SQPaddedTextField()
        tf.delegate = context.coordinator
        tf.borderStyle = .none
        tf.backgroundColor = .clear

        tf.addTarget(context.coordinator,
                     action: #selector(Coordinator.textDidChange(_:)),
                     for: .editingChanged)

        viewModel.bind(textField: tf)
        context.coordinator.configureSecureToggleIfNeeded(for: tf)
        return tf
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        // Sync text if VM changed programmatically
        if uiView.text != viewModel.text {
            uiView.text = viewModel.text
        }

        // Keep config current (in case you swap VM props)
        viewModel.bind(textField: uiView)
        context.coordinator.configureSecureToggleIfNeeded(for: uiView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        let viewModel: SQUITextFieldViewModel
        private var pendingSelectAll: DispatchWorkItem?
        private weak var secureToggleButton: UIButton?

        init(viewModel: SQUITextFieldViewModel) {
            self.viewModel = viewModel
        }

        deinit {
            pendingSelectAll?.cancel()
        }

        @objc func textDidChange(_ sender: UITextField) {
            viewModel.userDidEditText(sender.text ?? "")
        }

        @objc func secureToggleTapped() {
            viewModel.toggleSecureTextVisibility()
            updateSecureToggleImage()
        }

        func configureSecureToggleIfNeeded(for textField: UITextField) {
            guard viewModel.shouldShowSecureTextToggle else {
                secureToggleButton = nil
                textField.rightView = nil
                textField.rightViewMode = .never
                return
            }

            let button: UIButton
            if let existingButton = secureToggleButton {
                button = existingButton
            } else {
                let createdButton = UIButton(type: .system)
                createdButton.frame = CGRect(x: 0, y: 0, width: 28, height: 28)
                createdButton.contentEdgeInsets = UIEdgeInsets(top: 6, left: 6, bottom: 6, right: 6)
                createdButton.addTarget(self, action: #selector(secureToggleTapped), for: .touchUpInside)
                secureToggleButton = createdButton
                button = createdButton
            }

            button.tintColor = viewModel.uiConfig.placeholderColor.uiColor
            button.setPreferredSymbolConfiguration(
                UIImage.SymbolConfiguration(pointSize: 12, weight: .regular),
                forImageIn: .normal
            )
            textField.rightView = button
            textField.rightViewMode = .always
            updateSecureToggleImage()
        }

        private func updateSecureToggleImage() {
            guard let button = secureToggleButton else { return }
            button.setImage(
                SQImage(symbol: viewModel.secureTextToggleSymbol, color: viewModel.uiConfig.placeholderColor).image,
                for: .normal
            )
            button.accessibilityLabel = viewModel.isSecureTextVisible ? "Hide password" : "Show password"
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            viewModel.userDidBeginEditing()

            guard viewModel.selectAllOnFocus else { return }
            pendingSelectAll?.cancel()

            let work = DispatchWorkItem { [weak textField] in
                guard let textField else { return }
                guard textField.isFirstResponder, textField.window != nil else { return }
                textField.selectAll(nil)
            }
            pendingSelectAll = work
            DispatchQueue.main.async(execute: work)
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            pendingSelectAll?.cancel()
            pendingSelectAll = nil
            viewModel.userDidEndEditing()
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            pendingSelectAll?.cancel()
            pendingSelectAll = nil
            textField.resignFirstResponder()
            return true
        }
    }
}
