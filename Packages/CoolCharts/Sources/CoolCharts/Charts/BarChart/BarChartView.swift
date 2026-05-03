//
//  BarChartView.swift
//  CoolCharts
//
//  Created by Patrick Doyle on 1/29/26.
//

import SwiftUI

public struct BarChartView: View {
    public enum VisualStyle {
        case standard
        case glass
    }

    public enum HorizontalDistribution {
        case fill
        case leading
    }

    public struct ValueAxisLabel: Sendable {
        public let value: Double
        public let label: String
        public let color: Color?

        public init(value: Double, label: String, color: Color? = nil) {
            self.value = value
            self.label = label
            self.color = color
        }
    }

    public struct ReferenceLine: Sendable {
        public let value: Double
        public let label: String?
        public let color: Color
        public let lineWidth: CGFloat
        public let dash: [CGFloat]

        public init(
            value: Double,
            label: String? = nil,
            color: Color = .gray,
            lineWidth: CGFloat = 1,
            dash: [CGFloat] = [4, 4]
        ) {
            self.value = value
            self.label = label
            self.color = color
            self.lineWidth = lineWidth
            self.dash = dash
        }
    }

    public struct DataPoint: Identifiable {
        public let id: String
        public let label: String
        public let value: Double
        public let color: Color
        public let focusTitle: String?
        
        public init(
            id: String = UUID().uuidString,
            label: String,
            value: Double,
            color: Color,
            focusTitle: String? = nil
        ) {
            self.id = id
            self.label = label
            self.value = value
            self.color = color
            self.focusTitle = focusTitle
        }
    }

    public struct FocusConfig {
        public let valueLabelBuilder: ((Double) -> String)?
        public let titleLabelBuilder: ((DataPoint) -> String)?
        public let onFocus: ((DataPoint) -> Void)?

        public init(
            valueLabelBuilder: ((Double) -> String)? = nil,
            titleLabelBuilder: ((DataPoint) -> String)? = nil,
            onFocus: ((DataPoint) -> Void)? = nil
        ) {
            self.valueLabelBuilder = valueLabelBuilder
            self.titleLabelBuilder = titleLabelBuilder
            self.onFocus = onFocus
        }
    }

    let dataPoints: [DataPoint]
    let maxHeight: CGFloat
    let barSpacing: CGFloat
    let barCornerRadius: CGFloat
    let minimumBarWidth: CGFloat
    let maximumBarWidth: CGFloat?
    let minimumLabelWidth: CGFloat
    let horizontalDistribution: HorizontalDistribution
    let labelFont: Font
    let labelColor: Color
    let visualStyle: VisualStyle
    let referenceLines: [ReferenceLine]
    let valueAxisLabels: [ValueAxisLabel]
    let focusConfig: FocusConfig?

    @State private var focusedPointId: String?
    
    public init(
        dataPoints: [DataPoint],
        maxHeight: CGFloat = 60,
        barSpacing: CGFloat = 8,
        barCornerRadius: CGFloat = 3,
        minimumBarWidth: CGFloat = 12,
        maximumBarWidth: CGFloat? = nil,
        minimumLabelWidth: CGFloat = 0,
        horizontalDistribution: HorizontalDistribution = .fill,
        labelFont: Font = .caption,
        labelColor: Color = .secondary,
        visualStyle: VisualStyle = .standard,
        referenceLines: [ReferenceLine] = [],
        valueAxisLabels: [ValueAxisLabel] = [],
        focusConfig: FocusConfig? = nil
    ) {
        self.dataPoints = dataPoints
        self.maxHeight = maxHeight
        self.barSpacing = barSpacing
        self.barCornerRadius = barCornerRadius
        self.minimumBarWidth = minimumBarWidth
        self.maximumBarWidth = maximumBarWidth
        self.minimumLabelWidth = minimumLabelWidth
        self.horizontalDistribution = horizontalDistribution
        self.labelFont = labelFont
        self.labelColor = labelColor
        self.visualStyle = visualStyle
        self.referenceLines = referenceLines
        self.valueAxisLabels = valueAxisLabels
        self.focusConfig = focusConfig
    }
    
    private var maxValue: Double {
        dataPoints.map(\.value).max() ?? 1
    }

    private var chartLeadingInset: CGFloat {
        valueAxisLabels.isEmpty ? 0 : 18
    }

    private var axisLabelAnchorX: CGFloat {
        chartLeadingInset + 28
    }

    private var chartStartX: CGFloat {
        chartLeadingInset + 6
    }

    private func effectiveBarSpacing(totalWidth: CGFloat) -> CGFloat {
        guard dataPoints.count > 1 else { return barSpacing }
        guard horizontalDistribution == .fill else { return barSpacing }

        let width = itemWidth(totalWidth: totalWidth)
        let availableWidth = max(0, totalWidth - chartLeadingInset)
        let totalItemWidth = width * CGFloat(dataPoints.count)
        let leftoverWidth = max(0, availableWidth - totalItemWidth)
        return max(barSpacing, leftoverWidth / CGFloat(dataPoints.count - 1))
    }
    
    public var body: some View {
        GeometryReader { geometry in
            let spacing = effectiveBarSpacing(totalWidth: geometry.size.width)
            let width = barWidth(totalWidth: geometry.size.width)
            let labelWidth = itemWidth(totalWidth: geometry.size.width)
            ZStack(alignment: .topLeading) {
                if !valueAxisLabels.isEmpty {
                    axisLineView
                }

                ForEach(Array(referenceLines.enumerated()), id: \.offset) { _, referenceLine in
                    referenceLineView(referenceLine, totalWidth: geometry.size.width)
                }

                ForEach(Array(valueAxisLabels.enumerated()), id: \.offset) { _, axisLabel in
                    valueAxisLabelView(axisLabel)
                }

                HStack(alignment: .bottom, spacing: spacing) {
                    ForEach(dataPoints, id: \.id) { point in
                        VStack(spacing: 4) {
                            barView(for: point)
                                .frame(
                                    width: width,
                                    height: barHeight(for: point.value)
                                )
                                .frame(maxHeight: maxHeight, alignment: .bottom)

                            Text(point.label)
                                .font(labelFont)
                                .foregroundStyle(labelColor)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .frame(width: labelWidth)
                        }
                        .frame(width: labelWidth)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            focus(point)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, chartStartX)

                if let focusedPoint = focusedPoint {
                    focusedGuideLineView(
                        for: focusedPoint,
                        totalWidth: geometry.size.width,
                        spacing: spacing
                    )

                    focusedCaptionView(
                        for: focusedPoint,
                        totalWidth: geometry.size.width,
                        spacing: spacing
                    )
                }
            }
        }
        .frame(height: maxHeight + 28) // Add space for labels
    }

    @ViewBuilder
    private func barView(for point: DataPoint) -> some View {
        let shape = RoundedRectangle(cornerRadius: barCornerRadius, style: .continuous)

        switch visualStyle {
        case .standard:
            shape.fill(point.color)
        case .glass:
            shape
                .fill(point.color.opacity(0.72))
                .overlay {
                    shape
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.30),
                                    Color.white.opacity(0.04)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .overlay {
                    shape
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                }
        }
    }
    
    private func barWidth(totalWidth: CGFloat) -> CGFloat {
        let totalSpacing = CGFloat(dataPoints.count - 1) * barSpacing
        let availableWidth = max(0, totalWidth - chartLeadingInset - totalSpacing)
        let naturalWidth = max(minimumBarWidth, availableWidth / CGFloat(max(dataPoints.count, 1)))
        if let maximumBarWidth {
            return min(maximumBarWidth, naturalWidth)
        }
        return naturalWidth
    }

    private func itemWidth(totalWidth: CGFloat) -> CGFloat {
        max(barWidth(totalWidth: totalWidth), minimumLabelWidth)
    }
    
    private func barHeight(for value: Double) -> CGFloat {
        guard maxValue > 0 else { return 2 }
        let ratio = value / maxValue
        return max(2, ratio * maxHeight)
    }

    @ViewBuilder
    private func referenceLineView(_ referenceLine: ReferenceLine, totalWidth: CGFloat) -> some View {
        let yPosition = maxHeight - barHeight(for: referenceLine.value)

        ZStack(alignment: .leading) {
            Path { path in
                path.move(to: CGPoint(x: chartLeadingInset, y: yPosition))
                path.addLine(to: CGPoint(x: totalWidth, y: yPosition))
            }
            .stroke(
                referenceLine.color,
                style: StrokeStyle(lineWidth: referenceLine.lineWidth, dash: referenceLine.dash)
            )

            if let label = referenceLine.label {
                Text(label)
                    .font(labelFont)
                    .foregroundStyle(referenceLine.color.opacity(0.96))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.black.opacity(0.38))
                    )
                    .shadow(color: Color.black.opacity(0.42), radius: 7, x: 0, y: 2)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .position(
                        x: axisLabelAnchorX,
                        y: referenceLabelYPosition(for: yPosition)
                    )
            }
        }
    }

    @ViewBuilder
    private func focusedCaptionView(
        for point: DataPoint,
        totalWidth: CGFloat,
        spacing: CGFloat
    ) -> some View {
        let barWidth = barWidth(totalWidth: totalWidth)
        let xPosition = xPosition(for: point, totalWidth: totalWidth, spacing: spacing, barWidth: barWidth)
        let yPosition = maxHeight - barHeight(for: point.value)
        let title = focusConfig?.titleLabelBuilder?(point) ?? point.focusTitle ?? point.label
        let value = focusConfig?.valueLabelBuilder?(point.value) ?? defaultFormattedValue(point.value)

        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(labelFont)
                .foregroundStyle(labelColor.opacity(0.92))

            Text(value)
                .font(labelFont.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.96))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(Color.black.opacity(0.42))
        )
        .shadow(color: Color.black.opacity(0.40), radius: 8, x: 0, y: 3)
        .position(
            x: min(max(xPosition, 56), totalWidth - 56),
            y: max(16, yPosition - 18)
        )
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func focusedGuideLineView(
        for point: DataPoint,
        totalWidth: CGFloat,
        spacing: CGFloat
    ) -> some View {
        let barWidth = barWidth(totalWidth: totalWidth)
        let xPosition = xPosition(for: point, totalWidth: totalWidth, spacing: spacing, barWidth: barWidth)

        Path { path in
            path.move(to: CGPoint(x: xPosition, y: 6))
            path.addLine(to: CGPoint(x: xPosition, y: maxHeight))
        }
        .stroke(
            Color.white.opacity(0.28),
            style: StrokeStyle(lineWidth: 1, dash: [4, 4])
        )
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func valueAxisLabelView(_ axisLabel: ValueAxisLabel) -> some View {
        let yPosition = maxHeight - barHeight(for: axisLabel.value)

        Text(axisLabel.label)
            .font(labelFont)
            .foregroundStyle((axisLabel.color ?? labelColor).opacity(0.96))
            .shadow(color: Color.black.opacity(0.34), radius: 5, x: 0, y: 2)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.black.opacity(0.34))
            )
            .position(
                x: axisLabelAnchorX,
                y: axisLabelYPosition(for: yPosition)
            )
    }

    private func referenceLabelYPosition(for yPosition: CGFloat) -> CGFloat {
        min(maxHeight - 10, yPosition + 16)
    }

    private func axisLabelYPosition(for yPosition: CGFloat) -> CGFloat {
        min(max(yPosition - 18, 10), maxHeight - 10)
    }

    @ViewBuilder
    private var axisLineView: some View {
        Path { path in
            path.move(to: CGPoint(x: chartLeadingInset, y: 6))
            path.addLine(to: CGPoint(x: chartLeadingInset, y: maxHeight))
        }
        .stroke(
            Color.white.opacity(0.14),
            style: StrokeStyle(lineWidth: 1, dash: [2, 3])
        )
    }

    private var focusedPoint: DataPoint? {
        guard let focusedPointId else { return nil }
        return dataPoints.first(where: { $0.id == focusedPointId })
    }

    private func focus(_ point: DataPoint) {
        focusedPointId = point.id
        focusConfig?.onFocus?(point)
    }

    private func xPosition(
        for point: DataPoint,
        totalWidth: CGFloat,
        spacing: CGFloat,
        barWidth: CGFloat
    ) -> CGFloat {
        let width = max(barWidth, minimumLabelWidth)
        guard let index = dataPoints.firstIndex(where: { $0.id == point.id }) else {
            return chartStartX + (width / 2)
        }

        return chartStartX + (width / 2) + (CGFloat(index) * (width + spacing))
    }

    private func defaultFormattedValue(_ value: Double) -> String {
        if value.rounded() == value {
            return "\(Int(value))"
        }

        return value.formatted(.number.precision(.fractionLength(1)))
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
