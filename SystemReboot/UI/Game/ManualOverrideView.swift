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

// MARK: - Manual Override Scene (SpriteKit)

class ManualOverrideScene: SKScene {
    // Callbacks
    var onTimeUpdate: ((TimeInterval) -> Void)?
    var onHealthUpdate: ((Int) -> Void)?
    var onWin: (() -> Void)?

    // Game state
    private var timeRemaining: TimeInterval = BalanceConfig.ManualOverride.duration
    private var health: Int = BalanceConfig.ManualOverride.maxHealth
    private var isGameOver = false
    private var lastUpdateTime: TimeInterval = 0

    // Player
    private var playerNode: SKShapeNode!
    private var playerVelocity: CGPoint = .zero
    private let playerSpeed: CGFloat = BalanceConfig.ManualOverride.playerSpeed

    // Hazards
    private var hazards: [SKNode] = []
    private var hazardSpawnTimer: TimeInterval = 0
    private var hazardSpawnInterval: TimeInterval = BalanceConfig.ManualOverride.initialHazardSpawnInterval
    private var difficultyTimer: TimeInterval = 0

    // Invincibility after hit
    private var invincibilityTimer: TimeInterval = 0
    private let invincibilityDuration: TimeInterval = BalanceConfig.ManualOverride.invincibilityDuration

    override func didMove(to view: SKView) {
        backgroundColor = UIColor(hex: "0a0a0f") ?? .black

        setupPlayer()
        setupBoundary()
        setupBackground()
    }

    private func setupPlayer() {
        // Create player node - glowing orb
        playerNode = SKShapeNode(circleOfRadius: 20)
        playerNode.fillColor = DesignColors.primaryUI
        playerNode.strokeColor = DesignColors.primaryUI.withAlphaComponent(0.8)
        playerNode.lineWidth = 3
        playerNode.glowWidth = 10
        playerNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
        playerNode.zPosition = 10
        playerNode.name = "player"
        addChild(playerNode)

        // Add pulsing animation
        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.1, duration: 0.5),
            SKAction.scale(to: 1.0, duration: 0.5)
        ])
        playerNode.run(SKAction.repeatForever(pulse))
    }

    private func setupBoundary() {
        // Create boundary indicator
        let border = SKShapeNode(rect: CGRect(x: 20, y: 100, width: size.width - 40, height: size.height - 200), cornerRadius: 10)
        border.strokeColor = DesignColors.dangerUI.withAlphaComponent(0.3)
        border.fillColor = .clear
        border.lineWidth = 2
        border.glowWidth = 3
        border.zPosition = 1
        addChild(border)
    }

    private func setupBackground() {
        // Grid pattern
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

    func movePlayer(angle: CGFloat, distance: CGFloat) {
        let speed = playerSpeed * distance
        playerVelocity = CGPoint(
            x: cos(angle) * speed,
            y: -sin(angle) * speed  // Invert Y for screen coordinates
        )
    }

    func stopPlayer() {
        playerVelocity = .zero
    }

    override func update(_ currentTime: TimeInterval) {
        guard !isGameOver else { return }

        let deltaTime = lastUpdateTime == 0 ? 0 : currentTime - lastUpdateTime
        lastUpdateTime = currentTime

        // Update timer
        timeRemaining -= deltaTime
        onTimeUpdate?(timeRemaining)

        if timeRemaining <= 0 {
            // Player wins!
            isGameOver = true
            onWin?()
            return
        }

        // Update invincibility
        if invincibilityTimer > 0 {
            invincibilityTimer -= deltaTime
            // Flash effect
            playerNode.alpha = sin(currentTime * 20) > 0 ? 1.0 : 0.3
        } else {
            playerNode.alpha = 1.0
        }

        // Update difficulty (spawn faster over time)
        difficultyTimer += deltaTime
        if difficultyTimer >= 5 {
            difficultyTimer = 0
            hazardSpawnInterval = max(0.5, hazardSpawnInterval - 0.2)
        }

        // Spawn hazards
        hazardSpawnTimer += deltaTime
        if hazardSpawnTimer >= hazardSpawnInterval {
            hazardSpawnTimer = 0
            spawnHazard()
        }

        // Update player position
        updatePlayer(deltaTime: deltaTime)

        // Update hazards
        updateHazards(deltaTime: deltaTime)

        // Check collisions
        checkCollisions()
    }

    private func updatePlayer(deltaTime: TimeInterval) {
        var newX = playerNode.position.x + playerVelocity.x * CGFloat(deltaTime)
        var newY = playerNode.position.y + playerVelocity.y * CGFloat(deltaTime)

        // Clamp to bounds
        let padding: CGFloat = 30
        newX = max(padding, min(size.width - padding, newX))
        newY = max(120, min(size.height - 120, newY))

        playerNode.position = CGPoint(x: newX, y: newY)
    }

    private func spawnHazard() {
        let hazardType = Int.random(in: 0...2)

        switch hazardType {
        case 0:
            spawnProjectileHazard()
        case 1:
            spawnExpandingHazard()
        default:
            spawnSweepHazard()
        }
    }

    private func spawnProjectileHazard() {
        // Fast moving projectile from edge
        let hazard = SKShapeNode(circleOfRadius: 15)
        hazard.fillColor = DesignColors.dangerUI
        hazard.strokeColor = DesignColors.dangerUI.withAlphaComponent(0.8)
        hazard.lineWidth = 2
        hazard.glowWidth = 8
        hazard.name = "hazard"
        hazard.zPosition = 5

        // Random edge spawn
        let edge = Int.random(in: 0...3)
        var startPos: CGPoint
        var velocity: CGPoint
        let speed = CGFloat.random(in: BalanceConfig.ManualOverride.hazardSpeedMin...BalanceConfig.ManualOverride.hazardSpeedMax)
        let variance = BalanceConfig.ManualOverride.hazardVelocityVariance

        switch edge {
        case 0: // Top
            startPos = CGPoint(x: CGFloat.random(in: 50...(size.width - 50)), y: size.height - 100)
            velocity = CGPoint(x: CGFloat.random(in: -variance...variance), y: -speed)
        case 1: // Bottom
            startPos = CGPoint(x: CGFloat.random(in: 50...(size.width - 50)), y: 120)
            velocity = CGPoint(x: CGFloat.random(in: -variance...variance), y: speed)
        case 2: // Left
            startPos = CGPoint(x: 30, y: CGFloat.random(in: 150...(size.height - 150)))
            velocity = CGPoint(x: speed, y: CGFloat.random(in: -variance...variance))
        default: // Right
            startPos = CGPoint(x: size.width - 30, y: CGFloat.random(in: 150...(size.height - 150)))
            velocity = CGPoint(x: -speed, y: CGFloat.random(in: -variance...variance))
        }

        hazard.position = startPos
        hazard.userData = ["velocity": NSValue(cgPoint: velocity)]
        addChild(hazard)
        hazards.append(hazard)
    }

    private func spawnExpandingHazard() {
        // Warning indicator, then expanding danger zone
        let warningPos = CGPoint(
            x: CGFloat.random(in: 60...(size.width - 60)),
            y: CGFloat.random(in: 160...(size.height - 160))
        )

        // Warning circle
        let warning = SKShapeNode(circleOfRadius: 30)
        warning.strokeColor = DesignColors.warningUI
        warning.fillColor = DesignColors.warningUI.withAlphaComponent(0.1)
        warning.lineWidth = 2
        warning.position = warningPos
        warning.zPosition = 4
        addChild(warning)

        // Pulse warning
        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.2, duration: 0.2),
            SKAction.scale(to: 1.0, duration: 0.2)
        ])
        warning.run(SKAction.repeat(pulse, count: 3)) { [weak self] in
            warning.removeFromParent()

            // Spawn actual hazard
            let hazard = SKShapeNode(circleOfRadius: 5)
            hazard.fillColor = DesignColors.dangerUI
            hazard.strokeColor = DesignColors.dangerUI
            hazard.glowWidth = 10
            hazard.position = warningPos
            hazard.name = "hazard"
            hazard.zPosition = 5
            hazard.userData = ["expanding": true, "maxRadius": 60.0, "currentRadius": 5.0]
            self?.addChild(hazard)
            self?.hazards.append(hazard)
        }
    }

    private func spawnSweepHazard() {
        // Horizontal or vertical sweeping laser with a gap for the player to escape
        let isHorizontal = Bool.random()
        let gapSize: CGFloat = 70  // Gap wide enough for player (radius 15) to pass through

        let hazard = SKShapeNode()
        hazard.name = "hazard"
        hazard.zPosition = 5

        if isHorizontal {
            let startY = CGFloat.random(in: 150...(size.height - 150))
            // Random gap position along the width
            let gapStart = CGFloat.random(in: 40...(size.width - 40 - gapSize))

            let path = CGMutablePath()
            // First segment: from left edge to gap
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: gapStart, y: 0))
            // Second segment: from gap end to right edge
            path.move(to: CGPoint(x: gapStart + gapSize, y: 0))
            path.addLine(to: CGPoint(x: size.width, y: 0))

            hazard.path = path
            hazard.position = CGPoint(x: 0, y: startY)
            hazard.strokeColor = DesignColors.dangerUI
            hazard.lineWidth = 8
            hazard.glowWidth = 15

            let direction: CGFloat = Bool.random() ? 1 : -1
            hazard.userData = ["sweepVelocity": 80.0 * direction, "isHorizontal": true, "gapStart": gapStart, "gapEnd": gapStart + gapSize]
        } else {
            let startX = CGFloat.random(in: 50...(size.width - 50))
            // Random gap position along the height
            let playAreaTop = size.height - 120
            let playAreaBottom: CGFloat = 120
            let gapStart = CGFloat.random(in: (playAreaBottom + 20)...(playAreaTop - 20 - gapSize))

            let path = CGMutablePath()
            // First segment: from bottom to gap
            path.move(to: CGPoint(x: 0, y: playAreaBottom))
            path.addLine(to: CGPoint(x: 0, y: gapStart))
            // Second segment: from gap end to top
            path.move(to: CGPoint(x: 0, y: gapStart + gapSize))
            path.addLine(to: CGPoint(x: 0, y: playAreaTop))

            hazard.path = path
            hazard.position = CGPoint(x: startX, y: 0)
            hazard.strokeColor = DesignColors.dangerUI
            hazard.lineWidth = 8
            hazard.glowWidth = 15

            let direction: CGFloat = Bool.random() ? 1 : -1
            hazard.userData = ["sweepVelocity": 80.0 * direction, "isHorizontal": false, "gapStart": gapStart, "gapEnd": gapStart + gapSize]
        }

        addChild(hazard)
        hazards.append(hazard)
    }

    private func updateHazards(deltaTime: TimeInterval) {
        for hazard in hazards {
            guard let userData = hazard.userData else { continue }

            // Projectile movement
            if let velocityValue = userData["velocity"] as? NSValue {
                let velocity = velocityValue.cgPointValue
                hazard.position.x += velocity.x * CGFloat(deltaTime)
                hazard.position.y += velocity.y * CGFloat(deltaTime)

                // Remove if off screen
                if hazard.position.x < -50 || hazard.position.x > size.width + 50 ||
                   hazard.position.y < 50 || hazard.position.y > size.height + 50 {
                    hazard.removeFromParent()
                    hazards.removeAll { $0 === hazard }
                }
            }

            // Expanding hazard
            if userData["expanding"] as? Bool == true {
                var currentRadius = userData["currentRadius"] as? CGFloat ?? 5
                let maxRadius = userData["maxRadius"] as? CGFloat ?? 60

                currentRadius += 80 * CGFloat(deltaTime)

                if currentRadius >= maxRadius {
                    // Shrink and remove
                    let shrink = SKAction.scale(to: 0, duration: 0.2)
                    let remove = SKAction.removeFromParent()
                    hazard.run(SKAction.sequence([shrink, remove]))
                    hazards.removeAll { $0 === hazard }
                } else {
                    if let shapeNode = hazard as? SKShapeNode {
                        shapeNode.path = CGPath(ellipseIn: CGRect(x: -currentRadius, y: -currentRadius, width: currentRadius * 2, height: currentRadius * 2), transform: nil)
                        hazard.userData?["currentRadius"] = currentRadius
                    }
                }
            }

            // Sweep hazard
            if let sweepVelocity = userData["sweepVelocity"] as? CGFloat {
                let isHorizontal = userData["isHorizontal"] as? Bool ?? true

                if isHorizontal {
                    hazard.position.y += sweepVelocity * CGFloat(deltaTime)
                    if hazard.position.y < 100 || hazard.position.y > size.height - 100 {
                        hazard.removeFromParent()
                        hazards.removeAll { $0 === hazard }
                    }
                } else {
                    hazard.position.x += sweepVelocity * CGFloat(deltaTime)
                    if hazard.position.x < 20 || hazard.position.x > size.width - 20 {
                        hazard.removeFromParent()
                        hazards.removeAll { $0 === hazard }
                    }
                }
            }
        }
    }

    private func checkCollisions() {
        guard invincibilityTimer <= 0 else { return }

        let playerRadius: CGFloat = 15

        for hazard in hazards {
            guard let userData = hazard.userData else { continue }

            var collided = false

            // Check projectile/expanding collision (circle)
            if userData["velocity"] != nil || userData["expanding"] != nil {
                let hazardRadius = userData["currentRadius"] as? CGFloat ?? 15
                let distance = hypot(playerNode.position.x - hazard.position.x,
                                    playerNode.position.y - hazard.position.y)
                if distance < playerRadius + hazardRadius {
                    collided = true
                }
            }

            // Check sweep collision (line with gap)
            if userData["sweepVelocity"] != nil {
                let isHorizontal = userData["isHorizontal"] as? Bool ?? true
                let gapStart = userData["gapStart"] as? CGFloat ?? 0
                let gapEnd = userData["gapEnd"] as? CGFloat ?? 0

                if isHorizontal {
                    // Check if player is at the same Y level as the sweep line
                    if abs(playerNode.position.y - hazard.position.y) < playerRadius + 4 {
                        // Check if player is NOT in the gap (gap is in X coordinates)
                        let playerX = playerNode.position.x
                        let inGap = playerX > gapStart && playerX < gapEnd
                        if !inGap {
                            collided = true
                        }
                    }
                } else {
                    // Check if player is at the same X level as the sweep line
                    if abs(playerNode.position.x - hazard.position.x) < playerRadius + 4 {
                        // Check if player is NOT in the gap (gap is in Y coordinates)
                        let playerY = playerNode.position.y
                        let inGap = playerY > gapStart && playerY < gapEnd
                        if !inGap {
                            collided = true
                        }
                    }
                }
            }

            if collided {
                takeDamage()
                break
            }
        }
    }

    private func takeDamage() {
        health -= 1
        invincibilityTimer = invincibilityDuration
        onHealthUpdate?(health)

        HapticsService.shared.play(.warning)

        // Screen shake
        let shake = SKAction.sequence([
            SKAction.moveBy(x: 10, y: 0, duration: 0.05),
            SKAction.moveBy(x: -20, y: 0, duration: 0.05),
            SKAction.moveBy(x: 15, y: 0, duration: 0.05),
            SKAction.moveBy(x: -10, y: 0, duration: 0.05),
            SKAction.moveBy(x: 5, y: 0, duration: 0.05)
        ])

        if let camera = self.camera {
            camera.run(shake)
        } else {
            // Create camera for shake
            let cam = SKCameraNode()
            cam.position = CGPoint(x: size.width / 2, y: size.height / 2)
            addChild(cam)
            self.camera = cam
            cam.run(shake)
        }

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

        if health <= 0 {
            isGameOver = true
        }
    }
}
