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

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {

            if let errorText = viewModel.textFieldState.errorText {
                Text(errorText)
                    .sqFont(.bodySmall)
                    .sqForegroundColor(.colorErrorRed)
                    .transition(.opacity)
            }

            ZStack(alignment: .bottomTrailing) {
                SQUITextFieldRepresentable(viewModel: viewModel)
                    .sqForegroundColor(viewModel.uiConfig.textColor)
                    .sqTintColor(viewModel.uiConfig.tintColor)
                    .sqBackgroundColor(viewModel.uiConfig.backgroundColor)
                    .cornerRadius(.SQCornerRadius.m)
                    .sqBorder(
                        viewModel.borderColor ?? .border,
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

private struct SQUITextFieldRepresentable: UIViewRepresentable {

    let viewModel: SQUITextFieldViewModel

    func makeUIView(context: Context) -> UITextField {
        let tf = UITextField()
        tf.delegate = context.coordinator
        tf.borderStyle = .none
        tf.backgroundColor = .clear

        tf.addTarget(context.coordinator,
                     action: #selector(Coordinator.textDidChange(_:)),
                     for: .editingChanged)

        viewModel.bind(textField: tf)
        return tf
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        // Sync text if VM changed programmatically
        if uiView.text != viewModel.text {
            uiView.text = viewModel.text
        }

        // Keep config current (in case you swap VM props)
        viewModel.bind(textField: uiView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        let viewModel: SQUITextFieldViewModel
        private var pendingSelectAll: DispatchWorkItem?

        init(viewModel: SQUITextFieldViewModel) {
            self.viewModel = viewModel
        }

        deinit {
            pendingSelectAll?.cancel()
        }

        @objc func textDidChange(_ sender: UITextField) {
            viewModel.userDidEditText(sender.text ?? "")
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

