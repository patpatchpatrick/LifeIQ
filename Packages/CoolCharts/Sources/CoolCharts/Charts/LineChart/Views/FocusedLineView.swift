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
                .foregroundStyle(model.focusConfig.focusColor.opacity(0.85))
            
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
    
    @State private var captionWidth: CGFloat = 0

    private var clampedX: CGFloat {
        let half = captionWidth / 2
        let chartWidth = model.lineChartModel.width
        return max(half, min(chartWidth - half, model.lineX))
    }

    var body: some View {
        captionStack
            .padding(.horizontal, .SQSpace.m)
            .padding(.vertical, .SQSpace.s)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: .SQSpace.l, style: .continuous)
                        .fill(model.lineChartModel.uiConfig.colorConfig.backgroundPrimary.opacity(0.96))

                    RoundedRectangle(cornerRadius: .SQSpace.l, style: .continuous)
                        .fill(.ultraThinMaterial.opacity(0.72))
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: .SQSpace.l, style: .continuous)
                    .stroke(Color.white.opacity(0.24), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.24), radius: 16, x: 0, y: 6)
            .background(
                GeometryReader { geo in
                    Color.clear.onAppear { captionWidth = geo.size.width }
                }
            )
            .position(x: clampedX, y: model.focusedCoordinate.y)
    }
}

struct FocusedLineCaptionItemView: View {
    let captionItem: FocusedLineViewModel.CaptionItem
    
    @ViewBuilder
    var titleStack: some View {
        HStack(alignment: .center, spacing: .SQSpace.s) {
            
            if let lineColor = captionItem.lineColor {
                Capsule(style: .continuous)
                    .foregroundStyle(lineColor)
                    .frame(width: 12, height: 4)
            }
            
            Text(captionItem.lineTitle)
                .font(captionItem.uiConfig.fontConfig.font)
                .foregroundStyle(captionItem.uiConfig.colorConfig.textSecondary)
                .shadow(color: Color.black.opacity(0.18), radius: 1.5, x: 0, y: 1)
        }
    }
    
    @ViewBuilder
    var valueStack: some View {
        HStack(spacing: .SQSpace.s) {
            
            Text(captionItem.yTitle)
                .font(captionItem.uiConfig.fontConfig.boldFont)
                .foregroundStyle(captionItem.uiConfig.colorConfig.textPrimary)
                .shadow(color: Color.black.opacity(0.22), radius: 1.5, x: 0, y: 1)
            
            Text(captionItem.xTitle)
                .font(captionItem.uiConfig.fontConfig.font)
                .foregroundStyle(captionItem.uiConfig.colorConfig.textSecondary)
                .shadow(color: Color.black.opacity(0.18), radius: 1.5, x: 0, y: 1)
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
