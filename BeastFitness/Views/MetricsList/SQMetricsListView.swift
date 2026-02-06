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

    // MARK: - Actions

    private func rowTapped(_ row: SQMetricsListItemViewModel) {
        controller.metricTapped(row, using: modelContext)
    }

    // MARK: - Main Scroll

    @ViewBuilder
    var mainScroll: some View {
        List {
            ForEach(Array(controller.rows.enumerated()), id: \.1) { (index, row) in

                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        // Main body: tap toggles tracking
                        Button(
                            action: { rowTapped(row) },
                            label: { SQMetricsListItem(viewModel: row) }
                        )
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity)

                        // Trailing chevron: navigates to edit
                        NavigationLink(value: SQMetricNavTarget.edit(row.metricId)) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .sqForegroundColor(.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, index == 0 ? .SQSpace.s : 0)
                    .padding(.bottom, index == controller.rows.count - 1 ? .SQSpace.xl : 0)
                    .padding(.horizontal, .SQSpace.l)

                    if index != controller.rows.count - 1 {
                        Divider()
                            .sqTintColor(.divider(1))
                            .padding(.top, .SQSpace.xl)
                            .padding(.bottom, .SQSpace.xl)
                            .background(SQColor.background.color)
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Nav View

    var navView: some View {
        mainScroll
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Add Metrics")
            .navigationBarTitleDisplayMode(.inline)
            .background(SQColor.background.color)
            .searchable(
                text: $controller.searchText,
                placement: .navigationBarDrawer(displayMode: .automatic),
                prompt: "Search metrics"
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        controller.createMetricTapped()
                    } label: {
                        Image(systemName: SQImageSymbol.plus.rawValue)
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
