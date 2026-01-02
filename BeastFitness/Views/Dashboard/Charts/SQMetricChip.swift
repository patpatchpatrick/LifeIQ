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

        /// The raw numeric value to display
        let value: Double?

        /// For “score” chips (your current daily check-in)
        let maxValue: Double?

        /// For “measurement” chips (VO₂ max, HRV, RHR)
        let unitSuffix: String?
        let rangeMin: Double?
        let rangeMax: Double?

        /// Trailing caption (“Today”, “Latest”, “7d”, etc.)
        let trailingCaption: String

        init(
            id: String,
            title: String,
            systemImage: String,
            value: Double?,
            maxValue: Double = 10,
            trailingCaption: String = "Today"
        ) {
            self.id = id
            self.title = title
            self.systemImage = systemImage
            self.value = value
            self.maxValue = maxValue

            self.unitSuffix = nil
            self.rangeMin = nil
            self.rangeMax = nil
            self.trailingCaption = trailingCaption
        }

        /// Measurement-style init (VO₂ max)
        init(
            id: String,
            title: String,
            systemImage: String,
            value: Double?,
            unitSuffix: String,
            rangeMin: Double,
            rangeMax: Double,
            trailingCaption: String = "Latest"
        ) {
            self.id = id
            self.title = title
            self.systemImage = systemImage
            self.value = value

            self.maxValue = nil
            self.unitSuffix = unitSuffix
            self.rangeMin = rangeMin
            self.rangeMax = rangeMax
            self.trailingCaption = trailingCaption
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
        guard let v = model.value else { return 0 }

        // If measurement range exists, normalize within that range.
        if let rangeMin = model.rangeMin,
           let rangeMax = model.rangeMax,
           rangeMax > rangeMin
        {
            let clamped = Swift.min(Swift.max(v, rangeMin), rangeMax)
            return CGFloat((clamped - rangeMin) / (rangeMax - rangeMin))
        }

        // Fallback to “score/max” behavior
        if let maxValue = model.maxValue, maxValue > 0 {
            return CGFloat(Swift.min(Swift.max(v / maxValue, 0), 1))
        }

        return 0
    }


    private var valueText: String {
        guard let v = model.value else { return "—" }
        if abs(v.rounded() - v) < 0.0001 { return "\(Int(v))" }
        return String(format: "%.1f", v)
    }

    private var trailingText: String {
        model.trailingCaption
    }

    private var subtitleText: String {
        // For score chips: "/10"
        if let max = model.maxValue {
            return "/\(Int(max))"
        }
        // For measurement chips: "ml/kg/min"
        if let unit = model.unitSuffix {
            return unit
        }
        return ""
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

            Text(model.value == nil ? "—" : trailingText)
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

                if !subtitleText.isEmpty {
                    Text(subtitleText)
                        .sqFont(.bodySemiBold)
                        .sqForegroundColor(.textSecondary)
                        .lineLimit(1)
                }
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
