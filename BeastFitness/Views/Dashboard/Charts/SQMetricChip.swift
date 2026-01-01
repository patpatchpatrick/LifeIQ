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
        let value: Double?          // nil = no data yet
        let maxValue: Double        // e.g. 10
        let delta: Double?          // optional: vs baseline (e.g., 30-day avg)
        
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
        // tweak formatting as you like (0/1 decimals)
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
    
    private var deltaAccessibility: String? {
        guard let d = model.delta else { return nil }
        if d > 0 { return "\(deltaText ?? "") up" }
        if d < 0 { return "\(deltaText ?? "") down" }
        return "no change"
    }
    
    // MARK: - Body
    
    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack(spacing: 10) {
                
                // Icon bubble
                ZStack {
                    Circle()
                        .fill(.thinMaterial)
                    
                    Image(systemName: model.systemImage)
                        .font(.system(size: 15, weight: .semibold))
                }
                .frame(width: 28, height: 28)
                
                // Text
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.title)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    
                    HStack(spacing: 6) {
                        Text(valueText)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                        
                        Text("/\(Int(model.maxValue))")
                            .font(.system(size: 12, weight: .semibold))
                            .opacity(0.6)
                        
                        if let deltaText {
                            Text(deltaText)
                                .font(.system(size: 12, weight: .semibold))
                                .opacity(0.8)
                                .padding(.leading, 4)
                        }
                    }
                }
                
                Spacer(minLength: 8)
                
                // Mini bar (visual cue)
                VStack(alignment: .trailing, spacing: 6) {
                    Capsule()
                        .fill(.primary.opacity(0.10))
                        .frame(width: 54, height: 6)
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(.primary.opacity(model.value == nil ? 0.12 : 0.40))
                                .frame(width: 54 * progress, height: 6)
                        }
                    
                    // Tiny label for missing state
                    if model.value == nil {
                        Text("Check-in")
                            .font(.system(size: 10, weight: .semibold))
                            .opacity(0.55)
                    } else {
                        Text("Today")
                            .font(.system(size: 10, weight: .semibold))
                            .opacity(0.55)
                    }
                }
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(model.title), \(model.value == nil ? "no value" : valueText) out of \(Int(model.maxValue))")
        .accessibilityValue(deltaAccessibility ?? "")
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
                    .frame(width: 165) // tune for your layout
                }
            }
            .padding(.horizontal, 2)
        }
    }
}
