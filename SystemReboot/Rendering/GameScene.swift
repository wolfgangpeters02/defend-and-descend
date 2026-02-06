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

    // Pillar health bar tracking (boss mode)
    private var pillarHealthBars: [String: SKNode] = [:]

    // Entity node tracking (keyed by ID for efficient updates)
    private var enemyNodes: [String: SKNode] = [:]
    private var projectileNodes: [String: SKNode] = [:]
    private var pickupNodes: [String: SKNode] = [:]
    private var particleNodes: [String: SKNode] = [:]

    // Layer hierarchy
    private let backgroundLayer = SKNode()  // zPosition: -100
    private let hazardLayer = SKNode()      // zPosition: 0
    private let pickupLayer = SKNode()      // zPosition: 25
    private let enemyLayer = SKNode()       // zPosition: 50
    private let projectileLayer = SKNode()  // zPosition: 75
    private let playerLayer = SKNode()      // zPosition: 100
    private let particleLayer = SKNode()    // zPosition: 200

    // Node pool (Phase 5: reduce node allocations)
    private var nodePool: NodePool!

    // Survival mode event system
    private var survivalSystem = SurvivalArenaSystem()

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

    // Survival event visual elements
    private var eventBorderNode: SKShapeNode?
    private var eventAnnouncementLabel: SKLabelNode?
    private var eventTimerLabel: SKLabelNode?
    private var healingZoneNode: SKShapeNode?
    private var arenaOverlayNode: SKShapeNode?  // For buffer overflow shrink effect

    // Survival economy UI
    private var hashEarnedLabel: SKLabelNode?
    private var extractionLabel: SKLabelNode?
    private var lastHashEarned: Int = 0
    private var lastEventTimeRemaining: Int = -1  // Cache event timer to avoid per-frame string allocation

    // Callbacks
    var onGameOver: ((GameState) -> Void)?
    var onStateUpdate: ((GameState) -> Void)?
    var onExtraction: (() -> Void)?  // Called when extraction button pressed
    private var didCallGameOver = false  // Prevent calling onGameOver multiple times

    // Screen size for dynamic scaling
    private var screenSize: CGSize = .zero

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
        let container = SKNode()

        // Vertical lines
        var x: CGFloat = -size.width / 2
        while x <= size.width / 2 {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: x, y: -size.height / 2))
            path.addLine(to: CGPoint(x: x, y: size.height / 2))

            let line = SKShapeNode(path: path)
            line.strokeColor = color
            line.lineWidth = 1
            container.addChild(line)
            x += spacing
        }

        // Horizontal lines
        var y: CGFloat = -size.height / 2
        while y <= size.height / 2 {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: -size.width / 2, y: y))
            path.addLine(to: CGPoint(x: size.width / 2, y: y))

            let line = SKShapeNode(path: path)
            line.strokeColor = color
            line.lineWidth = 1
            container.addChild(line)
            y += spacing
        }

        return container
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

    // MARK: - HUD Setup (Cached - Phase 1.3)

    private func setupHUD() {
        hudLayer = SKNode()
        hudLayer.zPosition = 1000

        // For boss mode with larger arena, attach HUD to camera so it stays on screen
        // For other modes, add to scene directly
        if gameState.gameMode == .boss, let cam = cameraNode {
            cam.addChild(hudLayer)
        } else {
            addChild(hudLayer)
        }

        // Health bar constants
        let healthBarWidth: CGFloat = 200
        let healthBarHeight: CGFloat = 20

        // Calculate HUD positions based on whether attached to camera or scene
        let hudWidth = gameState.gameMode == .boss ? screenSize.width : gameState.arena.width
        let hudHeight = gameState.gameMode == .boss ? screenSize.height : gameState.arena.height
        // When attached to camera, positions are relative to camera center (0,0)
        let hudYOffset: CGFloat = gameState.gameMode == .boss ? hudHeight / 2 - 30 : hudHeight - 30
        let hudXOffsetLeft: CGFloat = gameState.gameMode == .boss ? -hudWidth / 2 + 120 : 120
        let hudXCenter: CGFloat = gameState.gameMode == .boss ? 0 : hudWidth / 2
        let hudXOffsetRight: CGFloat = gameState.gameMode == .boss ? hudWidth / 2 - 20 : hudWidth - 20

        // Create health bar background (cached)
        healthBarBg = SKShapeNode(rectOf: CGSize(width: healthBarWidth, height: healthBarHeight), cornerRadius: 4)
        healthBarBg.fillColor = SKColor.darkGray
        healthBarBg.strokeColor = SKColor.white.withAlphaComponent(0.3)
        healthBarBg.position = CGPoint(x: hudXOffsetLeft, y: hudYOffset)
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
        timerText.position = CGPoint(x: hudXCenter, y: hudYOffset)
        hudLayer.addChild(timerText)

        // Create kill counter (cached)
        killText = SKLabelNode(text: L10n.Game.HUD.kills(0))
        killText.fontName = "Helvetica"
        killText.fontSize = 16
        killText.fontColor = .white
        killText.horizontalAlignmentMode = .right
        killText.position = CGPoint(x: hudXOffsetRight, y: hudYOffset)
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

    // MARK: - Survival Event Visuals Setup

    private func setupSurvivalEventVisuals() {
        // Event border (pulsing colored border around arena during events)
        let borderPath = CGMutablePath()
        let inset: CGFloat = 10
        borderPath.addRect(CGRect(
            x: inset,
            y: inset,
            width: gameState.arena.width - inset * 2,
            height: gameState.arena.height - inset * 2
        ))

        eventBorderNode = SKShapeNode(path: borderPath)
        eventBorderNode?.strokeColor = .clear
        eventBorderNode?.fillColor = .clear
        eventBorderNode?.lineWidth = 6
        eventBorderNode?.zPosition = 500
        eventBorderNode?.alpha = 0
        addChild(eventBorderNode!)

        // Event announcement label (top center, below HUD)
        eventAnnouncementLabel = SKLabelNode(text: "")
        eventAnnouncementLabel?.fontName = "Menlo-Bold"
        eventAnnouncementLabel?.fontSize = 28
        eventAnnouncementLabel?.fontColor = .white
        eventAnnouncementLabel?.position = CGPoint(x: gameState.arena.width / 2, y: gameState.arena.height - 70)
        eventAnnouncementLabel?.zPosition = 1001
        eventAnnouncementLabel?.alpha = 0
        addChild(eventAnnouncementLabel!)

        // Event timer label (below announcement)
        eventTimerLabel = SKLabelNode(text: "")
        eventTimerLabel?.fontName = "Menlo"
        eventTimerLabel?.fontSize = 16
        eventTimerLabel?.fontColor = SKColor(red: 0.7, green: 0.7, blue: 0.7, alpha: 1)
        eventTimerLabel?.position = CGPoint(x: gameState.arena.width / 2, y: gameState.arena.height - 95)
        eventTimerLabel?.zPosition = 1001
        eventTimerLabel?.alpha = 0
        addChild(eventTimerLabel!)

        // Healing zone (for system restore event)
        healingZoneNode = SKShapeNode(circleOfRadius: 60)
        healingZoneNode?.fillColor = SKColor(red: 0.13, green: 0.77, blue: 0.37, alpha: 0.3) // #22c55e
        healingZoneNode?.strokeColor = SKColor(red: 0.13, green: 0.77, blue: 0.37, alpha: 0.8)
        healingZoneNode?.lineWidth = 3
        healingZoneNode?.zPosition = 15
        healingZoneNode?.alpha = 0
        addChild(healingZoneNode!)

        // Arena overlay for buffer overflow shrink effect
        arenaOverlayNode = SKShapeNode()
        arenaOverlayNode?.zPosition = 20
        arenaOverlayNode?.alpha = 0
        addChild(arenaOverlayNode!)

        // Hash earned display (bottom left)
        hashEarnedLabel = SKLabelNode(text: "Ħ 0")
        hashEarnedLabel?.fontName = "Menlo-Bold"
        hashEarnedLabel?.fontSize = 18
        hashEarnedLabel?.fontColor = SKColor(red: 0.02, green: 0.71, blue: 0.83, alpha: 1) // #06b6d4 cyan
        hashEarnedLabel?.horizontalAlignmentMode = .left
        hashEarnedLabel?.position = CGPoint(x: 20, y: 50)
        hashEarnedLabel?.zPosition = 1001
        addChild(hashEarnedLabel!)

        // Extraction available label (bottom center) - hidden until 3 min
        extractionLabel = SKLabelNode(text: L10n.Game.HUD.extractionReady)
        extractionLabel?.fontName = "Menlo-Bold"
        extractionLabel?.fontSize = 16
        extractionLabel?.fontColor = SKColor(red: 0.13, green: 0.77, blue: 0.37, alpha: 1) // #22c55e
        extractionLabel?.position = CGPoint(x: gameState.arena.width / 2, y: 50)
        extractionLabel?.zPosition = 1001
        extractionLabel?.alpha = 0
        addChild(extractionLabel!)
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
        lastUpdateTime = currentTime

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
        if gameState.gameMode == .survival || gameState.gameMode == .arena {
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

        // Update weapons - auto-fire
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
        if gameState.gameMode == .survival || gameState.gameMode == .arena {
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

    // MARK: - Boss Systems

    /// Initialize a boss encounter (called when entering boss mode)
    func initializeBoss(bossId: String) {
        // Determine boss type and create state
        let arenaCenter = CGPoint(
            x: gameState.arena.width / 2,
            y: gameState.arena.height / 2
        )

        let arenaRect = CGRect(x: 0, y: 0, width: gameState.arena.width, height: gameState.arena.height)

        if bossId.contains("cyberboss") || bossId.contains("server") {
            gameState.activeBossType = .cyberboss
            gameState.cyberbossState = CyberbossAI.createInitialState()
        } else if bossId.contains("void") || bossId.contains("harbinger") {
            gameState.activeBossType = .voidHarbinger
            gameState.voidHarbingerState = VoidHarbingerAI.createInitialState(arenaCenter: arenaCenter)
        } else if bossId.contains("overclocker") || bossId.contains("thermal") {
            gameState.activeBossType = .overclocker
            gameState.overclockerState = OverclockerAI.createInitialState(arenaCenter: arenaCenter, arenaRect: arenaRect)
        } else if bossId.contains("trojan") || bossId.contains("wyrm") || bossId.contains("packet") {
            gameState.activeBossType = .trojanWyrm
            gameState.trojanWyrmState = TrojanWyrmAI.createInitialState(arenaCenter: arenaCenter, arenaRect: arenaRect)
        }

        gameState.activeBossId = bossId

        // Spawn the boss enemy
        let config = GameConfigLoader.shared

        // Get boss config from JSON or use fallback
        let bossConfig = config.getEnemy(bossId) ?? EnemyConfig(
            id: bossId,
            name: "Boss",
            health: 5000,
            speed: 80,
            damage: 50,
            coinValue: 100,
            size: 60,
            color: "#ff0000",
            shape: "hexagon",
            isBoss: true
        )

        // Apply difficulty scaling
        var scaledConfig = bossConfig
        if let difficulty = gameState.bossDifficulty {
            scaledConfig.health *= Double(difficulty.healthMultiplier)
            scaledConfig.damage *= Double(difficulty.damageMultiplier)
        }

        let spawnOptions = SpawnOptions(
            x: gameState.arena.width / 2,
            y: gameState.arena.height / 4,  // Boss spawns in top quarter
            inactive: false,
            activationRadius: nil
        )

        let bossEnemy = EnemySystem.spawnEnemy(
            state: &gameState,
            type: bossId,
            config: scaledConfig,
            spawnOptions: spawnOptions
        )

        gameState.enemies.append(bossEnemy)
    }

    private func updateBossAI(context: FrameContext) {
        guard let bossType = gameState.activeBossType else { return }

        // Find the boss enemy
        guard let bossIndex = gameState.enemies.firstIndex(where: { $0.isBoss && !$0.isDead }) else {
            // Boss is dead - trigger victory!
            if !gameState.isGameOver {
                gameState.isGameOver = true
                gameState.victory = true
            }

            // Clear boss state
            gameState.activeBossType = nil
            gameState.activeBossId = nil
            gameState.cyberbossState = nil
            gameState.voidHarbingerState = nil
            gameState.overclockerState = nil
            gameState.trojanWyrmState = nil
            return
        }

        switch bossType {
        case .cyberboss:
            if var bossState = gameState.cyberbossState {
                // Extract boss to avoid overlapping inout access
                var boss = gameState.enemies[bossIndex]
                CyberbossAI.update(
                    boss: &boss,
                    bossState: &bossState,
                    gameState: &gameState,
                    deltaTime: context.deltaTime
                )
                gameState.enemies[bossIndex] = boss
                gameState.cyberbossState = bossState
            }

        case .voidHarbinger:
            if var bossState = gameState.voidHarbingerState {
                // Extract boss to avoid overlapping inout access
                var boss = gameState.enemies[bossIndex]
                VoidHarbingerAI.update(
                    boss: &boss,
                    bossState: &bossState,
                    gameState: &gameState,
                    deltaTime: context.deltaTime
                )
                gameState.enemies[bossIndex] = boss
                gameState.voidHarbingerState = bossState
            }

        case .overclocker:
            if var bossState = gameState.overclockerState {
                var boss = gameState.enemies[bossIndex]
                OverclockerAI.update(
                    boss: &boss,
                    bossState: &bossState,
                    gameState: &gameState,
                    deltaTime: context.deltaTime
                )

                // Apply wind/vacuum forces to player
                let bossPos = CGPoint(x: boss.x, y: boss.y)
                let playerPos = CGPoint(x: gameState.player.x, y: gameState.player.y)
                let wind = OverclockerAI.calculateWindForce(playerPos: playerPos, bossPos: bossPos, state: bossState)
                let vacuum = OverclockerAI.calculateVacuumForce(playerPos: playerPos, bossPos: bossPos, state: bossState)

                gameState.player.x += (wind.dx + vacuum.dx) * CGFloat(context.deltaTime)
                gameState.player.y += (wind.dy + vacuum.dy) * CGFloat(context.deltaTime)

                // Clamp player to arena
                let padding: CGFloat = 30
                gameState.player.x = max(padding, min(gameState.arena.width - padding, gameState.player.x))
                gameState.player.y = max(padding, min(gameState.arena.height - padding, gameState.player.y))

                // Check mechanics damage
                let arenaRect = CGRect(x: 0, y: 0, width: gameState.arena.width, height: gameState.arena.height)
                let mechanicsDamage = OverclockerAI.checkMechanicsDamage(
                    playerPos: CGPoint(x: gameState.player.x, y: gameState.player.y),
                    state: bossState,
                    bossPos: bossPos,
                    arenaRect: arenaRect,
                    deltaTime: context.deltaTime
                )
                if mechanicsDamage > 0 {
                    gameState.player.health -= mechanicsDamage
                }

                gameState.enemies[bossIndex] = boss
                gameState.overclockerState = bossState
            }

        case .trojanWyrm:
            if var bossState = gameState.trojanWyrmState {
                var boss = gameState.enemies[bossIndex]
                TrojanWyrmAI.update(
                    boss: &boss,
                    bossState: &bossState,
                    gameState: &gameState,
                    deltaTime: context.deltaTime
                )

                // Custom body segment collision (runs AFTER ProjectileSystem)
                TrojanWyrmAI.checkBodySegmentCollisions(
                    bossState: &bossState,
                    gameState: &gameState,
                    boss: &boss
                )

                gameState.enemies[bossIndex] = boss
                gameState.trojanWyrmState = bossState
            }
        }
    }

    private func updateBossMechanics(context: FrameContext) {
        // NOTE: All damage is handled by the boss AI (CyberbossAI/VoidHarbingerAI)
        // This function now only handles rendering of boss mechanics
        renderBossMechanics()
    }

    // MARK: - Boss Mechanics Rendering

    private var bossMechanicNodes: [String: SKNode] = [:]

    /// Efficiently find boss mechanic keys to remove (avoids per-key string allocation)
    /// Uses dropFirst instead of replacingOccurrences for better performance
    private func findKeysToRemove(prefix: String, activeIds: Set<String>) -> [String] {
        let prefixCount = prefix.count
        var keysToRemove: [String] = []
        keysToRemove.reserveCapacity(bossMechanicNodes.count / 4)  // Preallocate estimate

        for key in bossMechanicNodes.keys {
            guard key.hasPrefix(prefix) else { continue }
            let id = String(key.dropFirst(prefixCount))
            if !activeIds.contains(id) {
                keysToRemove.append(key)
            }
        }
        return keysToRemove
    }

    // Cached SKActions for boss mechanics (avoid recreating every frame)
    private lazy var laserFlickerAction: SKAction = {
        SKAction.sequence([
            SKAction.fadeAlpha(to: 0.8, duration: 0.08),
            SKAction.fadeAlpha(to: 1.0, duration: 0.08)
        ])
    }()

    private lazy var puddlePulseAction: SKAction = {
        SKAction.sequence([
            SKAction.scale(to: 1.15, duration: 0.3),
            SKAction.scale(to: 1.0, duration: 0.3)
        ])
    }()

    private lazy var voidZonePulseAction: SKAction = {
        SKAction.sequence([
            SKAction.scale(to: 1.1, duration: 0.4),
            SKAction.scale(to: 1.0, duration: 0.4)
        ])
    }()

    private lazy var pylonCrystalPulseAction: SKAction = {
        SKAction.sequence([
            SKAction.scale(to: 1.2, duration: 0.5),
            SKAction.scale(to: 1.0, duration: 0.5)
        ])
    }()

    private lazy var gravityWellRotateAction: SKAction = {
        SKAction.rotate(byAngle: .pi * 2, duration: 3)
    }()

    private lazy var arenaBoundaryPulseAction: SKAction = {
        SKAction.sequence([
            SKAction.fadeAlpha(to: 0.5, duration: 0.5),
            SKAction.fadeAlpha(to: 1.0, duration: 0.5)
        ])
    }()

    private lazy var chainsawRotateAction: SKAction = {
        SKAction.rotate(byAngle: .pi * 2, duration: 0.8)
    }()

    private lazy var chainsawDangerPulseAction: SKAction = {
        SKAction.sequence([
            SKAction.scale(to: 1.1, duration: 0.2),
            SKAction.scale(to: 1.0, duration: 0.2)
        ])
    }()

    // Frame counter for visual update throttling
    private var bossMechanicFrameCounter: Int = 0

    // State caching for puddles/zones to avoid redundant color updates
    private var puddlePhaseCache: [String: String] = [:]  // id -> "warning", "active", "pop"
    private var zonePhaseCache: [String: Bool] = [:]       // id -> isActive

    private func renderBossMechanics() {
        // Render Cyberboss mechanics
        if let bossState = gameState.cyberbossState {
            renderCyberbossMechanics(bossState: bossState)
        } else {
            // Clean up cyberboss nodes if not in cyberboss fight
            cleanupBossNodes(prefix: "cyberboss_")
        }

        // Render Void Harbinger mechanics
        if let bossState = gameState.voidHarbingerState {
            renderVoidHarbingerMechanics(bossState: bossState)
        } else {
            // Clean up void harbinger nodes if not in void harbinger fight
            cleanupBossNodes(prefix: "voidharbinger_")
        }

        // Render Overclocker mechanics
        if let bossState = gameState.overclockerState {
            renderOverclockerMechanics(bossState: bossState)
        } else {
            cleanupBossNodes(prefix: "overclocker_")
        }

        // Render Trojan Wyrm mechanics
        if let bossState = gameState.trojanWyrmState {
            renderTrojanWyrmMechanics(bossState: bossState)
        } else {
            cleanupBossNodes(prefix: "trojanwyrm_")
        }
    }

    private func cleanupBossNodes(prefix: String) {
        let keysToRemove = bossMechanicNodes.keys.filter { $0.hasPrefix(prefix) }
        for key in keysToRemove {
            if let node = bossMechanicNodes[key] {
                // Determine pool type from key prefix
                let poolType: String
                if key.contains("puddle") { poolType = "boss_puddle" }
                else if key.contains("laser") { poolType = "boss_laser" }
                else if key.contains("zone") { poolType = "boss_zone" }
                else if key.contains("pylon") { poolType = "boss_pylon" }
                else if key.contains("rift") { poolType = "boss_rift" }
                else if key.contains("well") { poolType = "boss_well" }
                else { poolType = "boss_misc" }
                nodePool.release(node, type: poolType)
            }
            bossMechanicNodes.removeValue(forKey: key)
        }
    }

    // MARK: - Cyberboss Rendering

    private func renderCyberbossMechanics(bossState: CyberbossAI.CyberbossState) {
        guard let boss = gameState.enemies.first(where: { $0.isBoss && !$0.isDead }) else { return }

        // Render chainsaw effect for melee mode (Phase 1-2)
        renderChainsawEffect(bossState: bossState, boss: boss)

        // Render damage puddles (with state caching to avoid redundant color updates)
        var activePuddleIds = Set<String>()
        for puddle in bossState.damagePuddles {
            activePuddleIds.insert(puddle.id)
            let nodeKey = "cyberboss_puddle_\(puddle.id)"

            let isWarningPhase = puddle.lifetime < puddle.warningDuration
            let isAboutToPop = puddle.lifetime > puddle.maxLifetime - 0.5

            // Determine current phase for caching
            let currentPhase: String
            if isWarningPhase { currentPhase = "warning" }
            else if isAboutToPop { currentPhase = "pop" }
            else { currentPhase = "active" }

            if let node = bossMechanicNodes[nodeKey] as? SKShapeNode {
                // Only update colors if phase changed (avoids redundant fillColor/strokeColor sets)
                let cachedPhase = puddlePhaseCache[puddle.id]
                if cachedPhase != currentPhase {
                    puddlePhaseCache[puddle.id] = currentPhase

                    if isWarningPhase {
                        // Warning phase - amber outline, subtle pulse
                        node.fillColor = DesignColors.warningUI.withAlphaComponent(0.1)
                        node.strokeColor = DesignColors.warningUI
                        node.lineWidth = 3
                        node.glowWidth = 0  // Removed for performance
                    } else if isAboutToPop {
                        // About to pop - danger red, high intensity
                        node.fillColor = DesignColors.dangerUI.withAlphaComponent(0.5)
                        node.strokeColor = DesignColors.dangerUI
                        node.lineWidth = 5  // Thicker line instead of glow
                        node.glowWidth = 0  // Removed for performance
                    } else {
                        // Active phase - danger fill at lower intensity
                        node.fillColor = DesignColors.dangerUI.withAlphaComponent(0.25)
                        node.strokeColor = DesignColors.dangerUI.withAlphaComponent(0.8)
                        node.lineWidth = 3
                        node.glowWidth = 0  // Removed for performance
                    }
                }
            } else {
                // Create new puddle node (starts in warning phase)
                let puddleNode = SKShapeNode(circleOfRadius: puddle.radius)
                puddleNode.fillColor = DesignColors.warningUI.withAlphaComponent(0.1)
                puddleNode.strokeColor = DesignColors.warningUI
                puddleNode.lineWidth = 3
                puddleNode.glowWidth = 0  // Removed for performance
                // Convert to scene coordinates (flip Y)
                puddleNode.position = CGPoint(x: puddle.x, y: gameState.arena.height - puddle.y)
                puddleNode.zPosition = 5
                puddleNode.name = nodeKey

                // Add pulsing effect (use cached action)
                puddleNode.run(SKAction.repeatForever(puddlePulseAction), withKey: "pulse")

                addChild(puddleNode)
                bossMechanicNodes[nodeKey] = puddleNode
            }
        }

        // Remove puddles that no longer exist (release to pool for reuse)
        let puddlePrefix = "cyberboss_puddle_"
        for key in findKeysToRemove(prefix: puddlePrefix, activeIds: activePuddleIds) {
            if let node = bossMechanicNodes[key] {
                nodePool.release(node, type: "boss_puddle")
            }
            // Clear phase cache for removed puddle
            let puddleId = String(key.dropFirst(puddlePrefix.count))
            puddlePhaseCache.removeValue(forKey: puddleId)
            bossMechanicNodes.removeValue(forKey: key)
        }

        // Render laser beams (optimized: use rotation instead of path rebuild)
        var activeLaserIds = Set<String>()
        for beam in bossState.laserBeams {
            activeLaserIds.insert(beam.id)
            let nodeKey = "cyberboss_laser_\(beam.id)"

            // Convert to scene coordinates (flip Y)
            let bossSceneX = boss.x
            let bossSceneY = gameState.arena.height - boss.y

            // Determine color based on warning vs active state
            let laserColor: SKColor = beam.isActive ? DesignColors.dangerUI : SKColor.yellow
            let laserWidth: CGFloat = beam.isActive ? 8 : 4  // Thicker line instead of glow

            if let node = bossMechanicNodes[nodeKey] as? SKShapeNode {
                // Update existing laser: position, rotation, and color
                node.position = CGPoint(x: bossSceneX, y: bossSceneY)
                node.zRotation = beam.angle * .pi / 180
                node.strokeColor = laserColor
                node.lineWidth = laserWidth
            } else {
                // Create new laser beam node with horizontal path (rotated via zRotation)
                let path = CGMutablePath()
                path.move(to: CGPoint.zero)
                path.addLine(to: CGPoint(x: beam.length, y: 0))

                let laserNode = SKShapeNode(path: path)
                laserNode.strokeColor = laserColor
                laserNode.lineWidth = laserWidth
                laserNode.glowWidth = 0  // Removed for performance
                laserNode.zPosition = 100
                laserNode.name = nodeKey
                laserNode.position = CGPoint(x: bossSceneX, y: bossSceneY)
                laserNode.zRotation = beam.angle * .pi / 180

                // Add subtle flicker effect (use cached action)
                laserNode.run(SKAction.repeatForever(laserFlickerAction), withKey: "flicker")

                addChild(laserNode)
                bossMechanicNodes[nodeKey] = laserNode
            }
        }

        // Remove lasers that no longer exist (release to pool for reuse)
        for key in findKeysToRemove(prefix: "cyberboss_laser_", activeIds: activeLaserIds) {
            if let node = bossMechanicNodes[key] {
                nodePool.release(node, type: "boss_laser")
            }
            bossMechanicNodes.removeValue(forKey: key)
        }

        // Show phase indicator
        renderPhaseIndicator(phase: bossState.phase, bossType: "cyberboss")
    }

    // MARK: - Chainsaw Effect

    private func renderChainsawEffect(bossState: CyberbossAI.CyberbossState, boss: Enemy) {
        let nodeKey = "cyberboss_chainsaw"

        // Only show chainsaw in melee mode (Phase 1-2)
        let showChainsaw = bossState.mode == .melee && bossState.phase <= 2

        if showChainsaw {
            let bossSceneY = gameState.arena.height - boss.y
            let bossSize = boss.size ?? 60

            if let existingNode = bossMechanicNodes[nodeKey] {
                // Update position
                existingNode.position = CGPoint(x: boss.x, y: bossSceneY)
            } else {
                // Create chainsaw visual - rotating saw teeth around boss
                let chainsawNode = SKNode()
                chainsawNode.name = nodeKey
                chainsawNode.position = CGPoint(x: boss.x, y: bossSceneY)
                chainsawNode.zPosition = 49 // Just below enemies

                // Create inner danger circle (subtle, design system colors)
                let dangerCircle = SKShapeNode(circleOfRadius: bossSize + 10)
                dangerCircle.fillColor = DesignColors.dangerUI.withAlphaComponent(0.15)
                dangerCircle.strokeColor = DesignColors.dangerUI.withAlphaComponent(0.6)
                dangerCircle.lineWidth = 2
                dangerCircle.glowWidth = 4
                dangerCircle.name = "dangerCircle"
                chainsawNode.addChild(dangerCircle)

                // Create saw teeth around the boss (smaller, less garish)
                let teethCount = 8
                let teethRadius = bossSize + 20
                for i in 0..<teethCount {
                    let angle = CGFloat(i) * (2 * .pi / CGFloat(teethCount))
                    let toothX = cos(angle) * teethRadius
                    let toothY = sin(angle) * teethRadius

                    // Create triangular saw tooth
                    let toothPath = CGMutablePath()
                    let toothSize: CGFloat = 12
                    toothPath.move(to: CGPoint(x: 0, y: toothSize / 2))
                    toothPath.addLine(to: CGPoint(x: toothSize, y: 0))
                    toothPath.addLine(to: CGPoint(x: 0, y: -toothSize / 2))
                    toothPath.closeSubpath()

                    let toothNode = SKShapeNode(path: toothPath)
                    toothNode.fillColor = DesignColors.dangerUI.withAlphaComponent(0.8)
                    toothNode.strokeColor = DesignColors.dangerUI
                    toothNode.lineWidth = 1
                    toothNode.glowWidth = 2
                    toothNode.position = CGPoint(x: toothX, y: toothY)
                    toothNode.zRotation = angle // Point outward
                    chainsawNode.addChild(toothNode)
                }

                // Add outer warning ring (using warning color)
                let outerRing = SKShapeNode(circleOfRadius: bossSize + 28)
                outerRing.fillColor = .clear
                outerRing.strokeColor = DesignColors.warningUI.withAlphaComponent(0.4)
                outerRing.lineWidth = 1.5
                outerRing.name = "outerRing"
                chainsawNode.addChild(outerRing)

                // Rotation animation - fast spinning saw (use cached action)
                chainsawNode.run(SKAction.repeatForever(chainsawRotateAction), withKey: "rotate")

                // Pulsing danger circle (use cached action)
                dangerCircle.run(SKAction.repeatForever(chainsawDangerPulseAction), withKey: "pulse")

                addChild(chainsawNode)
                bossMechanicNodes[nodeKey] = chainsawNode
            }
        } else {
            // Remove chainsaw when not in melee mode
            if let node = bossMechanicNodes[nodeKey] {
                // Fade out then remove
                node.run(SKAction.sequence([
                    SKAction.fadeOut(withDuration: 0.3),
                    SKAction.removeFromParent()
                ]))
                bossMechanicNodes.removeValue(forKey: nodeKey)
            }
        }
    }

    // MARK: - Void Harbinger Rendering

    private func renderVoidHarbingerMechanics(bossState: VoidHarbingerAI.VoidHarbingerState) {
        // Render void zones (with state caching to avoid redundant color updates)
        var activeZoneIds = Set<String>()
        for zone in bossState.voidZones {
            activeZoneIds.insert(zone.id)
            let nodeKey = "voidharbinger_zone_\(zone.id)"

            if let node = bossMechanicNodes[nodeKey] as? SKShapeNode {
                // Only update colors if active state changed
                let cachedIsActive = zonePhaseCache[zone.id]
                if cachedIsActive != zone.isActive {
                    zonePhaseCache[zone.id] = zone.isActive

                    if zone.isActive {
                        node.fillColor = DesignColors.secondaryUI.withAlphaComponent(0.3)
                        node.strokeColor = DesignColors.secondaryUI.withAlphaComponent(0.8)
                        node.removeAction(forKey: "pulse")  // Stop warning pulse when active
                    } else {
                        // Warning phase - pulsing outline
                        node.fillColor = DesignColors.warningUI.withAlphaComponent(0.1)
                        node.strokeColor = DesignColors.warningUI
                    }
                }
            } else {
                // Create new void zone node
                let zoneNode = SKShapeNode(circleOfRadius: zone.radius)
                // Convert to scene coordinates (flip Y)
                zoneNode.position = CGPoint(x: zone.x, y: gameState.arena.height - zone.y)
                zoneNode.zPosition = 5
                zoneNode.lineWidth = 2
                zoneNode.name = nodeKey

                if zone.isActive {
                    zoneNode.fillColor = DesignColors.secondaryUI.withAlphaComponent(0.3)
                    zoneNode.strokeColor = DesignColors.secondaryUI.withAlphaComponent(0.8)
                    zoneNode.glowWidth = 4
                } else {
                    // Warning phase
                    zoneNode.fillColor = DesignColors.warningUI.withAlphaComponent(0.1)
                    zoneNode.strokeColor = DesignColors.warningUI
                    // Use cached action for pulse
                    zoneNode.run(SKAction.repeatForever(voidZonePulseAction), withKey: "pulse")
                }

                addChild(zoneNode)
                bossMechanicNodes[nodeKey] = zoneNode
            }
        }

        // Remove zones that no longer exist (release to pool for reuse)
        let zonePrefix = "voidharbinger_zone_"
        for key in findKeysToRemove(prefix: zonePrefix, activeIds: activeZoneIds) {
            if let node = bossMechanicNodes[key] {
                nodePool.release(node, type: "boss_zone")
            }
            // Clear phase cache for removed zone
            let zoneId = String(key.dropFirst(zonePrefix.count))
            zonePhaseCache.removeValue(forKey: zoneId)
            bossMechanicNodes.removeValue(forKey: key)
        }

        // Render pylons (Phase 2)
        var activePylonIds = Set<String>()
        for pylon in bossState.pylons where !pylon.isDestroyed {
            activePylonIds.insert(pylon.id)
            let nodeKey = "voidharbinger_pylon_\(pylon.id)"

            if let container = bossMechanicNodes[nodeKey] {
                // Update health bar
                if let healthBar = container.childNode(withName: "healthFill") as? SKShapeNode {
                    let healthPercent = pylon.health / pylon.maxHealth
                    healthBar.xScale = max(0.01, healthPercent)
                }
            } else {
                // Create new pylon node
                let container = SKNode()
                // Convert to scene coordinates (flip Y)
                container.position = CGPoint(x: pylon.x, y: gameState.arena.height - pylon.y)
                container.zPosition = 50
                container.name = nodeKey

                // Pylon body (using design system colors)
                let pylonBody = SKShapeNode(rectOf: CGSize(width: 40, height: 60), cornerRadius: 5)
                pylonBody.fillColor = DesignColors.secondaryUI.withAlphaComponent(0.8)
                pylonBody.strokeColor = DesignColors.secondaryUI
                pylonBody.lineWidth = 2
                pylonBody.glowWidth = 3
                container.addChild(pylonBody)

                // Crystal on top
                let crystal = SKShapeNode(circleOfRadius: 12)
                crystal.fillColor = DesignColors.secondaryUI
                crystal.strokeColor = DesignColors.primaryUI.withAlphaComponent(0.6)
                crystal.position = CGPoint(x: 0, y: 40)
                crystal.glowWidth = 6
                container.addChild(crystal)

                // Health bar background
                let healthBg = SKShapeNode(rectOf: CGSize(width: 50, height: 6))
                healthBg.fillColor = DesignColors.surfaceUI
                healthBg.strokeColor = DesignColors.mutedUI
                healthBg.position = CGPoint(x: 0, y: -45)
                container.addChild(healthBg)

                // Health bar fill
                let healthFill = SKShapeNode(rect: CGRect(x: -25, y: -3, width: 50, height: 6))
                healthFill.fillColor = DesignColors.successUI
                healthFill.strokeColor = SKColor.clear
                healthFill.position = CGPoint(x: 0, y: -45)
                healthFill.name = "healthFill"
                container.addChild(healthFill)

                // Pulsing effect on crystal (use cached action)
                crystal.run(SKAction.repeatForever(pylonCrystalPulseAction), withKey: "pulse")

                addChild(container)
                bossMechanicNodes[nodeKey] = container
            }
        }

        // Remove destroyed pylons (release to pool for reuse)
        for key in findKeysToRemove(prefix: "voidharbinger_pylon_", activeIds: activePylonIds) {
            if let node = bossMechanicNodes[key] {
                nodePool.release(node, type: "boss_pylon")
            }
            bossMechanicNodes.removeValue(forKey: key)
        }

        // Render shield around boss during Phase 2 (pylons provide shield)
        let shieldKey = "voidharbinger_shield"
        // Find boss position from enemies array
        let bossEnemy = gameState.enemies.first { $0.isBoss && !$0.isDead }
        if bossState.phase == 2 && bossState.isInvulnerable, let boss = bossEnemy {
            let bossScenePos = CGPoint(x: boss.x, y: gameState.arena.height - boss.y)

            if let shieldNode = bossMechanicNodes[shieldKey] as? SKShapeNode {
                shieldNode.position = bossScenePos
            } else {
                // Create hexagonal shield effect
                let shieldRadius: CGFloat = 80
                let hexPath = CGMutablePath()
                for i in 0..<6 {
                    let angle = CGFloat(i) * .pi / 3 - .pi / 6
                    let point = CGPoint(
                        x: cos(angle) * shieldRadius,
                        y: sin(angle) * shieldRadius
                    )
                    if i == 0 {
                        hexPath.move(to: point)
                    } else {
                        hexPath.addLine(to: point)
                    }
                }
                hexPath.closeSubpath()

                let shieldNode = SKShapeNode(path: hexPath)
                shieldNode.fillColor = DesignColors.secondaryUI.withAlphaComponent(0.15)
                shieldNode.strokeColor = DesignColors.secondaryUI.withAlphaComponent(0.8)
                shieldNode.lineWidth = 3
                shieldNode.glowWidth = 8
                shieldNode.position = bossScenePos
                shieldNode.zPosition = 45
                shieldNode.name = shieldKey

                // Pulsing shield animation
                let shieldPulse = SKAction.sequence([
                    SKAction.group([
                        SKAction.scale(to: 1.08, duration: 0.8),
                        SKAction.fadeAlpha(to: 0.7, duration: 0.8)
                    ]),
                    SKAction.group([
                        SKAction.scale(to: 1.0, duration: 0.8),
                        SKAction.fadeAlpha(to: 1.0, duration: 0.8)
                    ])
                ])
                shieldNode.run(SKAction.repeatForever(shieldPulse), withKey: "pulse")

                // Slow rotation
                let rotation = SKAction.rotate(byAngle: .pi * 2, duration: 12)
                shieldNode.run(SKAction.repeatForever(rotation), withKey: "rotate")

                addChild(shieldNode)
                bossMechanicNodes[shieldKey] = shieldNode
            }
        } else {
            // Remove shield when not in Phase 2 or not invulnerable
            if let shield = bossMechanicNodes[shieldKey] {
                shield.removeFromParent()
                bossMechanicNodes.removeValue(forKey: shieldKey)
            }
        }

        // Render energy lines from pylons to boss (Phase 2)
        var activeLineIds = Set<String>()
        if bossState.phase == 2, let boss = bossEnemy {
            let bossScenePos = CGPoint(x: boss.x, y: gameState.arena.height - boss.y)

            for pylon in bossState.pylons where !pylon.isDestroyed {
                activeLineIds.insert(pylon.id)
                let lineKey = "voidharbinger_pylonline_\(pylon.id)"
                let pylonScenePos = CGPoint(x: pylon.x, y: gameState.arena.height - pylon.y)

                if let lineNode = bossMechanicNodes[lineKey] as? SKShapeNode {
                    // Update line path to follow boss position
                    let linePath = CGMutablePath()
                    linePath.move(to: pylonScenePos)
                    linePath.addLine(to: bossScenePos)
                    lineNode.path = linePath
                } else {
                    // Create energy line from pylon to boss
                    let linePath = CGMutablePath()
                    linePath.move(to: pylonScenePos)
                    linePath.addLine(to: bossScenePos)

                    let lineNode = SKShapeNode(path: linePath)
                    lineNode.strokeColor = DesignColors.secondaryUI.withAlphaComponent(0.6)
                    lineNode.lineWidth = 2
                    lineNode.glowWidth = 4
                    lineNode.zPosition = 40
                    lineNode.name = lineKey

                    // Pulsing line animation (energy flow effect)
                    let linePulse = SKAction.sequence([
                        SKAction.fadeAlpha(to: 0.4, duration: 0.3),
                        SKAction.fadeAlpha(to: 1.0, duration: 0.3)
                    ])
                    lineNode.run(SKAction.repeatForever(linePulse), withKey: "pulse")

                    addChild(lineNode)
                    bossMechanicNodes[lineKey] = lineNode
                }
            }
        }

        // Remove lines for destroyed pylons or when not in Phase 2
        for key in findKeysToRemove(prefix: "voidharbinger_pylonline_", activeIds: activeLineIds) {
            if let node = bossMechanicNodes[key] {
                node.removeFromParent()
            }
            bossMechanicNodes.removeValue(forKey: key)
        }

        // Render pylon direction indicators (Phase 2 only) - help player find pylons
        if bossState.phase == 2 && !bossState.pylons.filter({ !$0.isDestroyed }).isEmpty {
            // Show hint text
            let hintKey = "voidharbinger_pylon_hint"
            if bossMechanicNodes[hintKey] == nil {
                let hintLabel = SKLabelNode(text: "DESTROY THE PYLONS!")
                hintLabel.fontName = "Menlo-Bold"
                hintLabel.fontSize = 20
                hintLabel.fontColor = DesignColors.warningUI
                hintLabel.position = CGPoint(x: gameState.arena.width / 2, y: gameState.arena.height - 90)
                hintLabel.zPosition = 200
                hintLabel.name = hintKey

                // Pulsing animation
                let pulse = SKAction.sequence([
                    SKAction.fadeAlpha(to: 0.5, duration: 0.5),
                    SKAction.fadeAlpha(to: 1.0, duration: 0.5)
                ])
                hintLabel.run(SKAction.repeatForever(pulse), withKey: "pulse")

                addChild(hintLabel)
                bossMechanicNodes[hintKey] = hintLabel
            }

            // Show arrow indicators pointing to each pylon
            let playerScenePos = CGPoint(x: gameState.player.x, y: gameState.arena.height - gameState.player.y)

            for pylon in bossState.pylons where !pylon.isDestroyed {
                let arrowKey = "voidharbinger_pylon_arrow_\(pylon.id)"
                let pylonScenePos = CGPoint(x: pylon.x, y: gameState.arena.height - pylon.y)

                // Calculate direction from player to pylon
                let dx = pylonScenePos.x - playerScenePos.x
                let dy = pylonScenePos.y - playerScenePos.y
                let distance = sqrt(dx * dx + dy * dy)

                // Only show arrow if pylon is far from player (off-screen or distant)
                if distance > 200 {
                    let angle = atan2(dy, dx)

                    // Position arrow at edge of view near player, pointing toward pylon
                    let arrowDistance: CGFloat = 120
                    let arrowX = playerScenePos.x + cos(angle) * arrowDistance
                    let arrowY = playerScenePos.y + sin(angle) * arrowDistance

                    // Clamp to screen bounds
                    let clampedX = max(50, min(gameState.arena.width - 50, arrowX))
                    let clampedY = max(50, min(gameState.arena.height - 50, arrowY))

                    if let arrow = bossMechanicNodes[arrowKey] as? SKShapeNode {
                        arrow.position = CGPoint(x: clampedX, y: clampedY)
                        arrow.zRotation = angle
                    } else {
                        // Create arrow pointing right (will be rotated)
                        let arrowPath = CGMutablePath()
                        arrowPath.move(to: CGPoint(x: -15, y: -8))
                        arrowPath.addLine(to: CGPoint(x: 15, y: 0))
                        arrowPath.addLine(to: CGPoint(x: -15, y: 8))
                        arrowPath.addLine(to: CGPoint(x: -10, y: 0))
                        arrowPath.closeSubpath()

                        let arrowNode = SKShapeNode(path: arrowPath)
                        arrowNode.fillColor = DesignColors.warningUI
                        arrowNode.strokeColor = DesignColors.warningUI.withAlphaComponent(0.8)
                        arrowNode.lineWidth = 2
                        arrowNode.glowWidth = 4
                        arrowNode.position = CGPoint(x: clampedX, y: clampedY)
                        arrowNode.zRotation = angle
                        arrowNode.zPosition = 150
                        arrowNode.name = arrowKey

                        // Pulsing animation
                        let arrowPulse = SKAction.sequence([
                            SKAction.scale(to: 1.2, duration: 0.3),
                            SKAction.scale(to: 1.0, duration: 0.3)
                        ])
                        arrowNode.run(SKAction.repeatForever(arrowPulse), withKey: "pulse")

                        addChild(arrowNode)
                        bossMechanicNodes[arrowKey] = arrowNode
                    }
                } else {
                    // Remove arrow if pylon is close
                    if let arrow = bossMechanicNodes[arrowKey] {
                        arrow.removeFromParent()
                        bossMechanicNodes.removeValue(forKey: arrowKey)
                    }
                }
            }
        } else {
            // Remove pylon indicators when not in Phase 2
            let hintKey = "voidharbinger_pylon_hint"
            if let hint = bossMechanicNodes[hintKey] {
                hint.removeFromParent()
                bossMechanicNodes.removeValue(forKey: hintKey)
            }

            // Remove all pylon arrows
            let arrowPrefix = "voidharbinger_pylon_arrow_"
            for key in bossMechanicNodes.keys where key.hasPrefix(arrowPrefix) {
                if let arrow = bossMechanicNodes[key] {
                    arrow.removeFromParent()
                }
                bossMechanicNodes.removeValue(forKey: key)
            }
        }

        // Render void rifts (Phase 3+) - optimized: use rotation instead of path rebuild
        var activeRiftIds = Set<String>()
        for rift in bossState.voidRifts {
            activeRiftIds.insert(rift.id)
            let nodeKey = "voidharbinger_rift_\(rift.id)"

            // Convert to scene coordinates (flip Y)
            let centerSceneX = bossState.arenaCenter.x
            let centerSceneY = gameState.arena.height - bossState.arenaCenter.y

            if let node = bossMechanicNodes[nodeKey] as? SKShapeNode {
                // Update rift: just change rotation (no path rebuild)
                node.position = CGPoint(x: centerSceneX, y: centerSceneY)
                node.zRotation = rift.angle * .pi / 180
            } else {
                // Create new rift node with horizontal path (rotated via zRotation)
                let riftLength = BalanceConfig.VoidHarbinger.voidRiftLength
                let path = CGMutablePath()
                path.move(to: CGPoint.zero)
                path.addLine(to: CGPoint(x: riftLength, y: 0))

                let riftNode = SKShapeNode(path: path)
                riftNode.strokeColor = DesignColors.secondaryUI
                riftNode.lineWidth = rift.width
                riftNode.glowWidth = 6  // Reduced from 15 for performance
                riftNode.alpha = 0.8
                riftNode.zPosition = 10
                riftNode.name = nodeKey
                riftNode.position = CGPoint(x: centerSceneX, y: centerSceneY)
                riftNode.zRotation = rift.angle * .pi / 180

                addChild(riftNode)
                bossMechanicNodes[nodeKey] = riftNode
            }
        }

        // Remove rifts that no longer exist (release to pool for reuse)
        for key in findKeysToRemove(prefix: "voidharbinger_rift_", activeIds: activeRiftIds) {
            if let node = bossMechanicNodes[key] {
                nodePool.release(node, type: "boss_rift")
            }
            bossMechanicNodes.removeValue(forKey: key)
        }

        // Render gravity wells (Phase 3+)
        var activeWellIds = Set<String>()
        for well in bossState.gravityWells {
            activeWellIds.insert(well.id)
            let nodeKey = "voidharbinger_well_\(well.id)"

            if bossMechanicNodes[nodeKey] == nil {
                // Create gravity well visual
                let wellNode = SKShapeNode(circleOfRadius: well.pullRadius)
                wellNode.fillColor = SKColor.black.withAlphaComponent(0.25)
                wellNode.strokeColor = DesignColors.secondaryUI.withAlphaComponent(0.7)
                wellNode.lineWidth = 2
                // Convert to scene coordinates (flip Y)
                wellNode.position = CGPoint(x: well.x, y: gameState.arena.height - well.y)
                wellNode.zPosition = 4
                wellNode.name = nodeKey

                // Inner spiral effect
                let innerCircle = SKShapeNode(circleOfRadius: 30)
                innerCircle.fillColor = SKColor.black.withAlphaComponent(0.7)
                innerCircle.strokeColor = DesignColors.secondaryUI
                innerCircle.glowWidth = 8
                wellNode.addChild(innerCircle)

                // Rotation animation (use cached action)
                wellNode.run(SKAction.repeatForever(gravityWellRotateAction), withKey: "rotate")

                addChild(wellNode)
                bossMechanicNodes[nodeKey] = wellNode
            }
        }

        // Remove wells that no longer exist (release to pool for reuse)
        for key in findKeysToRemove(prefix: "voidharbinger_well_", activeIds: activeWellIds) {
            if let node = bossMechanicNodes[key] {
                nodePool.release(node, type: "boss_well")
            }
            bossMechanicNodes.removeValue(forKey: key)
        }

        // Render shrinking arena boundary (Phase 4) - optimized: use scale instead of path rebuild
        if bossState.phase == 4 {
            let arenaKey = "voidharbinger_arena"
            // Convert to scene coordinates (flip Y)
            let centerSceneY = gameState.arena.height - bossState.arenaCenter.y

            // Calculate scale based on current radius vs initial radius
            let initialRadius = BalanceConfig.VoidHarbinger.arenaStartRadius
            let currentScale = bossState.arenaRadius / initialRadius

            if let node = bossMechanicNodes[arenaKey] as? SKShapeNode {
                // Update arena size using scale (no path rebuild)
                node.xScale = currentScale
                node.yScale = currentScale
            } else {
                // Create arena boundary at full size (will be scaled down)
                let arenaNode = SKShapeNode(circleOfRadius: initialRadius)
                arenaNode.fillColor = SKColor.clear
                arenaNode.strokeColor = DesignColors.dangerUI
                arenaNode.lineWidth = 4
                arenaNode.glowWidth = 4  // Reduced from 8 for performance
                arenaNode.zPosition = 3
                arenaNode.name = arenaKey
                arenaNode.position = CGPoint(x: bossState.arenaCenter.x, y: centerSceneY)
                arenaNode.xScale = currentScale
                arenaNode.yScale = currentScale

                // Pulsing warning effect (use cached action)
                arenaNode.run(SKAction.repeatForever(arenaBoundaryPulseAction), withKey: "pulse")

                addChild(arenaNode)
                bossMechanicNodes[arenaKey] = arenaNode
            }
        } else {
            // Remove arena boundary if not in phase 4
            if let node = bossMechanicNodes["voidharbinger_arena"] {
                node.removeFromParent()
                bossMechanicNodes.removeValue(forKey: "voidharbinger_arena")
            }
        }

        // Show phase indicator and invulnerability
        renderPhaseIndicator(phase: bossState.phase, bossType: "voidharbinger", isInvulnerable: bossState.isInvulnerable)
    }

    // MARK: - Phase Indicator

    private func renderPhaseIndicator(phase: Int, bossType: String, isInvulnerable: Bool = false) {
        let nodeKey = "\(bossType)_phase_indicator"

        if let label = bossMechanicNodes[nodeKey] as? SKLabelNode {
            label.text = isInvulnerable ? L10n.Boss.phaseInvulnerable(phase) : L10n.Boss.phase(phase)
            label.fontColor = isInvulnerable ? DesignColors.warningUI : DesignColors.primaryUI
        } else {
            let label = SKLabelNode(text: L10n.Boss.phase(phase))
            label.fontName = "Menlo-Bold"
            label.fontSize = 18
            label.fontColor = DesignColors.primaryUI
            label.position = CGPoint(x: gameState.arena.width / 2, y: gameState.arena.height - 60)
            label.zPosition = 200
            label.name = nodeKey

            addChild(label)
            bossMechanicNodes[nodeKey] = label
        }
    }

    private func pointToLineDistance(point: CGPoint, lineStart: CGPoint, lineEnd: CGPoint) -> CGFloat {
        let dx = lineEnd.x - lineStart.x
        let dy = lineEnd.y - lineStart.y
        let lengthSquared = dx * dx + dy * dy

        if lengthSquared == 0 {
            return sqrt(pow(point.x - lineStart.x, 2) + pow(point.y - lineStart.y, 2))
        }

        let t = max(0, min(1, ((point.x - lineStart.x) * dx + (point.y - lineStart.y) * dy) / lengthSquared))
        let projX = lineStart.x + t * dx
        let projY = lineStart.y + t * dy

        return sqrt(pow(point.x - projX, 2) + pow(point.y - projY, 2))
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

    private func renderDamageEvents() {
        // Process and display new damage events
        for i in 0..<gameState.damageEvents.count {
            guard !gameState.damageEvents[i].displayed else { continue }

            let event = gameState.damageEvents[i]

            // Convert game position to scene position (flip Y)
            let scenePosition = CGPoint(
                x: event.position.x,
                y: gameState.arena.height - event.position.y
            )

            // Map DamageEventType to SCTType and display
            switch event.type {
            case .damage:
                combatText.showDamage(event.amount, at: scenePosition, isCritical: false)
            case .critical:
                combatText.showDamage(event.amount, at: scenePosition, isCritical: true)
            case .healing:
                combatText.showHealing(event.amount, at: scenePosition)
            case .playerDamage:
                combatText.show("-\(event.amount)", type: .damage, at: scenePosition)
            case .freeze:
                combatText.showFreeze(at: scenePosition)
            case .burn:
                combatText.showBurn(event.amount, at: scenePosition)
            case .chain:
                combatText.showChain(event.amount, at: scenePosition)
            case .execute:
                combatText.showExecute(at: scenePosition)
            case .xp:
                combatText.showXP(event.amount, at: scenePosition)
            case .currency:
                combatText.showCurrency(event.amount, at: scenePosition)
            case .miss:
                combatText.showMiss(at: scenePosition)
            case .shield:
                combatText.show("BLOCKED", type: .shield, at: scenePosition)
            case .immune:
                combatText.show("IMMUNE", type: .immune, at: scenePosition)
            }

            gameState.damageEvents[i].displayed = true
        }

        // Clean up old damage events (older than 2 seconds)
        let currentTime = gameState.startTime + gameState.timeElapsed
        gameState.damageEvents.removeAll { currentTime - $0.timestamp > 2.0 }
    }

    private func renderPlayer() {
        let player = gameState.player

        if playerNode == nil {
            playerNode = entityRenderer.createPlayerNode(size: player.size)
            playerLayer.addChild(playerNode!) // Use player layer (Phase 5)
        }

        // Update position (flip Y coordinate)
        playerNode?.position = CGPoint(
            x: player.x,
            y: gameState.arena.height - player.y
        )

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

            // Get or create node using pool (Phase 5)
            let node = nodePool.acquireEnemyNode(
                id: enemy.id,
                existing: &enemyNodes,
                renderer: entityRenderer,
                enemy: enemy
            )

            // Add to layer if new
            if node.parent == nil {
                enemyLayer.addChild(node)
            }

            // Update position
            node.position = CGPoint(
                x: enemy.x,
                y: gameState.arena.height - enemy.y
            )

            // Slow effect visual
            node.alpha = enemy.isSlowed ? 0.7 : 1.0
        }

        // Release unused nodes back to pool (Phase 5)
        nodePool.releaseInactive(type: "enemy", nodes: &enemyNodes, activeIds: activeIds)
    }

    private func renderProjectiles() {
        var activeIds = Set<String>()

        for projectile in gameState.projectiles {
            activeIds.insert(projectile.id)

            // Get or create node using pool (Phase 5)
            let node = nodePool.acquireProjectileNode(
                id: projectile.id,
                existing: &projectileNodes,
                renderer: entityRenderer,
                projectile: projectile
            )

            // Add to layer if new
            if node.parent == nil {
                projectileLayer.addChild(node)
            }

            // Update position
            node.position = CGPoint(
                x: projectile.x,
                y: gameState.arena.height - projectile.y
            )
        }

        // Release unused nodes back to pool (Phase 5)
        nodePool.releaseInactive(type: "projectile", nodes: &projectileNodes, activeIds: activeIds)
    }

    private func renderPickups() {
        var activeIds = Set<String>()

        for pickup in gameState.pickups {
            activeIds.insert(pickup.id)

            // Get or create node using pool (Phase 5)
            let node = nodePool.acquirePickupNode(
                id: pickup.id,
                existing: &pickupNodes,
                renderer: entityRenderer,
                pickup: pickup
            )

            // Add to layer if new
            if node.parent == nil {
                pickupLayer.addChild(node)
            }

            // Update position
            node.position = CGPoint(
                x: pickup.x,
                y: gameState.arena.height - pickup.y
            )
        }

        // Release unused nodes back to pool (Phase 5)
        nodePool.releaseInactive(type: "pickup", nodes: &pickupNodes, activeIds: activeIds)
    }

    private func renderParticles() {
        var activeIds = Set<String>()
        // Use gameTime for particle fade calculations (avoids Date() call)
        let now = gameState.startTime + gameState.timeElapsed

        for particle in gameState.particles {
            activeIds.insert(particle.id)

            // Get or create node using pool (Phase 5)
            let node = nodePool.acquireParticleNode(
                id: particle.id,
                existing: &particleNodes,
                renderer: entityRenderer,
                particle: particle
            )

            // Add to layer if new
            if node.parent == nil {
                particleLayer.addChild(node)
            }

            // Update position
            node.position = CGPoint(
                x: particle.x,
                y: gameState.arena.height - particle.y
            )

            // Fade out based on lifetime
            let progress = CGFloat((now - particle.createdAt) / particle.lifetime)
            node.alpha = max(0, 1.0 - progress)

            // Apply rotation if specified
            if let rotation = particle.rotation {
                node.zRotation = rotation
            }
        }

        // Release unused nodes back to pool (Phase 5)
        nodePool.releaseInactive(type: "particle", nodes: &particleNodes, activeIds: activeIds)
    }

    // MARK: - Pillar Rendering (Boss Mode)

    private func renderPillars() {
        // Only render pillar health bars in boss mode
        guard gameState.gameMode == .boss else {
            // Clean up any existing health bars when not in boss mode
            for (_, node) in pillarHealthBars {
                node.removeFromParent()
            }
            pillarHealthBars.removeAll()
            return
        }

        for (index, obstacle) in gameState.arena.obstacles.enumerated() {
            guard index < obstacleNodes.count else { continue }

            let obstacleNode = obstacleNodes[index]
            let pillarId = obstacle.id

            // Check if pillar is destructible and alive
            guard PillarSystem.isPillarAlive(obstacle: obstacle),
                  let healthPercent = PillarSystem.getPillarHealthPercent(obstacle: obstacle) else {
                // Pillar destroyed or not destructible - hide/remove it
                if obstacle.isDestructible, let health = obstacle.health, health <= 0 {
                    obstacleNode.alpha = 0  // Hide destroyed pillar
                    // Remove health bar if exists
                    if let healthBar = pillarHealthBars[pillarId] {
                        healthBar.removeFromParent()
                        pillarHealthBars.removeValue(forKey: pillarId)
                    }
                }
                continue
            }

            // Update or create health bar
            if let healthBarContainer = pillarHealthBars[pillarId] {
                // Update existing health bar
                if let fillNode = healthBarContainer.childNode(withName: "fill") as? SKShapeNode {
                    fillNode.xScale = max(0.01, healthPercent)

                    // Color based on health
                    if healthPercent > 0.6 {
                        fillNode.fillColor = SKColor(red: 0.4, green: 0.4, blue: 0.45, alpha: 1)
                    } else if healthPercent > 0.3 {
                        fillNode.fillColor = SKColor(red: 0.7, green: 0.5, blue: 0.2, alpha: 1)
                    } else {
                        fillNode.fillColor = SKColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 1)
                    }
                }
            } else {
                // Create new health bar
                let healthBar = createPillarHealthBar(width: obstacle.width * 0.8)
                healthBar.position = CGPoint(
                    x: obstacleNode.position.x,
                    y: obstacleNode.position.y + obstacle.height / 2 + 15
                )
                healthBar.zPosition = 150
                addChild(healthBar)
                pillarHealthBars[pillarId] = healthBar
            }

            // Update pillar visual based on damage
            if let shapeNode = obstacleNode as? SKShapeNode {
                // Darken pillar as it takes damage
                let damageAlpha = 0.6 + (healthPercent * 0.4)
                shapeNode.alpha = damageAlpha

                // Add red tint when low health
                if healthPercent < 0.3 {
                    shapeNode.strokeColor = SKColor(red: 0.8, green: 0.3, blue: 0.3, alpha: 1)
                    shapeNode.lineWidth = 3
                }
            }
        }
    }

    private func createPillarHealthBar(width: CGFloat) -> SKNode {
        let container = SKNode()

        // Background
        let bgNode = SKShapeNode(rectOf: CGSize(width: width, height: 6), cornerRadius: 2)
        bgNode.fillColor = SKColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 0.8)
        bgNode.strokeColor = SKColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1)
        bgNode.lineWidth = 1
        container.addChild(bgNode)

        // Fill (starts full)
        let fillNode = SKShapeNode(rect: CGRect(x: -width / 2, y: -3, width: width, height: 6), cornerRadius: 2)
        fillNode.fillColor = SKColor(red: 0.4, green: 0.4, blue: 0.45, alpha: 1)
        fillNode.strokeColor = .clear
        fillNode.name = "fill"
        container.addChild(fillNode)

        return container
    }

    // MARK: - Overclocker Rendering

    private func renderOverclockerMechanics(bossState: OverclockerAI.OverclockerState) {
        guard let boss = gameState.enemies.first(where: { $0.isBoss && !$0.isDead }) else { return }
        let bossPos = CGPoint(x: boss.x, y: boss.y)
        let arenaH = gameState.arena.height

        // Phase 1: Render rotating blades
        if bossState.phase == 1 {
            let bladeCount = BalanceConfig.Overclocker.bladeCount
            let bladeRadius = BalanceConfig.Overclocker.bladeOrbitRadius

            for i in 0..<bladeCount {
                let nodeKey = "overclocker_blade_\(i)"
                let angleOffset = CGFloat(i) * (2 * .pi / CGFloat(bladeCount))
                let currentAngle = bossState.bladeAngle + angleOffset

                let bladeNode: SKShapeNode
                if let existing = bossMechanicNodes[nodeKey] as? SKShapeNode {
                    bladeNode = existing
                } else {
                    // Create blade as a line
                    let path = CGMutablePath()
                    path.move(to: .zero)
                    path.addLine(to: CGPoint(x: bladeRadius, y: 0))
                    bladeNode = SKShapeNode(path: path)
                    bladeNode.strokeColor = SKColor.orange
                    bladeNode.lineWidth = BalanceConfig.Overclocker.bladeWidth
                    bladeNode.lineCap = .round
                    bladeNode.zPosition = 100
                    addChild(bladeNode)
                    bossMechanicNodes[nodeKey] = bladeNode
                }

                bladeNode.position = CGPoint(x: bossPos.x, y: arenaH - bossPos.y)
                bladeNode.zRotation = -currentAngle // Negative for Y-flip
            }
        } else {
            // Clean up blades if not in Phase 1
            for i in 0..<3 {
                let nodeKey = "overclocker_blade_\(i)"
                if let node = bossMechanicNodes[nodeKey] {
                    node.removeFromParent()
                    bossMechanicNodes.removeValue(forKey: nodeKey)
                }
            }
        }

        // Phase 2: Render lava tiles
        if bossState.phase == 2 {
            let arenaRect = bossState.arenaRect
            let tileW = arenaRect.width / 4
            let tileH = arenaRect.height / 4

            for i in 0..<16 {
                let nodeKey = "overclocker_tile_\(i)"
                let col = i % 4
                let row = i / 4

                let tileNode: SKShapeNode
                if let existing = bossMechanicNodes[nodeKey] as? SKShapeNode {
                    tileNode = existing
                } else {
                    tileNode = SKShapeNode(rectOf: CGSize(width: tileW - 4, height: tileH - 4), cornerRadius: 4)
                    tileNode.zPosition = 1
                    tileNode.lineWidth = 2
                    addChild(tileNode)
                    bossMechanicNodes[nodeKey] = tileNode
                }

                let tileX = arenaRect.minX + CGFloat(col) * tileW + tileW / 2
                let tileY = arenaRect.minY + CGFloat(row) * tileH + tileH / 2
                tileNode.position = CGPoint(x: tileX, y: arenaH - tileY)

                // Color based on state
                switch bossState.tileStates[i] {
                case .normal:
                    tileNode.fillColor = SKColor.darkGray.withAlphaComponent(0.3)
                    tileNode.strokeColor = SKColor.gray
                case .warning:
                    tileNode.fillColor = SKColor.orange.withAlphaComponent(0.5)
                    tileNode.strokeColor = SKColor.yellow
                case .lava:
                    tileNode.fillColor = SKColor.red.withAlphaComponent(0.7)
                    tileNode.strokeColor = SKColor.orange
                case .safe:
                    tileNode.fillColor = SKColor.cyan.withAlphaComponent(0.4)
                    tileNode.strokeColor = SKColor.blue
                }
            }
        } else {
            // Clean up tiles if not in Phase 2
            for i in 0..<16 {
                let nodeKey = "overclocker_tile_\(i)"
                if let node = bossMechanicNodes[nodeKey] {
                    node.removeFromParent()
                    bossMechanicNodes.removeValue(forKey: nodeKey)
                }
            }
        }

        // Phase 3 & 4: Render steam trail
        if bossState.phase >= 3 {
            var activeSteamIds = Set<String>()
            for segment in bossState.steamTrail {
                activeSteamIds.insert(segment.id)
                let nodeKey = "overclocker_steam_\(segment.id)"

                let steamNode: SKShapeNode
                if let existing = bossMechanicNodes[nodeKey] as? SKShapeNode {
                    steamNode = existing
                } else {
                    steamNode = SKShapeNode(circleOfRadius: BalanceConfig.Overclocker.steamRadius)
                    steamNode.fillColor = SKColor.white.withAlphaComponent(0.3)
                    steamNode.strokeColor = SKColor.gray.withAlphaComponent(0.5)
                    steamNode.zPosition = 50
                    addChild(steamNode)
                    bossMechanicNodes[nodeKey] = steamNode
                }

                steamNode.position = CGPoint(x: segment.x, y: arenaH - segment.y)
            }

            // Clean up old steam segments
            let keysToRemove = bossMechanicNodes.keys.filter { $0.hasPrefix("overclocker_steam_") && !activeSteamIds.contains(String($0.dropFirst("overclocker_steam_".count))) }
            for key in keysToRemove {
                bossMechanicNodes[key]?.removeFromParent()
                bossMechanicNodes.removeValue(forKey: key)
            }
        }

        // Phase 4: Render shredder ring
        if bossState.phase == 4 {
            let nodeKey = "overclocker_shredder"
            let shredderNode: SKShapeNode
            if let existing = bossMechanicNodes[nodeKey] as? SKShapeNode {
                shredderNode = existing
            } else {
                shredderNode = SKShapeNode(circleOfRadius: BalanceConfig.Overclocker.shredderRadius)
                shredderNode.fillColor = SKColor.red.withAlphaComponent(0.2)
                shredderNode.strokeColor = bossState.isSuctionActive ? SKColor.red : SKColor.orange
                shredderNode.lineWidth = 4
                shredderNode.zPosition = 99
                addChild(shredderNode)
                bossMechanicNodes[nodeKey] = shredderNode
            }

            shredderNode.position = CGPoint(x: bossPos.x, y: arenaH - bossPos.y)
            shredderNode.strokeColor = bossState.isSuctionActive ? SKColor.red : SKColor.orange
        } else {
            if let node = bossMechanicNodes["overclocker_shredder"] {
                node.removeFromParent()
                bossMechanicNodes.removeValue(forKey: "overclocker_shredder")
            }
        }
    }

    // MARK: - Trojan Wyrm Rendering

    private func renderTrojanWyrmMechanics(bossState: TrojanWyrmAI.TrojanWyrmState) {
        let arenaH = gameState.arena.height

        // Main head is rendered by standard enemy rendering, but we can add glow
        guard let boss = gameState.enemies.first(where: { $0.isBoss && !$0.isDead }) else { return }

        // Render body segments (Phase 1, 2, 4)
        if bossState.phase != 3 {
            for (i, segment) in bossState.segments.enumerated() {
                let nodeKey = "trojanwyrm_seg_\(i)"
                let segNode: SKShapeNode
                if let existing = bossMechanicNodes[nodeKey] as? SKShapeNode {
                    segNode = existing
                } else {
                    segNode = SKShapeNode(circleOfRadius: BalanceConfig.TrojanWyrm.bodyCollisionRadius)
                    segNode.lineWidth = 2
                    segNode.zPosition = 100
                    addChild(segNode)
                    bossMechanicNodes[nodeKey] = segNode
                }

                segNode.position = CGPoint(x: segment.x, y: arenaH - segment.y)

                // Phase 2: Ghost segment is cyan/transparent
                if bossState.phase == 2 && i == bossState.ghostSegmentIndex {
                    segNode.fillColor = SKColor.cyan.withAlphaComponent(0.2)
                    segNode.strokeColor = SKColor.cyan
                } else {
                    segNode.fillColor = SKColor(red: 0, green: 1, blue: 0.27, alpha: 0.7) // Hacker green
                    segNode.strokeColor = SKColor(red: 0, green: 0.8, blue: 0.2, alpha: 1.0)
                }
            }

            // Render head glow
            let headKey = "trojanwyrm_head"
            let headNode: SKShapeNode
            if let existing = bossMechanicNodes[headKey] as? SKShapeNode {
                headNode = existing
            } else {
                headNode = SKShapeNode(circleOfRadius: BalanceConfig.TrojanWyrm.headCollisionRadius + 5)
                headNode.fillColor = SKColor(red: 0, green: 1, blue: 0.27, alpha: 0.9)
                headNode.strokeColor = SKColor.white
                headNode.lineWidth = 3
                headNode.zPosition = 101
                addChild(headNode)
                bossMechanicNodes[headKey] = headNode
            }
            headNode.position = CGPoint(x: boss.x, y: arenaH - boss.y)
        } else {
            // Clean up main body in Phase 3
            for i in 0..<BalanceConfig.TrojanWyrm.segmentCount {
                let nodeKey = "trojanwyrm_seg_\(i)"
                if let node = bossMechanicNodes[nodeKey] {
                    node.removeFromParent()
                    bossMechanicNodes.removeValue(forKey: nodeKey)
                }
            }
            if let node = bossMechanicNodes["trojanwyrm_head"] {
                node.removeFromParent()
                bossMechanicNodes.removeValue(forKey: "trojanwyrm_head")
            }
        }

        // Phase 3: Render sub-worms
        if bossState.phase == 3 {
            for (wi, worm) in bossState.subWorms.enumerated() {
                // Sub-worm head
                let headKey = "trojanwyrm_sw_\(wi)_head"
                let swHeadNode: SKShapeNode
                if let existing = bossMechanicNodes[headKey] as? SKShapeNode {
                    swHeadNode = existing
                } else {
                    swHeadNode = SKShapeNode(circleOfRadius: BalanceConfig.TrojanWyrm.subWormHeadSize)
                    swHeadNode.fillColor = SKColor(red: 0, green: 1, blue: 0.27, alpha: 0.9)
                    swHeadNode.strokeColor = SKColor.white
                    swHeadNode.lineWidth = 2
                    swHeadNode.zPosition = 101
                    addChild(swHeadNode)
                    bossMechanicNodes[headKey] = swHeadNode
                }
                swHeadNode.position = CGPoint(x: worm.head.x, y: arenaH - worm.head.y)

                // Sub-worm body
                for (si, seg) in worm.body.enumerated() {
                    let segKey = "trojanwyrm_sw_\(wi)_seg_\(si)"
                    let swSegNode: SKShapeNode
                    if let existing = bossMechanicNodes[segKey] as? SKShapeNode {
                        swSegNode = existing
                    } else {
                        swSegNode = SKShapeNode(circleOfRadius: BalanceConfig.TrojanWyrm.subWormBodySize)
                        swSegNode.fillColor = SKColor(red: 0, green: 1, blue: 0.27, alpha: 0.6)
                        swSegNode.strokeColor = SKColor(red: 0, green: 0.8, blue: 0.2, alpha: 1.0)
                        swSegNode.lineWidth = 1
                        swSegNode.zPosition = 100
                        addChild(swSegNode)
                        bossMechanicNodes[segKey] = swSegNode
                    }
                    swSegNode.position = CGPoint(x: seg.x, y: arenaH - seg.y)
                }
            }
        } else {
            // Clean up sub-worms if not in Phase 3
            for wi in 0..<4 {
                if let node = bossMechanicNodes["trojanwyrm_sw_\(wi)_head"] {
                    node.removeFromParent()
                    bossMechanicNodes.removeValue(forKey: "trojanwyrm_sw_\(wi)_head")
                }
                for si in 0..<5 {
                    let segKey = "trojanwyrm_sw_\(wi)_seg_\(si)"
                    if let node = bossMechanicNodes[segKey] {
                        node.removeFromParent()
                        bossMechanicNodes.removeValue(forKey: segKey)
                    }
                }
            }
        }

        // Phase 4: Render aim line during aiming state
        if bossState.phase == 4 && bossState.phase4SubState == .aiming {
            let aimKey = "trojanwyrm_aimline"
            let playerPos = CGPoint(x: gameState.player.x, y: gameState.player.y)
            let headPos = CGPoint(x: boss.x, y: boss.y)

            let aimNode: SKShapeNode
            if let existing = bossMechanicNodes[aimKey] as? SKShapeNode {
                aimNode = existing
            } else {
                aimNode = SKShapeNode()
                aimNode.strokeColor = SKColor.red
                aimNode.lineWidth = 3
                aimNode.zPosition = 102
                addChild(aimNode)
                bossMechanicNodes[aimKey] = aimNode
            }

            let path = CGMutablePath()
            path.move(to: CGPoint(x: headPos.x, y: arenaH - headPos.y))
            path.addLine(to: CGPoint(x: playerPos.x, y: arenaH - playerPos.y))
            aimNode.path = path
        } else {
            if let node = bossMechanicNodes["trojanwyrm_aimline"] {
                node.removeFromParent()
                bossMechanicNodes.removeValue(forKey: "trojanwyrm_aimline")
            }
        }
    }

    // MARK: - Survival Event Rendering

    private func renderSurvivalEvents() {
        guard gameState.gameMode == .survival || gameState.gameMode == .arena else {
            // Hide all survival elements if not in survival mode
            eventBorderNode?.alpha = 0
            eventAnnouncementLabel?.alpha = 0
            eventTimerLabel?.alpha = 0
            healingZoneNode?.alpha = 0
            arenaOverlayNode?.alpha = 0
            return
        }

        // Update event border and announcement
        if let activeEvent = gameState.activeEvent {
            // Show event border with appropriate color
            if let borderColor = SurvivalArenaSystem.getEventBorderColor(state: gameState) {
                let color = colorFromHex(borderColor)
                eventBorderNode?.strokeColor = color
                eventBorderNode?.glowWidth = 5

                // Pulsing effect
                let pulse = 0.5 + 0.3 * sin(CGFloat(gameState.timeElapsed * 4))
                eventBorderNode?.alpha = pulse
            }

            // Show event announcement
            eventAnnouncementLabel?.text = eventName(for: activeEvent)
            eventAnnouncementLabel?.fontColor = eventBorderNode?.strokeColor ?? .white
            eventAnnouncementLabel?.alpha = 1

            // Show event timer (cached to avoid per-frame string allocation)
            if let endTime = gameState.eventEndTime {
                let remaining = max(0, endTime - gameState.timeElapsed)
                let remainingTenths = Int(remaining * 10)  // Cache at 0.1s precision
                if remainingTenths != lastEventTimeRemaining {
                    lastEventTimeRemaining = remainingTenths
                    eventTimerLabel?.text = String(format: "%.1fs remaining", remaining)
                }
                eventTimerLabel?.alpha = 1
            }

            // Event-specific rendering
            renderEventSpecificEffects(event: activeEvent)

        } else {
            // No active event - hide UI elements with fade
            if eventBorderNode?.alpha ?? 0 > 0 {
                eventBorderNode?.alpha = max(0, (eventBorderNode?.alpha ?? 0) - 0.05)
            }
            eventAnnouncementLabel?.alpha = 0
            eventTimerLabel?.alpha = 0
            healingZoneNode?.alpha = 0
            arenaOverlayNode?.alpha = 0
            lastEventTimeRemaining = -1  // Reset cache when no event

            // Reset corrupted obstacle visuals
            resetCorruptedObstacles()
        }

        // === ECONOMY UI ===
        // Update Hash earned display
        if gameState.stats.hashEarned != lastHashEarned {
            lastHashEarned = gameState.stats.hashEarned
            hashEarnedLabel?.text = "Ħ \(gameState.stats.hashEarned)"
        }

        // Show extraction button when available (after 3 min)
        if SurvivalArenaSystem.canExtract(state: gameState) {
            extractionLabel?.alpha = 1
            // Pulsing effect to draw attention
            let pulse = 0.7 + 0.3 * sin(CGFloat(gameState.timeElapsed * 2))
            extractionLabel?.alpha = pulse
        } else {
            extractionLabel?.alpha = 0
        }
    }

    private func renderEventSpecificEffects(event: SurvivalEventType) {
        switch event {
        case .systemRestore:
            // Render healing zone
            if let zonePos = gameState.eventData?.healingZonePosition {
                healingZoneNode?.position = CGPoint(
                    x: zonePos.x,
                    y: gameState.arena.height - zonePos.y
                )
                healingZoneNode?.alpha = 1

                // Pulsing glow
                let pulse = 0.7 + 0.3 * sin(CGFloat(gameState.timeElapsed * 3))
                healingZoneNode?.glowWidth = 8 * pulse

                // Check if player is in zone - intensify effect
                let dx = gameState.player.x - zonePos.x
                let dy = gameState.player.y - zonePos.y
                let distance = sqrt(dx * dx + dy * dy)
                if distance < 60 {
                    healingZoneNode?.fillColor = SKColor(red: 0.13, green: 0.77, blue: 0.37, alpha: 0.5)
                } else {
                    healingZoneNode?.fillColor = SKColor(red: 0.13, green: 0.77, blue: 0.37, alpha: 0.3)
                }
            }

        case .dataCorruption:
            // Highlight corrupted obstacles
            healingZoneNode?.alpha = 0
            updateCorruptedObstacles()

        case .bufferOverflow:
            // Show shrinking arena overlay
            healingZoneNode?.alpha = 0
            if let shrinkAmount = gameState.eventData?.shrinkAmount {
                renderArenaShirnkOverlay(shrinkAmount: shrinkAmount)
            }

        default:
            healingZoneNode?.alpha = 0
            arenaOverlayNode?.alpha = 0
        }
    }

    private func updateCorruptedObstacles() {
        guard let corruptedIds = gameState.eventData?.corruptedObstacles else { return }

        for (index, obstacle) in gameState.arena.obstacles.enumerated() {
            guard index < obstacleNodes.count else { continue }
            let node = obstacleNodes[index]

            let isCorrupted = obstacle.isCorrupted == true ||
                              corruptedIds.contains(obstacle.id ?? "obs_\(index)")

            if isCorrupted {
                // Corrupted visual: purple glow + pulsing
                if let shapeNode = node as? SKShapeNode {
                    shapeNode.strokeColor = SKColor(red: 0.66, green: 0.33, blue: 0.97, alpha: 1) // #a855f7
                    shapeNode.glowWidth = 5 + 3 * sin(CGFloat(gameState.timeElapsed * 5))
                    shapeNode.lineWidth = 3
                }
            } else {
                // Normal visual
                if let shapeNode = node as? SKShapeNode {
                    shapeNode.strokeColor = colorFromHex(obstacle.color).darker(by: 0.2)
                    shapeNode.glowWidth = 0
                    shapeNode.lineWidth = 2
                }
            }
        }
    }

    private func resetCorruptedObstacles() {
        for (index, obstacle) in gameState.arena.obstacles.enumerated() {
            guard index < obstacleNodes.count else { continue }
            if let shapeNode = obstacleNodes[index] as? SKShapeNode {
                shapeNode.strokeColor = colorFromHex(obstacle.color).darker(by: 0.2)
                shapeNode.glowWidth = 0
                shapeNode.lineWidth = 2
            }
        }
    }

    private func renderArenaShirnkOverlay(shrinkAmount: CGFloat) {
        // Create a frame showing the "danger zone" at arena edges
        let dangerPath = CGMutablePath()

        // Top danger strip
        dangerPath.addRect(CGRect(x: 0, y: gameState.arena.height - shrinkAmount, width: gameState.arena.width, height: shrinkAmount))
        // Bottom danger strip
        dangerPath.addRect(CGRect(x: 0, y: 0, width: gameState.arena.width, height: shrinkAmount))
        // Left danger strip
        dangerPath.addRect(CGRect(x: 0, y: shrinkAmount, width: shrinkAmount, height: gameState.arena.height - shrinkAmount * 2))
        // Right danger strip
        dangerPath.addRect(CGRect(x: gameState.arena.width - shrinkAmount, y: shrinkAmount, width: shrinkAmount, height: gameState.arena.height - shrinkAmount * 2))

        arenaOverlayNode?.path = dangerPath
        arenaOverlayNode?.fillColor = SKColor(red: 1, green: 0.27, blue: 0.27, alpha: 0.3) // #ff4444
        arenaOverlayNode?.strokeColor = SKColor(red: 1, green: 0.27, blue: 0.27, alpha: 0.8)
        arenaOverlayNode?.lineWidth = 2
        arenaOverlayNode?.alpha = 0.5 + 0.3 * sin(CGFloat(gameState.timeElapsed * 2))
    }

    private func eventName(for event: SurvivalEventType) -> String {
        switch event {
        case .memorySurge: return "⚡ MEMORY SURGE"
        case .bufferOverflow: return "⚠️ BUFFER OVERFLOW"
        case .cacheFlush: return "🧹 CACHE FLUSH"
        case .thermalThrottle: return "🔥 THERMAL THROTTLE"
        case .dataCorruption: return "☠️ DATA CORRUPTION"
        case .virusSwarm: return "🦠 VIRUS SWARM"
        case .systemRestore: return "💚 SYSTEM RESTORE"
        }
    }

    // MARK: - HUD Update (Cached - Phase 1.3)

    private func updateHUD() {
        // HUD is now provided by SwiftUI overlay - skip if elements not created
        guard healthBarFill != nil else { return }

        // Only update health bar if changed
        let healthPercent = gameState.player.health / gameState.player.maxHealth
        if abs(healthPercent - lastHealthPercent) > 0.001 {
            lastHealthPercent = healthPercent

            // Update fill scale (efficient - just changes transform)
            healthBarFill.xScale = max(0.001, healthPercent) // Avoid zero scale

            // Update fill color
            healthBarFill.fillColor = healthPercent > 0.3 ? SKColor.green : SKColor.red

            // Update text
            healthText?.text = "\(Int(gameState.player.health))/\(Int(gameState.player.maxHealth))"
        }

        // Only update timer if second changed
        let timeSeconds = Int(gameState.timeElapsed)
        if timeSeconds != lastTimeSeconds {
            lastTimeSeconds = timeSeconds
            let minutes = timeSeconds / 60
            let seconds = timeSeconds % 60
            timerText?.text = String(format: "%d:%02d", minutes, seconds)
        }

        // Only update kill counter if changed
        let killCount = gameState.stats.enemiesKilled
        if killCount != lastKillCount {
            lastKillCount = killCount
            killText?.text = L10n.Game.HUD.kills(killCount)
        }
    }

    // MARK: - Cleanup

    func cleanup() {
        // Clear all node tracking dictionaries
        enemyNodes.removeAll()
        projectileNodes.removeAll()
        pickupNodes.removeAll()
        particleNodes.removeAll()
        pillarHealthBars.removeAll()
        bossMechanicNodes.removeAll()

        // Clear phase caches
        puddlePhaseCache.removeAll()
        zonePhaseCache.removeAll()

        // Clear node pool (Phase 5)
        nodePool?.clear()

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
