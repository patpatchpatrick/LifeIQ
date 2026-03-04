//
//  PieChartSection.swift
//  NetWorthTracker
//
//  Created by Patrick Doyle on 5/24/25.
//

import SwiftUI

// MARK: - Sections

public struct PieChartSectionConfig: Identifiable, Sendable {
    public let id: String
    public let magnitude: Double /// All magnitudes will be summed and the percentage of the pie chart will be determined by the ratios
    public let color: Color
    public let radialFillPercent: Double?
    public let radialUnfilledColor: Color?
    
    public init(
        id: String,
        magnitude: Double,
        color: Color,
        radialFillPercent: Double? = nil,
        radialUnfilledColor: Color? = nil
    ) {
        self.id = id
        self.magnitude = magnitude
        self.color = color
        self.radialFillPercent = radialFillPercent
        self.radialUnfilledColor = radialUnfilledColor
    }
}

public struct PieChartSection: Identifiable, Sendable {
    public let id: String
    public let widthHeight: CGFloat
    public let pieceAlignment: PieChartModel.SectionAlignment
    public let color: Color
    public var strokeWidth: CGFloat
    public var expectedStrokeWidth: CGFloat
    public let chartMaxStrokeWidth: CGFloat
    public var startAngleDegrees: CGFloat
    public let expectedEndAngleDegrees: CGFloat
    public var endAngleDegrees: CGFloat
    public let radialFillPercent: Double?
    public let radialUnfilledColor: Color?
    
    public var theta: CGFloat {
        thetaDegrees * .pi / 180
    }
    
    public var thetaDegrees: CGFloat {
        startAngleDegrees - (-90) + (expectedEndAngleDegrees - startAngleDegrees) / 2
    }
    
    public var x: CGFloat {
        return radius * sin(theta)
    }
    
    public var y: CGFloat {
        return radius * cos(theta)
    }
    
    public init(
        id: String,
        widthHeight: CGFloat,
        pieceAlignment: PieChartModel.SectionAlignment,
        color: Color,
        strokeWidth: CGFloat,
        chartMaxStrokeWidth: CGFloat,
        startAngleDegrees: CGFloat,
        endAngleDegrees: CGFloat,
        radialFillPercent: Double? = nil,
        radialUnfilledColor: Color? = nil
    ) {
        self.id = id
        self.widthHeight = widthHeight
        self.pieceAlignment = pieceAlignment
        self.color = color
        self.strokeWidth = strokeWidth
        self.expectedStrokeWidth = strokeWidth
        self.chartMaxStrokeWidth = chartMaxStrokeWidth
        self.startAngleDegrees = startAngleDegrees
        self.expectedEndAngleDegrees = endAngleDegrees
        self.endAngleDegrees = startAngleDegrees /// Start at the start angle until it's animated
        self.radialFillPercent = radialFillPercent
        self.radialUnfilledColor = radialUnfilledColor
    }
    
    public var radius: CGFloat {
        switch pieceAlignment {
        case .outside:
            return  widthHeight / 2 - strokeWidth / 2
        case .center:
            return  widthHeight / 2 - chartMaxStrokeWidth / 2
        }
    }
    public var centerX: CGFloat { widthHeight / 2 }
    public var centerY: CGFloat { widthHeight / 2 }
}

extension PieChartSection: Animatable {
    
    public typealias AnimatableData = AnimatablePair<
        AnimatablePair<Double, Double>, AnimatablePair<Double, Double>>
    
    public var animatableData: AnimatableData {
        get {
            .init(.init(startAngleDegrees, endAngleDegrees), .init(strokeWidth, strokeWidth))
        }
        set {
            startAngleDegrees = newValue.first.first
            endAngleDegrees = newValue.first.second
            strokeWidth = newValue.second.first
        }
    }
}
