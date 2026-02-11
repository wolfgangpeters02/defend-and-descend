import SwiftUI
import SpriteKit

// MARK: - Motherboard View (Idle Mode)
// Main SwiftUI view for System Defense / Idle mode
// You are an AI protecting a computer system from viruses
// Implements progressive disclosure: show only what's needed, when it's needed

struct TDGameContainerView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @State private var gameState: TDGameState?
    @State private var scene: TDGameScene?
    @State private var delegateHandler: TDGameSceneDelegateHandler?
    @State private var selectedSlotId: String?
    @State private var selectedTowerId: String?
    @State private var showTowerMenu = false
    @State private var showGameOver = false
    @State private var isPaused = false

    // Drag-from-deck state (progressive disclosure - grid only visible during drag)
    @State private var isDraggingFromDeck = false
    @State private var draggedWeaponType: String?
    @State private var dragPosition: CGPoint = .zero
    @State private var nearestValidSlot: TowerSlot?
    @State private var canAffordDraggedTower = false
    @State private var previousNearestSlot: TowerSlot?  // For snap detection

    // Blocker mode state
    @State private var isBlockerModeActive = false
    @State private var selectedBlockerSlotId: String?

    // System Freeze state (0% efficiency)
    @State private var showSystemFreeze = false
    @State private var isPerformingManualOverride = false

    // Zero-Day Boss Fight state
    @State private var showZeroDayBossFight = false
    @State private var zeroDayBossFightResult: ZeroDayBossFightResult?

    // Sector unlock panel state (mega-board)
    @State private var showSectorUnlockPanel = false
    @State private var selectedSectorForUnlock: String?

    // Sector management (pause/unpause) panel state
    @State private var showSectorManagementPanel = false

    // TD Boss Integration state
    @State private var showBossAlert = false           // Boss spawned, show alert
    @State private var showBossDifficultySelector = false  // Difficulty picker modal
    @State private var selectedBossDifficulty: BossDifficulty?

    // Boss Fight Coordinator (replaces NotificationCenter pattern)
    @StateObject private var bossCoordinator = BossFightCoordinator()

    // Overclock state
    @State private var overclockTimeRemaining: TimeInterval = 0

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

    // MARK: - Zero-Day Alert Overlay (System Breach)

    private var zeroDayAlertOverlay: some View {
        VStack {
            Spacer()

            // Alert banner at bottom of screen (above tower deck)
            VStack(spacing: 12) {
                // Warning header
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(DesignTypography.headline(22))
                        .foregroundColor(.red)

                    Text(L10n.ZeroDay.breachDetected)
                        .font(.system(size: 18, weight: .black, design: .monospaced))
                        .foregroundColor(.red)

                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(DesignTypography.headline(22))
                        .foregroundColor(.red)
                }

                Text(L10n.ZeroDay.virusDetected)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.gray)

                Text(L10n.ZeroDay.efficiencyDraining)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.orange)

                // MANUAL_OVERRIDE button
                Button(action: {
                    initiateManualOverride()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "person.fill.viewfinder")
                            .font(DesignTypography.headline(18))
                        Text(L10n.ZeroDay.manualOverride)
                            .font(.system(size: 16, weight: .black, design: .monospaced))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.green)
                    )
                    .shadow(color: .green.opacity(0.6), radius: 10)
                }
                .padding(.top, 4)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.95))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.red.opacity(0.8), lineWidth: 2)
                    )
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 130) // Above tower deck
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: gameState?.zeroDayActive)
    }

    // MARK: - Manual Override (Zero-Day Boss Fight)

    private func initiateManualOverride() {
        HapticsService.shared.play(.warning)

        // Pause the TD game and launch boss fight
        isPaused = true
        showZeroDayBossFight = true
    }

    private func handleZeroDayBossFightResult(_ result: ZeroDayBossFightResult) {
        isPaused = false

        switch result {
        case .victory(let hashBonus):
            // Apply rewards and remove Zero-Day
            if var state = gameState {
                _ = ZeroDaySystem.onZeroDayDefeated(state: &state)
                gameState = state
                scene?.restoreEfficiency(to: max(0, state.leakCounter - 5))  // Bonus: restore some efficiency
            }

            appState.updatePlayer { profile in
                profile.addHash(hashBonus)
            }

            HapticsService.shared.play(.success)

        case .defeat:
            // Zero-Day remains active, efficiency penalty
            if var state = gameState {
                state.leakCounter = min(BalanceConfig.ZeroDay.maxLeakCounter, state.leakCounter + BalanceConfig.ZeroDay.defeatLeakPenalty)
                gameState = state
            }
            HapticsService.shared.play(.defeat)

        case .fled:
            // Zero-Day remains active, no penalty
            HapticsService.shared.play(.light)
        }
    }

    // MARK: - TD Boss Alert Overlay

    private var bossAlertOverlay: some View {
        VStack {
            Spacer()

            // Alert banner at bottom of screen (above tower deck)
            VStack(spacing: 12) {
                // Warning header
                HStack(spacing: 8) {
                    Image(systemName: "bolt.shield.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.orange)

                    Text(L10n.Boss.superVirusDetected)
                        .font(.system(size: 18, weight: .black, design: .monospaced))
                        .foregroundColor(.orange)

                    Image(systemName: "bolt.shield.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.orange)
                }

                if let bossType = gameState?.activeBossType {
                    Text(bossType == "cyberboss" ? L10n.Boss.cyberboss : L10n.Boss.voidHarbinger)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }

                Text(L10n.Boss.immuneToFirewalls)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.gray)

                Text(L10n.Boss.ignoreHint)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.red.opacity(0.8))

                // ENGAGE button
                Button(action: {
                    showBossDifficultySelector = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "person.fill.viewfinder")
                            .font(.system(size: 18, weight: .bold))
                        Text(L10n.Boss.engageTarget)
                            .font(.system(size: 16, weight: .black, design: .monospaced))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.orange)
                    )
                    .shadow(color: .orange.opacity(0.6), radius: 10)
                }
                .padding(.top, 4)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.95))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.orange.opacity(0.8), lineWidth: 2)
                    )
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 130) // Above tower deck
        }
    }

    // MARK: - Boss Difficulty Selector

    private var bossDifficultySelectorOverlay: some View {
        ZStack {
            // Dim background
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    showBossDifficultySelector = false
                }

            // Modal
            VStack(spacing: 16) {
                Text(L10n.Boss.selectDifficulty)
                    .font(.system(size: 20, weight: .black, design: .monospaced))
                    .foregroundColor(.white)

                if let bossType = gameState?.activeBossType {
                    Text(bossType == "cyberboss" ? L10n.Boss.cyberboss : L10n.Boss.voidHarbinger)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.orange)
                }

                // Difficulty buttons
                ForEach(BossDifficulty.allCases, id: \.self) { difficulty in
                    difficultyButton(difficulty: difficulty)
                }

                // Cancel button
                Button(action: {
                    showBossDifficultySelector = false
                }) {
                    Text(L10n.Common.cancel)
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(.gray)
                        .padding(.vertical, 8)
                }
                .padding(.top, 8)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.95))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.orange.opacity(0.5), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 40)
        }
    }

    private func difficultyButton(difficulty: BossDifficulty) -> some View {
        Button(action: {
            selectedBossDifficulty = difficulty
            showBossDifficultySelector = false
            startBossFight(difficulty: difficulty)
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(difficulty.displayName)
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(difficultyColor(difficulty))

                    Text("\(difficulty.hashReward) Ħ  •  \(Int(difficulty.blueprintChance * 100))% Blueprint")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.gray)
                }

                Spacer()

                Text("\(String(format: "%.1f", difficulty.healthMultiplier))x HP")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(difficultyColor(difficulty).opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(difficultyColor(difficulty).opacity(0.5), lineWidth: 1)
                    )
            )
        }
    }

    private func difficultyColor(_ difficulty: BossDifficulty) -> Color {
        DesignHelpers.difficultyColor(difficulty)
    }

    private func startBossFight(difficulty: BossDifficulty) {
        guard var state = gameState else { return }

        // Engage the boss
        guard let engagement = TDBossSystem.engageBoss(state: &state, difficulty: difficulty) else {
            return
        }

        gameState = state
        bossCoordinator.currentBossDistrictId = engagement.districtId
        bossCoordinator.selectedBossDifficulty = difficulty
        bossCoordinator.activeBossType = state.activeBossType

        // Pause TD and transition to boss fight
        isPaused = true
        bossCoordinator.showBossFight = true

        HapticsService.shared.play(.warning)
    }

    // MARK: - Overclock Button

    private var overclockButton: some View {
        let canOverclock = gameState?.canOverclock ?? false
        let buttonColor: Color = canOverclock ? .orange : .gray

        return VStack {
            Spacer()

            HStack {
                Spacer()

                Button(action: {
                    if canOverclock {
                        activateOverclock()
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "bolt.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(buttonColor)

                        Text(L10n.TD.overclock)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(buttonColor)

                        if !canOverclock, gameState?.bossActive == true {
                            Text(L10n.TD.bossActive)
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundColor(.red.opacity(0.7))
                        }
                    }
                    .padding(12)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.8))
                            .overlay(
                                Circle()
                                    .stroke(buttonColor.opacity(0.5), lineWidth: 2)
                            )
                    )
                }
                .padding(.trailing, 20)
            }
            .padding(.bottom, 180) // Above tower deck
        }
    }

    private var overclockActiveIndicator: some View {
        VStack {
            HStack {
                Spacer()

                VStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.orange)

                    Text(L10n.TD.overclocking)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.orange)

                    if let state = gameState {
                        Text("\(Int(state.overclockTimeRemaining))s")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }

                    Text(L10n.TD.hashMultiplier)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.green)

                    Text(L10n.TD.threatMultiplier)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.red)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.9))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.orange, lineWidth: 2)
                        )
                )
                .padding(.trailing, 20)
            }

            Spacer()
        }
        .padding(.top, 100)
    }

    private func activateOverclock() {
        guard var state = gameState else { return }

        if OverclockSystem.activateOverclock(state: &state) {
            gameState = state
            HapticsService.shared.play(.heavy)
        }
    }

    // MARK: - System Freeze Overlay (0% Efficiency)

    private var systemFreezeOverlay: some View {
        ZStack {
            // Dark overlay with scan line effect
            Color.black.opacity(0.95)
                .ignoresSafeArea()

            // Glitch-style lines (pre-computed to avoid non-deterministic rendering)
            VStack(spacing: 4) {
                ForEach(0..<50, id: \.self) { i in
                    let seed = Double(i)
                    Rectangle()
                        .fill(Color.red.opacity(0.05 + (seed.truncatingRemainder(dividingBy: 3)) * 0.05))
                        .frame(height: CGFloat(1 + Int(seed) % 3))
                }
            }
            .ignoresSafeArea()

            VStack(spacing: 24) {
                // Critical error header
                VStack(spacing: 12) {
                    Image(systemName: "xmark.octagon.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.red)

                    Text(L10n.Freeze.header)
                        .font(.system(size: 32, weight: .black, design: .monospaced))
                        .foregroundColor(.red)

                    Text(L10n.Freeze.criticalError)
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(.gray)

                    Text(L10n.Freeze.hashHalted)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.orange)
                }

                // Reboot options
                VStack(spacing: 16) {
                    Text(L10n.Freeze.selectReboot)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)

                    // Option 1: Flush Memory (Pay Hash)
                    let flushCost = FreezeRecoveryService.flushCost(currentHash: appState.currentPlayer.hash)
                    let canAffordFlush = FreezeRecoveryService.canAffordFlush(currentHash: appState.currentPlayer.hash)

                    Button(action: {
                        performFlushMemory(cost: flushCost)
                    }) {
                        VStack(spacing: 6) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 18, weight: .bold))
                                Text(L10n.Freeze.flushMemory)
                                    .font(.system(size: 16, weight: .black, design: .monospaced))
                            }

                            Text(L10n.Freeze.flushCost(flushCost))
                                .font(.system(size: 11, design: .monospaced))
                                .opacity(0.8)
                        }
                        .foregroundColor(canAffordFlush ? .black : .gray)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(canAffordFlush ? Color.cyan : Color.gray.opacity(0.3))
                        )
                    }
                    .disabled(!canAffordFlush)

                    // Option 2: Manual Override (Survival mini-game)
                    Button(action: {
                        performManualOverrideReboot()
                    }) {
                        VStack(spacing: 6) {
                            HStack(spacing: 8) {
                                Image(systemName: "person.fill.viewfinder")
                                    .font(.system(size: 18, weight: .bold))
                                Text(L10n.ZeroDay.manualOverride)
                                    .font(.system(size: 16, weight: .black, design: .monospaced))
                            }

                            Text(L10n.Freeze.overrideSurvive)
                                .font(.system(size: 11, design: .monospaced))
                                .opacity(0.8)
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.green)
                        )
                    }
                }
                .padding(.horizontal, 40)
            }
        }
        .transition(.opacity)
    }

    private func performFlushMemory(cost: Int) {
        HapticsService.shared.play(.medium)

        // Deduct cost
        appState.updatePlayer { profile in
            profile.hash -= cost
        }

        // Restore efficiency to target via FreezeRecoveryService
        let targetLeakCount = FreezeRecoveryService.leakCountForEfficiency(BalanceConfig.Freeze.recoveryTargetEfficiency)
        scene?.restoreEfficiency(to: targetLeakCount)

        withAnimation {
            showSystemFreeze = false
        }
    }

    private func performManualOverrideReboot() {
        HapticsService.shared.play(.warning)
        isPerformingManualOverride = true

        // TODO: Launch 30-second survival mini-game
        // For now, just restore to 100% as placeholder
        scene?.restoreEfficiency(to: 0)  // 100% efficiency = 0 leaks

        withAnimation {
            showSystemFreeze = false
            isPerformingManualOverride = false
        }

        HapticsService.shared.play(.success)
    }

    // MARK: - Top Bar (Simplified HUD)
    // Clean, minimal HUD with only essential info

    private var topBar: some View {
        HStack(spacing: 16) {
            // Left: Pause + Wave
            HStack(spacing: 10) {
                Button(action: {
                    isPaused = true
                    HapticsService.shared.play(.light)
                }) {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(8)
                }

                Text(L10n.Game.HUD.wave(gameState?.currentWave ?? 0))
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }

            Spacer()

            // Center: Efficiency bar (wider, more visible)
            HStack(spacing: 6) {
                let efficiency = calculateEfficiency()
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.3))
                        RoundedRectangle(cornerRadius: 4)
                            .fill(efficiencyColor)
                            .frame(width: geo.size.width * efficiency / 100)
                    }
                }
                .frame(width: 80, height: 10)

                Text("\(Int(efficiency))%")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(efficiencyColor)
            }

            Spacer()

            // Right: Power & Hash
            HStack(spacing: 12) {
                // Power usage (PSU capacity)
                HStack(spacing: 3) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 14))
                        .foregroundColor(powerColor)
                    Text("\(gameState?.powerUsed ?? 0)/\(gameState?.powerCapacity ?? 300)W")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(powerColor)
                }

                // Hash balance with storage cap
                HStack(spacing: 3) {
                    Image(systemName: "number.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.cyan)
                    Text(NumberFormatUtils.hashWithCap(
                        current: gameState?.hash ?? 0,
                        max: gameState?.hashStorageCapacity ?? 25000
                    ))
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.7))
    }

    // MARK: - Wave Controls (Auto-start, no manual button needed)
    // Waves auto-start - this view just shows current wave status

    private var waveControls: some View {
        EmptyView()  // No manual controls needed - waves auto-start
    }

    // MARK: - Tower Deck (Large Touch-Friendly)

    private func towerDeck(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            // Hint text
            Text(L10n.Motherboard.dragToDeploy)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.gray)
                .padding(.top, 6)

            // Scrollable tower cards - large and touch-friendly
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // Use Protocol-based deck if player has compiled protocols
                    let protocols = getCompiledProtocols()
                    if !protocols.isEmpty {
                        ForEach(Array(protocols.enumerated()), id: \.element.id) { index, proto in
                            ProtocolDeckCard(
                                protocol: proto,
                                hash: gameState?.hash ?? 0,
                                onDragStart: { startDragFromDeck(weaponType: proto.id) },
                                onDragChanged: { value in updateDragPosition(value, geometry: geometry) },
                                onDragEnded: { endDragFromDeck() }
                            )
                            // FTUE: Glow on first card for new players
                            .tutorialGlow(
                                color: DesignColors.primary,
                                isActive: index == 0 &&
                                    !appState.currentPlayer.firstTowerPlaced &&
                                    TutorialHintManager.shared.shouldShowHint(.deckCard, profile: appState.currentPlayer)
                            )
                        }
                    } else {
                        // Fallback to legacy weapon system
                        ForEach(getAvailableTowers(), id: \.id) { weapon in
                            TowerDeckCard(
                                weapon: weapon,
                                gold: gameState?.hash ?? 0,
                                onDragStart: { startDragFromDeck(weaponType: weapon.id) },
                                onDragChanged: { value in updateDragPosition(value, geometry: geometry) },
                                onDragEnded: { endDragFromDeck() }
                            )
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
        .frame(height: 110)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.95), Color.black.opacity(0.7)],
                startPoint: .bottom,
                endPoint: .top
            )
        )
    }

    // MARK: - Drag Preview Overlay (Progressive Disclosure)
    // Note: Grid dots are now shown in the SpriteKit scene, not here
    // This overlay only shows the dragged tower preview

    private func dragPreviewOverlay(weaponType: String, geometry: GeometryProxy) -> some View {
        ZStack {
            // The grid dots are rendered in TDGameScene now (progressive disclosure)
            // Only the dragged tower preview is shown here in SwiftUI

            // Check if this is a Protocol (System: Reboot) or legacy weapon
            if let proto = ProtocolLibrary.get(weaponType) {
                // Protocol-based preview
                let displayPosition = nearestValidSlot != nil && canAffordDraggedTower
                    ? convertGameToScreen(nearestValidSlot!.position, geometry: geometry)
                    : dragPosition
                let protoColor = Color(hex: proto.color) ?? DesignColors.primary
                let range = proto.firewallStats.range

                ZStack {
                    // Range preview circle (shown when snapped to valid slot)
                    if nearestValidSlot != nil && canAffordDraggedTower {
                        Circle()
                            .fill(protoColor.opacity(DesignLayout.rangeCircleFillOpacity))
                            .frame(width: range * 0.6, height: range * 0.6)

                        Circle()
                            .stroke(protoColor.opacity(DesignLayout.rangeCircleStrokeOpacity), lineWidth: 2)
                            .frame(width: range * 0.6, height: range * 0.6)
                    }

                    // Tower preview body
                    Circle()
                        .fill(protoColor.opacity(DesignLayout.towerPreviewOpacity))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle()
                                .stroke(
                                    canAffordDraggedTower ? Color.white : DesignColors.danger,
                                    lineWidth: 2
                                )
                        )
                        .shadow(
                            color: canAffordDraggedTower
                                ? protoColor.opacity(0.6)
                                : DesignColors.danger.opacity(0.4),
                            radius: canAffordDraggedTower ? 12 : 6
                        )

                    // Protocol icon
                    Image(systemName: proto.iconName)
                        .font(DesignTypography.headline(18))
                        .foregroundColor(.white)

                    // Cost indicator (Hash)
                    Text("Ħ\(TowerSystem.towerPlacementCost(rarity: proto.rarity))")
                        .font(DesignTypography.caption(11))
                        .fontWeight(.bold)
                        .foregroundColor(canAffordDraggedTower ? DesignColors.primary : DesignColors.danger)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(DesignColors.surface.opacity(0.9))
                        .cornerRadius(4)
                        .offset(y: 32)
                }
                .position(displayPosition)
                .animation(DesignAnimations.quick, value: nearestValidSlot?.id)

            } else if let weapon = GameConfigLoader.shared.getWeapon(weaponType) {
                // Legacy weapon preview
                let displayPosition = nearestValidSlot != nil && canAffordDraggedTower
                    ? convertGameToScreen(nearestValidSlot!.position, geometry: geometry)
                    : dragPosition

                ZStack {
                    // Range preview circle (shown when snapped to valid slot)
                    if nearestValidSlot != nil && canAffordDraggedTower {
                        Circle()
                            .fill(RarityColors.color(for: weapon.rarity).opacity(DesignLayout.rangeCircleFillOpacity))
                            .frame(width: CGFloat(weapon.range) * 0.6, height: CGFloat(weapon.range) * 0.6)

                        Circle()
                            .stroke(RarityColors.color(for: weapon.rarity).opacity(DesignLayout.rangeCircleStrokeOpacity), lineWidth: 2)
                            .frame(width: CGFloat(weapon.range) * 0.6, height: CGFloat(weapon.range) * 0.6)
                    }

                    // Tower preview body
                    Circle()
                        .fill(RarityColors.color(for: weapon.rarity).opacity(DesignLayout.towerPreviewOpacity))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle()
                                .stroke(
                                    canAffordDraggedTower ? Color.white : DesignColors.danger,
                                    lineWidth: 2
                                )
                        )
                        .shadow(
                            color: canAffordDraggedTower
                                ? DesignColors.primary.opacity(0.6)
                                : DesignColors.danger.opacity(0.4),
                            radius: canAffordDraggedTower ? 12 : 6
                        )

                    // Weapon icon
                    Image(systemName: iconForWeapon(weapon.id))
                        .font(DesignTypography.headline(18))
                        .foregroundColor(.white)

                    // Cost indicator (Hash)
                    Text("Ħ\(TowerSystem.towerPlacementCost(rarity: Rarity(rawValue: weapon.rarity) ?? .common))")
                        .font(DesignTypography.caption(11))
                        .fontWeight(.bold)
                        .foregroundColor(canAffordDraggedTower ? DesignColors.primary : DesignColors.danger)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(DesignColors.surface.opacity(0.9))
                        .cornerRadius(4)
                        .offset(y: 32)
                }
                .position(displayPosition)
                .animation(DesignAnimations.quick, value: nearestValidSlot?.id)
            }
        }
        .allowsHitTesting(false)
    }

    /// Get SF Symbol icon for firewall type (System: Reboot themed)
    private func iconForWeapon(_ weaponType: String) -> String {
        // Check if this is a Protocol ID first
        if let proto = ProtocolLibrary.get(weaponType) {
            return proto.iconName
        }

        // Legacy weapon icons
        switch weaponType {
        case "bow", "crossbow": return "antenna.radiowaves.left.and.right"  // Signal firewall
        case "wand", "staff": return "wand.and.rays"                        // Magic/scan firewall
        case "cannon", "bomb": return "burst.fill"                          // Burst firewall
        case "ice_shard": return "snowflake"                                // Freeze firewall
        case "laser": return "rays"                                         // Laser firewall
        case "flamethrower": return "flame.fill"                            // Purge firewall
        case "sword", "katana": return "bolt.fill"                          // Chain firewall
        default: return "shield.fill"                                       // Basic firewall
        }
    }

    // MARK: - Drag Handling (Progressive Disclosure)

    private func startDragFromDeck(weaponType: String) {
        isDraggingFromDeck = true
        draggedWeaponType = weaponType
        previousNearestSlot = nil
        canAffordDraggedTower = TowerPlacementService.canAfford(weaponType: weaponType, hash: gameState?.hash ?? 0)

        // Enter placement mode - shows grid dots (progressive disclosure)
        scene?.enterPlacementMode(weaponType: weaponType)

        HapticsService.shared.play(.selection)
    }

    private func updateDragPosition(_ value: DragGesture.Value, geometry: GeometryProxy) {
        dragPosition = value.location

        if let state = gameState {
            let gamePos = convertScreenToGame(dragPosition, geometry: geometry)
            let cameraScale = scene?.cameraScale ?? 1.0
            let snap = TowerPlacementService.snapDistance(cameraScale: cameraScale, mapWidth: state.map.width)
            let nearest = TowerPlacementService.findNearestSlot(gamePoint: gamePos, slots: state.towerSlots, snapDistance: snap)

            if nearestValidSlot?.id != nearest?.id {
                previousNearestSlot = nearestValidSlot
                nearestValidSlot = nearest

                scene?.highlightNearestSlot(nearest, canAfford: canAffordDraggedTower)

                if nearest != nil && canAffordDraggedTower {
                    HapticsService.shared.play(.slotSnap)
                }
            }
        }
    }

    private func endDragFromDeck() {
        // Exit placement mode - hides grid dots
        scene?.exitPlacementMode()

        defer {
            isDraggingFromDeck = false
            draggedWeaponType = nil
            nearestValidSlot = nil
            previousNearestSlot = nil
        }

        // Place tower if valid
        if let weaponType = draggedWeaponType,
           let slot = nearestValidSlot,
           canAffordDraggedTower {
            scene?.placeTower(weaponType: weaponType, slotId: slot.id, profile: appState.currentPlayer)
            HapticsService.shared.play(.towerPlace)

            // FTUE: Track first tower placement
            if !appState.currentPlayer.firstTowerPlaced {
                appState.recordFirstTowerPlacement()
            }
        }
    }

    // MARK: - Coordinate Conversion
    // The SpriteView renders full-screen with .aspectFill scaleMode
    // Game space is 800x600, screen space varies by device
    // With aspectFill, the scene is scaled up until it fills the screen (may crop edges)

    private let topHUDHeight: CGFloat = 50
    private let bottomDeckHeight: CGFloat = 110

    private func convertGameToScreen(_ point: CGPoint, geometry: GeometryProxy) -> CGPoint {
        if let scene = scene {
            return scene.convertGameToScreen(gamePoint: point, viewSize: geometry.size)
        }
        let gameSize = CGSize(width: gameState?.map.width ?? 800, height: gameState?.map.height ?? 600)
        return TowerPlacementService.convertGameToScreen(point, screenSize: geometry.size, gameSize: gameSize)
    }

    private func convertScreenToGame(_ point: CGPoint, geometry: GeometryProxy) -> CGPoint {
        if let scene = scene {
            return scene.convertScreenToGame(screenPoint: point, viewSize: geometry.size)
        }
        let gameSize = CGSize(width: gameState?.map.width ?? 800, height: gameState?.map.height ?? 600)
        return TowerPlacementService.convertScreenToGame(point, screenSize: geometry.size, gameSize: gameSize)
    }

    // MARK: - Tower Selection Menu

    private func towerSelectionMenu(slotId: String) -> some View {
        VStack(spacing: 12) {
            Text(L10n.TD.deployFirewall)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(.cyan)

            ForEach(getAvailableTowers(), id: \.id) { weapon in
                let cost = TowerSystem.towerPlacementCost(rarity: Rarity(rawValue: weapon.rarity) ?? .common)
                let canAfford = (gameState?.hash ?? 0) >= cost

                Button(action: {
                    placeTower(weaponType: weapon.id, slotId: slotId)
                }) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(weapon.towerName ?? weapon.name)
                                .font(.system(size: 14, weight: .medium, design: .monospaced))
                            Text(L10n.Stats.dmgRng(Int(weapon.damage), rng: Int(weapon.range)))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.gray)
                        }

                        Spacer()

                        Text("Ħ\(cost)")
                            .foregroundColor(canAfford ? .cyan : .red)
                            .fontWeight(.bold)
                            .font(.system(size: 14, design: .monospaced))
                    }
                    .padding(10)
                    .background(rarityColor(weapon.rarity).opacity(0.3))
                    .cornerRadius(8)
                }
                .disabled(!canAfford)
                .opacity(canAfford ? 1 : 0.5)
            }

            Button(L10n.Common.cancel) {
                showTowerMenu = false
                selectedSlotId = nil
            }
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundColor(.gray)
            .padding(.top, 8)
        }
        .padding(16)
        .background(Color.black.opacity(0.95))
        .cornerRadius(16)
        .frame(maxWidth: 300)
    }

    // MARK: - Tower Info Panel

    private func towerInfoPanel(tower: Tower, geometry: GeometryProxy) -> some View {
        let towerScreenPos = convertGameToScreen(tower.position, geometry: geometry)
        // Position panel to the side of the tower, avoiding edges
        let panelX = towerScreenPos.x > geometry.size.width / 2
            ? towerScreenPos.x - 120
            : towerScreenPos.x + 120
        let panelY = min(max(towerScreenPos.y, 150), geometry.size.height - 200)

        return VStack(alignment: .leading, spacing: 8) {
            // Header with name and merge stars
            HStack {
                Text(tower.towerName)
                    .font(DesignTypography.headline(16))
                    .foregroundColor(.white)

                Spacer()
            }

            Text(L10n.TD.levelMax(tower.level, max: 10))
                .font(DesignTypography.caption(12))
                .foregroundColor(.gray)

            Divider().background(Color.white.opacity(0.3))

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    TDStatRow(icon: "flame.fill", label: L10n.Stats.dmg, value: String(format: "%.1f", tower.damage), color: .orange)
                    TDStatRow(icon: "scope", label: L10n.Stats.rng, value: String(format: "%.0f", tower.range), color: .blue)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    TDStatRow(icon: "bolt.fill", label: L10n.Stats.spd, value: String(format: "%.2f/s", tower.attackSpeed), color: .yellow)
                    TDStatRow(icon: "chart.line.uptrend.xyaxis", label: L10n.Stats.dps, value: String(format: "%.1f", tower.damage * tower.attackSpeed), color: .green)
                }
            }
            .font(DesignTypography.caption(12))

            Divider().background(Color.white.opacity(0.3))

            // Action buttons
            HStack(spacing: 8) {
                if tower.canUpgrade {
                    Button(action: { upgradeTower(tower.id) }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.circle.fill")
                            Text("Ħ\(tower.upgradeCost)")
                        }
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background((gameState?.hash ?? 0) >= tower.upgradeCost ? Color.cyan : Color.gray)
                        .cornerRadius(6)
                    }
                    .disabled((gameState?.hash ?? 0) < tower.upgradeCost)
                }

                Button(action: { sellTower(tower.id) }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.uturn.backward.circle.fill")
                        Text(L10n.Common.recycle)
                    }
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.8))
                    .cornerRadius(6)
                }

                // Close button
                Spacer()
                Button(action: { selectedTowerId = nil }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(DesignTypography.headline(18))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .foregroundColor(.white)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.95))
                .shadow(color: rarityColorForTower(tower).opacity(0.5), radius: 8)
        )
        .frame(width: 200)
        .position(x: panelX, y: panelY)
    }

    private func rarityColorForTower(_ tower: Tower) -> Color {
        // Get rarity from weapon config
        if let weapon = GameConfigLoader.shared.getWeapon(tower.weaponType) {
            return rarityColor(weapon.rarity)
        }
        return .gray
    }

    // MARK: - Pause Overlay

    private var pauseOverlay: some View {
        ZStack {
            Color.black.opacity(0.9)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                VStack(spacing: 8) {
                    Text(L10n.TD.systemPaused)
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)
                    Text(L10n.TD.protocolsSuspended)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(.gray)
                }

                // CPU Upgrade Section
                cpuUpgradeSection

                VStack(spacing: 16) {
                    Button(action: {
                        isPaused = false
                        HapticsService.shared.play(.light)
                    }) {
                        Text(L10n.Common.resume)
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundColor(.black)
                            .frame(width: 220, height: 56)
                            .background(Color.green)
                            .cornerRadius(12)
                    }

                    // Sector Management button
                    Button(action: {
                        HapticsService.shared.play(.light)
                        showSectorManagementPanel = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.grid.2x2")
                            Text(L10n.Sector.manageSectors)
                        }
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)
                        .frame(width: 220, height: 48)
                        .background(Color.black.opacity(0.6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.cyan.opacity(0.5), lineWidth: 1)
                        )
                        .cornerRadius(10)
                    }

                    Button(action: {
                        HapticsService.shared.play(.light)
                        dismiss()
                    }) {
                        Text(L10n.Common.abort)
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .frame(width: 220, height: 56)
                            .background(Color.red.opacity(0.8))
                            .cornerRadius(12)
                    }
                }
            }
        }
    }

    // MARK: - CPU Upgrade Section

    private var cpuUpgradeSection: some View {
        let cpuInfo = StorageService.shared.getCpuTierInfo()
        let canUpgrade = cpuInfo.nextCost != nil && appState.currentPlayer.hash >= (cpuInfo.nextCost ?? 0)

        return VStack(spacing: 12) {
            // Current CPU info
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.CPU.tier)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.gray)
                    HStack(spacing: 4) {
                        Image(systemName: "cpu")
                            .font(DesignTypography.headline(22))
                        Text("\(cpuInfo.tier).0")
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                    }
                    .foregroundColor(.cyan)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.CPU.multiplier)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.gray)
                    Text("\(String(format: "%.0f", cpuInfo.multiplier))x")
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(.green)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(L10n.CPU.watts)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.gray)
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                        Text("\(appState.currentPlayer.hash)")
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                    }
                    .foregroundColor(.cyan)
                }
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)

            // Upgrade button (if not max tier)
            if let upgradeCost = cpuInfo.nextCost {
                Button(action: {
                    upgradeCpu()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.up.circle.fill")
                        Text(L10n.CPU.upgradeTo(cpuInfo.tier + 1))
                        Spacer()
                        Text("Ħ\(upgradeCost)")
                            .fontWeight(.bold)
                    }
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(canUpgrade ? .black : .gray)
                    .padding()
                    .background(canUpgrade ? Color.cyan : Color.gray.opacity(0.3))
                    .cornerRadius(10)
                }
                .disabled(!canUpgrade)
            } else {
                Text(L10n.CPU.maxTier)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.yellow)
                    .padding()
                    .background(Color.yellow.opacity(0.2))
                    .cornerRadius(10)
            }
        }
        .frame(width: 280)
    }

    // MARK: - CPU Upgrade Action

    private func upgradeCpu() {
        // Use GlobalUpgrades system for CPU upgrades
        let profile = appState.currentPlayer
        guard let cost = profile.globalUpgrades.cpuUpgradeCost,
              profile.hash >= cost else {
            HapticsService.shared.play(.warning)
            return
        }

        // Deduct cost and apply upgrade
        var updatedProfile = profile
        updatedProfile.hash -= cost
        updatedProfile.globalUpgrades.upgrade(.cpu)
        StorageService.shared.savePlayer(updatedProfile)
        appState.refreshPlayer()

        // Update game state's Hash generation
        if var state = gameState {
            state.baseHashPerSecond = appState.currentPlayer.globalUpgrades.hashPerSecond
            state.cpuTier = appState.currentPlayer.globalUpgrades.cpuLevel
            gameState = state
        }

        HapticsService.shared.play(.success)
    }

    // MARK: - Game Over Overlay

    private var gameOverOverlay: some View {
        ZStack {
            Color.black.opacity(0.95)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                // Victory/Defeat title - System: Reboot themed
                VStack(spacing: 8) {
                    Text(gameState?.victory == true ? L10n.TD.systemSecure : L10n.TD.systemBreach)
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .foregroundColor(gameState?.victory == true ? .green : .red)

                    Text(gameState?.victory == true ? L10n.TD.threatsNeutralized : L10n.TD.cpuCompromised)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(.gray)
                }

                // Stats card
                if let state = gameState {
                    VStack(spacing: 16) {
                        GameEndStatRow(label: L10n.TD.waves, value: "\(state.wavesCompleted)/20", icon: "waveform.path", color: .purple)
                        GameEndStatRow(label: L10n.TD.viruses, value: "\(state.stats.enemiesKilled)", icon: "ladybug.fill", color: .red)
                        GameEndStatRow(label: L10n.Common.hash, value: "Ħ\(state.stats.hashEarned)", icon: "number.circle.fill", color: .cyan)
                    }
                    .padding(24)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                    )
                }

                Button(action: {
                    HapticsService.shared.play(.light)
                    dismiss()
                }) {
                    Text(L10n.Common.exit)
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(.black)
                        .frame(width: 220, height: 56)
                        .background(Color.cyan)
                        .cornerRadius(12)
                }
            }
        }
    }

    // MARK: - Sector Unlock Panel (Mega-Board)

    private func sectorUnlockPanel(sectorId: String) -> some View {
        let status = SectorUnlockSystem.shared.getUnlockStatus(for: sectorId, profile: appState.currentPlayer)

        return ZStack {
            // Dimmed background
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .onTapGesture {
                    showSectorUnlockPanel = false
                    selectedSectorForUnlock = nil
                }

            // Panel
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.red)

                    Text(L10n.Sector.encrypted)
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)

                    Text(status?.displayName ?? L10n.Common.unknown)
                        .font(.system(size: 18, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                }

                // Description
                if let desc = status?.description {
                    Text(desc)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                // Cost display
                if let status = status {
                    VStack(spacing: 12) {
                        // Cost
                        HStack(spacing: 8) {
                            Text(L10n.Sector.decryptCost)
                                .font(.system(size: 14, weight: .medium, design: .monospaced))
                                .foregroundColor(.gray)

                            Text("Ħ \(status.unlockCost)")
                                .font(.system(size: 20, weight: .bold, design: .monospaced))
                                .foregroundColor(.cyan)
                        }

                        // Current balance
                        HStack(spacing: 8) {
                            Text(L10n.Sector.yourBalance)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundColor(.gray)

                            Text("Ħ \(status.currentHash)")
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundColor(status.canAfford ? .green : .orange)
                        }

                        // Status message
                        Text(status.statusMessage)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(status.canUnlock ? .green : .orange)
                            .padding(.top, 4)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(status.canUnlock ? Color.cyan.opacity(0.5) : Color.red.opacity(0.3), lineWidth: 1)
                            )
                    )
                }

                // Buttons
                HStack(spacing: 16) {
                    // Cancel
                    Button(action: {
                        HapticsService.shared.play(.light)
                        showSectorUnlockPanel = false
                        selectedSectorForUnlock = nil
                    }) {
                        Text(L10n.Common.cancel)
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .frame(width: 120, height: 50)
                            .background(Color.gray.opacity(0.3))
                            .cornerRadius(8)
                    }

                    // Decrypt
                    Button(action: {
                        unlockSelectedSector()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "lock.open.fill")
                            Text(L10n.Sector.decrypt)
                        }
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(status?.canUnlock == true ? .black : .gray)
                        .frame(width: 140, height: 50)
                        .background(status?.canUnlock == true ? Color.cyan : Color.gray.opacity(0.3))
                        .cornerRadius(8)
                    }
                    .disabled(status?.canUnlock != true)
                }
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(white: 0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.cyan.opacity(0.3), lineWidth: 2)
                    )
            )
            .padding(24)
        }
    }

    // MARK: - Sector Management Panel (Pause/Unpause)

    private var sectorManagementPanel: some View {
        let unlockedSectorIds = appState.currentPlayer.unlockedSectorIds

        return ZStack {
            // Dimmed background
            Color.black.opacity(0.9)
                .ignoresSafeArea()
                .onTapGesture {
                    showSectorManagementPanel = false
                }

            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 36))
                        .foregroundColor(.cyan)

                    Text(L10n.Sector.management)
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)

                    Text(L10n.Sector.pauseDescription)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.gray)
                }

                // Sector list
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(MotherboardLaneConfig.createAllLanes(), id: \.id) { lane in
                            let isUnlocked = lane.isStarterLane || unlockedSectorIds.contains(lane.sectorId)

                            if isUnlocked {
                                sectorRow(lane: lane)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(maxHeight: 300)

                // Warning message
                if let state = gameState, !state.pausedSectorIds.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(L10n.Sector.pausedWarning)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.orange)
                    }
                    .padding(12)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }

                // Close button
                Button(action: {
                    HapticsService.shared.play(.light)
                    showSectorManagementPanel = false
                }) {
                    Text(L10n.Common.done)
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(.black)
                        .frame(width: 200, height: 50)
                        .background(Color.cyan)
                        .cornerRadius(10)
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(white: 0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.cyan.opacity(0.3), lineWidth: 2)
                    )
            )
            .padding(20)
        }
    }

    private func sectorRow(lane: SectorLane) -> some View {
        let isPaused = gameState?.pausedSectorIds.contains(lane.sectorId) ?? false
        let themeColor = Color(hex: lane.themeColorHex) ?? .cyan

        return HStack(spacing: 16) {
            // Sector color indicator
            Circle()
                .fill(isPaused ? Color.gray : themeColor)
                .frame(width: 12, height: 12)

            // Sector name
            VStack(alignment: .leading, spacing: 2) {
                Text(lane.displayName)
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                    .foregroundColor(isPaused ? .gray : .white)

                Text(isPaused ? L10n.Common.paused : L10n.Common.active)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(isPaused ? .orange : .green)
            }

            Spacer()

            // Toggle button
            Button(action: {
                toggleSectorPause(sectorId: lane.sectorId)
            }) {
                Text(isPaused ? L10n.Common.resume : L10n.Common.pause)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(isPaused ? .green : .orange)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isPaused ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                    )
            }
            // Don't allow pausing the starter lane (PSU)
            .disabled(lane.isStarterLane)
            .opacity(lane.isStarterLane ? 0.5 : 1.0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isPaused ? Color.orange.opacity(0.3) : themeColor.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private func toggleSectorPause(sectorId: String) {
        guard var state = gameState else { return }

        if state.pausedSectorIds.contains(sectorId) {
            state.pausedSectorIds.remove(sectorId)
            HapticsService.shared.play(.light)
        } else {
            state.pausedSectorIds.insert(sectorId)
            HapticsService.shared.play(.warning)
        }

        // Update state - scene will pick up changes on next update cycle
        gameState = state
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

    private func placeTower(weaponType: String, slotId: String) {
        scene?.placeTower(weaponType: weaponType, slotId: slotId, profile: appState.currentPlayer)
        showTowerMenu = false
        selectedSlotId = nil
    }

    private func upgradeTower(_ towerId: String) {
        scene?.upgradeTower(towerId)
    }

    private func sellTower(_ towerId: String) {
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

    private func getAvailableTowers() -> [WeaponConfig] {
        let config = GameConfigLoader.shared
        return appState.currentPlayer.unlocks.weapons.compactMap { config.getWeapon($0) }
    }

    /// Get compiled Protocols from player profile (System: Reboot - Firewall deck)
    private func getCompiledProtocols() -> [Protocol] {
        return appState.currentPlayer.compiledProtocols.compactMap { protocolId in
            guard var proto = ProtocolLibrary.get(protocolId) else { return nil }
            // Apply player's level to the protocol
            proto.level = appState.currentPlayer.protocolLevel(protocolId)
            return proto
        }
    }

    private func rarityColor(_ rarity: String) -> Color {
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
    private func calculateEfficiency() -> CGFloat {
        return gameState?.efficiency ?? 100
    }

    /// Color for efficiency display
    private var efficiencyColor: Color {
        let efficiency = calculateEfficiency()
        if efficiency >= 70 { return .green }
        if efficiency >= 40 { return .yellow }
        if efficiency >= 20 { return .orange }
        return .red
    }

    /// Color for power usage display
    private var powerColor: Color {
        guard let state = gameState else { return .green }
        let usage = Double(state.powerUsed) / Double(max(1, state.powerCapacity))
        if usage >= 0.95 { return .red }      // At capacity
        if usage >= 0.75 { return .orange }   // Getting full
        if usage >= 0.50 { return .yellow }   // Half used
        return .green                          // Plenty available
    }

    /// Current Hash per second income rate
    private var hashPerSecond: CGFloat {
        return gameState?.hashPerSecond ?? 0
    }

    // MARK: - State Updates

    fileprivate func updateGameState(_ state: TDGameState) {
        let previousEfficiency = self.gameState?.efficiency ?? 100
        let previousBossActive = self.gameState?.bossActive ?? false
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

    private func unlockSelectedSector() {
        guard let sectorId = selectedSectorForUnlock else { return }

        let result = SectorUnlockSystem.shared.performUnlockTransaction(sectorId, appState: appState)

        if result.success {
            // Play celebration
            HapticsService.shared.play(.legendary)

            // Refresh mega-board visuals
            scene?.refreshMegaBoardVisuals()

            // Close panel
            showSectorUnlockPanel = false
            selectedSectorForUnlock = nil
        } else {
            HapticsService.shared.play(.error)
        }
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

