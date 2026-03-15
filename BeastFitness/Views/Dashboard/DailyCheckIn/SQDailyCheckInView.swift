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
        VStack(alignment: .leading, spacing: .SQSpace.xxl) {
            ForEach(viewModel.rows) { row in
                SQDailyCheckInRow(viewModel: row)
                    .disabled(row.isDisabled)
                    .opacity(row.isDisabled ? 0.5 : 1)
            }
        }
    }
    
    @ViewBuilder
    var mainScroll: some View {
        VStack(alignment: .leading, spacing: 0) {
            dateSelectionButton
                .padding(.horizontal, .SQSpace.xl)
                .padding(.vertical, .SQSpace.m)

            ScrollView {
                mainStack
                    .padding(.SQSpace.xl)
            }
        }
    }
    
    @ViewBuilder
    var dateSelectionButton: some View {
        Button {
            viewModel.showDatePicker(modelContext: modelContext)
        } label: {
            HStack(spacing: .SQSpace.s) {
                Text(viewModel.targetDate.formattedString(with: .long))
                    .sqFont(.body)
                    .sqForegroundColor(.textPrimary)

                SQImageView(image: .init(symbol: .chevronDown, symbolStyle: .colorWithFont(.textSecondary, font: .bodySmall)))
                    .frame(width: 10)
            }
        }
        .buttonStyle(.plain)
    }

    var submitButton: some View {
        SQButton(
            shouldHugContent: false,
            title: viewModel.isEditingPastDate ? "Update" : "Submit",
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
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("\(viewModel.period.rawValue.capitalized) Check-In")
                            .sqFont(.titleNav)
                            .sqForegroundColor(.textPrimary)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            viewModel.addMetricTapped()
                        } label: {
                            Text("Edit")
                        }
                    }
                }
                .background(SQColor.backgroundSheet.color)
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
                await viewModel.refresh(for: viewModel.targetDate, modelContext: modelContext)
            }
    }
}
