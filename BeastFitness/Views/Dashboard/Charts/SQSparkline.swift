//
//  SQSparkline.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 1/29/26.
//

import SwiftUI
import CoolCharts

/// BeastFitness-styled sparkline wrapper
struct SQSparkline: View {
    let dataPoints: [Double]
    let height: CGFloat
    let lineColor: Color

    init(dataPoints: [Double], height: CGFloat = 20, lineColor: Color = SQColor.textTertiary.color.opacity(0.5)) {
        self.dataPoints = dataPoints
        self.height = height
        self.lineColor = lineColor
    }

    var body: some View {
        SparklineView(
            dataPoints: dataPoints.map { SparklineView.DataPoint(value: $0) },
            lineColor: lineColor,
            lineWidth: 1.5
        )
        .frame(height: height)
        .frame(maxWidth: .infinity)
    }
}
