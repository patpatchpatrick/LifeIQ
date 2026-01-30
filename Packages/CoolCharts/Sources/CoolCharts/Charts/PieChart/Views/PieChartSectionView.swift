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
