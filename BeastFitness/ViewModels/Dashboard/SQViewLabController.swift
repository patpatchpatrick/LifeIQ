//
//  SQViewLabController.swift
//  BeastFitness
//
//  Created by Codex on 4/24/26.
//

import Foundation
import HealthKit

@MainActor
@Observable final class SQViewLabController: Identifiable {
    enum Mode: String, CaseIterable, Identifiable {
        case gallery = "Gallery"
        case scenario = "Scenario"

        var id: String { rawValue }
    }

    enum Domain: String, CaseIterable, Identifiable {
        case lifeScoreInsights = "Life Score & Insights"

        var id: String { rawValue }

        var subtitle: String {
            switch self {
            case .lifeScoreInsights:
                return "Run shared scenario inputs through the real insight engine and Life Score builder, then preview the same production UI the dashboard uses."
            }
        }
    }

    struct Scenario: Identifiable {
        let id: String
        let domain: Domain
        let title: String
        let subtitle: String
        let tags: [String]
        let notes: [String]
        let content: Content
    }

    enum Content {
        case lifeScoreInsights(SQHealthIntelligenceInput)
    }

    let id = UUID().uuidString
    private let hub: EventHub
    private let scenarioRunner: SQViewLabScenarioRunning
    @ObservationIgnored private var runtimeCache = [String: SQViewLabScenarioRuntime]()

    var selectedMode: Mode = .gallery
    var selectedDomain: Domain = .lifeScoreInsights {
        didSet {
            guard selectedDomain != oldValue else { return }
            if !scenarios(for: selectedDomain).contains(where: { $0.id == selectedScenarioId }) {
                selectedScenarioId = scenarios(for: selectedDomain).first?.id ?? ""
            }
        }
    }
    var selectedScenarioId: String

    let scenarios: [Scenario]

    init(
        hub: EventHub? = nil,
        scenarioRunner: SQViewLabScenarioRunning? = nil,
        scenarios: [Scenario]? = nil
    ) {
        let resolvedScenarios = scenarios ?? Self.defaultScenarios()

        self.hub = hub ?? SQAppState.shared.hub
        self.scenarioRunner = scenarioRunner ?? SQViewLabScenarioRunner()
        self.scenarios = resolvedScenarios
        self.selectedScenarioId = resolvedScenarios.first?.id ?? ""
    }

    var currentScenarios: [Scenario] {
        scenarios(for: selectedDomain)
    }

    var selectedScenario: Scenario? {
        currentScenarios.first(where: { $0.id == selectedScenarioId }) ?? currentScenarios.first
    }

    var selectedScenarioRuntime: SQViewLabScenarioRuntime? {
        guard let selectedScenario else { return nil }
        return runtime(for: selectedScenario)
    }

    func scenarios(for domain: Domain) -> [Scenario] {
        scenarios.filter { $0.domain == domain }
    }

    func runtime(for scenario: Scenario) -> SQViewLabScenarioRuntime {
        if let cachedRuntime = runtimeCache[scenario.id] {
            return cachedRuntime
        }

        let runtime = scenarioRunner.runtime(for: scenario)
        runtimeCache[scenario.id] = runtime
        return runtime
    }

    func focus(on scenario: Scenario) {
        selectedDomain = scenario.domain
        selectedScenarioId = scenario.id
        selectedMode = .scenario
    }

    func openDetail(for runtime: SQViewLabScenarioRuntime) {
        switch runtime.content {
        case .lifeScoreInsights(let content):
            hub.domainEvents.send(.pushDashboardRoute(.lifeScoreDetail(controller: .init(viewModel: content.lifeScoreViewModel))))
        }
    }
}

private extension SQViewLabController {
    struct ScenarioDay {
        let offset: Int
        let morning: [String: Float]
        let evening: [String: Float]
    }

    struct WorkoutSpec {
        let offset: Int
        let activityType: HKWorkoutActivityType
        let performance: Float?
        let difficulty: Float?
        let startHour: Int
        let durationMinutes: Double
        let calories: Double
    }

    static func defaultScenarios() -> [Scenario] {
        let referenceDate = Calendar.current.startOfDay(for: .now)
        return [
            alignedSleepTailwindScenario(referenceDate: referenceDate),
            strainCatchUpScenario(referenceDate: referenceDate),
            heavyWeekendCarryoverScenario(referenceDate: referenceDate),
            energyMoodMismatchScenario(referenceDate: referenceDate),
            sparseCalibratingScenario(referenceDate: referenceDate),
            mixedSportNoiseScenario(referenceDate: referenceDate)
        ]
    }

    static func alignedSleepTailwindScenario(referenceDate: Date) -> Scenario {
        let metricDefinitions = defaultMetricDefinitions()
        let days = (0..<14).map { offset -> ScenarioDay in
            let variant = Float(offset % 3)
            return .init(
                offset: offset,
                morning: [
                    SQMetricId.sleepHours: 7.5 + variant * 0.2,
                    SQMetricId.sleepQuality: 7.8 + variant * 0.4,
                    SQMetricId.energy: 7.1 + variant * 0.3,
                    SQMetricId.mood: 6.7 + variant * 0.2
                ],
                evening: [
                    SQMetricId.alcohol: offset % 5 == 0 ? 1 : 0,
                    SQMetricId.caffeine: 110 + Float((offset % 2) * 20)
                ]
            )
        }

        let workouts = makeWorkouts(
            referenceDate: referenceDate,
            specs: [
                .init(offset: 0, activityType: .running, performance: 8.5, difficulty: 6.7, startHour: 7, durationMinutes: 48, calories: 520),
                .init(offset: 2, activityType: .running, performance: 8.1, difficulty: 6.4, startHour: 7, durationMinutes: 42, calories: 470),
                .init(offset: 4, activityType: .cycling, performance: 7.9, difficulty: 6.0, startHour: 8, durationMinutes: 55, calories: 430),
                .init(offset: 7, activityType: .running, performance: 8.3, difficulty: 6.5, startHour: 7, durationMinutes: 50, calories: 510),
                .init(offset: 10, activityType: .running, performance: 8.0, difficulty: 6.1, startHour: 7, durationMinutes: 45, calories: 480)
            ]
        )

        return .init(
            id: "aligned-sleep-tailwind",
            domain: .lifeScoreInsights,
            title: "Aligned Sleep Tailwind",
            subtitle: "A strong, readable state where sleep and recovery should clearly lead the day.",
            tags: ["Expected", "Balanced"],
            notes: [
                "Check that the hero stays anchored to sleep and recovery instead of drifting toward habits.",
                "Recent changes should still surface behavior or training shifts without duplicating the chips."
            ],
            content: .lifeScoreInsights(
                .init(
                    referenceDate: referenceDate,
                    timeRange: .today,
                    metricDefinitions: metricDefinitions,
                    checkIns: makeCheckIns(referenceDate: referenceDate, days: days, metricDefinitions: metricDefinitions),
                    workouts: workouts,
                    sleepData: makeSleepDashboardData(score: 88),
                    isLoggedIn: true
                )
            )
        )
    }

    static func strainCatchUpScenario(referenceDate: Date) -> Scenario {
        let metricDefinitions = defaultMetricDefinitions()
        let days = (0..<14).map { offset -> ScenarioDay in
            let recentDrop = offset <= 2 ? Float(2 - offset) : 0
            return .init(
                offset: offset,
                morning: [
                    SQMetricId.sleepHours: max(5.8, 7.1 - recentDrop * 0.5),
                    SQMetricId.sleepQuality: max(4.9, 7.0 - recentDrop * 0.8),
                    SQMetricId.energy: max(5.2, 6.8 - recentDrop * 0.5),
                    SQMetricId.mood: max(5.0, 6.5 - recentDrop * 0.4)
                ],
                evening: [
                    SQMetricId.alcohol: 0,
                    SQMetricId.caffeine: 140 + recentDrop * 80
                ]
            )
        }

        let workouts = makeWorkouts(
            referenceDate: referenceDate,
            specs: [
                .init(offset: 0, activityType: .running, performance: 6.0, difficulty: 8.1, startHour: 6, durationMinutes: 62, calories: 640),
                .init(offset: 1, activityType: .running, performance: 6.2, difficulty: 7.9, startHour: 6, durationMinutes: 58, calories: 610),
                .init(offset: 3, activityType: .running, performance: 7.3, difficulty: 7.1, startHour: 6, durationMinutes: 46, calories: 500),
                .init(offset: 6, activityType: .cycling, performance: 7.1, difficulty: 6.8, startHour: 7, durationMinutes: 52, calories: 440)
            ]
        )

        return .init(
            id: "strain-catching-up",
            domain: .lifeScoreInsights,
            title: "Strain Catching Up",
            subtitle: "Sleep debt and harder training should stack into a more cautionary briefing.",
            tags: ["Caution", "Training"],
            notes: [
                "The action should stay specific instead of sounding motivational.",
                "Use this to pressure test negative deltas, cautionary actions, and sleep-led drag states."
            ],
            content: .lifeScoreInsights(
                .init(
                    referenceDate: referenceDate,
                    timeRange: .today,
                    metricDefinitions: metricDefinitions,
                    checkIns: makeCheckIns(referenceDate: referenceDate, days: days, metricDefinitions: metricDefinitions),
                    workouts: workouts,
                    sleepData: makeSleepDashboardData(score: 63),
                    isLoggedIn: true
                )
            )
        )
    }

    static func heavyWeekendCarryoverScenario(referenceDate: Date) -> Scenario {
        let metricDefinitions = defaultMetricDefinitions()
        let days = (0..<14).map { offset -> ScenarioDay in
            let isWeekendCarryover = offset <= 2
            return .init(
                offset: offset,
                morning: [
                    SQMetricId.sleepHours: isWeekendCarryover ? 6.0 + Float(offset) * 0.1 : 7.2,
                    SQMetricId.sleepQuality: isWeekendCarryover ? 5.4 + Float(offset) * 0.3 : 7.1,
                    SQMetricId.energy: isWeekendCarryover ? 5.3 + Float(offset) * 0.2 : 6.8,
                    SQMetricId.mood: isWeekendCarryover ? 5.5 + Float(offset) * 0.2 : 6.6
                ],
                evening: [
                    SQMetricId.alcohol: isWeekendCarryover ? 3.5 - Float(offset) : 0.5,
                    SQMetricId.caffeine: isWeekendCarryover ? 180 : 120
                ]
            )
        }

        let workouts = makeWorkouts(
            referenceDate: referenceDate,
            specs: [
                .init(offset: 0, activityType: .running, performance: 6.4, difficulty: 7.0, startHour: 8, durationMinutes: 40, calories: 430),
                .init(offset: 4, activityType: .running, performance: 7.6, difficulty: 6.4, startHour: 7, durationMinutes: 44, calories: 470),
                .init(offset: 8, activityType: .walking, performance: 7.2, difficulty: 5.0, startHour: 18, durationMinutes: 36, calories: 230)
            ]
        )

        return .init(
            id: "heavy-weekend-carryover",
            domain: .lifeScoreInsights,
            title: "Heavy Weekend Carryover",
            subtitle: "Habit shifts should show up in recent changes while the hero stays outcome-focused.",
            tags: ["Habits", "Carryover"],
            notes: [
                "Recent behavior changes should explain the day without hijacking the hero chips.",
                "This is useful for tuning the line between habit-driven changes and outcome-driven drivers."
            ],
            content: .lifeScoreInsights(
                .init(
                    referenceDate: referenceDate,
                    timeRange: .today,
                    metricDefinitions: metricDefinitions,
                    checkIns: makeCheckIns(referenceDate: referenceDate, days: days, metricDefinitions: metricDefinitions),
                    workouts: workouts,
                    sleepData: makeSleepDashboardData(score: 60),
                    isLoggedIn: true
                )
            )
        )
    }

    static func energyMoodMismatchScenario(referenceDate: Date) -> Scenario {
        let metricDefinitions = defaultMetricDefinitions()
        let days = (0..<14).map { offset -> ScenarioDay in
            let recentLift: Float = offset <= 2 ? 0.8 : 0.2
            let sleepHours: Float = 7.0 + Float((offset + 1) % 2) * 0.2
            let sleepQuality: Float = 7.1 + Float((offset + 2) % 2) * 0.3
            let energy: Float = 6.8 + recentLift
            let mood: Float = offset <= 2 ? 5.5 : 6.4
            let alcohol: Float = offset <= 2 ? 0 : 0.7
            let caffeine: Float = offset <= 2 ? 180 : 120

            return .init(
                offset: offset,
                morning: [
                    SQMetricId.sleepHours: sleepHours,
                    SQMetricId.sleepQuality: sleepQuality,
                    SQMetricId.energy: energy,
                    SQMetricId.mood: mood
                ],
                evening: [
                    SQMetricId.alcohol: alcohol,
                    SQMetricId.caffeine: caffeine
                ]
            )
        }

        let workouts = makeWorkouts(
            referenceDate: referenceDate,
            specs: [
                .init(offset: 0, activityType: .cycling, performance: 7.4, difficulty: 6.1, startHour: 17, durationMinutes: 55, calories: 450),
                .init(offset: 3, activityType: .running, performance: 7.0, difficulty: 6.3, startHour: 7, durationMinutes: 42, calories: 460)
            ]
        )
        let checkIns = makeCheckIns(
            referenceDate: referenceDate,
            days: days,
            metricDefinitions: metricDefinitions
        )
        let scenarioInput = SQHealthIntelligenceInput(
            referenceDate: referenceDate,
            timeRange: .today,
            metricDefinitions: metricDefinitions,
            checkIns: checkIns,
            workouts: workouts,
            sleepData: makeSleepDashboardData(score: 79),
            isLoggedIn: true
        )

        return .init(
            id: "energy-mood-mismatch",
            domain: .lifeScoreInsights,
            title: "Energy Up, Mood Lagging",
            subtitle: "A deliberately weird state where some signals improve while others stay soft.",
            tags: ["Unexpected", "Mismatch"],
            notes: [
                "This should still feel coherent even when the user state is not cleanly positive or negative.",
                "Good for testing summary/action quality when no one theme is perfect."
            ],
            content: .lifeScoreInsights(scenarioInput)
        )
    }

    static func sparseCalibratingScenario(referenceDate: Date) -> Scenario {
        let metricDefinitions = defaultMetricDefinitions()
        let days = [
            ScenarioDay(
                offset: 0,
                morning: [
                    SQMetricId.sleepHours: 7.1,
                    SQMetricId.sleepQuality: 7.0,
                    SQMetricId.energy: 6.5,
                    SQMetricId.mood: 6.4
                ],
                evening: [:]
            ),
            ScenarioDay(
                offset: 2,
                morning: [
                    SQMetricId.sleepHours: 6.8,
                    SQMetricId.sleepQuality: 6.7,
                    SQMetricId.energy: 6.1,
                    SQMetricId.mood: 6.0
                ],
                evening: [
                    SQMetricId.caffeine: 130
                ]
            )
        ]

        return .init(
            id: "sparse-calibrating",
            domain: .lifeScoreInsights,
            title: "Sparse / Calibrating",
            subtitle: "A low-data state where the engines should stay honest without looking broken.",
            tags: ["Sparse Data", "Empty State"],
            notes: [
                "This is mainly for checking not-enough-data behavior.",
                "The hero and detail surfaces should still feel deliberate even when the engine has little signal."
            ],
            content: .lifeScoreInsights(
                .init(
                    referenceDate: referenceDate,
                    timeRange: .today,
                    metricDefinitions: metricDefinitions,
                    checkIns: makeCheckIns(referenceDate: referenceDate, days: days, metricDefinitions: metricDefinitions),
                    workouts: [],
                    sleepData: makeSleepDashboardData(score: 70),
                    isLoggedIn: true
                )
            )
        )
    }

    static func mixedSportNoiseScenario(referenceDate: Date) -> Scenario {
        let metricDefinitions = defaultMetricDefinitions()
        let days = (0..<14).map { offset -> ScenarioDay in
            return .init(
                offset: offset,
                morning: [
                    SQMetricId.sleepHours: 7.0 + Float((offset + 1) % 3) * 0.1,
                    SQMetricId.sleepQuality: 6.8 + Float((offset + 2) % 3) * 0.2,
                    SQMetricId.energy: 6.6 + Float(offset % 2) * 0.2,
                    SQMetricId.mood: offset <= 1 ? 5.8 : 6.5
                ],
                evening: [
                    SQMetricId.alcohol: 0.4,
                    SQMetricId.caffeine: 120
                ]
            )
        }

        let workouts = makeWorkouts(
            referenceDate: referenceDate,
            specs: [
                .init(offset: 0, activityType: .pickleball, performance: 6.1, difficulty: 6.8, startHour: 18, durationMinutes: 70, calories: 500),
                .init(offset: 1, activityType: .cycling, performance: 7.9, difficulty: 6.3, startHour: 7, durationMinutes: 60, calories: 450),
                .init(offset: 3, activityType: .pickleball, performance: 6.3, difficulty: 6.6, startHour: 18, durationMinutes: 65, calories: 470),
                .init(offset: 5, activityType: .cycling, performance: 8.1, difficulty: 6.2, startHour: 7, durationMinutes: 58, calories: 440),
                .init(offset: 8, activityType: .running, performance: 7.2, difficulty: 6.4, startHour: 7, durationMinutes: 40, calories: 420)
            ]
        )

        return .init(
            id: "mixed-sport-noise",
            domain: .lifeScoreInsights,
            title: "Mixed-Sport Noise",
            subtitle: "A weird week where sport-specific performance does not tell one clean story.",
            tags: ["Unexpected", "Mixed Sport"],
            notes: [
                "Use this to make sure same-sport workout comparisons stay sane.",
                "Recent changes can surface sport-specific performance without forcing those exact labels into the hero."
            ],
            content: .lifeScoreInsights(
                .init(
                    referenceDate: referenceDate,
                    timeRange: .today,
                    metricDefinitions: metricDefinitions,
                    checkIns: makeCheckIns(referenceDate: referenceDate, days: days, metricDefinitions: metricDefinitions),
                    workouts: workouts,
                    sleepData: makeSleepDashboardData(score: 76),
                    isLoggedIn: true
                )
            )
        )
    }

    static func defaultMetricDefinitions() -> [SQMetricDefinition] {
        [
            .init(
                id: SQMetricId.mood,
                title: "Mood",
                kind: .scale,
                unit: .none,
                group: SQDefaultGroup.self_.rawValue,
                min: 0,
                max: 10,
                step: 1,
                isPreset: true,
                isEnabled: true,
                isDefault: true,
                sortOrder: 0,
                periods: [.morning, .evening],
                goalStyle: .justTrack
            ),
            .init(
                id: SQMetricId.energy,
                title: "Energy Level",
                kind: .scale,
                unit: .none,
                group: SQDefaultGroup.self_.rawValue,
                min: 0,
                max: 10,
                step: 1,
                isPreset: true,
                isEnabled: true,
                isDefault: true,
                sortOrder: 1,
                periods: [.morning, .evening],
                goalStyle: .justTrack,
                bodyBatteryEffect: .boostsWhenHigh
            ),
            .init(
                id: SQMetricId.sleepQuality,
                title: "Sleep Quality",
                kind: .scale,
                unit: .none,
                group: SQDefaultGroup.sleep.rawValue,
                min: 0,
                max: 10,
                step: 1,
                isPreset: true,
                isEnabled: true,
                isDefault: false,
                sortOrder: 2,
                periods: [.morning, .evening],
                isSingleDailyValue: true,
                goalStyle: .justTrack
            ),
            .init(
                id: SQMetricId.sleepHours,
                title: "Sleep Duration",
                kind: .number,
                unit: .hours,
                group: SQDefaultGroup.sleep.rawValue,
                min: 0,
                max: 24,
                step: 0.1,
                isPreset: true,
                isEnabled: true,
                isDefault: false,
                sortOrder: 3,
                periods: [.morning, .evening],
                isSingleDailyValue: true,
                goalStyle: .justTrack
            ),
            .init(
                id: SQMetricId.alcohol,
                title: "Alcohol",
                kind: .number,
                unit: .count,
                group: SQDefaultGroup.vices.rawValue,
                min: 0,
                max: 10,
                step: 0.1,
                isPreset: true,
                isEnabled: true,
                isDefault: true,
                sortOrder: 4,
                periods: [.morning, .evening],
                isSingleDailyValue: true,
                goalStyle: .avoidIt,
                bodyBatteryEffect: .drainsWhenHigh,
                scaleQuantityMapping: .init(quantityUnit: .count, maxQuantityValue: 10, quantityLabelOverride: "drink count")
            ),
            .init(
                id: SQMetricId.caffeine,
                title: "Caffeine",
                kind: .number,
                unit: .milligrams,
                group: SQDefaultGroup.vices.rawValue,
                min: 0,
                max: 1000,
                step: 0.1,
                isPreset: true,
                isEnabled: true,
                isDefault: true,
                sortOrder: 5,
                periods: [.morning, .evening],
                isSingleDailyValue: true,
                goalStyle: .avoidIt,
                bodyBatteryEffect: .drainsWhenHigh,
                scaleQuantityMapping: .init(quantityUnit: .milligrams, maxQuantityValue: 200)
            )
        ]
    }

    static func makeCheckIns(
        referenceDate: Date,
        days: [ScenarioDay],
        metricDefinitions: [SQMetricDefinition]
    ) -> [SQDailyCheckInStats] {
        let definitionsById = Dictionary(uniqueKeysWithValues: metricDefinitions.map { ($0.id, $0) })
        let calendar = Calendar.current
        let startOfReferenceDay = calendar.startOfDay(for: referenceDate)

        return days.flatMap { day in
            let targetDay = calendar.date(byAdding: .day, value: -day.offset, to: startOfReferenceDay) ?? startOfReferenceDay
            var entries = [SQDailyCheckInStats]()

            if !day.morning.isEmpty {
                let morningDate = calendar.date(byAdding: .hour, value: 8, to: targetDay) ?? targetDay
                entries.append(
                    makeCheckIn(
                        date: morningDate,
                        period: .morning,
                        values: day.morning,
                        definitionsById: definitionsById
                    )
                )
            }

            if !day.evening.isEmpty {
                let eveningDate = calendar.date(byAdding: .hour, value: 20, to: targetDay) ?? targetDay
                entries.append(
                    makeCheckIn(
                        date: eveningDate,
                        period: .evening,
                        values: day.evening,
                        definitionsById: definitionsById
                    )
                )
            }

            return entries
        }
        .sorted { $0.date < $1.date }
    }

    static func makeCheckIn(
        date: Date,
        period: SQMetricPeriod,
        values: [String: Float],
        definitionsById: [String: SQMetricDefinition]
    ) -> SQDailyCheckInStats {
        let metricValues = values.reduce(into: [String: SQMetricLoggedValue]()) { partialResult, pair in
            guard let definition = definitionsById[pair.key] else { return }
            let mode: SQMetricValueMode = definition.kind == .number ? .quantity : .scale
            partialResult[pair.key] = SQMetricEntry.loggedValue(
                rawValue: pair.value,
                enteredMode: mode,
                definition: definition
            )
        }

        return .init(
            date: date,
            period: period,
            values: values,
            metricValues: metricValues,
            notes: nil
        )
    }

    static func makeWorkouts(
        referenceDate: Date,
        specs: [WorkoutSpec]
    ) -> [SQWorkoutSessionable] {
        let calendar = Calendar.current
        let startOfReferenceDay = calendar.startOfDay(for: referenceDate)

        return specs.map { spec in
            let targetDay = calendar.date(byAdding: .day, value: -spec.offset, to: startOfReferenceDay) ?? startOfReferenceDay
            let startDate = calendar.date(byAdding: .hour, value: spec.startHour, to: targetDay) ?? targetDay
            let endDate = startDate.addingTimeInterval(spec.durationMinutes * 60)

            let manualWorkout = SQManualWorkout(
                sourceId: "lab-\(spec.activityType.rawValue)-\(spec.offset)-\(spec.startHour)",
                activityType: spec.activityType,
                device: SQWorkoutDevice(name: "View Lab"),
                startDate: startDate,
                endDate: endDate,
                activeDuration: spec.durationMinutes * 60,
                averageHeartRate: 142,
                totalCalories: spec.calories,
                details: nil
            )

            let session = SQWorkoutSession(
                id: manualWorkout.sourceId,
                workoutSource: .manual(manualWorkout),
                overrideData: nil,
                hkWorkoutId: nil
            )
            session.setReviewData(
                notes: nil,
                ratingUserPerformance: spec.performance,
                ratingDifficulty: spec.difficulty,
                temperature: nil
            )
            return session
        }
    }

    static func makeSleepDashboardData(score: Double) -> SQSleepDashboardData {
        let clamped = max(0, min(100, score))
        let breakdown = SQSleepScoreBreakdown(
            durationScore: min(clamped * 0.40, SQSleepScoreBreakdown.maxDurationScore),
            efficiencyScore: min(clamped * 0.25, SQSleepScoreBreakdown.maxEfficiencyScore),
            fragmentationScore: min(clamped * 0.20, SQSleepScoreBreakdown.maxFragmentationScore),
            architectureScore: min(clamped * 0.15, SQSleepScoreBreakdown.maxArchitectureScore)
        )

        return .init(
            currentNights: [],
            priorNights: [],
            latestNight: nil,
            averageScore: breakdown,
            phaseAggregates: []
        )
    }
}
