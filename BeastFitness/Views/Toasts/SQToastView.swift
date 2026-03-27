//
//  SQToastView.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/17/25.
//

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

struct SQToastView: View {
    let toast: SQToastViewModel
    let onDismiss: () -> Void

    private var accentColor: SQColor {
        switch toast.style {
        case .success:
            return .dashboardGlowMint
        case .error:
            return .dashboardTrendWarm
        case .warning:
            return .textWarning
        case .normal:
            return .dashboardGlowBlue
        }
    }

    private var statusTitle: String {
        switch toast.style {
        case .success:
            return "Success"
        case .error:
            return "Error"
        case .warning:
            return "Notice"
        case .normal:
            return "Update"
        }
    }

    private var symbol: SQImageSymbol {
        switch toast.style {
        case .success:
            return .checkmarkCircleFill
        case .error:
            return .xmarkCircleFill
        case .warning:
            return .exclamationmarkTriangleFill
        case .normal:
            return .exclamationmarkCircle
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: .SQSpace.m) {
            RoundedRectangle(cornerRadius: .SQCornerRadius.m, style: .continuous)
                .fill(accentColor.color.opacity(SQColor.isDarkMode ? 0.20 : 0.14))
                .frame(width: 36, height: 36)
                .overlay {
                    RoundedRectangle(cornerRadius: .SQCornerRadius.m, style: .continuous)
                        .stroke(SQColor.glassStrokeStrong.color, lineWidth: 1)
                }
                .overlay {
                    SQImageView(
                        image: .init(
                            symbol: symbol,
                            symbolStyle: .colorWithFont(accentColor, font: .body)
                        )
                    )
                    .frame(width: 18, height: 18)
                }

            VStack(alignment: .leading, spacing: .SQSpace.xs) {
                Text(statusTitle)
                    .sqFont(.bodyExtraSmall)
                    .sqForegroundColor(accentColor)
                    .padding(.horizontal, .SQSpace.s)
                    .padding(.vertical, 4)
                    .background {
                        Capsule(style: .continuous)
                            .fill(accentColor.color.opacity(SQColor.isDarkMode ? 0.16 : 0.12))
                            .overlay {
                                Capsule(style: .continuous)
                                    .stroke(SQColor.glassStrokeStrong.color, lineWidth: 1)
                            }
                    }

                Text(toast.title)
                    .sqFont(.bodySmallSemiBold)
                    .sqForegroundColor(.textPrimary)

                if let subtitle = toast.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .sqFont(.bodyExtraSmall)
                        .sqForegroundColor(.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)

            if toast.isUserDismissable {
                Button(action: onDismiss) {
                    Circle()
                        .fill(accentColor.color.opacity(SQColor.isDarkMode ? 0.16 : 0.12))
                        .frame(width: 28, height: 28)
                        .overlay {
                            Circle()
                                .stroke(SQColor.glassStrokeStrong.color, lineWidth: 1)
                        }
                        .overlay {
                            SQImageView(
                                image: .init(
                                    symbol: .xMark,
                                    symbolStyle: .colorWithFont(accentColor, font: .bodyExtraSmall)
                                )
                            )
                            .frame(width: 10, height: 10)
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, .SQSpace.l)
        .padding(.vertical, .SQSpace.m)
        .background {
            RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous)
                .fill(SQColor.glassPopoverTint.color.opacity(SQColor.isDarkMode ? 0.96 : 1))
                .overlay {
                    RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(SQColor.isDarkMode ? 0.08 : 0.14),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: .SQCornerRadius.s, style: .continuous)
                        .fill(accentColor.color.opacity(SQColor.isDarkMode ? 0.9 : 0.7))
                        .frame(width: 4)
                        .padding(.vertical, .SQSpace.m)
                        .padding(.leading, .SQSpace.s)
                }
        }
        .sqGlassSurface(level: .floating, cornerRadius: .SQCornerRadius.xl)
        .shadow(
            color: accentColor.color.opacity(SQColor.isDarkMode ? 0.24 : 0.16),
            radius: 24,
            x: 0,
            y: 12
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if toast.isUserDismissable {
                onDismiss()
            }
        }
    }
}
