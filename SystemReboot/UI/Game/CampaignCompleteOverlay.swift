import SwiftUI

// MARK: - Campaign Complete Overlay
// Shown once when the player defeats all 4 MVP sector bosses,
// completing the V1 campaign content.

struct CampaignCompleteOverlay: View {
    let onContinue: () -> Void

    @State private var showContent = false
    @State private var pulseContinue = false

    var body: some View {
        ZStack {
            // Dim background
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Icon
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 56))
                    .foregroundColor(DesignColors.success)

                // Title
                Text(L10n.CampaignComplete.title)
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundColor(DesignColors.primary)
                    .multilineTextAlignment(.center)

                // Body
                Text(L10n.CampaignComplete.body)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                // Coming soon tease
                Text(L10n.CampaignComplete.comingSoon)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(DesignColors.muted)
                    .multilineTextAlignment(.center)

                // Challenge encouragement
                Text(L10n.CampaignComplete.challenge)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(DesignColors.secondary)
                    .multilineTextAlignment(.center)

                // Continue button
                Button {
                    HapticsService.shared.play(.medium)
                    onContinue()
                } label: {
                    Text(L10n.CampaignComplete.continueButton)
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                        .foregroundColor(.black)
                        .padding(.horizontal, 48)
                        .padding(.vertical, 14)
                        .background(DesignColors.success)
                        .cornerRadius(12)
                        .scaleEffect(pulseContinue ? 1.05 : 1.0)
                }
                .padding(.top, 8)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(DesignColors.surface.opacity(0.95))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(DesignColors.primary.opacity(0.4), lineWidth: 2)
            )
            .padding(.horizontal, 24)
            .opacity(showContent ? 1 : 0)
            .scaleEffect(showContent ? 1 : 0.8)
        }
        .onAppear {
            HapticsService.shared.play(.success)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                showContent = true
            }
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true).delay(0.5)) {
                pulseContinue = true
            }
        }
    }
}
