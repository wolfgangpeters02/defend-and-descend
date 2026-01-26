import Foundation

// MARK: - Storage Service

class StorageService {
    static let shared = StorageService()

    private let userDefaults = UserDefaults.standard

    private enum Keys {
        static let playerProfile = "playerProfile"
        static let allPlayers = "allPlayers"
        static let currentPlayerId = "currentPlayerId"
    }

    private init() {}

    // MARK: - Player Profile

    /// Get or create a default player
    func getOrCreateDefaultPlayer() -> PlayerProfile {
        // Try to load existing player
        if let data = userDefaults.data(forKey: Keys.playerProfile) {
            // First try to decode with current schema
            if let profile = try? JSONDecoder().decode(PlayerProfile.self, from: data) {
                return profile
            }

            // If that fails, try to migrate from legacy format
            if let legacyProfile = migrateFromLegacyProfile(data: data) {
                savePlayer(legacyProfile)
                return legacyProfile
            }
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
        if let gold = json["gold"] as? Int { profile.gold = gold }

        // Migrate unlocks
        if let unlocksData = json["unlocks"] as? [String: Any] {
            if let weapons = unlocksData["weapons"] as? [String] {
                profile.unlocks.weapons = weapons
            }
            if let powerups = unlocksData["powerups"] as? [String] {
                profile.unlocks.powerups = powerups
            }
            if let arenas = unlocksData["arenas"] as? [String] {
                profile.unlocks.arenas = arenas
            }
        }

        // Migrate item levels
        if let weaponLevels = json["weaponLevels"] as? [String: Int] {
            profile.weaponLevels = weaponLevels
        }
        if let powerupLevels = json["powerupLevels"] as? [String: Int] {
            profile.powerupLevels = powerupLevels
        }

        // Old stats become survivor stats
        profile.survivorStats.arenaRuns = profile.totalRuns
        profile.survivorStats.totalSurvivorKills = profile.totalKills
        profile.survivorStats.longestSurvival = profile.bestTime

        // TD stats start fresh
        profile.tdStats = TDModeStats()

        return profile
    }

    /// Save player profile
    func savePlayer(_ profile: PlayerProfile) {
        if let data = try? JSONEncoder().encode(profile) {
            userDefaults.set(data, forKey: Keys.playerProfile)
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
        if let data = try? JSONEncoder().encode(players) {
            userDefaults.set(data, forKey: Keys.allPlayers)
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

        // Award XP and gold
        let xpReward = kills + Int(time / 10) + (victory ? 25 : 0)
        let goldReward = coinsCollected / 10

        profile.xp += xpReward
        profile.gold += goldReward

        // Check level up
        while profile.xp >= PlayerProfile.xpForLevel(profile.level) {
            profile.xp -= PlayerProfile.xpForLevel(profile.level)
            profile.level += 1
        }

        savePlayer(profile)
    }

    /// Save TD game result
    func saveTDResult(wavesCompleted: Int, enemiesKilled: Int, goldEarned: Int, towersPlaced: Int, victory: Bool) {
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

        // Award XP and gold
        let xpReward = wavesCompleted * 10 + enemiesKilled + (victory ? 50 : 0)
        let goldReward = goldEarned / 10 + (victory ? wavesCompleted * 5 : 0)

        profile.xp += xpReward
        profile.gold += goldReward

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

    /// Save timestamp when app goes to background
    func saveLastActiveTime() {
        var profile = getOrCreateDefaultPlayer()
        profile.tdStats.lastActiveTimestamp = Date().timeIntervalSince1970
        savePlayer(profile)
    }

    /// Calculate and apply offline earnings
    /// Returns: (wattsEarned, timeAway) or nil if no earnings
    func calculateOfflineEarnings() -> OfflineEarningsResult? {
        let profile = getOrCreateDefaultPlayer()

        // Check if we have a valid last active timestamp
        guard profile.tdStats.lastActiveTimestamp > 0 else {
            return nil
        }

        let now = Date().timeIntervalSince1970
        let timeAway = now - profile.tdStats.lastActiveTimestamp

        // Minimum 1 minute away to earn anything
        guard timeAway >= 60 else {
            return nil
        }

        // Cap at 8 hours (28800 seconds)
        let cappedTime = min(timeAway, 28800)

        // Calculate earnings
        // offlineWatts = timeAway * baseRate * cpuMultiplier * avgEfficiency * 0.5 (offline penalty)
        let baseRate = profile.tdStats.baseWattsPerSecond
        let cpuMultiplier = profile.tdStats.cpuMultiplier
        let efficiency = profile.tdStats.averageEfficiency / 100
        let offlineMultiplier: CGFloat = 0.5  // 50% efficiency when offline

        let wattsEarned = Int(cappedTime * Double(baseRate * cpuMultiplier * efficiency * offlineMultiplier))

        // Calculate passive Data from virus kills
        let passiveData = profile.tdStats.passiveDataEarned

        return OfflineEarningsResult(
            wattsEarned: wattsEarned,
            dataEarned: passiveData,
            timeAwaySeconds: timeAway,
            cappedTimeSeconds: cappedTime,
            wasCapped: timeAway > 28800
        )
    }

    /// Apply offline earnings to player profile
    func applyOfflineEarnings(_ earnings: OfflineEarningsResult) {
        var profile = getOrCreateDefaultPlayer()

        // Add Watts
        profile.gold += earnings.wattsEarned

        // Update timestamp
        profile.tdStats.lastActiveTimestamp = Date().timeIntervalSince1970

        savePlayer(profile)
    }

    /// Update virus kill count (for passive Data generation)
    func addVirusKills(_ count: Int) {
        var profile = getOrCreateDefaultPlayer()
        profile.tdStats.totalVirusKills += count
        profile.tdStats.totalTDKills += count
        profile.totalKills += count
        savePlayer(profile)
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
    /// Returns: true if upgrade successful, false if not enough Watts or max tier
    func upgradeCpuTier() -> Bool {
        var profile = getOrCreateDefaultPlayer()

        guard let cost = profile.tdStats.nextCpuUpgradeCost else {
            // Already at max tier
            return false
        }

        guard profile.gold >= cost else {
            // Not enough Watts
            return false
        }

        // Deduct cost and upgrade
        profile.gold -= cost
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

    // MARK: - Reset

    /// Reset all data (for debugging)
    func resetAllData() {
        userDefaults.removeObject(forKey: Keys.playerProfile)
        userDefaults.removeObject(forKey: Keys.allPlayers)
        userDefaults.removeObject(forKey: Keys.currentPlayerId)
    }
}

// MARK: - Offline Earnings Result

struct OfflineEarningsResult {
    let wattsEarned: Int
    let dataEarned: Int
    let timeAwaySeconds: TimeInterval
    let cappedTimeSeconds: TimeInterval
    let wasCapped: Bool

    /// Format time away as human-readable string
    var formattedTimeAway: String {
        let hours = Int(timeAwaySeconds) / 3600
        let minutes = (Int(timeAwaySeconds) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}
