//
//  SQAppBlockerHost.swift
//  BeastFitness
//
//  Created by Codex on 4/10/26.
//

import SwiftUI

struct SQAppBlockerHost: View {
    @Bindable var blockerState: SQAppBlockerState

    var body: some View {
        ZStack {
            if let blocker = blockerState.current {
                ZStack {
                    Color.black
                        .opacity(SQColor.isDarkMode ? 0.52 : 0.28)

                    LinearGradient(
                        colors: [
                            SQColor.dashboardGlowBlue.color.opacity(SQColor.isDarkMode ? 0.20 : 0.12),
                            Color.clear,
                            SQColor.dashboardGlowMint.color.opacity(SQColor.isDarkMode ? 0.12 : 0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
                .background(.ultraThinMaterial)
                .ignoresSafeArea()

                blockerCard(blocker)
                    .padding(.horizontal, .SQSpace.xl)
                    .transition(.scale(scale: 0.97).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.18), value: blockerState.isPresented)
        .zIndex(20_000)
    }

    private func blockerCard(_ blocker: SQAppBlockerViewModel) -> some View {
        VStack(spacing: .SQSpace.xl) {
            VStack(spacing: .SQSpace.m) {
                headerBadge(blocker)

                ZStack {
                    Circle()
                        .fill(accentColor(for: blocker).color.opacity(SQColor.isDarkMode ? 0.24 : 0.14))
                        .frame(width: 84, height: 84)

                    Circle()
                        .stroke(accentColor(for: blocker).color.opacity(SQColor.isDarkMode ? 0.32 : 0.20), lineWidth: 1)
                        .frame(width: 84, height: 84)

                    SQImageView(
                        image: .init(
                            symbol: .exclamationmarkTriangleFill,
                            symbolStyle: .colorWithFont(accentForegroundColor(for: blocker), font: .title3)
                        )
                    )
                    .frame(width: 34, height: 34)
                }

                VStack(spacing: .SQSpace.s) {
                    Text(blocker.title)
                        .sqFont(.title2)
                        .sqForegroundColor(.textPrimary)
                        .multilineTextAlignment(.center)

                    Text(blocker.message)
                        .sqFont(.body)
                        .sqForegroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }

            if let primaryButtonTitle = blocker.primaryButtonTitle {
                SQButton(style: .glassPrimary, title: primaryButtonTitle) {
                    blockerState.handlePrimaryAction()
                }
            }
        }
        .frame(maxWidth: 360)
        .padding(.horizontal, .SQSpace.xl)
        .padding(.vertical, .SQSpace.xxl)
        .background {
            RoundedRectangle(cornerRadius: .SQCornerRadius.xxl, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(SQColor.isDarkMode ? 0.12 : 0.26),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .mask(
                    RoundedRectangle(cornerRadius: .SQCornerRadius.xxl, style: .continuous)
                )
        }
        .sqGlassSurface(level: .floating, cornerRadius: .SQCornerRadius.xxl)
        .shadow(
            color: accentColor(for: blocker).color.opacity(SQColor.isDarkMode ? 0.24 : 0.12),
            radius: 32,
            x: 0,
            y: 18
        )
    }

    private func headerBadge(_ blocker: SQAppBlockerViewModel) -> some View {
        HStack(spacing: .SQSpace.xs) {
            Circle()
                .fill(accentColor(for: blocker).color)
                .frame(width: 8, height: 8)

            Text(blocker.kind == .forceUpdate ? "Update Required" : "Maintenance")
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textSecondary)
                .textCase(.uppercase)
        }
        .padding(.horizontal, .SQSpace.m)
        .padding(.vertical, .SQSpace.xs)
        .background {
            Capsule(style: .continuous)
                .fill(accentColor(for: blocker).color.opacity(SQColor.isDarkMode ? 0.16 : 0.12))
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(SQColor.glassStroke.color, lineWidth: 1)
                }
        }
    }

    private func accentColor(for blocker: SQAppBlockerViewModel) -> SQColor {
        switch blocker.kind {
        case .appDisabled:
            return .dashboardTrendWarm
        case .forceUpdate:
            return .dashboardGlowBlue
        }
    }

    private func accentForegroundColor(for blocker: SQAppBlockerViewModel) -> SQColor {
        switch blocker.kind {
        case .appDisabled:
            return .textPrimary
        case .forceUpdate:
            return .dashboardGlowBlueForeground
        }
    }
}
