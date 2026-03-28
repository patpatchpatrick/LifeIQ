//
//  SQWorkoutsListView.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/6/25.
//

import SwiftUI

struct SQWorkoutsListView: View {
    @State var controller: SQWorkoutsListController

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: .SQSpace.m) {
            HStack(spacing: .SQSpace.m) {
                RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                    .fill(SQColor.dashboardGlowBlue.color.opacity(SQColor.isDarkMode ? 0.16 : 0.12))
                    .frame(width: 42, height: 42)
                    .overlay {
                        RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                            .stroke(SQColor.glassStrokeStrong.color, lineWidth: 1)
                    }
                    .overlay {
                        SQImageView(
                            image: .init(
                                symbol: .figureRun,
                                symbolStyle: .colorWithFont(.dashboardGlowBlue, font: .bodySmall)
                            )
                        )
                        .frame(width: 16, height: 16)
                    }

                VStack(alignment: .leading, spacing: .SQSpace.xs) {
                    Text("Recent workouts")
                        .sqFont(.bodySemiBold)
                        .sqForegroundColor(.textPrimary)

                    Text("Open any saved session to review its summary, route, and performance details.")
                        .sqFont(.bodyExtraSmall)
                        .sqForegroundColor(.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: .SQSpace.s) {
                SQDashboardTrendBadge(
                    text: "\(controller.rows.count) saved",
                    tone: .neutral,
                    symbol: nil
                )

                Text("Newest first")
                    .sqFont(.bodyExtraSmall)
                    .sqForegroundColor(.textSecondary)
            }
        }
        .padding(.SQSpace.l)
        .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: .SQSpace.m) {
            Text("No workouts yet")
                .sqFont(.bodySemiBold)
                .sqForegroundColor(.textPrimary)

            Text("Completed workouts will appear here once you record or import them.")
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.SQSpace.l)
        .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
    }

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: .SQSpace.l) {
            overviewCard

            if controller.rows.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: .SQSpace.m) {
                    ForEach(controller.rows) { row in
                        Button {
                            controller.displayWorkoutSummary(for: row)
                        } label: {
                            SQWorkoutsListItem(viewModel: row)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, .SQSpace.l)
        .padding(.vertical, .SQSpace.l)
    }
 
    var body: some View {
        ScrollView {
            content
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Workouts")
        .navigationBarTitleDisplayMode(.inline)
        .background {
            SQSheetBackground()
        }
    }
}
