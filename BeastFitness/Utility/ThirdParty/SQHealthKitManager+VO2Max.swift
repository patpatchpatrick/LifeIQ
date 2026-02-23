//
//  SQHealthKitManager+VO2Max.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 1/2/26.
//

import HealthKit

struct SQVO2MaxSample: Sendable, Hashable {
    let value: Double              // ml/kg/min
    let startDate: Date
    let endDate: Date
    let healthKitId: String?       // sample UUID string if you want it
    let sourceName: String?
}

extension SQHealthKitManager {

    @MainActor
    func fetchLatestVO2Max() async throws -> SQVO2MaxSample? {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw SQHealthKitError.healthDataUnavailable
        }

        try await Self.healthStore.requestAuthorization(
            toShare: allTypesToReadWrite,
            read: allTypesToReadWrite
        )

        let vo2Type = HKQuantityType.quantityType(forIdentifier: .vo2Max)!
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        let sample: HKQuantitySample? = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: vo2Type,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: samples?.first as? HKQuantitySample)
            }

            Self.healthStore.execute(query)
        }

        guard let sample else { return nil }

        return Self.mapVO2MaxSample(sample)
    }
}

extension SQHealthKitManager {

    @MainActor
    func fetchVO2MaxSamples(_ timeRange: SQTimeRange) async throws -> [SQVO2MaxSample] {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw SQHealthKitError.healthDataUnavailable
        }

        try await Self.healthStore.requestAuthorization(
            toShare: allTypesToReadWrite,
            read: allTypesToReadWrite
        )

        let vo2Type = HKQuantityType.quantityType(forIdentifier: .vo2Max)!
        let predicate = HKQuery.predicateForSamples(
            withStart: timeRange.startDate,
            end: timeRange.endDate,
            options: []
        )

        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let samples: [HKQuantitySample] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: vo2Type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: samples as? [HKQuantitySample] ?? [])
            }

            Self.healthStore.execute(query)
        }

        return samples.map(Self.mapVO2MaxSample)
    }
}

extension SQHealthKitManager {

    @MainActor
    func fetchVO2MaxSamples(upTo date: Date, limit: Int) async throws -> [SQVO2MaxSample] {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw SQHealthKitError.healthDataUnavailable
        }

        try await Self.healthStore.requestAuthorization(
            toShare: allTypesToReadWrite,
            read: allTypesToReadWrite
        )

        guard let vo2Type = HKQuantityType.quantityType(forIdentifier: .vo2Max) else {
            throw SQHealthKitError.healthDataUnavailable
        }

        // Include all samples through the end of the calendar day containing `date`
        let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: date) ?? date.addingTimeInterval(86400)
        let startOfNextDay = Calendar.current.startOfDay(for: nextDay)
        let predicate = HKQuery.predicateForSamples(
            withStart: .distantPast,
            end: startOfNextDay,
            options: .strictEndDate
        )
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        let samples: [HKQuantitySample] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: vo2Type,
                predicate: predicate,
                limit: limit,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: samples as? [HKQuantitySample] ?? [])
            }
            Self.healthStore.execute(query)
        }

        return samples.map(Self.mapVO2MaxSample)
    }
}

extension SQHealthKitManager {

    static let vo2MaxUnit: HKUnit = {
        // ml / (kg * min)
        let ml = HKUnit.literUnit(with: .milli)
        let kg = HKUnit.gramUnit(with: .kilo)
        return ml.unitDivided(by: kg).unitDivided(by: .minute())
    }()

    static func mapVO2MaxSample(_ sample: HKQuantitySample) -> SQVO2MaxSample {
        let value = sample.quantity.doubleValue(for: vo2MaxUnit)

        return SQVO2MaxSample(
            value: value,
            startDate: sample.startDate,
            endDate: sample.endDate,
            healthKitId: sample.uuid.uuidString,
            sourceName: sample.sourceRevision.source.name
        )
    }
}
