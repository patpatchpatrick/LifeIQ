//
//  SQDashboardSectionGroupViewModel+Mocks.swift
//  BeastFitness
//

import Foundation

@MainActor
extension SQDashboardSectionGroupViewModel {

    static var mock: [SQDashboardSectionGroupViewModel] {
        [mockDailyStats, mockSleep, mockWorkouts]
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
            rowsByFilter: ["All": mockRows],
            columnHeaders: ["Metric", "Avg Score", "vs Prior"]
        )

        return SQDashboardSectionGroupViewModel(
            id: "daily-stats",
            title: "Daily Stats",
            sections: [metricsSection]
        )
    }

    // MARK: - Workouts

    private static var mockSleep: SQDashboardSectionGroupViewModel {
        let scoreRow = SQDashboardSleepScoreRowViewModel(
            totalScore: 78,
            scoreLabel: "78/100",
            components: [
                .init(id: "duration", title: "Duration", score: 39, maxScore: 50, color: .accent(1)),
                .init(id: "bedtime", title: "Bedtime", score: 23, maxScore: 30, color: .accentNeutral1),
                .init(id: "interruptions", title: "Interruptions", score: 16, maxScore: 20, color: .accentNeutral4)
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
            rowsByFilter: ["All": [scoreRow]]
        )

        let phasesSection = SQDashboardSubsectionViewModel(
            id: "sleep-phases",
            title: "Sleep Phases",
            rowsByFilter: ["All": phasesRows],
            columnHeaders: ["Phase", "Avg Duration", "vs Prior"]
        )

        let summarySection = SQDashboardSubsectionViewModel(
            id: "sleep-summary",
            title: "Sleep Summary",
            rowsByFilter: ["All": [summaryRow]]
        )

        return SQDashboardSectionGroupViewModel(
            id: "sleep",
            title: "Sleep",
            sections: [scoreSection, summarySection, phasesSection]
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
            rowsByFilter: ["Time": [totalsRow]],
            dropDownViewModel: totalsDropdown
        )

        let activityRow = SQDashboardActivityRowViewModel(workouts: mockWorkoutsList)

        let activitiesDropdown = SQDropDownMenuViewModel(
            defaultItem: .init(title: "All"),
            items: [.init(title: "All")],
            itemSelectionHandler: { _ in }
        )

        let activitiesSection = SQDashboardSubsectionViewModel(
            id: "activities",
            title: "Activities",
            rowsByFilter: ["All": [activityRow]],
            dropDownViewModel: activitiesDropdown
        )

        return SQDashboardSectionGroupViewModel(
            id: "workouts",
            title: "Workouts",
            sections: [totalsSection, activitiesSection]
        )
    }
}
