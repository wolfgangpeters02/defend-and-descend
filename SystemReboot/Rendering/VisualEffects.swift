import Foundation
import CoreGraphics
import SpriteKit

// MARK: - Visual Effects Manager

class VisualEffects {
    static let shared = VisualEffects()

    // Screen shake
    private var shakeIntensity: CGFloat = 0
    private var shakeDuration: TimeInterval = 0
    private var shakeStartTime: TimeInterval = 0

    // Screen flash
    private var flashActive = false
    private var flashColor: SKColor = .white
    private var flashOpacity: CGFloat = 0
    private var flashDuration: TimeInterval = 0
    private var flashStartTime: TimeInterval = 0

    // Slow motion
    private var slowMotionActive = false
    private var slowMotionTimeScale: CGFloat = 1.0
    private var slowMotionEndTime: TimeInterval = 0

    // Hitstop
    private var hitstopActive = false
    private var hitstopEndTime: TimeInterval = 0

    private init() {}

    // MARK: - Screen Shake

    func triggerScreenShake(intensity: CGFloat, duration: TimeInterval) {
        shakeIntensity = intensity
        shakeDuration = duration
        shakeStartTime = Date().timeIntervalSince1970
    }

    func getScreenShakeOffset() -> CGPoint {
        let now = Date().timeIntervalSince1970
        let elapsed = now - shakeStartTime

        guard elapsed < shakeDuration else {
            return .zero
        }

        let progress = CGFloat(elapsed / shakeDuration)
        let decay = 1 - progress
        let currentIntensity = shakeIntensity * decay

        let offsetX = CGFloat.random(in: -currentIntensity...currentIntensity)
        let offsetY = CGFloat.random(in: -currentIntensity...currentIntensity)

        return CGPoint(x: offsetX, y: offsetY)
    }

    // MARK: - Screen Flash

    func triggerScreenFlash(color: SKColor = .white, opacity: CGFloat = 0.5, duration: TimeInterval = 0.2) {
        flashActive = true
        flashColor = color
        flashOpacity = opacity
        flashDuration = duration
        flashStartTime = Date().timeIntervalSince1970
    }

    func getScreenFlash() -> (active: Bool, color: SKColor, opacity: CGFloat) {
        guard flashActive else {
            return (false, .white, 0)
        }

        let now = Date().timeIntervalSince1970
        let elapsed = now - flashStartTime

        if elapsed >= flashDuration {
            flashActive = false
            return (false, .white, 0)
        }

        let progress = CGFloat(elapsed / flashDuration)
        let currentOpacity = flashOpacity * (1 - progress)

        return (true, flashColor, currentOpacity)
    }

    // MARK: - Slow Motion

    func triggerSlowMotion(timeScale: CGFloat = 0.3, duration: TimeInterval = 0.5) {
        slowMotionActive = true
        slowMotionTimeScale = timeScale
        slowMotionEndTime = Date().timeIntervalSince1970 + duration
    }

    func getTimeScale() -> CGFloat {
        guard slowMotionActive else { return 1.0 }

        let now = Date().timeIntervalSince1970
        if now >= slowMotionEndTime {
            slowMotionActive = false
            return 1.0
        }

        return slowMotionTimeScale
    }

    // MARK: - Hitstop

    func triggerHitstop(duration: TimeInterval = 0.05) {
        hitstopActive = true
        hitstopEndTime = Date().timeIntervalSince1970 + duration
    }

    func isHitstopActive() -> Bool {
        guard hitstopActive else { return false }

        let now = Date().timeIntervalSince1970
        if now >= hitstopEndTime {
            hitstopActive = false
            return false
        }

        return true
    }
}

// MARK: - Advanced Particle Effects

extension ParticleFactory {

    /// Create level up effect
    static func createLevelUpEffect(state: inout GameState, x: CGFloat, y: CGFloat) {
        let now = Date().timeIntervalSince1970

        for i in 0..<30 {
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let speed = CGFloat.random(in: 100...200)

            state.particles.append(Particle(
                id: "\(RandomUtils.generateId())-levelup-\(i)",
                type: "legendary",
                x: x,
                y: y,
                lifetime: Double.random(in: 0.5...1.0),
                createdAt: now,
                color: "#ffd700",
                size: CGFloat.random(in: 4...8),
                velocity: CGPoint(x: cos(angle) * speed, y: sin(angle) * speed),
                shape: .star
            ))
        }
    }

    /// Create victory confetti
    static func createVictoryConfetti(state: inout GameState, x: CGFloat, y: CGFloat) {
        let now = Date().timeIntervalSince1970
        let colors = ["#ff0000", "#00ff00", "#0000ff", "#ffff00", "#ff00ff", "#00ffff"]

        for i in 0..<50 {
            let angle = CGFloat.random(in: -(.pi / 4)...(-.pi * 3 / 4))
            let speed = CGFloat.random(in: 200...400)

            state.particles.append(Particle(
                id: "\(RandomUtils.generateId())-confetti-\(i)",
                type: "legendary",
                x: x + CGFloat.random(in: -100...100),
                y: y,
                lifetime: Double.random(in: 1.0...2.0),
                createdAt: now,
                color: colors.randomElement() ?? "#ffffff",
                size: CGFloat.random(in: 4...8),
                velocity: CGPoint(x: cos(angle) * speed, y: sin(angle) * speed),
                shape: [.square, .star, .diamond].randomElement()
            ))
        }
    }

    /// Create legendary explosion (100 particles)
    static func createLegendaryExplosion(state: inout GameState, x: CGFloat, y: CGFloat) {
        let now = Date().timeIntervalSince1970

        // Main burst
        for i in 0..<100 {
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let speed = CGFloat.random(in: 50...250)

            state.particles.append(Particle(
                id: "\(RandomUtils.generateId())-legendary-\(i)",
                type: "legendary",
                x: x,
                y: y,
                lifetime: Double.random(in: 0.5...1.5),
                createdAt: now,
                color: ["#ffd700", "#ff6600", "#ff0000"].randomElement() ?? "#ffd700",
                size: CGFloat.random(in: 3...10),
                velocity: CGPoint(x: cos(angle) * speed, y: sin(angle) * speed),
                rotation: CGFloat.random(in: 0...(2 * .pi)),
                rotationSpeed: CGFloat.random(in: -10...10),
                drag: 0.02,
                shape: [.star, .spark, .circle].randomElement()
            ))
        }

        // Trailing sparkles
        for i in 0..<50 {
            let delay = Double(i) * 0.02
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let speed = CGFloat.random(in: 30...100)

            state.particles.append(Particle(
                id: "\(RandomUtils.generateId())-sparkle-\(i)",
                type: "legendary",
                x: x + CGFloat.random(in: -30...30),
                y: y + CGFloat.random(in: -30...30),
                lifetime: Double.random(in: 0.3...0.8) + delay,
                createdAt: now,
                color: "#ffffff",
                size: CGFloat.random(in: 2...4),
                velocity: CGPoint(x: cos(angle) * speed, y: sin(angle) * speed),
                shape: .spark
            ))
        }

        // Screen effects
        VisualEffects.shared.triggerScreenShake(intensity: 15, duration: 0.5)
        VisualEffects.shared.triggerScreenFlash(color: SKColor.yellow, opacity: 0.6, duration: 0.3)
    }

    /// Create player death effect
    static func createPlayerDeathEffect(state: inout GameState, x: CGFloat, y: CGFloat) {
        let now = Date().timeIntervalSince1970

        // Main explosion
        for i in 0..<60 {
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let speed = CGFloat.random(in: 50...200)

            state.particles.append(Particle(
                id: "\(RandomUtils.generateId())-death-\(i)",
                type: "hit",
                x: x,
                y: y,
                lifetime: Double.random(in: 0.5...1.2),
                createdAt: now,
                color: "#00ffff",
                size: CGFloat.random(in: 3...8),
                velocity: CGPoint(x: cos(angle) * speed, y: sin(angle) * speed),
                drag: 0.03
            ))
        }

        // Smoke clouds
        for i in 0..<20 {
            state.particles.append(Particle(
                id: "\(RandomUtils.generateId())-smoke-\(i)",
                type: "explosion",
                x: x + CGFloat.random(in: -20...20),
                y: y + CGFloat.random(in: -20...20),
                lifetime: Double.random(in: 0.8...1.5),
                createdAt: now,
                color: "#333333",
                size: CGFloat.random(in: 15...30),
                velocity: CGPoint(x: CGFloat.random(in: -20...20), y: CGFloat.random(in: -50 ... -20)),
                drag: 0.05
            ))
        }

        VisualEffects.shared.triggerScreenShake(intensity: 20, duration: 0.8)
        VisualEffects.shared.triggerScreenFlash(color: SKColor.red, opacity: 0.7, duration: 0.4)
    }

    /// Create fire particles
    static func createFireParticles(state: inout GameState, x: CGFloat, y: CGFloat, count: Int = 5) {
        let now = Date().timeIntervalSince1970

        for i in 0..<count {
            state.particles.append(Particle(
                id: "\(RandomUtils.generateId())-fire-\(i)",
                type: "hit",
                x: x + CGFloat.random(in: -5...5),
                y: y + CGFloat.random(in: -5...5),
                lifetime: Double.random(in: 0.3...0.6),
                createdAt: now,
                color: ["#ff4500", "#ff6600", "#ffcc00"].randomElement() ?? "#ff4500",
                size: CGFloat.random(in: 3...6),
                velocity: CGPoint(x: CGFloat.random(in: -20...20), y: CGFloat.random(in: -80 ... -40)),
                drag: 0.1
            ))
        }
    }

    /// Create ice particles
    static func createIceParticles(state: inout GameState, x: CGFloat, y: CGFloat, count: Int = 5) {
        let now = Date().timeIntervalSince1970

        for i in 0..<count {
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let speed = CGFloat.random(in: 30...80)

            state.particles.append(Particle(
                id: "\(RandomUtils.generateId())-ice-\(i)",
                type: "hit",
                x: x,
                y: y,
                lifetime: Double.random(in: 0.3...0.5),
                createdAt: now,
                color: ["#00ffff", "#87ceeb", "#ffffff"].randomElement() ?? "#00ffff",
                size: CGFloat.random(in: 2...5),
                velocity: CGPoint(x: cos(angle) * speed, y: sin(angle) * speed),
                shape: .diamond
            ))
        }
    }

    /// Create lightning particles
    static func createLightningParticles(state: inout GameState, x: CGFloat, y: CGFloat, count: Int = 8) {
        let now = Date().timeIntervalSince1970

        for i in 0..<count {
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let speed = CGFloat.random(in: 100...200)

            state.particles.append(Particle(
                id: "\(RandomUtils.generateId())-lightning-\(i)",
                type: "hit",
                x: x,
                y: y,
                lifetime: 0.15,
                createdAt: now,
                color: "#00ffff",
                size: CGFloat.random(in: 2...4),
                velocity: CGPoint(x: cos(angle) * speed, y: sin(angle) * speed),
                shape: .spark
            ))
        }
    }
}

// MARK: - Damage Numbers

struct DamageNumber {
    var id: String
    var x: CGFloat
    var y: CGFloat
    var damage: CGFloat
    var isCritical: Bool
    var createdAt: TimeInterval
    var velocityY: CGFloat
}

class DamageNumberManager {
    static let shared = DamageNumberManager()
    private var numbers: [DamageNumber] = []

    private init() {}

    func create(x: CGFloat, y: CGFloat, damage: CGFloat, isCritical: Bool = false) {
        numbers.append(DamageNumber(
            id: RandomUtils.generateId(),
            x: x + CGFloat.random(in: -10...10),
            y: y,
            damage: damage,
            isCritical: isCritical,
            createdAt: Date().timeIntervalSince1970,
            velocityY: -100
        ))
    }

    func update(deltaTime: TimeInterval) {
        let now = Date().timeIntervalSince1970
        let gravity: CGFloat = 200

        for i in 0..<numbers.count {
            numbers[i].velocityY += gravity * CGFloat(deltaTime)
            numbers[i].y += numbers[i].velocityY * CGFloat(deltaTime)
        }

        // Remove expired (after 1 second)
        numbers = numbers.filter { now - $0.createdAt < 1.0 }
    }

    func getNumbers() -> [DamageNumber] {
        return numbers
    }
}
