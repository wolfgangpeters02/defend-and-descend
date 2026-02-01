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
            if let profile = try? JSONDecoder().decode(PlayerProfile.self, from: data) {
                // Apply migrations (unlocks all arenas for testing)
                let migratedProfile = PlayerProfile.migrate(profile)
                if migratedProfile.unlocks.arenas.count != profile.unlocks.arenas.count {
                    savePlayer(migratedProfile)
                }
                return migratedProfile
            }

            // If that fails, try to migrate from legacy format
            if let legacyProfile = migrateFromLegacyProfile(data: data) {
                let migratedProfile = PlayerProfile.migrate(legacyProfile)
                savePlayer(migratedProfile)
                return migratedProfile
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
        profile.addHash(goldReward)

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
        profile.addHash(goldReward)

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
            scheduleEfficiencyNotification(
                efficiency: efficiency,
                threatLevel: threatLevel,
                towerDefenseStrength: towerDefenseStrength,
                activeLaneCount: activeLaneCount
            )
        }
    }

    /// Schedule notification for when efficiency is predicted to hit 0%
    private func scheduleEfficiencyNotification(
        efficiency: CGFloat,
        threatLevel: CGFloat,
        towerDefenseStrength: CGFloat,
        activeLaneCount: Int
    ) {
        // Use the same calculation as offline simulation to estimate leak rate
        // Threat grows at 10% of normal rate (0.001 per second)
        let offlineThreatGrowthRate: CGFloat = 0.001

        // Estimate average threat over next 24 hours
        let estimatedAvgThreat = threatLevel + (86400 * offlineThreatGrowthRate / 2)

        // Expected enemy HP at this threat level (base HP 20, +15% per level)
        let baseEnemyHP: CGFloat = 20
        let avgEnemyHP = baseEnemyHP * (1 + estimatedAvgThreat * 0.15)

        // Expected spawn rate (base 2s, faster at higher threat, min 0.3s)
        let baseSpawnInterval: CGFloat = 2.0
        let avgSpawnInterval = max(0.3, baseSpawnInterval / (1 + estimatedAvgThreat * 0.1))
        let enemiesPerSecond = 1.0 / avgSpawnInterval

        // Total enemy HP per second = enemies/sec * HP per enemy * lanes
        let enemyHPPerSecond = enemiesPerSecond * avgEnemyHP * CGFloat(activeLaneCount)

        // Defense strength (tower DPS)
        let defensePerSecond = towerDefenseStrength

        // If defense < offense, calculate leak rate
        guard defensePerSecond < enemyHPPerSecond else {
            // Defense is strong enough - no notification needed
            NotificationService.shared.cancelEfficiencyNotifications()
            return
        }

        // HP deficit per second
        let hpDeficitPerSecond = enemyHPPerSecond - defensePerSecond

        // One leak = one enemy getting through
        // Estimate leaks per hour based on HP deficit
        let hpDeficitPerHour = hpDeficitPerSecond * 3600
        let leaksPerHour = hpDeficitPerHour / avgEnemyHP

        // Each leak = 5% efficiency loss
        let efficiencyPerLeak: CGFloat = 0.05
        let leaksUntilZero = efficiency / efficiencyPerLeak

        // Time until 0% efficiency
        guard leaksPerHour > 0 else { return }
        let hoursUntilZero = leaksUntilZero / leaksPerHour
        let secondsUntilZero = hoursUntilZero * 3600

        // Schedule notification (min 5 minutes, max 24 hours out)
        if secondsUntilZero >= 300 && secondsUntilZero <= 86400 {
            NotificationService.shared.scheduleEfficiencyZeroNotification(
                estimatedTimeUntilZero: secondsUntilZero
            )
        }
    }

    /// Calculate offline earnings with defense simulation
    /// Returns: (hashEarned, timeAway, leaks, etc.) or nil if no earnings
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

        // Cap at 24 hours (86400 seconds) - extended from 8 hours
        let cappedTime = min(timeAway, 86400)

        // ---- OFFLINE SIMULATION ----

        // 1. Calculate threat growth (10% of normal rate = 0.001 per second)
        let offlineThreatGrowthRate: CGFloat = 0.001
        let startThreatLevel = profile.tdStats.lastThreatLevel
        let threatGrowth = CGFloat(cappedTime) * offlineThreatGrowthRate
        let endThreatLevel = startThreatLevel + threatGrowth

        // 2. Calculate defense vs. offense
        // Defense strength = sum of tower DPS (stored when player left)
        let defenseStrength = profile.tdStats.towerDefenseStrength
        let laneCount = max(1, profile.tdStats.activeLaneCount)

        // Offense strength = f(threat level, lanes)
        // Base enemy HP at threat 1 = ~20, spawn rate ~2s
        // At threat 10: HP = 20 × 2.35 = 47, spawn rate ~0.5s
        // Approximate incoming damage per second per lane
        let avgThreatLevel = (startThreatLevel + endThreatLevel) / 2
        let healthMultiplier = 1.0 + (avgThreatLevel - 1.0) * 0.15  // +15% per threat
        let spawnRateMultiplier = 1.0 + avgThreatLevel * 0.1  // Faster spawns at higher threat
        let baseEnemyHP: CGFloat = 20
        let offenseStrengthPerLane = baseEnemyHP * healthMultiplier * spawnRateMultiplier
        let totalOffenseStrength = offenseStrengthPerLane * CGFloat(laneCount)

        // 3. Calculate leak rate
        // If defense < offense, enemies leak through
        let defenseRatio = defenseStrength > 0 ? defenseStrength / totalOffenseStrength : 0
        let defenseThreshold: CGFloat = 0.8  // Need 80% of offense to hold

        var leaksPerHour: CGFloat = 0
        if defenseRatio < defenseThreshold {
            // Leaks scale with how overwhelmed defense is
            // At 0% defense: ~10 leaks per hour
            // At 50% defense: ~5 leaks per hour
            // At 80% defense: 0 leaks
            let deficitRatio = 1.0 - (defenseRatio / defenseThreshold)
            leaksPerHour = deficitRatio * 10.0
        }

        // 4. Calculate total leaks
        let hoursOffline = CGFloat(cappedTime) / 3600.0
        let totalLeaks = Int(leaksPerHour * hoursOffline)

        // 5. Calculate new efficiency
        let startLeakCounter = profile.tdStats.lastLeakCounter
        let newLeakCounter = startLeakCounter + totalLeaks
        let startEfficiency = max(0, min(100, 100 - CGFloat(startLeakCounter) * 5))
        let newEfficiency = max(0, min(100, 100 - CGFloat(newLeakCounter) * 5))

        // 6. Calculate average efficiency during offline period
        let avgEfficiency = (startEfficiency + newEfficiency) / 2

        // 7. Calculate hash earned based on average efficiency
        let baseRate = profile.tdStats.baseHashPerSecond
        let cpuMultiplier = profile.tdStats.cpuMultiplier
        let offlineMultiplier: CGFloat = 0.5  // 50% of active rate when offline

        let hashEarned = Int(cappedTime * Double(baseRate * cpuMultiplier * (avgEfficiency / 100) * offlineMultiplier))

        return OfflineEarningsResult(
            hashEarned: hashEarned,
            timeAwaySeconds: timeAway,
            cappedTimeSeconds: cappedTime,
            wasCapped: timeAway > 86400,
            leaksOccurred: totalLeaks,
            newThreatLevel: endThreatLevel,
            newEfficiency: newEfficiency,
            startEfficiency: startEfficiency
        )
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
        if let data = try? JSONEncoder().encode(state) {
            userDefaults.set(data, forKey: Keys.tdSessionState)
        }
    }

    /// Load TD session state
    func loadTDSession() -> TDSessionState? {
        guard let data = userDefaults.data(forKey: Keys.tdSessionState),
              let state = try? JSONDecoder().decode(TDSessionState.self, from: data)
        else { return nil }
        return state
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

// MARK: - Offline Earnings Result

struct OfflineEarningsResult {
    let hashEarned: Int
    let timeAwaySeconds: TimeInterval
    let cappedTimeSeconds: TimeInterval
    let wasCapped: Bool

    // Simulation Results
    let leaksOccurred: Int
    let newThreatLevel: CGFloat
    let newEfficiency: CGFloat
    let startEfficiency: CGFloat

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

    /// Whether leaks occurred during offline time
    var hadLeaks: Bool {
        return leaksOccurred > 0
    }

    /// Damage report for UI display
    var damageReport: String {
        if leaksOccurred == 0 {
            return "Defense held. No breaches detected."
        } else if newEfficiency <= 0 {
            return "System compromised. \(leaksOccurred) breaches. Efficiency: 0%"
        } else {
            return "\(leaksOccurred) breaches detected. Efficiency: \(Int(newEfficiency))%"
        }
    }
}
