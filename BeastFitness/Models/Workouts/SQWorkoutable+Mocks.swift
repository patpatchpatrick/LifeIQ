//
//  SQWorkoutable+Mocks.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/13/25.
//

import HealthKit

final class SQMockWorkout: SQWorkoutable {
    var activityType: HKWorkoutActivityType
    var coreOutputQuantityTypeId: SQQuantityType?
    var coreOutputUnit: SQUnit?
    var activeDuration: Double?
    var startDate: Date?
    var endDate: Date?
    
    private var outputs: [SQQuantityType: Double]
    
    init(
        activityType: HKWorkoutActivityType,
        coreOutputQuantityTypeId: SQQuantityType? = nil,
        coreOutputUnit: SQUnit? = nil,
        activeDuration: Double? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        outputs: [SQQuantityType: Double] = [:]
    ) {
        self.activityType = activityType
        self.coreOutputQuantityTypeId = coreOutputQuantityTypeId
        self.coreOutputUnit = coreOutputUnit
        self.activeDuration = activeDuration
        self.startDate = startDate
        self.endDate = endDate
        self.outputs = outputs
    }
    
    func sumOutputFor(_ quantityTypeIdentifier: SQQuantityType) -> Double? {
        outputs[quantityTypeIdentifier]
    }
    
    func avgOutputFor(_ quantityTypeIdentifier: SQQuantityType) -> Double? {
        outputs[quantityTypeIdentifier]
    }
    
    static let mockRun = SQMockWorkout(
        activityType: .running,
        coreOutputQuantityTypeId: .distanceWalkingRunning,
        coreOutputUnit: .meter,
        activeDuration: 45 * 60,
        startDate: Date().addingTimeInterval(-3600),
        endDate: Date(),
        outputs: [.distanceWalkingRunning : 550]
    )
}

extension [any SQWorkoutable] {
    static var mock: [any SQWorkoutable] {
        [SQMockWorkout.mockRun, SQMockWorkout.mockRun, SQMockWorkout.mockRun]
    }
}
