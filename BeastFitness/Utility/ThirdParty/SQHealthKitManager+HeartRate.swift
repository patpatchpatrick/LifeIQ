//
//  SQHealthKitManager+HeartRate.swift
//  BeastFitness
//

import Foundation
import HealthKit
import BeastFitnessCore

struct SQHeartRateDailySummary: Sendable {
    let date: Date
    let average: Double?
    let minimum: Double?
    let maximum: Double?
}

struct SQHeartRateIntervalSummary: Sendable {
    let startDate: Date
    let endDate: Date
    let average: Double

    var durationSeconds: Double {
        max(0, endDate.timeIntervalSince(startDate))
    }
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

    func fetchWorkoutHeartRateSummaries(for workout: HKWorkout) async throws -> [SQHeartRateIntervalSummary] {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw SQHealthKitError.healthDataUnavailable
        }

        guard let quantityType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            return []
        }

        try await requestAppAuthorization()

        let timePredicate = HKQuery.predicateForSamples(
            withStart: workout.startDate,
            end: workout.endDate,
            options: [.strictStartDate, .strictEndDate]
        )
        let sourcePredicate = HKQuery.predicateForObjects(from: workout)
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [timePredicate, sourcePredicate])
        let calendar = Calendar.current
        let anchorDate = calendar.date(
            bySettingHour: calendar.component(.hour, from: workout.startDate),
            minute: calendar.component(.minute, from: workout.startDate),
            second: 0,
            of: workout.startDate
        ) ?? workout.startDate
        let interval = DateComponents(minute: 1)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: [.discreteAverage],
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
                var summaries = [SQHeartRateIntervalSummary]()

                results.enumerateStatistics(from: workout.startDate, to: workout.endDate) { stats, _ in
                    guard let average = stats.averageQuantity()?.doubleValue(for: unit) else {
                        return
                    }

                    guard (25...240).contains(average) else {
                        return
                    }

                    let endDate = min(stats.endDate, workout.endDate)
                    guard endDate > stats.startDate else {
                        return
                    }

                    summaries.append(
                        SQHeartRateIntervalSummary(
                            startDate: stats.startDate,
                            endDate: endDate,
                            average: average
                        )
                    )
                }

                continuation.resume(returning: summaries.sorted { $0.startDate < $1.startDate })
            }

            Self.healthStore.execute(query)
        }
    }

    func fetchWorkoutHeartRateSummaries(for healthKitId: String) async throws -> [SQHeartRateIntervalSummary] {
        guard let workout = try await fetchWorkout(with: healthKitId) else {
            return []
        }

        return try await fetchWorkoutHeartRateSummaries(for: workout)
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

        try await requestAppAuthorization()

        SQLogger.shared.log(
            """
            [Health Debug] Heart query starting:
            identifier=\(identifier.rawValue)
            timeRange=\(timeRange.rawValue)
            start=\(timeRange.startDate.formattedString(with: .fullWithoutDayName))
            end=\(timeRange.endDate.formattedString(with: .fullWithoutDayName))
            authorization=\(String(describing: Self.healthStore.authorizationStatus(for: quantityType)))
            """,
            .debug,
            context: .healthKit
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

                let firstSummaryDate = summaries.first?.date.formattedString(with: .medium) ?? "nil"
                let lastSummaryDate = summaries.last?.date.formattedString(with: .medium) ?? "nil"
                SQLogger.shared.log(
                    """
                    [Health Debug] Heart query finished:
                    identifier=\(identifier.rawValue)
                    timeRange=\(timeRange.rawValue)
                    summaryCount=\(summaries.count)
                    firstSummaryDate=\(firstSummaryDate)
                    lastSummaryDate=\(lastSummaryDate)
                    """,
                    .debug,
                    context: .healthKit
                )

                continuation.resume(returning: summaries.sorted { $0.date < $1.date })
            }

            Self.healthStore.execute(query)
        }
    }

    private func fetchWorkout(with healthKitId: String) async throws -> HKWorkout? {
        guard let uuid = UUID(uuidString: healthKitId) else {
            return nil
        }

        let sampleType = HKObjectType.workoutType()
        try await requestAppAuthorization()
        let predicate = HKQuery.predicateForObject(with: uuid)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sampleType,
                predicate: predicate,
                limit: 1,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume(returning: (samples as? [HKWorkout])?.first)
            }

            Self.healthStore.execute(query)
        }
    }
}
