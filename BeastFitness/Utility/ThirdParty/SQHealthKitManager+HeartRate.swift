//
//  SQHealthKitManager+HeartRate.swift
//  BeastFitness
//

import Foundation
import HealthKit

struct SQHeartRateDailySummary: Sendable {
    let date: Date
    let average: Double?
    let minimum: Double?
    let maximum: Double?
}

extension SQHealthKitManager {
    func fetchDailyHeartRateSummaries(_ timeRange: SQTimeRange) async throws -> [SQHeartRateDailySummary] {
        try await fetchDailyHeartRateSummaries(
            for: .heartRate,
            timeRange: timeRange,
            options: [.discreteAverage, .discreteMin, .discreteMax],
            validRange: 25...240
        )
    }

    func fetchDailyRestingHeartRateSummaries(_ timeRange: SQTimeRange) async throws -> [SQHeartRateDailySummary] {
        try await fetchDailyHeartRateSummaries(
            for: .restingHeartRate,
            timeRange: timeRange,
            options: [.discreteAverage],
            validRange: 25...120
        )
    }

    private func fetchDailyHeartRateSummaries(
        for identifier: HKQuantityTypeIdentifier,
        timeRange: SQTimeRange,
        options: HKStatisticsOptions,
        validRange: ClosedRange<Double>
    ) async throws -> [SQHeartRateDailySummary] {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw SQHealthKitError.healthDataUnavailable
        }

        guard let quantityType = HKObjectType.quantityType(forIdentifier: identifier) else {
            return []
        }

        try await Self.healthStore.requestAuthorization(
            toShare: Set<HKSampleType>(),
            read: Set<HKObjectType>([quantityType])
        )

        let predicate = HKQuery.predicateForSamples(
            withStart: timeRange.startDate,
            end: timeRange.endDate
        )
        let calendar = Calendar.current
        let anchorDate = calendar.startOfDay(for: timeRange.startDate)
        let interval = DateComponents(day: 1)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: options,
                anchorDate: anchorDate,
                intervalComponents: interval
            )

            query.initialResultsHandler = { _, results, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let results else {
                    continuation.resume(returning: [])
                    return
                }

                let unit = HKUnit.count().unitDivided(by: .minute())
                var summaries = [SQHeartRateDailySummary]()

                results.enumerateStatistics(from: timeRange.startDate, to: timeRange.endDate) { stats, _ in
                    let average = stats.averageQuantity().map { $0.doubleValue(for: unit) }
                    let minimum = stats.minimumQuantity().map { $0.doubleValue(for: unit) }
                    let maximum = stats.maximumQuantity().map { $0.doubleValue(for: unit) }

                    let filteredAverage = average.flatMap { validRange.contains($0) ? $0 : nil }
                    let filteredMinimum = minimum.flatMap { validRange.contains($0) ? $0 : nil }
                    let filteredMaximum = maximum.flatMap { validRange.contains($0) ? $0 : nil }

                    guard filteredAverage != nil || filteredMinimum != nil || filteredMaximum != nil else {
                        return
                    }

                    summaries.append(
                        SQHeartRateDailySummary(
                            date: stats.startDate,
                            average: filteredAverage,
                            minimum: filteredMinimum,
                            maximum: filteredMaximum
                        )
                    )
                }

                continuation.resume(returning: summaries.sorted { $0.date < $1.date })
            }

            Self.healthStore.execute(query)
        }
    }
}
