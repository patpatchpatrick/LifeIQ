//
//  SQWorkoutSummaryView.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/6/25.
//

import SwiftUI
import SwiftData
import CoolCharts

struct SQWorkoutSummaryView: View {
    @State var controller: SQWorkoutSummaryController
    @Environment(\.modelContext) private var modelContext

    @State private var routeSectionCollapsed = false
    @State private var performanceSectionCollapsed = false
    @State private var heartRateZonesSectionCollapsed = false
    @State private var statsSectionCollapsed = false
    @State private var reviewScrollOffset: CGFloat = 0

    private var mainStackHorizPadding: CGFloat { .SQSpace.l }

    private var reviewNavTitleOpacity: Double {
        let threshold: CGFloat = 80
        return Double(max(0, min(1, 1 - reviewScrollOffset / threshold)))
    }

    private var workoutDateText: String {
        controller.state.workoutStartDate?.formattedString(with: .full) ?? Date.now.formattedString(with: .full)
    }

    private var heroTitleText: String {
        if let userFullName = controller.state.userFullName, !userFullName.isEmpty {
            return userFullName
        }
        return controller.state.isLoggedIn ? "Your workout" : "Local workout"
    }

    @ViewBuilder
    private var workoutHeroCard: some View {
        VStack(alignment: .leading, spacing: .SQSpace.l) {
            HStack(spacing: .SQSpace.m) {
                if let user = controller.state.user {
                    SQUserIcon(user: user)
                } else {
                    ZStack {
                        Circle()
                            .fill(SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.84 : 0.96))
                            .overlay(
                                Circle()
                                    .stroke(SQColor.glassStroke.color, lineWidth: 1)
                            )

                        SQImageView(
                            image: .init(
                                symbol: .personCircle,
                                symbolStyle: .colorWithFont(.textPrimary, font: .body)
                            )
                        )
                        .frame(width: 20, height: 20)
                    }
                    .frame(width: 42, height: 42)
                }

                VStack(alignment: .leading, spacing: .SQSpace.xs) {
                    Text(heroTitleText)
                        .sqFont(.title4)
                        .sqForegroundColor(.textPrimary)

                    Text(workoutDateText)
                        .sqFont(.bodyExtraSmall)
                        .sqForegroundColor(.textSecondary)
                }

                Spacer()
            }

            if !controller.state.isLoggedIn {
                HStack(spacing: .SQSpace.s) {
                    workoutMetaChip(title: "Storage", value: "Local only")

                    Text("Sign in to sync workout edits across devices.")
                        .sqFont(.bodyExtraSmall)
                        .sqForegroundColor(.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
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
        .frame(maxWidth: .infinity, alignment: .leading)
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

                Text("These responses help build better insights over time.")
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
        .frame(maxWidth: .infinity, alignment: .leading)
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

            if let premiumInsightsModel = controller.premiumInsightsModel {
                VStack(alignment: .leading, spacing: .SQSpace.m) {
                    SQWorkoutPremiumInsightsView(
                        model: premiumInsightsModel,
                        onScoreInfoTap: { score in
                            controller.displayPremiumInsightDetail(for: score)
                        }
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.SQSpace.l)
                .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
            }

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

            if let heartRateZonesViewModel = controller.heartRateZonesViewModel {
                SQDashboardSubsection(title: "Heart Rate Zones", isCollapsed: $heartRateZonesSectionCollapsed) {
                    SQWorkoutHeartRateZonesView(viewModel: heartRateZonesViewModel)
                }
            }

            if controller.state.shouldShowPerformanceSection {
                SQDashboardSubsection(title: "Performance", isCollapsed: $performanceSectionCollapsed) {
                    VStack(spacing: SQDashboardView.uiConfig.sectionRowSpacing) {
                        SQColumnHeaderRow(columns: [.leading("Stat"), .trailing("Score"), .trailing("Rank")])
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

private struct SQWorkoutHeartRateZonesView: View {
    let viewModel: SQWorkoutHeartRateZonesViewModel

    @State private var selectedZoneId: String?

    var body: some View {
        VStack(alignment: .leading, spacing: .SQSpace.l) {
            Text(viewModel.subtitle)
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textSecondary)

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: .SQSpace.xl) {
                    zoneChart
                    zoneLegend
                }

                VStack(alignment: .leading, spacing: .SQSpace.l) {
                    zoneChart
                    zoneLegend
                }
            }

            heartRateSummaryRow

            if let selectedItem {
                selectedZoneDetail(selectedItem)
            }

            Text(viewModel.footnote)
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var selectedItem: SQWorkoutHeartRateZonesViewModel.ZoneItem? {
        guard let selectedZoneId else { return nil }
        return viewModel.zoneItems.first(where: { $0.id == selectedZoneId })
    }

    private var zoneChart: some View {
        SQWorkoutHeartRateZonePieChart(
            items: viewModel.zoneItems,
            centerTopText: selectedItem?.title ?? "Avg HR",
            centerBottomText: selectedItem.map { durationText(for: $0.durationSeconds) } ?? viewModel.averageHeartRateText,
            selectedZoneId: selectedZoneId,
            onSelectionChanged: { zoneId in
                if selectedZoneId == zoneId {
                    selectedZoneId = nil
                } else {
                    selectedZoneId = zoneId
                }
            }
        )
        .frame(width: 148, height: 148)
    }

    private var zoneLegend: some View {
        VStack(alignment: .leading, spacing: .SQSpace.s) {
            ForEach(viewModel.zoneItems) { item in
                let isSelected = selectedZoneId == item.id
                Button {
                    if selectedZoneId == item.id {
                        selectedZoneId = nil
                    } else {
                        selectedZoneId = item.id
                    }
                } label: {
                    HStack(alignment: .center, spacing: .SQSpace.m) {
                        Capsule(style: .continuous)
                            .fill(item.color.color)
                            .frame(width: 16, height: 4)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .sqFont(.bodyExtraSmall)
                                .sqForegroundColor(isSelected ? .textPrimary : .textSecondary)

                            Text(item.rangeText)
                                .sqFont(.bodyExtraSmall)
                                .sqForegroundColor(.textSecondary)

                            Text("\(durationText(for: item.durationSeconds)) • \(durationPercentText(for: item.durationSeconds))")
                                .sqFont(.bodySmallSemiBold)
                                .sqForegroundColor(.textPrimary)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, .SQSpace.m)
                    .padding(.vertical, .SQSpace.s)
                    .background {
                        RoundedRectangle(cornerRadius: .SQCornerRadius.m, style: .continuous)
                            .fill(
                                isSelected
                                ? SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.92 : 1)
                                : Color.clear
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: .SQCornerRadius.m, style: .continuous)
                                    .stroke(
                                        isSelected
                                        ? SQColor.glassStrokeStrong.color
                                        : Color.white.opacity(0.001),
                                        lineWidth: 1
                                    )
                            }
                    }
                    .opacity(selectedZoneId == nil || isSelected ? 1 : 0.62)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, .SQSpace.s)
    }

    private var heartRateSummaryRow: some View {
        HStack(spacing: .SQSpace.s) {
            heartRateCard(title: "Min", value: viewModel.minimumHeartRateText, color: .accentNeutral4)
            heartRateCard(title: "Avg", value: viewModel.averageHeartRateText, color: .dashboardGlowBlue)
            heartRateCard(title: "Max", value: viewModel.maximumHeartRateText, color: .dashboardTrendWarm)
        }
    }

    private func heartRateCard(title: String, value: String, color: SQColor) -> some View {
        VStack(alignment: .leading, spacing: .SQSpace.xs) {
            Text(title.uppercased())
                .sqFont(.headerSmall)
                .sqForegroundColor(.textSecondary)

            Text(value)
                .sqFont(.bodySmallSemiBold)
                .sqForegroundColor(.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.SQSpace.m)
        .background {
            RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                .fill(SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.76 : 0.98))
                .overlay {
                    RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                        .stroke(color.color.opacity(SQColor.isDarkMode ? 0.42 : 0.24), lineWidth: 1)
                }
        }
    }

    private func selectedZoneDetail(_ item: SQWorkoutHeartRateZonesViewModel.ZoneItem) -> some View {
        VStack(alignment: .leading, spacing: .SQSpace.s) {
            HStack(alignment: .firstTextBaseline, spacing: .SQSpace.s) {
                Text("\(item.title) • \(item.subtitle)")
                    .sqFont(.bodySmallSemiBold)
                    .sqForegroundColor(.textPrimary)

                Spacer(minLength: 0)

                Text("\(Int(item.contribution.rounded())) pts")
                    .sqFont(.bodySmallSemiBold)
                    .sqForegroundColor(.textPrimary)
            }

            Text("\(durationText(for: item.durationSeconds)) in range \(item.rangeText). This zone contributed \(Int(item.contribution.rounded())) weighted load points.")
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.SQSpace.l)
        .background {
            RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                .fill(SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.72 : 0.96))
                .overlay {
                    RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                        .stroke(SQColor.glassStroke.color, lineWidth: 1)
                }
        }
    }

    private func durationText(for durationSeconds: Double) -> String {
        durationSeconds.readableTime()
    }

    private func durationPercentText(for durationSeconds: Double) -> String {
        let totalDuration = max(viewModel.zoneItems.reduce(0) { $0 + $1.durationSeconds }, 1)
        let percent = durationSeconds / totalDuration
        return percent.toPercentageString(decimals: 0)
    }
}

private struct SQWorkoutHeartRateZonePieChart: View {
    private static let chartSize: CGFloat = 148
    private static let centerDiscSize: CGFloat = 86

    let items: [SQWorkoutHeartRateZonesViewModel.ZoneItem]
    let centerTopText: String
    let centerBottomText: String
    let selectedZoneId: String?
    let onSelectionChanged: (String?) -> Void

    @State private var pieChartModel: PieChartModel?

    private var rebuildKey: String {
        items
            .map { "\($0.id):\($0.durationSeconds)" }
            .joined(separator: "|")
    }

    var body: some View {
        ZStack {
            if let pieChartModel {
                PieChartView(model: pieChartModel, visualStyle: .glass)
            } else {
                Circle()
                    .stroke(Color.white.opacity(SQColor.isDarkMode ? 0.16 : 0.24), lineWidth: 18)
            }

            Circle()
                .fill(SQColor.glassPopoverTint.color.opacity(SQColor.isDarkMode ? 0.92 : 1))
                .frame(width: Self.centerDiscSize, height: Self.centerDiscSize)
                .overlay {
                    Circle()
                        .stroke(SQColor.glassStrokeStrong.color, lineWidth: 1)
                }

            VStack(spacing: 2) {
                Text(centerTopText)
                    .sqFont(.bodyExtraSmall)
                    .sqForegroundColor(.textSecondary)

                Text(centerBottomText)
                    .sqFont(.bodySmallSemiBold)
                    .sqForegroundColor(.textPrimary)
            }
            .frame(width: Self.centerDiscSize - 10)
            .onTapGesture {
                onSelectionChanged(nil)
            }
        }
        .frame(width: Self.chartSize, height: Self.chartSize)
        .onAppear {
            rebuildModel()
        }
        .onChange(of: rebuildKey) { _, _ in
            rebuildModel()
        }
        .onChange(of: selectedZoneId) { _, newValue in
            guard let pieChartModel, pieChartModel.focusedSectionId != newValue else { return }
            pieChartModel.sectionFocused(sectionId: newValue, shouldCallFocusCompletionHandler: false)
        }
    }

    private func rebuildModel() {
        let model = PieChartModel(
            sections: items.map { item in
                PieChartSectionConfig(
                    id: item.id,
                    magnitude: max(0.0001, item.durationSeconds),
                    color: item.color.color,
                    radialFillPercent: 1,
                    radialUnfilledColor: Color.white.opacity(SQColor.isDarkMode ? 0.12 : 0.18)
                )
            },
            sectionIdTapped: { sectionId in
                onSelectionChanged(sectionId)
            },
            sectionAlignment: .center,
            widthHeight: Self.chartSize,
            focusGrowthPercent: 0.5
        )

        if let model {
            model.expectedPieSections = model.expectedPieSections.map { section in
                var section = section
                section.strokeWidth = 16
                section.expectedStrokeWidth = 16
                return section
            }
            model.pieSections = model.expectedPieSections
        }

        pieChartModel = model
        if pieChartModel?.focusedSectionId != selectedZoneId {
            pieChartModel?.sectionFocused(sectionId: selectedZoneId, shouldCallFocusCompletionHandler: false)
        }
    }
}
