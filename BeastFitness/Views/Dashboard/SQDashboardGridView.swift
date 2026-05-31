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
                    SQDashboardPrimaryValue(value: "\(Int(scoreRow.totalScore.rounded()))", unit: "Sleep Score")

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
                    Text(timeRow.currentValueAndTrend.value)
                        .sqFont(.title3)
                        .sqForegroundColor(.textPrimary)

                    if let trend = timeRow.currentValueAndTrend.trend {
                        SQDashboardTrendText(trend: trend)
                    }

                    if let caloriesRow {
                        SQDashboardMiniStat(title: "Calories", value: caloriesRow.currentValueAndTrend.value)
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
                    SQDashboardPrimaryValue(value: row.bestValue, unit: row.unit)

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
            onViewMore: {
                controller.displayDashboardDetail(
                    title: "Heart Overview",
                    sectionIds: ["heart-rate", "heart-access-warning", "heart-empty-warning"]
                )
            }
        ) {
            if let row {
                VStack(alignment: .leading, spacing: .SQSpace.s) {
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
        let rows = (section("activities")?.activeRows as? [SQDashboardActivityRowViewModel]) ?? []
        return rows
            .flatMap { $0.workoutGroupViewModels }
            .flatMap { $0.workouts.workouts }
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
                .sqForegroundColor(.textPrimary)
                .lineLimit(1)

            SQImageView(
                image: .init(
                    symbol: .chevronRight,
                    symbolStyle: .colorWithFont(.textSecondary, font: .bodyExtraSmall)
                )
            )
            .frame(width: 9, height: 9)
        }
    }
}

private struct SQDashboardGridCard<Content: View>: View {
    let title: String
    let icon: SQImageSymbol
    let accentColor: SQColor
    let onViewMore: () -> Void
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

                Text(title)
                    .sqFont(.bodyBold)
                    .sqForegroundColor(.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Spacer(minLength: 0)
            }

            content()
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            Button(action: onViewMore) {
                SQDashboardViewMoreLabel()
            }
            .buttonStyle(.plain)
        }
        .padding(.SQSpace.l)
        .frame(maxWidth: .infinity, minHeight: 166, alignment: .topLeading)
        .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl, showsShadow: false)
    }
}

private struct SQDashboardPrimaryValue: View {
    let value: String
    let unit: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(value)
                .sqFont(.title1)
                .sqForegroundColor(.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.74)

            Text(unit)
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
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
                .sqForegroundColor(.textSecondary)

            if let value = value as? AttributedString {
                Text(value)
                    .sqFont(.bodySmallSemiBold)
                    .sqForegroundColor(.textPrimary)
                    .lineLimit(1)
            } else {
                Text(value as? String ?? "")
                    .sqFont(.bodySmallSemiBold)
                    .sqForegroundColor(.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
        }
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
                .sqForegroundColor(.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: .SQSpace.s)

            Text(value)
                .sqFont(.bodySmallSemiBold)
                .sqForegroundColor(.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            if let trailing {
                Text(trailing)
                    .sqFont(.bodyExtraSmall)
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
                .sqForegroundColor(.textPrimary)
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
                .sqForegroundColor(.textSecondary)

            if let emphasizedValue = trend.emphasizedValue {
                Text(emphasizedValue)
                    .sqFont(.bodySmallSemiBold)
                    .sqForegroundColor(trend.tone.accentColor)
            }

            Text(trend.suffix)
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textSecondary)
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
