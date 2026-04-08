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
        GridItem(.adaptive(minimum: 132), spacing: .SQSpace.s, alignment: .leading)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: .SQSpace.l) {
            HStack(alignment: .top, spacing: .SQSpace.l) {
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
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                SQRecoveryScoreBadge(score: viewModel.score, accentColor: accentColor)
            }

            VStack(alignment: .leading, spacing: .SQSpace.s) {
                Text("Factors")
                    .sqFont(.bodyExtraSmall)
                    .sqForegroundColor(.textSecondary)

                LazyVGrid(columns: driverColumns, alignment: .leading, spacing: .SQSpace.s) {
                    ForEach(viewModel.drivers) { driver in
                        SQBodyBatteryDriverCard(driver: driver)
                    }
                }
            }
        }
    }
}

private struct SQRecoveryScoreBadge: View {
    let score: Int
    let accentColor: SQColor

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            accentColor.color.opacity(SQColor.isDarkMode ? 0.05 : 0.04),
                            accentColor.color.opacity(SQColor.isDarkMode ? 0.10 : 0.10),
                            SQColor.backgroundSecondary.color.opacity(SQColor.isDarkMode ? 0.98 : 0.98)
                        ],
                        center: .center,
                        startRadius: 6,
                        endRadius: 54
                    )
                )
                .overlay {
                    Circle()
                        .stroke(accentColor.color.opacity(SQColor.isDarkMode ? 0.24 : 0.24), lineWidth: 1.5)
                }
                .shadow(
                    color: accentColor.color.opacity(SQColor.isDarkMode ? 0.10 : 0.08),
                    radius: 10,
                    x: 0,
                    y: 6
                )

            VStack(spacing: 2) {
                Text("\(score)")
                    .sqFont(.title2)
                    .sqForegroundColor(.textPrimary)

                Text("RECOVERY")
                    .sqFont(.headerSmall)
                    .sqForegroundColor(.textSecondary)
            }
        }
        .frame(width: 108, height: 108)
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
        Group {
            if let alert = driver.alert {
                Button {
                    SQAppState.shared.hub.alertEvents.send(.present(alert))
                } label: {
                    cardContent
                }
                .buttonStyle(.plain)
            } else {
                cardContent
            }
        }
    }

    private var cardContent: some View {
        HStack(alignment: .center, spacing: .SQSpace.s) {
            Circle()
                .fill(accentColor.color.opacity(SQColor.isDarkMode ? 0.9 : 0.82))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(driver.title.uppercased())
                    .sqFont(.bodyExtraSmall)
                    .sqForegroundColor(.textSecondary)

                HStack(spacing: .SQSpace.xs) {
                    Text(driver.valueText)
                        .sqFont(.bodySmallSemiBold)
                        .sqForegroundColor(.textPrimary)

                    if let symbol = driver.symbol {
                        SQImageView(
                            image: .init(
                                symbol: symbol,
                                symbolStyle: .colorWithFont(accentColor, font: .bodyExtraSmall)
                            )
                        )
                        .frame(width: 10, height: 10)
                    }
                }
            }

            Spacer(minLength: 0)

            if driver.alert != nil {
                SQImageView(
                    image: .init(
                        symbol: .infoCircle,
                        symbolStyle: .colorWithFont(.textSecondary, font: .bodyExtraSmall)
                    )
                )
                .frame(width: 12, height: 12)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, .SQSpace.m)
        .padding(.vertical, .SQSpace.m)
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
