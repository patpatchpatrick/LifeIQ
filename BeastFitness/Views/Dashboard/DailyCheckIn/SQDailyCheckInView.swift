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
        SQButton(shouldHugContent: false, title: "Submit", isDisabled: !viewModel.canSubmit, action: { viewModel.submitTapped(modelContext: modelContext) })
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
                .background(SQColor.backgroundSecondary.color)
                .safeAreaInset(edge: .bottom) {
                    submitButton
                }
        }
    }

    var body: some View {
        navStack
    }
}
