//
//  SQDatePickerModal.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 2/2/26.
//

import SwiftUI

struct SQDatePickerModal: View {
    struct DateEntry: Identifiable {
        let id = UUID()
        let date: Date
        let displayText: String
        let period: SQMetricPeriod
        let isToday: Bool
        let isCompleted: Bool
    }

    let dateEntries: [DateEntry]
    var selectedDate: Date?
    var selectedPeriod: SQMetricPeriod?
    let onDateSelected: (Date, SQMetricPeriod) -> Void
    let onDismiss: () -> Void

    private func isSelected(_ entry: DateEntry) -> Bool {
        guard let selectedDate, let selectedPeriod else { return false }
        return Calendar.current.isDate(entry.date, inSameDayAs: selectedDate) && entry.period == selectedPeriod
    }

    private var titleText: String {
        "Select Check-In"
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

            ScrollView {
                VStack(spacing: .SQSpace.s) {
                    ForEach(dateEntries) { entry in
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
                }
                .padding(.SQSpace.xl)
            }
        }
        .frame(maxWidth: 520, maxHeight: 620)
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
}
