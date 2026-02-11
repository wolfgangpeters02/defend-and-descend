import SwiftUI
import SpriteKit

// MARK: - TD Stat Row
// Extracted from TDGameContainerView.swift for maintainability

struct TDStatRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(DesignTypography.caption(10))
            Text("\(label):")
                .foregroundColor(.gray)
            Text(value)
                .foregroundColor(.white)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Resource Indicator

struct ResourceIndicator: View {
    let icon: String
    let value: Int
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(DesignTypography.caption(12))
            Text("\(value)")
                .foregroundColor(.white)
                .fontWeight(.bold)
                .font(DesignTypography.body(14))
        }
    }
}

// MARK: - Wave Progress Bar

struct WaveProgressBar: View {
    let current: Int
    let total: Int

    private var progress: CGFloat {
        guard total > 0 else { return 1.0 }
        return CGFloat(total - current) / CGFloat(total)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.gray.opacity(0.3))

                // Progress fill
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [.green, .yellow]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * progress)
            }
        }
        .frame(height: 4)
    }
}

// MARK: - Countdown Bar

struct CountdownBar: View {
    let seconds: TimeInterval
    let maxSeconds: TimeInterval

    private var progress: CGFloat {
        CGFloat(seconds / maxSeconds)
    }

    var body: some View {
        VStack(spacing: 2) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.3))

                    // Progress fill
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.yellow)
                        .frame(width: geometry.size.width * progress)
                }
            }
            .frame(height: 4)

            Text(L10n.Stats.nextSeconds(Int(seconds)))
                .font(DesignTypography.caption(10))
                .foregroundColor(.yellow)
        }
    }
}

// MARK: - Game End Stat Row

struct GameEndStatRow: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(DesignTypography.headline(22))
                .foregroundColor(color)
                .frame(width: 32)
            Text(label)
                .font(.system(size: 18))
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Boss Loot Modal Wrapper
// Wrapper to handle optional reward gracefully in fullScreenCover

struct BossLootModalWrapper: View {
    let reward: BossLootReward?
    let onCollect: () -> Void

    var body: some View {
        if let reward = reward {
            BossLootModal(reward: reward, onCollect: onCollect)
        } else {
            // Fallback - should never happen but prevents empty content issues
            Color.black.ignoresSafeArea()
                .onAppear {
                    onCollect()  // Dismiss immediately
                }
        }
    }
}

// MARK: - Zero-Day Boss Fight

enum ZeroDayBossFightResult {
    case victory(hashBonus: Int)
    case defeat
    case fled
}

struct ZeroDayBossFightView: View {
    let onComplete: (ZeroDayBossFightResult) -> Void

    @ObservedObject var appState = AppState.shared
    @State private var gameState: GameState?
    @State private var gameScene: GameScene?
    @State private var showResult = false
    @State private var didWin = false
    @State private var timeRemaining: TimeInterval = BalanceConfig.ManualOverride.duration
    @State private var timer: Timer?

    private let survivalDuration: TimeInterval = BalanceConfig.ManualOverride.duration

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Game scene
                if let scene = gameScene {
                    SpriteView(scene: scene)
                        .ignoresSafeArea()
                } else {
                    Color.black.ignoresSafeArea()
                    ProgressView()
                        .tint(.red)
                }

                // HUD
                VStack {
                    // Top bar
                    HStack {
                        // Flee button
                        Button {
                            timer?.invalidate()
                            onComplete(.fled)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark")
                                Text(L10n.Common.flee)
                            }
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.red)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(8)
                        }

                        Spacer()

                        // Title
                        Text(L10n.ZeroDay.overrideTitle)
                            .font(.system(size: 16, weight: .black, design: .monospaced))
                            .foregroundColor(.red)

                        Spacer()

                        // Timer
                        Text(String(format: "%.1f", timeRemaining))
                            .font(.system(size: 24, weight: .black, design: .monospaced))
                            .foregroundColor(timeRemaining > BalanceConfig.ZeroDayFight.timerWarningThreshold ? .green : .red)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(8)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    Spacer()

                    // Health bar
                    if let state = gameState {
                        HStack {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.red)
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.gray.opacity(0.3))
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.red)
                                        .frame(width: geo.size.width * CGFloat(state.player.health / state.player.maxHealth))
                                }
                            }
                            .frame(height: 12)
                            Text("\(Int(state.player.health))")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 100)
                    }
                }

                // Result overlay
                if showResult {
                    resultOverlay
                }
            }
            .onChange(of: geometry.size) { newSize in
                if gameScene == nil && newSize.width > 0 && newSize.height > 0 {
                    setupBossFight(screenSize: newSize)
                }
            }
            .onAppear {
                if geometry.size.width > 0 && geometry.size.height > 0 {
                    setupBossFight(screenSize: geometry.size)
                }
            }
            .onDisappear {
                timer?.invalidate()
            }
        }
    }

    private var resultOverlay: some View {
        ZStack {
            Color.black.opacity(0.9).ignoresSafeArea()

            VStack(spacing: 24) {
                if didWin {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)

                    Text(L10n.ZeroDay.neutralized)
                        .font(.system(size: 28, weight: .black, design: .monospaced))
                        .foregroundColor(.green)

                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "memorychip")
                                .foregroundColor(.green)
                            Text(L10n.ZeroDay.dataReward)
                                .foregroundColor(.green)
                        }
                        HStack {
                            Image(systemName: "bolt.fill")
                                .foregroundColor(.cyan)
                            Text(L10n.ZeroDay.wattsReward)
                                .foregroundColor(.cyan)
                        }
                    }
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                } else {
                    Image(systemName: "xmark.shield.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.red)

                    Text(L10n.ZeroDay.overrideFailed)
                        .font(.system(size: 28, weight: .black, design: .monospaced))
                        .foregroundColor(.red)

                    Text(L10n.ZeroDay.efficiencyPenalty)
                        .font(.system(size: 16, design: .monospaced))
                        .foregroundColor(.orange)
                }

                Button {
                    if didWin {
                        onComplete(.victory(hashBonus: 550))
                    } else {
                        onComplete(.defeat)
                    }
                } label: {
                    Text(L10n.Common.continueAction)
                        .font(.system(size: 18, weight: .black, design: .monospaced))
                        .foregroundColor(.black)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 14)
                        .background(didWin ? Color.green : Color.orange)
                        .cornerRadius(12)
                }
            }
        }
    }

    private func setupBossFight(screenSize: CGSize) {
        // Create a boss game state for the mini-game using Protocol
        let protocolId = appState.currentPlayer.equippedProtocolId ?? "kernel_pulse"
        let gameProtocol = ProtocolLibrary.all.first { $0.id == protocolId } ?? ProtocolLibrary.kernelPulse
        let state = GameStateFactory.shared.createBossGameState(
            gameProtocol: gameProtocol,
            bossType: "cyberboss",
            difficulty: .easy,
            playerProfile: appState.currentPlayer
        )
        gameState = state

        // Create and configure scene
        let scene = GameScene()
        scene.configure(gameState: state, screenSize: screenSize)
        scene.onGameOver = { finalState in
            timer?.invalidate()
            gameState = finalState
            didWin = false
            showResult = true
            HapticsService.shared.play(.defeat)
        }
        scene.onStateUpdate = { updatedState in
            gameState = updatedState
        }

        gameScene = scene

        // Start countdown timer
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            timeRemaining -= 0.1
            if timeRemaining <= 0 {
                timer?.invalidate()
                didWin = true
                showResult = true
                HapticsService.shared.play(.success)
            }
        }
    }
}
