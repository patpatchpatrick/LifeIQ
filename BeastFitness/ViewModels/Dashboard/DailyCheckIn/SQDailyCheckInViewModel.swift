//
//  SQDailyCheckInViewModel.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/25/25.
//

import Combine
import SwiftUI
import SwiftData
import BeastFitnessCore

@Observable @MainActor
final class SQDailyCheckInViewModel: Identifiable {
    typealias MetricId = SQMetricId
    private var cancellables = Set<AnyCancellable>()
    private var modelContext: ModelContext?

    let id = UUID()
    private(set) var stats: SQDailyCheckInStats?
    private(set) var targetDate: Date
    let eventHub: EventHub
    let dashboardInterface: SQDashboardInterface = SQDashboardController.default

    private let dailyCheckInManager: SQDailyCheckInManaging
    private let metricsManager: SQMetricsManaging

    var isEditingPastDate: Bool {
        !Calendar.current.isDateInToday(targetDate)
    }

    private(set) var rows: [SQDailyCheckInRowViewModel] = []
    let onDismiss: () -> Void
    private(set) var isLoading: Bool = false

    var isAddMetricSheetDisplayed: Bool = false
    let metricsListController = SQMetricsListController.default(
        state: SQAppState.shared.metricsListState,
        metricsManager: SQMetricsManager.shared)

    init(
        eventHub: EventHub,
        stats: SQDailyCheckInStats?,
        targetDate: Date = .now,
        dailyCheckInManager: SQDailyCheckInManaging = SQDailyCheckInManager(),
        metricsManager: SQMetricsManaging,
        onDismiss: @escaping () -> Void
    ) {
        self.eventHub = eventHub
        self.stats = stats
        self.targetDate = targetDate
        self.dailyCheckInManager = dailyCheckInManager
        self.metricsManager = metricsManager
        self.onDismiss = onDismiss

        handleEventSubscriptions(hub: eventHub)
    }
    
    // MARK: - Subscriptions
    
    private func handleEventSubscriptions(hub: EventHub) {
        hub.metricEvents.sink { [weak self] event in
            guard let self else { return }
            switch event {
            case .metricsUpdated:
                SQLogger.shared.log("Metric events updated, refreshing daily check in list", .debug, context: .dailyCheckIn)
                guard let modelContext = self.modelContext else { return }
                Task {
                    await self.refresh(for: self.targetDate, modelContext: modelContext)
                }
            }
        }.store(in: &cancellables)
    }

    // MARK: - Row Building

    /// Comprehensive refresh function that updates date, loads stats, and refreshes rows
    @MainActor
    func refresh(for date: Date, modelContext: ModelContext) async {
        self.modelContext = modelContext
        self.targetDate = date

        // Load stats for the new date
        let loadedStats = try? await dailyCheckInManager.getDailyCheckInStats(
            for: date,
            context: modelContext
        )
        self.stats = loadedStats

        // Refresh rows with new stats
        do {
            try metricsManager.loadIfNeeded(using: modelContext)
            self.rows = buildRows(for: loadedStats)
        } catch {
            eventHub.alertEvents.send(.present(.init(
                SQError.standard(withDescription: "Error loading metrics: \(error.localizedDescription)")
            )))
            self.rows = [buildNotesRow(stats: loadedStats)]
        }
    }

    @MainActor
    func refreshRows(stats: SQDailyCheckInStats?, modelContext: ModelContext) {
        self.modelContext = modelContext
        do {
            try metricsManager.loadIfNeeded(using: modelContext)
            self.rows = buildRows(for: stats)
        } catch {
            eventHub.alertEvents.send(.present(.init(
                SQError.standard(withDescription: "Error loading metrics: \(error.localizedDescription)")
            )))
            self.rows = [buildNotesRow(stats: stats)]
        }
    }

    // MARK: - Generic Segments

    enum SQBinaryYesNo: String, SQCheckInSegmentable, CaseIterable {
        case no, yes
        var segmentId: String { rawValue }
        var segmentTitle: String { self == .yes ? "Yes" : "No" }
        var value: Float { self == .yes ? 1 : 0 }
    }

    struct SQScaleSegment: SQCheckInSegmentable, Hashable {
        let segmentId: String
        let segmentTitle: String
        let value: Float
    }

    // MARK: - Build Rows

    func buildRows(for stats: SQDailyCheckInStats?) -> [SQDailyCheckInRowViewModel] {
        var built: [SQDailyCheckInRowViewModel] = []

        let metrics = metricsManager.dailyCheckInMetrics()

        for metric in metrics {
            let field: SQDailyCheckInField = .metric(id: metric.id)

            // Build display title with emoji and unit
            var displayTitle = metric.title

            // Add unit suffix if present (e.g., "Weight (lbs)")
            if metric.unit != .none {
                displayTitle = "\(displayTitle) (\(metric.unit.rawValue))"
            }

            // Prepend emoji if present
            if let emoji = metric.emoji {
                displayTitle = "\(emoji) \(displayTitle)"
            }

            switch metric.kind {

            case .binary:
                let initial = Self.binaryInitialSelection(metricId: metric.id, stats: stats)

                let row = SQDailyCheckInRowSegmentedControlViewModel(
                    field: field,
                    title: displayTitle,
                    segments: SQBinaryYesNo.allCases,
                    initialSelection: initial,
                    onFocused: { [weak self] in self?.handleRowFocused($0) }
                )
                built.append(row)

            case .scale:
                let segments = Self.scaleSegments(for: metric)
                guard !segments.isEmpty else { continue }

                let initial = Self.scaleInitialSelection(metricId: metric.id, stats: stats, segments: segments)

                let row = SQDailyCheckInRowSegmentedControlViewModel(
                    field: field,
                    title: displayTitle,
                    segments: segments,
                    initialSelection: initial,
                    onFocused: { [weak self] in self?.handleRowFocused($0) }
                )
                built.append(row)

            case .number:
                let tf = Self.numericTextField(metric: metric)

                let row = SQDailyCheckInTextEntryViewModel(
                    field: field,
                    title: displayTitle,
                    textFieldViewModel: tf,
                    onFocused: { [weak self] in self?.handleRowFocused($0) }
                )

                if let existing = stats?.values[metric.id] {
                    row.initialize(with: Self.formatNumber(existing, metric: metric))
                }

                built.append(row)
            }
        }

        built.append(buildNotesRow(stats: stats))

        for (idx, row) in built.enumerated() { row.number = String(idx + 1) }
        return built
    }

    // MARK: - Scale Helpers

    private static func scaleSegments(for metric: SQMetricDefinition) -> [SQScaleSegment] {
        let minV = metric.min ?? 0
        let maxV = metric.max ?? 10
        let stepV = metric.step ?? 1

        guard stepV > 0, maxV >= minV else { return [] }

        var segments: [SQScaleSegment] = []
        var v = minV
        var safety = 0

        while v <= maxV + 0.0001, safety < 200 {
            let title = v.clean
            segments.append(.init(segmentId: title, segmentTitle: title, value: v))
            v += stepV
            safety += 1
        }

        return segments
    }

    private static func scaleInitialSelection(
        metricId: String,
        stats: SQDailyCheckInStats?,
        segments: [SQScaleSegment]
    ) -> SQScaleSegment? {
        guard let stored = stats?.values[metricId] else { return nil }
        return segments.min(by: { abs($0.value - stored) < abs($1.value - stored) })
    }

    // MARK: - Number Helpers

    private static func numericTextField(metric: SQMetricDefinition) -> SQTextFieldViewModel {
        let maxDecimalPlaces = maxDecimalPlaces(fromStep: metric.step) ?? 0

        let min: Float = metric.min ?? -Float.greatestFiniteMagnitude
        let max: Float = metric.max ?? Float.greatestFiniteMagnitude

        return SQTextFieldViewModel(
            lineLimit: 1,
            placeholder: metric.unit == .hours ? "8" : "0",
            keyboardType: .decimalPad,
            textChangeFormatter: .decimal(maxDecimalPlaces: maxDecimalPlaces),
            validationRule: .decimal(maxDecimalPlaces: maxDecimalPlaces, range: Double(min)...Double(max)),
            errorHandler: { text in
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }
                guard let value = Float(trimmed) else { return "Enter a number" }
                if value > max { return "Must be ≤ \(max.clean)" }
                if value < min { return "Must be ≥ \(min.clean)" }
                return nil
            }
        )
    }


    private static func formatNumber(_ v: Float, metric: SQMetricDefinition) -> String {
        let places = maxDecimalPlaces(fromStep: metric.step) ?? 0
        return String(format: "%.\(places)f", v)
    }

    private static func maxDecimalPlaces(fromStep step: Float?) -> Int? {
        guard let step, step > 0 else { return nil }
        let s = String(step)
        guard let dot = s.firstIndex(of: ".") else { return 0 }
        return s.distance(from: dot, to: s.endIndex) - 1
    }

    // MARK: - Binary Helpers

    private static func binaryInitialSelection(metricId: String, stats: SQDailyCheckInStats?) -> SQBinaryYesNo? {
        guard let v = stats?.values[metricId] else { return nil }
        return v >= 0.5 ? .yes : .no
    }

    // MARK: - Notes Row

    private func buildNotesRow(stats: SQDailyCheckInStats?) -> SQDailyCheckInRowViewModel {
        let notesMaxCharacterCount: Int = SQDailyCheckInStats.notesMaxChars

        let notesTextField = SQTextFieldViewModel(
            uiConfig: .standard,
            axis: .vertical,
            lineLimit: 4,
            placeholder: "Notes (optional: drank, stress, travel, etc.)",
            keyboardType: .default,
            textAutoCap: .sentences,
            autoCorrectionEnabled: true,
            textChangeFormatter: .maxLength(notesMaxCharacterCount),
            validationRule: .length(max: notesMaxCharacterCount),
            errorHandler: { _ in nil }
        )

        let notesRow = SQDailyCheckInTextEntryViewModel(
            field: .notes,
            title: "Notes",
            textFieldViewModel: notesTextField,
            onFocused: { [weak self] in self?.handleRowFocused($0) }
        )

        notesRow.initialize(with: stats?.notes)
        return notesRow
    }

    // MARK: - Focus handling

    private func handleRowFocused(_ row: SQDailyCheckInRowViewModel) {
        let rowIsTextField = row is SQDailyCheckInTextEntryViewModel
        if !rowIsTextField { hideKeyboard() }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }

    // MARK: - Form Submission

    var canSubmit: Bool {
        // Allow submission if at least one row is completed
        rows.contains { $0.isCompleted }
    }

    func submitTapped(modelContext: ModelContext) async {
        isLoading = true
        rows.forEach { $0.isDisabled = true }

        defer {
            isLoading = false
            rows.forEach { $0.isDisabled = false }
        }

        guard canSubmit else {
            SQLogger.shared.log(
                "Should not be able to submit check-in if fields aren't valid",
                .error,
                context: .dailyCheckIn
            )
            return
        }

        // Make sure manager is loaded (so allMetrics() can resolve definitions)
        do { try metricsManager.loadIfNeeded(using: modelContext) } catch {}

        var values: [String: Float] = [:]
        var notes: String? = nil

        for row in rows {
            switch row.field {

            case .metric(let metricId):
                guard let metric = metricsManager.allMetrics(includeArchived: true).first(where: { $0.id == metricId }) else { continue }

                switch metric.kind {

                case .binary:
                    if
                        let segmented = row as? SQDailyCheckInRowSegmentedControlViewModel,
                        let seg = segmented.selectedSegment,
                        let yn = SQBinaryYesNo.fromSegment(seg)
                    {
                        values[metricId] = yn.value
                    }

                case .scale:
                    if
                        let segmented = row as? SQDailyCheckInRowSegmentedControlViewModel,
                        let seg = segmented.selectedSegment,
                        let v = Float(seg.id)
                    {
                        values[metricId] = v
                    }

                case .number:
                    if let textRow = row as? SQDailyCheckInTextEntryViewModel {
                        let raw = textRow.textFieldViewModel.text.trimmingCharacters(in: .whitespacesAndNewlines)
                        if let v = Float(raw) { values[metricId] = v }
                    }
                }

            case .notes:
                if let textRow = row as? SQDailyCheckInTextEntryViewModel {
                    let text = textRow.textFieldViewModel.text.trimmingCharacters(in: .whitespacesAndNewlines)
                    notes = text.isEmpty ? nil : text
                }
            }
        }

        let stats = SQDailyCheckInStats(
            date: targetDate,
            values: values,
            notes: notes
        )

        SQLogger.shared.log("Submitting daily stats: \(stats)", .debug, context: .dailyCheckIn)

        do {
            try await dailyCheckInManager.saveDailyCheckInStats(stats: stats, to: modelContext)
            await dashboardInterface.refreshUI(for: modelContext)
            onDismiss()
        } catch {
            eventHub.alertEvents.send(
                .present(.init(SQError.standard(withDescription: "Error saving check in data: \(error.localizedDescription).")))
            )
        }
    }

    func addMetricTapped() {
        isAddMetricSheetDisplayed = true
    }

    func showDatePicker(modelContext: ModelContext) {
        Task {
            // Load date entries with completion status
            let dateEntries = await loadDateEntries(modelContext: modelContext)

            // Show modal with pre-loaded entries
            eventHub.modalEvents.send(.presentDatePicker(
                dateEntries: dateEntries,
                onDateSelected: { [weak self] selectedDate in
                    guard let self else { return }
                    Task {
                        await self.refresh(for: selectedDate, modelContext: modelContext)
                    }
                }
            ))
        }
    }

    private func loadDateEntries(modelContext: ModelContext) async -> [SQDatePickerModal.DateEntry] {
        let calendar = Calendar.current
        var entries: [SQDatePickerModal.DateEntry] = []

        let today = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.locale = .current
        dateFormatter.dateFormat = "EEEE, MMMM d, yyyy"

        // Add "Today" first
        let todayNormalized = calendar.startOfDay(for: today)
        let todayStats = try? await dailyCheckInManager.getDailyCheckInStats(
            for: todayNormalized,
            context: modelContext
        )

        entries.append(SQDatePickerModal.DateEntry(
            date: todayNormalized,
            displayText: dateFormatter.string(from: today),
            isToday: true,
            isCompleted: todayStats != nil
        ))

        // Add past 30 days
        for i in 1...30 {
            guard let pastDate = calendar.date(byAdding: .day, value: -i, to: today) else { continue }
            let normalizedDate = calendar.startOfDay(for: pastDate)

            let stats = try? await dailyCheckInManager.getDailyCheckInStats(
                for: normalizedDate,
                context: modelContext
            )

            entries.append(SQDatePickerModal.DateEntry(
                date: normalizedDate,
                displayText: dateFormatter.string(from: normalizedDate),
                isToday: false,
                isCompleted: stats != nil
            ))
        }

        return entries
    }
}

// MARK: - Segmented Helpers

protocol SQCheckInSegmentable: Hashable {
    var segmentTitle: String { get }
    var segmentId: String { get }
}

extension SQCheckInSegmentable where Self: CaseIterable {
    static func fromSegment(_ segment: SQSegmentedControlSegment) -> Self? {
        Self.allCases.first { $0.segmentId == segment.id }
    }
}

private extension Float {
    var clean: String {
        if self.rounded() == self { return "\(Int(self))" }
        return String(format: "%.1f", Double(self))
    }
}
