import SwiftUI

// MARK: - Content View
// System: Reboot starts directly on the Motherboard (no main menu)

struct ContentView: View {
    @StateObject private var appState = AppState.shared

    var body: some View {
        ZStack {
            // Main game hub - Board, Arsenal, Upgrades, Debug tabs
            // FTUE camera tutorial is handled inside MotherboardView
            SystemTabView(onExit: nil)

            // Welcome Back modal overlay (System: Reboot offline earnings)
            if appState.showWelcomeBack, let earnings = appState.pendingOfflineEarnings {
                WelcomeBackModal(
                    earnings: earnings,
                    onDismiss: {
                        appState.collectOfflineEarnings()
                    }
                )
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: appState.showWelcomeBack)
            }
        }
        .environmentObject(appState)
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
