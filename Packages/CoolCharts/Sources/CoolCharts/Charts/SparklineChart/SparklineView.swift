//
//  SparklineView.swift
//  CoolCharts
//
//  Created by Patrick Doyle on 1/29/26.
//

import SwiftUI

/// A minimal sparkline chart with no axes, labels, or decoration.
/// Designed to show trend-at-a-glance for 7–14 day windows.
public struct SparklineView: View {
    
    public struct DataPoint {
        public let value: Double
        
        public init(value: Double) {
            self.value = value
        }
    }
    
    public let dataPoints: [DataPoint]
    public let lineColor: Color
    public let lineWidth: CGFloat
    
    public init(
        dataPoints: [DataPoint],
        lineColor: Color = .gray.opacity(0.6),
        lineWidth: CGFloat = 1.5
    ) {
        self.dataPoints = dataPoints
        self.lineColor = lineColor
        self.lineWidth = lineWidth
    }
    
    public var body: some View {
        GeometryReader { geo in
            if dataPoints.count >= 2 {
                Path { path in
                    let values = dataPoints.map(\.value)
                    guard let minValue = values.min(),
                          let maxValue = values.max(),
                          maxValue > minValue else {
                        // All values are the same, draw flat line
                        let midY = geo.size.height / 2
                        path.move(to: CGPoint(x: 0, y: midY))
                        path.addLine(to: CGPoint(x: geo.size.width, y: midY))
                        return
                    }
                    
                    let xStep = geo.size.width / CGFloat(dataPoints.count - 1)
                    let range = maxValue - minValue
                    
                    for (index, point) in dataPoints.enumerated() {
                        let x = CGFloat(index) * xStep
                        // Invert Y so higher values appear at top
                        let normalizedValue = (point.value - minValue) / range
                        let y = geo.size.height * (1 - normalizedValue)
                        
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(lineColor, lineWidth: lineWidth)
            } else {
                // Not enough data
                EmptyView()
            }
        }
    }
}
