//
//  SQLeaderboardRowView.swift
//  BeastFitness
//
//  Created by Claude on 2/12/26.
//

import SwiftUI

struct SQLeaderboardRowView: View {
    let viewModel: SQLeaderboardRowViewModel
    var onTitleTapped: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: .SQSpace.m) {
            SQDashboardTrendBadge(
                text: "#\(viewModel.rank)",
                tone: viewModel.rankTone,
                symbol: nil
            )
            .frame(width: 50, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: .SQSpace.s) {
                    if viewModel.isNavigable {
                        Button {
                            onTitleTapped?()
                        } label: {
                            HStack(spacing: .SQSpace.xs) {
                                Text(viewModel.title)
                                    .sqFont(.body)
                                    .sqForegroundColor(.textPrimary)
                                    .lineLimit(1)
                                SQImageView(image: .init(
                                    symbol: .chevronRight,
                                    symbolStyle: .colorWithFont(.textTertiary, font: .bodyExtraSmall)
                                ))
                                .frame(width: 5)
                            }
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text(viewModel.title)
                            .sqFont(.body)
                            .sqForegroundColor(.textPrimary)
                            .lineLimit(1)
                    }

                    if viewModel.hasWarning {
                        Button {
                            viewModel.warningTapped()
                        } label: {
                            SQImageView(image: .init(
                                symbol: .exclamationmarkTriangle,
                                symbolStyle: .colorWithFont(
                                    .backgroundWarning,
                                    font: .bodyExtraSmall
                                )
                            ))
                            .frame(width: 14)
                            .padding(.SQSpace.xs) // Increase tap target area
                        }
                        .buttonStyle(.plain)
                    }
                }

                Text(viewModel.dateString)
                    .sqFont(.bodyExtraSmall)
                    .sqForegroundColor(.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Score (right side)
            Text(viewModel.scoreAttributedString)

            if let topPercentText = viewModel.topPercentText {
                HStack(spacing: .SQSpace.xs) {
                    Text("Top")
                        .sqFont(.bodyExtraSmall)
                        .sqForegroundColor(.textSecondary)

                    SQDashboardTrendBadge(
                        text: topPercentText,
                        tone: viewModel.percentileTone,
                        symbol: nil
                    )
                }
                .frame(width: 84, alignment: .trailing)
            } else {
                Text("")
                    .frame(width: 84, alignment: .trailing)
            }
        }
        .padding(.horizontal, .SQSpace.l)
        .padding(.vertical, .SQSpace.m)
    }
}
