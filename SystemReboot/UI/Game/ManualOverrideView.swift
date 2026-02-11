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
                                    .foregroundColor(i < gameController.health ? .red : .gray)
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
    private var playerNode: SKShapeNode!
    private var hazardNodes: [UUID: SKNode] = [:]

    // Pending expanding hazards waiting for warning animation to finish
    private var pendingExpandingHazards: [ManualOverrideSystem.Hazard] = []

    override func didMove(to view: SKView) {
        backgroundColor = UIColor(hex: "0a0a0f") ?? .black

        simState = ManualOverrideSystem.makeInitialState(sceneSize: size)
        previousHealth = simState.health

        setupCamera()
        setupPlayer()
        setupBoundary()
        setupBackground()
    }

    // MARK: - Setup

    private func setupCamera() {
        let cam = SKCameraNode()
        cam.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(cam)
        self.camera = cam
    }

    private func setupPlayer() {
        playerNode = SKShapeNode(circleOfRadius: 20)
        playerNode.fillColor = DesignColors.primaryUI
        playerNode.strokeColor = DesignColors.primaryUI.withAlphaComponent(0.8)
        playerNode.lineWidth = 3
        playerNode.glowWidth = 10
        playerNode.position = simState.playerPosition
        playerNode.zPosition = 10
        playerNode.name = "player"
        addChild(playerNode)

        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.1, duration: 0.5),
            SKAction.scale(to: 1.0, duration: 0.5)
        ])
        playerNode.run(SKAction.repeatForever(pulse))
    }

    private func setupBoundary() {
        let border = SKShapeNode(rect: CGRect(x: 20, y: 100, width: size.width - 40, height: size.height - 200), cornerRadius: 10)
        border.strokeColor = DesignColors.dangerUI.withAlphaComponent(0.3)
        border.fillColor = .clear
        border.lineWidth = 2
        border.glowWidth = 3
        border.zPosition = 1
        addChild(border)
    }

    private func setupBackground() {
        for x in stride(from: CGFloat(0), to: size.width, by: 40) {
            let line = SKShapeNode(rect: CGRect(x: x, y: 0, width: 1, height: size.height))
            line.fillColor = UIColor.white.withAlphaComponent(0.03)
            line.strokeColor = .clear
            line.zPosition = 0
            addChild(line)
        }
        for y in stride(from: CGFloat(0), to: size.height, by: 40) {
            let line = SKShapeNode(rect: CGRect(x: 0, y: y, width: size.width, height: 1))
            line.fillColor = UIColor.white.withAlphaComponent(0.03)
            line.strokeColor = .clear
            line.zPosition = 0
            addChild(line)
        }
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

        // Render player
        playerNode.position = simState.playerPosition
        if simState.invincibilityTimer > 0 {
            playerNode.alpha = sin(currentTime * 20) > 0 ? 1.0 : 0.3
        } else {
            playerNode.alpha = 1.0
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
            onHealthUpdate?(simState.health)
            playDamageEffects()

            if events.gameLost {
                onHealthUpdate?(simState.health)
            }
        }
    }

    // MARK: - Hazard Rendering

    private func createHazardNode(for hazard: ManualOverrideSystem.Hazard) {
        switch hazard.kind {
        case .projectile:
            let node = SKShapeNode(circleOfRadius: 15)
            node.fillColor = DesignColors.dangerUI
            node.strokeColor = DesignColors.dangerUI.withAlphaComponent(0.8)
            node.lineWidth = 2
            node.glowWidth = 8
            node.name = "hazard"
            node.zPosition = 5
            node.position = hazard.position
            addChild(node)
            hazardNodes[hazard.id] = node

        case .expanding:
            // Show warning animation first; the actual hazard node is created after
            showExpandingWarning(for: hazard)

        case .sweep(_, let isHorizontal, let gapStart, let gapEnd):
            let node = SKShapeNode()
            node.name = "hazard"
            node.zPosition = 5
            node.strokeColor = DesignColors.dangerUI
            node.lineWidth = 8
            node.glowWidth = 15
            node.position = hazard.position

            let path = CGMutablePath()
            if isHorizontal {
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: gapStart, y: 0))
                path.move(to: CGPoint(x: gapEnd, y: 0))
                path.addLine(to: CGPoint(x: size.width, y: 0))
            } else {
                let playAreaBottom: CGFloat = 120
                let playAreaTop = size.height - 120
                path.move(to: CGPoint(x: 0, y: playAreaBottom))
                path.addLine(to: CGPoint(x: 0, y: gapStart))
                path.move(to: CGPoint(x: 0, y: gapEnd))
                path.addLine(to: CGPoint(x: 0, y: playAreaTop))
            }
            node.path = path
            addChild(node)
            hazardNodes[hazard.id] = node
        }
    }

    private func showExpandingWarning(for hazard: ManualOverrideSystem.Hazard) {
        let warning = SKShapeNode(circleOfRadius: 30)
        warning.strokeColor = DesignColors.warningUI
        warning.fillColor = DesignColors.warningUI.withAlphaComponent(0.1)
        warning.lineWidth = 2
        warning.position = hazard.position
        warning.zPosition = 4
        addChild(warning)

        pendingExpandingHazards.append(hazard)

        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.2, duration: 0.2),
            SKAction.scale(to: 1.0, duration: 0.2)
        ])
        warning.run(SKAction.repeat(pulse, count: 3)) { [weak self] in
            warning.removeFromParent()

            guard let self else { return }

            // Create the actual expanding hazard node
            let node = SKShapeNode(circleOfRadius: 5)
            node.fillColor = DesignColors.dangerUI
            node.strokeColor = DesignColors.dangerUI
            node.glowWidth = 10
            node.position = hazard.position
            node.name = "hazard"
            node.zPosition = 5
            self.addChild(node)
            self.hazardNodes[hazard.id] = node
            self.pendingExpandingHazards.removeAll { $0.id == hazard.id }
        }
    }

    private func commitPendingExpandingHazards() {
        // Clean up pending hazards that were already removed from simulation
        // (e.g., if the system removed them before the warning animation finished)
        pendingExpandingHazards.removeAll { pending in
            !simState.hazards.contains { $0.id == pending.id }
        }
    }

    private func renderHazards() {
        for hazard in simState.hazards {
            guard let node = hazardNodes[hazard.id] else { continue }

            node.position = hazard.position

            // Update expanding hazard shape
            if case .expanding(let currentRadius, _) = hazard.kind,
               let shapeNode = node as? SKShapeNode {
                shapeNode.path = CGPath(
                    ellipseIn: CGRect(x: -currentRadius, y: -currentRadius,
                                      width: currentRadius * 2, height: currentRadius * 2),
                    transform: nil
                )
            }
        }
    }

    private func removeHazardNode(id: UUID) {
        guard let node = hazardNodes.removeValue(forKey: id) else { return }
        // Expanding hazards get a shrink animation
        if node.userData == nil {
            // Check if this was an expanding type by seeing if it has a circle path
            let shrink = SKAction.scale(to: 0, duration: 0.2)
            let remove = SKAction.removeFromParent()
            node.run(SKAction.sequence([shrink, remove]))
        } else {
            node.removeFromParent()
        }
    }

    // MARK: - Damage Effects

    private func playDamageEffects() {
        HapticsService.shared.play(.warning)

        // Screen shake
        let shake = SKAction.sequence([
            SKAction.moveBy(x: 10, y: 0, duration: 0.05),
            SKAction.moveBy(x: -20, y: 0, duration: 0.05),
            SKAction.moveBy(x: 15, y: 0, duration: 0.05),
            SKAction.moveBy(x: -10, y: 0, duration: 0.05),
            SKAction.moveBy(x: 5, y: 0, duration: 0.05)
        ])
        camera?.run(shake)

        // Flash red
        let flash = SKShapeNode(rect: CGRect(origin: .zero, size: size))
        flash.fillColor = UIColor.red.withAlphaComponent(0.3)
        flash.strokeColor = .clear
        flash.zPosition = 100
        flash.position = .zero
        addChild(flash)

        let fadeOut = SKAction.fadeOut(withDuration: 0.3)
        let remove = SKAction.removeFromParent()
        flash.run(SKAction.sequence([fadeOut, remove]))
    }
}
