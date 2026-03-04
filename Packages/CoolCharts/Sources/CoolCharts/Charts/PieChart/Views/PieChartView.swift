//
//  PieChartView.swift
//  CoolCharts
//
//  Created by Patrick Doyle on 3/18/25.
//

import SwiftUI

public struct PieChartView: View {
    
    // MARK: - Init Params
    @ObservedObject public var model: PieChartModel
    public let showsSectionLabels: Bool
    public let donutHoleDiameterPercent: CGFloat
    
    // MARK: - Init
    
    public init(
        model: PieChartModel,
        showsSectionLabels: Bool = false,
        donutHoleDiameterPercent: CGFloat = 0
    ) {
        self.model = model
        self.showsSectionLabels = showsSectionLabels
        self.donutHoleDiameterPercent = max(0, min(0.95, donutHoleDiameterPercent))
    }
    
    // MARK: - Body
    
    public var body: some View {
        ZStack {
            ForEach(model.pieSections) { pieSection in
                Group {
                    if let radialFillPercent = pieSection.radialFillPercent {
                        PieChartDonutBandSectorShape(model: pieSection, radialFillPercent: 1)
                            .fill(pieSection.radialUnfilledColor ?? pieSection.color.opacity(0.2))

                        PieChartDonutBandSectorShape(
                            model: pieSection,
                            radialFillPercent: CGFloat(max(0, min(1, radialFillPercent)))
                        )
                        .fill(pieSection.color)
                    } else {
                        PieChartSectionShape(model: pieSection)
                            .fill(pieSection.color)
                    }
                }
                    .onTapGesture {
                        model.sectionFocused(sectionId: pieSection.id)
                    }
            }
            if showsSectionLabels {
                EmptyView()
            }

            let hasRadialSections = model.pieSections.contains(where: { $0.radialFillPercent != nil })
            if donutHoleDiameterPercent > 0 && !hasRadialSections {
                Circle()
                    .fill(Color.black)
                    .frame(
                        width: model.widthHeight * donutHoleDiameterPercent,
                        height: model.widthHeight * donutHoleDiameterPercent
                    )
                    .blendMode(.destinationOut)
            }
        }
        .compositingGroup()
        .drawingGroup()
        .frame(height: model.widthHeight)
    }
}

#Preview {
    PieChartView(
        model: .init(
            sections: [
                .init(id: UUID().uuidString, magnitude: 2, color: .green)
            ],
            sectionAlignment: .center)!)
}
