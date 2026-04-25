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

    var body: some View {
        VStack(alignment: .leading, spacing: .SQSpace.m) {
            Text(displayStatusTitle)
                .sqFont(.title3)
                .sqForegroundColor(.textPrimary)

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

            Button {
                SQAppState.shared.hub.alertEvents.send(.present(viewModel.formulaAlert))
            } label: {
                HStack(spacing: .SQSpace.s) {
                    SQImageView(
                        image: .init(
                            symbol: .infoCircle,
                            symbolStyle: .colorWithFont(.dashboardGlowBlue, font: .bodyExtraSmall)
                        )
                    )
                    .frame(width: 14, height: 14)

                    Text("How this score is calculated")
                        .sqFont(.bodyExtraSmall)
                        .sqForegroundColor(.textPrimary)

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, .SQSpace.s)
            }
            .buttonStyle(.plain)
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
        Group {
            if let alert = driver.alert {
                Button {
                    SQAppState.shared.hub.alertEvents.send(.present(alert))
                } label: {
                    rowContent(showInfo: true)
                }
                .buttonStyle(.plain)
            } else {
                rowContent(showInfo: false)
            }
        }
    }

    private func rowContent(showInfo: Bool) -> some View {
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

                if showInfo {
                    SQImageView(
                        image: .init(
                            symbol: .infoCircle,
                            symbolStyle: .colorWithFont(.textSecondary, font: .bodyExtraSmall)
                        )
                    )
                    .frame(width: 12, height: 12)
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
