//
//  SQDatePickerModal.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 2/2/26.
//

import SwiftUI

struct SQDatePickerModal: View {
    private static let modalMaxWidth: CGFloat = 540
    private static let modalPreferredHeight: CGFloat = 700

    enum Mode: String {
        case recent = "Recent"
        case calendar = "Calendar"
    }

    struct DateEntry: Identifiable {
        let id = UUID()
        let date: Date
        let displayText: String
        let period: SQMetricPeriod
        let isToday: Bool
        let isCompleted: Bool
    }

    let dateEntries: [DateEntry]
    let completionMap: [String: Set<SQMetricPeriod>]
    var selectedDate: Date?
    var selectedPeriod: SQMetricPeriod?
    let onDateSelected: (Date, SQMetricPeriod) -> Void
    let onDismiss: () -> Void
    @State private var mode: Mode
    @State private var displayedMonth: Date
    @State private var calendarSelectedDate: Date

    init(
        dateEntries: [DateEntry],
        completionMap: [String: Set<SQMetricPeriod>],
        selectedDate: Date?,
        selectedPeriod: SQMetricPeriod?,
        onDateSelected: @escaping (Date, SQMetricPeriod) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.dateEntries = dateEntries
        self.completionMap = completionMap
        self.selectedDate = selectedDate
        self.selectedPeriod = selectedPeriod
        self.onDateSelected = onDateSelected
        self.onDismiss = onDismiss

        let initialDate = Calendar.current.startOfDay(for: selectedDate ?? .now)
        _mode = State(initialValue: .recent)
        _displayedMonth = State(initialValue: Self.monthStart(for: initialDate))
        _calendarSelectedDate = State(initialValue: initialDate)
    }

    private func isSelected(_ entry: DateEntry) -> Bool {
        guard let selectedDate, let selectedPeriod else { return false }
        return Calendar.current.isDate(entry.date, inSameDayAs: selectedDate) && entry.period == selectedPeriod
    }

    private var titleText: String {
        "Select Check-In"
    }

    private var modeSegments: [Mode] {
        [.recent, .calendar]
    }

    private var monthTitle: String {
        let calendar = Calendar.current
        let monthName = calendar.monthSymbols[calendar.component(.month, from: displayedMonth) - 1]
        let year = calendar.component(.year, from: displayedMonth)
        return "\(monthName) \(year)"
    }

    private var displayedMonthDays: [Date?] {
        let calendar = Calendar.current
        guard let range = calendar.range(of: .day, in: .month, for: displayedMonth) else { return [] }

        let firstOfMonth = Self.monthStart(for: displayedMonth)
        let weekday = calendar.component(.weekday, from: firstOfMonth)
        let leadingPadding = (weekday - calendar.firstWeekday + 7) % 7

        var days = Array<Date?>(repeating: nil, count: leadingPadding)
        days.append(contentsOf: range.compactMap { day -> Date? in
            calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth)
        })
        return days
    }

    private var weekdaySymbols: [String] {
        let calendar = Calendar.current
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        guard !symbols.isEmpty else { return [] }

        let firstWeekdayIndex = max(0, calendar.firstWeekday - 1)
        let orderedSymbols = Array(symbols[firstWeekdayIndex...]) + Array(symbols[..<firstWeekdayIndex])
        return orderedSymbols
    }

    private var selectedCalendarDateTitle: String {
        calendarSelectedDate.formattedString(with: .long)
    }

    private static func monthStart(for date: Date) -> Date {
        let calendar = Calendar.current
        return calendar.date(from: calendar.dateComponents([.year, .month], from: date))
            ?? calendar.startOfDay(for: date)
    }

    private func completedPeriods(for date: Date) -> Set<SQMetricPeriod> {
        completionMap[date.anchorDayKey()] ?? []
    }

    private func isFuture(_ date: Date) -> Bool {
        Calendar.current.startOfDay(for: date) > Calendar.current.startOfDay(for: .now)
    }

    private func isCalendarSelected(_ date: Date) -> Bool {
        Calendar.current.isDate(date, inSameDayAs: calendarSelectedDate)
    }

    private func isCurrentMonth(_ date: Date) -> Bool {
        Calendar.current.isDate(date, equalTo: displayedMonth, toGranularity: .month)
    }

    private func completionSubtitle(for period: SQMetricPeriod, date: Date) -> String {
        completedPeriods(for: date).contains(period) ? "Completed" : "Not completed"
    }

    private var modalWidth: CGFloat {
        min(UIScreen.main.bounds.width - 32, Self.modalMaxWidth)
    }

    private var modalHeight: CGFloat {
        min(UIScreen.main.bounds.height - 96, Self.modalPreferredHeight)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: .SQSpace.xs) {
                    Text(titleText)
                        .sqFont(.title2)
                        .sqForegroundColor(.textPrimary)

                    Text("Choose a date and period to edit or review.")
                        .sqFont(.bodyExtraSmall)
                        .sqForegroundColor(.textSecondary)
                }

                Spacer()

                Button {
                    onDismiss()
                } label: {
                    RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                        .fill(SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.8 : 1))
                        .frame(width: 32, height: 32)
                        .overlay(
                            RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                                .stroke(SQColor.glassStroke.color, lineWidth: 1)
                        )
                        .overlay(
                            SQImageView(
                                image: .init(
                                    symbol: .xMark,
                                    symbolStyle: .colorWithFont(.textSecondary, font: .headerSmall)
                                )
                            )
                            .frame(width: 12, height: 12)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.SQSpace.xl)

            Divider()
                .sqTintColor(.glassStroke)

            VStack(spacing: .SQSpace.m) {
                HStack(spacing: .SQSpace.s) {
                    ForEach(modeSegments, id: \.rawValue) { entryMode in
                        Button {
                            var transaction = Transaction()
                            transaction.animation = nil
                            withTransaction(transaction) {
                                mode = entryMode
                            }
                        } label: {
                            Text(entryMode.rawValue)
                                .sqFont(.bodySemiBold)
                                .sqForegroundColor(mode == entryMode ? .textPrimary : .textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, .SQSpace.s)
                                .background(
                                    RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                                        .fill(
                                            mode == entryMode
                                                ? SQColor.dashboardGlowBlue.color.opacity(SQColor.isDarkMode ? 0.18 : 0.12)
                                                : SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.54 : 0.9)
                                        )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                                        .stroke(
                                            mode == entryMode
                                                ? SQColor.dashboardGlowBlue.color.opacity(0.36)
                                                : SQColor.glassStroke.color,
                                            lineWidth: 1
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, .SQSpace.xl)
                .padding(.top, .SQSpace.l)

                if mode == .recent {
                    ScrollView {
                        VStack(spacing: .SQSpace.s) {
                            ForEach(dateEntries) { entry in
                                recentEntryButton(entry)
                            }
                        }
                        .padding(.horizontal, .SQSpace.xl)
                        .padding(.bottom, .SQSpace.xl)
                    }
                } else {
                    calendarContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(width: modalWidth, height: modalHeight, alignment: .top)
        .animation(nil, value: mode)
        .background {
            ZStack {
                SQSheetBackground()

                RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous)
                    .fill(SQColor.glassPopoverTint.color.opacity(SQColor.isDarkMode ? 0.58 : 0.84))
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous)
                .stroke(SQColor.glassStrokeStrong.color, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous))
        .shadow(color: Color.black.opacity(0.22), radius: 24, x: 0, y: 10)
    }

    private func recentEntryButton(_ entry: DateEntry) -> some View {
        Button {
            onDateSelected(entry.date, entry.period)
            onDismiss()
        } label: {
            HStack(spacing: .SQSpace.m) {
                ZStack {
                    Circle()
                        .fill(
                            entry.isCompleted
                                ? SQColor.dashboardGlowMint.color.opacity(0.16)
                                : SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.7 : 0.96)
                        )

                    Circle()
                        .stroke(
                            entry.isCompleted
                                ? SQColor.dashboardGlowMint.color.opacity(0.45)
                                : SQColor.glassStroke.color,
                            lineWidth: 1
                        )

                    if entry.isCompleted {
                        SQImageView(
                            image: .init(
                                symbol: .checkmark,
                                symbolStyle: .colorWithFont(.textPrimary, font: .headerSmall)
                            )
                        )
                        .frame(width: 10, height: 10)
                    }
                }
                .frame(width: 18, height: 18)

                VStack(alignment: .leading, spacing: .SQSpace.xs) {
                    Text(entry.displayText)
                        .sqFont(.bodySemiBold)
                        .sqForegroundColor(.textPrimary)

                    HStack(spacing: .SQSpace.xs) {
                        if entry.isToday {
                            Text("Today")
                                .sqFont(.bodyExtraSmall)
                                .sqForegroundColor(.textSecondary)
                        }

                        Text(entry.period.rawValue.capitalized)
                            .sqFont(.bodyExtraSmall)
                            .sqForegroundColor(.textSecondary)
                    }
                }

                Spacer()

                if isSelected(entry) {
                    SQDashboardTrendBadge(
                        text: "Selected",
                        tone: .positive,
                        symbol: nil
                    )
                } else {
                    SQImageView(
                        image: .init(
                            symbol: .chevronRight,
                            symbolStyle: .colorWithFont(.textTertiary, font: .bodyExtraSmall)
                        )
                    )
                    .frame(width: 8)
                }
            }
            .padding(.SQSpace.l)
            .background(
                RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous)
                    .fill(
                        isSelected(entry)
                            ? SQColor.dashboardGlowBlue.color.opacity(SQColor.isDarkMode ? 0.14 : 0.10)
                            : SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.72 : 0.96)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous)
                    .stroke(
                        isSelected(entry)
                            ? SQColor.dashboardGlowBlue.color.opacity(0.40)
                            : SQColor.glassStroke.color,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var calendarContent: some View {
        VStack(spacing: .SQSpace.l) {
            VStack(spacing: .SQSpace.m) {
                HStack {
                    Button {
                        if let previousMonth = Calendar.current.date(byAdding: .month, value: -1, to: displayedMonth) {
                            displayedMonth = Self.monthStart(for: previousMonth)
                        }
                    } label: {
                        SQImageView(
                            image: .init(
                                symbol: .chevronLeft,
                                symbolStyle: .colorWithFont(.textSecondary, font: .headerSmall)
                            )
                        )
                        .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text(monthTitle)
                        .sqFont(.headerSmall)
                        .sqForegroundColor(.textPrimary)

                    Spacer()

                    Button {
                        if let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: displayedMonth) {
                            displayedMonth = Self.monthStart(for: nextMonth)
                        }
                    } label: {
                        SQImageView(
                            image: .init(
                                symbol: .chevronRight,
                                symbolStyle: .colorWithFont(.textSecondary, font: .headerSmall)
                            )
                        )
                        .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.plain)
                    .disabled(Calendar.current.compare(displayedMonth, to: Self.monthStart(for: .now), toGranularity: .month) != .orderedAscending)
                    .opacity(Calendar.current.compare(displayedMonth, to: Self.monthStart(for: .now), toGranularity: .month) != .orderedAscending ? 0.35 : 1)
                }

                HStack {
                    Spacer()

                    Button {
                        let today = Calendar.current.startOfDay(for: .now)
                        calendarSelectedDate = today
                        displayedMonth = Self.monthStart(for: today)
                    } label: {
                        Text("Today")
                            .sqFont(.bodyExtraSmall)
                            .sqForegroundColor(.textSecondary)
                    }
                    .buttonStyle(.plain)
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: .SQSpace.xs), count: 7), spacing: .SQSpace.s) {
                    ForEach(weekdaySymbols, id: \.self) { symbol in
                        Text(symbol)
                            .sqFont(.bodyExtraSmall)
                            .sqForegroundColor(.textTertiary)
                            .frame(maxWidth: .infinity)
                    }

                    ForEach(Array(displayedMonthDays.enumerated()), id: \.offset) { _, day in
                        if let day {
                            calendarDayButton(day)
                        } else {
                            Color.clear
                                .frame(height: 44)
                        }
                    }
                }
            }
            .padding(.SQSpace.l)
            .background(
                RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous)
                    .fill(SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.72 : 0.96))
            )
            .overlay(
                RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous)
                    .stroke(SQColor.glassStroke.color, lineWidth: 1)
            )

            calendarSelectionCard
        }
        .padding(.horizontal, .SQSpace.xl)
        .padding(.bottom, .SQSpace.xl)
    }

    private func calendarDayButton(_ day: Date) -> some View {
        let periods = completedPeriods(for: day)
        let isSelected = isCalendarSelected(day)
        let isToday = Calendar.current.isDateInToday(day)
        let isDisabled = isFuture(day)

        return Button {
            calendarSelectedDate = day
        } label: {
            VStack(spacing: 4) {
                Text("\(Calendar.current.component(.day, from: day))")
                    .sqFont(.bodySemiBold)
                    .sqForegroundColor(isDisabled ? .textTertiary : .textPrimary)

                HStack(spacing: 4) {
                    Circle()
                        .fill(periods.contains(.morning) ? SQColor.dashboardGlowMint.color : Color.clear)
                        .overlay(Circle().stroke(periods.contains(.morning) ? SQColor.dashboardGlowMint.color.opacity(0.6) : Color.clear, lineWidth: 1))
                        .frame(width: 5, height: 5)

                    Circle()
                        .fill(periods.contains(.evening) ? SQColor.dashboardGlowBlue.color : Color.clear)
                        .overlay(Circle().stroke(periods.contains(.evening) ? SQColor.dashboardGlowBlue.color.opacity(0.6) : Color.clear, lineWidth: 1))
                        .frame(width: 5, height: 5)
                }
                .frame(height: 6)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                    .fill(
                        isSelected
                            ? SQColor.dashboardGlowBlue.color.opacity(SQColor.isDarkMode ? 0.18 : 0.12)
                            : (isToday
                                ? SQColor.dashboardGlowMint.color.opacity(SQColor.isDarkMode ? 0.12 : 0.08)
                                : Color.clear)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                    .stroke(
                        isSelected
                            ? SQColor.dashboardGlowBlue.color.opacity(0.38)
                            : (isToday ? SQColor.dashboardGlowMint.color.opacity(0.28) : Color.clear),
                        lineWidth: 1
                    )
            )
            .opacity(isCurrentMonth(day) ? (isDisabled ? 0.4 : 1) : 0.5)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }

    private var calendarSelectionCard: some View {
        VStack(alignment: .leading, spacing: .SQSpace.m) {
            HStack {
                VStack(alignment: .leading, spacing: .SQSpace.xs) {
                    Text(selectedCalendarDateTitle)
                        .sqFont(.bodySemiBold)
                        .sqForegroundColor(.textPrimary)

                    Text("Choose morning or evening for this day.")
                        .sqFont(.bodyExtraSmall)
                        .sqForegroundColor(.textSecondary)
                }

                Spacer()
            }

            VStack(spacing: .SQSpace.s) {
                periodButton(.morning)
                periodButton(.evening)
            }
        }
        .padding(.SQSpace.l)
        .background(
            RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous)
                .fill(SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.72 : 0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous)
                .stroke(SQColor.glassStroke.color, lineWidth: 1)
        )
    }

    private func periodButton(_ period: SQMetricPeriod) -> some View {
        let isCompleted = completedPeriods(for: calendarSelectedDate).contains(period)
        let isActiveSelection = (selectedPeriod == period) && (selectedDate.map { Calendar.current.isDate($0, inSameDayAs: calendarSelectedDate) } ?? false)

        return Button {
            onDateSelected(calendarSelectedDate, period)
            onDismiss()
        } label: {
            HStack(spacing: .SQSpace.m) {
                ZStack {
                    Circle()
                        .fill(
                            isCompleted
                                ? SQColor.dashboardGlowMint.color.opacity(0.16)
                                : SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.7 : 0.96)
                        )

                    Circle()
                        .stroke(
                            isCompleted
                                ? SQColor.dashboardGlowMint.color.opacity(0.45)
                                : SQColor.glassStroke.color,
                            lineWidth: 1
                        )

                    if isCompleted {
                        SQImageView(
                            image: .init(
                                symbol: .checkmark,
                                symbolStyle: .colorWithFont(.textPrimary, font: .bodyExtraSmall)
                            )
                        )
                        .frame(width: 9, height: 9)
                    }
                }
                .frame(width: 18, height: 18)

                VStack(alignment: .leading, spacing: .SQSpace.xs) {
                    Text(period.rawValue.capitalized)
                        .sqFont(.bodySemiBold)
                        .sqForegroundColor(.textPrimary)

                    Text(completionSubtitle(for: period, date: calendarSelectedDate))
                        .sqFont(.bodyExtraSmall)
                        .sqForegroundColor(.textSecondary)
                }

                Spacer()

                if isActiveSelection {
                    SQDashboardTrendBadge(
                        text: "Selected",
                        tone: .positive,
                        symbol: nil
                    )
                } else {
                    SQImageView(
                        image: .init(
                            symbol: .chevronRight,
                            symbolStyle: .colorWithFont(.textTertiary, font: .bodyExtraSmall)
                        )
                    )
                    .frame(width: 8)
                }
            }
            .padding(.SQSpace.l)
            .background(
                RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous)
                    .fill(
                        isActiveSelection
                            ? SQColor.dashboardGlowBlue.color.opacity(SQColor.isDarkMode ? 0.14 : 0.10)
                            : SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.62 : 0.92)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous)
                    .stroke(
                        isActiveSelection
                            ? SQColor.dashboardGlowBlue.color.opacity(0.40)
                            : SQColor.glassStroke.color,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
