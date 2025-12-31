//
//  ContentView.swift
//  Beast Fitness Watch Watch App
//
//  Created by Patrick Doyle on 12/18/25.
//

import SwiftUI
import HealthKit
import BeastFitnessCore

import SwiftUI

struct SWRootView: View {
    @State var viewModel: SWRootController

    init(appState: SWAppState) {
        _viewModel = .init(initialValue: .init(appState: appState))
    }
    
    var background: some View {
        LinearGradient(
            colors: [
                Color.black,
                Color.black.opacity(0.85),
                Color.black
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                background

                VStack(spacing: 8) {
                    activeExerciseCard
                        .frame(maxHeight: geo.size.height * 0.78)

                    bottomMetricsRow
                        .frame(maxHeight: geo.size.height * 0.22)
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
            }
        }
    }

    // MARK: - Active Exercise Card (center)

    private var activeExerciseCard: some View {
        VStack(spacing: 10) {
            // Replace these with your real fields if you have them.
            // If you don't yet, you can keep using rootState.activeWorkoutDescription as the subtext.
            Text("ACTIVE")
                .font(.system(.caption2, design: .rounded).weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill(Color.white.opacity(0.10))
                )
                .foregroundStyle(.white.opacity(0.85))

            // Active Exercise name (use a dedicated field if you have one)
            Text(viewModel.rootState.title)
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            // Current set line (use dedicated set fields if available)
            Text("Set • " + viewModel.rootState.activeWorkoutDescription)
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .lineLimit(2)

            // Little progress indicator vibe
            HStack(spacing: 6) {
                ForEach(0..<6, id: \.self) { i in
                    Capsule()
                        .fill(Color.white.opacity(i < 3 ? 0.55 : 0.15))
                        .frame(width: 16, height: 4)
                }
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.35), radius: 10, x: 0, y: 6)
        )
    }

    // MARK: - Bottom Metrics

    private var bottomMetricsRow: some View {
        HStack {
            LiveMetricCircle(
                icon: "heart.fill",
                title: viewModel.rootState.heartRateTitle,
                unit: "bpm",
                ringStyle: .heartbeat
            )

            Spacer()

            LiveMetricCircle(
                icon: "flame.fill",
                title: viewModel.rootState.activeCaloriesTitle,
                unit: "kCal",
                ringStyle: .pulse
            )
        }
        .padding(.bottom, 2)
    }
}

// MARK: - Live Metric Circle

private struct LiveMetricCircle: View {
    enum RingStyle {
        case heartbeat
        case pulse
    }

    let icon: String
    let title: String
    let unit: String
    let ringStyle: RingStyle

    @State private var animate = false

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                // Outer ring
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 6)

                // Animated ring
                Circle()
                    .trim(from: 0.0, to: animate ? 0.92 : 0.55)
                    .stroke(
                        Color.white.opacity(animate ? 0.55 : 0.25),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(animation, value: animate)

                // Inner glow / pulse
                Circle()
                    .fill(Color.white.opacity(animate ? 0.08 : 0.04))
                    .scaleEffect(animate ? 1.0 : 0.92)
                    .animation(animation, value: animate)

                VStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.white.opacity(0.9))
                        .scaleEffect(iconScale)
                        .animation(animation, value: animate)

                    Text(title)
                        .font(.system(.caption2, design: .rounded).weight(.semibold))
                        .foregroundStyle(.white.opacity(0.70))
                    
                    Text(unit)
                        .font(.system(.footnote, design: .rounded).weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .frame(width: 58, height: 58)
        }
        .onAppear { animate = true }
    }

    private var animation: Animation {
        switch ringStyle {
        case .heartbeat:
            // quick “double tap” feel
            return .easeInOut(duration: 0.42).repeatForever(autoreverses: true)
        case .pulse:
            // slower, steady pulse
            return .easeInOut(duration: 0.9).repeatForever(autoreverses: true)
        }
    }

    private var iconScale: CGFloat {
        switch ringStyle {
        case .heartbeat:
            return animate ? 1.12 : 0.96
        case .pulse:
            return animate ? 1.06 : 0.98
        }
    }
}

#Preview {
    SWRootView(appState: .shared)
}

final class WatchAppDelegate: NSObject, WKApplicationDelegate {
    
    // Ensure this exact signature is used
    func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
        
        SQLogger.shared.logW("Starting workout via Watch App Delegate", .debug, context: .watchInterface)
        
        Task { @MainActor in
            SWWorkoutManager.shared.startWorkout(with: workoutConfiguration)
        }
    }
}
