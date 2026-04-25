//
//  SQHealthKitManager+Sleep.swift
//  BeastFitness
//

import Foundation
import HealthKit
import BeastFitnessCore

extension SQHealthKitManager {

    func fetchSleepSegments(from startDate: Date, to endDate: Date) async throws -> [SQSleepStageSegment] {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw SQError.standard
        }

        try await requestAppAuthorization()

        guard let categoryType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            throw SQError.standard
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let samples = try await executeSleepSampleQuery(
            categoryType: categoryType,
            predicate: predicate,
            sortDescriptors: [sortDescriptor],
            limit: HKObjectQueryNoLimit
        )

        let segments = samples.compactMap { sample -> SQSleepStageSegment? in
            guard let phase = Self.phase(for: sample) else { return nil }
            return SQSleepStageSegment(
                phase: phase,
                startDate: sample.startDate,
                endDate: sample.endDate
            )
        }

        return segments
    }

    private func executeSleepSampleQuery(
        categoryType: HKCategoryType,
        predicate: NSPredicate?,
        sortDescriptors: [NSSortDescriptor]?,
        limit: Int
    ) async throws -> [HKCategorySample] {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: categoryType,
                predicate: predicate,
                limit: limit,
                sortDescriptors: sortDescriptors
            ) { _, result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let categorySamples = (result as? [HKCategorySample]) ?? []
                continuation.resume(returning: categorySamples)
            }

            SQHealthKitManager.healthStore.execute(query)
        }
    }

    private static func phase(for sample: HKCategorySample) -> SQSleepPhase? {
        let value = sample.value

        if value == HKCategoryValueSleepAnalysis.awake.rawValue {
            return .awake
        }

        if #available(iOS 16.0, *) {
            switch value {
            case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                return .rem
            case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                return .core
            case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                return .deep
            default:
                break
            }
        }

        if value == HKCategoryValueSleepAnalysis.asleep.rawValue
            || value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue {
            return .core
        }

        // Ignore inBed and unsupported values for the phase timeline.
        return nil
    }
}
