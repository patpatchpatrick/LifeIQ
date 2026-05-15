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
    private let onSegmentSelected: ((TimelineChartSegment) -> Void)?
    private let onLaneSelected: ((TimelineChartLane) -> Void)?

    public init(
        lanes: [TimelineChartLane],
        segments: [TimelineChartSegment],
        startDate: Date,
        endDate: Date,
        laneLabelWidth: CGFloat = 48,
        laneSpacing: CGFloat = 10,
        laneHeight: CGFloat = 10,
        visualStyle: VisualStyle = .standard,
        onSegmentSelected: ((TimelineChartSegment) -> Void)? = nil,
        onLaneSelected: ((TimelineChartLane) -> Void)? = nil
    ) {
        self.lanes = lanes
        self.segments = segments
        self.startDate = startDate
        self.endDate = endDate
        self.laneLabelWidth = laneLabelWidth
        self.laneSpacing = laneSpacing
        self.laneHeight = laneHeight
        self.visualStyle = visualStyle
        self.onSegmentSelected = onSegmentSelected
        self.onLaneSelected = onLaneSelected
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
                .frame(width: geometry.size.width, height: chartHeight, alignment: .topLeading)
                .contentShape(Rectangle())
                .onTapGesture { location in
                    selectTimelineItem(
                        at: location,
                        chartWidth: chartWidth,
                        totalSeconds: totalSeconds
                    )
                }
            }
            .frame(height: chartHeight)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 0) {
                    axisTick
                    Rectangle()
                        .fill(axisColor)
                        .frame(height: 1)
                    axisTick
                }

                HStack {
                    axisEndpointLabel(Self.timeLabel(startDate))
                    Spacer()
                    axisEndpointLabel(Self.timeLabel(endDate))
                }
            }
            .padding(.leading, laneLabelWidth)
            .padding(.top, 2)
        }
    }

    @ViewBuilder
    private var axisTick: some View {
        switch visualStyle {
        case .standard:
            Rectangle()
                .fill(labelColor.opacity(0.38))
                .frame(width: 1, height: 5)
        case .glass:
            Rectangle()
                .fill(axisColor.opacity(1.4))
                .frame(width: 1, height: 5)
        }
    }

    @ViewBuilder
    private func axisEndpointLabel(_ label: String) -> some View {
        switch visualStyle {
        case .standard:
            Text(label)
                .font(.caption2)
                .foregroundStyle(labelColor)
        case .glass:
            Text(label)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(Color.white.opacity(0.70))
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

    private var axisColor: Color {
        switch visualStyle {
        case .standard:
            return labelColor.opacity(0.24)
        case .glass:
            return Color.white.opacity(0.14)
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

    private func selectTimelineItem(at location: CGPoint, chartWidth: CGFloat, totalSeconds: TimeInterval) {
        guard onSegmentSelected != nil || onLaneSelected != nil else { return }
        guard location.x >= 0, location.x <= laneLabelWidth + chartWidth else { return }
        guard laneHeight > 0 else { return }

        let laneStride = laneHeight + laneSpacing
        let laneIndex = Int(location.y / laneStride)
        guard lanes.indices.contains(laneIndex) else { return }

        let laneY = location.y - CGFloat(laneIndex) * laneStride
        guard laneY >= 0, laneY <= laneStride else { return }

        let lane = lanes[laneIndex]
        let chartX = location.x - laneLabelWidth
        guard chartX >= 0, chartX <= chartWidth else {
            onLaneSelected?(lane)
            return
        }

        let selectedDate = startDate.addingTimeInterval(Double(chartX / max(1, chartWidth)) * totalSeconds)
        if let segment = segments.first(where: { segment in
            segment.laneId == lane.id &&
            segment.startDate <= selectedDate &&
            selectedDate <= segment.endDate
        }) {
            onSegmentSelected?(segment)
            return
        }

        onLaneSelected?(lane)
    }

    private static func timeLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
