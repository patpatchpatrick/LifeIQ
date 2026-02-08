//
//  SQStatRowSection.swift
//  BeastFitness
//

import SwiftUI

struct SQStatRowSection: View {
    let rows: [SQStatRowData]

    var body: some View {
        VStack(spacing: 0) {
            // Column Headers
            HStack(spacing: 12) {
                // Column 1: "Stat" (40%)
                HStack(spacing: 8) {
                    Text("Stat")
                        .font(.sqFont(.bodySmall))
                        .sqForegroundColor(.textSecondary)

                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Column 2: "Avg Score" (30%)
                Text("Avg Score")
                    .font(.sqFont(.bodySmall))
                    .sqForegroundColor(.textSecondary)
                    .frame(maxWidth: .infinity * 0.75, alignment: .leading)

                // Column 3: "14d %" (30%)
                Text("14d %")
                    .font(.sqFont(.bodySmall))
                    .sqForegroundColor(.textSecondary)
                    .frame(maxWidth: .infinity * 0.75, alignment: .trailing)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            // Stat Rows
            ForEach(rows) { row in
                Divider()
                    .sqBackgroundColor(.divider())

                SQDashboardStatRow(data: row)
            }
        }
    }
}

#Preview {
    VStack(spacing: 0) {
        SQStatRowSection(
            rows: [
                SQStatRowData(
                    id: "mood",
                    icon: "😊",
                    title: "Mood",
                    avgValue: "4.2",
                    unit: "/5",
                    sparklineData: [3.5, 4.0, 4.2, 4.1, 4.5, 4.3, 4.2],
                    change14d: 12.5
                ),
                SQStatRowData(
                    id: "energy",
                    icon: "⚡️",
                    title: "Energy",
                    avgValue: "3.8",
                    unit: "/5",
                    sparklineData: [3.2, 3.5, 3.8, 3.9, 4.0, 3.7, 3.8],
                    change14d: 8.3
                )
            ]
        )
    }
    .sqBackgroundColor(.backgroundSecondary)
    .cornerRadius(12)
}
