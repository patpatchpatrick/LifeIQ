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
        VStack(alignment: .leading, spacing: .SQSpace.l) {
            ForEach(viewModel.rows) { row in
                SQDailyCheckInRow(viewModel: row)
                    .disabled(row.isDisabled)
                    .opacity(row.isDisabled ? 0.45 : 1)
            }
        }
    }
    
    @ViewBuilder
    var mainScroll: some View {
        VStack(alignment: .leading, spacing: 0) {
            dateSelectionButton
                .padding(.horizontal, .SQSpace.xl)
                .padding(.top, .SQSpace.l)
                .padding(.bottom, .SQSpace.m)

            ScrollView {
                mainStack
                    .padding(.horizontal, .SQSpace.xl)
                    .padding(.top, .SQSpace.s)
                    .padding(.bottom, .SQSpace.xxl)
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
                    .sqFont(.bodySemiBold)
                    .sqForegroundColor(.textPrimary)

                SQImageView(image: .init(symbol: .chevronDown, symbolStyle: .colorWithFont(.textSecondary, font: .bodySmall)))
                    .frame(width: 10)
            }
            .padding(.vertical, .SQSpace.m)
            .padding(.horizontal, .SQSpace.l)
            .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
        }
        .buttonStyle(.plain)
    }

    var submitButton: some View {
        SQButton(
            style: .glassPrimary,
            shouldHugContent: false,
            title: viewModel.isEditingPastDate ? "Update" : "Submit",
            isDisabled: !viewModel.canSubmit,
            isLoading: viewModel.isLoading,
            action: { Task { await viewModel.submitTapped(modelContext: modelContext) } })
            .padding(.horizontal, .SQSpace.xl)
            .padding(.top, .SQSpace.m)
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
                .background {
                    SQSheetBackground()
                }
                .safeAreaInset(edge: .bottom) {
                    VStack(spacing: 0) {
                        Divider()
                            .sqTintColor(.glassStroke)

                        submitButton
                    }
                    .background(.ultraThinMaterial)
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
