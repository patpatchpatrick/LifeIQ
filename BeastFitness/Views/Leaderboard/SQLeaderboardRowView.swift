//
//  SQLeaderboardRowView.swift
//  BeastFitness
//
//  Created by Claude on 2/12/26.
//

import SwiftUI

struct SQLeaderboardRowView: View {
    let viewModel: SQLeaderboardRowViewModel

    // Display emoji medal for top 3, rank number for others
    private var rankDisplay: String {
        switch viewModel.rank {
        case 1:
            return "🥇"
        case 2:
            return "🥈"
        case 3:
            return "🥉"
        default:
            return "#\(viewModel.rank)"
        }
    }

    // Use emoji for top 3, text color for others
    private var usesEmoji: Bool {
        viewModel.rank <= 3
    }

    var body: some View {
        HStack(spacing: .SQSpace.m) {
            // Rank (left side)
            Group {
                if usesEmoji {
                    Text(rankDisplay)
                        .font(.system(size: 24))
                } else {
                    Text(rankDisplay)
                        .sqFont(.bodyLarge)
                        .sqForegroundColor(.textSecondary)
                }
            }
            .frame(width: 50, alignment: .leading)

            // Workout info (center)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: .SQSpace.m) {
                    Text(viewModel.title)
                        .sqFont(.body)
                        .sqForegroundColor(.textPrimary)
                        .lineLimit(1)

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
        }
        .padding(.horizontal, .SQSpace.l)
        .padding(.vertical, .SQSpace.m)
        .sqBackgroundColor(.backgroundSecondary)
    }
}
