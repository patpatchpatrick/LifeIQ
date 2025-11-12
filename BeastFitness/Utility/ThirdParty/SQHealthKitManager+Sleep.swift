//
//  SQHealthKitManager+Sleep.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 10/24/24.
//
import Foundation
import HealthKit

extension SQHealthKitManager {
    
    func fetchSleep (_ timeRange: SQTimeRange) async -> SleepQueryResult {
        do {
            guard HKHealthStore.isHealthDataAvailable() else {
                throw SQStandardError.standard
            }
            
            try await Self.healthStore.requestAuthorization(toShare: allQuantityTypes, read: allQuantityTypes)
            
            let predicate = HKQuery.predicateForSamples(withStart: timeRange.startDate, end: timeRange.endDate)
            let limit = HKObjectQueryNoLimit
            let categoryType = HKObjectType.categoryType(forIdentifier: HKCategoryTypeIdentifier.sleepAnalysis)
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            
            guard let categoryType else {
                SQLogger.shared.log("Cannot get sleep category type", .error)
                return .error(SQStandardError.standard)
            }
            
            return await self.executeSleepQuery(categoryType: categoryType, predicate: predicate, sortDescriptors: [sortDescriptor], limit: limit)
        } catch {
            SQLogger.shared.log("Error requesting healthStore auth: \(error.localizedDescription)", .error)
            return .error(error)
        }
    }
    
    func executeSleepQuery(categoryType: HKCategoryType, predicate: NSPredicate?, sortDescriptors: [NSSortDescriptor]?, limit: Int) async -> SleepQueryResult {
        let query = HKSampleQuery(
            sampleType: categoryType,
            predicate: predicate,
            limit: limit,
            sortDescriptors: sortDescriptors,
            resultsHandler: { (query, tmpResult, errorOrNil) in
                // Handle error
                if let error = errorOrNil {
                    SQLogger.shared.log("HKSampleQuery initialResultsHandler with identifier \(categoryType.identifier) error: \(error.localizedDescription)", .error)
                    // TODO: - PTD.  Display the appropriate error if the user doesn't provide authoriation to their health data
                    self.completeSleepQueryResultContinuation(.error(error))
                    return
                }
                
                SQLogger.shared.log("HKSampleQuery initialResultsHandler has returned for \(categoryType.identifier)", .debug)
                guard let result = tmpResult else {
                    self.completeSleepQueryResultContinuation(.success(nil))
                    return
                }
                
                var totalSleepTimeInHours = 0.0
                for sample in result {
                    guard let sleepSample = sample as? HKCategorySample else {
                        continue
                    }
                    let sleepTimeForOneDay = sleepSample.endDate.timeIntervalSince(sleepSample.startDate)
                    let sleepTimeInHours = sleepTimeForOneDay / (60.0*60.0)
                    totalSleepTimeInHours += sleepTimeInHours
                    SQLogger.shared.log("PTD HKSampleQuery initialResultsHandler has returned \(sleepTimeInHours) \nStartDate\(sleepSample.startDate)\nEndDate\(sleepSample.endDate)", .debug)
                }
                
                self.completeSleepQueryResultContinuation(.success(.init(totalTime: totalSleepTimeInHours)))
                return
            })
        
        Self.healthStore.execute(query)
        
        return await withCheckedContinuation { continuation in
            self.sleepQueryResultContinuation = continuation
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
