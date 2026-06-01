//
//  SQHeartRateService.swift
//  BeastFitness
//

import Foundation
import HealthKit
import BeastFitnessCore
import CoolCharts

enum SQHeartRateZone: Int, CaseIterable, Identifiable, Sendable {
    case zone1
    case zone2
    case zone3
    case zone4
    case zone5

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .zone1: return "Zone 1"
        case .zone2: return "Zone 2"
        case .zone3: return "Zone 3"
        case .zone4: return "Zone 4"
        case .zone5: return "Zone 5"
        }
    }

    var subtitle: String {
        switch self {
        case .zone1: return "Recovery"
        case .zone2: return "Aerobic"
        case .zone3: return "Tempo"
        case .zone4: return "Threshold"
        case .zone5: return "Peak"
        }
    }

    var lowerPercentOfMax: Double {
        switch self {
        case .zone1: return 0.50
        case .zone2: return 0.60
        case .zone3: return 0.70
        case .zone4: return 0.80
        case .zone5: return 0.90
        }
    }

    var upperPercentOfMax: Double? {
        switch self {
        case .zone1: return 0.60
        case .zone2: return 0.70
        case .zone3: return 0.80
        case .zone4: return 0.90
        case .zone5: return nil
        }
    }

    var loadMultiplier: Double {
        switch self {
        case .zone1: return 1
        case .zone2: return 2
        case .zone3: return 4
        case .zone4: return 10
        case .zone5: return 18
        }
    }
}

struct SQHeartRateZoneRange: Sendable {
    let zone: SQHeartRateZone
    let lowerBound: Int
    let upperBound: Int?

    func contains(_ heartRate: Double) -> Bool {
        if let upperBound {
            return heartRate >= Double(lowerBound) && heartRate < Double(upperBound)
        }

        return heartRate >= Double(lowerBound)
    }
}

struct SQHeartRateZoneProfile: Sendable {
    let estimatedMaxHeartRate: Int
    let age: Int?
    let methodDescription: String
    let zones: [SQHeartRateZoneRange]
}

struct SQHeartRateZoneDistribution: Identifiable, Sendable {
    let zone: SQHeartRateZone
    let durationSeconds: Double
    let contribution: Double
    let range: SQHeartRateZoneRange

    var id: SQHeartRateZone { zone }
}

struct SQHeartRateWorkoutZoneSummary: Sendable {
    let profile: SQHeartRateZoneProfile
    let distributions: [SQHeartRateZoneDistribution]
    let weightedLoad: Double
    let minimumObservedHeartRate: Double
    let averageHeartRate: Double
    let maximumObservedHeartRate: Double
    let recordedDurationSeconds: Double
}

private extension SQHeartRateWorkoutZoneSummary {
    var hasPlausibleHeartRateValues: Bool {
        let plausibleHeartRateRange: ClosedRange<Double> = 25...240
        return plausibleHeartRateRange.contains(minimumObservedHeartRate)
            && plausibleHeartRateRange.contains(averageHeartRate)
            && plausibleHeartRateRange.contains(maximumObservedHeartRate)
            && minimumObservedHeartRate <= averageHeartRate
            && averageHeartRate <= maximumObservedHeartRate
            && recordedDurationSeconds > 0
    }
}

@MainActor
protocol SQHeartRateServicing {
    func buildDashboardRowViewModel(
        for timeRange: SQTimeRange,
        includeHealthKitData: Bool
    ) async throws -> SQDashboardHeartSummaryRowViewModel?
    func buildWorkoutZoneSummary(for workout: SQWorkoutSessionable) async -> SQHeartRateWorkoutZoneSummary?
}

@MainActor
final class SQHeartRateService: SQHeartRateServicing {
    private let healthKitManager: SQHealthKitManaging
    private let userState: SQUserStating

    init(
        healthKitManager: SQHealthKitManaging = SQHealthKitManager.shared,
        userState: SQUserStating = SQAppState.shared.userState
    ) {
        self.healthKitManager = healthKitManager
        self.userState = userState
    }

    func buildDashboardRowViewModel(
        for timeRange: SQTimeRange,
        includeHealthKitData: Bool
    ) async throws -> SQDashboardHeartSummaryRowViewModel? {
        guard includeHealthKitData else {
            return nil
        }

        async let heartTask = healthKitManager.fetchDailyHeartRateSummaries(timeRange)
        async let restingTask = healthKitManager.fetchDailyRestingHeartRateSummaries(timeRange)

        let heartSummaries = try await heartTask
        let restingSummaries = (try? await restingTask) ?? []

        let averageResting = restingSummaries.compactMap(\.average).average
        let lowestHeartRate = heartSummaries.compactMap(\.minimum).min()
        let peakHeartRate = heartSummaries.compactMap(\.maximum).max()
        let restingTrendChart = makeRestingTrendChart(from: restingSummaries, timeRange: timeRange)

        guard averageResting != nil || lowestHeartRate != nil || peakHeartRate != nil || restingTrendChart != nil else {
            return nil
        }

        return SQDashboardHeartSummaryRowViewModel(
            items: [
                .init(
                    id: "resting",
                    title: "Resting Avg",
                    value: formatted(averageResting),
                    unit: "bpm",
                    detail: detailText(for: timeRange, defaultText: "Average resting")
                ),
                .init(
                    id: "low",
                    title: "Lowest",
                    value: formatted(lowestHeartRate),
                    unit: "bpm",
                    detail: detailText(for: timeRange, defaultText: "Lowest recorded")
                ),
                .init(
                    id: "high",
                    title: "Highest",
                    value: formatted(peakHeartRate),
                    unit: "bpm",
                    detail: detailText(for: timeRange, defaultText: "Peak recorded")
                )
            ],
            trendChart: restingTrendChart
        )
    }

    func buildWorkoutZoneSummary(for workout: SQWorkoutSessionable) async -> SQHeartRateWorkoutZoneSummary? {
        if let cached = await SQWorkoutSession.metadataManager.cachedHeartRateZoneSummary(for: workout.id) {
            if cached.hasPlausibleHeartRateValues {
                return cached
            }

            await SQWorkoutSession.metadataManager.removeCachedHeartRateZoneSummary(for: workout.id)
            SQLogger.shared.log(
                "Discarded implausible cached workout HR zone summary for \(workout.id): avg=\(cached.averageHeartRate), min=\(cached.minimumObservedHeartRate), max=\(cached.maximumObservedHeartRate)",
                .debug,
                context: .healthKit
            )
        }

        do {
            let intervalSummaries: [SQHeartRateIntervalSummary]

            switch workout.workoutSource {
            case .hkWorkout(let hkWorkout):
                if userState.loggedInUser?.usesAppReviewDemoData == true {
                    intervalSummaries = SQHealthKitManager.shared.mockHealthData.workoutHeartRateIntervals(for: hkWorkout.hkWorkout.uuid.uuidString)
                } else {
                    intervalSummaries = try await healthKitManager.fetchWorkoutHeartRateSummaries(for: hkWorkout.hkWorkout)
                }
            case .stravaWorkout(_), .manual(_):
                guard let healthKitId = workout.hkWorkoutId else {
                    return nil
                }
                if userState.loggedInUser?.usesAppReviewDemoData == true {
                    intervalSummaries = SQHealthKitManager.shared.mockHealthData.workoutHeartRateIntervals(for: healthKitId)
                } else {
                    intervalSummaries = try await healthKitManager.fetchWorkoutHeartRateSummaries(for: healthKitId)
                }
            }

            let validIntervals = intervalSummaries.filter { $0.durationSeconds > 0 }
            guard !validIntervals.isEmpty else {
                return nil
            }

            let maximumObservedHeartRate = validIntervals.map(\.average).max() ?? 0
            let minimumObservedHeartRate = validIntervals.map(\.average).min() ?? 0
            guard maximumObservedHeartRate > 0 else {
                return nil
            }

            let profile = makeZoneProfile(
                for: workout,
                maximumObservedHeartRate: maximumObservedHeartRate
            )

            let distributions = profile.zones.map { range -> SQHeartRateZoneDistribution in
                let durationSeconds = validIntervals
                    .filter { range.contains($0.average) }
                    .reduce(0) { $0 + $1.durationSeconds }
                let contribution = (durationSeconds / 60) * range.zone.loadMultiplier
                return .init(
                    zone: range.zone,
                    durationSeconds: durationSeconds,
                    contribution: contribution,
                    range: range
                )
            }

            let recordedDurationSeconds = distributions.reduce(0) { $0 + $1.durationSeconds }
            guard recordedDurationSeconds > 0 else {
                return nil
            }

            let weightedLoad = distributions.reduce(0) { $0 + $1.contribution }
            let weightedHeartRateTotal = validIntervals.reduce(0) { partialResult, sample in
                partialResult + (sample.average * sample.durationSeconds)
            }
            let averageHeartRate = weightedHeartRateTotal / recordedDurationSeconds

            let summary = SQHeartRateWorkoutZoneSummary(
                profile: profile,
                distributions: distributions,
                weightedLoad: weightedLoad,
                minimumObservedHeartRate: minimumObservedHeartRate,
                averageHeartRate: averageHeartRate,
                maximumObservedHeartRate: maximumObservedHeartRate,
                recordedDurationSeconds: recordedDurationSeconds
            )

            guard summary.hasPlausibleHeartRateValues else {
                SQLogger.shared.log(
                    "Skipping implausible workout HR zone summary for \(workout.id): avg=\(summary.averageHeartRate), min=\(summary.minimumObservedHeartRate), max=\(summary.maximumObservedHeartRate)",
                    .debug,
                    context: .healthKit
                )
                return nil
            }

            await SQWorkoutSession.metadataManager.cacheHeartRateZoneSummary(summary, for: workout.id)
            return summary
        } catch {
            SQLogger.shared.log(
                "Failed to build workout HR zone summary for \(workout.id): \(error.localizedDescription)",
                .debug,
                context: .healthKit
            )
            return nil
        }
    }

    private func formatted(_ value: Double?) -> String {
        guard let value else { return "--" }
        return Int(value.rounded()).description
    }

    private func detailText(for timeRange: SQTimeRange, defaultText: String) -> String {
        switch timeRange {
        case .today:
            return "\(defaultText) today"
        case .pastWeek:
            return "\(defaultText) in 7 days"
        case .past30Days:
            return "\(defaultText) in 30 days"
        case .pastYear:
            return "\(defaultText) in 1 year"
        case .allTime:
            return "\(defaultText) all time"
        case .yesterday:
            return "\(defaultText) yesterday"
        case .weekBeforeLast:
            return "\(defaultText) in prior week"
        case .thirtyDaysBeforeLast:
            return "\(defaultText) in prior 30 days"
        case .yearBeforeLast:
            return "\(defaultText) in prior year"
        }
    }

    private func makeRestingTrendChart(
        from summaries: [SQHeartRateDailySummary],
        timeRange: SQTimeRange
    ) -> SQDashboardHeartSummaryRowViewModel.TrendChart? {
        let aggregated = aggregateRestingSummaries(summaries, for: timeRange)
        let points = aggregated.compactMap { summary -> LineChartIdentifiablePoint? in
            guard let value = summary.average else { return nil }
            return .init(
                id: summary.date.timeIntervalSince1970.description,
                point: CGPoint(x: summary.date.timeIntervalSince1970, y: value)
            )
        }

        guard points.count >= 2 else {
            return nil
        }

        return .init(
            title: "Resting HR Trend",
            subtitle: restingTrendSubtitle(for: timeRange),
            points: points,
            trendPoints: buildTrendInputPoints(from: points),
            rangeLabelSuffix: "bpm",
            averageValue: points.map { Double($0.point.y) }.average ?? 0,
            averageLabel: "AVG \(Int((points.map { Double($0.point.y) }.average ?? 0).rounded()))"
        )
    }

    private func aggregateRestingSummaries(
        _ summaries: [SQHeartRateDailySummary],
        for timeRange: SQTimeRange
    ) -> [SQHeartRateDailySummary] {
        switch timeRange {
        case .pastYear, .yearBeforeLast:
            return aggregate(summaries, by: .weekOfYear)
        case .allTime:
            return aggregate(summaries, by: .month)
        default:
            return summaries.sorted { $0.date < $1.date }
        }
    }

    private func aggregate(
        _ summaries: [SQHeartRateDailySummary],
        by component: Calendar.Component
    ) -> [SQHeartRateDailySummary] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: summaries) { summary -> Date in
            switch component {
            case .weekOfYear:
                return calendar.dateInterval(of: .weekOfYear, for: summary.date)?.start
                ?? calendar.startOfDay(for: summary.date)
            case .month:
                return calendar.date(from: calendar.dateComponents([.year, .month], from: summary.date))
                ?? calendar.startOfDay(for: summary.date)
            default:
                return calendar.startOfDay(for: summary.date)
            }
        }

        return grouped.compactMap { date, groupedSummaries in
            let averages = groupedSummaries.compactMap(\.average)
            guard !averages.isEmpty else {
                return nil
            }

            return SQHeartRateDailySummary(
                date: date,
                average: averages.average,
                minimum: nil,
                maximum: nil
            )
        }
        .sorted { $0.date < $1.date }
    }

    private func restingTrendSubtitle(for timeRange: SQTimeRange) -> String {
        switch timeRange {
        case .pastYear, .yearBeforeLast:
            return "Weekly average resting heart rate"
        case .allTime:
            return "Monthly average resting heart rate"
        default:
            return "Daily average resting heart rate"
        }
    }

    private func buildTrendInputPoints(
        from inputPoints: [LineChartIdentifiablePoint]
    ) -> [LineChartIdentifiablePoint]? {
        guard inputPoints.count >= 4 else { return nil }

        let alpha: CGFloat = inputPoints.count > 12 ? 0.20 : 0.26
        var smoothedY = inputPoints[0].point.y

        let smoothedPoints = inputPoints.enumerated().map { index, point in
            if index == 0 {
                return point
            }

            smoothedY = (alpha * point.point.y) + ((1 - alpha) * smoothedY)
            return LineChartIdentifiablePoint(
                id: point.id,
                point: CGPoint(x: point.point.x, y: smoothedY)
            )
        }

        let anchorCount = inputPoints.count >= 9 ? 4 : 3
        let anchorIndices = buildTrendAnchorIndices(totalCount: smoothedPoints.count, anchorCount: anchorCount)
        return anchorIndices.map { smoothedPoints[$0] }
    }

    private func buildTrendAnchorIndices(totalCount: Int, anchorCount: Int) -> [Int] {
        guard totalCount > 0 else { return [] }
        guard anchorCount > 1 else { return [0] }

        let lastIndex = totalCount - 1
        let denominator = max(1, anchorCount - 1)
        let indices = (0..<anchorCount).map { anchorIndex in
            Int(round((Double(anchorIndex) / Double(denominator)) * Double(lastIndex)))
        }

        return indices.reduce(into: [Int]()) { result, index in
            if result.last != index {
                result.append(index)
            }
        }
    }

    private func makeZoneProfile(
        for workout: SQWorkoutSessionable,
        maximumObservedHeartRate: Double
    ) -> SQHeartRateZoneProfile {
        let referenceDate = workout.startDate ?? .now
        let age = userState.loggedInUser?.dateOfBirth.flatMap {
            Calendar.current.dateComponents([.year], from: $0, to: referenceDate).year
        }

        let estimatedMaxHeartRate = estimatedMaxHeartRate(
            age: age,
            maximumObservedHeartRate: maximumObservedHeartRate
        )
        let zones = SQHeartRateZone.allCases.map { zone -> SQHeartRateZoneRange in
            let lowerBound = Int((Double(estimatedMaxHeartRate) * zone.lowerPercentOfMax).rounded())
            let upperBound = zone.upperPercentOfMax.map {
                Int((Double(estimatedMaxHeartRate) * $0).rounded())
            }
            return .init(zone: zone, lowerBound: lowerBound, upperBound: upperBound)
        }

        let methodDescription: String
        if age != nil {
            methodDescription = "Estimated from your profile age and observed workout heart rate."
        } else {
            methodDescription = "Estimated from observed workout heart rate using standard max-HR defaults."
        }

        return .init(
            estimatedMaxHeartRate: estimatedMaxHeartRate,
            age: age,
            methodDescription: methodDescription,
            zones: zones
        )
    }

    private func estimatedMaxHeartRate(
        age: Int?,
        maximumObservedHeartRate: Double
    ) -> Int {
        let ageEstimate = age.map { 208 - (0.7 * Double($0)) } ?? 190
        let adjustedEstimate = max(ageEstimate, maximumObservedHeartRate * 1.03)
        return Int(clamp(adjustedEstimate.rounded(), min: 155, max: 210))
    }

    private func clamp(_ value: Double, min minimum: Double, max maximum: Double) -> Double {
        Swift.max(minimum, Swift.min(maximum, value))
    }
}
