//
//  SQToastView.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/17/25.
//

import SwiftUI

import SwiftUI

struct SQToastHostView: View {
    @Bindable var toasts: SQToastState

    var body: some View {
        ZStack(alignment: .bottom) {
            if let toast = toasts.current {
                SQToastView(
                    toast: toast,
                    onDismiss: { toasts.dismissCurrent() }
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 50)          // spacing above bottom edge
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .onAppear {
                    scheduleAutoDismiss(for: toast)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .ignoresSafeArea(edges: .bottom) // ensures it can sit on the safe-area edge cleanly
        .animation(.easeInOut(duration: 0.18), value: toasts.isPresented)
    }

    private func scheduleAutoDismiss(for toast: SQToastViewModel) {
        guard toast.duration > 0 else { return }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(toast.duration * 1_000_000_000))
            if toasts.current?.id == toast.id {
                toasts.dismissCurrent()
            }
        }
    }
}


import SwiftUI

struct SQToastView: View {
    let toast: SQToastViewModel
    let onDismiss: () -> Void

    private var backgroundColor: Color {
        switch toast.style {
        case .success:
            return Color.green
        case .error:
            return Color.red
        case .warning:
            return Color.orange
        case .normal:
            return Color.black.opacity(0.85)
        }
    }

    private var foregroundColor: Color {
        switch toast.style {
        case .success, .error, .warning:
            return .white
        case .normal:
            return .white
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(toast.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(foregroundColor)

                if let subtitle = toast.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundColor(foregroundColor.opacity(0.9))
                }
            }

            Spacer(minLength: 0)

            if toast.isUserDismissable {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(foregroundColor)
                        .padding(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(radius: 18)
        .contentShape(Rectangle())
        .onTapGesture {
            if toast.isUserDismissable {
                onDismiss()
            }
        }
    }
}

