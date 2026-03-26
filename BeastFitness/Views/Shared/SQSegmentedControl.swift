//
//  SQSegmentedControl.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/25/25.
//

import SwiftUI


struct SQSegmentedControlSegment: Hashable, Identifiable {
    let id: String
    let title: String
    /// The numeric value to persist when this segment is selected.
    /// Use this when the segmented control represents a rating or scale — set the
    /// value explicitly on each segment so the persisted number stays correct even
    /// if segments are added, reordered, or the scale changes.
    /// Nil for segments that don't map to a persisted numeric value.
    let ratingValue: Float?

    init(id: String? = nil, title: String, ratingValue: Float? = nil) {
        self.id = id ?? title
        self.title = title
        self.ratingValue = ratingValue
    }
}

struct SQSegmentedControl<Label: View>: View  {
    let segments: [SQSegmentedControlSegment]
    @Binding var selection: SQSegmentedControlSegment?
    let label: (SQSegmentedControlSegment) -> Label

    var height: CGFloat = 38
    var width: CGFloat = 38
    var wrapsContent: Bool = false
    var activeColor: SQColor = .dashboardGlowBlue
    var inactiveColor: SQColor = .glassStroke
    var textColor: Color = SQColor.textPrimary.color
    var inactiveTextColor: Color = SQColor.textSecondary.color

    @ViewBuilder
    func mainLabel(_ segment: SQSegmentedControlSegment) -> some View {
        label(segment)
    }
    
    @ViewBuilder
    func sizeAdjustedLabel(_ segment: SQSegmentedControlSegment) -> some View {
        if wrapsContent {
            mainLabel(segment)
                .frame(height: height)
                .padding(.horizontal, .SQSpace.m)
        } else {
            mainLabel(segment)
                .frame(height: height)
                .frame(width: width)
        }
    }
    
    @ViewBuilder
    var mainControl: some View {
        HStack(spacing: .SQSpace.m) {
            ForEach(segments) { segment in
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                        if selection == segment {
                            selection = nil
                        } else {
                            selection = segment
                        }
                    }
                } label: {
                    sizeAdjustedLabel(segment)
                        .background(
                            RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                                .fill(
                                    selection == segment
                                        ? activeColor.color.opacity(SQColor.isDarkMode ? 0.18 : 0.12)
                                        : SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.76 : 0.96)
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                                .stroke(
                                    selection == segment
                                        ? activeColor.color.opacity(0.44)
                                        : inactiveColor.color,
                                    lineWidth: 1
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    var body: some View {
        ScrollView(.horizontal, content: { mainControl })
            .scrollIndicators(.hidden)
    }
}

struct SQSegmentedControl_Previews: PreviewProvider {
    struct PreviewContainer: View {
        let segments: [SQSegmentedControlSegment] = [
            .init(title: "1"),
            .init(title: "😦"),
            .init(title: "3")
        ]

        @State private var selected: SQSegmentedControlSegment? = .init(title: "1")

        var body: some View {
            SQSegmentedControl(
                segments: segments,
                selection: $selected
            ) { segment in
                Text(segment.title)
                    .font(.system(size: 14, weight: .semibold))
            }
            .padding()
        }
    }

    static var previews: some View {
        PreviewContainer()
            .previewLayout(.sizeThatFits)
            .preferredColorScheme(.dark)
            .padding()
    }
}
