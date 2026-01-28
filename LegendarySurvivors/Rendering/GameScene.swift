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
    private var dataEarnedLabel: SKLabelNode?
    private var extractionLabel: SKLabelNode?
    private var lastDataEarned: Int = 0

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

        // Use screen size if provided and valid, otherwise fall back to arena size
        if let screenSize = screenSize, screenSize.width > 0, screenSize.height > 0 {
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

        // Scene fills the screen
        self.size = screenSize
        self.scaleMode = .resizeFill

        // Also set anchorPoint here (will be reinforced in didMove)
        self.anchorPoint = CGPoint(x: 0, y: 0)

        print("[GameScene] setupScene - screenSize: \(screenSize), arena: \(gameState.arena.width)x\(gameState.arena.height)")

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
        setupHUD()
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

        // Data earned display (bottom left)
        dataEarnedLabel = SKLabelNode(text: "◈ 0")
        dataEarnedLabel?.fontName = "Menlo-Bold"
        dataEarnedLabel?.fontSize = 18
        dataEarnedLabel?.fontColor = SKColor(red: 0, green: 0.83, blue: 1, alpha: 1) // #00d4ff
        dataEarnedLabel?.horizontalAlignmentMode = .left
        dataEarnedLabel?.position = CGPoint(x: 20, y: 50)
        dataEarnedLabel?.zPosition = 1001
        addChild(dataEarnedLabel!)

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

    /// Get current Data earned (for UI)
    var dataEarned: Int {
        return gameState.stats.dataEarned
    }

    /// Trigger extraction - ends game with 100% Data reward
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

        // Get boss config or create a default powerful boss config
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
        // Update Cyberboss damage puddles
        if let bossState = gameState.cyberbossState {
            for puddle in bossState.damagePuddles {
                let dx = gameState.player.x - puddle.x
                let dy = gameState.player.y - puddle.y
                let distance = sqrt(dx * dx + dy * dy)

                if distance < puddle.radius {
                    // Apply damage
                    gameState.player.health -= puddle.damage * CGFloat(context.deltaTime)
                }
            }

            // Update laser beams collision
            for beam in bossState.laserBeams {
                if let bossIndex = gameState.enemies.firstIndex(where: { $0.isBoss && !$0.isDead }) {
                    let boss = gameState.enemies[bossIndex]
                    let beamEndX = boss.x + cos(beam.angle * .pi / 180) * beam.length
                    let beamEndY = boss.y + sin(beam.angle * .pi / 180) * beam.length

                    // Point-to-line distance
                    let distance = pointToLineDistance(
                        point: CGPoint(x: gameState.player.x, y: gameState.player.y),
                        lineStart: CGPoint(x: boss.x, y: boss.y),
                        lineEnd: CGPoint(x: beamEndX, y: beamEndY)
                    )

                    if distance < 20 {
                        // Laser hit - heavy damage
                        gameState.player.health -= beam.damage
                    }
                }
            }
        }

        // Update Void Harbinger mechanics
        if gameState.voidHarbingerState != nil {
            // Void zones
            if let voidZones = gameState.voidZones {
                for zone in voidZones where zone.activated {
                    let dx = gameState.player.x - zone.x
                    let dy = gameState.player.y - zone.y
                    let distance = sqrt(dx * dx + dy * dy)

                    if distance < zone.radius {
                        gameState.player.health -= zone.damage * CGFloat(context.deltaTime)
                    }
                }
            }

            // Gravity wells
            if let wells = gameState.gravityWells {
                for well in wells {
                    let dx = well.x - gameState.player.x
                    let dy = well.y - gameState.player.y
                    let distance = sqrt(dx * dx + dy * dy)

                    if distance < well.pullRadius && distance > 10 {
                        let pullStrength = well.pullStrength * (1 - distance / well.pullRadius)
                        let nx = dx / distance
                        let ny = dy / distance
                        gameState.player.x += nx * pullStrength * CGFloat(context.deltaTime)
                        gameState.player.y += ny * pullStrength * CGFloat(context.deltaTime)
                    }
                }
            }

            // Arena walls (shrinking arena)
            if let walls = gameState.arenaWalls {
                let centerX = gameState.arena.width / 2
                let centerY = gameState.arena.height / 2
                let dx = gameState.player.x - centerX
                let dy = gameState.player.y - centerY
                let distance = sqrt(dx * dx + dy * dy)

                if distance > walls.currentRadius {
                    // Push player back and deal damage
                    let nx = dx / distance
                    let ny = dy / distance
                    gameState.player.x = centerX + nx * (walls.currentRadius - 10)
                    gameState.player.y = centerY + ny * (walls.currentRadius - 10)
                    gameState.player.health -= walls.damage * CGFloat(context.deltaTime)
                }
            }
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
        // Update Data earned display
        if gameState.stats.dataEarned != lastDataEarned {
            lastDataEarned = gameState.stats.dataEarned
            dataEarnedLabel?.text = "◈ \(gameState.stats.dataEarned)"
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
