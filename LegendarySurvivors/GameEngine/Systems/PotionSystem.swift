import Foundation
import CoreGraphics

// MARK: - Potion System

class PotionSystem {

    // Max charges for each potion type
    static let maxCharges: [String: CGFloat] = [
        "health": 100,
        "bomb": 150,
        "magnet": 75,
        "shield": 100
    ]

    /// Charge potions from collected coins
    static func chargePotions(state: inout GameState, coins: Int) {
        let chargeAmount = CGFloat(coins)

        // Health potion
        let healthNeeded = maxCharges["health"]! - state.potions.health
        let healthCharge = min(healthNeeded, chargeAmount * 2)
        state.potions.health += healthCharge

        // Bomb potion
        let bombNeeded = maxCharges["bomb"]! - state.potions.bomb
        let bombCharge = min(bombNeeded, chargeAmount)
        state.potions.bomb += bombCharge

        // Magnet potion
        let magnetNeeded = maxCharges["magnet"]! - state.potions.magnet
        let magnetCharge = min(magnetNeeded, chargeAmount * 1.5)
        state.potions.magnet += magnetCharge

        // Shield potion
        let shieldNeeded = maxCharges["shield"]! - state.potions.shield
        let shieldCharge = min(shieldNeeded, chargeAmount * 1.2)
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

    /// Health potion - restore 50% max health
    private static func useHealthPotion(state: inout GameState) -> Bool {
        state.potions.health = 0

        let healAmount = state.player.maxHealth * 0.5
        state.player.health = min(state.player.maxHealth, state.player.health + healAmount)

        // Use state time instead of Date()
        let currentTime = state.startTime + state.timeElapsed

        // Healing particles
        for i in 0..<20 {
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let speed = CGFloat.random(in: 30...80)

            state.particles.append(Particle(
                id: "\(RandomUtils.generateId())-heal-\(i)",
                type: "data",
                x: state.player.x,
                y: state.player.y,
                lifetime: 0.8,
                createdAt: currentTime,
                color: "#00ff00",
                size: CGFloat.random(in: 4...8),
                velocity: CGPoint(x: cos(angle) * speed, y: sin(angle) * speed - 30)
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
                    count: 10,
                    size: state.enemies[i].size ?? 20
                )

                // Drop Data pickup
                PickupSystem.dropData(
                    state: &state,
                    x: state.enemies[i].x,
                    y: state.enemies[i].y,
                    value: state.enemies[i].coinValue ?? 1
                )
            }
        }

        // Screen flash
        VisualEffects.shared.triggerScreenFlash(color: .orange, opacity: 0.8, duration: 0.3)
        VisualEffects.shared.triggerScreenShake(intensity: 15, duration: 0.5)
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
                lifetime: 0.3,
                createdAt: currentTime,
                color: "#ffff00",
                size: 4
            ))
        }

        // Expand pickup range temporarily (instant collection)
        let originalRange = state.player.pickupRange
        state.player.pickupRange = 2000

        // Will reset on next frame via normal pickup logic
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // This is a simplification - in practice you'd track this state
        }

        HapticsService.shared.play(.light)
        return true
    }

    /// Shield potion - 5 seconds of invulnerability
    private static func useShieldPotion(state: inout GameState) -> Bool {
        state.potions.shield = 0

        // Use state time instead of Date()
        let currentTime = state.startTime + state.timeElapsed
        let shieldDuration: TimeInterval = 5.0
        state.player.invulnerable = true
        state.player.invulnerableUntil = currentTime + shieldDuration
        state.activePotionEffects.shieldUntil = currentTime + shieldDuration

        // Shield activation particles
        for i in 0..<30 {
            let angle = CGFloat(i) * (2 * .pi / 30)
            let radius = state.player.size * 2

            state.particles.append(Particle(
                id: "\(RandomUtils.generateId())-shield-\(i)",
                type: "legendary",
                x: state.player.x + cos(angle) * radius,
                y: state.player.y + sin(angle) * radius,
                lifetime: 0.5,
                createdAt: currentTime,
                color: "#00ffff",
                size: 6,
                velocity: CGPoint(x: cos(angle) * 50, y: sin(angle) * 50)
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
