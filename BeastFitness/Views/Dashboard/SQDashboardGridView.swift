//
//  SQDashboardGridView.swift
//  BeastFitness
//
//  Created by Codex on 5/30/26.
//

import SwiftUI

struct SQDashboardGridView: View {
    @Bindable var controller: SQDashboardController
    let lifeScoreViewModel: SQLifeScoreViewModel?

    private var layoutCardIds: [String] {
        controller.state.sectionGroups.flatMap { group in
            group.sections.map(\.id)
        }
    }

    private var detailSections: [SQDashboardSubsectionViewModel] {
        controller.state.uncustomizedSectionGroups.flatMap(\.sections)
    }

    private let columns = [
        GridItem(.adaptive(minimum: 164), spacing: .SQSpace.m, alignment: .top)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .center, spacing: .SQSpace.m) {
            ForEach(layoutCardIds, id: \.self) { cardId in
                card(for: cardId)
                    .frame(maxWidth: .infinity, minHeight: 166, alignment: .topLeading)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, .SQSpace.xl)
    }

    @ViewBuilder
    private func card(for cardId: String) -> some View {
        switch cardId {
        case "sleep-overview":
            sleepCard
        case "sleep-phases":
            sleepPhasesCard
        case "top-insight":
            topInsightCard
        case "key-metrics":
            keyMetricsCard
        case "latest-workout":
            latestWorkoutCard
        case "activity-calories":
            activityCaloriesCard
        case "vo2-max":
            vo2MaxCard
        case "heart-overview":
            heartOverviewCard
        default:
            EmptyView()
        }
    }

    private func section(_ id: String) -> SQDashboardSubsectionViewModel? {
        detailSections.first(where: { $0.id == id })
    }

    private var showsAverageContext: Bool {
        controller.state.selectedTimeRange != .today
    }

    private var currentRangeWorkouts: [SQWorkoutSessionable] {
        let rows = (section("activities")?.activeRows as? [SQDashboardActivityRowViewModel]) ?? []
        return rows
            .flatMap { $0.workoutGroupViewModels }
            .flatMap { $0.workouts.workouts }
    }

    private var selectedRangeAverageDayCount: Double {
        switch controller.state.selectedTimeRange {
        case .today:
            return 1
        case .pastSevenDays:
            return 7
        case .past30Days:
            return 30
        case .pastYear:
            return 365
        case .allTime:
            let dates = currentRangeWorkouts.compactMap(\.startDate)
            guard let firstDate = dates.min(), let lastDate = dates.max() else {
                return 1
            }

            let calendar = Calendar.current
            let firstDay = calendar.startOfDay(for: firstDate)
            let lastDay = calendar.startOfDay(for: lastDate)
            let days = calendar.dateComponents([.day], from: firstDay, to: lastDay).day ?? 0
            return Double(max(1, days + 1))
        }
    }

}

// MARK: - Cards

private extension SQDashboardGridView {
    var sleepCard: some View {
        let scoreRow = section("sleep-score")?.activeRows.first as? SQDashboardSleepScoreRowViewModel
        let summaryItems = (section("sleep-summary")?.activeRows.first as? SQDashboardSleepSummaryRowViewModel)?.items ?? []
        let duration = summaryItems.first(where: { $0.id == "sleep-total" })?.value
        let efficiency = scoreRow?.components.first(where: { $0.id == "efficiency" })

        return SQDashboardGridCard(
            title: "Sleep",
            icon: .bedDoubleFill,
            accentColor: .accentSecondary(1),
            onViewMore: {
                controller.displayDashboardDetail(
                    title: "Sleep",
                    sectionIds: [
                        "sleep-score",
                        "sleep-summary",
                        "sleep-duration",
                        "sleep-timeline",
                        "sleep-access-warning",
                        "sleep-empty-warning"
                    ]
                )
            }
        ) {
            if let scoreRow {
                VStack(alignment: .leading, spacing: .SQSpace.m) {
                    if showsAverageContext {
                        SQDashboardAverageBadge()
                    }

                    SQDashboardPrimaryValue(
                        value: "\(Int(scoreRow.totalScore.rounded()))",
                        unit: showsAverageContext
                            ? scoreRow.scoreValueLabel.replacingOccurrences(of: "Avg ", with: "")
                            : scoreRow.scoreValueLabel
                    )

                    if let trendDelta = scoreRow.trendDelta {
                        SQDashboardTrendDeltaPill(viewModel: trendDelta)
                    }

                    VStack(alignment: .leading, spacing: .SQSpace.s) {
                        if let duration {
                            SQDashboardMiniStat(title: "Duration", value: duration)
                        }
                        if let efficiency {
                            SQDashboardMiniStat(
                                title: "Efficiency",
                                value: "\(Int(efficiency.score.rounded()))/\(Int(efficiency.maxScore.rounded()))"
                            )
                        }
                    }
                }
            } else {
                SQDashboardCardEmptyState(
                    title: "No sleep data yet",
                    subtitle: "Connect Sleep in Health or wear Apple Watch overnight."
                )
            }
        }
    }

    var sleepPhasesCard: some View {
        let rows = (section("sleep-phases")?.activeRows as? [SQDashboardMetricStatsRowViewModel]) ?? []

        return SQDashboardGridCard(
            title: "Sleep Phases",
            icon: .moonZzzFill,
            accentColor: .accentSecondary(1),
            onViewMore: {
                controller.displayDashboardDetail(
                    title: "Sleep Phases",
                    sectionIds: ["sleep-phases", "sleep-access-warning", "sleep-empty-warning"]
                )
            }
        ) {
            if rows.isEmpty {
                SQDashboardCardEmptyState(
                    title: "No phase data yet",
                    subtitle: "Sleep stages appear after Apple Health has enough data."
                )
            } else {
                VStack(alignment: .leading, spacing: .SQSpace.s) {
                    if showsAverageContext {
                        SQDashboardAverageBadge()
                    }

                    SQDashboardPhaseBar(rows: rows)

                    ForEach(rows.prefix(4)) { row in
                        SQDashboardMetricLine(title: row.title, value: row.avgValue, trailing: row.changePercent?.toPercentageString(decimals: 0))
                    }
                }
            }
        }
    }

    var topInsightCard: some View {
        let insightRow = section("insights")?.activeRows.first as? SQDashboardInsightRowViewModel
        let insight = insightRow?.model ?? lifeScoreViewModel?.primaryInsight

        return SQDashboardGridCard(
            title: "Top Insight",
            icon: .sparkles,
            accentColor: .dashboardGlowMint,
            onViewMore: {
                controller.displayDashboardDetail(title: "Insights", sectionIds: ["insights"])
            }
        ) {
            if let insight {
                VStack(alignment: .leading, spacing: .SQSpace.s) {
                    Button {
                        if let insightRow {
                            insightRow.onInfoTap?()
                        } else if lifeScoreViewModel != nil {
                            controller.handleLifeScoreTap()
                        }
                    } label: {
                        HStack(alignment: .top, spacing: .SQSpace.s) {
                            Text(insight.title)
                                .sqFont(.bodySemiBold)
                                .sqForegroundColor(.textPrimary)
                                .lineLimit(3)
                                .fixedSize(horizontal: false, vertical: true)

                            Spacer(minLength: 0)

                            SQImageView(
                                image: .init(
                                    symbol: .chevronRight,
                                    symbolStyle: .colorWithFont(.textSecondary, font: .bodyExtraSmall)
                                )
                            )
                            .frame(width: 9, height: 9)
                            .padding(.top, 4)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Text(insight.confidence.badgeTitle)
                        .sqFont(.bodyExtraSmall)
                        .sqForegroundColor(.dashboardGlowMint)

                    Text(insight.deltaText)
                        .sqFont(.title3)
                        .sqForegroundColor(insight.effect == .positive ? .dashboardGlowMint : .colorErrorRed)
                }
            } else {
                SQDashboardCardEmptyState(
                    title: "Insights are calibrating",
                    subtitle: "Keep logging check-ins, sleep, and workouts."
                )
            }
        }
    }

    var keyMetricsCard: some View {
        let section = section("metrics")
        let rows = ((section?.activeRows as? [SQDashboardMetricStatsRowViewModel]) ?? [])
            .sorted { lhs, rhs in
                abs(lhs.changePercent ?? 0) > abs(rhs.changePercent ?? 0)
            }

        return SQDashboardGridCard(
            title: "Key Metrics",
            icon: .chartBar,
            accentColor: .dashboardGlowBlue,
            onViewMore: {
                controller.displayDashboardDetail(title: "Key Metrics", sectionIds: ["metrics"])
            }
        ) {
            if section?.isLocked == true {
                SQDashboardCardEmptyState(
                    title: "Log in to unlock",
                    subtitle: "Your check-in metrics are saved to your account."
                )
            } else if rows.isEmpty {
                SQDashboardCardEmptyState(
                    title: "No metrics yet",
                    subtitle: "Complete a daily check-in to populate this card."
                )
            } else {
                VStack(alignment: .leading, spacing: .SQSpace.s) {
                    if showsAverageContext {
                        SQDashboardAverageBadge()
                    }

                    ForEach(rows.prefix(4)) { row in
                        SQDashboardMetricLine(
                            title: row.title,
                            value: row.avgValue + row.unit,
                            trailing: row.changePercent?.toPercentageString(decimals: 0)
                        )
                    }
                }
            }
        }
    }

    var latestWorkoutCard: some View {
        let workout = latestWorkout

        return SQDashboardGridCard(
            title: "Latest Workout",
            icon: workout?.activityType.imageSymbol ?? .figureRun,
            accentColor: .dashboardTrendWarm,
            onViewMore: {
                controller.displayWorkoutsList()
            }
        ) {
            if let workout {
                VStack(alignment: .leading, spacing: .SQSpace.m) {
                    Button {
                        controller.displayWorkoutDetail(workout)
                    } label: {
                        HStack(spacing: .SQSpace.s) {
                            Text(workout.activityType.name)
                                .sqFont(.bodySemiBold)
                                .sqForegroundColor(.textPrimary)
                                .lineLimit(1)

                            Spacer(minLength: 0)

                            SQImageView(
                                image: .init(
                                    symbol: .chevronRight,
                                    symbolStyle: .colorWithFont(.textSecondary, font: .bodyExtraSmall)
                                )
                            )
                            .frame(width: 9, height: 9)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if let startDate = workout.startDate {
                        Text(startDate.formattedString(with: .medium))
                            .sqFont(.bodyExtraSmall)
                            .sqForegroundColor(.textSecondary)
                    }

                    HStack(spacing: .SQSpace.m) {
                        if let activeDuration = workout.activeDuration {
                            SQDashboardMiniStat(title: "Time", value: SQDashboardGridFormatter.duration(activeDuration))
                        }
                        if let calories = workout.totalCalories {
                            SQDashboardMiniStat(title: "Calories", value: "\(Int(calories.rounded()))")
                        }
                    }

                    if let scoreModel = controller.latestWorkoutPremiumInsightsModel {
                        SQDashboardLatestWorkoutScorePreview(
                            model: scoreModel,
                            onScoreTap: { score in
                                controller.displayWorkoutScoreDetail(score)
                            },
                            onLockedTap: {
                                controller.displayWorkoutScoreSubscription(
                                    source: "dashboard_latest_workout_score_preview"
                                )
                            }
                        )
                    }
                }
            } else {
                SQDashboardCardEmptyState(
                    title: "No workouts yet",
                    subtitle: "Record a workout to see your latest session."
                )
            }
        }
    }

    var activityCaloriesCard: some View {
        let timeRow = section("totals")?.rowsByFilter["Time"]?.first as? SQDashboardWorkoutTotalsRowViewModel
        let caloriesRow = section("totals")?.rowsByFilter["Kilocalories"]?.first as? SQDashboardWorkoutTotalsRowViewModel
        let workouts = currentRangeWorkouts
        let averageDayCount = selectedRangeAverageDayCount
        let averageActiveSeconds = workouts.reduce(0) { $0 + ($1.activeDuration ?? 0) } / averageDayCount
        let averageCalories = workouts.reduce(0) { $0 + ($1.totalCalories ?? 0) } / averageDayCount

        return SQDashboardGridCard(
            title: "Activity & Calories",
            icon: .flame,
            accentColor: .dashboardTrendWarm,
            onViewMore: {
                controller.displayDashboardDetail(
                    title: "Activity & Calories",
                    sectionIds: ["totals", "activities", "workouts-access-warning", "workouts-empty-warning"]
                )
            }
        ) {
            if let timeRow {
                VStack(alignment: .leading, spacing: .SQSpace.m) {
                    if showsAverageContext {
                        SQDashboardAverageBadge()

                        SQDashboardPrimaryValue(
                            value: SQDashboardGridFormatter.duration(averageActiveSeconds),
                            unit: "per day"
                        )
                    } else {
                        Text(timeRow.currentValueAndTrend.value)
                            .sqFont(.title1)
                            .monospacedDigit()
                            .sqForegroundColor(.textPrimary)
                    }

                    if let trend = timeRow.currentValueAndTrend.trend {
                        SQDashboardTrendText(trend: trend)
                    }

                    if let caloriesRow {
                        if showsAverageContext {
                            SQDashboardMiniStat(
                                title: "Calories",
                                value: "\(Int(averageCalories.rounded())) kcal"
                            )
                        } else {
                            SQDashboardMiniStat(title: "Calories", value: caloriesRow.currentValueAndTrend.value)
                        }
                    }

                    SQDashboardMiniBars(points: timeRow.currentChartDataPoints)
                        .frame(height: 54)
                }
            } else {
                SQDashboardCardEmptyState(
                    title: "No activity data",
                    subtitle: "Workouts and active calories will appear here."
                )
            }
        }
    }

    var vo2MaxCard: some View {
        let row = (section("performance")?.activeRows as? [SQDashboardMetricPerformanceRowViewModel])?
            .first(where: { $0.metricId == "vo2-max" })

        return SQDashboardGridCard(
            title: "VO₂ Max",
            icon: .heart,
            accentColor: .colorFadedRed,
            onViewMore: {
                if let row {
                    controller.displayPerformanceRow(row)
                } else {
                    controller.displayDashboardDetail(
                        title: "Performance",
                        sectionIds: ["performance", "workouts-access-warning", "workouts-empty-warning"]
                    )
                }
            }
        ) {
            if let row {
                VStack(alignment: .leading, spacing: .SQSpace.m) {
                    if showsAverageContext {
                        SQDashboardAverageBadge()
                    }

                    SQDashboardPrimaryValue(
                        value: row.bestValue,
                        unit: showsAverageContext
                            ? row.valueUnitLabel.replacingOccurrences(of: "avg ", with: "")
                            : row.valueUnitLabel
                    )

                    if let trendDelta = row.trendDelta {
                        SQDashboardTrendDeltaPill(viewModel: trendDelta)
                    }

                    if let percentileRank = row.percentileRank {
                        Text("Top \(max(1, Int(ceil((1.0 - percentileRank) * 100))))%")
                            .sqFont(.bodySmallSemiBold)
                            .sqForegroundColor(.textPrimary)
                    }
                }
            } else {
                SQDashboardCardEmptyState(
                    title: "No VO₂ Max data yet",
                    subtitle: "Record outdoor walks or runs with Apple Watch to estimate VO₂ Max."
                )
            }
        }
    }

    var heartOverviewCard: some View {
        let row = section("heart-rate")?.activeRows.first as? SQDashboardHeartSummaryRowViewModel

        return SQDashboardGridCard(
            title: "Heart Overview",
            icon: .heart,
            accentColor: .colorFadedRed,
            onViewMore: nil
        ) {
            if let row {
                VStack(alignment: .leading, spacing: .SQSpace.s) {
                    if showsAverageContext {
                        SQDashboardAverageBadge()
                    }

                    ForEach(row.items.prefix(3)) { item in
                        SQDashboardMetricLine(
                            title: item.title,
                            value: item.value == "--" ? "--" : "\(item.value) \(item.unit)",
                            trailing: nil
                        )
                    }
                }
            } else {
                SQDashboardCardEmptyState(
                    title: "No heart data",
                    subtitle: "Enable Heart Rate and Resting Heart Rate in Health."
                )
            }
        }
    }

    var latestWorkout: SQWorkoutSessionable? {
        currentRangeWorkouts
            .max { lhs, rhs in
                (lhs.startDate ?? .distantPast) < (rhs.startDate ?? .distantPast)
            }
    }
}

// MARK: - Shared Pieces

struct SQDashboardViewMoreLabel: View {
    var body: some View {
        HStack(spacing: 4) {
            Text("View more")
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textTertiary)
                .lineLimit(1)

            SQImageView(
                image: .init(
                    symbol: .chevronRight,
                    symbolStyle: .colorWithFont(.textTertiary, font: .bodyExtraSmall)
                )
            )
            .frame(width: 9, height: 9)
        }
    }
}

struct SQDashboardTrendDeltaPill: View {
    let viewModel: SQDashboardTrendDeltaViewModel

    var body: some View {
        HStack(spacing: .SQSpace.xs) {
            SQDashboardTrendBadge(
                text: viewModel.valueText,
                tone: viewModel.tone,
                symbol: viewModel.symbol
            )

            Text(viewModel.comparisonText)
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.76)
        }
    }
}

private struct SQDashboardGridCard<Content: View>: View {
    let title: String
    let icon: SQImageSymbol
    let accentColor: SQColor
    let onViewMore: (() -> Void)?
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: .SQSpace.m) {
            HStack(alignment: .center, spacing: .SQSpace.s) {
                SQImageView(
                    image: .init(
                        symbol: icon,
                        symbolStyle: .colorWithFont(accentColor, font: .bodySmall)
                    )
                )
                .frame(width: 18, height: 18)
                .opacity(0.82)

                Text(title)
                    .sqFont(.bodySmallSemiBold)
                    .sqForegroundColor(.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Spacer(minLength: 0)
            }

            content()
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            if let onViewMore {
                Button(action: onViewMore) {
                    SQDashboardViewMoreLabel()
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.SQSpace.l)
        .frame(maxWidth: .infinity, minHeight: 166, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous)
                .fill(SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.64 : 0.82))
                .overlay {
                    RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous)
                        .stroke(SQColor.glassStroke.color.opacity(SQColor.isDarkMode ? 0.58 : 0.72), lineWidth: 1)
                }
        }
    }
}

private struct SQDashboardPrimaryValue: View {
    let value: String
    let unit: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(value)
                .sqFont(.title1)
                .monospacedDigit()
                .sqForegroundColor(.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.74)

            Text(unit)
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
    }
}

private struct SQDashboardAverageBadge: View {
    var body: some View {
        Text("Avg")
            .sqFont(.headerSmall)
            .sqForegroundColor(.textTertiary)
            .padding(.horizontal, .SQSpace.s)
            .padding(.vertical, 4)
            .background {
                Capsule(style: .continuous)
                    .fill(SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.48 : 0.62))
                    .overlay {
                        Capsule(style: .continuous)
                            .stroke(SQColor.glassStroke.color.opacity(SQColor.isDarkMode ? 0.48 : 0.58), lineWidth: 1)
                    }
            }
    }
}

private struct SQDashboardMiniStat: View {
    let title: String
    let value: Any

    init(title: String, value: String) {
        self.title = title
        self.value = value
    }

    init(title: String, value: AttributedString) {
        self.title = title
        self.value = value
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .sqFont(.headerSmall)
                .sqForegroundColor(.textTertiary)

            if let value = value as? AttributedString {
                Text(value)
                    .sqFont(.bodySmallBold)
                    .sqForegroundColor(.textPrimary)
                    .monospacedDigit()
                    .lineLimit(1)
            } else {
                Text(value as? String ?? "")
                    .sqFont(.bodySmallBold)
                    .monospacedDigit()
                    .sqForegroundColor(.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
        }
    }
}

private struct SQDashboardLatestWorkoutScorePreview: View {
    let model: SQWorkoutPremiumInsightsModel
    let onScoreTap: (SQWorkoutPremiumInsightScore) -> Void
    let onLockedTap: () -> Void

    private var isLocked: Bool {
        model.availability == .locked
    }

    private var lockedSubtitle: String? {
        model.lockedSubtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .SQSpace.s) {
            HStack(spacing: .SQSpace.xs) {
                Text("Scores")
                    .sqFont(.headerSmall)
                    .sqForegroundColor(.textTertiary)

                if isLocked {
                    SQImageView(
                        image: .init(
                            symbol: .lockFill,
                            symbolStyle: .colorWithFont(.textTertiary, font: .bodyExtraSmall)
                        )
                    )
                    .frame(width: 9, height: 9)
                }
            }

            ZStack {
                HStack(spacing: .SQSpace.s) {
                    ForEach(model.scores.prefix(2)) { score in
                        scoreChip(score)
                    }
                }
                .blur(radius: isLocked ? 4.5 : 0)
                .opacity(isLocked ? 0.72 : 1)

                if isLocked {
                    Button(action: onLockedTap) {
                        HStack(spacing: .SQSpace.xs) {
                            SQImageView(
                                image: .init(
                                    symbol: .lockFill,
                                    symbolStyle: .colorWithFont(.textPrimary, font: .bodyExtraSmall)
                                )
                            )
                            .frame(width: 10, height: 10)

                            Text("Unlock")
                                .sqFont(.bodySmallSemiBold)
                                .sqForegroundColor(.textPrimary)
                        }
                        .padding(.horizontal, .SQSpace.s)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule(style: .continuous))
                        .overlay {
                            Capsule(style: .continuous)
                                .stroke(SQColor.glassStrokeStrong.color.opacity(0.48), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            if isLocked, let lockedSubtitle {
                Text(lockedSubtitle)
                    .sqFont(.bodyExtraSmall)
                    .sqForegroundColor(.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func scoreChip(_ score: SQWorkoutPremiumInsightScore) -> some View {
        Button {
            if isLocked {
                onLockedTap()
            } else {
                onScoreTap(score)
            }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(score.title.uppercased())
                    .sqFont(.headerSmall)
                    .sqForegroundColor(.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(score.value)")
                        .sqFont(.bodySmallBold)
                        .monospacedDigit()
                        .sqForegroundColor(.textPrimary)

                    Text("/100")
                        .sqFont(.bodyExtraSmall)
                        .sqForegroundColor(.textTertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, .SQSpace.s)
            .padding(.vertical, 7)
            .background {
                RoundedRectangle(cornerRadius: .SQCornerRadius.m, style: .continuous)
                    .fill(score.accentColor.color.opacity(SQColor.isDarkMode ? 0.12 : 0.10))
                    .overlay {
                        RoundedRectangle(cornerRadius: .SQCornerRadius.m, style: .continuous)
                            .stroke(score.accentColor.color.opacity(SQColor.isDarkMode ? 0.28 : 0.20), lineWidth: 1)
                    }
            }
        }
        .buttonStyle(.plain)
    }
}

private struct SQDashboardMetricLine: View {
    let title: String
    let value: String
    let trailing: String?

    private var trailingColor: SQColor {
        guard let trailing else { return .textSecondary }
        return trailing.hasPrefix("-") ? .colorErrorRed : .dashboardGlowMint
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: .SQSpace.s) {
            Text(title)
                .sqFont(.bodySmall)
                .sqForegroundColor(.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: .SQSpace.s)

            Text(value)
                .sqFont(.bodySmallSemiBold)
                .monospacedDigit()
                .sqForegroundColor(.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            if let trailing {
                Text(trailing)
                    .sqFont(.bodySmallSemiBold)
                    .monospacedDigit()
                    .sqForegroundColor(trailingColor)
                    .lineLimit(1)
            }
        }
    }
}

private struct SQDashboardCardEmptyState: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: .SQSpace.s) {
            Text(title)
                .sqFont(.bodySmallSemiBold)
                .sqForegroundColor(.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Text(subtitle)
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct SQDashboardPhaseBar: View {
    let rows: [SQDashboardMetricStatsRowViewModel]

    private let colors: [SQColor] = [.accentSecondary(1), .dashboardGlowBlue, .dashboardGlowMint, .dashboardTrendWarm]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(rows.prefix(4).enumerated()), id: \.element.id) { index, row in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(colors[index % colors.count].color)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel(row.title)
            }
        }
        .frame(height: 12)
    }
}

private struct SQDashboardMiniBars: View {
    let points: [SQDashboardWorkoutTotalsRowViewModel.ChartDataPoint]

    var body: some View {
        let maxValue = points.map(\.value).max() ?? 1
        HStack(alignment: .bottom, spacing: 5) {
            ForEach(points.prefix(12)) { point in
                VStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(SQColor.dashboardTrendWarm.color.opacity(0.88))
                        .frame(height: max(6, CGFloat(point.value / max(maxValue, 1)) * 42))
                    Text(point.label)
                        .sqFont(.bodyExtraSmall)
                        .sqForegroundColor(.textTertiary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

private struct SQDashboardTrendText: View {
    let trend: SQDashboardWorkoutTotalsRowViewModel.TrendSummary

    var body: some View {
        HStack(spacing: .SQSpace.xs) {
            Text(trend.prefix)
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textTertiary)

            if let emphasizedValue = trend.emphasizedValue {
                Text(emphasizedValue)
                    .sqFont(.bodySmallSemiBold)
                    .monospacedDigit()
                    .sqForegroundColor(trend.tone.accentColor)
            }

            Text(trend.suffix)
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textTertiary)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.72)
    }
}

private enum SQDashboardGridFormatter {
    static func duration(_ seconds: Double) -> String {
        let totalMinutes = max(0, Int((seconds / 60).rounded()))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }

        return "\(minutes)m"
    }
}
