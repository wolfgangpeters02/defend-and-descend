import Foundation
import CoreGraphics

// MARK: - Core System
// Handles the Core (Guardian in TD mode) - health, auto-attack, and defense

class CoreSystem {

    // MARK: - Core Management

    /// Initialize core for a TD game
    static func createCore(
        position: CGPoint,
        playerProfile: PlayerProfile
    ) -> TDCore {
        // Base core stats
        var core = TDCore(
            x: position.x,
            y: position.y,
            health: 100,
            maxHealth: 100
        )

        // Apply player level bonuses
        let levelBonus: CGFloat = 1.0 + CGFloat(playerProfile.level - 1) * 0.02  // +2% per level
        core.maxHealth *= levelBonus
        core.health = core.maxHealth

        return core
    }

    // MARK: - Core Auto-Attack

    /// Process core's automatic attack
    static func processCoreAttack(state: inout TDGameState, currentTime: TimeInterval) {
        guard state.core.canAttack else { return }

        // Check attack cooldown
        let attackInterval = 1.0 / state.core.attackSpeed
        guard currentTime - state.core.lastAttackTime >= attackInterval else { return }

        // Find target in range
        guard let target = findCoreTarget(state: state) else { return }

        // Create projectile
        let dx = target.x - state.core.x
        let dy = target.y - state.core.y
        let angle = atan2(dy, dx)
        let speed: CGFloat = 300

        let projectile = Projectile(
            id: RandomUtils.generateId(),
            weaponId: "core_attack",
            x: state.core.x,
            y: state.core.y,
            velocityX: cos(angle) * speed,
            velocityY: sin(angle) * speed,
            damage: state.core.damage,
            radius: 6,
            color: "#ffd700",  // Gold color for Guardian
            lifetime: 2.0,
            piercing: 0,
            hitEnemies: [],
            isHoming: false,
            homingStrength: 0,
            isEnemyProjectile: false,
            createdAt: currentTime
        )

        state.projectiles.append(projectile)
        state.core.lastAttackTime = currentTime
    }

    /// Find best target for core attack
    private static func findCoreTarget(state: TDGameState) -> TDEnemy? {
        let corePos = state.core.position
        var bestTarget: TDEnemy?
        var bestProgress: CGFloat = -1

        for enemy in state.enemies {
            if enemy.isDead || enemy.reachedCore { continue }

            let dx = enemy.x - corePos.x
            let dy = enemy.y - corePos.y
            let distance = sqrt(dx*dx + dy*dy)

            // Check if in range
            if distance <= state.core.range {
                // Prioritize enemies closest to core (highest progress)
                if enemy.pathProgress > bestProgress {
                    bestProgress = enemy.pathProgress
                    bestTarget = enemy
                }
            }
        }

        return bestTarget
    }

    // MARK: - Core Damage

    /// Apply damage to core
    static func damageCore(state: inout TDGameState, amount: CGFloat) {
        state.core.takeDamage(amount)

        // Check game over
        if state.core.isDead {
            state.isGameOver = true
        }
    }

    /// Heal core
    static func healCore(state: inout TDGameState, amount: CGFloat) {
        state.core.health = min(state.core.maxHealth, state.core.health + amount)
    }

    // MARK: - Core Upgrades

    /// Upgrade core stat
    static func upgradeCoreStat(state: inout TDGameState, stat: CoreUpgrade, cost: Int) -> Bool {
        guard state.hash >= cost else { return false }

        state.hash -= cost
        state.stats.goldSpent += cost

        switch stat {
        case .health:
            let bonus: CGFloat = 20
            state.core.maxHealth += bonus
            state.core.health += bonus

        case .damage:
            state.core.damage *= 1.15  // +15%

        case .range:
            state.core.range += 20

        case .attackSpeed:
            state.core.attackSpeed *= 1.1  // +10%

        case .armor:
            state.core.armor = min(0.5, state.core.armor + 0.05)  // +5%, max 50%
        }

        return true
    }

    // MARK: - Core Visual

    /// Get core color based on health percentage
    static func getCoreColor(state: TDGameState) -> String {
        let healthPercent = state.core.health / state.core.maxHealth

        if healthPercent > 0.6 {
            return "#00ff00"  // Green - healthy
        } else if healthPercent > 0.3 {
            return "#ffff00"  // Yellow - damaged
        } else {
            return "#ff0000"  // Red - critical
        }
    }

    /// Get core pulse scale (for visual feedback)
    static func getCorePulseScale(state: TDGameState, currentTime: TimeInterval) -> CGFloat {
        // Pulse faster when low health
        let healthPercent = state.core.health / state.core.maxHealth
        let pulseSpeed = 2.0 + (1.0 - healthPercent) * 3.0  // 2-5 pulses per second

        let pulse = sin(currentTime * pulseSpeed * .pi * 2)
        return 1.0 + pulse * 0.05 * (1.0 - healthPercent)  // More visible at low health
    }
}

// MARK: - Core Upgrade Types

enum CoreUpgrade: String, CaseIterable {
    case health
    case damage
    case range
    case attackSpeed
    case armor

    var displayName: String {
        switch self {
        case .health: return "Health"
        case .damage: return "Damage"
        case .range: return "Range"
        case .attackSpeed: return "Attack Speed"
        case .armor: return "Armor"
        }
    }

    var description: String {
        switch self {
        case .health: return "+20 Max Health"
        case .damage: return "+15% Damage"
        case .range: return "+20 Range"
        case .attackSpeed: return "+10% Attack Speed"
        case .armor: return "+5% Damage Reduction"
        }
    }

    var baseCost: Int {
        switch self {
        case .health: return 50
        case .damage: return 75
        case .range: return 60
        case .attackSpeed: return 100
        case .armor: return 80
        }
    }
}
