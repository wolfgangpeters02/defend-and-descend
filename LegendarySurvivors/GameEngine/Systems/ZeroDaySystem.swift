import Foundation
import CoreGraphics

// MARK: - Zero-Day System
// System: Reboot - Emergency boss mechanic
// A Zero-Day virus spawns periodically that cannot be killed by Firewalls
// Player must enter Active/Debugger mode to defeat it
// While active, it rapidly drains system efficiency

struct ZeroDaySystem {

    // MARK: - Constants

    /// Minimum waves before Zero-Day can spawn (to let player set up)
    static let minWavesBeforeSpawn = 3

    /// Efficiency drain rate per second while Zero-Day is active
    static let efficiencyDrainRate: CGFloat = 2.0

    /// Bonus Hash for defeating Zero-Day
    static let defeatHashBonus = 525  // Combined reward

    /// Efficiency restored when Zero-Day is defeated
    static let defeatEfficiencyRestore = 30

    // MARK: - Update

    /// Update Zero-Day spawn timer and effects
    /// - Returns: true if state was modified
    static func update(state: inout TDGameState, deltaTime: TimeInterval) -> Bool {
        var modified = false

        // Don't spawn Zero-Day if game is paused or over
        guard !state.isPaused && !state.isGameOver else { return false }

        // Don't spawn if not enough waves completed
        guard state.wavesCompleted >= minWavesBeforeSpawn else { return false }

        // If Zero-Day is active, drain efficiency
        if state.zeroDayActive && state.isZeroDayAlive {
            // Drain efficiency over time
            let drain = efficiencyDrainRate * CGFloat(deltaTime)
            state.leakCounter += Int(drain) // Each point increases leak counter

            // Cap leak counter at 20 (100% efficiency loss)
            state.leakCounter = min(state.leakCounter, 20)

            modified = true
        } else if state.zeroDayActive && !state.isZeroDayAlive {
            // Zero-Day was defeated or escaped - reset
            state.zeroDayActive = false
            state.zeroDayBossId = nil
            state.zeroDayTimer = TimeInterval.random(
                in: TDGameState.zeroDayMinSpawnTime...TDGameState.zeroDayMaxSpawnTime
            )
            modified = true
        } else if !state.zeroDayActive {
            // Count down to next Zero-Day spawn
            state.zeroDayTimer -= deltaTime

            if state.zeroDayTimer <= 0 {
                // Spawn Zero-Day!
                spawnZeroDay(state: &state)
                modified = true
            }
        }

        return modified
    }

    // MARK: - Spawn Zero-Day

    /// Spawn a Zero-Day boss enemy
    static func spawnZeroDay(state: inout TDGameState) {
        // Pick a random path
        guard let path = state.paths.randomElement(), !path.waypoints.isEmpty else {
            return
        }

        let startPos = path.waypoints[0]

        // Create Zero-Day boss
        var zeroDayBoss = TDEnemy(
            id: "zero_day_\(RandomUtils.generateId())",
            type: "zero_day",
            x: startPos.x,
            y: startPos.y,
            pathIndex: 0,
            pathProgress: 0,
            health: 9999,           // Very high health (immune to towers anyway)
            maxHealth: 9999,
            speed: 30,              // Very slow - gives player time to react
            damage: 0,              // Doesn't do direct damage
            goldValue: 0,           // No coins (reward is from Active mode)
            xpValue: 0,
            size: 60,               // Large, menacing
            color: "#9933ff",       // Purple/violet for Zero-Day
            shape: "virus",
            isBoss: true
        )
        // Set Zero-Day specific flags
        zeroDayBoss.isZeroDay = true
        zeroDayBoss.immuneToTowers = true

        state.enemies.append(zeroDayBoss)
        state.zeroDayBossId = zeroDayBoss.id
        state.zeroDayActive = true
    }

    // MARK: - Defeat Zero-Day

    /// Called when player defeats Zero-Day in Active mode
    /// Returns bonus rewards to apply
    static func onZeroDayDefeated(state: inout TDGameState) -> ZeroDayReward {
        // Reset Zero-Day state
        state.zeroDayActive = false

        // Remove Zero-Day from enemies list
        if let bossId = state.zeroDayBossId {
            state.enemies.removeAll { $0.id == bossId }
        }
        state.zeroDayBossId = nil

        // Restore some efficiency (reduce leak counter)
        state.leakCounter = max(0, state.leakCounter - (defeatEfficiencyRestore / 5))

        // Set cooldown before next Zero-Day
        state.zeroDayTimer = state.zeroDayCooldown

        return ZeroDayReward(
            hashBonus: defeatHashBonus,
            efficiencyRestored: defeatEfficiencyRestore
        )
    }

    // MARK: - Check Tower Immunity

    /// Check if an enemy is immune to tower damage
    static func isImmuneToTowers(enemy: TDEnemy) -> Bool {
        return enemy.isZeroDay || enemy.immuneToTowers
    }
}

// MARK: - Zero-Day Reward

struct ZeroDayReward {
    let hashBonus: Int
    let efficiencyRestored: Int
}

// MARK: - TDEnemy Extension for Zero-Day

extension TDEnemy {
    /// Check if this enemy is a Zero-Day boss
    var isZeroDayBoss: Bool {
        return isZeroDay
    }
}
