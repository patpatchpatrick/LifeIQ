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
            durationScore: scores.map(\.durationScore).average ?? 0,
            efficiencyScore: scores.map(\.efficiencyScore).average ?? 0,
            fragmentationScore: scores.map(\.fragmentationScore).average ?? 0,
            architectureScore: scores.map(\.architectureScore).average ?? 0
        )

        let phaseAggregates = SQSleepPhase.allCases.map { phase in
            let currentDurations = currentNights.map { $0.phaseDuration(for: phase) }
            let priorDurations = priorNights.map { $0.phaseDuration(for: phase) }

            return SQSleepPhaseAggregate(
                phase: phase,
                averageDuration: currentDurations.average ?? 0,
                priorAverageDuration: priorDurations.average,
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

        let efficiencyScore = efficiencyScore(for: night)
        let architectureScore = architectureScore(for: night)

        let awakeMinutes = night.phaseDuration(for: .awake) / 60.0
        let awakeSegments = night.segments.filter { $0.phase == .awake }.count
        let interruptionsPenalty = Double(max(awakeSegments - 1, 0)) * 1.2
        let awakePenalty = awakeMinutes * 0.05
        let fragmentationScore = max(
            0,
            SQSleepScoreBreakdown.maxFragmentationScore - interruptionsPenalty - awakePenalty
        )

        return SQSleepScoreBreakdown(
            durationScore: durationScore,
            efficiencyScore: efficiencyScore,
            fragmentationScore: fragmentationScore,
            architectureScore: architectureScore
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

            guard let primaryBlockInterval = primarySleepBlockInterval(
                from: clippedSegments,
                wakeDay: wakeDay
            ) else {
                return nil
            }

            let primaryBlockSegments = clippedSegments.compactMap { segment -> SQSleepStageSegment? in
                let overlapStart = max(segment.startDate, primaryBlockInterval.start)
                let overlapEnd = min(segment.endDate, primaryBlockInterval.end)
                guard overlapEnd > overlapStart else { return nil }
                return .init(phase: segment.phase, startDate: overlapStart, endDate: overlapEnd)
            }
            .sorted(by: { $0.startDate < $1.startDate })

            guard !primaryBlockSegments.isEmpty else { return nil }

            let totalSleep = primaryBlockSegments
                .filter { $0.phase != .awake }
                .reduce(0) { $0 + $1.duration }
            guard totalSleep >= 30 * 60 else { return nil }

            let sleepStartDate = primaryBlockSegments.first(where: { $0.phase != .awake })?.startDate
                ?? primaryBlockSegments.first?.startDate
                ?? nightStart
            let wakeDate = primaryBlockSegments.last?.endDate ?? nightEnd

            return SQSleepNight(
                wakeDay: wakeDay,
                sleepStartDate: sleepStartDate,
                wakeDate: wakeDate,
                segments: primaryBlockSegments
            )
        }
        .sorted(by: { $0.wakeDay < $1.wakeDay })
    }

    private func primarySleepBlockInterval(
        from segments: [SQSleepStageSegment],
        wakeDay: Date
    ) -> DateInterval? {
        let nonAwakeSegments = segments
            .filter { $0.phase != .awake }
            .sorted(by: { $0.startDate < $1.startDate })

        guard !nonAwakeSegments.isEmpty else { return nil }

        // Bridge brief wake/gap periods so one fragmented night remains one block.
        let maxBridgeGap: TimeInterval = 75 * 60

        struct SleepBlock {
            var start: Date
            var end: Date
            var sleepDuration: TimeInterval
        }

        var blocks = [SleepBlock]()
        var currentBlock = SleepBlock(
            start: nonAwakeSegments[0].startDate,
            end: nonAwakeSegments[0].endDate,
            sleepDuration: nonAwakeSegments[0].duration
        )

        for segment in nonAwakeSegments.dropFirst() {
            let gap = segment.startDate.timeIntervalSince(currentBlock.end)
            if gap <= maxBridgeGap {
                currentBlock.end = max(currentBlock.end, segment.endDate)
                currentBlock.sleepDuration += segment.duration
            } else {
                blocks.append(currentBlock)
                currentBlock = SleepBlock(
                    start: segment.startDate,
                    end: segment.endDate,
                    sleepDuration: segment.duration
                )
            }
        }
        blocks.append(currentBlock)

        let wakeDayStart = calendar.startOfDay(for: wakeDay)
        let overnightStartCutoff = calendar.date(byAdding: .hour, value: 5, to: wakeDayStart) ?? wakeDayStart
        let overnightBlocks = blocks.filter { $0.start < overnightStartCutoff }

        // Treat daytime/morning-only blocks as naps/incomplete tracking, not a full night.
        guard !overnightBlocks.isEmpty else {
            return nil
        }

        guard let bestBlock = overnightBlocks.max(by: { $0.sleepDuration < $1.sleepDuration }) else {
            return nil
        }

        return DateInterval(start: bestBlock.start, end: bestBlock.end)
    }

    private func efficiencyScore(for night: SQSleepNight) -> Double {
        let timeInBed = night.timeInBedDuration
        guard timeInBed > 0 else { return 0 }

        let efficiency = night.totalSleepDuration / timeInBed
        let normalizedEfficiency = (efficiency - 0.72) / 0.20

        return max(0, min(1, normalizedEfficiency)) * SQSleepScoreBreakdown.maxEfficiencyScore
    }

    private func architectureScore(for night: SQSleepNight) -> Double {
        let totalSleep = night.totalSleepDuration
        guard totalSleep > 0 else { return 0 }

        let remShare = night.phaseDuration(for: .rem) / totalSleep
        let deepShare = night.phaseDuration(for: .deep) / totalSleep

        let remFit = normalizedRangeFit(value: remShare, target: 0.24, tolerance: 0.12)
        let deepFit = normalizedRangeFit(value: deepShare, target: 0.16, tolerance: 0.10)
        let blendedFit = (remFit * 0.55) + (deepFit * 0.45)

        return blendedFit * SQSleepScoreBreakdown.maxArchitectureScore
    }

    private func normalizedRangeFit(value: Double, target: Double, tolerance: Double) -> Double {
        guard tolerance > 0 else { return 0 }
        let deviation = abs(value - target)
        return max(0, min(1, 1 - (deviation / tolerance)))
    }

    private func latestCompletedWakeDay(now: Date) -> Date {
        let startOfToday = calendar.startOfDay(for: now)
        let hour = calendar.component(.hour, from: now)

        // Use today's wake day once we're past early-morning hours so
        // the dashboard reflects the just-completed night after waking.
        if hour < 4 {
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
        // A wake day's sleep should come from the prior evening/night, not the prior morning.
        // Starting at 6 PM previous day avoids attributing yesterday-morning sleep to today's wake day.
        return calendar.date(byAdding: .hour, value: -6, to: dayStart) ?? dayStart
    }

    private func nightWindowEnd(for wakeDay: Date) -> Date {
        let dayStart = calendar.startOfDay(for: wakeDay)
        return calendar.date(byAdding: .hour, value: 12, to: dayStart) ?? dayStart
    }
}
