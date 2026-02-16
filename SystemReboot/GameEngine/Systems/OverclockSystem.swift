import Foundation
import CoreGraphics

// MARK: - Overclock System
// Player can overclock the CPU for risk/reward gameplay:
// - Double hash generation for 60 seconds
// - Threat grows at 10x speed (triggers boss faster)
// - Increased power demand - may disable towers if insufficient power

struct OverclockSystem {

    // MARK: - Constants (from BalanceConfig)

    static var overclockDuration: TimeInterval { BalanceConfig.Overclock.duration }
    static var hashMultiplier: CGFloat { BalanceConfig.Overclock.hashMultiplier }
    static var threatMultiplier: CGFloat { BalanceConfig.Overclock.threatMultiplier }
    static var powerDemandMultiplier: CGFloat { BalanceConfig.Overclock.powerDemandMultiplier }

    // MARK: - Activate Overclock

    /// Attempt to activate overclock
    /// Returns true if activation succeeded
    static func activateOverclock(state: inout TDGameState) -> Bool {
        // Check if can overclock
        guard state.canOverclock else {
            return false
        }

        state.overclockActive = true
        state.overclockTimeRemaining = overclockDuration
        state.overclockThreatMultiplier = threatMultiplier
        state.overclockHashMultiplier = hashMultiplier
        state.overclockPowerDemandMultiplier = powerDemandMultiplier

        // Calculate power deficit and disable towers if needed
        updatePowerAllocation(state: &state)

        return true
    }

    // MARK: - Update

    /// Update overclock state each frame
    /// Returns true if overclock ended this frame
    static func update(state: inout TDGameState, deltaTime: TimeInterval) -> Bool {
        guard state.overclockActive else { return false }

        // Count down timer
        state.overclockTimeRemaining -= deltaTime

        // Check if overclock ended
        if state.overclockTimeRemaining <= 0 {
            deactivateOverclock(state: &state)
            return true
        }

        // Continuously update power allocation (in case towers are placed/sold)
        updatePowerAllocation(state: &state)

        return false
    }

    // MARK: - Deactivate Overclock

    /// Deactivate overclock and restore normal state
    private static func deactivateOverclock(state: inout TDGameState) {
        state.overclockActive = false
        state.overclockTimeRemaining = 0
        state.overclockThreatMultiplier = 1.0
        state.overclockHashMultiplier = 1.0
        state.overclockPowerDemandMultiplier = 1.0

        // Re-enable all disabled towers
        state.disabledTowerIds.removeAll()
    }

    // MARK: - Power Allocation

    /// Update which towers are disabled due to power shortage during overclock
    private static func updatePowerAllocation(state: inout TDGameState) {
        // Calculate power deficit
        let deficit = state.powerDeficit

        if deficit >= 0 {
            // No power shortage - ensure all towers enabled
            state.disabledTowerIds.removeAll()
            return
        }

        // Power shortage! Need to disable towers
        // Strategy: Disable lowest-tier (cheapest) towers first
        var towersToDisable: [(id: String, powerDraw: Int)] = []
        var currentDeficit = -deficit  // Make positive for comparison

        // Sort towers by power draw (disable cheapest first)
        let sortedTowers = state.towers.sorted { $0.effectivePowerDraw < $1.effectivePowerDraw }

        for tower in sortedTowers {
            if currentDeficit <= 0 { break }

            towersToDisable.append((id: tower.id, powerDraw: tower.effectivePowerDraw))
            currentDeficit -= tower.effectivePowerDraw
        }

        // Update disabled tower set
        state.disabledTowerIds = Set(towersToDisable.map { $0.id })
    }

    // MARK: - Helpers

    /// Check if a tower is currently disabled due to overclock power shortage
    static func isTowerDisabled(towerId: String, state: TDGameState) -> Bool {
        return state.disabledTowerIds.contains(towerId)
    }

    /// Get the effective threat growth rate (accounting for overclock)
    static func getEffectiveThreatGrowthRate(state: TDGameState) -> CGFloat {
        let baseRate = state.idleThreatGrowthRate
        return state.overclockActive ? baseRate * state.overclockThreatMultiplier : baseRate
    }

    /// Get the effective hash multiplier (accounting for overclock)
    static func getEffectiveHashMultiplier(state: TDGameState) -> CGFloat {
        return state.overclockActive ? state.overclockHashMultiplier : 1.0
    }
}
