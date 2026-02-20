//
//  SQColumnHeaderRow.swift
//  BeastFitness
//
//  Created by Claude Code on 2026-02-12.
//

import SwiftUI

/// A reusable column header row that aligns with dashboard stat rows
///
/// Uses the same layout constraints as `SQDashboardStatRow` to ensure column titles
/// align perfectly with their corresponding data columns below.
struct SQColumnHeaderRow: View {
    let columns: [ColumnHeader]

    struct ColumnHeader {
        let title: String
        let alignment: Alignment

        /// Column 1: Icon + Title column (left-aligned, full width)
        static func leading(_ title: String) -> ColumnHeader {
            ColumnHeader(title: title, alignment: .leading)
        }

        /// Column 2 & 3: Data columns (right-aligned, 75% width)
        static func trailing(_ title: String) -> ColumnHeader {
            ColumnHeader(title: title, alignment: .trailing)
        }
    }

    var body: some View {
        HStack(spacing: 12) { // Same spacing as SQDashboardStatRow
            ForEach(Array(columns.enumerated()), id: \.offset) { index, column in
                Text(column.title)
                    .sqFont(.bodyExtraSmall)
                    .sqForegroundColor(.textTertiary)
                    .frame(
                        maxWidth: index == 0 ? .infinity : .infinity * 0.75,
                        alignment: column.alignment == .leading ? .leading : .trailing
                    )
            }
        }
        .padding(.bottom, 8) // Space between header and first row
    }
}

#Preview("Metrics Headers") {
    VStack(spacing: 1) {
        SQColumnHeaderRow(columns: [
            .leading("Metric"),
            .trailing("Avg Score"),
            .trailing("7d %")
        ])
        .padding(.horizontal, 16)

        // Sample data rows to verify alignment
        SQDashboardStatRow(
            data: SQStatRowData(
                id: "mood",
                icon: "😊",
                title: "Mood",
                avgValue: "4.5",
                unit: "/ 10",
                sparklineData: [3.5, 4.0, 4.2, 4.1, 4.5, 4.3, 4.2],
                changePercent: 35.28
            )
        )
        .padding(.horizontal, 16)

        SQDashboardStatRow(
            data: SQStatRowData(
                id: "mental-clarity",
                icon: "🧠",
                title: "Mental Clarity",
                avgValue: "8.1",
                unit: "/ 10",
                sparklineData: [7.5, 8.0, 8.2, 8.1, 8.5, 8.3, 8.2],
                changePercent: 35.28
            )
        )
        .padding(.horizontal, 16)
    }
    .sqBackgroundColor(.backgroundSecondary)
    .cornerRadius(12)
    .padding(16)
    .sqBackgroundColor(.background)
}

#Preview("Performance Headers") {
    VStack(spacing: 1) {
        SQColumnHeaderRow(columns: [
            .leading("Stat"),
            .trailing("Avg Score"),
            .trailing("7d %")
        ])
        .padding(.horizontal, 16)

        // Sample data rows to verify alignment
        SQDashboardStatRow(
            data: SQStatRowData(
                id: "vo2-max",
                icon: "heart.fill",
                title: "VO2 Max",
                avgValue: "48.1",
                unit: "ml/kg/min",
                sparklineData: [45.5, 46.0, 47.2, 47.1, 48.5, 48.3, 48.1],
                changePercent: -35.28
            )
        )
        .padding(.horizontal, 16)

        SQDashboardStatRow(
            data: SQStatRowData(
                id: "fastest-mile",
                icon: "figure.run",
                title: "Fastest Mile",
                avgValue: "8:12",
                unit: "/ mile",
                sparklineData: [8.5, 8.3, 8.2, 8.1, 8.0, 8.1, 8.2],
                changePercent: 35.28
            )
        )
        .padding(.horizontal, 16)
    }
    .sqBackgroundColor(.backgroundSecondary)
    .cornerRadius(12)
    .padding(16)
    .sqBackgroundColor(.background)
}
