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
    @Published var selectedWeapon: String = "bow"
    @Published var selectedPowerup: String = "tank"
    @Published var selectedArena: String = "grasslands"
    @Published var gameMode: GameMode = .arena

    // Main mode selection (Survivor vs TD)
    @Published var mainMode: MainGameMode = .survivor

    // TD-specific selections
    @Published var selectedTDMap: String = "grasslands"

    private init() {
        self.currentPlayer = StorageService.shared.getOrCreateDefaultPlayer()
    }

    // MARK: - Player Management

    func refreshPlayer() {
        currentPlayer = StorageService.shared.getOrCreateDefaultPlayer()
    }

    func updatePlayer(_ updates: (inout PlayerProfile) -> Void) {
        updates(&currentPlayer)
        StorageService.shared.savePlayer(currentPlayer)
    }

    // MARK: - Unlocked Items

    var unlockedWeapons: [String] {
        currentPlayer.unlocks.weapons
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

    func recordRun(kills: Int, time: TimeInterval, coins: Int) {
        updatePlayer { profile in
            profile.totalRuns += 1
            profile.totalKills += kills
            if time > profile.bestTime {
                profile.bestTime = time
            }
        }
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

    func selectNextWeapon() {
        guard let currentIndex = unlockedWeapons.firstIndex(of: selectedWeapon) else { return }
        let nextIndex = (currentIndex + 1) % unlockedWeapons.count
        selectedWeapon = unlockedWeapons[nextIndex]
    }

    func selectPreviousWeapon() {
        guard let currentIndex = unlockedWeapons.firstIndex(of: selectedWeapon) else { return }
        let prevIndex = (currentIndex - 1 + unlockedWeapons.count) % unlockedWeapons.count
        selectedWeapon = unlockedWeapons[prevIndex]
    }

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
        SynergySystem.getSynergy(weaponType: selectedWeapon, powerupType: selectedPowerup)
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
            profile.gold += goldReward

            // Check level up
            while profile.xp >= PlayerProfile.xpForLevel(profile.level) {
                profile.xp -= PlayerProfile.xpForLevel(profile.level)
                profile.level += 1
            }
        }
    }

    /// Record survivor run result with unified progression
    func recordSurvivorRun(time: TimeInterval, kills: Int, coins: Int, gameMode: GameMode, victory: Bool) {
        updatePlayer { profile in
            profile.totalRuns += 1
            profile.totalKills += kills

            if time > profile.bestTime {
                profile.bestTime = time
            }

            // Update mode-specific stats
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
            let goldReward = coins / 10

            profile.xp += xpReward
            profile.gold += goldReward

            // Check level up
            while profile.xp >= PlayerProfile.xpForLevel(profile.level) {
                profile.xp -= PlayerProfile.xpForLevel(profile.level)
                profile.level += 1
            }
        }
    }
}
