import Foundation
import CoreGraphics

// MARK: - Pickup System

class PickupSystem {

    /// Update all pickups - magnetize and collect
    static func update(state: inout GameState, context: FrameContext) {
        let player = state.player

        var indicesToRemove: [Int] = []

        for i in 0..<state.pickups.count {
            // Check lifetime
            if context.timestamp - state.pickups[i].createdAt > state.pickups[i].lifetime {
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
                state.pickups[i].x += (dx / dist) * speed * CGFloat(context.deltaTime)
                state.pickups[i].y += (dy / dist) * speed * CGFloat(context.deltaTime)

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

    /// Drop a Data pickup (◈)
    static func dropData(state: inout GameState, x: CGFloat, y: CGFloat, value: Int) {
        // Use state time instead of Date()
        let currentTime = state.startTime + state.timeElapsed

        state.pickups.append(Pickup(
            id: RandomUtils.generateId(),
            type: .data,
            x: x,
            y: y,
            value: value,
            lifetime: GameConstants.pickupLifetime,
            createdAt: currentTime,
            magnetized: false
        ))

        // Data sparkle effect (green)
        ParticleFactory.createDataSparkle(state: &state, x: x, y: y)
    }

    /// Collect a pickup
    private static func collectPickup(state: inout GameState, pickupIndex: Int) {
        let pickup = state.pickups[pickupIndex]

        switch pickup.type {
        case .data:
            state.sessionData += pickup.value
            state.stats.dataCollected += pickup.value
            state.stats.dataEarned += pickup.value

            // Charge potions with collected data
            chargePotions(state: &state, amount: pickup.value)

            // Collection particle - green for Data (use state time instead of Date())
            state.particles.append(Particle(
                id: RandomUtils.generateId(),
                type: .data,
                x: pickup.x,
                y: pickup.y,
                lifetime: 0.5,
                createdAt: state.startTime + state.timeElapsed,
                color: "#22c55e",  // Green for Data
                size: 12,
                velocity: CGPoint(x: 0, y: -50)
            ))

        case .health:
            state.player.health = min(state.player.maxHealth, state.player.health + CGFloat(pickup.value))

        case .xp, .powerup:
            break // Not implemented yet
        }
    }

    /// Charge potions based on collected Data
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
