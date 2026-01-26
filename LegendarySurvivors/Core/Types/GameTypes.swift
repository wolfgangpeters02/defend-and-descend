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

    // System: Reboot - Data multiplier for Debug mode sectors
    var dataMultiplier: CGFloat = 1.0

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

    // System: Reboot - Dual Currency
    var watts: Int = 0      // Watts - earned passively in Motherboard, spent on building/upgrades
    var data: Int = 0       // Data - earned in Debug/Active mode, spent on Protocol unlocks

    // MARK: - CodingKeys (exclude computed properties)

    enum CodingKeys: String, CodingKey {
        case id, displayName, createdAt, level, xp, watts, data
        case compiledProtocols, protocolLevels, equippedProtocolId, protocolBlueprints
        case globalUpgrades, unlockedExpansions, motherboardEfficiency
        case unlockedSectors, sectorBestTimes
        case lastActiveTimestamp, offlineEfficiencySnapshot
        case unlocks, weaponLevels, powerupLevels, heroUpgrades
        case survivorStats, tdStats
        case totalRuns, bestTime, totalKills, legendariesUnlocked
    }

    // Legacy currency alias (for backward compatibility)
    var gold: Int {
        get { return watts }
        set { watts = newValue }
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

    // MARK: - Global Upgrades (New)

    /// CPU, RAM, Cooling upgrades
    var globalUpgrades: GlobalUpgrades = GlobalUpgrades()

    // MARK: - Motherboard Progress (New)

    /// IDs of unlocked board expansions
    var unlockedExpansions: [String] = []

    /// Current efficiency (0.0 to 1.0)
    var motherboardEfficiency: CGFloat = 1.0

    // MARK: - Sector Progress (New)

    /// IDs of unlocked sectors
    var unlockedSectors: [String] = [SectorLibrary.starterSectorId]

    /// Sector ID -> Best survival time
    var sectorBestTimes: [String: TimeInterval] = [:]

    // MARK: - Offline State (New)

    /// Last time the app was active (for offline calculation)
    var lastActiveTimestamp: Date = Date()

    /// Efficiency snapshot for offline calculation
    var offlineEfficiencySnapshot: CGFloat = 1.0

    // MARK: - Legacy Fields (Preserved for migration)

    // Collection unlocks (shared between modes) - LEGACY
    var unlocks: PlayerUnlocks
    var weaponLevels: [String: Int]  // weapon_id -> level (1-10)
    var powerupLevels: [String: Int]

    // Hero Upgrades - LEGACY (replaced by globalUpgrades)
    var heroUpgrades: HeroUpgrades = HeroUpgrades()

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

    /// Get the currently equipped protocol
    func equippedProtocol() -> Protocol? {
        guard var proto = ProtocolLibrary.get(equippedProtocolId) else { return nil }
        proto.level = protocolLevel(equippedProtocolId)
        proto.isCompiled = true
        return proto
    }

    // MARK: - Sector Helpers

    /// Check if a sector is unlocked
    func isSectorUnlocked(_ sectorId: String) -> Bool {
        return unlockedSectors.contains(sectorId)
    }

    /// Get best time for a sector
    func sectorBestTime(_ sectorId: String) -> TimeInterval? {
        return sectorBestTimes[sectorId]
    }
}

// MARK: - Hero Upgrades (Purchased with Watts, used in Active/Debugger mode)

struct HeroUpgrades: Codable {
    var maxHpLevel: Int = 0         // Each level: +10 HP
    var damageLevel: Int = 0        // Each level: +5% damage
    var speedLevel: Int = 0         // Each level: +5% speed
    var pickupRangeLevel: Int = 0   // Each level: +10% pickup range

    // Maximum level for each upgrade
    static let maxLevel = 10

    // Bonus calculations
    var hpBonus: CGFloat { return CGFloat(maxHpLevel) * 10 }
    var damageMultiplier: CGFloat { return 1.0 + CGFloat(damageLevel) * 0.05 }
    var speedMultiplier: CGFloat { return 1.0 + CGFloat(speedLevel) * 0.05 }
    var pickupRangeMultiplier: CGFloat { return 1.0 + CGFloat(pickupRangeLevel) * 0.10 }

    // Cost for next level of each upgrade type
    static func upgradeCost(currentLevel: Int) -> Int {
        guard currentLevel < maxLevel else { return 0 }
        // 100, 200, 400, 800, 1600, 3200, 6400, 12800, 25600, 51200
        return 100 * Int(pow(2.0, Double(currentLevel)))
    }

    func canUpgrade(type: HeroUpgradeType, watts: Int) -> Bool {
        let level = self.level(for: type)
        guard level < HeroUpgrades.maxLevel else { return false }
        return watts >= HeroUpgrades.upgradeCost(currentLevel: level)
    }

    func level(for type: HeroUpgradeType) -> Int {
        switch type {
        case .maxHp: return maxHpLevel
        case .damage: return damageLevel
        case .speed: return speedLevel
        case .pickupRange: return pickupRangeLevel
        }
    }

    mutating func upgrade(type: HeroUpgradeType) {
        switch type {
        case .maxHp: maxHpLevel = min(maxHpLevel + 1, HeroUpgrades.maxLevel)
        case .damage: damageLevel = min(damageLevel + 1, HeroUpgrades.maxLevel)
        case .speed: speedLevel = min(speedLevel + 1, HeroUpgrades.maxLevel)
        case .pickupRange: pickupRangeLevel = min(pickupRangeLevel + 1, HeroUpgrades.maxLevel)
        }
    }
}

enum HeroUpgradeType: String, CaseIterable, Codable {
    case maxHp = "Max HP"
    case damage = "Damage"
    case speed = "Speed"
    case pickupRange = "Pickup Range"

    var icon: String {
        switch self {
        case .maxHp: return "heart.fill"
        case .damage: return "flame.fill"
        case .speed: return "hare.fill"
        case .pickupRange: return "magnet"
        }
    }

    var description: String {
        switch self {
        case .maxHp: return "+10 HP per level"
        case .damage: return "+5% damage per level"
        case .speed: return "+5% speed per level"
        case .pickupRange: return "+10% pickup range per level"
        }
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

    // System: Reboot - Offline/Idle Earnings
    var lastActiveTimestamp: TimeInterval = 0  // Last time player was active
    var totalVirusKills: Int = 0               // Total viruses killed (for passive Data)
    var totalData: Int = 0                     // Data currency (from Debugger/active mode)
    var baseWattsPerSecond: CGFloat = 10       // Base Watts income rate
    var averageEfficiency: CGFloat = 100       // Rolling average efficiency for offline calc

    // CPU Tier Upgrades (global income multiplier)
    var cpuTier: Int = 1                       // Current CPU tier (1-5)

    /// Calculate passive Data earned from virus kills
    var passiveDataEarned: Int {
        return totalVirusKills / 1000  // 1 Data per 1000 kills
    }

    /// CPU tier multiplier for Watts income
    var cpuMultiplier: CGFloat {
        switch cpuTier {
        case 1: return 1.0
        case 2: return 2.0
        case 3: return 4.0
        case 4: return 8.0
        case 5: return 16.0
        default: return 1.0
        }
    }

    /// Cost in Watts to upgrade to next CPU tier
    var nextCpuUpgradeCost: Int? {
        switch cpuTier {
        case 1: return 1000   // 1.0 -> 2.0
        case 2: return 5000   // 2.0 -> 3.0
        case 3: return 25000  // 3.0 -> 4.0
        case 4: return 100000 // 4.0 -> 5.0
        default: return nil   // Max tier
        }
    }

    /// Display name for current CPU tier
    var cpuDisplayName: String {
        return "CPU \(cpuTier).0"
    }

    /// Check if CPU can be upgraded (not max tier and has enough Watts)
    func canUpgradeCpu(watts: Int) -> Bool {
        guard let cost = nextCpuUpgradeCost else { return false }
        return watts >= cost
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
            watts: 500,                       // Starting Watts
            data: 0,                          // Starting Data
            compiledProtocols: [defaultProtocolId],  // Start with Kernel Pulse
            protocolLevels: [defaultProtocolId: 1],
            equippedProtocolId: defaultProtocolId,
            protocolBlueprints: [],
            globalUpgrades: GlobalUpgrades(),
            unlockedExpansions: [],
            motherboardEfficiency: 1.0,
            unlockedSectors: [defaultSectorId],
            sectorBestTimes: [:],
            lastActiveTimestamp: Date(),
            offlineEfficiencySnapshot: 1.0,
            unlocks: PlayerUnlocks(
                arenas: ["grasslands"],
                weapons: ["bow"],
                powerups: ["tank"]
            ),
            weaponLevels: ["bow": 1],
            powerupLevels: ["tank": 1],
            heroUpgrades: HeroUpgrades(),
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

        // Ensure starter sector is unlocked
        if !profile.unlockedSectors.contains(defaultSectorId) {
            profile.unlockedSectors.append(defaultSectorId)
        }

        // Migrate gold to watts if needed (gold is now a computed property)
        // This happens automatically via the getter/setter

        return profile
    }
}
