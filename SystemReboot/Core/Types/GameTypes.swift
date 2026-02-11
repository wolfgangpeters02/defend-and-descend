import Foundation
import CoreGraphics

// MARK: - Game Mode

enum GameMode: String, Codable {
    case survival      // Endless survival in Memory Core arena
    case boss          // Direct boss encounter
    case towerDefense  // Motherboard tower defense

    // Legacy support
    case arena         // Maps to survival
    case dungeon       // Maps to boss
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
    var bossPuddles: [DamagePuddle]?
    var bossLasers: [BossLaser]?

    // Survival mode events
    var activeEvent: SurvivalEventType?
    var eventEndTime: TimeInterval?
    var eventData: SurvivalEventData?

    // WoW raid mechanics
    var voidZones: [VoidZone]?
    var pylons: [Pylon]?
    var voidRifts: [VoidRift]?
    var gravityWells: [GravityWell]?
    var meteorStrikes: [MeteorStrike]?
    var arenaWalls: ArenaWall?

    // Camera
    var camera: Camera?

    // Session stats
    var stats: SessionStats = SessionStats()

    // Combat text
    var combatTexts: [CombatText]?

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

    /// Blueprint drop chance (from BalanceConfig)
    var blueprintChance: CGFloat {
        return BalanceConfig.BossDifficultyConfig.blueprintChances[rawValue] ?? 0.05
    }

    /// Display name for UI
    var displayName: String {
        return self.rawValue
    }
}

// MARK: - Survival Events

enum SurvivalEventType: String, Codable {
    case memorySurge       // Speed boost + increased spawns
    case bufferOverflow    // Arena shrinks temporarily
    case cacheFlush        // Clears all enemies
    case thermalThrottle   // Slow movement + damage boost
    case dataCorruption    // Obstacles become hazards
    case virusSwarm        // 50 fast weak enemies
    case systemRestore     // Healing zone spawns
}

struct SurvivalEventData: Codable {
    var shrinkAmount: CGFloat?           // For buffer overflow
    var corruptedObstacles: [String]?    // For data corruption
    var healingZonePosition: CGPoint?    // For system restore
    var swarmDirection: CGFloat?         // For virus swarm (angle)
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
    var extractionAvailable: Bool = false // True after 3 minutes survival
    var extracted: Bool = false           // True if player chose to extract

    /// Calculate final Hash reward based on exit type
    func finalHashReward() -> Int {
        if extracted {
            return hashEarned  // 100% on extraction
        } else {
            return hashEarned / 2  // 50% on death
        }
    }
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

    /// Check if this ability set contains any dungeon-only abilities
    var hasDungeonOnlyAbilities: Bool {
        return lifesteal != nil || revive != nil || thorns != nil ||
               explosionOnKill != nil || orbitalStrike != nil || timeFreeze != nil
    }
}

struct TrailEffect {
    var x: CGFloat
    var y: CGFloat
    var lifetime: TimeInterval
    var createdAt: TimeInterval
}

// MARK: - Weapon (Also represents Towers in TD mode)

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

    // Slow effect (for Ice weapons/towers)
    var slow: CGFloat?
    var slowDuration: TimeInterval?

    // Chain effect (for Lightning weapons/towers)
    var chain: Int?

    var color: String
    var particleEffect: String?

    // Tower name for TD mode (e.g., "Archer Tower" for bow)
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
    var coinValue: Int?

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

    // Boss-specific
    var bossMode: BossMode?
    var bossModeTimer: TimeInterval?
    var bossPhase2Spawned: Bool?
    var bossLastAttackTime: TimeInterval?
    var bossLaserAngle: CGFloat?

    // Void Harbinger
    var voidPhase2Active: Bool?
    var voidLastVolleyTime: TimeInterval?
    var voidLastAddTime: TimeInterval?
    var voidLastVoidZoneTime: TimeInterval?
    var voidLastMeteorTime: TimeInterval?
    var voidLastTeleportTime: TimeInterval?
    var voidInvulnerable: Bool?

    // Pylon linkage (for void_pylon enemy type)
    var pylonId: String?

    // Milestones
    var milestones: BossMilestones?

    var shape: String?
}

enum BossMode: String {
    case melee
    case ranged
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
