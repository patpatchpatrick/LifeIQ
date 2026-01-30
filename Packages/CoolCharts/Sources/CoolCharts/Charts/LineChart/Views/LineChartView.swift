//
//  LineChartView.swift
//  SportsPulse
//
//  Created by Patrick Doyle on 9/16/25.
//

import SwiftUI

public struct LineChartView: View {
    @ObservedObject var model: LineChartModel
    
    // MARK: - Body
    
    public var body: some View {
        ZStack {
            
            if let gridConfig = model.gridConfig {
                GridBackgroundView(lineChartModel: model, gridConfig: gridConfig)
            }
            
            LineChartShape(model: model)
                .fill(model.lineColor)
            
            Rectangle()
                .fill(LinearGradient(gradient: Gradient(colors: [.green.opacity(0.2), .clear]), startPoint: .top, endPoint: .bottom))
                .frame(width: model.width, height: model.height)
                .clipShape(LineChartGradientShape(model: model))
            
            if let focusedLineModel = model.focusedLineModel {
                FocusedLineView(lineChartModel: model, model: focusedLineModel)
            }
        }
        .onTapGesture { location in
            model.coordinateFocused(at: location)
        }
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
        var path = Path()
        
        path.move(to: model.coordinates.first!)
        
        model.coordinates.forEach {
            path.addLine(to: $0)
        }
        
        return path
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
        
        path.move(to: model.coordinates.first!)
        
        model.coordinates.forEach {
            path.addLine(to: $0)
        }
        
        path.addLine(to: .init(x: model.coordinates.last!.x + LineChartShape.strokeWidth, y: model.coordinates.last!.y))
        
        path.addLine(to: .init(x: model.xCeiling + LineChartShape.strokeWidth, y: model.yFloor))
        
        path.closeSubpath()
        
        return path
    }
}

#Preview {
    LineChartView(model: .mock!)
}
