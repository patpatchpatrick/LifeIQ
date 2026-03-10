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
            max(0, (durationHours / 7.75) * SQSleepScoreBreakdown.maxDurationScore)
        )

        let bedtimeScore = bedtimeScoreFor(startDate: night.sleepStartDate)

        let awakeMinutes = night.phaseDuration(for: .awake) / 60.0
        let awakeSegments = night.segments.filter { $0.phase == .awake }.count
        let interruptionsPenalty = Double(max(awakeSegments - 1, 0)) * 1.2
        let awakePenalty = awakeMinutes * 0.05
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

    private func bedtimeScoreFor(startDate: Date) -> Double {
        let components = calendar.dateComponents([.hour, .minute], from: startDate)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0

        // Represent post-midnight bedtimes as continuation of previous night.
        var bedtimeMinutes = hour * 60 + minute
        if bedtimeMinutes < 12 * 60 {
            bedtimeMinutes += 24 * 60
        }

        let idealStart = 22 * 60            // 10:00 PM
        let idealEnd = 26 * 60              // 2:00 AM
        let toleranceEarly = 20 * 60        // 8:00 PM
        let toleranceLate = 29 * 60         // 5:00 AM

        if bedtimeMinutes >= idealStart && bedtimeMinutes <= idealEnd {
            return SQSleepScoreBreakdown.maxBedtimeScore
        }

        if bedtimeMinutes < idealStart {
            let span = Double(idealStart - toleranceEarly)
            let progress = Double(bedtimeMinutes - toleranceEarly) / max(1, span)
            return max(0, min(1, progress)) * SQSleepScoreBreakdown.maxBedtimeScore
        }

        let span = Double(toleranceLate - idealEnd)
        let progress = Double(toleranceLate - bedtimeMinutes) / max(1, span)
        return max(0, min(1, progress)) * SQSleepScoreBreakdown.maxBedtimeScore
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

private extension Array where Element == Double {
    var average: Double {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Double(count)
    }
}
