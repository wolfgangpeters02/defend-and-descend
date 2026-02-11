import SwiftUI
import SpriteKit

// MARK: - Motherboard View (Idle Mode)
// Main SwiftUI view for System Defense / Idle mode
// You are an AI protecting a computer system from viruses
// Implements progressive disclosure: show only what's needed, when it's needed
//
// Extensions:
//   TDGameContainerView+Overlays.swift  — Zero-Day, Boss, Overclock, Freeze overlays
//   TDGameContainerView+HUD.swift       — Top bar, wave controls, CPU upgrade
//   TDGameContainerView+Towers.swift    — Tower deck, drag preview, tower info panel
//   TDGameContainerView+Panels.swift    — Pause, game over, sector unlock/management

struct TDGameContainerView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @State var gameState: TDGameState?
    @State var scene: TDGameScene?
    @State private var delegateHandler: TDGameSceneDelegateHandler?
    @State var selectedSlotId: String?
    @State var selectedTowerId: String?
    @State var showTowerMenu = false
    @State var showGameOver = false
    @State var isPaused = false

    // Drag-from-deck state (progressive disclosure - grid only visible during drag)
    @State var isDraggingFromDeck = false
    @State var draggedWeaponType: String?
    @State var dragPosition: CGPoint = .zero
    @State var nearestValidSlot: TowerSlot?
    @State var canAffordDraggedTower = false
    @State var previousNearestSlot: TowerSlot?  // For snap detection

    // Blocker mode state
    @State var isBlockerModeActive = false
    @State var selectedBlockerSlotId: String?

    // System Freeze state (0% efficiency)
    @State var showSystemFreeze = false
    @State var isPerformingManualOverride = false

    // Zero-Day Boss Fight state
    @State var showZeroDayBossFight = false
    @State var zeroDayBossFightResult: ZeroDayBossFightResult?

    // Sector unlock panel state (mega-board)
    @State var showSectorUnlockPanel = false
    @State var selectedSectorForUnlock: String?

    // Sector management (pause/unpause) panel state
    @State var showSectorManagementPanel = false

    // TD Boss Integration state
    @State var showBossAlert = false           // Boss spawned, show alert
    @State var showBossDifficultySelector = false  // Difficulty picker modal
    @State var selectedBossDifficulty: BossDifficulty?

    // Boss Fight Coordinator (replaces NotificationCenter pattern)
    @StateObject var bossCoordinator = BossFightCoordinator()

    // Overclock state
    @State var overclockTimeRemaining: TimeInterval = 0

    let mapId: String

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Game scene - full screen
                if let scene = scene {
                    SpriteView(scene: scene)
                        .ignoresSafeArea()
                }

                // HUD overlay - respects safe areas
                VStack(spacing: 0) {
                    // Top bar - below notch
                    topBar
                        .safeAreaInset(edge: .top) { Color.clear.frame(height: 0) }

                    Spacer()

                    // Tower deck at bottom - above home indicator
                    towerDeck(geometry: geometry)
                        .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 0) }
                }

                // Selected tower info panel
                if let towerId = selectedTowerId,
                   let tower = gameState?.towers.first(where: { $0.id == towerId }) {
                    towerInfoPanel(tower: tower, geometry: geometry)
                }

                // Drag preview overlay
                if isDraggingFromDeck, let weaponType = draggedWeaponType {
                    dragPreviewOverlay(weaponType: weaponType, geometry: geometry)
                }

                // Zero-Day Alert overlay (System Breach)
                if let state = gameState, state.zeroDayActive, !showSystemFreeze {
                    zeroDayAlertOverlay
                }

                // TD Boss Alert overlay (threat milestone boss)
                if let state = gameState, state.bossActive, !state.bossEngaged, !showSystemFreeze {
                    bossAlertOverlay
                }

                // Boss Difficulty Selector modal
                if showBossDifficultySelector {
                    bossDifficultySelectorOverlay
                }

                // Overclock button (always visible when not overclocking)
                if let state = gameState, !state.overclockActive {
                    overclockButton
                }

                // Overclock active indicator
                if let state = gameState, state.overclockActive {
                    overclockActiveIndicator
                }

                // System Freeze overlay (0% efficiency)
                if showSystemFreeze {
                    systemFreezeOverlay
                }

                // Pause overlay
                if isPaused && !showSystemFreeze {
                    pauseOverlay
                }

                // Game over overlay
                if showGameOver {
                    gameOverOverlay
                }

                // Sector unlock panel (mega-board)
                if showSectorUnlockPanel, let sectorId = selectedSectorForUnlock {
                    sectorUnlockPanel(sectorId: sectorId)
                }

                // Sector management (pause/unpause) panel
                if showSectorManagementPanel {
                    sectorManagementPanel
                }
            }
            .coordinateSpace(name: "gameArea")
        }
        .onAppear {
            setupGame()
            setupBossCoordinator()
        }
        .onDisappear {
            saveOfflineSimulationState()
        }
        // Force view refresh when boss or overclock state changes
        .onChange(of: gameState?.bossActive) { _ in isPaused = isPaused }
        .onChange(of: gameState?.overclockActive) { _ in isPaused = isPaused }
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $showZeroDayBossFight) {
            ZeroDayBossFightView(
                onComplete: { result in
                    zeroDayBossFightResult = result
                    handleZeroDayBossFightResult(result)
                    showZeroDayBossFight = false
                }
            )
        }
        .fullScreenCover(isPresented: $bossCoordinator.showBossFight) {
            if let difficulty = selectedBossDifficulty {
                GameContainerView(
                    gameMode: .boss,
                    bossDifficulty: difficulty,
                    onExit: {
                        bossCoordinator.showBossFight = false
                    },
                    bossFightCoordinator: bossCoordinator
                )
                .environmentObject(appState)
            }
        }
        .fullScreenCover(isPresented: $bossCoordinator.showBossLootModal) {
            BossLootModalWrapper(
                reward: bossCoordinator.pendingBossLootReward,
                onCollect: {
                    bossCoordinator.onLootCollected()
                    isPaused = false
                }
            )
        }
    }

    /// Configure the boss fight coordinator with context-specific callbacks
    private func setupBossCoordinator() {
        bossCoordinator.onVictory = { [self] districtId, difficulty in
            guard var state = gameState else {
                return BossFightVictoryContext(hashReward: difficulty.hashReward, isFirstKill: false, nextDistrictUnlocked: nil)
            }
            let baseReward = TDBossSystem.onBossFightWon(state: &state, districtId: districtId)
            gameState = state
            return BossFightVictoryContext(
                hashReward: baseReward.hashReward,
                isFirstKill: baseReward.nextDistrictUnlocked != nil,
                nextDistrictUnlocked: baseReward.nextDistrictUnlocked
            )
        }

        bossCoordinator.onDefeat = { [self] in
            guard var state = gameState else { return }
            TDBossSystem.onBossFightLostLetPass(state: &state)
            gameState = state
            isPaused = false
            bossCoordinator.currentBossDistrictId = nil
        }

        bossCoordinator.onLootApplied = { [self] reward in
            if reward.unlockedSectorId != nil {
                scene?.refreshMegaBoardVisuals()
            }
            isPaused = false
        }
    }

    // MARK: - Offline Simulation

    /// Save state needed for offline simulation when player leaves
    private func saveOfflineSimulationState() {
        guard let state = gameState else { return }

        // Calculate tower defense strength (sum of tower DPS)
        let towerDefenseStrength = state.towers.reduce(0.0) { total, tower in
            total + (tower.damage * tower.attackSpeed)
        }

        // Count active (non-paused) lanes
        let unlockedSectorIds = appState.currentPlayer.unlockedSectorIds
        let allLanes = MotherboardLaneConfig.createAllLanes()
        let activeLaneCount = allLanes.filter { lane in
            let isUnlocked = lane.isStarterLane || unlockedSectorIds.contains(lane.sectorId)
            let isNotPaused = !state.pausedSectorIds.contains(lane.sectorId)
            return isUnlocked && isNotPaused
        }.count

        // Save offline simulation state
        StorageService.shared.saveOfflineSimulationState(
            threatLevel: state.idleThreatLevel,
            leakCounter: state.leakCounter,
            towerDefenseStrength: towerDefenseStrength,
            activeLaneCount: activeLaneCount,
            efficiency: state.efficiency
        )

        // Also save the session state
        StorageService.shared.saveTDSession(TDSessionState.from(gameState: state))
    }

    // MARK: - Game Setup

    private func setupGame() {
        guard var state = TDGameStateFactory.createTDGameState(mapId: mapId, playerProfile: appState.currentPlayer) else {
            return
        }

        // FTUE: Grace period for new players who haven't placed a tower yet
        if !appState.currentPlayer.firstTowerPlaced {
            // Set spawn timer to -8 seconds, giving ~10 seconds before first enemy
            state.idleSpawnTimer = -8.0
        }

        // Sync persisted boss defeats to game state
        state.defeatedDistrictBosses = Set(appState.currentPlayer.defeatedDistrictBosses)

        let waves = WaveSystem.generateWaves(totalWaves: 20)

        let handler = TDGameSceneDelegateHandler()
        handler.appState = appState
        handler.onGameStateUpdated = { newState in
            self.updateGameState(newState)
        }
        handler.onSlotSelected = { slotId in
            self.handleSlotSelected(slotId)
        }
        handler.onTowerSelected = { towerId in
            self.handleTowerSelected(towerId)
        }
        handler.onGateSelected = { sectorId in
            self.handleGateSelected(sectorId)
        }
        handler.onSystemFrozen = {
            withAnimation {
                self.showSystemFreeze = true
            }
        }
        handler.onBossSpawned = { bossType in
            // Boss spawned - show alert (state already has boss info)
            withAnimation {
                self.showBossAlert = true
            }
            HapticsService.shared.play(.warning)
        }
        handler.onBossReachedCPU = {
            // Boss reached CPU without engagement - efficiency loss already applied
            HapticsService.shared.play(.defeat)
        }

        // Scene size based on map dimensions
        let sceneSize = CGSize(width: state.map.width, height: state.map.height)

        let newScene = TDGameScene(size: sceneSize)
        newScene.scaleMode = .aspectFill
        newScene.gameStateDelegate = handler
        newScene.loadState(state, waves: waves)

        self.delegateHandler = handler
        self.gameState = state
        self.scene = newScene
    }

    /// MARK: - Actions

    private func startWave() {
        scene?.startWave()
    }

    func placeTower(weaponType: String, slotId: String) {
        scene?.placeTower(weaponType: weaponType, slotId: slotId, profile: appState.currentPlayer)
        showTowerMenu = false
        selectedSlotId = nil
    }

    func upgradeTower(_ towerId: String) {
        scene?.upgradeTower(towerId)
    }

    func sellTower(_ towerId: String) {
        scene?.sellTower(towerId)
        selectedTowerId = nil
    }

    // MARK: - Blocker Actions

    /// Toggle blocker placement mode
    private func toggleBlockerMode() {
        isBlockerModeActive.toggle()
        HapticsService.shared.play(.selection)

        if isBlockerModeActive {
            // Exit any other active mode
            selectedTowerId = nil
            showTowerMenu = false
        }
    }

    /// Place a blocker at a slot
    private func placeBlocker(slotId: String) {
        scene?.placeBlocker(slotId: slotId)
        // Stay in blocker mode for multiple placements
    }

    /// Remove a blocker
    private func removeBlocker(blockerId: String) {
        scene?.removeBlocker(blockerId: blockerId)
    }

    // MARK: - Helpers

    func getAvailableTowers() -> [WeaponConfig] {
        let config = GameConfigLoader.shared
        return appState.currentPlayer.unlocks.weapons.compactMap { config.getWeapon($0) }
    }

    /// Get compiled Protocols from player profile (System: Reboot - Firewall deck)
    func getCompiledProtocols() -> [Protocol] {
        return appState.currentPlayer.compiledProtocols.compactMap { protocolId in
            guard var proto = ProtocolLibrary.get(protocolId) else { return nil }
            // Apply player's level to the protocol
            proto.level = appState.currentPlayer.protocolLevel(protocolId)
            return proto
        }
    }

    func rarityColor(_ rarity: String) -> Color {
        switch rarity {
        case "common": return .gray
        case "rare": return .blue
        case "epic": return .purple
        case "legendary": return .orange
        default: return .gray
        }
    }

    // MARK: - Efficiency System (System: Reboot)

    /// Get efficiency from game state (0-100%)
    /// Efficiency = 100 - (leakCounter * 5)
    /// Each virus reaching CPU reduces efficiency by 5%
    func calculateEfficiency() -> CGFloat {
        return gameState?.efficiency ?? 100
    }

    /// Color for efficiency display
    var efficiencyColor: Color {
        let efficiency = calculateEfficiency()
        if efficiency >= 70 { return .green }
        if efficiency >= 40 { return .yellow }
        if efficiency >= 20 { return .orange }
        return .red
    }

    /// Color for power usage display
    var powerColor: Color {
        guard let state = gameState else { return .green }
        let usage = Double(state.powerUsed) / Double(max(1, state.powerCapacity))
        if usage >= 0.95 { return .red }      // At capacity
        if usage >= 0.75 { return .orange }   // Getting full
        if usage >= 0.50 { return .yellow }   // Half used
        return .green                          // Plenty available
    }

    /// Current Hash per second income rate
    var hashPerSecond: CGFloat {
        return gameState?.hashPerSecond ?? 0
    }

    // MARK: - State Updates

    fileprivate func updateGameState(_ state: TDGameState) {
        let previousEfficiency = self.gameState?.efficiency ?? 100
        self.gameState = state

        // Check for System Freeze (efficiency hit 0%)
        if state.efficiency <= 0 && previousEfficiency > 0 && !showSystemFreeze {
            withAnimation(.easeInOut(duration: 0.3)) {
                showSystemFreeze = true
            }
            HapticsService.shared.play(.defeat)
        }

        if state.isGameOver {
            showGameOver = true
            saveGameResult(state: state)
        }
    }

    fileprivate func handleSlotSelected(_ slotId: String) {
        // Legacy tap-to-place disabled - use drag-to-place only
        // This provides a cleaner UX with progressive disclosure
    }

    fileprivate func handleTowerSelected(_ towerId: String?) {
        selectedTowerId = towerId
    }

    fileprivate func handleGateSelected(_ sectorId: String) {
        selectedSectorForUnlock = sectorId
        showSectorUnlockPanel = true
    }

    private func saveGameResult(state: TDGameState) {
        appState.updatePlayer { profile in
            GameRewardService.applyTDResult(
                to: &profile,
                wavesCompleted: state.wavesCompleted,
                enemiesKilled: state.stats.enemiesKilled,
                towersPlaced: state.stats.towersPlaced,
                hashEarned: state.stats.hashEarned,
                victory: state.victory
            )
        }
    }
}

// MARK: - Scene Delegate Handler

private class TDGameSceneDelegateHandler: TDGameSceneDelegate {
    weak var appState: AppState?

    var onGameStateUpdated: ((TDGameState) -> Void)?
    var onSlotSelected: ((String) -> Void)?
    var onTowerSelected: ((String?) -> Void)?
    var onGateSelected: ((String) -> Void)?
    var onSystemFrozen: (() -> Void)?
    var onBossSpawned: ((String) -> Void)?
    var onBossReachedCPU: (() -> Void)?

    func gameStateUpdated(_ state: TDGameState) {
        DispatchQueue.main.async { [weak self] in
            self?.onGameStateUpdated?(state)
        }
    }

    func slotSelected(_ slotId: String) {
        DispatchQueue.main.async { [weak self] in
            self?.onSlotSelected?(slotId)
        }
    }

    func towerSelected(_ towerId: String?) {
        DispatchQueue.main.async { [weak self] in
            self?.onTowerSelected?(towerId)
        }
    }

    func gateSelected(_ sectorId: String) {
        DispatchQueue.main.async { [weak self] in
            self?.onGateSelected?(sectorId)
        }
    }

    func systemFrozen() {
        DispatchQueue.main.async { [weak self] in
            self?.onSystemFrozen?()
        }
    }

    func getUnlockedSectorIds() -> Set<String> {
        // Return unlocked TD sectors from player profile
        return appState?.currentPlayer.unlockedSectorIds ?? Set([SectorID.power.rawValue])
    }

    func spawnPointTapped(_ lane: SectorLane) {
        // Forward to the gate selected handler (reuse existing unlock UI)
        DispatchQueue.main.async { [weak self] in
            self?.onGateSelected?(lane.sectorId)
        }
    }

    func placementFailed(_ reason: TowerPlacementResult) {
        // TDGameContainerView uses scene-level haptic feedback
        // Additional UI feedback could be added here if needed
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
        // Not used in TDGameContainerView - boss UI handled via overlays
    }
}

// MARK: - Extracted Views
// TowerDeckCard, ProtocolDeckCard → TowerDeckCards.swift
// TDStatRow, ResourceIndicator, WaveProgressBar, CountdownBar → TDHelperViews.swift
// ZeroDayBossFightView, BossLootModalWrapper → TDHelperViews.swift

// MARK: - Preview

struct TDGameContainerView_Previews: PreviewProvider {
    static var previews: some View {
        TDGameContainerView(mapId: "grasslands")
            .environmentObject(AppState.shared)
    }
}

// NOTE: The following types were extracted to separate files:
// - TowerDeckCard (TowerDeckCards.swift)
// - TowerCardCircuitPattern (TowerDeckCards.swift)
// - RarityCorners (TowerDeckCards.swift)
// - ProtocolDeckCard (TowerDeckCards.swift)
// - TDStatRow (TDHelperViews.swift)
// - ResourceIndicator (TDHelperViews.swift)
// - WaveProgressBar (TDHelperViews.swift)
// - CountdownBar (TDHelperViews.swift)
// - GameEndStatRow (TDHelperViews.swift)
// - BossLootModalWrapper (TDHelperViews.swift)
// - ZeroDayBossFightResult (TDHelperViews.swift)
// - ZeroDayBossFightView (TDHelperViews.swift)
