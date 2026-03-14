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
    
    // MARK: - Main Scroll

    @ViewBuilder
    func metricRow(index: Int, row: SQMetricsListItemViewModel) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Main row content - navigates to edit
                NavigationLink(value: SQMetricNavTarget.edit(row.metricId)) {
                    SQMetricsListItem(viewModel: row)
                }
                .buttonStyle(.plain)

                // Toggle tracking button
                Button {
                    controller.metricTapped(row, using: modelContext)
                } label: {
                    trackingButton(isTracked: row.isTracked)
                        .padding(.horizontal, .SQSpace.l)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, index == 0 ? .SQSpace.s : 0)
            .padding(.bottom, index == controller.rows.count - 1 ? .SQSpace.s : 0)

            if index != controller.rows.count - 1 {
                Divider()
                    .sqTintColor(.divider(1))
                    .padding(.horizontal, .SQSpace.l)
            }
        }
    }

    @ViewBuilder
    func trackingButton(isTracked: Bool) -> some View {
        if isTracked {
            ZStack {
                Circle()
                    .sqForegroundColor(.colorGreenDarkBorder)
                    .frame(width: 28, height: 28)

                SQImageView(
                    image: .init(
                        symbol: .checkmark,
                        symbolStyle: .colorWithFont(.textPrimary, font: .bodySmall)
                    )
                )
                .frame(width: 14, height: 14)
            }
        } else {
            ZStack {
                Circle()
                    .sqForegroundColor(.backgroundSecondaryLight)
                    .frame(width: 28, height: 28)

                SQImageView(
                    image: .init(
                        symbol: .plus,
                        symbolStyle: .colorWithFont(.textSecondary, font: .bodySmall)
                    )
                )
                .frame(width: 14, height: 14)
            }
        }
    }

    @ViewBuilder
    var mainScroll: some View {
        List {
            ForEach(Array(controller.rows.enumerated()), id: \.1) { (index, row) in

                metricRow(index: index, row: row)
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
            .background(SQColor.backgroundSheet.color)
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
