//
//  LineChartModel.swift
//  SportsPulse
//
//  Created by Patrick Doyle on 9/16/25.
//

import SwiftUI

public struct LineChartIdentifiablePoint: Sendable {
    public let id: String
    public let point: CGPoint

    public init(id: String, point: CGPoint) {
        self.id = id
        self.point = point
    }
}

struct LineChartCoordinate {
    /// The ID associated with this point
    let id: String
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
    public let lineTitle: String
    let lineColor: Color
    public let inputPoints: [LineChartIdentifiablePoint]
    
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
    
    public let uiConfig: UIConfig
    
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
    public let focusConfig: FocusConfig?

    // MARK: - Grid
    public let gridConfig: GridConfig?

    // MARK: - Navigation
    public let navigationConfig: NavigationConfig?

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
    ///   - navigationConfig: Should be passed if the line chart will show navigation buttons
    public init?(width: CGFloat = 200, height: CGFloat = 200, lineTitle: String, uiConfig: UIConfig, inputPoints: [LineChartIdentifiablePoint], gridConfig: GridConfig? = nil, focusConfig: FocusConfig? = nil, navigationConfig: NavigationConfig? = nil) {
        guard inputPoints.count >= 2 else { return nil }

        self.width = width
        self.height = height
        self.lineTitle = lineTitle
        self.uiConfig = uiConfig
        self.inputPoints = inputPoints
        self.gridConfig = gridConfig
        self.focusConfig = focusConfig
        self.navigationConfig = navigationConfig
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

    static func buildCoordinates(width: CGFloat, height: CGFloat, inputPoints: [LineChartIdentifiablePoint]) -> [LineChartCoordinate] {
        let yFloor = height - verticalPaddingPct * height
        let yCeiling = verticalPaddingPct * height
        let xFloor = horizontalPaddingPct * width
        let xCeiling = width - horizontalPaddingPct * width

        let minX = inputPoints.map(\.point.x).min() ?? 0
        let maxX = inputPoints.map(\.point.x).max() ?? 1
        let minY = inputPoints.map(\.point.y).min() ?? 0
        let maxY = inputPoints.map(\.point.y).max() ?? 1

        // Normalize and scale points to chart dimensions
        return inputPoints.map { identifiablePoint in
            let point = identifiablePoint.point
            let normalizedX = (point.x - minX) / (maxX - minX)
            let normalizedY = (point.y - minY) / (maxY - minY)

            let x = xFloor + normalizedX * (xCeiling - xFloor)
            let y = yFloor - normalizedY * (yFloor - yCeiling) // Invert Y-axis
            let originalPoint = point
            let scaledPoint = CGPoint(x: x, y: y)
            return .init(id: identifiablePoint.id, point: scaledPoint, originalPoint: originalPoint)
        }.sorted { $0.point.x < $1.point.x }
    }

    @MainActor static let mock = LineChartModel(
        width: 250,
        height: 200,
        lineTitle: "Total",
        uiConfig: .init(colorConfig: .init(textPrimary: .accentColor, textSecondary: .black, backgroundPrimary: .blue, backgroundSecondary: .purple, lineColor: .green), fontConfig: .init(font: .body, boldFont: .caption)),
        inputPoints: [
            LineChartIdentifiablePoint(id: "0", point: CGPoint(x: 0, y: 1024)),
            LineChartIdentifiablePoint(id: "1", point: CGPoint(x: 1, y: 237)),
            LineChartIdentifiablePoint(id: "2", point: CGPoint(x: 2, y: 176)),
            LineChartIdentifiablePoint(id: "3", point: CGPoint(x: 3, y: 324)),
            LineChartIdentifiablePoint(id: "4", point: CGPoint(x: 4, y: 427)),
            LineChartIdentifiablePoint(id: "5", point: CGPoint(x: 5, y: 518))
        ],
        gridConfig: .init()
    )
    
    // MARK: - Actions
    
    public func focusCoordinateWith(id: String) {
        guard let coordinateToFocus = self.lineChartCoordinates.first(where: { $0.id == id }) else { return }
        coordinateFocused(at: .init(id: coordinateToFocus.id, point: coordinateToFocus.point))
    }
    
    public func coordinateFocused(at point: LineChartIdentifiablePoint) {
        guard let focusConfig else { return }
        focusConfig.onFocus?(point)

        withAnimation {
            self.focusedLineModel = .init(focusConfig: focusConfig, lineChartModel: self, focusedCoordinate: point.point)
        }
    }
    
    public func unfocus() {
        withAnimation {
            self.focusedLineModel = nil
        }
    }

    // MARK: - Navigation

    public func incrementXPoint() {
        navigatePoint(axis: .x, direction: .forward)
    }

    public func decrementXPoint() {
        navigatePoint(axis: .x, direction: .backward)
    }

    public func incrementYPoint() {
        navigatePoint(axis: .y, direction: .forward)
    }

    public func decrementYPoint() {
        navigatePoint(axis: .y, direction: .backward)
    }

    private func navigatePoint(axis: ChartAxis, direction: NavigationDirection) {
        guard navigationConfig != nil else { return }

        // Sort points based on the axis
        let sortedPoints: [LineChartIdentifiablePoint]
        switch axis {
        case .x:
            sortedPoints = inputPoints.sorted { $0.point.x < $1.point.x }
        case .y:
            sortedPoints = inputPoints.sorted { $0.point.y < $1.point.y }
        }

        guard !sortedPoints.isEmpty else { return }

        // Get the currently focused point ID by finding the coordinate with matching X position
        let currentFocusedId: String? = {
            guard let focusedLineModel = focusedLineModel else { return nil }
            // Find the coordinate with the matching lineX (the snapped X position)
            return lineChartCoordinates.first(where: { $0.point.x == focusedLineModel.lineX })?.id
        }()

        // If no point is focused, focus the edge point based on direction
        guard let focusedId = currentFocusedId else {
            let defaultIndex = direction == .forward ? 0 : sortedPoints.count - 1
            focusCoordinateWith(id: sortedPoints[defaultIndex].id)
            return
        }

        // Find the current focused point index
        guard let currentIndex = sortedPoints.firstIndex(where: { $0.id == focusedId }) else {
            // If focused ID not found, focus the edge point based on direction
            let defaultIndex = direction == .forward ? 0 : sortedPoints.count - 1
            focusCoordinateWith(id: sortedPoints[defaultIndex].id)
            return
        }

        // Calculate next index with wrapping
        let nextIndex: Int
        if direction == .forward {
            nextIndex = currentIndex + 1 >= sortedPoints.count ? 0 : currentIndex + 1
        } else {
            nextIndex = currentIndex - 1 < 0 ? sortedPoints.count - 1 : currentIndex - 1
        }

        focusCoordinateWith(id: sortedPoints[nextIndex].id)
    }

    private enum ChartAxis {
        case x
        case y
    }

    private enum NavigationDirection {
        case forward
        case backward
    }
}

// MARK: - NavigationConfig

public struct NavigationConfig: Sendable {
    public let showXAxisButtons: Bool
    public let showYAxisButtons: Bool

    public init(showXAxisButtons: Bool = true, showYAxisButtons: Bool = true) {
        self.showXAxisButtons = showXAxisButtons
        self.showYAxisButtons = showYAxisButtons
    }
}
