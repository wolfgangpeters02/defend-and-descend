import SwiftUI

// MARK: - Welcome Back Modal
// Shows offline earnings when player returns to the game
// System: Reboot themed - terminal/tech aesthetic

struct WelcomeBackModal: View {
    let earnings: OfflineEarningsResult
    let onDismiss: () -> Void

    @State private var showContent = false
    @State private var showStats = false

    private var efficiencyColor: Color {
        switch earnings.newEfficiency {
        case 0.7...: return .green
        case 0.4..<0.7: return .yellow
        case 0.2..<0.4: return .orange
        default: return .red
        }
    }

    private var threatColor: Color {
        switch earnings.newThreatLevel {
        case 0..<2: return .green
        case 2..<5: return .yellow
        case 5..<10: return .orange
        default: return .red
        }
    }

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
                    Text(L10n.Welcome.header)
                        .font(.system(size: 28, weight: .black, design: .monospaced))
                        .foregroundColor(.cyan)

                    Text(L10n.Welcome.subtitle)
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(.gray)
                }
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : -20)

                // Time away
                VStack(spacing: 4) {
                    Text(L10n.Welcome.offlineDuration)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.gray)

                    Text(earnings.formattedTimeAway)
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)

                    if earnings.wasCapped {
                        Text(L10n.Welcome.cappedAt8h)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.orange)
                    }
                }
                .opacity(showStats ? 1 : 0)

                // Simulation report card
                VStack(spacing: 16) {
                    // Status row - show if there were issues
                    if earnings.leaksOccurred > 0 {
                        HStack(spacing: 16) {
                            // Leaks
                            VStack(spacing: 2) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                Text(L10n.Welcome.leaks(earnings.leaksOccurred))
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(.orange)
                            }

                            // Efficiency change
                            VStack(spacing: 2) {
                                Image(systemName: "gauge.with.dots.needle.33percent")
                                    .font(.caption)
                                    .foregroundColor(efficiencyColor)
                                Text(L10n.Welcome.efficiency(Int(earnings.newEfficiency * 100)))
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(efficiencyColor)
                            }

                            // Threat level
                            VStack(spacing: 2) {
                                Image(systemName: "bolt.fill")
                                    .font(.caption)
                                    .foregroundColor(threatColor)
                                Text(L10n.Welcome.threatLevel(String(format: "%.1f", earnings.newThreatLevel)))
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(threatColor)
                            }
                        }
                        .padding(.bottom, 8)
                    }

                    Text(L10n.Welcome.generatedPwr)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)

                    // Hash earned
                    VStack(spacing: 4) {
                        Image(systemName: "number.circle.fill")
                            .font(.title2)
                            .foregroundColor(.cyan)

                        Text("+Ħ\(earnings.hashEarned)")
                            .font(.system(size: 22, weight: .bold, design: .monospaced))
                            .foregroundColor(.cyan)

                        Text(L10n.Common.hash)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(.gray)

                        // Show if efficiency reduced earnings
                        if earnings.newEfficiency < earnings.startEfficiency {
                            Text(L10n.Welcome.reduced(Int((1 - earnings.newEfficiency / earnings.startEfficiency) * 100)))
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(.orange.opacity(0.8))
                        }
                    }

                    // Defense vs Offense explanation (only show if there were leaks)
                    if earnings.leaksOccurred > 0 {
                        Divider()
                            .background(Color.gray.opacity(0.3))
                            .padding(.vertical, 4)

                        VStack(spacing: 6) {
                            Text(L10n.Welcome.defenseReport)
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(.gray)

                            HStack(spacing: 16) {
                                VStack(spacing: 2) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "shield.fill")
                                            .font(.system(size: 10))
                                        Text("\(NumberFormatUtils.compact(Int(earnings.defenseStrength))) DPS")
                                    }
                                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                                        .foregroundColor(.green)
                                    Text(L10n.Welcome.yourTowers)
                                        .font(.system(size: 8, design: .monospaced))
                                        .foregroundColor(.gray)
                                }

                                Text(L10n.Welcome.vs)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.gray)

                                VStack(spacing: 2) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .font(.system(size: 10))
                                        Text("\(NumberFormatUtils.compact(Int(earnings.offenseStrength))) HP/s")
                                    }
                                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                                        .foregroundColor(.red)
                                    Text(L10n.Welcome.viruses)
                                        .font(.system(size: 8, design: .monospaced))
                                        .foregroundColor(.gray)
                                }
                            }

                            if earnings.defenseStrength < earnings.offenseStrength * 0.8 {
                                Text(L10n.Welcome.upgradeHint)
                                    .font(.system(size: 8, design: .monospaced))
                                    .foregroundColor(.orange.opacity(0.7))
                                    .multilineTextAlignment(.center)
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
                                .stroke(earnings.leaksOccurred > 0 ? Color.orange.opacity(0.3) : Color.cyan.opacity(0.3), lineWidth: 1)
                        )
                )
                .opacity(showStats ? 1 : 0)
                .scaleEffect(showStats ? 1 : 0.8)

                // Collect button
                Button(action: dismiss) {
                    Text(L10n.Common.collect)
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
            hashEarned: 1250,
            timeAwaySeconds: 7200,
            cappedTimeSeconds: 7200,
            wasCapped: false,
            leaksOccurred: 3,
            newThreatLevel: 4.5,
            newEfficiency: 0.65,
            startEfficiency: 1.0,
            defenseStrength: 45,    // Tower DPS
            offenseStrength: 120    // Enemy HP/sec
        ),
        onDismiss: {}
    )
}
