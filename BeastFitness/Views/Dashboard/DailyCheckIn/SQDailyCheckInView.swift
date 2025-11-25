//
//  SQDailyCheckInView.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/24/25.
//

import SwiftUI

@Observable @MainActor
final class SQDailyCheckInRowViewModel: Identifiable {
    
}

@Observable @MainActor
final class SQDailyCheckInViewModel {
    let rows: [SQDailyCheckInRowViewModel] = [.init(), .init(), .init()]
}

struct SQDailyCheckInView: View {
    @Bindable var viewModel: SQDailyCheckInViewModel
    
    @ViewBuilder
    var mainStack: some View {
        VStack(alignment: .leading, spacing: .SQSpace.xl) {
            ForEach(viewModel.rows) { _ in
                Text("Row")
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
    
    @ViewBuilder
    var navStack: some View {
        NavigationStack {
            mainScroll
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle("Daily Check-In")
                .navigationBarTitleDisplayMode(.inline)
                .background(SQColor.backgroundSecondary.color)
        }
    }

    
    var body: some View {
        navStack
    }
}
