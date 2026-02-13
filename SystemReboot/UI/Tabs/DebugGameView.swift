import SwiftUI
import SpriteKit

// MARK: - Legacy Debug View (kept for fallback)

struct DebugView: View {
    @ObservedObject var appState = AppState.shared
    let onLaunch: (DebugArena) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(L10n.Debug.mode)
                    .font(DesignTypography.display(28))
                    .foregroundColor(.white)

                Spacer()

                // Hash balance
                HStack(spacing: 6) {
                    Text("Ħ")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(DesignColors.primary)
                    Text("\(appState.currentPlayer.hash)")
                        .font(DesignTypography.headline(18))
                        .foregroundColor(DesignColors.primary)
                }
            }
            .padding()

            // Loadout preview
            loadoutPreview

            Divider()
                .background(DesignColors.muted.opacity(0.3))
                .padding(.horizontal)

            // Sector selection
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(L10n.Sector.select)
                        .font(DesignTypography.caption(12))
                        .foregroundColor(DesignColors.muted)
                        .padding(.horizontal)

                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(DebugArenaLibrary.all) { arena in
                            DebugArenaCard(
                                arena: arena,
                                isUnlocked: appState.currentPlayer.isDebugArenaUnlocked(arena.id),
                                bestTime: appState.currentPlayer.debugArenaBestTime(arena.id),
                                onSelect: { onLaunch(arena) },
                                onUnlock: { unlockArena(arena) }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
        }
    }

    private var loadoutPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.Common.loadout)
                .font(DesignTypography.caption(12))
                .foregroundColor(DesignColors.muted)

            if let equipped = appState.currentPlayer.equippedProtocol() {
                HStack {
                    Image(systemName: equipped.iconName)
                        .font(.system(size: 28))
                        .foregroundColor(Color(hex: equipped.color) ?? .cyan)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(equipped.name)
                            .font(DesignTypography.headline(16))
                            .foregroundColor(.white)

                        Text(L10n.Stats.dmgRate(Int(equipped.weaponStats.damage), rate: String(format: "%.1f", equipped.weaponStats.fireRate)))
                            .font(DesignTypography.caption(11))
                            .foregroundColor(DesignColors.muted)
                    }

                    Spacer()

                    Text(L10n.Common.lv(equipped.level))
                        .font(DesignTypography.headline(16))
                        .foregroundColor(DesignColors.primary)
                }
                .padding()
                .background(DesignColors.surface)
                .cornerRadius(12)
            }
        }
        .padding()
    }

    private func unlockArena(_ arena: DebugArena) {
        guard appState.currentPlayer.hash >= arena.unlockCost else { return }
        HapticsService.shared.play(.medium)
        appState.updatePlayer { profile in
            profile.hash -= arena.unlockCost
            profile.unlockedSectors.append(arena.id)
        }
    }
}

// MARK: - Debug Arena Card

struct DebugArenaCard: View {
    let arena: DebugArena
    let isUnlocked: Bool
    var bestTime: TimeInterval?
    let onSelect: () -> Void
    let onUnlock: () -> Void

    @ObservedObject var appState = AppState.shared

    private var isDungeon: Bool {
        arena.gameMode == .dungeon
    }

    var body: some View {
        VStack(spacing: 12) {
            // Header
            VStack(spacing: 4) {
                Text(arena.name)
                    .font(DesignTypography.headline(16))
                    .foregroundColor(isUnlocked ? .white : DesignColors.muted)

                Text(arena.subtitle)
                    .font(DesignTypography.caption(11))
                    .foregroundColor(DesignColors.muted)
            }

            // Mode badge (Dungeon vs Arena)
            HStack(spacing: 6) {
                Image(systemName: isDungeon ? "door.left.hand.open" : "sparkles")
                    .font(.system(size: 10))
                Text(isDungeon ? L10n.Mode.dungeon : L10n.Mode.arena)
                    .font(DesignTypography.caption(9))
            }
            .foregroundColor(isDungeon ? DesignColors.secondary : DesignColors.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background((isDungeon ? DesignColors.secondary : DesignColors.primary).opacity(0.15))
            .cornerRadius(4)

            // Difficulty badge
            Text(arena.difficulty.displayName)
                .font(DesignTypography.caption(10))
                .foregroundColor(Color(hex: arena.difficulty.color) ?? .green)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(hex: arena.difficulty.color)?.opacity(0.2) ?? .green.opacity(0.2))
                .cornerRadius(4)

            // Hash multiplier
            Text("Ħ x\(String(format: "%.1f", arena.hashMultiplier))")
                .font(DesignTypography.caption(11))
                .foregroundColor(DesignColors.success)

            // Best time or lock status
            if isUnlocked {
                if let time = bestTime {
                    Text(L10n.Stats.best(formatTime(time)))
                        .font(DesignTypography.caption(10))
                        .foregroundColor(DesignColors.muted)
                }

                Button(action: onSelect) {
                    Text(L10n.Common.launch)
                        .font(DesignTypography.headline(14))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(DesignColors.success)
                        .cornerRadius(8)
                }
            } else {
                let canAfford = appState.currentPlayer.hash >= arena.unlockCost
                Button(action: onUnlock) {
                    HStack {
                        Image(systemName: "lock.fill")
                        Text("Ħ\(arena.unlockCost)")
                    }
                    .font(DesignTypography.headline(14))
                    .foregroundColor(canAfford ? .white : DesignColors.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(canAfford ? DesignColors.surface : DesignColors.surface)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(canAfford ? DesignColors.primary : DesignColors.muted, lineWidth: 1)
                    )
                }
                .disabled(!canAfford)
            }
        }
        .padding()
        .background(DesignColors.surface)
        .cornerRadius(16)
        .opacity(isUnlocked ? 1.0 : 0.7)
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

// MARK: - Debug Game View (Full Active Mode with Protocol Weapon)

struct DebugGameView: View {
    let debugArena: DebugArena
    let `protocol`: Protocol
    let onExit: () -> Void

    @ObservedObject var appState = AppState.shared
    @State private var gameState: GameState?
    @State private var gameScene: GameScene?
    @State private var showGameOver = false
    @State private var showVictory = false
    @State private var showExtractionAvailable = false
    @State private var extractionTimer: Timer?
    @State private var hasExtracted = false
    @State private var inputState = InputState()  // For joystick control
    @State private var currentScreenSize: CGSize = .zero

    // Extraction becomes available after this many seconds
    private let extractionTimeThreshold: TimeInterval = BalanceConfig.SurvivalEconomy.extractionTime

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Game scene
                if let scene = gameScene {
                    SpriteView(scene: scene)
                        .ignoresSafeArea()
                } else {
                    // Show loading while waiting for valid geometry
                    DesignColors.background
                        .ignoresSafeArea()
                    VStack {
                        ProgressView()
                            .tint(DesignColors.primary)
                        Text(L10n.Motherboard.initializing)
                            .font(DesignTypography.caption(12))
                            .foregroundColor(DesignColors.muted)
                            .padding(.top, 8)
                    }
                }

                // Virtual joystick for movement (no momentum for direct control)
                VirtualJoystick(
                    onMove: { angle, distance in
                        inputState.joystick = JoystickInput(angle: angle, distance: distance)
                        gameScene?.updateInput(inputState)
                    },
                    onStop: {
                        inputState.joystick = nil
                        gameScene?.updateInput(inputState)
                    },
                    config: JoystickConfig(enableMomentum: false)
                )

                // HUD overlay (only show when game is running)
                if gameScene != nil {
                    VStack {
                        debugHUD
                        Spacer()
                    }
                }

                // Extraction available overlay
                if showExtractionAvailable && !showGameOver && !showVictory {
                    extractionOverlay
                }

                // Game over overlay
                if showGameOver || showVictory {
                    debugGameOverOverlay
                }
            }
            .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
                // Check if extraction should become available
                if let state = gameState,
                   !showExtractionAvailable && !hasExtracted,
                   state.timeElapsed >= extractionTimeThreshold {
                    withAnimation(.spring(response: 0.5)) {
                        showExtractionAvailable = true
                    }
                    HapticsService.shared.play(.success)
                }
            }
            .onChange(of: geometry.size) { newSize in
                if gameScene == nil && newSize.width > 0 && newSize.height > 0 {
                    currentScreenSize = newSize
                    setupDebugGame(screenSize: newSize)
                }
            }
            .onAppear {
                // Also try on appear in case geometry is already valid
                if gameScene == nil && geometry.size.width > 0 && geometry.size.height > 0 {
                    currentScreenSize = geometry.size
                    setupDebugGame(screenSize: geometry.size)
                }
            }
        }
    }

    private var debugHUD: some View {
        HStack {
            // Health
            if let state = gameState {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                    Text("\(Int(state.player.health))/\(Int(state.player.maxHealth))")
                        .font(DesignTypography.headline(14))
                        .foregroundColor(.white)
                }
            }

            Spacer()

            // Arena name
            Text(debugArena.name)
                .font(DesignTypography.headline(16))
                .foregroundColor(DesignColors.success)

            Spacer()

            // Hash collected
            if let state = gameState {
                let hashAmount = Int(CGFloat(state.stats.enemiesKilled) * debugArena.hashMultiplier)
                HStack(spacing: 4) {
                    Text("Ħ")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(DesignColors.primary)
                    Text("\(hashAmount)")
                        .font(DesignTypography.headline(14))
                        .foregroundColor(DesignColors.primary)
                }
            }

            Spacer()

            // Time
            if let state = gameState {
                Text(formatTime(state.timeElapsed))
                    .font(DesignTypography.headline(14))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.7))
    }

    private var extractionOverlay: some View {
        VStack {
            Spacer()

            VStack(spacing: 16) {
                // Header
                HStack {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(DesignColors.success)

                    Text(L10n.Extraction.available)
                        .font(DesignTypography.headline(18))
                        .foregroundColor(DesignColors.success)
                }

                // Current hash
                if let state = gameState {
                    let baseHash = state.stats.enemiesKilled
                    let multipliedHash = Int(CGFloat(baseHash) * debugArena.hashMultiplier)

                    HStack(spacing: 4) {
                        Text("Ħ")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(DesignColors.primary)
                        Text(L10n.Extraction.hashSecured(multipliedHash))
                            .font(DesignTypography.body(14))
                            .foregroundColor(.white)
                    }
                }

                // Choice buttons
                HStack(spacing: 16) {
                    // Extract Now button
                    Button {
                        HapticsService.shared.play(.success)
                        hasExtracted = true
                        showExtractionAvailable = false
                        showVictory = true
                    } label: {
                        VStack(spacing: 4) {
                            Text(L10n.Extraction.extract)
                                .font(DesignTypography.headline(16))
                            Text(L10n.Extraction.keepHash)
                                .font(DesignTypography.caption(10))
                                .opacity(0.7)
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(DesignColors.success)
                        .cornerRadius(10)
                    }

                    // Continue button
                    Button {
                        HapticsService.shared.play(.light)
                        withAnimation {
                            showExtractionAvailable = false
                            hasExtracted = true  // Don't show extraction again
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Text(L10n.Common.continueAction)
                                .font(DesignTypography.headline(16))
                            Text(L10n.Extraction.riskForMore)
                                .font(DesignTypography.caption(10))
                                .opacity(0.7)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(DesignColors.danger.opacity(0.8))
                        .cornerRadius(10)
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(DesignColors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(DesignColors.success, lineWidth: 2)
                    )
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 100)  // Above virtual joystick area
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var debugGameOverOverlay: some View {
        ZStack {
            Color.black.opacity(0.9).ignoresSafeArea()

            VStack(spacing: 24) {
                // Title
                Text(showVictory ? L10n.Extraction.sectorCleansed : L10n.Debug.failed)
                    .font(DesignTypography.display(32))
                    .foregroundColor(showVictory ? DesignColors.success : DesignColors.danger)

                // Stats
                if let state = gameState {
                    VStack(spacing: 12) {
                        let baseHash = state.stats.enemiesKilled
                        let multipliedHash = Int(CGFloat(baseHash) * debugArena.hashMultiplier)
                        let finalHash = showVictory ? multipliedHash : multipliedHash / 2

                        HStack {
                            Text(L10n.Extraction.virusesEliminated)
                                .foregroundColor(DesignColors.muted)
                            Spacer()
                            Text("\(state.stats.enemiesKilled)")
                                .foregroundColor(.white)
                        }

                        HStack {
                            Text(L10n.Extraction.hashEarned)
                                .foregroundColor(DesignColors.muted)
                            Spacer()
                            HStack(spacing: 4) {
                                Text("Ħ")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(DesignColors.primary)
                                Text("+\(finalHash)")
                                    .foregroundColor(DesignColors.primary)
                            }
                        }

                        HStack {
                            Text(L10n.GameOver.timeSurvived)
                                .foregroundColor(DesignColors.muted)
                            Spacer()
                            Text(formatTime(state.timeElapsed))
                                .foregroundColor(.white)
                        }
                    }
                    .font(DesignTypography.body(16))
                    .padding()
                    .background(DesignColors.surface)
                    .cornerRadius(12)
                    .frame(maxWidth: 300)
                }

                // Buttons
                HStack(spacing: 16) {
                    // Retry button
                    Button {
                        showGameOver = false
                        showVictory = false
                        setupDebugGame(screenSize: currentScreenSize)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.counterclockwise")
                            Text(L10n.Common.retry)
                        }
                        .font(DesignTypography.headline(16))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(DesignColors.surface)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(DesignColors.primary.opacity(0.5), lineWidth: 1)
                        )
                    }

                    // Exit button
                    Button {
                        // Award Hash before exiting
                        if let state = gameState {
                            let baseHash = state.stats.enemiesKilled
                            let multipliedHash = Int(CGFloat(baseHash) * debugArena.hashMultiplier)
                            let finalHash = showVictory ? multipliedHash : multipliedHash / 2
                            appState.updatePlayer { profile in
                                profile.addHash(max(1, finalHash))
                            }
                        }
                        onExit()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle")
                            Text(L10n.Common.collectAndExit)
                        }
                        .font(DesignTypography.headline(16))
                        .foregroundColor(.black)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(DesignColors.primary)
                        .cornerRadius(10)
                    }
                }
            }
            .padding()
        }
    }

    private func setupDebugGame(screenSize: CGSize) {
        // Create game state based on arena's game mode
        var state: GameState
        if debugArena.gameMode == .dungeon, let bossType = debugArena.dungeonType {
            // Use boss mode - direct boss encounter
            state = GameStateFactory.shared.createBossGameState(
                gameProtocol: `protocol`,
                bossType: mapDungeonToBoss(bossType),
                difficulty: .normal,
                playerProfile: appState.currentPlayer
            )
        } else {
            // Use survival mode (survival waves)
            state = GameStateFactory.shared.createDebugGameState(
                gameProtocol: `protocol`,
                debugArena: debugArena,
                playerProfile: appState.currentPlayer
            )
        }
        gameState = state

        // Create and configure scene
        let scene = GameScene()
        scene.configure(gameState: state, screenSize: screenSize)
        scene.onGameOver = { finalState in
            gameState = finalState
            if finalState.victory {
                showVictory = true
            } else {
                showGameOver = true
            }
            HapticsService.shared.play(finalState.victory ? .success : .warning)
        }
        scene.onStateUpdate = { updatedState in
            gameState = updatedState
        }

        gameScene = scene
    }

    /// Map old dungeon types to boss encounter IDs
    private func mapDungeonToBoss(_ dungeonType: String) -> String {
        switch dungeonType {
        case "cathedral": return "voidharbinger"
        case "void_raid": return "voidharbinger"
        case "heist": return "cyberboss"
        case "frozen": return "frost_titan"
        case "volcanic": return "inferno_lord"
        default: return "cyberboss"
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

// MARK: - Currency Info Sheet

struct CurrencyInfoSheet: View {
    let info: CurrencyInfoType
    @ObservedObject var appState = AppState.shared
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(DesignColors.muted)
                }
            }
            .padding(.horizontal)

            // Icon and title
            VStack(spacing: 12) {
                Image(systemName: info.icon)
                    .font(.system(size: 48))
                    .foregroundColor(info.color)

                Text(info.title)
                    .font(DesignTypography.display(24))
                    .foregroundColor(.white)
            }

            // Description
            Text(info.description)
                .font(DesignTypography.body(14))
                .foregroundColor(DesignColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            // PSU Upgrade section (only for power info)
            if info == .power {
                psuUpgradeSection
            }

            Spacer()
        }
        .padding(.top, 20)
        .background(DesignColors.background)
        .presentationDetents([.height(info == .power ? 480 : 320)])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private var psuUpgradeSection: some View {
        let currentLevel = appState.currentPlayer.componentLevels.psu
        let tierName = ComponentLevels.psuTierName(at: currentLevel)
        let currentCapacity = BalanceConfig.Components.psuCapacity(at: currentLevel)
        let nextCapacity = currentLevel < ComponentLevels.maxLevel ? BalanceConfig.Components.psuCapacity(at: currentLevel + 1) : nil
        let upgradeCost = appState.currentPlayer.componentLevels.upgradeCost(for: .psu)
        let canAfford = upgradeCost != nil && appState.currentPlayer.hash >= upgradeCost!

        VStack(spacing: 16) {
            Divider()
                .background(DesignColors.muted.opacity(0.3))
                .padding(.horizontal)

            // Current PSU info
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.Currency.psuLevel)
                        .font(DesignTypography.caption(11))
                        .foregroundColor(DesignColors.muted)
                    Text("\(tierName) (\(currentCapacity)W)")
                        .font(DesignTypography.headline(16))
                        .foregroundColor(.yellow)
                }

                Spacer()

                if let nextCap = nextCapacity {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(L10n.Currency.nextLevel)
                            .font(DesignTypography.caption(11))
                            .foregroundColor(DesignColors.muted)
                        Text("\(nextCap)W")
                            .font(DesignTypography.headline(16))
                            .foregroundColor(.green)
                    }
                }
            }
            .padding(.horizontal, 24)

            // Upgrade button
            if let cost = upgradeCost {
                Button {
                    upgradePSU()
                } label: {
                    HStack {
                        Image(systemName: "bolt.badge.plus.fill")
                        Text(L10n.Currency.upgradePSU)
                        Spacer()
                        Text("Ħ \(cost)")
                            .font(DesignTypography.headline(14))
                    }
                    .font(DesignTypography.headline(14))
                    .foregroundColor(canAfford ? .black : DesignColors.muted)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(canAfford ? Color.yellow : DesignColors.surface)
                    .cornerRadius(12)
                }
                .disabled(!canAfford)
                .padding(.horizontal, 24)
            } else {
                Text(L10n.Currency.psuMaxed)
                    .font(DesignTypography.headline(14))
                    .foregroundColor(.green)
                    .padding(.horizontal, 24)
            }
        }
    }

    private func upgradePSU() {
        guard let cost = appState.currentPlayer.componentLevels.upgradeCost(for: .psu),
              appState.currentPlayer.hash >= cost else { return }

        HapticsService.shared.play(.success)
        appState.updatePlayer { profile in
            profile.hash -= cost
            profile.componentLevels.upgrade(.psu)
        }
    }
}
