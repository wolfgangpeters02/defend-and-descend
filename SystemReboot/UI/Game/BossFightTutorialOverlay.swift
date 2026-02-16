import SwiftUI

// MARK: - Boss Fight Tutorial Overlay
// Shown when the boss fight scene opens for the first time.
// Game starts paused; player taps START to begin.

struct BossFightTutorialOverlay: View {
    let onStart: () -> Void

    @State private var showContent = false
    @State private var pulseStart = false

    var body: some View {
        ZStack {
            // Dim background
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: 28) {
                // Joystick icon
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 56))
                    .foregroundColor(DesignColors.primary)

                // Instructions
                VStack(spacing: 12) {
                    Text(L10n.BossTutorial.moveToDodge)
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    Text(L10n.BossTutorial.autoFireActive)
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(DesignColors.muted)
                        .multilineTextAlignment(.center)
                }

                // START button
                Button {
                    HapticsService.shared.play(.medium)
                    onStart()
                } label: {
                    Text(L10n.BossTutorial.startFight)
                        .font(.system(size: 22, weight: .black, design: .monospaced))
                        .foregroundColor(.black)
                        .padding(.horizontal, 48)
                        .padding(.vertical, 16)
                        .background(DesignColors.success)
                        .cornerRadius(12)
                        .scaleEffect(pulseStart ? 1.05 : 1.0)
                }
            }
            .padding(32)
            .opacity(showContent ? 1 : 0)
            .scaleEffect(showContent ? 1 : 0.8)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                showContent = true
            }
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true).delay(0.5)) {
                pulseStart = true
            }
        }
    }
}
