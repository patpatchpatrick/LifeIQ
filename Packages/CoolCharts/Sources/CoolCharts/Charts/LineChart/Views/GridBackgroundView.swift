//
//  GridBackgroundView.swift
//  SportsPulse
//
//  Created by Patrick Doyle on 9/16/25.
//

import SwiftUI

public struct GridConfig {
    let numberOfHorizontalLines: Int
    let numberOfVerticalLines: Int
    let lineColor: Color
    let xLabelBuilder: ((CGFloat) -> String)?
    let yLabelBuilder: ((CGFloat) -> String)?
    
    public init(numberOfHorizontalLines: Int = 3, numberOfVerticalLines: Int = 3, lineColor: Color = .gray.opacity(0.2), xLabelBuilder: ((CGFloat) -> String)? = nil, yLabelBuilder:  ((CGFloat) -> String)? = nil) {
        self.numberOfHorizontalLines = numberOfHorizontalLines
        self.numberOfVerticalLines = numberOfVerticalLines
        self.lineColor = lineColor
        self.xLabelBuilder = xLabelBuilder
        self.yLabelBuilder = yLabelBuilder
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
                            .foregroundColor(.secondary)
                            .position(x: 15, y: yPos + 5)
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
                            .foregroundColor(.secondary)
                            .position(x: xPos + 5, y: height - 10)
                    }
                }
            }
        }
        .frame(width: lineChartModel.width, height: lineChartModel.height)
    }
}

