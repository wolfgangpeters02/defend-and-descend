import Foundation
import CoreGraphics

// MARK: - Core System
// Handles the Core — health, auto-attack, and defense

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
            health: BalanceConfig.TDCore.baseHealth,
            maxHealth: BalanceConfig.TDCore.baseHealth
        )

        // Apply player level bonuses
        let levelBonus: CGFloat = 1.0 + CGFloat(playerProfile.level - 1) * BalanceConfig.TDCore.levelBonusPercent
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
        let speed = BalanceConfig.TDCore.projectileSpeed

        let projectile = Projectile(
            id: RandomUtils.generateId(),
            weaponId: "core_attack",
            x: state.core.x,
            y: state.core.y,
            velocityX: cos(angle) * speed,
            velocityY: sin(angle) * speed,
            damage: state.core.damage,
            radius: BalanceConfig.TDCore.projectileRadius,
            color: "#ffd700",  // Gold color for Core auto-attack
            lifetime: BalanceConfig.TDCore.projectileLifetime,
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
        state.stats.hashSpent += cost

        switch stat {
        case .health:
            let bonus = BalanceConfig.TDCore.healthUpgradeBonus
            state.core.maxHealth += bonus
            state.core.health += bonus

        case .damage:
            state.core.damage *= BalanceConfig.TDCore.damageUpgradeMultiplier

        case .range:
            state.core.range += BalanceConfig.TDCore.rangeUpgradeBonus

        case .attackSpeed:
            state.core.attackSpeed *= BalanceConfig.TDCore.attackSpeedUpgradeMultiplier

        case .armor:
            state.core.armor = min(BalanceConfig.TDCore.maxArmor, state.core.armor + BalanceConfig.TDCore.armorUpgradeBonus)
        }

        return true
    }

    // MARK: - Core Visual

    /// Get core color based on health percentage
    static func getCoreColor(state: TDGameState) -> String {
        let healthPercent = state.core.health / state.core.maxHealth

        if healthPercent > BalanceConfig.TDCore.healthyThreshold {
            return "#00ff00"  // Green - healthy
        } else if healthPercent > BalanceConfig.TDCore.damagedThreshold {
            return "#ffff00"  // Yellow - damaged
        } else {
            return "#ff0000"  // Red - critical
        }
    }

    /// Get core pulse scale (for visual feedback)
    static func getCorePulseScale(state: TDGameState, currentTime: TimeInterval) -> CGFloat {
        // Pulse faster when low health
        let healthPercent = state.core.health / state.core.maxHealth
        let pulseSpeed = BalanceConfig.TDCore.minPulseSpeed + (1.0 - healthPercent) * BalanceConfig.TDCore.maxPulseSpeedVariation

        let pulse = sin(currentTime * pulseSpeed * .pi * 2)
        return 1.0 + pulse * BalanceConfig.TDCore.pulseIntensity * (1.0 - healthPercent)  // More visible at low health
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
        case .health: return "+\(Int(BalanceConfig.TDCore.healthUpgradeBonus)) Max Health"
        case .damage: return "+\(Int((BalanceConfig.TDCore.damageUpgradeMultiplier - 1.0) * 100))% Damage"
        case .range: return "+\(Int(BalanceConfig.TDCore.rangeUpgradeBonus)) Range"
        case .attackSpeed: return "+\(Int((BalanceConfig.TDCore.attackSpeedUpgradeMultiplier - 1.0) * 100))% Attack Speed"
        case .armor: return "+\(Int(BalanceConfig.TDCore.armorUpgradeBonus * 100))% Damage Reduction"
        }
    }

    var baseCost: Int {
        switch self {
        case .health: return BalanceConfig.TDCore.healthUpgradeCost
        case .damage: return BalanceConfig.TDCore.damageUpgradeCost
        case .range: return BalanceConfig.TDCore.rangeUpgradeCost
        case .attackSpeed: return BalanceConfig.TDCore.attackSpeedUpgradeCost
        case .armor: return BalanceConfig.TDCore.armorUpgradeCost
        }
    }
}
