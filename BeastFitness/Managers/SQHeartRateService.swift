//
//  SQHeartRateService.swift
//  BeastFitness
//

import Foundation

@MainActor
protocol SQHeartRateServicing {
    func buildDashboardRowViewModel(for timeRange: SQTimeRange) async throws -> SQDashboardHeartSummaryRowViewModel?
}

@MainActor
final class SQHeartRateService: SQHeartRateServicing {
    private let healthKitManager: SQHealthKitManaging

    init(healthKitManager: SQHealthKitManaging = SQHealthKitManager.shared) {
        self.healthKitManager = healthKitManager
    }

    func buildDashboardRowViewModel(for timeRange: SQTimeRange) async throws -> SQDashboardHeartSummaryRowViewModel? {
        async let heartTask = healthKitManager.fetchDailyHeartRateSummaries(timeRange)
        async let restingTask = healthKitManager.fetchDailyRestingHeartRateSummaries(timeRange)

        let heartSummaries = try await heartTask
        let restingSummaries = try await restingTask

        let averageResting = restingSummaries.compactMap(\.average).average
        let lowestHeartRate = heartSummaries.compactMap(\.minimum).min()
        let peakHeartRate = heartSummaries.compactMap(\.maximum).max()

        guard averageResting != nil || lowestHeartRate != nil || peakHeartRate != nil else {
            return nil
        }

        return SQDashboardHeartSummaryRowViewModel(
            items: [
                .init(
                    id: "resting",
                    title: "Resting Avg",
                    value: formatted(averageResting),
                    unit: "bpm",
                    detail: detailText(for: timeRange, defaultText: "Average resting")
                ),
                .init(
                    id: "low",
                    title: "Lowest",
                    value: formatted(lowestHeartRate),
                    unit: "bpm",
                    detail: detailText(for: timeRange, defaultText: "Lowest recorded")
                ),
                .init(
                    id: "high",
                    title: "Highest",
                    value: formatted(peakHeartRate),
                    unit: "bpm",
                    detail: detailText(for: timeRange, defaultText: "Peak recorded")
                )
            ]
        )
    }

    private func formatted(_ value: Double?) -> String {
        guard let value else { return "--" }
        return Int(value.rounded()).description
    }

    private func detailText(for timeRange: SQTimeRange, defaultText: String) -> String {
        switch timeRange {
        case .today:
            return "\(defaultText) today"
        case .pastWeek:
            return "\(defaultText) in 7 days"
        case .past30Days:
            return "\(defaultText) in 30 days"
        case .pastYear:
            return "\(defaultText) in 1 year"
        case .allTime:
            return "\(defaultText) all time"
        case .yesterday:
            return "\(defaultText) yesterday"
        case .weekBeforeLast:
            return "\(defaultText) in prior week"
        case .thirtyDaysBeforeLast:
            return "\(defaultText) in prior 30 days"
        case .yearBeforeLast:
            return "\(defaultText) in prior year"
        }
    }
}
