//
//  SQDashboardWorkoutTotalsRowViewModel.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 2/7/26.
//


import SwiftUI

@Observable @MainActor
final class SQDashboardWorkoutTotalsRowViewModel: SQDashboardRowViewModel {
    
    // Stored data for each metric type
    private let timeData: MetricData
    private let caloriesData: MetricData
    
    // Current displayed data (updated when metric changes)
    var currentValueAndTrend: TotalValueAndTrend
    var currentChartDataPoints: [ChartDataPoint]
    
    // Metric selection
    enum MetricType: String, CaseIterable {
        case workoutTime = "Workout Time"
        case kilocalories = "Kilocalories"
    }
    
    struct MetricData {
        let valueAndTrend: TotalValueAndTrend
        let chartDataPoints: [ChartDataPoint]
    }
    
    struct TotalValueAndTrend {
        let value: AttributedString
        let trend: AttributedString
    }
    
    struct ChartDataPoint: Identifiable {
        let id = UUID()
        let label: String
        let value: Double
    }
    
    
    init(config: SQDashboardWorkoutSummaryRowConfig, workouts: [SQWorkoutSessionable], priorWorkouts: [SQWorkoutSessionable], filter: MetricType) {
        
        let totalSeconds = workouts.reduce(0) { $0 + ($1.activeDuration ?? 0) }
        let totalSecondsPriorWeek = priorWorkouts.reduce(0) { $0 + ($1.activeDuration ?? 0) }
        
        let totalKilocalories = workouts.reduce(0) { $0 + ($1.totalCalories ?? 0) }
        let totalKilocaloriesPriorWeek = priorWorkouts.reduce(0) { $0 + ($1.totalCalories ?? 0) }

        let totalTimeValue = Self.formatDuration(seconds: totalSeconds)
        let totalTimeTrend = Self.buildTrend(
            timeRange: config.timeRange,
            priorTimeRange: config.priorTimeRange,
            currentSeconds: totalSeconds,
            previousSeconds: totalSecondsPriorWeek
        )
        
        let totalKilocaloriesValue = Self.formatKilocalories(totalKilocalories: totalKilocalories)
        let totalKilocaliresTrend = Self.buildTrend(
            timeRange: config.timeRange,
            priorTimeRange: config.priorTimeRange,
            currentSeconds: totalKilocalories,
            previousSeconds: totalKilocaloriesPriorWeek
        )
        
        // Store data for both metrics
        self.timeData = MetricData(
            valueAndTrend: TotalValueAndTrend(value: totalTimeValue, trend: totalTimeTrend),
            chartDataPoints: Self.buildChartDataPoints(timeRange: config.timeRange, workouts: workouts, metric: .workoutTime)
        )
        
        self.caloriesData = MetricData(
            valueAndTrend: TotalValueAndTrend(value: totalKilocaloriesValue, trend: totalKilocaliresTrend),
            chartDataPoints: Self.buildChartDataPoints(timeRange: config.timeRange, workouts: workouts, metric: .kilocalories)
        )
        
        switch filter {
        case .workoutTime:
            self.currentValueAndTrend = timeData.valueAndTrend
            self.currentChartDataPoints = timeData.chartDataPoints
        case .kilocalories:
            self.currentValueAndTrend = caloriesData.valueAndTrend
            self.currentChartDataPoints = caloriesData.chartDataPoints
        }
        
        super.init(rowId: .workoutTotals, rowType: .workoutTotals)
    }
    
}

// MARK: - Formatting

private extension SQDashboardWorkoutTotalsRowViewModel {
    static func formatDuration(seconds: Double) -> AttributedString {
        let total = max(0, Int(seconds.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        
        var parts: [AttributedString] = []
        if hours > 0 {
            parts.append(numberUnit(number: hours, unit: "hr"))
        }
        if minutes > 0 || hours == 0 {
            parts.append(numberUnit(number: minutes, unit: "min"))
        }
        
        // Styled spacer so it doesn't pull in default line metrics
        let spacer = AttributedString.build(
            with: " ",
            font: SQFont(type: .bodySmall).font,
            color: SQColor.textSecondary.color
        )
        
        return parts.reduce(AttributedString(), { acc, next in
            if acc.characters.isEmpty { return next }
            var result = acc
            result.append(spacer)
            result.append(next)
            return result
        })
    }
    
    static func formatKilocalories(totalKilocalories: Double) -> AttributedString {
        let kcal = max(0, Int(totalKilocalories.rounded())) // guard negatives
        
        // Reuse numberUnit for consistent styling: "500 kcal"
        return numberUnit(number: kcal, unit: "kcal")
    }
    
    static func numberUnit(number: Int, unit: String) -> AttributedString {
        var result = AttributedString()
        
        // Bold white number
        let numberStr = AttributedString.build(
            with: "\(number)",
            font: SQFont(type: .bodySmallBold).font,
            color: SQColor.textPrimary.color
        )
        // Regular gray unit (prefixed with space)
        let unitStr = AttributedString.build(
            with: " \(unit)",
            font: SQFont(type: .bodySmall).font,
            color: SQColor.textSecondary.color
        )
        
        result.append(numberStr)
        result.append(unitStr)
        return result
    }
    
    static func buildTrend(
        timeRange: SQTimeRange,
        priorTimeRange: SQTimeRange,
        currentSeconds: Double,
        previousSeconds: Double
    ) -> AttributedString {
        // No prior data
        guard previousSeconds > 0 else {
            /// Return an empty string if we don't have previous day's data
            return AttributedString.build(
                with: "",
                font: SQFont(type: .bodySmall).font,
                color: SQColor.textSecondary.color
            )
        }

        let delta = currentSeconds - previousSeconds
        let ratio = delta / previousSeconds           // e.g. 0.52 for +52%
        let percent = ratio

        // If basically flat
        if abs(percent) < 0.01 {
            return AttributedString.build(
                with: "About the same as last week",
                font: SQFont(type: .bodySmall).font,
                color: SQColor.textSecondary.color
            )
        }

        let direction = percent > 0 ? "Up" : "Down"
        let percentString = abs(percent).toPercentageString() // e.g. "52.0%"

        // Colors/fonts
        let baseFont = SQFont(type: .bodySmall).font
        let baseColor = SQColor.textPrimary.color
        let pctColor = SQColor.colorGreenRed(percent: percent * 4).color
        let pctFont = SQFont(type: .bodySmallBold).font

        // Build pieces: "Up " + "52%" + " from last week"
        var result = AttributedString()

        let prefix = AttributedString.build(
            with: "\(direction) ",
            font: baseFont,
            color: baseColor
        )

        let percentAttr = AttributedString.build(
            with: percentString,            // already includes "%"
            font: pctFont,
            color: pctColor
        )

        let suffix = AttributedString.build(
            with: " from \(priorTimeRange.title.lowercased())",
            font: baseFont,
            color: baseColor
        )

        result.append(prefix)
        result.append(percentAttr)
        result.append(suffix)

        return result
    }
    
    static func buildChartDataPoints(
        timeRange: SQTimeRange,
        workouts: [SQWorkoutSessionable],
        metric: MetricType
    ) -> [ChartDataPoint] {
        let calendar = Calendar.current
        let now = Date()
        
        switch timeRange {
        case .today:
            // For "today" just show a single bar or return empty
            let totalValue = workouts.reduce(0.0) { total, workout in
                total + (metric == .workoutTime ? (workout.activeDuration ?? 0) : (workout.totalCalories ?? 0))
            }
            return [ChartDataPoint(label: "Today", value: totalValue)]
            
        case .yesterday:
            let totalValue = workouts.reduce(0.0) { total, workout in
                total + (metric == .workoutTime ? (workout.activeDuration ?? 0) : (workout.totalCalories ?? 0))
            }
            return [ChartDataPoint(label: "Yest.", value: totalValue)]
            
        case .pastWeek:
            // Last 7 days: M T W T F S S
            var dayTotals: [Date: Double] = [:]
            
            // Initialize last 7 days with 0
            for dayOffset in 0..<7 {
                if let day = calendar.date(byAdding: .day, value: -dayOffset, to: now) {
                    let dayStart = calendar.startOfDay(for: day)
                    dayTotals[dayStart] = 0
                }
            }
            
            // Aggregate workouts by day
            for workout in workouts {
                guard let startDate = workout.startDate else { continue }
                let value = metric == .workoutTime ? (workout.activeDuration ?? 0) : (workout.totalCalories ?? 0)
                let dayStart = calendar.startOfDay(for: startDate)
                dayTotals[dayStart, default: 0] += value
            }
            
            // Sort by date and map to chart points
            let sortedDays = dayTotals.keys.sorted()
            return sortedDays.map { day in
                let weekdaySymbol = calendar.shortWeekdaySymbols[calendar.component(.weekday, from: day) - 1].prefix(1)
                return ChartDataPoint(
                    label: String(weekdaySymbol),
                    value: dayTotals[day] ?? 0
                )
            }
            
        case .pastYear:
            // Last 12 months: J F M A M J J A S O N D
            var monthTotals: [Date: Double] = [:]
            
            // Initialize last 12 months with 0
            for monthOffset in 0..<12 {
                if let month = calendar.date(byAdding: .month, value: -monthOffset, to: now) {
                    let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: month))!
                    monthTotals[monthStart] = 0
                }
            }
            
            // Aggregate workouts by month
            for workout in workouts {
                guard let startDate = workout.startDate else { continue }
                let value = metric == .workoutTime ? (workout.activeDuration ?? 0) : (workout.totalCalories ?? 0)
                let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: startDate))!
                monthTotals[monthStart, default: 0] += value
            }
            
            // Sort by date and map to chart points
            let sortedMonths = monthTotals.keys.sorted()
            return sortedMonths.map { month in
                let monthSymbol = calendar.shortMonthSymbols[calendar.component(.month, from: month) - 1].prefix(1)
                return ChartDataPoint(
                    label: String(monthSymbol),
                    value: monthTotals[month] ?? 0
                )
            }
            
        default:
            return []
        }
    }
}
