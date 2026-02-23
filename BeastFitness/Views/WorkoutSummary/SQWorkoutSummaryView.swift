//
//  SQWorkoutSummaryView.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/6/25.
//

import SwiftUI

struct SQWorkoutSummaryView: View {
    @Bindable var controller: SQWorkoutSummaryController
    @Environment(\.modelContext) private var modelContext
    
    var customNavigationTitle: String? = nil
    var backgroundColor: SQColor = .background
    var screenWidth: CGFloat { UIScreen.main.bounds.width }
    let mainStackHorizPadding: CGFloat = .SQSpace.xxl
    var statColumnWidth: CGFloat { (screenWidth - mainStackHorizPadding * 2.0) / CGFloat(controller.state.workoutStatRowColumnCount) }
    
    @ViewBuilder
    var userNameAndDateRow: some View {
        HStack(spacing: .SQSpace.l) {
            
            SQUserIcon(user: controller.state.user ?? .mock)
                .redacted(controller.state.user == nil, reason: .placeholder)
            
            VStack(alignment: .leading, spacing: .SQSpace.xs) {
                Text(controller.state.userFullName ?? SQUser.mock.name)
                    .sqFont(.title3)
                    .sqForegroundColor(.textPrimary)
                    .redacted(controller.state.userFullName == nil, reason: .placeholder)
                
                Text(controller.state.workoutStartDate?.formattedString(with: .full) ?? Date.now.formattedString(with: .full))
                    .sqFont(.bodyExtraSmall)
                    .sqForegroundColor(.textSecondary)
                    .redacted(controller.state.workoutStartDate == nil, reason: .placeholder)
            }
            
            Spacer()
        }
    }
    
    @ViewBuilder
    var mainStack: some View {
        VStack(alignment: .leading, spacing: 0) {
            userNameAndDateRow
                .padding(.bottom, .SQSpace.xl)
            
            Text(controller.state.workoutTitle ?? "My workout")
                .sqFont(.title3)
                .sqForegroundColor(.textPrimary)
                .redacted(controller.state.workoutTitle == nil, reason: .placeholder)
                .padding(.bottom, .SQSpace.xl)
            
            if controller.state.shouldShowRouteView {
                SQWorkoutRouteMapView(
                    isLoading: controller.state.isLoadingRoute,
                    locations: controller.state.routeLocations,
                    errorMessage: controller.state.routeLoadErrorMessage
                )
                .padding(.bottom, .SQSpace.xl)
            }
            
            VStack(spacing: .SQSpace.l) {
                ForEach(controller.state.workoutStatsRows) { row in
                    SQWorkoutSummaryStatsRow(row: row, columnWidth: statColumnWidth)
                }
            }
        }
    }
    
    @ViewBuilder
    var mainScroll: some View {
        ScrollView {
            mainStack
                .padding(mainStackHorizPadding)
        }
    }
    var body: some View {
        mainScroll
            .background(backgroundColor.color)
            .navigationTitle(customNavigationTitle ?? "Workout summary")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            controller.pushEditWorkoutView()
                        } label: {
                            Label("Edit workout", systemImage: SQImageSymbol.pencil.rawValue)
                        }
                        Button {
                            Task { @MainActor in
                              await controller.deleteWorkout(from: modelContext)
                            }
                        } label: {
                            Label("Delete workout", systemImage: SQImageSymbol.xCircle.rawValue)
                        }
                    } label: {
                        Image(systemName: SQImageSymbol.ellipsisCircle.rawValue)
                            .imageScale(.large)
                    }
                }
            }
    }
}

struct SQWorkoutSummaryStatsRow: View {
    let row: SQWorkoutSummaryStatRow
    let columnWidth: CGFloat
    
    @ViewBuilder
    func buildStat(_ stat: SQWorkoutSessionVisibleStat) -> some View {
        VStack(alignment: .center, spacing: .SQSpace.s) {
            Text(stat.title)
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textSecondary)
            
            Text(stat.value)
                .sqFont(.bodySmallBold)
                .sqForegroundColor(.textPrimary)
        }
        .frame(width: columnWidth)
    }
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(row.visibleStats.enumerated()), id: \.1) { (index, visibleStat) in
                buildStat(visibleStat)
            }
            
            /// Left align the stats iif there aren't exactly 3
            if row.visibleStats.count < 3 {
                Spacer()
            }
        }
    }
}
