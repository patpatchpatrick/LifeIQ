//
//  SQActivityBarChart.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 1/29/26.
//

import SwiftUI

struct SQActivityBarChart: View {
    let dataPoints: [DataPoint]
    let maxHeight: CGFloat
    
    struct DataPoint: Identifiable {
        let id = UUID()
        let label: String
        let value: Double // Duration in seconds or other metric
        let color: Color
    }
    
    private var maxValue: Double {
        dataPoints.map(\.value).max() ?? 1
    }
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(dataPoints) { point in
                VStack(spacing: 4) {
                    // Bar
                    RoundedRectangle(cornerRadius: 3)
                        .fill(point.color)
                        .frame(
                            width: barWidth,
                            height: barHeight(for: point.value)
                        )
                        .frame(maxHeight: maxHeight, alignment: .bottom)
                    
                    // Label
                    Text(point.label)
                        .sqFont(.bodySmall)
                        .sqForegroundColor(.textTertiary)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private var barWidth: CGFloat {
        // Distribute available width among bars, accounting for spacing
        let totalSpacing = CGFloat(dataPoints.count - 1) * 8
        let availableWidth = UIScreen.main.bounds.width - (.SQSpace.l * 2) - totalSpacing
        return max(12, availableWidth / CGFloat(dataPoints.count))
    }
    
    private func barHeight(for value: Double) -> CGFloat {
        guard maxValue > 0 else { return 2 }
        let ratio = value / maxValue
        return max(2, ratio * maxHeight) // Minimum 2pt height for visibility
    }
}

#Preview {
    VStack(spacing: 40) {
        // Weekly example
        SQActivityBarChart(
            dataPoints: [
                .init(label: "M", value: 1800, color: .blue),
                .init(label: "T", value: 3600, color: .blue),
                .init(label: "W", value: 4200, color: .blue),
                .init(label: "T", value: 2400, color: .blue),
                .init(label: "F", value: 5400, color: .blue),
                .init(label: "S", value: 3900, color: .blue),
                .init(label: "S", value: 1200, color: .blue)
            ],
            maxHeight: 60
        )
        .padding()
        
        // Yearly example (monthly)
        SQActivityBarChart(
            dataPoints: [
                .init(label: "J", value: 50000, color: .green),
                .init(label: "F", value: 45000, color: .green),
                .init(label: "M", value: 60000, color: .green),
                .init(label: "A", value: 55000, color: .green),
                .init(label: "M", value: 72000, color: .green),
                .init(label: "J", value: 68000, color: .green),
                .init(label: "J", value: 58000, color: .green),
                .init(label: "A", value: 62000, color: .green),
                .init(label: "S", value: 54000, color: .green),
                .init(label: "O", value: 48000, color: .green),
                .init(label: "N", value: 42000, color: .green),
                .init(label: "D", value: 38000, color: .green)
            ],
            maxHeight: 80
        )
        .padding()
    }
    .preferredColorScheme(.dark)
    .background(Color.black)
}
