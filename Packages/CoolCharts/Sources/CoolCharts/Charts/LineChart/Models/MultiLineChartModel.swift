//
//  MultiLineChartModel.swift
//  CoolCharts
//

import SwiftUI

public struct MultiLineChartSeries: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let color: Color
    public let inputPoints: [LineChartIdentifiablePoint]
    public let focusLabelByPointId: [String: String]

    public init(
        id: String,
        title: String,
        color: Color,
        inputPoints: [LineChartIdentifiablePoint],
        focusLabelByPointId: [String: String] = [:]
    ) {
        self.id = id
        self.title = title
        self.color = color
        self.inputPoints = inputPoints
        self.focusLabelByPointId = focusLabelByPointId
    }
}

public struct MultiLineChartFocusedPoint: Sendable {
    public let seriesID: String
    public let seriesTitle: String
    public let pointID: String
    public let originalPoint: CGPoint

    public init(
        seriesID: String,
        seriesTitle: String,
        pointID: String,
        originalPoint: CGPoint
    ) {
        self.seriesID = seriesID
        self.seriesTitle = seriesTitle
        self.pointID = pointID
        self.originalPoint = originalPoint
    }
}

public struct MultiLineChartFocusConfig: Sendable {
    public let focusColor: Color
    public let xLabelBuilder: (@Sendable (String, CGFloat) -> String)?
    public let yLabelBuilder: (@Sendable (String, String, CGFloat) -> String)?
    public let onFocus: (@Sendable (MultiLineChartFocusedPoint) -> Void)?

    public init(
        focusColor: Color = .purple,
        xLabelBuilder: (@Sendable (String, CGFloat) -> String)? = nil,
        yLabelBuilder: (@Sendable (String, String, CGFloat) -> String)? = nil,
        onFocus: (@Sendable (MultiLineChartFocusedPoint) -> Void)? = nil
    ) {
        self.focusColor = focusColor
        self.xLabelBuilder = xLabelBuilder
        self.yLabelBuilder = yLabelBuilder
        self.onFocus = onFocus
    }
}

struct MultiLineChartCoordinate {
    let seriesID: String
    let seriesTitle: String
    let seriesColor: Color
    let id: String
    let point: CGPoint
    let originalPoint: CGPoint
    let focusLabel: String?
}

struct MultiLineChartCoordinateSet: Identifiable {
    let id: String
    let title: String
    let color: Color
    let coordinates: [MultiLineChartCoordinate]

    var points: [CGPoint] {
        coordinates.map(\.point)
    }
}

public final class MultiLineChartModel: ObservableObject {
    static let verticalPaddingPct = LineChartModel.verticalPaddingPct
    static let horizontalPaddingPct = LineChartModel.horizontalPaddingPct
    static let yDomainPaddingPct = LineChartModel.yDomainPaddingPct

    let width: CGFloat
    let height: CGFloat
    public let series: [MultiLineChartSeries]
    public let uiConfig: LineChartModel.UIConfig
    public let gridConfig: GridConfig?
    public let focusConfig: MultiLineChartFocusConfig?
    public let navigationConfig: NavigationConfig?

    let coordinateSets: [MultiLineChartCoordinateSet]
    let originalCoordinatesMinX: CGFloat
    let originalCoordinatesMaxX: CGFloat
    let originalCoordinatesMinY: CGFloat
    let originalCoordinatesMaxY: CGFloat

    @Published public private(set) var visibleSeriesIDs: Set<String>
    @Published private(set) var focusedLineModel: MultiLineChartFocusedLineViewModel?

    var yFloor: CGFloat { height - Self.verticalPaddingPct * height }
    var yCeiling: CGFloat { Self.verticalPaddingPct * height }
    var xFloor: CGFloat { Self.horizontalPaddingPct * width }
    var xCeiling: CGFloat { width - Self.horizontalPaddingPct * width }

    var visibleCoordinateSets: [MultiLineChartCoordinateSet] {
        coordinateSets.filter { visibleSeriesIDs.contains($0.id) }
    }

    var visibleCoordinates: [MultiLineChartCoordinate] {
        visibleCoordinateSets.flatMap(\.coordinates)
    }

    var coordinatesMinX: CGFloat {
        visibleCoordinates.map(\.point.x).min() ?? xFloor
    }

    var coordinatesMaxX: CGFloat {
        visibleCoordinates.map(\.point.x).max() ?? xCeiling
    }

    var coordinatesMinY: CGFloat {
        visibleCoordinates.map(\.point.y).min() ?? yCeiling
    }

    var coordinatesMaxY: CGFloat {
        visibleCoordinates.map(\.point.y).max() ?? yFloor
    }

    public init?(
        width: CGFloat = 200,
        height: CGFloat = 200,
        series: [MultiLineChartSeries],
        uiConfig: LineChartModel.UIConfig,
        gridConfig: GridConfig? = nil,
        focusConfig: MultiLineChartFocusConfig? = nil,
        navigationConfig: NavigationConfig? = nil
    ) {
        let validSeries = series
            .map { series in
                MultiLineChartSeries(
                    id: series.id,
                    title: series.title,
                    color: series.color,
                    inputPoints: series.inputPoints.sorted { $0.point.x < $1.point.x },
                    focusLabelByPointId: series.focusLabelByPointId
                )
            }
            .filter { $0.inputPoints.count >= 2 }

        guard !validSeries.isEmpty else { return nil }

        let allPoints = validSeries.flatMap(\.inputPoints)
        guard let xDomain = Self.domain(for: allPoints.map(\.point.x)),
              let yDomain = Self.paddedDomain(for: allPoints.map(\.point.y)) else {
            return nil
        }

        self.width = width
        self.height = height
        self.series = validSeries
        self.uiConfig = uiConfig
        self.gridConfig = gridConfig
        self.focusConfig = focusConfig
        self.navigationConfig = navigationConfig
        self.visibleSeriesIDs = Set(validSeries.map(\.id))
        self.originalCoordinatesMinX = xDomain.lowerBound
        self.originalCoordinatesMaxX = xDomain.upperBound
        self.originalCoordinatesMinY = yDomain.lowerBound
        self.originalCoordinatesMaxY = yDomain.upperBound
        self.coordinateSets = validSeries.map { series in
            MultiLineChartCoordinateSet(
                id: series.id,
                title: series.title,
                color: series.color,
                coordinates: Self.buildCoordinates(
                    width: width,
                    height: height,
                    series: series,
                    xDomain: xDomain,
                    yDomain: yDomain
                )
            )
        }
    }

    public func isSeriesVisible(_ seriesID: String) -> Bool {
        visibleSeriesIDs.contains(seriesID)
    }

    public func toggleSeriesVisibility(_ seriesID: String) {
        if visibleSeriesIDs.contains(seriesID) {
            guard visibleSeriesIDs.count > 1 else { return }
            visibleSeriesIDs.remove(seriesID)

            if focusedLineModel?.focusedCoordinate.seriesID == seriesID {
                unfocus()
            }
        } else {
            visibleSeriesIDs.insert(seriesID)
        }
    }

    public func focusCoordinateWith(seriesID: String, pointID: String) {
        guard let coordinate = coordinateSets
            .first(where: { $0.id == seriesID })?
            .coordinates
            .first(where: { $0.id == pointID }) else {
            return
        }

        coordinateFocused(coordinate)
    }

    public func focusNearestCoordinate(to location: CGPoint) {
        guard let coordinate = visibleCoordinates.min(by: { lhs, rhs in
            lhs.point.distance(to: location) < rhs.point.distance(to: location)
        }) else {
            return
        }

        coordinateFocused(coordinate)
    }

    public func unfocus() {
        withAnimation {
            focusedLineModel = nil
        }
    }

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

    private func coordinateFocused(_ coordinate: MultiLineChartCoordinate) {
        guard let focusConfig else { return }

        focusConfig.onFocus?(
            .init(
                seriesID: coordinate.seriesID,
                seriesTitle: coordinate.seriesTitle,
                pointID: coordinate.id,
                originalPoint: coordinate.originalPoint
            )
        )

        withAnimation {
            focusedLineModel = .init(
                focusConfig: focusConfig,
                lineChartModel: self,
                focusedCoordinate: coordinate
            )
        }
    }

    private func navigatePoint(axis: ChartAxis, direction: NavigationDirection) {
        guard navigationConfig != nil else { return }

        let sortedCoordinates: [MultiLineChartCoordinate]
        switch axis {
        case .x:
            sortedCoordinates = xNavigationCoordinates()
        case .y:
            sortedCoordinates = visibleCoordinates.sorted {
                $0.originalPoint.y < $1.originalPoint.y
            }
        }

        guard !sortedCoordinates.isEmpty else { return }

        let currentFocusedCoordinate = focusedLineModel?.focusedCoordinate
        let currentIndex = currentFocusedCoordinate.flatMap { current in
            sortedCoordinates.firstIndex { coordinate in
                coordinate.seriesID == current.seriesID && coordinate.id == current.id
            }
        }

        guard let currentIndex else {
            let defaultIndex = direction == .forward ? 0 : sortedCoordinates.count - 1
            coordinateFocused(sortedCoordinates[defaultIndex])
            return
        }

        let nextIndex: Int
        if direction == .forward {
            nextIndex = currentIndex + 1 >= sortedCoordinates.count ? 0 : currentIndex + 1
        } else {
            nextIndex = currentIndex - 1 < 0 ? sortedCoordinates.count - 1 : currentIndex - 1
        }

        coordinateFocused(sortedCoordinates[nextIndex])
    }

    private func xNavigationCoordinates() -> [MultiLineChartCoordinate] {
        let seriesID: String?
        if let focusedSeriesID = focusedLineModel?.focusedCoordinate.seriesID,
           visibleSeriesIDs.contains(focusedSeriesID) {
            seriesID = focusedSeriesID
        } else {
            seriesID = visibleCoordinateSets.first?.id
        }

        return visibleCoordinateSets
            .first(where: { $0.id == seriesID })?
            .coordinates
            .sorted { $0.originalPoint.x < $1.originalPoint.x }
            ?? visibleCoordinates.sorted { $0.originalPoint.x < $1.originalPoint.x }
    }

    private enum ChartAxis {
        case x
        case y
    }

    private enum NavigationDirection {
        case forward
        case backward
    }

    private static func buildCoordinates(
        width: CGFloat,
        height: CGFloat,
        series: MultiLineChartSeries,
        xDomain: ClosedRange<CGFloat>,
        yDomain: ClosedRange<CGFloat>
    ) -> [MultiLineChartCoordinate] {
        let yFloor = height - verticalPaddingPct * height
        let yCeiling = verticalPaddingPct * height
        let xFloor = horizontalPaddingPct * width
        let xCeiling = width - horizontalPaddingPct * width
        let minX = xDomain.lowerBound
        let maxX = xDomain.upperBound
        let minY = yDomain.lowerBound
        let maxY = yDomain.upperBound

        return series.inputPoints.map { identifiablePoint in
            let point = identifiablePoint.point
            let normalizedX = maxX == minX ? 0.5 : (point.x - minX) / (maxX - minX)
            let normalizedY = maxY == minY ? 0.5 : (point.y - minY) / (maxY - minY)
            let scaledPoint = CGPoint(
                x: xFloor + normalizedX * (xCeiling - xFloor),
                y: yFloor - normalizedY * (yFloor - yCeiling)
            )

            return MultiLineChartCoordinate(
                seriesID: series.id,
                seriesTitle: series.title,
                seriesColor: series.color,
                id: identifiablePoint.id,
                point: scaledPoint,
                originalPoint: point,
                focusLabel: series.focusLabelByPointId[identifiablePoint.id]
            )
        }
        .sorted { $0.point.x < $1.point.x }
    }

    private static func domain(for values: [CGFloat]) -> ClosedRange<CGFloat>? {
        guard let min = values.min(), let max = values.max() else { return nil }
        return min...max
    }

    private static func paddedDomain(for values: [CGFloat]) -> ClosedRange<CGFloat>? {
        guard let min = values.min(), let max = values.max() else { return nil }
        let range = max - min
        let padding = Swift.max(range * yDomainPaddingPct, range == 0 ? 1 : 0)
        return (min - padding)...(max + padding)
    }
}

struct MultiLineChartFocusedLineViewModel: Animatable, Sendable {
    let focusConfig: MultiLineChartFocusConfig
    public nonisolated(unsafe) let lineChartModel: MultiLineChartModel
    var focusedCoordinate: MultiLineChartCoordinate
    let lineX: CGFloat
    let lineStartY: CGFloat
    let lineEndY: CGFloat
    let captionItems: [CaptionItem]

    init(
        focusConfig: MultiLineChartFocusConfig,
        lineChartModel: MultiLineChartModel,
        focusedCoordinate: MultiLineChartCoordinate
    ) {
        self.focusConfig = focusConfig
        self.lineChartModel = lineChartModel
        self.focusedCoordinate = focusedCoordinate
        self.lineX = focusedCoordinate.point.x
        self.lineStartY = lineChartModel.yCeiling
        self.lineEndY = lineChartModel.yFloor

        let matchingCoordinates = lineChartModel.visibleCoordinates
            .filter { abs($0.originalPoint.x - focusedCoordinate.originalPoint.x) < 0.001 }
            .sorted { lhs, rhs in
                if lhs.seriesID == focusedCoordinate.seriesID {
                    return true
                }
                if rhs.seriesID == focusedCoordinate.seriesID {
                    return false
                }
                return lhs.seriesTitle.localizedCaseInsensitiveCompare(rhs.seriesTitle) == .orderedAscending
            }

        self.captionItems = matchingCoordinates.map { coordinate in
            let xTitle = focusConfig.xLabelBuilder?(coordinate.id, coordinate.originalPoint.x) ?? "\(Double(coordinate.originalPoint.x))"
            let yTitle = coordinate.focusLabel
                ?? focusConfig.yLabelBuilder?(coordinate.seriesID, coordinate.id, coordinate.originalPoint.y)
                ?? "\(Double(coordinate.originalPoint.y))"

            return .init(
                lineColor: coordinate.seriesColor,
                lineTitle: coordinate.seriesTitle,
                xTitle: xTitle,
                yTitle: yTitle,
                uiConfig: lineChartModel.uiConfig
            )
        }
    }

    struct CaptionItem: Identifiable, Sendable {
        let id = UUID()
        let lineColor: Color?
        let lineTitle: String
        let xTitle: String
        let yTitle: String
        let uiConfig: LineChartModel.UIConfig
    }

    public typealias AnimatableData = AnimatablePair<Double, Double>

    public var animatableData: AnimatableData {
        get {
            .init(focusedCoordinate.point.x, focusedCoordinate.point.y)
        }
        set {
            focusedCoordinate = MultiLineChartCoordinate(
                seriesID: focusedCoordinate.seriesID,
                seriesTitle: focusedCoordinate.seriesTitle,
                seriesColor: focusedCoordinate.seriesColor,
                id: focusedCoordinate.id,
                point: .init(x: newValue.first, y: newValue.second),
                originalPoint: focusedCoordinate.originalPoint,
                focusLabel: focusedCoordinate.focusLabel
            )
        }
    }
}

private extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat {
        hypot(x - other.x, y - other.y)
    }
}
