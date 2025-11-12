//
//  HKWorkoutActivityType+Extensions.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 9/30/24.
//

import HealthKit

extension HKWorkoutActivityType {

  /*
   Simple mapping of available workout types to a human readable name.
   */
  var name: String {
    switch self {
    case .americanFootball:             return "American Football"
    case .archery:                      return "Archery"
    case .australianFootball:           return "Australian Football"
    case .badminton:                    return "Badminton"
    case .baseball:                     return "Baseball"
    case .basketball:                   return "Basketball"
    case .bowling:                      return "Bowling"
    case .boxing:                       return "Boxing"
    case .climbing:                     return "Climbing"
    case .crossTraining:                return "Cross Training"
    case .curling:                      return "Curling"
    case .cycling:                      return "Cycling"
    case .dance:                        return "Dance"
    case .danceInspiredTraining:        return "Dance Inspired Training"
    case .elliptical:                   return "Elliptical"
    case .equestrianSports:             return "Equestrian Sports"
    case .fencing:                      return "Fencing"
    case .fishing:                      return "Fishing"
    case .functionalStrengthTraining:   return "Functional Strength Training"
    case .golf:                         return "Golf"
    case .gymnastics:                   return "Gymnastics"
    case .handball:                     return "Handball"
    case .hiking:                       return "Hiking"
    case .hockey:                       return "Hockey"
    case .hunting:                      return "Hunting"
    case .lacrosse:                     return "Lacrosse"
    case .martialArts:                  return "Martial Arts"
    case .mindAndBody:                  return "Mind and Body"
    case .mixedMetabolicCardioTraining: return "Mixed Metabolic Cardio Training"
    case .paddleSports:                 return "Paddle Sports"
    case .play:                         return "Play"
    case .preparationAndRecovery:       return "Preparation and Recovery"
    case .racquetball:                  return "Racquetball"
    case .rowing:                       return "Rowing"
    case .rugby:                        return "Rugby"
    case .running:                      return "Running"
    case .sailing:                      return "Sailing"
    case .skatingSports:                return "Skating Sports"
    case .snowSports:                   return "Snow Sports"
    case .soccer:                       return "Soccer"
    case .softball:                     return "Softball"
    case .squash:                       return "Squash"
    case .stairClimbing:                return "Stair Climbing"
    case .surfingSports:                return "Surfing Sports"
    case .swimming:                     return "Swimming"
    case .tableTennis:                  return "Table Tennis"
    case .tennis:                       return "Tennis"
    case .trackAndField:                return "Track and Field"
    case .traditionalStrengthTraining:  return "Traditional Strength Training"
    case .volleyball:                   return "Volleyball"
    case .walking:                      return "Walking"
    case .waterFitness:                 return "Water Fitness"
    case .waterPolo:                    return "Water Polo"
    case .waterSports:                  return "Water Sports"
    case .wrestling:                    return "Wrestling"
    case .yoga:                         return "Yoga"

    // iOS 10
    case .barre:                        return "Barre"
    case .coreTraining:                 return "Core Training"
    case .crossCountrySkiing:           return "Cross Country Skiing"
    case .downhillSkiing:               return "Downhill Skiing"
    case .flexibility:                  return "Flexibility"
    case .highIntensityIntervalTraining:    return "High Intensity Interval Training"
    case .jumpRope:                     return "Jump Rope"
    case .kickboxing:                   return "Kickboxing"
    case .pilates:                      return "Pilates"
    case .snowboarding:                 return "Snowboarding"
    case .stairs:                       return "Stairs"
    case .stepTraining:                 return "Step Training"
    case .wheelchairWalkPace:           return "Wheelchair Walk Pace"
    case .wheelchairRunPace:            return "Wheelchair Run Pace"

    // iOS 11
    case .taiChi:                       return "Tai Chi"
    case .mixedCardio:                  return "Mixed Cardio"
    case .handCycling:                  return "Hand Cycling"

    // iOS 13
    case .discSports:                   return "Disc Sports"
    case .fitnessGaming:                return "Fitness Gaming"
        
    case .pickleball:                   return "Pickleball"

    // Catch-all
    default:                            return "Other"
    }
  }
    
    var image: SQImage {
        // TODO: - PTD add icons for all activity types
        switch self {
        case .running, .walking:
            return .init(symbol: .figureWalk)
        case .functionalStrengthTraining, .traditionalStrengthTraining:
            return .init(asset: .dumbell)
        case .cycling:
            return .init(symbol: .bicycle)
        case .pickleball:
            return .init(asset: .pickleball)
        default:
            return .init(symbol: .questionmarkCircle)
        }
    }
    
    // TODO: - PTD finish with all activities
    var coreOutputQuantityTypeId: SQQuantityType? {
        switch self {
        case .running, .walking:
            return .distanceWalkingRunning
        case .cycling:
            return .distanceCycling
        case .pickleball, .traditionalStrengthTraining, .functionalStrengthTraining:
            return .activeEnergyBurned
        default:
            return nil
        }
    }
    
    var coreOutputUnit: SQUnit? {
        coreOutputQuantityTypeId?.unit
    }
}

enum SQQuantityType {
    case distanceWalkingRunning
    case distanceCycling
    case activeEnergyBurned
    case heartRate
    
    var hkQuantityTypeIdentifier: HKQuantityTypeIdentifier? {
        switch self {
        case .distanceWalkingRunning:
            return .distanceWalkingRunning
        case .distanceCycling:
            return .distanceCycling
        case .activeEnergyBurned:
            return .activeEnergyBurned
        case .heartRate:
            return .heartRate
        }
    }
    
    var unit: SQUnit? {
        switch self {
        case .activeEnergyBurned:
            return .kilocalorie
        case .distanceWalkingRunning, .distanceCycling:
            return .mile
        case .heartRate:
            return .countPerMinute
        }
    }
}

enum SQUnit: CaseIterable {
    case kilocalorie
    case mile
    case meter
    case countPerMinute
    
    static func convert(_ value: Double?, from fromUnit: SQUnit, to toUnit: SQUnit) -> Double? {
        guard let value else { return nil }
        guard fromUnit.unitType == toUnit.unitType else {
            SQLogger.shared.log("Cannot convert units of different types: \(fromUnit), \(toUnit)", .error)
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
        case .countPerMinute:
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
}

// TODO: - Figure out the best place to put this
var SQSupportedQuantityTypes: [HKQuantityTypeIdentifier]  = [
    .distanceWalkingRunning,
    .distanceCycling,
    .activeEnergyBurned,
    .heartRate
]
