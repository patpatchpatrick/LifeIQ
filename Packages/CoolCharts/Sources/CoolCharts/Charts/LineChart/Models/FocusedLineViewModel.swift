//
//  FocusedLineViewModel.swift
//  SportsPulse
//
//  Created by Patrick Doyle on 9/16/25.
//

import SwiftUI

public struct FocusConfig: Sendable {
    public let focusColor: Color
    public let xLabelBuilder: (@Sendable (CGFloat) -> String)?
    public let yLabelBuilder: (@Sendable (CGFloat) -> String)?
    public let onFocus: (@Sendable (CGPoint) -> Void)?

    public init(focusColor: Color = .purple, xLabelBuilder: (@Sendable (CGFloat) -> String)? = nil, yLabelBuilder: (@Sendable (CGFloat) -> String)? = nil, onFocus: (@Sendable (CGPoint) -> Void)? = nil) {
        self.focusColor = focusColor
        self.xLabelBuilder = xLabelBuilder
        self.yLabelBuilder = yLabelBuilder
        self.onFocus = onFocus
    }
}

public struct FocusedLineViewModel: Animatable, Sendable {
    public let focusConfig: FocusConfig
    public nonisolated(unsafe) let lineChartModel: LineChartModel
    public private(set) var focusedCoordinate: CGPoint
    
    public let lineX: CGFloat
    public let lineStartY: CGFloat
    public let lineEndY: CGFloat
    
    let captionItems: [CaptionItem]
    
    init(focusConfig: FocusConfig, lineChartModel: LineChartModel, focusedCoordinate: CGPoint) {
        self.focusConfig = focusConfig
        self.lineChartModel = lineChartModel
        self.focusedCoordinate = focusedCoordinate
        self.lineStartY = lineChartModel.coordinatesMinY
        self.lineEndY = lineChartModel.coordinatesMaxY
        
        /// Get the nearest tapped coordinate from the chart
        let nearestX: CGFloat = {
            var nearestX = lineChartModel.coordinates.first?.x ?? 0
            for coordinate in lineChartModel.coordinates {
                if abs(coordinate.x - focusedCoordinate.x) < abs(nearestX - focusedCoordinate.x) {
                    nearestX = coordinate.x
                }
            }
            return nearestX
        }()
        
        self.lineX = nearestX
        
        let focusedCoordinate = lineChartModel.lineChartCoordinates.first(where: { $0.point.x == nearestX })
        
        if let focusedCoordinate {
            let xValue = focusedCoordinate.originalPoint.x
            let yValue = focusedCoordinate.originalPoint.y
            let xTitle = focusConfig.xLabelBuilder?(xValue) ?? "\(Double(xValue))"
            let yTitle = focusConfig.yLabelBuilder?(yValue) ?? "\(Double(yValue))"
            
            captionItems = [
                .init(lineColor: lineChartModel.lineColor, lineTitle: lineChartModel.lineTitle, xTitle: xTitle, yTitle: yTitle, uiConfig: lineChartModel.uiConfig)
            ]
        } else {
            captionItems = []
        }
    }
    
    // MARK: - Caption
    
    struct CaptionItem: Identifiable, Sendable {
        let id = UUID()
        let lineColor: Color?
        let lineTitle: String
        let xTitle: String
        let yTitle: String
        let uiConfig: LineChartModel.UIConfig
    }
    
    
    // MARK: - Animatable
    
    public typealias AnimatableData = AnimatablePair<
       Double, Double>
    
    public var animatableData: AnimatableData {
        get {
            .init(focusedCoordinate.x, focusedCoordinate.y)
        }
        set {
            focusedCoordinate = .init(x: newValue.first, y: newValue.second)
        }
    }
}
