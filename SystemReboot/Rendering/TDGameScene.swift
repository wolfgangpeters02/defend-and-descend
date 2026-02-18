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

    // Cached tower child node refs (avoids per-frame childNode(withName:) lookups)
    struct TowerNodeRefs {
        weak var barrel: SKNode?
        weak var rangeNode: SKNode?
        weak var cooldownNode: SKShapeNode?
        weak var levelLabel: SKLabelNode?
        weak var glowNode: SKNode?
        weak var lodDetail: SKNode?
        weak var starIndicator: SKNode?
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
    var mergeCandidateIds: Set<String> = []  // Tower IDs eligible for merge during drag

    // Particle layer
    var particleLayer: SKNode!

    // Camera controller (zoom, pan, inertia — extracted in Step 4.2)
    let cameraController = CameraController()

    // Particle effect service (particles, arcs, shake, boss effects — extracted in Step 4.3)
    let particleEffectService = ParticleEffectService()

    // Node pool for TD projectiles (reduces alloc/dealloc churn)
    let tdNodePool = NodePool(maxPerType: 150)

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
        view.preferredFramesPerSecond = 30

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

        let cpuTier = state.cpuTier
        let tierColor = CPUTierColors.color(for: cpuTier)
        let tierGlowColor = CPUTierColors.glowColor(for: cpuTier)

        // Create CPU container node
        let coreContainer = SKNode()
        coreContainer.position = convertToScene(state.core.position)
        coreContainer.name = "core"

        // --- IHS (Integrated Heat Spreader) body ---
        let cpuSize = BalanceConfig.Motherboard.cpuSize  // 300pt
        let cpuBody = SKShapeNode(rectOf: CGSize(width: cpuSize, height: cpuSize), cornerRadius: 16)
        cpuBody.fillColor = DesignColors.surfaceUI
        cpuBody.strokeColor = tierColor
        cpuBody.lineWidth = 5
        cpuBody.name = "cpuBody"
        coreContainer.addChild(cpuBody)

        // --- Silicon die (inner detail) ---
        let dieSize = BalanceConfig.Motherboard.cpuDieSize  // 200pt
        let innerChip = SKShapeNode(rectOf: CGSize(width: dieSize, height: dieSize), cornerRadius: 4)
        innerChip.fillColor = UIColor(red: 0.06, green: 0.06, blue: 0.10, alpha: 1.0)
        innerChip.strokeColor = tierColor.withAlphaComponent(0.6)
        innerChip.lineWidth = 2
        innerChip.name = "innerChip"
        coreContainer.addChild(innerChip)

        // --- Tier-responsive core blocks on die surface ---
        // Each tier reveals more processing cores (created once, toggled via isHidden)
        let coreBlockSize: CGFloat = 36
        let coreBlockGap: CGFloat = 8
        let coreBlockPositions: [CGPoint] = [
            // Row 1 (bottom)
            CGPoint(x: -coreBlockSize - coreBlockGap / 2, y: -coreBlockSize * 1.5 - coreBlockGap),
            CGPoint(x: coreBlockGap / 2, y: -coreBlockSize * 1.5 - coreBlockGap),
            // Row 2
            CGPoint(x: -coreBlockSize - coreBlockGap / 2, y: -coreBlockSize / 2),
            CGPoint(x: coreBlockGap / 2, y: -coreBlockSize / 2),
            // Row 3
            CGPoint(x: -coreBlockSize - coreBlockGap / 2, y: coreBlockSize / 2 + coreBlockGap),
            CGPoint(x: coreBlockGap / 2, y: coreBlockSize / 2 + coreBlockGap),
            // Row 4 (top)
            CGPoint(x: -coreBlockSize - coreBlockGap / 2, y: coreBlockSize * 1.5 + coreBlockGap * 2),
            CGPoint(x: coreBlockGap / 2, y: coreBlockSize * 1.5 + coreBlockGap * 2),
        ]

        let coreBlockColor = UIColor(red: 0.10, green: 0.10, blue: 0.16, alpha: 1.0)
        let coresVisible = min(cpuTier * 2, coreBlockPositions.count)
        for (index, pos) in coreBlockPositions.enumerated() {
            let block = SKShapeNode(rectOf: CGSize(width: coreBlockSize, height: coreBlockSize), cornerRadius: 3)
            block.position = pos
            block.fillColor = coreBlockColor
            block.strokeColor = tierColor.withAlphaComponent(0.5)
            block.lineWidth = 1
            block.name = "coreBlock_\(index)"
            block.isHidden = index >= coresVisible
            block.zPosition = 0.1
            coreContainer.addChild(block)
        }

        // --- L2 cache bars (visible at tier 3+) ---
        let cacheBarWidth: CGFloat = dieSize * 0.35
        let cacheBarHeight: CGFloat = 10
        let cacheBarColor = UIColor(red: 0.08, green: 0.08, blue: 0.14, alpha: 1.0)
        let l2Positions: [CGPoint] = [
            CGPoint(x: -dieSize / 2 + cacheBarWidth / 2 + 8, y: 0),
            CGPoint(x: dieSize / 2 - cacheBarWidth / 2 - 8, y: 0),
        ]
        for (index, pos) in l2Positions.enumerated() {
            let bar = SKShapeNode(rectOf: CGSize(width: cacheBarWidth, height: cacheBarHeight), cornerRadius: 2)
            bar.position = pos
            bar.fillColor = cacheBarColor
            bar.strokeColor = tierColor.withAlphaComponent(0.35)
            bar.lineWidth = 0.5
            bar.name = "cacheBar_L2_\(index)"
            bar.isHidden = cpuTier < 3
            bar.zPosition = 0.1
            coreContainer.addChild(bar)
        }

        // --- L3 cache block (visible at tier 4+) ---
        let l3Block = SKShapeNode(rectOf: CGSize(width: dieSize * 0.7, height: 16), cornerRadius: 2)
        l3Block.position = CGPoint(x: 0, y: -dieSize / 2 + 20)
        l3Block.fillColor = cacheBarColor
        l3Block.strokeColor = tierColor.withAlphaComponent(0.3)
        l3Block.lineWidth = 0.5
        l3Block.name = "cacheBar_L3"
        l3Block.isHidden = cpuTier < 4
        l3Block.zPosition = 0.1
        coreContainer.addChild(l3Block)

        // --- CPU label ---
        let cpuLabel = SKLabelNode(text: "CPU")
        cpuLabel.fontName = "Menlo-Bold"
        cpuLabel.fontSize = 32
        cpuLabel.fontColor = tierColor
        cpuLabel.verticalAlignmentMode = .center
        cpuLabel.horizontalAlignmentMode = .center
        cpuLabel.position = CGPoint(x: 0, y: dieSize / 2 + 20)
        cpuLabel.zPosition = 0.2
        coreContainer.addChild(cpuLabel)

        // --- Efficiency percentage ---
        let efficiencyLabel = SKLabelNode(text: "100%")
        efficiencyLabel.fontName = "Menlo-Bold"
        efficiencyLabel.fontSize = 18
        efficiencyLabel.fontColor = DesignColors.successUI
        efficiencyLabel.verticalAlignmentMode = .center
        efficiencyLabel.horizontalAlignmentMode = .center
        efficiencyLabel.position = CGPoint(x: 0, y: dieSize / 2 + 48)
        efficiencyLabel.name = "efficiencyLabel"
        efficiencyLabel.zPosition = 0.2
        coreContainer.addChild(efficiencyLabel)

        // --- Tier label (below CPU) ---
        let tierLabel = SKLabelNode(text: "T\(cpuTier)")
        tierLabel.fontName = "Menlo-Bold"
        tierLabel.fontSize = 14
        tierLabel.fontColor = tierColor.withAlphaComponent(0.6)
        tierLabel.verticalAlignmentMode = .center
        tierLabel.horizontalAlignmentMode = .center
        tierLabel.position = CGPoint(x: 0, y: -dieSize / 2 - 20)
        tierLabel.name = "tierLabel"
        tierLabel.zPosition = 0.2
        coreContainer.addChild(tierLabel)

        // --- PERF: Heatsink fins batched into single compound path ---
        let finCount = BalanceConfig.Motherboard.cpuFinCount  // 16
        let finLength: CGFloat = 30
        let finWidth: CGFloat = 8
        let finOffset = cpuSize / 2 + finLength / 2 + 4
        let finsPath = CGMutablePath()

        for i in 0..<finCount {
            let angle = CGFloat(i) * (.pi * 2 / CGFloat(finCount))
            let cx = cos(angle) * finOffset
            let cy = sin(angle) * finOffset
            let finRect = CGRect(x: -finWidth / 2, y: -finLength / 2, width: finWidth, height: finLength)
            let transform = CGAffineTransform(translationX: cx, y: cy).rotated(by: angle + .pi / 2)
            finsPath.addRoundedRect(in: finRect, cornerWidth: 2, cornerHeight: 2, transform: transform)
        }

        let finsNode = SKShapeNode(path: finsPath)
        finsNode.fillColor = tierColor.withAlphaComponent(0.7)
        finsNode.strokeColor = tierColor
        finsNode.lineWidth = 1
        finsNode.zPosition = -0.5
        coreContainer.addChild(finsNode)

        // --- PERF: Pin connectors batched into single compound path ---
        let pinCount = BalanceConfig.Motherboard.cpuPinsPerSide  // 12
        let pinLength: CGFloat = 18
        let pinWidth: CGFloat = 6
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
        pinsNode.fillColor = tierColor.withAlphaComponent(0.5)
        pinsNode.strokeColor = .clear
        coreContainer.addChild(pinsNode)

        // --- Glow ring (pulsing, tier-colored) ---
        let glowRadius = BalanceConfig.Motherboard.cpuGlowRingRadius  // 200
        let glowRing = SKShapeNode(circleOfRadius: glowRadius)
        glowRing.fillColor = .clear
        glowRing.strokeColor = tierGlowColor.withAlphaComponent(0.35)
        glowRing.lineWidth = 5
        glowRing.name = "glowRing"
        glowRing.zPosition = -1
        coreContainer.addChild(glowRing)

        // Pulse animation for glow ring
        let pulseOut = SKAction.scale(to: 1.12, duration: 1.0)
        let pulseIn = SKAction.scale(to: 0.92, duration: 1.0)
        pulseOut.timingMode = .easeInEaseOut
        pulseIn.timingMode = .easeInEaseOut
        let pulse = SKAction.sequence([pulseOut, pulseIn])
        glowRing.run(SKAction.repeatForever(pulse))

        // --- Inner glow ring (tier-colored) ---
        let innerGlowRadius = cpuSize / 2 + 15
        let innerGlow = SKShapeNode(circleOfRadius: innerGlowRadius)
        innerGlow.fillColor = .clear
        innerGlow.strokeColor = tierColor.withAlphaComponent(0.4)
        innerGlow.lineWidth = 3
        innerGlow.name = "innerGlow"
        innerGlow.zPosition = -0.5
        coreContainer.addChild(innerGlow)

        // CPU sits above lanes (pathLayer z=3) and blockers (z=3.5), below towers (z=4)
        coreContainer.zPosition = 3.8
        backgroundLayer.addChild(coreContainer)

        // Register CPU glow nodes for zoom-based LOD
        glowNodes.append((cpuBody, 2.0))
        glowNodes.append((glowRing, 3.0))
        glowNodes.append((innerGlow, 1.5))
    }

    /// CPU tier color palette — progresses from copper to platinum as tiers increase
    struct CPUTierColors {
        static let copper = UIColor(red: 184/255, green: 115/255, blue: 51/255, alpha: 1.0)           // #b87333 - Tier 1
        static let brighterCopper = UIColor(red: 212/255, green: 149/255, blue: 106/255, alpha: 1.0)  // #d4956a - Tier 2
        static let goldTint = UIColor(red: 212/255, green: 168/255, blue: 75/255, alpha: 1.0)         // #d4a84b - Tier 3
        static let warmGold = UIColor(red: 255/255, green: 215/255, blue: 0/255, alpha: 1.0)          // #ffd700 - Tier 4
        static let platinum = UIColor(red: 255/255, green: 232/255, blue: 138/255, alpha: 1.0)        // #ffe88a - Tier 5

        static func color(for tier: Int) -> UIColor {
            switch tier {
            case 1: return copper
            case 2: return brighterCopper
            case 3: return goldTint
            case 4: return warmGold
            case 5: return platinum
            default: return copper
            }
        }

        static func glowColor(for tier: Int) -> UIColor {
            switch tier {
            case 1: return copper
            case 2: return brighterCopper
            case 3: return UIColor(red: 230/255, green: 190/255, blue: 100/255, alpha: 1.0)
            case 4: return UIColor(red: 255/255, green: 230/255, blue: 80/255, alpha: 1.0)
            case 5: return UIColor(red: 255/255, green: 240/255, blue: 180/255, alpha: 1.0)
            default: return copper
            }
        }
    }

    // MARK: - Update Loop

    override func update(_ currentTime: TimeInterval) {
        guard var state = state, !state.isPaused, !state.isGameOver else { return }

        // Calculate delta time (capped to prevent jumps after scene.isPaused resumes)
        let rawDelta = lastUpdateTime == 0 ? 0 : currentTime - lastUpdateTime
        let deltaTime = min(rawDelta, 1.0 / 15.0)
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
            case .kill(let color, let hashValue, let isBoss):
                let enemyColor = UIColor(hex: color) ?? .red
                spawnDeathParticles(at: scenePos, color: enemyColor, isBoss: isBoss)
                spawnHashFloaties(at: scenePos, hashValue: hashValue)
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

        // Sync audio viewport (convert scene coords → game coords for spatial sound filtering)
        let sceneRect = calculateVisibleRect()
        AudioManager.shared.visibleRect = CGRect(
            x: sceneRect.origin.x,
            y: size.height - sceneRect.maxY,
            width: sceneRect.width,
            height: sceneRect.height
        )

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

