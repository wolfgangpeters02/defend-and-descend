import SwiftUI
import SpriteKit
import Combine

// MARK: - System Tab View
// Main game hub - motherboard game with HUD, Arsenal accessible via SYS button

struct SystemTabView: View {
    @ObservedObject var appState = AppState.shared
    @StateObject private var embeddedGameController = EmbeddedTDGameController()  // Persists across view lifecycle
    @State private var showSystemMenu = false  // Arsenal/Settings sheet
    @State private var selectedBoss: BossEncounter?
    @State private var selectedDifficulty: BossDifficulty = .normal

    var onExit: (() -> Void)? = nil

    var body: some View {
        ZStack {
            // Background
            DesignColors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top navigation bar only shown if there's an exit button
                if onExit != nil {
                    topNavigationBar
                }

                // Main game board (no tab bar - system menu accessed via HUD)
                MotherboardView(
                    embeddedGameController: embeddedGameController,
                    showSystemMenu: $showSystemMenu
                )
            }
        }
        .fullScreenCover(item: $selectedBoss) { boss in
            BossGameView(
                boss: boss,
                difficulty: selectedDifficulty,
                protocol: appState.currentPlayer.equippedProtocol() ?? ProtocolLibrary.kernelPulse,
                onExit: {
                    selectedBoss = nil
                }
            )
        }
        .sheet(isPresented: $showSystemMenu) {
            SystemMenuSheet()
        }
    }

    // MARK: - Top Navigation Bar

    private var topNavigationBar: some View {
        HStack {
            // Exit button
            if let onExit = onExit {
                Button {
                    HapticsService.shared.play(.light)
                    onExit()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text(L10n.Common.menu)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                    }
                    .foregroundColor(DesignColors.muted)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(DesignColors.surface.opacity(0.8))
                    .cornerRadius(8)
                }
            }

            Spacer()

            // Title
            Text(L10n.System.title)
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .foregroundColor(DesignColors.primary)

            Spacer()

            // Placeholder for symmetry (same width as exit button)
            if onExit != nil {
                Color.clear
                    .frame(width: 80, height: 36)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(DesignColors.surface.opacity(0.5))
    }

}

// MARK: - Preview

#Preview {
    SystemTabView()
}
