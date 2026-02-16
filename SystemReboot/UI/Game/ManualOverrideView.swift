import SwiftUI
import SpriteKit

// MARK: - Manual Override Mini-Game View

struct ManualOverrideView: View {
    let onSuccess: () -> Void
    let onFailure: () -> Void
    let onCancel: () -> Void

    @StateObject private var gameController = ManualOverrideController()
    @State private var showingResult = false
    @State private var didWin = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dark background
                Color.black.ignoresSafeArea()

                // Game scene
                SpriteView(scene: gameController.scene)
                    .ignoresSafeArea()

                // HUD overlay
                VStack {
                    // Top bar with timer and health
                    HStack {
                        // Cancel button
                        Button {
                            HapticsService.shared.play(.light)
                            onCancel()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .padding(.leading, 16)

                        Spacer()

                        // Timer
                        VStack(spacing: 2) {
                            Text(L10n.Override.survive)
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(DesignColors.muted)

                            Text(String(format: "%.1f", max(0, gameController.timeRemaining)))
                                .font(.system(size: 32, weight: .black, design: .monospaced))
                                .foregroundColor(timerColor)
                        }

                        Spacer()

                        // Health
                        HStack(spacing: 4) {
                            ForEach(0..<3, id: \.self) { i in
                                Image(systemName: i < gameController.health ? "heart.fill" : "heart")
                                    .foregroundColor(i < gameController.health ? .red : DesignColors.textSecondary)
                                    .font(.system(size: 20))
                            }
                        }
                        .padding(.trailing, 16)
                    }
                    .padding(.top, 60)

                    Spacer()

                    // Joystick area
                    VirtualJoystick(
                        onMove: { angle, distance in
                            gameController.movePlayer(angle: angle, distance: distance)
                        },
                        onStop: {
                            gameController.stopPlayer()
                        },
                        config: JoystickConfig(
                            deadZone: 0.1,
                            snapToDirections: false,
                            enableHaptics: true,
                            enableMomentum: false
                        )
                    )
                    .frame(height: geometry.size.height * 0.4)
                }

                // Instructions (fade out after 2 seconds)
                if gameController.showInstructions {
                    VStack(spacing: 8) {
                        Text(L10n.Override.dodgeHazards)
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)

                        Text(L10n.Override.moveWithJoystick)
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(DesignColors.muted)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.8))
                    )
                    .transition(.opacity)
                }

                // Result overlay
                if showingResult {
                    resultOverlay
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                }
            }
        }
        .onReceive(gameController.$gameState) { state in
            switch state {
            case .won:
                didWin = true
                showingResult = true
                HapticsService.shared.play(.success)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    onSuccess()
                }
            case .lost:
                didWin = false
                showingResult = true
                HapticsService.shared.play(.defeat)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    onFailure()
                }
            case .playing:
                break
            }
        }
    }

    private var timerColor: Color {
        if gameController.timeRemaining <= 5 {
            return .red
        } else if gameController.timeRemaining <= 10 {
            return .orange
        } else {
            return DesignColors.success
        }
    }

    private var resultOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                if didWin {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(DesignColors.success)

                    Text(L10n.Override.systemRecovered)
                        .font(.system(size: 24, weight: .black, design: .monospaced))
                        .foregroundColor(.white)

                    Text(L10n.Override.efficiencyRestored)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(DesignColors.muted)
                } else {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.red)

                    Text(L10n.Override.failed)
                        .font(.system(size: 24, weight: .black, design: .monospaced))
                        .foregroundColor(.white)

                    Text(L10n.Override.tryAgain)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(DesignColors.muted)
                }
            }
        }
    }
}

// MARK: - Manual Override Controller

class ManualOverrideController: ObservableObject {
    enum GameState {
        case playing
        case won
        case lost
    }

    @Published var timeRemaining: TimeInterval = BalanceConfig.ManualOverride.duration
    @Published var health: Int = BalanceConfig.ManualOverride.maxHealth
    @Published var gameState: GameState = .playing
    @Published var showInstructions = true

    let scene: ManualOverrideScene

    init() {
        let scene = ManualOverrideScene(size: CGSize(width: 400, height: 600))
        scene.scaleMode = .aspectFill
        self.scene = scene

        scene.onTimeUpdate = { [weak self] time in
            DispatchQueue.main.async {
                self?.timeRemaining = time
            }
        }

        scene.onHealthUpdate = { [weak self] health in
            DispatchQueue.main.async {
                self?.health = health
                if health <= 0 {
                    self?.gameState = .lost
                }
            }
        }

        scene.onWin = { [weak self] in
            DispatchQueue.main.async {
                self?.gameState = .won
            }
        }

        // Hide instructions after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            withAnimation(.easeOut(duration: 0.5)) {
                self?.showInstructions = false
            }
        }
    }

    func movePlayer(angle: CGFloat, distance: CGFloat) {
        scene.movePlayer(angle: angle, distance: distance)
    }

    func stopPlayer() {
        scene.stopPlayer()
    }
}

// MARK: - Manual Override Scene (Thin Renderer)
// Visual compositions live in ManualOverrideScene+Visuals.swift extension.

class ManualOverrideScene: SKScene {
    // Callbacks
    var onTimeUpdate: ((TimeInterval) -> Void)?
    var onHealthUpdate: ((Int) -> Void)?
    var onWin: (() -> Void)?

    // Simulation state (domain logic lives in ManualOverrideSystem)
    private var simState: ManualOverrideSystem.State!
    private var lastUpdateTime: TimeInterval = 0
    private var previousHealth: Int = 0

    // Render nodes
    private var playerNode: SKNode!
    private var hazardNodes: [UUID: SKNode] = [:]
    // Track hazard types for removal animations
    private var hazardTypes: [UUID: HazardVisualType] = [:]
    private enum HazardVisualType { case projectile, expanding, sweep }

    // Pending expanding hazards waiting for warning animation to finish
    private var pendingExpandingHazards: [ManualOverrideSystem.Hazard] = []

    override func didMove(to view: SKView) {
        backgroundColor = DesignColors.backgroundUI

        simState = ManualOverrideSystem.makeInitialState(sceneSize: size)
        previousHealth = simState.health

        setupCamera()

        // Background (circuit board grid + copper traces)
        let bg = createCircuitBackground()
        addChild(bg)
        startAmbientDataFlow()

        // Border (copper double-stroke + corner pads)
        let border = createCircuitBorder()
        addChild(border)

        // Player (multi-node composition)
        playerNode = createPlayerComposition(at: simState.playerPosition)
        addChild(playerNode)
    }

    // MARK: - Setup

    private func setupCamera() {
        let cam = SKCameraNode()
        cam.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(cam)
        self.camera = cam
    }

    // MARK: - Input

    func movePlayer(angle: CGFloat, distance: CGFloat) {
        ManualOverrideSystem.applyJoystickInput(state: &simState, angle: angle, distance: distance)
    }

    func stopPlayer() {
        ManualOverrideSystem.stopPlayer(state: &simState)
    }

    // MARK: - Game Loop

    override func update(_ currentTime: TimeInterval) {
        guard simState != nil, !simState.isGameOver else { return }

        let deltaTime = lastUpdateTime == 0 ? 0 : currentTime - lastUpdateTime
        lastUpdateTime = currentTime

        // Tick simulation
        let events = ManualOverrideSystem.update(state: &simState, deltaTime: deltaTime, sceneSize: size)

        // Report state to UI
        onTimeUpdate?(simState.timeRemaining)

        if events.gameWon {
            onWin?()
            return
        }

        // Render player position + invincibility flicker
        playerNode.position = simState.playerPosition
        if simState.invincibilityTimer > 0 {
            playerNode.alpha = sin(currentTime * 20) > 0 ? 1.0 : 0.3
        } else {
            playerNode.alpha = 1.0
        }

        // Update player damage state visual (color shift based on health)
        if simState.health != previousHealth {
            updatePlayerDamageState(
                playerNode: playerNode,
                health: simState.health,
                maxHealth: BalanceConfig.ManualOverride.maxHealth)
        }

        // Handle spawned hazards
        for hazard in events.spawnedHazards {
            createHazardNode(for: hazard)
        }

        // Commit any pending expanding hazards whose warnings have finished
        commitPendingExpandingHazards()

        // Update hazard node positions/shapes from simulation state
        renderHazards()

        // Handle removed hazards
        for id in events.removedHazardIDs {
            removeHazardNode(id: id)
        }

        // Handle damage
        if events.damageDealt {
            previousHealth = simState.health
            onHealthUpdate?(simState.health)
            playUpgradedDamageEffects(playerPosition: simState.playerPosition)

            if events.gameLost {
                onHealthUpdate?(simState.health)
            }
        }
    }

    // MARK: - Hazard Rendering

    private func createHazardNode(for hazard: ManualOverrideSystem.Hazard) {
        switch hazard.kind {
        case .projectile:
            let node = createProjectileVirusNode(at: hazard.position)
            addChild(node)
            hazardNodes[hazard.id] = node
            hazardTypes[hazard.id] = .projectile

        case .expanding:
            pendingExpandingHazards.append(hazard)
            createExpandingWarning(at: hazard.position) { [weak self] in
                guard let self,
                      self.simState.hazards.contains(where: { $0.id == hazard.id }) else { return }
                let node = self.createExpandingHazardNode(at: hazard.position)
                self.addChild(node)
                self.hazardNodes[hazard.id] = node
                self.hazardTypes[hazard.id] = .expanding
                self.pendingExpandingHazards.removeAll { $0.id == hazard.id }
            }

        case .sweep:
            let node = createSweepScanNode(hazard: hazard, sceneSize: size)
            addChild(node)
            hazardNodes[hazard.id] = node
            hazardTypes[hazard.id] = .sweep
        }
    }

    private func commitPendingExpandingHazards() {
        pendingExpandingHazards.removeAll { pending in
            !simState.hazards.contains { $0.id == pending.id }
        }
    }

    private func renderHazards() {
        for hazard in simState.hazards {
            guard let node = hazardNodes[hazard.id] else { continue }

            node.position = hazard.position

            // Update expanding hazard child shapes
            if case .expanding(let currentRadius, _) = hazard.kind {
                updateExpandingHazardVisuals(node: node, currentRadius: currentRadius)
            }
        }
    }

    private func removeHazardNode(id: UUID) {
        guard let node = hazardNodes.removeValue(forKey: id) else { return }
        let type = hazardTypes.removeValue(forKey: id)

        switch type {
        case .projectile:
            animateProjectileRemoval(node)
        case .expanding:
            animateExpandingRemoval(node)
        case .sweep:
            animateSweepRemoval(node)
        case .none:
            node.removeFromParent()
        }
    }
}
