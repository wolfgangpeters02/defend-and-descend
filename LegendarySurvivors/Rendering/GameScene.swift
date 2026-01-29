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

    // Callbacks
    var onGameOver: ((GameState) -> Void)?
    var onStateUpdate: ((GameState) -> Void)?
    var onExtraction: (() -> Void)?  // Called when extraction button pressed

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
            print("[GameScene] Boss mode - using arena size: \(width)x\(height), screen: \(self.screenSize)")
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
            print("[GameScene] didMove - using view bounds: \(view.bounds.size)")
        }

        print("[GameScene] didMove - view: \(view.bounds.size), scene size: \(size), anchorPoint: \(anchorPoint)")
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

        print("[GameScene] setupScene - screenSize: \(screenSize), arena: \(gameState.arena.width)x\(gameState.arena.height), scene size: \(self.size)")

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
        killText = SKLabelNode(text: "Kills: 0")
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
        extractionLabel = SKLabelNode(text: "⬆ EXTRACTION READY")
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

        // Check game over
        if gameState.isGameOver {
            onGameOver?(gameState)
        }
    }

    private func updateGameState(context: FrameContext) {
        // Don't update game logic if game is over (prevents stats from increasing after death)
        guard !gameState.isGameOver else { return }

        // Update time
        gameState.timeElapsed += context.deltaTime
        gameState.gameTime = gameState.timeElapsed

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
            if gameState.timeElapsed - gameState.lastBossSpawnTime >= GameConstants.bossSpawnInterval {
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
        print("[Boss] Initializing boss: \(bossId)")

        // Determine boss type and create state
        let arenaCenter = CGPoint(
            x: gameState.arena.width / 2,
            y: gameState.arena.height / 2
        )

        if bossId.contains("cyberboss") || bossId.contains("server") {
            gameState.activeBossType = .cyberboss
            gameState.cyberbossState = CyberbossAI.createInitialState()
        } else if bossId.contains("void") || bossId.contains("harbinger") {
            gameState.activeBossType = .voidHarbinger
            gameState.voidHarbingerState = VoidHarbingerAI.createInitialState(arenaCenter: arenaCenter)
        }

        gameState.activeBossId = bossId

        // Spawn the boss enemy
        let config = GameConfigLoader.shared

        // Get boss config from JSON or use fallback
        let bossConfig = config.getEnemy(bossId) ?? EnemyConfig(
            id: bossId,
            name: "Boss",
            health: 10000,
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
        print("[Boss] Boss spawned: \(bossConfig.name) at (\(bossEnemy.x), \(bossEnemy.y))")
    }

    private func updateBossAI(context: FrameContext) {
        guard let bossType = gameState.activeBossType else { return }

        // Find the boss enemy
        guard let bossIndex = gameState.enemies.firstIndex(where: { $0.isBoss && !$0.isDead }) else {
            // Boss is dead - trigger victory!
            if !gameState.isGameOver {
                gameState.isGameOver = true
                gameState.victory = true
                print("[Boss] Boss defeated! Victory!")
            }

            // Clear boss state
            gameState.activeBossType = nil
            gameState.activeBossId = nil
            gameState.cyberbossState = nil
            gameState.voidHarbingerState = nil
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

        case .frostTitan, .infernoLord:
            // Future bosses - not implemented yet
            break
        }
    }

    private func updateBossMechanics(context: FrameContext) {
        // NOTE: All damage is handled by the boss AI (CyberbossAI/VoidHarbingerAI)
        // This function now only handles rendering of boss mechanics
        renderBossMechanics()
    }

    // MARK: - Boss Mechanics Rendering

    private var bossMechanicNodes: [String: SKNode] = [:]

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
    }

    private func cleanupBossNodes(prefix: String) {
        let keysToRemove = bossMechanicNodes.keys.filter { $0.hasPrefix(prefix) }
        for key in keysToRemove {
            bossMechanicNodes[key]?.removeFromParent()
            bossMechanicNodes.removeValue(forKey: key)
        }
    }

    // MARK: - Cyberboss Rendering

    private func renderCyberbossMechanics(bossState: CyberbossAI.CyberbossState) {
        guard let boss = gameState.enemies.first(where: { $0.isBoss && !$0.isDead }) else { return }

        // Render chainsaw effect for melee mode (Phase 1-2)
        renderChainsawEffect(bossState: bossState, boss: boss)

        // Render damage puddles
        var activePuddleIds = Set<String>()
        for puddle in bossState.damagePuddles {
            activePuddleIds.insert(puddle.id)
            let nodeKey = "cyberboss_puddle_\(puddle.id)"

            let isWarningPhase = puddle.lifetime < puddle.warningDuration
            let isAboutToPop = puddle.lifetime > puddle.maxLifetime - 0.5

            if let node = bossMechanicNodes[nodeKey] as? SKShapeNode {
                // Update existing node based on phase (using design system colors)
                if isWarningPhase {
                    // Warning phase - amber outline, subtle pulse
                    node.fillColor = DesignColors.warningUI.withAlphaComponent(0.1)
                    node.strokeColor = DesignColors.warningUI
                    node.glowWidth = 3 + 3 * sin(CGFloat(puddle.lifetime * 6))
                } else if isAboutToPop {
                    // About to pop - danger red, high intensity
                    node.fillColor = DesignColors.dangerUI.withAlphaComponent(0.5)
                    node.strokeColor = DesignColors.dangerUI
                    node.glowWidth = 10
                } else {
                    // Active phase - danger fill at lower intensity
                    node.fillColor = DesignColors.dangerUI.withAlphaComponent(0.25)
                    node.strokeColor = DesignColors.dangerUI.withAlphaComponent(0.8)
                    node.glowWidth = 5
                }
            } else {
                // Create new puddle node (starts in warning phase)
                let puddleNode = SKShapeNode(circleOfRadius: puddle.radius)
                puddleNode.fillColor = DesignColors.warningUI.withAlphaComponent(0.1)
                puddleNode.strokeColor = DesignColors.warningUI
                puddleNode.lineWidth = 2
                puddleNode.glowWidth = 3
                // Convert to scene coordinates (flip Y)
                puddleNode.position = CGPoint(x: puddle.x, y: gameState.arena.height - puddle.y)
                puddleNode.zPosition = 5
                puddleNode.name = nodeKey

                // Add pulsing effect
                let pulse = SKAction.sequence([
                    SKAction.scale(to: 1.15, duration: 0.3),
                    SKAction.scale(to: 1.0, duration: 0.3)
                ])
                puddleNode.run(SKAction.repeatForever(pulse))

                addChild(puddleNode)
                bossMechanicNodes[nodeKey] = puddleNode
            }
        }

        // Remove puddles that no longer exist
        let puddleKeysToRemove = bossMechanicNodes.keys.filter {
            $0.hasPrefix("cyberboss_puddle_") && !activePuddleIds.contains($0.replacingOccurrences(of: "cyberboss_puddle_", with: ""))
        }
        for key in puddleKeysToRemove {
            bossMechanicNodes[key]?.removeFromParent()
            bossMechanicNodes.removeValue(forKey: key)
        }

        // Render laser beams
        var activeLaserIds = Set<String>()
        for beam in bossState.laserBeams {
            activeLaserIds.insert(beam.id)
            let nodeKey = "cyberboss_laser_\(beam.id)"

            // Convert to scene coordinates (flip Y)
            let bossSceneX = boss.x
            let bossSceneY = gameState.arena.height - boss.y

            let angleRad = beam.angle * .pi / 180
            let endX = bossSceneX + cos(angleRad) * beam.length
            let endY = bossSceneY + sin(angleRad) * beam.length

            if let node = bossMechanicNodes[nodeKey] as? SKShapeNode {
                // Update existing laser position and rotation
                let path = CGMutablePath()
                path.move(to: CGPoint(x: bossSceneX, y: bossSceneY))
                path.addLine(to: CGPoint(x: endX, y: endY))
                node.path = path
            } else {
                // Create new laser beam node
                let path = CGMutablePath()
                path.move(to: CGPoint(x: bossSceneX, y: bossSceneY))
                path.addLine(to: CGPoint(x: endX, y: endY))

                let laserNode = SKShapeNode(path: path)
                laserNode.strokeColor = DesignColors.dangerUI
                laserNode.lineWidth = 6
                laserNode.glowWidth = 8
                laserNode.zPosition = 100
                laserNode.name = nodeKey

                // Add subtle flicker effect
                let flicker = SKAction.sequence([
                    SKAction.fadeAlpha(to: 0.8, duration: 0.08),
                    SKAction.fadeAlpha(to: 1.0, duration: 0.08)
                ])
                laserNode.run(SKAction.repeatForever(flicker))

                addChild(laserNode)
                bossMechanicNodes[nodeKey] = laserNode
            }
        }

        // Remove lasers that no longer exist
        let laserKeysToRemove = bossMechanicNodes.keys.filter {
            $0.hasPrefix("cyberboss_laser_") && !activeLaserIds.contains($0.replacingOccurrences(of: "cyberboss_laser_", with: ""))
        }
        for key in laserKeysToRemove {
            bossMechanicNodes[key]?.removeFromParent()
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

                // Rotation animation - fast spinning saw
                let rotateAction = SKAction.rotate(byAngle: .pi * 2, duration: 0.8)
                chainsawNode.run(SKAction.repeatForever(rotateAction), withKey: "rotate")

                // Pulsing danger circle
                let pulse = SKAction.sequence([
                    SKAction.scale(to: 1.1, duration: 0.2),
                    SKAction.scale(to: 1.0, duration: 0.2)
                ])
                dangerCircle.run(SKAction.repeatForever(pulse))

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
        // Render void zones
        var activeZoneIds = Set<String>()
        for zone in bossState.voidZones {
            activeZoneIds.insert(zone.id)
            let nodeKey = "voidharbinger_zone_\(zone.id)"

            if let node = bossMechanicNodes[nodeKey] as? SKShapeNode {
                // Update existing node (using design system colors)
                if zone.isActive {
                    node.fillColor = DesignColors.secondaryUI.withAlphaComponent(0.3)
                    node.strokeColor = DesignColors.secondaryUI.withAlphaComponent(0.8)
                } else {
                    // Warning phase - pulsing outline
                    node.fillColor = DesignColors.warningUI.withAlphaComponent(0.1)
                    node.strokeColor = DesignColors.warningUI
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
                    let pulse = SKAction.sequence([
                        SKAction.scale(to: 1.1, duration: 0.4),
                        SKAction.scale(to: 1.0, duration: 0.4)
                    ])
                    zoneNode.run(SKAction.repeatForever(pulse))
                }

                addChild(zoneNode)
                bossMechanicNodes[nodeKey] = zoneNode
            }
        }

        // Remove zones that no longer exist
        let zoneKeysToRemove = bossMechanicNodes.keys.filter {
            $0.hasPrefix("voidharbinger_zone_") && !activeZoneIds.contains($0.replacingOccurrences(of: "voidharbinger_zone_", with: ""))
        }
        for key in zoneKeysToRemove {
            bossMechanicNodes[key]?.removeFromParent()
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

                // Pulsing effect on crystal
                let pulse = SKAction.sequence([
                    SKAction.scale(to: 1.2, duration: 0.5),
                    SKAction.scale(to: 1.0, duration: 0.5)
                ])
                crystal.run(SKAction.repeatForever(pulse))

                addChild(container)
                bossMechanicNodes[nodeKey] = container
            }
        }

        // Remove destroyed pylons
        let pylonKeysToRemove = bossMechanicNodes.keys.filter {
            $0.hasPrefix("voidharbinger_pylon_") && !activePylonIds.contains($0.replacingOccurrences(of: "voidharbinger_pylon_", with: ""))
        }
        for key in pylonKeysToRemove {
            bossMechanicNodes[key]?.removeFromParent()
            bossMechanicNodes.removeValue(forKey: key)
        }

        // Render void rifts (Phase 3+)
        var activeRiftIds = Set<String>()
        for rift in bossState.voidRifts {
            activeRiftIds.insert(rift.id)
            let nodeKey = "voidharbinger_rift_\(rift.id)"

            // Convert to scene coordinates (flip Y)
            let centerSceneX = bossState.arenaCenter.x
            let centerSceneY = gameState.arena.height - bossState.arenaCenter.y
            let sceneCenter = CGPoint(x: centerSceneX, y: centerSceneY)

            let angleRad = rift.angle * .pi / 180
            let endX = centerSceneX + cos(angleRad) * 700
            let endY = centerSceneY + sin(angleRad) * 700

            if let node = bossMechanicNodes[nodeKey] as? SKShapeNode {
                // Update rift position
                let path = CGMutablePath()
                path.move(to: sceneCenter)
                path.addLine(to: CGPoint(x: endX, y: endY))
                node.path = path
            } else {
                // Create new rift node
                let path = CGMutablePath()
                path.move(to: sceneCenter)
                path.addLine(to: CGPoint(x: endX, y: endY))

                let riftNode = SKShapeNode(path: path)
                riftNode.strokeColor = DesignColors.secondaryUI
                riftNode.lineWidth = rift.width
                riftNode.glowWidth = 15
                riftNode.alpha = 0.8
                riftNode.zPosition = 10
                riftNode.name = nodeKey

                addChild(riftNode)
                bossMechanicNodes[nodeKey] = riftNode
            }
        }

        // Remove rifts that no longer exist
        let riftKeysToRemove = bossMechanicNodes.keys.filter {
            $0.hasPrefix("voidharbinger_rift_") && !activeRiftIds.contains($0.replacingOccurrences(of: "voidharbinger_rift_", with: ""))
        }
        for key in riftKeysToRemove {
            bossMechanicNodes[key]?.removeFromParent()
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

                // Rotation animation
                let rotate = SKAction.rotate(byAngle: .pi * 2, duration: 3)
                wellNode.run(SKAction.repeatForever(rotate))

                addChild(wellNode)
                bossMechanicNodes[nodeKey] = wellNode
            }
        }

        // Remove wells that no longer exist
        let wellKeysToRemove = bossMechanicNodes.keys.filter {
            $0.hasPrefix("voidharbinger_well_") && !activeWellIds.contains($0.replacingOccurrences(of: "voidharbinger_well_", with: ""))
        }
        for key in wellKeysToRemove {
            bossMechanicNodes[key]?.removeFromParent()
            bossMechanicNodes.removeValue(forKey: key)
        }

        // Render shrinking arena boundary (Phase 4)
        if bossState.phase == 4 {
            let arenaKey = "voidharbinger_arena"
            // Convert to scene coordinates (flip Y)
            let centerSceneY = gameState.arena.height - bossState.arenaCenter.y

            if let node = bossMechanicNodes[arenaKey] as? SKShapeNode {
                // Update arena size
                let path = CGPath(ellipseIn: CGRect(
                    x: bossState.arenaCenter.x - bossState.arenaRadius,
                    y: centerSceneY - bossState.arenaRadius,
                    width: bossState.arenaRadius * 2,
                    height: bossState.arenaRadius * 2
                ), transform: nil)
                node.path = path
            } else {
                // Create arena boundary
                let path = CGPath(ellipseIn: CGRect(
                    x: bossState.arenaCenter.x - bossState.arenaRadius,
                    y: centerSceneY - bossState.arenaRadius,
                    width: bossState.arenaRadius * 2,
                    height: bossState.arenaRadius * 2
                ), transform: nil)

                let arenaNode = SKShapeNode(path: path)
                arenaNode.fillColor = SKColor.clear
                arenaNode.strokeColor = DesignColors.dangerUI
                arenaNode.lineWidth = 4
                arenaNode.glowWidth = 8
                arenaNode.zPosition = 3
                arenaNode.name = arenaKey

                // Pulsing warning effect
                let pulse = SKAction.sequence([
                    SKAction.fadeAlpha(to: 0.5, duration: 0.5),
                    SKAction.fadeAlpha(to: 1.0, duration: 0.5)
                ])
                arenaNode.run(SKAction.repeatForever(pulse))

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
            label.text = isInvulnerable ? "PHASE \(phase) - INVULNERABLE" : "PHASE \(phase)"
            label.fontColor = isInvulnerable ? DesignColors.warningUI : DesignColors.primaryUI
        } else {
            let label = SKLabelNode(text: "PHASE \(phase)")
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

            // Show event timer
            if let endTime = gameState.eventEndTime {
                let remaining = max(0, endTime - gameState.timeElapsed)
                eventTimerLabel?.text = String(format: "%.1fs remaining", remaining)
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
            killText?.text = "Kills: \(killCount)"
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
