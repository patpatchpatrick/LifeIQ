//
//  LineChartModel.swift
//  SportsPulse
//
//  Created by Patrick Doyle on 9/16/25.
//

import SwiftUI

struct LineChartCoordinate {
    /// The point scaled for the coordinate system
    let point: CGPoint
    /// The actual values of the original point
    let originalPoint: CGPoint
}

public final class LineChartModel: ObservableObject {
    static let verticalPaddingPct = 0.1
    static let horizontalPaddingPct = 0.1

    let width: CGFloat
    let height: CGFloat
    let lineTitle: String
    let lineColor: Color
    let inputPoints: [CGPoint]
    
    // MARK: - Coordinates
    /// Map of scaled coordinated and original coordinates
    let lineChartCoordinates: [LineChartCoordinate]
    /// The scaled coordinates of the chart
    let coordinates: [CGPoint]
    let coordinatesMinX: CGFloat
    let coordinatesMaxX: CGFloat
    let coordinatesMinY: CGFloat
    let coordinatesMaxY: CGFloat
    /// The original coordinates of the chart
    let originalCoordinates: [CGPoint]
    let originalCoordinatesMinX: CGFloat
    let originalCoordinatesMaxX: CGFloat
    let originalCoordinatesMinY: CGFloat
    let originalCoordinatesMaxY: CGFloat
    
    let uiConfig: UIConfig
    
    public struct UIConfig: Sendable {
        public let colorConfig: ColorConfig
        public let fontConfig: FontConfig
        
        public init(colorConfig: ColorConfig, fontConfig: FontConfig) {
            self.colorConfig = colorConfig
            self.fontConfig = fontConfig
        }
    }
    
    public struct ColorConfig: Sendable {
        let textPrimary: Color
        let textSecondary: Color
        let backgroundPrimary: Color
        let backgroundSecondary: Color
        let lineColor: Color
        
        public init(textPrimary: Color, textSecondary: Color, backgroundPrimary: Color, backgroundSecondary: Color, lineColor: Color) {
            self.textPrimary = textPrimary
            self.textSecondary = textSecondary
            self.backgroundPrimary = backgroundPrimary
            self.backgroundSecondary = backgroundSecondary
            self.lineColor = lineColor
        }
    }
    
    public struct FontConfig: Sendable {
        let font: Font
        let boldFont: Font
        
        public init(font: Font, boldFont: Font) {
            self.font = font
            self.boldFont = boldFont
        }
    }
    
    // MARK: - Focus
    @Published private(set) var focusedLineModel: FocusedLineViewModel?
    let focusConfig: FocusConfig?
    
    // MARK: - Grid
    let gridConfig: GridConfig?

    var yFloor: CGFloat { height - Self.verticalPaddingPct * height }
    var yCeiling: CGFloat { Self.verticalPaddingPct * height }
    var xFloor: CGFloat { Self.horizontalPaddingPct * width }
    var xCeiling: CGFloat { width - Self.horizontalPaddingPct * width }
    
    /// Init
    /// - Parameters:
    ///   - width: width
    ///   - height: height
    ///   - lineTitle: Title of the line (appears on selectable caption)
    ///   - lineColor: Line color
    ///   - inputPoints: Line chart points
    ///   - gridConfig: Should be passed if the line chart will use a grid
    ///   - focusConfig: Should be passed if the line chart will allow focus
    public init?(width: CGFloat = 200, height: CGFloat = 200, lineTitle: String, uiConfig: UIConfig, inputPoints: [CGPoint], gridConfig: GridConfig? = nil, focusConfig: FocusConfig? = nil) {
        guard inputPoints.count >= 2 else { return nil }

        self.width = width
        self.height = height
        self.lineTitle = lineTitle
        self.uiConfig = uiConfig
        self.inputPoints = inputPoints
        self.gridConfig = gridConfig
        self.focusConfig = focusConfig
        self.lineChartCoordinates = Self.buildCoordinates(width: width, height: height, inputPoints: inputPoints)
        self.coordinates = lineChartCoordinates.map { $0.point }
        self.originalCoordinates = lineChartCoordinates.map { $0.originalPoint }
        self.coordinatesMinX = coordinates.map { $0.x }.min()!
        self.coordinatesMaxX = coordinates.map { $0.x }.max()!
        self.coordinatesMinY = coordinates.map { $0.y }.min()!
        self.coordinatesMaxY = coordinates.map { $0.y }.max()!
        self.originalCoordinatesMinX = originalCoordinates.map { $0.x }.min()!
        self.originalCoordinatesMaxX = originalCoordinates.map { $0.x }.max()!
        self.originalCoordinatesMinY = originalCoordinates.map { $0.y }.min()!
        self.originalCoordinatesMaxY = originalCoordinates.map { $0.y }.max()!
        self.lineColor = uiConfig.colorConfig.lineColor
    }

    static func buildCoordinates(width: CGFloat, height: CGFloat, inputPoints: [CGPoint]) -> [LineChartCoordinate] {
        let yFloor = height - verticalPaddingPct * height
        let yCeiling = verticalPaddingPct * height
        let xFloor = horizontalPaddingPct * width
        let xCeiling = width - horizontalPaddingPct * width

        let minX = inputPoints.map(\.x).min() ?? 0
        let maxX = inputPoints.map(\.x).max() ?? 1
        let minY = inputPoints.map(\.y).min() ?? 0
        let maxY = inputPoints.map(\.y).max() ?? 1

        // Normalize and scale points to chart dimensions
        return inputPoints.map { point in
            let normalizedX = (point.x - minX) / (maxX - minX)
            let normalizedY = (point.y - minY) / (maxY - minY)

            let x = xFloor + normalizedX * (xCeiling - xFloor)
            let y = yFloor - normalizedY * (yFloor - yCeiling) // Invert Y-axis
            let originalPoint = point
            let scaledPoint = CGPoint(x: x, y: y)
            return .init(point: scaledPoint, originalPoint: originalPoint)
        }.sorted { $0.point.x < $1.point.x }
    }

    @MainActor static let mock = LineChartModel(
        width: 250,
        height: 200,
        lineTitle: "Total",
        uiConfig: .init(colorConfig: .init(textPrimary: .accentColor, textSecondary: .black, backgroundPrimary: .blue, backgroundSecondary: .purple, lineColor: .green), fontConfig: .init(font: .body, boldFont: .caption)),
        inputPoints: [
            CGPoint(x: 0, y: 1024),
            CGPoint(x: 1, y: 237),
            CGPoint(x: 2, y: 176),
            CGPoint(x: 3, y: 324),
            CGPoint(x: 4, y: 427),
            CGPoint(x: 5, y: 518)
        ],
        gridConfig: .init()
    )
    
    // MARK: - Actions
    
    public func coordinateFocused(at point: CGPoint) {
        guard let focusConfig else { return }
        focusConfig.onFocus?()
        
        withAnimation {
            self.focusedLineModel = .init(focusConfig: focusConfig, lineChartModel: self, focusedCoordinate: point)
        }
    }
    
    public func unfocus() {
        withAnimation {
            self.focusedLineModel = nil
        }
    }
}
