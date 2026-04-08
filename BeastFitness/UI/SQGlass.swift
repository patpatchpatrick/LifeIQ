//
//  SQGlass.swift
//  BeastFitness
//
//  Created by Codex on 3/26/26.
//

import SwiftUI

enum SQGlassLevel {
    case card
    case floating

    fileprivate var tint: SQColor {
        switch self {
        case .card:
            return .glassCardTint
        case .floating:
            return .glassPopoverTint
        }
    }

    fileprivate var stroke: SQColor {
        switch self {
        case .card:
            return .glassStroke
        case .floating:
            return .glassStrokeStrong
        }
    }

    fileprivate var topHighlightOpacity: Double {
        switch self {
        case .card:
            return SQColor.isDarkMode ? 0.12 : 0.34
        case .floating:
            return SQColor.isDarkMode ? 0.24 : 0.40
        }
    }

    fileprivate var shadowOpacity: Double {
        switch self {
        case .card:
            return SQColor.isDarkMode ? 0.07 : 0.06
        case .floating:
            return SQColor.isDarkMode ? 0.26 : 0.14
        }
    }

    fileprivate var shadowRadius: CGFloat {
        switch self {
        case .card:
            return 10
        case .floating:
            return 24
        }
    }

    fileprivate var shadowYOffset: CGFloat {
        switch self {
        case .card:
            return 4
        case .floating:
            return 12
        }
    }
}

private struct SQGlassSurfaceModifier: ViewModifier {
    let level: SQGlassLevel
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background {
                if case .floating = level {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.regularMaterial)
                        .overlay {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .fill(level.tint.color)
                        }
                        .allowsHitTesting(false)
                } else {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(level.tint.color)
                        .allowsHitTesting(false)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(level.topHighlightOpacity),
                                Color.white.opacity(0.01)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .mask(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    )
                    .allowsHitTesting(false)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(level.stroke.color, lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .shadow(
                color: Color.black.opacity(level.shadowOpacity),
                radius: level.shadowRadius,
                x: 0,
                y: level.shadowYOffset
            )
    }
}

extension View {
    func sqGlassSurface(
        level: SQGlassLevel,
        cornerRadius: CGFloat = .SQCornerRadius.xl
    ) -> some View {
        modifier(SQGlassSurfaceModifier(level: level, cornerRadius: cornerRadius))
    }
}

struct SQDashboardBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    SQColor.dashboardGradientStart.color,
                    SQColor.dashboardGradientMid.color,
                    SQColor.dashboardGradientEnd.color
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    SQColor.dashboardGlowBlue.color.opacity(SQColor.isDarkMode ? 0.12 : 0.30),
                    .clear
                ],
                center: .topLeading,
                startRadius: 24,
                endRadius: 360
            )
            .offset(x: -40, y: -80)

            RadialGradient(
                colors: [
                    SQColor.dashboardGlowMint.color.opacity(SQColor.isDarkMode ? 0.08 : 0.18),
                    .clear
                ],
                center: .bottomTrailing,
                startRadius: 40,
                endRadius: 320
            )
            .offset(x: 80, y: 140)
        }
        .ignoresSafeArea()
    }
}

struct SQSheetBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    SQColor.sheetGradientStart.color,
                    SQColor.sheetGradientMid.color,
                    SQColor.sheetGradientEnd.color
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    SQColor.dashboardGlowBlue.color.opacity(SQColor.isDarkMode ? 0.10 : 0.18),
                    .clear
                ],
                center: .top,
                startRadius: 24,
                endRadius: 280
            )
            .offset(x: -10, y: -60)

            RadialGradient(
                colors: [
                    SQColor.dashboardGlowMint.color.opacity(SQColor.isDarkMode ? 0.06 : 0.12),
                    .clear
                ],
                center: .bottomTrailing,
                startRadius: 30,
                endRadius: 260
            )
            .offset(x: 60, y: 120)
        }
        .ignoresSafeArea()
    }
}
