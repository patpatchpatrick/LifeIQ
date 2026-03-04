//
//  SQSleepModels.swift
//  BeastFitness
//

import Foundation

enum SQSleepPhase: String, CaseIterable, Sendable {
    case awake
    case rem
    case core
    case deep

    var title: String {
        switch self {
        case .awake: return "Awake"
        case .rem: return "REM"
        case .core: return "Core"
        case .deep: return "Deep"
        }
    }
}

struct SQSleepStageSegment: Identifiable, Sendable {
    let id: String
    let phase: SQSleepPhase
    let startDate: Date
    let endDate: Date

    var duration: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }

    init(phase: SQSleepPhase, startDate: Date, endDate: Date, id: String? = nil) {
        self.id = id ?? "\(phase.rawValue)-\(startDate.timeIntervalSince1970)-\(endDate.timeIntervalSince1970)"
        self.phase = phase
        self.startDate = startDate
        self.endDate = endDate
    }
}

struct SQSleepNight: Identifiable, Sendable {
    let id: String
    /// The calendar day this night ended on (wake day).
    let wakeDay: Date
    let sleepStartDate: Date
    let wakeDate: Date
    let segments: [SQSleepStageSegment]

    var totalSleepDuration: TimeInterval {
        phaseDuration(for: .rem) + phaseDuration(for: .core) + phaseDuration(for: .deep)
    }

    func phaseDuration(for phase: SQSleepPhase) -> TimeInterval {
        segments
            .filter { $0.phase == phase }
            .reduce(0) { $0 + $1.duration }
    }

    init(wakeDay: Date, sleepStartDate: Date, wakeDate: Date, segments: [SQSleepStageSegment]) {
        self.wakeDay = wakeDay
        self.sleepStartDate = sleepStartDate
        self.wakeDate = wakeDate
        self.segments = segments.sorted(by: { $0.startDate < $1.startDate })
        self.id = "night-\(wakeDay.timeIntervalSince1970)"
    }
}

struct SQSleepScoreBreakdown: Sendable {
    static let maxDurationScore = 50.0
    static let maxBedtimeScore = 30.0
    static let maxInterruptionsScore = 20.0

    let durationScore: Double
    let bedtimeScore: Double
    let interruptionsScore: Double

    var totalScore: Double {
        durationScore + bedtimeScore + interruptionsScore
    }
}

struct SQSleepPhaseAggregate: Sendable {
    let phase: SQSleepPhase
    let averageDuration: TimeInterval
    let priorAverageDuration: TimeInterval?
    let sparklineDataHours: [Double]

    var changePercent: Double {
        guard let priorAverageDuration, priorAverageDuration > 0 else { return 0 }
        return (averageDuration - priorAverageDuration) / priorAverageDuration
    }
}

struct SQSleepDashboardData: Sendable {
    let currentNights: [SQSleepNight]
    let priorNights: [SQSleepNight]
    let latestNight: SQSleepNight?
    let averageScore: SQSleepScoreBreakdown?
    let phaseAggregates: [SQSleepPhaseAggregate]
}
