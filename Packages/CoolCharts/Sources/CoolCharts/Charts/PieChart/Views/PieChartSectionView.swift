//
//  PieChartSectionView.swift
//  CoolCharts
//
//  Created by Patrick Doyle on 5/24/25.
//

import SwiftUI

public struct PieChartSectionView: View {
    public var model: PieChartSection
    
    public init(model: PieChartSection) {
        self.model = model
    }
    
    public var body: some View {
        PieChartSectionShape(model: model)
            .fill(model.color)
    }
}

public struct PieChartSectionShape: Shape {
    public var model: PieChartSection
    
    public init(model: PieChartSection) {
        self.model = model
    }
    
    public func path(in rect: CGRect) -> Path {
        let path = piePiecePath(in: rect)
        let polishedPath = polishOffUi(path)
        return Path(polishedPath)
    }
    
    public func polishOffUi(_ path: Path) -> CGPath {
        return path.cgPath.copy(
            strokingWithWidth: model.strokeWidth,
            lineCap: .butt,
            lineJoin: .miter,
            miterLimit: 0)
    }
    
    public func piePiecePath(in rect: CGRect) -> Path {
        var path = Path()
        
        /// Clockwise is weird in SwiftUI: https://stackoverflow.com/questions/57225735/is-clockwise-of-path-addarc-in-swiftui-wrong
        path.addArc(
            center: .init(x: model.centerX, y: model.centerY),
            radius: model.radius,
            startAngle: .degrees(model.startAngleDegrees),
            endAngle: .degrees(model.endAngleDegrees),
            clockwise: false)
        
        return path
    }
    
    public var animatableData: PieChartSection.AnimatableData {
        get { model.animatableData }
        set { model.animatableData = newValue }
    }
}

public struct PieChartSectorShape: Shape {
    public var model: PieChartSection
    public var radiusPercent: CGFloat

    public init(model: PieChartSection, radiusPercent: CGFloat = 1) {
        self.model = model
        self.radiusPercent = radiusPercent
    }

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let maxRadius = model.widthHeight / 2
        let radius = maxRadius * max(0, min(1, radiusPercent))

        path.move(to: CGPoint(x: model.centerX, y: model.centerY))
        path.addArc(
            center: CGPoint(x: model.centerX, y: model.centerY),
            radius: radius,
            startAngle: .degrees(model.startAngleDegrees),
            endAngle: .degrees(model.endAngleDegrees),
            clockwise: false
        )
        path.closeSubpath()
        return path
    }

    public var animatableData: PieChartSection.AnimatableData {
        get { model.animatableData }
        set { model.animatableData = newValue }
    }
}

public struct PieChartDonutBandSectorShape: Shape {
    public var model: PieChartSection
    public var radialFillPercent: CGFloat

    public init(model: PieChartSection, radialFillPercent: CGFloat = 1) {
        self.model = model
        self.radialFillPercent = radialFillPercent
    }

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let midRadius = model.radius
        let innerRadius = max(0, midRadius - model.strokeWidth / 2)
        let outerRadius = midRadius + model.strokeWidth / 2
        let effectiveOuter = innerRadius + (outerRadius - innerRadius) * max(0, min(1, radialFillPercent))

        // Outer arc
        path.addArc(
            center: CGPoint(x: model.centerX, y: model.centerY),
            radius: effectiveOuter,
            startAngle: .degrees(model.startAngleDegrees),
            endAngle: .degrees(model.endAngleDegrees),
            clockwise: false
        )

        // Inner arc (reverse) to close band
        path.addArc(
            center: CGPoint(x: model.centerX, y: model.centerY),
            radius: innerRadius,
            startAngle: .degrees(model.endAngleDegrees),
            endAngle: .degrees(model.startAngleDegrees),
            clockwise: true
        )
        path.closeSubpath()

        return path
    }

    public var animatableData: PieChartSection.AnimatableData {
        get { model.animatableData }
        set { model.animatableData = newValue }
    }
}
