import SwiftUI

// MARK: - Welcome Back Modal
// Shows offline earnings when player returns to the game
// System: Reboot themed - terminal/tech aesthetic

struct WelcomeBackModal: View {
    let earnings: OfflineEarningsResult
    let onDismiss: () -> Void

    @State private var showContent = false
    @State private var showStats = false

    var body: some View {
        ZStack {
            // Dark overlay
            Color.black.opacity(0.9)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }

            // Modal content
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text("SYSTEM ONLINE")
                        .font(.system(size: 28, weight: .black, design: .monospaced))
                        .foregroundColor(.cyan)

                    Text("Welcome back, Guardian")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(.gray)
                }
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : -20)

                // Time away
                VStack(spacing: 4) {
                    Text("OFFLINE DURATION")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.gray)

                    Text(earnings.formattedTimeAway)
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)

                    if earnings.wasCapped {
                        Text("(capped at 8h)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.orange)
                    }
                }
                .opacity(showStats ? 1 : 0)

                // Earnings card
                VStack(spacing: 16) {
                    Text("IDLE EARNINGS")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)

                    HStack(spacing: 32) {
                        // Watts earned
                        VStack(spacing: 4) {
                            Image(systemName: "bolt.fill")
                                .font(.title2)
                                .foregroundColor(.cyan)

                            Text("+\(earnings.wattsEarned)")
                                .font(.system(size: 22, weight: .bold, design: .monospaced))
                                .foregroundColor(.cyan)

                            Text("WATTS")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundColor(.gray)
                        }

                        // Data earned (if any)
                        if earnings.dataEarned > 0 {
                            VStack(spacing: 4) {
                                Image(systemName: "memorychip")
                                    .font(.title2)
                                    .foregroundColor(.green)

                                Text("+\(earnings.dataEarned)")
                                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                                    .foregroundColor(.green)

                                Text("DATA")
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(hex: "0d1117") ?? Color.black)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                        )
                )
                .opacity(showStats ? 1 : 0)
                .scaleEffect(showStats ? 1 : 0.8)

                // Collect button
                Button(action: dismiss) {
                    Text("COLLECT")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(.black)
                        .frame(width: 200, height: 50)
                        .background(Color.cyan)
                        .cornerRadius(10)
                }
                .opacity(showStats ? 1 : 0)
            }
            .padding(32)
        }
        .onAppear {
            // Animate in sequence
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                showContent = true
            }

            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2)) {
                showStats = true
            }

            // Play sound effect
            HapticsService.shared.play(.success)
        }
    }

    private func dismiss() {
        HapticsService.shared.play(.selection)
        withAnimation(.easeOut(duration: 0.2)) {
            showContent = false
            showStats = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onDismiss()
        }
    }
}

// MARK: - Preview

#Preview {
    WelcomeBackModal(
        earnings: OfflineEarningsResult(
            wattsEarned: 1250,
            dataEarned: 3,
            timeAwaySeconds: 7200,
            cappedTimeSeconds: 7200,
            wasCapped: false
        ),
        onDismiss: {}
    )
}
