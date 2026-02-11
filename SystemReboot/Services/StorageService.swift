import Foundation

// MARK: - Storage Service

class StorageService {
    static let shared = StorageService()

    private let userDefaults = UserDefaults.standard

    private enum Keys {
        static let playerProfile = "playerProfile"
        static let allPlayers = "allPlayers"
        static let currentPlayerId = "currentPlayerId"
        static let tdSessionState = "td_session_state"
    }

    private init() {}

    // MARK: - Player Profile

    /// Get or create a default player
    func getOrCreateDefaultPlayer() -> PlayerProfile {
        // Try to load existing player
        if let data = userDefaults.data(forKey: Keys.playerProfile) {
            // First try to decode with current schema
            do {
                let profile = try JSONDecoder().decode(PlayerProfile.self, from: data)
                // Apply migrations (unlocks all arenas for testing)
                let migratedProfile = PlayerProfile.migrate(profile)
                if migratedProfile.unlocks.arenas.count != profile.unlocks.arenas.count {
                    savePlayer(migratedProfile)
                }
                return migratedProfile
            } catch {
                print("[StorageService] WARNING: Failed to decode PlayerProfile, attempting legacy migration: \(error)")
            }

            // If that fails, try to migrate from legacy format
            if let legacyProfile = migrateFromLegacyProfile(data: data) {
                let migratedProfile = PlayerProfile.migrate(legacyProfile)
                savePlayer(migratedProfile)
                return migratedProfile
            }

            print("[StorageService] ERROR: Failed to load or migrate player profile, creating default")
        }

        // Create default player
        let defaultProfile = PlayerProfile.defaultProfile
        savePlayer(defaultProfile)
        return defaultProfile
    }

    /// Migrate from legacy profile format (pre-TD update)
    private func migrateFromLegacyProfile(data: Data) -> PlayerProfile? {
        // Try to decode as dictionary to extract legacy fields
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        // Create new profile with defaults
        var profile = PlayerProfile.defaultProfile

        // Migrate basic fields
        if let id = json["id"] as? String { profile.id = id }
        if let displayName = json["displayName"] as? String { profile.displayName = displayName }
        if let createdAt = json["createdAt"] as? String { profile.createdAt = createdAt }

        // Migrate progression (old fields become unified)
        if let totalRuns = json["totalRuns"] as? Int { profile.totalRuns = totalRuns }
        if let totalKills = json["totalKills"] as? Int { profile.totalKills = totalKills }
        if let bestTime = json["bestTime"] as? Double { profile.bestTime = bestTime }
        if let legendariesUnlocked = json["legendariesUnlocked"] as? Int { profile.legendariesUnlocked = legendariesUnlocked }

        // Migrate old level/xp/gold if present (these were separate before)
        if let level = json["level"] as? Int { profile.level = level }
        if let xp = json["xp"] as? Int { profile.xp = xp }
        if let gold = json["gold"] as? Int { profile.hash = gold }  // Legacy gold → hash

        // Migrate hash from saved profile
        if let hash = json["hash"] as? Int { profile.hash = hash }

        // Migration: Convert legacy Data currency to Hash (Data is now removed)
        // Add existing data balance to hash at 10:1 ratio (since Hash is more abundant)
        if let data = json["data"] as? Int, data > 0 {
            profile.hash += data * 10  // Convert data to hash
        }

        // Migrate unlocks
        if let unlocksData = json["unlocks"] as? [String: Any] {
            if let weapons = unlocksData["weapons"] as? [String] {
                profile.unlocks.weapons = weapons
            }
            if let arenas = unlocksData["arenas"] as? [String] {
                profile.unlocks.arenas = arenas
            }
        }

        // Migrate item levels
        if let weaponLevels = json["weaponLevels"] as? [String: Int] {
            profile.weaponLevels = weaponLevels
        }

        // Old stats become survivor stats
        profile.survivorStats.arenaRuns = profile.totalRuns
        profile.survivorStats.totalSurvivorKills = profile.totalKills
        profile.survivorStats.longestSurvival = profile.bestTime

        // TD stats start fresh
        profile.tdStats = TDModeStats()

        // Migrate TD sector progress if present, otherwise use defaults
        if let unlockedTDSectors = json["unlockedTDSectors"] as? [String], !unlockedTDSectors.isEmpty {
            profile.unlockedTDSectors = unlockedTDSectors
        } else {
            // Default to starter sector (RAM)
            profile.unlockedTDSectors = [SectorID.starter.rawValue]
        }

        if let tdSectorProgress = json["tdSectorUnlockProgress"] as? [String: Int] {
            profile.tdSectorUnlockProgress = tdSectorProgress
        }

        // Blueprint system migration
        // bossKillRecords defaults to empty dict (new field)
        profile.bossKillRecords = [:]

        // Migrate existing protocolBlueprints if present
        if let blueprints = json["protocolBlueprints"] as? [String] {
            profile.protocolBlueprints = blueprints
        }

        return profile
    }

    /// Save player profile
    func savePlayer(_ profile: PlayerProfile) {
        do {
            let data = try JSONEncoder().encode(profile)
            userDefaults.set(data, forKey: Keys.playerProfile)
        } catch {
            print("[StorageService] ERROR: Failed to encode PlayerProfile: \(error)")
        }
    }

    /// Get player by ID (for multi-profile support)
    func getPlayer(id: String) -> PlayerProfile? {
        let allPlayers = getAllPlayers()
        return allPlayers.first { $0.id == id }
    }

    /// Get all players
    func getAllPlayers() -> [PlayerProfile] {
        guard let data = userDefaults.data(forKey: Keys.allPlayers),
              let players = try? JSONDecoder().decode([PlayerProfile].self, from: data) else {
            return []
        }
        return players
    }

    /// Create a new player
    func createPlayer(name: String) -> PlayerProfile {
        var profile = PlayerProfile.defaultProfile
        profile.id = UUID().uuidString
        profile.displayName = name
        profile.createdAt = ISO8601DateFormatter().string(from: Date())

        var allPlayers = getAllPlayers()
        allPlayers.append(profile)
        savePlayers(allPlayers)

        return profile
    }

    /// Save all players
    private func savePlayers(_ players: [PlayerProfile]) {
        do {
            let data = try JSONEncoder().encode(players)
            userDefaults.set(data, forKey: Keys.allPlayers)
        } catch {
            print("[StorageService] ERROR: Failed to encode player list: \(error)")
        }
    }

    /// Update existing player
    func updatePlayer(id: String, updates: (inout PlayerProfile) -> Void) {
        var allPlayers = getAllPlayers()
        if let index = allPlayers.firstIndex(where: { $0.id == id }) {
            updates(&allPlayers[index])
            savePlayers(allPlayers)

            // Also update main profile if it's the current one
            if let currentId = getCurrentPlayerId(), currentId == id {
                savePlayer(allPlayers[index])
            }
        }
    }

    /// Get current player ID
    func getCurrentPlayerId() -> String? {
        return userDefaults.string(forKey: Keys.currentPlayerId)
    }

    /// Set current player
    func setCurrentPlayer(id: String) {
        userDefaults.set(id, forKey: Keys.currentPlayerId)
    }

    // MARK: - Run Statistics

    /// Save survivor run result (arena or dungeon)
    func saveRunResult(time: TimeInterval, kills: Int, coinsCollected: Int, victory: Bool, gameMode: GameMode = .arena) {
        var profile = getOrCreateDefaultPlayer()

        // Update global stats
        profile.totalRuns += 1
        profile.totalKills += kills

        if time > profile.bestTime {
            profile.bestTime = time
        }

        // Update survivor-specific stats
        if gameMode == .arena {
            profile.survivorStats.arenaRuns += 1
        } else if gameMode == .dungeon {
            profile.survivorStats.dungeonRuns += 1
            if victory {
                profile.survivorStats.dungeonsCompleted += 1
            }
        }

        profile.survivorStats.totalSurvivorKills += kills
        if time > profile.survivorStats.longestSurvival {
            profile.survivorStats.longestSurvival = time
        }

        // Award XP and hash
        let xpReward = kills + Int(time / BalanceConfig.SurvivorRewards.xpPerTimePeriod) + (victory ? BalanceConfig.SurvivorRewards.victoryXPBonus : 0)
        let hashReward = coinsCollected / BalanceConfig.SurvivorRewards.hashRewardDivisor

        profile.xp += xpReward
        profile.addHash(hashReward)

        // Check level up
        while profile.xp >= PlayerProfile.xpForLevel(profile.level) {
            profile.xp -= PlayerProfile.xpForLevel(profile.level)
            profile.level += 1
        }

        savePlayer(profile)
    }

    /// Save TD game result
    func saveTDResult(wavesCompleted: Int, enemiesKilled: Int, hashEarned: Int, towersPlaced: Int, victory: Bool) {
        var profile = getOrCreateDefaultPlayer()

        // Update TD-specific stats
        profile.tdStats.gamesPlayed += 1
        if victory {
            profile.tdStats.gamesWon += 1
        }
        profile.tdStats.totalWavesCompleted += wavesCompleted
        profile.tdStats.highestWave = max(profile.tdStats.highestWave, wavesCompleted)
        profile.tdStats.totalTowersPlaced += towersPlaced
        profile.tdStats.totalTDKills += enemiesKilled

        // Update global stats (TD kills count toward total)
        profile.totalKills += enemiesKilled

        // Award XP and hash
        let xpReward = wavesCompleted * BalanceConfig.TDRewards.xpPerWave + enemiesKilled + (victory ? BalanceConfig.TDRewards.victoryXPBonus : 0)
        let hashReward = hashEarned / BalanceConfig.TDRewards.hashRewardDivisor + (victory ? wavesCompleted * BalanceConfig.TDRewards.victoryHashPerWave : 0)

        profile.xp += xpReward
        profile.addHash(hashReward)

        // Check level up
        while profile.xp >= PlayerProfile.xpForLevel(profile.level) {
            profile.xp -= PlayerProfile.xpForLevel(profile.level)
            profile.level += 1
        }

        savePlayer(profile)
    }

    // MARK: - Unlocks

    /// Check if item is unlocked
    func isUnlocked(category: String, id: String) -> Bool {
        let profile = getOrCreateDefaultPlayer()
        return LevelingSystem.isItemUnlocked(profile: profile, category: category, id: id)
    }

    /// Unlock item
    func unlockItem(category: String, id: String) {
        var profile = getOrCreateDefaultPlayer()
        if LevelingSystem.unlockItem(profile: &profile, category: category, id: id) {
            savePlayer(profile)
        }
    }

    /// Level up item
    func levelUpItem(category: String, id: String) {
        var profile = getOrCreateDefaultPlayer()
        if LevelingSystem.levelUpItem(profile: &profile, category: category, id: id) {
            savePlayer(profile)
        }
    }

    // MARK: - System: Reboot - Offline Earnings

    /// Save timestamp and game state when app goes to background
    func saveLastActiveTime() {
        var profile = getOrCreateDefaultPlayer()
        profile.tdStats.lastActiveTimestamp = Date().timeIntervalSince1970
        savePlayer(profile)
    }

    /// Save current game state for offline simulation
    /// Call this when the player leaves the TD game
    func saveOfflineSimulationState(
        threatLevel: CGFloat,
        leakCounter: Int,
        towerDefenseStrength: CGFloat,
        activeLaneCount: Int,
        efficiency: CGFloat
    ) {
        var profile = getOrCreateDefaultPlayer()
        profile.tdStats.lastActiveTimestamp = Date().timeIntervalSince1970
        profile.tdStats.lastThreatLevel = threatLevel
        profile.tdStats.lastLeakCounter = leakCounter
        profile.tdStats.towerDefenseStrength = towerDefenseStrength
        profile.tdStats.activeLaneCount = max(1, activeLaneCount)
        profile.tdStats.averageEfficiency = efficiency
        savePlayer(profile)

        // Schedule efficiency notification if enabled
        if profile.notificationsEnabled && efficiency > 0 {
            OfflineSimulator.scheduleEfficiencyNotification(
                efficiency: efficiency,
                threatLevel: threatLevel,
                towerDefenseStrength: towerDefenseStrength,
                activeLaneCount: activeLaneCount
            )
        }
    }

    /// Calculate offline earnings with defense simulation
    /// Delegates to OfflineSimulator for game domain logic
    func calculateOfflineEarnings() -> OfflineEarningsResult? {
        let profile = getOrCreateDefaultPlayer()
        return OfflineSimulator.calculateEarnings(tdStats: profile.tdStats)
    }

    /// Apply offline earnings and simulation results to player profile
    func applyOfflineEarnings(_ earnings: OfflineEarningsResult) {
        var profile = getOrCreateDefaultPlayer()

        // Add Hash (subject to HDD storage cap)
        profile.addHash(earnings.hashEarned)

        // Update timestamp
        profile.tdStats.lastActiveTimestamp = Date().timeIntervalSince1970

        // Apply simulation results for next session
        profile.tdStats.lastThreatLevel = earnings.newThreatLevel
        profile.tdStats.lastLeakCounter += earnings.leaksOccurred
        profile.tdStats.averageEfficiency = earnings.newEfficiency

        savePlayer(profile)
    }

    /// Apply offline simulation results to active game state
    /// Call this when loading a saved session after offline time
    func applyOfflineSimulationToGameState(
        earnings: OfflineEarningsResult,
        state: inout TDGameState
    ) {
        // Update threat level
        state.idleThreatLevel = earnings.newThreatLevel

        // Update leak counter (efficiency is computed from this)
        state.leakCounter += earnings.leaksOccurred
    }

    /// Update average efficiency for offline calculations
    func updateAverageEfficiency(_ efficiency: CGFloat) {
        var profile = getOrCreateDefaultPlayer()
        // Rolling average: 90% old, 10% new
        profile.tdStats.averageEfficiency = profile.tdStats.averageEfficiency * 0.9 + efficiency * 0.1
        savePlayer(profile)
    }

    // MARK: - CPU Tier Upgrades

    /// Attempt to upgrade CPU tier
    /// Returns: true if upgrade successful, false if not enough Hash or max tier
    func upgradeCpuTier() -> Bool {
        var profile = getOrCreateDefaultPlayer()

        guard let cost = profile.tdStats.nextCpuUpgradeCost else {
            // Already at max tier
            return false
        }

        guard profile.hash >= cost else {
            // Not enough Hash
            return false
        }

        // Deduct cost and upgrade
        profile.hash -= cost
        profile.tdStats.cpuTier += 1

        savePlayer(profile)
        return true
    }

    /// Get current CPU tier info
    func getCpuTierInfo() -> (tier: Int, multiplier: CGFloat, nextCost: Int?) {
        let profile = getOrCreateDefaultPlayer()
        return (
            tier: profile.tdStats.cpuTier,
            multiplier: profile.tdStats.cpuMultiplier,
            nextCost: profile.tdStats.nextCpuUpgradeCost
        )
    }

    // MARK: - TD Session Persistence

    /// Save TD session state (towers, slots, resources)
    func saveTDSession(_ state: TDSessionState) {
        do {
            let data = try JSONEncoder().encode(state)
            userDefaults.set(data, forKey: Keys.tdSessionState)
        } catch {
            print("[StorageService] ERROR: Failed to encode TDSessionState: \(error)")
        }
    }

    /// Load TD session state
    func loadTDSession() -> TDSessionState? {
        guard let data = userDefaults.data(forKey: Keys.tdSessionState) else { return nil }
        do {
            return try JSONDecoder().decode(TDSessionState.self, from: data)
        } catch {
            print("[StorageService] ERROR: Failed to decode TDSessionState: \(error)")
            return nil
        }
    }

    /// Clear TD session state (on game reset or new game)
    func clearTDSession() {
        userDefaults.removeObject(forKey: Keys.tdSessionState)
    }

    // MARK: - Reset

    /// Reset all data (for debugging)
    func resetAllData() {
        userDefaults.removeObject(forKey: Keys.playerProfile)
        userDefaults.removeObject(forKey: Keys.allPlayers)
        userDefaults.removeObject(forKey: Keys.currentPlayerId)
        userDefaults.removeObject(forKey: Keys.tdSessionState)
    }
}

