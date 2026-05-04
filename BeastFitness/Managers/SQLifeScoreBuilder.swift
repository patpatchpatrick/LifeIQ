//
//  SQLifeScoreBuilder.swift
//  BeastFitness
//
//  Created by Codex on 4/24/26.
//

import Foundation
import BeastFitnessCore

struct SQLifeScoreBuildInput {
    let intelligenceInput: SQHealthIntelligenceInput
    let insightsResult: SQInsightsResult
}

struct SQLifeScoreV2Component: Identifiable, Hashable {
    let id: String
    let title: String
    let score: Int
    let weight: Double
    let contribution: Double
    let positiveDrivers: [String]
    let negativeDrivers: [String]
    let positiveCapHits: [String]
    let confidence: Double
    let evidence: [SQLifeScoreV2ComponentEvidence]
}

struct SQLifeScoreV2ComponentEvidence: Hashable {
    let title: String
    let valueText: String
    let summary: String
    let effect: SQLifeScoreSignalEffect
}

enum SQLifeScoreV2DriverKind: Hashable {
    case healthState
    case behavior
    case dataConfidence
    case personalized
}

struct SQLifeScoreV2Driver: Identifiable, Hashable {
    let id: String
    let title: String
    let signalId: String
    let componentId: String
    let kind: SQLifeScoreV2DriverKind
    let effect: SQLifeScoreSignalEffect
    let scoreImpact: Double
    let summary: String
}

struct SQLifeScoreV2Result: Hashable {
    let score: Int?
    let components: [SQLifeScoreV2Component]
    let topDrivers: [SQLifeScoreV2Driver]
    let calibrationWarnings: [String]
    let positiveContributionCapHits: [String]
}

@MainActor
protocol SQLifeScoreBuilding {
    func buildViewModel(input: SQLifeScoreBuildInput) -> SQLifeScoreViewModel
}

struct SQLifeScoreV2Builder {
    private let semanticResolver = SQMetricSemanticResolver()

    private struct RawComponent {
        let id: String
        let title: String
        let score: Double
        let weight: Double
        let positiveDrivers: [String]
        let negativeDrivers: [String]
        let positiveCapHits: [String]
        let confidence: Double
        let evidence: [SQLifeScoreV2ComponentEvidence]
    }

    private struct ScoredSignal {
        let signalId: String
        let title: String
        let score: Double
        let neutralScore: Double
        let confidence: Double
        let impactCap: Double
        var rawValueText: String? = nil
        var sourceText: String? = nil
        var sourceContextText: String? = nil

        var driverImpact: Double {
            SQLifeScoreV2Builder.clampStatic(score - neutralScore, min: -impactCap, max: impactCap)
        }
    }

    func build(
        input: SQHealthIntelligenceInput,
        currentScore: Int?
    ) -> SQLifeScoreV2Result {
        let snapshots = SQInsightFeatureBuilder().makeFeatureSnapshots(
            checkIns: input.checkIns,
            workouts: input.workouts,
            metricDefinitions: input.metricDefinitions,
            sleepData: input.sleepData,
            restingHeartRateSummaries: input.restingHeartRateSummaries
        )
        let snapshot = currentStateSnapshot(
            from: snapshots,
            input: input
        )
        let personalizedResult = SQLifeScoreMetricContributorBuilder().buildContributors(
            from: snapshot,
            metricDefinitions: input.metricDefinitions
        )

        let metricDefinitionsById = input.metricDefinitions.reduce(into: [String: SQMetricDefinition]()) { partialResult, definition in
            partialResult[definition.id] = definition
        }

        var rawComponents = [
            sleepComponent(
                snapshot: snapshot,
                referenceDate: input.referenceDate,
                metricDefinitionsById: metricDefinitionsById
            ),
            recoveryComponent(
                snapshot: snapshot,
                snapshots: snapshots,
                referenceDate: input.referenceDate,
                metricDefinitionsById: metricDefinitionsById
            ),
            mindEnergyComponent(
                snapshot: snapshot,
                referenceDate: input.referenceDate,
                metricDefinitionsById: metricDefinitionsById
            ),
            trainingComponent(
                snapshots: snapshots,
                referenceDate: input.referenceDate
            ),
            habitsComponent(
                snapshot: snapshot,
                snapshots: snapshots,
                referenceDate: input.referenceDate,
                metricDefinitionsById: metricDefinitionsById
            ),
            dataConfidenceComponent(
                snapshot: snapshot,
                input: input,
                snapshots: snapshots
            )
        ]
        .compactMap { $0 }

        if let personalizedComponent = personalizedMetricsComponent(
            from: personalizedResult
        ) {
            rawComponents.append(personalizedComponent)
        }

        let totalWeight = rawComponents.reduce(0) { $0 + $1.weight }
        guard totalWeight > 0 else {
            return .init(
                score: nil,
                components: [],
                topDrivers: [],
                calibrationWarnings: ["v2: no usable inputs"],
                positiveContributionCapHits: []
            )
        }

        let weightedScore = rawComponents.reduce(0) { partialResult, component in
            partialResult + component.score * component.weight
        } / totalWeight
        let lowComponentPenalty = v2LowComponentPenalty(rawComponents)
        let score = Int(clamp(weightedScore - lowComponentPenalty, min: 0, max: 100).rounded())
        let components = rawComponents.map { component in
            SQLifeScoreV2Component(
                id: component.id,
                title: component.title,
                score: Int(clamp(component.score, min: 0, max: 100).rounded()),
                weight: component.weight,
                contribution: component.score * component.weight / totalWeight,
                positiveDrivers: component.positiveDrivers,
                negativeDrivers: component.negativeDrivers,
                positiveCapHits: component.positiveCapHits,
                confidence: component.confidence,
                evidence: component.evidence
            )
        }
        .sorted { $0.weight > $1.weight }

        let drivers = v2Drivers(
            components: components,
            snapshot: snapshot,
            snapshots: snapshots,
            personalizedResult: personalizedResult
        )
        let warnings = calibrationWarnings(
            score: score,
            currentScore: currentScore,
            components: components,
            drivers: drivers
        )

        return .init(
            score: score,
            components: components,
            topDrivers: Array(drivers.prefix(8)),
            calibrationWarnings: warnings,
            positiveContributionCapHits: rawComponents.flatMap(\.positiveCapHits)
        )
    }

    private func sleepComponent(
        snapshot: SQInsightFeatureSnapshot?,
        referenceDate: Date,
        metricDefinitionsById: [String: SQMetricDefinition]
    ) -> RawComponent? {
        var signals = [ScoredSignal]()
        let snapshotContextText = sourceContextText(for: snapshot?.date, referenceDate: referenceDate)

        if let sleepHoursSignal = scoredMetricSignal(
            signalId: SQMetricId.sleepHours,
            title: "Sleep Duration",
            in: snapshot,
            metricDefinitionsById: metricDefinitionsById,
            neutralScore: 74,
            confidence: 0.9,
            impactCap: 22,
            sourceContextText: snapshotContextText,
            score: { sleepDurationScore(hours: $0) }
        ) {
            signals.append(sleepHoursSignal)
        }

        if let qualitySignal = scoredMetricSignal(
            signalId: SQMetricId.sleepQuality,
            title: "Sleep Quality",
            in: snapshot,
            metricDefinitionsById: metricDefinitionsById,
            neutralScore: 74,
            confidence: 0.9,
            impactCap: 26,
            sourceContextText: snapshotContextText,
            score: { clamp(($0 / 10) * 100, min: 0, max: 100) }
        ) {
            signals.append(qualitySignal)
        }

        return component(
            id: "sleep",
            title: "Sleep",
            signals: signals,
            weight: 25,
            fallbackScore: nil,
            positiveScoreCap: 93
        )
    }

    private func recoveryComponent(
        snapshot: SQInsightFeatureSnapshot?,
        snapshots: [SQInsightFeatureSnapshot],
        referenceDate: Date,
        metricDefinitionsById: [String: SQMetricDefinition]
    ) -> RawComponent? {
        var signals = [ScoredSignal]()
        let snapshotContextText = sourceContextText(for: snapshot?.date, referenceDate: referenceDate)

        if let recoverySignal = scoredMetricSignal(
            signalId: SQMetricId.soreness,
            title: "Soreness",
            in: snapshot,
            metricDefinitionsById: metricDefinitionsById,
            neutralScore: 74,
            confidence: 0.85,
            impactCap: 18,
            sourceContextText: snapshotContextText,
            score: sorenessReadinessScore
        ) {
            signals.append(recoverySignal)
        }

        if let restingHRScore = restingHeartRateRecoveryScore(
            snapshot: snapshot,
            snapshots: snapshots
        ) {
            signals.append(
                .init(
                    signalId: SQInsightAnalysisMetricId.restingHeartRate,
                    title: "Resting HR",
                    score: restingHRScore,
                    neutralScore: 76,
                    confidence: 0.75,
                    impactCap: 13,
                    rawValueText: snapshot
                        .flatMap { $0.rawSignalValue(for: SQInsightAnalysisMetricId.restingHeartRate) }
                        .map { signalValueText(signalId: SQInsightAnalysisMetricId.restingHeartRate, rawValue: $0) },
                    sourceText: sourceText(for: .healthKitDerived),
                    sourceContextText: snapshotContextText
                )
            )
        }

        if let sleepCarryover = scoredMetricSignal(
            signalId: SQMetricId.sleepQuality,
            title: "Sleep Carryover",
            in: snapshot,
            metricDefinitionsById: metricDefinitionsById,
            neutralScore: 74,
            confidence: 0.65,
            impactCap: 10,
            sourceContextText: snapshotContextText,
            score: { clamp(($0 / 10) * 100, min: 0, max: 100) }
        ) {
            signals.append(sleepCarryover)
        }

        return component(
            id: "recoveryReadiness",
            title: "Recovery / Readiness",
            signals: signals,
            weight: 20,
            fallbackScore: nil,
            positiveScoreCap: 90
        )
    }

    private func mindEnergyComponent(
        snapshot: SQInsightFeatureSnapshot?,
        referenceDate: Date,
        metricDefinitionsById: [String: SQMetricDefinition]
    ) -> RawComponent? {
        let signalSpecs: [(String, String, Double)] = [
            (SQMetricId.energy, "Energy", 20),
            (SQMetricId.mood, "Mood", 17),
            (SQMetricId.mentalClarity, "Mental Clarity", 17),
            (SQMetricId.motivation, "Motivation", 13),
            (SQMetricId.stress, "Stress", 22),
            (SQMetricId.anxiety, "Anxiety", 19)
        ]
        let snapshotContextText = sourceContextText(for: snapshot?.date, referenceDate: referenceDate)

        let signals = signalSpecs.compactMap { signalId, title, cap -> ScoredSignal? in
            guard let signal = scoredMetricSignal(
                signalId: signalId,
                title: title,
                in: snapshot,
                metricDefinitionsById: metricDefinitionsById,
                neutralScore: 72,
                confidence: 0.85,
                impactCap: cap,
                sourceContextText: snapshotContextText,
                score: { rawValue in
                    switch signalId {
                    case SQMetricId.stress, SQMetricId.anxiety:
                        return clamp(100 - (rawValue / 10 * 100), min: 0, max: 100)
                    default:
                        return clamp((rawValue / 10) * 100, min: 0, max: 100)
                    }
                }
            ) else {
                return nil
            }

            return signal
        }

        return component(
            id: "mindEnergy",
            title: "Mind / Energy",
            signals: signals,
            weight: 20,
            fallbackScore: nil,
            positiveScoreCap: 90
        )
    }

    private func trainingComponent(
        snapshots: [SQInsightFeatureSnapshot],
        referenceDate: Date
    ) -> RawComponent? {
        let signals = recentWorkoutSignals(
            snapshots: snapshots,
            referenceDate: referenceDate
        )
        let fallback = signals.isEmpty
            ? trainingFallbackScore(snapshots: snapshots, referenceDate: referenceDate)
            : nil
        return component(
            id: "trainingPerformance",
            title: "Training Load / Performance",
            signals: signals,
            weight: signals.isEmpty ? trainingFallbackWeight(fallback) : 15,
            fallbackScore: fallback,
            fallbackConfidence: signals.isEmpty ? 0.35 : 0.8,
            positiveScoreCap: 88
        )
    }

    private func recentWorkoutSignals(
        snapshots: [SQInsightFeatureSnapshot],
        referenceDate: Date
    ) -> [ScoredSignal] {
        let calendar = Calendar.current
        let referenceDay = calendar.startOfDay(for: referenceDate)

        let recentWorkoutSnapshots = snapshots.compactMap { candidate -> (snapshot: SQInsightFeatureSnapshot, age: Int, decay: Double)? in
            guard candidate.hasWorkout else { return nil }
            let candidateDay = calendar.startOfDay(for: candidate.date)
            let dayAge = calendar.dateComponents([.day], from: candidateDay, to: referenceDay).day ?? Int.max
            guard dayAge >= 0, dayAge <= 3 else { return nil }
            guard let decay = workoutCarryoverDecay(dayAge: dayAge) else { return nil }
            return (candidate, dayAge, decay)
        }

        let performanceSignals = recentWorkoutSnapshots.compactMap { candidate -> ScoredSignal? in
            guard let performance = candidate.snapshot.averageWorkoutPerformance else { return nil }
            let rawScore = workoutPerformanceScore(performance)
            let score = decayedScore(rawScore, neutralScore: 72, decay: candidate.decay)
            return .init(
                signalId: SQInsightAnalysisMetricId.workoutPerformance,
                title: candidate.age == 0 ? "Workout Performance" : "Recent Workout Performance",
                score: score,
                neutralScore: 72,
                confidence: 0.8 * max(0.45, candidate.decay),
                impactCap: 18,
                rawValueText: signalValueText(signalId: SQInsightAnalysisMetricId.workoutPerformance, rawValue: performance),
                sourceText: sourceText(for: .workoutDerived),
                sourceContextText: recordedAgeContextText(candidate.age)
            )
        }

        let loadSignals = recentWorkoutSnapshots.compactMap { candidate -> ScoredSignal? in
            guard let difficulty = candidate.snapshot.averageWorkoutDifficulty else { return nil }
            let rawScore = trainingLoadScore(difficulty)
            let score = decayedScore(rawScore, neutralScore: 72, decay: candidate.decay)
            return .init(
                signalId: SQInsightAnalysisMetricId.workoutDifficulty,
                title: candidate.age == 0 ? "Training Load" : "Recent Training Load",
                score: score,
                neutralScore: 72,
                confidence: 0.8 * max(0.45, candidate.decay),
                impactCap: 10,
                rawValueText: signalValueText(signalId: SQInsightAnalysisMetricId.workoutDifficulty, rawValue: difficulty),
                sourceText: sourceText(for: .workoutDerived),
                sourceContextText: recordedAgeContextText(candidate.age)
            )
        }

        let ratedSignals = strongestSignals(performanceSignals, limit: 1)
            + strongestSignals(loadSignals, limit: 1)
            + trainingStrainSignals(from: recentWorkoutSnapshots)
        guard ratedSignals.isEmpty else { return ratedSignals }

        let activitySignals = recentWorkoutSnapshots.map { candidate -> ScoredSignal in
            let rawScore = min(78, 76 + Double(max(0, candidate.snapshot.workoutCount - 1)))
            let score = decayedScore(rawScore, neutralScore: 72, decay: candidate.decay)
            let workoutLabel = candidate.snapshot.workoutCount == 1 ? "1 workout" : "\(candidate.snapshot.workoutCount) workouts"
            return .init(
                signalId: SQInsightAnalysisMetricId.workoutDifficulty,
                title: candidate.age == 0 ? "Workout Activity" : "Recent Workout Activity",
                score: score,
                neutralScore: 72,
                confidence: 0.55 * max(0.45, candidate.decay),
                impactCap: 6,
                rawValueText: workoutLabel,
                sourceText: sourceText(for: .workoutDerived),
                sourceContextText: recordedAgeContextText(candidate.age)
            )
        }

        return strongestSignals(activitySignals, limit: 1)
    }

    private func trainingFallbackScore(
        snapshots: [SQInsightFeatureSnapshot],
        referenceDate: Date
    ) -> Double {
        guard let latestWorkoutAge = latestWorkoutDayAge(
            snapshots: snapshots,
            referenceDate: referenceDate
        ) else {
            return 70
        }

        switch latestWorkoutAge {
        case 0...3:
            return 72
        case 4...5:
            return 70
        case 6...9:
            return 66
        default:
            return 62
        }
    }

    private func trainingFallbackWeight(_ fallbackScore: Double?) -> Double {
        guard let fallbackScore else { return 4 }
        return fallbackScore < 68 ? 8 : 5
    }

    private func latestWorkoutDayAge(
        snapshots: [SQInsightFeatureSnapshot],
        referenceDate: Date
    ) -> Int? {
        let calendar = Calendar.current
        let referenceDay = calendar.startOfDay(for: referenceDate)
        return snapshots
            .filter(\.hasWorkout)
            .compactMap { snapshot -> Int? in
                let snapshotDay = calendar.startOfDay(for: snapshot.date)
                let dayAge = calendar.dateComponents([.day], from: snapshotDay, to: referenceDay).day
                guard let dayAge, dayAge >= 0 else { return nil }
                return dayAge
            }
            .min()
    }

    private func workoutPerformanceScore(_ performance: Double) -> Double {
        clamp(70 + ((performance - 5) * 4.8), min: 62, max: 94)
    }

    private func trainingLoadScore(_ difficulty: Double) -> Double {
        clamp(75 + (min(difficulty, 8.5) * 0.9), min: 74, max: 83)
    }

    private func trainingStrainSignals(
        from recentWorkoutSnapshots: [(snapshot: SQInsightFeatureSnapshot, age: Int, decay: Double)]
    ) -> [ScoredSignal] {
        let highIntensityDays = recentWorkoutSnapshots
            .filter { $0.age <= 2 }
            .compactMap { candidate -> Double? in
                let intensity = max(
                    candidate.snapshot.averageWorkoutDifficulty ?? 0,
                    candidate.snapshot.averageWorkoutPerformance ?? 0
                )
                return intensity >= 9 ? intensity : nil
            }

        guard highIntensityDays.count >= 2 else { return [] }

        let averageIntensity = highIntensityDays.reduce(0, +) / Double(highIntensityDays.count)
        let score = clamp(
            72 - (Double(highIntensityDays.count - 1) * 7) - (max(0, averageIntensity - 9) * 4),
            min: 55,
            max: 66
        )

        return [
            .init(
                signalId: SQInsightAnalysisMetricId.workoutDifficulty,
                title: "Training Strain",
                score: score,
                neutralScore: 72,
                confidence: 0.78,
                impactCap: 14,
                rawValueText: "\(highIntensityDays.count) high-intensity workout days",
                sourceText: sourceText(for: .workoutDerived),
                sourceContextText: "Last 3 Days"
            )
        ]
    }

    private func workoutCarryoverDecay(dayAge: Int) -> Double? {
        switch dayAge {
        case 0:
            return 1.0
        case 1:
            return 0.65
        case 2:
            return 0.35
        case 3:
            return 0.15
        default:
            return nil
        }
    }

    private func decayedScore(
        _ score: Double,
        neutralScore: Double,
        decay: Double
    ) -> Double {
        neutralScore + ((score - neutralScore) * decay)
    }

    private func strongestSignals(
        _ signals: [ScoredSignal],
        limit: Int
    ) -> [ScoredSignal] {
        Array(
            signals
                .sorted { abs($0.driverImpact) > abs($1.driverImpact) }
                .prefix(limit)
        )
    }

    private func habitsComponent(
        snapshot: SQInsightFeatureSnapshot?,
        snapshots: [SQInsightFeatureSnapshot],
        referenceDate: Date,
        metricDefinitionsById: [String: SQMetricDefinition]
    ) -> RawComponent? {
        let habitMetricIds = [
            SQMetricId.alcohol,
            SQMetricId.caffeine,
            SQMetricId.weed,
            SQMetricId.nicotine
        ]
        guard habitMetricIds.contains(where: {
            allowsLifeScoreMetric($0, metricDefinitionsById: metricDefinitionsById)
        }) else {
            return nil
        }

        let signals = habitSignals(
            in: snapshot,
            metricDefinitionsById: metricDefinitionsById,
            sourceContextText: snapshot.map {
                recordedAgeContextText(
                    dayAge(
                        from: $0.date,
                        to: referenceDate
                    )
                )
            }
        )
        let fallbackEvidence = signals.isEmpty
            ? recentHabitEvidenceItems(
                snapshots: snapshots,
                referenceDate: referenceDate,
                metricDefinitionsById: metricDefinitionsById
            )
            : []

        return component(
            id: "habitsBehaviors",
            title: "Habits / Behaviors",
            signals: signals,
            weight: 10,
            fallbackScore: 74,
            positiveScoreCap: 78,
            fallbackEvidence: fallbackEvidence
        )
    }

    private func habitSignals(
        in snapshot: SQInsightFeatureSnapshot?,
        metricDefinitionsById: [String: SQMetricDefinition],
        sourceContextText: String? = nil
    ) -> [ScoredSignal] {
        [
            behaviorSignal(
                signalId: SQMetricId.alcohol,
                title: "Alcohol",
                rawValue: snapshot?.rawSignalValue(for: SQMetricId.alcohol),
                metricDefinitionsById: metricDefinitionsById,
                neutralThrough: 0.05,
                score: { clamp(76 - ($0 * 13), min: 25, max: 76) },
                cap: 24,
                sourceContextText: sourceContextText
            ),
            behaviorSignal(
                signalId: SQMetricId.caffeine,
                title: "Caffeine",
                rawValue: snapshot?.rawSignalValue(for: SQMetricId.caffeine),
                metricDefinitionsById: metricDefinitionsById,
                neutralThrough: 175,
                score: { value in
                    if value <= 175 { return 76 }
                    return clamp(76 - ((value - 175) / 5.2), min: 32, max: 76)
                },
                cap: 13,
                sourceContextText: sourceContextText
            ),
            behaviorSignal(
                signalId: SQMetricId.weed,
                title: "Weed",
                rawValue: snapshot?.rawSignalValue(for: SQMetricId.weed),
                metricDefinitionsById: metricDefinitionsById,
                neutralThrough: 0.05,
                score: { clamp(76 - ($0 * 11), min: 30, max: 76) },
                cap: 18,
                sourceContextText: sourceContextText
            ),
            behaviorSignal(
                signalId: SQMetricId.nicotine,
                title: "Nicotine",
                rawValue: snapshot?.rawSignalValue(for: SQMetricId.nicotine),
                metricDefinitionsById: metricDefinitionsById,
                neutralThrough: 0.05,
                score: { clamp(76 - ($0 * 11), min: 30, max: 76) },
                cap: 18,
                sourceContextText: sourceContextText
            )
        ]
        .compactMap { $0 }
    }

    private func recentHabitEvidenceItems(
        snapshots: [SQInsightFeatureSnapshot],
        referenceDate: Date,
        metricDefinitionsById: [String: SQMetricDefinition]
    ) -> [SQLifeScoreV2ComponentEvidence] {
        let candidates = snapshots.flatMap { snapshot -> [(signal: ScoredSignal, age: Int)] in
            let dayAge = dayAge(from: snapshot.date, to: referenceDate)
            guard dayAge >= 0, dayAge <= 7 else { return [] }
            return habitSignals(
                in: snapshot,
                metricDefinitionsById: metricDefinitionsById,
                sourceContextText: recordedAgeContextText(dayAge)
            )
            .map { ($0, dayAge) }
        }

        return candidates
            .sorted {
                if abs($0.signal.driverImpact) == abs($1.signal.driverImpact) {
                    return $0.age < $1.age
                }
                return abs($0.signal.driverImpact) > abs($1.signal.driverImpact)
            }
            .prefix(2)
            .enumerated()
            .map { index, candidate in
                let valueText: String
                if let rawValueText = candidate.signal.rawValueText {
                    valueText = evidenceValueText(
                        rawValueText: rawValueText,
                        sourceText: sourceText(for: .userLogged),
                        sourceContextText: recordedAgeContextText(candidate.age)
                    )
                } else {
                    valueText = "Recorded from \(sourceText(for: .userLogged)) (\(recordedAgeContextText(candidate.age)))"
                }

                return .init(
                    title: candidate.signal.title,
                    valueText: valueText,
                    summary: "",
                    effect: index == 0 && candidate.signal.driverImpact <= -5 ? .negative : .neutral
                )
            }
    }

    private func recordedAgeContextText(_ age: Int) -> String {
        switch age {
        case 0:
            return "Today"
        case 1:
            return "Yesterday"
        default:
            return "\(age) days ago"
        }
    }

    private func dayAge(from date: Date, to referenceDate: Date) -> Int {
        let calendar = Calendar.current
        let dateDay = calendar.startOfDay(for: date)
        let referenceDay = calendar.startOfDay(for: referenceDate)
        return calendar.dateComponents([.day], from: dateDay, to: referenceDay).day ?? Int.max
    }

    private func behaviorSignal(
        signalId: String,
        title: String,
        rawValue: Double?,
        metricDefinitionsById: [String: SQMetricDefinition],
        neutralThrough: Double,
        score: (Double) -> Double,
        cap: Double,
        sourceContextText: String? = nil
    ) -> ScoredSignal? {
        guard allowsLifeScoreMetric(signalId, metricDefinitionsById: metricDefinitionsById) else { return nil }
        guard let rawValue else { return nil }
        let resolvedScore = rawValue <= neutralThrough ? 76 : score(rawValue)
        return .init(
            signalId: signalId,
            title: title,
            score: resolvedScore,
            neutralScore: 74,
            confidence: 0.8,
            impactCap: cap,
            rawValueText: signalValueText(signalId: signalId, rawValue: rawValue),
            sourceText: sourceText(for: .userLogged),
            sourceContextText: sourceContextText
        )
    }

    private func dataConfidenceComponent(
        snapshot: SQInsightFeatureSnapshot?,
        input: SQHealthIntelligenceInput,
        snapshots: [SQInsightFeatureSnapshot]
    ) -> RawComponent? {
        let calendar = Calendar.current
        let referenceDay = calendar.startOfDay(for: input.referenceDate)
        let sevenDayStart = calendar.date(byAdding: .day, value: -6, to: referenceDay) ?? referenceDay
        let recentCheckInDays = Set(
            input.checkIns.compactMap { checkIn -> String? in
                let day = calendar.startOfDay(for: checkIn.date)
                guard day >= sevenDayStart && day <= referenceDay else { return nil }
                return day.firebaseDailyDateKey
            }
        ).count
        let currentSignalCount = snapshot?.rawSignalValues.count ?? 0
        let activeSnapshotCount = snapshots.suffix(14).filter {
            !$0.rawSignalValues.isEmpty || $0.hasWorkout
        }.count
        let checkInScore = clamp((Double(recentCheckInDays) / 5.0) * 100, min: 0, max: 100)
        let currentScore = clamp((Double(currentSignalCount) / 8.0) * 100, min: 0, max: 100)
        let historyScore = clamp((Double(activeSnapshotCount) / 10.0) * 100, min: 0, max: 100)
        let promptPenalty = input.hasCompletedCurrentPromptCheckIn ? 0.0 : 10.0
        let rawScore = (checkInScore * 0.44) + (currentScore * 0.30) + (historyScore * 0.26) - promptPenalty
        let score = clamp(rawScore, min: 25, max: 74)
        let isLowConfidence = score < 64

        return .init(
            id: "dataConfidence",
            title: "Data Confidence / Consistency",
            score: score,
            weight: isLowConfidence ? 6 : 1,
            positiveDrivers: [],
            negativeDrivers: isLowConfidence ? ["Missing or inconsistent logs"] : [],
            positiveCapHits: [],
            confidence: min(1, max(0.2, rawScore / 100)),
            evidence: [
                .init(
                    title: "Recent Logging",
                    valueText: "\(recentCheckInDays) check-in day\(recentCheckInDays == 1 ? "" : "s") from Daily Check-In (Last 7 Days)",
                    summary: "",
                    effect: isLowConfidence ? .negative : .neutral
                )
            ]
        )
    }

    private func personalizedMetricsComponent(
        from contributionResult: SQLifeScoreMetricContributionResult
    ) -> RawComponent? {
        let customContributors = contributionResult.incrementalContributors.filter(\.isCustom)
        guard !customContributors.isEmpty else { return nil }

        let customTotal = clamp(
            customContributors.reduce(0) { $0 + $1.contributionPoints },
            min: -5,
            max: 5
        )
        let score = clamp(78 + (customTotal * 4.5), min: 50, max: 96)

        return .init(
            id: "personalizedMetrics",
            title: "Personalized Metrics",
            score: score,
            weight: 5,
            positiveDrivers: customContributors
                .filter { $0.contributionPoints > 0.05 }
                .prefix(3)
                .map { cleanedMetricTitle($0.title) },
            negativeDrivers: customContributors
                .filter { $0.contributionPoints < -0.05 }
                .prefix(3)
                .map { cleanedMetricTitle($0.title) },
            positiveCapHits: abs(customTotal) >= 4.9 ? ["Personalized Metrics"] : [],
            confidence: 0.65,
            evidence: customContributors.prefix(3).map { contributor in
                let rawValueText = contributor.utilityScore.map { "\(Int($0.rounded()))/100 utility" }
                    ?? "Personalized signal"

                return .init(
                    title: cleanedMetricTitle(contributor.title),
                    valueText: evidenceValueText(
                        rawValueText: rawValueText,
                        sourceText: sourceText(for: contributor.source),
                        sourceContextText: "Today"
                    ),
                    summary: "",
                    effect: contributor.effect
                )
            }
        )
    }

    private func component(
        id: String,
        title: String,
        signals: [ScoredSignal],
        weight: Double,
        fallbackScore: Double?,
        fallbackConfidence: Double = 0.3,
        positiveScoreCap: Double,
        fallbackEvidence: [SQLifeScoreV2ComponentEvidence] = []
    ) -> RawComponent? {
        if signals.isEmpty {
            guard let fallbackScore else { return nil }
            let cappedScore = min(fallbackScore, positiveScoreCap)
            let negativeDrivers = fallbackScore < neutralScore(for: id) - 0.5
                ? ["No recent \(title.lowercased()) signal"]
                : []
            return .init(
                id: id,
                title: title,
                score: cappedScore,
                weight: weight,
                positiveDrivers: [],
                negativeDrivers: negativeDrivers,
                positiveCapHits: fallbackScore > positiveScoreCap ? [title] : [],
                confidence: fallbackConfidence,
                evidence: fallbackEvidence
            )
        }

        let weightedSignals = signals.map { signal -> (signal: ScoredSignal, weight: Double) in
            let positiveImpact = max(0, signal.driverImpact) * 0.60
            let negativeImpact = abs(min(0, signal.driverImpact)) * 1.25
            let weight = signal.confidence * max(4, positiveImpact + negativeImpact)
            return (signal, weight)
        }
        let totalWeight = weightedSignals.reduce(0) { $0 + $1.weight }
        let uncappedScore = totalWeight > 0
            ? weightedSignals.reduce(0) { $0 + ($1.signal.score * $1.weight) } / totalWeight
            : signals.map(\.score).reduce(0, +) / Double(signals.count)
        let score = min(uncappedScore, positiveScoreCap)
        let positives = signals
            .filter { $0.driverImpact >= 7 && $0.score > 74 }
            .sorted { $0.driverImpact > $1.driverImpact }
            .prefix(3)
            .map(\.title)
        let negatives = signals
            .filter { $0.driverImpact <= -5 }
            .sorted { $0.driverImpact < $1.driverImpact }
            .prefix(3)
            .map(\.title)
        let confidence = clamp(
            signals.map(\.confidence).reduce(0, +) / Double(signals.count),
            min: 0,
            max: 1
        )

        return .init(
            id: id,
            title: title,
            score: score,
            weight: weight * confidenceMultiplier(confidence),
            positiveDrivers: Array(positives),
            negativeDrivers: Array(negatives),
            positiveCapHits: uncappedScore > positiveScoreCap ? [title] : [],
            confidence: confidence,
            evidence: evidenceItems(
                for: signals,
                componentTitle: title
            )
        )
    }

    private func v2Drivers(
        components: [SQLifeScoreV2Component],
        snapshot: SQInsightFeatureSnapshot?,
        snapshots: [SQInsightFeatureSnapshot],
        personalizedResult: SQLifeScoreMetricContributionResult
    ) -> [SQLifeScoreV2Driver] {
        var drivers = [SQLifeScoreV2Driver]()

        for component in components {
            for title in component.negativeDrivers {
                let scoreImpact = Double(component.score) - neutralScore(for: component.id)
                guard abs(scoreImpact) >= 0.5 else { continue }
                drivers.append(
                    .init(
                        id: "v2.\(component.id).negative.\(title)",
                        title: title,
                        signalId: signalId(forDriverTitle: title),
                        componentId: component.id,
                        kind: driverKind(componentId: component.id, signalId: signalId(forDriverTitle: title)),
                        effect: .negative,
                        scoreImpact: scoreImpact,
                        summary: v2DriverSummary(
                            title: title,
                            component: component,
                            effect: .negative
                        )
                    )
                )
            }

            guard component.id != "dataConfidence" else { continue }
            for title in component.positiveDrivers {
                let scoreImpact = (Double(component.score) - neutralScore(for: component.id)) * 0.6
                guard abs(scoreImpact) >= 0.5 else { continue }
                drivers.append(
                    .init(
                        id: "v2.\(component.id).positive.\(title)",
                        title: title,
                        signalId: signalId(forDriverTitle: title),
                        componentId: component.id,
                        kind: driverKind(componentId: component.id, signalId: signalId(forDriverTitle: title)),
                        effect: .positive,
                        scoreImpact: scoreImpact,
                        summary: v2DriverSummary(
                            title: title,
                            component: component,
                            effect: .positive
                        )
                    )
                )
            }
        }

        let lowDataComponent = components.first { $0.id == "dataConfidence" }
        if let lowDataComponent, lowDataComponent.score < 65 {
            let scoreImpact = Double(lowDataComponent.score) - neutralScore(for: "dataConfidence")
            if abs(scoreImpact) >= 0.5 {
                drivers.append(
                    .init(
                        id: "v2.dataConfidence.lowData",
                        title: "Low Data Confidence",
                        signalId: "insight.dataConfidence",
                        componentId: "dataConfidence",
                        kind: .dataConfidence,
                        effect: .negative,
                        scoreImpact: scoreImpact,
                        summary: "Missing or inconsistent logs are lowering confidence in the score."
                    )
                )
            }
        }

        if abs(personalizedResult.customMetricContributionTotal) >= 0.5,
           let contributor = personalizedResult.incrementalContributors
            .filter(\.isCustom)
            .sorted(by: { abs($0.contributionPoints) > abs($1.contributionPoints) })
            .first {
            drivers.append(
                .init(
                    id: "v2.personalized.\(contributor.metricId)",
                    title: cleanedMetricTitle(contributor.title),
                    signalId: contributor.metricId,
                    componentId: "personalizedMetrics",
                    kind: .personalized,
                    effect: contributor.contributionPoints >= 0 ? .positive : .negative,
                    scoreImpact: contributor.contributionPoints,
                    summary: "\(cleanedMetricTitle(contributor.title)) is a personalized signal."
                )
            )
        }

        return drivers.sorted {
            if abs($0.scoreImpact) != abs($1.scoreImpact) {
                return abs($0.scoreImpact) > abs($1.scoreImpact)
            }

            return $0.title < $1.title
        }
    }

    private func v2DriverSummary(
        title: String,
        component: SQLifeScoreV2Component,
        effect: SQLifeScoreSignalEffect
    ) -> String {
        if component.id == "trainingPerformance" {
            switch (title, effect) {
            case ("Training Load", .positive), ("Recent Training Load", .positive):
                return "Training load is trending in a positive direction."
            case ("Training Load", .negative), ("Recent Training Load", .negative):
                return "Training load may be harder to absorb right now."
            case ("Training Strain", .positive):
                return "Recent training strain looks manageable."
            case ("Training Strain", .negative):
                return "Recent training strain may be catching up with you."
            case ("Workout Performance", .positive), ("Recent Workout Performance", .positive):
                return "Recent training sessions look strong."
            case ("Workout Performance", .negative), ("Recent Workout Performance", .negative):
                return "Recent training performance is below your usual baseline."
            case ("Workout Activity", .positive), ("Recent Workout Activity", .positive):
                return "Recent workout activity is adding healthy momentum."
            case ("Workout Activity", .negative), ("Recent Workout Activity", .negative):
                return "Recent workout activity is lighter than usual."
            default:
                break
            }
        }

        switch effect {
        case .positive:
            return "\(title) is supporting \(component.title)."
        case .negative:
            return "\(title) is pulling down \(component.title)."
        case .neutral:
            return "\(title) is steady for \(component.title)."
        }
    }

    private func calibrationWarnings(
        score: Int,
        currentScore: Int?,
        components: [SQLifeScoreV2Component],
        drivers: [SQLifeScoreV2Driver]
    ) -> [String] {
        var warnings = [String]()

        if let currentScore, abs(score - currentScore) > 10 {
            warnings.append("latest-day shadow v2 delta >10 from current score")
        }

        if components.first(where: { $0.id == "dataConfidence" })?.score ?? 100 < 55 {
            warnings.append("latest-day low data confidence")
        }

        let topHealthDriver = drivers.first {
            $0.kind == .healthState
        }

        if topHealthDriver?.signalId == SQInsightAnalysisMetricId.restingHeartRate {
            warnings.append("latest-day resting HR is top v2 health driver")
        }

        return warnings.isEmpty ? ["None"] : warnings
    }

    private func v2LowComponentPenalty(_ components: [RawComponent]) -> Double {
        components.reduce(0) { partialResult, component in
            switch component.id {
            case "dataConfidence":
                return partialResult + max(0, 60 - component.score) * 0.12
            case "habitsBehaviors":
                return partialResult + max(0, 62 - component.score) * 0.07
            case "sleep", "recoveryReadiness", "mindEnergy":
                return partialResult + max(0, 66 - component.score) * 0.06
            case "trainingPerformance":
                return partialResult + max(0, 60 - component.score) * 0.04
            default:
                return partialResult
            }
        }
    }

    private func latestSnapshot(
        from snapshots: [SQInsightFeatureSnapshot],
        referenceDate: Date
    ) -> SQInsightFeatureSnapshot? {
        let calendar = Calendar.current
        let referenceDay = calendar.startOfDay(for: referenceDate)
        return snapshots
            .filter { $0.date <= referenceDate || calendar.isDate($0.date, inSameDayAs: referenceDay) }
            .max { $0.date < $1.date }
    }

    private func currentStateSnapshot(
        from snapshots: [SQInsightFeatureSnapshot],
        input: SQHealthIntelligenceInput
    ) -> SQInsightFeatureSnapshot? {
        let latest = latestSnapshot(
            from: snapshots,
            referenceDate: input.referenceDate
        )

        guard input.timeRange == .today,
              input.currentCheckInPromptPeriod != nil,
              !input.hasCompletedCurrentPromptCheckIn else {
            return latest
        }

        let calendar = Calendar.current
        let referenceDay = calendar.startOfDay(for: input.referenceDate)
        if let latest, calendar.isDate(latest.date, inSameDayAs: referenceDay) {
            return latest
        }

        return snapshots
            .filter { calendar.isDate($0.date, inSameDayAs: referenceDay) }
            .max { $0.date < $1.date }
    }

    private func utilityScore(
        for signalId: String,
        in snapshot: SQInsightFeatureSnapshot?,
        fallback: (Double) -> Double
    ) -> Double? {
        guard let feature = snapshot?.signalFeatures[signalId] else { return nil }
        return feature.goalUtilityScore ?? fallback(feature.rawValue)
    }

    private func scoredMetricSignal(
        signalId: String,
        title: String,
        in snapshot: SQInsightFeatureSnapshot?,
        metricDefinitionsById: [String: SQMetricDefinition],
        neutralScore: Double,
        confidence: Double,
        impactCap: Double,
        sourceContextText: String?,
        score: (Double) -> Double
    ) -> ScoredSignal? {
        guard allowsLifeScoreMetric(signalId, metricDefinitionsById: metricDefinitionsById) else { return nil }
        guard let feature = snapshot?.signalFeatures[signalId] else { return nil }

        return .init(
            signalId: signalId,
            title: title,
            score: feature.goalUtilityScore ?? score(feature.rawValue),
            neutralScore: neutralScore,
            confidence: confidence,
            impactCap: impactCap,
            rawValueText: signalValueText(signalId: signalId, rawValue: feature.rawValue),
            sourceText: sourceText(for: feature.source),
            sourceContextText: sourceContextText
        )
    }

    private func restingHeartRateRecoveryScore(
        snapshot: SQInsightFeatureSnapshot?,
        snapshots: [SQInsightFeatureSnapshot]
    ) -> Double? {
        guard let latest = snapshot?.rawSignalValue(for: SQInsightAnalysisMetricId.restingHeartRate) else {
            return nil
        }

        let history = snapshots
            .dropLast()
            .suffix(21)
            .compactMap { $0.rawSignalValue(for: SQInsightAnalysisMetricId.restingHeartRate) }
        let baseline = history.isEmpty
            ? 60
            : history.reduce(0, +) / Double(history.count)
        let delta = latest - baseline
        let score = delta >= 0
            ? 82 - (delta * 4.5)
            : 82 + abs(delta * 2.0)

        return clamp(score, min: 35, max: 96)
    }

    private func sleepDurationScore(hours: Double) -> Double {
        switch hours {
        case 7.25...8.6:
            return 94
        case 6.75..<7.25:
            return 84
        case 8.6...9.2:
            return 84
        case 6.0..<6.75:
            return 68
        case 9.2...:
            return 66
        case 5.0..<6.0:
            return 48
        default:
            return 36
        }
    }

    private func sorenessReadinessScore(_ value: Double) -> Double {
        clamp(92 - (value * 6), min: 30, max: 96)
    }

    private func evidenceItems(
        for signals: [ScoredSignal],
        componentTitle: String
    ) -> [SQLifeScoreV2ComponentEvidence] {
        signals
            .sorted { abs($0.driverImpact) > abs($1.driverImpact) }
            .prefix(4)
            .map { signal in
                let signalScore = Int(clamp(signal.score, min: 0, max: 100).rounded())
                let effect: SQLifeScoreSignalEffect
                if signal.driverImpact >= 5 {
                    effect = .positive
                } else if signal.driverImpact <= -5 {
                    effect = .negative
                } else {
                    effect = .neutral
                }

                let valueText: String
                if let rawValueText = signal.rawValueText, let sourceText = signal.sourceText {
                    valueText = evidenceValueText(
                        rawValueText: rawValueText,
                        sourceText: sourceText,
                        sourceContextText: signal.sourceContextText
                    )
                } else if let rawValueText = signal.rawValueText {
                    valueText = rawValueText
                } else {
                    valueText = "\(signalScore)/100 signal score"
                }

                return .init(
                    title: signal.title,
                    valueText: valueText,
                    summary: "",
                    effect: effect
                )
            }
    }

    private func evidenceValueText(
        rawValueText: String,
        sourceText: String,
        sourceContextText: String?
    ) -> String {
        if let sourceContextText, !sourceContextText.isEmpty {
            return "\(rawValueText) from \(sourceText) (\(sourceContextText))"
        }

        return "\(rawValueText) from \(sourceText)"
    }

    private func cleanedMetricTitle(_ title: String) -> String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func signalValueText(signalId: String, rawValue: Double) -> String {
        switch signalId {
        case SQMetricId.sleepHours:
            return "\(formattedDecimal(rawValue)) hr"
        case SQInsightAnalysisMetricId.restingHeartRate:
            return "\(Int(rawValue.rounded())) bpm"
        case SQMetricId.caffeine:
            return "\(Int(rawValue.rounded())) mg"
        case SQMetricId.alcohol:
            let rounded = formattedDecimal(rawValue)
            return "\(rounded) drink\(abs(rawValue - 1) < 0.05 ? "" : "s")"
        case SQMetricId.sleepQuality,
             SQMetricId.soreness,
             SQMetricId.energy,
             SQMetricId.mood,
             SQMetricId.mentalClarity,
             SQMetricId.motivation,
             SQMetricId.stress,
             SQMetricId.anxiety,
             SQInsightAnalysisMetricId.workoutPerformance,
             SQInsightAnalysisMetricId.workoutDifficulty:
            return "\(formattedDecimal(rawValue))/10"
        default:
            return formattedDecimal(rawValue)
        }
    }

    private func sourceText(for source: SQInsightSignalSource) -> String {
        switch source {
        case .userLogged:
            return "Daily Check-In"
        case .healthKitFallback:
            return "HealthKit"
        case .healthKitDerived:
            return "HealthKit"
        case .workoutDerived:
            return "Workout Log"
        }
    }

    private func sourceContextText(for date: Date?, referenceDate: Date) -> String? {
        guard let date else { return nil }
        return recordedAgeContextText(dayAge(from: date, to: referenceDate))
    }

    private func allowsLifeScoreMetric(
        _ metricId: String,
        metricDefinitionsById: [String: SQMetricDefinition]
    ) -> Bool {
        guard let definition = metricDefinitionsById[metricId] else { return true }
        return semanticResolver.lifeScoreImpact(for: definition) != .none
    }

    private func formattedDecimal(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }

        return String(format: "%.1f", value)
    }

    private func neutralScore(for componentId: String) -> Double {
        switch componentId {
        case "dataConfidence":
            return 72
        case "habitsBehaviors":
            return 74
        case "trainingPerformance":
            return 72
        default:
            return 74
        }
    }

    private func driverKind(
        componentId: String,
        signalId: String
    ) -> SQLifeScoreV2DriverKind {
        switch componentId {
        case "dataConfidence":
            return .dataConfidence
        case "personalizedMetrics":
            return .personalized
        case "habitsBehaviors":
            return .behavior
        default:
            if [SQMetricId.alcohol, SQMetricId.caffeine, SQMetricId.weed, SQMetricId.nicotine, SQMetricId.porn].contains(signalId) {
                return .behavior
            }
            return .healthState
        }
    }

    private func signalId(forDriverTitle title: String) -> String {
        switch title {
        case "Sleep Duration":
            return SQMetricId.sleepHours
        case "Sleep Quality", "Sleep Carryover":
            return SQMetricId.sleepQuality
        case "Recovery", "Soreness":
            return SQMetricId.soreness
        case "Resting HR":
            return SQInsightAnalysisMetricId.restingHeartRate
        case "Energy":
            return SQMetricId.energy
        case "Mood":
            return SQMetricId.mood
        case "Mental Clarity":
            return SQMetricId.mentalClarity
        case "Motivation":
            return SQMetricId.motivation
        case "Stress":
            return SQMetricId.stress
        case "Anxiety":
            return SQMetricId.anxiety
        case "Workout Performance", "Recent Workout Performance":
            return SQInsightAnalysisMetricId.workoutPerformance
        case "Workout Difficulty", "Training Load", "Recent Training Load", "Training Strain", "Workout Activity", "Recent Workout Activity":
            return SQInsightAnalysisMetricId.workoutDifficulty
        case "Alcohol":
            return SQMetricId.alcohol
        case "Caffeine":
            return SQMetricId.caffeine
        case "Weed":
            return SQMetricId.weed
        case "Nicotine":
            return SQMetricId.nicotine
        case "Missing or inconsistent logs", "Recent logging":
            return "insight.dataConfidence"
        default:
            return title
        }
    }

    private func confidenceMultiplier(_ confidence: Double) -> Double {
        clamp(0.65 + (confidence * 0.35), min: 0.65, max: 1)
    }

    private func clamp(_ value: Double, min minimum: Double, max maximum: Double) -> Double {
        Self.clampStatic(value, min: minimum, max: maximum)
    }

    private static func clampStatic(_ value: Double, min minimum: Double, max maximum: Double) -> Double {
        Swift.max(minimum, Swift.min(maximum, value))
    }
}

@MainActor
struct SQLifeScoreBuilder: SQLifeScoreBuilding {
    private let v2Builder: SQLifeScoreV2Builder
    private let sleepAggregationService: SQSleepAggregationService

    init(
        sleepAggregationService: SQSleepAggregationService
    ) {
        self.v2Builder = SQLifeScoreV2Builder()
        self.sleepAggregationService = sleepAggregationService
    }

    func buildViewModel(input: SQLifeScoreBuildInput) -> SQLifeScoreViewModel {
        let calendar = Calendar.current
        let intelligenceInput = input.intelligenceInput
        let primaryInsight = intelligenceInput.timeRange == .today ? input.insightsResult.insights.first : nil
        let startOfReferenceDay = calendar.startOfDay(for: intelligenceInput.referenceDate)
        let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfReferenceDay) ?? startOfReferenceDay
        let v2Result = v2Builder.build(
            input: intelligenceInput,
            currentScore: nil
        )
        let previousV2Result = v2Builder.build(
            input: intelligenceInput.withReferenceDate(startOfYesterday),
            currentScore: nil
        )
        let previousV2ComponentsById = Dictionary(uniqueKeysWithValues: previousV2Result.components.map { ($0.id, $0) })
        let components = v2Result.components.map { component in
            lifeScoreComponent(
                from: component,
                previousComponent: previousV2ComponentsById[component.id]
            )
        }
        let previousComponents = previousV2Result.components.map { lifeScoreComponent(from: $0) }
        let lifeScoreDrivers = v2Result.topDrivers.map(lifeScoreDriver)
        let totalWeight = components.reduce(0) { $0 + $1.weight }
        let scoreDeltaFromPreviousDay: Int? = {
            guard let currentScore = v2Result.score,
                  let previousScore = previousV2Result.score else { return nil }
            return currentScore - previousScore
        }()
        let state = lifeScoreState(
            score: v2Result.score,
            availableWeight: totalWeight,
            scoreDeltaFromPreviousDay: scoreDeltaFromPreviousDay,
            components: components,
            drivers: lifeScoreDrivers,
            primaryInsight: primaryInsight
        )
        let roundedScore = state == .calibrating ? nil : v2Result.score
        let alignedActions = lifeScoreAlignedActions(
            input.insightsResult.actions,
            state: state,
            score: roundedScore,
            scoreDeltaFromPreviousDay: scoreDeltaFromPreviousDay,
            components: components
        )
        let headlineText = lifeScoreHeroSummaryText(
            state: state,
            components: components,
            previousComponents: previousComponents,
            totalWeight: totalWeight,
            drivers: lifeScoreDrivers,
            changes: input.insightsResult.changes,
            referenceDate: intelligenceInput.referenceDate
        )
        let heroAction = lifeScoreHeroAction(
            fallbackActions: alignedActions,
            state: state,
            components: components,
            drivers: lifeScoreDrivers,
            changes: input.insightsResult.changes,
            referenceDate: intelligenceInput.referenceDate
        )
        let refinementPromptText = lifeScoreRefinementPromptText(for: intelligenceInput)

        let subtitle: String
        if components.isEmpty {
            subtitle = "LifeIQ is still calibrating. Add Health data or check in a few times so the score has something real to work from."
        } else if !intelligenceInput.isLoggedIn {
            subtitle = "Early preview based on the signals available in guest mode."
        } else if totalWeight < 60 {
            subtitle = "LifeIQ is still calibrating because some of your usual signals are missing today."
        } else {
            subtitle = "A read on how your sleep, recovery, mind, habits, and training are lining up right now."
        }

        let visibleDrivers = topLifeScoreDrivers(lifeScoreDrivers)
        let visibleChanges = topLifeScoreChanges(
            input: intelligenceInput,
            fallbackChanges: input.insightsResult.changes
        )
        let displayComponents = lifeScoreDisplayComponents(
            components.sorted { $0.weight > $1.weight }
        )

        return .init(
            score: roundedScore,
            scoreDeltaFromPreviousDay: scoreDeltaFromPreviousDay,
            state: state,
            subtitle: subtitle,
            refinementPromptText: refinementPromptText,
            components: displayComponents,
            headlineText: headlineText,
            primaryInsight: primaryInsight,
            driverTimeframeText: lifeScoreDriverTimeframeText(for: visibleDrivers),
            drivers: visibleDrivers,
            changes: visibleChanges,
            actions: heroAction.map { [$0] } ?? alignedActions,
            availableWeight: totalWeight
        )
    }

    private func lifeScoreComponent(
        from component: SQLifeScoreV2Component,
        previousComponent: SQLifeScoreV2Component? = nil
    ) -> SQLifeScoreComponent {
        .init(
            id: component.id,
            title: component.title,
            score: component.score,
            scoreDeltaFromPreviousDay: previousComponent.map { component.score - $0.score },
            summary: lifeScoreComponentSummary(from: component),
            weight: component.weight,
            detailItems: lifeScoreComponentDetailItems(from: component)
        )
    }

    private func lifeScoreDisplayComponents(_ components: [SQLifeScoreComponent]) -> [SQLifeScoreComponent] {
        guard !components.contains(where: { $0.id == "personalizedMetrics" }) else {
            return components
        }

        let personalizedPlaceholder = SQLifeScoreComponent(
            id: "personalizedMetrics",
            title: "Personalized Metrics",
            score: 78,
            summary: "No personal metrics are affecting today's score.",
            weight: 0,
            detailItems: [
                .init(
                    id: "personalizedMetrics-none",
                    title: "No Score Impact",
                    valueText: "No eligible custom metric was logged for today's score.",
                    summary: "Custom metrics can still appear in insights when useful.",
                    effect: .neutral
                )
            ]
        )

        return components + [personalizedPlaceholder]
    }

    private func lifeScoreComponentSummary(from component: SQLifeScoreV2Component) -> String {
        let negativeDrivers = sanitizedDriverTitles(component.negativeDrivers)
        if !negativeDrivers.isEmpty {
            if component.id == "trainingPerformance" {
                return trainingComponentSummary(driverTitles: negativeDrivers, effect: .negative)
            }
            return "\(negativeDrivers.joined(separator: ", ")) \(negativeDrivers.count == 1 ? "is" : "are") weighing on \(component.title.lowercased())."
        }

        let positiveDrivers = sanitizedDriverTitles(component.positiveDrivers)
        if !positiveDrivers.isEmpty {
            if component.id == "trainingPerformance" {
                return trainingComponentSummary(driverTitles: positiveDrivers, effect: .positive)
            }
            return "\(positiveDrivers.joined(separator: ", ")) \(positiveDrivers.count == 1 ? "is" : "are") supporting \(component.title.lowercased())."
        }

        switch component.score {
        case 86...:
            return "\(component.title) is strongly supportive today."
        case 72...85:
            return "\(component.title) looks steady today."
        case 58...71:
            return "\(component.title) is a mild drag today."
        default:
            return "\(component.title) is a meaningful drag today."
        }
    }

    private func trainingComponentSummary(
        driverTitles: [String],
        effect: SQLifeScoreSignalEffect
    ) -> String {
        let hasLoad = driverTitles.contains { ["Training Load", "Recent Training Load", "Training Strain"].contains($0) }
        let hasPerformance = driverTitles.contains { ["Workout Performance", "Recent Workout Performance"].contains($0) }
        let hasActivity = driverTitles.contains { ["Workout Activity", "Recent Workout Activity"].contains($0) }

        switch effect {
        case .positive:
            if hasPerformance && hasLoad {
                return "Recent sessions look strong and the training load looks manageable."
            }
            if hasPerformance {
                return "Recent training sessions look strong."
            }
            if hasLoad {
                return "Training load is trending in a positive direction."
            }
            if hasActivity {
                return "Recent workout activity is adding healthy momentum."
            }
            return "Training is giving the day some momentum."
        case .negative:
            if hasPerformance && hasLoad {
                return "Recent sessions are lower than usual and training load may be harder to absorb."
            }
            if hasPerformance {
                return "Recent training performance is below your usual baseline."
            }
            if hasLoad {
                return "Training load may be harder to absorb right now."
            }
            if hasActivity {
                return "Recent workout activity is lighter than usual."
            }
            return "Training is weighing on the day."
        case .neutral:
            return "Training looks steady today."
        }
    }

    private func sanitizedDriverTitles(_ titles: [String]) -> [String] {
        titles
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func lifeScoreDriverTimeframeText(for drivers: [SQInsightDriver]) -> String? {
        guard !drivers.isEmpty else { return nil }

        let categories = Set(drivers.map(\.category))
        if drivers.contains(where: { $0.signalId == "insight.dataConfidence" }) {
            return "Today + last 7 days"
        }

        if categories.contains(.training) {
            return "Today + last 3 days"
        }

        return "Today"
    }

    private func topLifeScoreDrivers(_ drivers: [SQInsightDriver]) -> [SQInsightDriver] {
        Array(
            drivers
                .filter { $0.effectMagnitude >= 0.5 }
                .sorted(by: lifeScoreDriverImpactRanked)
                .prefix(3)
        )
    }

    private func topLifeScoreChanges(_ changes: [SQInsightChange]) -> [SQInsightChange] {
        Array(
            changes
                .sorted(by: lifeScoreChangeImpactRanked)
                .prefix(3)
        )
    }

    private func topLifeScoreChanges(
        input: SQHealthIntelligenceInput,
        fallbackChanges: [SQInsightChange]
    ) -> [SQInsightChange] {
        let snapshots = SQInsightFeatureBuilder().makeFeatureSnapshots(
            checkIns: input.checkIns,
            workouts: input.workouts,
            metricDefinitions: input.metricDefinitions,
            sleepData: input.sleepData,
            restingHeartRateSummaries: input.restingHeartRateSummaries
        )
        let rawChanges = SQInsightChangeBuilder().buildChanges(
            from: snapshots,
            surfaceIntent: input.timeRange.insightSurfaceIntent,
            referenceDate: input.referenceDate
        )

        return topLifeScoreChanges(rawChanges.isEmpty ? fallbackChanges : rawChanges)
    }

    private func lifeScoreDriverImpactRanked(_ lhs: SQInsightDriver, _ rhs: SQInsightDriver) -> Bool {
        if lhs.effectMagnitude != rhs.effectMagnitude {
            return lhs.effectMagnitude > rhs.effectMagnitude
        }

        if lhs.rankingScore != rhs.rankingScore {
            return lhs.rankingScore > rhs.rankingScore
        }

        return lhs.title < rhs.title
    }

    private func lifeScoreChangeImpactRanked(_ lhs: SQInsightChange, _ rhs: SQInsightChange) -> Bool {
        if lhs.effectMagnitude != rhs.effectMagnitude {
            return lhs.effectMagnitude > rhs.effectMagnitude
        }

        if lhs.rankingScore != rhs.rankingScore {
            return lhs.rankingScore > rhs.rankingScore
        }

        return lhs.title < rhs.title
    }

    private func lifeScoreComponentDetailItems(from component: SQLifeScoreV2Component) -> [SQLifeScoreDetailItem] {
        let evidenceItems = component.evidence.enumerated().map { index, evidence in
            SQLifeScoreDetailItem(
                id: "\(component.id)-evidence-\(index)",
                title: evidence.title,
                valueText: evidence.valueText,
                summary: evidence.summary,
                effect: evidence.effect
            )
        }

        guard evidenceItems.isEmpty else { return evidenceItems }
        if component.id == "habitsBehaviors" {
            return []
        }

        return [
            .init(
                id: "\(component.id)-summary",
                title: "Score Inputs",
                valueText: "\(component.score)/100",
                summary: "\(component.title) is based on the latest available signals for this area.",
                effect: component.score >= 74 ? .positive : (component.score < 62 ? .negative : .neutral)
            )
        ]
    }

    private func lifeScoreDriver(from driver: SQLifeScoreV2Driver) -> SQInsightDriver {
        .init(
            id: driver.id,
            signalId: driver.signalId,
            title: driver.title,
            summary: driver.summary,
            category: insightCategory(for: driver),
            direction: driver.effect == .negative ? .drag : .supportive,
            recentAverage: 0,
            baselineAverage: 0,
            deltaText: signedDecimal(total: driver.scoreImpact),
            effectMagnitude: abs(driver.scoreImpact),
            rankingScore: abs(driver.scoreImpact)
        )
    }

    private func insightCategory(for driver: SQLifeScoreV2Driver) -> SQInsightCategory {
        switch driver.componentId {
        case "sleep":
            return .sleep
        case "habitsBehaviors":
            return .habits
        case "trainingPerformance":
            return .training
        default:
            return .recovery
        }
    }
}

private extension SQLifeScoreBuilder {
    func signedDecimal(total value: Double) -> String {
        let prefix = value >= 0 ? "+" : ""
        return prefix + formattedDecimal(value)
    }

    func lifeScoreHeroSummaryText(
        state: SQLifeScoreState,
        components: [SQLifeScoreComponent],
        previousComponents: [SQLifeScoreComponent],
        totalWeight: Double,
        drivers: [SQInsightDriver],
        changes: [SQInsightChange],
        referenceDate: Date
    ) -> String? {
        guard totalWeight > 0 else {
            return stateHeroSummaryText(
                for: state,
                components: components,
                drivers: drivers,
                changes: changes,
                referenceDate: referenceDate
            )
        }

        let previousTotalWeight = previousComponents.reduce(0) { $0 + $1.weight }
        guard previousTotalWeight > 0 else {
            return stateHeroSummaryText(
                for: state,
                components: components,
                drivers: drivers,
                changes: changes,
                referenceDate: referenceDate
            )
        }

        let previousComponentsById = Dictionary(uniqueKeysWithValues: previousComponents.map { ($0.id, $0) })
        let componentImpacts = components.compactMap { component -> (component: SQLifeScoreComponent, delta: Double)? in
            guard let previousComponent = previousComponentsById[component.id] else { return nil }
            let currentContribution = Double(component.score) * (component.weight / totalWeight)
            let previousContribution = Double(previousComponent.score) * (previousComponent.weight / previousTotalWeight)
            return (component, currentContribution - previousContribution)
        }

        if let strongestDrop = componentImpacts
            .filter({ $0.delta <= -10 })
            .min(by: { $0.delta < $1.delta }) {
            return componentDropHeadlineText(
                for: strongestDrop.component,
                state: state
            )
        }

        if shouldSurfaceLiftHeadline(for: state),
           let strongestLift = componentImpacts
            .filter({ $0.delta >= 10 })
            .max(by: { $0.delta < $1.delta }) {
            return componentLiftHeadlineText(
                for: strongestLift.component,
                state: state,
                referenceDate: referenceDate
            )
        }

        return stateHeroSummaryText(
            for: state,
            components: components,
            drivers: drivers,
            changes: changes,
            referenceDate: referenceDate
        )
    }

    func shouldSurfaceLiftHeadline(for state: SQLifeScoreState) -> Bool {
        switch state {
        case .strong, .primed, .rebounding, .balanced:
            return true
        case .slightlyOff, .dipping, .underPressure, .calibrating:
            return false
        }
    }

    func componentDropHeadlineText(
        for component: SQLifeScoreComponent,
        state: SQLifeScoreState
    ) -> String {
        if state == .strong || state == .primed {
            switch component.id {
            case "sleep":
                return "Sleep took a hit, but you're still in a good position today."
            case "recoveryReadiness", "heart":
                return "Recovery dipped, but the day still has enough support."
            case "trainingPerformance", "workouts":
                return "Training strain is up, but you're still holding a solid baseline."
            default:
                return "\(component.title) is off, but the overall day still looks solid."
            }
        }

        switch component.id {
        case "sleep":
            if component.score < 55 {
                return "Poor sleep quality is dragging you down today."
            }

            return "Sleep quality is a little mixed today."
        case "recoveryReadiness", "heart":
            return "Recovery signals look lower today, and they're weighing on your Life Score."
        case "habitsBehaviors", "habits":
            return "Recent habits look less aligned today, and they're weighing on your Life Score."
        case "trainingPerformance", "workouts":
            return "Recent training looks harder to absorb today, and it's weighing on your Life Score."
        case "dataConfidence", "consistency":
            return "Missing check-ins are making today's Life Score less complete."
        default:
            return "\(component.title) looks lower today, and it's weighing on your Life Score."
        }
    }

    func componentLiftHeadlineText(
        for component: SQLifeScoreComponent,
        state: SQLifeScoreState,
        referenceDate: Date
    ) -> String {
        if state == .balanced {
            return stateHeroSummaryText(for: state, referenceDate: referenceDate)
        }

        switch component.id {
        case "sleep":
            return "Sleep is giving you a better base today."
        case "recoveryReadiness", "heart":
            return "Recovery signals are giving you a better base today."
        case "habitsBehaviors", "habits":
            return "Your recent habits are giving the day some momentum."
        case "trainingPerformance", "workouts":
            return "Training looks easier to absorb today."
        case "dataConfidence", "consistency":
            return "Your recent check-ins are helping LifeIQ understand today more clearly."
        default:
            return "\(component.title) is giving the day some momentum."
        }
    }

    enum HeroPressureSubfamily {
        case sleep
        case habits
        case recoveryStrain
        case stress
        case lowData
    }

    func pressureSubfamilyHeroSummary(
        state: SQLifeScoreState,
        components: [SQLifeScoreComponent],
        drivers: [SQInsightDriver],
        changes: [SQInsightChange],
        referenceDate: Date
    ) -> String? {
        guard let subfamily = pressureSubfamily(
            state: state,
            components: components,
            drivers: drivers,
            changes: changes
        ) else {
            return nil
        }

        let options: [String]
        switch (state, subfamily) {
        case (_, .lowData):
            options = [
                "Missing logs are making today's read less complete.",
                "LifeIQ has enough to flag pressure, but not a clean full read.",
                "Inconsistent logging is part of today's pressure."
            ]
        case (_, .habits):
            options = [
                "Recent habits are adding most of the pressure today.",
                "Habit load is making the day harder to recover from.",
                "Alcohol, caffeine, or other habits are weighing on the day."
            ]
        case (_, .recoveryStrain):
            options = [
                "Recent strain is making today harder to absorb.",
                "Training and recovery are not lining up cleanly today.",
                "Your body is carrying more strain than usual."
            ]
        case (_, .stress):
            options = [
                "Mind and energy signals are a little lower today.",
                "Energy or clarity may need more support today.",
                "Mental load is part of today's pressure."
            ]
        case (_, .sleep):
            options = [
                "Sleep pressure is weighing on the day.",
                "Sleep is not giving you much margin today.",
                "A weaker sleep base is dragging the day down."
            ]
        }

        return deterministicOption(
            from: options,
            referenceDate: referenceDate,
            salt: pressureSubfamilyVariationSalt(subfamily)
        )
    }

    func pressureSubfamilyHeroAction(
        state: SQLifeScoreState,
        components: [SQLifeScoreComponent],
        drivers: [SQInsightDriver],
        changes: [SQInsightChange],
        referenceDate: Date
    ) -> String? {
        guard let subfamily = pressureSubfamily(
            state: state,
            components: components,
            drivers: drivers,
            changes: changes
        ) else {
            return nil
        }

        let options: [String]
        switch subfamily {
        case .lowData:
            options = [
                "Log the basics before reading too much into the score.",
                "Complete a check-in so LifeIQ can separate missing data from real pressure.",
                "Fill in today's core signals to make the read cleaner."
            ]
        case .habits:
            options = [
                "Keep vice load lower today and protect tonight's sleep.",
                "Avoid adding more habit drag today.",
                "Make the next healthy choice obvious and keep the evening clean."
            ]
        case .recoveryStrain:
            options = [
                "Pull back on intensity and let recent training absorb.",
                "Make today more about recovery than output.",
                "Choose easier work over another hard push."
            ]
        case .stress:
            options = [
                "Lower the friction on the day and avoid stacking stress.",
                "Protect energy by keeping the next few choices simple.",
                "Keep effort contained until stress signals settle."
            ]
        case .sleep:
            options = [
                "Prioritize sleep tonight and keep workouts lighter today.",
                "Make sleep the priority tonight; keep training easy today.",
                "Protect recovery today so sleep can rebound tonight."
            ]
        }

        return deterministicOption(
            from: options,
            referenceDate: referenceDate,
            salt: pressureSubfamilyVariationSalt(subfamily) + 41
        )
    }

    func pressureSubfamily(
        state: SQLifeScoreState,
        components: [SQLifeScoreComponent],
        drivers: [SQInsightDriver],
        changes: [SQInsightChange]
    ) -> HeroPressureSubfamily? {
        switch state {
        case .slightlyOff, .dipping, .underPressure:
            break
        case .strong, .primed, .balanced, .rebounding, .calibrating:
            return nil
        }

        let driverSignalIds = Set(drivers.map(\.signalId))
        let negativeChangeSignalIds = Set(
            changes
                .filter { $0.direction == .worsened }
                .map(\.signalId)
        )
        let pressureSignalIds = driverSignalIds.union(negativeChangeSignalIds)

        if (componentScore("dataConfidence", in: components) ?? 100) < 50 {
            return .lowData
        }

        if pressureSignalIds.contains(where: isHabitPressureSignalId)
            || (componentScore("habitsBehaviors", in: components) ?? 100) < 60 {
            return .habits
        }

        if pressureSignalIds.contains(where: isTrainingPressureSignalId)
            || (componentScore("trainingPerformance", in: components) ?? 100) < 62
            || (componentScore("recoveryReadiness", in: components) ?? 100) < 58 {
            return .recoveryStrain
        }

        if driverSignalIds.contains(where: isStressPressureSignalId)
            || (componentScore("mindEnergy", in: components) ?? 100) < 66 {
            return .stress
        }

        if pressureSignalIds.contains(where: isSleepPressureSignalId)
            || (componentScore("sleep", in: components) ?? 100) < 72 {
            return .sleep
        }

        return nil
    }

    func pressureSubfamilyVariationSalt(_ subfamily: HeroPressureSubfamily) -> Int {
        switch subfamily {
        case .sleep:
            return 311
        case .habits:
            return 337
        case .recoveryStrain:
            return 359
        case .stress:
            return 383
        case .lowData:
            return 401
        }
    }

    func stateHeroSummaryText(for state: SQLifeScoreState, referenceDate: Date) -> String {
        stateHeroSummaryText(
            for: state,
            components: [],
            drivers: [],
            changes: [],
            referenceDate: referenceDate
        )
    }

    func stateHeroSummaryText(
        for state: SQLifeScoreState,
        components: [SQLifeScoreComponent],
        drivers: [SQInsightDriver],
        changes: [SQInsightChange],
        referenceDate: Date
    ) -> String {
        if let pressureSummary = pressureSubfamilyHeroSummary(
            state: state,
            components: components,
            drivers: drivers,
            changes: changes,
            referenceDate: referenceDate
        ) {
            return pressureSummary
        }

        let options: [String]
        switch state {
        case .strong:
            options = [
                "You're in a strong position today.",
                "Everything is lining up for a good day.",
                "You're well recovered and ready to go.",
                "You're in one of your better windows right now.",
                "Your body is in a good place today."
            ]
        case .primed:
            options = [
                "You're primed for a solid day.",
                "You've got good momentum today.",
                "This is a good window to get things done.",
                "You're set up to perform today.",
                "Energy and motivation are working in your favor."
            ]
        case .balanced:
            options = [
                "Things look steady today.",
                "You're in a decent rhythm.",
                "Today is fairly neutral.",
                "You're holding a stable baseline.",
                "Nothing is off, but nothing is pushing you forward either."
            ]
        case .rebounding:
            options = [
                "You're trending in the right direction.",
                "Things are improving today.",
                "You're bouncing back from a rougher stretch.",
                "Recovery is moving back up.",
                "You're regaining momentum."
            ]
        case .slightlyOff:
            options = [
                "One or two things are slightly off today.",
                "The day may feel a bit uneven.",
                "You're mostly fine, but not at your best.",
                "There's a small drag on the day.",
                "You might feel a bit off compared to normal."
            ]
        case .dipping:
            options = [
                "You're starting to trend downward.",
                "Things are slipping compared to yesterday.",
                "The day is losing momentum.",
                "You're trending in the wrong direction.",
                "Recovery and performance are dipping."
            ]
        case .underPressure:
            options = [
                "The day is working against you a bit.",
                "Recovery is falling behind today.",
                "You're carrying more strain than usual.",
                "This is a lower-quality day overall.",
                "Several signals are dragging you down."
            ]
        case .calibrating:
            options = [
                "LifeIQ needs a little more data to read the day clearly.",
                "There isn't enough signal yet to make this fully personal.",
                "The day is still calibrating."
            ]
        }

        return deterministicOption(
            from: options,
            referenceDate: referenceDate,
            salt: stateVariationSalt(for: state)
        )
    }

    func lifeScoreHeroAction(
        fallbackActions: [SQInsightAction],
        state: SQLifeScoreState,
        components: [SQLifeScoreComponent],
        drivers: [SQInsightDriver],
        changes: [SQInsightChange],
        referenceDate: Date
    ) -> SQInsightAction? {
        guard state != .calibrating else { return fallbackActions.first }

        let summary = contextualLifeScoreActionSummary(
            state: state,
            components: components,
            drivers: drivers,
            changes: changes,
            referenceDate: referenceDate
        ) ?? stateHeroActionSummary(for: state, referenceDate: referenceDate)
        let tone = lifeScoreActionTone(for: state)

        return .init(
            id: "life-score-action-\(lifeScoreActionIdSuffix(for: state, referenceDate: referenceDate))",
            title: lifeScoreActionTitle(for: state),
            summary: summary,
            context: nil,
            tone: tone,
            rankingScore: (fallbackActions.first?.rankingScore ?? 0) + 1
        )
    }

    func contextualLifeScoreActionSummary(
        state: SQLifeScoreState,
        components: [SQLifeScoreComponent],
        drivers: [SQInsightDriver],
        changes: [SQInsightChange],
        referenceDate: Date
    ) -> String? {
        switch state {
        case .slightlyOff, .dipping, .underPressure:
            break
        case .strong, .primed, .balanced, .rebounding, .calibrating:
            return nil
        }

        if let pressureAction = pressureSubfamilyHeroAction(
            state: state,
            components: components,
            drivers: drivers,
            changes: changes,
            referenceDate: referenceDate
        ) {
            return pressureAction
        }

        let lowComponents = components
            .filter { component in
                switch component.id {
                case "sleep":
                    return component.score < 72
                case "heart":
                    return component.score < 65
                case "habits", "workouts":
                    return component.score < 60
                case "consistency":
                    return component.score < 50
                default:
                    return component.score < 60
                }
            }
            .sorted { $0.score < $1.score }

        guard let lowestComponent = lowComponents.first else { return nil }

        let options: [String]
        switch lowestComponent.id {
        case "sleep":
            options = [
                "Prioritize quality sleep tonight and keep workouts lighter today.",
                "Make sleep the priority tonight; keep training easy today.",
                "Keep workouts lighter today and give sleep a chance to rebound tonight."
            ]
        case "heart":
            options = [
                "Keep workouts lighter today while recovery settles.",
                "Pull back on intensity until recovery looks steadier.",
                "Protect recovery today before adding more strain."
            ]
        case "habits":
            options = [
                "Tighten the basics today and avoid adding extra drag.",
                "Keep the day simple and make the next healthy choice obvious.",
                "Clean up the easy levers before chasing intensity."
            ]
        case "workouts":
            options = [
                "Pull back on intensity and let recent training absorb.",
                "Make today more about recovery than output.",
                "Choose easier work over another hard push."
            ]
        case "consistency":
            options = [
                "Complete a check-in so LifeIQ can read the day more clearly.",
                "Log the basics today so the score has a cleaner signal.",
                "Give LifeIQ a fresh check-in before reading too much into the score."
            ]
        default:
            return nil
        }

        return deterministicOption(
            from: options,
            referenceDate: referenceDate,
            salt: componentVariationSalt(for: lowestComponent.id)
        )
    }

    func stateHeroActionSummary(for state: SQLifeScoreState, referenceDate: Date) -> String {
        let options: [String]
        switch state {
        case .strong:
            options = [
                "Push training today if you want.",
                "Go for a harder session if it fits your plan.",
                "Use this window for a strong workout.",
                "Take advantage of the momentum today.",
                "Lean into intensity while it's there."
            ]
        case .primed:
            options = [
                "Use the energy for something meaningful.",
                "Push where it matters most.",
                "Take on something that requires focus or effort.",
                "Channel this into a strong session or task.",
                "Make the most of this window."
            ]
        case .balanced:
            options = [
                "Stay consistent and keep effort moderate.",
                "Stick to your plan without overreaching.",
                "Keep things moderate.",
                "Don't overreach; just execute.",
                "Maintain your current rhythm."
            ]
        case .rebounding:
            options = [
                "Keep this rebound going.",
                "Build on the rebound, but don't rush it.",
                "Stay steady and let it compound.",
                "Keep doing what is working and let it build.",
                "Let the improvement stabilize before pushing harder."
            ]
        case .slightlyOff:
            options = [
                "Keep effort moderate today.",
                "Be more intentional with your energy.",
                "Avoid pushing too hard.",
                "Focus on doing things well, not hard.",
                "Adjust expectations slightly."
            ]
        case .dipping:
            options = [
                "Keep strain moderate today.",
                "Protect recovery before things slide further.",
                "Pull things back slightly.",
                "Stabilize before pushing again.",
                "Don't let the dip turn into a slide."
            ]
        case .underPressure:
            options = [
                "Make recovery the priority today.",
                "Keep things light and low stress.",
                "Pull back on intensity.",
                "Focus on rest and reset.",
                "Avoid adding extra strain today."
            ]
        case .calibrating:
            options = [
                "Complete a check-in to make this more personal.",
                "Log the basics so LifeIQ can calibrate.",
                "Add today's signals before reading too much into the score."
            ]
        }

        return deterministicOption(
            from: options,
            referenceDate: referenceDate,
            salt: stateVariationSalt(for: state) + 41
        )
    }

    func lifeScoreActionTone(for state: SQLifeScoreState) -> SQInsightActionTone {
        switch state {
        case .strong, .primed, .balanced, .rebounding:
            return .maintain
        case .slightlyOff:
            return .improve
        case .dipping, .underPressure, .calibrating:
            return .caution
        }
    }

    func lifeScoreActionTitle(for state: SQLifeScoreState) -> String {
        switch state {
        case .strong, .primed:
            return "Use The Window"
        case .balanced, .rebounding:
            return "Best Move Today"
        case .slightlyOff:
            return "Adjust Today"
        case .dipping, .underPressure:
            return "Watch Today"
        case .calibrating:
            return "Next Step"
        }
    }

    func lifeScoreActionIdSuffix(for state: SQLifeScoreState, referenceDate: Date) -> String {
        let dayIndex = dayVariationIndex(for: referenceDate)
        return "\(state.title.lowercased().replacingOccurrences(of: " ", with: "-"))-\(dayIndex)"
    }

    func deterministicOption(
        from options: [String],
        referenceDate: Date,
        salt: Int
    ) -> String {
        guard !options.isEmpty else { return "" }

        let rawIndex = dayVariationIndex(for: referenceDate) + salt
        let index = ((rawIndex % options.count) + options.count) % options.count
        return options[index]
    }

    func dayVariationIndex(for referenceDate: Date) -> Int {
        Calendar.current.ordinality(of: .day, in: .era, for: referenceDate)
            ?? Int(referenceDate.timeIntervalSinceReferenceDate / 86_400)
    }

    func stateVariationSalt(for state: SQLifeScoreState) -> Int {
        switch state {
        case .strong:
            return 3
        case .primed:
            return 11
        case .balanced:
            return 17
        case .rebounding:
            return 23
        case .slightlyOff:
            return 31
        case .dipping:
            return 37
        case .underPressure:
            return 43
        case .calibrating:
            return 47
        }
    }

    func componentVariationSalt(for componentId: String) -> Int {
        switch componentId {
        case "sleep":
            return 5
        case "heart":
            return 13
        case "habits":
            return 19
        case "workouts":
            return 29
        case "consistency":
            return 53
        default:
            return 59
        }
    }

    func lifeScoreAlignedActions(
        _ actions: [SQInsightAction],
        state: SQLifeScoreState,
        score: Int?,
        scoreDeltaFromPreviousDay: Int?,
        components: [SQLifeScoreComponent]
    ) -> [SQInsightAction] {
        let limitedActions = Array(actions.prefix(1))
        guard shouldCautionLifeScoreTraining(
            state: state,
            score: score,
            scoreDeltaFromPreviousDay: scoreDeltaFromPreviousDay,
            components: components
        ) else {
            return limitedActions
        }

        guard let action = limitedActions.first else { return [] }
        guard isTrainingPushAction(action.summary) else { return limitedActions }

        return [
            .init(
                id: "\(action.id)-life-score-caution",
                title: "Watch Today",
                summary: lifeScoreCautionActionSummary(state: state, components: components),
                context: action.context,
                tone: .caution,
                rankingScore: action.rankingScore
            )
        ]
    }

    func shouldCautionLifeScoreTraining(
        state: SQLifeScoreState,
        score: Int?,
        scoreDeltaFromPreviousDay: Int?,
        components: [SQLifeScoreComponent]
    ) -> Bool {
        if state == .dipping || state == .underPressure {
            return true
        }

        if (score ?? 100) < 72 {
            return true
        }

        if (scoreDeltaFromPreviousDay ?? 0) < 0,
           (score ?? 100) < 80 {
            return true
        }

        return components.contains { component in
            switch component.id {
            case "sleep":
                return component.score < 72
            case "recoveryReadiness", "heart", "habitsBehaviors", "habits":
                return component.score < 65
            default:
                return false
            }
        }
    }

    func lifeScoreCautionActionSummary(
        state: SQLifeScoreState,
        components: [SQLifeScoreComponent]
    ) -> String {
        if let sleepScore = componentScore("sleep", in: components), sleepScore < 72 {
            return "Prioritize quality sleep tonight and keep workouts lighter today."
        }

        if let recoveryScore = componentScore("recoveryReadiness", in: components), recoveryScore < 65 {
            return "Keep strain moderate while recovery is still soft."
        }

        if state == .dipping {
            return "Keep workouts lighter today and protect recovery tonight."
        }

        return "Protect recovery before adding extra intensity."
    }

    func componentScore(_ id: String, in components: [SQLifeScoreComponent]) -> Int? {
        let aliases = componentIdAliases(for: id)
        return components.first { aliases.contains($0.id) }?.score
    }

    func componentIdAliases(for id: String) -> Set<String> {
        switch id {
        case "recoveryReadiness", "heart":
            return ["recoveryReadiness", "heart"]
        case "habitsBehaviors", "habits":
            return ["habitsBehaviors", "habits"]
        case "trainingPerformance", "workouts":
            return ["trainingPerformance", "workouts"]
        case "dataConfidence", "consistency":
            return ["dataConfidence", "consistency"]
        default:
            return [id]
        }
    }

    func isTrainingPushAction(_ summary: String) -> Bool {
        let normalizedSummary = normalizedHeroMatchText(summary)
        return normalizedSummary.contains("push harder")
            || normalizedSummary.contains("push training")
            || normalizedSummary.contains("good day to push")
    }

    func lifeScoreRefinementPromptText(for intelligenceInput: SQHealthIntelligenceInput) -> String? {
        guard intelligenceInput.timeRange == .today,
              intelligenceInput.isLoggedIn,
              let currentCheckInPromptPeriod = intelligenceInput.currentCheckInPromptPeriod,
              !intelligenceInput.hasCompletedCurrentPromptCheckIn else {
            return nil
        }

        let periodTitle: String
        switch currentCheckInPromptPeriod {
        case .morning:
            periodTitle = "morning"
        case .evening:
            periodTitle = "evening"
        case .unknown:
            return "Complete your check-in to refine today's score."
        }

        return "Complete your \(periodTitle) check-in to refine today's score."
    }

    func normalizedHeroMatchText(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: "sleep quality", with: "sleep")
            .replacingOccurrences(of: "sleep hours", with: "sleep")
            .replacingOccurrences(of: "resting heart rate", with: "resting hr")
            .replacingOccurrences(of: "mental clarity", with: "clarity")
            .replacingOccurrences(of: "running performance", with: "performance")
            .replacingOccurrences(of: "cycling performance", with: "performance")
            .replacingOccurrences(of: "walking performance", with: "performance")
            .replacingOccurrences(of: "pickleball performance", with: "performance")
            .replacingOccurrences(of: "workout performance", with: "performance")
    }

    func lifeScoreState(
        score: Int?,
        availableWeight: Double,
        scoreDeltaFromPreviousDay: Int?,
        components: [SQLifeScoreComponent],
        drivers: [SQInsightDriver],
        primaryInsight: SQInsight?
    ) -> SQLifeScoreState {
        guard let score else { return .calibrating }
        guard availableWeight >= 45 else { return .calibrating }

        let sleepScore = componentScore("sleep", in: components)
        let recoveryScore = componentScore("recoveryReadiness", in: components)
        let habitsScore = componentScore("habitsBehaviors", in: components)
        let workoutsScore = componentScore("trainingPerformance", in: components)
        let dataConfidenceScore = componentScore("dataConfidence", in: components)

        let lowComponentCount = components.filter { $0.score < 60 }.count
        let softDragComponentCount = components.filter { $0.score < 72 }.count
        let strongComponentCount = components.filter { $0.score >= 85 }.count

        let stateDrivers = drivers.filter { isLifeScoreStateSignalId($0.signalId) }
        let supportiveDrivers = stateDrivers.filter { $0.direction == .supportive }
        let dragDrivers = stateDrivers.filter { $0.direction == .drag }

        let strongNegativeMomentum = (scoreDeltaFromPreviousDay ?? 0) <= -7
        let negativeMomentum = (scoreDeltaFromPreviousDay ?? 0) <= -4
        let positiveMomentum = (scoreDeltaFromPreviousDay ?? 0) >= 4

        let hasRecoveryDrag = (sleepScore ?? 100) < 62
            || (recoveryScore ?? 100) < 58
            || dragDrivers.contains { recoveryPressureSignalIds.contains($0.signalId) && $0.rankingScore >= 10 }
        let hasMentalPressure = dragDrivers.contains { mentalPressureSignalIds.contains($0.signalId) && $0.rankingScore >= 8 }
        let hasTrainingPressure = dragDrivers.contains { trainingPressureSignalIds.contains($0.signalId) && $0.rankingScore >= 8 }
        let hasReadinessLift = supportiveDrivers.contains { readinessLiftSignalIds.contains($0.signalId) }
        let hasTrainingLift = supportiveDrivers.contains { trainingLiftSignalIds.contains($0.signalId) }

        let primaryInsightText = normalizedHeroMatchText(
            [
                primaryInsight?.title ?? "",
                primaryInsight?.summary ?? ""
            ]
            .joined(separator: " ")
        )
        let insightSuggestsPressure = primaryInsight?.effect == .negative
            || primaryInsightText.contains("under pressure")
            || primaryInsightText.contains("dragging")
            || primaryInsightText.contains("stress")
            || primaryInsightText.contains("anxiety")
        let insightSuggestsLift = primaryInsight?.effect == .positive
            || primaryInsightText.contains("helping")
            || primaryInsightText.contains("setting up a good day")

        let majorNegativeComponentCount = components.filter { isMajorNegativeLifeScoreComponent($0) }.count
        let severeNegativeComponentCount = components.filter { isSevereNegativeLifeScoreComponent($0) }.count
        let majorMentalPressure = dragDrivers.contains { mentalPressureSignalIds.contains($0.signalId) && $0.rankingScore >= 11 }
        let majorTrainingPressure = dragDrivers.contains { trainingPressureSignalIds.contains($0.signalId) && $0.rankingScore >= 11 }
        let majorSignalPressureCount = [majorMentalPressure, majorTrainingPressure].filter { $0 }.count
        let majorPressureCount = majorNegativeComponentCount + majorSignalPressureCount
        let hasStackedMajorPressure = hasRecoveryDrag
            && (majorMentalPressure || majorTrainingPressure)
            && score < 78
        let allowsUnderPressure = score < 68
            || (score < 72 && severeNegativeComponentCount >= 2)
            || (score < 72 && severeNegativeComponentCount >= 1 && majorPressureCount >= 2)

        if positiveMomentum
            && score >= 70
            && score < 88
            && severeNegativeComponentCount < 2 {
            return .rebounding
        }

        if allowsUnderPressure && (
            score < 50
                || (majorPressureCount >= 2 && score < 70)
                || (severeNegativeComponentCount >= 2 && score < 72)
                || (severeNegativeComponentCount >= 1 && score < 64)
                || (hasStackedMajorPressure && score < 70)
                || ((habitsScore ?? 100) < 40 && (sleepScore ?? 100) < 65 && score < 70)
        ) {
            return .underPressure
        }

        if strongNegativeMomentum && (score < 82 || softDragComponentCount >= 1 || insightSuggestsPressure) {
            return .dipping
        }

        if negativeMomentum && (score < 78 || hasMentalPressure || hasTrainingPressure || softDragComponentCount >= 2) {
            return .dipping
        }

        if score >= 90
            && strongComponentCount >= 3
            && !hasRecoveryDrag
            && !hasMentalPressure
            && !negativeMomentum {
            return .strong
        }

        if score >= 84
            && !hasRecoveryDrag
            && !negativeMomentum
            && (hasReadinessLift
                || hasTrainingLift
                || insightSuggestsLift
                || (sleepScore ?? 0) >= 85
                || (recoveryScore ?? 0) >= 82
                || (workoutsScore ?? 0) >= 78) {
            return .primed
        }

        if score >= 78
            && softDragComponentCount <= 1
            && !negativeMomentum
            && (dataConfidenceScore ?? 100) >= 55 {
            return .balanced
        }

        if score >= 66
            || (score >= 60 && lowComponentCount == 0) {
            return .slightlyOff
        }

        if score >= 58 {
            return .slightlyOff
        }

        return (score < 78 && severeNegativeComponentCount >= 1) ? .underPressure : .slightlyOff
    }

    func isMajorNegativeLifeScoreComponent(_ component: SQLifeScoreComponent) -> Bool {
        switch component.id {
        case "sleep":
            return component.score < 58
        case "recoveryReadiness", "heart":
            return component.score < 58
        case "habitsBehaviors", "habits":
            return component.score < 50
        case "trainingPerformance", "workouts":
            return component.score < 55
        case "dataConfidence", "consistency":
            return component.score < 40
        default:
            return component.score < 55
        }
    }

    func isSevereNegativeLifeScoreComponent(_ component: SQLifeScoreComponent) -> Bool {
        switch component.id {
        case "sleep":
            return component.score < 48
        case "recoveryReadiness", "heart":
            return component.score < 50
        case "habitsBehaviors", "habits":
            return component.score < 38
        case "trainingPerformance", "workouts":
            return component.score < 42
        case "dataConfidence", "consistency":
            return component.score < 25
        default:
            return component.score < 45
        }
    }

    func isLifeScoreStateSignalId(_ signalId: String) -> Bool {
        readinessLiftSignalIds.contains(signalId)
            || mentalPressureSignalIds.contains(signalId)
            || trainingPressureSignalIds.contains(signalId)
    }

    func isHabitPressureSignalId(_ signalId: String) -> Bool {
        [
            SQMetricId.alcohol,
            SQMetricId.caffeine,
            SQMetricId.weed,
            SQMetricId.nicotine,
            SQMetricId.porn
        ].contains(signalId)
    }

    func isStressPressureSignalId(_ signalId: String) -> Bool {
        mentalPressureSignalIds.contains(signalId)
    }

    func isSleepPressureSignalId(_ signalId: String) -> Bool {
        [
            SQMetricId.sleepHours,
            SQMetricId.sleepQuality
        ].contains(signalId)
    }

    func isTrainingPressureSignalId(_ signalId: String) -> Bool {
        trainingPressureSignalIds.contains(signalId)
            || signalId == SQMetricId.soreness
            || signalId == SQInsightAnalysisMetricId.restingHeartRate
    }

    var readinessLiftSignalIds: Set<String> {
        [
            SQMetricId.sleepHours,
            SQMetricId.sleepQuality,
            SQInsightAnalysisMetricId.restingHeartRate,
            SQMetricId.energy,
            SQMetricId.mood,
            SQMetricId.mentalClarity,
            SQMetricId.motivation,
            SQInsightAnalysisMetricId.workoutPerformance
        ]
    }

    var mentalPressureSignalIds: Set<String> {
        [
            SQMetricId.stress,
            SQMetricId.anxiety,
            SQMetricId.mood,
            SQMetricId.energy,
            SQMetricId.mentalClarity
        ]
    }

    var recoveryPressureSignalIds: Set<String> {
        [
            SQMetricId.sleepHours,
            SQMetricId.sleepQuality,
            SQInsightAnalysisMetricId.restingHeartRate,
            SQMetricId.soreness,
            SQMetricId.stress,
            SQMetricId.anxiety
        ]
    }

    var trainingPressureSignalIds: Set<String> {
        [
            SQInsightAnalysisMetricId.workoutDifficulty,
            SQInsightAnalysisMetricId.workoutPerformance,
            SQMetricId.soreness,
            SQMetricId.motivation
        ]
    }

    var trainingLiftSignalIds: Set<String> {
        [
            SQMetricId.motivation,
            SQInsightAnalysisMetricId.workoutPerformance,
            SQMetricId.energy
        ]
    }

    func lifeScoreSleepComponent(
        checkIns: [SQDailyCheckInStats],
        sleepCheckIns: [SQDailyCheckInStats] = [],
        referenceDate: Date,
        sleepData: SQSleepDashboardData?
    ) -> SQLifeScoreComponent? {
        guard let sleepInput = sleepComponentInput(
            checkIns: resolvedSleepCheckIns(from: checkIns, explicitSleepCheckIns: sleepCheckIns),
            targetDay: referenceDate,
            sleepData: sleepData,
            usePreviousHealthNight: false
        ) else {
            return nil
        }

        return lifeScoreSleepComponent(
            for: sleepInput
        )
    }

    func previousLifeScoreSleepComponent(
        checkIns: [SQDailyCheckInStats],
        sleepCheckIns: [SQDailyCheckInStats] = [],
        referenceDate: Date,
        sleepData: SQSleepDashboardData?
    ) -> SQLifeScoreComponent? {
        let calendar = Calendar.current
        let targetDay = calendar.date(byAdding: .day, value: -1, to: referenceDate) ?? referenceDate
        guard let sleepInput = sleepComponentInput(
            checkIns: resolvedSleepCheckIns(from: checkIns, explicitSleepCheckIns: sleepCheckIns),
            targetDay: targetDay,
            sleepData: sleepData,
            usePreviousHealthNight: true
        ) else {
            return nil
        }

        return lifeScoreSleepComponent(
            for: sleepInput
        )
    }

    struct LifeScoreSleepInput {
        let score: Double
        let durationHours: Double?
        let source: LifeScoreSleepSource
    }

    enum LifeScoreSleepSource {
        case checkIn(quality: Double?, hours: Double?)
        case healthKitLatest(score: SQSleepScoreBreakdown, durationHours: Double)
        case healthKitAverage(score: Double, durationHours: Double?, nightCount: Int)
        case priorHealthKitLatest(score: SQSleepScoreBreakdown, durationHours: Double)
        case priorHealthKitAverage(score: Double, durationHours: Double?, nightCount: Int)
    }

    func sleepComponentInput(
        checkIns: [SQDailyCheckInStats],
        targetDay: Date,
        sleepData: SQSleepDashboardData?,
        usePreviousHealthNight: Bool
    ) -> LifeScoreSleepInput? {
        let calendar = Calendar.current
        let targetCheckIn = checkIns
            .filter { calendar.isDate($0.date, inSameDayAs: targetDay) }
            .sorted { $0.date < $1.date }
            .last

        let sleepQuality = targetCheckIn?.values[SQMetricId.sleepQuality].map { clamp(Double($0), min: 0, max: 10) }
        let sleepHours = targetCheckIn?.values[SQMetricId.sleepHours].map { clamp(Double($0), min: 0, max: 24) }
        let resolvedHealthKitSleepInput = healthKitSleepInput(
            sleepData: sleepData,
            usePreviousHealthNight: usePreviousHealthNight
        )
        let healthKitMetricIds = targetCheckIn?.healthKitMetricIds ?? []
        let hasUserEnteredSleepMetric = (sleepQuality != nil && !healthKitMetricIds.contains(SQMetricId.sleepQuality))
            || (sleepHours != nil && !healthKitMetricIds.contains(SQMetricId.sleepHours))

        if !hasUserEnteredSleepMetric, let resolvedHealthKitSleepInput {
            return resolvedHealthKitSleepInput
        }

        if let sleepQuality {
            let qualityScore = sleepQuality * 10
            if let sleepHours {
                let durationScore = sleepDurationScore(hours: sleepHours)
                return .init(
                    score: (qualityScore * 0.75) + (durationScore * 0.25),
                    durationHours: sleepHours,
                    source: .checkIn(quality: sleepQuality, hours: sleepHours)
                )
            }

            return .init(
                score: qualityScore,
                durationHours: sleepHours,
                source: .checkIn(quality: sleepQuality, hours: sleepHours)
            )
        }

        if let sleepHours {
            return .init(
                score: sleepDurationScore(hours: sleepHours),
                durationHours: sleepHours,
                source: .checkIn(quality: nil, hours: sleepHours)
            )
        }

        return resolvedHealthKitSleepInput
    }

    func healthKitSleepInput(
        sleepData: SQSleepDashboardData?,
        usePreviousHealthNight: Bool
    ) -> LifeScoreSleepInput? {
        if usePreviousHealthNight {
            if let priorNight = sleepData?.priorNights.sorted(by: { $0.wakeDay < $1.wakeDay }).last {
                let score = sleepAggregationService.score(for: priorNight)
                return .init(
                    score: score.totalScore,
                    durationHours: priorNight.totalSleepDuration / 3600.0,
                    source: .priorHealthKitLatest(
                        score: score,
                        durationHours: priorNight.totalSleepDuration / 3600.0
                    )
                )
            }

            let priorScores = sleepData?.priorNights.map({ sleepAggregationService.score(for: $0).totalScore }) ?? []
            if let averageScore = priorScores.average {
                let averageDuration = sleepData?.priorNights.map(\.totalSleepDuration).average.map { $0 / 3600.0 }
                return .init(
                    score: averageScore,
                    durationHours: averageDuration,
                    source: .priorHealthKitAverage(
                        score: averageScore,
                        durationHours: averageDuration,
                        nightCount: priorScores.count
                    )
                )
            }

            return nil
        }

        if let latestNight = sleepData?.latestNight {
            let score = sleepAggregationService.score(for: latestNight)
            return .init(
                score: score.totalScore,
                durationHours: latestNight.totalSleepDuration / 3600.0,
                source: .healthKitLatest(
                    score: score,
                    durationHours: latestNight.totalSleepDuration / 3600.0
                )
            )
        }

        if let averageScore = sleepData?.averageScore?.totalScore {
            let averageDuration = sleepData?.currentNights.map(\.totalSleepDuration).average.map { $0 / 3600.0 }
            return .init(
                score: averageScore,
                durationHours: averageDuration,
                source: .healthKitAverage(
                    score: averageScore,
                    durationHours: averageDuration,
                    nightCount: sleepData?.currentNights.count ?? 0
                )
            )
        }

        return nil
    }

    func resolvedSleepCheckIns(
        from checkIns: [SQDailyCheckInStats],
        explicitSleepCheckIns: [SQDailyCheckInStats]
    ) -> [SQDailyCheckInStats] {
        if !explicitSleepCheckIns.isEmpty {
            return explicitSleepCheckIns
        }

        let morningCheckIns = checkIns.filter { $0.period == .morning }
        if !morningCheckIns.isEmpty {
            return morningCheckIns
        }

        return checkIns
    }

    func lifeScoreSleepComponent(for input: LifeScoreSleepInput) -> SQLifeScoreComponent {
        let roundedScore = adjustedLifeScoreSleepComponentScore(
            rawSleepScore: input.score,
            durationHours: input.durationHours
        )

        let summary: String
        switch roundedScore {
        case 85...:
            summary = "Sleep looked strong and should be helping recovery."
        case 70...84:
            summary = "Sleep was decent, but not elite enough to fully lift the day."
        case 55...69:
            summary = "Sleep was mixed, so recovery support looks only moderate."
        default:
            summary = "Sleep is the biggest drag on the score right now."
        }

        return .init(
            id: "sleep",
            title: "Sleep",
            score: roundedScore,
            summary: summary,
            weight: 30,
            detailItems: sleepDetailItems(
                input: input,
                adjustedScore: roundedScore
            )
        )
    }

    func sleepDetailItems(
        input: LifeScoreSleepInput,
        adjustedScore: Int
    ) -> [SQLifeScoreDetailItem] {
        let rawScore = Int(input.score.rounded())
        let sourceItem: SQLifeScoreDetailItem

        switch input.source {
        case .checkIn(let quality, let hours):
            sourceItem = .init(
                id: "sleep-source-check-in",
                title: "Source",
                valueText: sleepCheckInSourceValueText(quality: quality, hours: hours),
                summary: sleepCheckInSourceSummary(
                    quality: quality,
                    hours: hours,
                    rawScore: rawScore
                ),
                effect: sleepEffect(for: adjustedScore)
            )
        case .healthKitLatest(let score, let durationHours):
            sourceItem = .init(
                id: "sleep-source-healthkit",
                title: "Source",
                valueText: "HealthKit Sleep Score \(Int(score.totalScore.rounded()))/100 • \(formattedHours(durationHours)) asleep",
                summary: "LifeIQ used last night's HealthKit sleep stages: duration \(Int(score.durationScore.rounded()))/\(Int(SQSleepScoreBreakdown.maxDurationScore)), efficiency \(Int(score.efficiencyScore.rounded()))/\(Int(SQSleepScoreBreakdown.maxEfficiencyScore)), fragmentation \(Int(score.fragmentationScore.rounded()))/\(Int(SQSleepScoreBreakdown.maxFragmentationScore)), architecture \(Int(score.architectureScore.rounded()))/\(Int(SQSleepScoreBreakdown.maxArchitectureScore)).",
                effect: sleepEffect(for: adjustedScore)
            )
        case .healthKitAverage(let score, let durationHours, let nightCount):
            sourceItem = .init(
                id: "sleep-source-healthkit-average",
                title: "Source",
                valueText: "HealthKit average \(Int(score.rounded()))/100 across \(nightCount) night\(nightCount == 1 ? "" : "s")",
                summary: healthKitAverageSleepSummary(durationHours: durationHours),
                effect: sleepEffect(for: adjustedScore)
            )
        case .priorHealthKitLatest(let score, let durationHours):
            sourceItem = .init(
                id: "sleep-source-prior-healthkit",
                title: "Source",
                valueText: "Previous HealthKit Sleep Score \(Int(score.totalScore.rounded()))/100 • \(formattedHours(durationHours)) asleep",
                summary: "This prior-night value is only used to compare Life Score against yesterday, not to fill in today's missing sleep.",
                effect: sleepEffect(for: adjustedScore)
            )
        case .priorHealthKitAverage(let score, let durationHours, let nightCount):
            sourceItem = .init(
                id: "sleep-source-prior-healthkit-average",
                title: "Source",
                valueText: "Previous HealthKit average \(Int(score.rounded()))/100 across \(nightCount) night\(nightCount == 1 ? "" : "s")",
                summary: priorHealthKitAverageSleepSummary(durationHours: durationHours),
                effect: sleepEffect(for: adjustedScore)
            )
        }

        let adjustmentItem = SQLifeScoreDetailItem(
            id: "sleep-life-score-adjustment",
            title: "Life Score Adjustment",
            valueText: "Raw sleep \(rawScore)/100 -> Life Score sleep \(adjustedScore)/100",
            summary: sleepAdjustmentSummary(rawScore: rawScore, adjustedScore: adjustedScore, durationHours: input.durationHours),
            effect: sleepEffect(for: adjustedScore)
        )

        return [sourceItem, adjustmentItem]
    }

    func sleepCheckInSourceValueText(quality: Double?, hours: Double?) -> String {
        var parts = ["Daily Check-In"]
        if let quality {
            parts.append("Sleep Quality \(formattedDecimal(quality))/10")
        }
        if let hours {
            parts.append("Sleep Hours \(formattedHours(hours))")
        }
        return parts.joined(separator: " • ")
    }

    func sleepCheckInSourceSummary(quality: Double?, hours: Double?, rawScore: Int) -> String {
        if let quality, let hours {
            let qualityScore = Int((quality * 10).rounded())
            let durationScore = Int(sleepDurationScore(hours: hours).rounded())
            return "LifeIQ used Daily Check-In: sleep quality \(formattedDecimal(quality))/10 became \(qualityScore)/100, sleep hours \(formattedHours(hours)) became \(durationScore)/100, then 75% quality and 25% duration produced raw sleep \(rawScore)/100."
        }

        if let quality {
            let qualityScore = Int((quality * 10).rounded())
            return "LifeIQ used your Sleep Quality check-in as raw sleep \(qualityScore)/100 because sleep hours were not logged."
        }

        if let hours {
            let durationScore = Int(sleepDurationScore(hours: hours).rounded())
            return "LifeIQ used your Sleep Hours check-in as raw sleep \(durationScore)/100 because sleep quality was not logged."
        }

        return "LifeIQ used Daily Check-In sleep data as raw sleep \(rawScore)/100."
    }

    func healthKitAverageSleepSummary(durationHours: Double?) -> String {
        var summary = "LifeIQ used the average HealthKit sleep score for the selected completed-night window."
        if let durationHours {
            summary += " Average sleep was \(formattedHours(durationHours))."
        }
        return summary
    }

    func priorHealthKitAverageSleepSummary(durationHours: Double?) -> String {
        var summary = "This prior-window value is only used to compare Life Score against yesterday, not to fill in today's missing sleep."
        if let durationHours {
            summary += " Average sleep was \(formattedHours(durationHours))."
        }
        return summary
    }

    func sleepAdjustmentSummary(
        rawScore: Int,
        adjustedScore: Int,
        durationHours: Double?
    ) -> String {
        var summary = "Life Score is stricter than the dashboard Sleep Score, so sleep below 90 is pulled down before it affects the day."

        if let durationHours, durationHours < 7.25 {
            summary += " A short sleep duration added an extra penalty."
        }

        if adjustedScore < rawScore {
            summary += " That changed sleep's Life Score contribution by \(rawScore - adjustedScore) point\(rawScore - adjustedScore == 1 ? "" : "s")."
        }

        return summary
    }

    func sleepEffect(for score: Int) -> SQLifeScoreSignalEffect {
        if score >= 80 {
            return .positive
        }

        if score < 65 {
            return .negative
        }

        return .neutral
    }

    func adjustedLifeScoreSleepComponentScore(
        rawSleepScore: Double,
        durationHours: Double?
    ) -> Int {
        var adjustedScore = rawSleepScore

        if rawSleepScore < 90 {
            adjustedScore -= (90 - rawSleepScore) * 0.35
        }

        if let durationHours {
            switch durationHours {
            case ..<5.5:
                adjustedScore -= 18
            case ..<6.5:
                adjustedScore -= 11
            case ..<7.25:
                adjustedScore -= 5
            case 9.75...:
                adjustedScore -= 4
            default:
                break
            }
        }

        return Int(clamp(adjustedScore, min: 20, max: 98).rounded())
    }

    func sleepDurationScore(hours: Double) -> Double {
        if hours >= 7, hours <= 9 {
            return 100
        }

        if hours < 7 {
            return clamp(100 - ((7 - hours) * 18), min: 0, max: 100)
        }

        return clamp(100 - ((hours - 9) * 12), min: 0, max: 100)
    }

    func lifeScoreHeartComponent(
        from restingHeartRateSummaries: [SQHeartRateDailySummary],
        referenceDate: Date
    ) -> SQLifeScoreComponent? {
        let calendar = Calendar.current
        let startOfReferenceDay = calendar.startOfDay(for: referenceDate)
        let summaries = restingHeartRateSummaries
            .filter { $0.average != nil }
            .sorted { $0.date < $1.date }
            .filter { calendar.startOfDay(for: $0.date) <= startOfReferenceDay }

        guard let latestSummary = summaries.last,
              let latestAverage = latestSummary.average else {
            return nil
        }

        let daysSinceLatest = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: latestSummary.date),
            to: startOfReferenceDay
        ).day ?? 0
        guard daysSinceLatest <= 2 else { return nil }

        let recentSummaries = Array(summaries.suffix(2))
        let baselineSummaries = Array(summaries.dropLast(recentSummaries.count).suffix(7))

        guard recentSummaries.count >= 1,
              baselineSummaries.count >= 3,
              let recentAverage = recentSummaries.compactMap(\.average).average,
              let baselineAverage = baselineSummaries.compactMap(\.average).average else {
            return nil
        }

        let delta = recentAverage - baselineAverage
        let roundedScore = Int(clamp(78 - (delta * 8), min: 30, max: 95).rounded())

        let summary: String
        switch delta {
        case ...(-2):
            summary = "Resting HR is lower than usual and should be helping recovery."
        case ...1:
            summary = "Resting HR is close to your usual range and looks stable."
        case ...4:
            summary = "Resting HR is a bit elevated versus your usual range."
        default:
            summary = "Resting HR is elevated enough to drag recovery today."
        }

        return .init(
            id: "heart",
            title: "Heart",
            score: roundedScore,
            summary: summary,
            weight: 20,
            detailItems: [
                .init(
                    id: "resting-heart-rate",
                    title: "Resting HR",
                    valueText: "\(formattedWholeNumber(latestAverage)) bpm vs \(formattedWholeNumber(baselineAverage)) baseline",
                    summary: summary,
                    effect: delta <= 1 ? .positive : .negative
                )
            ]
        )
    }

    func lifeScoreHabitsComponent(
        from recentCheckIns: [SQDailyCheckInStats],
        metricDefinitions: [SQMetricDefinition],
        referenceDate: Date
    ) -> SQLifeScoreComponent? {
        let sevenDayValues = averagedMetricValues(from: recentCheckIns)
        let recentValues = weightedRecentMetricValues(
            from: recentCheckIns,
            referenceDate: referenceDate,
            maxDays: 2
        )
        guard !sevenDayValues.isEmpty || !recentValues.isEmpty else { return nil }

        let trackedDefinitions = metricDefinitions
            .filter { $0.isEnabled && !$0.isArchived }

        let scoredHabits = trackedDefinitions
            .filter { sevenDayValues[$0.id] != nil || recentValues[$0.id] != nil }
            .filter { $0.goalStyle != .justTrack && $0.goalStyle != .unknown }
            .compactMap { definition -> (definition: SQMetricDefinition, value: Double, score: Double, item: SQLifeScoreDetailItem)? in
                let sevenDayValue = sevenDayValues[definition.id]
                let recentValue = recentValues[definition.id]
                guard let baselineValue = sevenDayValue ?? recentValue,
                      let baselineScore = habitScore(for: baselineValue, definition: definition) else {
                    return nil
                }

                let recentScore = recentValue.flatMap { habitScore(for: $0, definition: definition) }
                let blendedScore = blendedHabitScore(
                    baselineScore: baselineScore,
                    recentScore: recentScore
                )
                let effect = habitEffect(for: recentValue ?? baselineValue, score: blendedScore, definition: definition)
                let valueText = habitValueText(
                    sevenDayValue: sevenDayValue,
                    recentValue: recentValue,
                    definition: definition
                )

                return (
                    definition: definition,
                    value: recentValue ?? baselineValue,
                    score: blendedScore,
                    item: .init(
                        id: definition.id,
                        title: definition.title,
                        valueText: valueText,
                        summary: habitScoreSummary(
                            sevenDayValue: sevenDayValue,
                            recentValue: recentValue,
                            score: blendedScore,
                            definition: definition
                        ),
                        effect: effect
                    )
                )
            }

        guard !scoredHabits.isEmpty else { return nil }
        let averageScore = scoredHabits.map(\.score).reduce(0, +) / Double(scoredHabits.count)
        let vicePenalty = recentVicePenalty(
            from: recentValues,
            trackedDefinitions: trackedDefinitions
        )
        let adjustedScore = averageScore - vicePenalty
        let roundedScore = Int(clamp(adjustedScore, min: 0, max: 100).rounded())

        let positiveCount = scoredHabits.filter { $0.item.effect == .positive }.count
        let negativeCount = scoredHabits.filter { $0.item.effect == .negative }.count

        let summary: String
        if vicePenalty >= 10 {
            summary = "Recent vice-heavy days are weighing on the score more than usual."
        } else if positiveCount > 0 && negativeCount > 0 {
            summary = "\(positiveCount) recent habits supported the score, while \(negativeCount) pulled it down."
        } else if positiveCount > 0 {
            summary = "Your recent goal-based habits are mostly supportive."
        } else if negativeCount > 0 {
            summary = "Several recent goal-based habits are dragging the score down."
        } else if roundedScore >= 45 {
            summary = "Your recent goal-based habits are mostly neutral."
        } else {
            summary = "Your recent habit signals are clearly weighing on the score."
        }

        return .init(
            id: "habits",
            title: "Habits",
            score: roundedScore,
            summary: summary,
            weight: 35,
            detailItems: scoredHabits
                .map(\.item)
                .sorted { lhs, rhs in
                    lifeScoreEffectPriority(lhs.effect) < lifeScoreEffectPriority(rhs.effect)
                }
        )
    }

    func blendedHabitScore(
        baselineScore: Double,
        recentScore: Double?
    ) -> Double {
        guard let recentScore else { return baselineScore }
        return (baselineScore * 0.45) + (recentScore * 0.55)
    }

    func weightedRecentMetricValues(
        from stats: [SQDailyCheckInStats],
        referenceDate: Date,
        maxDays: Int
    ) -> [String: Double] {
        let calendar = Calendar.current
        let startOfReferenceDay = calendar.startOfDay(for: referenceDate)
        var weightedValues: [String: [(value: Double, weight: Double)]] = [:]

        for stat in stats {
            let dayStart = calendar.startOfDay(for: stat.date)
            let dayOffset = calendar.dateComponents([.day], from: dayStart, to: startOfReferenceDay).day ?? maxDays
            guard dayOffset >= 0, dayOffset < maxDays else { continue }

            let weight: Double = dayOffset == 0 ? 1.0 : 0.7
            for (metricId, value) in stat.values {
                weightedValues[metricId, default: []].append((Double(value), weight))
            }
        }

        return weightedValues.reduce(into: [String: Double]()) { partialResult, pair in
            let totalWeight = pair.value.reduce(0) { $0 + $1.weight }
            guard totalWeight > 0 else { return }
            let weightedSum = pair.value.reduce(0) { $0 + ($1.value * $1.weight) }
            partialResult[pair.key] = weightedSum / totalWeight
        }
    }

    func recentVicePenalty(
        from recentValues: [String: Double],
        trackedDefinitions: [SQMetricDefinition]
    ) -> Double {
        let definitionsById = Dictionary(uniqueKeysWithValues: trackedDefinitions.map { ($0.id, $0) })

        let alcoholPenalty = recentValues[SQMetricId.alcohol].map {
            clamp($0 * 4.2, min: 0, max: 18)
        } ?? 0
        let caffeinePenalty = recentValues[SQMetricId.caffeine].map {
            clamp(($0 - 120.0) / 30.0, min: 0, max: 7)
        } ?? 0

        func normalizedPenalty(metricId: String, maxPenalty: Double) -> Double {
            guard let value = recentValues[metricId],
                  let definition = definitionsById[metricId],
                  let normalized = normalizedMetricValue(value, definition: definition) else {
                return 0
            }

            return clamp(normalized * maxPenalty, min: 0, max: maxPenalty)
        }

        let weedPenalty = normalizedPenalty(metricId: SQMetricId.weed, maxPenalty: 10)
        let nicotinePenalty = normalizedPenalty(metricId: SQMetricId.nicotine, maxPenalty: 9)
        let pornPenalty = normalizedPenalty(metricId: SQMetricId.porn, maxPenalty: 5)

        return clamp(
            alcoholPenalty + caffeinePenalty + weedPenalty + nicotinePenalty + pornPenalty,
            min: 0,
            max: 24
        )
    }

    func lifeScoreWorkoutComponent(
        todaysWorkouts: [SQWorkoutSessionable],
        lastWeekWorkouts: [SQWorkoutSessionable]
    ) -> SQLifeScoreComponent? {
        let activeWorkoutDays = Set(lastWeekWorkouts.compactMap { $0.startDate?.firebaseDailyDateKey }).count
        guard activeWorkoutDays > 0 || !todaysWorkouts.isEmpty else { return nil }
        let todayWorkoutBonus = todaysWorkouts.isEmpty ? 0.0 : 8.0
        let rawScore = (Double(activeWorkoutDays) / 4.0) * 100.0 + todayWorkoutBonus
        let roundedScore = Int(clamp(rawScore, min: 0, max: 100).rounded())

        let summary: String
        if todaysWorkouts.isEmpty {
            summary = "You trained on \(activeWorkoutDays) of the last 7 days."
        } else {
            summary = "You trained on \(activeWorkoutDays) of the last 7 days, including today."
        }

        return .init(
            id: "workouts",
            title: "Workouts",
            score: roundedScore,
            summary: summary,
            weight: 20,
            detailItems: []
        )
    }

    func lifeScoreConsistencyComponent(
        past7DaysCheckIns: [SQDailyCheckInStats],
        hasCompletedCurrentCheckIn: Bool,
        isLoggedIn: Bool
    ) -> SQLifeScoreComponent? {
        guard isLoggedIn else { return nil }

        let uniqueLoggedDays = Set(past7DaysCheckIns.map(\.uniqueDateKey)).count
        guard uniqueLoggedDays > 0 || hasCompletedCurrentCheckIn else { return nil }
        let baseScore = (Double(uniqueLoggedDays) / 5.0) * 100.0
        let completionBonus = hasCompletedCurrentCheckIn ? 10.0 : 0.0
        let roundedScore = Int(clamp(baseScore + completionBonus, min: 0, max: 100).rounded())

        let summary: String
        if hasCompletedCurrentCheckIn {
            summary = "You checked in on \(uniqueLoggedDays) of the last 7 days and you're current for today."
        } else {
            summary = "You checked in on \(uniqueLoggedDays) of the last 7 days, but today's prompt is still open."
        }

        return .init(
            id: "consistency",
            title: "Consistency",
            score: roundedScore,
            summary: summary,
            weight: 15,
            detailItems: []
        )
    }

    func averagedMetricValues(from stats: [SQDailyCheckInStats]) -> [String: Double] {
        var perDayValues: [String: [String: [Double]]] = [:]

        for stat in stats {
            let dayKey = stat.uniqueDateKey
            for (metricId, value) in stat.values {
                perDayValues[metricId, default: [:]][dayKey, default: []].append(Double(value))
            }
        }

        return perDayValues.reduce(into: [String: Double]()) { partialResult, pair in
            let metricId = pair.key
            let dailyValues = pair.value.values.compactMap { values -> Double? in
                guard !values.isEmpty else { return nil }
                return values.reduce(0, +) / Double(values.count)
            }

            guard !dailyValues.isEmpty else { return }
            partialResult[metricId] = dailyValues.reduce(0, +) / Double(dailyValues.count)
        }
    }

    func clamp(_ value: Double, min minimum: Double, max maximum: Double) -> Double {
        Swift.max(minimum, Swift.min(maximum, value))
    }

    func formattedWholeNumber(_ value: Double) -> String {
        String(Int(value.rounded()))
    }

    func formattedDecimal(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }

        return String(format: "%.1f", value)
    }

    func formattedHours(_ value: Double) -> String {
        "\(formattedDecimal(value))h"
    }

    func habitScore(for value: Double, definition: SQMetricDefinition) -> Double? {
        switch definition.goalStyle {
        case .buildUp:
            if let target = definition.targetValue, target > 0 {
                return clamp((value / Double(target)) * 100, min: 0, max: 100)
            }

            guard let normalized = normalizedMetricValue(value, definition: definition) else { return nil }
            return normalized * 100

        case .keepLow:
            if let target = definition.targetValue {
                return inverseScore(
                    value: value,
                    target: Double(target),
                    upperBound: keepLowUpperBound(for: definition, target: Double(target))
                )
            }

            guard let normalized = normalizedMetricValue(value, definition: definition) else { return nil }
            return (1 - normalized) * 100

        case .avoidIt:
            if value <= 0 {
                return 100
            }

            let upperBound = max(Double(definition.max ?? 0), 1)
            return clamp((1 - (value / upperBound)) * 100, min: 0, max: 100)

        case .stayInRange:
            guard
                let rangeMin = definition.targetRangeMin.map(Double.init),
                let rangeMax = definition.targetRangeMax.map(Double.init),
                rangeMax >= rangeMin
            else {
                return nil
            }

            if value >= rangeMin && value <= rangeMax {
                return 100
            }

            let distance: Double
            let toleranceSpan: Double
            if value < rangeMin {
                distance = rangeMin - value
                toleranceSpan = max(rangeMin - Double(definition.min ?? 0), rangeMax - rangeMin, 1)
            } else {
                distance = value - rangeMax
                toleranceSpan = max(Double(definition.max ?? Float(rangeMax)) - rangeMax, rangeMax - rangeMin, 1)
            }

            return clamp((1 - (distance / toleranceSpan)) * 100, min: 0, max: 100)

        case .justTrack, .unknown:
            return nil
        }
    }

    func inverseScore(value: Double, target: Double, upperBound: Double) -> Double {
        guard upperBound > target else {
            return value <= target ? 100 : 0
        }

        if value <= target {
            return 100
        }

        return clamp((1 - ((value - target) / (upperBound - target))) * 100, min: 0, max: 100)
    }

    func normalizedMetricValue(_ value: Double, definition: SQMetricDefinition) -> Double? {
        guard
            let min = definition.min.map(Double.init),
            let max = definition.max.map(Double.init),
            max > min
        else {
            return nil
        }

        return clamp((value - min) / (max - min), min: 0, max: 1)
    }

    func keepLowUpperBound(for definition: SQMetricDefinition, target: Double) -> Double {
        let maxValue = Double(definition.max ?? Float(target + 1))
        return max(maxValue, target + 1)
    }

    func formattedMetricValue(_ value: Double, definition: SQMetricDefinition) -> String {
        let raw = value == value.rounded() ? "\(Int(value))" : String(format: "%.1f", value)

        let unit = definition.quantityUnit
        let unitSuffix = unit.shortDisplayName
        if unit == .none || unit == .count || unit == .unknown {
            if definition.kind == .scale || definition.kind == .binary {
                let max = definition.scaleMaxValue
                return "\(raw)/\(Int(max))"
            }
            return raw
        }

        if unit == .percent {
            return "\(raw)%"
        }

        return "\(raw) \(unitSuffix)"
    }

    func habitValueText(
        sevenDayValue: Double?,
        recentValue: Double?,
        definition: SQMetricDefinition
    ) -> String {
        switch (sevenDayValue, recentValue) {
        case let (.some(sevenDayValue), .some(recentValue)):
            return "7d avg \(formattedMetricValue(sevenDayValue, definition: definition)) • recent \(formattedMetricValue(recentValue, definition: definition))"
        case let (.some(sevenDayValue), .none):
            return "7d avg \(formattedMetricValue(sevenDayValue, definition: definition))"
        case let (.none, .some(recentValue)):
            return "recent \(formattedMetricValue(recentValue, definition: definition))"
        case (.none, .none):
            return "Tracked"
        }
    }

    func habitScoreSummary(
        sevenDayValue: Double?,
        recentValue: Double?,
        score: Double,
        definition: SQMetricDefinition
    ) -> String {
        let comparisonValue = sevenDayValue ?? recentValue ?? 0

        switch definition.goalStyle {
        case .buildUp:
            if let target = definition.targetValue {
                return comparisonValue >= Double(target)
                    ? "Your 7-day average met or exceeded the target of \(formattedTarget(target, definition: definition))."
                    : "Your 7-day average stayed below the target of \(formattedTarget(target, definition: definition))."
            }
            return score >= 70
                ? "Your recent average is moving in a supportive direction."
                : "Your recent average still wants a higher range."

        case .keepLow:
            if let target = definition.targetValue {
                return comparisonValue <= Double(target)
                    ? "Your 7-day average stayed at or below the target of \(formattedTarget(target, definition: definition))."
                    : "Your 7-day average ran above the target of \(formattedTarget(target, definition: definition))."
            }
            return score >= 70
                ? "Your recent average stayed reasonably low."
                : "Your recent average has been running higher than ideal."

        case .avoidIt:
            if comparisonValue <= 0 {
                return "Your recent average stayed at zero, which is strongly supportive."
            }

            return score >= 55
                ? "Your recent average was above zero, so it slightly lowered this score."
                : "Your recent average was high enough to clearly lower this score."

        case .stayInRange:
            let minText = definition.targetRangeMin.map { formattedTarget($0, definition: definition) } ?? "?"
            let maxText = definition.targetRangeMax.map { formattedTarget($0, definition: definition) } ?? "?"
            return comparisonValue >= Double(definition.targetRangeMin ?? 0) && comparisonValue <= Double(definition.targetRangeMax ?? 0)
                ? "Your 7-day average stayed inside the target range of \(minText)-\(maxText)."
                : "Your 7-day average sat outside the target range of \(minText)-\(maxText)."

        case .justTrack, .unknown:
            return "Tracked for awareness."
        }
    }

    func habitEffect(for value: Double, score: Double, definition: SQMetricDefinition) -> SQLifeScoreSignalEffect {
        switch definition.goalStyle {
        case .buildUp:
            if let target = definition.targetValue, value >= Double(target) {
                return .positive
            }
            return habitEffect(forScore: score, positiveThreshold: 85, negativeThreshold: 50)

        case .keepLow:
            if let target = definition.targetValue, value <= Double(target) {
                return .positive
            }
            return score < 50 ? .negative : .neutral

        case .avoidIt:
            if value <= 0 {
                return .positive
            }
            return score < 55 ? .negative : .neutral

        case .stayInRange:
            if
                let rangeMin = definition.targetRangeMin.map(Double.init),
                let rangeMax = definition.targetRangeMax.map(Double.init),
                value >= rangeMin,
                value <= rangeMax
            {
                return .positive
            }
            return score < 60 ? .negative : .neutral

        case .justTrack, .unknown:
            return .neutral
        }
    }

    func habitEffect(
        forScore score: Double,
        positiveThreshold: Double,
        negativeThreshold: Double
    ) -> SQLifeScoreSignalEffect {
        if score >= positiveThreshold {
            return .positive
        }

        if score < negativeThreshold {
            return .negative
        }

        return .neutral
    }

    func formattedTarget(_ value: Float, definition: SQMetricDefinition) -> String {
        formattedMetricValue(Double(value), definition: definition)
    }

    func lifeScoreEffectPriority(_ effect: SQLifeScoreSignalEffect) -> Int {
        switch effect {
        case .positive:
            return 0
        case .negative:
            return 1
        case .neutral:
            return 2
        }
    }
}
