//
//  PieChartModel.swift
//  CoolCharts
//
//  Created by Patrick Doyle on 5/24/25.
//

import SwiftUI

@MainActor
public final class PieChartModel: ObservableObject {
    public var expectedPieSections: [PieChartSection]
    @Published public var pieSections: [PieChartSection]
    public let sectionIdTapped: ((String) -> Void)?
    public let sectionAlignment: SectionAlignment
    public enum SectionAlignment: Sendable {
        case outside
        case center
    }
    public let initialStartAngleDegrees: CGFloat
    public let widthHeight: CGFloat
    
    
    // MARK: - UI Configuration
    
    public init?(
        sections: [PieChartSectionConfig],
        sectionIdTapped: ((String) -> Void)? = nil,
        sectionAlignment: SectionAlignment = .center,
        initialStartAngleDegrees: CGFloat = -90,
        widthHeight: CGFloat = 200
    ) {
        self.sectionIdTapped = sectionIdTapped
        
        var totalMagnitude: Double = 0
        
        for section in sections {
            guard section.magnitude > 0 else {
                print("Invalid Section Magnitude", section.magnitude)
                return nil
            }
            
            totalMagnitude += section.magnitude
        }
        
        guard totalMagnitude > 0 else {
            print("Section magnitudes add up to zero or less")
            return nil
        }
        
        var startAngle = initialStartAngleDegrees
        
        var pieSections = [PieChartSection]()
        for section in sections {
            
            let anglePercentage = section.magnitude / totalMagnitude
            let endAngle = startAngle + anglePercentage * 360
            
            pieSections.append(.init(
                id: section.id,
                widthHeight: widthHeight,
                pieceAlignment: sectionAlignment,
                color: section.color,
                strokeWidth: 30,
                chartMaxStrokeWidth: 40,
                startAngleDegrees: startAngle,
                endAngleDegrees: endAngle))
            
            startAngle = endAngle
        }
        
        self.expectedPieSections = pieSections
        self.pieSections = []
        self.sectionAlignment = sectionAlignment
        self.initialStartAngleDegrees = initialStartAngleDegrees
        self.widthHeight = widthHeight
    }
    
    public func animateAppearance() async {
        
        pieSections = []
        for section in expectedPieSections {
            pieSections.append(section)
            
            withAnimation {
                pieSections = pieSections.map {
                    var section = $0
                    section.endAngleDegrees = section.expectedEndAngleDegrees
                    return section
                }
            }

            try? await Task.sleep(for: .seconds(0.1))
        }
    }
    
    public func sectionFocused(sectionId: String?, shouldCallFocusCompletionHandler: Bool = true) {
        
        withAnimation {
            pieSections = pieSections.map {
                var section = $0
                if section.id == sectionId {
                    section.strokeWidth = section.chartMaxStrokeWidth
                } else {
                    section.strokeWidth = section.expectedStrokeWidth
                }
                return section
            }
        }
        
        if let sectionId, shouldCallFocusCompletionHandler {
            sectionIdTapped?(sectionId)
        }
    }
}
