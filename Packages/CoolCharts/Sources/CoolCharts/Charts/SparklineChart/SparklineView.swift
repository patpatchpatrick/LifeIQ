//
//  SparklineView.swift
//  CoolCharts
//

import SwiftUI

/// A minimal sparkline chart with no axes, labels, or decoration.
/// Renders a smooth bold stroke line with a soft gradient fill beneath it.
/// Designed to show trend-at-a-glance for 7–30 day windows.
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

    /// Vertical padding (pts) kept clear at top and bottom within the frame,
    /// so the line never hugs the very edge of its bounding box.
    private let verticalPad: CGFloat = 2

    public init(
        dataPoints: [DataPoint],
        lineColor: Color = .gray.opacity(0.6),
        lineWidth: CGFloat = 2.0
    ) {
        self.dataPoints = dataPoints
        self.lineColor = lineColor
        self.lineWidth = lineWidth
    }

    public var body: some View {
        GeometryReader { geo in
            if dataPoints.count >= 2 {
                let points = resolvedPoints(in: geo.size)
                ZStack {
                    gradientFill(points: points, size: geo.size)
                    smoothLinePath(points: points)
                        .stroke(lineColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                }
            }
        }
    }

    // MARK: - Point Resolution

    private func resolvedPoints(in size: CGSize) -> [CGPoint] {
        let values = dataPoints.map(\.value)
        guard let minValue = values.min(), let maxValue = values.max() else { return [] }

        let xStep = size.width / CGFloat(dataPoints.count - 1)

        if maxValue == minValue {
            // Flat line — sit at 70% down so it's close to the label below rather than centered
            let y = size.height * 0.7
            return dataPoints.indices.map { i in CGPoint(x: CGFloat(i) * xStep, y: y) }
        }

        let range = maxValue - minValue
        let drawHeight = size.height - verticalPad * 2
        return dataPoints.enumerated().map { i, point in
            let x = CGFloat(i) * xStep
            let normalized = (point.value - minValue) / range
            let y = verticalPad + drawHeight * (1 - normalized)
            return CGPoint(x: x, y: y)
        }
    }

    // MARK: - Smooth Line (midpoint bezier)

    /// Builds a smooth path using the midpoint quadratic-bezier method.
    /// Each original data point acts as a control point; the path passes
    /// through the midpoints between consecutive points, producing soft curves.
    private func smoothLinePath(points: [CGPoint]) -> Path {
        var path = Path()
        guard points.count >= 2 else { return path }

        path.move(to: points[0])

        for i in 0..<(points.count - 1) {
            let p0 = points[i]
            let p1 = points[i + 1]
            let mid = CGPoint(x: (p0.x + p1.x) / 2, y: (p0.y + p1.y) / 2)

            if i == 0 {
                path.addLine(to: mid)
            } else {
                path.addQuadCurve(to: mid, control: p0)
            }
        }
        // Final segment straight to the last point
        path.addLine(to: points[points.count - 1])

        return path
    }

    // MARK: - Gradient Fill

    private func gradientFill(points: [CGPoint], size: CGSize) -> some View {
        let fillPath = Path { path in
            path.move(to: CGPoint(x: points[0].x, y: size.height))
            points.forEach { path.addLine(to: $0) }
            path.addLine(to: CGPoint(x: points[points.count - 1].x, y: size.height))
            path.closeSubpath()
        }

        return fillPath
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [lineColor.opacity(0.25), lineColor.opacity(0.0)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }
}
