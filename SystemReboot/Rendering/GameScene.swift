import SpriteKit
import CoreGraphics

// MARK: - Game Scene

class GameScene: SKScene {
    // State
    var gameState: GameState!
    var inputState = InputState()
    var lastUpdateTime: TimeInterval = 0
    var isInitialized = false

    // Rendering
    var entityRenderer: EntityRenderer!
    var backgroundNode: SKShapeNode?
    var playerNode: SKNode?
    var obstacleNodes: [SKNode] = []
    var hazardNodes: [SKNode] = []

    // Pillar health bar tracking (boss mode)
    var pillarHealthBars: [String: SKNode] = [:]

    // Entity node tracking (keyed by ID for efficient updates)
    var enemyNodes: [String: SKNode] = [:]
    var projectileNodes: [String: SKNode] = [:]
    var pickupNodes: [String: SKNode] = [:]
    var particleNodes: [String: SKNode] = [:]

    // Layer hierarchy
    let backgroundLayer = SKNode()  // zPosition: -100
    let hazardLayer = SKNode()      // zPosition: 0
    let pickupLayer = SKNode()      // zPosition: 25
    let enemyLayer = SKNode()       // zPosition: 50
    let projectileLayer = SKNode()  // zPosition: 75
    let playerLayer = SKNode()      // zPosition: 100
    let particleLayer = SKNode()    // zPosition: 200

    // Node pool (Phase 5: reduce node allocations)
    var nodePool: NodePool!

    // Survival mode event system
    var survivalSystem = SurvivalArenaSystem()

    // Cached HUD Elements (Phase 1.3 - HUD Caching)
    var hudLayer: SKNode!
    var healthBarBg: SKShapeNode!
    var healthBarFill: SKShapeNode!
    var healthText: SKLabelNode!
    var timerText: SKLabelNode!
    var killText: SKLabelNode!
    var lastHealthPercent: CGFloat = 1.0
    var lastKillCount: Int = 0
    var lastTimeSeconds: Int = 0

    // Player invulnerability animation (Phase 1.4 - SKAction Animations)
    var invulnerabilityAction: SKAction?
    var isPlayingInvulnerability = false

    // Debug overlay
    var debugFrameTimes: [TimeInterval] = []
    var debugUpdateCounter: Int = 0
    var debugOverlayNode: SKNode?

    // Screen effects
    var screenFlashNode: SKShapeNode?
    var cameraNode: SKCameraNode?

    // Survival event visual elements
    var eventBorderNode: SKShapeNode?
    var eventAnnouncementLabel: SKLabelNode?
    var eventTimerLabel: SKLabelNode?
    var healingZoneNode: SKShapeNode?
    var arenaOverlayNode: SKShapeNode?  // For buffer overflow shrink effect

    // Survival economy UI
    var hashEarnedLabel: SKLabelNode?
    var extractionLabel: SKLabelNode?
    var lastHashEarned: Int = 0
    var lastEventTimeRemaining: Int = -1  // Cache event timer to avoid per-frame string allocation

    // Callbacks
    var onGameOver: ((GameState) -> Void)?
    var onStateUpdate: ((GameState) -> Void)?
    var onExtraction: (() -> Void)?  // Called when extraction button pressed
    var didCallGameOver = false  // Prevent calling onGameOver multiple times

    // Screen size for dynamic scaling
    var screenSize: CGSize = .zero

    // Boss mechanics rendering (Step 4.1: delegated to BossRenderingManager)
    var bossRenderingManager = BossRenderingManager()

    // MARK: - Setup

    func configure(gameState: GameState, screenSize: CGSize? = nil) {
        self.gameState = gameState
        self.entityRenderer = EntityRenderer()

        // Boss mode: Use the designed arena size (1200x900) for proper pillar/boss placement
        // Camera will follow player within the larger arena
        if gameState.gameMode == .boss {
            // Keep arena at designed size - don't resize to screen
            let width = gameState.arena.width > 0 ? gameState.arena.width : 1200
            let height = gameState.arena.height > 0 ? gameState.arena.height : 900
            self.screenSize = screenSize ?? CGSize(width: width, height: height)
            self.gameState.arena.width = width
            self.gameState.arena.height = height
            // Player position is set by createBossGameState, don't override
        }
        // Other modes: Resize arena to match screen for full-screen gameplay
        else if let screenSize = screenSize, screenSize.width > 0, screenSize.height > 0 {
            self.screenSize = screenSize
            // Update arena dimensions to match screen
            self.gameState.arena.width = screenSize.width
            self.gameState.arena.height = screenSize.height
            // Reposition player to center of new arena
            self.gameState.player.x = screenSize.width / 2
            self.gameState.player.y = screenSize.height / 2
        } else {
            // Fall back to arena dimensions or use reasonable defaults
            let width = gameState.arena.width > 0 ? gameState.arena.width : 390
            let height = gameState.arena.height > 0 ? gameState.arena.height : 844
            self.screenSize = CGSize(width: width, height: height)
            self.gameState.arena.width = width
            self.gameState.arena.height = height
            self.gameState.player.x = width / 2
            self.gameState.player.y = height / 2
        }

        setupScene()
        isInitialized = true
    }

    override func didMove(to view: SKView) {
        // CRITICAL: Set anchor point in didMove after scene is attached to view
        // Without this, default (0.5, 0.5) makes (0,0) the center
        self.anchorPoint = CGPoint(x: 0, y: 0)

        // Update scene size to match view if needed
        if size.width <= 0 || size.height <= 0 {
            size = view.bounds.size
        }
    }

    private func setupScene() {
        backgroundColor = colorFromHex(gameState.arena.backgroundColor)

        // Boss mode: Scene is arena-sized (larger than screen), camera follows player
        // Other modes: Scene matches screen size
        if gameState.gameMode == .boss {
            self.size = CGSize(width: gameState.arena.width, height: gameState.arena.height)
            self.scaleMode = .aspectFill  // Show arena through camera viewport
        } else {
            self.size = screenSize
            self.scaleMode = .resizeFill
        }

        // Also set anchorPoint here (will be reinforced in didMove)
        self.anchorPoint = CGPoint(x: 0, y: 0)

        // Initialize node pool (Phase 5)
        nodePool = NodePool(maxPerType: 100)

        // Configure boss rendering manager (Step 4.1)
        bossRenderingManager.configure(scene: self, nodePool: nodePool, enemyLayer: enemyLayer)

        // Setup camera for screen shake
        setupCamera()

        // Setup layer hierarchy (Phase 5)
        setupLayers()

        // Create layers
        setupBackground()
        setupObstacles()
        setupHazards()
        // Note: HUD is provided by SwiftUI overlay in GameContainerView
        // setupHUD() - disabled to avoid duplicate UI
        setupScreenFlash()
        setupInvulnerabilityAnimation()
        setupSurvivalEventVisuals()
    }

    private func setupLayers() {
        // Add layers in z-order
        backgroundLayer.zPosition = -100
        hazardLayer.zPosition = 0
        pickupLayer.zPosition = 25
        enemyLayer.zPosition = 50
        projectileLayer.zPosition = 75
        playerLayer.zPosition = 100
        particleLayer.zPosition = 200

        addChild(backgroundLayer)
        addChild(hazardLayer)
        addChild(pickupLayer)
        addChild(enemyLayer)
        addChild(projectileLayer)
        addChild(playerLayer)
        addChild(particleLayer)
    }

    private func setupCamera() {
        cameraNode = SKCameraNode()
        cameraNode?.position = CGPoint(x: gameState.arena.width / 2, y: gameState.arena.height / 2)
        addChild(cameraNode!)
        camera = cameraNode
    }

    private func setupBackground() {
        // Force dark terminal background regardless of arena config
        let darkBackground = SKColor(red: 10/255, green: 10/255, blue: 15/255, alpha: 1.0) // #0a0a0f

        backgroundNode = SKShapeNode(rectOf: CGSize(width: gameState.arena.width, height: gameState.arena.height))
        backgroundNode?.fillColor = darkBackground
        backgroundNode?.strokeColor = .clear
        backgroundNode?.position = CGPoint(x: gameState.arena.width / 2, y: gameState.arena.height / 2)
        backgroundNode?.zPosition = -100
        addChild(backgroundNode!)

        // Add green wireframe grid overlay (subtle terminal aesthetic)
        let gridNode = createWireframeGrid(
            size: CGSize(width: gameState.arena.width, height: gameState.arena.height),
            spacing: 50,
            color: SKColor(red: 0, green: 1, blue: 0.255, alpha: 0.08) // #00ff41 at 8% opacity
        )
        gridNode.position = CGPoint(x: gameState.arena.width / 2, y: gameState.arena.height / 2)
        gridNode.zPosition = -99
        addChild(gridNode)
    }

    private func createWireframeGrid(size: CGSize, spacing: CGFloat, color: SKColor) -> SKNode {
        // Performance: Single compound path instead of individual line nodes
        let combinedPath = CGMutablePath()

        // Vertical lines
        var x: CGFloat = -size.width / 2
        while x <= size.width / 2 {
            combinedPath.move(to: CGPoint(x: x, y: -size.height / 2))
            combinedPath.addLine(to: CGPoint(x: x, y: size.height / 2))
            x += spacing
        }

        // Horizontal lines
        var y: CGFloat = -size.height / 2
        while y <= size.height / 2 {
            combinedPath.move(to: CGPoint(x: -size.width / 2, y: y))
            combinedPath.addLine(to: CGPoint(x: size.width / 2, y: y))
            y += spacing
        }

        let gridNode = SKShapeNode(path: combinedPath)
        gridNode.strokeColor = color
        gridNode.lineWidth = 1
        return gridNode
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
            hazardLayer.addChild(node)
        }
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

    // MARK: - Survival Extraction

    /// Check if extraction is currently available
    var canExtract: Bool {
        return SurvivalArenaSystem.canExtract(state: gameState)
    }

    /// Get current Hash earned (for UI)
    var hashEarned: Int {
        return gameState.stats.hashEarned
    }

    /// Trigger extraction - ends game with 100% Hash reward
    func triggerExtraction() {
        guard canExtract else { return }
        SurvivalArenaSystem.extract(state: &gameState)
        onExtraction?()
    }

    // MARK: - Input

    func updateInput(_ input: InputState) {
        self.inputState = input
    }

    // MARK: - Game Loop

    override func update(_ currentTime: TimeInterval) {
        guard isInitialized else { return }

        // Create frame context with cached timestamp (Phase 1: Timestamp Caching)
        let context = FrameContext(currentTime: currentTime, lastUpdateTime: lastUpdateTime)
        // Raw delta for debug FPS (uncapped — FrameContext caps at 33.3ms which hides real drops)
        let rawDelta = lastUpdateTime > 0 ? currentTime - lastUpdateTime : 0
        lastUpdateTime = currentTime

        // Debug overlay (before game logic so FPS tracks even when game is over)
        if AppState.shared.showDebugOverlay {
            syncDebugOverlayVisibility()
            recordDebugFrameTime(rawDelta)
            if shouldUpdateDebugOverlay() {
                updateDebugOverlay()
            }
        } else if debugOverlayNode != nil {
            removeDebugOverlay()
        }

        // Update game state
        updateGameState(context: context)

        // Update rendering
        render()

        // Notify state update
        onStateUpdate?(gameState)

        // Check game over (only call callback once)
        if gameState.isGameOver && !didCallGameOver {
            didCallGameOver = true
            onGameOver?(gameState)
        }
    }

    private func updateGameState(context: FrameContext) {
        // Don't update game logic if game is over (prevents stats from increasing after death)
        guard !gameState.isGameOver else { return }

        // Update time
        gameState.timeElapsed += context.deltaTime
        gameState.gameTime = gameState.timeElapsed
        gameState.currentFrameTime = context.timestamp  // Store frame timestamp for consistent time checks

        // Initialize spatial grid for collision detection (Phase 3)
        if gameState.enemyGrid == nil {
            gameState.enemyGrid = SpatialGrid<Enemy>(cellSize: 100)
        }
        gameState.enemyGrid?.rebuild(from: gameState.enemies)

        // Initialize object pools (Phase 4: reduced GC pressure)
        if gameState.particlePool == nil {
            gameState.particlePool = ObjectPool<Particle>(maxSize: 500, prewarm: 100) {
                Particle.defaultParticle
            }
        }
        if gameState.projectilePool == nil {
            gameState.projectilePool = ObjectPool<Projectile>(maxSize: 200, prewarm: 50) {
                Projectile.defaultProjectile
            }
        }

        // Update player
        PlayerSystem.update(state: &gameState, input: inputState, context: context)

        // Process obstacle collisions (all modes with obstacles)
        if !gameState.arena.obstacles.isEmpty {
            ArenaSystem.processPlayerObstacleCollisions(state: &gameState)
        }

        // Constrain player to arena bounds
        ArenaSystem.constrainPlayerToArena(state: &gameState)

        // Spawn enemies in survival mode (boss mode has boss already spawned)
        if gameState.gameMode == .survival {
            SpawnSystem.update(state: &gameState, context: context)

            // Spawn boss every 2 minutes in survival mode
            if gameState.timeElapsed - gameState.lastBossSpawnTime >= BalanceConfig.BossSurvivor.spawnInterval {
                SpawnSystem.spawnBoss(state: &gameState, context: context)
            }
        }

        // Update enemies
        EnemySystem.update(state: &gameState, context: context)

        // Process enemy obstacle collisions
        if !gameState.arena.obstacles.isEmpty {
            ArenaSystem.processEnemyObstacleCollisions(state: &gameState)
        }

        // Update protocols - auto-fire
        WeaponSystem.update(state: &gameState, context: context)

        // Update projectiles
        ProjectileSystem.update(state: &gameState, context: context)

        // Projectiles collide with obstacles
        if !gameState.arena.obstacles.isEmpty {
            ArenaSystem.processProjectileObstacleCollisions(state: &gameState)
        }

        // Update pickups
        PickupSystem.update(state: &gameState, context: context)

        // Update particles
        updateParticles(context: context)

        // Survival mode: Update event system
        if gameState.gameMode == .survival {
            survivalSystem.update(state: &gameState, deltaTime: context.deltaTime)
        }

        // Boss mode specific updates
        if gameState.gameMode == .boss && gameState.activeBossId != nil {
            updateBossAI(context: context)
            updateBossMechanics(context: context)
            // Update destructible pillars
            PillarSystem.update(state: &gameState, deltaTime: context.deltaTime)

        }

        // Update camera to follow player (for large arenas)
        updateCameraFollow()
    }

    // MARK: - Camera Follow

    private func updateCameraFollow() {
        guard let camera = cameraNode else { return }

        // Calculate target camera position (centered on player)
        let targetX = gameState.player.x
        let targetY = gameState.arena.height - gameState.player.y  // Flip Y for scene coords

        // Clamp camera to arena bounds (keep viewport within arena)
        let halfWidth = screenSize.width / 2
        let halfHeight = screenSize.height / 2

        let clampedX = max(halfWidth, min(gameState.arena.width - halfWidth, targetX))
        let clampedY = max(halfHeight, min(gameState.arena.height - halfHeight, targetY))

        // Smooth camera follow
        let smoothing: CGFloat = 0.1
        let newX = camera.position.x + (clampedX - camera.position.x) * smoothing
        let newY = camera.position.y + (clampedY - camera.position.y) * smoothing

        camera.position = CGPoint(x: newX, y: newY)
    }

    private func updateParticles(context: FrameContext) {
        gameState.particles = gameState.particles.filter { context.timestamp - $0.createdAt < $0.lifetime }

        // Update particle positions
        for i in 0..<gameState.particles.count {
            if let velocity = gameState.particles[i].velocity {
                gameState.particles[i].x += velocity.x * CGFloat(context.deltaTime)
                gameState.particles[i].y += velocity.y * CGFloat(context.deltaTime)

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
        renderDamageEvents()
        renderSurvivalEvents()
        renderPillars()  // Boss mode: pillar health and destruction
        updateHUD() // Phase 1.3: Only update changed values
    }

    // MARK: - Cleanup

    func cleanup() {
        // Clear all node tracking dictionaries
        enemyNodes.removeAll()
        projectileNodes.removeAll()
        pickupNodes.removeAll()
        particleNodes.removeAll()
        pillarHealthBars.removeAll()

        // Clear debug overlay
        removeDebugOverlay()

        // Clear boss rendering (Step 4.1)
        bossRenderingManager.cleanup()

        // Clear node pool (Phase 5)
        nodePool?.clear()

        // Remove all children
        removeAllChildren()
    }

    // MARK: - Helpers

    func colorFromHex(_ hex: String) -> SKColor {
        guard let (r, g, b) = ColorUtils.hexToRGB(hex) else {
            return SKColor.gray
        }
        return SKColor(red: r, green: g, blue: b, alpha: 1.0)
    }
}
