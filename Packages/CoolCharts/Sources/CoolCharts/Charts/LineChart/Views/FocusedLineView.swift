//
//  FocusedLineView.swift
//  SportsPulse
//
//  Created by Patrick Doyle on 9/16/25.
//

import SwiftUI

struct FocusedLineView: View {
    let lineChartModel: LineChartModel
    let model: FocusedLineViewModel
    
    @ViewBuilder
    var mainStack: some View {
        ZStack {
            FocusedLineShape(model: model)
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [5]))
                .foregroundStyle(model.focusConfig.focusColor)
            
            FocusedLineCaptionView(model: model)
        }
    }
    
    var body: some View {
        mainStack
    }
}

struct FocusedLineCaptionView: View {
    let model: FocusedLineViewModel

    @ViewBuilder
    var captionStack: some View {
        VStack(spacing: .SQSpace.s) {
            ForEach(model.captionItems) {
                FocusedLineCaptionItemView(captionItem: $0)
            }
        }
    }
    
    var body: some View {
        captionStack
            .padding(.SQSpace.s)
            .background(model.lineChartModel.uiConfig.colorConfig.backgroundSecondary)
            .cornerRadius(.SQSpace.s)
            .position(x: model.lineX, y: model.focusedCoordinate.y)
    }
}

struct FocusedLineCaptionItemView: View {
    let captionItem: FocusedLineViewModel.CaptionItem
    
    @ViewBuilder
    var titleStack: some View {
        HStack(alignment: .center, spacing: .SQSpace.s) {
            
            if let lineColor = captionItem.lineColor {
                Rectangle()
                    .foregroundStyle(lineColor)
                    .frame(width: 4, height: 1)
            }
            
            Text(captionItem.lineTitle)
                .font(captionItem.uiConfig.fontConfig.font)
                .foregroundStyle(captionItem.uiConfig.colorConfig.textSecondary)
        }
    }
    
    @ViewBuilder
    var valueStack: some View {
        HStack(spacing: .SQSpace.s) {
            
            Text(captionItem.yTitle)
                .font(captionItem.uiConfig.fontConfig.boldFont)
                .foregroundStyle(captionItem.uiConfig.colorConfig.textPrimary)
            
            Text(captionItem.xTitle)
                .font(captionItem.uiConfig.fontConfig.font)
                .foregroundStyle(captionItem.uiConfig.colorConfig.textSecondary)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            
            titleStack
            
            valueStack
        }
    }
}

struct FocusedLineShape: Shape {
    let model: FocusedLineViewModel
    var focusedCoordinate: CGPoint { model.focusedCoordinate }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: model.lineX, y: model.lineStartY))
        path.addLine(to: CGPoint(x: model.lineX, y: model.lineEndY))
        return path
    }
}

extension CGFloat {
    struct SQSpace {
        /// Extra-small spacing — **4pt**
        static let s: CGFloat = 4
        
        /// Small spacing — **8pt**
        static let m: CGFloat = 8
        
        /// Medium spacing — **12pt**
        static let l: CGFloat = 12
        
        /// Large spacing — **16pt**
        static let xl: CGFloat = 16
        
        /// Extra-large spacing — **24pt**
        static let xxl: CGFloat = 24
    }
}
