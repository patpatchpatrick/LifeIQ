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
                .fill(accentColor.color.opacity(SQColor.isDarkMode ? 0.14 : 0.12))
                .frame(width: 36, height: 36)
                .overlay {
                    RoundedRectangle(cornerRadius: .SQCornerRadius.m, style: .continuous)
                        .stroke(accentColor.color.opacity(SQColor.isDarkMode ? 0.32 : 0.24), lineWidth: 1)
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
                            .fill(accentColor.color.opacity(SQColor.isDarkMode ? 0.12 : 0.10))
                            .overlay {
                                Capsule(style: .continuous)
                                    .stroke(SQColor.glassStroke.color.opacity(0.72), lineWidth: 1)
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
                        .fill(SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.68 : 0.90))
                        .frame(width: 28, height: 28)
                        .overlay {
                            Circle()
                                .stroke(SQColor.glassStroke.color.opacity(0.78), lineWidth: 1)
                        }
                        .overlay {
                            SQImageView(
                                image: .init(
                                    symbol: .xMark,
                                    symbolStyle: .colorWithFont(.textTertiary, font: .bodyExtraSmall)
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
                .fill(
                    LinearGradient(
                        colors: [
                            SQColor.sheetGradientMid.color.opacity(SQColor.isDarkMode ? 0.98 : 0.96),
                            SQColor.sheetGradientEnd.color.opacity(SQColor.isDarkMode ? 0.96 : 0.94)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous)
                        .fill(SQColor.glassPopoverTint.color.opacity(SQColor.isDarkMode ? 0.30 : 0.62))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(SQColor.isDarkMode ? 0.045 : 0.14),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: .SQCornerRadius.s, style: .continuous)
                        .fill(accentColor.color.opacity(SQColor.isDarkMode ? 0.72 : 0.52))
                        .frame(width: 4)
                        .padding(.vertical, .SQSpace.m)
                        .padding(.leading, .SQSpace.s)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous)
                        .stroke(SQColor.glassStrokeStrong.color.opacity(SQColor.isDarkMode ? 0.52 : 0.66), lineWidth: 1)
                }
        }
        .shadow(
            color: Color.black.opacity(SQColor.isDarkMode ? 0.16 : 0.10),
            radius: 16,
            x: 0,
            y: 8
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if toast.isUserDismissable {
                onDismiss()
            }
        }
    }
}
