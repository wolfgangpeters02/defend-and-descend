import Foundation
import CoreGraphics

// MARK: - Game Mode

enum GameMode: String, Codable {
    case arena
    case dungeon
    case towerDefense
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

    // Arena
    var arena: ArenaData

    // Player
    var player: Player

    // Run setup
    var currentWeaponType: String
    var currentPowerUpType: String
    var activeSynergy: Synergy?

    // Resources
    var coins: Int = 0

    // Potions
    var potions: PotionCharges = PotionCharges()
    var activePotionEffects: ActivePotionEffects = ActivePotionEffects()

    // Time & XP
    var runStartTime: TimeInterval
    var timeElapsed: TimeInterval = 0
    var xp: Int = 0
    var xpBarProgress: CGFloat = 0
    var lastBossSpawnTime: TimeInterval = 0

    // Game objects
    var enemies: [Enemy] = []
    var projectiles: [Projectile] = []
    var particles: [Particle] = []
    var pickups: [Pickup] = []

    // Upgrades
    var upgradeLevel: Int = 0
    var pendingUpgrade: Bool = false
    var upgradeChoices: [UpgradeChoice] = []

    // Dungeon mode
    var rooms: [DungeonRoom]?
    var currentRoomIndex: Int?
    var currentRoom: DungeonRoom?
    var roomCleared: Bool?
    var doors: [Door]?
    var dungeonCountdown: Int?
    var dungeonCountdownActive: Bool?

    // Advanced dungeon features
    var movingHazards: [MovingHazard]?
    var securityCameras: [SecurityCamera]?
    var bossPuddles: [DamagePuddle]?
    var bossLasers: [BossLaser]?

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

    // UI state
    var isGameOver: Bool = false
    var isPaused: Bool = false
    var victory: Bool = false
}

// MARK: - Session Stats

struct SessionStats {
    var enemiesKilled: Int = 0
    var coinsCollected: Int = 0
    var damageDealt: CGFloat = 0
    var damageTaken: CGFloat = 0
    var upgradesChosen: Int = 0
    var maxCombo: Int = 0
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
}

struct Hazard: Identifiable {
    var id: String
    var x: CGFloat
    var y: CGFloat
    var width: CGFloat
    var height: CGFloat
    var damage: CGFloat
    var damageType: String
    var type: String
}

struct ArenaEffectZone: Identifiable {
    var id: String
    var x: CGFloat
    var y: CGFloat
    var width: CGFloat
    var height: CGFloat
    var effects: [String: CGFloat]
    var type: String
    var speedMultiplier: CGFloat?
    var healPerSecond: CGFloat?
    var visualEffect: String?
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

// MARK: - Dungeon

struct DungeonRoom: Identifiable {
    var id: String
    var type: String
    var width: CGFloat
    var height: CGFloat
    var enemies: [EnemySpawn]
    var obstacles: [Obstacle]
    var effectZones: [ArenaEffectZone]
    var hazards: [Hazard]
    var backgroundColor: String
    var decorations: [Decoration]
    var doors: [Door]
    var securityCameras: [SecurityCamera]?
    var isBossRoom: Bool = false
    var bossId: String?
    var cleared: Bool = false
}

struct EnemySpawn: Identifiable {
    var id: String
    var type: String
    var delay: Double
}

struct RoomEnemyWave {
    var enemyType: String
    var count: Int
    var delay: TimeInterval?
}

struct Door: Identifiable {
    var id: String
    var x: CGFloat
    var y: CGFloat
    var width: CGFloat
    var height: CGFloat
    var locked: Bool
    var targetRoomIndex: Int
    var direction: String
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

    var size: CGFloat?
    var trail: Bool?
}

// MARK: - Pickup

struct Pickup {
    var id: String
    var type: String
    var x: CGFloat
    var y: CGFloat
    var value: Int
    var lifetime: TimeInterval
    var createdAt: TimeInterval
    var magnetized: Bool
}

// MARK: - Particle

struct Particle {
    var id: String
    var type: String
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

// MARK: - Synergy

struct Synergy {
    var name: String
    var description: String
    var effects: [String: CGFloat]
}

// MARK: - Camera

struct Camera {
    var x: CGFloat
    var y: CGFloat
    var viewportWidth: CGFloat
    var viewportHeight: CGFloat
}

// MARK: - Advanced Dungeon Features

struct MovingHazard {
    var id: String
    var x: CGFloat
    var y: CGFloat
    var width: CGFloat
    var height: CGFloat
    var damage: CGFloat
    var type: String

    var startX: CGFloat
    var endX: CGFloat
    var startY: CGFloat
    var endY: CGFloat
    var speed: CGFloat
    var direction: Int // 1 or -1
}

struct SecurityCamera: Identifiable {
    var id: String
    var x: CGFloat
    var y: CGFloat
    var detectionRadius: CGFloat
    var detectionAngle: CGFloat
    var rotation: CGFloat
    var rotationSpeed: CGFloat
    var isTriggered: Bool
    var cooldown: Double
    var lastTriggerTime: Double = 0

    var facing: CGFloat?
    var triggered: Bool?
    var triggeredAt: TimeInterval?
}

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

// MARK: - Player Profile (Unified Progression)

struct PlayerProfile: Codable {
    var id: String
    var displayName: String
    var createdAt: String

    // Unified progression
    var level: Int = 1
    var xp: Int = 0
    var gold: Int = 0

    // Collection unlocks (shared between modes)
    var unlocks: PlayerUnlocks
    var weaponLevels: [String: Int]  // weapon_id -> level (1-10)
    var powerupLevels: [String: Int]

    // Stats by mode
    var survivorStats: SurvivorModeStats
    var tdStats: TDModeStats

    // Legacy stats (preserved)
    var totalRuns: Int
    var bestTime: TimeInterval
    var totalKills: Int
    var legendariesUnlocked: Int

    // XP required for next level
    static func xpForLevel(_ level: Int) -> Int {
        return 100 + (level - 1) * 75
    }
}

struct PlayerUnlocks: Codable {
    var arenas: [String]   // Also unlocks TD maps
    var weapons: [String]  // Also unlocks towers
    var powerups: [String]
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
}

// MARK: - Default Profile

extension PlayerProfile {
    /// Create a default profile for new players
    static var defaultProfile: PlayerProfile {
        PlayerProfile(
            id: UUID().uuidString,
            displayName: "Guardian",
            createdAt: ISO8601DateFormatter().string(from: Date()),
            level: 1,
            xp: 0,
            gold: 100,
            unlocks: PlayerUnlocks(
                arenas: ["grasslands", "volcano", "ice_cave"],
                weapons: ["bow", "ice_shard"],
                powerups: ["tank", "berserker"]
            ),
            weaponLevels: ["bow": 1, "ice_shard": 1],
            powerupLevels: ["tank": 1, "berserker": 1],
            survivorStats: SurvivorModeStats(),
            tdStats: TDModeStats(),
            totalRuns: 0,
            bestTime: 0,
            totalKills: 0,
            legendariesUnlocked: 0
        )
    }
}
