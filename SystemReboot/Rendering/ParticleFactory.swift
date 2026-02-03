import Foundation
import CoreGraphics

// MARK: - Particle Factory

class ParticleFactory {

    /// Maximum particles allowed (prevents lag from particle accumulation)
    private static let maxParticles = 300

    /// Get current timestamp from game state (avoids Date() calls)
    private static func timestamp(from state: GameState) -> TimeInterval {
        return state.startTime + state.timeElapsed
    }

    /// Check if we can add more particles (enforces cap)
    private static func canAddParticles(state: GameState, count: Int = 1) -> Bool {
        return state.particles.count + count < maxParticles
    }

    /// Trim excess particles if over limit (removes oldest)
    private static func enforceParticleLimit(state: inout GameState) {
        if state.particles.count > maxParticles {
            // Use suffix instead of removeFirst to avoid O(n) array shift
            state.particles = Array(state.particles.suffix(maxParticles))
        }
    }

    /// Create explosion particles
    static func createExplosion(
        state: inout GameState,
        x: CGFloat,
        y: CGFloat,
        color: String,
        count: Int,
        size: CGFloat
    ) {
        // Limit particle count based on current particle count
        let availableSlots = max(0, maxParticles - state.particles.count)
        let actualCount = min(count, availableSlots)
        guard actualCount > 0 else { return }

        let now = timestamp(from: state)

        for i in 0..<actualCount {
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let speed = CGFloat.random(in: 50...150)
            let particleSize = CGFloat.random(in: size * 0.3...size)

            state.particles.append(Particle(
                id: "\(RandomUtils.generateId())-explosion-\(i)",
                type: .explosion,
                x: x,
                y: y,
                lifetime: Double.random(in: 0.3...0.8),
                createdAt: now,
                color: color,
                size: particleSize,
                velocity: CGPoint(x: cos(angle) * speed, y: sin(angle) * speed),
                rotation: CGFloat.random(in: 0...(2 * .pi)),
                rotationSpeed: CGFloat.random(in: -5...5),
                drag: 0.02,
                shape: [.circle, .spark, .square].randomElement()
            ))
        }
    }

    /// Create blood splatter particles
    static func createBloodParticles(
        state: inout GameState,
        x: CGFloat,
        y: CGFloat,
        count: Int
    ) {
        let now = timestamp(from: state)

        for i in 0..<count {
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let speed = CGFloat.random(in: 30...100)

            state.particles.append(Particle(
                id: "\(RandomUtils.generateId())-blood-\(i)",
                type: .blood,
                x: x,
                y: y,
                lifetime: Double.random(in: 0.2...0.5),
                createdAt: now,
                color: "#8b0000",
                size: CGFloat.random(in: 2...5),
                velocity: CGPoint(x: cos(angle) * speed, y: sin(angle) * speed),
                drag: 0.05
            ))
        }
    }

    /// Create Hash sparkle effect (cyan)
    static func createHashSparkle(
        state: inout GameState,
        x: CGFloat,
        y: CGFloat
    ) {
        let now = timestamp(from: state)

        for i in 0..<5 {
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let speed = CGFloat.random(in: 20...60)

            state.particles.append(Particle(
                id: "\(RandomUtils.generateId())-sparkle-\(i)",
                type: .hash,
                x: x,
                y: y,
                lifetime: 0.4,
                createdAt: now,
                color: "#06b6d4",  // Cyan for Hash
                size: CGFloat.random(in: 2...4),
                velocity: CGPoint(x: cos(angle) * speed, y: sin(angle) * speed),
                shape: .star
            ))
        }
    }

    /// Create muzzle flash effect
    static func createMuzzleFlash(
        state: inout GameState,
        x: CGFloat,
        y: CGFloat,
        angle: CGFloat,
        weaponType: String
    ) {
        let now = timestamp(from: state)
        let color = getWeaponColor(weaponType)

        for i in 0..<3 {
            let spread = CGFloat.random(in: -0.3...0.3)
            let speed = CGFloat.random(in: 100...200)

            state.particles.append(Particle(
                id: "\(RandomUtils.generateId())-muzzle-\(i)",
                type: .muzzle,
                x: x + cos(angle) * 15,
                y: y + sin(angle) * 15,
                lifetime: 0.15,
                createdAt: now,
                color: color,
                size: CGFloat.random(in: 3...6),
                velocity: CGPoint(
                    x: cos(angle + spread) * speed,
                    y: sin(angle + spread) * speed
                ),
                shape: .spark
            ))
        }
    }

    /// Create impact effect
    static func createImpactEffect(
        state: inout GameState,
        x: CGFloat,
        y: CGFloat,
        weaponType: String
    ) {
        let now = timestamp(from: state)
        let color = getWeaponColor(weaponType)

        for i in 0..<5 {
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let speed = CGFloat.random(in: 30...80)

            state.particles.append(Particle(
                id: "\(RandomUtils.generateId())-impact-\(i)",
                type: .impact,
                x: x,
                y: y,
                lifetime: 0.2,
                createdAt: now,
                color: color,
                size: CGFloat.random(in: 2...5),
                velocity: CGPoint(x: cos(angle) * speed, y: sin(angle) * speed)
            ))
        }
    }

    /// Create weapon trail particles
    static func createWeaponTrail(
        state: inout GameState,
        x: CGFloat,
        y: CGFloat,
        weaponType: String
    ) {
        // Only spawn trail particles occasionally
        guard RandomUtils.randomBool(probability: 0.3) else { return }

        let now = timestamp(from: state)
        let color = getWeaponColor(weaponType)

        state.particles.append(Particle(
            id: "\(RandomUtils.generateId())-trail",
            type: .trail,
            x: x + CGFloat.random(in: -2...2),
            y: y + CGFloat.random(in: -2...2),
            lifetime: 0.15,
            createdAt: now,
            color: color,
            size: CGFloat.random(in: 2...4),
            drag: 0.1
        ))
    }

    /// Get weapon-themed color
    private static func getWeaponColor(_ weaponType: String) -> String {
        switch weaponType {
        case "sword", "katana", "axe", "spear", "hammer":
            return "#c0c0c0" // Silver
        case "bow", "crossbow":
            return "#8b4513" // Brown
        case "wand", "staff":
            return "#9370db" // Purple magic
        case "flamethrower":
            return "#ff4500" // Orange fire
        case "ice_shard":
            return "#00ffff" // Cyan ice
        case "lightning":
            return "#00ffff" // Cyan lightning
        case "laser":
            return "#ff0000" // Red laser
        case "bomb", "cannon":
            return "#ff8800" // Orange explosion
        case "dual_guns":
            return "#ffd700" // Gold
        case "excalibur":
            return "#ffd700" // Golden legendary
        case "scythe":
            return "#000000" // Dark
        default:
            return "#ffffff" // White fallback
        }
    }
}
