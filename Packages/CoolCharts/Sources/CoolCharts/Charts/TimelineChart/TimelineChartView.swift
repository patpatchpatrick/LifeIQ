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
    public let lanes: [TimelineChartLane]
    public let segments: [TimelineChartSegment]
    public let startDate: Date
    public let endDate: Date

    private let laneLabelWidth: CGFloat
    private let laneSpacing: CGFloat
    private let laneHeight: CGFloat

    public init(
        lanes: [TimelineChartLane],
        segments: [TimelineChartSegment],
        startDate: Date,
        endDate: Date,
        laneLabelWidth: CGFloat = 48,
        laneSpacing: CGFloat = 10,
        laneHeight: CGFloat = 10
    ) {
        self.lanes = lanes
        self.segments = segments
        self.startDate = startDate
        self.endDate = endDate
        self.laneLabelWidth = laneLabelWidth
        self.laneSpacing = laneSpacing
        self.laneHeight = laneHeight
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geometry in
                let chartWidth = max(0, geometry.size.width - laneLabelWidth)
                let totalSeconds = max(1, endDate.timeIntervalSince(startDate))

                ZStack(alignment: .topLeading) {
                    ForEach(Array(lanes.enumerated()), id: \.element.id) { index, lane in
                        let y = CGFloat(index) * (laneHeight + laneSpacing)

                        RoundedRectangle(cornerRadius: laneHeight / 2)
                            .fill(lane.color.opacity(0.18))
                            .frame(width: chartWidth, height: laneHeight)
                            .offset(x: laneLabelWidth, y: y)

                        Text(lane.title)
                            .font(.caption2)
                            .foregroundStyle(Color.secondary)
                            .lineLimit(1)
                            .frame(width: laneLabelWidth - 6, alignment: .leading)
                            .offset(x: 0, y: y - 2)
                    }

                    ForEach(segments) { segment in
                        if let laneIndex = lanes.firstIndex(where: { $0.id == segment.laneId }) {
                            let clippedStart = max(segment.startDate, startDate)
                            let clippedEnd = min(segment.endDate, endDate)
                            if clippedEnd > clippedStart {
                                let startXRatio = clippedStart.timeIntervalSince(startDate) / totalSeconds
                                let endXRatio = clippedEnd.timeIntervalSince(startDate) / totalSeconds
                                let x = laneLabelWidth + CGFloat(startXRatio) * chartWidth
                                let width = max(2, CGFloat(endXRatio - startXRatio) * chartWidth)
                                let y = CGFloat(laneIndex) * (laneHeight + laneSpacing)

                                RoundedRectangle(cornerRadius: laneHeight / 2)
                                    .fill(segment.color ?? lanes[laneIndex].color)
                                    .frame(width: width, height: laneHeight)
                                    .offset(x: x, y: y)
                            }
                        }
                    }
                }
            }
            .frame(height: chartHeight)

            HStack {
                Text(Self.timeLabel(startDate))
                    .font(.caption2)
                    .foregroundStyle(Color.secondary)
                Spacer()
                Text(Self.timeLabel(endDate))
                    .font(.caption2)
                    .foregroundStyle(Color.secondary)
            }
            .padding(.leading, laneLabelWidth)
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
