import SwiftUI
import SpriteKit

// MARK: - Notification for Boss Fight Completion
// Used to reliably communicate boss fight results back to TDGameContainerView
// (SwiftUI closure capture in fullScreenCover is unreliable)
extension Notification.Name {
    static let bossFightCompleted = Notification.Name("bossFightCompleted")
}

// MARK: - Game Container View
// System: Reboot - Active/Debugger Mode
// Terminal hacker aesthetic with scan lines and glitch effects

struct GameContainerView: View {
    let gameMode: GameMode
    var bossDifficulty: BossDifficulty = .normal
    let onExit: () -> Void
    var onBossFightComplete: ((Bool) -> Void)? = nil  // Called with victory result for boss mode

    @ObservedObject var appState = AppState.shared
    @State private var gameState: GameState?
    @State private var gameScene: GameScene?
    @State private var sceneId = UUID()  // Forces SpriteView refresh on retry
    @State private var showGameOver = false
    @State private var showVictory = false
    @State private var inputState = InputState()
    @State private var screenSize: CGSize = .zero
    @State private var showGlitchEffect = false
    @State private var scanLineOffset: CGFloat = 0
    @State private var previousHealth: CGFloat = 0
    @State private var awardedBlueprint: String?  // Protocol ID awarded from boss
    @State private var showBlueprintDiscovery = false
    @State private var blueprintDropResult: BlueprintDropSystem.DropResult?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Game scene
                if let scene = gameScene {
                    SpriteView(scene: scene)
                        .id(sceneId)  // Force refresh on retry
                        .ignoresSafeArea()
                } else {
                    Color.black
                        .ignoresSafeArea()
                }

                // Scan lines overlay - terminal aesthetic
                ScanLinesOverlay()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                // Glitch effect overlay (when player takes damage)
                if showGlitchEffect {
                    GlitchEffectOverlay()
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }

                // Virtual joystick overlay (no momentum for direct control)
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

                // HUD overlay - Mobile-first design with large readable elements
                VStack(spacing: 0) {
                    // Top HUD - Full width bar
                    HStack(alignment: .center, spacing: 0) {
                        // Left: Health bar (large)
                        if let state = gameState {
                            VStack(alignment: .leading, spacing: 4) {
                                // Health value
                                HStack(spacing: 6) {
                                    Image(systemName: "heart.fill")
                                        .font(DesignTypography.headline(22))
                                        .foregroundColor(.red)
                                    Text("\(Int(state.player.health))/\(Int(state.player.maxHealth))")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.white)
                                }

                                // Health bar - wider
                                GeometryReader { geo in
                                    let healthPercent = state.player.maxHealth > 0 ? max(0, min(1, state.player.health / state.player.maxHealth)) : 0
                                    let barWidth = max(1, geo.size.width * healthPercent)
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color.gray.opacity(0.3))
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(
                                                LinearGradient(
                                                    colors: [.red, .orange],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .frame(width: barWidth)
                                    }
                                }
                                .frame(width: 140, height: 10)
                            }
                        }

                        Spacer()

                        // Center: Timer (prominent)
                        if let state = gameState {
                            VStack(spacing: 2) {
                                Text(L10n.Game.HUD.time)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.gray)
                                Text(formatTime(state.timeElapsed))
                                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(10)
                        }

                        Spacer()

                        // Right: Stats + Exit
                        HStack(spacing: 16) {
                            // Kills
                            if let state = gameState {
                                HStack(spacing: 4) {
                                    Image(systemName: "flame.fill")
                                        .font(DesignTypography.headline(18))
                                        .foregroundColor(.orange)
                                    Text("\(state.stats.enemiesKilled)")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }

                            // Exit button
                            Button(action: {
                                HapticsService.shared.play(.light)
                                onExit()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(DesignTypography.display(28))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [Color.black.opacity(0.8), Color.black.opacity(0.4)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    // Boss Health Bar (boss mode only)
                    if gameMode == .boss || gameMode == .dungeon,
                       let state = gameState,
                       let boss = state.enemies.first(where: { $0.isBoss && !$0.isDead }) {
                        VStack(spacing: 4) {
                            // Boss name (format type string for display)
                            Text(boss.type.replacingOccurrences(of: "_", with: " ").uppercased())
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(.purple)

                            // Boss HP bar - full width
                            GeometryReader { geo in
                                let healthPercent = boss.maxHealth > 0 ? max(0, min(1, boss.health / boss.maxHealth)) : 0
                                let barWidth = max(1, geo.size.width * CGFloat(healthPercent))
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.gray.opacity(0.3))
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(
                                            LinearGradient(
                                                colors: [.purple, .red],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: barWidth)
                                }
                            }
                            .frame(height: 12)

                            // Boss HP text
                            Text("\(Int(boss.health)) / \(Int(boss.maxHealth))")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.horizontal, 40)
                        .padding(.top, 8)
                    }

                    Spacer()

                    // Bottom: Level/XP indicator (optional)
                    if let state = gameState {
                        HStack(spacing: 16) {
                            // Level
                            HStack(spacing: 4) {
                                Text(L10n.Game.HUD.level)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.gray)
                                Text("\(state.upgradeLevel + 1)")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.cyan)
                            }

                            // XP bar
                            GeometryReader { geo in
                                let xpPercent = max(0, min(1, state.xpBarProgress))
                                let xpWidth = max(1, geo.size.width * xpPercent)
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.gray.opacity(0.3))
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.cyan)
                                        .frame(width: xpWidth)
                                }
                            }
                            .frame(width: 100, height: 6)

                            // Hash (Ħ) earned display
                            HStack(spacing: 4) {
                                Text("Ħ")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(DesignColors.primary)
                                Text("\(state.stats.hashEarned)")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(DesignColors.primary)
                            }

                            // Extraction button (survival mode only, after 3 min)
                            if (gameMode == .survival || gameMode == .arena) && state.stats.extractionAvailable {
                                Button(action: {
                                    HapticsService.shared.play(.medium)
                                    gameScene?.triggerExtraction()
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "arrow.up.circle.fill")
                                            .font(.system(size: 16, weight: .bold))
                                        Text(L10n.Game.HUD.extract)
                                            .font(.system(size: 14, weight: .bold))
                                    }
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(DesignColors.success)
                                    .cornerRadius(8)
                                }
                                .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(10)
                        .padding(.bottom, 100) // Above joystick
                        .animation(.easeInOut(duration: 0.3), value: state.stats.extractionAvailable)
                    }
                }

                // Game over overlay
                if showGameOver {
                    GameOverOverlay(
                        victory: false,
                        gameState: gameState,
                        onRetry: {
                            showGameOver = false
                            sceneId = UUID()  // Force SpriteView refresh
                            setupGame()
                        },
                        onExit: {
                            // Save run stats with Hash rewards
                            if let state = gameState {
                                appState.recordSurvivorRun(
                                    time: state.timeElapsed,
                                    kills: state.stats.enemiesKilled,
                                    sessionHash: state.sessionHash,
                                    gameMode: gameMode,
                                    victory: false,
                                    hashEarned: state.stats.hashEarned,
                                    extracted: state.stats.extracted
                                )
                            }
                            onExit()
                        }
                    )
                }

                // Victory overlay (includes extraction and boss rewards)
                if showVictory && !showBlueprintDiscovery {
                    GameOverOverlay(
                        victory: true,
                        gameState: gameState,
                        awardedBlueprint: awardedBlueprint,
                        onRetry: {
                            showVictory = false
                            awardedBlueprint = nil
                            blueprintDropResult = nil
                            sceneId = UUID()  // Force SpriteView refresh
                            setupGame()
                        },
                        onExit: {
                            if let state = gameState {
                                appState.recordSurvivorRun(
                                    time: state.timeElapsed,
                                    kills: state.stats.enemiesKilled,
                                    sessionHash: state.sessionHash,
                                    gameMode: gameMode,
                                    victory: true,
                                    hashEarned: state.stats.hashEarned,
                                    extracted: state.stats.extracted
                                )
                            }
                            onExit()
                        }
                    )
                }

                // Blueprint reveal modal (4-tap decoding experience)
                if showBlueprintDiscovery, let dropResult = blueprintDropResult, let protocolId = dropResult.protocolId {
                    BlueprintRevealModal(
                        protocolId: protocolId,
                        isFirstKill: dropResult.isFirstKill,
                        onDismiss: {
                            showBlueprintDiscovery = false
                        }
                    )
                }
            }
            // Setup game when we have valid geometry
            .onChange(of: geometry.size) { newSize in
                if gameScene == nil && newSize.width > 0 && newSize.height > 0 {
                    screenSize = newSize
                    setupGame()
                }
            }
            .onAppear {
                print("[GameContainerView] onAppear - geometry: \(geometry.size), gameScene: \(gameScene == nil ? "nil" : "exists")")
                // Also try on appear in case geometry is already valid
                if gameScene == nil && geometry.size.width > 0 && geometry.size.height > 0 {
                    screenSize = geometry.size
                    setupGame()
                }
            }
        }
    }

    private func setupGame() {
        print("[GameContainerView] setupGame - screenSize: \(screenSize)")

        // Use selected Protocol from AppState (unified weapon system)
        let gameProtocol = appState.selectedProtocolObject
        let arenaType = appState.selectedArena

        // All active game modes now use boss encounter architecture
        let bossType = mapArenaToBoss(arenaType)
        let state = GameStateFactory.shared.createBossGameState(
            gameProtocol: gameProtocol,
            bossType: bossType,
            difficulty: bossDifficulty,
            playerProfile: appState.currentPlayer
        )
        gameState = state

        print("[GameContainerView] Created game state - arena: \(state.arena.width)x\(state.arena.height), player at: (\(state.player.x), \(state.player.y))")

        // Create and configure scene with screen size for full-screen arena
        let scene = GameScene()
        scene.configure(gameState: state, screenSize: screenSize)

        // Initialize boss for boss mode
        if gameMode == .boss || gameMode == .dungeon, let bossId = state.activeBossId {
            scene.initializeBoss(bossId: bossId)
        }

        scene.onGameOver = { finalState in
            print("[GameContainer] onGameOver called - victory=\(finalState.victory), gameMode=\(gameMode)")
            gameState = finalState
            if finalState.victory {
                // For boss mode from TD: dismiss first, then post notification with delay
                if gameMode == .boss {
                    print("[GameContainer] Boss mode victory - dismissing and posting notification")
                    onExit()  // Dismiss fullScreenCover first
                    // Post notification after a short delay so parent view is active
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        print("[GameContainer] Posting bossFightCompleted notification (victory)")
                        NotificationCenter.default.post(
                            name: .bossFightCompleted,
                            object: nil,
                            userInfo: ["victory": true]
                        )
                    }
                    return
                }
                showVictory = true
            } else {
                // For boss mode, losing means player retreated
                if gameMode == .boss {
                    print("[GameContainer] Boss mode loss - dismissing and posting notification")
                    onExit()  // Dismiss fullScreenCover first
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        print("[GameContainer] Posting bossFightCompleted notification (loss)")
                        NotificationCenter.default.post(
                            name: .bossFightCompleted,
                            object: nil,
                            userInfo: ["victory": false]
                        )
                    }
                    return
                }
                showGameOver = true
            }
        }
        scene.onStateUpdate = { updatedState in
            // Check for damage taken (health decreased)
            if let currentState = gameState {
                if updatedState.player.health < currentState.player.health {
                    triggerGlitchEffect()
                }
            }
            gameState = updatedState
        }

        // Initialize previous health
        previousHealth = state.player.health

        gameScene = scene
    }

    /// Maps arena/dungeon type to boss type for boss encounters
    private func mapArenaToBoss(_ arenaType: String) -> String {
        switch arenaType {
        // New boss IDs from BossEncounter
        case "cyberboss", "rogue_process":
            return "cyberboss"
        case "void_harbinger", "memory_leak":
            return "void_harbinger"
        // Legacy mappings
        case "server_room", "mainframe", "network":
            return "cyberboss"
        case "void", "corruption", "dark":
            return "void_harbinger"
        default:
            return "cyberboss"  // Default to cyberboss
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    /// Trigger the glitch visual effect when taking damage
    private func triggerGlitchEffect() {
        // Show glitch effect briefly
        showGlitchEffect = true
        HapticsService.shared.play(.light)

        // Hide after short duration
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            showGlitchEffect = false
        }
    }
}

// MARK: - Game Over Overlay

struct GameOverOverlay: View {
    let victory: Bool
    let gameState: GameState?
    var awardedBlueprint: String? = nil  // Protocol ID awarded from boss
    let onRetry: () -> Void
    let onExit: () -> Void

    // Calculate actual Hash reward from session
    private var hashEarned: Int {
        guard let state = gameState else { return 0 }
        return state.stats.hashEarned
    }

    // Final reward after extraction multiplier
    private var finalHashReward: Int {
        guard let state = gameState else { return 0 }
        return state.stats.finalHashReward()
    }

    // Did player extract successfully?
    private var didExtract: Bool {
        gameState?.stats.extracted ?? false
    }

    // Get protocol name for display
    private var awardedProtocolName: String? {
        guard let id = awardedBlueprint else { return nil }
        return ProtocolLibrary.get(id)?.name
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 30) {
                // System: Reboot themed titles
                if victory {
                    Text(L10n.GameOver.victory)
                        .font(.system(size: 36, weight: .black, design: .monospaced))
                        .foregroundColor(.green)

                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                } else {
                    Text(L10n.GameOver.defeat)
                        .font(.system(size: 36, weight: .black, design: .monospaced))
                        .foregroundColor(.red)

                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.red)
                }

                if let state = gameState {
                    VStack(spacing: 12) {
                        StatRow(label: L10n.GameOver.timeSurvived, value: formatTime(state.timeElapsed))
                        StatRow(label: L10n.GameOver.virusesKilled, value: "\(state.stats.enemiesKilled)")
                        StatRow(label: L10n.GameOver.damageDealt, value: formatNumber(Int(state.stats.damageDealt)))

                        Divider().background(Color.white.opacity(0.3))

                        // Hash reward - universal currency
                        VStack(spacing: 8) {
                            HStack {
                                HStack(spacing: 6) {
                                    Text("Ħ")
                                        .font(.system(size: 18, weight: .bold))
                                    Text(L10n.GameOver.hashCollected)
                                }
                                .font(.system(size: 14))
                                .foregroundColor(.gray)

                                Spacer()

                                Text("\(hashEarned)")
                                    .font(.system(size: 18, weight: .medium, design: .monospaced))
                                    .foregroundColor(.cyan.opacity(0.8))
                            }

                            HStack {
                                HStack(spacing: 6) {
                                    Image(systemName: didExtract ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundColor(didExtract ? .green : .orange)
                                    Text(didExtract ? L10n.GameOver.extractionBonus : L10n.GameOver.deathPenalty)
                                }
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(didExtract ? .green : .orange)

                                Spacer()

                                Text("+Ħ\(finalHashReward)")
                                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                                    .foregroundColor(didExtract ? .green : .orange)
                            }

                            // Blueprint reward (boss mode only)
                            if let protocolName = awardedProtocolName {
                                Divider().background(Color.white.opacity(0.3))

                                HStack {
                                    HStack(spacing: 6) {
                                        Image(systemName: "doc.badge.plus")
                                            .foregroundColor(.purple)
                                        Text(L10n.GameOver.blueprintAcquired)
                                    }
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.purple)

                                    Spacer()

                                    Text(protocolName.uppercased())
                                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                                        .foregroundColor(.purple)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(awardedBlueprint != nil ? Color.purple.opacity(0.5) : Color.green.opacity(0.3), lineWidth: 1)
                            )
                    )
                }

                HStack(spacing: 20) {
                    Button(action: onRetry) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text(L10n.Common.retry)
                        }
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(.black)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 15)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.cyan)
                        )
                    }

                    Button(action: onExit) {
                        HStack {
                            Image(systemName: "house.fill")
                            Text(L10n.Common.menu)
                        }
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 15)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white, lineWidth: 2)
                        )
                    }
                }
            }
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    private func formatNumber(_ number: Int) -> String {
        if number >= 1000000 {
            return String(format: "%.1fM", Double(number) / 1000000)
        } else if number >= 1000 {
            return String(format: "%.1fK", Double(number) / 1000)
        }
        return "\(number)"
    }
}

struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 16))
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Scan Lines Overlay (Terminal Aesthetic)

struct ScanLinesOverlay: View {
    @State private var offset: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                // Draw horizontal scan lines every 4pt
                let lineSpacing: CGFloat = 4
                let lineHeight: CGFloat = 2
                var y: CGFloat = offset.truncatingRemainder(dividingBy: lineSpacing * 2)

                while y < size.height {
                    let rect = CGRect(x: 0, y: y, width: size.width, height: lineHeight)
                    context.fill(Path(rect), with: .color(.white.opacity(0.03)))
                    y += lineSpacing
                }
            }
            .onAppear {
                // Subtle slow scroll animation
                withAnimation(Animation.linear(duration: 8).repeatForever(autoreverses: false)) {
                    offset = 8 // One full cycle
                }
            }
        }
    }
}

// MARK: - Glitch Effect Overlay (Damage Feedback)

struct GlitchEffectOverlay: View {
    @State private var rgbOffset: CGFloat = 3
    @State private var slices: [GlitchSlice] = []

    struct GlitchSlice: Identifiable {
        let id = UUID()
        let yPosition: CGFloat
        let height: CGFloat
        let xOffset: CGFloat
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // RGB channel split effect
                Rectangle()
                    .fill(Color.red.opacity(0.15))
                    .offset(x: -rgbOffset, y: 0)
                    .blendMode(.screen)

                Rectangle()
                    .fill(Color.blue.opacity(0.15))
                    .offset(x: rgbOffset, y: 0)
                    .blendMode(.screen)

                // Horizontal displacement slices
                ForEach(slices) { slice in
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: geometry.size.width, height: slice.height)
                        .offset(x: slice.xOffset, y: slice.yPosition - geometry.size.height / 2)
                }
            }
            .onAppear {
                generateGlitchSlices(height: geometry.size.height)
            }
        }
    }

    private func generateGlitchSlices(height: CGFloat) {
        // Generate random horizontal displacement slices
        slices = (0..<Int.random(in: 3...8)).map { _ in
            GlitchSlice(
                yPosition: CGFloat.random(in: 0...height),
                height: CGFloat.random(in: 10...40),
                xOffset: CGFloat.random(in: -20...20)
            )
        }
    }
}

#Preview {
    GameContainerView(gameMode: .arena, onExit: {})
}
