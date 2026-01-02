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
                    Button(
                        action: { rowTapped(row) },
                        label: { SQMetricsListItem(viewModel: row) }
                    )
                    .buttonStyle(.plain)
                    .padding(.top, index == 0 ? .SQSpace.s : 0)
                    .padding(.bottom, index == controller.rows.count - 1 ? .SQSpace.xl : 0)
                    .padding(.horizontal, .SQSpace.l)

                    if index != controller.rows.count - 1 {
                        Divider()
                            .sqTintColor(.divider)
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
            .task {
                // ✅ Keep this out of the ForEach body; lightweight and reliable
                controller.loadUI(using: modelContext)
            }
    }

    // MARK: - Nav Stack

    @ViewBuilder
    var navStack: some View {
        NavigationStack {
            navView
        }
    }

    var body: some View {
        navStack
    }
}
