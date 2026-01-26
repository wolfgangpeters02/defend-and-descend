import SwiftUI
import SpriteKit

// MARK: - Game Container View

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
                                        .font(.title2)
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
                                        .font(.title3)
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
                                    .font(.title)
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
                                    .font(.title3)
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
            gameState = updatedState
        }

        gameScene = scene
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

// MARK: - Game Over Overlay

struct GameOverOverlay: View {
    let victory: Bool
    let gameState: GameState?
    let onRetry: () -> Void
    let onExit: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 30) {
                if victory {
                    Text("VICTORY!")
                        .font(.system(size: 48, weight: .black))
                        .foregroundColor(.yellow)

                    Image(systemName: "crown.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.yellow)
                } else {
                    Text("GAME OVER")
                        .font(.system(size: 48, weight: .black))
                        .foregroundColor(.red)
                }

                if let state = gameState {
                    VStack(spacing: 12) {
                        StatRow(label: "Time Survived", value: formatTime(state.timeElapsed))
                        StatRow(label: "Enemies Killed", value: "\(state.stats.enemiesKilled)")
                        StatRow(label: "Damage Dealt", value: formatNumber(Int(state.stats.damageDealt)))
                        StatRow(label: "Coins Collected", value: "\(state.stats.coinsCollected)")
                        StatRow(label: "Upgrades", value: "\(state.stats.upgradesChosen)")
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.1))
                    )
                }

                HStack(spacing: 20) {
                    Button(action: onRetry) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("RETRY")
                        }
                        .font(.system(size: 18, weight: .bold))
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
                        .font(.system(size: 18, weight: .bold))
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

#Preview {
    GameContainerView(gameMode: .arena, onExit: {})
}
