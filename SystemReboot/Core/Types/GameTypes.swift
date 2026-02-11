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

struct BossMilestones {
    var announced75: Bool = false
    var announced50: Bool = false
    var announced25: Bool = false
}

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

// MARK: - Boss Mechanics

struct DamagePuddle {
    var id: String
    var x: CGFloat
    var y: CGFloat
    var radius: CGFloat
    var damage: CGFloat
    var createdAt: TimeInterval
    var lifetime: TimeInterval
    var fadeStartTime: TimeInterval
    var fadeDuration: TimeInterval
}

struct BossLaser {
    var id: String
    var bossId: String
    var angle: CGFloat
    var length: CGFloat
    var damage: CGFloat
    var rotationSpeed: CGFloat
}

// MARK: - WoW Raid Mechanics

struct VoidZone {
    var id: String
    var x: CGFloat
    var y: CGFloat
    var radius: CGFloat
    var damage: CGFloat
    var telegraphDuration: TimeInterval
    var createdAt: TimeInterval
    var activated: Bool
    var activationTime: TimeInterval
}

struct Pylon {
    var id: String
    var x: CGFloat
    var y: CGFloat
    var health: CGFloat
    var maxHealth: CGFloat
    var size: CGFloat
    var destroyed: Bool
    var lastBeamTime: TimeInterval
}

struct VoidRift {
    var id: String
    var centerX: CGFloat
    var centerY: CGFloat
    var angle: CGFloat
    var length: CGFloat
    var width: CGFloat
    var damage: CGFloat
    var rotationSpeed: CGFloat
}

struct GravityWell {
    var id: String
    var x: CGFloat
    var y: CGFloat
    var pullRadius: CGFloat
    var pullStrength: CGFloat
    var createdAt: TimeInterval
    var lifetime: TimeInterval
}

struct MeteorStrike {
    var id: String
    var targetX: CGFloat
    var targetY: CGFloat
    var radius: CGFloat
    var damage: CGFloat
    var telegraphDuration: TimeInterval
    var createdAt: TimeInterval
    var impactTime: TimeInterval
    var impacted: Bool
}

struct ArenaWall {
    var currentRadius: CGFloat
    var shrinkRate: CGFloat
    var minRadius: CGFloat
    var centerX: CGFloat
    var centerY: CGFloat
    var damage: CGFloat
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

// MARK: - Blueprint System

/// Boss kill tracking for drop rate calculations
struct BossKillRecord: Codable {
    var bossId: String
    var totalKills: Int = 0
    var killsByDifficulty: [String: Int] = [:]  // "normal": 5, "hard": 3
    var blueprintsEarnedFromBoss: [String] = []
    var lastKillDate: Date?
}

// MARK: - Player Profile (Unified Progression)

struct PlayerProfile: Codable {
    var id: String
    var displayName: String
    var createdAt: String

    // Unified progression
    var level: Int = 1
    var xp: Int = 0

    // System: Reboot - Single Currency (Hash is universal)
    var hash: Int = 0       // Hash (Ħ) - universal currency for all purchases

    // MARK: - FTUE (First Time User Experience)

    /// Whether the intro sequence has been completed
    var hasCompletedIntro: Bool = false

    /// Whether the player has placed their first tower
    var firstTowerPlaced: Bool = false

    /// IDs of tutorial hints that have been seen/dismissed
    var tutorialHintsSeen: [String] = []

    // MARK: - Notification Settings

    /// Whether efficiency alert notifications are enabled
    var notificationsEnabled: Bool = false

    // MARK: - CodingKeys (exclude computed properties)

    enum CodingKeys: String, CodingKey {
        case id, displayName, createdAt, level, xp, hash
        case hasCompletedIntro, firstTowerPlaced, tutorialHintsSeen  // FTUE
        case notificationsEnabled  // Settings
        case compiledProtocols, protocolLevels, equippedProtocolId, protocolBlueprints
        case globalUpgrades, componentLevels, unlockedComponents  // Upgrade systems
        case unlockedExpansions, motherboardEfficiency
        case unlockedSectors, sectorBestTimes, tdSectorUnlockProgress, unlockedTDSectors
        case defeatedDistrictBosses
        // lastActiveTimestamp and offlineEfficiencySnapshot removed from CodingKeys:
        // Source of truth is tdStats.lastActiveTimestamp / tdStats.averageEfficiency.
        // Old saves may contain a Date-formatted lastActiveTimestamp which would fail
        // to decode as TimeInterval, so we exclude it and use defaults.
        case unlocks, weaponLevels
        case survivorStats, tdStats
        case totalRuns, bestTime, totalKills, legendariesUnlocked
        case bossKillRecords  // Blueprint system
    }

    // MARK: - Protocol System (New)

    /// IDs of compiled (unlocked) protocols
    var compiledProtocols: [String] = []

    /// Protocol ID -> Level (1-10)
    var protocolLevels: [String: Int] = [:]

    /// Currently equipped protocol for Debug mode
    var equippedProtocolId: String = ProtocolLibrary.starterProtocolId

    /// IDs of found but not compiled protocol blueprints
    var protocolBlueprints: [String] = []

    /// Boss kill tracking for blueprint drop calculations
    var bossKillRecords: [String: BossKillRecord] = [:]

    // MARK: - Global Upgrades (Legacy - being replaced by Component system)

    /// CPU, RAM, Cooling upgrades (LEGACY - use componentLevels instead)
    var globalUpgrades: GlobalUpgrades = GlobalUpgrades()

    // MARK: - Component Upgrade System (New)

    /// Levels for each upgradable component (PSU, Storage, RAM, GPU, Cache, Expansion, I/O, Network, CPU)
    var componentLevels: ComponentLevels = ComponentLevels()

    /// Tracks which components are unlocked via district boss defeats
    var unlockedComponents: UnlockedComponents = UnlockedComponents()

    // MARK: - Motherboard Progress (New)

    /// IDs of unlocked board expansions
    var unlockedExpansions: [String] = []

    /// Current efficiency (0.0 to 1.0)
    var motherboardEfficiency: CGFloat = 1.0

    // MARK: - Sector Progress (New)

    /// IDs of unlocked Active mode sectors
    var unlockedSectors: [String] = [SectorLibrary.starterSectorId, "cathedral"]  // RAM + Cathedral unlocked by default

    /// Sector ID -> Best survival time
    var sectorBestTimes: [String: TimeInterval] = [:]

    /// TD Mega-Board sector unlock progress (partial payments)
    var tdSectorUnlockProgress: [String: Int] = [:]

    /// IDs of unlocked TD Mega-Board sectors (default: starter sector)
    var unlockedTDSectors: [String] = [SectorID.starter.rawValue]

    /// IDs of districts where boss has been defeated for first time
    /// Defeating a district boss unlocks visibility of the next district
    var defeatedDistrictBosses: [String] = []

    // MARK: - Offline State (Legacy - actual state lives in tdStats)

    /// Last time the app was active (for offline calculation)
    /// NOTE: Source of truth is tdStats.lastActiveTimestamp (TimeInterval)
    var lastActiveTimestamp: TimeInterval = 0

    /// Efficiency snapshot for offline calculation
    /// NOTE: Source of truth is tdStats.averageEfficiency
    var offlineEfficiencySnapshot: CGFloat = 1.0

    // MARK: - Legacy Fields (Preserved for migration)

    // Collection unlocks (shared between modes) - LEGACY
    var unlocks: PlayerUnlocks
    var weaponLevels: [String: Int]  // weapon_id -> level (1-10)

    // Stats by mode
    var survivorStats: SurvivorModeStats
    var tdStats: TDModeStats

    // Legacy stats (preserved)
    var totalRuns: Int
    var bestTime: TimeInterval
    var totalKills: Int
    var legendariesUnlocked: Int

    // XP required for next level (uses BalanceConfig)
    static func xpForLevel(_ level: Int) -> Int {
        return BalanceConfig.xpRequired(level: level)
    }

    // MARK: - Protocol Helpers

    /// Check if a protocol is compiled (unlocked)
    func isProtocolCompiled(_ protocolId: String) -> Bool {
        return compiledProtocols.contains(protocolId)
    }

    /// Get the level of a protocol (1 if not leveled)
    func protocolLevel(_ protocolId: String) -> Int {
        return protocolLevels[protocolId] ?? 1
    }

    /// Check if player has a blueprint for a protocol
    func hasBlueprint(_ protocolId: String) -> Bool {
        return protocolBlueprints.contains(protocolId)
    }

    // MARK: - Boss Kill Tracking (Blueprint System)

    /// Get kill count for a specific boss
    func bossKillCount(_ bossId: String) -> Int {
        return bossKillRecords[bossId]?.totalKills ?? 0
    }

    /// Track a boss kill
    mutating func recordBossKill(_ bossId: String, difficulty: BossDifficulty) {
        var record = bossKillRecords[bossId] ?? BossKillRecord(bossId: bossId)
        record.totalKills += 1
        record.killsByDifficulty[difficulty.rawValue, default: 0] += 1
        record.lastKillDate = Date()
        bossKillRecords[bossId] = record
    }

    /// Track a blueprint drop from a boss
    mutating func recordBlueprintDrop(_ bossId: String, protocolId: String) {
        if var record = bossKillRecords[bossId] {
            record.blueprintsEarnedFromBoss.append(protocolId)
            bossKillRecords[bossId] = record
        }
    }

    /// Get kills since last blueprint drop from a boss
    func killsSinceLastDrop(_ bossId: String) -> Int {
        guard let record = bossKillRecords[bossId] else { return 0 }
        return record.totalKills - record.blueprintsEarnedFromBoss.count
    }

    /// Get the currently equipped protocol
    func equippedProtocol() -> Protocol? {
        guard var proto = ProtocolLibrary.get(equippedProtocolId) else { return nil }
        proto.level = protocolLevel(equippedProtocolId)
        proto.isCompiled = true
        return proto
    }

    // MARK: - Sector Helpers (Active Mode)

    /// Check if a sector is unlocked
    func isSectorUnlocked(_ sectorId: String) -> Bool {
        return unlockedSectors.contains(sectorId)
    }

    /// Get best time for a sector
    func sectorBestTime(_ sectorId: String) -> TimeInterval? {
        return sectorBestTimes[sectorId]
    }

    // MARK: - TD Sector Helpers (Motherboard Map)

    /// Set of unlocked TD sector IDs (for efficient lookup)
    var unlockedSectorIds: Set<String> {
        return Set(unlockedTDSectors)
    }

    // Note: isTDSectorUnlocked and unlockTDSector are in MegaBoardSystem.swift extension

    // MARK: - Component Helpers

    /// Check if a component type is unlocked
    func isComponentUnlocked(_ type: UpgradeableComponent) -> Bool {
        return unlockedComponents.isUnlocked(type)
    }

    /// Get level of a component
    func componentLevel(_ type: UpgradeableComponent) -> Int {
        return componentLevels[type]
    }

    /// Check if a component can be upgraded
    func canUpgradeComponent(_ type: UpgradeableComponent) -> Bool {
        guard isComponentUnlocked(type) else { return false }
        return componentLevels.canUpgrade(type)
    }

    /// Get upgrade cost for a component (nil if max level or locked)
    func componentUpgradeCost(_ type: UpgradeableComponent) -> Int? {
        guard isComponentUnlocked(type) else { return nil }
        return componentLevels.upgradeCost(for: type)
    }

    /// Upgrade a component if affordable
    mutating func upgradeComponent(_ type: UpgradeableComponent) -> Bool {
        guard let cost = componentUpgradeCost(type),
              hash >= cost else { return false }
        hash -= cost
        componentLevels.upgrade(type)
        return true
    }

    /// Record a district boss defeat (unlocks next component)
    mutating func recordDistrictBossDefeat(_ sectorId: SectorID) {
        let sectorIdString = sectorId.rawValue
        if !defeatedDistrictBosses.contains(sectorIdString) {
            defeatedDistrictBosses.append(sectorIdString)
            unlockedComponents.recordBossDefeat()
        }
    }

    // MARK: - Currency Helpers (System: Reboot)

    /// Maximum hash storage capacity based on Storage component level
    var hashStorageCapacity: Int {
        return componentLevels.hashStorageCapacity
    }

    /// Add hash with storage cap enforcement
    /// Returns the actual amount added (may be less if hitting cap)
    @discardableResult
    mutating func addHash(_ amount: Int) -> Int {
        let cap = hashStorageCapacity
        let spaceAvailable = max(0, cap - hash)
        let actualAdded = min(amount, spaceAvailable)
        hash += actualAdded
        return actualAdded
    }

    /// Check if hash storage is full
    var isHashStorageFull: Bool {
        return hash >= hashStorageCapacity
    }

    /// Percentage of hash storage used (0.0 - 1.0)
    var hashStoragePercent: Double {
        guard hashStorageCapacity > 0 else { return 0 }
        return Double(hash) / Double(hashStorageCapacity)
    }
}

struct PlayerUnlocks: Codable {
    var arenas: [String]   // Also unlocks TD maps
    var weapons: [String]  // Also unlocks towers
}

struct SurvivorModeStats: Codable {
    var arenaRuns: Int = 0
    var dungeonRuns: Int = 0
    var totalSurvivorKills: Int = 0
    var longestSurvival: TimeInterval = 0
    var dungeonsCompleted: Int = 0
    var bossesDefeated: Int = 0
}

struct TDModeStats: Codable {
    var gamesPlayed: Int = 0
    var gamesWon: Int = 0
    var totalWavesCompleted: Int = 0
    var highestWave: Int = 0
    var totalTowersPlaced: Int = 0
    var totalTDKills: Int = 0

    // System: Reboot - Offline/Idle Earnings
    var lastActiveTimestamp: TimeInterval = 0  // Last time player was active
    var baseHashPerSecond: CGFloat = 1.0       // Base Hash income rate (must match GlobalUpgrades)
    var averageEfficiency: CGFloat = 100       // Rolling average efficiency for offline calc

    // Offline Simulation State
    var lastThreatLevel: CGFloat = 1.0         // Threat level when player left
    var lastLeakCounter: Int = 0               // Leak counter when player left
    var towerDefenseStrength: CGFloat = 0      // Sum of tower DPS for offline calc
    var activeLaneCount: Int = 1               // Number of active (non-paused) lanes

    // CPU Tier Upgrades (global income multiplier)
    var cpuTier: Int = 1                       // Current CPU tier (1-5)

    /// CPU tier multiplier for Hash income
    var cpuMultiplier: CGFloat {
        BalanceConfig.CPU.multiplier(tier: cpuTier)
    }

    /// Cost in Hash to upgrade to next CPU tier
    var nextCpuUpgradeCost: Int? {
        BalanceConfig.CPU.upgradeCost(currentTier: cpuTier)
    }

    /// Display name for current CPU tier
    var cpuDisplayName: String {
        return "CPU \(cpuTier).0"
    }

    /// Check if CPU can be upgraded (not max tier and has enough Hash)
    func canUpgradeCpu(hash: Int) -> Bool {
        guard let cost = nextCpuUpgradeCost else { return false }
        return hash >= cost
    }
}

// MARK: - Default Profile

extension PlayerProfile {
    // MARK: - Constants (to avoid circular dependencies)

    /// Default starter protocol ID
    static let defaultProtocolId = "kernel_pulse"

    /// Default starter sector ID
    static let defaultSectorId = "ram"

    /// Create a default profile for new players
    static var defaultProfile: PlayerProfile {
        PlayerProfile(
            id: UUID().uuidString,
            displayName: "Kernel",
            createdAt: ISO8601DateFormatter().string(from: Date()),
            level: 1,
            xp: 0,
            hash: 500,                        // Starting Hash (Ħ) - universal currency
            hasCompletedIntro: false,         // FTUE: New player hasn't seen intro
            firstTowerPlaced: false,          // FTUE: New player hasn't placed a tower
            tutorialHintsSeen: [],            // FTUE: No hints dismissed yet
            compiledProtocols: [defaultProtocolId],  // Start with Kernel Pulse
            protocolLevels: [defaultProtocolId: 1],
            equippedProtocolId: defaultProtocolId,
            protocolBlueprints: [],
            bossKillRecords: [:],  // Blueprint system tracking
            globalUpgrades: GlobalUpgrades(),
            unlockedExpansions: [],
            motherboardEfficiency: 1.0,
            unlockedSectors: [defaultSectorId, "cathedral"],  // RAM + Cathedral unlocked by default
            sectorBestTimes: [:],
            lastActiveTimestamp: 0,
            offlineEfficiencySnapshot: 1.0,
            unlocks: PlayerUnlocks(
                arenas: ["grasslands", "volcano", "ice_cave", "castle", "space", "temple", "cyberboss", "voidrealm"],  // All arenas unlocked for testing
                weapons: ["kernel_pulse"]  // Default Protocol (unified weapon system)
            ),
            weaponLevels: ["kernel_pulse": 1],  // Default Protocol level
            survivorStats: SurvivorModeStats(),
            tdStats: TDModeStats(),
            totalRuns: 0,
            bestTime: 0,
            totalKills: 0,
            legendariesUnlocked: 0
        )
    }

    /// Migrate an old profile to new format
    static func migrate(_ oldProfile: PlayerProfile) -> PlayerProfile {
        var profile = oldProfile

        // Ensure starter protocol is compiled
        if !profile.compiledProtocols.contains(defaultProtocolId) {
            profile.compiledProtocols.append(defaultProtocolId)
        }

        // Ensure protocol level exists
        if profile.protocolLevels[defaultProtocolId] == nil {
            profile.protocolLevels[defaultProtocolId] = 1
        }

        // Ensure starter sectors are unlocked (RAM + Cathedral)
        if !profile.unlockedSectors.contains(defaultSectorId) {
            profile.unlockedSectors.append(defaultSectorId)
        }
        if !profile.unlockedSectors.contains("cathedral") {
            profile.unlockedSectors.append("cathedral")
        }

        // Unlock all arenas/dungeons for testing
        let allArenas = ["grasslands", "volcano", "ice_cave", "castle", "space", "temple", "cyberboss", "voidrealm"]
        for arena in allArenas {
            if !profile.unlocks.arenas.contains(arena) {
                profile.unlocks.arenas.append(arena)
            }
        }

        // Migrate legacy gold to hash if needed
        // This happens automatically via StorageService migration

        // Blueprint system: ensure bossKillRecords is initialized
        // (New field added for tracking boss kills and drop rates)
        // Note: This is a no-op if already initialized via Codable

        return profile
    }
}
