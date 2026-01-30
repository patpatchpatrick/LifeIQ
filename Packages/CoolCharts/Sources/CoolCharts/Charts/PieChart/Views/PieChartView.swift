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
    
    // MARK: - Init
    
    public init(model: PieChartModel) {
        self.model = model
    }
    
    // MARK: - Body
    
    public var body: some View {
        ZStack {
            ForEach(model.pieSections) { pieSection in
                PieChartSectionShape(model: pieSection)
                    .fill(pieSection.color)
                    .onTapGesture {
                        model.sectionFocused(sectionId: pieSection.id)
                    }
            }
            ForEach(model.pieSections) { pieSection in
                Text("Hi")
                    .shadow(radius: 1)
                    .position(x: pieSection.widthHeight / 2 + pieSection.x, y: pieSection.widthHeight / 2 - pieSection.y)
                    .font(pieSection.strokeWidth == pieSection.expectedStrokeWidth ? .body : .largeTitle)
            }
        }
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
