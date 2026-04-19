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
    case kilometer
    case meter
    case minute
    case hour
    case count
    case countPerMinute
    case secondsPerMile
    case secondsPerKilometer
    case milligram
    case gram
    case pound
    case kilogram
    case milliliter
    case liter
    case fluidOunce
    case inch
    case centimeter
    case percent
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
        case .minute:
            switch toUnit {
            case .hour:
                return value / 60.0
            default:
                return value
            }
        case .hour:
            switch toUnit {
            case .minute:
                return value * 60.0
            default:
                return value
            }
        case .mile:
            switch toUnit {
            case .meter:
                return value * 1609.344
            case .kilometer:
                return value * 1.609344
            default:
                return value
            }
        case .kilometer:
            switch toUnit {
            case .meter:
                return value * 1000
            case .mile:
                return value / 1.609344
            default:
                return value
            }
        case .meter:
            switch toUnit {
            case .mile:
                return value / 1609.344
            case .kilometer:
                return value / 1000
            default:
                return value
            }
        case .countPerMinute, .count, .percent:
            return value
        case .secondsPerMile:
            switch toUnit {
            case .secondsPerKilometer:
                return value / 1.609344
            default:
                return value
            }
        case .secondsPerKilometer:
            switch toUnit {
            case .secondsPerMile:
                return value * 1.609344
            default:
                return value
            }
        case .milligram:
            switch toUnit {
            case .gram:
                return value / 1000.0
            case .kilogram:
                return value / 1_000_000.0
            default:
                return value
            }
        case .gram:
            switch toUnit {
            case .milligram:
                return value * 1000.0
            case .kilogram:
                return value / 1000.0
            default:
                return value
            }
        case .pound:
            switch toUnit {
            case .kilogram:
                return value * 0.45359237
            case .gram:
                return value * 453.59237
            case .milligram:
                return value * 453_592.37
            default:
                return value
            }
        case .kilogram:
            switch toUnit {
            case .pound:
                return value / 0.45359237
            case .gram:
                return value * 1000.0
            case .milligram:
                return value * 1_000_000.0
            default:
                return value
            }
        case .milliliter:
            switch toUnit {
            case .liter:
                return value / 1000.0
            case .fluidOunce:
                return value / 29.5735295625
            default:
                return value
            }
        case .liter:
            switch toUnit {
            case .milliliter:
                return value * 1000.0
            case .fluidOunce:
                return value * 33.8140227018
            default:
                return value
            }
        case .fluidOunce:
            switch toUnit {
            case .milliliter:
                return value * 29.5735295625
            case .liter:
                return value / 33.8140227018
            default:
                return value
            }
        case .inch:
            switch toUnit {
            case .centimeter:
                return value * 2.54
            default:
                return value
            }
        case .centimeter:
            switch toUnit {
            case .inch:
                return value / 2.54
            default:
                return value
            }
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
        case .minute, .hour:
            return .time
        case .mile, .kilometer, .meter, .inch, .centimeter:
            return .distance
        case .countPerMinute:
            return .countPerTime
        case .count, .percent:
            return .total
        case .secondsPerMile, .secondsPerKilometer:
            return .timePerDistance
        case .milligram, .gram, .pound, .kilogram:
            return .weight
        case .milliliter, .liter, .fluidOunce:
            return .volume
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
        case .minute:
                .minute()
        case .hour:
                .hour()
        case .mile:
                .mile()
        case .kilometer:
                .meterUnit(with: .kilo)
        case .meter:
                .meter()
        case .countPerMinute:
                .count().unitDivided(by: .minute())
        case .count:
                .count()
        case .secondsPerMile:
                .second().unitDivided(by: .mile())
        case .secondsPerKilometer:
                .second().unitDivided(by: .meterUnit(with: .kilo))
        case .milligram:
                .gramUnit(with: .milli)
        case .gram:
                .gram()
        case .pound:
                .pound()
        case .kilogram:
                .gramUnit(with: .kilo)
        case .milliliter:
                .literUnit(with: .milli)
        case .liter:
                .liter()
        case .fluidOunce:
                .fluidOunceUS()
        case .inch:
                .inch()
        case .centimeter:
                .meterUnit(with: .centi)
        case .percent:
                .percent()
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
        case .kilocalorie, .minute, .hour, .mile, .kilometer, .meter, .count, .milligram, .gram, .pound, .kilogram, .milliliter, .liter, .fluidOunce, .inch, .centimeter, .percent:
            return hkUnit?.unitString
        case .countPerMinute:
            return "bpm"
        case .secondsPerMile:
            return "/mi"
        case .secondsPerKilometer:
            return "/km"
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
    case volume
    case temperature
    case unknown
}
