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
    let onDateSelected: (Date, SQMetricPeriod) -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Select Date")
                    .sqFont(.title2)
                    .sqForegroundColor(.textPrimary)

                Spacer()

                Button {
                    onDismiss()
                } label: {
                    Image(systemName: SQImageSymbol.xMark.rawValue)
                        .sqForegroundColor(.textSecondary)
                        .padding(.SQSpace.s)
                }
            }
            .padding(.SQSpace.l)

            Divider()

            // Date list
            ScrollView {
                VStack(spacing: .SQSpace.xs) {
                    ForEach(dateEntries) { entry in
                        Button {
                            onDateSelected(entry.date, entry.period)
                            onDismiss()
                        } label: {
                            HStack(spacing: .SQSpace.m) {
                                // Completion indicator circle
                                Circle()
                                    .fill(entry.isCompleted
                                          ? Color.green
                                          : Color.gray.opacity(0.3))
                                    .frame(width: 8, height: 8)

                                VStack(alignment: .leading, spacing: .SQSpace.xs) {
                                    Text(entry.displayText)
                                        .sqFont(.body)
                                        .sqForegroundColor(.textPrimary)

                                    if entry.isToday {
                                        Text("Today")
                                            .sqFont(.bodyExtraSmall)
                                            .sqForegroundColor(.textSecondary)
                                    }
                                }

                                Spacer()

                                Image(systemName: SQImageSymbol.chevronRight.rawValue)
                                    .sqFont(.bodyExtraSmall)
                                    .sqForegroundColor(.textSecondary)
                            }
                            .padding(.SQSpace.m)
                            .sqBackgroundColor(.backgroundSecondary)
                            .cornerRadius(.SQCornerRadius.s)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.SQSpace.l)
            }
        }
        .frame(maxWidth: 500, maxHeight: 600)
        .sqBackgroundColor(.background)
        .cornerRadius(.SQCornerRadius.m)
        .shadow(radius: 20)
    }
}
