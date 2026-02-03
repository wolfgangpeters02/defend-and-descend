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
    @Published var selectedArena: String = "grasslands"
    @Published var gameMode: GameMode = .boss

    /// Get the equipped Protocol object from player profile
    var selectedProtocolObject: Protocol {
        ProtocolLibrary.all.first { $0.id == currentPlayer.equippedProtocolId } ?? ProtocolLibrary.kernelPulse
    }

    // Main mode selection (Survivor vs TD)
    @Published var mainMode: MainGameMode = .survivor

    // TD-specific selections
    @Published var selectedTDMap: String = "grasslands"

    // Offline earnings
    @Published var pendingOfflineEarnings: OfflineEarningsResult?
    @Published var showWelcomeBack: Bool = false

    // FTUE (First Time User Experience)
    @Published var showIntroSequence: Bool = false

    // Game Reset Signal (for resetting embedded game controllers)
    @Published var tdResetRequested: Bool = false

    // Background save signal (for persisting game state before app suspension)
    @Published var shouldSaveGameState: Bool = false

    private init() {
        self.currentPlayer = StorageService.shared.getOrCreateDefaultPlayer()

        // Check if we should show intro sequence for new players
        if !currentPlayer.hasCompletedIntro {
            showIntroSequence = true
        } else {
            // Only check offline earnings for returning players
            checkOfflineEarnings()
        }
    }

    // MARK: - Offline Earnings (System: Reboot)

    /// Check for offline earnings on app launch/return
    func checkOfflineEarnings() {
        // Cancel any pending efficiency notifications since player has returned
        NotificationService.shared.onPlayerReturned()

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
        // Signal game controllers to save their state
        shouldSaveGameState = true
    }

    /// Called when app returns to foreground
    func onAppForeground() {
        checkOfflineEarnings()
    }

    // MARK: - FTUE (First Time User Experience)

    /// Called when player completes the intro sequence
    func completeIntroSequence() {
        updatePlayer { profile in
            profile.hasCompletedIntro = true
        }
        showIntroSequence = false

        // Activate initial tutorial hints
        TutorialHintManager.shared.activateHint(.deckCard)
        TutorialHintManager.shared.activateHint(.towerSlot)
    }

    /// Called when player places their first tower
    func recordFirstTowerPlacement() {
        guard !currentPlayer.firstTowerPlaced else { return }

        updatePlayer { profile in
            profile.firstTowerPlaced = true
        }

        // Dismiss the deck card and tower slot hints
        markHintSeen(.deckCard)
        markHintSeen(.towerSlot)
    }

    /// Mark a tutorial hint as seen (permanently dismissed)
    func markHintSeen(_ hint: TutorialHintType) {
        TutorialHintManager.shared.markHintSeen(hint)

        updatePlayer { profile in
            if !profile.tutorialHintsSeen.contains(hint.rawValue) {
                profile.tutorialHintsSeen.append(hint.rawValue)
            }
        }
    }

    /// Check milestone and potentially show hints
    func checkMilestone(hashEarned: Int) {
        // Milestone: First 500 Hash earned - show PSU upgrade hint
        if hashEarned >= 500 && !currentPlayer.tutorialHintsSeen.contains(TutorialHintType.psuUpgrade.rawValue) {
            TutorialHintManager.shared.activateHint(.psuUpgrade)
        }
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

    var unlockedArenas: [String] {
        currentPlayer.unlocks.arenas
    }

    // MARK: - Item Levels

    func weaponLevel(for id: String) -> Int {
        currentPlayer.weaponLevels[id] ?? 1
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

    func recordRun(kills: Int, time: TimeInterval, sessionHash: Int) {
        // Use the full survivor run recording with Hash rewards
        recordSurvivorRun(time: time, kills: kills, sessionHash: sessionHash, gameMode: .arena, victory: false)
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
        guard let currentIndex = protocols.firstIndex(of: currentPlayer.equippedProtocolId) else {
            currentPlayer.equippedProtocolId = protocols[0]
            return
        }
        let nextIndex = (currentIndex + 1) % protocols.count
        currentPlayer.equippedProtocolId = protocols[nextIndex]
    }

    func selectPreviousProtocol() {
        let protocols = compiledProtocolIds
        guard !protocols.isEmpty else { return }
        guard let currentIndex = protocols.firstIndex(of: currentPlayer.equippedProtocolId) else {
            currentPlayer.equippedProtocolId = protocols[0]
            return
        }
        let prevIndex = (currentIndex - 1 + protocols.count) % protocols.count
        currentPlayer.equippedProtocolId = protocols[prevIndex]
    }

    /// Legacy support
    func selectNextWeapon() { selectNextProtocol() }
    func selectPreviousWeapon() { selectPreviousProtocol() }

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
    /// - hashEarned: Actual Hash collected during session (from SessionStats)
    /// - extracted: True if player extracted (100% reward), false if died (50% reward)
    func recordSurvivorRun(
        time: TimeInterval,
        kills: Int,
        sessionHash: Int,
        gameMode: GameMode,
        victory: Bool,
        hashEarned: Int = 0,
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

            // System: Reboot - Award HASH
            // Use session-earned Hash with extraction multiplier
            let hashReward: Int
            if hashEarned > 0 {
                // New system: Use actual session Hash with extraction bonus
                hashReward = extracted ? hashEarned : hashEarned / 2
            } else {
                // Legacy fallback for old calls
                let hashFromKills = kills / 20
                let hashFromTime = Int(time / 30)
                let hashVictoryBonus = victory ? 10 : 0
                hashReward = max(1, hashFromKills + hashFromTime + hashVictoryBonus)
            }

            profile.addHash(hashReward)

            // Check level up
            while profile.xp >= PlayerProfile.xpForLevel(profile.level) {
                profile.xp -= PlayerProfile.xpForLevel(profile.level)
                profile.level += 1
            }
        }
    }

    // MARK: - Boss Rewards

    /// Difficulty-based Hash bonus
    static let difficultyHashBonus: [BossDifficulty: Int] = [
        .easy: 250,
        .normal: 500,
        .hard: 1500,
        .nightmare: 3000
    ]

    /// Record boss defeat and award blueprint using RNG loot system
    /// - Returns: BlueprintDropSystem.DropResult containing the awarded protocol (nil if no drop)
    @discardableResult
    func recordBossDefeat(
        bossId: String,
        difficulty: BossDifficulty,
        time: TimeInterval,
        kills: Int
    ) -> BlueprintDropSystem.DropResult {
        var dropResult = BlueprintDropSystem.DropResult.noDrop

        updatePlayer { profile in
            // Calculate drop BEFORE recording the kill (for first-kill detection)
            dropResult = BlueprintDropSystem.shared.calculateDrop(
                bossId: bossId,
                difficulty: difficulty,
                profile: profile
            )

            // Record the boss kill
            profile.recordBossKill(bossId, difficulty: difficulty)
            profile.survivorStats.bossesDefeated += 1
            profile.totalKills += kills

            // Award Hash based on difficulty
            let hashBonus = Self.difficultyHashBonus[difficulty] ?? 500
            profile.addHash(hashBonus)

            // Award XP
            let xpReward = 100 + (difficulty == .nightmare ? 100 : difficulty == .hard ? 50 : 0)
            profile.xp += xpReward

            // Award blueprint if one dropped
            if let protocolId = dropResult.protocolId {
                if !profile.hasBlueprint(protocolId) && !profile.isProtocolCompiled(protocolId) {
                    profile.protocolBlueprints.append(protocolId)
                    profile.recordBlueprintDrop(bossId, protocolId: protocolId)
                }
            }

            // Level up check
            while profile.xp >= PlayerProfile.xpForLevel(profile.level) {
                profile.xp -= PlayerProfile.xpForLevel(profile.level)
                profile.level += 1
            }
        }

        return dropResult
    }

}
