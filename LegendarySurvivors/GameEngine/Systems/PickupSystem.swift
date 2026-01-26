import Foundation
import CoreGraphics

// MARK: - Pickup System

class PickupSystem {

    /// Update all pickups - magnetize and collect
    static func update(state: inout GameState, deltaTime: TimeInterval) {
        let player = state.player
        let now = Date().timeIntervalSince1970

        var indicesToRemove: [Int] = []

        for i in 0..<state.pickups.count {
            // Check lifetime
            if now - state.pickups[i].createdAt > state.pickups[i].lifetime {
                indicesToRemove.append(i)
                continue
            }

            // Calculate distance to player
            let dx = player.x - state.pickups[i].x
            let dy = player.y - state.pickups[i].y
            let dist = sqrt(dx * dx + dy * dy)

            // Check if in pickup range
            if dist <= player.pickupRange {
                // Magnetize toward player
                state.pickups[i].magnetized = true
                let speed: CGFloat = GameConstants.coinMagnetSpeed
                state.pickups[i].x += (dx / dist) * speed * CGFloat(deltaTime)
                state.pickups[i].y += (dy / dist) * speed * CGFloat(deltaTime)

                // Collect if touching player
                if dist < player.size + 5 {
                    collectPickup(state: &state, pickupIndex: i)
                    indicesToRemove.append(i)
                }
            }
        }

        // Remove collected pickups (in reverse order)
        for index in indicesToRemove.sorted().reversed() {
            if index < state.pickups.count {
                state.pickups.remove(at: index)
            }
        }
    }

    /// Drop a coin pickup
    static func dropCoin(state: inout GameState, x: CGFloat, y: CGFloat, value: Int) {
        state.pickups.append(Pickup(
            id: RandomUtils.generateId(),
            type: "coin",
            x: x,
            y: y,
            value: value,
            lifetime: GameConstants.pickupLifetime,
            createdAt: Date().timeIntervalSince1970,
            magnetized: false
        ))

        // Coin sparkle effect
        ParticleFactory.createCoinSparkle(state: &state, x: x, y: y)
    }

    /// Collect a pickup
    private static func collectPickup(state: inout GameState, pickupIndex: Int) {
        let pickup = state.pickups[pickupIndex]

        if pickup.type == "coin" {
            state.coins += pickup.value
            state.stats.coinsCollected += pickup.value

            // Charge potions
            chargePotions(state: &state, amount: pickup.value)

            // Collection particle
            state.particles.append(Particle(
                id: RandomUtils.generateId(),
                type: "coin",
                x: pickup.x,
                y: pickup.y,
                lifetime: 0.5,
                createdAt: Date().timeIntervalSince1970,
                color: "#ffcc00",
                size: 12,
                velocity: CGPoint(x: 0, y: -50)
            ))
        }
    }

    /// Charge potions based on collected coins
    private static func chargePotions(state: inout GameState, amount: Int) {
        let chargeAmount = CGFloat(amount)

        // Health potion: 100 charge max
        state.potions.health = min(100, state.potions.health + chargeAmount * 2)

        // Bomb potion: 150 charge max
        state.potions.bomb = min(150, state.potions.bomb + chargeAmount)

        // Magnet potion: 75 charge max
        state.potions.magnet = min(75, state.potions.magnet + chargeAmount * 1.5)

        // Shield potion: 100 charge max
        state.potions.shield = min(100, state.potions.shield + chargeAmount * 1.2)
    }
}
