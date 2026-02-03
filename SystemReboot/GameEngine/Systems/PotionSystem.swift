import Foundation
import CoreGraphics

// MARK: - Potion System

class PotionSystem {

    // Max charges for each potion type
    static let maxCharges: [String: CGFloat] = [
        "health": BalanceConfig.Potions.healthMaxCharge,
        "bomb": BalanceConfig.Potions.bombMaxCharge,
        "magnet": BalanceConfig.Potions.magnetMaxCharge,
        "shield": BalanceConfig.Potions.shieldMaxCharge
    ]

    /// Charge potions from collected coins
    static func chargePotions(state: inout GameState, coins: Int) {
        let chargeAmount = CGFloat(coins)

        // Health potion
        let healthNeeded = maxCharges["health"]! - state.potions.health
        let healthCharge = min(healthNeeded, chargeAmount * BalanceConfig.Potions.healthChargeMultiplier)
        state.potions.health += healthCharge

        // Bomb potion
        let bombNeeded = maxCharges["bomb"]! - state.potions.bomb
        let bombCharge = min(bombNeeded, chargeAmount * BalanceConfig.Potions.bombChargeMultiplier)
        state.potions.bomb += bombCharge

        // Magnet potion
        let magnetNeeded = maxCharges["magnet"]! - state.potions.magnet
        let magnetCharge = min(magnetNeeded, chargeAmount * BalanceConfig.Potions.magnetChargeMultiplier)
        state.potions.magnet += magnetCharge

        // Shield potion
        let shieldNeeded = maxCharges["shield"]! - state.potions.shield
        let shieldCharge = min(shieldNeeded, chargeAmount * BalanceConfig.Potions.shieldChargeMultiplier)
        state.potions.shield += shieldCharge
    }

    /// Check if a potion is fully charged
    static func isPotionCharged(_ type: String, state: GameState) -> Bool {
        guard let max = maxCharges[type] else { return false }

        switch type {
        case "health":
            return state.potions.health >= max
        case "bomb":
            return state.potions.bomb >= max
        case "magnet":
            return state.potions.magnet >= max
        case "shield":
            return state.potions.shield >= max
        default:
            return false
        }
    }

    /// Get potion charge percentage (0-1)
    static func getPotionProgress(_ type: String, state: GameState) -> CGFloat {
        guard let max = maxCharges[type] else { return 0 }

        switch type {
        case "health":
            return state.potions.health / max
        case "bomb":
            return state.potions.bomb / max
        case "magnet":
            return state.potions.magnet / max
        case "shield":
            return state.potions.shield / max
        default:
            return 0
        }
    }

    /// Use a potion
    static func usePotion(_ type: String, state: inout GameState) -> Bool {
        guard isPotionCharged(type, state: state) else { return false }

        switch type {
        case "health":
            return useHealthPotion(state: &state)
        case "bomb":
            return useBombPotion(state: &state)
        case "magnet":
            return useMagnetPotion(state: &state)
        case "shield":
            return useShieldPotion(state: &state)
        default:
            return false
        }
    }

    /// Health potion - restore percentage of max health
    private static func useHealthPotion(state: inout GameState) -> Bool {
        state.potions.health = 0

        let healAmount = state.player.maxHealth * BalanceConfig.Potions.healthRestorePercent
        state.player.health = min(state.player.maxHealth, state.player.health + healAmount)

        // Use state time instead of Date()
        let currentTime = state.startTime + state.timeElapsed

        // Healing particles
        for i in 0..<BalanceConfig.Particles.healParticleCount {
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let speed = CGFloat.random(in: BalanceConfig.Particles.healParticleSpeedMin...BalanceConfig.Particles.healParticleSpeedMax)

            state.particles.append(Particle(
                id: "\(RandomUtils.generateId())-heal-\(i)",
                type: "data",
                x: state.player.x,
                y: state.player.y,
                lifetime: BalanceConfig.Particles.phoenixParticleLifetime,
                createdAt: currentTime,
                color: "#00ff00",
                size: CGFloat.random(in: 4...8),
                velocity: CGPoint(x: cos(angle) * speed, y: sin(angle) * speed + BalanceConfig.Particles.healParticleVelocityOffset)
            ))
        }

        HapticsService.shared.play(.medium)
        return true
    }

    /// Bomb potion - kill all enemies on screen
    private static func useBombPotion(state: inout GameState) -> Bool {
        state.potions.bomb = 0

        // Kill all enemies
        for i in 0..<state.enemies.count {
            if !state.enemies[i].isDead && !state.enemies[i].isBoss {
                state.enemies[i].isDead = true
                state.stats.enemiesKilled += 1

                // Explosion at each enemy
                ParticleFactory.createExplosion(
                    state: &state,
                    x: state.enemies[i].x,
                    y: state.enemies[i].y,
                    color: "#ff6600",
                    count: BalanceConfig.Particles.bombParticleCountPerEnemy,
                    size: state.enemies[i].size ?? BalanceConfig.EnemyDefaults.collisionSize
                )

                // Drop Hash pickup
                PickupSystem.dropHash(
                    state: &state,
                    x: state.enemies[i].x,
                    y: state.enemies[i].y,
                    value: state.enemies[i].coinValue ?? BalanceConfig.EnemyDefaults.coinValue
                )
            }
        }

        // Screen flash
        VisualEffects.shared.triggerScreenFlash(color: .orange, opacity: 0.8, duration: BalanceConfig.Potions.bombFlashDuration)
        VisualEffects.shared.triggerScreenShake(intensity: BalanceConfig.Visual.screenShakeIntensity, duration: BalanceConfig.Visual.screenShakeDuration)
        HapticsService.shared.play(.heavy)

        return true
    }

    /// Magnet potion - collect all pickups instantly
    private static func useMagnetPotion(state: inout GameState) -> Bool {
        state.potions.magnet = 0

        // Use state time instead of Date()
        let currentTime = state.startTime + state.timeElapsed

        // Magnetize all pickups to player
        for i in 0..<state.pickups.count {
            state.pickups[i].magnetized = true

            // Visual trail to player
            state.particles.append(Particle(
                id: "\(RandomUtils.generateId())-magnet-\(i)",
                type: "data",
                x: state.pickups[i].x,
                y: state.pickups[i].y,
                lifetime: BalanceConfig.Particles.magnetParticleLifetime,
                createdAt: currentTime,
                color: "#ffff00",
                size: BalanceConfig.Particles.magnetParticleSize
            ))
        }

        // Expand pickup range temporarily (instant collection)
        let originalRange = state.player.pickupRange
        state.player.pickupRange = BalanceConfig.Potions.magnetPickupRange

        // Will reset on next frame via normal pickup logic
        DispatchQueue.main.asyncAfter(deadline: .now() + BalanceConfig.Potions.magnetDuration) {
            // This is a simplification - in practice you'd track this state
        }

        HapticsService.shared.play(.light)
        return true
    }

    /// Shield potion - temporary invulnerability
    private static func useShieldPotion(state: inout GameState) -> Bool {
        state.potions.shield = 0

        // Use currentFrameTime for consistent time base (context.timestamp)
        let frameTime = state.currentFrameTime
        let shieldDuration = BalanceConfig.Potions.shieldDuration
        state.player.invulnerable = true
        state.player.invulnerableUntil = frameTime + shieldDuration
        state.activePotionEffects.shieldUntil = frameTime + shieldDuration

        // Shield activation particles
        for i in 0..<BalanceConfig.Particles.shieldParticleCount {
            let angle = CGFloat(i) * (2 * .pi / CGFloat(BalanceConfig.Particles.shieldParticleCount))
            let radius = state.player.size * 2

            state.particles.append(Particle(
                id: "\(RandomUtils.generateId())-shield-\(i)",
                type: "legendary",
                x: state.player.x + cos(angle) * radius,
                y: state.player.y + sin(angle) * radius,
                lifetime: BalanceConfig.Particles.shieldActivationParticleLifetime,
                createdAt: frameTime,
                color: "#00ffff",
                size: BalanceConfig.Particles.shieldActivationParticleSize,
                velocity: CGPoint(x: cos(angle) * BalanceConfig.Particles.shieldActivationParticleSpeed, y: sin(angle) * BalanceConfig.Particles.shieldActivationParticleSpeed)
            ))
        }

        HapticsService.shared.play(.medium)
        return true
    }

    /// Update active potion effects
    static func updatePotionEffects(state: inout GameState, context: FrameContext? = nil) {
        // Use context timestamp if available, otherwise use state time
        let now = context?.timestamp ?? (state.startTime + state.timeElapsed)

        // Check shield expiration
        if let shieldUntil = state.activePotionEffects.shieldUntil {
            if now >= shieldUntil {
                state.activePotionEffects.shieldUntil = nil
                // Invulnerability is managed by PlayerSystem
            }
        }
    }
}
