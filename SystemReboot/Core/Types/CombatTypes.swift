import Foundation
import CoreGraphics

// MARK: - Projectile

struct Projectile: Identifiable {
    var id: String
    var weaponId: String
    var x: CGFloat
    var y: CGFloat
    var velocityX: CGFloat
    var velocityY: CGFloat
    var damage: CGFloat
    var radius: CGFloat
    var color: String
    var lifetime: Double
    var piercing: Int
    var hitEnemies: [String]
    var isHoming: Bool
    var homingStrength: CGFloat
    var isEnemyProjectile: Bool = false

    var targetId: String?
    var speed: CGFloat?
    var createdAt: TimeInterval?
    var pierceRemaining: Int?
    var sourceType: String?

    var splash: CGFloat?
    var slow: CGFloat?
    var slowDuration: TimeInterval?
    var chain: Int?

    var size: CGFloat?
    var trail: Bool?
}

// MARK: - Pickup

struct Pickup {
    var id: String
    var type: PickupType
    var x: CGFloat
    var y: CGFloat
    var value: Int
    var lifetime: TimeInterval
    var createdAt: TimeInterval
    var magnetized: Bool

    /// Convenience initializer for backwards compatibility with string type
    init(id: String, type: String, x: CGFloat, y: CGFloat, value: Int,
         lifetime: TimeInterval, createdAt: TimeInterval, magnetized: Bool) {
        self.id = id
        self.type = PickupType(from: type)
        self.x = x
        self.y = y
        self.value = value
        self.lifetime = lifetime
        self.createdAt = createdAt
        self.magnetized = magnetized
    }

    /// Primary initializer with typed pickup type
    init(id: String, type: PickupType, x: CGFloat, y: CGFloat, value: Int,
         lifetime: TimeInterval, createdAt: TimeInterval, magnetized: Bool) {
        self.id = id
        self.type = type
        self.x = x
        self.y = y
        self.value = value
        self.lifetime = lifetime
        self.createdAt = createdAt
        self.magnetized = magnetized
    }
}

// MARK: - Particle

struct Particle {
    var id: String
    var type: ParticleType
    var x: CGFloat
    var y: CGFloat
    var lifetime: TimeInterval
    var createdAt: TimeInterval

    var color: String?
    var size: CGFloat?
    var velocity: CGPoint?

    var rotation: CGFloat?
    var rotationSpeed: CGFloat?
    var drag: CGFloat?
    var shape: ParticleShape?
    var scale: CGFloat?

    /// Convenience initializer for backwards compatibility with string type
    init(id: String, type: String, x: CGFloat, y: CGFloat, lifetime: TimeInterval,
         createdAt: TimeInterval, color: String? = nil, size: CGFloat? = nil,
         velocity: CGPoint? = nil, rotation: CGFloat? = nil, rotationSpeed: CGFloat? = nil,
         drag: CGFloat? = nil, shape: ParticleShape? = nil, scale: CGFloat? = nil) {
        self.id = id
        self.type = ParticleType(from: type)
        self.x = x
        self.y = y
        self.lifetime = lifetime
        self.createdAt = createdAt
        self.color = color
        self.size = size
        self.velocity = velocity
        self.rotation = rotation
        self.rotationSpeed = rotationSpeed
        self.drag = drag
        self.shape = shape
        self.scale = scale
    }

    /// Primary initializer with typed particle type
    init(id: String, type: ParticleType, x: CGFloat, y: CGFloat, lifetime: TimeInterval,
         createdAt: TimeInterval, color: String? = nil, size: CGFloat? = nil,
         velocity: CGPoint? = nil, rotation: CGFloat? = nil, rotationSpeed: CGFloat? = nil,
         drag: CGFloat? = nil, shape: ParticleShape? = nil, scale: CGFloat? = nil) {
        self.id = id
        self.type = type
        self.x = x
        self.y = y
        self.lifetime = lifetime
        self.createdAt = createdAt
        self.color = color
        self.size = size
        self.velocity = velocity
        self.rotation = rotation
        self.rotationSpeed = rotationSpeed
        self.drag = drag
        self.shape = shape
        self.scale = scale
    }
}

enum ParticleShape: String {
    case circle, star, spark, square, plus, heart, diamond
}

// MARK: - Combat Text

enum CombatTextType: String {
    case phaseAnnouncement = "phase-announcement"
    case warning
    case mechanic
    case achievement
    case milestone
}

struct CombatText {
    var id: String
    var type: CombatTextType
    var text: String
    var createdAt: TimeInterval
    var duration: TimeInterval
    var priority: Int

    var progress: (current: Int, total: Int)?
    var color: String?
    var icon: String?
}

// MARK: - Scrolling Combat Text Events

enum DamageEventType: String, Codable {
    case damage           // Standard damage dealt
    case critical         // Critical hit damage
    case healing          // Health restored
    case shield           // Damage absorbed
    case freeze           // Freeze/slow applied
    case burn             // Burn/DoT damage
    case chain            // Chain lightning damage
    case execute          // Execute/instant kill
    case xp               // XP gained
    case currency         // Currency/hash gained
    case miss             // Missed/dodged
    case playerDamage     // Damage taken by player
    case immune           // Target is immune to damage
}

struct DamageEvent: Identifiable {
    let id: String
    let type: DamageEventType
    let amount: Int
    let position: CGPoint
    let timestamp: TimeInterval
    var displayed: Bool = false

    init(type: DamageEventType, amount: Int, position: CGPoint, timestamp: TimeInterval) {
        self.id = UUID().uuidString
        self.type = type
        self.amount = amount
        self.position = position
        self.timestamp = timestamp
    }
}
