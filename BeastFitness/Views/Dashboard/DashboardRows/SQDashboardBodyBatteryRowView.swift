//
//  SQDashboardBodyBatteryRowView.swift
//  BeastFitness
//

import SwiftUI

struct SQDashboardBodyBatteryRowView: View {
    @Bindable var viewModel: SQDashboardBodyBatteryRowViewModel

    private var accentColor: SQColor {
        switch viewModel.statusTone {
        case .positive:
            return .dashboardGlowMint
        case .negative:
            return .dashboardTrendWarm
        case .neutral:
            return .dashboardGlowBlue
        }
    }

    private var statusSymbol: SQImageSymbol? {
        switch viewModel.statusTone {
        case .positive:
            return .arrowUp
        case .negative:
            return .arrowDown
        case .neutral:
            return nil
        }
    }

    private let driverColumns = [
        GridItem(.adaptive(minimum: 108), spacing: .SQSpace.s, alignment: .leading)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: .SQSpace.l) {
            HStack(alignment: .center, spacing: .SQSpace.xl) {
                SQBodyBatteryGauge(score: viewModel.score, accentColor: accentColor)

                VStack(alignment: .leading, spacing: .SQSpace.s) {
                    SQDashboardTrendBadge(
                        text: viewModel.statusTitle,
                        tone: viewModel.statusTone,
                        symbol: statusSymbol
                    )

                    Text(viewModel.headline)
                        .sqFont(.title3)
                        .sqForegroundColor(.textPrimary)

                    Text(viewModel.summary)
                        .sqFont(.bodyExtraSmall)
                        .sqForegroundColor(.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            LazyVGrid(columns: driverColumns, alignment: .leading, spacing: .SQSpace.s) {
                ForEach(viewModel.drivers) { driver in
                    SQBodyBatteryDriverCard(driver: driver)
                }
            }

            Text(viewModel.footer)
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textDisabled)
        }
    }
}

private struct SQBodyBatteryGauge: View {
    let score: Int
    let accentColor: SQColor

    private let bodyWidth: CGFloat = 132
    private let bodyHeight: CGFloat = 160

    var body: some View {
        VStack(spacing: .SQSpace.xs) {
            Capsule(style: .continuous)
                .fill(accentColor.color.opacity(SQColor.isDarkMode ? 0.55 : 0.32))
                .frame(width: 44, height: 8)
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(SQColor.glassStrokeStrong.color, lineWidth: 1)
                }

            ZStack {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.82 : 1))
                    .overlay {
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .stroke(SQColor.glassStrokeStrong.color, lineWidth: 1)
                    }

                GeometryReader { proxy in
                    let fillHeight = max(18, (proxy.size.height - 16) * CGFloat(score) / 100)

                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    accentColor.color.opacity(SQColor.isDarkMode ? 0.22 : 0.16),
                                    accentColor.color.opacity(SQColor.isDarkMode ? 0.86 : 0.58)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(SQColor.isDarkMode ? 0.18 : 0.30),
                                            Color.clear
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        .frame(width: proxy.size.width - 18, height: fillHeight)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 8)
                }
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                .allowsHitTesting(false)

                VStack(spacing: 2) {
                    Text("\(score)")
                        .sqFont(.title1)
                        .sqForegroundColor(.textPrimary)

                    Text("Current")
                        .sqFont(.bodyExtraSmall)
                        .sqForegroundColor(.textSecondary)
                }
                .padding(.horizontal, .SQSpace.m)
                .padding(.vertical, .SQSpace.s)
                .background {
                    RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                        .fill(SQColor.glassPopoverTint.color.opacity(SQColor.isDarkMode ? 0.92 : 1))
                        .overlay {
                            RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                                .stroke(SQColor.glassStrokeStrong.color, lineWidth: 1)
                        }
                }
            }
            .frame(width: bodyWidth, height: bodyHeight)
            .shadow(
                color: accentColor.color.opacity(SQColor.isDarkMode ? 0.18 : 0.10),
                radius: 18,
                x: 0,
                y: 10
            )
        }
    }
}

private struct SQBodyBatteryDriverCard: View {
    let driver: SQDashboardBodyBatteryRowViewModel.Driver

    private var accentColor: SQColor {
        switch driver.tone {
        case .positive:
            return .dashboardGlowMint
        case .negative:
            return .dashboardTrendWarm
        case .neutral:
            return .dashboardGlowBlue
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .SQSpace.xs) {
            Text(driver.title.uppercased())
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textSecondary)

            HStack(spacing: .SQSpace.xs) {
                if let symbol = driver.symbol {
                    SQImageView(
                        image: .init(
                            symbol: symbol,
                            symbolStyle: .colorWithFont(accentColor, font: .bodyExtraSmall)
                        )
                    )
                    .frame(width: 10, height: 10)
                }

                Text(driver.valueText)
                    .sqFont(.bodySmallSemiBold)
                    .sqForegroundColor(.textPrimary)
            }

            Text(driver.detailText)
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textSecondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, .SQSpace.m)
        .padding(.vertical, .SQSpace.s)
        .background {
            RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                .fill(SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.70 : 0.96))
                .overlay {
                    RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                        .stroke(SQColor.glassStroke.color, lineWidth: 1)
                }
        }
    }
}
