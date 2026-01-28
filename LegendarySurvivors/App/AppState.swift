import SwiftUI
import Combine

// MARK: - Main Game Mode Selection

enum MainGameMode: String, CaseIterable {
    case survivor = "Survivor"
    case towerDefense = "Tower Defense"

    var description: String {
        switch self {
        case .survivor: return "Arena, Dungeon & Boss fights"
        case .towerDefense: return "Place towers, defend the core"
        }
    }

    var icon: String {
        switch self {
        case .survivor: return "figure.run"
        case .towerDefense: return "building.columns.fill"
        }
    }
}

// MARK: - App State

class AppState: ObservableObject {
    static let shared = AppState()

    @Published var currentPlayer: PlayerProfile
    @Published var selectedProtocol: String = "kernel_pulse"  // Protocol ID (unified weapon system)
    @Published var selectedPowerup: String = "tank"
    @Published var selectedArena: String = "grasslands"
    @Published var gameMode: GameMode = .arena

    /// Get the selected Protocol object
    var selectedProtocolObject: Protocol {
        ProtocolLibrary.all.first { $0.id == selectedProtocol } ?? ProtocolLibrary.kernelPulse
    }

    // Main mode selection (Survivor vs TD)
    @Published var mainMode: MainGameMode = .survivor

    // TD-specific selections
    @Published var selectedTDMap: String = "grasslands"

    // Offline earnings
    @Published var pendingOfflineEarnings: OfflineEarningsResult?
    @Published var showWelcomeBack: Bool = false

    private init() {
        self.currentPlayer = StorageService.shared.getOrCreateDefaultPlayer()
        checkOfflineEarnings()
    }

    // MARK: - Offline Earnings (System: Reboot)

    /// Check for offline earnings on app launch/return
    func checkOfflineEarnings() {
        if let earnings = StorageService.shared.calculateOfflineEarnings() {
            // Only show if meaningful earnings (at least 10 Hash)
            if earnings.hashEarned >= 10 {
                pendingOfflineEarnings = earnings
                showWelcomeBack = true
            }
        }
    }

    /// Collect offline earnings
    func collectOfflineEarnings() {
        guard let earnings = pendingOfflineEarnings else { return }

        // Apply earnings to player
        StorageService.shared.applyOfflineEarnings(earnings)
        refreshPlayer()

        // Clear pending
        pendingOfflineEarnings = nil
        showWelcomeBack = false
    }

    /// Called when app goes to background
    func onAppBackground() {
        StorageService.shared.saveLastActiveTime()
    }

    /// Called when app returns to foreground
    func onAppForeground() {
        checkOfflineEarnings()
    }

    // MARK: - Player Management

    func refreshPlayer() {
        currentPlayer = StorageService.shared.getOrCreateDefaultPlayer()
    }

    func updatePlayer(_ updates: (inout PlayerProfile) -> Void) {
        updates(&currentPlayer)
        StorageService.shared.savePlayer(currentPlayer)
    }

    // MARK: - Unlocked Items (Protocol-based unified system)

    /// Compiled (unlocked) Protocol IDs available for use as weapons/towers
    var compiledProtocolIds: [String] {
        currentPlayer.compiledProtocols
    }

    /// Legacy support - maps to compiled protocols
    var unlockedWeapons: [String] {
        compiledProtocolIds
    }

    var unlockedPowerups: [String] {
        currentPlayer.unlocks.powerups
    }

    var unlockedArenas: [String] {
        currentPlayer.unlocks.arenas
    }

    // MARK: - Item Levels

    func weaponLevel(for id: String) -> Int {
        currentPlayer.weaponLevels[id] ?? 1
    }

    func powerupLevel(for id: String) -> Int {
        currentPlayer.powerupLevels[id] ?? 1
    }

    // MARK: - Stats

    func recordRunEnd(time: TimeInterval, kills: Int, victory: Bool) {
        updatePlayer { profile in
            profile.totalRuns += 1
            profile.totalKills += kills
            if time > profile.bestTime {
                profile.bestTime = time
            }
        }
    }

    func recordRun(kills: Int, time: TimeInterval, sessionData: Int) {
        // Use the full survivor run recording with Data rewards
        recordSurvivorRun(time: time, kills: kills, sessionData: sessionData, gameMode: .arena, victory: false)
    }

    func unlockItem(category: String, id: String, rarity: Rarity) {
        updatePlayer { profile in
            _ = LevelingSystem.unlockItem(profile: &profile, category: category, id: id)
            if rarity == .legendary {
                profile.legendariesUnlocked += 1
            }
        }
    }

    func levelUpItem(category: String, id: String) {
        updatePlayer { profile in
            _ = LevelingSystem.levelUpItem(profile: &profile, category: category, id: id)
        }
    }

    // MARK: - Selection Helpers

    func selectNextProtocol() {
        let protocols = compiledProtocolIds
        guard !protocols.isEmpty else { return }
        guard let currentIndex = protocols.firstIndex(of: selectedProtocol) else {
            selectedProtocol = protocols[0]
            return
        }
        let nextIndex = (currentIndex + 1) % protocols.count
        selectedProtocol = protocols[nextIndex]
    }

    func selectPreviousProtocol() {
        let protocols = compiledProtocolIds
        guard !protocols.isEmpty else { return }
        guard let currentIndex = protocols.firstIndex(of: selectedProtocol) else {
            selectedProtocol = protocols[0]
            return
        }
        let prevIndex = (currentIndex - 1 + protocols.count) % protocols.count
        selectedProtocol = protocols[prevIndex]
    }

    /// Legacy support
    func selectNextWeapon() { selectNextProtocol() }
    func selectPreviousWeapon() { selectPreviousProtocol() }

    func selectNextPowerup() {
        guard let currentIndex = unlockedPowerups.firstIndex(of: selectedPowerup) else { return }
        let nextIndex = (currentIndex + 1) % unlockedPowerups.count
        selectedPowerup = unlockedPowerups[nextIndex]
    }

    func selectPreviousPowerup() {
        guard let currentIndex = unlockedPowerups.firstIndex(of: selectedPowerup) else { return }
        let prevIndex = (currentIndex - 1 + unlockedPowerups.count) % unlockedPowerups.count
        selectedPowerup = unlockedPowerups[prevIndex]
    }

    func selectNextArena() {
        guard let currentIndex = unlockedArenas.firstIndex(of: selectedArena) else { return }
        let nextIndex = (currentIndex + 1) % unlockedArenas.count
        selectedArena = unlockedArenas[nextIndex]
    }

    func selectPreviousArena() {
        guard let currentIndex = unlockedArenas.firstIndex(of: selectedArena) else { return }
        let prevIndex = (currentIndex - 1 + unlockedArenas.count) % unlockedArenas.count
        selectedArena = unlockedArenas[prevIndex]
    }

    // MARK: - Synergy Preview

    var currentSynergy: (name: String, description: String)? {
        SynergySystem.getSynergy(weaponType: selectedProtocol, powerupType: selectedPowerup)
    }

    // MARK: - TD Mode Support

    /// Unlocked TD maps (same as arenas)
    var unlockedTDMaps: [String] {
        currentPlayer.unlocks.arenas.filter { tdSupportedMaps.contains($0) }
    }

    /// Maps that support TD mode
    private var tdSupportedMaps: [String] {
        ["grasslands", "volcano", "ice_cave", "castle", "space", "temple"]
    }

    /// Get unlocked towers (same as weapons)
    var unlockedTowers: [String] {
        currentPlayer.unlocks.weapons
    }

    func selectNextTDMap() {
        guard let currentIndex = unlockedTDMaps.firstIndex(of: selectedTDMap) else { return }
        let nextIndex = (currentIndex + 1) % unlockedTDMaps.count
        selectedTDMap = unlockedTDMaps[nextIndex]
    }

    func selectPreviousTDMap() {
        guard let currentIndex = unlockedTDMaps.firstIndex(of: selectedTDMap) else { return }
        let prevIndex = (currentIndex - 1 + unlockedTDMaps.count) % unlockedTDMaps.count
        selectedTDMap = unlockedTDMaps[prevIndex]
    }

    /// Record TD game result
    func recordTDResult(wavesCompleted: Int, enemiesKilled: Int, goldEarned: Int, victory: Bool) {
        updatePlayer { profile in
            profile.tdStats.gamesPlayed += 1
            if victory {
                profile.tdStats.gamesWon += 1
            }
            profile.tdStats.totalWavesCompleted += wavesCompleted
            profile.tdStats.highestWave = max(profile.tdStats.highestWave, wavesCompleted)
            profile.tdStats.totalTDKills += enemiesKilled

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
        }
    }

    /// Record survivor run result with unified progression
    /// Active/Debugger mode is the primary source of Data currency
    /// - dataEarned: Actual Data collected during session (from SessionStats)
    /// - extracted: True if player extracted (100% reward), false if died (50% reward)
    func recordSurvivorRun(
        time: TimeInterval,
        kills: Int,
        sessionData: Int,
        gameMode: GameMode,
        victory: Bool,
        dataEarned: Int = 0,
        extracted: Bool = false
    ) {
        updatePlayer { profile in
            profile.totalRuns += 1
            profile.totalKills += kills

            if time > profile.bestTime {
                profile.bestTime = time
            }

            // Update mode-specific stats
            if gameMode == .survival || gameMode == .arena {
                profile.survivorStats.arenaRuns += 1
            } else if gameMode == .boss || gameMode == .dungeon {
                profile.survivorStats.dungeonRuns += 1
                if victory {
                    profile.survivorStats.dungeonsCompleted += 1
                    profile.survivorStats.bossesDefeated += 1
                }
            }

            profile.survivorStats.totalSurvivorKills += kills
            if time > profile.survivorStats.longestSurvival {
                profile.survivorStats.longestSurvival = time
            }

            // Award XP
            let xpReward = kills + Int(time / 10) + (victory || extracted ? 25 : 0)
            profile.xp += xpReward

            // System: Reboot - Award DATA
            // Use session-earned Data with extraction multiplier
            let dataReward: Int
            if dataEarned > 0 {
                // New system: Use actual session Data with extraction bonus
                dataReward = extracted ? dataEarned : dataEarned / 2
            } else {
                // Legacy fallback for old calls
                let dataFromKills = kills / 20
                let dataFromTime = Int(time / 30)
                let dataVictoryBonus = victory ? 10 : 0
                dataReward = max(1, dataFromKills + dataFromTime + dataVictoryBonus)
            }

            profile.data += dataReward

            // Check level up
            while profile.xp >= PlayerProfile.xpForLevel(profile.level) {
                profile.xp -= PlayerProfile.xpForLevel(profile.level)
                profile.level += 1
            }
        }
    }

    // MARK: - Boss Rewards

    /// Boss-to-Protocol reward mapping
    static let bossRewards: [String: [String]] = [
        "cyberboss": ["burst_protocol", "trace_route"],      // Rogue Process drops ranged protocols
        "void_harbinger": ["fork_bomb", "overflow"],          // Memory Leak drops advanced protocols
        "frost_titan": ["ice_shard", "root_access"],          // (Future) Frozen Thread
        "inferno_lord": ["null_pointer"]                      // (Future) Thermal Throttle
    ]

    /// Difficulty-based Data bonus
    static let difficultyDataBonus: [BossDifficulty: Int] = [
        .normal: 50,
        .hard: 150,
        .nightmare: 300
    ]

    /// Record boss defeat and award blueprint
    /// - Returns: The protocol ID that was awarded (nil if already owned)
    @discardableResult
    func recordBossDefeat(
        bossId: String,
        difficulty: BossDifficulty,
        time: TimeInterval,
        kills: Int
    ) -> String? {
        var awardedProtocol: String?

        updatePlayer { profile in
            profile.survivorStats.bossesDefeated += 1
            profile.totalKills += kills

            // Award Data based on difficulty
            let dataBonus = Self.difficultyDataBonus[difficulty] ?? 50
            profile.data += dataBonus

            // Award XP
            let xpReward = 100 + (difficulty == .nightmare ? 100 : difficulty == .hard ? 50 : 0)
            profile.xp += xpReward

            // Award blueprint (if not already owned)
            if let possibleRewards = Self.bossRewards[bossId] {
                for protocolId in possibleRewards {
                    // Check if player doesn't already have blueprint or compiled
                    if !profile.hasBlueprint(protocolId) && !profile.isProtocolCompiled(protocolId) {
                        profile.protocolBlueprints.append(protocolId)
                        awardedProtocol = protocolId
                        print("[Boss] Awarded blueprint: \(protocolId)")
                        break
                    }
                }

                // Nightmare difficulty: Award rare blueprint even if common ones owned
                if awardedProtocol == nil && difficulty == .nightmare {
                    // Try to give a random rare protocol they don't have
                    let rareProtocols = ["null_pointer", "overflow", "root_access"]
                    for protocolId in rareProtocols.shuffled() {
                        if !profile.hasBlueprint(protocolId) && !profile.isProtocolCompiled(protocolId) {
                            profile.protocolBlueprints.append(protocolId)
                            awardedProtocol = protocolId
                            print("[Boss] Nightmare bonus blueprint: \(protocolId)")
                            break
                        }
                    }
                }
            }

            // Level up check
            while profile.xp >= PlayerProfile.xpForLevel(profile.level) {
                profile.xp -= PlayerProfile.xpForLevel(profile.level)
                profile.level += 1
            }
        }

        return awardedProtocol
    }

}
