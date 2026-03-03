//
//  SQWorkoutSummaryView.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/6/25.
//

import SwiftUI

struct SQWorkoutSummaryView: View {
    @State var controller: SQWorkoutSummaryController
    @Environment(\.modelContext) private var modelContext
    
    var backgroundColor: SQColor = .background
    var screenWidth: CGFloat { UIScreen.main.bounds.width }
    let mainStackHorizPadding: CGFloat = .SQSpace.xxl
    var statColumnWidth: CGFloat { (screenWidth - mainStackHorizPadding * 2.0 - .SQSpace.l * 2) / CGFloat(controller.state.workoutStatRowColumnCount) }

    @State private var routeSectionCollapsed = false
    @State private var performanceSectionCollapsed = false
    @State private var statsSectionCollapsed = false

    // Scroll-tracking for review mode nav title fade
    @State private var reviewScrollOffset: CGFloat = 0

    private var reviewNavTitleOpacity: Double {
        let threshold: CGFloat = 80
        return Double(max(0, min(1, 1 - reviewScrollOffset / threshold)))
    }
    
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
    
    // MARK: - Review Header

    @ViewBuilder
    var reviewHeader: some View {
        VStack(alignment: .leading, spacing: .SQSpace.xl) {
            if !controller.reviewHighlights.isEmpty {
                reviewHighlightsSection
            }
            Divider()
            reviewQuestionsSection
            Divider()
        }
    }

    @ViewBuilder
    var reviewHighlightsSection: some View {
        VStack(alignment: .leading, spacing: .SQSpace.m) {
            ForEach(controller.reviewHighlights) { highlight in
                HStack(alignment: .top, spacing: .SQSpace.s) {
                    Text("•")
                        .sqFont(.body)
                        .sqForegroundColor(highlightColor(for: highlight.sentiment))

                    highlight.segments.reduce(Text("")) { result, segment in
                        result + Text(segment.text)
                            .foregroundColor(
                                segment.isStatistic
                                    ? highlightColor(for: highlight.sentiment).color
                                    : SQColor.textPrimary.color
                            )
                    }
                    .sqFont(.body)
                }
            }
        }
    }

    private func highlightColor(for sentiment: SQWorkoutReviewHighlight.Sentiment) -> SQColor {
        switch sentiment {
        case .positive: return .colorGreenPct(percent: 1, base: .textPrimary)
        case .negative: return .textError
        case .neutral:  return .textPrimary
        }
    }

    @ViewBuilder
    var reviewQuestionsSection: some View {
        let bindable = Bindable(controller)
        VStack(alignment: .leading, spacing: .SQSpace.xl) {
            Text("A couple quick questions to help track your progress")
                .sqFont(.bodySmall)
                .sqForegroundColor(.textSecondary)

            SQUITextField(viewModel: controller.titleViewModel)

            SQTextField(viewModel: controller.notesViewModel)

            VStack(alignment: .leading, spacing: .SQSpace.s) {
                Text("Temperature")
                    .sqFont(.bodySmall)
                    .sqForegroundColor(.textPrimary)
                HStack(spacing: .SQSpace.s) {
                    SQUITextField(viewModel: controller.temperatureViewModel)
                    Text(SQUnit.degreesFahrenheit.unitString ?? "°F")
                        .sqFont(.body)
                        .sqForegroundColor(.textSecondary)
                }
            }

            reviewRatingRow(
                title: "How did you perform?",
                segments: SQWorkoutSummaryController.performanceSegments,
                selection: bindable.selectedPerformance,
                scaleMin: "Very low",
                scaleMax: "Very high"
            )

            reviewRatingRow(
                title: "How hard was it?",
                segments: SQWorkoutSummaryController.difficultySegments,
                selection: bindable.selectedDifficulty,
                scaleMin: "Easy",
                scaleMax: "Max effort"
            )
        }
    }

    @ViewBuilder
    func reviewRatingRow(
        title: String,
        segments: [SQSegmentedControlSegment],
        selection: Binding<SQSegmentedControlSegment?>,
        scaleMin: String,
        scaleMax: String
    ) -> some View {
        VStack(alignment: .leading, spacing: .SQSpace.m) {
            Text(title)
                .sqFont(.bodySmall)
                .sqForegroundColor(.textPrimary)

            SQSegmentedControl(segments: segments, selection: selection) { segment in
                Text(segment.title)
                    .sqFont(.title3)
                    .sqForegroundColor(.textPrimary)
            }

            HStack {
                Text(scaleMin)
                    .sqFont(.bodySmall)
                    .sqForegroundColor(.textSecondary)
                Spacer()
                Text(scaleMax)
                    .sqFont(.bodySmall)
                    .sqForegroundColor(.textSecondary)
            }
        }
    }

    @ViewBuilder
    var mainStack: some View {
        VStack(alignment: .leading, spacing: 0) {
            if controller.mode == .review {
                reviewHeader
                    .padding(.bottom, .SQSpace.xl)
            }

            userNameAndDateRow
                .padding(.bottom, .SQSpace.xl)
            
            if controller.mode != .review {
                Text(controller.state.workoutTitle ?? "My workout")
                    .sqFont(.title3)
                    .sqForegroundColor(.textPrimary)
                    .redacted(controller.state.workoutTitle == nil, reason: .placeholder)
                    .padding(.bottom, .SQSpace.xl)
            }
            
            if controller.state.shouldShowRouteView {
                SQDashboardSubsection(title: "Route", isCollapsed: $routeSectionCollapsed) {
                    SQWorkoutRouteMapView(
                        isLoading: controller.state.isLoadingRoute || controller.state.isLoading,
                        locations: controller.state.routeLocations,
                        errorMessage: controller.state.routeLoadErrorMessage
                    )
                }
                .padding(.bottom, .SQSpace.xl)
            }
            
            SQDashboardSubsection(title: "Stats", isCollapsed: $statsSectionCollapsed) {
                VStack(spacing: .SQSpace.l) {
                    ForEach(controller.state.workoutStatsRows) { row in
                        SQDashboardPerformanceRow(data: row)
                    }
                }
            }
            .padding(.bottom, .SQSpace.xl)

            if controller.state.shouldShowPerformanceSection {
                SQDashboardSubsection(title: "Performance", isCollapsed: $performanceSectionCollapsed) {
                    VStack(spacing: SQDashboardView.uiConfig.sectionRowSpacing) {
                        SQColumnHeaderRow(columns: [.leading("Stat"), .trailing("Best Score"), .trailing("Rank")])
                        ForEach(controller.state.performanceRowData) { row in
                            SQDashboardPerformanceRow(data: row)
                                .onTapGesture {
                                    controller.displayLeaderboard(for: row)
                                }
                        }
                    }
                }
                .padding(.bottom, .SQSpace.xl)
            }
        }
    }
    
    @ViewBuilder
    var mainScroll: some View {
        ScrollView {
            mainStack
                .padding(mainStackHorizPadding)
        }
        .onScrollGeometryChange(for: CGFloat.self) { geo in
            geo.contentOffset.y + geo.contentInsets.top
        } action: { _, newValue in
            guard controller.mode == .review else { return }
            reviewScrollOffset = max(0, newValue)
        }
    }
    var body: some View {
        mainScroll
            .redacted(controller.state.isLoading, reason: .placeholder)
            .background(backgroundColor.color)
            .navigationTitle(controller.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await controller.onAppear()
            }
            .toolbar {
                if controller.mode == .review {
                    ToolbarItem(placement: .principal) {
                        Text("Nice workout! 💪")
                            .sqFont(.title1)
                            .sqForegroundColor(.textPrimary)
                            .opacity(reviewNavTitleOpacity)
                    }
                }
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
