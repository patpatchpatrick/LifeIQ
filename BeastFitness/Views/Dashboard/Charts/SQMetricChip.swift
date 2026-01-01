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
        let delta: Double?

        init(
            id: String,
            title: String,
            systemImage: String,
            value: Double?,
            maxValue: Double = 10,
            delta: Double? = nil
        ) {
            self.id = id
            self.title = title
            self.systemImage = systemImage
            self.value = value
            self.maxValue = maxValue
            self.delta = delta
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

    private var deltaText: String? {
        guard let d = model.delta else { return nil }
        let sign = d > 0 ? "+" : (d < 0 ? "−" : "")
        let absVal = abs(d)
        let formatted: String = abs(absVal.rounded() - absVal) < 0.0001
            ? "\(Int(absVal))"
            : String(format: "%.1f", absVal)
        return "\(sign)\(formatted)"
    }

    var body: some View {
        Button { onTap?() } label: {
            HStack(spacing: 10) {

                // Icon bubble (fixed)
                ZStack {
                    Circle().fill(.thinMaterial)
                    Image(systemName: model.systemImage)
                        .font(.system(size: 15, weight: .semibold))
                }
                .frame(width: 28, height: 28)
                .layoutPriority(0)

                // Text (HIGH PRIORITY)
                VStack(alignment: .leading, spacing: 3) {
                    Text(model.title)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)

                    HStack(spacing: 5) {
                        Text(valueText)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .lineLimit(1)

                        Text("/\(Int(model.maxValue))")
                            .font(.system(size: 12, weight: .semibold))
                            .opacity(0.6)
                            .lineLimit(1)

                        if let deltaText {
                            Text(deltaText)
                                .font(.system(size: 12, weight: .semibold))
                                .opacity(0.8)
                                .lineLimit(1)
                                .padding(.leading, 2)
                        }
                    }
                }
                .layoutPriority(10) // <- makes this win
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

                // Trailing mini-bar (predictable, shrinkable)
                VStack(alignment: .trailing, spacing: 6) {
                    GeometryReader { geo in
                        let w = geo.size.width

                        Capsule()
                            .fill(.primary.opacity(0.10))
                            .frame(height: 6)
                            .overlay(alignment: .leading) {
                                Capsule()
                                    .fill(.primary.opacity(model.value == nil ? 0.12 : 0.40))
                                    .frame(width: w * progress, height: 6)
                            }
                    }
                    .frame(height: 6)

                    Text(model.value == nil ? "Check-in" : "Today")
                        .font(.system(size: 10, weight: .semibold))
                        .opacity(0.55)
                        .lineLimit(1)
                }
                .frame(width: 64)          // <- fixed width so it won't steal space
                .layoutPriority(0)
            }
            .padding(.horizontal, horizPadding)
            .padding(.vertical, vertPadding)
            .frame(height: height)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.thinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.primary.opacity(0.10), lineWidth: 1)
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
                    .frame(width: 185) // tune for your layout
                }
            }
            .padding(.horizontal, 2)
        }
    }
}
