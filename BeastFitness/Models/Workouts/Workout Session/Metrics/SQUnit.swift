//
//  SQUnit.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/14/25.
//

import HealthKit
import BeastFitnessCore

enum SQUnit: String, Codable, CaseIterable, UnfrozenEnum {
    case kilocalorie
    case mile
    case meter
    case count
    case countPerMinute
    case secondsPerMile
    case pound
    case degreesCelsius
    case degreesFahrenheit
    case unknown
    
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
        case .secondsPerMile:
            return value
        case .pound:
            return value
        case .degreesCelsius:
            switch toUnit {
            case .degreesFahrenheit:
                return value * 9.0 / 5.0 + 32.0
            default:
                return value
            }
        case .degreesFahrenheit:
            switch toUnit {
            case .degreesCelsius:
                return (value - 32.0) * 5.0 / 9.0
            default:
                return value
            }
        case .unknown:
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
        case .secondsPerMile:
            return .timePerDistance
        case .pound:
            return .weight
        case .degreesCelsius, .degreesFahrenheit:
            return .temperature
        case .unknown:
            return .unknown
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
        case .secondsPerMile:
                .second().unitDivided(by: .mile())
        case .pound:
                .pound()
        case .degreesCelsius:
                .degreeCelsius()
        case .degreesFahrenheit:
                .degreeFahrenheit()
        case .unknown:
            nil
        }
    }
    
    var unitString: String? {
        switch self {
        case .kilocalorie, .mile, .meter, .count, .pound:
            return hkUnit?.unitString
        case .countPerMinute:
            return "bpm"
        case .secondsPerMile:
            return "/mi"
        case .degreesCelsius:
            return "°C"
        case .degreesFahrenheit:
            return "°F"
        case .unknown:
            return nil
        }
    }
}

enum SQUnitType: String, Codable, UnfrozenEnum {
    case time
    case distance
    case energy
    case countPerTime
    case timePerDistance
    case total
    case weight
    case temperature
    case unknown
}
