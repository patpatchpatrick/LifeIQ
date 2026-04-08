//
//  GridBackgroundView.swift
//  SportsPulse
//
//  Created by Patrick Doyle on 9/16/25.
//

import SwiftUI
import Foundation

public struct GridConfig {
    public struct ReferenceLine: Sendable {
        public let value: CGFloat
        public let label: String?
        public let lineColor: Color
        public let labelColor: Color?
        public let lineWidth: CGFloat
        public let dash: [CGFloat]

        public init(
            value: CGFloat,
            label: String? = nil,
            lineColor: Color = .gray,
            labelColor: Color? = nil,
            lineWidth: CGFloat = 1,
            dash: [CGFloat] = [4, 4]
        ) {
            self.value = value
            self.label = label
            self.lineColor = lineColor
            self.labelColor = labelColor
            self.lineWidth = lineWidth
            self.dash = dash
        }
    }

    let numberOfHorizontalLines: Int
    let numberOfVerticalLines: Int
    let lineColor: Color
    let xLabelBuilder: ((CGFloat) -> String)?
    let yLabelBuilder: ((CGFloat) -> String)?
    let showRangeLabels: Bool
    let rangeLabelBuilder: ((CGFloat) -> String)?
    let referenceLines: [ReferenceLine]
    
    public init(
        numberOfHorizontalLines: Int = 3,
        numberOfVerticalLines: Int = 3,
        lineColor: Color = .gray.opacity(0.2),
        xLabelBuilder: ((CGFloat) -> String)? = nil,
        yLabelBuilder:  ((CGFloat) -> String)? = nil,
        showRangeLabels: Bool = true,
        rangeLabelBuilder: ((CGFloat) -> String)? = nil,
        referenceLines: [ReferenceLine] = []
    ) {
        self.numberOfHorizontalLines = numberOfHorizontalLines
        self.numberOfVerticalLines = numberOfVerticalLines
        self.lineColor = lineColor
        self.xLabelBuilder = xLabelBuilder
        self.yLabelBuilder = yLabelBuilder
        self.showRangeLabels = showRangeLabels
        self.rangeLabelBuilder = rangeLabelBuilder
        self.referenceLines = referenceLines
    }
}

struct GridBackgroundView: View {
    let lineChartModel: LineChartModel
    let gridConfig: GridConfig
    var lineColor: Color { gridConfig.lineColor }
    var numberOfHorizontalLines: Int { gridConfig.numberOfHorizontalLines }
    var numberOfVerticalLines: Int { gridConfig.numberOfVerticalLines }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Canvas { context, size in
                let width = lineChartModel.coordinatesMaxX - lineChartModel.coordinatesMinX
                let height = lineChartModel.coordinatesMaxY - lineChartModel.coordinatesMinY

                let hSpacing = height / CGFloat(numberOfHorizontalLines + 1)
                let vSpacing = width / CGFloat(numberOfVerticalLines + 1)

                let startingXCoordinate = lineChartModel.coordinatesMinX
                let endingXCoordinate = lineChartModel.coordinatesMaxX
                let startingYCoordinate = lineChartModel.coordinatesMinY
                let endingYCoordinate = lineChartModel.coordinatesMaxY

                // Horizontal grid lines
                for i in 0...numberOfHorizontalLines {
                    let y = startingYCoordinate + CGFloat(i) * hSpacing
                    var path = Path()
                    path.move(to: CGPoint(x: startingXCoordinate, y: y))
                    path.addLine(to: CGPoint(x: endingXCoordinate, y: y))
                    context.stroke(path, with: .color(lineColor), lineWidth: 1)
                }

                // Vertical grid lines
                for i in 0...numberOfVerticalLines {
                    let x = startingXCoordinate + CGFloat(i) * vSpacing
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: startingYCoordinate))
                    path.addLine(to: CGPoint(x: x, y: endingYCoordinate))
                    context.stroke(path, with: .color(lineColor), lineWidth: 1)
                }

                let yMin = lineChartModel.originalCoordinatesMinY
                let yMax = lineChartModel.originalCoordinatesMaxY

                for referenceLine in gridConfig.referenceLines {
                    guard yMax > yMin else { continue }
                    let normalized = (referenceLine.value - yMin) / (yMax - yMin)
                    let clamped = min(max(normalized, 0), 1)
                    let y = endingYCoordinate - clamped * (endingYCoordinate - startingYCoordinate)

                    var path = Path()
                    path.move(to: CGPoint(x: startingXCoordinate, y: y))
                    path.addLine(to: CGPoint(x: endingXCoordinate, y: y))
                    context.stroke(
                        path,
                        with: .color(referenceLine.lineColor),
                        style: StrokeStyle(lineWidth: referenceLine.lineWidth, dash: referenceLine.dash)
                    )
                }
            }

            // Labels
            GeometryReader { geo in
                let height = geo.size.height
                let width = geo.size.width

                let yMin = lineChartModel.originalCoordinatesMinY
                let yMax = lineChartModel.originalCoordinatesMaxY
                let xMin = lineChartModel.originalCoordinatesMinX
                let xMax = lineChartModel.originalCoordinatesMaxX

                let hSpacing = height / CGFloat(numberOfHorizontalLines + 1)
                let vSpacing = width / CGFloat(numberOfVerticalLines + 1)

                // Y-axis labels (left)
                if let yLabelBuilder = gridConfig.yLabelBuilder {
                    ForEach(0...numberOfHorizontalLines, id: \.self) { i in
                        let yPos = hSpacing * CGFloat(i)
                        let value = yMax - (CGFloat(i) / CGFloat(numberOfHorizontalLines)) * (yMax - yMin)
                        let label = yLabelBuilder(value)
                        Text(label)
                            .font(.caption2)
                            .foregroundColor(lineChartModel.uiConfig.colorConfig.textSecondary)
                            .position(x: 15, y: yPos + 5)
                    }
                }

                if gridConfig.showRangeLabels {
                    let topLabel = buildRangeLabel(for: yMax)
                    let bottomLabel = buildRangeLabel(for: yMin)
                    let labelsAreEqual = topLabel == bottomLabel

                    VStack(alignment: .leading, spacing: 0) {
                        Text(topLabel)
                            .font(lineChartModel.uiConfig.fontConfig.font)
                            .foregroundColor(lineChartModel.uiConfig.colorConfig.textSecondary.opacity(0.45))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(lineChartModel.uiConfig.colorConfig.backgroundPrimary.opacity(0.22))
                            )

                        Spacer()

                        if !labelsAreEqual {
                            Text(bottomLabel)
                                .font(lineChartModel.uiConfig.fontConfig.font)
                                .foregroundColor(lineChartModel.uiConfig.colorConfig.textSecondary.opacity(0.38))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(lineChartModel.uiConfig.colorConfig.backgroundPrimary.opacity(0.16))
                                )
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .padding(.leading, 6)
                    .padding(.top, 2)
                    .padding(.bottom, 8)
                    .allowsHitTesting(false)
                }

                ForEach(Array(gridConfig.referenceLines.enumerated()), id: \.offset) { _, referenceLine in
                    if let label = referenceLine.label, yMax > yMin {
                        let normalized = (referenceLine.value - yMin) / (yMax - yMin)
                        let clamped = min(max(normalized, 0), 1)
                        let yPos = lineChartModel.coordinatesMaxY - clamped * (lineChartModel.coordinatesMaxY - lineChartModel.coordinatesMinY)

                        Text(label)
                            .font(lineChartModel.uiConfig.fontConfig.font)
                            .foregroundColor((referenceLine.labelColor ?? referenceLine.lineColor).opacity(0.88))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(lineChartModel.uiConfig.colorConfig.backgroundPrimary.opacity(0.24))
                            )
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .position(
                                x: lineChartModel.coordinatesMinX + 46,
                                y: referenceLabelYPosition(
                                    for: yPos,
                                    minY: lineChartModel.coordinatesMinY,
                                    maxY: lineChartModel.coordinatesMaxY
                                )
                            )
                            .allowsHitTesting(false)
                    }
                }

                // X-axis labels (bottom)
                if let xLabelBuilder = gridConfig.xLabelBuilder {
                    ForEach(0...numberOfVerticalLines, id: \.self) { i in
                        let xPos = vSpacing * CGFloat(i)
                        let value = xMin + (CGFloat(i) / CGFloat(numberOfVerticalLines)) * (xMax - xMin)
                        let label = xLabelBuilder(value)
                        Text(label)
                            .font(.caption2)
                            .foregroundColor(lineChartModel.uiConfig.colorConfig.textSecondary)
                            .position(x: xPos + 5, y: height - 10)
                    }
                }
            }
        }
        .frame(width: lineChartModel.width, height: lineChartModel.height)
    }

    private func buildRangeLabel(for value: CGFloat) -> String {
        if let rangeLabelBuilder = gridConfig.rangeLabelBuilder {
            return rangeLabelBuilder(value)
        }

        let number = Double(value)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.maximumFractionDigits = abs(number) >= 100 ? 0 : (abs(number) >= 10 ? 1 : 2)
        formatter.minimumFractionDigits = 0

        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }

    private func referenceLabelYPosition(for y: CGFloat, minY: CGFloat, maxY: CGFloat) -> CGFloat {
        let preferredAbove = y - 14
        if preferredAbove >= minY + 10 {
            return preferredAbove
        }
        return min(maxY - 10, y + 14)
    }
}
