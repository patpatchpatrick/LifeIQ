//
//  MultiLineChartView.swift
//  CoolCharts
//

import SwiftUI

public struct MultiLineChartView: View {
    @ObservedObject var model: MultiLineChartModel

    public init(model: MultiLineChartModel) {
        self.model = model
    }

    public var body: some View {
        ZStack {
            chartContent

            if model.navigationConfig != nil {
                navigationButtons
            }
        }
    }

    private var chartContent: some View {
        ZStack {
            if let gridConfig = model.gridConfig {
                MultiLineGridBackgroundView(lineChartModel: model, gridConfig: gridConfig)
            }

            ForEach(model.visibleCoordinateSets) { coordinateSet in
                MultiLineChartShape(points: coordinateSet.points)
                    .stroke(
                        LinearGradient(
                            colors: [
                                coordinateSet.color.opacity(1.0),
                                coordinateSet.color.opacity(0.74)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                    )
                    .shadow(color: coordinateSet.color.opacity(0.22), radius: 8, x: 0, y: 3)
            }

            if let focusedLineModel = model.focusedLineModel {
                MultiFocusedLineView(model: focusedLineModel)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { location in
            model.focusNearestCoordinate(to: location)
        }
    }

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

private struct MultiLineChartShape: Shape {
    let points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        SmoothLinePathBuilder.buildPath(points: points)
    }
}

private struct MultiLineGridBackgroundView: View {
    let lineChartModel: MultiLineChartModel
    let gridConfig: GridConfig

    var body: some View {
        Canvas { context, _ in
            let width = lineChartModel.coordinatesMaxX - lineChartModel.coordinatesMinX
            let height = lineChartModel.coordinatesMaxY - lineChartModel.coordinatesMinY
            let hSpacing = height / CGFloat(gridConfig.numberOfHorizontalLines + 1)
            let vSpacing = width / CGFloat(gridConfig.numberOfVerticalLines + 1)

            for index in 0...gridConfig.numberOfHorizontalLines {
                let y = lineChartModel.coordinatesMinY + CGFloat(index) * hSpacing
                var path = Path()
                path.move(to: CGPoint(x: lineChartModel.coordinatesMinX, y: y))
                path.addLine(to: CGPoint(x: lineChartModel.coordinatesMaxX, y: y))
                context.stroke(path, with: .color(gridConfig.lineColor), lineWidth: 1)
            }

            for index in 0...gridConfig.numberOfVerticalLines {
                let x = lineChartModel.coordinatesMinX + CGFloat(index) * vSpacing
                var path = Path()
                path.move(to: CGPoint(x: x, y: lineChartModel.coordinatesMinY))
                path.addLine(to: CGPoint(x: x, y: lineChartModel.coordinatesMaxY))
                context.stroke(path, with: .color(gridConfig.lineColor), lineWidth: 1)
            }
        }
    }
}

private struct MultiFocusedLineView: View {
    let model: MultiLineChartFocusedLineViewModel

    var body: some View {
        ZStack {
            MultiFocusedLineShape(model: model)
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [5]))
                .foregroundStyle(model.focusConfig.focusColor.opacity(0.85))

            MultiFocusedLineCaptionView(model: model)
        }
    }
}

private struct MultiFocusedLineCaptionView: View {
    let model: MultiLineChartFocusedLineViewModel
    @State private var captionWidth: CGFloat = 0

    private var clampedX: CGFloat {
        let half = captionWidth / 2
        let chartWidth = model.lineChartModel.width
        return max(half, min(chartWidth - half, model.lineX))
    }

    var body: some View {
        VStack(spacing: .SQSpace.s) {
            ForEach(model.captionItems) { item in
                MultiFocusedLineCaptionItemView(captionItem: item)
            }
        }
        .padding(.horizontal, .SQSpace.m)
        .padding(.vertical, .SQSpace.s)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: .SQSpace.l, style: .continuous)
                    .fill(model.lineChartModel.uiConfig.colorConfig.backgroundPrimary.opacity(0.96))

                RoundedRectangle(cornerRadius: .SQSpace.l, style: .continuous)
                    .fill(.ultraThinMaterial.opacity(0.72))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: .SQSpace.l, style: .continuous)
                .stroke(Color.white.opacity(0.24), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.24), radius: 16, x: 0, y: 6)
        .background(
            GeometryReader { geo in
                Color.clear.onAppear { captionWidth = geo.size.width }
            }
        )
        .position(x: clampedX, y: model.focusedCoordinate.point.y)
    }
}

private struct MultiFocusedLineCaptionItemView: View {
    let captionItem: MultiLineChartFocusedLineViewModel.CaptionItem

    var body: some View {
        VStack(alignment: .leading, spacing: .SQSpace.s) {
            HStack(alignment: .center, spacing: .SQSpace.s) {
                if let lineColor = captionItem.lineColor {
                    Capsule(style: .continuous)
                        .foregroundStyle(lineColor)
                        .frame(width: 12, height: 4)
                }

                Text(captionItem.lineTitle)
                    .font(captionItem.uiConfig.fontConfig.font)
                    .foregroundStyle(captionItem.uiConfig.colorConfig.textSecondary)
                    .shadow(color: Color.black.opacity(0.18), radius: 1.5, x: 0, y: 1)
            }

            HStack(spacing: .SQSpace.s) {
                Text(captionItem.yTitle)
                    .font(captionItem.uiConfig.fontConfig.boldFont)
                    .foregroundStyle(captionItem.uiConfig.colorConfig.textPrimary)
                    .shadow(color: Color.black.opacity(0.22), radius: 1.5, x: 0, y: 1)

                Text(captionItem.xTitle)
                    .font(captionItem.uiConfig.fontConfig.font)
                    .foregroundStyle(captionItem.uiConfig.colorConfig.textSecondary)
                    .shadow(color: Color.black.opacity(0.18), radius: 1.5, x: 0, y: 1)
            }
        }
    }
}

private struct MultiFocusedLineShape: Shape {
    let model: MultiLineChartFocusedLineViewModel

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: model.lineX, y: model.lineStartY))
        path.addLine(to: CGPoint(x: model.lineX, y: model.lineEndY))
        return path
    }
}
