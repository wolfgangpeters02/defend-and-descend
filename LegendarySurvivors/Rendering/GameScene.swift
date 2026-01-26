import SpriteKit
import CoreGraphics

// MARK: - Game Scene

class GameScene: SKScene {
    // State
    private var gameState: GameState!
    private var inputState = InputState()
    private var lastUpdateTime: TimeInterval = 0
    private var isInitialized = false

    // Rendering
    private var entityRenderer: EntityRenderer!
    private var backgroundNode: SKShapeNode?
    private var playerNode: SKNode?
    private var obstacleNodes: [SKNode] = []
    private var hazardNodes: [SKNode] = []

    // Entity node tracking (keyed by ID for efficient updates)
    private var enemyNodes: [String: SKNode] = [:]
    private var projectileNodes: [String: SKNode] = [:]
    private var pickupNodes: [String: SKNode] = [:]
    private var particleNodes: [String: SKNode] = [:]

    // Cached HUD Elements (Phase 1.3 - HUD Caching)
    private var hudLayer: SKNode!
    private var healthBarBg: SKShapeNode!
    private var healthBarFill: SKShapeNode!
    private var healthText: SKLabelNode!
    private var timerText: SKLabelNode!
    private var killText: SKLabelNode!
    private var lastHealthPercent: CGFloat = 1.0
    private var lastKillCount: Int = 0
    private var lastTimeSeconds: Int = 0

    // Player invulnerability animation (Phase 1.4 - SKAction Animations)
    private var invulnerabilityAction: SKAction?
    private var isPlayingInvulnerability = false

    // Screen effects
    private var screenFlashNode: SKShapeNode?
    private var cameraNode: SKCameraNode?

    // Callbacks
    var onGameOver: ((GameState) -> Void)?
    var onStateUpdate: ((GameState) -> Void)?

    // Screen size for dynamic scaling
    private var screenSize: CGSize = .zero

    // MARK: - Setup

    func configure(gameState: GameState, screenSize: CGSize? = nil) {
        self.gameState = gameState
        self.entityRenderer = EntityRenderer()

        // Use screen size if provided, otherwise fall back to arena size
        if let screenSize = screenSize {
            self.screenSize = screenSize
            // Update arena dimensions to match screen
            self.gameState.arena.width = screenSize.width
            self.gameState.arena.height = screenSize.height
            // Reposition player to center of new arena
            self.gameState.player.x = screenSize.width / 2
            self.gameState.player.y = screenSize.height / 2
        } else {
            self.screenSize = CGSize(width: gameState.arena.width, height: gameState.arena.height)
        }

        setupScene()
        isInitialized = true
    }

    private func setupScene() {
        backgroundColor = colorFromHex(gameState.arena.backgroundColor)

        // Scene fills the screen
        self.size = screenSize
        self.scaleMode = .resizeFill

        // Setup camera for screen shake
        setupCamera()

        // Create layers
        setupBackground()
        setupObstacles()
        setupHazards()
        setupHUD()
        setupScreenFlash()
        setupInvulnerabilityAnimation()
    }

    private func setupCamera() {
        cameraNode = SKCameraNode()
        cameraNode?.position = CGPoint(x: gameState.arena.width / 2, y: gameState.arena.height / 2)
        addChild(cameraNode!)
        camera = cameraNode
    }

    private func setupBackground() {
        backgroundNode = SKShapeNode(rectOf: CGSize(width: gameState.arena.width, height: gameState.arena.height))
        backgroundNode?.fillColor = colorFromHex(gameState.arena.backgroundColor)
        backgroundNode?.strokeColor = .clear
        backgroundNode?.position = CGPoint(x: gameState.arena.width / 2, y: gameState.arena.height / 2)
        backgroundNode?.zPosition = -100
        addChild(backgroundNode!)
    }

    private func setupObstacles() {
        for obstacle in gameState.arena.obstacles {
            let node = SKShapeNode(rectOf: CGSize(width: obstacle.width, height: obstacle.height))
            node.fillColor = colorFromHex(obstacle.color)
            node.strokeColor = colorFromHex(obstacle.color).darker(by: 0.2)
            node.lineWidth = 2
            node.position = CGPoint(
                x: obstacle.x + obstacle.width / 2,
                y: gameState.arena.height - (obstacle.y + obstacle.height / 2) // Flip Y
            )
            node.zPosition = 10
            obstacleNodes.append(node)
            addChild(node)
        }
    }

    private func setupHazards() {
        for hazard in gameState.arena.hazards {
            let node = SKShapeNode(rectOf: CGSize(width: hazard.width, height: hazard.height))
            node.fillColor = hazardColor(for: hazard.type)
            node.strokeColor = .clear
            node.alpha = 0.7
            node.position = CGPoint(
                x: hazard.x + hazard.width / 2,
                y: gameState.arena.height - (hazard.y + hazard.height / 2) // Flip Y
            )
            node.zPosition = 5

            // Add pulsing effect for hazards (SKAction-based)
            let pulse = SKAction.sequence([
                SKAction.fadeAlpha(to: 0.5, duration: 0.5),
                SKAction.fadeAlpha(to: 0.7, duration: 0.5)
            ])
            node.run(SKAction.repeatForever(pulse))

            hazardNodes.append(node)
            addChild(node)
        }
    }

    // MARK: - HUD Setup (Cached - Phase 1.3)

    private func setupHUD() {
        hudLayer = SKNode()
        hudLayer.zPosition = 1000
        addChild(hudLayer)

        // Health bar constants
        let healthBarWidth: CGFloat = 200
        let healthBarHeight: CGFloat = 20

        // Create health bar background (cached)
        healthBarBg = SKShapeNode(rectOf: CGSize(width: healthBarWidth, height: healthBarHeight), cornerRadius: 4)
        healthBarBg.fillColor = SKColor.darkGray
        healthBarBg.strokeColor = SKColor.white.withAlphaComponent(0.3)
        healthBarBg.position = CGPoint(x: 120, y: gameState.arena.height - 30)
        hudLayer.addChild(healthBarBg)

        // Create health bar fill (cached - update only fillColor and xScale)
        healthBarFill = SKShapeNode(rect: CGRect(
            x: -healthBarWidth / 2,
            y: -healthBarHeight / 2,
            width: healthBarWidth,
            height: healthBarHeight
        ), cornerRadius: 4)
        healthBarFill.fillColor = SKColor.green
        healthBarFill.strokeColor = .clear
        healthBarFill.position = healthBarBg.position
        hudLayer.addChild(healthBarFill)

        // Create health text (cached)
        healthText = SKLabelNode(text: "\(Int(gameState.player.maxHealth))/\(Int(gameState.player.maxHealth))")
        healthText.fontName = "Helvetica-Bold"
        healthText.fontSize = 14
        healthText.fontColor = .white
        healthText.position = CGPoint(x: healthBarBg.position.x, y: healthBarBg.position.y - 5)
        hudLayer.addChild(healthText)

        // Create timer text (cached)
        timerText = SKLabelNode(text: "0:00")
        timerText.fontName = "Helvetica-Bold"
        timerText.fontSize = 24
        timerText.fontColor = .white
        timerText.position = CGPoint(x: gameState.arena.width / 2, y: gameState.arena.height - 30)
        hudLayer.addChild(timerText)

        // Create kill counter (cached)
        killText = SKLabelNode(text: "Kills: 0")
        killText.fontName = "Helvetica"
        killText.fontSize = 16
        killText.fontColor = .white
        killText.horizontalAlignmentMode = .right
        killText.position = CGPoint(x: gameState.arena.width - 20, y: gameState.arena.height - 30)
        hudLayer.addChild(killText)
    }

    // MARK: - Screen Effects Setup (Phase 1.4)

    private func setupScreenFlash() {
        screenFlashNode = SKShapeNode(rectOf: CGSize(width: gameState.arena.width * 2, height: gameState.arena.height * 2))
        screenFlashNode?.fillColor = .white
        screenFlashNode?.strokeColor = .clear
        screenFlashNode?.alpha = 0
        screenFlashNode?.zPosition = 999
        screenFlashNode?.position = CGPoint(x: gameState.arena.width / 2, y: gameState.arena.height / 2)
        addChild(screenFlashNode!)
    }

    private func setupInvulnerabilityAnimation() {
        // Pre-create the invulnerability flash action
        invulnerabilityAction = SKAction.repeatForever(
            SKAction.sequence([
                SKAction.fadeAlpha(to: 0.3, duration: 0.05),
                SKAction.fadeAlpha(to: 1.0, duration: 0.05)
            ])
        )
    }

    private func hazardColor(for type: String) -> SKColor {
        switch type {
        case "lava":
            return SKColor(red: 1.0, green: 0.3, blue: 0.0, alpha: 1.0)
        case "spikes":
            return SKColor.gray
        case "asteroid":
            return SKColor.darkGray
        default:
            return SKColor.red
        }
    }

    // MARK: - Screen Effects (Phase 1.4 - SKAction-based)

    /// Triggers a screen flash effect
    func flashScreen(color: SKColor = .white, intensity: CGFloat = 0.3, duration: TimeInterval = 0.1) {
        guard let flash = screenFlashNode else { return }

        flash.fillColor = color
        flash.removeAllActions()

        let flashAction = SKAction.sequence([
            SKAction.fadeAlpha(to: intensity, duration: 0.01),
            SKAction.fadeAlpha(to: 0, duration: duration)
        ])
        flash.run(flashAction)
    }

    /// Triggers a screen shake effect
    func shakeScreen(intensity: CGFloat = 5, duration: TimeInterval = 0.2) {
        guard let camera = cameraNode else { return }

        let originalPosition = CGPoint(x: gameState.arena.width / 2, y: gameState.arena.height / 2)
        camera.removeAction(forKey: "shake")

        let shakeCount = Int(duration / 0.02)
        var shakeActions: [SKAction] = []

        for i in 0..<shakeCount {
            let decayFactor = 1.0 - (CGFloat(i) / CGFloat(shakeCount))
            let offsetX = CGFloat.random(in: -intensity...intensity) * decayFactor
            let offsetY = CGFloat.random(in: -intensity...intensity) * decayFactor
            shakeActions.append(SKAction.move(to: CGPoint(
                x: originalPosition.x + offsetX,
                y: originalPosition.y + offsetY
            ), duration: 0.02))
        }

        shakeActions.append(SKAction.move(to: originalPosition, duration: 0.02))
        camera.run(SKAction.sequence(shakeActions), withKey: "shake")
    }

    // MARK: - Input

    func updateInput(_ input: InputState) {
        self.inputState = input
    }

    // MARK: - Game Loop

    override func update(_ currentTime: TimeInterval) {
        guard isInitialized else { return }

        // Calculate delta time
        let deltaTime = lastUpdateTime > 0 ? currentTime - lastUpdateTime : 0
        lastUpdateTime = currentTime

        // Cap delta time to prevent physics explosions
        let cappedDelta = min(deltaTime, 1.0 / 30.0)

        // Update game state
        updateGameState(deltaTime: cappedDelta)

        // Update rendering
        render()

        // Notify state update
        onStateUpdate?(gameState)

        // Check game over
        if gameState.isGameOver {
            onGameOver?(gameState)
        }
    }

    private func updateGameState(deltaTime: TimeInterval) {
        // Update time
        gameState.timeElapsed += deltaTime

        // Update player
        PlayerSystem.update(state: &gameState, input: inputState, deltaTime: deltaTime)

        // Spawn enemies (Phase 2)
        SpawnSystem.update(state: &gameState)

        // Spawn boss every 2 minutes
        if gameState.timeElapsed - gameState.lastBossSpawnTime >= GameConstants.bossSpawnInterval {
            SpawnSystem.spawnBoss(state: &gameState)
        }

        // Update enemies (Phase 2)
        EnemySystem.update(state: &gameState, deltaTime: deltaTime)

        // Update weapons - auto-fire (Phase 2)
        WeaponSystem.update(state: &gameState)

        // Update projectiles (Phase 2)
        ProjectileSystem.update(state: &gameState, deltaTime: deltaTime)

        // Update pickups (Phase 2)
        PickupSystem.update(state: &gameState, deltaTime: deltaTime)

        // Update particles
        updateParticles(deltaTime: deltaTime)
    }

    private func updateParticles(deltaTime: TimeInterval) {
        let now = Date().timeIntervalSince1970
        gameState.particles = gameState.particles.filter { now - $0.createdAt < $0.lifetime }

        // Update particle positions
        for i in 0..<gameState.particles.count {
            if let velocity = gameState.particles[i].velocity {
                gameState.particles[i].x += velocity.x * CGFloat(deltaTime)
                gameState.particles[i].y += velocity.y * CGFloat(deltaTime)

                // Apply drag
                if let drag = gameState.particles[i].drag, drag > 0 {
                    let newVelX = velocity.x * (1 - drag)
                    let newVelY = velocity.y * (1 - drag)
                    gameState.particles[i].velocity = CGPoint(x: newVelX, y: newVelY)
                }
            }
        }
    }

    // MARK: - Rendering

    private func render() {
        renderPlayer()
        renderEnemies()
        renderProjectiles()
        renderPickups()
        renderParticles()
        updateHUD() // Phase 1.3: Only update changed values
    }

    private func renderPlayer() {
        let player = gameState.player

        if playerNode == nil {
            playerNode = entityRenderer.createPlayerNode(size: player.size)
            addChild(playerNode!)
        }

        // Update position (flip Y coordinate)
        playerNode?.position = CGPoint(
            x: player.x,
            y: gameState.arena.height - player.y
        )
        playerNode?.zPosition = 100

        // Invulnerability flash using SKAction (Phase 1.4)
        if player.invulnerable {
            if !isPlayingInvulnerability, let action = invulnerabilityAction {
                playerNode?.run(action, withKey: "invulnerability")
                isPlayingInvulnerability = true
            }
        } else {
            if isPlayingInvulnerability {
                playerNode?.removeAction(forKey: "invulnerability")
                playerNode?.alpha = 1.0
                isPlayingInvulnerability = false
            }
        }
    }

    private func renderEnemies() {
        var activeIds = Set<String>()

        for enemy in gameState.enemies where !enemy.isDead {
            activeIds.insert(enemy.id)

            // Get or create node
            let node: SKNode
            if let existingNode = enemyNodes[enemy.id] {
                node = existingNode
            } else {
                node = entityRenderer.createEnemyNode(enemy: enemy)
                enemyNodes[enemy.id] = node
                addChild(node)
            }

            // Update position
            node.position = CGPoint(
                x: enemy.x,
                y: gameState.arena.height - enemy.y
            )
            node.zPosition = 50

            // Slow effect visual
            node.alpha = enemy.isSlowed ? 0.7 : 1.0
        }

        // Remove nodes for dead/removed enemies
        for (id, node) in enemyNodes where !activeIds.contains(id) {
            node.removeFromParent()
            enemyNodes.removeValue(forKey: id)
        }
    }

    private func renderProjectiles() {
        var activeIds = Set<String>()

        for projectile in gameState.projectiles {
            activeIds.insert(projectile.id)

            // Get or create node
            let node: SKNode
            if let existingNode = projectileNodes[projectile.id] {
                node = existingNode
            } else {
                node = entityRenderer.createProjectileNode(projectile: projectile)
                projectileNodes[projectile.id] = node
                addChild(node)
            }

            // Update position
            node.position = CGPoint(
                x: projectile.x,
                y: gameState.arena.height - projectile.y
            )
            node.zPosition = 75
        }

        // Remove nodes for removed projectiles
        for (id, node) in projectileNodes where !activeIds.contains(id) {
            node.removeFromParent()
            projectileNodes.removeValue(forKey: id)
        }
    }

    private func renderPickups() {
        var activeIds = Set<String>()

        for pickup in gameState.pickups {
            activeIds.insert(pickup.id)

            // Get or create node
            let node: SKNode
            if let existingNode = pickupNodes[pickup.id] {
                node = existingNode
            } else {
                node = entityRenderer.createPickupNode(pickup: pickup)
                pickupNodes[pickup.id] = node
                addChild(node)
            }

            // Update position
            node.position = CGPoint(
                x: pickup.x,
                y: gameState.arena.height - pickup.y
            )
            node.zPosition = 25
        }

        // Remove nodes for collected pickups
        for (id, node) in pickupNodes where !activeIds.contains(id) {
            node.removeFromParent()
            pickupNodes.removeValue(forKey: id)
        }
    }

    private func renderParticles() {
        var activeIds = Set<String>()
        let now = Date().timeIntervalSince1970

        for particle in gameState.particles {
            activeIds.insert(particle.id)

            // Get or create node
            let node: SKNode
            if let existingNode = particleNodes[particle.id] {
                node = existingNode
            } else {
                node = entityRenderer.createParticleNode(particle: particle)
                particleNodes[particle.id] = node
                addChild(node)
            }

            // Update position
            node.position = CGPoint(
                x: particle.x,
                y: gameState.arena.height - particle.y
            )
            node.zPosition = 200

            // Fade out based on lifetime
            let progress = CGFloat((now - particle.createdAt) / particle.lifetime)
            node.alpha = 1.0 - progress

            // Apply rotation if specified
            if let rotation = particle.rotation {
                node.zRotation = rotation
            }
        }

        // Remove nodes for expired particles
        for (id, node) in particleNodes where !activeIds.contains(id) {
            node.removeFromParent()
            particleNodes.removeValue(forKey: id)
        }
    }

    // MARK: - HUD Update (Cached - Phase 1.3)

    private func updateHUD() {
        // Only update health bar if changed
        let healthPercent = gameState.player.health / gameState.player.maxHealth
        if abs(healthPercent - lastHealthPercent) > 0.001 {
            lastHealthPercent = healthPercent

            // Update fill scale (efficient - just changes transform)
            healthBarFill.xScale = max(0.001, healthPercent) // Avoid zero scale

            // Update fill color
            healthBarFill.fillColor = healthPercent > 0.3 ? SKColor.green : SKColor.red

            // Update text
            healthText.text = "\(Int(gameState.player.health))/\(Int(gameState.player.maxHealth))"
        }

        // Only update timer if second changed
        let timeSeconds = Int(gameState.timeElapsed)
        if timeSeconds != lastTimeSeconds {
            lastTimeSeconds = timeSeconds
            let minutes = timeSeconds / 60
            let seconds = timeSeconds % 60
            timerText.text = String(format: "%d:%02d", minutes, seconds)
        }

        // Only update kill counter if changed
        let killCount = gameState.stats.enemiesKilled
        if killCount != lastKillCount {
            lastKillCount = killCount
            killText.text = "Kills: \(killCount)"
        }
    }

    // MARK: - Cleanup

    func cleanup() {
        // Clear all node tracking dictionaries
        enemyNodes.removeAll()
        projectileNodes.removeAll()
        pickupNodes.removeAll()
        particleNodes.removeAll()

        // Remove all children
        removeAllChildren()
    }

    // MARK: - Helpers

    private func colorFromHex(_ hex: String) -> SKColor {
        guard let (r, g, b) = ColorUtils.hexToRGB(hex) else {
            return SKColor.gray
        }
        return SKColor(red: r, green: g, blue: b, alpha: 1.0)
    }
}

// MARK: - SKColor Extension

extension SKColor {
    func darker(by percentage: CGFloat) -> SKColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return SKColor(hue: h, saturation: s, brightness: max(b - percentage, 0), alpha: a)
    }

    func lighter(by percentage: CGFloat) -> SKColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return SKColor(hue: h, saturation: s, brightness: min(b + percentage, 1), alpha: a)
    }
}
