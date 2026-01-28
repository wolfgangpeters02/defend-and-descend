import Foundation
import CoreGraphics

// MARK: - Shared Types for Survivor + TD Unified Progression
// These types work identically in both modes

// MARK: - WeaponTower (Unified Weapon/Tower Definition)
// In Survivor mode: Player fires the weapon
// In TD mode: Tower fires the same projectile

struct WeaponTower: Codable, Identifiable {
    var id: String
    var name: String
    var towerName: String  // Display name in TD mode (e.g., "Archer Tower")
    var description: String
    var rarity: Rarity
    var level: Int  // 1-10, shared between modes

    // Combat stats (same for weapon and tower)
    var damage: CGFloat
    var range: CGFloat
    var attackSpeed: CGFloat  // Attacks per second

    // Projectile properties
    var projectileType: String
    var projectileCount: Int
    var pierce: Int
    var splash: CGFloat
    var homing: Bool

    // Special effects
    var slow: CGFloat?          // Slow percentage (0.5 = 50% slow)
    var slowDuration: TimeInterval?
    var chain: Int?             // Chain lightning targets

    // Visual
    var color: String
    var icon: String

    // Level scaling
    var baseDamage: CGFloat
    var baseRange: CGFloat
    var baseAttackSpeed: CGFloat

    /// Calculate stats for a given level
    mutating func applyLevel(_ newLevel: Int) {
        level = min(10, max(1, newLevel))
        let levelMultiplier: CGFloat = 1.0 + CGFloat(level - 1) * 0.1  // +10% per level

        damage = baseDamage * levelMultiplier
        range = baseRange * (1.0 + CGFloat(level - 1) * 0.05)  // +5% range per level
        attackSpeed = baseAttackSpeed * (1.0 + CGFloat(level - 1) * 0.03)  // +3% speed per level
    }

    /// Gold cost to upgrade to next level
    var upgradeCost: Int {
        guard level < 10 else { return 0 }
        return 100 + (level * 50)  // 150, 200, 250, 300, 350, 400, 450, 500, 550
    }

    /// Create from WeaponConfig
    static func from(config: WeaponConfig, level: Int = 1) -> WeaponTower {
        var wt = WeaponTower(
            id: config.id,
            name: config.name,
            towerName: config.towerName ?? "\(config.name) Tower",
            description: config.description,
            rarity: Rarity(rawValue: config.rarity) ?? .common,
            level: level,
            damage: CGFloat(config.damage),
            range: CGFloat(config.range),
            attackSpeed: CGFloat(config.attackSpeed),
            projectileType: config.projectileType,
            projectileCount: config.special?.projectileCount ?? 1,
            pierce: config.special?.pierce ?? 0,
            splash: CGFloat(config.special?.splash ?? 0),
            homing: config.special?.homing ?? false,
            slow: config.special?.slow.map { CGFloat($0) },
            slowDuration: config.special?.slowDuration,
            chain: config.special?.chain,
            color: config.color,
            icon: config.icon,
            baseDamage: CGFloat(config.damage),
            baseRange: CGFloat(config.range),
            baseAttackSpeed: CGFloat(config.attackSpeed)
        )
        wt.applyLevel(level)
        return wt
    }
}

// MARK: - ArenaMap (Unified Arena/TD Map Definition)
// In Survivor mode: Fight in the arena
// In TD mode: Defend the same map with paths

struct ArenaMap: Codable, Identifiable {
    var id: String
    var name: String
    var rarity: Rarity

    // Dimensions
    var width: CGFloat
    var height: CGFloat

    // Visual
    var backgroundColor: String
    var theme: String
    var particleEffect: String?

    // Shared elements
    var obstacles: [MapObstacle]
    var hazards: [MapHazard]
    var effectZones: [MapEffectZone]

    // TD-specific (nil in Survivor mode)
    var paths: [EnemyPath]?
    var corePosition: CGPoint?
    var towerSlots: [TowerSlot]?

    // Arena modifier (affects both modes)
    var globalModifier: MapModifier?

    /// Check if this map supports TD mode
    var supportsTD: Bool {
        return paths != nil && !paths!.isEmpty && corePosition != nil
    }
}

struct MapObstacle: Codable, Identifiable {
    var id: String
    var x: CGFloat
    var y: CGFloat
    var width: CGFloat
    var height: CGFloat
    var color: String
    var type: String  // "tree", "rock", "wall", "pillar", etc.

    /// Rectangle for collision
    var rect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }
}

struct MapHazard: Codable, Identifiable {
    var id: String
    var x: CGFloat
    var y: CGFloat
    var width: CGFloat
    var height: CGFloat
    var damage: CGFloat
    var type: String  // "lava", "asteroid", "spikes", etc.

    var rect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }
}

struct MapEffectZone: Codable, Identifiable {
    var id: String
    var x: CGFloat
    var y: CGFloat
    var width: CGFloat
    var height: CGFloat
    var type: String  // "ice", "speedBoost", "healing"
    var speedMultiplier: CGFloat?
    var healPerSecond: CGFloat?
    var visualEffect: String?

    var rect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }
}

struct MapModifier: Codable {
    var playerSpeedMultiplier: CGFloat?
    var enemySpeedMultiplier: CGFloat?
    var damageMultiplier: CGFloat?
    var enemyDamageMultiplier: CGFloat?
    var projectileSpeedMultiplier: CGFloat?
    var description: String
}

// MARK: - TD-Specific Path Types

struct EnemyPath: Codable, Identifiable {
    var id: String
    var waypoints: [CGPoint]

    /// Total length of the path
    var length: CGFloat {
        guard waypoints.count > 1 else { return 0 }
        var total: CGFloat = 0
        for i in 1..<waypoints.count {
            let dx = waypoints[i].x - waypoints[i-1].x
            let dy = waypoints[i].y - waypoints[i-1].y
            total += sqrt(dx*dx + dy*dy)
        }
        return total
    }

    /// Get position at progress (0.0 to 1.0)
    func positionAt(progress: CGFloat) -> CGPoint {
        guard waypoints.count > 1 else { return waypoints.first ?? .zero }

        let targetDistance = progress * length
        var traveled: CGFloat = 0

        for i in 1..<waypoints.count {
            let from = waypoints[i-1]
            let to = waypoints[i]
            let dx = to.x - from.x
            let dy = to.y - from.y
            let segmentLength = sqrt(dx*dx + dy*dy)

            if traveled + segmentLength >= targetDistance {
                let remaining = targetDistance - traveled
                let t = remaining / segmentLength
                return CGPoint(
                    x: from.x + dx * t,
                    y: from.y + dy * t
                )
            }
            traveled += segmentLength
        }

        return waypoints.last ?? .zero
    }
}

struct TowerSlot: Codable, Identifiable {
    var id: String
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat  // Slot size (typically tower radius)
    var occupied: Bool = false
    var towerId: String?  // ID of placed tower

    var position: CGPoint {
        CGPoint(x: x, y: y)
    }
}

// MARK: - Unified Enemy (Shared between modes)

struct SharedEnemy: Codable, Identifiable {
    var id: String
    var type: String
    var name: String

    // Base stats
    var baseHealth: CGFloat
    var baseSpeed: CGFloat
    var baseDamage: CGFloat

    // Rewards
    var coinValue: Int
    var xpValue: Int

    // Visual
    var size: CGFloat
    var color: String
    var shape: String  // "square", "triangle", "hexagon"

    // Boss flag
    var isBoss: Bool

    /// Create scaled enemy for wave
    func scaled(healthMultiplier: CGFloat, damageMultiplier: CGFloat) -> SharedEnemy {
        var enemy = self
        enemy.baseHealth *= healthMultiplier
        enemy.baseDamage *= damageMultiplier
        return enemy
    }
}

// MARK: - Guardian Stats (Shared Player/Core stats)
// In Survivor: These are player stats
// In TD: These affect core and global tower bonuses

struct GuardianStats: Codable {
    // Shared stats (affect both modes)
    var damage: CGFloat = 1.0        // Damage multiplier for weapons/towers
    var attackSpeed: CGFloat = 1.0   // Attack speed multiplier
    var range: CGFloat = 1.0         // Range multiplier
    var health: CGFloat = 100        // Player HP / Core HP

    // Survivor-only stats
    var speed: CGFloat = 200         // Movement speed (Survivor only)
    var armor: CGFloat = 0           // Damage reduction (Survivor only)
    var regen: CGFloat = 1.5         // HP regen per second (Survivor only)
    var pickupRange: CGFloat = 50    // Data/XP pickup range (Survivor only)

    // TD-only stats
    var maxTowers: Int = 5           // Max towers placeable (TD only)
    var goldGeneration: CGFloat = 0  // Passive gold per second (TD only)
    var coreArmor: CGFloat = 0       // Core damage reduction (TD only)
}

// MARK: - Collection Item (Generic unlockable)

struct CollectionItem: Codable, Identifiable {
    var id: String
    var category: CollectionCategory
    var name: String
    var description: String
    var rarity: Rarity
    var level: Int
    var maxLevel: Int
    var unlocked: Bool
    var icon: String

    enum CollectionCategory: String, Codable {
        case weapon      // Also unlocks tower
        case arena       // Also unlocks TD map
        case powerup     // Survivor-only power-ups
    }
}

// Note: CGPoint already conforms to Codable in modern iOS
