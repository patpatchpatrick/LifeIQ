//
//  SQDashboardView.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/11/25.
//

import SwiftUI

struct SQDashboardView: View {
    @Bindable var viewModel: SQDashboardViewModel
    
    var mainScroll: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                ForEach(viewModel.rowViewModels) { rowViewModel in
                    switch rowViewModel.rowType {
                    case .text:
                        if let textRowViewModel = rowViewModel as? SQDashboardTextRowViewModel {
                            SQDashboardTextRow(viewModel: textRowViewModel)
                        }
                    case .weekSummary:
                        if let weekSummaryViewModel = rowViewModel as? SQDashboardWeekSummaryRowViewModel {
                            SQDashboardWeekSummaryRow(viewModel: weekSummaryViewModel)
                        }
                    }
                }
                
                Spacer()
            }
            .padding(.top, .SQSpace.xxl)
        }
    }

    var body: some View {
        mainScroll
            .navigationBarTitleDisplayMode(.inline)
                               .toolbar {
                                   ToolbarItem(placement: .topBarLeading) {
                                       HStack(spacing: 12) {
                                           // Profile icon
                                           ZStack {
                                               Circle()
                                                   .fill(Color(.systemGray5))
                                               Text("P") // or an SF Symbol / image
                                                   .font(.system(size: 16, weight: .semibold))
                                           }
                                           .frame(width: 34, height: 34)
                                           
                                           // Multiline welcome text
                                           VStack(alignment: .leading, spacing: 2) {
                                               Text("Welcome back! 👋🏻")
                                                   .font(.system(size: 13, weight: .medium))
                                                   .foregroundStyle(Color.secondary)
                                               
                                               Text("Patrick Doyle")
                                                   .font(.system(size: 17, weight: .semibold))
                                                   .foregroundStyle(Color.primary)
                                           }
                                       }
                                   }
                               }
            .background(SQColor.background.color.ignoresSafeArea())
    }
}
