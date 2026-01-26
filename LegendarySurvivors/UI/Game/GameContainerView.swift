import SwiftUI
import SpriteKit

// MARK: - Game Container View
// System: Reboot - Active/Debugger Mode
// Terminal hacker aesthetic with scan lines and glitch effects

struct GameContainerView: View {
    let gameMode: GameMode
    let onExit: () -> Void

    @ObservedObject var appState = AppState.shared
    @State private var gameState: GameState?
    @State private var gameScene: GameScene?
    @State private var showGameOver = false
    @State private var showVictory = false
    @State private var inputState = InputState()
    @State private var screenSize: CGSize = .zero
    @State private var showGlitchEffect = false
    @State private var scanLineOffset: CGFloat = 0
    @State private var previousHealth: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Game scene
                if let scene = gameScene {
                    SpriteView(scene: scene)
                        .ignoresSafeArea()
                } else {
                    Color.black
                        .ignoresSafeArea()
                        .onAppear {
                            screenSize = geometry.size
                            setupGame()
                        }
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

                // Virtual joystick overlay
                VirtualJoystick(
                    onMove: { angle, distance in
                        inputState.joystick = JoystickInput(angle: angle, distance: distance)
                        gameScene?.updateInput(inputState)
                    },
                    onStop: {
                        inputState.joystick = nil
                        gameScene?.updateInput(inputState)
                    }
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
                                            .frame(width: geo.size.width * (state.player.health / state.player.maxHealth))
                                    }
                                }
                                .frame(width: 140, height: 10)
                            }
                        }

                        Spacer()

                        // Center: Timer (prominent)
                        if let state = gameState {
                            VStack(spacing: 2) {
                                Text("TIME")
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

                    Spacer()

                    // Bottom: Level/XP indicator (optional)
                    if let state = gameState {
                        HStack(spacing: 16) {
                            // Level
                            HStack(spacing: 4) {
                                Text("LV")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.gray)
                                Text("\(state.upgradeLevel + 1)")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.cyan)
                            }

                            // XP bar
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.gray.opacity(0.3))
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.cyan)
                                        .frame(width: geo.size.width * state.xpBarProgress)
                                }
                            }
                            .frame(width: 100, height: 6)

                            // Coins
                            HStack(spacing: 4) {
                                Image(systemName: "dollarsign.circle.fill")
                                    .font(DesignTypography.headline(18))
                                    .foregroundColor(.yellow)
                                Text("\(state.coins)")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.yellow)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(10)
                        .padding(.bottom, 100) // Above joystick
                    }
                }

                // Game over overlay
                if showGameOver {
                    GameOverOverlay(
                        victory: false,
                        gameState: gameState,
                        onRetry: {
                            showGameOver = false
                            setupGame()
                        },
                        onExit: {
                            // Save run stats
                            if let state = gameState {
                                appState.recordRun(
                                    kills: state.stats.enemiesKilled,
                                    time: state.timeElapsed,
                                    coins: state.coins
                                )
                            }
                            onExit()
                        }
                    )
                }

                // Victory overlay
                if showVictory {
                    GameOverOverlay(
                        victory: true,
                        gameState: gameState,
                        onRetry: {
                            showVictory = false
                            setupGame()
                        },
                        onExit: {
                            if let state = gameState {
                                appState.recordRun(
                                    kills: state.stats.enemiesKilled,
                                    time: state.timeElapsed,
                                    coins: state.coins
                                )
                            }
                            onExit()
                        }
                    )
                }
            }
        }
    }

    private func setupGame() {
        // Use selected loadout from AppState
        let weaponType = appState.selectedWeapon
        let powerUpType = appState.selectedPowerup
        let arenaType = appState.selectedArena

        // Create game state based on mode
        let state: GameState
        if gameMode == .arena {
            state = GameStateFactory.shared.createArenaGameState(
                weaponType: weaponType,
                powerUpType: powerUpType,
                arenaType: arenaType
            )
        } else {
            state = GameStateFactory.shared.createDungeonGameState(
                weaponType: weaponType,
                powerUpType: powerUpType,
                arenaType: arenaType
            )
        }
        gameState = state

        // Create and configure scene with screen size for full-screen arena
        let scene = GameScene()
        scene.configure(gameState: state, screenSize: screenSize)
        scene.onGameOver = { finalState in
            gameState = finalState
            if finalState.victory {
                showVictory = true
            } else {
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
    let onRetry: () -> Void
    let onExit: () -> Void

    // Calculate Data reward (matches AppState.recordSurvivorRun formula)
    private var dataEarned: Int {
        guard let state = gameState else { return 0 }
        let kills = state.stats.enemiesKilled
        let time = state.timeElapsed
        let dataFromKills = kills / 20
        let dataFromTime = Int(time / 30)
        let victoryBonus = victory ? 10 : 0
        return max(1, dataFromKills + dataFromTime + victoryBonus)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 30) {
                // System: Reboot themed titles
                if victory {
                    Text("EXTRACTION COMPLETE")
                        .font(.system(size: 36, weight: .black, design: .monospaced))
                        .foregroundColor(.green)

                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                } else {
                    Text("DEBUG FAILED")
                        .font(.system(size: 36, weight: .black, design: .monospaced))
                        .foregroundColor(.red)

                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.red)
                }

                if let state = gameState {
                    VStack(spacing: 12) {
                        StatRow(label: "Time Survived", value: formatTime(state.timeElapsed))
                        StatRow(label: "Viruses Killed", value: "\(state.stats.enemiesKilled)")
                        StatRow(label: "Damage Dealt", value: formatNumber(Int(state.stats.damageDealt)))

                        Divider().background(Color.white.opacity(0.3))

                        // Data reward - primary currency from Active mode
                        HStack {
                            HStack(spacing: 6) {
                                Image(systemName: "memorychip")
                                    .foregroundColor(.green)
                                Text("DATA EXTRACTED")
                            }
                            .font(.system(size: 16))
                            .foregroundColor(.gray)

                            Spacer()

                            Text("+\(dataEarned)")
                                .font(.system(size: 24, weight: .bold, design: .monospaced))
                                .foregroundColor(.green)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.green.opacity(0.3), lineWidth: 1)
                            )
                    )
                }

                HStack(spacing: 20) {
                    Button(action: onRetry) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("RETRY")
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
                            Text("MENU")
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
