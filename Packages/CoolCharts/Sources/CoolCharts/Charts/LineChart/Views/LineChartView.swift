//
//  LineChartView.swift
//  SportsPulse
//
//  Created by Patrick Doyle on 9/16/25.
//

import SwiftUI

public struct LineChartView: View {
    @ObservedObject var model: LineChartModel
    
    public init(model: LineChartModel) {
        self.model = model
    }
    
    // MARK: - Body

    public var body: some View {
        ZStack {
            chartContent

            if model.navigationConfig != nil {
                navigationButtons
            }
        }
    }

    // MARK: - Chart Content

    private var chartContent: some View {
        ZStack {
            if let gridConfig = model.gridConfig {
                GridBackgroundView(lineChartModel: model, gridConfig: gridConfig)
            }

            if model.showPrimaryLine {
                LineChartShape(model: model)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.92),
                                model.lineColor
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: model.lineColor.opacity(0.24), radius: 10, x: 0, y: 3)
            }

            if model.showTrendLine, !model.trendLineCoordinates.isEmpty, let trendLineColor = model.trendLineColor {
                TrendLineShape(points: model.trendLineCoordinates)
                    .stroke(
                        LinearGradient(
                            colors: [
                                trendLineColor.opacity(0.95),
                                trendLineColor.opacity(0.72)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                    )
                    .shadow(color: trendLineColor.opacity(0.22), radius: 7, x: 0, y: 2)
            }

            if model.showPrimaryLine {
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(
                                colors: [
                                    model.lineColor.opacity(0.24),
                                    model.lineColor.opacity(0.08),
                                    .clear
                                ]
                            ),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: model.width, height: model.height)
                    .clipShape(LineChartGradientShape(model: model))
            }

            if let focusedLineModel = model.focusedLineModel {
                FocusedLineView(lineChartModel: model, model: focusedLineModel)
            }
        }
        .onTapGesture { location in
            // Find the nearest coordinate in the chart to the tapped location
            var nearestX = model.coordinates.first?.x ?? 0
            for coordinate in model.coordinates {
                if abs(coordinate.x - location.x) < abs(nearestX - location.x) {
                    nearestX = coordinate.x
                }
            }

            // Get the identifiable point for the nearest coordinate
            if let focusedCoordinate = model.lineChartCoordinates.first(where: { $0.point.x == nearestX }) {
                let identifiablePoint = LineChartIdentifiablePoint(
                    id: focusedCoordinate.id,
                    point: location
                )
                model.coordinateFocused(at: identifiablePoint)
            }
        }
    }

    // MARK: - Navigation Buttons

    @ViewBuilder
    private var navigationButtons: some View {
        GeometryReader { geometry in
            let buttonSize: CGFloat = 44
            let buttonOffset: CGFloat = 4

            if model.navigationConfig?.showXAxisButtons == true {
                navigationButton(
                    icon: "chevron.left",
                    action: { model.decrementXPoint() },
                    position: CGPoint(
                        x: buttonOffset + buttonSize / 2,
                        y: geometry.size.height / 2
                    ),
                    size: buttonSize
                )

                navigationButton(
                    icon: "chevron.right",
                    action: { model.incrementXPoint() },
                    position: CGPoint(
                        x: geometry.size.width - buttonOffset - buttonSize / 2,
                        y: geometry.size.height / 2
                    ),
                    size: buttonSize
                )
            }

            if model.navigationConfig?.showYAxisButtons == true {
                navigationButton(
                    icon: "chevron.up",
                    action: { model.incrementYPoint() },
                    position: CGPoint(
                        x: geometry.size.width / 2,
                        y: buttonOffset + buttonSize / 2
                    ),
                    size: buttonSize
                )

                navigationButton(
                    icon: "chevron.down",
                    action: { model.decrementYPoint() },
                    position: CGPoint(
                        x: geometry.size.width / 2,
                        y: geometry.size.height - buttonOffset - buttonSize / 2
                    ),
                    size: buttonSize
                )
            }
        }
    }

    @ViewBuilder
    private func navigationButton(icon: String, action: @escaping () -> Void, position: CGPoint, size: CGFloat) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(model.uiConfig.fontConfig.font)
                .foregroundColor(model.uiConfig.colorConfig.textPrimary)
                .frame(width: size, height: size)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(model.uiConfig.colorConfig.backgroundSecondary.opacity(0.85))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )
        }
        .position(position)
    }
}

struct LineChartShape: Shape {
    static let strokeWidth: CGFloat = 3
    nonisolated(unsafe) let model: LineChartModel
    
    func path(in rect: CGRect) -> Path {
        let path = linePath(in: rect)
        let polishedPath = polishOffUi(path)
        return Path(polishedPath)
    }
    
    func polishOffUi(_ path: Path) -> CGPath {
        return path.cgPath.copy(
            strokingWithWidth: Self.strokeWidth,
            lineCap: .round,
            lineJoin: .miter,
            miterLimit: 0)
    }
    
    func linePath(in rect: CGRect) -> Path {
        SmoothLinePathBuilder.buildPath(points: model.coordinates)
    }
}

struct LineChartGradientShape: Shape {
    
    nonisolated(unsafe) let model: LineChartModel
    
    func path(in rect: CGRect) -> Path {
        let path = linePath(in: rect)
        return path
    }
    
    func linePath(in rect: CGRect) -> Path {
        var path = Path()
        guard let firstPoint = model.coordinates.first, let lastPoint = model.coordinates.last else {
            return path
        }

        // Start at the bottom of the chart directly below the first data point
        path.move(to: .init(x: firstPoint.x, y: model.yFloor))
        path.addLine(to: firstPoint)

        SmoothLinePathBuilder.appendSmoothedPoints(
            Array(model.coordinates.dropFirst()),
            to: &path,
            moveToFirstPoint: false
        )

        // Come back down to the bottom below the last data point
        path.addLine(to: .init(x: lastPoint.x, y: model.yFloor))

        // Close along the bottom back to the start
        path.closeSubpath()

        return path
    }
}

struct TrendLineShape: Shape {
    let points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        SmoothLinePathBuilder.buildPath(points: points)
    }
}

enum SmoothLinePathBuilder {
    static func buildPath(points: [CGPoint]) -> Path {
        var path = Path()
        appendSmoothedPoints(points, to: &path, moveToFirstPoint: true)
        return path
    }

    static func appendSmoothedPoints(
        _ points: [CGPoint],
        to path: inout Path,
        moveToFirstPoint: Bool
    ) {
        guard let first = points.first else { return }
        guard points.count > 1 else {
            if moveToFirstPoint {
                path.move(to: first)
            } else {
                path.addLine(to: first)
            }
            return
        }

        if moveToFirstPoint {
            path.move(to: first)
        } else {
            path.addLine(to: first)
        }

        if points.count == 2 {
            path.addLine(to: points[1])
            return
        }

        for index in 0..<(points.count - 1) {
            let current = points[index]
            let next = points[index + 1]
            let midpoint = CGPoint(
                x: (current.x + next.x) / 2,
                y: (current.y + next.y) / 2
            )

            if index == 0 {
                path.addQuadCurve(to: midpoint, control: current)
            } else {
                path.addQuadCurve(to: midpoint, control: current)
            }

            if index == points.count - 2 {
                path.addQuadCurve(to: next, control: midpoint)
            }
        }
    }
}

#Preview {
    LineChartView(model: .mock!)
}
