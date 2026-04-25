//
//  SQInsightRelationshipRegistry.swift
//  BeastFitness
//
//  Created by Codex on 4/22/26.
//

import Foundation

struct SQInsightRelationshipRegistry {
    let activeRelationships: [SQInsightRelationshipDefinition]

    init(activeRelationships: [SQInsightRelationshipDefinition] = Self.defaultRelationships) {
        self.activeRelationships = activeRelationships.filter(\.isActive)
    }

    var relevantSignalIds: Set<String> {
        Set(
            activeRelationships.flatMap { relationship in
                [relationship.inputSignalId, relationship.outputSignalId] +
                relationship.variants.compactMap { variant in
                    guard case .nextDay(let controlMetricId, _, _) = variant.timing else {
                        return nil
                    }

                    return controlMetricId
                }
            }
        )
    }

    private static let defaultRelationships: [SQInsightRelationshipDefinition] = [
        viceRelationship(
            idBase: "insight.alcohol.sleep",
            inputSignalId: SQMetricId.alcohol,
            inputTitle: "Alcohol",
            outputSignalId: SQMetricId.sleepQuality,
            outputTitle: "Sleep Quality",
            category: .sleep,
            bucketUnitName: "evenings",
            lowBucketUpperBound: 2,
            highBucketLowerBound: 3,
            driverText: "Higher alcohol",
            outcomeText: "Lower sleep",
            strongActionText: "Try cutting back on alcohol before recovery-focused or training-heavy days.",
            subtleActionText: "Even a small sleep dip can add up. Keep alcohol lighter before recovery-focused days."
        ),
        viceRelationship(
            idBase: "insight.alcohol.energy",
            inputSignalId: SQMetricId.alcohol,
            inputTitle: "Alcohol",
            outputSignalId: SQMetricId.energy,
            outputTitle: "Energy",
            category: .recovery,
            bucketUnitName: "evenings",
            lowBucketUpperBound: 2,
            highBucketLowerBound: 3,
            driverText: "Higher alcohol",
            outcomeText: "Lower energy",
            strongActionText: "If energy matters the next day, keep alcohol lower on the nights before.",
            subtleActionText: "Even a small energy drop can matter on training days. Keep alcohol lighter the night before."
        ),
        viceRelationship(
            idBase: "insight.alcohol.mood",
            inputSignalId: SQMetricId.alcohol,
            inputTitle: "Alcohol",
            outputSignalId: SQMetricId.mood,
            outputTitle: "Mood",
            category: .habits,
            bucketUnitName: "evenings",
            lowBucketUpperBound: 2,
            highBucketLowerBound: 3,
            driverText: "Higher alcohol",
            outcomeText: "Lower mood",
            strongActionText: "If mood matters the next day, keep alcohol lower the night before."
        ),
        viceRelationship(
            idBase: "insight.alcohol.motivation",
            inputSignalId: SQMetricId.alcohol,
            inputTitle: "Alcohol",
            outputSignalId: SQMetricId.motivation,
            outputTitle: "Motivation",
            category: .habits,
            bucketUnitName: "evenings",
            lowBucketUpperBound: 2,
            highBucketLowerBound: 3,
            driverText: "Higher alcohol",
            outcomeText: "Lower motivation",
            strongActionText: "If motivation matters the next day, keep alcohol lower the night before."
        ),
        viceRelationship(
            idBase: "insight.caffeine.sleep",
            inputSignalId: SQMetricId.caffeine,
            inputTitle: "Caffeine",
            outputSignalId: SQMetricId.sleepQuality,
            outputTitle: "Sleep Quality",
            category: .sleep,
            bucketUnitName: "evenings",
            lowBucketUpperBound: 100,
            highBucketLowerBound: 200,
            driverText: "Higher caffeine",
            outcomeText: "Lower sleep",
            strongActionText: "Try pulling caffeine earlier or lowering it on nights when sleep quality matters most.",
            subtleActionText: "Even a small sleep hit can accumulate. Try lowering caffeine on recovery-focused nights."
        ),
        viceRelationship(
            idBase: "insight.caffeine.energy",
            inputSignalId: SQMetricId.caffeine,
            inputTitle: "Caffeine",
            outputSignalId: SQMetricId.energy,
            outputTitle: "Energy",
            category: .recovery,
            bucketUnitName: "evenings",
            lowBucketUpperBound: 100,
            highBucketLowerBound: 200,
            driverText: "Higher caffeine",
            outcomeText: "Lower energy",
            strongActionText: "If steadier next-day energy matters, keep caffeine lower later in the day."
        ),
        viceRelationship(
            idBase: "insight.nicotine.sleep",
            inputSignalId: SQMetricId.nicotine,
            inputTitle: "Nicotine",
            outputSignalId: SQMetricId.sleepQuality,
            outputTitle: "Sleep Quality",
            category: .sleep,
            lowBucketUpperBound: 2,
            highBucketLowerBound: 3,
            driverText: "Higher nicotine",
            outcomeText: "Lower sleep",
            strongActionText: "If sleep matters the next day, keep nicotine lower the night before."
        ),
        viceRelationship(
            idBase: "insight.nicotine.energy",
            inputSignalId: SQMetricId.nicotine,
            inputTitle: "Nicotine",
            outputSignalId: SQMetricId.energy,
            outputTitle: "Energy",
            category: .recovery,
            lowBucketUpperBound: 2,
            highBucketLowerBound: 3,
            driverText: "Higher nicotine",
            outcomeText: "Lower energy",
            strongActionText: "If energy matters the next day, keep nicotine lower the night before."
        ),
        viceRelationship(
            idBase: "insight.nicotine.mood",
            inputSignalId: SQMetricId.nicotine,
            inputTitle: "Nicotine",
            outputSignalId: SQMetricId.mood,
            outputTitle: "Mood",
            category: .habits,
            lowBucketUpperBound: 2,
            highBucketLowerBound: 3,
            driverText: "Higher nicotine",
            outcomeText: "Lower mood",
            strongActionText: "If mood matters the next day, keep nicotine lower the night before."
        ),
        viceRelationship(
            idBase: "insight.nicotine.motivation",
            inputSignalId: SQMetricId.nicotine,
            inputTitle: "Nicotine",
            outputSignalId: SQMetricId.motivation,
            outputTitle: "Motivation",
            category: .habits,
            lowBucketUpperBound: 2,
            highBucketLowerBound: 3,
            driverText: "Higher nicotine",
            outcomeText: "Lower motivation",
            strongActionText: "If motivation matters the next day, keep nicotine lower the night before."
        ),
        viceRelationship(
            idBase: "insight.weed.sleep",
            inputSignalId: SQMetricId.weed,
            inputTitle: "Weed",
            outputSignalId: SQMetricId.sleepQuality,
            outputTitle: "Sleep Quality",
            category: .sleep,
            lowBucketUpperBound: 2,
            highBucketLowerBound: 3,
            driverText: "Higher weed",
            outcomeText: "Lower sleep",
            strongActionText: "If sleep quality matters the next day, keep weed lower the night before."
        ),
        viceRelationship(
            idBase: "insight.weed.energy",
            inputSignalId: SQMetricId.weed,
            inputTitle: "Weed",
            outputSignalId: SQMetricId.energy,
            outputTitle: "Energy",
            category: .recovery,
            lowBucketUpperBound: 2,
            highBucketLowerBound: 3,
            driverText: "Higher weed",
            outcomeText: "Lower energy",
            strongActionText: "If energy matters the next day, keep weed lower the night before."
        ),
        viceRelationship(
            idBase: "insight.weed.mood",
            inputSignalId: SQMetricId.weed,
            inputTitle: "Weed",
            outputSignalId: SQMetricId.mood,
            outputTitle: "Mood",
            category: .habits,
            lowBucketUpperBound: 2,
            highBucketLowerBound: 3,
            driverText: "Higher weed",
            outcomeText: "Lower mood",
            strongActionText: "If mood matters the next day, keep weed lower the night before."
        ),
        viceRelationship(
            idBase: "insight.weed.motivation",
            inputSignalId: SQMetricId.weed,
            inputTitle: "Weed",
            outputSignalId: SQMetricId.motivation,
            outputTitle: "Motivation",
            category: .habits,
            lowBucketUpperBound: 2,
            highBucketLowerBound: 3,
            driverText: "Higher weed",
            outcomeText: "Lower motivation",
            strongActionText: "If motivation matters the next day, keep weed lower the night before."
        ),
        viceRelationship(
            idBase: "insight.porn.mood",
            inputSignalId: SQMetricId.porn,
            inputTitle: "Porn",
            outputSignalId: SQMetricId.mood,
            outputTitle: "Mood",
            category: .habits,
            lowBucketUpperBound: 2,
            highBucketLowerBound: 3,
            driverText: "Higher porn",
            outcomeText: "Lower mood",
            strongActionText: "If mood matters the next day, keep porn use lower the night before."
        ),
        viceRelationship(
            idBase: "insight.porn.motivation",
            inputSignalId: SQMetricId.porn,
            inputTitle: "Porn",
            outputSignalId: SQMetricId.motivation,
            outputTitle: "Motivation",
            category: .habits,
            lowBucketUpperBound: 2,
            highBucketLowerBound: 3,
            driverText: "Higher porn",
            outcomeText: "Lower motivation",
            strongActionText: "If motivation matters the next day, keep porn use lower the night before."
        ),
        workoutPerformanceRelationship(
            id: "insight.sleep-quality.workout-performance",
            inputSignalId: SQMetricId.sleepQuality,
            inputTitle: "Sleep Quality",
            driverText: "Better sleep quality",
            lowBucketUpperBound: 5.5,
            highBucketLowerBound: 7,
            strongActionText: "Protect sleep quality before sessions where performance matters most.",
            subtleActionText: "Even small performance gains are worth protecting before key sessions."
        ),
        workoutPerformanceRelationship(
            id: "insight.sleep-hours.workout-performance",
            inputSignalId: SQMetricId.sleepHours,
            inputTitle: "Sleep Hours",
            driverText: "More sleep",
            lowBucketUpperBound: 6.5,
            highBucketLowerBound: 7.5,
            strongActionText: "Aim for more sleep before sessions where performance matters most.",
            subtleActionText: "Even a modest sleep edge can help on important training days."
        ),
        viceRelationship(
            idBase: "insight.alcohol.workout-performance",
            inputSignalId: SQMetricId.alcohol,
            inputTitle: "Alcohol",
            outputSignalId: SQInsightAnalysisMetricId.workoutPerformance,
            outputTitle: "Workout Performance",
            category: .training,
            bucketUnitName: "evenings",
            lowBucketUpperBound: 2,
            highBucketLowerBound: 3,
            driverText: "Higher alcohol",
            outcomeText: "Lower performance",
            strongActionText: "If workout performance matters the next day, keep alcohol lower the night before.",
            subtleActionText: "Even a small performance dip can matter on important training days. Keep alcohol lighter the night before."
        ),
        viceRelationship(
            idBase: "insight.caffeine.workout-performance",
            inputSignalId: SQMetricId.caffeine,
            inputTitle: "Caffeine",
            outputSignalId: SQInsightAnalysisMetricId.workoutPerformance,
            outputTitle: "Workout Performance",
            category: .training,
            lowBucketUpperBound: 100,
            highBucketLowerBound: 200,
            driverText: "Higher caffeine",
            outcomeText: "Lower performance",
            strongActionText: "If workout performance matters, keep caffeine at the level that supports better sessions."
        ),
        viceRelationship(
            idBase: "insight.nicotine.workout-performance",
            inputSignalId: SQMetricId.nicotine,
            inputTitle: "Nicotine",
            outputSignalId: SQInsightAnalysisMetricId.workoutPerformance,
            outputTitle: "Workout Performance",
            category: .training,
            lowBucketUpperBound: 2,
            highBucketLowerBound: 3,
            driverText: "Higher nicotine",
            outcomeText: "Lower performance",
            strongActionText: "If workout performance matters, keep nicotine lower on training days and the night before."
        ),
        viceRelationship(
            idBase: "insight.weed.workout-performance",
            inputSignalId: SQMetricId.weed,
            inputTitle: "Weed",
            outputSignalId: SQInsightAnalysisMetricId.workoutPerformance,
            outputTitle: "Workout Performance",
            category: .training,
            lowBucketUpperBound: 2,
            highBucketLowerBound: 3,
            driverText: "Higher weed",
            outcomeText: "Lower performance",
            strongActionText: "If workout performance matters, keep weed lower on training days and the night before."
        ),
        viceRelationship(
            idBase: "insight.porn.workout-performance",
            inputSignalId: SQMetricId.porn,
            inputTitle: "Porn",
            outputSignalId: SQInsightAnalysisMetricId.workoutPerformance,
            outputTitle: "Workout Performance",
            category: .training,
            lowBucketUpperBound: 2,
            highBucketLowerBound: 3,
            driverText: "Higher porn",
            outcomeText: "Lower performance",
            strongActionText: "If workout performance matters, keep porn use lower on training days and the night before."
        )
    ]

    private static func viceRelationship(
        idBase: String,
        inputSignalId: String,
        inputTitle: String,
        outputSignalId: String,
        outputTitle: String,
        category: SQInsightCategory,
        bucketUnitName: String = "days",
        lowBucketUpperBound: Double,
        highBucketLowerBound: Double,
        driverText: String,
        outcomeText: String,
        strongActionText: String,
        subtleActionText: String? = nil
    ) -> SQInsightRelationshipDefinition {
        .init(
            inputSignalId: inputSignalId,
            inputTitle: inputTitle,
            outputSignalId: outputSignalId,
            outputTitle: outputTitle,
            category: category,
            recommendationFamily: .reduce,
            variants: [
                .init(
                    id: "\(idBase).carryover-clean",
                    priority: 0,
                    timing: .nextDay(
                        controlMetricId: inputSignalId,
                        controlTitle: inputTitle,
                        controlRequirement: .absent
                    )
                ),
                .init(
                    id: "\(idBase).carryover-with-reuse",
                    priority: 1,
                    timing: .nextDay(
                        controlMetricId: inputSignalId,
                        controlTitle: inputTitle,
                        controlRequirement: .present
                    )
                ),
                .init(
                    id: "\(idBase).same-day",
                    priority: 2,
                    timing: .sameDay
                )
            ],
            lowBucketUpperBound: lowBucketUpperBound,
            highBucketLowerBound: highBucketLowerBound,
            bucketUnitName: bucketUnitName,
            expectedEffect: .negative,
            driverText: driverText,
            outcomeText: outcomeText,
            strongActionText: strongActionText,
            subtleActionText: subtleActionText
        )
    }

    private static func workoutPerformanceRelationship(
        id: String,
        inputSignalId: String,
        inputTitle: String,
        driverText: String,
        lowBucketUpperBound: Double,
        highBucketLowerBound: Double,
        strongActionText: String,
        subtleActionText: String? = nil
    ) -> SQInsightRelationshipDefinition {
        .init(
            inputSignalId: inputSignalId,
            inputTitle: inputTitle,
            outputSignalId: SQInsightAnalysisMetricId.workoutPerformance,
            outputTitle: "Workout Performance",
            category: .training,
            recommendationFamily: .increase,
            variants: [
                .init(id: id, priority: 0, timing: .sameDay)
            ],
            lowBucketUpperBound: lowBucketUpperBound,
            highBucketLowerBound: highBucketLowerBound,
            bucketUnitName: "workout days",
            expectedEffect: .positive,
            driverText: driverText,
            outcomeText: "Better workouts",
            strongActionText: strongActionText,
            subtleActionText: subtleActionText
        )
    }
}
