import SwiftUI
import SpriteKit
import Combine

// MARK: - Embedded TD Game Controller (Observable State)

class EmbeddedTDGameController: ObservableObject {
    @Published var scene: TDGameScene?
    @Published var gameState: TDGameState?
    @Published var isDraggingFromDeck = false
    @Published var draggedProtocolId: String?
    @Published var dragPosition: CGPoint = .zero
    @Published var nearestValidSlot: TowerSlot?
    @Published var canAffordDraggedTower = false
    @Published var isSystemFrozen = false  // True when efficiency hits 0%
    @Published var showSectorUnlockPanel = false
    @Published var selectedSectorForUnlock: String?
    @Published var powerShakeTriggered = false  // Triggers shake animation on power indicator
    @Published var selectedTowerId: String?  // Selected tower for upgrade panel

    // Boss system state
    @Published var isBossActive = false
    @Published var activeBossType: String?
    @Published var showBossDifficultySelector = false
    @Published var bossAlertDismissed = false  // User dismissed alert to let boss pass
    @Published var overclockActive = false
    @Published var overclockTimeRemaining: TimeInterval = 0

    // Boss fight state (for launching boss fight fullscreen)
    @Published var showBossFight = false
    @Published var selectedBossDifficulty: BossDifficulty = .normal

    // Camera tutorial state (FTUE)
    @Published var showCameraTutorial = false

    private var delegateHandler: EmbeddedTDDelegateHandler?
    private var cancellables = Set<AnyCancellable>()
    private var lastHashSyncTime: Date = .distantPast

    init() {
        // Observe reset requests from AppState (triggered by account reset)
        AppState.shared.$tdResetRequested
            .dropFirst()
            .filter { $0 }
            .sink { [weak self] _ in
                self?.reset()
                // Reset the flag after handling
                DispatchQueue.main.async {
                    AppState.shared.tdResetRequested = false
                }
            }
            .store(in: &cancellables)

        // Observe save requests from AppState (triggered by app going to background)
        AppState.shared.$shouldSaveGameState
            .dropFirst()
            .filter { $0 }
            .sink { [weak self] _ in
                self?.saveSessionState()
                // Reset the flag after handling
                DispatchQueue.main.async {
                    AppState.shared.shouldSaveGameState = false
                }
            }
            .store(in: &cancellables)
    }

    /// Save current game state to persistent storage
    func saveSessionState() {
        guard let state = gameState else { return }
        StorageService.shared.saveTDSession(TDSessionState.from(gameState: state))
    }

    /// Reset game state (called on account reset)
    func reset() {
        scene?.isPaused = true
        TDGameScene.resetCaches()
        scene = nil
        gameState = nil
        delegateHandler = nil
        isDraggingFromDeck = false
        draggedProtocolId = nil
        nearestValidSlot = nil
        isSystemFrozen = false
        isBossActive = false
        activeBossType = nil
        overclockActive = false
        selectedTowerId = nil
    }

    func setup(screenSize: CGSize, playerProfile: PlayerProfile) {
        guard scene == nil else { return }

        // Use the new Motherboard City map (4000x4000 PCB canvas)
        guard var state = TDGameStateFactory.createMotherboardGameState(playerProfile: playerProfile) else {
            return
        }

        // Restore saved session if one exists (towers, slots, resources)
        if let savedSession = StorageService.shared.loadTDSession() {
            savedSession.apply(to: &state)
        }

        let waves = WaveSystem.generateWaves(totalWaves: BalanceConfig.TDSession.totalWaves)

        let handler = EmbeddedTDDelegateHandler()
        handler.onGameStateUpdated = { [weak self] newState in
            DispatchQueue.main.async {
                self?.gameState = newState
                // Track freeze state changes
                if newState.isSystemFrozen && !(self?.isSystemFrozen ?? false) {
                    self?.isSystemFrozen = true
                }
                // Track boss + overclock state (delegated to +BossState extension)
                self?.syncBossState(from: newState)
                // Inject debug hash into live game state if pending
                #if DEBUG
                if AppState.shared.debugHashPending > 0 {
                    self?.scene?.state?.hash += AppState.shared.debugHashPending
                    AppState.shared.debugHashPending = 0
                }
                #endif

                // Sync hash to player profile (throttled to once per second to avoid excessive UserDefaults writes)
                if newState.hash != AppState.shared.currentPlayer.hash {
                    let now = Date()
                    if now.timeIntervalSince(self?.lastHashSyncTime ?? .distantPast) >= BalanceConfig.TDSession.hashSyncInterval {
                        self?.lastHashSyncTime = now
                        AppState.shared.updatePlayer { profile in
                            profile.hash = newState.hash
                        }
                    }
                }
            }
        }
        handler.onSystemFrozen = { [weak self] in
            DispatchQueue.main.async {
                self?.isSystemFrozen = true
            }
        }
        handler.onGateSelected = { [weak self] sectorId in
            DispatchQueue.main.async {
                self?.selectedSectorForUnlock = sectorId
                self?.showSectorUnlockPanel = true
            }
        }
        handler.onGetUnlockedSectorIds = {
            // Get unlocked sectors from AppState (which holds current player)
            // PSU is always included as the starter sector
            var sectors = AppState.shared.currentPlayer.unlockedSectorIds
            sectors.insert(SectorID.power.rawValue)  // Ensure PSU is always unlocked
            return sectors
        }
        handler.onPlacementFailed = { [weak self] reason in
            DispatchQueue.main.async {
                // Trigger power shake for insufficient power
                if case .insufficientPower = reason {
                    self?.powerShakeTriggered = true
                    // Reset after animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self?.powerShakeTriggered = false
                    }
                }
            }
        }
        handler.onTowerSelected = { [weak self] towerId in
            DispatchQueue.main.async {
                self?.selectedTowerId = towerId
            }
        }
        handler.onBossSpawned = { [weak self] bossType in
            DispatchQueue.main.async {
                self?.handleBossSpawned(type: bossType)
            }
        }
        handler.onBossReachedCPU = { [weak self] in
            DispatchQueue.main.async {
                self?.handleBossReachedCPU()
            }
        }
        handler.onBossTapped = { [weak self] in
            DispatchQueue.main.async {
                self?.handleBossTapped()
            }
        }

        // Scene size based on map dimensions
        let sceneSize = CGSize(width: state.map.width, height: state.map.height)

        let newScene = TDGameScene(size: sceneSize)
        newScene.backgroundColor = .black  // Set immediately to avoid grey flash
        newScene.scaleMode = .aspectFill
        newScene.gameStateDelegate = handler

        // FTUE: Camera tutorial for new players
        let isNewPlayer = !playerProfile.hasCompletedIntro
        if isNewPlayer {
            newScene.cameraController.suppressIntroAnimation = true
            state.isPaused = true
            state.idleSpawnEnabled = false  // Tutorial controls spawning; re-enabled after tower placement
        }

        newScene.loadState(state, waves: waves)

        self.delegateHandler = handler
        self.gameState = state
        self.scene = newScene

        if isNewPlayer {
            showCameraTutorial = true
        }
    }

    /// Complete the camera tutorial
    func completeCameraTutorial() {
        showCameraTutorial = false

        // Mark intro as completed
        AppState.shared.completeIntroSequence()

        // Spawn batch 2: mixed weak enemies for satisfying first kills
        spawnTutorialBatch2()

        // Activate tutorial hints for tower placement
        TutorialHintManager.shared.activateHint(.deckCard)
        TutorialHintManager.shared.activateHint(.towerSlot)
    }

    /// Spawn batch 2 tutorial enemies with staggered timing and enable idle spawning
    private func spawnTutorialBatch2() {
        guard let scene = scene else { return }

        let spawnPoint = CGPoint(x: 4200, y: 2100) // PSU spawn edge
        let enemies = TutorialSpawnSystem.createBatch2Enemies(spawnPoint: spawnPoint, pathIndex: 0)
        let stagger = BalanceConfig.Tutorial.batch2SpawnStagger
        let grace = BalanceConfig.Tutorial.batch2GracePeriod

        for (index, enemy) in enemies.enumerated() {
            let delay = grace + stagger * Double(index)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.scene?.state?.enemies.append(enemy)
                scene.spawnPortalAnimation(at: scene.convertToScene(spawnPoint))
            }
        }

        // Enable idle spawning with short grace period after batch 2
        scene.state?.idleSpawnEnabled = true
        scene.state?.idleSpawnTimer = BalanceConfig.Tutorial.postTutorialSpawnTimer
    }

    // MARK: - System Freeze Recovery

    /// Flush Memory: Pay Hash percentage to restore efficiency
    func flushMemory() {
        guard isSystemFrozen else { return }
        isSystemFrozen = false
        scene?.recoverFromFreeze(restoreToEfficiency: BalanceConfig.Freeze.recoveryTargetEfficiency)
    }

    /// Manual Override complete: Restore efficiency without cost
    func manualOverrideSuccess() {
        guard isSystemFrozen else { return }
        isSystemFrozen = false
        scene?.recoverFromFreeze(restoreToEfficiency: BalanceConfig.Freeze.manualOverrideRecoveryEfficiency)
    }

    /// Unlock a sector (decrypt it)
    func unlockSector(_ sectorId: String, appState: AppState) -> Bool {
        let result = SectorUnlockSystem.shared.performUnlockTransaction(sectorId, appState: appState)

        if result.success {
            // Play celebration
            HapticsService.shared.play(.legendary)
            AudioManager.shared.play(.victory)

            // Refresh mega-board visuals
            scene?.refreshMegaBoardVisuals()

            // Close panel
            showSectorUnlockPanel = false
            selectedSectorForUnlock = nil
            return true
        } else {
            HapticsService.shared.play(.error)
            AudioManager.shared.play(.uiDeny)
            return false
        }
    }

    /// Dismiss sector unlock panel
    func dismissSectorUnlockPanel() {
        showSectorUnlockPanel = false
        selectedSectorForUnlock = nil
    }
}

// MARK: - Embedded TD Delegate Handler

private class EmbeddedTDDelegateHandler: TDGameSceneDelegate {
    var onGameStateUpdated: ((TDGameState) -> Void)?
    var onSystemFrozen: (() -> Void)?
    var onGateSelected: ((String) -> Void)?
    var onGetUnlockedSectorIds: (() -> Set<String>)?
    var onPlacementFailed: ((TowerPlacementResult) -> Void)?
    var onTowerSelected: ((String?) -> Void)?
    var onBossSpawned: ((String) -> Void)?
    var onBossReachedCPU: (() -> Void)?
    var onBossTapped: (() -> Void)?

    func gameStateUpdated(_ state: TDGameState) {
        onGameStateUpdated?(state)
    }

    func slotSelected(_ slotId: String) {
        // Not used in embedded view - drag-to-place only
    }

    func towerSelected(_ towerId: String?) {
        onTowerSelected?(towerId)
    }

    func gateSelected(_ sectorId: String) {
        onGateSelected?(sectorId)
    }

    func systemFrozen() {
        onSystemFrozen?()
    }

    func getUnlockedSectorIds() -> Set<String> {
        // Get unlocked sectors from player profile via callback
        // PSU (power) is always unlocked as the starter sector
        return onGetUnlockedSectorIds?() ?? Set([SectorID.power.rawValue])
    }

    func spawnPointTapped(_ lane: SectorLane) {
        // Trigger sector unlock panel for the lane's sector
        onGateSelected?(lane.sectorId)
    }

    func placementFailed(_ reason: TowerPlacementResult) {
        onPlacementFailed?(reason)
    }

    func bossSpawned(type: String) {
        DispatchQueue.main.async { [weak self] in
            self?.onBossSpawned?(type)
        }
    }

    func bossReachedCPU() {
        DispatchQueue.main.async { [weak self] in
            self?.onBossReachedCPU?()
        }
    }

    func bossTapped() {
        DispatchQueue.main.async { [weak self] in
            self?.onBossTapped?()
        }
    }
}
