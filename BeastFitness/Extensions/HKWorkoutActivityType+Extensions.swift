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

    
    // TODO: - PTD best-guess mappings for all activities.
    // You can adjust per activity if you want a different "core" metric.
    var coreOutputQuantityTypeId: SQQuantityType? {
        switch self {

        // MARK: - Distance: walking / running–style
        case .running,
             .walking,
             .hiking,
             .wheelchairWalkPace,
             .wheelchairRunPace:
            return .distanceWalkingRunning

        // MARK: - Distance: cycling
        case .cycling,
             .handCycling:
            return .distanceCycling

        // MARK: - Distance: swimming / water cardio
        case .swimming,
             .waterFitness,
             .waterSports:
            return .distanceSwimming   // add to SQQuantityType if you don't have it

        // MARK: - Distance: rowing
        case .rowing:
            return .distanceRowing     // add to SQQuantityType if needed

        // MARK: - Distance: snow sports
        case .crossCountrySkiing:
            return .distanceCrossCountrySkiing   // add if needed
        case .downhillSkiing,
             .snowboarding,
             .snowSports:
            return .distanceDownhillSnowSports   // add if needed

        // MARK: - Stair / step based
        case .stairClimbing,
             .stairs:
            return .flightsClimbed     // or .distanceWalkingRunning if you prefer

        // MARK: - Tri / multi-sport
        case .swimBikeRun:
            // Could also choose distanceSwimming or distanceCycling depending on how you aggregate
            return .distanceWalkingRunning

        // MARK: - Strength / gym / HIIT / cardio machines
        case .elliptical,
             .coreTraining,
             .highIntensityIntervalTraining,
             .mixedMetabolicCardioTraining,
             .mixedCardio,
             .jumpRope,
             .stepTraining,
             .fitnessGaming,
             .cardioDance,
             .cooldown,
             .preparationAndRecovery:
            return nil
            
        case .functionalStrengthTraining,
             .traditionalStrengthTraining:
            return .sqTotalVolumeLifted

        // MARK: - Team & court / field sports
        case .americanFootball,
             .australianFootball,
             .soccer,
             .lacrosse,
             .rugby,
             .cricket,
             .basketball,
             .baseball,
             .softball,
             .hockey,
             .handball,
             .volleyball,
             .waterPolo,
             .pickleball,
             .discSports,
             .paddleSports:
            return nil

        // MARK: - Racket & similar
        case .badminton,
             .tennis,
             .tableTennis,
             .racquetball,
             .squash:
            return nil

        // MARK: - Combat / martial / boxing
        case .boxing,
             .martialArts,
             .kickboxing,
             .wrestling:
            return nil

        // MARK: - Dance & mind/body
        case .dance,
             .danceInspiredTraining,
             .socialDance,
             .yoga,
             .mindAndBody,
             .taiChi,
             .pilates,
             .flexibility,
             .barre:
            return nil

        // MARK: - Misc / outdoor activities
        case .climbing,
             .fishing,
             .hunting,
             .equestrianSports,
             .golf,
             .gymnastics,
             .skatingSports,
             .surfingSports,
             .sailing,
             .trackAndField,
             .underwaterDiving,
             .play,
             .archery,
             .bowling,
             .crossTraining,
             .curling,
             .fencing,
             .other:
            return nil

        // MARK: - Newer / catch-all
        case .transition:
            return nil

        @unknown default:
            return nil
        }
    }
}

// MARK: - Images

extension HKWorkoutActivityType {

    var imageSymbol: SQImageSymbol {
            switch self {

            // MARK: - Movement basics
            case .running:
                return .figureRun
            case .walking:
                return .figureWalk
            case .hiking:
                return .figureHiking
            case .stairClimbing, .stairs, .stepTraining:
                return .figureStairs

            // MARK: - Strength / gym
            case .functionalStrengthTraining,
                 .traditionalStrengthTraining,
                 .coreTraining,
                 .crossTraining:
                return .figureStrength

            // MARK: - Cardio machines & mixed
            case .elliptical:
                return .figureElliptical
            case .rowing:
                return .figureRowing
            case .mixedCardio,
                 .mixedMetabolicCardioTraining,
                 .highIntensityIntervalTraining,
                 .jumpRope,
                 .fitnessGaming:
                return .figureRun

            // MARK: - Wheels
            case .cycling,
                 .handCycling:
                return .bicycle
            case .wheelchairWalkPace,
                 .wheelchairRunPace:
                return .wheelchairWalkPace

            // MARK: - Water
            case .swimming,
                 .waterFitness,
                 .waterSports,
                 .waterPolo,
                 .underwaterDiving:
                return .figureSwimming
            case .sailing:
                return .sailboat
            case .surfingSports:
                return .surfing

            // MARK: - Snow & ice
            case .downhillSkiing,
                 .crossCountrySkiing,
                 .snowSports:
                return .figureSkiing
            case .snowboarding:
                return .figureSnowboarding
            case .skatingSports:
                return .figureSkating

            // MARK: - Mind & mobility
            case .yoga,
                 .mindAndBody,
                 .flexibility,
                 .taiChi,
                 .preparationAndRecovery,
                 .cooldown:
                return .figureYoga
            case .pilates,
                 .barre:
                return .figurePilates

            // MARK: - Field & court sports
            case .basketball:
                return .basketball
            case .baseball,
                 .softball:
                return .baseball
            case .soccer:
                return .soccerball
            case .volleyball:
                return .volleyball
            case .rugby:
                return .rugbyball
            case .americanFootball,
                 .australianFootball:
                return .football
            case .tennis,
                 .racquetball,
                 .squash,
                 .paddleSports:
                return .tennisRacket
            case .tableTennis:
                return .tableTennisPaddle
            case .badminton:
                return .badminton
            case .pickleball:
                return .figurePickleball
            case .golf:
                return .golf
            case .hockey:
                return .hockeyPuck
            case .bowling:
                return .bowlingBall
            case .handball:
                return .figureHandball

            // MARK: - Combat / martial
            case .boxing,
                 .kickboxing,
                 .martialArts:
                return .boxing
            case .wrestling:
                return .figureStrength

            // MARK: - Dance-related
            case .dance,
                 .danceInspiredTraining,
                 .socialDance,
                 .cardioDance:
                return .figureDance
                
            // MARK: - Outdoor & misc
            case .climbing:
                return .climbing
            case .equestrianSports:
                return .figureEquestrian
            case .fencing:
                return .fencing
            case .fishing:
                return .figureFishing
            case .hunting:
                return .figureHunting
            case .cricket:
                return .figureCricket
            case .discSports:
                return .figureDiscSports
            case .gymnastics:
                return .figureStrength
            case .trackAndField:
                return .figureRun
            case .play:
                return .figureRun

            // MARK: - Multi-stage
            case .swimBikeRun,
                 .transition:
                return .figureRun
                
            case .archery:
                return .figureArchery
                
            case .curling:
                return .figureCurling
                
            case .lacrosse:
                return .figureLacrosse

            // MARK: - Catch-all
            case .other:
                return .questionmarkCircle

            @unknown default:
                return .questionmarkCircle
            }
        }

}
