//
//  SQMetricsListView.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 1/2/26.
//

import SwiftUI
import SwiftData

struct SQMetricsListView: View {
    @State var controller: SQMetricsListController
    @Environment(\.modelContext) private var modelContext

    @ViewBuilder
    private func toolbarIconButton(symbol: SQImageSymbol, foregroundColor: SQColor, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            SQImageView(
                image: .init(
                    symbol: symbol,
                    symbolStyle: .colorWithFont(foregroundColor, font: .bodySmall)
                )
            )
            .frame(width: 14, height: 14)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    func trackingButton(isTracked: Bool) -> some View {
        HStack(spacing: .SQSpace.xs) {
            SQImageView(
                image: .init(
                    symbol: isTracked ? .checkmark : .plus,
                    symbolStyle: .colorWithFont(
                        isTracked ? .dashboardGlowBlueForeground : .textSecondary,
                        font: .headerSmall
                    )
                )
            )
            .frame(width: 10, height: 10)

            Text(isTracked ? "Tracked" : "Add")
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(isTracked ? .dashboardGlowBlueForeground : .textSecondary)
        }
        .padding(.vertical, 7)
        .padding(.horizontal, .SQSpace.s)
        .background(
            Capsule(style: .continuous)
                .fill(
                    isTracked
                        ? SQColor.dashboardGlowBlue.color.opacity(SQColor.isDarkMode ? 0.24 : 0.16)
                        : SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.78 : 0.96)
                )
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(
                    isTracked
                        ? SQColor.dashboardGlowBlue.color.opacity(0.44)
                        : SQColor.glassStroke.color,
                    lineWidth: 1
                )
        )
    }

    @ViewBuilder
    func metricRow(_ row: SQMetricsListItemViewModel) -> some View {
        HStack(spacing: .SQSpace.m) {
            NavigationLink(value: SQMetricNavTarget.edit(row.metricId)) {
                SQMetricsListItem(viewModel: row)
            }
            .buttonStyle(.plain)

            Button {
                controller.metricTapped(row, using: modelContext)
            } label: {
                trackingButton(isTracked: row.isTracked)
            }
            .buttonStyle(.plain)
            .padding(.trailing, .SQSpace.l)
        }
        .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: .SQSpace.m) {
            Text("No metrics found")
                .sqFont(.bodySemiBold)
                .sqForegroundColor(.textPrimary)

            Text("Try a different search or create a new metric.")
                .sqFont(.bodySmall)
                .sqForegroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.SQSpace.xl)
        .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
    }

    @ViewBuilder
    var mainScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .SQSpace.s) {
                if controller.rows.isEmpty {
                    emptyState
                } else {
                    ForEach(controller.rows) { row in
                        metricRow(row)
                    }
                }
            }
            .padding(.horizontal, .SQSpace.l)
            .padding(.top, .SQSpace.l)
            .padding(.bottom, .SQSpace.xl)
        }
    }

    var navView: some View {
        mainScroll
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Add Metrics")
            .navigationBarTitleDisplayMode(.inline)
            .background {
                SQSheetBackground()
            }
            .searchable(
                text: $controller.searchText,
                placement: .navigationBarDrawer(displayMode: .automatic),
                prompt: "Search metrics"
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    toolbarIconButton(symbol: .plus, foregroundColor: .textPrimary) {
                        controller.createMetricTapped()
                    }
                }
            }
            .task {
                controller.loadUI(using: modelContext)
            }
    }

    // MARK: - Nav Stack

    @ViewBuilder
    var navStack: some View {
        NavigationStack(path: $controller.navigationPath) {
            navView
                .navigationDestination(for: SQMetricNavTarget.self) { target in
                    switch target {
                    case .create:
                        SQMetricFormView(viewModel: SQMetricFormViewModel(
                            mode: .create,
                            metricsManager: controller.metricsManager
                        ))
                    case .edit(let metricId):
                        if let metric = controller.metricDefinition(for: metricId) {
                            SQMetricFormView(viewModel: SQMetricFormViewModel(
                                mode: .edit(metric),
                                metricsManager: controller.metricsManager
                            ))
                        }
                    }
                }
        }
    }

    var body: some View {
        navStack
    }
}
