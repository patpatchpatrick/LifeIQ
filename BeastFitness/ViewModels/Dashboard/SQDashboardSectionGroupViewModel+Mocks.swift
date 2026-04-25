//
//  SQDashboardSectionGroupViewModel+Mocks.swift
//  BeastFitness
//

import Foundation
import SwiftUI
import CoolCharts

@MainActor
extension SQDashboardSectionGroupViewModel {

    static func mock(for timeRange: AppTimeRange) -> [SQDashboardSectionGroupViewModel] {
        var groups = [SQDashboardSectionGroupViewModel]()

        if timeRange == .today {
            groups.append(mockRecovery)
        }

        groups.append(contentsOf: [mockDailyStats, mockInsightsGroup, mockSleep, mockHeart, mockWorkouts])
        return groups
    }

    private static var mockRecovery: SQDashboardSectionGroupViewModel {
        let bodyBatteryRow = SQDashboardBodyBatteryRowViewModel(
            score: 78,
            statusTitle: "Solid",
            statusTone: .positive,
            headline: "Recovery is carrying you",
            summary: "Strong sleep recharge is keeping your energy reserves elevated, though recent training is eating into some of it.",
            drivers: [
                .init(title: "Sleep", valueText: "+41", detailText: "Sleep Score 79 last night", attributedDetailText: buildBodyBatteryMockDetail([.plain("Sleep Score "), .highlight("79"), .plain(" last night")]), tone: .positive, symbol: .arrowUp, alert: nil),
                .init(title: "Strain", valueText: "-11", detailText: "11 pts from 2 today, 1 yesterday", attributedDetailText: buildBodyBatteryMockDetail([.highlight("11 pts"), .plain(" from "), .highlight("2"), .plain(" today, "), .highlight("1"), .plain(" yesterday")]), tone: .negative, symbol: .arrowDown, alert: nil),
                .init(title: "Check-ins", valueText: "+4", detailText: "+4 from today's signals", attributedDetailText: buildBodyBatteryMockDetail([.highlight("+4"), .plain(" from today's signals")]), tone: .positive, symbol: .arrowUp, alert: nil)
            ],
            formulaAlert: .init(
                title: "How Recovery Score Is Calculated",
                subtitle: "Recovery Score starts from a neutral baseline and then adjusts based on the signals available today. Missing signals are omitted.",
                primary: .ok,
                canDismiss: true
            ),
            footer: "Estimated from last night’s sleep, current workout strain, and today’s recovery signals."
        )

        let bodyBatterySection = SQDashboardSubsectionViewModel(
            id: "recovery-score",
            title: "Recovery Score",
            defaultPriority: 10,
            rowsByFilter: ["All": [bodyBatteryRow]]
        )

        return SQDashboardSectionGroupViewModel(
            id: "recovery",
            title: "Recovery",
            defaultPriority: 15,
            sections: [bodyBatterySection]
        )
    }

    // MARK: - Daily Stats

    private static var mockDailyStats: SQDashboardSectionGroupViewModel {
        let mockRows: [SQDashboardRowViewModel] = [
            SQDashboardMetricStatsRowViewModel(
                metricId: "mock-mood", icon: "😊", title: "Mood",
                avgValue: "7.5", unit: "/10",
                sparklineData: [6, 7, 8, 7, 7.5], changePercent: 0.05
            ),
            SQDashboardMetricStatsRowViewModel(
                metricId: "mock-energy", icon: "⚡️", title: "Energy",
                avgValue: "6.8", unit: "/10",
                sparklineData: [5, 6, 7, 7, 6.8], changePercent: -0.02
            ),
            SQDashboardMetricStatsRowViewModel(
                metricId: "mock-sleep", icon: "😴", title: "Sleep Hours",
                avgValue: "7.2", unit: "hrs",
                sparklineData: [7, 8, 6, 7, 7.2], changePercent: 0.03
            ),
            SQDashboardMetricStatsRowViewModel(
                metricId: "mock-energy", icon: "⚡️", title: "Energy",
                avgValue: "6.8", unit: "/10",
                sparklineData: [5, 6, 7, 7, 6.8], changePercent: -0.02
            ),
            SQDashboardMetricStatsRowViewModel(
                metricId: "mock-sleep", icon: "😴", title: "Sleep Hours",
                avgValue: "7.2", unit: "hrs",
                sparklineData: [7, 8, 6, 7, 7.2], changePercent: 0.03
            ),
            SQDashboardMetricStatsRowViewModel(
                metricId: "mock-energy", icon: "⚡️", title: "Energy",
                avgValue: "6.8", unit: "/10",
                sparklineData: [5, 6, 7, 7, 6.8], changePercent: -0.02
            ),
            SQDashboardMetricStatsRowViewModel(
                metricId: "mock-sleep", icon: "😴", title: "Sleep Hours",
                avgValue: "7.2", unit: "hrs",
                sparklineData: [7, 8, 6, 7, 7.2], changePercent: 0.03
            ),
            SQDashboardMetricStatsRowViewModel(
                metricId: "mock-clarity", icon: "🧠", title: "Mental Clarity",
                avgValue: "7.0", unit: "/10",
                sparklineData: [6, 7, 7, 8, 7.0], changePercent: 0.08
            ),
        ]

        let metricsSection = SQDashboardSubsectionViewModel(
            id: "metrics",
            title: "Metrics",
            defaultPriority: 10,
            rowsByFilter: ["All": mockRows],
            columnHeaders: ["Metric", "Avg Score", "vs Prior"]
        )

        return SQDashboardSectionGroupViewModel(
            id: "daily-stats",
            title: "Daily Stats",
            defaultPriority: 20,
            sections: [metricsSection]
        )
    }

    private static var mockInsightsGroup: SQDashboardSectionGroupViewModel {
        SQDashboardSectionGroupViewModel(
            id: "insights",
            title: "Insights",
            defaultPriority: 25,
            sections: [mockInsightsSection]
        )
    }

    private static var mockInsightsSection: SQDashboardSubsectionViewModel {
        let insights = mockInsights
        let rows = insights.map { SQDashboardInsightRowViewModel(model: $0) as SQDashboardRowViewModel }
        let categoryOrder: [SQInsightCategory] = [.recovery, .sleep, .training, .habits]
        let presentCategories = categoryOrder.filter { category in
            insights.contains(where: { $0.category == category })
        }

        var rowsByFilter: [String: [SQDashboardRowViewModel]] = ["All": rows]
        for category in presentCategories {
            rowsByFilter[category.badgeTitle] = insights
                .filter { $0.category == category }
                .map { SQDashboardInsightRowViewModel(model: $0) as SQDashboardRowViewModel }
        }

        let filterItems = [SQDropDownMenuViewModel.Item(title: "All")] + presentCategories.map {
            SQDropDownMenuViewModel.Item(title: $0.badgeTitle)
        }
        let dropDownViewModel = SQDropDownMenuViewModel(
            defaultItem: .init(title: "All"),
            items: filterItems,
            itemSelectionHandler: { _ in }
        )

        let sectionViewModel = SQDashboardSubsectionViewModel(
            id: "insights",
            title: "Insights",
            defaultPriority: 15,
            rowsByFilter: rowsByFilter,
            dropDownViewModel: dropDownViewModel,
            rowSpacing: .SQSpace.m,
            maxVisibleRows: 4
        )

        dropDownViewModel.itemSelectionHandler = { selectedFilter in
            sectionViewModel.updateActiveFilter(selectedFilter)
        }

        return sectionViewModel
    }

    private static var mockInsights: [SQInsight] {
        [
            .init(
                id: "mock.insight.sleep-energy",
                familyKey: "metric.sleepHours->metric.energy",
                title: "Longer sleep tends to lift energy",
                summary: "On days after 8+ hours of sleep, your energy check-ins trend about 1.2 points higher.",
                evidenceText: "Sample dashboard insight for UI testing.",
                actionText: "Protect sleep duration before harder training days.",
                driverText: "More Sleep",
                outcomeText: "Higher Energy",
                deltaText: "+1.2 pts",
                category: .recovery,
                confidence: .medium,
                effect: .positive,
                sampleCount: 18,
                rankingScore: 0.94
            ),
            .init(
                id: "mock.insight.alcohol-sleep",
                familyKey: "metric.alcohol->metric.sleepQuality",
                title: "Alcohol is dragging sleep quality",
                summary: "Even moderate drinking nights are followed by lower sleep-quality check-ins the next morning.",
                evidenceText: "Sample dashboard insight for UI testing.",
                actionText: "Try alcohol-free evenings before important recovery days.",
                driverText: "More Alcohol",
                outcomeText: "Lower Sleep Quality",
                deltaText: "-0.9 pts",
                category: .sleep,
                confidence: .medium,
                effect: .negative,
                sampleCount: 15,
                rankingScore: 0.89
            ),
            .init(
                id: "mock.insight.caffeine-workout",
                familyKey: "metric.caffeine->metric.workoutPerformance",
                title: "Earlier caffeine aligns with better sessions",
                summary: "Workouts started after an earlier caffeine window tend to score better than late-caffeine days.",
                evidenceText: "Sample dashboard insight for UI testing.",
                actionText: "Front-load caffeine before midday when possible.",
                driverText: "Earlier Caffeine",
                outcomeText: "Better Training",
                deltaText: "+6%",
                category: .training,
                confidence: .low,
                effect: .positive,
                sampleCount: 11,
                rankingScore: 0.77
            ),
            .init(
                id: "mock.insight.checkin-recovery",
                familyKey: "metric.mood->metric.recovery",
                title: "Good check-in days tend to stack together",
                summary: "Mood, clarity, and recovery ratings often rise together when your routine stays consistent for a few days.",
                evidenceText: "Sample dashboard insight for UI testing.",
                actionText: "Use this as a baseline pattern for consistency experiments.",
                driverText: "Consistency",
                outcomeText: "Better Recovery",
                deltaText: "+8%",
                category: .habits,
                confidence: .high,
                effect: .neutral,
                sampleCount: 22,
                rankingScore: 0.72
            ),
            .init(
                id: "mock.insight.strain-sleep",
                familyKey: "metric.trainingLoad->metric.sleepHours",
                title: "Heavy training nights need more sleep",
                summary: "Your harder training days look better the next day when sleep also stretches past your usual baseline.",
                evidenceText: "Sample dashboard insight for UI testing.",
                actionText: "Pair your highest-strain days with longer recovery sleep windows.",
                driverText: "Higher Strain",
                outcomeText: "More Sleep Needed",
                deltaText: "+42 min",
                category: .training,
                confidence: .medium,
                effect: .neutral,
                sampleCount: 14,
                rankingScore: 0.69
            )
        ]
    }

    // MARK: - Workouts

    private static var mockSleep: SQDashboardSectionGroupViewModel {
        let scoreRow = SQDashboardSleepScoreRowViewModel(
            totalScore: 78,
            scoreLabel: "78/100",
            components: [
                .init(id: "duration", title: "Duration", score: 31, maxScore: 40, color: .accent(1), detailText: AttributedString("Across the last 7 nights, average sleep was 7h 48m. This score compares sleep time against an 8h target, so shorter nights pull it down.")),
                .init(id: "efficiency", title: "Efficiency", score: 20, maxScore: 25, color: .accentNeutral1, detailText: AttributedString("Across the last 7 nights, about 88% of time in bed was spent asleep (7h 48m asleep out of 8h 52m in bed on average).")),
                .init(id: "fragmentation", title: "Fragmentation", score: 15, maxScore: 20, color: .accentNeutral4, detailText: AttributedString("Across the last 7 nights, there were about 3 awake periods per night totaling 34m awake on average. More broken-up sleep lowers this score.")),
                .init(id: "architecture", title: "Architecture", score: 12, maxScore: 15, color: .dashboardGlowMint, detailText: AttributedString("Across the last 7 nights, REM made up 23% and Deep sleep made up 15% of total sleep. This score rewards a balanced restorative mix."))
            ]
        )

        let summaryRow = SQDashboardSleepSummaryRowViewModel(items: [
            .init(id: "total", title: "Avg Total Sleep", value: "7h 53m"),
            .init(id: "bed", title: "Avg Bedtime", value: "10:44 PM"),
            .init(id: "wake", title: "Avg Wake Time", value: "6:37 AM")
        ])

        let phasesRows: [SQDashboardRowViewModel] = [
            SQDashboardMetricStatsRowViewModel(
                metricId: "mock-rem",
                icon: SQImageSymbol.eye.rawValue,
                title: "REM",
                avgValue: "1h 24m",
                unit: "",
                sparklineData: [1.2, 1.4, 1.1, 1.5, 1.4, 1.3, 1.4],
                changePercent: 0.12
            ),
            SQDashboardMetricStatsRowViewModel(
                metricId: "mock-deep",
                icon: SQImageSymbol.moonZzzFill.rawValue,
                title: "Deep",
                avgValue: "52m",
                unit: "",
                sparklineData: [0.8, 0.9, 0.7, 0.85, 0.9, 0.83, 0.87],
                changePercent: 0.05
            )
        ]

        let scoreSection = SQDashboardSubsectionViewModel(
            id: "sleep-score",
            title: "Sleep Score",
            defaultPriority: 10,
            rowsByFilter: ["All": [scoreRow]]
        )

        let phasesSection = SQDashboardSubsectionViewModel(
            id: "sleep-phases",
            title: "Sleep Phases",
            defaultPriority: 40,
            rowsByFilter: ["All": phasesRows],
            columnHeaders: ["Phase", "Avg Duration", "vs Prior"]
        )

        let summarySection = SQDashboardSubsectionViewModel(
            id: "sleep-summary",
            title: "Sleep Summary",
            defaultPriority: 20,
            rowsByFilter: ["All": [summaryRow]]
        )

        let durationRow = SQDashboardSleepDurationRowViewModel(
            bars: [
                .init(id: "sleep-dur-0", label: "M", focusTitle: "Monday, Jan 6, 2026", valueHours: 7.1, color: SQColor.dashboardGlowBlue.color.opacity(0.58)),
                .init(id: "sleep-dur-1", label: "T", focusTitle: "Tuesday, Jan 7, 2026", valueHours: 7.8, color: SQColor.dashboardGlowBlue.color.opacity(0.58)),
                .init(id: "sleep-dur-2", label: "W", focusTitle: "Wednesday, Jan 8, 2026", valueHours: 6.9, color: SQColor.dashboardGlowBlue.color.opacity(0.58)),
                .init(id: "sleep-dur-3", label: "T", focusTitle: "Thursday, Jan 9, 2026", valueHours: 8.0, color: SQColor.dashboardGlowBlue.color.opacity(0.58)),
                .init(id: "sleep-dur-4", label: "F", focusTitle: "Friday, Jan 10, 2026", valueHours: 7.4, color: SQColor.dashboardGlowBlue.color.opacity(0.58)),
                .init(id: "sleep-dur-5", label: "S", focusTitle: "Saturday, Jan 11, 2026", valueHours: 7.6, color: SQColor.dashboardGlowBlue.color.opacity(0.58)),
                .init(id: "sleep-dur-6", label: "S", focusTitle: "Sunday, Jan 12, 2026", valueHours: 8.2, color: SQColor.dashboardGlowBlue.color)
            ],
            averageDurationHours: 7.57,
            averageLabel: "AVG 7h 34m",
            barSpacing: 8,
            minimumBarWidth: 8,
            maximumBarWidth: 18
        )

        let durationSection = SQDashboardSubsectionViewModel(
            id: "sleep-duration",
            title: "Sleep Duration",
            defaultPriority: 30,
            rowsByFilter: ["All": [durationRow]]
        )

        return SQDashboardSectionGroupViewModel(
            id: "sleep",
            title: "Sleep",
            defaultPriority: 30,
            sections: [scoreSection, summarySection, durationSection, phasesSection]
        )
    }

    private static var mockWorkouts: SQDashboardSectionGroupViewModel {
        let mockWorkoutsList: [any SQWorkoutSessionable] = .mock

        let totalsRow = SQDashboardWorkoutTotalsRowViewModel(
            config: .mock,
            workouts: mockWorkoutsList,
            priorWorkouts: [],
            filter: .workoutTime
        )

        let totalsDropdown = SQDropDownMenuViewModel(
            defaultItem: .init(title: "Time"),
            items: [.init(title: "Time"), .init(title: "Kilocalories")],
            itemSelectionHandler: { _ in }
        )

        let totalsSection = SQDashboardSubsectionViewModel(
            id: "totals",
            title: "Totals",
            defaultPriority: 10,
            rowsByFilter: ["Time": [totalsRow]],
            dropDownViewModel: totalsDropdown
        )

        let activityRow = SQDashboardActivityRowViewModel(
            workoutGroupViewModels: [
                .init(activityType: .running, workouts: .init(workouts: mockWorkoutsList))
            ]
        )

        let activitiesDropdown = SQDropDownMenuViewModel(
            defaultItem: .init(title: "All"),
            items: [.init(title: "All")],
            itemSelectionHandler: { _ in }
        )

        let activitiesSection = SQDashboardSubsectionViewModel(
            id: "activities",
            title: "Activities",
            defaultPriority: 20,
            rowsByFilter: ["All": [activityRow]],
            dropDownViewModel: activitiesDropdown
        )

        return SQDashboardSectionGroupViewModel(
            id: "workouts",
            title: "Workouts",
            defaultPriority: 50,
            sections: [totalsSection, activitiesSection]
        )
    }

    private static var mockHeart: SQDashboardSectionGroupViewModel {
        let row = SQDashboardHeartSummaryRowViewModel(
            items: [
                .init(id: "resting", title: "Resting Avg", value: "58", unit: "bpm", detail: "Average resting in 7 days"),
                .init(id: "low", title: "Lowest", value: "46", unit: "bpm", detail: "Lowest recorded in 7 days"),
                .init(id: "high", title: "Highest", value: "171", unit: "bpm", detail: "Peak recorded in 7 days")
            ],
            trendChart: .init(
                title: "Resting HR Trend",
                subtitle: "Daily average resting heart rate",
                points: [
                    .init(id: "heart-0", point: CGPoint(x: 1, y: 60)),
                    .init(id: "heart-1", point: CGPoint(x: 2, y: 59)),
                    .init(id: "heart-2", point: CGPoint(x: 3, y: 58)),
                    .init(id: "heart-3", point: CGPoint(x: 4, y: 57)),
                    .init(id: "heart-4", point: CGPoint(x: 5, y: 58)),
                    .init(id: "heart-5", point: CGPoint(x: 6, y: 56)),
                    .init(id: "heart-6", point: CGPoint(x: 7, y: 57))
                ],
                trendPoints: nil,
                rangeLabelSuffix: "bpm",
                averageValue: 57.9,
                averageLabel: "AVG 58"
            )
        )

        let section = SQDashboardSubsectionViewModel(
            id: "heart-rate",
            title: "Heart Rate",
            defaultPriority: 10,
            rowsByFilter: ["All": [row]]
        )

        return SQDashboardSectionGroupViewModel(
            id: "heart",
            title: "Heart",
            defaultPriority: 40,
            sections: [section]
        )
    }

    private enum BodyBatteryMockTextSegment {
        case plain(String)
        case highlight(String)
    }

    private static func buildBodyBatteryMockDetail(_ segments: [BodyBatteryMockTextSegment]) -> AttributedString {
        segments.reduce(into: AttributedString()) { result, segment in
            switch segment {
            case .plain(let text):
                result += AttributedString.build(with: text, color: SQColor.textSecondary.color)
            case .highlight(let text):
                result += AttributedString.build(with: text, color: SQColor.dashboardGlowBlue.color)
            }
        }
    }
}
