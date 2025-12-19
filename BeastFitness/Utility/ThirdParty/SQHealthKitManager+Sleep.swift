//
//  SQHealthKitManager+Sleep.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 10/24/24.
//
import Foundation
import HealthKit
import BeastFitnessCore

extension SQHealthKitManager {
    
    func fetchSleep(_ timeRange: SQTimeRange) async throws -> SQSleepQueryResult? {
           guard HKHealthStore.isHealthDataAvailable() else {
               throw SQStandardError.standard   // or SQHealthKitError.healthDataUnavailable
           }
           
           do {
               try await Self.healthStore.requestAuthorization(
                   toShare: allQuantityTypes,
                   read: allQuantityTypes
               )
           } catch {
               SQLogger.shared.log("Error requesting healthStore auth: \(error.localizedDescription)", .error, context: .dataProcessing)
               throw error
           }
           
           let predicate = HKQuery.predicateForSamples(
               withStart: timeRange.startDate,
               end: timeRange.endDate
           )
           let limit = HKObjectQueryNoLimit
           let sortDescriptor = NSSortDescriptor(
               key: HKSampleSortIdentifierEndDate,
               ascending: false
           )
           
           guard let categoryType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
               SQLogger.shared.log("Cannot get sleep category type", .error, context: .dataProcessing)
               throw SQStandardError.standard
           }
           
           return try await executeSleepQuery(
               categoryType: categoryType,
               predicate: predicate,
               sortDescriptors: [sortDescriptor],
               limit: limit
           )
       }
    
    func executeSleepQuery(
            categoryType: HKCategoryType,
            predicate: NSPredicate?,
            sortDescriptors: [NSSortDescriptor]?,
            limit: Int
        ) async throws -> SQSleepQueryResult? {
            try await withCheckedThrowingContinuation { continuation in
                let query = HKSampleQuery(
                    sampleType: categoryType,
                    predicate: predicate,
                    limit: limit,
                    sortDescriptors: sortDescriptors
                ) { query, tmpResult, errorOrNil in
                    
                    if let error = errorOrNil {
                        SQLogger.shared.log(
                            "HKSampleQuery initialResultsHandler with identifier \(categoryType.identifier) error: \(error.localizedDescription)",
                            .error,
                            context: .dataProcessing
                        )
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    SQLogger.shared.log(
                        "HKSampleQuery initialResultsHandler has returned for \(categoryType.identifier)",
                        .debug,
                        context: .dataProcessing
                    )
                    
                    guard let result = tmpResult else {
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    var totalSleepTimeInHours = 0.0
                    for sample in result {
                        guard let sleepSample = sample as? HKCategorySample else {
                            continue
                        }
                        let sleepTimeForOneDay = sleepSample.endDate.timeIntervalSince(sleepSample.startDate)
                        let sleepTimeInHours = sleepTimeForOneDay / (60.0 * 60.0)
                        totalSleepTimeInHours += sleepTimeInHours
                        
                        SQLogger.shared.log(
                            "PTD HKSampleQuery initialResultsHandler has returned \(sleepTimeInHours) " +
                            "\nStartDate \(sleepSample.startDate)" +
                            "\nEndDate \(sleepSample.endDate)",
                            .debug,
                            context: .dataProcessing
                        )
                    }
                    
                    let resultModel = SQSleepQueryResult(totalTime: totalSleepTimeInHours)
                    continuation.resume(returning: resultModel)
                }
                
                SQHealthKitManager.healthStore.execute(query)
            }
        }
    
    enum SleepQueryResult {
        case success(SQSleepQueryResult?)
        case error(Error)
        
        var sleepQueryResult: SQSleepQueryResult? {
            switch self {
            case .success(let result):
                return result
            case .error:
                return nil
            }
        }
    }
}

struct SQSleepQueryResult {
    let totalTime: Double
}
