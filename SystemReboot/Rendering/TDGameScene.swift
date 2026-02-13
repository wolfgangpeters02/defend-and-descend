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

    // Game loop context (frame-to-frame tracking state, extracted in Step 4.5)
    var frameContext = TDGameLoop.FrameContext()

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
    var placementProtocolId: String?

    // Cached nodes for performance
    var towerNodes: [String: SKNode] = [:]
    var enemyNodes: [String: SKNode] = [:]
    var enemyLastHealth: [String: CGFloat] = [:]  // Track health for hit flash
    var projectileNodes: [String: SKNode] = [:]
    // slotNodes removed — hit testing uses distance-based math now
    var gateNodes: [String: SKNode] = [:]  // Mega-board encryption gates

    // Cached tower child node refs (avoids per-frame childNode(withName:) lookups)
    struct TowerNodeRefs {
        weak var barrel: SKNode?
        weak var rangeNode: SKNode?
        weak var cooldownNode: SKShapeNode?
        weak var levelLabel: SKLabelNode?
        weak var glowNode: SKNode?
        weak var lodDetail: SKNode?
    }
    var towerNodeRefs: [String: TowerNodeRefs] = [:]

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

    // Particle effect service (particles, arcs, shake, boss effects — extracted in Step 4.3)
    let particleEffectService = ParticleEffectService()

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

    // Tower attack tracking for firing animations
    var towerLastAttackTimes: [String: TimeInterval] = [:]

    // MARK: - Path LED System (Visual Overhaul)
    // LEDs along lanes that react to enemy proximity
    var pathLEDNodes: [String: [SKShapeNode]] = [:]  // laneId -> LED nodes
    var ledUpdateCounter: Int = 0                      // Update every 3 frames for performance
    var ledIdlePhase: CGFloat = 0                      // For idle heartbeat animation

    // MARK: - Lane Flow Animation (Dashed data-flow overlay)
    var laneFlowNodes: [String: (node: SKShapeNode, path: CGPath, dashLengths: [CGFloat])] = [:]
    var laneFlowPhase: CGFloat = 0  // Animated dash phase offset

    // MARK: - Capacitor System (PSU Power Theme)
    // Capacitors in PSU sector that pulse and "discharge" when towers fire
    var psuCapacitorNodes: [SKNode] = []              // Capacitor containers for animation
    var lastCapacitorDischargeTime: TimeInterval = 0  // Cooldown between discharge effects

    // MARK: - Power Flow Particles (PSU Power Theme)
    var lastPowerFlowSpawnTime: TimeInterval = 0

    // MARK: - Debug Overlay
    var debugFrameTimes: [TimeInterval] = []
    var debugUpdateCounter: Int = 0
    var debugOverlayNode: SKNode?

    // previousEfficiency is now in frameContext (TDGameLoop.FrameContext)

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

    // Cached MegaBoardConfig (avoids recreating every call)
    lazy var cachedMegaBoardConfig: MegaBoardConfig = MegaBoardConfig.createDefault()

    // MARK: - Background Detail LOD (Performance)
    // Hide background decorations and parallax when zoomed out (invisible at that scale anyway)
    var backgroundDetailVisible: Bool = true
    var sectorDetailsVisible: Bool = true

    // MARK: - Glow LOD (Performance)
    // Disable expensive glowWidth (Gaussian blur shader) when zoomed out
    var glowNodes: [(node: SKShapeNode, normalGlowWidth: CGFloat)] = []
    var glowLODEnabled: Bool = true
    var ledsHidden: Bool = false

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

        // Configure particle effect service (delegated in Step 4.3)
        particleEffectService.configure(
            scene: self,
            particleLayer: particleLayer,
            pathLayer: pathLayer,
            cameraNode: cameraController.cameraNode
        )
        particleEffectService.isMotherboardMap = isMotherboardMap
        particleEffectService.getCurrentScale = { [weak self] in
            self?.currentScale ?? 1.0
        }
        particleEffectService.getLastUpdateTime = { [weak self] in
            self?.lastUpdateTime ?? 0
        }
        particleEffectService.getEnemyCount = { [weak self] in
            self?.state?.enemies.count ?? 0
        }
        particleEffectService.getUnlockedSectorIds = { [weak self] in
            self?.gameStateDelegate?.getUnlockedSectorIds() ?? Set([SectorID.power.rawValue])
        }
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

        // Wire layer references early so effects work even if loadState runs before didMove
        particleEffectService.scene = self
        particleEffectService.particleLayer = particleLayer
        particleEffectService.pathLayer = pathLayer
        particleEffectService.isMotherboardMap = (state?.map.theme == "motherboard")
    }

    // MARK: - State Management

    func loadState(_ newState: TDGameState, waves: [TDWave]) {
        self.state = newState
        self.waves = waves

        // Sync wave progress with saved state
        // If waves were completed in a previous session, resume from that point
        if newState.wavesCompleted > 0 && newState.wavesCompleted < waves.count {
            currentWaveIndex = newState.wavesCompleted
            frameContext.hasStartedFirstWave = true
            frameContext.gameStartDelay = 0  // No delay for restored sessions with progress
            // Reset wave-in-progress state to start fresh at next wave
            self.state?.waveInProgress = false
            self.state?.waveEnemiesSpawned = 0
            self.state?.waveEnemiesRemaining = 0
        } else if !newState.towers.isEmpty {
            // Session has towers but no completed waves - player built defenses, start quickly
            currentWaveIndex = 0
            frameContext.hasStartedFirstWave = false
            frameContext.gameStartDelay = 0.5  // Brief delay then start
            // Reset wave state to ensure clean start
            self.state?.waveInProgress = false
            self.state?.waveEnemiesSpawned = 0
            self.state?.waveEnemiesRemaining = 0
        } else {
            // Fresh start - short delay to let player see the board
            currentWaveIndex = 0
            frameContext.hasStartedFirstWave = false
            frameContext.gameStartDelay = 1.0  // Reduced from 2.0
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

        // Sync particle service map flag (state may have changed since setupLayers)
        particleEffectService.isMotherboardMap = isMotherboardMap

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

        for slot in state.towerSlots {
            // Create subtle grid dot (shown only during placement mode)
            let gridDot = createGridDot(slot: slot)
            gridDot.position = convertToScene(slot.position)
            gridDot.name = "gridDot_\(slot.id)"
            gridDotsLayer.addChild(gridDot)

            // PERF: Removed invisible slot hit-area nodes (-80 nodes).
            // Hit testing now uses distance-based math in touchesBegan.
        }
    }

    /// Create tower socket visual (Circuit board aesthetic)
    /// Performance: Single compound path per slot instead of 9 child nodes
    private func createGridDot(slot: TowerSlot) -> SKNode {
        if slot.occupied {
            // Occupied slot: Bright chip indicator
            let chipSize: CGFloat = 20
            let chip = SKShapeNode(rectOf: CGSize(width: chipSize, height: chipSize), cornerRadius: 3)
            chip.fillColor = DesignColors.primaryUI.withAlphaComponent(0.6)
            chip.strokeColor = DesignColors.primaryUI
            chip.lineWidth = 1
            chip.glowWidth = 0
            return chip
        } else {
            // Empty slot: Single compound path with dot, pins, and traces
            let dotRadius: CGFloat = 4
            let pinSize: CGFloat = 3
            let pinOffset: CGFloat = 10
            let compoundPath = CGMutablePath()

            // Center dot
            compoundPath.addEllipse(in: CGRect(x: -dotRadius, y: -dotRadius, width: dotRadius * 2, height: dotRadius * 2))

            // Corner pins
            for (xSign, ySign) in [(1, 1), (1, -1), (-1, 1), (-1, -1)] as [(CGFloat, CGFloat)] {
                let px = pinOffset * xSign - pinSize / 2
                let py = pinOffset * ySign - pinSize / 2
                compoundPath.addRect(CGRect(x: px, y: py, width: pinSize, height: pinSize))
            }

            // Connection traces
            for (xSign, ySign) in [(1, 0), (-1, 0), (0, 1), (0, -1)] as [(CGFloat, CGFloat)] {
                compoundPath.move(to: CGPoint(x: dotRadius * xSign, y: dotRadius * ySign))
                compoundPath.addLine(to: CGPoint(x: 8 * xSign, y: 8 * ySign))
            }

            let slotShape = SKShapeNode(path: compoundPath)
            slotShape.fillColor = UIColor(white: 0.3, alpha: 0.4)
            slotShape.strokeColor = UIColor(white: 0.4, alpha: 0.3)
            slotShape.lineWidth = 1
            return slotShape
        }
    }

    // PERF: createSlotNode removed — invisible hit-area nodes replaced by
    // distance-based math in touchesBegan (-80 nodes).

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
        octagon.glowWidth = 1.5  // Core damage indicator (1 node per game)

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
        cpuBody.glowWidth = 2.0  // Important focal point (1 CPU per game)
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

        // PERF: Heatsink fins batched into single compound path (8→1 node)
        let finCount = 8
        let finLength: CGFloat = 20
        let finWidth: CGFloat = 6
        let finOffset = cpuSize / 2 + finLength / 2 + 2
        let finsPath = CGMutablePath()

        for i in 0..<finCount {
            let angle = CGFloat(i) * .pi / 4
            let cx = cos(angle) * finOffset
            let cy = sin(angle) * finOffset
            let finRect = CGRect(x: -finWidth / 2, y: -finLength / 2, width: finWidth, height: finLength)
            let transform = CGAffineTransform(translationX: cx, y: cy).rotated(by: angle + .pi / 2)
            finsPath.addRoundedRect(in: finRect, cornerWidth: 2, cornerHeight: 2, transform: transform)
        }

        let finsNode = SKShapeNode(path: finsPath)
        finsNode.fillColor = copperColor.withAlphaComponent(0.7)
        finsNode.strokeColor = copperColor
        finsNode.lineWidth = 1
        finsNode.zPosition = -0.5
        coreContainer.addChild(finsNode)

        // PERF: Pin connectors batched into single compound path (24→1 node)
        let pinCount = 6
        let pinLength: CGFloat = 15
        let pinWidth: CGFloat = 4
        let pinSpacing = cpuSize / CGFloat(pinCount + 1)
        let pinsPath = CGMutablePath()

        for side in 0..<4 {
            for i in 1...pinCount {
                let offset = -cpuSize / 2 + pinSpacing * CGFloat(i)
                switch side {
                case 0: // Top
                    pinsPath.addRect(CGRect(x: offset - pinWidth / 2, y: cpuSize / 2, width: pinWidth, height: pinLength))
                case 1: // Bottom
                    pinsPath.addRect(CGRect(x: offset - pinWidth / 2, y: -cpuSize / 2 - pinLength, width: pinWidth, height: pinLength))
                case 2: // Left
                    pinsPath.addRect(CGRect(x: -cpuSize / 2 - pinLength, y: offset - pinWidth / 2, width: pinLength, height: pinWidth))
                case 3: // Right
                    pinsPath.addRect(CGRect(x: cpuSize / 2, y: offset - pinWidth / 2, width: pinLength, height: pinWidth))
                default:
                    break
                }
            }
        }

        let pinsNode = SKShapeNode(path: pinsPath)
        pinsNode.fillColor = copperColor.withAlphaComponent(0.5)
        pinsNode.strokeColor = .clear
        coreContainer.addChild(pinsNode)

        // Glow ring (pulsing gold glow - intensity based on efficiency)
        let glowRing = SKShapeNode(circleOfRadius: cpuSize / 2 + 25)
        glowRing.fillColor = .clear
        glowRing.strokeColor = goldGlowColor.withAlphaComponent(0.4)
        glowRing.lineWidth = 4
        glowRing.glowWidth = 3.0  // Pulsing CPU halo (1 ring per game)
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
        innerGlow.strokeColor = copperColor.withAlphaComponent(0.5)
        innerGlow.lineWidth = 2
        innerGlow.glowWidth = 1.5  // Inner copper glow (1 ring per game)
        innerGlow.name = "innerGlow"
        innerGlow.zPosition = -0.5
        coreContainer.addChild(innerGlow)

        backgroundLayer.addChild(coreContainer)

        // Register CPU glow nodes for zoom-based LOD
        glowNodes.append((cpuBody, 2.0))
        glowNodes.append((glowRing, 3.0))
        glowNodes.append((innerGlow, 1.5))
    }

    // MARK: - Update Loop

    override func update(_ currentTime: TimeInterval) {
        guard var state = state, !state.isPaused, !state.isGameOver else { return }

        // Calculate delta time
        let deltaTime = lastUpdateTime == 0 ? 0 : currentTime - lastUpdateTime
        lastUpdateTime = currentTime

        // Debug overlay (before frozen check so FPS tracks during freeze)
        if AppState.shared.showDebugOverlay {
            syncDebugOverlayVisibility()
            recordDebugFrameTime(deltaTime)
            if shouldUpdateDebugOverlay() {
                updateDebugOverlay()
            }
        } else if debugOverlayNode != nil {
            removeDebugOverlay()
        }

        // When frozen, only update core visual (pulsing red), no game logic
        if state.isSystemFrozen {
            updateCoreVisual(state: state, currentTime: currentTime)
            return
        }

        // MARK: - Game Logic (delegated to TDGameLoop — Step 4.5)
        let unlockedSectorIds = gameStateDelegate?.getUnlockedSectorIds() ?? Set([SectorID.power.rawValue])
        let result = TDGameLoop.update(
            state: &state,
            deltaTime: deltaTime,
            currentTime: currentTime,
            context: &frameContext,
            unlockedSectorIds: unlockedSectorIds
        )

        // MARK: - Process Visual Events from Game Loop

        // Spawn visuals (portal animations + boss entrance effects)
        for spawn in result.spawnVisuals {
            if spawn.needsPortal {
                spawnPortalAnimation(at: convertToScene(spawn.position))
            }
            if spawn.isBoss {
                let bossColor = UIColor(hex: spawn.color) ?? .red
                triggerBossEntranceEffect(at: spawn.position, bossColor: bossColor)
            }
        }

        // Boss delegate callbacks
        if let bossType = result.bossSpawnedType {
            gameStateDelegate?.bossSpawned(type: bossType)
        }
        if result.bossReachedCPU {
            gameStateDelegate?.bossReachedCPU()
        }

        // Collision visuals (impact sparks, death particles, boss death effects)
        for event in result.collisionVisuals {
            let scenePos = convertToScene(event.position)
            switch event.kind {
            case .impact(let color):
                spawnImpactSparks(at: scenePos, color: UIColor(hex: color) ?? .yellow)
            case .kill(let color, let goldValue, let isBoss):
                let enemyColor = UIColor(hex: color) ?? .red
                spawnDeathParticles(at: scenePos, color: enemyColor, isBoss: isBoss)
                spawnGoldFloaties(at: scenePos, goldValue: goldValue)
                if isBoss {
                    triggerBossDeathEffect(at: event.position, bossColor: enemyColor)
                }
            }
        }

        // Efficiency drop feedback
        if result.efficiencyDropped {
            triggerDamageFlash()
        }

        // System freeze — notify delegate and stop
        if result.systemJustFroze {
            self.state = state
            gameStateDelegate?.gameStateUpdated(state)
            gameStateDelegate?.systemFrozen()
            return
        }

        // MARK: - Rendering Updates

        // Camera physics (inertia scrolling)
        cameraController.updatePhysics(deltaTime: deltaTime)

        // Parallax background
        updateParallaxLayers()

        // Entity visuals
        updateTowerVisuals(state: state)
        updateEnemyVisuals(state: state)
        updateProjectileVisuals(state: state)
        updateCoreVisual(state: state, currentTime: currentTime)

        // Motherboard theme: path LEDs
        if isMotherboardMap {
            updatePathLEDs(enemies: state.enemies, currentTime: currentTime)
            // Animate dashed data-flow overlay (every 6 frames, skip when zoomed out)
            if ledUpdateCounter % 6 == 0 && currentScale < 0.8 {
                updateLaneFlowAnimation(deltaTime: deltaTime)
            }
        }

        // Tower Level of Detail based on zoom
        TowerAnimations.currentCameraScale = currentScale
        updateTowerLOD()

        // Sector IC component LOD: hide details when zoomed out
        if isMotherboardMap {
            updateSectorLOD()
        }

        // Background detail LOD: hide decorations and parallax when zoomed out
        updateBackgroundDetailLOD()

        // Glow LOD: disable expensive Gaussian blur shaders when zoomed out
        updateGlowLOD()

        // LED visibility: hide individual LED nodes when zoomed out
        updateLEDVisibility()

        // Motherboard theme: sector visibility
        if isMotherboardMap {
            updateSectorVisibility(currentTime: currentTime)
        }

        // Scrolling combat text
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

