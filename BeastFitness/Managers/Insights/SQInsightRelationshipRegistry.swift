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
        signalTrend(
            id: "insight.trend.alcohol",
            inputSignalId: SQMetricId.alcohol,
            inputTitle: "Alcohol",
            category: .habits,
            recommendationFamily: .reduce,
            bucketUnitName: "days",
            expectedEffect: .negative,
            strongActionText: "Alcohol has been moving in the wrong direction recently. Try a lighter stretch and see how your next few days feel."
        ),
        signalTrend(
            id: "insight.trend.caffeine",
            inputSignalId: SQMetricId.caffeine,
            inputTitle: "Caffeine",
            category: .habits,
            recommendationFamily: .shiftEarlier,
            bucketUnitName: "days",
            expectedEffect: .negative,
            strongActionText: "Caffeine is trending up recently. If sleep or steady energy matters, pull it earlier or bring it down slightly."
        ),
        signalTrend(
            id: "insight.trend.weed",
            inputSignalId: SQMetricId.weed,
            inputTitle: "Weed",
            category: .habits,
            recommendationFamily: .reduce,
            bucketUnitName: "days",
            expectedEffect: .negative,
            strongActionText: "Weed use has been trending up recently. If recovery or sleep matters, try a lighter stretch and compare the next few days."
        ),
        signalBaselineChange(
            id: "insight.baseline.sleep-hours",
            inputSignalId: SQMetricId.sleepHours,
            inputTitle: "Sleep Hours",
            category: .sleep,
            recommendationFamily: .increase,
            bucketUnitName: "days",
            expectedEffect: .positive,
            strongActionText: "Sleep has slipped below your normal baseline. Protect a few longer nights and watch how recovery responds."
        ),
        signalBaselineChange(
            id: "insight.baseline.sleep-quality",
            inputSignalId: SQMetricId.sleepQuality,
            inputTitle: "Sleep Quality",
            category: .sleep,
            recommendationFamily: .protectRecovery,
            bucketUnitName: "days",
            expectedEffect: .positive,
            strongActionText: "Sleep quality is running below your usual baseline. Keep evenings recovery-friendly for a few days and see if it rebounds."
        ),
        signalBaselineChange(
            id: "insight.baseline.energy",
            inputSignalId: SQMetricId.energy,
            inputTitle: "Energy",
            category: .recovery,
            recommendationFamily: .protectRecovery,
            bucketUnitName: "days",
            expectedEffect: .positive,
            strongActionText: "Energy is below your usual baseline right now. Pull back on drains and protect sleep until it rebounds."
        ),
        signalBaselineChange(
            id: "insight.baseline.mood",
            inputSignalId: SQMetricId.mood,
            inputTitle: "Mood",
            category: .habits,
            recommendationFamily: .keepConsistent,
            bucketUnitName: "days",
            expectedEffect: .positive,
            strongActionText: "Mood is below your usual baseline. Keep routines steadier for a few days and watch whether it lifts."
        ),
        currentStateRelationship(
            id: "insight.today.sleep-hours.opportunity",
            inputSignalId: SQMetricId.sleepHours,
            inputTitle: "Sleep Hours",
            insightClass: .opportunity,
            category: .sleep,
            recommendationFamily: .protectRecovery,
            bucketUnitName: "days",
            minimumBucketSampleCount: 3,
            minimumEffectMagnitude: 0.75,
            recentWindowDayCount: 1,
            baselineWindowDayCount: 14,
            expectedEffect: .positive,
            driverText: "Sleep is supporting today",
            outcomeText: "Recovery Tailwind",
            strongActionText: "Sleep is lining up well today. Use it, but keep the rest of the day recovery-friendly enough to hold onto the advantage."
        ),
        currentStateRelationship(
            id: "insight.today.sleep-hours.risk",
            inputSignalId: SQMetricId.sleepHours,
            inputTitle: "Sleep Hours",
            insightClass: .risk,
            category: .sleep,
            recommendationFamily: .protectRecovery,
            bucketUnitName: "days",
            minimumBucketSampleCount: 3,
            minimumEffectMagnitude: 0.75,
            recentWindowDayCount: 1,
            baselineWindowDayCount: 14,
            expectedEffect: .positive,
            driverText: "Sleep is dragging today",
            outcomeText: "Recovery Drag",
            strongActionText: "Sleep is below your usual range. Protect recovery today and avoid stacking extra strain if you can."
        ),
        currentStateRelationship(
            id: "insight.today.sleep-quality.opportunity",
            inputSignalId: SQMetricId.sleepQuality,
            inputTitle: "Sleep Quality",
            insightClass: .opportunity,
            category: .sleep,
            recommendationFamily: .protectRecovery,
            bucketUnitName: "days",
            minimumBucketSampleCount: 3,
            minimumEffectMagnitude: 0.75,
            recentWindowDayCount: 1,
            baselineWindowDayCount: 14,
            expectedEffect: .positive,
            driverText: "Sleep quality is helping today",
            outcomeText: "Recovery Tailwind",
            strongActionText: "Sleep quality looks better than usual. This is a good day to take advantage of that recovery if the rest of the signals cooperate."
        ),
        currentStateRelationship(
            id: "insight.today.sleep-quality.risk",
            inputSignalId: SQMetricId.sleepQuality,
            inputTitle: "Sleep Quality",
            insightClass: .risk,
            category: .sleep,
            recommendationFamily: .protectRecovery,
            bucketUnitName: "days",
            minimumBucketSampleCount: 3,
            minimumEffectMagnitude: 0.75,
            recentWindowDayCount: 1,
            baselineWindowDayCount: 14,
            expectedEffect: .positive,
            driverText: "Sleep quality is hurting today",
            outcomeText: "Recovery Drag",
            strongActionText: "Sleep quality is below your usual range. Keep the day steadier and set up tonight to recover better."
        ),
        currentStateRelationship(
            id: "insight.today.energy.opportunity",
            inputSignalId: SQMetricId.energy,
            inputTitle: "Energy",
            insightClass: .opportunity,
            category: .recovery,
            recommendationFamily: .moderateStrain,
            bucketUnitName: "days",
            minimumBucketSampleCount: 3,
            minimumEffectMagnitude: 0.75,
            recentWindowDayCount: 1,
            baselineWindowDayCount: 14,
            expectedEffect: .positive,
            driverText: "Energy is available today",
            outcomeText: "Good Window",
            strongActionText: "Energy is stronger than usual today. If the rest of your signals line up, this could be a good window to use it well."
        ),
        currentStateRelationship(
            id: "insight.today.energy.risk",
            inputSignalId: SQMetricId.energy,
            inputTitle: "Energy",
            insightClass: .risk,
            category: .recovery,
            recommendationFamily: .protectRecovery,
            bucketUnitName: "days",
            minimumBucketSampleCount: 3,
            minimumEffectMagnitude: 0.75,
            recentWindowDayCount: 1,
            baselineWindowDayCount: 14,
            expectedEffect: .positive,
            driverText: "Energy is under pressure today",
            outcomeText: "Low Reserve",
            strongActionText: "Energy is below your usual range today. Protect the basics and avoid making the day harder than it needs to be."
        ),
        currentStateRelationship(
            id: "insight.today.sleep-energy.opportunity",
            inputSignalId: SQMetricId.sleepHours,
            inputTitle: "Sleep Hours",
            outputSignalId: SQMetricId.energy,
            outputTitle: "Energy",
            insightClass: .opportunity,
            category: .recovery,
            recommendationFamily: .moderateStrain,
            bucketUnitName: "days",
            minimumBucketSampleCount: 3,
            minimumEffectMagnitude: 0.75,
            recentWindowDayCount: 1,
            baselineWindowDayCount: 14,
            expectedEffect: .positive,
            driverText: "Sleep and energy are aligned",
            outcomeText: "Strong Window",
            strongActionText: "Sleep and energy are both running stronger than usual. If the rest of your signals agree, this is a good day to use that window well."
        ),
        currentStateRelationship(
            id: "insight.today.sleep-energy.risk",
            inputSignalId: SQMetricId.sleepHours,
            inputTitle: "Sleep Hours",
            outputSignalId: SQMetricId.energy,
            outputTitle: "Energy",
            insightClass: .risk,
            category: .recovery,
            recommendationFamily: .protectRecovery,
            bucketUnitName: "days",
            minimumBucketSampleCount: 3,
            minimumEffectMagnitude: 0.75,
            recentWindowDayCount: 1,
            baselineWindowDayCount: 14,
            expectedEffect: .positive,
            driverText: "Sleep and energy are both low",
            outcomeText: "Stacked Drag",
            strongActionText: "Sleep and energy are both below your usual range. Treat today as a recovery-protection day and avoid stacking unnecessary strain."
        ),
        currentStateRelationship(
            id: "insight.today.sleep-quality-mood.opportunity",
            inputSignalId: SQMetricId.sleepQuality,
            inputTitle: "Sleep Quality",
            outputSignalId: SQMetricId.mood,
            outputTitle: "Mood",
            insightClass: .opportunity,
            category: .recovery,
            recommendationFamily: .keepConsistent,
            bucketUnitName: "days",
            minimumBucketSampleCount: 3,
            minimumEffectMagnitude: 0.75,
            recentWindowDayCount: 1,
            baselineWindowDayCount: 14,
            expectedEffect: .positive,
            driverText: "Sleep quality and mood are aligned",
            outcomeText: "Supportive State",
            strongActionText: "Sleep quality and mood are both stronger than usual. Keep the day consistent and see if the momentum holds."
        ),
        currentStateRelationship(
            id: "insight.today.sleep-quality-mood.risk",
            inputSignalId: SQMetricId.sleepQuality,
            inputTitle: "Sleep Quality",
            outputSignalId: SQMetricId.mood,
            outputTitle: "Mood",
            insightClass: .risk,
            category: .recovery,
            recommendationFamily: .keepConsistent,
            bucketUnitName: "days",
            minimumBucketSampleCount: 3,
            minimumEffectMagnitude: 0.75,
            recentWindowDayCount: 1,
            baselineWindowDayCount: 14,
            expectedEffect: .positive,
            driverText: "Sleep quality and mood are both under pressure",
            outcomeText: "Stacked Drag",
            strongActionText: "Sleep quality and mood are both below usual. Keep today steadier than normal and protect tonight's recovery."
        ),
        signalBaselineChange(
            id: "insight.baseline.workout-performance",
            inputSignalId: SQInsightAnalysisMetricId.workoutPerformance,
            inputTitle: "Workout Performance",
            category: .training,
            recommendationFamily: .protectRecovery,
            eligibleSurfaceIntents: [.pastWeek, .pastYear],
            bucketUnitName: "workout days",
            minimumBucketSampleCount: 2,
            minimumEffectMagnitude: 0.4,
            recentWindowDayCount: 2,
            baselineWindowDayCount: 8,
            expectedEffect: .positive,
            strongActionText: "Workout performance is below your usual baseline. Protect recovery and watch whether the next few sessions rebound."
        ),
        followUpRelationship(
            id: "insight.followup.alcohol-energy",
            inputSignalId: SQMetricId.alcohol,
            inputTitle: "Alcohol",
            outputSignalId: SQMetricId.energy,
            outputTitle: "Energy",
            category: .recovery,
            bucketUnitName: "days",
            expectedEffect: .negative
        ),
        followUpRelationship(
            id: "insight.followup.alcohol-mood",
            inputSignalId: SQMetricId.alcohol,
            inputTitle: "Alcohol",
            outputSignalId: SQMetricId.mood,
            outputTitle: "Mood",
            category: .habits,
            bucketUnitName: "days",
            expectedEffect: .negative
        ),
        followUpRelationship(
            id: "insight.followup.caffeine-sleep",
            inputSignalId: SQMetricId.caffeine,
            inputTitle: "Caffeine",
            outputSignalId: SQMetricId.sleepQuality,
            outputTitle: "Sleep Quality",
            category: .sleep,
            bucketUnitName: "days",
            expectedEffect: .negative
        ),
        followUpRelationship(
            id: "insight.followup.sleep-hours-energy",
            inputSignalId: SQMetricId.sleepHours,
            inputTitle: "Sleep Hours",
            outputSignalId: SQMetricId.energy,
            outputTitle: "Energy",
            category: .recovery,
            bucketUnitName: "days",
            expectedEffect: .positive
        ),
        followUpRelationship(
            id: "insight.followup.sleep-quality-performance",
            inputSignalId: SQMetricId.sleepQuality,
            inputTitle: "Sleep Quality",
            outputSignalId: SQInsightAnalysisMetricId.workoutPerformance,
            outputTitle: "Workout Performance",
            category: .training,
            bucketUnitName: "workout days",
            minimumBucketSampleCount: 2,
            minimumEffectMagnitude: 0.4,
            expectedEffect: .positive
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

    private static func signalTrend(
        id: String,
        inputSignalId: String,
        inputTitle: String,
        category: SQInsightCategory,
        recommendationFamily: SQInsightRecommendationFamily,
        eligibleSurfaceIntents: Set<SQInsightSurfaceIntent> = [.today, .pastWeek],
        bucketUnitName: String,
        minimumBucketSampleCount: Int = 2,
        minimumEffectMagnitude: Double = 0.75,
        recentWindowDayCount: Int = 3,
        comparisonWindowDayCount: Int = 3,
        expectedEffect: SQInsightEffect,
        strongActionText: String
    ) -> SQInsightRelationshipDefinition {
        .init(
            familyKey: "trend.\(inputSignalId)",
            inputSignalId: inputSignalId,
            inputTitle: inputTitle,
            outputSignalId: inputSignalId,
            outputTitle: inputTitle,
            insightClass: .trend,
            analyzerFamily: .recentTrend,
            category: category,
            recommendationFamily: recommendationFamily,
            eligibleSurfaceIntents: eligibleSurfaceIntents,
            variants: [
                .init(id: id, priority: 0, timing: .sameDay)
            ],
            lowBucketUpperBound: 0,
            highBucketLowerBound: 0,
            bucketUnitName: bucketUnitName,
            minimumBucketSampleCount: minimumBucketSampleCount,
            minimumEffectMagnitude: minimumEffectMagnitude,
            recentWindowDayCount: recentWindowDayCount,
            comparisonWindowDayCount: comparisonWindowDayCount,
            expectedEffect: expectedEffect,
            driverText: inputTitle,
            outcomeText: "Recent Trend",
            strongActionText: strongActionText,
            subtleActionText: "Keep watching the recent trend and compare how the next few days feel."
        )
    }

    private static func signalBaselineChange(
        id: String,
        inputSignalId: String,
        inputTitle: String,
        category: SQInsightCategory,
        recommendationFamily: SQInsightRecommendationFamily,
        eligibleSurfaceIntents: Set<SQInsightSurfaceIntent> = [.today, .pastWeek, .pastYear],
        bucketUnitName: String,
        minimumBucketSampleCount: Int = 3,
        minimumEffectMagnitude: Double = 0.75,
        recentWindowDayCount: Int = 3,
        baselineWindowDayCount: Int = 14,
        expectedEffect: SQInsightEffect,
        strongActionText: String
    ) -> SQInsightRelationshipDefinition {
        .init(
            familyKey: "baseline.\(inputSignalId)",
            inputSignalId: inputSignalId,
            inputTitle: inputTitle,
            outputSignalId: inputSignalId,
            outputTitle: inputTitle,
            insightClass: .baselineChange,
            analyzerFamily: .baselineDeviation,
            category: category,
            recommendationFamily: recommendationFamily,
            eligibleSurfaceIntents: eligibleSurfaceIntents,
            variants: [
                .init(id: id, priority: 0, timing: .sameDay)
            ],
            lowBucketUpperBound: 0,
            highBucketLowerBound: 0,
            bucketUnitName: bucketUnitName,
            minimumBucketSampleCount: minimumBucketSampleCount,
            minimumEffectMagnitude: minimumEffectMagnitude,
            recentWindowDayCount: recentWindowDayCount,
            baselineWindowDayCount: baselineWindowDayCount,
            expectedEffect: expectedEffect,
            driverText: inputTitle,
            outcomeText: "Baseline Shift",
            strongActionText: strongActionText,
            subtleActionText: "Use this baseline shift as a check-in point and see if it persists."
        )
    }

    private static func followUpRelationship(
        id: String,
        inputSignalId: String,
        inputTitle: String,
        outputSignalId: String,
        outputTitle: String,
        category: SQInsightCategory,
        bucketUnitName: String,
        minimumBucketSampleCount: Int = 3,
        minimumEffectMagnitude: Double = 0.75,
        recentWindowDayCount: Int = 3,
        comparisonWindowDayCount: Int = 3,
        expectedEffect: SQInsightEffect
    ) -> SQInsightRelationshipDefinition {
        .init(
            familyKey: "followup.\(inputSignalId)->\(outputSignalId)",
            inputSignalId: inputSignalId,
            inputTitle: inputTitle,
            outputSignalId: outputSignalId,
            outputTitle: outputTitle,
            insightClass: .followUp,
            analyzerFamily: .followUpOutcome,
            category: category,
            recommendationFamily: .observeAndCompare,
            eligibleSurfaceIntents: [.today, .pastWeek],
            variants: [
                .init(id: id, priority: 0, timing: .sameDay)
            ],
            lowBucketUpperBound: 0,
            highBucketLowerBound: 0,
            bucketUnitName: bucketUnitName,
            minimumBucketSampleCount: minimumBucketSampleCount,
            minimumEffectMagnitude: minimumEffectMagnitude,
            recentWindowDayCount: recentWindowDayCount,
            comparisonWindowDayCount: comparisonWindowDayCount,
            expectedEffect: expectedEffect,
            driverText: inputTitle,
            outcomeText: outputTitle,
            strongActionText: "The recent shift looks promising. Keep going and compare how the next few \(bucketUnitName) feel.",
            subtleActionText: "Keep this change steady for a little longer and see whether the result persists."
        )
    }

    private static func currentStateRelationship(
        id: String,
        inputSignalId: String,
        inputTitle: String,
        outputSignalId: String? = nil,
        outputTitle: String? = nil,
        insightClass: SQInsightClass,
        category: SQInsightCategory,
        recommendationFamily: SQInsightRecommendationFamily,
        bucketUnitName: String,
        minimumBucketSampleCount: Int = 3,
        minimumEffectMagnitude: Double = 0.75,
        recentWindowDayCount: Int = 1,
        baselineWindowDayCount: Int = 14,
        expectedEffect: SQInsightEffect,
        driverText: String,
        outcomeText: String,
        strongActionText: String
    ) -> SQInsightRelationshipDefinition {
        let resolvedOutputSignalId = outputSignalId ?? inputSignalId
        let resolvedOutputTitle = outputTitle ?? inputTitle

        return .init(
            familyKey: "current.\(inputSignalId)->\(resolvedOutputSignalId).\(insightClass.rawValue)",
            inputSignalId: inputSignalId,
            inputTitle: inputTitle,
            outputSignalId: resolvedOutputSignalId,
            outputTitle: resolvedOutputTitle,
            insightClass: insightClass,
            analyzerFamily: .currentStateAssessment,
            category: category,
            recommendationFamily: recommendationFamily,
            eligibleSurfaceIntents: [.today],
            variants: [
                .init(id: id, priority: 0, timing: .sameDay)
            ],
            lowBucketUpperBound: 0,
            highBucketLowerBound: 0,
            bucketUnitName: bucketUnitName,
            minimumBucketSampleCount: minimumBucketSampleCount,
            minimumEffectMagnitude: minimumEffectMagnitude,
            recentWindowDayCount: recentWindowDayCount,
            baselineWindowDayCount: baselineWindowDayCount,
            expectedEffect: expectedEffect,
            driverText: driverText,
            outcomeText: outcomeText,
            strongActionText: strongActionText,
            subtleActionText: "Use this as a current-state signal and see whether the rest of the day confirms it."
        )
    }
}
