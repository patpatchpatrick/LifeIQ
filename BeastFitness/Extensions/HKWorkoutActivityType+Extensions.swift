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
        case .highIntensityIntervalTraining:return "High Intensity Interval Training"
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

        // Newer types
        case .cricket:                      return "Cricket"
        case .cardioDance:                  return "Cardio Dance"
        case .socialDance:                  return "Social Dance"
        case .cooldown:                     return "Cooldown"
        case .swimBikeRun:                  return "Swim-Bike-Run"
        case .transition:                   return "Transition"
        case .underwaterDiving:            return "Underwater Diving"

        // Catch-all
        case .other:                        return "Other"

        @unknown default:
            return "Other"
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

// MARK: - Images

extension HKWorkoutActivityType {

    var imageSymbol: SQImageSymbol {
        switch self {

        // Movement basics
        case .running:                          return .figureRun
        case .walking:                          return .figureWalk
        case .hiking:                           return .figureHiking
        case .stairClimbing, .stairs:           return .figureStairs

        // Strength
        case .functionalStrengthTraining,
             .traditionalStrengthTraining:      return .figureStrength

        // Cardio machines & mixed
        case .elliptical:                       return .figureElliptical
        case .rowing:                           return .figureRowing
        case .mixedCardio,
             .mixedMetabolicCardioTraining,
             .highIntensityIntervalTraining:    return .figureRun

        // Wheels
        case .cycling, .handCycling:            return .bicycle
        case .wheelchairWalkPace,
             .wheelchairRunPace:                return .wheelchairWalkPace

        // Water
        case .swimming, .waterFitness,
             .waterSports, .waterPolo:          return .figureSwimming
        case .sailing:                          return .sailboat
        case .surfingSports:                    return .surfing

        // Snow & ice
        case .downhillSkiing, .crossCountrySkiing: return .figureSkiing
        case .snowboarding:                     return .figureSnowboarding
        case .skatingSports:                    return .figureSkating

        // Mind & mobility
        case .yoga:                             return .figureYoga
        case .pilates:                          return .figurePilates
        case .flexibility, .mindAndBody:        return .figureYoga
        case .preparationAndRecovery:           return .figureYoga
        case .cooldown:                         return .figureYoga  // closest match

        // Field & court sports
        case .basketball:                       return .basketball
        case .baseball, .softball:              return .baseball
        case .soccer:                           return .soccerball
        case .volleyball:                       return .volleyball
        case .rugby:                            return .rugbyball
        case .americanFootball,
             .australianFootball:               return .football
        case .tennis, .racquetball, .squash:    return .tennisRacket
        case .tableTennis:                      return .tableTennisPaddle
        case .badminton:                        return .badminton
        case .pickleball:                       return .questionmarkCircle // asset-only type
        case .golf:                             return .golf
        case .hockey:                           return .hockeyPuck
        case .bowling:                          return .bowlingBall
        case .handball:                         return .handCycling // closest available SF symbol

        // Niche / best-effort
        case .fencing:                          return .fencing
        case .boxing, .kickboxing:              return .boxing
        case .climbing:                         return .climbing
        case .equestrianSports:                 return .figureWalk    // no horse icon
        case .archery:                          return .questionmarkCircle
        case .fishing:                          return .questionmarkCircle
        case .hunting:                          return .questionmarkCircle
        case .discSports:                       return .questionmarkCircle
        case .fitnessGaming:                    return .questionmarkCircle

        // Dance-related
        case .dance, .danceInspiredTraining:    return .figureRun     // closest symbol
        case .socialDance:                      return .figureRun     // same
        case .cardioDance:                      return .figureRun

        // Multi-stage
        case .swimBikeRun:                      return .figureRun     // triathlon-like, no symbol exists
        case .transition:                       return .figureRun     // closest match

        // Cricket
        case .cricket:                          return .questionmarkCircle  // no cricket SF Symbol

        // Underwater / diving
        case .underwaterDiving:                 return .figureSwimming

        // Catch-all
        case .other:                            return .questionmarkCircle

        @unknown default:
            return .questionmarkCircle
        }
    }

}
