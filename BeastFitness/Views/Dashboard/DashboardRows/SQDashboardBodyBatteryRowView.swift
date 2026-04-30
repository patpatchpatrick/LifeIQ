//
//  SQDashboardBodyBatteryRowView.swift
//  BeastFitness
//

import SwiftUI

struct SQDashboardBodyBatteryRowView: View {
    @Bindable var viewModel: SQDashboardBodyBatteryRowViewModel

    private var displayStatusTitle: String {
        switch viewModel.statusTitle {
        case "Solid":
            return "Strong"
        default:
            return viewModel.statusTitle
        }
    }

    private var statusColor: SQColor {
        switch viewModel.statusTone {
        case .positive:
            return .dashboardGlowMint
        case .negative:
            return .dashboardTrendWarm
        case .neutral:
            return .dashboardGlowBlue
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .SQSpace.m) {
            HStack(alignment: .firstTextBaseline, spacing: .SQSpace.s) {
                Text(displayStatusTitle)
                    .sqFont(.bodySmallSemiBold)
                    .sqForegroundColor(statusColor)

                if let score = viewModel.score {
                    Text("\(score)/100")
                        .sqFont(.bodyExtraSmall)
                        .sqForegroundColor(.textSecondary)
                }
            }
            .padding(.horizontal, .SQSpace.s)
            .padding(.vertical, .SQSpace.xs)
            .background {
                Capsule(style: .continuous)
                    .fill(statusColor.color.opacity(SQColor.isDarkMode ? 0.14 : 0.10))
                    .overlay {
                        Capsule(style: .continuous)
                            .stroke(statusColor.color.opacity(SQColor.isDarkMode ? 0.28 : 0.18), lineWidth: 1)
                    }
            }

            if let warning = viewModel.dataQualityWarning {
                HStack(alignment: .top, spacing: .SQSpace.s) {
                    SQImageView(
                        image: .init(
                            symbol: .infoCircle,
                            symbolStyle: .colorWithFont(.dashboardTrendWarm, font: .bodyExtraSmall)
                        )
                    )
                    .frame(width: 14, height: 14)
                    .padding(.top, 1)

                    Text(warning)
                        .sqFont(.bodyExtraSmall)
                        .sqForegroundColor(.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.SQSpace.m)
                .background {
                    RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                        .fill(SQColor.dashboardTrendWarm.color.opacity(SQColor.isDarkMode ? 0.10 : 0.08))
                        .overlay {
                            RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                                .stroke(SQColor.dashboardTrendWarm.color.opacity(SQColor.isDarkMode ? 0.22 : 0.16), lineWidth: 1)
                        }
                }
            }

            VStack(alignment: .leading, spacing: .SQSpace.xs) {
                ForEach(viewModel.drivers) { driver in
                    RecoveryDriverRow(driver: driver)
                }
            }
        }
    }
}

private struct RecoveryDriverRow: View {
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
        rowContent()
    }

    private func rowContent() -> some View {
        HStack(alignment: .firstTextBaseline, spacing: .SQSpace.s) {
            Text(driver.title)
                .sqFont(.bodySmall)
                .sqForegroundColor(.textPrimary)

            Spacer(minLength: 0)

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
        .padding(.vertical, .SQSpace.s)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(SQColor.glassStroke.color.opacity(0.45))
                .frame(height: 1)
        }
    }
}
