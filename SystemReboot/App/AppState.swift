import SwiftUI
import Combine

// MARK: - App State

class AppState: ObservableObject {
    static let shared = AppState()

    @Published var currentPlayer: PlayerProfile
    @Published var selectedArena: String = ArenaID.starter.rawValue
    @Published var gameMode: GameMode = .boss

    /// Get the equipped Protocol object from player profile
    var selectedProtocolObject: Protocol {
        ProtocolLibrary.all.first { $0.id == currentPlayer.equippedProtocolId } ?? ProtocolLibrary.kernelPulse
    }

    // Offline earnings
    @Published var pendingOfflineEarnings: OfflineEarningsResult?
    @Published var showWelcomeBack: Bool = false

    // FTUE (First Time User Experience)
    @Published var showIntroSequence: Bool = false

    // Game Reset Signal (for resetting embedded game controllers)
    @Published var tdResetRequested: Bool = false

    // Background save signal (for persisting game state before app suspension)
    @Published var shouldSaveGameState: Bool = false

    // Debug overlay (developer preference, persisted via UserDefaults)
    @Published var showDebugOverlay: Bool = UserDefaults.standard.bool(forKey: "debugOverlayEnabled") {
        didSet { UserDefaults.standard.set(showDebugOverlay, forKey: "debugOverlayEnabled") }
    }

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
            // Only show if meaningful earnings
            if earnings.hashEarned >= BalanceConfig.OfflineEarnings.minimumDisplayThreshold {
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

    // MARK: - Player Management
    // Note: FTUE methods moved to AppState+Tutorial.swift

    func refreshPlayer() {
        currentPlayer = StorageService.shared.getOrCreateDefaultPlayer()
    }

    func updatePlayer(_ updates: (inout PlayerProfile) -> Void) {
        updates(&currentPlayer)
        StorageService.shared.savePlayer(currentPlayer)
    }

    // MARK: - Unlocked Items (Protocol-based unified system)

    /// Compiled (unlocked) Protocol IDs available for use in any game mode
    var compiledProtocolIds: [String] {
        currentPlayer.compiledProtocols
    }

    var unlockedArenas: [String] {
        currentPlayer.unlocks.arenas
    }

    // MARK: - Stats

    func recordRun(kills: Int, time: TimeInterval, sessionHash: Int) {
        // Use the full survivor run recording with Hash rewards
        recordSurvivorRun(time: time, kills: kills, sessionHash: sessionHash, gameMode: .survival, victory: false)
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
            updatePlayer { $0.equippedProtocolId = protocols[0] }
            return
        }
        let nextIndex = (currentIndex + 1) % protocols.count
        updatePlayer { $0.equippedProtocolId = protocols[nextIndex] }
    }

    func selectPreviousProtocol() {
        let protocols = compiledProtocolIds
        guard !protocols.isEmpty else { return }
        guard let currentIndex = protocols.firstIndex(of: currentPlayer.equippedProtocolId) else {
            updatePlayer { $0.equippedProtocolId = protocols[0] }
            return
        }
        let prevIndex = (currentIndex - 1 + protocols.count) % protocols.count
        updatePlayer { $0.equippedProtocolId = protocols[prevIndex] }
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

    // MARK: - TD Mode Support

    /// Record TD game result
    func recordTDResult(wavesCompleted: Int, enemiesKilled: Int, hashEarned: Int, victory: Bool) {
        updatePlayer { profile in
            GameRewardService.applyTDResult(
                to: &profile,
                wavesCompleted: wavesCompleted,
                enemiesKilled: enemiesKilled,
                towersPlaced: 0,
                hashEarned: hashEarned,
                victory: victory
            )
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
            GameRewardService.applySurvivorResult(
                to: &profile,
                time: time,
                kills: kills,
                gameMode: gameMode,
                victory: victory,
                hashEarned: hashEarned,
                extracted: extracted
            )
        }
    }

}
