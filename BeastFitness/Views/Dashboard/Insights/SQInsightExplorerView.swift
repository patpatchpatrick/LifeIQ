//
//  SQInsightExplorerView.swift
//  BeastFitness
//

import SwiftUI
import CoolCharts
import BeastFitnessCore

enum SQInsightExplorerLag: Int, CaseIterable, Identifiable {
    case sameDay = 0
    case nextDay = 1
    case twoDaysLater = 2

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .sameDay:
            return "Same day"
        case .nextDay:
            return "Next day"
        case .twoDaysLater:
            return "2 days later"
        }
    }

    var sentencePhrase: String {
        switch self {
        case .sameDay:
            return "the same day"
        case .nextDay:
            return "the next day"
        case .twoDaysLater:
            return "2 days later"
        }
    }
}

enum SQInsightExplorerRange: String, CaseIterable, Identifiable {
    case days30 = "30d"
    case days90 = "90d"
    case year = "1y"
    case all = "All"

    var id: String { rawValue }

    var sentencePhrase: String {
        switch self {
        case .days30:
            return "over the last 30 days"
        case .days90:
            return "over the last 90 days"
        case .year:
            return "over the last year"
        case .all:
            return "across all logged data"
        }
    }

    func startDate(referenceDate: Date) -> Date? {
        switch self {
        case .days30:
            return Calendar.current.date(byAdding: .day, value: -30, to: referenceDate)
        case .days90:
            return Calendar.current.date(byAdding: .day, value: -90, to: referenceDate)
        case .year:
            return Calendar.current.date(byAdding: .day, value: -365, to: referenceDate)
        case .all:
            return nil
        }
    }
}

struct SQInsightExplorerMetricOption: Identifiable, Hashable {
    let id: String
    let title: String
}

struct SQInsightExplorerChartPoint: Identifiable, Hashable {
    let id: String
    let date: Date
    let driverValue: Double
    let driverDisplayLabel: String
    let outcomeValue: Double
    let outcomeRawValue: Double
    let outcomeDisplayLabel: String
    let outcomeUtilityValue: Double?
}

struct SQInsightExplorerRelationshipResult: Identifiable, Hashable {
    let id: String
    let driverId: String
    let outcomeId: String
    let driverTitle: String
    let outcomeTitle: String
    let range: SQInsightExplorerRange
    let lag: SQInsightExplorerLag
    let higherDriverThreshold: Double
    let displayEffectPoints: Double
    let effectPoints: Double
    let confidence: SQInsightConfidence
    let matchedDays: Int
    let highDriverAverageOutcome: Double
    let highDriverAverageOutcomeRawLabel: String
    let lowDriverAverageOutcome: Double
    let lowDriverAverageOutcomeRawLabel: String
    let rankingScore: Double
    let chartPoints: [SQInsightExplorerChartPoint]

    var effect: SQInsightEffect {
        if effectPoints >= 5 {
            return .positive
        } else if effectPoints <= -5 {
            return .negative
        }

        return .neutral
    }

    var directionTitle: String {
        switch effect {
        case .positive:
            return "Likely support"
        case .negative:
            return "Likely drag"
        case .neutral:
            return "No clear pattern"
        }
    }

    var effectSummary: String {
        let magnitude = abs(displayEffectPoints).sqStringRoundedTo(places: 0)
        if displayEffectPoints > 0 {
            return "\(outcomeTitle) averages \(magnitude)% higher \(lag.sentencePhrase) after higher \(driverTitle) days \(range.sentencePhrase)."
        } else if displayEffectPoints < 0 {
            return "\(outcomeTitle) averages \(magnitude)% lower \(lag.sentencePhrase) after higher \(driverTitle) days \(range.sentencePhrase)."
        }

        return "\(outcomeTitle) does not move clearly after higher \(driverTitle) days."
    }

    var higherDriverDefinition: String {
        "Higher \(driverTitle) days means days above your median \(driverTitle) value \(range.sentencePhrase)."
    }
}

struct SQInsightExplorerAnalyzer {
    private enum ValueFormat: Hashable {
        case scale(max: Double)
        case quantity(unit: String)
        case score
        case bpm
        case plain

        func label(for value: Double) -> String {
            let roundedValue = value.sqStringRoundedTo(places: value.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 1)

            switch self {
            case .scale(let max):
                return "\(roundedValue)/\(max.sqStringRoundedTo(places: 0))"
            case .quantity(let unit):
                return unit.isEmpty ? roundedValue : "\(roundedValue) \(unit)"
            case .score:
                return "\(value.sqStringRoundedTo(places: 0)) score"
            case .bpm:
                return "\(value.sqStringRoundedTo(places: 0)) bpm"
            case .plain:
                return roundedValue
            }
        }
    }

    private struct SignalValue {
        let displayValue: Double
        let rawValue: Double
        let displayLabel: String
        let valueFormat: ValueFormat
        let utilityValue: Double?
    }

    private struct DailyMetricValues {
        let date: Date
        let values: [String: SignalValue]
    }

    private struct SignalDataset {
        let options: [SQInsightExplorerMetricOption]
        let dailyValues: [DailyMetricValues]

        var optionsById: [String: SQInsightExplorerMetricOption] {
            Dictionary(uniqueKeysWithValues: options.map { ($0.id, $0) })
        }
    }

    private let featureBuilder = SQInsightFeatureBuilder()

    func analyze(
        input: SQHealthIntelligenceInput,
        driverId: String,
        outcomeId: String,
        range: SQInsightExplorerRange,
        lag: SQInsightExplorerLag
    ) -> SQInsightExplorerRelationshipResult? {
        let dataset = buildSignalDataset(input: input, range: range)
        return analyze(
            dataset: dataset,
            driverId: driverId,
            outcomeId: outcomeId,
            range: range,
            lag: lag
        )
    }

    private func analyze(
        dataset: SignalDataset,
        driverId: String,
        outcomeId: String,
        range: SQInsightExplorerRange,
        lag: SQInsightExplorerLag
    ) -> SQInsightExplorerRelationshipResult? {
        guard driverId != outcomeId else { return nil }
        let optionsById = dataset.optionsById
        guard let driver = optionsById[driverId], let outcome = optionsById[outcomeId] else { return nil }

        let dailyValues = dataset.dailyValues
        let valuesByDay = Dictionary(uniqueKeysWithValues: dailyValues.map { ($0.date.anchorDayKey(), $0) })
        let matchedPoints = dailyValues.compactMap { driverDay -> SQInsightExplorerChartPoint? in
            guard let driverValue = driverDay.values[driverId] else { return nil }
            let outcomeDate = Calendar.current.date(byAdding: .day, value: lag.rawValue, to: driverDay.date) ?? driverDay.date
            guard let outcomeValue = valuesByDay[outcomeDate.anchorDayKey()]?.values[outcomeId] else { return nil }
            return .init(
                id: "\(driverDay.date.anchorDayKey())-\(lag.rawValue)",
                date: driverDay.date,
                driverValue: driverValue.displayValue,
                driverDisplayLabel: driverValue.displayLabel,
                outcomeValue: outcomeValue.displayValue,
                outcomeRawValue: outcomeValue.rawValue,
                outcomeDisplayLabel: outcomeValue.displayLabel,
                outcomeUtilityValue: outcomeValue.utilityValue
            )
        }

        guard matchedPoints.count >= 6 else { return nil }

        let median = percentile(matchedPoints.map(\.driverValue), percentile: 0.5)
        let high = matchedPoints.filter { $0.driverValue > median }
        let low = matchedPoints.filter { $0.driverValue <= median }
        guard !high.isEmpty, !low.isEmpty else { return nil }

        let highOutcome = average(high.map(\.outcomeValue))
        let lowOutcome = average(low.map(\.outcomeValue))
        let highOutcomeRaw = average(high.map(\.outcomeRawValue))
        let lowOutcomeRaw = average(low.map(\.outcomeRawValue))
        let outcomeValueFormat = valuesByDay
            .values
            .lazy
            .compactMap { $0.values[outcomeId]?.valueFormat }
            .first ?? .plain
        let displayEffectPoints = highOutcome - lowOutcome
        let highUtilityOutcome = average(high.map { $0.outcomeUtilityValue ?? $0.outcomeValue })
        let lowUtilityOutcome = average(low.map { $0.outcomeUtilityValue ?? $0.outcomeValue })
        let effectPoints = highUtilityOutcome - lowUtilityOutcome
        let confidence = confidence(sampleCount: matchedPoints.count, effectMagnitude: abs(effectPoints))
        let rankingScore = rankingScore(
            sampleCount: matchedPoints.count,
            effectMagnitude: abs(effectPoints),
            confidence: confidence
        )

        return .init(
            id: "\(driverId)-\(outcomeId)-\(range.rawValue)-\(lag.rawValue)",
            driverId: driverId,
            outcomeId: outcomeId,
            driverTitle: driver.title,
            outcomeTitle: outcome.title,
            range: range,
            lag: lag,
            higherDriverThreshold: median,
            displayEffectPoints: displayEffectPoints,
            effectPoints: effectPoints,
            confidence: confidence,
            matchedDays: matchedPoints.count,
            highDriverAverageOutcome: highOutcome,
            highDriverAverageOutcomeRawLabel: outcomeValueFormat.label(for: highOutcomeRaw),
            lowDriverAverageOutcome: lowOutcome,
            lowDriverAverageOutcomeRawLabel: outcomeValueFormat.label(for: lowOutcomeRaw),
            rankingScore: rankingScore,
            chartPoints: matchedPoints.sorted { $0.date < $1.date }
        )
    }

    func topRelationships(input: SQHealthIntelligenceInput, range: SQInsightExplorerRange = .days90) -> [SQInsightExplorerRelationshipResult] {
        let dataset = buildSignalDataset(input: input, range: range)
        let options = dataset.options
        var results = [SQInsightExplorerRelationshipResult]()

        for driver in options {
            for outcome in options where outcome.id != driver.id {
                let best = SQInsightExplorerLag.allCases
                    .compactMap { lag in
                        analyze(dataset: dataset, driverId: driver.id, outcomeId: outcome.id, range: range, lag: lag)
                    }
                    .max { $0.rankingScore < $1.rankingScore }
                if let best {
                    results.append(best)
                }
            }
        }

        return results
            .filter { $0.confidence != .low || abs($0.effectPoints) >= 7 }
            .sorted { lhs, rhs in
                if lhs.rankingScore == rhs.rankingScore {
                    return lhs.matchedDays > rhs.matchedDays
                }
                return lhs.rankingScore > rhs.rankingScore
            }
    }

    func metricOptions(input: SQHealthIntelligenceInput) -> [SQInsightExplorerMetricOption] {
        buildSignalDataset(input: input, range: .all).options
    }

    private func buildSignalDataset(
        input: SQHealthIntelligenceInput,
        range: SQInsightExplorerRange
    ) -> SignalDataset {
        let startDate = range.startDate(referenceDate: input.referenceDate)
        let snapshots = featureBuilder.makeFeatureSnapshots(
            checkIns: input.checkIns,
            workouts: input.workouts,
            metricDefinitions: input.metricDefinitions,
            sleepData: input.sleepData,
            restingHeartRateSummaries: input.restingHeartRateSummaries
        )
        let definitionsById = Dictionary(uniqueKeysWithValues: input.metricDefinitions.map { ($0.id, $0) })

        var optionMap = [String: SQInsightExplorerMetricOption]()
        let dailyValues = snapshots
            .compactMap { snapshot -> DailyMetricValues? in
                guard startDate.map({ snapshot.date >= $0 }) ?? true else { return nil }
                var values = [String: SignalValue]()

                for feature in snapshot.signalFeatures.values where canExplore(feature) {
                    optionMap[feature.signalId] = .init(id: feature.signalId, title: feature.title)
                    let valueFormat = rawValueFormat(
                        feature: feature,
                        definition: definitionsById[feature.signalId]
                    )
                    values[feature.signalId] = .init(
                        displayValue: normalizedDisplayValue(feature: feature, snapshot: snapshot),
                        rawValue: feature.rawValue,
                        displayLabel: valueFormat.label(for: feature.rawValue),
                        valueFormat: valueFormat,
                        utilityValue: normalizedUtilityValue(feature: feature)
                    )
                }

                guard !values.isEmpty else { return nil }
                return .init(date: snapshot.date, values: values)
            }

        let options = optionMap.values.sorted {
            $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
        return .init(options: options, dailyValues: dailyValues.sorted { $0.date < $1.date })
    }

    private func canExplore(_ feature: SQInsightSignalFeature) -> Bool {
        feature.insightMode != .off
            && feature.insightMode != .trendsOnly
            && feature.sensitivity != .medicationLike
    }

    private func normalizedDisplayValue(feature: SQInsightSignalFeature, snapshot: SQInsightFeatureSnapshot) -> Double {
        let value = feature.normalizedValue.map { $0 * 100 }
            ?? snapshot.normalizedSignalValue(for: feature.signalId).map { $0 <= 10 ? $0 * 10 : $0 }
            ?? feature.rawValue
        return clamp(value, min: 0, max: 100)
    }

    private func normalizedUtilityValue(feature: SQInsightSignalFeature) -> Double? {
        feature.goalUtilityScore.map { clamp($0, min: 0, max: 100) }
    }

    private func rawValueFormat(feature: SQInsightSignalFeature, definition: SQMetricDefinition?) -> ValueFormat {
        if let definition {
            return rawValueFormat(for: definition)
        }

        switch feature.signalId {
        case SQInsightAnalysisMetricId.workoutPerformance, SQInsightAnalysisMetricId.workoutDifficulty:
            return .score
        case SQInsightAnalysisMetricId.restingHeartRate:
            return .bpm
        default:
            return .plain
        }
    }

    private func rawValueFormat(for definition: SQMetricDefinition) -> ValueFormat {
        switch definition.kind {
        case .scale, .binary:
            if definition.scaleQuantityMapping == nil {
                return .scale(max: Double(definition.scaleMaxValue))
            }
            fallthrough
        case .number:
            return .quantity(unit: definition.quantityLabel)
        case .unknown:
            return .plain
        }
    }

    private func clamp<T: Comparable>(_ value: T, min minimum: T, max maximum: T) -> T {
        Swift.max(minimum, Swift.min(maximum, value))
    }

    private func confidence(sampleCount: Int, effectMagnitude: Double) -> SQInsightConfidence {
        switch (sampleCount, effectMagnitude) {
        case (24..., 12...):
            return .high
        case (12..., 7...):
            return .medium
        default:
            return .low
        }
    }

    private func rankingScore(sampleCount: Int, effectMagnitude: Double, confidence: SQInsightConfidence) -> Double {
        let confidenceWeight: Double
        switch confidence {
        case .high:
            confidenceWeight = 40
        case .medium:
            confidenceWeight = 20
        case .low:
            confidenceWeight = 0
        }

        return confidenceWeight + effectMagnitude + min(Double(sampleCount), 45)
    }

    private func percentile(_ values: [Double], percentile: Double) -> Double {
        let sorted = values.sorted()
        guard let first = sorted.first else { return 0 }
        guard sorted.count > 1 else { return first }
        let index = max(0, min(sorted.count - 1, Int((Double(sorted.count - 1) * percentile).rounded())))
        return sorted[index]
    }

    private func average(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }
}

@Observable @MainActor
final class SQInsightExplorerController {
    let id = UUID().uuidString
    private let input: SQHealthIntelligenceInput
    private let analyzer = SQInsightExplorerAnalyzer()
    @ObservationIgnored private var suppressSelectionUpdates = false

    private(set) var metricOptions: [SQInsightExplorerMetricOption]
    private(set) var topRelationships: [SQInsightExplorerRelationshipResult]
    private(set) var result: SQInsightExplorerRelationshipResult?
    @ObservationIgnored private(set) var driverMenuViewModel = SQDropDownMenuViewModel(
        defaultItem: .init(title: ""),
        items: []
    ) { _ in }
    @ObservationIgnored private(set) var outcomeMenuViewModel = SQDropDownMenuViewModel(
        defaultItem: .init(title: ""),
        items: []
    ) { _ in }
    var selectedDriverId: String = "" {
        didSet {
            updateMetricMenuSelection(driverMenuViewModel, selectedId: selectedDriverId)
            selectionDidChange()
        }
    }
    var selectedOutcomeId: String = "" {
        didSet {
            updateMetricMenuSelection(outcomeMenuViewModel, selectedId: selectedOutcomeId)
            selectionDidChange()
        }
    }
    var selectedRange: SQInsightExplorerRange = .days90 {
        didSet { selectionDidChange() }
    }
    var selectedLag: SQInsightExplorerLag = .nextDay {
        didSet { selectionDidChange() }
    }

    init(
        input: SQHealthIntelligenceInput,
        preselectedDriverId: String? = nil,
        preselectedOutcomeId: String? = nil,
        preselectedLag: SQInsightExplorerLag = .nextDay,
        initialRange: SQInsightExplorerRange = .days90
    ) {
        let analyzer = SQInsightExplorerAnalyzer()
        let metricOptions = analyzer.metricOptions(input: input)
        let topRelationships = analyzer.topRelationships(input: input, range: initialRange)

        self.input = input
        self.metricOptions = metricOptions
        self.topRelationships = topRelationships
        self.suppressSelectionUpdates = true
        self.selectedDriverId = preselectedDriverId ?? topRelationships.first?.driverId ?? metricOptions.first?.id ?? ""
        self.selectedOutcomeId = preselectedOutcomeId ?? topRelationships.first?.outcomeId ?? metricOptions.dropFirst().first?.id ?? metricOptions.first?.id ?? ""
        self.selectedLag = preselectedLag
        self.selectedRange = initialRange
        self.configureMetricMenus()
        self.suppressSelectionUpdates = false
        updateResult()
    }

    var hasEnoughMetricOptions: Bool {
        metricOptions.count >= 2
    }

    func applyTopRelationship(_ relationship: SQInsightExplorerRelationshipResult) {
        SQLogger.shared.log(
            "PTD InsightExplorer applyTopRelationship driver=\(relationship.driverId) outcome=\(relationship.outcomeId) range=\(relationship.range.rawValue) lag=\(relationship.lag.rawValue) matchedDays=\(relationship.matchedDays)",
            .debug,
            context: .dashboard
        )
        suppressSelectionUpdates = true
        selectedDriverId = relationship.driverId
        selectedOutcomeId = relationship.outcomeId
        selectedRange = relationship.range
        selectedLag = relationship.lag
        suppressSelectionUpdates = false
        result = relationship
    }

    func logPresentationState(source: String) {
        SQLogger.shared.log(
            "PTD InsightExplorer presentation source=\(source) selectedDriver=\(selectedDriverId) selectedOutcome=\(selectedOutcomeId) range=\(selectedRange.rawValue) lag=\(selectedLag.rawValue) hasResult=\(result != nil) matchedDays=\(result?.matchedDays.description ?? "nil") optionCount=\(metricOptions.count) topRelationshipCount=\(topRelationships.count)",
            .debug,
            context: .dashboard
        )
    }

    private func selectionDidChange() {
        guard !suppressSelectionUpdates else { return }
        updateResult()
    }

    private func configureMetricMenus() {
        let items = metricOptions.map { SQDropDownMenuViewModel.Item(title: $0.title) }
        let driverDefault = selectedMetricOption(for: selectedDriverId) ?? metricOptions.first
        let outcomeDefault = selectedMetricOption(for: selectedOutcomeId) ?? metricOptions.dropFirst().first ?? metricOptions.first

        driverMenuViewModel = SQDropDownMenuViewModel(
            defaultItem: .init(title: driverDefault?.title ?? ""),
            items: items,
            itemSelectionHandler: { [weak self] title in
                guard let self,
                      let option = self.metricOptions.first(where: { $0.title == title }) else { return }
                self.selectedDriverId = option.id
            }
        )
        outcomeMenuViewModel = SQDropDownMenuViewModel(
            defaultItem: .init(title: outcomeDefault?.title ?? ""),
            items: items,
            itemSelectionHandler: { [weak self] title in
                guard let self,
                      let option = self.metricOptions.first(where: { $0.title == title }) else { return }
                self.selectedOutcomeId = option.id
            }
        )
    }

    private func selectedMetricOption(for id: String) -> SQInsightExplorerMetricOption? {
        metricOptions.first { $0.id == id }
    }

    private func updateMetricMenuSelection(_ menuViewModel: SQDropDownMenuViewModel, selectedId: String) {
        guard let option = selectedMetricOption(for: selectedId) else { return }
        menuViewModel.mainButton.title = option.title
    }

    private func updateResult() {
        result = analyzer.analyze(
            input: input,
            driverId: selectedDriverId,
            outcomeId: selectedOutcomeId,
            range: selectedRange,
            lag: selectedLag
        )

        if result == nil {
            let optionIds = Set(metricOptions.map(\.id))
            SQLogger.shared.log(
                "PTD InsightExplorer no result selectedDriver=\(selectedDriverId) driverInOptions=\(optionIds.contains(selectedDriverId)) selectedOutcome=\(selectedOutcomeId) outcomeInOptions=\(optionIds.contains(selectedOutcomeId)) range=\(selectedRange.rawValue) lag=\(selectedLag.rawValue) optionCount=\(metricOptions.count) topRelationshipCount=\(topRelationships.count) options=\(metricOptions.prefix(12).map { "\($0.title):\($0.id)" }.joined(separator: ", "))",
                .debug,
                context: .dashboard
            )
        } else if let result {
            SQLogger.shared.log(
                "PTD InsightExplorer result driver=\(result.driverId) outcome=\(result.outcomeId) range=\(result.range.rawValue) lag=\(result.lag.rawValue) matchedDays=\(result.matchedDays) displayEffect=\(result.displayEffectPoints) utilityEffect=\(result.effectPoints)",
                .debug,
                context: .dashboard
            )
        }
    }
}

extension SQInsightExplorerController: Hashable {
    nonisolated static func == (lhs: SQInsightExplorerController, rhs: SQInsightExplorerController) -> Bool {
        lhs.id == rhs.id
    }

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

@Observable @MainActor
final class SQDashboardInsightExplorerRowViewModel: SQDashboardRowViewModel {
    let isLocked: Bool
    let topRelationships: [SQInsightExplorerRelationshipResult]
    let onOpenExplorer: () -> Void
    let onLockedTap: () -> Void
    let onRelationshipTap: (SQInsightExplorerRelationshipResult) -> Void

    init(
        isLocked: Bool,
        topRelationships: [SQInsightExplorerRelationshipResult],
        onOpenExplorer: @escaping () -> Void,
        onLockedTap: @escaping () -> Void,
        onRelationshipTap: @escaping (SQInsightExplorerRelationshipResult) -> Void
    ) {
        self.isLocked = isLocked
        self.topRelationships = topRelationships
        self.onOpenExplorer = onOpenExplorer
        self.onLockedTap = onLockedTap
        self.onRelationshipTap = onRelationshipTap
        super.init(rowId: .insightExplorer, rowType: .insightExplorer)
    }
}

struct SQDashboardInsightExplorerRowView: View {
    let viewModel: SQDashboardInsightExplorerRowViewModel

    var body: some View {
        if viewModel.isLocked {
            Button(action: viewModel.onLockedTap) {
                lockedContent
            }
            .buttonStyle(.plain)
        } else {
            unlockedContent
        }
    }

    private var lockedContent: some View {
        VStack(alignment: .leading, spacing: .SQSpace.s) {
            HStack(spacing: .SQSpace.s) {
                SQImageView(
                    image: .init(
                        symbol: .lockFill,
                        symbolStyle: .colorWithFont(.textSecondary, font: .bodyExtraSmall)
                    )
                )
                .frame(width: 12, height: 12)

                Text("Unlock Insight Explorer")
                    .sqFont(.bodySemiBold)
                    .sqForegroundColor(.textPrimary)
            }

            Text("Compare any two metrics and view your top detected relationships.")
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.SQSpace.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(rowBackground)
    }

    private var unlockedContent: some View {
        VStack(alignment: .leading, spacing: .SQSpace.m) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: .SQSpace.xs) {
                    Text("Top Relationships")
                        .sqFont(.bodySemiBold)
                        .sqForegroundColor(.textPrimary)

                    Text("Start from your strongest detected patterns.")
                        .sqFont(.bodyExtraSmall)
                        .sqForegroundColor(.textSecondary)
                }

                Spacer(minLength: .SQSpace.m)

                Button(action: viewModel.onOpenExplorer) {
                    Text("Compare")
                        .sqFont(.bodyExtraSmall)
                        .sqForegroundColor(.textPrimary)
                        .padding(.vertical, 7)
                        .padding(.horizontal, .SQSpace.s)
                        .background(
                            Capsule(style: .continuous)
                                .fill(SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.82 : 0.96))
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(SQColor.glassStroke.color, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }

            if viewModel.topRelationships.isEmpty {
                Text("Log more overlapping metrics to generate top relationships.")
                    .sqFont(.bodyExtraSmall)
                    .sqForegroundColor(.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.topRelationships.prefix(3).enumerated()), id: \.element.id) { index, relationship in
                        Button {
                            viewModel.onRelationshipTap(relationship)
                        } label: {
                            relationshipRow(relationship)
                        }
                        .buttonStyle(.plain)

                        if index < min(viewModel.topRelationships.count, 3) - 1 {
                            Divider()
                                .sqTintColor(.glassStroke)
                        }
                    }
                }
            }
        }
        .padding(.SQSpace.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(rowBackground)
    }

    private func relationshipRow(_ relationship: SQInsightExplorerRelationshipResult) -> some View {
        HStack(alignment: .top, spacing: .SQSpace.m) {
            VStack(alignment: .leading, spacing: .SQSpace.xs) {
                Text("\(relationship.driverTitle) -> \(relationship.outcomeTitle)")
                    .sqFont(.bodySmallSemiBold)
                    .sqForegroundColor(.textPrimary)

                Text(relationship.effectSummary)
                    .sqFont(.bodyExtraSmall)
                    .sqForegroundColor(.textSecondary)
                    .lineLimit(2)
            }

            Spacer(minLength: .SQSpace.s)

            VStack(alignment: .trailing, spacing: .SQSpace.xs) {
                SQDashboardTrendBadge(
                    text: relationship.confidence.badgeTitle,
                    tone: tone(for: relationship.effect),
                    symbol: nil
                )

                Text("\(relationship.matchedDays) days")
                    .sqFont(.bodyExtraSmall)
                    .sqForegroundColor(.textSecondary)
            }
        }
        .padding(.vertical, .SQSpace.s)
        .contentShape(Rectangle())
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous)
            .fill(SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.76 : 0.98))
            .overlay {
                RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous)
                    .stroke(SQColor.glassStroke.color, lineWidth: 1)
            }
    }

    private func tone(for effect: SQInsightEffect) -> SQDashboardTrendTone {
        switch effect {
        case .positive:
            return .positive
        case .negative:
            return .negative
        case .neutral:
            return .neutral
        }
    }
}

struct SQInsightExplorerView: View {
    @Bindable var controller: SQInsightExplorerController

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .SQSpace.l) {
                controls

                if !controller.hasEnoughMetricOptions {
                    emptyState
                } else if let result = controller.result {
                    resultSummary(result)
                    evidenceTable(result)
                    relationshipChart(result)
                    topRelationships
                } else {
                    noPatternState
                    topRelationships
                }
            }
            .padding(.horizontal, .SQSpace.l)
            .padding(.vertical, .SQSpace.l)
        }
        .navigationTitle("Insight Explorer")
        .navigationBarTitleDisplayMode(.inline)
        .background {
            SQSheetBackground()
        }
        .onAppear {
            controller.logPresentationState(source: "view_on_appear")
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: .SQSpace.m) {
            metricPicker(title: "Metric A", menuViewModel: controller.driverMenuViewModel)
            metricPicker(title: "Metric B", menuViewModel: controller.outcomeMenuViewModel)

            Picker("Range", selection: $controller.selectedRange) {
                ForEach(SQInsightExplorerRange.allCases) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)

            Picker("Lag", selection: $controller.selectedLag) {
                ForEach(SQInsightExplorerLag.allCases) { lag in
                    Text(lag.title).tag(lag)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.SQSpace.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
    }

    private func metricPicker(title: String, menuViewModel: SQDropDownMenuViewModel) -> some View {
        HStack {
            Text(title)
                .sqFont(.bodySmallSemiBold)
                .sqForegroundColor(.textSecondary)

            Spacer()

            SQDropDownMenu(menuViewModel: menuViewModel, isDisabled: false)
        }
    }

    private func resultSummary(_ result: SQInsightExplorerRelationshipResult) -> some View {
        VStack(alignment: .leading, spacing: .SQSpace.m) {
            HStack(spacing: .SQSpace.s) {
                SQDashboardTrendBadge(text: result.directionTitle, tone: tone(for: result.effect), symbol: nil)
                SQDashboardTrendBadge(text: result.confidence.badgeTitle, tone: tone(for: result.effect), symbol: nil)
                SQDashboardTrendBadge(text: "\(result.matchedDays) matched days", tone: .neutral, symbol: nil)
            }

            Text("\(result.driverTitle) -> \(result.outcomeTitle)")
                .sqFont(.title3)
                .sqForegroundColor(.textPrimary)

            Text(result.effectSummary)
                .sqFont(.bodySmallSemiBold)
                .sqForegroundColor(.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text("\(result.higherDriverDefinition) Values are shown as normalized percentages so different metrics can be compared together.")
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("This is an association in your logged data, not a medical or causal claim.")
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.SQSpace.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
    }

    private func evidenceTable(_ result: SQInsightExplorerRelationshipResult) -> some View {
        VStack(alignment: .leading, spacing: .SQSpace.m) {
            Text("Evidence")
                .sqFont(.bodySemiBold)
                .sqForegroundColor(.textPrimary)

            evidenceRow(title: "Time range", value: result.range.rawValue)
            evidenceRow(title: "Timing", value: result.lag.title)
            evidenceRow(title: "Higher \(result.driverTitle)", value: "Above \(result.higherDriverThreshold.sqStringRoundedTo(places: 0))%")
            evidenceRow(
                title: "High \(result.driverTitle)",
                value: "\(result.highDriverAverageOutcome.sqStringRoundedTo(places: 0))% \(result.outcomeTitle) (\(result.highDriverAverageOutcomeRawLabel))"
            )
            evidenceRow(
                title: "Low \(result.driverTitle)",
                value: "\(result.lowDriverAverageOutcome.sqStringRoundedTo(places: 0))% \(result.outcomeTitle) (\(result.lowDriverAverageOutcomeRawLabel))"
            )
            evidenceRow(title: "Difference", value: "\(signed(result.displayEffectPoints))%")
        }
        .padding(.SQSpace.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
    }

    private func evidenceRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textSecondary)

            Spacer(minLength: .SQSpace.m)

            Text(value)
                .sqFont(.bodySmallSemiBold)
                .sqForegroundColor(.textPrimary)
        }
    }

    private func relationshipChart(_ result: SQInsightExplorerRelationshipResult) -> some View {
        VStack(alignment: .leading, spacing: .SQSpace.m) {
            Text("Logged Together")
                .sqFont(.bodySemiBold)
                .sqForegroundColor(.textPrimary)

            Text("Both lines use normalized percentages so the trends can be compared on the same chart.")
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            GeometryReader { proxy in
                if let chartModel = relationshipChartModel(result, width: proxy.size.width, height: 220) {
                    MultiLineChartView(model: chartModel)
                        .frame(width: proxy.size.width, height: 220)
                } else {
                    chartUnavailableState
                }
            }
            .frame(height: 220)

            HStack(spacing: .SQSpace.m) {
                legend(color: .dashboardGlowBlue, title: result.driverTitle)
                legend(color: .dashboardGlowMint, title: result.outcomeTitle)
            }
        }
        .padding(.SQSpace.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
    }

    private var chartUnavailableState: some View {
        Text("Not enough overlapping points to draw this chart yet.")
            .sqFont(.bodyExtraSmall)
            .sqForegroundColor(.textSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var topRelationships: some View {
        VStack(alignment: .leading, spacing: .SQSpace.m) {
            Text("Top Relationships")
                .sqFont(.bodySemiBold)
                .sqForegroundColor(.textPrimary)

            if controller.topRelationships.isEmpty {
                Text("Log more overlapping metrics to generate top relationships.")
                    .sqFont(.bodyExtraSmall)
                    .sqForegroundColor(.textSecondary)
            } else {
                ForEach(controller.topRelationships.prefix(5)) { relationship in
                    Button {
                        controller.applyTopRelationship(relationship)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: .SQSpace.xs) {
                                Text("\(relationship.driverTitle) -> \(relationship.outcomeTitle)")
                                    .sqFont(.bodySmallSemiBold)
                                    .sqForegroundColor(.textPrimary)

                                Text(relationship.effectSummary)
                                    .sqFont(.bodyExtraSmall)
                                    .sqForegroundColor(.textSecondary)
                                    .lineLimit(2)
                            }

                            Spacer()

                            SQDashboardTrendBadge(
                                text: relationship.confidence.badgeTitle,
                                tone: tone(for: relationship.effect),
                                symbol: nil
                            )
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.SQSpace.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
    }

    private var emptyState: some View {
        Text("Track at least two metrics to compare relationships.")
            .sqFont(.bodySmall)
            .sqForegroundColor(.textSecondary)
            .padding(.SQSpace.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
    }

    private var noPatternState: some View {
        Text("No clear pattern yet for this pair. Try a longer range or a different timing.")
            .sqFont(.bodySmall)
            .sqForegroundColor(.textSecondary)
            .padding(.SQSpace.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
    }

    private func legend(color: SQColor, title: String) -> some View {
        HStack(spacing: .SQSpace.xs) {
            Circle()
                .fill(color.color)
                .frame(width: 8, height: 8)

            Text(title)
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textSecondary)
                .lineLimit(1)
        }
    }

    private func relationshipChartModel(
        _ result: SQInsightExplorerRelationshipResult,
        width: CGFloat,
        height: CGFloat
    ) -> MultiLineChartModel? {
        let sortedPoints = result.chartPoints.sorted { $0.date < $1.date }
        let driverPoints = sortedPoints.map {
            LineChartIdentifiablePoint(
                id: $0.id,
                point: CGPoint(x: $0.date.timeIntervalSince1970, y: $0.driverValue)
            )
        }
        let outcomePoints = sortedPoints.map {
            LineChartIdentifiablePoint(
                id: $0.id,
                point: CGPoint(x: $0.date.timeIntervalSince1970, y: $0.outcomeValue)
            )
        }
        let driverFocusLabels = Dictionary(uniqueKeysWithValues: sortedPoints.map { ($0.id, $0.driverDisplayLabel) })
        let outcomeFocusLabels = Dictionary(uniqueKeysWithValues: sortedPoints.map { ($0.id, $0.outcomeDisplayLabel) })

        let chartModel = MultiLineChartModel(
            width: max(width, 1),
            height: height,
            series: [
                .init(
                    id: result.driverId,
                    title: result.driverTitle,
                    color: SQColor.dashboardGlowBlue.color,
                    inputPoints: driverPoints,
                    focusLabelByPointId: driverFocusLabels
                ),
                .init(
                    id: result.outcomeId,
                    title: result.outcomeTitle,
                    color: SQColor.dashboardGlowMint.color,
                    inputPoints: outcomePoints,
                    focusLabelByPointId: outcomeFocusLabels
                )
            ],
            uiConfig: relationshipChartUIConfig(),
            gridConfig: GridConfig(
                lineColor: SQColor.glassStroke.color.opacity(SQColor.isDarkMode ? 0.9 : 0.55)
            ),
            focusConfig: relationshipChartFocusConfig()
        )

        if chartModel == nil {
            SQLogger.shared.log(
                "PTD InsightExplorer chart unavailable driver=\(result.driverId) outcome=\(result.outcomeId) chartPoints=\(sortedPoints.count) driverPoints=\(driverPoints.count) outcomePoints=\(outcomePoints.count) width=\(width) height=\(height)",
                .debug,
                context: .dashboard
            )
        }

        return chartModel
    }

    private func relationshipChartUIConfig() -> LineChartModel.UIConfig {
        LineChartModel.UIConfig(
            colorConfig: .init(
                textPrimary: SQColor.textPrimary.color,
                textSecondary: SQColor.textSecondary.color,
                backgroundPrimary: SQColor.glassCardTint.color,
                backgroundSecondary: SQColor.glassPopoverTint.color,
                lineColor: SQColor.dashboardGlowBlue.color,
                trendLineColor: nil
            ),
            fontConfig: .init(
                font: SQFont(type: .bodyExtraSmall).font,
                boldFont: SQFont(type: .bodySmallBold).font
            )
        )
    }

    private func relationshipChartFocusConfig() -> MultiLineChartFocusConfig {
        let xLabelBuilder: @Sendable (String, CGFloat) -> String = { _, xValue in
            let date = Date(timeIntervalSince1970: TimeInterval(xValue))
            return date.formattedString(with: .medium)
        }

        let yLabelBuilder: @Sendable (String, String, CGFloat) -> String = { _, _, yValue in
            "\(Double(yValue).sqStringRoundedTo(places: 0))%"
        }

        return .init(
            focusColor: SQColor.dashboardGlowBlue.color,
            xLabelBuilder: xLabelBuilder,
            yLabelBuilder: yLabelBuilder
        )
    }

    private func signed(_ value: Double) -> String {
        let rounded = value.sqStringRoundedTo(places: 0)
        return value > 0 ? "+\(rounded)" : rounded
    }

    private func tone(for effect: SQInsightEffect) -> SQDashboardTrendTone {
        switch effect {
        case .positive:
            return .positive
        case .negative:
            return .negative
        case .neutral:
            return .neutral
        }
    }
}
