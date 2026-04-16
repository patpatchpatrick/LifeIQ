//
//  SQLaunchSplashView.swift
//  BeastFitness
//

import SwiftUI

struct SQLaunchSplashView: View {
    @State private var hasEntered = false
    @State private var isHovering = false
    @State private var isGlowing = false

    var body: some View {
        ZStack {
            SQDashboardBackground()

            VStack(spacing: .SQSpace.xxl) {
                orbStack

                VStack(spacing: .SQSpace.s) {
                    Text("LifeIQ")
                        .sqFont(.title2)
                        .sqForegroundColor(.textPrimary)

                    Text("Recovery, workouts, and habits in one place.")
                        .sqFont(.bodyExtraSmall)
                        .sqForegroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .opacity(hasEntered ? 1 : 0)
                .offset(y: hasEntered ? 0 : 10)
                .animation(.easeOut(duration: 0.55).delay(0.18), value: hasEntered)
            }
            .padding(.horizontal, .SQSpace.xxl)
        }
        .ignoresSafeArea()
        .task {
            guard !hasEntered else { return }

            withAnimation(.spring(response: 0.95, dampingFraction: 0.82)) {
                hasEntered = true
            }

            isHovering = true
            isGlowing = true
        }
    }

    private var orbStack: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            SQColor.dashboardGlowBlue.color.opacity(isGlowing ? 0.38 : 0.24),
                            SQColor.dashboardGlowMint.color.opacity(isGlowing ? 0.20 : 0.10),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 18,
                        endRadius: 180
                    )
                )
                .frame(width: 290, height: 290)
                .scaleEffect(isGlowing ? 1.06 : 0.95)
                .blur(radius: isGlowing ? 10 : 18)
                .animation(
                    .easeInOut(duration: 2.6).repeatForever(autoreverses: true),
                    value: isGlowing
                )

            Image("Que")
                .resizable()
                .scaledToFit()
                .frame(width: 212, height: 212)
                .shadow(color: SQColor.dashboardGlowBlue.color.opacity(0.18), radius: 24, x: 0, y: 18)
                .shadow(color: Color.black.opacity(0.18), radius: 20, x: 0, y: 14)
                .scaleEffect(hasEntered ? 1 : 0.90)
                .opacity(hasEntered ? 1 : 0)
                .offset(y: isHovering ? -6 : 4)
                .animation(
                    .easeInOut(duration: 2.8).repeatForever(autoreverses: true),
                    value: isHovering
                )
        }
    }
}
