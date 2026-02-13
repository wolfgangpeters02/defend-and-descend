import Foundation
import CoreGraphics

// MARK: - Freeze Recovery Service
// Extracted from SystemTabView + TDGameContainerView + TDGameScene (Phase 2.4)
// Centralizes System Freeze recovery logic: cost calculation, efficiency restoration,
// enemy cleanup, and state transitions.

struct FreezeRecoveryService {

    // MARK: - Flush Memory (Pay Hash to recover)

    /// Calculate the cost to flush memory (fraction of banked hash)
    static func flushCost(currentHash: Int) -> Int {
        let divisor = BalanceConfig.Freeze.recoveryHashDivisor
        return max(BalanceConfig.Freeze.minimumFlushCost, currentHash / divisor)
    }

    /// Check if player can afford to flush memory
    static func canAffordFlush(currentHash: Int) -> Bool {
        return currentHash >= flushCost(currentHash: currentHash)
    }

    // MARK: - State Recovery

    /// Recover game state from a system freeze
    /// Clears freeze flag, restores efficiency to target, and marks all enemies as dead
    /// - Parameters:
    ///   - state: The game state to mutate
    ///   - targetEfficiency: The efficiency percentage to restore to (default from BalanceConfig)
    /// - Returns: true if recovery was performed
    @discardableResult
    static func recoverFromFreeze(
        state: inout TDGameState,
        targetEfficiency: CGFloat = BalanceConfig.Freeze.recoveryTargetEfficiency
    ) -> Bool {
        guard state.isSystemFrozen else { return false }

        // Clear freeze state
        state.isSystemFrozen = false

        // Restore efficiency
        // efficiency = 100 - leakCounter * efficiencyLossPerLeak
        // leakCounter = (100 - targetEfficiency) / efficiencyLossPerLeak
        let leakCount = leakCountForEfficiency(targetEfficiency)
        state.leakCounter = leakCount

        // Clear all enemies that were on the field (system "rebooted")
        for i in 0..<state.enemies.count {
            state.enemies[i].isDead = true
        }

        return true
    }

    /// Restore efficiency by setting the leak counter directly
    static func restoreEfficiency(state: inout TDGameState, toLeakCount leakCount: Int) {
        state.leakCounter = max(0, leakCount)
    }

    // MARK: - Helpers

    /// Convert an efficiency percentage to the corresponding leak count
    static func leakCountForEfficiency(_ efficiency: CGFloat) -> Int {
        BalanceConfig.TDSession.leakCountForEfficiency(efficiency)
    }

    /// Convert a leak count to efficiency percentage
    static func efficiencyForLeakCount(_ leakCount: Int) -> CGFloat {
        BalanceConfig.TDSession.efficiencyForLeakCount(leakCount)
    }
}
