import Foundation
import CoreGraphics

// MARK: - Pickup System

class PickupSystem {

    /// Maximum pickups on screen before oldest are auto-collected
    private static let maxPickups = BalanceConfig.Pickups.maxPickupsOnScreen

    /// Update all pickups - magnetize and collect
    static func update(state: inout GameState, context: FrameContext) {
        let player = state.player
        let collectDist = player.size + 5

        // Auto-collect oldest pickups when over cap
        while state.pickups.count > maxPickups {
            collectPickup(state: &state, pickupIndex: 0)
            state.pickups.removeFirst()
        }

        // Track which pickups to keep
        var writeIndex = 0

        for i in 0..<state.pickups.count {
            // Check lifetime
            if context.timestamp - state.pickups[i].createdAt > state.pickups[i].lifetime {
                continue
            }

            // Calculate distance to player
            let dx = player.x - state.pickups[i].x
            let dy = player.y - state.pickups[i].y
            let dist = sqrt(dx * dx + dy * dy)

            // Collect if touching player
            if dist < collectDist {
                collectPickup(state: &state, pickupIndex: i)
                continue
            }

            // Magnetize toward player if in range
            if dist <= player.pickupRange {
                state.pickups[i].magnetized = true
                let speed: CGFloat = BalanceConfig.Player.pickupMagnetSpeed
                state.pickups[i].x += (dx / dist) * speed * CGFloat(context.deltaTime)
                state.pickups[i].y += (dy / dist) * speed * CGFloat(context.deltaTime)
            }

            // Keep this pickup - compact in-place
            state.pickups[writeIndex] = state.pickups[i]
            writeIndex += 1
        }

        // Trim removed entries
        state.pickups.removeSubrange(writeIndex..<state.pickups.count)
    }

    /// Drop a Hash pickup (Ħ)
    static func dropHash(state: inout GameState, x: CGFloat, y: CGFloat, value: Int) {
        // Use state time instead of Date()
        let currentTime = state.startTime + state.timeElapsed

        state.pickups.append(Pickup(
            id: RandomUtils.generateId(),
            type: .hash,
            x: x,
            y: y,
            value: value,
            lifetime: BalanceConfig.Pickups.lifetime,
            createdAt: currentTime,
            magnetized: false
        ))
    }

    /// Collect a pickup
    private static func collectPickup(state: inout GameState, pickupIndex: Int) {
        let pickup = state.pickups[pickupIndex]

        switch pickup.type {
        case .hash:
            state.sessionHash += pickup.value
            state.stats.hashCollected += pickup.value
            state.stats.hashEarned += pickup.value

            // Collection particle - cyan for Hash (use state time instead of Date())
            state.particles.append(Particle(
                id: RandomUtils.generateId(),
                type: .hash,
                x: pickup.x,
                y: pickup.y,
                lifetime: BalanceConfig.Particles.collectionParticleLifetime,
                createdAt: state.startTime + state.timeElapsed,
                color: "#06b6d4",  // Cyan for Hash
                size: BalanceConfig.Particles.collectionParticleSize,
                velocity: CGPoint(x: 0, y: BalanceConfig.Particles.collectionParticleVelocity)
            ))

        case .health:
            state.player.health = min(state.player.maxHealth, state.player.health + CGFloat(pickup.value))

        case .xp:
            break // Not implemented yet
        }
    }

}
