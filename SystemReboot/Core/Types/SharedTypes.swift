import Foundation
import CoreGraphics

// MARK: - Shared Types for Survivor + TD Unified Progression
// These types work identically in both modes

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
    var sectorId: String?  // Which sector this path originates from (for boss type selection)

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
    var hashValue: Int
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
    }
}

// Note: CGPoint already conforms to Codable in modern iOS
