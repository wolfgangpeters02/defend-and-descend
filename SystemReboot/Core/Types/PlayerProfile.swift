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
