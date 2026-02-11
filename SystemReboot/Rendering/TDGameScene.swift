import SpriteKit
import SwiftUI

// MARK: - TD Game Scene
// SpriteKit scene for Tower Defense rendering

class TDGameScene: SKScene {

    // MARK: - Properties

    weak var gameStateDelegate: TDGameSceneDelegate?

    var state: TDGameState?  // Internal access for boss fight state sync
    var lastUpdateTime: TimeInterval = 0
    var spawnTimer: TimeInterval = 0
    var currentWaveIndex: Int = 0
    var waves: [TDWave] = []
    var gameStartDelay: TimeInterval = BalanceConfig.TDRendering.gameStartDelay
    var hasStartedFirstWave: Bool = false

    // Logging state (to avoid spam)
    var lastLoggedEnemyCount: Int = -1
    var lastLoggedWaveNumber: Int = -1

    // Node layers
    var backgroundLayer: SKNode!
    var pathLayer: SKNode!
    var towerSlotLayer: SKNode!           // Hidden by default, shown only during drag
    var gridDotsLayer: SKNode!            // Subtle grid dots for placement mode
    var blockerLayer: SKNode!             // Blocker nodes and slots layer
    var activeSlotHighlight: SKNode? // Highlights nearest valid slot during drag
    var towerLayer: SKNode!
    var enemyLayer: SKNode!
    var projectileLayer: SKNode!
    var uiLayer: SKNode!

    // Placement state (for progressive disclosure)
    var isInPlacementMode: Bool = false
    var placementWeaponType: String?

    // Cached nodes for performance
    var towerNodes: [String: SKNode] = [:]
    var enemyNodes: [String: SKNode] = [:]
    var projectileNodes: [String: SKNode] = [:]
    var slotNodes: [String: SKNode] = [:]
    var gateNodes: [String: SKNode] = [:]  // Mega-board encryption gates

    // Animation LOD: Track which towers have paused animations for off-screen culling
    var pausedTowerAnimations: Set<String> = []

    // Mega-board renderer
    var megaBoardRenderer: MegaBoardRenderer?

    // Selection
    var selectedSlotId: String?
    var selectedTowerId: String?

    // Drag state for merging and moving
    var isDragging = false
    var draggedTowerId: String?
    var dragStartPosition: CGPoint?
    var dragNode: SKNode?
    var longPressTimer: Timer?
    var validMoveSlots: Set<String> = []  // Empty slots for tower repositioning

    // Particle layer
    var particleLayer: SKNode!

    // Camera controller (zoom, pan, inertia — extracted in Step 4.2)
    let cameraController = CameraController()

    // Forwarding properties so extensions keep compiling unchanged
    var cameraNode: SKCameraNode! { cameraController.cameraNode }
    var currentScale: CGFloat { cameraController.currentScale }

    /// Expose camera scale for coordinate conversion from SwiftUI layer
    var cameraScale: CGFloat { cameraController.currentScale }

    // Parallax background
    var parallaxLayers: [(node: SKNode, speedFactor: CGFloat)] = []
    var lastCameraPosition: CGPoint = .zero

    // Projectile trails
    var projectileTrails: [String: [CGPoint]] = [:]
    let maxTrailLength: Int = 8

    // Projectile previous positions for swept collision detection
    var projectilePrevPositions: [String: CGPoint] = [:]

    // Tower attack tracking for firing animations
    var towerLastAttackTimes: [String: TimeInterval] = [:]

    // MARK: - Path LED System (Visual Overhaul)
    // LEDs along lanes that react to enemy proximity
    var pathLEDNodes: [String: [SKShapeNode]] = [:]  // laneId -> LED nodes
    var ledUpdateCounter: Int = 0                      // Update every 3 frames for performance
    var ledIdlePhase: CGFloat = 0                      // For idle heartbeat animation

    // MARK: - Capacitor System (PSU Power Theme)
    // Capacitors in PSU sector that pulse and "discharge" when towers fire
    var psuCapacitorNodes: [SKNode] = []              // Capacitor containers for animation
    var lastCapacitorDischargeTime: TimeInterval = 0  // Cooldown between discharge effects

    // MARK: - Power Flow Particles (PSU Power Theme)
    // Constant subtle particles flowing from PSU toward CPU along traces
    var powerFlowEmitterRunning: Bool = false
    var lastPowerFlowSpawnTime: TimeInterval = 0

    // MARK: - Screen Shake System (Context-Aware)
    // Only shakes when zoomed in, with cooldown to prevent shake fatigue
    var lastShakeTime: TimeInterval = 0
    var screenShakeCooldown: TimeInterval = BalanceConfig.TDRendering.screenShakeCooldown
    var originalCameraPosition: CGPoint = .zero
    var isShaking: Bool = false

    // MARK: - Efficiency Tracking (for damage flash)
    var previousEfficiency: CGFloat = 100

    // MARK: - Smooth Barrel Rotation
    // Interpolated barrel rotation for polished aiming feel
    var towerBarrelRotations: [String: CGFloat] = [:]  // towerId -> current barrel rotation
    let barrelRotationSpeed: CGFloat = BalanceConfig.TDRendering.barrelRotationSpeed

    // Motherboard City rendering
    var isMotherboardMap: Bool {
        state?.map.theme == "motherboard"
    }

    // MARK: - LED Update Caches
    // Cached lane config for LED updates (avoids per-frame allocation)
    lazy var cachedLaneConfig: [SectorLane] = MotherboardLaneConfig.createAllLanes()
    lazy var laneColorCache: [String: UIColor] = {
        var cache: [String: UIColor] = [:]
        for lane in MotherboardLaneConfig.createAllLanes() {
            cache[lane.id] = UIColor(hex: lane.themeColorHex) ?? UIColor.yellow
        }
        return cache
    }()

    // MARK: - Ambient Particle Management (Performance)
    // Caps on ambient particles to prevent unbounded growth
    var ambientParticleCount: Int = 0
    let maxAmbientParticles: Int = BalanceConfig.TDRendering.maxAmbientParticles
    var visibleSectorIds: Set<String> = []  // For culling off-screen effects
    var lastVisibilityUpdate: TimeInterval = 0
    let visibilityUpdateInterval: TimeInterval = BalanceConfig.TDRendering.visibilityUpdateInterval

    // MARK: - Setup

    override func didMove(to view: SKView) {
        backgroundColor = .black

        // CRITICAL: Set anchor point to bottom-left (0,0) for correct positioning
        // Without this, default (0.5, 0.5) makes (0,0) the center, causing entities
        // to render in wrong positions
        self.anchorPoint = CGPoint(x: 0, y: 0)

        #if DEBUG
        print("[TDGameScene] didMove - view: \(view.bounds.size), scene size: \(size)")
        #endif

        // Only setup layers if not already done (loadState may have been called first)
        if backgroundLayer == nil {
            setupLayers()
        }

        // Setup camera for zoom/pan (delegated to CameraController)
        cameraController.isMotherboardMap = isMotherboardMap
        cameraController.shouldSuppressPan = { [weak self] in
            guard let self = self else { return false }
            return self.isInPlacementMode || self.isDragging
        }
        let starterCenter = isMotherboardMap ? MegaBoardSystem.shared.starterSector?.center : nil
        cameraController.setup(in: self, starterSectorCenter: starterCenter)
        cameraController.setupGestureRecognizers(view: view)
    }

    /// Reset camera to default view
    func resetCamera() {
        cameraController.reset(to: CGPoint(x: size.width / 2, y: size.height / 2), scale: 1.0)
    }

    private func setupLayers() {
        // Create layer hierarchy (z-order matters for progressive disclosure)
        backgroundLayer = SKNode()
        backgroundLayer.zPosition = 0
        addChild(backgroundLayer)

        // Grid dots layer - below path, always slightly visible for socket awareness
        gridDotsLayer = SKNode()
        gridDotsLayer.zPosition = 1
        gridDotsLayer.alpha = 0.3  // Always slightly visible (Dark Terminal aesthetic)
        addChild(gridDotsLayer)

        // Path layer - above grid dots so path is always visible
        pathLayer = SKNode()
        pathLayer.zPosition = 3
        addChild(pathLayer)

        // Blocker layer - on path layer for visual placement
        blockerLayer = SKNode()
        blockerLayer.zPosition = 3.5
        addChild(blockerLayer)

        // Tower slot layer - HIDDEN by default (progressive disclosure)
        // Only shown during drag operations
        towerSlotLayer = SKNode()
        towerSlotLayer.zPosition = 2
        towerSlotLayer.alpha = 0  // Hidden by default
        addChild(towerSlotLayer)

        towerLayer = SKNode()
        towerLayer.zPosition = 4
        addChild(towerLayer)

        enemyLayer = SKNode()
        enemyLayer.zPosition = 5
        addChild(enemyLayer)

        projectileLayer = SKNode()
        projectileLayer.zPosition = 6
        addChild(projectileLayer)

        particleLayer = SKNode()
        particleLayer.zPosition = 7
        addChild(particleLayer)

        uiLayer = SKNode()
        uiLayer.zPosition = 10
        addChild(uiLayer)
    }

    // MARK: - State Management

    func loadState(_ newState: TDGameState, waves: [TDWave]) {
        self.state = newState
        self.waves = waves

        // Sync wave progress with saved state
        // If waves were completed in a previous session, resume from that point
        if newState.wavesCompleted > 0 && newState.wavesCompleted < waves.count {
            currentWaveIndex = newState.wavesCompleted
            hasStartedFirstWave = true
            gameStartDelay = 0  // No delay for restored sessions with progress
            // Reset wave-in-progress state to start fresh at next wave
            self.state?.waveInProgress = false
            self.state?.waveEnemiesSpawned = 0
            self.state?.waveEnemiesRemaining = 0
        } else if !newState.towers.isEmpty {
            // Session has towers but no completed waves - player built defenses, start quickly
            currentWaveIndex = 0
            hasStartedFirstWave = false
            gameStartDelay = 0.5  // Brief delay then start
            // Reset wave state to ensure clean start
            self.state?.waveInProgress = false
            self.state?.waveEnemiesSpawned = 0
            self.state?.waveEnemiesRemaining = 0
        } else {
            // Fresh start - short delay to let player see the board
            currentWaveIndex = 0
            hasStartedFirstWave = false
            gameStartDelay = 1.0  // Reduced from 2.0
        }

        // Initialize mega-board system for motherboard maps
        if newState.map.theme == "motherboard" {
            MegaBoardSystem.shared.loadDefaultConfig()
            MegaBoardSystem.shared.updateUnlockCache(from: AppState.shared.currentPlayer)
        }

        // Ensure layers are set up (in case loadState is called before didMove)
        if backgroundLayer == nil {
            setupLayers()
        }

        // Setup visuals
        setupBackground()
        setupPaths()
        setupTowerSlots()
        setupBlockers()
        setupCore()

        // Setup mega-board visuals (ghost sectors, gates) for motherboard maps
        if newState.map.theme == "motherboard" {
            setupMegaBoardVisuals()
        }
    }

    private func setupTowerSlots() {
        guard let state = state else { return }

        towerSlotLayer.removeAllChildren()
        gridDotsLayer.removeAllChildren()
        slotNodes.removeAll()

        for slot in state.towerSlots {
            // Create subtle grid dot (shown only during placement mode)
            let gridDot = createGridDot(slot: slot)
            gridDot.position = convertToScene(slot.position)
            gridDot.name = "gridDot_\(slot.id)"
            gridDotsLayer.addChild(gridDot)

            // Create legacy slot node (hidden by default, used for hit detection)
            let slotNode = createSlotNode(slot: slot)
            slotNode.position = convertToScene(slot.position)
            slotNode.name = "slot_\(slot.id)"
            towerSlotLayer.addChild(slotNode)
            slotNodes[slot.id] = slotNode
        }
    }

    /// Create tower socket visual (Circuit board aesthetic)
    /// Smaller, subtler dots when idle; brighter appearance during placement
    private func createGridDot(slot: TowerSlot) -> SKNode {
        let container = SKNode()

        if slot.occupied {
            // Occupied slot: Bright chip indicator
            let chipSize: CGFloat = 20
            let chip = SKShapeNode(rectOf: CGSize(width: chipSize, height: chipSize), cornerRadius: 3)
            chip.fillColor = DesignColors.primaryUI.withAlphaComponent(0.6)
            chip.strokeColor = DesignColors.primaryUI
            chip.lineWidth = 1
            chip.glowWidth = 4
            container.addChild(chip)
        } else {
            // Empty slot: Subtle grid point with circuit board pins
            let dotRadius: CGFloat = 4
            let dot = SKShapeNode(circleOfRadius: dotRadius)
            dot.fillColor = UIColor(white: 0.3, alpha: 0.4)
            dot.strokeColor = UIColor(white: 0.5, alpha: 0.3)
            dot.lineWidth = 1
            container.addChild(dot)

            // Corner pins (circuit board aesthetic - smaller, subtler)
            let pinSize: CGFloat = 3
            let pinOffset: CGFloat = 10
            for (xSign, ySign) in [(1, 1), (1, -1), (-1, 1), (-1, -1)] as [(CGFloat, CGFloat)] {
                let pin = SKShapeNode(rectOf: CGSize(width: pinSize, height: pinSize))
                pin.fillColor = UIColor(white: 0.4, alpha: 0.3)
                pin.strokeColor = .clear
                pin.position = CGPoint(x: pinOffset * xSign, y: pinOffset * ySign)
                container.addChild(pin)
            }

            // Connection traces (subtle lines to pins)
            for (xSign, ySign) in [(1, 0), (-1, 0), (0, 1), (0, -1)] as [(CGFloat, CGFloat)] {
                let trace = SKShapeNode()
                let path = CGMutablePath()
                path.move(to: CGPoint(x: dotRadius * xSign, y: dotRadius * ySign))
                path.addLine(to: CGPoint(x: 8 * xSign, y: 8 * ySign))
                trace.path = path
                trace.strokeColor = UIColor(white: 0.35, alpha: 0.25)
                trace.lineWidth = 1
                container.addChild(trace)
            }
        }

        return container
    }

    private func createSlotNode(slot: TowerSlot) -> SKNode {
        let container = SKNode()

        // Invisible hit area for slot detection (progressive disclosure - no visible circles)
        let hitArea = SKShapeNode(circleOfRadius: slot.size / 2)
        hitArea.fillColor = .clear
        hitArea.strokeColor = .clear
        hitArea.name = "hitArea"
        container.addChild(hitArea)

        return container
    }

    // MARK: - Blocker Nodes (System: Reboot - Path Control)

    func setupBlockers() {
        guard let state = state else { return }

        blockerLayer.removeAllChildren()

        // Render blocker slots (available placement positions)
        for slot in state.blockerSlots {
            let slotNode = createBlockerSlotNode(slot: slot)
            slotNode.position = convertToScene(slot.position)
            slotNode.name = "blockerSlot_\(slot.id)"
            blockerLayer.addChild(slotNode)
        }

        // Render placed blockers
        for blocker in state.blockerNodes {
            let blockerNode = createBlockerNode(blocker: blocker)
            blockerNode.position = convertToScene(blocker.position)
            blockerNode.name = "blocker_\(blocker.id)"
            blockerLayer.addChild(blockerNode)
        }
    }

    /// Create visual for blocker slot (octagon outline where blocker can be placed)
    private func createBlockerSlotNode(slot: BlockerSlot) -> SKNode {
        let container = SKNode()

        if slot.occupied {
            // Slot is occupied - no visual needed (blocker will be rendered separately)
            return container
        }

        // Draw octagon outline to indicate available blocker position
        let size: CGFloat = 24
        let path = UIBezierPath()
        let points = octagonPoints(size: size)
        path.move(to: points[0])
        for i in 1..<points.count {
            path.addLine(to: points[i])
        }
        path.close()

        let octagon = SKShapeNode(path: path.cgPath)
        octagon.strokeColor = UIColor.red.withAlphaComponent(0.4)
        octagon.fillColor = UIColor.red.withAlphaComponent(0.1)
        octagon.lineWidth = 2
        octagon.glowWidth = 2

        // Subtle pulse animation
        let fadeOut = SKAction.fadeAlpha(to: 0.3, duration: 1.0)
        let fadeIn = SKAction.fadeAlpha(to: 0.7, duration: 1.0)
        octagon.run(SKAction.repeatForever(SKAction.sequence([fadeOut, fadeIn])))

        container.addChild(octagon)
        return container
    }

    /// Create visual for placed blocker (solid red octagon - stop sign aesthetic)
    private func createBlockerNode(blocker: BlockerNode) -> SKNode {
        let container = SKNode()

        // Draw solid octagon (stop sign style)
        let size: CGFloat = 28
        let path = UIBezierPath()
        let points = octagonPoints(size: size)
        path.move(to: points[0])
        for i in 1..<points.count {
            path.addLine(to: points[i])
        }
        path.close()

        let octagon = SKShapeNode(path: path.cgPath)
        octagon.strokeColor = UIColor(red: 0.8, green: 0.1, blue: 0.1, alpha: 1.0)
        octagon.fillColor = UIColor(red: 0.6, green: 0.1, blue: 0.1, alpha: 0.9)
        octagon.lineWidth = 3
        container.addChild(octagon)

        // Add "X" or "STOP" symbol inside
        let xSize: CGFloat = 10
        let xPath = UIBezierPath()
        xPath.move(to: CGPoint(x: -xSize, y: -xSize))
        xPath.addLine(to: CGPoint(x: xSize, y: xSize))
        xPath.move(to: CGPoint(x: xSize, y: -xSize))
        xPath.addLine(to: CGPoint(x: -xSize, y: xSize))

        let xSymbol = SKShapeNode(path: xPath.cgPath)
        xSymbol.strokeColor = .white
        xSymbol.lineWidth = 3
        xSymbol.lineCap = .round
        container.addChild(xSymbol)

        return container
    }

    /// Generate points for an octagon shape
    private func octagonPoints(size: CGFloat) -> [CGPoint] {
        var points: [CGPoint] = []
        let radius = size / 2
        for i in 0..<8 {
            let angle = CGFloat(i) * .pi / 4 - .pi / 8
            let x = radius * cos(angle)
            let y = radius * sin(angle)
            points.append(CGPoint(x: x, y: y))
        }
        return points
    }

    /// Update blocker visuals after placement/removal
    func updateBlockers() {
        setupBlockers()
    }

    private func setupCore() {
        guard let state = state else { return }

        // Copper/Gold colors matching trace aesthetic
        let copperColor = UIColor(red: 184/255, green: 115/255, blue: 51/255, alpha: 1.0)  // #b87333
        let goldGlowColor = UIColor(red: 212/255, green: 168/255, blue: 75/255, alpha: 1.0)  // #d4a84b

        // Create CPU container node
        let coreContainer = SKNode()
        coreContainer.position = convertToScene(state.core.position)
        coreContainer.name = "core"

        // CPU body - rounded square (Heatsink/Chip aesthetic)
        let cpuSize: CGFloat = 90
        let cpuBody = SKShapeNode(rectOf: CGSize(width: cpuSize, height: cpuSize), cornerRadius: 12)
        cpuBody.fillColor = DesignColors.surfaceUI
        cpuBody.strokeColor = copperColor
        cpuBody.lineWidth = 4
        cpuBody.glowWidth = 8
        cpuBody.name = "cpuBody"
        coreContainer.addChild(cpuBody)

        // Inner chip detail - smaller square with copper accent
        let innerSize: CGFloat = 60
        let innerChip = SKShapeNode(rectOf: CGSize(width: innerSize, height: innerSize), cornerRadius: 6)
        innerChip.fillColor = DesignColors.backgroundUI
        innerChip.strokeColor = copperColor.withAlphaComponent(0.6)
        innerChip.lineWidth = 2
        innerChip.name = "innerChip"
        coreContainer.addChild(innerChip)

        // CPU label with copper color
        let cpuLabel = SKLabelNode(text: "CPU")
        cpuLabel.fontName = "Menlo-Bold"
        cpuLabel.fontSize = 20
        cpuLabel.fontColor = copperColor
        cpuLabel.verticalAlignmentMode = .center
        cpuLabel.horizontalAlignmentMode = .center
        coreContainer.addChild(cpuLabel)

        // Efficiency percentage (below CPU text)
        let efficiencyLabel = SKLabelNode(text: "100%")
        efficiencyLabel.fontName = "Menlo-Bold"
        efficiencyLabel.fontSize = 12
        efficiencyLabel.fontColor = DesignColors.successUI
        efficiencyLabel.verticalAlignmentMode = .center
        efficiencyLabel.horizontalAlignmentMode = .center
        efficiencyLabel.position = CGPoint(x: 0, y: -18)
        efficiencyLabel.name = "efficiencyLabel"
        coreContainer.addChild(efficiencyLabel)

        // Heatsink fins radiating from the chip (copper colored)
        let finCount = 8
        let finLength: CGFloat = 20
        let finWidth: CGFloat = 6
        let finOffset = cpuSize / 2 + finLength / 2 + 2

        for i in 0..<finCount {
            let angle = CGFloat(i) * .pi / 4  // 8 directions
            let fin = SKShapeNode(rectOf: CGSize(width: finWidth, height: finLength), cornerRadius: 2)
            fin.fillColor = copperColor.withAlphaComponent(0.7)
            fin.strokeColor = copperColor
            fin.lineWidth = 1

            fin.position = CGPoint(
                x: cos(angle) * finOffset,
                y: sin(angle) * finOffset
            )
            fin.zRotation = angle + .pi / 2
            fin.zPosition = -0.5
            coreContainer.addChild(fin)
        }

        // Pin connectors (circuit board aesthetic - copper)
        let pinCount = 6
        let pinLength: CGFloat = 15
        let pinWidth: CGFloat = 4
        let pinSpacing = cpuSize / CGFloat(pinCount + 1)

        for side in 0..<4 {  // 4 sides
            for i in 1...pinCount {
                let pin = SKShapeNode(rectOf: CGSize(width: pinWidth, height: pinLength))
                pin.fillColor = copperColor.withAlphaComponent(0.5)
                pin.strokeColor = .clear

                let offset = -cpuSize / 2 + pinSpacing * CGFloat(i)
                switch side {
                case 0: // Top
                    pin.position = CGPoint(x: offset, y: cpuSize / 2 + pinLength / 2)
                case 1: // Bottom
                    pin.position = CGPoint(x: offset, y: -cpuSize / 2 - pinLength / 2)
                case 2: // Left
                    pin.zRotation = .pi / 2
                    pin.position = CGPoint(x: -cpuSize / 2 - pinLength / 2, y: offset)
                case 3: // Right
                    pin.zRotation = .pi / 2
                    pin.position = CGPoint(x: cpuSize / 2 + pinLength / 2, y: offset)
                default:
                    break
                }
                coreContainer.addChild(pin)
            }
        }

        // Glow ring (pulsing gold glow - intensity based on efficiency)
        let glowRing = SKShapeNode(circleOfRadius: cpuSize / 2 + 25)
        glowRing.fillColor = .clear
        glowRing.strokeColor = goldGlowColor.withAlphaComponent(0.4)
        glowRing.lineWidth = 4
        glowRing.glowWidth = 10  // Reduced from 20 for performance
        glowRing.name = "glowRing"
        glowRing.zPosition = -1
        coreContainer.addChild(glowRing)

        // Pulse animation for glow ring (synced to game rhythm)
        let pulseOut = SKAction.scale(to: 1.15, duration: 0.8)
        let pulseIn = SKAction.scale(to: 0.9, duration: 0.8)
        pulseOut.timingMode = .easeInEaseOut
        pulseIn.timingMode = .easeInEaseOut
        let pulse = SKAction.sequence([pulseOut, pulseIn])
        glowRing.run(SKAction.repeatForever(pulse))

        // Secondary inner glow (copper)
        let innerGlow = SKShapeNode(circleOfRadius: cpuSize / 2 + 5)
        innerGlow.fillColor = .clear
        innerGlow.strokeColor = copperColor.withAlphaComponent(0.3)
        innerGlow.lineWidth = 2
        innerGlow.glowWidth = 8
        innerGlow.name = "innerGlow"
        innerGlow.zPosition = -0.5
        coreContainer.addChild(innerGlow)

        backgroundLayer.addChild(coreContainer)
    }

    // MARK: - Update Loop

    override func update(_ currentTime: TimeInterval) {
        guard var state = state, !state.isPaused, !state.isGameOver else { return }

        // Calculate delta time
        let deltaTime = lastUpdateTime == 0 ? 0 : currentTime - lastUpdateTime
        lastUpdateTime = currentTime

        // Check for System Freeze (0% efficiency)
        // When frozen, pause all game updates and notify delegate
        if state.isSystemFrozen {
            // Only update core visual (pulsing red), no game logic
            updateCoreVisual(state: state, currentTime: currentTime)
            return
        }

        // Update game time
        state.gameTime += deltaTime

        // MARK: - Idle TD Continuous Spawning
        // Replace wave-based spawning with continuous idle spawning
        if state.idleSpawnEnabled {
            // Initial delay before spawning starts
            if !hasStartedFirstWave {
                gameStartDelay -= deltaTime
                if gameStartDelay <= 0 {
                    hasStartedFirstWave = true
                }
            }

            if hasStartedFirstWave {
                let unlockedSectorIds = gameStateDelegate?.getUnlockedSectorIds() ?? Set([SectorID.power.rawValue])
                if let enemy = IdleSpawnSystem.update(
                    state: &state,
                    deltaTime: deltaTime,
                    currentTime: currentTime,
                    unlockedSectorIds: unlockedSectorIds
                ) {
                    state.enemies.append(enemy)
                    let spawnPosition = convertToScene(enemy.position)
                    spawnPortalAnimation(at: spawnPosition)

                    // Boss entrance: trigger special effects
                    if enemy.isBoss {
                        let bossColor = UIColor(hex: enemy.color) ?? .red
                        triggerBossEntranceEffect(at: enemy.position, bossColor: bossColor)
                    }

                }
            }
        }

        // Update Overclock system (timer, power allocation)
        OverclockSystem.update(state: &state, deltaTime: deltaTime)

        // Update Boss system (spawning at threat milestones, movement)
        let bossResult = TDBossSystem.update(state: &state, deltaTime: deltaTime)
        if bossResult.bossSpawned {
            // Trigger boss entrance effects
            if let bossId = state.activeBossId,
               let boss = state.enemies.first(where: { $0.id == bossId }) {
                let bossColor = UIColor(hex: boss.color) ?? .orange
                triggerBossEntranceEffect(at: boss.position, bossColor: bossColor)
            }
            gameStateDelegate?.bossSpawned(type: bossResult.spawnedBossType ?? "unknown")
        }
        if bossResult.bossReachedCPU {
            gameStateDelegate?.bossReachedCPU()
        }

        // Update systems
        PathSystem.updateEnemyPositions(state: &state, deltaTime: deltaTime, currentTime: currentTime)
        TowerSystem.updateTargets(state: &state)
        TowerSystem.processTowerAttacks(state: &state, currentTime: currentTime, deltaTime: deltaTime)
        CoreSystem.processCoreAttack(state: &state, currentTime: currentTime)
        updateProjectiles(state: &state, deltaTime: deltaTime, currentTime: currentTime)
        PathSystem.processReachedCore(state: &state)
        processCollisions(state: &state)
        cleanupDeadEntities(state: &state)

        // Check for efficiency drop (enemy leaked) and trigger damage flash
        if state.efficiency < previousEfficiency {
            triggerDamageFlash()
        }
        previousEfficiency = state.efficiency

        // Check if system just froze (efficiency hit 0%)
        if state.isSystemFrozen {
            self.state = state
            gameStateDelegate?.gameStateUpdated(state)
            gameStateDelegate?.systemFrozen()
            return
        }

        // Efficiency System (System: Reboot)
        PathSystem.updateLeakDecay(state: &state, deltaTime: deltaTime)
        PathSystem.updateHashIncome(state: &state, deltaTime: deltaTime)

        // Zero-Day System (System Breach events)
        _ = ZeroDaySystem.update(state: &state, deltaTime: deltaTime)

        // Update camera physics (inertia scrolling)
        cameraController.updatePhysics(deltaTime: deltaTime)

        // Update parallax background
        updateParallaxLayers()

        // Update visuals
        updateTowerVisuals(state: state)
        updateEnemyVisuals(state: state)
        updateProjectileVisuals(state: state)
        updateCoreVisual(state: state, currentTime: currentTime)

        // Update path LEDs for visual feedback (motherboard theme)
        if isMotherboardMap {
            updatePathLEDs(enemies: state.enemies)
        }

        // Update Level of Detail based on zoom
        updateTowerLOD()

        // Update sector visibility and pause/resume ambient effects (motherboard theme)
        if isMotherboardMap {
            updateSectorVisibility(currentTime: currentTime)
        }

        // Render scrolling combat text
        renderDamageEvents(state: &state)

        // Save state and notify delegate
        self.state = state
        gameStateDelegate?.gameStateUpdated(state)
    }

    // MARK: - Wave Spawning

    private func processWaveSpawning(state: inout TDGameState, currentTime: TimeInterval, deltaTime: TimeInterval) {
        guard currentWaveIndex < waves.count else { return }

        let wave = waves[currentWaveIndex]

        // Check spawn timer
        spawnTimer += deltaTime
        if spawnTimer >= wave.delayBetweenSpawns {
            spawnTimer = 0

            // Spawn next enemy with portal animation (pass unlocked sectors for multi-lane spawning)
            let unlockedSectorIds = gameStateDelegate?.getUnlockedSectorIds() ?? Set([SectorID.power.rawValue])
            if let enemy = WaveSystem.spawnNextEnemy(state: &state, wave: wave, currentTime: currentTime, unlockedSectorIds: unlockedSectorIds) {
                state.enemies.append(enemy)
                let spawnPosition = convertToScene(enemy.position)
                spawnPortalAnimation(at: spawnPosition)

                // Boss entrance: trigger special effects
                if enemy.isBoss {
                    let bossColor = UIColor(hex: enemy.color) ?? .red
                    triggerBossEntranceEffect(at: enemy.position, bossColor: bossColor)
                }

            }
        }
    }

    // MARK: - Projectile Updates

    private func updateProjectiles(state: inout TDGameState, deltaTime: TimeInterval, currentTime: TimeInterval) {
        for i in (0..<state.projectiles.count).reversed() {
            var proj = state.projectiles[i]

            // Store previous position for swept collision detection
            projectilePrevPositions[proj.id] = CGPoint(x: proj.x, y: proj.y)

            // Move projectile
            proj.x += proj.velocityX * CGFloat(deltaTime)
            proj.y += proj.velocityY * CGFloat(deltaTime)

            // Homing behavior
            if proj.isHoming, let targetId = proj.targetId,
               let target = state.enemies.first(where: { $0.id == targetId && !$0.isDead }) {
                let dx = target.x - proj.x
                let dy = target.y - proj.y
                let distance = sqrt(dx*dx + dy*dy)
                if distance > 0 {
                    let currentAngle = atan2(proj.velocityY, proj.velocityX)
                    let targetAngle = atan2(dy, dx)
                    var angleDiff = targetAngle - currentAngle
                    while angleDiff > .pi { angleDiff -= 2 * .pi }
                    while angleDiff < -.pi { angleDiff += 2 * .pi }

                    let turnSpeed = proj.homingStrength * CGFloat(deltaTime)
                    let newAngle = currentAngle + max(-turnSpeed, min(turnSpeed, angleDiff))
                    let speed = proj.speed ?? 400
                    proj.velocityX = cos(newAngle) * speed
                    proj.velocityY = sin(newAngle) * speed
                }
            }

            // Update lifetime
            proj.lifetime -= deltaTime

            // Check bounds and lifetime
            if proj.lifetime <= 0 ||
               proj.x < -50 || proj.x > state.map.width + 50 ||
               proj.y < -50 || proj.y > state.map.height + 50 {
                state.projectiles.remove(at: i)
                continue
            }

            state.projectiles[i] = proj
        }
    }

    // MARK: - Collision Processing

    /// Swept collision detection to prevent projectile tunneling through fast-moving objects
    private func processCollisions(state: inout TDGameState) {
        for projIndex in (0..<state.projectiles.count).reversed() {
            var proj = state.projectiles[projIndex]

            // Skip enemy projectiles
            if proj.isEnemyProjectile { continue }

            // Get previous position for swept collision (fallback to current if first frame)
            let prevPos = projectilePrevPositions[proj.id] ?? CGPoint(x: proj.x, y: proj.y)
            let currPos = CGPoint(x: proj.x, y: proj.y)

            for enemyIndex in 0..<state.enemies.count {
                var enemy = state.enemies[enemyIndex]
                if enemy.isDead || enemy.reachedCore { continue }

                // Swept collision: check if projectile path intersects enemy circle
                let hitRadius = proj.radius + (enemy.size / 2)
                let enemyCenter = CGPoint(x: enemy.x, y: enemy.y)

                // Use swept sphere collision (line segment vs circle)
                let collision = lineIntersectsCircle(
                    lineStart: prevPos,
                    lineEnd: currPos,
                    circleCenter: enemyCenter,
                    circleRadius: hitRadius
                )

                if collision && !proj.hitEnemies.contains(enemy.id) {
                    // Apply damage
                    enemy.health -= proj.damage
                    state.stats.damageDealt += proj.damage

                    // Emit scrolling combat text event
                    let damageEvent = DamageEvent(
                        type: .damage,
                        amount: Int(proj.damage),
                        position: CGPoint(x: enemy.x, y: enemy.y),
                        timestamp: state.gameTime
                    )
                    state.damageEvents.append(damageEvent)

                    // Apply slow
                    if let slow = proj.slow, let duration = proj.slowDuration {
                        enemy.applySlow(amount: slow, duration: duration, currentTime: state.gameTime)
                    }

                    // Mark as hit
                    proj.hitEnemies.append(enemy.id)

                    // Spawn impact sparks
                    let impactPos = convertToScene(CGPoint(x: enemy.x, y: enemy.y))
                    spawnImpactSparks(at: impactPos, color: UIColor(hex: proj.color) ?? .yellow)

                    // Splash damage
                    if let splash = proj.splash, splash > 0 {
                        applySplashDamage(state: &state, center: CGPoint(x: enemy.x, y: enemy.y), radius: splash, damage: proj.damage * 0.5, slow: proj.slow, slowDuration: proj.slowDuration)
                    }

                    // Check enemy death
                    if enemy.health <= 0 {
                        enemy.isDead = true
                        let actualGold = state.addHash(enemy.goldValue)
                        state.stats.hashEarned += actualGold
                        state.stats.enemiesKilled += 1
                        state.virusesKilledTotal += 1  // For passive Data generation
                        state.waveEnemiesRemaining -= 1

                        // Spawn death particles and gold floaties
                        let deathPos = convertToScene(CGPoint(x: enemy.x, y: enemy.y))
                        let enemyWorldPos = CGPoint(x: enemy.x, y: enemy.y)
                        let enemyColor = UIColor(hex: enemy.color) ?? .red
                        spawnDeathParticles(at: deathPos, color: enemyColor, isBoss: enemy.isBoss)
                        spawnGoldFloaties(at: deathPos, goldValue: enemy.goldValue)

                        // Boss death: trigger special effects
                        if enemy.isBoss {
                            triggerBossDeathEffect(at: enemyWorldPos, bossColor: enemyColor)
                        }
                    }

                    state.enemies[enemyIndex] = enemy

                    // Handle pierce
                    if proj.piercing > 0 {
                        proj.piercing -= 1
                    } else {
                        state.projectiles.remove(at: projIndex)
                        break
                    }
                }
            }

            if projIndex < state.projectiles.count {
                state.projectiles[projIndex] = proj
            }
        }
    }

    /// Check if a line segment intersects a circle (for swept collision detection)
    /// This catches fast-moving projectiles that would otherwise tunnel through enemies
    private func lineIntersectsCircle(lineStart: CGPoint, lineEnd: CGPoint, circleCenter: CGPoint, circleRadius: CGFloat) -> Bool {
        // Vector from line start to circle center
        let d = CGPoint(x: lineEnd.x - lineStart.x, y: lineEnd.y - lineStart.y)
        let f = CGPoint(x: lineStart.x - circleCenter.x, y: lineStart.y - circleCenter.y)

        let a = d.x * d.x + d.y * d.y
        let b = 2 * (f.x * d.x + f.y * d.y)
        let c = f.x * f.x + f.y * f.y - circleRadius * circleRadius

        var discriminant = b * b - 4 * a * c

        // No intersection at all
        if discriminant < 0 {
            return false
        }

        discriminant = sqrt(discriminant)

        // Check if intersection is within the line segment (t between 0 and 1)
        let t1 = (-b - discriminant) / (2 * a)
        let t2 = (-b + discriminant) / (2 * a)

        // Either intersection point is on the segment, or segment is inside the circle
        if t1 >= 0 && t1 <= 1 {
            return true
        }
        if t2 >= 0 && t2 <= 1 {
            return true
        }

        // Also check if either endpoint is inside the circle (segment fully inside)
        let startDist = sqrt(f.x * f.x + f.y * f.y)
        let endDx = lineEnd.x - circleCenter.x
        let endDy = lineEnd.y - circleCenter.y
        let endDist = sqrt(endDx * endDx + endDy * endDy)

        return startDist <= circleRadius || endDist <= circleRadius
    }

    private func applySplashDamage(state: inout TDGameState, center: CGPoint, radius: CGFloat, damage: CGFloat, slow: CGFloat?, slowDuration: TimeInterval?) {
        for i in 0..<state.enemies.count {
            var enemy = state.enemies[i]
            if enemy.isDead || enemy.reachedCore { continue }

            let dx = enemy.x - center.x
            let dy = enemy.y - center.y
            let distance = sqrt(dx*dx + dy*dy)

            if distance < radius {
                enemy.health -= damage
                state.stats.damageDealt += damage

                // Emit splash damage event
                let splashEvent = DamageEvent(
                    type: .damage,
                    amount: Int(damage),
                    position: CGPoint(x: enemy.x, y: enemy.y),
                    timestamp: state.gameTime
                )
                state.damageEvents.append(splashEvent)

                if let slow = slow, let duration = slowDuration {
                    enemy.applySlow(amount: slow, duration: duration, currentTime: state.gameTime)
                }

                if enemy.health <= 0 {
                    enemy.isDead = true
                    let actualGold = state.addHash(enemy.goldValue)
                    state.stats.hashEarned += actualGold
                    state.stats.enemiesKilled += 1
                    state.virusesKilledTotal += 1  // For passive Data generation
                    state.waveEnemiesRemaining -= 1
                }

                state.enemies[i] = enemy
            }
        }
    }

    // MARK: - Camera Info (for SwiftUI coordinate conversion)

    /// Get current camera position in game coordinates
    var cameraPosition: CGPoint {
        cameraNode?.position ?? CGPoint(x: size.width / 2, y: size.height / 2)
    }

    /// Convert screen touch position to game coordinates, accounting for camera
    /// Uses SpriteKit's built-in conversion which handles aspectFill and camera correctly
    func convertScreenToGame(screenPoint: CGPoint, viewSize: CGSize) -> CGPoint {
        guard let _ = self.view else {
            // Fallback if no view
            return screenPoint
        }

        // Use SpriteKit's built-in conversion - this handles aspectFill scaling and camera
        let scenePoint = convertPoint(fromView: screenPoint)

        // Slot visuals are rendered using convertToScene() which flips Y: visual.y = size.height - state.y
        // Touch gives SpriteKit coordinates (visual position)
        // To match state coordinates: state.y = size.height - visual.y
        let gameY = size.height - scenePoint.y

        return CGPoint(x: scenePoint.x, y: gameY)
    }

    /// Convert game coordinates to screen position, accounting for camera
    func convertGameToScreen(gamePoint: CGPoint, viewSize: CGSize) -> CGPoint {
        guard let _ = self.view else {
            return gamePoint
        }

        // Game state coordinates have Y that needs to be flipped to SpriteKit coordinates
        // (reverse of convertScreenToGame)
        let scenePoint = CGPoint(x: gamePoint.x, y: size.height - gamePoint.y)

        // Use SpriteKit's built-in conversion to get screen coordinates
        let screenPoint = convertPoint(toView: scenePoint)
        return screenPoint
    }

    // MARK: - Helpers

    func convertToScene(_ point: CGPoint) -> CGPoint {
        // Convert from game coordinates (origin top-left) to SpriteKit (origin bottom-left)
        return CGPoint(x: point.x, y: size.height - point.y)
    }

    func updateSlotVisual(slot: TowerSlot) {
        // Update grid dot visibility based on occupation
        // Grid dot is now a container (SKNode) not SKShapeNode
        if let dotNode = gridDotsLayer.childNode(withName: "gridDot_\(slot.id)") {
            if slot.occupied {
                dotNode.alpha = 0
            } else {
                // Always slightly visible (0.3 base), brighter during placement mode
                dotNode.alpha = isInPlacementMode ? 1 : 0.3
            }
        }
    }

    private func hazardColor(for type: String) -> UIColor {
        switch type {
        case "lava": return .orange
        case "asteroid": return .gray
        case "spikes": return .purple
        default: return .red
        }
    }
}

// MARK: - Delegate Protocol

protocol TDGameSceneDelegate: AnyObject {
    func gameStateUpdated(_ state: TDGameState)
    func slotSelected(_ slotId: String)
    func towerSelected(_ towerId: String?)
    func gateSelected(_ sectorId: String)  // Mega-board encryption gate tapped
    func systemFrozen()                     // Efficiency hit 0% - show recovery UI
    func getUnlockedSectorIds() -> Set<String>  // Get currently unlocked TD sectors
    func spawnPointTapped(_ lane: SectorLane)   // Locked spawn point tapped for unlock
    func placementFailed(_ reason: TowerPlacementResult)  // Tower placement failed - show feedback
    func bossSpawned(type: String)          // Super virus boss spawned at threat milestone
    func bossReachedCPU()                   // Boss reached CPU (player ignored it)
    func bossTapped()                        // Player tapped on boss to engage
}

