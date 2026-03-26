//
//  SQActivityBarChart.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 1/29/26.
//

import SwiftUI
import CoolCharts

/// Wrapper around CoolCharts BarChartView with BeastFitness styling
struct SQActivityBarChart: View {
    enum VisualStyle {
        case standard
        case glass
    }

    let dataPoints: [DataPoint]
    let maxHeight: CGFloat
    let barSpacing: CGFloat
    let barCornerRadius: CGFloat
    let labelColor: Color
    let visualStyle: VisualStyle

    struct DataPoint: Identifiable {
        let id = UUID()
        let label: String
        let value: Double
        let color: Color
    }

    init(
        dataPoints: [DataPoint],
        maxHeight: CGFloat,
        barSpacing: CGFloat = 8,
        barCornerRadius: CGFloat = 3,
        labelColor: Color = SQColor.textTertiary.color,
        visualStyle: VisualStyle = .standard
    ) {
        self.dataPoints = dataPoints
        self.maxHeight = maxHeight
        self.barSpacing = barSpacing
        self.barCornerRadius = barCornerRadius
        self.labelColor = labelColor
        self.visualStyle = visualStyle
    }
    
    var body: some View {
        BarChartView(
            dataPoints: dataPoints.map { point in
                BarChartView.DataPoint(
                    label: point.label,
                    value: point.value,
                    color: point.color
                )
            },
            maxHeight: maxHeight,
            barSpacing: barSpacing,
            barCornerRadius: barCornerRadius,
            labelFont: SQFont(type: .bodySmall).font,
            labelColor: labelColor,
            visualStyle: visualStyle == .glass ? .glass : .standard
        )
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
