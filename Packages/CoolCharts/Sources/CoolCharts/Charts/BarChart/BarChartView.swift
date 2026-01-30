//
//  BarChartView.swift
//  CoolCharts
//
//  Created by Patrick Doyle on 1/29/26.
//

import SwiftUI

public struct BarChartView: View {
    let dataPoints: [DataPoint]
    let maxHeight: CGFloat
    let barSpacing: CGFloat
    let barCornerRadius: CGFloat
    let labelFont: Font
    let labelColor: Color
    
    public struct DataPoint: Identifiable {
        public let id = UUID()
        public let label: String
        public let value: Double
        public let color: Color
        
        public init(label: String, value: Double, color: Color) {
            self.label = label
            self.value = value
            self.color = color
        }
    }
    
    public init(
        dataPoints: [DataPoint],
        maxHeight: CGFloat = 60,
        barSpacing: CGFloat = 8,
        barCornerRadius: CGFloat = 3,
        labelFont: Font = .caption,
        labelColor: Color = .secondary
    ) {
        self.dataPoints = dataPoints
        self.maxHeight = maxHeight
        self.barSpacing = barSpacing
        self.barCornerRadius = barCornerRadius
        self.labelFont = labelFont
        self.labelColor = labelColor
    }
    
    private var maxValue: Double {
        dataPoints.map(\.value).max() ?? 1
    }
    
    public var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .bottom, spacing: barSpacing) {
                ForEach(dataPoints, id: \.id) { point in
                    VStack(spacing: 4) {
                        // Bar
                        RoundedRectangle(cornerRadius: barCornerRadius)
                            .fill(point.color)
                            .frame(
                                width: barWidth(totalWidth: geometry.size.width),
                                height: barHeight(for: point.value)
                            )
                            .frame(maxHeight: maxHeight, alignment: .bottom)
                        
                        // Label
                        Text(point.label)
                            .font(labelFont)
                            .foregroundStyle(labelColor)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: maxHeight + 20) // Add space for labels
    }
    
    private func barWidth(totalWidth: CGFloat) -> CGFloat {
        let totalSpacing = CGFloat(dataPoints.count - 1) * barSpacing
        let availableWidth = totalWidth - totalSpacing
        return max(12, availableWidth / CGFloat(dataPoints.count))
    }
    
    private func barHeight(for value: Double) -> CGFloat {
        guard maxValue > 0 else { return 2 }
        let ratio = value / maxValue
        return max(2, ratio * maxHeight)
    }
}

#Preview {
    VStack(spacing: 40) {
        // Weekly example
        BarChartView(
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
        BarChartView(
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
