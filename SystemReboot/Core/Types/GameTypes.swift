import Foundation
import CoreGraphics

// MARK: - Game Mode

enum GameMode: String, Codable {
    case survival      // Endless survival in Memory Core arena
    case boss          // Direct boss encounter
    case towerDefense  // Motherboard tower defense

    /// Backward compatibility: old saves may contain "arena" or "dungeon" raw values
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        switch rawValue {
        case "arena": self = .survival
        case "dungeon": self = .boss
        default:
            guard let mode = GameMode(rawValue: rawValue) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Unknown GameMode: \(rawValue)"
                )
            }
            self = mode
        }
    }
}

// MARK: - Rarity

enum Rarity: String, Codable {
    case common
    case rare
    case epic
    case legendary
}

// MARK: - Game State

struct GameState {
    // Session
    var sessionId: String
    var playerId: String
    var startTime: TimeInterval
    var gameMode: GameMode
    var gameTime: Double = 0
    var currentFrameTime: TimeInterval = 0  // Set from context.timestamp each frame for consistent time checks

    // Arena
    var arena: ArenaData

    // Player
    var player: Player

    // Run setup
    var currentWeaponType: String

    // Resources (Hash collected during this session)
    var sessionHash: Int = 0

    // Potions
    var potions: PotionCharges = PotionCharges()
    var activePotionEffects: ActivePotionEffects = ActivePotionEffects()

    // Time & XP
    var runStartTime: TimeInterval
    var timeElapsed: TimeInterval = 0
    var xp: Int = 0
    var xpBarProgress: CGFloat = 0
    var lastBossSpawnTime: TimeInterval = 0

    // System: Reboot - Hash multiplier for boss fights
    var hashMultiplier: CGFloat = 1.0

    // Game objects
    var enemies: [Enemy] = []
    var projectiles: [Projectile] = []
    var particles: [Particle] = []
    var pickups: [Pickup] = []

    // Spatial partitioning (Phase 3: O(n) collision detection)
    var enemyGrid: SpatialGrid<Enemy>?

    // Object pools (Phase 4: reduced GC pressure)
    var particlePool: ObjectPool<Particle>?
    var projectilePool: ObjectPool<Projectile>?

    // Upgrades
    var upgradeLevel: Int = 0
    var pendingUpgrade: Bool = false
    var upgradeChoices: [UpgradeChoice] = []

    // Boss encounter
    var bossDifficulty: BossDifficulty?

    // Camera
    var camera: Camera?

    // Session stats
    var stats: SessionStats = SessionStats()

    // Scrolling combat text events (damage numbers, healing, etc.)
    var damageEvents: [DamageEvent] = []

    // Boss AI state tracking
    var activeBossId: String?
    var activeBossType: BossType?
    var cyberbossState: CyberbossAI.CyberbossState?
    var voidHarbingerState: VoidHarbingerAI.VoidHarbingerState?
    var overclockerState: OverclockerAI.OverclockerState?
    var trojanWyrmState: TrojanWyrmAI.TrojanWyrmState?

    // UI state
    var isGameOver: Bool = false
    var isPaused: Bool = false
    var victory: Bool = false
}

// MARK: - Boss Types

enum BossType: String {
    case cyberboss = "cyberboss"
    case voidHarbinger = "voidharbinger"
    case overclocker = "overclocker"
    case trojanWyrm = "trojan_wyrm"
}

// MARK: - Boss Difficulty

enum BossDifficulty: String, Codable, CaseIterable {
    case easy = "Easy"
    case normal = "Normal"
    case hard = "Hard"
    case nightmare = "Nightmare"

    /// Boss health multiplier (from BalanceConfig)
    var healthMultiplier: CGFloat {
        return BalanceConfig.BossDifficultyConfig.healthMultipliers[rawValue] ?? 1.0
    }

    /// Boss damage multiplier (from BalanceConfig)
    var damageMultiplier: CGFloat {
        return BalanceConfig.BossDifficultyConfig.damageMultipliers[rawValue] ?? 1.0
    }

    /// Player health multiplier (from BalanceConfig)
    var playerHealthMultiplier: CGFloat {
        return BalanceConfig.BossDifficultyConfig.playerHealthMultipliers[rawValue] ?? 1.0
    }

    /// Player damage multiplier (from BalanceConfig)
    var playerDamageMultiplier: CGFloat {
        return BalanceConfig.BossDifficultyConfig.playerDamageMultipliers[rawValue] ?? 1.0
    }

    /// Hash reward for defeating boss (from BalanceConfig)
    var hashReward: Int {
        return BalanceConfig.BossDifficultyConfig.hashRewards[rawValue] ?? 1000
    }

    /// Display name for UI
    var displayName: String {
        return self.rawValue
    }
}

// MARK: - Session Stats

struct SessionStats {
    var enemiesKilled: Int = 0
    var hashCollected: Int = 0           // Hash pickups collected during gameplay
    var damageDealt: CGFloat = 0
    var damageTaken: CGFloat = 0
    var upgradesChosen: Int = 0
    var maxCombo: Int = 0

    // Economy - Hash (Ħ) earned this session (includes time bonus + pickups)
    var hashEarned: Int = 0              // Running total of Hash earned
}

// MARK: - Potions

struct PotionCharges {
    var health: CGFloat = 0
    var bomb: CGFloat = 0
    var magnet: CGFloat = 0
    var shield: CGFloat = 0
}

struct ActivePotionEffects {
    var shieldUntil: TimeInterval?
    var magnetUntil: TimeInterval?
    var originalPickupRange: CGFloat?
}

// MARK: - Player

struct Player {
    var x: CGFloat
    var y: CGFloat
    var health: CGFloat
    var maxHealth: CGFloat
    var speed: CGFloat
    var size: CGFloat

    var weapons: [Weapon]
    var pickupRange: CGFloat

    var armor: CGFloat
    var regen: CGFloat

    var abilities: PlayerAbilities?

    var trail: [TrailEffect]
    var invulnerable: Bool
    var invulnerableUntil: TimeInterval

    var velocityX: CGFloat
    var velocityY: CGFloat
    var moving: Bool

    // Effect zone tracking
    var onIce: Bool = false
    var iceSpeedMultiplier: CGFloat = 1.0
    var inSpeedZone: Bool = false
    var speedZoneMultiplier: CGFloat = 1.0

    // Dynamic modifiers (from ArenaSystem)
    var speedMultiplier: CGFloat = 1.0
    var damageReduction: CGFloat = 0
}

struct PlayerAbilities {
    // Dungeon-only abilities (don't translate to TD)
    var lifesteal: CGFloat?
    var revive: Int?
    var thorns: CGFloat?
    var explosionOnKill: CGFloat?
    var orbitalStrike: CGFloat?
    var orbitalStrikeLastUsed: TimeInterval?
    var timeFreeze: CGFloat?
    var timeFreezeLastUsed: TimeInterval?

}

struct TrailEffect {
    var x: CGFloat
    var y: CGFloat
    var lifetime: TimeInterval
    var createdAt: TimeInterval
}

// MARK: - Weapon

struct Weapon {
    var type: String
    var level: Int
    var damage: CGFloat
    var range: CGFloat
    var attackSpeed: CGFloat
    var lastAttackTime: TimeInterval

    var projectileCount: Int?
    var pierce: Int?
    var splash: CGFloat?
    var homing: Bool?

    // Slow effect (Ice weapons)
    var slow: CGFloat?
    var slowDuration: TimeInterval?

    // Chain effect (Lightning weapons)
    var chain: Int?

    var color: String
    var particleEffect: String?

    // Display name
    var towerName: String?

}

// MARK: - Arena

struct ArenaData {
    var type: String
    var name: String
    var width: CGFloat
    var height: CGFloat
    var backgroundColor: String
    var obstacles: [Obstacle]
    var hazards: [Hazard]
    var effectZones: [ArenaEffectZone]?
    var events: [ArenaEvent]?
    var particleEffect: String?
    var globalModifier: GlobalArenaModifier?
    var decorations: [Decoration]?
}

struct GlobalArenaModifier {
    var playerSpeedMultiplier: CGFloat?
    var enemySpeedMultiplier: CGFloat?
    var damageMultiplier: CGFloat?
    var enemyDamageMultiplier: CGFloat?
    var projectileSpeedMultiplier: CGFloat?
    var description: String
}

struct Obstacle: Identifiable {
    var id: String
    var x: CGFloat
    var y: CGFloat
    var width: CGFloat
    var height: CGFloat
    var color: String
    var type: String
    var isCorrupted: Bool = false  // For survival event: data corruption

    // Destructible pillar support (boss fights)
    var health: CGFloat?       // nil = indestructible
    var maxHealth: CGFloat?
    var isDestructible: Bool { health != nil }
}

struct Hazard: Identifiable {
    var id: String
    var x: CGFloat
    var y: CGFloat
    var width: CGFloat
    var height: CGFloat
    var damage: CGFloat
    var damageType: HazardDamageType
    var type: String

    /// Convenience initializer for backwards compatibility with string damageType
    init(id: String, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat,
         damage: CGFloat, damageType: String, type: String) {
        self.id = id
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.damage = damage
        self.damageType = HazardDamageType(from: damageType)
        self.type = type
    }

    /// Primary initializer with typed damageType
    init(id: String, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat,
         damage: CGFloat, damageType: HazardDamageType, type: String) {
        self.id = id
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.damage = damage
        self.damageType = damageType
        self.type = type
    }
}

struct ArenaEffectZone: Identifiable {
    var id: String
    var x: CGFloat
    var y: CGFloat
    var width: CGFloat
    var height: CGFloat
    var effects: [String: CGFloat]
    var type: EffectZoneType
    var speedMultiplier: CGFloat?
    var healPerSecond: CGFloat?
    var visualEffect: String?

    /// Convenience initializer for backwards compatibility with string type
    init(id: String, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat,
         effects: [String: CGFloat], type: String, speedMultiplier: CGFloat? = nil,
         healPerSecond: CGFloat? = nil, visualEffect: String? = nil) {
        self.id = id
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.effects = effects
        self.type = EffectZoneType(from: type)
        self.speedMultiplier = speedMultiplier
        self.healPerSecond = healPerSecond
        self.visualEffect = visualEffect
    }

    /// Primary initializer with typed effect zone type
    init(id: String, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat,
         effects: [String: CGFloat], type: EffectZoneType, speedMultiplier: CGFloat? = nil,
         healPerSecond: CGFloat? = nil, visualEffect: String? = nil) {
        self.id = id
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.effects = effects
        self.type = type
        self.speedMultiplier = speedMultiplier
        self.healPerSecond = healPerSecond
        self.visualEffect = visualEffect
    }
}

struct ArenaEvent {
    var type: String
    var intervalMin: TimeInterval
    var intervalMax: TimeInterval
    var lastTriggered: TimeInterval
    var nextTrigger: TimeInterval
    var damage: CGFloat?
    var radius: CGFloat?
    var duration: TimeInterval?
}

struct Decoration: Identifiable {
    var id: String
    var x: CGFloat
    var y: CGFloat
    var type: String
    var color: String?
}

// MARK: - Enemy

struct Enemy: Identifiable {
    var id: String
    var type: String
    var x: CGFloat
    var y: CGFloat
    var health: CGFloat
    var maxHealth: CGFloat
    var damage: CGFloat
    var speed: CGFloat
    var xpValue: Int
    var color: String

    var velocityX: CGFloat = 0
    var velocityY: CGFloat = 0

    var currentSpeed: CGFloat?
    var hashValue: Int?

    var targetX: CGFloat?
    var targetY: CGFloat?
    var size: CGFloat?

    var isSlowed: Bool = false
    var slowAmount: CGFloat = 0
    var slowEndTime: TimeInterval = 0
    var isDead: Bool = false
    var isBoss: Bool = false
    var bossPhase: Int?
    var inactive: Bool?
    var activationRadius: CGFloat?

    // Pylon linkage (for void_pylon enemy type)
    var pylonId: String?

    var shape: String?
}

// MARK: - Upgrades

struct UpgradeChoice: Identifiable {
    var id: String
    var name: String
    var description: String
    var icon: String
    var rarity: Rarity
    var effect: UpgradeEffect
}

struct UpgradeEffect {
    var type: UpgradeEffectType
    var target: String
    var value: CGFloat
    var isMultiplier: Bool?
}

enum UpgradeEffectType: String, Codable {
    case stat
    case weapon
    case ability
}

// MARK: - Camera

struct Camera {
    var x: CGFloat
    var y: CGFloat
    var viewportWidth: CGFloat
    var viewportHeight: CGFloat
}

// MARK: - Input

struct InputState {
    var up: Bool = false
    var down: Bool = false
    var left: Bool = false
    var right: Bool = false
    var joystick: JoystickInput?
}

struct JoystickInput {
    var angle: CGFloat
    var distance: CGFloat
}
