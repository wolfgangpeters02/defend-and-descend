import SwiftUI
import SpriteKit
import Combine

// MARK: - Embedded TD Game Controller (Observable State)

class EmbeddedTDGameController: ObservableObject {
    @Published var scene: TDGameScene?
    @Published var gameState: TDGameState?
    @Published var isDraggingFromDeck = false
    @Published var draggedWeaponType: String?
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
        scene = nil
        gameState = nil
        delegateHandler = nil
        isDraggingFromDeck = false
        draggedWeaponType = nil
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
                // Track boss state
                if newState.bossActive && !newState.bossEngaged {
                    if !(self?.isBossActive ?? false) {
                        self?.isBossActive = true
                        self?.activeBossType = newState.activeBossType
                    }
                } else if !newState.bossActive {
                    self?.isBossActive = false
                    self?.activeBossType = nil
                    self?.bossAlertDismissed = false  // Reset for next boss
                }
                // Track overclock state
                self?.overclockActive = newState.overclockActive
                self?.overclockTimeRemaining = newState.overclockTimeRemaining
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
                self?.isBossActive = true
                self?.activeBossType = bossType
                self?.bossAlertDismissed = false  // Reset so alert shows for new boss
                HapticsService.shared.play(.warning)
            }
        }
        handler.onBossReachedCPU = { [weak self] in
            DispatchQueue.main.async {
                self?.isBossActive = false
                self?.activeBossType = nil
                self?.bossAlertDismissed = false  // Reset for next boss
                HapticsService.shared.play(.defeat)
            }
        }
        handler.onBossTapped = { [weak self] in
            DispatchQueue.main.async {
                // Show difficulty selector when boss is tapped
                self?.bossAlertDismissed = false  // Reset in case alert was dismissed
                self?.showBossDifficultySelector = true
            }
        }

        // Scene size based on map dimensions
        let sceneSize = CGSize(width: state.map.width, height: state.map.height)

        let newScene = TDGameScene(size: sceneSize)
        newScene.backgroundColor = .black  // Set immediately to avoid grey flash
        newScene.scaleMode = .aspectFill
        newScene.gameStateDelegate = handler
        newScene.loadState(state, waves: waves)

        self.delegateHandler = handler
        self.gameState = state
        self.scene = newScene
    }

    // MARK: - Drag Handling

    func startDrag(weaponType: String) {
        isDraggingFromDeck = true
        draggedWeaponType = weaponType

        if let proto = ProtocolLibrary.get(weaponType) {
            let cost = TowerSystem.towerPlacementCost(rarity: proto.rarity)
            canAffordDraggedTower = (gameState?.hash ?? 0) >= cost
        }

        scene?.enterPlacementMode(weaponType: weaponType)
        HapticsService.shared.play(.selection)
    }

    func updateDrag(_ value: DragGesture.Value, geometry: GeometryProxy) {
        dragPosition = value.location

        guard let state = gameState else { return }

        let gamePos = convertScreenToGame(dragPosition, geometry: geometry)
        var nearest: TowerSlot?

        // Use camera scale for snap distance
        // When zoomed OUT (scale > 1), we need LARGER snap distance in game units
        // because game units appear smaller on screen
        let cameraScale = scene?.cameraScale ?? 1.0
        // Reduced snap distance to prevent confusing placement (was 200 for large maps)
        let baseSnapDistance: CGFloat = state.map.width > 2000 ? BalanceConfig.TDSession.largeMapSnapScreenDistance : BalanceConfig.TDSession.baseSnapScreenDistance
        // Divide by scale so zoomed out = larger snap area
        let snapDistanceInGameUnits: CGFloat = baseSnapDistance / min(cameraScale, 1.0) * max(cameraScale, 1.0)

        var minDistance: CGFloat = snapDistanceInGameUnits

        for slot in state.towerSlots where !slot.occupied {
            let dx = slot.x - gamePos.x
            let dy = slot.y - gamePos.y
            let distance = sqrt(dx*dx + dy*dy)
            if distance < minDistance {
                minDistance = distance
                nearest = slot
            }
        }

        if nearestValidSlot?.id != nearest?.id {
            nearestValidSlot = nearest
            scene?.highlightNearestSlot(nearest, canAfford: canAffordDraggedTower)

            if nearest != nil && canAffordDraggedTower {
                HapticsService.shared.play(.slotSnap)
            }
        }
    }

    func endDrag(profile: PlayerProfile) {
        scene?.exitPlacementMode()

        defer {
            isDraggingFromDeck = false
            draggedWeaponType = nil
            nearestValidSlot = nil
        }

        if let weaponType = draggedWeaponType,
           let slot = nearestValidSlot,
           canAffordDraggedTower {
            scene?.placeTower(weaponType: weaponType, slotId: slot.id, profile: profile)
            HapticsService.shared.play(.towerPlace)
        }
    }

    // MARK: - Coordinate Conversion

    func convertScreenToGame(_ point: CGPoint, geometry: GeometryProxy) -> CGPoint {
        // Use scene's camera-aware conversion if available
        if let scene = scene {
            return scene.convertScreenToGame(screenPoint: point, viewSize: geometry.size)
        }

        // Fallback: simple conversion without camera
        let gameWidth = gameState?.map.width ?? 800
        let gameHeight = gameState?.map.height ?? 600
        let screenWidth = geometry.size.width
        let screenHeight = geometry.size.height
        let scaleX = screenWidth / gameWidth
        let scaleY = screenHeight / gameHeight
        let scale = max(scaleX, scaleY)
        let scaledWidth = gameWidth * scale
        let scaledHeight = gameHeight * scale
        let offsetX = (screenWidth - scaledWidth) / 2
        let offsetY = (screenHeight - scaledHeight) / 2

        return CGPoint(
            x: (point.x - offsetX) / scale,
            y: (point.y - offsetY) / scale
        )
    }

    func convertGameToScreen(_ point: CGPoint, geometry: GeometryProxy) -> CGPoint {
        // Use scene's camera-aware conversion if available
        if let scene = scene {
            return scene.convertGameToScreen(gamePoint: point, viewSize: geometry.size)
        }

        // Fallback: simple conversion without camera
        let gameWidth = gameState?.map.width ?? 800
        let gameHeight = gameState?.map.height ?? 600
        let screenWidth = geometry.size.width
        let screenHeight = geometry.size.height
        let scaleX = screenWidth / gameWidth
        let scaleY = screenHeight / gameHeight
        let scale = max(scaleX, scaleY)
        let scaledWidth = gameWidth * scale
        let scaledHeight = gameHeight * scale
        let offsetX = (screenWidth - scaledWidth) / 2
        let offsetY = (screenHeight - scaledHeight) / 2

        return CGPoint(
            x: point.x * scale + offsetX,
            y: point.y * scale + offsetY
        )
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
        scene?.recoverFromFreeze(restoreToEfficiency: BalanceConfig.Freeze.recoveryTargetEfficiency)
    }

    /// Unlock a sector (decrypt it)
    func unlockSector(_ sectorId: String, appState: AppState) -> Bool {
        let result = SectorUnlockSystem.shared.performUnlockTransaction(sectorId, appState: appState)

        if result.success {
            // Play celebration
            HapticsService.shared.play(.legendary)

            // Refresh mega-board visuals
            scene?.refreshMegaBoardVisuals()

            // Close panel
            showSectorUnlockPanel = false
            selectedSectorForUnlock = nil
            return true
        } else {
            HapticsService.shared.play(.error)
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
