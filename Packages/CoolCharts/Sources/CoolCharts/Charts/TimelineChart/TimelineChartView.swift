//
//  TimelineChartView.swift
//  CoolCharts
//

import SwiftUI

public struct TimelineChartLane: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let color: Color

    public init(id: String, title: String, color: Color) {
        self.id = id
        self.title = title
        self.color = color
    }
}

public struct TimelineChartSegment: Identifiable, Sendable {
    public let id: String
    public let laneId: String
    public let startDate: Date
    public let endDate: Date
    public let color: Color?

    public init(id: String, laneId: String, startDate: Date, endDate: Date, color: Color? = nil) {
        self.id = id
        self.laneId = laneId
        self.startDate = startDate
        self.endDate = endDate
        self.color = color
    }
}

public struct TimelineChartView: View {
    public enum VisualStyle: Equatable {
        case standard
        case glass
    }

    public let lanes: [TimelineChartLane]
    public let segments: [TimelineChartSegment]
    public let startDate: Date
    public let endDate: Date

    private let laneLabelWidth: CGFloat
    private let laneSpacing: CGFloat
    private let laneHeight: CGFloat
    private let visualStyle: VisualStyle

    public init(
        lanes: [TimelineChartLane],
        segments: [TimelineChartSegment],
        startDate: Date,
        endDate: Date,
        laneLabelWidth: CGFloat = 48,
        laneSpacing: CGFloat = 10,
        laneHeight: CGFloat = 10,
        visualStyle: VisualStyle = .standard
    ) {
        self.lanes = lanes
        self.segments = segments
        self.startDate = startDate
        self.endDate = endDate
        self.laneLabelWidth = laneLabelWidth
        self.laneSpacing = laneSpacing
        self.laneHeight = laneHeight
        self.visualStyle = visualStyle
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geometry in
                let chartWidth = max(0, geometry.size.width - laneLabelWidth)
                let totalSeconds = max(1, endDate.timeIntervalSince(startDate))

                ZStack(alignment: .topLeading) {
                    ForEach(Array(lanes.enumerated()), id: \.element.id) { index, lane in
                        let y = CGFloat(index) * (laneHeight + laneSpacing)
                        let laneSegments = segments.filter { $0.laneId == lane.id }

                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: laneHeight / 2)
                                .fill(trackFillColor(for: lane))

                            ForEach(laneSegments) { segment in
                                let clippedStart = max(segment.startDate, startDate)
                                let clippedEnd = min(segment.endDate, endDate)

                                if clippedEnd > clippedStart {
                                    let startXRatio = clippedStart.timeIntervalSince(startDate) / totalSeconds
                                    let endXRatio = clippedEnd.timeIntervalSince(startDate) / totalSeconds
                                    let startX = max(0, CGFloat(startXRatio) * chartWidth)
                                    let rawWidth = CGFloat(endXRatio - startXRatio) * chartWidth
                                    let width = max(2, min(chartWidth - startX, rawWidth))
                                    let segmentColor = segment.color ?? lane.color

                                    RoundedRectangle(cornerRadius: laneHeight / 2)
                                        .fill(segmentFill(for: segmentColor))
                                        .frame(width: width, height: laneHeight)
                                        .offset(x: startX)
                                        .overlay(alignment: .leading) {
                                            if visualStyle == .glass {
                                                RoundedRectangle(cornerRadius: laneHeight / 2)
                                                    .fill(
                                                        LinearGradient(
                                                            colors: [
                                                                Color.white.opacity(0.30),
                                                                Color.white.opacity(0.02)
                                                            ],
                                                            startPoint: .top,
                                                            endPoint: .bottom
                                                        )
                                                    )
                                                    .frame(width: width, height: laneHeight)
                                                    .offset(x: startX)

                                                RoundedRectangle(cornerRadius: laneHeight / 2)
                                                    .stroke(Color.white.opacity(0.20), lineWidth: 1)
                                                    .frame(width: width, height: laneHeight)
                                                    .offset(x: startX)
                                            }
                                        }
                                }
                            }
                        }
                        .frame(width: chartWidth, height: laneHeight, alignment: .leading)
                        .clipShape(RoundedRectangle(cornerRadius: laneHeight / 2))
                        .overlay {
                            if visualStyle == .glass {
                                RoundedRectangle(cornerRadius: laneHeight / 2)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            }
                        }
                        .offset(x: laneLabelWidth, y: y)

                        Text(lane.title)
                            .font(.caption2)
                            .foregroundStyle(labelColor)
                            .lineLimit(1)
                            .frame(width: laneLabelWidth - 6, alignment: .leading)
                            .offset(x: 0, y: y - 2)
                    }
                }
            }
            .frame(height: chartHeight)

            HStack {
                timeLabelView(Self.timeLabel(startDate))
                Spacer()
                timeLabelView(Self.timeLabel(endDate))
            }
            .padding(.leading, laneLabelWidth)
        }
    }

    @ViewBuilder
    private func timeLabelView(_ label: String) -> some View {
        switch visualStyle {
        case .standard:
            Text(label)
                .font(.caption2)
                .foregroundStyle(labelColor)
        case .glass:
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.white.opacity(0.86))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )
        }
    }

    private var labelColor: Color {
        switch visualStyle {
        case .standard:
            return .secondary
        case .glass:
            return Color.white.opacity(0.64)
        }
    }

    private func trackFillColor(for lane: TimelineChartLane) -> Color {
        switch visualStyle {
        case .standard:
            return lane.color.opacity(0.18)
        case .glass:
            return Color.white.opacity(0.08)
        }
    }

    private func segmentFill(for color: Color) -> AnyShapeStyle {
        switch visualStyle {
        case .standard:
            return AnyShapeStyle(color)
        case .glass:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        color.opacity(0.82),
                        color.opacity(0.42)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }

    private var chartHeight: CGFloat {
        CGFloat(lanes.count) * laneHeight + CGFloat(max(0, lanes.count - 1)) * laneSpacing
    }

    private static func timeLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
