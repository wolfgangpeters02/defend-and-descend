import Foundation

// MARK: - Boss State Management
// Extracted from EmbeddedTDGameController (Step 4.4)
// Consolidates boss lifecycle handling: spawn, reach CPU, engagement, and overclock tracking.

extension EmbeddedTDGameController {

    /// Sync boss-related state from an updated game state snapshot.
    /// Called from the onGameStateUpdated delegate callback.
    func syncBossState(from state: TDGameState) {
        // Track boss presence
        if state.bossActive && !state.bossEngaged {
            if !isBossActive {
                isBossActive = true
                activeBossType = state.activeBossType
            }
        } else if !state.bossActive {
            isBossActive = false
            activeBossType = nil
            bossAlertDismissed = false  // Reset for next boss
        }

        // Track overclock state
        overclockActive = state.overclockActive
        overclockTimeRemaining = state.overclockTimeRemaining
    }

    /// Handle a new boss spawning on the map.
    func handleBossSpawned(type: String) {
        isBossActive = true
        activeBossType = type
        bossAlertDismissed = false  // Reset so alert shows for new boss
        HapticsService.shared.play(.warning)
    }

    /// Handle the boss reaching the CPU (player ignored it).
    func handleBossReachedCPU() {
        isBossActive = false
        activeBossType = nil
        bossAlertDismissed = false  // Reset for next boss
        HapticsService.shared.play(.defeat)
    }

    /// Handle the player tapping on the boss to engage.
    func handleBossTapped() {
        bossAlertDismissed = false  // Reset in case alert was dismissed
        showBossDifficultySelector = true
    }
}
