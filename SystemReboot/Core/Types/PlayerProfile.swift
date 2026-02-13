import Foundation
import CoreGraphics

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

struct PlayerProfile: Codable, HashStorable {
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
        case defeatedSectorBosses = "defeatedDistrictBosses"  // Preserved key for save compat
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

    // MARK: - Global Upgrades (Legacy - kept for save backward compat only)

    /// DEPRECATED: Use componentLevels. Kept for Codable backward compat.
    var globalUpgrades: LegacyGlobalUpgrades = LegacyGlobalUpgrades()

    // MARK: - Component Upgrade System (New)

    /// Levels for each upgradable component (PSU, Storage, RAM, GPU, Cache, Expansion, I/O, Network, CPU)
    var componentLevels: ComponentLevels = ComponentLevels()

    /// Tracks which components are unlocked via sector boss defeats
    var unlockedComponents: UnlockedComponents = UnlockedComponents()

    // MARK: - Motherboard Progress (New)

    /// IDs of unlocked board expansions
    var unlockedExpansions: [String] = []

    /// Current efficiency (0.0 to 1.0)
    var motherboardEfficiency: CGFloat = 1.0

    // MARK: - Debug Arena Progress

    /// IDs of unlocked debug arenas (CodingKey: "unlockedSectors" for save compat)
    var unlockedSectors: [String] = [DebugArenaLibrary.starterArenaId, "cathedral"]  // RAM + Cathedral unlocked by default

    /// Arena ID -> Best survival time (CodingKey: "sectorBestTimes" for save compat)
    var sectorBestTimes: [String: TimeInterval] = [:]

    /// TD Mega-Board sector unlock progress (partial payments)
    var tdSectorUnlockProgress: [String: Int] = [:]

    /// IDs of unlocked TD Mega-Board sectors (default: starter sector)
    var unlockedTDSectors: [String] = [SectorID.starter.rawValue]

    /// IDs of sectors where boss has been defeated for first time
    /// Defeating a sector boss unlocks visibility of the next sector
    var defeatedSectorBosses: [String] = []

    // MARK: - Offline State (Legacy - actual state lives in tdStats)

    /// Last time the app was active (for offline calculation)
    /// NOTE: Source of truth is tdStats.lastActiveTimestamp (TimeInterval)
    var lastActiveTimestamp: TimeInterval = 0

    /// Efficiency snapshot for offline calculation
    /// NOTE: Source of truth is tdStats.averageEfficiency
    var offlineEfficiencySnapshot: CGFloat = 1.0

    // MARK: - Legacy Fields (Preserved for save backward compat — do NOT read from these)
    // Canonical data lives in compiledProtocols/protocolLevels.
    // These are kept so old saves decode; migrate() copies them into the protocol system.

    /// DEPRECATED: Use compiledProtocols instead. Kept for Codable backward compat.
    var unlocks: PlayerUnlocks
    /// DEPRECATED: Use protocolLevels instead. Kept for Codable backward compat.
    var weaponLevels: [String: Int]

    // Stats by mode
    var survivorStats: SurvivorModeStats
    var tdStats: TDModeStats

    // Legacy stats (preserved)
    var totalRuns: Int
    var bestTime: TimeInterval
    var totalKills: Int
    var legendariesUnlocked: Int

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
    var baseHashPerSecond: CGFloat = 1.0       // Base Hash income rate (synced from ComponentLevels)
    var networkHashMultiplier: CGFloat = 1.0   // Network component bonus (synced from ComponentLevels)
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

        // Ensure starter debug arenas are unlocked (RAM + Cathedral)
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

        // Migrate legacy globalUpgrades → componentLevels (take max of each)
        profile.componentLevels.psu = max(profile.componentLevels.psu, profile.globalUpgrades.psuLevel)
        profile.componentLevels.cpu = max(profile.componentLevels.cpu, profile.globalUpgrades.cpuLevel)
        profile.componentLevels.ram = max(profile.componentLevels.ram, profile.globalUpgrades.ramLevel)
        profile.componentLevels.cache = max(profile.componentLevels.cache, profile.globalUpgrades.coolingLevel)
        profile.componentLevels.storage = max(profile.componentLevels.storage, profile.globalUpgrades.hddLevel)

        // Migrate legacy weapon data → protocol system
        // Old saves may only have weaponLevels/unlocks.weapons; copy to canonical protocol fields
        for (weaponId, level) in profile.weaponLevels {
            let existingLevel = profile.protocolLevels[weaponId] ?? 0
            profile.protocolLevels[weaponId] = max(existingLevel, level)
        }
        for weaponId in profile.unlocks.weapons {
            if !profile.compiledProtocols.contains(weaponId) {
                profile.compiledProtocols.append(weaponId)
            }
        }

        return profile
    }
}
