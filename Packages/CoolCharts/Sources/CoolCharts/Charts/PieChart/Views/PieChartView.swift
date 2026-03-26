//
//  PieChartView.swift
//  CoolCharts
//
//  Created by Patrick Doyle on 3/18/25.
//

import SwiftUI

public struct PieChartView: View {
    public enum VisualStyle {
        case standard
        case glass
    }
    
    // MARK: - Init Params
    @ObservedObject public var model: PieChartModel
    public let showsSectionLabels: Bool
    public let donutHoleDiameterPercent: CGFloat
    public let visualStyle: VisualStyle
    
    // MARK: - Init
    
    public init(
        model: PieChartModel,
        showsSectionLabels: Bool = false,
        donutHoleDiameterPercent: CGFloat = 0,
        visualStyle: VisualStyle = .standard
    ) {
        self.model = model
        self.showsSectionLabels = showsSectionLabels
        self.donutHoleDiameterPercent = max(0, min(0.95, donutHoleDiameterPercent))
        self.visualStyle = visualStyle
    }
    
    // MARK: - Body
    
    public var body: some View {
        ZStack {
            ForEach(model.pieSections) { pieSection in
                sectionBody(for: pieSection)
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

    @ViewBuilder
    private func sectionBody(for pieSection: PieChartSection) -> some View {
        if let radialFillPercent = pieSection.radialFillPercent {
            let trackShape = PieChartDonutBandSectorShape(model: pieSection, radialFillPercent: 1)
            let filledShape = PieChartDonutBandSectorShape(
                model: pieSection,
                radialFillPercent: CGFloat(max(0, min(1, radialFillPercent)))
            )

            switch visualStyle {
            case .standard:
                trackShape
                    .fill(pieSection.radialUnfilledColor ?? pieSection.color.opacity(0.2))

                filledShape
                    .fill(pieSection.color)
            case .glass:
                trackShape
                    .fill(pieSection.radialUnfilledColor ?? pieSection.color.opacity(0.2))
                    .overlay {
                        trackShape
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    }

                filledShape
                    .fill(pieSection.color.opacity(0.72))
                    .overlay {
                        filledShape
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.30),
                                        Color.white.opacity(0.02)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .overlay {
                        filledShape
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    }
            }
        } else {
            PieChartSectionShape(model: pieSection)
                .fill(pieSection.color)
        }
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
