import Foundation
import CoreGraphics

// MARK: - Game Constants

enum GameConstants {
    // Player defaults
    static let defaultPlayerHealth: CGFloat = 100
    static let defaultPlayerSpeed: CGFloat = 200
    static let defaultPlayerSize: CGFloat = 15
    static let defaultPickupRange: CGFloat = 50
    static let defaultRegen: CGFloat = 1.5

    // Invulnerability
    static let invulnerabilityDuration: TimeInterval = 0.5 // seconds
    static let reviveInvulnerabilityDuration: TimeInterval = 3.0

    // Combat
    static let projectileBaseLifetime: TimeInterval = 2.0
    static let pickupLifetime: TimeInterval = 10.0
    static let coinMagnetSpeed: CGFloat = 400

    // Upgrades
    static let upgradeIntervalArena: TimeInterval = 60 // 1 minute
    static let bossSpawnInterval: TimeInterval = 120 // 2 minutes

    // Trail
    static let trailLifetime: TimeInterval = 0.5
    static let trailSpawnChance: Double = 0.3

    // Particles
    static let particleUpdateInterval: TimeInterval = 0.05 // 50ms

    // Performance
    static let maxParticles: Int = 500
    static let maxProjectiles: Int = 1000
}

// MARK: - Visual Constants

enum VisualConstants {
    // Colors
    static let playerColor = "#00ffff" // Cyan
    static let healthBarBackground = "#333333"
    static let healthBarForeground = "#00ff00"

    // Sizes
    static let healthBarWidth: CGFloat = 50
    static let healthBarHeight: CGFloat = 6
    static let healthBarOffset: CGFloat = 25

    // Effects
    static let screenShakeDuration: TimeInterval = 0.2
    static let screenShakeIntensity: CGFloat = 5
}

// MARK: - Weapon Mastery

enum WeaponMasteryConstants {
    static let maxLevel: Int = 20
    static let baseDamageMultiplier: CGFloat = 1.0
    static let damagePerLevel: CGFloat = 0.05 // 5% per level
}
