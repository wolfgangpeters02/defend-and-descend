import Foundation
import CoreGraphics

// MARK: - TD Particle Factory
// Creates particle definitions for Tower Defense mode

class TDParticleFactory {

    // MARK: - Death Particles

    /// Create enemy death particles
    static func createDeathParticles(
        state: inout TDGameState,
        x: CGFloat,
        y: CGFloat,
        color: String,
        isBoss: Bool = false
    ) {
        let now = Date().timeIntervalSince1970
        let count = isBoss ? 40 : Int.random(in: 15...25)

        for i in 0..<count {
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let speed = CGFloat.random(in: 50...150)
            let particleSize = CGFloat.random(in: 2...6)

            state.particles.append(Particle(
                id: "\(RandomUtils.generateId())-death-\(i)",
                type: "death",
                x: x,
                y: y,
                lifetime: Double.random(in: 0.3...0.8),
                createdAt: now,
                color: color,
                size: particleSize,
                velocity: CGPoint(x: cos(angle) * speed, y: sin(angle) * speed),
                rotation: CGFloat.random(in: 0...(2 * .pi)),
                rotationSpeed: CGFloat.random(in: -5...5),
                drag: 0.02
            ))
        }
    }

    // MARK: - Hash Floaties

    /// Create hash floating particles on enemy kill
    static func createHashFloaties(
        state: inout TDGameState,
        x: CGFloat,
        y: CGFloat,
        hashValue: Int
    ) {
        let now = Date().timeIntervalSince1970
        let count = min(5, max(1, hashValue / 5))

        for i in 0..<count {
            state.particles.append(Particle(
                id: "\(RandomUtils.generateId())-hash-\(i)",
                type: "hash",
                x: x + CGFloat.random(in: -10...10),
                y: y,
                lifetime: 0.8,
                createdAt: now + Double(i) * 0.1,
                color: TierColors.gold,
                size: 10,
                velocity: CGPoint(x: CGFloat.random(in: -20...20), y: -50),
                shape: .star
            ))
        }
    }

    // MARK: - Impact Sparks

    /// Create impact sparks when projectile hits enemy
    static func createImpactSparks(
        state: inout TDGameState,
        x: CGFloat,
        y: CGFloat,
        color: String
    ) {
        let now = Date().timeIntervalSince1970

        for i in 0..<5 {
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let speed = CGFloat.random(in: 30...80)

            state.particles.append(Particle(
                id: "\(RandomUtils.generateId())-impact-\(i)",
                type: "impact",
                x: x,
                y: y,
                lifetime: 0.2,
                createdAt: now,
                color: color,
                size: CGFloat.random(in: 1...3),
                velocity: CGPoint(x: cos(angle) * speed, y: sin(angle) * speed),
                shape: .spark
            ))
        }
    }

    // MARK: - Tower Placement

    /// Create burst effect when tower is placed
    static func createPlacementBurst(
        state: inout TDGameState,
        x: CGFloat,
        y: CGFloat,
        color: String
    ) {
        let now = Date().timeIntervalSince1970
        let count = 12

        for i in 0..<count {
            let angle = CGFloat(i) * (.pi * 2 / CGFloat(count))
            let speed: CGFloat = 100

            state.particles.append(Particle(
                id: "\(RandomUtils.generateId())-place-\(i)",
                type: "placement",
                x: x,
                y: y,
                lifetime: 0.3,
                createdAt: now,
                color: color,
                size: CGFloat.random(in: 2...4),
                velocity: CGPoint(x: cos(angle) * speed, y: sin(angle) * speed),
                drag: 0.1
            ))
        }
    }

    // MARK: - Merge Celebration

    /// Create celebratory particles when towers merge
    static func createMergeCelebration(
        state: inout TDGameState,
        x: CGFloat,
        y: CGFloat,
        color: String
    ) {
        let now = Date().timeIntervalSince1970
        let count = Int.random(in: 35...65)
        let colors = [color, TierColors.gold, "#ff8800", "#ffffff"]

        for i in 0..<count {
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let speed = CGFloat.random(in: 80...200)

            state.particles.append(Particle(
                id: "\(RandomUtils.generateId())-merge-\(i)",
                type: "merge",
                x: x,
                y: y,
                lifetime: Double.random(in: 0.4...0.8),
                createdAt: now,
                color: colors.randomElement()!,
                size: CGFloat.random(in: 2...5),
                velocity: CGPoint(x: cos(angle) * speed, y: sin(angle) * speed),
                drag: 0.03,
                shape: [.circle, .star, .spark].randomElement()
            ))
        }
    }

    // MARK: - Core Hit

    /// Create warning particles when enemy reaches core
    static func createCoreHitEffect(
        state: inout TDGameState,
        x: CGFloat,
        y: CGFloat
    ) {
        let now = Date().timeIntervalSince1970

        for i in 0..<20 {
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let speed = CGFloat.random(in: 60...120)

            state.particles.append(Particle(
                id: "\(RandomUtils.generateId())-corehit-\(i)",
                type: "corehit",
                x: x,
                y: y,
                lifetime: 0.4,
                createdAt: now,
                color: "#ff0000",
                size: CGFloat.random(in: 3...6),
                velocity: CGPoint(x: cos(angle) * speed, y: sin(angle) * speed),
                drag: 0.02
            ))
        }
    }

    // MARK: - Slow Effect

    /// Create frost particles for slowed enemies
    static func createSlowEffect(
        state: inout TDGameState,
        x: CGFloat,
        y: CGFloat
    ) {
        let now = Date().timeIntervalSince1970

        // Only spawn occasionally
        guard RandomUtils.randomBool(probability: 0.2) else { return }

        state.particles.append(Particle(
            id: "\(RandomUtils.generateId())-slow",
            type: "slow",
            x: x + CGFloat.random(in: -5...5),
            y: y + CGFloat.random(in: -5...5),
            lifetime: 0.5,
            createdAt: now,
            color: "#00ffff",
            size: CGFloat.random(in: 2...4),
            velocity: CGPoint(x: CGFloat.random(in: -10...10), y: CGFloat.random(in: 10...30)),
            shape: .diamond
        ))
    }

    // MARK: - Targeting Line

    /// Create targeting effect particles (optional visual)
    static func createTargetingPulse(
        state: inout TDGameState,
        fromX: CGFloat,
        fromY: CGFloat,
        toX: CGFloat,
        toY: CGFloat,
        color: String
    ) {
        let now = Date().timeIntervalSince1970
        let dx = toX - fromX
        let dy = toY - fromY
        let distance = sqrt(dx*dx + dy*dy)
        let particleCount = Int(distance / 30)

        for i in 0..<particleCount {
            let t = CGFloat(i) / CGFloat(particleCount)
            let x = fromX + dx * t
            let y = fromY + dy * t

            state.particles.append(Particle(
                id: "\(RandomUtils.generateId())-target-\(i)",
                type: "targeting",
                x: x,
                y: y,
                lifetime: 0.1,
                createdAt: now + Double(i) * 0.02,
                color: color,
                size: 2,
                shape: .circle,
                scale: 0.5 + t * 0.5
            ))
        }
    }
}
