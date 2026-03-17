//
//  SQDailyCheckInVitalRow.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 1/29/26.
//

import SwiftUI
import CoolCharts

/// A single row in the vertical Daily Check-In vitals list.
/// Displays: emoji, title, value, and sparkline trend.
struct SQDailyCheckInVitalRow: View {
    
    struct Model: Identifiable {
        let id: String
        let emoji: String
        let title: String
        let value: String
        let subtitle: String? // Optional label like "avg" for averages
        let sparklineData: [Double]

        init(
            id: String,
            emoji: String,
            title: String,
            value: String,
            subtitle: String? = nil,
            sparklineData: [Double]
        ) {
            self.id = id
            self.emoji = emoji
            self.title = title
            self.value = value
            self.subtitle = subtitle
            self.sparklineData = sparklineData
        }
    }
    
    let model: Model
    var onTap: (() -> Void)? = nil
    
    private var rowHeight: CGFloat { 44 }
    private var sparklineWidth: CGFloat { 80 }
    
    var body: some View {
        Button(action: { onTap?() }) {
            HStack(alignment: .center, spacing: .SQSpace.l) {
                // Emoji
                Text(model.emoji)
                    .sqFont(.title3)
                    .frame(width: 24, alignment: .center)
                
                // Title
                Text(model.title)
                    .sqFont(.body)
                    .sqForegroundColor(.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Value with optional subtitle
                HStack(spacing: .SQSpace.xs) {
                    if let subtitle = model.subtitle {
                        Text(subtitle)
                            .sqFont(.bodyExtraSmall)
                            .sqForegroundColor(.textTertiary)
                    }

                    Text(model.value)
                        .sqFont(.body)
                        .sqForegroundColor(.textSecondary)
                }
                .frame(minWidth: 60, alignment: .trailing)
                
                // Sparkline
                SparklineView(
                    dataPoints: model.sparklineData.map { SparklineView.DataPoint(value: $0) },
                    lineColor: SQColor.textTertiary.color.opacity(0.5)
                )
                .frame(width: sparklineWidth, height: 20)
            }
            .frame(height: rowHeight)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}
