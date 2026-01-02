//
//  SQDailyCheckInView.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/24/25.
//

import SwiftUI

struct SQDailyCheckInView: View {
    @Bindable var viewModel: SQDailyCheckInViewModel
    @Environment(\.modelContext) private var modelContext
    
    @ViewBuilder
    var mainStack: some View {
        VStack(alignment: .leading, spacing: .SQSpace.xl) {
            ForEach(viewModel.rows) { row in
                SQDailyCheckInRow(viewModel: row)
                    .disabled(row.isDisabled)
                    .opacity(row.isDisabled ? 0.5 : 1)
            }
        }
    }
    
    @ViewBuilder
    var mainScroll: some View {
        ScrollView {
            mainStack
                .padding(.SQSpace.xl)
        }
    }
    
    var submitButton: some View {
        SQButton(
            shouldHugContent: false,
            title: "Submit",
            isDisabled: !viewModel.canSubmit,
            isLoading: viewModel.isLoading,
            action: { Task { await viewModel.submitTapped(modelContext: modelContext) } })
            .padding(.horizontal, .SQSpace.xl)
            .padding(.bottom, .SQSpace.l)
    }
    
    @ViewBuilder
    var navStack: some View {
        NavigationStack {
            mainScroll
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle("Daily Check-In")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            viewModel.addMetricTapped()
                        } label: {
                            HStack(spacing: .SQSpace.m) {
                                Image(systemName: SQImageSymbol.plus.rawValue)
                                Text("Add Metric")
                            }
                        }
                    }
                }
                .background(SQColor.backgroundSecondary.color)
                .safeAreaInset(edge: .bottom) {
                    submitButton
                }
                .sheet(isPresented: $viewModel.isAddMetricSheetDisplayed) {
                    SQMetricsListView(controller: viewModel.metricsListController)
                    }
        }
    }

    var body: some View {
        navStack
            .task {
                /// TODO: - Don't refresh for every appear, only the first time the view appears
                viewModel.refreshRows(stats: viewModel.stats, modelContext: modelContext)
            }
    }
}
