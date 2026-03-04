//
//  SQSleepAggregationService.swift
//  BeastFitness
//

import Foundation

struct SQSleepDashboardWindow {
    let currentWakeDays: [Date]
    let priorWakeDays: [Date]
    let fetchStartDate: Date
    let fetchEndDate: Date
}

struct SQSleepAggregationService {
    private let calendar = Calendar.current

    func makeDashboardWindow(for timeRange: AppTimeRange, now: Date = .now) -> SQSleepDashboardWindow {
        let anchorWakeDay = latestCompletedWakeDay(now: now)
        let currentCount = nightCount(for: timeRange)

        let currentWakeDays = (0..<currentCount).compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: anchorWakeDay)
        }.sorted()

        let priorWakeDays: [Date]
        switch timeRange {
        case .allTime:
            priorWakeDays = []
        case .today:
            priorWakeDays = (1...7).compactMap { offset in
                calendar.date(byAdding: .day, value: -offset, to: anchorWakeDay)
            }.sorted()
        default:
            priorWakeDays = (currentCount..<(currentCount * 2)).compactMap { offset in
                calendar.date(byAdding: .day, value: -offset, to: anchorWakeDay)
            }.sorted()
        }

        let allWakeDays = (currentWakeDays + priorWakeDays).sorted()
        let earliestWakeDay = allWakeDays.first ?? anchorWakeDay
        let latestWakeDay = allWakeDays.last ?? anchorWakeDay

        let fetchStartDate = nightWindowStart(for: earliestWakeDay)
        let fetchEndDate = nightWindowEnd(for: latestWakeDay)

        return SQSleepDashboardWindow(
            currentWakeDays: currentWakeDays,
            priorWakeDays: priorWakeDays,
            fetchStartDate: fetchStartDate,
            fetchEndDate: fetchEndDate
        )
    }

    func buildDashboardData(
        segments: [SQSleepStageSegment],
        window: SQSleepDashboardWindow
    ) -> SQSleepDashboardData {
        let currentNights = buildNights(for: window.currentWakeDays, using: segments)
        let priorNights = buildNights(for: window.priorWakeDays, using: segments)

        let latestNight = currentNights.sorted(by: { $0.wakeDay > $1.wakeDay }).first
        let scores = currentNights.map(score(for:))
        let averageScore: SQSleepScoreBreakdown? = scores.isEmpty ? nil : .init(
            durationScore: scores.map(\.durationScore).average,
            bedtimeScore: scores.map(\.bedtimeScore).average,
            interruptionsScore: scores.map(\.interruptionsScore).average
        )

        let phaseAggregates = SQSleepPhase.allCases.map { phase in
            let currentDurations = currentNights.map { $0.phaseDuration(for: phase) }
            let priorDurations = priorNights.map { $0.phaseDuration(for: phase) }

            return SQSleepPhaseAggregate(
                phase: phase,
                averageDuration: currentDurations.average,
                priorAverageDuration: priorDurations.isEmpty ? nil : priorDurations.average,
                sparklineDataHours: currentDurations.map { $0 / 3600.0 }
            )
        }

        return SQSleepDashboardData(
            currentNights: currentNights,
            priorNights: priorNights,
            latestNight: latestNight,
            averageScore: averageScore,
            phaseAggregates: phaseAggregates
        )
    }

    func score(for night: SQSleepNight) -> SQSleepScoreBreakdown {
        let durationHours = night.totalSleepDuration / 3600.0
        let durationScore = min(
            SQSleepScoreBreakdown.maxDurationScore,
            max(0, (durationHours / 8.0) * SQSleepScoreBreakdown.maxDurationScore)
        )

        let bedtimeScore = bedtimeScoreFor(startDate: night.sleepStartDate)

        let awakeMinutes = night.phaseDuration(for: .awake) / 60.0
        let awakeSegments = night.segments.filter { $0.phase == .awake }.count
        let interruptionsPenalty = Double(max(awakeSegments - 1, 0)) * 2.5
        let awakePenalty = awakeMinutes * 0.2
        let interruptionsScore = max(
            0,
            SQSleepScoreBreakdown.maxInterruptionsScore - interruptionsPenalty - awakePenalty
        )

        return SQSleepScoreBreakdown(
            durationScore: durationScore,
            bedtimeScore: bedtimeScore,
            interruptionsScore: interruptionsScore
        )
    }

    private func buildNights(
        for wakeDays: [Date],
        using segments: [SQSleepStageSegment]
    ) -> [SQSleepNight] {
        wakeDays.compactMap { wakeDay in
            let nightStart = nightWindowStart(for: wakeDay)
            let nightEnd = nightWindowEnd(for: wakeDay)

            let clippedSegments = segments.compactMap { segment -> SQSleepStageSegment? in
                let overlapStart = max(segment.startDate, nightStart)
                let overlapEnd = min(segment.endDate, nightEnd)
                guard overlapEnd > overlapStart else { return nil }
                return .init(phase: segment.phase, startDate: overlapStart, endDate: overlapEnd)
            }
            .sorted(by: { $0.startDate < $1.startDate })

            guard !clippedSegments.isEmpty else { return nil }

            // Ignore very short or likely nap-like nights.
            let totalSleep = clippedSegments
                .filter { $0.phase != .awake }
                .reduce(0) { $0 + $1.duration }
            guard totalSleep >= 30 * 60 else { return nil }

            let sleepStartDate = clippedSegments.first(where: { $0.phase != .awake })?.startDate
                ?? clippedSegments.first?.startDate
                ?? nightStart
            let wakeDate = clippedSegments.last?.endDate ?? nightEnd

            return SQSleepNight(
                wakeDay: wakeDay,
                sleepStartDate: sleepStartDate,
                wakeDate: wakeDate,
                segments: clippedSegments
            )
        }
        .sorted(by: { $0.wakeDay < $1.wakeDay })
    }

    private func bedtimeScoreFor(startDate: Date) -> Double {
        // Target bedtime: 10:30 PM local time.
        let targetMinutes = 22 * 60 + 30
        let components = calendar.dateComponents([.hour, .minute], from: startDate)
        let actualMinutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)

        var diff = abs(actualMinutes - targetMinutes)
        diff = min(diff, 1440 - diff)

        let maxDeviation = 180.0
        let normalized = max(0, 1 - (Double(diff) / maxDeviation))

        return normalized * SQSleepScoreBreakdown.maxBedtimeScore
    }

    private func latestCompletedWakeDay(now: Date) -> Date {
        let startOfToday = calendar.startOfDay(for: now)
        let hour = calendar.component(.hour, from: now)

        if hour < 12 {
            return calendar.date(byAdding: .day, value: -1, to: startOfToday) ?? startOfToday
        }

        return startOfToday
    }

    private func nightCount(for range: AppTimeRange) -> Int {
        switch range {
        case .today: return 1
        case .pastSevenDays: return 7
        case .past30Days: return 30
        case .pastYear: return 365
        case .allTime: return 3650
        }
    }

    private func nightWindowStart(for wakeDay: Date) -> Date {
        let dayStart = calendar.startOfDay(for: wakeDay)
        return calendar.date(byAdding: .hour, value: -18, to: dayStart) ?? dayStart
    }

    private func nightWindowEnd(for wakeDay: Date) -> Date {
        let dayStart = calendar.startOfDay(for: wakeDay)
        return calendar.date(byAdding: .hour, value: 12, to: dayStart) ?? dayStart
    }
}

private extension Array where Element == Double {
    var average: Double {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Double(count)
    }
}
