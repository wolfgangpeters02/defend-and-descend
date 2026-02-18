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
    var arenaGridNode: SKShapeNode?
    var vignetteNode: SKSpriteNode?
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
    var shakeOffset: CGPoint = .zero
    var shakeIntensity: CGFloat = 0
    var shakeDuration: TimeInterval = 0
    var shakeElapsed: TimeInterval = 0

    // Callbacks
    var onGameOver: ((GameState) -> Void)?
    var onStateUpdate: ((GameState) -> Void)?
    var didCallGameOver = false  // Prevent calling onGameOver multiple times

    // Screen size for dynamic scaling
    var screenSize: CGSize = .zero
    /// Visible viewport size in scene coordinates (accounts for .aspectFill scaling)
    var visibleViewportSize: CGSize = .zero

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
            // Calculate visible viewport in scene coordinates (accounts for .aspectFill)
            let viewAspect = self.screenSize.width / self.screenSize.height
            let sceneAspect = width / height
            if viewAspect > sceneAspect {
                // View wider than scene: full width visible, top/bottom clipped
                visibleViewportSize = CGSize(width: width, height: width / viewAspect)
            } else {
                // View taller than scene: full height visible, sides clipped
                visibleViewportSize = CGSize(width: height * viewAspect, height: height)
            }
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
        view.preferredFramesPerSecond = 30

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
        arenaGridNode = gridNode as? SKShapeNode
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

    // MARK: - Boss Arena Theme (Stage 9)

    /// 9a: Apply boss-specific arena color theme to background and grid.
    func applyBossArenaTheme() {
        guard let bossType = gameState.activeBossType else { return }

        let bgColor: SKColor
        let gridColor: SKColor

        switch bossType {
        case .cyberboss:
            bgColor = SKColor(red: 10/255, green: 10/255, blue: 26/255, alpha: 1.0)
            gridColor = SKColor(red: 0, green: 1, blue: 1, alpha: 0.08)
        case .voidHarbinger:
            bgColor = SKColor(red: 10/255, green: 0, blue: 15/255, alpha: 1.0)
            gridColor = SKColor(red: 1, green: 0, blue: 1, alpha: 0.06)
        case .overclocker:
            bgColor = SKColor(red: 15/255, green: 10/255, blue: 5/255, alpha: 1.0)
            gridColor = SKColor(red: 1, green: 0.533, blue: 0, alpha: 0.08)
        case .trojanWyrm:
            bgColor = SKColor(red: 5/255, green: 10/255, blue: 5/255, alpha: 1.0)
            gridColor = SKColor(red: 0, green: 1, blue: 0.255, alpha: 0.08)
        }

        backgroundNode?.fillColor = bgColor
        arenaGridNode?.strokeColor = gridColor
        setupVignette()
    }

    /// 9c: Create a radial vignette overlay for the boss arena.
    private func setupVignette() {
        guard vignetteNode == nil else { return }

        let textureSize = CGSize(width: 256, height: 256)
        let renderer = UIGraphicsImageRenderer(size: textureSize)
        let image = renderer.image { context in
            let cgContext = context.cgContext
            let center = CGPoint(x: textureSize.width / 2, y: textureSize.height / 2)
            let maxRadius = sqrt(pow(textureSize.width / 2, 2) + pow(textureSize.height / 2, 2))

            let colors = [UIColor.clear.cgColor, UIColor.black.cgColor]
            let locations: [CGFloat] = [0.3, 1.0]
            guard let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors as CFArray,
                locations: locations
            ) else { return }

            cgContext.drawRadialGradient(
                gradient,
                startCenter: center, startRadius: 0,
                endCenter: center, endRadius: maxRadius,
                options: []
            )
        }

        let texture = SKTexture(image: image)
        let vp = visibleViewportSize.width > 0 ? visibleViewportSize : screenSize
        let vignetteSize = CGSize(width: vp.width * 1.5, height: vp.height * 1.5)
        let vignette = SKSpriteNode(texture: texture, size: vignetteSize)
        vignette.position = .zero
        vignette.zPosition = -10
        vignette.alpha = 0.1

        if let cam = cameraNode {
            cam.addChild(vignette)
        } else {
            vignette.position = CGPoint(x: gameState.arena.width / 2, y: gameState.arena.height / 2)
            addChild(vignette)
        }
        vignetteNode = vignette
    }

    /// 9c: Update vignette intensity based on boss phase.
    func updateVignetteForPhase(_ phase: Int) {
        guard let vignette = vignetteNode else { return }
        let targetAlpha: CGFloat
        switch phase {
        case 1: targetAlpha = 0.1
        case 2: targetAlpha = 0.15
        case 3: targetAlpha = 0.2
        case 4: targetAlpha = 0.3
        default: targetAlpha = 0.1
        }
        if abs(vignette.alpha - targetAlpha) > 0.01 {
            vignette.run(SKAction.fadeAlpha(to: targetAlpha, duration: 0.5), withKey: "vignetteFade")
        }
    }

    /// Returns the current boss phase (1-4).
    func currentBossPhase() -> Int {
        if let s = gameState.cyberbossState { return s.phase }
        if let s = gameState.voidHarbingerState { return s.phase }
        if let s = gameState.overclockerState { return s.phase }
        if let s = gameState.trojanWyrmState { return s.phase }
        return 1
    }

    /// Returns the theme color for the active boss type.
    func bossThemeColor() -> SKColor {
        guard let bossType = gameState.activeBossType else {
            return SKColor(red: 0, green: 1, blue: 0.255, alpha: 1)
        }
        switch bossType {
        case .cyberboss:     return SKColor(red: 0, green: 1, blue: 1, alpha: 1)
        case .voidHarbinger: return SKColor(red: 1, green: 0, blue: 1, alpha: 1)
        case .overclocker:   return SKColor(red: 1, green: 0.533, blue: 0, alpha: 1)
        case .trojanWyrm:    return SKColor(red: 0, green: 1, blue: 0.255, alpha: 1)
        }
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

        // Update player
        PlayerSystem.update(state: &gameState, input: inputState, context: context)

        // Process obstacle collisions (all modes with obstacles)
        if !gameState.arena.obstacles.isEmpty {
            ArenaSystem.processPlayerObstacleCollisions(state: &gameState)
        }

        // Constrain player to arena bounds
        ArenaSystem.constrainPlayerToArena(state: &gameState)

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

        // Boss mode specific updates
        if gameState.gameMode == .boss && gameState.activeBossId != nil {
            updateBossAI(context: context)
            updateBossMechanics(context: context)
            // Update destructible pillars
            PillarSystem.update(state: &gameState, deltaTime: context.deltaTime)

        }

        // Update screen shake offset (decays each frame)
        updateShake(deltaTime: context.deltaTime)

        // Update camera to follow player (for large arenas)
        updateCameraFollow()
    }

    // MARK: - Camera Follow

    private func updateCameraFollow() {
        guard let camera = cameraNode else { return }

        // Calculate target camera position (centered on player)
        let targetX = gameState.player.x
        let targetY = gameState.arena.height - gameState.player.y  // Flip Y for scene coords

        // Clamp camera to arena bounds (use visible viewport to account for .aspectFill scaling)
        let viewport = visibleViewportSize.width > 0 ? visibleViewportSize : screenSize
        let halfWidth = viewport.width / 2
        let halfHeight = viewport.height / 2

        let clampedX = max(halfWidth, min(gameState.arena.width - halfWidth, targetX))
        let clampedY = max(halfHeight, min(gameState.arena.height - halfHeight, targetY))

        // Smooth camera follow (ignore shake offset for base tracking)
        let baseX = camera.position.x - shakeOffset.x
        let baseY = camera.position.y - shakeOffset.y
        let smoothing: CGFloat = 0.1
        let newX = baseX + (clampedX - baseX) * smoothing
        let newY = baseY + (clampedY - baseY) * smoothing

        // Apply shake offset on top of follow position
        camera.position = CGPoint(x: newX + shakeOffset.x, y: newY + shakeOffset.y)
    }

    private func updateParticles(context: FrameContext) {
        let timestamp = context.timestamp
        let dt = CGFloat(context.deltaTime)
        var writeIndex = 0

        for i in 0..<gameState.particles.count {
            // Remove expired particles in-place
            if timestamp - gameState.particles[i].createdAt >= gameState.particles[i].lifetime {
                continue
            }

            // Update position
            if let velocity = gameState.particles[i].velocity {
                gameState.particles[i].x += velocity.x * dt
                gameState.particles[i].y += velocity.y * dt

                // Apply drag
                if let drag = gameState.particles[i].drag, drag > 0 {
                    gameState.particles[i].velocity = CGPoint(
                        x: velocity.x * (1 - drag),
                        y: velocity.y * (1 - drag)
                    )
                }
            }

            // Compact in-place
            gameState.particles[writeIndex] = gameState.particles[i]
            writeIndex += 1
        }

        gameState.particles.removeSubrange(writeIndex..<gameState.particles.count)
    }

    // MARK: - HUD Setup (Cached - Phase 1.3)

    func setupHUD() {
        hudLayer = SKNode()
        hudLayer.zPosition = 1000

        // For boss mode with larger arena, attach HUD to camera so it stays on screen
        if gameState.gameMode == .boss, let cam = cameraNode {
            cam.addChild(hudLayer)
        } else {
            addChild(hudLayer)
        }

        let healthBarWidth: CGFloat = 200
        let healthBarHeight: CGFloat = 20

        let bossViewport = visibleViewportSize.width > 0 ? visibleViewportSize : screenSize
        let hudWidth = gameState.gameMode == .boss ? bossViewport.width : gameState.arena.width
        let hudHeight = gameState.gameMode == .boss ? bossViewport.height : gameState.arena.height
        let hudYOffset: CGFloat = gameState.gameMode == .boss ? hudHeight / 2 - 30 : hudHeight - 30
        let hudXOffsetLeft: CGFloat = gameState.gameMode == .boss ? -hudWidth / 2 + 120 : 120
        let hudXCenter: CGFloat = gameState.gameMode == .boss ? 0 : hudWidth / 2
        let hudXOffsetRight: CGFloat = gameState.gameMode == .boss ? hudWidth / 2 - 20 : hudWidth - 20

        healthBarBg = SKShapeNode(rectOf: CGSize(width: healthBarWidth, height: healthBarHeight), cornerRadius: 4)
        healthBarBg.fillColor = SKColor.darkGray
        healthBarBg.strokeColor = SKColor.white.withAlphaComponent(0.3)
        healthBarBg.position = CGPoint(x: hudXOffsetLeft, y: hudYOffset)
        hudLayer.addChild(healthBarBg)

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

        healthText = SKLabelNode(text: "\(Int(gameState.player.maxHealth))/\(Int(gameState.player.maxHealth))")
        healthText.fontName = "Helvetica-Bold"
        healthText.fontSize = 14
        healthText.fontColor = .white
        healthText.position = CGPoint(x: healthBarBg.position.x, y: healthBarBg.position.y - 5)
        hudLayer.addChild(healthText)

        timerText = SKLabelNode(text: "0:00")
        timerText.fontName = "Helvetica-Bold"
        timerText.fontSize = 24
        timerText.fontColor = .white
        timerText.position = CGPoint(x: hudXCenter, y: hudYOffset)
        hudLayer.addChild(timerText)

        killText = SKLabelNode(text: L10n.Game.HUD.kills(0))
        killText.fontName = "Helvetica"
        killText.fontSize = 16
        killText.fontColor = .white
        killText.horizontalAlignmentMode = .right
        killText.position = CGPoint(x: hudXOffsetRight, y: hudYOffset)
        hudLayer.addChild(killText)
    }

    // MARK: - HUD Update (Cached - Phase 1.3)

    func updateHUD() {
        guard healthBarFill != nil else { return }

        let healthPercent = gameState.player.health / gameState.player.maxHealth
        if abs(healthPercent - lastHealthPercent) > 0.001 {
            lastHealthPercent = healthPercent
            healthBarFill.xScale = max(0.001, healthPercent)
            healthBarFill.fillColor = healthPercent > 0.3 ? SKColor.green : SKColor.red
            healthText?.text = "\(Int(gameState.player.health))/\(Int(gameState.player.maxHealth))"
        }

        let timeSeconds = Int(gameState.timeElapsed)
        if timeSeconds != lastTimeSeconds {
            lastTimeSeconds = timeSeconds
            let minutes = timeSeconds / 60
            let seconds = timeSeconds % 60
            timerText?.text = String(format: "%d:%02d", minutes, seconds)
        }

        let killCount = gameState.stats.enemiesKilled
        if killCount != lastKillCount {
            lastKillCount = killCount
            killText?.text = L10n.Game.HUD.kills(killCount)
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

        // Clear arena theme references
        arenaGridNode = nil
        vignetteNode = nil

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
