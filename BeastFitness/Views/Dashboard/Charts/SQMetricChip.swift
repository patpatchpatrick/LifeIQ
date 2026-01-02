//
//  SQMetricChip.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 1/1/26.
//

import SwiftUI

struct SQMetricChip: View {
    struct Model: Identifiable, Hashable {
        let id: String
        let title: String
        let systemImage: String
        let value: Double?
        let maxValue: Double

        init(
            id: String,
            title: String,
            systemImage: String,
            value: Double?,
            maxValue: Double = 10,
        ) {
            self.id = id
            self.title = title
            self.systemImage = systemImage
            self.value = value
            self.maxValue = maxValue
        }
    }

    let model: Model
    var onTap: (() -> Void)? = nil

    // MARK: - Styling

    private var cornerRadius: CGFloat { 14 }
    private var height: CGFloat { 58 }
    private var horizPadding: CGFloat { 12 }
    private var vertPadding: CGFloat { 10 }

    private var progress: CGFloat {
        guard let value = model.value, model.maxValue > 0 else { return 0 }
        return CGFloat(min(max(value / model.maxValue, 0), 1))
    }

    private var valueText: String {
        guard let v = model.value else { return "—" }
        if abs(v.rounded() - v) < 0.0001 { return "\(Int(v))" }
        return String(format: "%.1f", v)
    }
    
    var trailingBarStack: some View {
        VStack(alignment: .trailing, spacing: 6) {
            GeometryReader { geo in
                let w = geo.size.width

                Capsule()
                    .fill(SQColor.textPrimary.color.opacity(0.10))
                    .frame(height: 6)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(SQColor.textPrimary.color.opacity(model.value == nil ? 0.12 : 0.40))
                            .frame(width: w * progress, height: 6)
                    }
            }
            .frame(height: 6)

            Text(model.value == nil ? "Check-in" : "Today")
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textSecondary)
                .lineLimit(1)
        }
        .frame(width: 64)
        .layoutPriority(0)
    }
    
    var titleAndScore: some View {
        VStack(alignment: .leading, spacing: .SQSpace.s) {
            Text(model.title)
                .sqFont(.bodySmallSemiBold)
                .lineLimit(1)
                .truncationMode(.tail)

            HStack(spacing: .SQSpace.s) {
                Text(valueText)
                    .sqFont(.bodyBold)
                    .sqForegroundColor(.textPrimary)
                    .lineLimit(1)

                Text("/\(Int(model.maxValue))")
                    .sqFont(.bodySemiBold)
                    .sqForegroundColor(.textSecondary)
                    .lineLimit(1)
            }
        }
        .layoutPriority(10)
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
    }

    var body: some View {
        Button { onTap?() } label: {
            HStack(spacing: .SQSpace.l) {

                Image(systemName: model.systemImage)
                    .font(.system(size: 15, weight: .semibold))
                .layoutPriority(0)

                titleAndScore

                trailingBarStack
            }
            .padding(.horizontal, horizPadding)
            .padding(.vertical, vertPadding)
            .frame(height: height)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(SQColor.textPrimary.color.opacity(0.1), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}


struct SQMetricChipStrip: View {
    let chips: [SQMetricChip.Model]
    var onTap: (SQMetricChip.Model) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(chips) { chip in
                    SQMetricChip(model: chip) {
                        onTap(chip)
                    }
                }
            }
            .padding(.horizontal, 2)
        }
    }
}
