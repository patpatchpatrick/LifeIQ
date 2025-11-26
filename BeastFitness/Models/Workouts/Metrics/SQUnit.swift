//
//  SQUnit.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/14/25.
//

import HealthKit

enum SQUnit: CaseIterable {
    case kilocalorie
    case mile
    case meter
    case count
    case countPerMinute
    
    static func convert(_ value: Double?, from fromUnit: SQUnit, to toUnit: SQUnit) -> Double? {
        guard let value else { return nil }
        guard fromUnit.unitType == toUnit.unitType else {
            SQLogger.shared.log("Cannot convert units of different types: \(fromUnit), \(toUnit)", .error, context: .general)
            return nil
        }
        
        switch fromUnit {
        case .kilocalorie:
            return value
        case .mile:
            switch toUnit {
            case .meter:
                return value * 1609.344
            default:
                return value
            }
        case .meter:
            switch toUnit {
            case .mile:
                return value / 1609.344
            default:
                return value
            }
        case .countPerMinute, .count:
            return value
        }
    }
    
    func convert(_ value: Double?, to unit: SQUnit) -> Double? {
        Self.convert(value, from: self, to: unit)
    }
    
    var unitType: SQUnitType {
        switch self {
        case .kilocalorie:
            return .energy
        case .mile, .meter:
            return .distance
        case .countPerMinute:
            return .countPerTime
        case .count:
            return .total
        }
    }
    
    var hkUnit: HKUnit? {
        switch self {
        case .kilocalorie:
                .kilocalorie()
        case .mile:
                .mile()
        case .meter:
                .mile()
        case .countPerMinute:
                .count().unitDivided(by: .minute())
        case .count:
                .count()
        }
    }
    
    var unitString: String? {
        hkUnit?.unitString
    }
}

enum SQUnitType {
    case time
    case distance
    case energy
    case countPerTime
    case total
}
