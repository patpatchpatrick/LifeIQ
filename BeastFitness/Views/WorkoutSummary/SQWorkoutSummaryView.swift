//
//  SQWorkoutSummaryView.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/6/25.
//

import SwiftUI
import SwiftData

struct SQWorkoutSummaryView: View {
    @State var controller: SQWorkoutSummaryController
    @Environment(\.modelContext) private var modelContext

    @State private var routeSectionCollapsed = false
    @State private var performanceSectionCollapsed = false
    @State private var statsSectionCollapsed = false
    @State private var reviewScrollOffset: CGFloat = 0

    private var mainStackHorizPadding: CGFloat { .SQSpace.l }

    private var reviewNavTitleOpacity: Double {
        let threshold: CGFloat = 80
        return Double(max(0, min(1, 1 - reviewScrollOffset / threshold)))
    }

    @ViewBuilder
    private var workoutHeroCard: some View {
        VStack(alignment: .leading, spacing: .SQSpace.l) {
            HStack(spacing: .SQSpace.m) {
                SQUserIcon(user: controller.state.user ?? .mock)
                    .redacted(controller.state.user == nil, reason: .placeholder)

                VStack(alignment: .leading, spacing: .SQSpace.xs) {
                    Text(controller.state.userFullName ?? SQUser.mock.name)
                        .sqFont(.title4)
                        .sqForegroundColor(.textPrimary)
                        .redacted(controller.state.userFullName == nil, reason: .placeholder)

                    Text(controller.state.workoutStartDate?.formattedString(with: .full) ?? Date.now.formattedString(with: .full))
                        .sqFont(.bodyExtraSmall)
                        .sqForegroundColor(.textSecondary)
                        .redacted(controller.state.workoutStartDate == nil, reason: .placeholder)
                }

                Spacer()
            }

            if controller.mode == .review {
                VStack(alignment: .leading, spacing: .SQSpace.xs) {
                    Text("Post-Workout Review")
                        .sqFont(.title2)
                        .sqForegroundColor(.textPrimary)

                    Text("Capture a few details while the session is still fresh.")
                        .sqFont(.bodyExtraSmall)
                        .sqForegroundColor(.textSecondary)
                }
            } else {
                VStack(alignment: .leading, spacing: .SQSpace.s) {
                    Text(controller.state.workoutTitle ?? "My workout")
                        .sqFont(.title2)
                        .sqForegroundColor(.textPrimary)
                        .redacted(controller.state.workoutTitle == nil, reason: .placeholder)

                    workoutReviewDisplay
                }
            }
        }
        .padding(.SQSpace.l)
        .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
    }

    @ViewBuilder
    private var reviewHeader: some View {
        VStack(spacing: .SQSpace.l) {
            if !controller.reviewHighlights.isEmpty {
                reviewHighlightsSection
            }

            reviewQuestionsSection
        }
    }

    @ViewBuilder
    private var reviewHighlightsSection: some View {
        VStack(alignment: .leading, spacing: .SQSpace.m) {
            Text("Highlights")
                .sqFont(.title4)
                .sqForegroundColor(.textPrimary)

            VStack(alignment: .leading, spacing: .SQSpace.m) {
                ForEach(controller.reviewHighlights) { highlight in
                    HStack(alignment: .top, spacing: .SQSpace.s) {
                        Circle()
                            .fill(highlightColor(for: highlight.sentiment).color.opacity(0.9))
                            .frame(width: 6, height: 6)
                            .padding(.top, 6)

                        highlight.segments.reduce(Text("")) { result, segment in
                            result + Text(segment.text)
                                .foregroundColor(
                                    segment.isStatistic
                                        ? highlightColor(for: highlight.sentiment).color
                                        : SQColor.textPrimary.color
                                )
                                .bold(segment.isStatistic)
                        }
                        .sqFont(.bodySmall)
                    }
                }
            }
        }
        .padding(.SQSpace.l)
        .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
    }

    private func highlightColor(for sentiment: SQWorkoutReviewHighlight.Sentiment) -> SQColor {
        switch sentiment {
        case .positive: return .dashboardGlowMint
        case .negative: return .dashboardTrendWarm
        case .neutral:  return .dashboardGlowBlue
        }
    }

    @ViewBuilder
    private func questionTitle(title: String) -> some View {
        Text(title.uppercased())
            .sqFont(.headerSmall)
            .sqForegroundColor(.textSecondary)
            .padding(.bottom, .SQSpace.xs)
    }

    @ViewBuilder
    private var reviewQuestionsSection: some View {
        let bindable = Bindable(controller)
        VStack(alignment: .leading, spacing: .SQSpace.l) {
            VStack(alignment: .leading, spacing: .SQSpace.xs) {
                Text("Quick Check-In")
                    .sqFont(.title4)
                    .sqForegroundColor(.textPrimary)

                Text("These responses help BeastFitness build better insights over time.")
                    .sqFont(.bodyExtraSmall)
                    .sqForegroundColor(.textSecondary)
            }

            SQUITextField(viewModel: controller.titleViewModel)
            SQTextField(viewModel: controller.notesViewModel)

            VStack(alignment: .leading, spacing: .SQSpace.s) {
                questionTitle(title: "Temperature")

                HStack(spacing: .SQSpace.s) {
                    SQUITextField(viewModel: controller.temperatureViewModel, width: 72)

                    Text(SQUnit.degreesFahrenheit.unitString ?? "°F")
                        .sqFont(.bodySmall)
                        .sqForegroundColor(.textSecondary)

                    Spacer()
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
        .padding(.SQSpace.l)
        .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
    }

    @ViewBuilder
    private func reviewRatingRow(
        title: String,
        segments: [SQSegmentedControlSegment],
        selection: Binding<SQSegmentedControlSegment?>,
        scaleMin: String,
        scaleMax: String
    ) -> some View {
        VStack(alignment: .leading, spacing: .SQSpace.m) {
            questionTitle(title: title)

            SQSegmentedControl(segments: segments, selection: selection) { segment in
                Text(segment.title)
                    .sqFont(.title3)
                    .sqForegroundColor(.textPrimary)
            }

            HStack {
                Text(scaleMin)
                    .sqFont(.bodyExtraSmall)
                    .sqForegroundColor(.textSecondary)

                Spacer()

                Text(scaleMax)
                    .sqFont(.bodyExtraSmall)
                    .sqForegroundColor(.textSecondary)
            }
        }
    }

    @ViewBuilder
    private var workoutReviewDisplay: some View {
        let workout = controller.state.currentWorkout
        let notes = workout?.reviewNotes
        let temperatureCelsius = workout?.temperatureCelsius
        let performanceRating = workout?.ratingUserPerformance
        let difficultyRating = workout?.ratingDifficulty

        let hasNotes = !(notes?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let fahrenheit: Double? = temperatureCelsius.flatMap {
            SQUnit.degreesCelsius.convert($0, to: .degreesFahrenheit)
        }
        let performanceSegment = performanceRating.flatMap { rating in
            SQWorkoutSummaryController.performanceSegments.first { $0.ratingValue == rating }
        }
        let difficultySegment = difficultyRating.flatMap { rating in
            SQWorkoutSummaryController.difficultySegments.first { $0.ratingValue == rating }
        }

        VStack(alignment: .leading, spacing: .SQSpace.m) {
            if hasNotes, let notes {
                Text(notes)
                    .sqFont(.bodySmall)
                    .sqForegroundColor(.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: .SQSpace.s) {
                if let fahrenheit {
                    workoutMetaChip(title: "Temp", value: "\(Int(fahrenheit.rounded()))°F")
                }

                if let seg = performanceSegment {
                    workoutMetaChip(title: "Performance", value: seg.title)
                }

                if let seg = difficultySegment {
                    workoutMetaChip(title: "Effort", value: seg.title)
                }
            }
        }
    }

    @ViewBuilder
    private func workoutMetaChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .sqFont(.headerSmall)
                .sqForegroundColor(.textSecondary)

            Text(value)
                .sqFont(.bodySmallSemiBold)
                .sqForegroundColor(.textPrimary)
        }
        .padding(.horizontal, .SQSpace.m)
        .padding(.vertical, .SQSpace.s)
        .background(
            Capsule(style: .continuous)
                .fill(SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.80 : 0.96))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(SQColor.glassStroke.color, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var mainStack: some View {
        VStack(alignment: .leading, spacing: .SQSpace.l) {
            workoutHeroCard

            if controller.mode == .review {
                reviewHeader
            }

            if controller.state.shouldShowRouteView {
                SQDashboardSubsection(title: "Route", isCollapsed: $routeSectionCollapsed) {
                    SQWorkoutRouteMapView(
                        isLoading: controller.state.isLoadingRoute || controller.state.isLoading,
                        locations: controller.state.routeLocations,
                        errorMessage: controller.state.routeLoadErrorMessage
                    )
                }
            }

            SQDashboardSubsection(title: "Stats", isCollapsed: $statsSectionCollapsed) {
                VStack(spacing: .SQSpace.l) {
                    ForEach(controller.state.workoutStatsRows) { row in
                        SQDashboardPerformanceRow(data: row)
                    }
                }
            }

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
            }
        }
    }

    @ViewBuilder
    private var mainScroll: some View {
        ScrollView {
            mainStack
                .padding(.horizontal, mainStackHorizPadding)
                .padding(.top, .SQSpace.l)
                .padding(.bottom, .SQSpace.xl)
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
            .dismissKeyboardOnBackgroundTap()
            .redacted(controller.state.isLoading, reason: .placeholder)
            .background {
                SQSheetBackground()
            }
            .navigationTitle(controller.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await controller.onAppear()
            }
            .onChange(of: controller.dismissKeyboard) {
                sqHideKeyboard()
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(controller.navTitle)
                        .sqFont(.title1)
                        .sqForegroundColor(.textPrimary)
                        .opacity(reviewNavTitleOpacity)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        if controller.showNavEditWorkoutButton {
                            Button {
                                controller.pushEditWorkoutView()
                            } label: {
                                Label("Edit workout", systemImage: SQImageSymbol.pencil.rawValue)
                            }
                        }
                        Button {
                            Task { @MainActor in
                                await controller.deleteWorkout(from: modelContext)
                            }
                        } label: {
                            Label("Delete workout", systemImage: SQImageSymbol.xCircle.rawValue)
                        }
                    } label: {
                        SQImageView(
                            image: .init(
                                symbol: .ellipsisCircle,
                                symbolStyle: .colorWithFont(.textPrimary, font: .body)
                            )
                        )
                        .frame(width: 18, height: 18)
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
            ForEach(Array(row.visibleStats.enumerated()), id: \.1) { (_, visibleStat) in
                buildStat(visibleStat)
            }

            if row.visibleStats.count < 3 {
                Spacer()
            }
        }
    }
}
