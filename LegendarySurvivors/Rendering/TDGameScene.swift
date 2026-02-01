import SpriteKit
import SwiftUI

// MARK: - TD Game Scene
// SpriteKit scene for Tower Defense rendering

class TDGameScene: SKScene {

    // MARK: - Properties

    weak var gameStateDelegate: TDGameSceneDelegate?

    var state: TDGameState?  // Internal access for boss fight state sync
    private var lastUpdateTime: TimeInterval = 0
    private var spawnTimer: TimeInterval = 0
    private var currentWaveIndex: Int = 0
    private var waves: [TDWave] = []
    private var gameStartDelay: TimeInterval = 2.0  // Initial delay before wave 1
    private var hasStartedFirstWave: Bool = false

    // Logging state (to avoid spam)
    private var lastLoggedEnemyCount: Int = -1
    private var lastLoggedWaveNumber: Int = -1

    // Node layers
    private var backgroundLayer: SKNode!
    private var pathLayer: SKNode!
    private var towerSlotLayer: SKNode!           // Hidden by default, shown only during drag
    private var gridDotsLayer: SKNode!            // Subtle grid dots for placement mode
    private var blockerLayer: SKNode!             // Blocker nodes and slots layer
    private var activeSlotHighlight: SKNode? // Highlights nearest valid slot during drag
    private var towerLayer: SKNode!
    private var enemyLayer: SKNode!
    private var projectileLayer: SKNode!
    private var uiLayer: SKNode!

    // Placement state (for progressive disclosure)
    private var isInPlacementMode: Bool = false
    private var placementWeaponType: String?

    // Cached nodes for performance
    private var towerNodes: [String: SKNode] = [:]
    private var enemyNodes: [String: SKNode] = [:]
    private var projectileNodes: [String: SKNode] = [:]
    private var slotNodes: [String: SKNode] = [:]
    private var gateNodes: [String: SKNode] = [:]  // Mega-board encryption gates

    // Animation LOD: Track which towers have paused animations for off-screen culling
    private var pausedTowerAnimations: Set<String> = []

    // Mega-board renderer
    private var megaBoardRenderer: MegaBoardRenderer?

    // Selection
    private var selectedSlotId: String?
    private var selectedTowerId: String?

    // Drag state for merging and moving
    private var isDragging = false
    private var draggedTowerId: String?
    private var dragStartPosition: CGPoint?
    private var dragNode: SKNode?
    private var longPressTimer: Timer?
    private var validMoveSlots: Set<String> = []  // Empty slots for tower repositioning

    // Particle layer
    private var particleLayer: SKNode!

    // Camera for zoom/pan
    private var cameraNode: SKCameraNode!
    private var currentScale: CGFloat = 1.0
    private let minScale: CGFloat = 0.15  // Zoom IN limit - closer for detail inspection
    private let maxScale: CGFloat = 1.8   // Zoom OUT limit (see more map but not too much black)

    /// Expose camera scale for coordinate conversion from SwiftUI layer
    var cameraScale: CGFloat {
        return currentScale
    }

    // Inertia camera physics
    private var cameraVelocity: CGPoint = .zero
    private let cameraFriction: CGFloat = 0.92
    private let cameraBoundsElasticity: CGFloat = 0.3
    private var lastPanVelocity: CGPoint = .zero

    // Parallax background
    private var parallaxLayers: [(node: SKNode, speedFactor: CGFloat)] = []
    private var lastCameraPosition: CGPoint = .zero

    // Projectile trails
    private var projectileTrails: [String: [CGPoint]] = [:]
    private let maxTrailLength: Int = 8

    // Projectile previous positions for swept collision detection
    private var projectilePrevPositions: [String: CGPoint] = [:]

    // Tower attack tracking for firing animations
    private var towerLastAttackTimes: [String: TimeInterval] = [:]

    // MARK: - Path LED System (Visual Overhaul)
    // LEDs along lanes that react to enemy proximity
    private var pathLEDNodes: [String: [SKShapeNode]] = [:]  // laneId -> LED nodes
    private var ledUpdateCounter: Int = 0                      // Update every 3 frames for performance
    private var ledIdlePhase: CGFloat = 0                      // For idle heartbeat animation

    // MARK: - Capacitor System (PSU Power Theme)
    // Capacitors in PSU sector that pulse and "discharge" when towers fire
    private var psuCapacitorNodes: [SKNode] = []              // Capacitor containers for animation
    private var lastCapacitorDischargeTime: TimeInterval = 0  // Cooldown between discharge effects

    // MARK: - Power Flow Particles (PSU Power Theme)
    // Constant subtle particles flowing from PSU toward CPU along traces
    private var powerFlowEmitterRunning: Bool = false
    private var lastPowerFlowSpawnTime: TimeInterval = 0

    // MARK: - Screen Shake System (Context-Aware)
    // Only shakes when zoomed in, with cooldown to prevent shake fatigue
    private var lastShakeTime: TimeInterval = 0
    private var screenShakeCooldown: TimeInterval = 0.5  // Max 1 shake per 0.5 seconds
    private var originalCameraPosition: CGPoint = .zero
    private var isShaking: Bool = false

    // MARK: - Efficiency Tracking (for damage flash)
    private var previousEfficiency: CGFloat = 100

    // MARK: - Smooth Barrel Rotation
    // Interpolated barrel rotation for polished aiming feel
    private var towerBarrelRotations: [String: CGFloat] = [:]  // towerId -> current barrel rotation
    private let barrelRotationSpeed: CGFloat = 8.0  // radians per second

    // Motherboard City rendering
    private var isMotherboardMap: Bool {
        state?.map.theme == "motherboard"
    }

    // MARK: - Ambient Particle Management (Performance)
    // Caps on ambient particles to prevent unbounded growth
    private var ambientParticleCount: Int = 0
    private let maxAmbientParticles: Int = 30  // Cap total ambient particles
    private var visibleSectorIds: Set<String> = []  // For culling off-screen effects
    private var lastVisibilityUpdate: TimeInterval = 0
    private let visibilityUpdateInterval: TimeInterval = 0.5  // Update visible sectors every 0.5s

    // MARK: - Setup

    override func didMove(to view: SKView) {
        backgroundColor = .black

        // CRITICAL: Set anchor point to bottom-left (0,0) for correct positioning
        // Without this, default (0.5, 0.5) makes (0,0) the center, causing entities
        // to render in wrong positions
        self.anchorPoint = CGPoint(x: 0, y: 0)

        print("[TDGameScene] didMove - view: \(view.bounds.size), scene size: \(size), anchorPoint: \(anchorPoint)")

        // Only setup layers if not already done (loadState may have been called first)
        if backgroundLayer == nil {
            setupLayers()
        }

        // Setup camera for zoom/pan
        setupCamera()
        setupGestureRecognizers(view: view)
    }

    private func setupCamera() {
        cameraNode = SKCameraNode()

        // Center camera on the starter sector for motherboard, or scene center for others
        if isMotherboardMap {
            // Motherboard: Center on starter sector (RAM at center of 3x3 grid)
            if let starterSector = MegaBoardSystem.shared.starterSector {
                cameraNode.position = starterSector.center
            } else {
                // Fallback: center of grid (1400 * 1.5 = 2100)
                cameraNode.position = CGPoint(x: 2100, y: 2100)
            }
        } else {
            cameraNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
        }
        addChild(cameraNode)
        camera = cameraNode

        // Start zoomed out to give overview, then animate to comfortable level
        if isMotherboardMap {
            // Motherboard: start zoomed out, animate to comfortable view
            currentScale = 2.0  // Start at max zoom out
            cameraNode.setScale(currentScale)

            // Animate zoom-in to comfortable level
            let wait = SKAction.wait(forDuration: 0.8)
            let zoomIn = SKAction.scale(to: 1.0, duration: 1.0)
            zoomIn.timingMode = .easeInEaseOut
            let updateScale = SKAction.run { [weak self] in
                self?.currentScale = 1.0
            }
            cameraNode.run(SKAction.sequence([wait, zoomIn, updateScale]))
        } else {
            currentScale = 1.5  // Start slightly zoomed out
            cameraNode.setScale(currentScale)

            // Animate zoom-in
            let wait = SKAction.wait(forDuration: 1.0)
            let zoomIn = SKAction.scale(to: 0.8, duration: 0.6)
            zoomIn.timingMode = .easeInEaseOut
            let updateScale = SKAction.run { [weak self] in
                self?.currentScale = 0.8
            }
            cameraNode.run(SKAction.sequence([wait, zoomIn, updateScale]))
        }
    }

    private func setupGestureRecognizers(view: SKView) {
        // Pinch to zoom
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        pinchGesture.cancelsTouchesInView = false  // Allow touches to pass through
        view.addGestureRecognizer(pinchGesture)

        // Pan to move camera (one finger for easy navigation)
        // Tower placement is handled via drag from weapon deck in SwiftUI layer
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        panGesture.minimumNumberOfTouches = 1
        panGesture.maximumNumberOfTouches = 2
        panGesture.cancelsTouchesInView = false  // Allow SwiftUI gestures to also work
        view.addGestureRecognizer(panGesture)
    }

    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        guard let cameraNode = cameraNode, let view = gesture.view else { return }

        if gesture.state == .changed {
            // Get pinch center in view coordinates
            let pinchCenter = gesture.location(in: view)

            // Convert to scene coordinates BEFORE zoom
            let scenePointBefore = convertPoint(fromView: pinchCenter)

            // Calculate new scale (invert: pinch out = smaller scale = zoom in)
            let newScale = currentScale / gesture.scale
            let clampedScale = max(minScale, min(maxScale, newScale))

            // Apply new scale
            cameraNode.setScale(clampedScale)
            currentScale = clampedScale

            // Convert same view point to scene coordinates AFTER zoom
            let scenePointAfter = convertPoint(fromView: pinchCenter)

            // Adjust camera position so pinch point stays fixed (Google Maps style)
            let deltaX = scenePointAfter.x - scenePointBefore.x
            let deltaY = scenePointAfter.y - scenePointBefore.y
            cameraNode.position.x -= deltaX
            cameraNode.position.y -= deltaY

            gesture.scale = 1.0
        } else if gesture.state == .ended {
            currentScale = cameraNode.xScale
        }
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let cameraNode = cameraNode, let view = gesture.view else { return }

        // CRITICAL: Suppress camera panning when in tower placement mode OR dragging tower
        // This prevents the "wishy-washy" UX where map moves while placing/moving towers
        if isInPlacementMode || isDragging {
            gesture.setTranslation(.zero, in: view)
            return
        }

        switch gesture.state {
        case .began:
            // Stop any existing inertia
            cameraVelocity = .zero

        case .changed:
            let translation = gesture.translation(in: view)

            // Pan speed multiplier - faster for large maps
            let panSpeedMultiplier: CGFloat = isMotherboardMap ? 2.5 : 1.0

            // Move camera (inverted for natural scrolling)
            let newX = cameraNode.position.x - translation.x * currentScale * panSpeedMultiplier
            let newY = cameraNode.position.y + translation.y * currentScale * panSpeedMultiplier

            // Get camera bounds
            let bounds = calculateCameraBounds()

            // Soft bounds - allow slight overscroll with resistance
            let overscrollResistance: CGFloat = 0.3
            var finalX = newX
            var finalY = newY

            if newX < bounds.minX {
                finalX = bounds.minX + (newX - bounds.minX) * overscrollResistance
            } else if newX > bounds.maxX {
                finalX = bounds.maxX + (newX - bounds.maxX) * overscrollResistance
            }

            if newY < bounds.minY {
                finalY = bounds.minY + (newY - bounds.minY) * overscrollResistance
            } else if newY > bounds.maxY {
                finalY = bounds.maxY + (newY - bounds.maxY) * overscrollResistance
            }

            cameraNode.position = CGPoint(x: finalX, y: finalY)

            // Capture velocity for inertia
            let velocity = gesture.velocity(in: view)
            lastPanVelocity = CGPoint(x: -velocity.x * currentScale * panSpeedMultiplier, y: velocity.y * currentScale * panSpeedMultiplier)

            gesture.setTranslation(.zero, in: view)

        case .ended, .cancelled:
            // Transfer velocity for inertia scrolling
            cameraVelocity = lastPanVelocity
            lastPanVelocity = .zero

        default:
            break
        }
    }

    /// Calculate camera bounds based on map size
    /// Now allows panning to see full map edges (Google Maps style)
    private func calculateCameraBounds() -> (minX: CGFloat, maxX: CGFloat, minY: CGFloat, maxY: CGFloat) {
        guard let view = self.view else {
            // Fallback for motherboard: center of map
            if isMotherboardMap {
                return (2100, 2100, 2100, 2100)
            }
            return (size.width / 2, size.width / 2, size.height / 2, size.height / 2)
        }

        // Calculate visible area in game units
        let visibleWidth = view.bounds.width * currentScale
        let visibleHeight = view.bounds.height * currentScale
        let halfWidth = visibleWidth / 2
        let halfHeight = visibleHeight / 2

        if isMotherboardMap {
            // Full motherboard is 4200x4200 (3x3 sectors of 1400 each)
            let mapWidth: CGFloat = 4200
            let mapHeight: CGFloat = 4200

            // Allow camera to reach edges - camera can go from halfWidth to mapWidth-halfWidth
            let minX = halfWidth
            let maxX = mapWidth - halfWidth
            let minY = halfHeight
            let maxY = mapHeight - halfHeight

            // If zoomed out so much that visible area > map, center it
            return (
                minX: min(minX, mapWidth / 2),
                maxX: max(maxX, mapWidth / 2),
                minY: min(minY, mapHeight / 2),
                maxY: max(maxY, mapHeight / 2)
            )
        }

        // Standard maps: allow panning to edges
        let minX = halfWidth
        let maxX = size.width - halfWidth
        let minY = halfHeight
        let maxY = size.height - halfHeight

        return (
            minX: min(minX, size.width / 2),
            maxX: max(maxX, size.width / 2),
            minY: min(minY, size.height / 2),
            maxY: max(maxY, size.height / 2)
        )
    }

    /// Update camera physics for inertia scrolling
    private func updateCameraPhysics(deltaTime: TimeInterval) {
        guard let cameraNode = cameraNode else { return }

        // Skip if velocity is negligible
        let speed = sqrt(cameraVelocity.x * cameraVelocity.x + cameraVelocity.y * cameraVelocity.y)
        guard speed > 0.1 else {
            cameraVelocity = .zero
            return
        }

        // Apply velocity to camera position
        let dt = CGFloat(deltaTime)
        var newX = cameraNode.position.x + cameraVelocity.x * dt
        var newY = cameraNode.position.y + cameraVelocity.y * dt

        // Get camera bounds
        let bounds = calculateCameraBounds()

        // Elastic bounce at bounds
        if newX < bounds.minX {
            newX = bounds.minX
            cameraVelocity.x = -cameraVelocity.x * cameraBoundsElasticity
        } else if newX > bounds.maxX {
            newX = bounds.maxX
            cameraVelocity.x = -cameraVelocity.x * cameraBoundsElasticity
        }

        if newY < bounds.minY {
            newY = bounds.minY
            cameraVelocity.y = -cameraVelocity.y * cameraBoundsElasticity
        } else if newY > bounds.maxY {
            newY = bounds.maxY
            cameraVelocity.y = -cameraVelocity.y * cameraBoundsElasticity
        }

        cameraNode.position = CGPoint(x: newX, y: newY)

        // Apply friction
        cameraVelocity.x *= cameraFriction
        cameraVelocity.y *= cameraFriction
    }

    /// Reset camera to default view
    func resetCamera() {
        guard let cameraNode = cameraNode else { return }
        let action = SKAction.group([
            SKAction.move(to: CGPoint(x: size.width / 2, y: size.height / 2), duration: 0.3),
            SKAction.scale(to: 1.0, duration: 0.3)
        ])
        action.timingMode = .easeInEaseOut
        cameraNode.run(action)
        currentScale = 1.0
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
            print("[TDGameScene] loadState - Restored wave progress: starting at wave \(currentWaveIndex)")
        } else if !newState.towers.isEmpty {
            // Session has towers but no completed waves - player built defenses, start quickly
            currentWaveIndex = 0
            hasStartedFirstWave = false
            gameStartDelay = 0.5  // Brief delay then start
            // Reset wave state to ensure clean start
            self.state?.waveInProgress = false
            self.state?.waveEnemiesSpawned = 0
            self.state?.waveEnemiesRemaining = 0
            print("[TDGameScene] loadState - Restored session with \(newState.towers.count) towers, starting soon")
        } else {
            // Fresh start - short delay to let player see the board
            currentWaveIndex = 0
            hasStartedFirstWave = false
            gameStartDelay = 1.0  // Reduced from 2.0
        }

        print("[TDGameScene] loadState - map: \(newState.map.width)x\(newState.map.height)")
        print("[TDGameScene] loadState - paths: \(newState.paths.count), spawnPoints: \(newState.map.spawnPoints)")
        print("[TDGameScene] loadState - waves: \(waves.count), towerSlots: \(newState.towerSlots.count)")

        // Initialize mega-board system for motherboard maps
        if newState.map.theme == "motherboard" {
            MegaBoardSystem.shared.loadDefaultConfig()
            MegaBoardSystem.shared.updateUnlockCache(from: AppState.shared.currentPlayer)
            print("[TDGameScene] Mega-board system initialized")
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

    /// Setup mega-board ghost sectors and encryption gates
    private func setupMegaBoardVisuals() {
        guard isMotherboardMap else { return }

        // Clear existing gate nodes
        gateNodes.removeAll()

        let profile = AppState.shared.currentPlayer

        // Create and store renderer
        megaBoardRenderer = MegaBoardRenderer(scene: self)
        guard let renderer = megaBoardRenderer else { return }

        // Render ghost sectors (locked but adjacent to unlocked)
        let ghostSectors = MegaBoardSystem.shared.visibleLockedSectors(for: profile)
        for sector in ghostSectors {
            renderer.renderGhostSector(sector, in: backgroundLayer)
        }

        // Render encryption gates and store references for hit testing
        let gates = MegaBoardSystem.shared.visibleGates(for: profile)
        for gate in gates {
            if let sector = MegaBoardSystem.shared.sector(id: gate.sectorId) {
                renderer.renderEncryptionGate(gate, sector: sector, in: uiLayer)

                // Store gate node for hit testing (find by name)
                if let gateNode = uiLayer.childNode(withName: "gate_\(gate.id)") {
                    gateNodes[gate.sectorId] = gateNode
                }
            }
        }

        // Render data bus connections
        let connections = MegaBoardSystem.shared.connections
        for connection in connections {
            let isActive = connection.isActive(unlockedSectorIds: Set(profile.unlockedTDSectors))
            renderer.renderDataBus(connection, isActive: isActive, in: pathLayer)
        }

        print("[TDGameScene] Mega-board visuals: \(ghostSectors.count) ghost sectors, \(gates.count) gates")
    }

    /// Refresh mega-board visuals after a sector is unlocked
    func refreshMegaBoardVisuals() {
        guard isMotherboardMap else { return }

        // Update state.paths with newly unlocked lanes
        let unlockedSectorIds = gameStateDelegate?.getUnlockedSectorIds() ?? Set([SectorID.power.rawValue])
        let activeLanes = MotherboardLaneConfig.getUnlockedLanes(unlockedSectorIds: unlockedSectorIds)
        let activePaths = activeLanes.map { lane -> EnemyPath in
            var path = lane.path
            path.sectorId = lane.sectorId
            return path
        }
        state?.paths = activePaths
        state?.basePaths = activePaths

        // Also update spawn points in map
        state?.map.spawnPoints = activeLanes.map { $0.spawnPoint }

        // Clear existing visuals
        megaBoardRenderer?.removeAllGhostSectors()
        megaBoardRenderer?.removeAllEncryptionGates()
        megaBoardRenderer?.removeAllDataBuses()
        gateNodes.removeAll()

        // Rebuild lane visuals (copper traces)
        pathLayer.removeAllChildren()
        setupMotherboardPaths()

        // Rebuild
        setupMegaBoardVisuals()

        print("[TDGameScene] Refreshed mega-board: \(activeLanes.count) active lanes/paths")
    }

    private func setupBackground() {
        guard let state = state else { return }

        // Clear existing
        backgroundLayer.removeAllChildren()

        // Use different rendering based on map theme
        if isMotherboardMap {
            setupMotherboardBackground()
        } else {
            setupStandardBackground()
        }
    }

    /// Standard background rendering for non-motherboard maps
    private func setupStandardBackground() {
        guard let state = state else { return }

        // Background color - deep terminal black
        let bg = SKSpriteNode(color: DesignColors.backgroundUI, size: size)
        bg.position = CGPoint(x: size.width/2, y: size.height/2)
        backgroundLayer.addChild(bg)

        // Add circuit board grid pattern
        let gridNode = SpriteKitDesign.createCircuitGridNode(size: size, gridSpacing: 40)
        gridNode.zPosition = 0.5
        backgroundLayer.addChild(gridNode)

        // Draw obstacles with circuit board style (darker surface)
        for obstacle in state.map.obstacles {
            let node = SKSpriteNode(
                color: DesignColors.surfaceUI,
                size: CGSize(width: obstacle.width, height: obstacle.height)
            )
            node.position = CGPoint(x: obstacle.x + obstacle.width/2, y: size.height - obstacle.y - obstacle.height/2)
            backgroundLayer.addChild(node)
        }

        // Draw hazards with danger color
        for hazard in state.map.hazards {
            let node = SKSpriteNode(
                color: DesignColors.dangerUI.withAlphaComponent(0.4),
                size: CGSize(width: hazard.width, height: hazard.height)
            )
            node.position = CGPoint(x: hazard.x + hazard.width/2, y: size.height - hazard.y - hazard.height/2)
            backgroundLayer.addChild(node)
        }

        // Setup parallax layers
        setupParallaxBackground()
    }

    // MARK: - Motherboard PCB Rendering

    /// PCB substrate background for motherboard map
    private func setupMotherboardBackground() {
        // PCB Colors
        let substrateColor = UIColor(hex: MotherboardColors.substrate) ?? UIColor(red: 0.1, green: 0.1, blue: 0.18, alpha: 1.0)

        // 1. PCB Substrate (dark blue-black base)
        let substrate = SKSpriteNode(color: substrateColor, size: size)
        substrate.position = CGPoint(x: size.width/2, y: size.height/2)
        substrate.zPosition = -5
        backgroundLayer.addChild(substrate)

        // 2. Ground plane hatch pattern (diagonal lines)
        let hatchNode = createGroundPlaneHatch()
        hatchNode.zPosition = -4.5
        backgroundLayer.addChild(hatchNode)

        // 3. PCB Grid pattern (subtle copper grid)
        let gridNode = createPCBGridNode()
        gridNode.zPosition = -4
        backgroundLayer.addChild(gridNode)

        // 4. Draw sector decorations (ICs, vias, traces, labels)
        drawSectorDecorations()

        // 5. Start sector ambient effects (makes districts feel alive)
        startSectorAmbientEffects()

        // 6. Draw silkscreen labels
        drawSilkscreenLabels()

        // Note: CPU core is drawn by setupCore() in loadState() - no duplicate needed
    }

    /// Create subtle PCB grid pattern - OPTIMIZED: single path instead of 84 separate nodes
    private func createPCBGridNode() -> SKNode {
        let gridNode = SKShapeNode()
        let gridSpacing: CGFloat = 100  // 100pt grid cells
        let lineColor = UIColor(hex: MotherboardColors.ghostMode)?.withAlphaComponent(0.3) ?? UIColor.darkGray.withAlphaComponent(0.3)

        // Combine ALL lines into a single CGPath for 1 draw call instead of 84
        let path = CGMutablePath()

        // Vertical lines
        for x in stride(from: 0, through: size.width, by: gridSpacing) {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
        }

        // Horizontal lines
        for y in stride(from: 0, through: size.height, by: gridSpacing) {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
        }

        gridNode.path = path
        gridNode.strokeColor = lineColor
        gridNode.lineWidth = 1

        return gridNode
    }

    /// Create diagonal ground plane hatch pattern - OPTIMIZED: single path instead of ~141 nodes
    private func createGroundPlaneHatch() -> SKNode {
        let hatchNode = SKShapeNode()
        let hatchSpacing: CGFloat = 80  // Increased spacing (was 40) - subtle pattern doesn't need density
        let hatchColor = UIColor(hex: "#1a2a3a")?.withAlphaComponent(0.08) ?? UIColor.gray.withAlphaComponent(0.08)

        // Combine ALL diagonal lines into a single CGPath
        let path = CGMutablePath()
        let diagonalLength = sqrt(size.width * size.width + size.height * size.height)
        let lineCount = Int(diagonalLength / hatchSpacing)

        for i in -lineCount..<lineCount {
            let offset = CGFloat(i) * hatchSpacing
            path.move(to: CGPoint(x: offset, y: 0))
            path.addLine(to: CGPoint(x: offset + size.height, y: size.height))
        }

        hatchNode.path = path
        hatchNode.strokeColor = hatchColor
        hatchNode.lineWidth = 1

        return hatchNode
    }

    /// Draw decorative elements for each sector (ICs, vias, traces)
    private func drawSectorDecorations() {
        let megaConfig = MegaBoardConfig.createDefault()
        let ghostColor = UIColor(hex: MotherboardColors.ghostMode)?.withAlphaComponent(0.15) ?? UIColor.gray.withAlphaComponent(0.15)

        for sector in megaConfig.sectors {
            // Skip CPU sector - it has its own special rendering
            guard sector.id != SectorID.cpu.rawValue else { continue }

            let sectorNode = SKNode()
            let sectorCenter = CGPoint(
                x: sector.worldX + sector.width / 2,
                y: sector.worldY + sector.height / 2
            )

            let themeColor = UIColor(hex: sector.theme.primaryColorHex) ?? ghostColor

            // === FOUNDATION LAYER (Phase 1: City Streets) ===

            // 1. Secondary street grid (cosmetic PCB traces forming city blocks)
            drawSecondaryStreetGrid(to: sectorNode, in: sector, themeColor: themeColor)

            // 2. Via roundabouts at trace intersections
            addViaRoundabouts(to: sectorNode, in: sector, themeColor: themeColor)

            // 3. Silkscreen labels (faint component markings)
            addSilkscreenLabels(to: sectorNode, in: sector, themeColor: themeColor)

            // === COMPONENT LAYER (District-specific) ===

            // Add vias (small filled circles) - legacy scattered vias
            addSectorVias(to: sectorNode, in: sector, color: ghostColor)

            // Add IC footprints based on sector type
            addSectorICs(to: sectorNode, in: sector)

            // Add trace bundles to edges
            addSectorTraces(to: sectorNode, in: sector, color: ghostColor)

            // Sector name label (silkscreen style)
            let nameLabel = SKLabelNode(text: sector.displayName.uppercased())
            nameLabel.fontName = "Menlo"
            nameLabel.fontSize = 18
            nameLabel.fontColor = UIColor(hex: sector.theme.primaryColorHex)?.withAlphaComponent(0.4) ?? ghostColor
            nameLabel.position = CGPoint(x: sectorCenter.x, y: sector.worldY + sector.height - 40)
            nameLabel.horizontalAlignmentMode = .center
            nameLabel.zPosition = -2
            sectorNode.addChild(nameLabel)

            sectorNode.zPosition = -3
            backgroundLayer.addChild(sectorNode)
        }
    }

    // MARK: - Sector Ambient Effects System

    /// Start ambient effects for each sector to make districts feel alive
    private func startSectorAmbientEffects() {
        let megaConfig = MegaBoardConfig.createDefault()

        for sector in megaConfig.sectors {
            // Skip CPU sector
            guard sector.id != SectorID.cpu.rawValue else { continue }

            switch sector.theme {
            case .power:
                startPSUSectorAmbient(sector: sector)
            case .graphics:
                startGPUSectorAmbient(sector: sector)
            case .memory:
                startRAMSectorAmbient(sector: sector)
            case .storage:
                startStorageSectorAmbient(sector: sector)
            case .network:
                startNetworkSectorAmbient(sector: sector)
            case .io:
                startIOSectorAmbient(sector: sector)
            case .processing:
                startCacheSectorAmbient(sector: sector)
            }
        }
    }

    // MARK: - PSU Sector Ambient (Power Theme)

    /// PSU sector: Minimal ambient effects - most visuals are static PSU components
    /// Power rails and capacitor sparks have been removed for cleaner aesthetic
    private func startPSUSectorAmbient(sector: MegaBoardSector) {
        // PSU sector ambient effects are intentionally minimal
        // The "city" aesthetic comes from static PSU component decorations
        // Only very subtle voltage arcs remain (handled by startVoltageArcSystem)
    }

    // MARK: - GPU Sector Ambient (Heat Theme) - OPTIMIZED: No glow, slower spawn

    /// GPU sector: Simplified heat shimmer (no expensive glow effects)
    private func startGPUSectorAmbient(sector: MegaBoardSector) {
        let themeColor = UIColor(hex: sector.theme.primaryColorHex) ?? .red
        let center = CGPoint(x: sector.worldX + sector.width / 2, y: sector.worldY + sector.height / 2)

        // REMOVED: Thermal glow circle (expensive blur shader)
        // Heat shimmer emitter - slower spawn rate (was 0.15, now 0.4)
        let spawnShimmer = SKAction.run { [weak self] in
            self?.spawnHeatShimmer(at: center, color: themeColor)
        }

        let shimmerSequence = SKAction.repeatForever(SKAction.sequence([
            spawnShimmer,
            SKAction.wait(forDuration: 0.4)  // Slower spawn rate
        ]))

        backgroundLayer.run(shimmerSequence, withKey: "gpuHeat_\(sector.id)")
    }

    /// Spawn a heat shimmer particle - OPTIMIZED: no glow, simpler animation
    private func spawnHeatShimmer(at center: CGPoint, color: UIColor) {
        guard ambientParticleCount < maxAmbientParticles else { return }
        ambientParticleCount += 1

        let shimmer = SKShapeNode(rectOf: CGSize(width: 3, height: 8))
        shimmer.position = CGPoint(
            x: center.x + CGFloat.random(in: -100...100),
            y: center.y - 100 + CGFloat.random(in: -50...50)
        )
        shimmer.fillColor = color.withAlphaComponent(0.4)
        shimmer.strokeColor = .clear
        shimmer.zPosition = -2.7
        // REMOVED: blendMode = .add (causes extra render pass)
        particleLayer.addChild(shimmer)

        // Simple rise and fade
        shimmer.run(SKAction.sequence([
            SKAction.group([
                SKAction.moveBy(x: 0, y: 80, duration: 1.5),
                SKAction.fadeOut(withDuration: 1.5)
            ]),
            SKAction.run { [weak self] in self?.ambientParticleCount -= 1 },
            SKAction.removeFromParent()
        ]))
    }

    // MARK: - RAM Sector Ambient (Memory Theme)

    /// RAM sector: OPTIMIZED - Static LEDs with simple shared blink, no glow
    private func startRAMSectorAmbient(sector: MegaBoardSector) {
        let themeColor = UIColor(hex: sector.theme.primaryColorHex) ?? .green

        // Create static LED nodes (no individual animations)
        let chipBaseY = sector.worldY + sector.height / 2
        let chipX = sector.worldX + 150

        // Pre-defined blink pattern (which LEDs are "on" at each step)
        // Pattern cycles through showing different LEDs lit
        let blinkPatterns: [[Bool]] = [
            [true, false, false, true, false, true, false, false, true, false, false, true],
            [false, true, false, false, true, false, true, false, false, true, false, false],
            [true, true, false, false, false, true, false, true, false, false, true, false],
            [false, false, true, true, false, false, false, false, true, true, false, true],
        ]

        var allLEDs: [SKShapeNode] = []
        for chipIndex in 0..<4 {
            let yOffset = CGFloat(chipIndex) * 100 - 150
            for ledIndex in 0..<3 {
                let ledX = chipX + 50 + CGFloat(ledIndex) * 50
                let ledY = chipBaseY + yOffset + 30

                let led = SKShapeNode(circleOfRadius: 3)
                led.position = CGPoint(x: ledX, y: ledY)
                led.fillColor = themeColor.withAlphaComponent(0.2)
                led.strokeColor = themeColor.withAlphaComponent(0.4)
                led.lineWidth = 1
                // REMOVED: glowWidth, blendMode
                led.zPosition = -2.3
                backgroundLayer.addChild(led)
                allLEDs.append(led)
            }
        }

        // Single timer updates all LEDs with pre-defined pattern
        var patternIndex = 0
        let updateLEDs = SKAction.run { [weak self] in
            guard self != nil else { return }
            let pattern = blinkPatterns[patternIndex % blinkPatterns.count]
            for (i, led) in allLEDs.enumerated() {
                let isOn = pattern[i % pattern.count]
                led.fillColor = themeColor.withAlphaComponent(isOn ? 0.8 : 0.15)
            }
            patternIndex += 1
        }

        let blinkSequence = SKAction.repeatForever(SKAction.sequence([
            updateLEDs,
            SKAction.wait(forDuration: 0.3)  // Update every 0.3s (was random 0.05-0.15)
        ]))
        backgroundLayer.run(blinkSequence, withKey: "ramBlink_\(sector.id)")

        // Simplified data pulse (less frequent, no glow)
        startRAMDataPulse(sector: sector, color: themeColor)
    }

    /// RAM sector: Simplified data pulse - no glow, less frequent
    private func startRAMDataPulse(sector: MegaBoardSector, color: UIColor) {
        let spawnPulse = SKAction.run { [weak self] in
            guard let self = self, self.ambientParticleCount < self.maxAmbientParticles else { return }
            self.ambientParticleCount += 1

            let pulseY = sector.worldY + sector.height / 2 + CGFloat.random(in: -100...100)
            let pulse = SKShapeNode(rectOf: CGSize(width: 300, height: 3))
            pulse.position = CGPoint(x: sector.worldX, y: pulseY)
            pulse.fillColor = color.withAlphaComponent(0.5)
            pulse.strokeColor = .clear
            // REMOVED: glowWidth, blendMode
            pulse.zPosition = -2.2
            self.particleLayer.addChild(pulse)

            pulse.run(SKAction.sequence([
                SKAction.group([
                    SKAction.moveTo(x: sector.worldX + sector.width, duration: 0.5),
                    SKAction.fadeOut(withDuration: 0.5)
                ]),
                SKAction.run { [weak self] in self?.ambientParticleCount -= 1 },
                SKAction.removeFromParent()
            ]))
        }

        let pulseSequence = SKAction.repeatForever(SKAction.sequence([
            SKAction.wait(forDuration: 4.0),  // Less frequent (was 2-5s random)
            spawnPulse
        ]))
        backgroundLayer.run(pulseSequence, withKey: "ramPulse_\(sector.id)")
    }

    // MARK: - Storage Sector Ambient - OPTIMIZED: No glow, simpler LED

    /// Storage sector: Simple activity LED, no trail particles
    private func startStorageSectorAmbient(sector: MegaBoardSector) {
        let themeColor = UIColor(hex: sector.theme.primaryColorHex) ?? .purple
        let chipCenter = CGPoint(x: sector.worldX + 325, y: sector.worldY + sector.height / 2)

        // Simple activity LED (no glow)
        let activityLED = SKShapeNode(circleOfRadius: 5)
        activityLED.position = CGPoint(x: chipCenter.x + 100, y: chipCenter.y + 50)
        activityLED.fillColor = themeColor.withAlphaComponent(0.3)
        activityLED.strokeColor = themeColor.withAlphaComponent(0.6)
        activityLED.lineWidth = 1
        // REMOVED: glowWidth, blendMode
        activityLED.zPosition = -2.3
        backgroundLayer.addChild(activityLED)

        // Simple on/off blink (not complex random pattern)
        let activityBlink = SKAction.repeatForever(SKAction.sequence([
            SKAction.run { activityLED.fillColor = themeColor.withAlphaComponent(0.8) },
            SKAction.wait(forDuration: 0.1),
            SKAction.run { activityLED.fillColor = themeColor.withAlphaComponent(0.2) },
            SKAction.wait(forDuration: 0.8)
        ]))
        activityLED.run(activityBlink, withKey: "storageActivity")

        // REMOVED: Data trail particles (too expensive, minimal visual impact)
    }

    /// Storage sector: Data trail - DISABLED for performance
    private func startStorageDataTrail(sector: MegaBoardSector, color: UIColor) {
        // Disabled - particles were expensive for minimal visual impact
    }

    // MARK: - Network Sector Ambient - OPTIMIZED: No glow, less frequent rings

    /// Network sector: Simplified rings, static LEDs
    private func startNetworkSectorAmbient(sector: MegaBoardSector) {
        let themeColor = UIColor(hex: sector.theme.primaryColorHex) ?? .cyan
        let center = CGPoint(x: sector.worldX + sector.width / 2, y: sector.worldY + sector.height / 2)

        // Expanding signal rings (no glow, less frequent)
        let spawnRing = SKAction.run { [weak self] in
            guard let self = self, self.ambientParticleCount < self.maxAmbientParticles else { return }
            self.ambientParticleCount += 1

            let ring = SKShapeNode(circleOfRadius: 20)
            ring.position = center
            ring.fillColor = .clear
            ring.strokeColor = themeColor.withAlphaComponent(0.4)
            ring.lineWidth = 2
            // REMOVED: glowWidth, blendMode
            ring.zPosition = -2.8
            self.particleLayer.addChild(ring)

            ring.run(SKAction.sequence([
                SKAction.group([
                    SKAction.scale(to: 8, duration: 2.0),
                    SKAction.fadeOut(withDuration: 2.0)
                ]),
                SKAction.run { [weak self] in self?.ambientParticleCount -= 1 },
                SKAction.removeFromParent()
            ]))
        }

        let ringSequence = SKAction.repeatForever(SKAction.sequence([
            spawnRing,
            SKAction.wait(forDuration: 2.5)  // Less frequent (was 1.5)
        ]))
        backgroundLayer.run(ringSequence, withKey: "networkRings_\(sector.id)")

        // Static packet LEDs with shared blink timer (no individual animations)
        var packetLEDs: [SKShapeNode] = []
        for i in 0..<4 {
            let led = SKShapeNode(rectOf: CGSize(width: 8, height: 4))
            led.position = CGPoint(x: center.x - 50 + CGFloat(i) * 30, y: center.y + 150)
            led.fillColor = themeColor.withAlphaComponent(0.2)
            led.strokeColor = .clear
            // REMOVED: glowWidth, blendMode
            led.zPosition = -2.3
            backgroundLayer.addChild(led)
            packetLEDs.append(led)
        }

        // Single timer updates all LEDs
        var blinkState = 0
        let blinkPattern: [[Bool]] = [[true, false, true, false], [false, true, false, true], [true, true, false, false], [false, false, true, true]]
        let updateLEDs = SKAction.run {
            let pattern = blinkPattern[blinkState % blinkPattern.count]
            for (i, led) in packetLEDs.enumerated() {
                led.fillColor = themeColor.withAlphaComponent(pattern[i] ? 0.8 : 0.15)
            }
            blinkState += 1
        }
        backgroundLayer.run(SKAction.repeatForever(SKAction.sequence([updateLEDs, SKAction.wait(forDuration: 0.4)])), withKey: "networkLEDs_\(sector.id)")
    }

    // MARK: - I/O Sector Ambient - OPTIMIZED: Static LEDs, no burst particles

    /// I/O sector: Static LEDs with simple shared blink
    private func startIOSectorAmbient(sector: MegaBoardSector) {
        // Static USB LEDs (no individual animations, no glow)
        var usbLEDs: [SKShapeNode] = []
        for i in 0..<3 {
            let ledX = sector.worldX + 100 + CGFloat(i) * 120 + 40
            let ledY = sector.worldY + 200 + 25

            let led = SKShapeNode(circleOfRadius: 3)
            led.position = CGPoint(x: ledX, y: ledY)
            led.fillColor = UIColor.green.withAlphaComponent(0.2)
            led.strokeColor = .clear
            // REMOVED: glowWidth, blendMode
            led.zPosition = -2.3
            backgroundLayer.addChild(led)
            usbLEDs.append(led)
        }

        // Single timer updates all LEDs with rotating pattern
        var ledState = 0
        let updateLEDs = SKAction.run {
            for (i, led) in usbLEDs.enumerated() {
                let isOn = (i == ledState % 3)
                led.fillColor = UIColor.green.withAlphaComponent(isOn ? 0.8 : 0.15)
            }
            ledState += 1
        }
        backgroundLayer.run(SKAction.repeatForever(SKAction.sequence([updateLEDs, SKAction.wait(forDuration: 0.5)])), withKey: "ioLEDs_\(sector.id)")

        // REMOVED: Data burst particles (too expensive)
    }

    /// I/O sector: Data burst - DISABLED for performance
    private func startIODataBurst(sector: MegaBoardSector, color: UIColor) {
        // Disabled - particles were expensive for minimal visual impact
    }

    // MARK: - Cache Sector Ambient - OPTIMIZED: No flash particles, simple speed lines

    /// Cache sector: Simplified - just occasional speed lines, no flash particles
    private func startCacheSectorAmbient(sector: MegaBoardSector) {
        let themeColor = UIColor(hex: sector.theme.primaryColorHex) ?? .blue

        // REMOVED: Cache hit flash particles (very expensive with glowWidth=15)
        // Only keep speed lines, but less frequent
        startCacheSpeedLines(sector: sector, color: themeColor)
    }

    /// Cache sector: Speed lines - simplified, no glow, less frequent
    private func startCacheSpeedLines(sector: MegaBoardSector, color: UIColor) {
        let spawnLine = SKAction.run { [weak self] in
            guard let self = self, self.ambientParticleCount < self.maxAmbientParticles else { return }
            self.ambientParticleCount += 1

            let y = sector.worldY + CGFloat.random(in: 100...(sector.height - 100))
            let lineLength: CGFloat = 100  // Fixed length instead of random

            let line = SKShapeNode()
            let path = CGMutablePath()
            path.move(to: CGPoint(x: sector.worldX, y: y))
            path.addLine(to: CGPoint(x: sector.worldX + lineLength, y: y))
            line.path = path
            line.strokeColor = color.withAlphaComponent(0.6)
            line.lineWidth = 2
            // REMOVED: glowWidth, blendMode
            line.zPosition = -2.6
            self.particleLayer.addChild(line)

            line.run(SKAction.sequence([
                SKAction.moveBy(x: sector.width + lineLength, y: 0, duration: 0.2),
                SKAction.run { [weak self] in self?.ambientParticleCount -= 1 },
                SKAction.removeFromParent()
            ]))
        }

        let lineSequence = SKAction.repeatForever(SKAction.sequence([
            SKAction.wait(forDuration: 0.8),  // Less frequent (was 0.2-0.6)
            spawnLine
        ]))
        backgroundLayer.run(lineSequence, withKey: "cacheLines_\(sector.id)")
    }

    /// Add via holes scattered around a sector
    private func addSectorVias(to node: SKNode, in sector: MegaBoardSector, color: UIColor) {
        let viaCount = 12
        let viaRadius: CGFloat = 4
        let margin: CGFloat = 100  // Keep vias away from edges

        for _ in 0..<viaCount {
            let x = sector.worldX + margin + CGFloat.random(in: 0...(sector.width - margin * 2))
            let y = sector.worldY + margin + CGFloat.random(in: 0...(sector.height - margin * 2))

            // Via hole (dark center with ring)
            let via = SKShapeNode(circleOfRadius: viaRadius)
            via.position = CGPoint(x: x, y: y)
            via.fillColor = UIColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1.0)
            via.strokeColor = color
            via.lineWidth = 1.5
            via.zPosition = -3
            node.addChild(via)

            // Copper pad around via
            let pad = SKShapeNode(circleOfRadius: viaRadius + 3)
            pad.position = CGPoint(x: x, y: y)
            pad.fillColor = .clear
            pad.strokeColor = UIColor(hex: MotherboardColors.copperTrace)?.withAlphaComponent(0.2) ?? UIColor.orange.withAlphaComponent(0.2)
            pad.lineWidth = 2
            pad.zPosition = -3.1
            node.addChild(pad)
        }
    }

    /// Add IC footprint decorations based on sector type
    private func addSectorICs(to node: SKNode, in sector: MegaBoardSector) {
        let themeColor = UIColor(hex: sector.theme.primaryColorHex)?.withAlphaComponent(0.3) ?? UIColor.gray.withAlphaComponent(0.3)

        switch sector.theme {
        case .power:
            // Capacitor symbols for PSU
            addCapacitorSymbols(to: node, in: sector, color: themeColor)

        case .graphics:
            // Heat sink pattern for GPU
            addHeatSinkPattern(to: node, in: sector, color: themeColor)

        case .memory:
            // Memory chip rows for RAM/Cache
            addMemoryChips(to: node, in: sector, color: themeColor)

        case .storage:
            // SSD chip outlines
            addStorageChips(to: node, in: sector, color: themeColor)

        case .io:
            // Port/connector outlines
            addIOConnectors(to: node, in: sector, color: themeColor)

        case .network:
            // Network jack outline
            addNetworkJack(to: node, in: sector, color: themeColor)

        case .processing:
            // Small processor cache blocks
            addCacheBlocks(to: node, in: sector, color: themeColor)
        }
    }

    // MARK: - District Foundation System
    // Shared visual elements for all districts: street grids, vias, labels, shadows
    // Creates the cohesive "motherboard city" feel across all sectors

    /// Shared colors used across all districts
    private struct DistrictFoundationColors {
        // PCB base colors
        static let copper = UIColor(hex: "#b87333") ?? .orange
        static let copperPad = UIColor(hex: "#c48940") ?? .orange
        static let soldermask = UIColor(hex: "#0a0f0a") ?? .black
        static let silkscreen = UIColor(hex: "#ffffff") ?? .white
        static let via = UIColor(hex: "#1a1a22") ?? .black
        static let shadow = UIColor.black
    }

    /// Draw secondary street grid (cosmetic PCB traces) for a sector
    /// Creates the "city streets" pattern that connects to main lane
    private func drawSecondaryStreetGrid(to node: SKNode, in sector: MegaBoardSector, themeColor: UIColor) {
        let baseX = sector.worldX
        let baseY = sector.worldY
        let width = sector.width
        let height = sector.height
        let zPos: CGFloat = 1  // Above substrate/grid, below components

        // Main arterial traces - copper color, clearly visible
        let arteryWidth: CGFloat = 6
        let arteryAlpha: CGFloat = 0.50

        // Side street traces - slightly thinner and dimmer
        let streetWidth: CGFloat = 4
        let streetAlpha: CGFloat = 0.35

        // Create arterial grid pattern using single path for efficiency
        let arteryPath = CGMutablePath()

        // Horizontal arteries (3 lines across sector)
        let hSpacing = height / 4
        for i in 1...3 {
            let y = baseY + hSpacing * CGFloat(i)
            // Add slight organic curve to avoid rigid grid look
            let curveOffset = CGFloat.random(in: -20...20)
            arteryPath.move(to: CGPoint(x: baseX + 50, y: y + curveOffset))
            arteryPath.addLine(to: CGPoint(x: baseX + width * 0.3, y: y))
            arteryPath.addLine(to: CGPoint(x: baseX + width * 0.7, y: y + curveOffset * 0.5))
            arteryPath.addLine(to: CGPoint(x: baseX + width - 50, y: y))
        }

        // Vertical arteries (3 lines down sector)
        let vSpacing = width / 4
        for i in 1...3 {
            let x = baseX + vSpacing * CGFloat(i)
            let curveOffset = CGFloat.random(in: -20...20)
            arteryPath.move(to: CGPoint(x: x + curveOffset, y: baseY + 50))
            arteryPath.addLine(to: CGPoint(x: x, y: baseY + height * 0.3))
            arteryPath.addLine(to: CGPoint(x: x + curveOffset * 0.5, y: baseY + height * 0.7))
            arteryPath.addLine(to: CGPoint(x: x, y: baseY + height - 50))
        }

        let arteryNode = SKShapeNode(path: arteryPath)
        arteryNode.strokeColor = DistrictFoundationColors.copper.withAlphaComponent(arteryAlpha)
        arteryNode.lineWidth = arteryWidth
        arteryNode.lineCap = .round
        arteryNode.lineJoin = .round
        arteryNode.zPosition = zPos
        node.addChild(arteryNode)

        // Side streets (smaller traces between arteries)
        let streetPath = CGMutablePath()

        // Horizontal side streets
        let hSideSpacing = height / 8
        for i in [1, 3, 5, 7] {
            let y = baseY + hSideSpacing * CGFloat(i)
            streetPath.move(to: CGPoint(x: baseX + 80, y: y))
            streetPath.addLine(to: CGPoint(x: baseX + width * 0.4, y: y))
            // Skip middle (where main lane typically runs)
            streetPath.move(to: CGPoint(x: baseX + width * 0.6, y: y))
            streetPath.addLine(to: CGPoint(x: baseX + width - 80, y: y))
        }

        // Vertical side streets
        let vSideSpacing = width / 8
        for i in [1, 3, 5, 7] {
            let x = baseX + vSideSpacing * CGFloat(i)
            streetPath.move(to: CGPoint(x: x, y: baseY + 80))
            streetPath.addLine(to: CGPoint(x: x, y: baseY + height * 0.4))
            streetPath.move(to: CGPoint(x: x, y: baseY + height * 0.6))
            streetPath.addLine(to: CGPoint(x: x, y: baseY + height - 80))
        }

        let streetNode = SKShapeNode(path: streetPath)
        streetNode.strokeColor = DistrictFoundationColors.copper.withAlphaComponent(streetAlpha)
        streetNode.lineWidth = streetWidth
        streetNode.lineCap = .round
        streetNode.zPosition = zPos - 0.1
        node.addChild(streetNode)
    }

    /// Add via "roundabouts" at trace intersections
    /// Creates small circular vias where streets cross - like traffic circles
    private func addViaRoundabouts(to node: SKNode, in sector: MegaBoardSector, themeColor: UIColor) {
        let baseX = sector.worldX
        let baseY = sector.worldY
        let width = sector.width
        let height = sector.height
        let zPos: CGFloat = 1.5  // Just above streets, below components

        let viaRadius: CGFloat = 10
        let padRadius: CGFloat = 14

        // Place vias at grid intersections (where arteries cross)
        let hSpacing = height / 4
        let vSpacing = width / 4

        // Create single path for all via holes (efficiency)
        let viaHolePath = CGMutablePath()
        let viaPadPath = CGMutablePath()

        for row in 1...3 {
            for col in 1...3 {
                let x = baseX + vSpacing * CGFloat(col)
                let y = baseY + hSpacing * CGFloat(row)

                // Add slight offset for organic feel
                let offset = CGPoint(
                    x: CGFloat.random(in: -15...15),
                    y: CGFloat.random(in: -15...15)
                )

                let center = CGPoint(x: x + offset.x, y: y + offset.y)

                // Via hole (dark center)
                viaHolePath.addEllipse(in: CGRect(
                    x: center.x - viaRadius,
                    y: center.y - viaRadius,
                    width: viaRadius * 2,
                    height: viaRadius * 2
                ))

                // Copper pad around via
                viaPadPath.addEllipse(in: CGRect(
                    x: center.x - padRadius,
                    y: center.y - padRadius,
                    width: padRadius * 2,
                    height: padRadius * 2
                ))
            }
        }

        // Pad layer (behind holes) - copper pads around vias
        let padNode = SKShapeNode(path: viaPadPath)
        padNode.fillColor = .clear
        padNode.strokeColor = DistrictFoundationColors.copperPad.withAlphaComponent(0.50)
        padNode.lineWidth = 4
        padNode.zPosition = zPos - 0.1
        node.addChild(padNode)

        // Via holes (dark centers with theme accent ring)
        let holeNode = SKShapeNode(path: viaHolePath)
        holeNode.fillColor = DistrictFoundationColors.via
        holeNode.strokeColor = themeColor.withAlphaComponent(0.60)
        holeNode.lineWidth = 2
        holeNode.zPosition = zPos
        node.addChild(holeNode)
    }

    /// Add silkscreen labels (faint component markings)
    /// Creates the "text" feel of real PCBs - very subtle
    private func addSilkscreenLabels(to node: SKNode, in sector: MegaBoardSector, themeColor: UIColor) {
        let baseX = sector.worldX
        let baseY = sector.worldY
        let zPos: CGFloat = 2  // Above streets/vias, below components

        // Silkscreen labels - subtle but visible
        let labelAlpha: CGFloat = 0.35

        // Component reference designators scattered around
        let designators: [(text: String, x: CGFloat, y: CGFloat, rotation: CGFloat)] = [
            ("C1", 150, 200, 0),
            ("C2", 1200, 180, 0),
            ("R12", 400, 550, CGFloat.pi / 12),
            ("U3", 800, 700, 0),
            ("L1", 250, 850, -CGFloat.pi / 8),
            ("Q4", 1050, 450, CGFloat.pi / 6),
            ("D7", 600, 300, 0),
            ("T1", 700, 950, 0)
        ]

        for designator in designators {
            let label = SKLabelNode(text: designator.text)
            label.fontName = "Menlo"
            label.fontSize = 10
            label.fontColor = DistrictFoundationColors.silkscreen.withAlphaComponent(labelAlpha)
            label.position = CGPoint(x: baseX + designator.x, y: baseY + designator.y)
            label.zRotation = designator.rotation
            label.horizontalAlignmentMode = .left
            label.zPosition = zPos
            node.addChild(label)
        }

        // Add a few small silkscreen lines/boxes (component outlines)
        let outlinePath = CGMutablePath()

        // Small component outline boxes
        let outlines: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat)] = [
            (160, 210, 30, 15),
            (1210, 190, 25, 12),
            (610, 310, 20, 10),
            (260, 860, 35, 18)
        ]

        for outline in outlines {
            outlinePath.addRect(CGRect(
                x: baseX + outline.x,
                y: baseY + outline.y,
                width: outline.w,
                height: outline.h
            ))
        }

        let outlineNode = SKShapeNode(path: outlinePath)
        outlineNode.fillColor = .clear
        outlineNode.strokeColor = DistrictFoundationColors.silkscreen.withAlphaComponent(labelAlpha * 0.8)
        outlineNode.lineWidth = 1
        outlineNode.zPosition = zPos
        node.addChild(outlineNode)
    }

    /// Add a drop shadow to a component for depth
    /// Creates subtle "building" shadow effect
    private func addComponentShadow(to parent: SKNode, shape: CGPath, offset: CGPoint = CGPoint(x: 3, y: -3), alpha: CGFloat = 0.15) {
        let shadow = SKShapeNode(path: shape)
        shadow.fillColor = DistrictFoundationColors.shadow.withAlphaComponent(alpha)
        shadow.strokeColor = .clear
        shadow.position = offset
        shadow.zPosition = -0.5  // Behind the component
        parent.addChild(shadow)
    }

    // MARK: - PSU District Components ("Zoomed-In PSU City")
    // Creates realistic PSU internal components as district background
    // Sector coordinates: 0-1400 range (sector size is 1400x1400)

    /// Cached colors for PSU components - parsed once, reused everywhere
    private struct PSUColors {
        static let capacitorBody = UIColor(hex: "#2a2a35") ?? .darkGray
        static let capacitorBandBlue = UIColor(hex: "#3366aa") ?? .blue
        static let capacitorBandGreen = UIColor(hex: "#338855") ?? .green
        static let capacitorBandDarkBlue = UIColor(hex: "#2a2a55") ?? .blue
        static let copper = UIColor(hex: "#b87333") ?? .orange
        static let transformerBody = UIColor(hex: "#1a1a22") ?? .black
        static let lamination = UIColor(hex: "#252530") ?? .darkGray
        static let heatSinkFin = UIColor(hex: "#3a3a45") ?? .gray
        static let connectorBody = UIColor(hex: "#1a1a1a") ?? .black
        static let goldPin = UIColor(hex: "#d4a600") ?? .yellow
        static let mosfetTab = UIColor(hex: "#4a4a55") ?? .gray
        static let ferriteCore = UIColor(hex: "#15151a") ?? .black
        static let ceramicBody = UIColor(hex: "#c4a882") ?? .brown
        static let leadWire = UIColor(hex: "#888888") ?? .gray
        static let theme = UIColor(hex: "#ffdd00") ?? .yellow
    }

    /// Main entry point for PSU district decorations
    private func addCapacitorSymbols(to node: SKNode, in sector: MegaBoardSector, color: UIColor) {
        drawPSUComponents(to: node, in: sector, themeColor: color)
    }

    /// Draw all PSU components - creates a "zoomed-in PSU" cityscape
    private func drawPSUComponents(to node: SKNode, in sector: MegaBoardSector, themeColor: UIColor) {
        // PERFORMANCE OPTIMIZED: Uses batched paths instead of individual nodes
        // Reduces node count from ~200+ to ~30 nodes
        psuCapacitorNodes.removeAll()

        let baseX = sector.worldX
        let baseY = sector.worldY
        let width = sector.width
        let height = sector.height
        let zPos: CGFloat = 3

        func isNearLane(_ x: CGFloat, _ y: CGFloat) -> Bool {
            if y > 500 && y < 900 && x > 300 && x < 1100 { return true }
            if x > 1000 && y > 400 && y < 700 { return true }
            return false
        }

        // Pre-generate random positions (seeded for consistency)
        var ceramicPositions: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat)] = []
        var mosfetPositions: [(x: CGFloat, y: CGFloat)] = []
        var heatSinkPositions: [(x: CGFloat, y: CGFloat, finCount: Int, finH: CGFloat)] = []

        for _ in 0..<80 {
            let x = CGFloat.random(in: 50...(width - 50))
            let y = CGFloat.random(in: 50...(height - 50))
            if !isNearLane(x, y) {
                ceramicPositions.append((x, y, CGFloat.random(in: 8...14), CGFloat.random(in: 6...10)))
            }
        }
        for _ in 0..<25 {
            let x = CGFloat.random(in: 100...(width - 100))
            let y = CGFloat.random(in: 100...(height - 100))
            if !isNearLane(x, y) { mosfetPositions.append((x, y)) }
        }
        for _ in 0..<10 {
            let x = CGFloat.random(in: 80...(width - 80))
            let y = CGFloat.random(in: 80...(height - 80))
            if !isNearLane(x, y) {
                heatSinkPositions.append((x, y, Int.random(in: 8...14), CGFloat.random(in: 40...65)))
            }
        }

        // ========== BATCHED CERAMIC CAPACITORS (1 node for all) ==========
        let ceramicPath = CGMutablePath()
        for pos in ceramicPositions {
            ceramicPath.addRect(CGRect(x: baseX + pos.x - pos.w/2, y: baseY + pos.y - pos.h/2, width: pos.w, height: pos.h))
        }
        let ceramicNode = SKShapeNode(path: ceramicPath)
        ceramicNode.fillColor = PSUColors.ceramicBody.withAlphaComponent(0.5)
        ceramicNode.strokeColor = themeColor.withAlphaComponent(0.15)
        ceramicNode.lineWidth = 0.5
        ceramicNode.zPosition = zPos - 0.2
        node.addChild(ceramicNode)

        // ========== BATCHED MOSFET BODIES (1 node for all) ==========
        let mosfetBodyPath = CGMutablePath()
        let mosfetTabPath = CGMutablePath()
        for pos in mosfetPositions {
            mosfetBodyPath.addRect(CGRect(x: baseX + pos.x - 12, y: baseY + pos.y - 16, width: 24, height: 32))
            mosfetTabPath.addRect(CGRect(x: baseX + pos.x - 16, y: baseY + pos.y + 16, width: 32, height: 8))
        }
        let mosfetBody = SKShapeNode(path: mosfetBodyPath)
        mosfetBody.fillColor = UIColor(red: 0.08, green: 0.08, blue: 0.1, alpha: 1.0)
        mosfetBody.strokeColor = themeColor.withAlphaComponent(0.2)
        mosfetBody.lineWidth = 0.5
        mosfetBody.zPosition = zPos - 0.1
        node.addChild(mosfetBody)

        let mosfetTab = SKShapeNode(path: mosfetTabPath)
        mosfetTab.fillColor = PSUColors.mosfetTab
        mosfetTab.strokeColor = .clear
        mosfetTab.zPosition = zPos - 0.05
        node.addChild(mosfetTab)

        // ========== BATCHED HEAT SINK FINS (1 node per heat sink) ==========
        for hs in heatSinkPositions {
            let finsPath = CGMutablePath()
            let finW: CGFloat = 4
            let spacing = finW + 3
            let totalW = CGFloat(hs.finCount) * spacing
            for f in 0..<hs.finCount {
                let fx = baseX + hs.x - totalW/2 + CGFloat(f) * spacing
                finsPath.addRect(CGRect(x: fx, y: baseY + hs.y - hs.finH/2, width: finW, height: hs.finH))
            }
            let fins = SKShapeNode(path: finsPath)
            fins.fillColor = UIColor(red: 0.22, green: 0.22, blue: 0.26, alpha: 1.0)
            fins.strokeColor = themeColor.withAlphaComponent(0.15)
            fins.lineWidth = 0.5
            fins.zPosition = zPos
            node.addChild(fins)
        }

        // ========== LARGE ELECTROLYTIC CAPACITORS (keep as individual - 12 units) ==========
        let bandColors = [PSUColors.capacitorBandBlue, PSUColors.capacitorBandGreen, PSUColors.capacitorBandDarkBlue]
        var capIndex = 0
        for _ in 0..<15 {
            let x = CGFloat.random(in: 100...(width - 100))
            let y = CGFloat.random(in: 100...(height - 100))
            guard !isNearLane(x, y) else { continue }
            if capIndex >= 12 { break }

            let container = createElectrolyticCapacitor(
                height: CGFloat.random(in: 65...110),
                bandColor: bandColors[capIndex % bandColors.count],
                themeColor: themeColor
            )
            container.position = CGPoint(x: baseX + x, y: baseY + y)
            container.zPosition = zPos + 0.2
            node.addChild(container)
            psuCapacitorNodes.append(container)
            capIndex += 1
        }

        // ========== TRANSFORMERS (3 units - reduced) ==========
        let transformerPositions: [(x: CGFloat, y: CGFloat)] = [(200, 250), (1050, 350), (350, 1000)]
        for pos in transformerPositions {
            if !isNearLane(pos.x, pos.y) {
                let transformer = createTransformer(themeColor: themeColor)
                transformer.position = CGPoint(x: baseX + pos.x, y: baseY + pos.y)
                transformer.zPosition = zPos
                transformer.setScale(CGFloat.random(in: 0.75...1.0))
                node.addChild(transformer)
            }
        }

        // ========== 24-PIN CONNECTOR (1 unit) ==========
        let connector = create24PinConnector(themeColor: themeColor)
        connector.position = CGPoint(x: baseX + 1150, y: baseY + 200)
        connector.zPosition = zPos
        node.addChild(connector)

        // ========== INDUCTOR COILS (6 units - reduced) ==========
        for i in 0..<8 {
            let x = CGFloat.random(in: 150...(width - 150))
            let y = CGFloat.random(in: 150...(height - 150))
            guard !isNearLane(x, y) else { continue }
            if i >= 6 { break }

            let coil = createInductorCoil(themeColor: themeColor)
            coil.position = CGPoint(x: baseX + x, y: baseY + y)
            coil.zPosition = zPos
            coil.setScale(CGFloat.random(in: 0.7...1.0))
            node.addChild(coil)
        }

        // ========== PCB TRACES ==========
        addPSUTraces(to: node, baseX: baseX, baseY: baseY, zPos: zPos - 0.3)
    }

    // MARK: - PSU Component Factories

    /// Create a tall electrolytic capacitor with colored band
    /// - Parameters:
    ///   - height: Height of the capacitor body (85-110pt typical)
    ///   - bandColor: Pre-parsed UIColor for the manufacturer band
    ///   - themeColor: Theme accent color for subtle highlights
    private func createElectrolyticCapacitor(height: CGFloat, bandColor: UIColor, themeColor: UIColor) -> SKNode {
        let container = SKNode()
        let width: CGFloat = 55

        // Main cylindrical body (drawn as rounded rect)
        let bodyPath = CGMutablePath()
        bodyPath.addRoundedRect(in: CGRect(x: -width/2, y: -height/2, width: width, height: height),
                                 cornerWidth: 8, cornerHeight: 8)

        // Add shadow first (behind body)
        addComponentShadow(to: container, shape: bodyPath, offset: CGPoint(x: 4, y: -4), alpha: 0.12)

        let body = SKShapeNode(path: bodyPath)
        body.fillColor = PSUColors.capacitorBody
        body.strokeColor = themeColor.withAlphaComponent(0.15)
        body.lineWidth = 1
        container.addChild(body)

        // Colored band at top (manufacturer marking)
        let bandHeight: CGFloat = height * 0.25
        let bandPath = CGMutablePath()
        bandPath.addRoundedRect(in: CGRect(x: -width/2 + 2, y: height/2 - bandHeight - 4, width: width - 4, height: bandHeight),
                                 cornerWidth: 4, cornerHeight: 4)
        let band = SKShapeNode(path: bandPath)
        band.fillColor = bandColor.withAlphaComponent(0.6)
        band.strokeColor = bandColor.withAlphaComponent(0.3)
        band.lineWidth = 1
        container.addChild(band)

        // Top cap (slightly lighter)
        let topCap = SKShapeNode(ellipseIn: CGRect(x: -width/2 + 3, y: height/2 - 8, width: width - 6, height: 12))
        topCap.fillColor = PSUColors.capacitorBody.withAlphaComponent(0.8)
        topCap.strokeColor = themeColor.withAlphaComponent(0.1)
        topCap.lineWidth = 1
        container.addChild(topCap)

        // Leads (both in single path for efficiency)
        let leads = SKShapeNode()
        let leadsPath = CGMutablePath()
        leadsPath.move(to: CGPoint(x: -12, y: -height/2))
        leadsPath.addLine(to: CGPoint(x: -12, y: -height/2 - 15))
        leadsPath.move(to: CGPoint(x: 12, y: -height/2))
        leadsPath.addLine(to: CGPoint(x: 12, y: -height/2 - 15))
        leads.path = leadsPath
        leads.strokeColor = PSUColors.leadWire.withAlphaComponent(0.5)
        leads.lineWidth = 2
        container.addChild(leads)

        // Glow overlay for breathing animation (separate from discharge effect)
        let breatheGlow = SKShapeNode(path: bodyPath)
        breatheGlow.fillColor = themeColor.withAlphaComponent(0.0)
        breatheGlow.strokeColor = .clear
        breatheGlow.name = "breatheGlow"
        container.addChild(breatheGlow)

        // Discharge overlay (separate node to avoid animation conflicts)
        let dischargeGlow = SKShapeNode(path: bodyPath)
        dischargeGlow.fillColor = .clear
        dischargeGlow.strokeColor = .clear
        dischargeGlow.name = "dischargeGlow"
        container.addChild(dischargeGlow)

        // Subtle breathing animation (runs continuously, doesn't conflict with discharge)
        let breatheIn = SKAction.customAction(withDuration: 3.0) { [weak breatheGlow] _, elapsed in
            let progress = elapsed / 3.0
            breatheGlow?.fillColor = themeColor.withAlphaComponent(0.08 * progress)
        }
        let breatheOut = SKAction.customAction(withDuration: 3.0) { [weak breatheGlow] _, elapsed in
            let progress = elapsed / 3.0
            breatheGlow?.fillColor = themeColor.withAlphaComponent(0.08 * (1 - progress))
        }
        let breatheCycle = SKAction.sequence([breatheIn, breatheOut])
        breatheGlow.run(SKAction.repeatForever(breatheCycle), withKey: "breathing")

        return container
    }

    /// Create main transformer with E-I core and copper windings
    private func createTransformer(themeColor: UIColor) -> SKNode {
        let container = SKNode()
        let width: CGFloat = 150
        let height: CGFloat = 100

        // Main body (E-I core)
        let bodyPath = CGMutablePath()
        bodyPath.addRect(CGRect(x: -width/2, y: -height/2, width: width, height: height))

        // Add shadow (larger component = more prominent shadow)
        addComponentShadow(to: container, shape: bodyPath, offset: CGPoint(x: 5, y: -5), alpha: 0.15)

        let body = SKShapeNode(path: bodyPath)
        body.fillColor = PSUColors.transformerBody
        body.strokeColor = themeColor.withAlphaComponent(0.12)
        body.lineWidth = 2
        container.addChild(body)

        // E-core laminations (all in single path for efficiency)
        let laminations = SKShapeNode()
        let lamPath = CGMutablePath()
        for i in 0..<4 {
            let y = -height/2 + 20 + CGFloat(i) * 20
            lamPath.move(to: CGPoint(x: -width/2 + 10, y: y))
            lamPath.addLine(to: CGPoint(x: width/2 - 10, y: y))
        }
        laminations.path = lamPath
        laminations.strokeColor = PSUColors.lamination.withAlphaComponent(0.8)
        laminations.lineWidth = 1
        container.addChild(laminations)

        // Copper windings (all in single path for efficiency)
        let windings = SKShapeNode()
        let windingsPath = CGMutablePath()
        let windingWidth: CGFloat = 80
        let windingHeight: CGFloat = 50
        for row in 0..<3 {
            let y = -windingHeight/2 + CGFloat(row) * 18
            windingsPath.move(to: CGPoint(x: -windingWidth/2, y: y))
            // Create wavy pattern
            for i in 0..<8 {
                let x = -windingWidth/2 + CGFloat(i + 1) * (windingWidth / 8)
                let yOffset: CGFloat = (i % 2 == 0) ? 4 : -4
                windingsPath.addLine(to: CGPoint(x: x, y: y + yOffset))
            }
        }
        windings.path = windingsPath
        windings.strokeColor = PSUColors.copper.withAlphaComponent(0.3)
        windings.lineWidth = 3
        container.addChild(windings)

        return container
    }

    /// Create heat sink with aluminum fins
    private func createHeatSink(finCount: Int, finHeight: CGFloat) -> SKNode {
        let container = SKNode()
        let finSpacing: CGFloat = 8
        let finWidth: CGFloat = 4
        let totalWidth = CGFloat(finCount) * finSpacing
        let baseHeight: CGFloat = 8

        // Overall shadow footprint (covers base and fins area)
        let shadowPath = CGMutablePath()
        shadowPath.addRect(CGRect(x: -totalWidth/2, y: -baseHeight/2, width: totalWidth, height: finHeight + baseHeight))
        addComponentShadow(to: container, shape: shadowPath, offset: CGPoint(x: 4, y: -4), alpha: 0.1)

        // Base plate
        let basePath = CGMutablePath()
        basePath.addRect(CGRect(x: -totalWidth/2, y: -baseHeight/2, width: totalWidth, height: baseHeight))
        let base = SKShapeNode(path: basePath)
        base.fillColor = PSUColors.heatSinkFin
        base.strokeColor = PSUColors.heatSinkFin.withAlphaComponent(0.8)
        base.lineWidth = 1
        container.addChild(base)

        // All fins in single path for efficiency
        let fins = SKShapeNode()
        let finsPath = CGMutablePath()
        for i in 0..<finCount {
            let x = -totalWidth/2 + CGFloat(i) * finSpacing + finSpacing/2
            finsPath.addRect(CGRect(x: x - finWidth/2, y: baseHeight/2, width: finWidth, height: finHeight))
        }
        fins.path = finsPath
        fins.fillColor = PSUColors.heatSinkFin.withAlphaComponent(0.9)
        fins.strokeColor = PSUColors.heatSinkFin.withAlphaComponent(0.5)
        fins.lineWidth = 0.5
        container.addChild(fins)

        return container
    }

    /// Create 24-pin main connector with gold pins
    /// Uses single path for all 24 pins to reduce node count
    private func create24PinConnector(themeColor: UIColor) -> SKNode {
        let container = SKNode()
        let width: CGFloat = 180
        let height: CGFloat = 45

        // Connector body (black plastic housing)
        let bodyPath = CGMutablePath()
        bodyPath.addRoundedRect(in: CGRect(x: -width/2, y: -height/2, width: width, height: height),
                                 cornerWidth: 4, cornerHeight: 4)

        // Add shadow
        addComponentShadow(to: container, shape: bodyPath, offset: CGPoint(x: 4, y: -4), alpha: 0.12)

        let body = SKShapeNode(path: bodyPath)
        body.fillColor = PSUColors.connectorBody
        body.strokeColor = themeColor.withAlphaComponent(0.1)
        body.lineWidth = 1
        container.addChild(body)

        // Pin grid (12 x 2 = 24 pins) - all in single path for efficiency
        let pinRadius: CGFloat = 3
        let pinSpacingX: CGFloat = 13
        let pinSpacingY: CGFloat = 14

        let pins = SKShapeNode()
        let pinsPath = CGMutablePath()
        for row in 0..<2 {
            for col in 0..<12 {
                let x = -width/2 + 15 + CGFloat(col) * pinSpacingX
                let y = -pinSpacingY/2 + CGFloat(row) * pinSpacingY
                pinsPath.addEllipse(in: CGRect(x: x - pinRadius, y: y - pinRadius,
                                               width: pinRadius * 2, height: pinRadius * 2))
            }
        }
        pins.path = pinsPath
        pins.fillColor = PSUColors.goldPin.withAlphaComponent(0.35)
        pins.strokeColor = PSUColors.goldPin.withAlphaComponent(0.2)
        pins.lineWidth = 0.5
        container.addChild(pins)

        return container
    }

    /// Create MOSFET (power transistor)
    private func createMOSFET(themeColor: UIColor) -> SKNode {
        let container = SKNode()
        let width: CGFloat = 22
        let height: CGFloat = 32

        // Main body
        let bodyPath = CGMutablePath()
        bodyPath.addRect(CGRect(x: -width/2, y: -height/2 + 8, width: width, height: height - 8))

        // Add shadow
        addComponentShadow(to: container, shape: bodyPath, offset: CGPoint(x: 2, y: -2), alpha: 0.1)

        let body = SKShapeNode(path: bodyPath)
        body.fillColor = PSUColors.connectorBody
        body.strokeColor = themeColor.withAlphaComponent(0.1)
        body.lineWidth = 1
        container.addChild(body)

        // Heat sink tab (top)
        let tabPath = CGMutablePath()
        tabPath.addRect(CGRect(x: -width/2 - 4, y: height/2 - 4, width: width + 8, height: 10))
        let tab = SKShapeNode(path: tabPath)
        tab.fillColor = PSUColors.mosfetTab
        tab.strokeColor = PSUColors.mosfetTab.withAlphaComponent(0.6)
        tab.lineWidth = 1
        container.addChild(tab)

        // Mounting hole in tab
        let hole = SKShapeNode(circleOfRadius: 3)
        hole.position = CGPoint(x: 0, y: height/2 + 1)
        hole.fillColor = PSUColors.connectorBody.withAlphaComponent(0.8)
        hole.strokeColor = PSUColors.mosfetTab.withAlphaComponent(0.4)
        hole.lineWidth = 0.5
        container.addChild(hole)

        // Legs (3 pins) - all in single path
        let legs = SKShapeNode()
        let legsPath = CGMutablePath()
        for i in 0..<3 {
            let x = -8 + CGFloat(i) * 8
            legsPath.move(to: CGPoint(x: x, y: -height/2 + 8))
            legsPath.addLine(to: CGPoint(x: x, y: -height/2 - 6))
        }
        legs.path = legsPath
        legs.strokeColor = PSUColors.leadWire.withAlphaComponent(0.4)
        legs.lineWidth = 2
        container.addChild(legs)

        return container
    }

    /// Create inductor coil with ferrite core
    private func createInductorCoil(themeColor: UIColor) -> SKNode {
        let container = SKNode()
        let width: CGFloat = 55
        let height: CGFloat = 35

        // Ferrite core (dark block)
        let corePath = CGMutablePath()
        corePath.addRoundedRect(in: CGRect(x: -width/2, y: -height/2, width: width, height: height),
                                 cornerWidth: 6, cornerHeight: 6)

        // Add shadow
        addComponentShadow(to: container, shape: corePath, offset: CGPoint(x: 3, y: -3), alpha: 0.1)

        let core = SKShapeNode(path: corePath)
        core.fillColor = PSUColors.ferriteCore
        core.strokeColor = themeColor.withAlphaComponent(0.08)
        core.lineWidth = 1
        container.addChild(core)

        // Copper windings (all in single path)
        let windings = SKShapeNode()
        let windingsPath = CGMutablePath()
        for i in 0..<6 {
            let x = -width/2 + 8 + CGFloat(i) * 8
            windingsPath.move(to: CGPoint(x: x, y: height/2 - 5))
            windingsPath.addLine(to: CGPoint(x: x + 5, y: -height/2 + 5))
        }
        windings.path = windingsPath
        windings.strokeColor = PSUColors.copper.withAlphaComponent(0.25)
        windings.lineWidth = 2
        container.addChild(windings)

        return container
    }

    /// Create small ceramic capacitor
    private func createCeramicCapacitor() -> SKNode {
        let container = SKNode()
        let width: CGFloat = 10
        let height: CGFloat = 6

        // Main body with end caps (all in single node for efficiency)
        let body = SKShapeNode()
        let bodyPath = CGMutablePath()
        bodyPath.addRoundedRect(in: CGRect(x: -width/2, y: -height/2, width: width, height: height),
                                 cornerWidth: 1, cornerHeight: 1)

        // Tiny shadow for small components
        addComponentShadow(to: container, shape: bodyPath, offset: CGPoint(x: 1, y: -1), alpha: 0.08)

        body.path = bodyPath
        body.fillColor = PSUColors.ceramicBody.withAlphaComponent(0.2)
        body.strokeColor = PSUColors.ceramicBody.withAlphaComponent(0.15)
        body.lineWidth = 0.5
        container.addChild(body)

        // End caps overlay (combined into single path)
        let endCapWidth: CGFloat = 2
        let endCaps = SKShapeNode()
        let endCapsPath = CGMutablePath()
        endCapsPath.addRect(CGRect(x: -width/2, y: -height/2, width: endCapWidth, height: height))
        endCapsPath.addRect(CGRect(x: width/2 - endCapWidth, y: -height/2, width: endCapWidth, height: height))
        endCaps.path = endCapsPath
        endCaps.fillColor = PSUColors.ceramicBody.withAlphaComponent(0.25)
        endCaps.strokeColor = .clear
        container.addChild(endCaps)

        return container
    }

    // MARK: - PCB Trace Helper

    /// Draw a single PCB trace path
    /// - Parameters:
    ///   - points: Array of (x, y) offsets from sector origin
    ///   - node: Parent node to add trace to
    ///   - baseX/baseY: Sector world origin
    ///   - zPos: Z position for layering
    ///   - lineWidth: Trace thickness (6pt for main, 3pt for secondary)
    ///   - alpha: Copper color alpha (0.15 for main, 0.1 for secondary)
    private func drawPCBTrace(points: [(x: CGFloat, y: CGFloat)], to node: SKNode,
                              baseX: CGFloat, baseY: CGFloat, zPos: CGFloat,
                              lineWidth: CGFloat, alpha: CGFloat) {
        guard !points.isEmpty else { return }
        let tracePath = CGMutablePath()
        for (index, point) in points.enumerated() {
            let pos = CGPoint(x: baseX + point.x, y: baseY + point.y)
            if index == 0 {
                tracePath.move(to: pos)
            } else {
                tracePath.addLine(to: pos)
            }
        }
        let traceNode = SKShapeNode(path: tracePath)
        traceNode.strokeColor = PSUColors.copper.withAlphaComponent(alpha)
        traceNode.lineWidth = lineWidth
        traceNode.lineCap = .round
        traceNode.lineJoin = .round
        traceNode.zPosition = zPos
        node.addChild(traceNode)
    }

    /// Add PCB power traces connecting PSU components
    private func addPSUTraces(to node: SKNode, baseX: CGFloat, baseY: CGFloat, zPos: CGFloat) {
        // Main power traces (thick, connecting major components)
        let mainTraces: [[(x: CGFloat, y: CGFloat)]] = [
            // Trace from transformer to 24-pin connector
            [(x: 725, y: 400), (x: 900, y: 350), (x: 1100, y: 200), (x: 1200, y: 175)],
            // Trace from transformer to caps
            [(x: 575, y: 400), (x: 400, y: 380), (x: 200, y: 340)],
            // Vertical trace
            [(x: 650, y: 500), (x: 650, y: 700), (x: 400, y: 850), (x: 300, y: 950)]
        ]

        for trace in mainTraces {
            drawPCBTrace(points: trace, to: node, baseX: baseX, baseY: baseY,
                        zPos: zPos, lineWidth: 6, alpha: 0.15)
        }

        // Secondary traces (thinner)
        let secondaryTraces: [[(x: CGFloat, y: CGFloat)]] = [
            [(x: 280, y: 620), (x: 350, y: 620)],  // Between MOSFETs
            [(x: 500, y: 250), (x: 580, y: 280), (x: 650, y: 340)],  // Inductors to transformer
            [(x: 850, y: 300), (x: 780, y: 350), (x: 725, y: 380)]   // Other inductor
        ]

        for trace in secondaryTraces {
            drawPCBTrace(points: trace, to: node, baseX: baseX, baseY: baseY,
                        zPos: zPos, lineWidth: 3, alpha: 0.1)
        }
    }

    /// Trigger capacitor discharge effect (call when nearby tower fires)
    /// Now creates a subtle pulse on nearby electrolytic capacitors
    func triggerCapacitorDischarge(near position: CGPoint) {
        // Rate limit: max 1 discharge per 0.5 seconds (reduced frequency)
        let currentTime = CACurrentMediaTime()
        guard currentTime - lastCapacitorDischargeTime > 0.5 else { return }
        lastCapacitorDischargeTime = currentTime

        // Find capacitors near the position
        for container in psuCapacitorNodes {
            let distance = hypot(container.position.x - position.x,
                                container.position.y - position.y)

            // Only affect capacitors within 300 points
            guard distance < 300 else { continue }

            // Use separate dischargeGlow node (doesn't conflict with breathing animation)
            if let dischargeGlow = container.childNode(withName: "dischargeGlow") as? SKShapeNode {
                let pulseUp = SKAction.customAction(withDuration: 0.1) { [weak dischargeGlow] _, elapsed in
                    let progress = elapsed / 0.1
                    dischargeGlow?.fillColor = PSUColors.theme.withAlphaComponent(0.2 * progress)
                }
                let pulseDown = SKAction.customAction(withDuration: 0.2) { [weak dischargeGlow] _, elapsed in
                    let progress = elapsed / 0.2
                    dischargeGlow?.fillColor = PSUColors.theme.withAlphaComponent(0.2 * (1 - progress))
                }
                dischargeGlow.run(SKAction.sequence([pulseUp, pulseDown]), withKey: "discharge")
            }
        }
    }

    // MARK: - Power Flow Particles

    /// Start the ambient power flow particle system for the PSU lane
    /// Called once during motherboard setup
    private func startPowerFlowParticles() {
        guard !powerFlowEmitterRunning else { return }
        powerFlowEmitterRunning = true

        // Get PSU lane path
        let lanes = MotherboardLaneConfig.createAllLanes()
        guard let psuLane = lanes.first(where: { $0.sectorId == SectorID.power.rawValue }) else { return }

        // Schedule repeating spawn action
        let spawnInterval: TimeInterval = 1.0  // Spawn every 1 second

        let spawnAction = SKAction.run { [weak self] in
            self?.spawnPowerFlowParticle(along: psuLane.path)
        }

        let wait = SKAction.wait(forDuration: spawnInterval)
        let sequence = SKAction.sequence([spawnAction, wait])

        pathLayer.run(SKAction.repeatForever(sequence), withKey: "powerFlowEmitter")
    }

    /// Spawn a single power flow particle that travels along the PSU path toward CPU
    private func spawnPowerFlowParticle(along path: EnemyPath) {
        guard path.waypoints.count >= 2 else { return }

        let psuYellow = UIColor(hex: "#ffdd00") ?? UIColor.yellow

        // Create the particle
        let particle = SKShapeNode(circleOfRadius: 3)
        particle.fillColor = psuYellow.withAlphaComponent(0.7)
        particle.strokeColor = psuYellow
        particle.lineWidth = 1
        particle.glowWidth = 4
        particle.blendMode = .add
        particle.zPosition = 6
        particle.name = "powerParticle"

        // Start at the PSU spawn point
        let startPoint = convertToScene(path.waypoints[0])
        particle.position = startPoint
        pathLayer.addChild(particle)

        // Determine travel speed based on combat state
        // Base travel time: 2.5 seconds, speeds up 2x during combat
        let hasCombat = (state?.enemies.count ?? 0) > 0
        let travelTime: TimeInterval = hasCombat ? 1.25 : 2.5

        // Build path following action
        var actions: [SKAction] = []

        for i in 0..<(path.waypoints.count - 1) {
            let from = convertToScene(path.waypoints[i])
            let to = convertToScene(path.waypoints[i + 1])

            let dx = to.x - from.x
            let dy = to.y - from.y
            let segmentLength = sqrt(dx * dx + dy * dy)

            // Calculate segment time proportional to total travel time
            let totalLength = calculatePathLength(path)
            let segmentTime = travelTime * (segmentLength / totalLength)

            actions.append(SKAction.move(to: to, duration: segmentTime))
        }

        // Fade out and remove at the end
        actions.append(SKAction.fadeOut(withDuration: 0.2))
        actions.append(SKAction.removeFromParent())

        particle.run(SKAction.sequence(actions))
    }

    /// Calculate total length of a path
    private func calculatePathLength(_ path: EnemyPath) -> CGFloat {
        var totalLength: CGFloat = 0
        for i in 0..<(path.waypoints.count - 1) {
            let from = path.waypoints[i]
            let to = path.waypoints[i + 1]
            let dx = to.x - from.x
            let dy = to.y - from.y
            totalLength += sqrt(dx * dx + dy * dy)
        }
        return max(1, totalLength)  // Avoid division by zero
    }

    // MARK: - Trace Pulse Effects

    /// Spawn a trace pulse when a tower fires - travels along the copper trace toward CPU
    private func spawnTracePulse(at towerPosition: CGPoint, color: UIColor) {
        // Find the nearest lane to this tower position
        let lanes = MotherboardLaneConfig.createAllLanes()
        let unlockedSectorIds = gameStateDelegate?.getUnlockedSectorIds() ?? Set([SectorID.power.rawValue])

        var nearestLane: SectorLane?
        var nearestDistance: CGFloat = .infinity

        for lane in lanes {
            // Only consider unlocked lanes
            guard lane.isStarterLane || unlockedSectorIds.contains(lane.sectorId) else { continue }

            // Find closest point on this lane's path
            for waypoint in lane.path.waypoints {
                let dx = waypoint.x - towerPosition.x
                let dy = waypoint.y - towerPosition.y
                let distance = sqrt(dx * dx + dy * dy)
                if distance < nearestDistance {
                    nearestDistance = distance
                    nearestLane = lane
                }
            }
        }

        guard let lane = nearestLane, nearestDistance < 200 else { return }

        // Create the pulse node
        let pulseContainer = SKNode()
        pulseContainer.position = convertToScene(towerPosition)
        pulseContainer.zPosition = 8
        pulseContainer.name = "tracePulse"

        // Bright center
        let core = SKShapeNode(circleOfRadius: 10)
        core.fillColor = color.withAlphaComponent(0.9)
        core.strokeColor = color
        core.lineWidth = 2
        core.glowWidth = 12
        core.blendMode = .add
        core.name = "core"
        pulseContainer.addChild(core)

        // Expanding ring
        let ring = SKShapeNode(circleOfRadius: 6)
        ring.fillColor = .clear
        ring.strokeColor = color.withAlphaComponent(0.6)
        ring.lineWidth = 3
        ring.glowWidth = 4
        ring.blendMode = .add
        ring.name = "ring"
        pulseContainer.addChild(ring)

        pathLayer.addChild(pulseContainer)

        // Animate ring expansion
        let ringExpand = SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 3.0, duration: 0.3),
                SKAction.fadeOut(withDuration: 0.3)
            ]),
            SKAction.removeFromParent()
        ])
        ring.run(ringExpand)

        // Build path to CPU (find closest point on lane path and animate from there)
        let cpuCenter = convertToScene(MotherboardLaneConfig.cpuCenter)

        // Find the segment of the path closest to the tower
        var closestSegmentIndex = 0
        var closestT: CGFloat = 0
        var closestDistance: CGFloat = .infinity

        for i in 0..<(lane.path.waypoints.count - 1) {
            let a = convertToScene(lane.path.waypoints[i])
            let b = convertToScene(lane.path.waypoints[i + 1])
            let (t, dist) = closestPointOnSegment(point: pulseContainer.position, segmentStart: a, segmentEnd: b)

            if dist < closestDistance {
                closestDistance = dist
                closestSegmentIndex = i
                closestT = t
            }
        }

        // Build move actions from current position through remaining waypoints to CPU
        var actions: [SKAction] = []
        let travelSpeed: CGFloat = 600  // Points per second

        // First move to the closest point on the path
        let startA = convertToScene(lane.path.waypoints[closestSegmentIndex])
        let startB = convertToScene(lane.path.waypoints[closestSegmentIndex + 1])
        let pathPoint = CGPoint(x: startA.x + (startB.x - startA.x) * closestT,
                                y: startA.y + (startB.y - startA.y) * closestT)

        let distToPath = distance(from: pulseContainer.position, to: pathPoint)
        if distToPath > 1 {
            actions.append(SKAction.move(to: pathPoint, duration: Double(distToPath / travelSpeed)))
        }

        // Then follow the path toward CPU
        for i in (closestSegmentIndex + 1)..<lane.path.waypoints.count {
            let waypoint = convertToScene(lane.path.waypoints[i])
            let prevPoint = i == closestSegmentIndex + 1 ? pathPoint : convertToScene(lane.path.waypoints[i - 1])
            let dist = distance(from: prevPoint, to: waypoint)
            actions.append(SKAction.move(to: waypoint, duration: Double(dist / travelSpeed)))
        }

        // Fade while moving
        let totalDuration = actions.reduce(0) { $0 + $1.duration }
        let fadeAction = SKAction.fadeOut(withDuration: totalDuration)

        // Core shrinks as it travels
        let shrinkAction = SKAction.scale(to: 0.3, duration: totalDuration)

        // Run all actions
        pulseContainer.run(SKAction.sequence([
            SKAction.group([
                SKAction.sequence(actions),
                fadeAction,
                shrinkAction
            ]),
            SKAction.removeFromParent()
        ]))
    }

    /// Find closest point on a line segment to a given point
    private func closestPointOnSegment(point: CGPoint, segmentStart: CGPoint, segmentEnd: CGPoint) -> (t: CGFloat, distance: CGFloat) {
        let dx = segmentEnd.x - segmentStart.x
        let dy = segmentEnd.y - segmentStart.y
        let lengthSquared = dx * dx + dy * dy

        if lengthSquared == 0 {
            return (0, distance(from: point, to: segmentStart))
        }

        let t = max(0, min(1, ((point.x - segmentStart.x) * dx + (point.y - segmentStart.y) * dy) / lengthSquared))
        let closestPoint = CGPoint(x: segmentStart.x + t * dx, y: segmentStart.y + t * dy)
        return (t, distance(from: point, to: closestPoint))
    }

    /// Simple distance helper
    private func distance(from a: CGPoint, to b: CGPoint) -> CGFloat {
        let dx = b.x - a.x
        let dy = b.y - a.y
        return sqrt(dx * dx + dy * dy)
    }

    // MARK: - Voltage Arc Effects

    /// Start the ambient voltage arc system for PSU sector
    /// Creates random electric arcs between components
    private func startVoltageArcSystem() {
        guard isMotherboardMap else { return }

        // PSU sector bounds (grid position 2,1 = world x: 2800-4200, y: 1400-2800)
        let psuSectorMinX: CGFloat = 2800
        let psuSectorMaxX: CGFloat = 4200
        let psuSectorMinY: CGFloat = 1400
        let psuSectorMaxY: CGFloat = 2800

        // Arc anchor points within PSU sector (capacitors, traces, etc.)
        let arcAnchors = [
            CGPoint(x: 3000, y: 1800),   // Capacitor 1 area
            CGPoint(x: 3200, y: 1600),   // Capacitor 2 area
            CGPoint(x: 3800, y: 2200),   // Capacitor 3 area
            CGPoint(x: 3400, y: 2000),   // Trace junction
            CGPoint(x: 3600, y: 1700),   // Trace junction
            CGPoint(x: 3100, y: 2400),   // Near path
        ]

        // Schedule random arc generation
        let createArc = SKAction.run { [weak self] in
            guard let self = self else { return }

            // Pick two random anchor points
            guard arcAnchors.count >= 2 else { return }
            var indices = Array(0..<arcAnchors.count).shuffled()
            let startIdx = indices.removeFirst()
            let endIdx = indices.removeFirst()

            let startPoint = arcAnchors[startIdx]
            let endPoint = arcAnchors[endIdx]

            self.spawnVoltageArc(from: startPoint, to: endPoint)
        }

        // Random interval between 8-15 seconds (reduced frequency for subtler effect)
        let waitAction = SKAction.run { [weak self] in
            guard let self = self else { return }
            let delay = TimeInterval.random(in: 8.0...15.0)
            self.pathLayer.run(SKAction.sequence([
                SKAction.wait(forDuration: delay),
                createArc,
                SKAction.run { self.scheduleNextArc() }
            ]), withKey: "voltageArcSchedule")
        }

        // Start the first arc after a short delay
        pathLayer.run(SKAction.sequence([
            SKAction.wait(forDuration: 2.0),
            createArc,
            waitAction
        ]), withKey: "voltageArcInit")
    }

    /// Schedule the next voltage arc
    private func scheduleNextArc() {
        guard isMotherboardMap else { return }

        let arcAnchors = [
            CGPoint(x: 3000, y: 1800),
            CGPoint(x: 3200, y: 1600),
            CGPoint(x: 3800, y: 2200),
            CGPoint(x: 3400, y: 2000),
            CGPoint(x: 3600, y: 1700),
            CGPoint(x: 3100, y: 2400),
        ]

        let createArc = SKAction.run { [weak self] in
            guard let self = self, arcAnchors.count >= 2 else { return }
            var indices = Array(0..<arcAnchors.count).shuffled()
            let startIdx = indices.removeFirst()
            let endIdx = indices.removeFirst()
            self.spawnVoltageArc(from: arcAnchors[startIdx], to: arcAnchors[endIdx])
        }

        let delay = TimeInterval.random(in: 8.0...15.0)  // Reduced frequency
        pathLayer.run(SKAction.sequence([
            SKAction.wait(forDuration: delay),
            createArc,
            SKAction.run { [weak self] in self?.scheduleNextArc() }
        ]), withKey: "voltageArcSchedule")
    }

    /// Spawn a single voltage arc between two points (subtle, toned down)
    private func spawnVoltageArc(from start: CGPoint, to end: CGPoint) {
        let startScene = convertToScene(start)
        let endScene = convertToScene(end)

        // Create jagged lightning path
        let arcPath = createLightningPath(from: startScene, to: endScene, segments: Int.random(in: 2...3))

        let arc = SKShapeNode(path: arcPath)
        arc.strokeColor = UIColor.yellow.withAlphaComponent(0.4)  // Dimmer
        arc.lineWidth = 1  // Thinner
        arc.glowWidth = 3  // Reduced glow
        arc.blendMode = .add
        arc.zPosition = -2.5  // Behind gameplay elements
        arc.name = "voltageArc"
        pathLayer.addChild(arc)

        // Quick flash and fade (shorter, subtler)
        let flashSequence = SKAction.sequence([
            SKAction.run { arc.glowWidth = 5 },
            SKAction.wait(forDuration: 0.02),
            SKAction.run { arc.glowWidth = 2 },
            SKAction.wait(forDuration: 0.03),
            SKAction.fadeOut(withDuration: 0.08),
            SKAction.removeFromParent()
        ])

        arc.run(flashSequence)

        // NOTE: Endpoint sparks removed for cleaner aesthetic
    }

    /// Create a jagged lightning bolt path between two points
    private func createLightningPath(from start: CGPoint, to end: CGPoint, segments: Int) -> CGPath {
        let path = CGMutablePath()
        path.move(to: start)

        let dx = end.x - start.x
        let dy = end.y - start.y
        let perpX = -dy
        let perpY = dx
        let perpLength = sqrt(perpX * perpX + perpY * perpY)
        let normPerpX = perpX / max(1, perpLength)
        let normPerpY = perpY / max(1, perpLength)

        for i in 1..<segments {
            let t = CGFloat(i) / CGFloat(segments)
            let baseX = start.x + dx * t
            let baseY = start.y + dy * t

            // Random perpendicular offset for jagged effect
            let offset = CGFloat.random(in: -20...20)
            let pointX = baseX + normPerpX * offset
            let pointY = baseY + normPerpY * offset

            path.addLine(to: CGPoint(x: pointX, y: pointY))
        }

        path.addLine(to: end)
        return path
    }

    /// Spawn a small spark effect at arc endpoint
    private func spawnArcSpark(at position: CGPoint) {
        let spark = SKShapeNode(circleOfRadius: 4)
        spark.position = position
        spark.fillColor = UIColor.white.withAlphaComponent(0.9)
        spark.strokeColor = .clear
        spark.glowWidth = 8
        spark.blendMode = .add
        spark.zPosition = 8
        pathLayer.addChild(spark)

        let sparkAnim = SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 2.0, duration: 0.05),
                SKAction.fadeAlpha(to: 0.5, duration: 0.05)
            ]),
            SKAction.group([
                SKAction.scale(to: 0.5, duration: 0.1),
                SKAction.fadeOut(withDuration: 0.1)
            ]),
            SKAction.removeFromParent()
        ])
        spark.run(sparkAnim)
    }

    // MARK: - Context-Aware Screen Shake System

    /// Trigger screen shake with context-aware constraints
    /// Only shakes when zoomed in, respects cooldown, and checks visibility
    /// - Parameters:
    ///   - intensity: Shake magnitude in points (6-10 for major events)
    ///   - duration: How long the shake lasts
    ///   - position: Optional world position - only shakes if visible on screen
    func triggerScreenShake(intensity: CGFloat, duration: TimeInterval, position: CGPoint? = nil) {
        guard let camera = cameraNode else { return }

        // RULE 1: Only shake when zoomed in (scale < 0.6)
        // When zoomed out, player is in "strategic view" and shake is jarring
        guard currentScale < 0.6 else { return }

        // RULE 2: If position provided, only shake if position is visible on screen
        if let pos = position {
            let scenePos = convertToScene(pos)
            if !isPositionVisible(scenePos) { return }
        }

        // RULE 3: Cooldown - max 1 shake per screenShakeCooldown seconds
        let currentTime = lastUpdateTime
        guard currentTime - lastShakeTime >= screenShakeCooldown else { return }
        lastShakeTime = currentTime

        // RULE 4: Don't start new shake if already shaking
        guard !isShaking else { return }

        isShaking = true
        originalCameraPosition = camera.position

        // Create shake sequence with decay
        let shakeCount = Int(duration / 0.03)  // ~30 shakes per second
        var shakeActions: [SKAction] = []

        for i in 0..<shakeCount {
            let progress = CGFloat(i) / CGFloat(shakeCount)
            let decayMultiplier = 1.0 - progress  // Linear decay

            let offsetX = CGFloat.random(in: -1...1) * intensity * decayMultiplier
            let offsetY = CGFloat.random(in: -1...1) * intensity * decayMultiplier

            let shakeAction = SKAction.run { [weak self] in
                guard let self = self, let camera = self.cameraNode else { return }
                camera.position = CGPoint(
                    x: self.originalCameraPosition.x + offsetX,
                    y: self.originalCameraPosition.y + offsetY
                )
            }
            shakeActions.append(shakeAction)
            shakeActions.append(SKAction.wait(forDuration: 0.03))
        }

        // Return to original position
        let resetAction = SKAction.run { [weak self] in
            guard let self = self, let camera = self.cameraNode else { return }
            camera.position = self.originalCameraPosition
            self.isShaking = false
        }
        shakeActions.append(resetAction)

        camera.run(SKAction.sequence(shakeActions), withKey: "screenShake")
    }

    /// Check if a scene position is visible in the current camera view
    private func isPositionVisible(_ scenePosition: CGPoint) -> Bool {
        guard let camera = cameraNode, let view = self.view else { return false }

        let viewWidth = view.bounds.width * currentScale
        let viewHeight = view.bounds.height * currentScale

        let visibleRect = CGRect(
            x: camera.position.x - viewWidth / 2,
            y: camera.position.y - viewHeight / 2,
            width: viewWidth,
            height: viewHeight
        )

        return visibleRect.contains(scenePosition)
    }

    /// Flash a color overlay on the screen (for impacts, damage, boss events)
    /// - Parameters:
    ///   - color: The flash color
    ///   - alpha: Maximum opacity of the flash (0.15-0.3 typical)
    ///   - duration: Total flash duration
    func flashOverlay(color: UIColor, alpha: CGFloat = 0.15, duration: TimeInterval = 0.15) {
        guard let camera = cameraNode, let view = self.view else { return }

        // Create full-screen overlay attached to camera
        let overlaySize = CGSize(
            width: view.bounds.width * currentScale * 2,
            height: view.bounds.height * currentScale * 2
        )
        let overlay = SKShapeNode(rectOf: overlaySize)
        overlay.position = .zero  // Centered on camera
        overlay.fillColor = color
        overlay.strokeColor = .clear
        overlay.alpha = 0
        overlay.zPosition = 1000  // Above everything
        overlay.name = "flashOverlay"

        camera.addChild(overlay)

        // Flash animation: quick fade in, slower fade out
        let flashIn = SKAction.fadeAlpha(to: alpha, duration: duration * 0.2)
        let flashOut = SKAction.fadeOut(withDuration: duration * 0.8)
        let remove = SKAction.removeFromParent()

        overlay.run(SKAction.sequence([flashIn, flashOut, remove]))
    }

    /// Trigger boss entrance effects (warning rings + shake + flash)
    func triggerBossEntranceEffect(at position: CGPoint, bossColor: UIColor = .red) {
        let scenePos = convertToScene(position)

        // 1. Warning rings expanding outward
        for i in 0..<3 {
            let delay = TimeInterval(i) * 0.15
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.spawnWarningRing(at: scenePos, color: bossColor, delay: 0)
            }
        }

        // 2. Screen shake (intensity 6, boss entrance)
        triggerScreenShake(intensity: 6, duration: 0.25, position: position)

        // 3. Flash overlay (yellow for power theme, or boss color)
        flashOverlay(color: .yellow, alpha: 0.2, duration: 0.2)
    }

    /// Trigger boss death effects (massive explosion + rings + shake)
    func triggerBossDeathEffect(at position: CGPoint, bossColor: UIColor = .red) {
        let scenePos = convertToScene(position)

        // 1. Massive particle explosion (50 particles)
        spawnBossDeathExplosion(at: scenePos, color: bossColor)

        // 2. Multiple expanding rings with stagger
        for i in 0..<5 {
            let delay = TimeInterval(i) * 0.1
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.spawnDeathRing(at: scenePos, color: bossColor, scale: 1.0 + CGFloat(i) * 0.3)
            }
        }

        // 3. Screen shake (intensity 8, boss death is major event)
        triggerScreenShake(intensity: 8, duration: 0.35, position: position)

        // 4. Flash overlay (boss color)
        flashOverlay(color: bossColor, alpha: 0.25, duration: 0.25)
    }

    /// Spawn expanding warning ring for boss entrance
    private func spawnWarningRing(at position: CGPoint, color: UIColor, delay: TimeInterval) {
        let ring = SKShapeNode(circleOfRadius: 20)
        ring.position = position
        ring.fillColor = .clear
        ring.strokeColor = color.withAlphaComponent(0.8)
        ring.lineWidth = 4
        ring.glowWidth = 6
        ring.blendMode = .add
        ring.zPosition = 100
        ring.setScale(0.5)
        particleLayer.addChild(ring)

        let expandAndFade = SKAction.group([
            SKAction.scale(to: 8.0, duration: 0.6),
            SKAction.sequence([
                SKAction.wait(forDuration: 0.3),
                SKAction.fadeOut(withDuration: 0.3)
            ])
        ])
        let remove = SKAction.removeFromParent()

        ring.run(SKAction.sequence([
            SKAction.wait(forDuration: delay),
            expandAndFade,
            remove
        ]))
    }

    /// Spawn death ring for boss death effect
    private func spawnDeathRing(at position: CGPoint, color: UIColor, scale: CGFloat) {
        let ring = SKShapeNode(circleOfRadius: 30)
        ring.position = position
        ring.fillColor = .clear
        ring.strokeColor = color.withAlphaComponent(0.9)
        ring.lineWidth = 6
        ring.glowWidth = 10
        ring.blendMode = .add
        ring.zPosition = 100

        particleLayer.addChild(ring)

        let expandAndFade = SKAction.group([
            SKAction.scale(to: scale * 6.0, duration: 0.5),
            SKAction.fadeOut(withDuration: 0.5)
        ])
        let remove = SKAction.removeFromParent()

        ring.run(SKAction.sequence([expandAndFade, remove]))
    }

    /// Spawn massive particle explosion for boss death
    private func spawnBossDeathExplosion(at position: CGPoint, color: UIColor) {
        let particleCount = 50

        for _ in 0..<particleCount {
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let speed = CGFloat.random(in: 80...200)
            let size = CGFloat.random(in: 4...10)

            let particle = SKShapeNode(circleOfRadius: size)
            particle.position = position
            particle.fillColor = color.withAlphaComponent(0.9)
            particle.strokeColor = .white.withAlphaComponent(0.5)
            particle.lineWidth = 1
            particle.glowWidth = size
            particle.blendMode = .add
            particle.zPosition = 101

            particleLayer.addChild(particle)

            let velocity = CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed)
            let duration = TimeInterval.random(in: 0.5...1.0)

            let move = SKAction.move(by: velocity, duration: duration)
            move.timingMode = .easeOut

            let fadeAndShrink = SKAction.group([
                SKAction.fadeOut(withDuration: duration),
                SKAction.scale(to: 0.2, duration: duration)
            ])

            let remove = SKAction.removeFromParent()

            particle.run(SKAction.sequence([
                SKAction.group([move, fadeAndShrink]),
                remove
            ]))
        }
    }

    /// Trigger player damage flash (red overlay)
    func triggerDamageFlash() {
        // Only flash when zoomed in
        guard currentScale < 0.6 else { return }
        flashOverlay(color: .red, alpha: 0.15, duration: 0.2)

        // Optional: small shake for damage (intensity 3)
        triggerScreenShake(intensity: 3, duration: 0.15, position: nil)
    }

    /// Add heat sink pattern for GPU sector
    private func addHeatSinkPattern(to node: SKNode, in sector: MegaBoardSector, color: UIColor) {
        // PERFORMANCE OPTIMIZED: Batched paths for GPU district
        let baseX = sector.worldX
        let baseY = sector.worldY
        let width = sector.width
        let height = sector.height
        let zPos: CGFloat = 3

        func isNearLane(_ x: CGFloat, _ y: CGFloat) -> Bool {
            if y > 500 && y < 900 && x > 300 && x < 1100 { return true }
            if x > 1000 && y > 400 && y < 700 { return true }
            return false
        }

        let heatSinkColor = UIColor(red: 0.25, green: 0.25, blue: 0.30, alpha: 1.0)
        let vramColor = UIColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 1.0)
        let thermalPadColor = UIColor(red: 0.4, green: 0.35, blue: 0.5, alpha: 0.6)
        let copperColor = UIColor(hex: "#b87333") ?? .orange

        // Pre-generate positions
        var vramPositions: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat)] = []
        var thermalPositions: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat)] = []
        var vrmPositions: [(x: CGFloat, y: CGFloat)] = []
        var capPositions: [(x: CGFloat, y: CGFloat, r: CGFloat)] = []
        var heatSinkData: [(x: CGFloat, y: CGFloat, finCount: Int, finW: CGFloat, finH: CGFloat)] = []

        for _ in 0..<25 {
            let x = CGFloat.random(in: 60...(width - 60))
            let y = CGFloat.random(in: 60...(height - 60))
            if !isNearLane(x, y) {
                vramPositions.append((x, y, CGFloat.random(in: 28...42), CGFloat.random(in: 22...32)))
            }
        }
        for _ in 0..<20 {
            let x = CGFloat.random(in: 50...(width - 50))
            let y = CGFloat.random(in: 50...(height - 50))
            if !isNearLane(x, y) {
                thermalPositions.append((x, y, CGFloat.random(in: 18...35), CGFloat.random(in: 18...35)))
            }
        }
        for _ in 0..<10 {
            let x = CGFloat.random(in: 100...(width - 100))
            let y = CGFloat.random(in: 100...(height - 100))
            if !isNearLane(x, y) { vrmPositions.append((x, y)) }
        }
        for _ in 0..<50 {
            let x = CGFloat.random(in: 40...(width - 40))
            let y = CGFloat.random(in: 40...(height - 40))
            if !isNearLane(x, y) { capPositions.append((x, y, CGFloat.random(in: 4...7))) }
        }
        for _ in 0..<10 {
            let x = CGFloat.random(in: 80...(width - 80))
            let y = CGFloat.random(in: 80...(height - 80))
            if !isNearLane(x, y) {
                heatSinkData.append((x, y, Int.random(in: 10...14), CGFloat.random(in: 4...5), CGFloat.random(in: 50...80)))
            }
        }

        // ========== BATCHED THERMAL PADS ==========
        let thermalPath = CGMutablePath()
        for pos in thermalPositions {
            thermalPath.addRect(CGRect(x: baseX + pos.x - pos.w/2, y: baseY + pos.y - pos.h/2, width: pos.w, height: pos.h))
        }
        let thermalNode = SKShapeNode(path: thermalPath)
        thermalNode.fillColor = thermalPadColor
        thermalNode.strokeColor = .clear
        thermalNode.zPosition = zPos - 0.2
        node.addChild(thermalNode)

        // ========== BATCHED VRAM CHIPS ==========
        let vramPath = CGMutablePath()
        for pos in vramPositions {
            vramPath.addRoundedRect(in: CGRect(x: baseX + pos.x - pos.w/2, y: baseY + pos.y - pos.h/2, width: pos.w, height: pos.h), cornerWidth: 2, cornerHeight: 2)
        }
        let vramNode = SKShapeNode(path: vramPath)
        vramNode.fillColor = vramColor
        vramNode.strokeColor = color.withAlphaComponent(0.4)
        vramNode.lineWidth = 0.5
        vramNode.zPosition = zPos - 0.1
        node.addChild(vramNode)

        // ========== BATCHED VRMs ==========
        let vrmPath = CGMutablePath()
        for pos in vrmPositions {
            vrmPath.addRect(CGRect(x: baseX + pos.x - 8, y: baseY + pos.y - 12, width: 16, height: 24))
        }
        let vrmNode = SKShapeNode(path: vrmPath)
        vrmNode.fillColor = UIColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 1.0)
        vrmNode.strokeColor = copperColor.withAlphaComponent(0.3)
        vrmNode.lineWidth = 0.5
        vrmNode.zPosition = zPos - 0.1
        node.addChild(vrmNode)

        // ========== BATCHED CAPACITORS ==========
        let capPath = CGMutablePath()
        for pos in capPositions {
            capPath.addEllipse(in: CGRect(x: baseX + pos.x - pos.r, y: baseY + pos.y - pos.r, width: pos.r * 2, height: pos.r * 2))
        }
        let capNode = SKShapeNode(path: capPath)
        capNode.fillColor = UIColor(red: 0.15, green: 0.15, blue: 0.18, alpha: 1.0)
        capNode.strokeColor = color.withAlphaComponent(0.15)
        capNode.lineWidth = 0.5
        capNode.zPosition = zPos - 0.3
        node.addChild(capNode)

        // ========== HEAT SINKS (batched fins per sink) ==========
        for hs in heatSinkData {
            let finsPath = CGMutablePath()
            let spacing = hs.finW + 3
            let totalW = CGFloat(hs.finCount) * spacing
            for f in 0..<hs.finCount {
                let fx = baseX + hs.x - totalW/2 + CGFloat(f) * spacing
                finsPath.addRect(CGRect(x: fx, y: baseY + hs.y - hs.finH/2, width: hs.finW, height: hs.finH))
            }
            let finsNode = SKShapeNode(path: finsPath)
            finsNode.fillColor = heatSinkColor
            finsNode.strokeColor = color.withAlphaComponent(0.2)
            finsNode.lineWidth = 0.5
            finsNode.zPosition = zPos
            node.addChild(finsNode)
        }

        // ========== GPU DIE (individual - 2 units) ==========
        let gpuDiePositions: [(x: CGFloat, y: CGFloat, label: String)] = [(350, 300, "GPU"), (900, 950, "VRAM")]
        for pos in gpuDiePositions {
            if !isNearLane(pos.x, pos.y) {
                let dieSize: CGFloat = 90
                let die = SKShapeNode(rect: CGRect(x: -dieSize/2, y: -dieSize/2, width: dieSize, height: dieSize), cornerRadius: 3)
                die.position = CGPoint(x: baseX + pos.x, y: baseY + pos.y)
                die.fillColor = UIColor(red: 0.12, green: 0.12, blue: 0.15, alpha: 1.0)
                die.strokeColor = color
                die.lineWidth = 2
                die.zPosition = zPos + 0.2
                node.addChild(die)

                let label = SKLabelNode(text: pos.label)
                label.fontName = "Menlo-Bold"
                label.fontSize = 12
                label.fontColor = color.withAlphaComponent(0.7)
                label.position = CGPoint(x: baseX + pos.x, y: baseY + pos.y)
                label.horizontalAlignmentMode = .center
                label.verticalAlignmentMode = .center
                label.zPosition = zPos + 0.3
                node.addChild(label)
            }
        }
    }

    /// Add memory chip rows for RAM/Cache sectors - Dense "memory city"
    private func addMemoryChips(to node: SKNode, in sector: MegaBoardSector, color: UIColor) {
        // PERFORMANCE OPTIMIZED: Uses batched paths instead of individual nodes
        let baseX = sector.worldX
        let baseY = sector.worldY
        let width = sector.width
        let height = sector.height
        let zPos: CGFloat = 3

        func isNearLane(_ x: CGFloat, _ y: CGFloat) -> Bool {
            if y > 500 && y < 900 && x > 300 && x < 1100 { return true }
            if x > 1000 && y > 400 && y < 700 { return true }
            return false
        }

        let chipColor = UIColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 1.0)
        let goldColor = UIColor(hex: "#d4a600") ?? .yellow
        let pcbGreen = UIColor(red: 0.05, green: 0.12, blue: 0.08, alpha: 1.0)

        // Pre-generate positions for batching
        var dimmSlots: [(y: CGFloat, slotW: CGFloat, index: Int)] = []
        var contactPositions: [(x: CGFloat, y: CGFloat)] = []
        var dramChips: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat)] = []
        var pinPositions: [(x: CGFloat, y: CGFloat)] = []
        var spdPositions: [(x: CGFloat, y: CGFloat)] = []
        var capPositions: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat)] = []

        // ========== Generate DIMM slot positions ==========
        let dimmSlotY: [CGFloat] = [150, 300, 450, 850, 1000, 1150]
        for (index, slotY) in dimmSlotY.enumerated() {
            if !isNearLane(width/2, slotY) {
                let slotW: CGFloat = width - 200
                dimmSlots.append((y: slotY, slotW: slotW, index: index))
                let contactCount = Int(slotW / 8)
                for c in 0..<contactCount {
                    contactPositions.append((x: 105 + CGFloat(c) * 8, y: slotY + 4))
                }
            }
        }

        // ========== Generate DRAM chip positions ==========
        for _ in 0..<50 {
            let x = CGFloat.random(in: 80...(width - 80))
            let y = CGFloat.random(in: 80...(height - 80))
            guard !isNearLane(x, y) else { continue }
            let chipW = CGFloat.random(in: 30...60)
            let chipH = CGFloat.random(in: 20...35)
            dramChips.append((x: x, y: y, w: chipW, h: chipH))
            let pinCount = Int(chipW / 6)
            for p in 0..<pinCount {
                pinPositions.append((x: x - chipW/2 + 3 + CGFloat(p) * 6, y: y + chipH/2))
                pinPositions.append((x: x - chipW/2 + 3 + CGFloat(p) * 6, y: y - chipH/2 - 4))
            }
        }

        // ========== Generate SPD positions ==========
        for _ in 0..<20 {
            let x = CGFloat.random(in: 100...(width - 100))
            let y = CGFloat.random(in: 100...(height - 100))
            guard !isNearLane(x, y) else { continue }
            spdPositions.append((x: x, y: y))
        }

        // ========== Generate capacitor positions ==========
        for _ in 0..<100 {
            let x = CGFloat.random(in: 40...(width - 40))
            let y = CGFloat.random(in: 40...(height - 40))
            guard !isNearLane(x, y) else { continue }
            let capW = CGFloat.random(in: 4...8)
            let capH = CGFloat.random(in: 3...5)
            capPositions.append((x: x, y: y, w: capW, h: capH))
        }

        // ========== BATCHED DIMM SLOTS ==========
        let slotPath = CGMutablePath()
        for slot in dimmSlots {
            slotPath.addRoundedRect(in: CGRect(x: baseX + 100, y: baseY + slot.y, width: slot.slotW, height: 20), cornerWidth: 2, cornerHeight: 2)
        }
        let slotNode = SKShapeNode(path: slotPath)
        slotNode.fillColor = pcbGreen
        slotNode.strokeColor = color.withAlphaComponent(0.4)
        slotNode.lineWidth = 1
        slotNode.zPosition = zPos - 0.2
        node.addChild(slotNode)

        // ========== BATCHED GOLD CONTACTS ==========
        let contactPath = CGMutablePath()
        for pos in contactPositions {
            contactPath.addRect(CGRect(x: baseX + pos.x, y: baseY + pos.y, width: 4, height: 12))
        }
        let contactNode = SKShapeNode(path: contactPath)
        contactNode.fillColor = goldColor.withAlphaComponent(0.5)
        contactNode.strokeColor = .clear
        contactNode.zPosition = zPos - 0.1
        node.addChild(contactNode)

        // ========== BATCHED DRAM CHIPS ==========
        let chipPath = CGMutablePath()
        for chip in dramChips {
            chipPath.addRoundedRect(in: CGRect(x: baseX + chip.x - chip.w/2, y: baseY + chip.y - chip.h/2, width: chip.w, height: chip.h), cornerWidth: 2, cornerHeight: 2)
        }
        let chipNode = SKShapeNode(path: chipPath)
        chipNode.fillColor = chipColor
        chipNode.strokeColor = color.withAlphaComponent(0.4)
        chipNode.lineWidth = 1
        chipNode.zPosition = zPos
        node.addChild(chipNode)

        // ========== BATCHED CHIP PINS ==========
        let pinPath = CGMutablePath()
        for pos in pinPositions {
            pinPath.addRect(CGRect(x: baseX + pos.x, y: baseY + pos.y, width: 3, height: 4))
        }
        let pinNode = SKShapeNode(path: pinPath)
        pinNode.fillColor = goldColor.withAlphaComponent(0.3)
        pinNode.strokeColor = .clear
        pinNode.zPosition = zPos + 0.1
        node.addChild(pinNode)

        // ========== BATCHED SPD CHIPS ==========
        let spdPath = CGMutablePath()
        for pos in spdPositions {
            spdPath.addRoundedRect(in: CGRect(x: baseX + pos.x - 8, y: baseY + pos.y - 5, width: 16, height: 10), cornerWidth: 1, cornerHeight: 1)
        }
        let spdNode = SKShapeNode(path: spdPath)
        spdNode.fillColor = chipColor
        spdNode.strokeColor = color.withAlphaComponent(0.3)
        spdNode.lineWidth = 0.5
        spdNode.zPosition = zPos - 0.1
        node.addChild(spdNode)

        // ========== BATCHED CAPACITORS ==========
        let capPath = CGMutablePath()
        for pos in capPositions {
            capPath.addRect(CGRect(x: baseX + pos.x - pos.w/2, y: baseY + pos.y - pos.h/2, width: pos.w, height: pos.h))
        }
        let capNode = SKShapeNode(path: capPath)
        capNode.fillColor = UIColor(red: 0.6, green: 0.55, blue: 0.4, alpha: 0.4)
        capNode.strokeColor = .clear
        capNode.zPosition = zPos - 0.3
        node.addChild(capNode)

        // ========== DIMM LABELS (individual - few nodes) ==========
        for slot in dimmSlots {
            let label = SKLabelNode(text: "DIMM\(slot.index + 1)")
            label.fontName = "Menlo"
            label.fontSize = 8
            label.fontColor = color.withAlphaComponent(0.4)
            label.position = CGPoint(x: baseX + 80, y: baseY + slot.y + 5)
            label.horizontalAlignmentMode = .right
            label.zPosition = zPos
            node.addChild(label)
        }

        // ========== DDR5 LABELS (individual - few nodes) ==========
        let labels = ["DDR5", "16GB", "4800", "CL40", "1.1V"]
        for i in 0..<8 {
            let x = CGFloat.random(in: 150...(width - 150))
            let y = CGFloat.random(in: 150...(height - 150))
            guard !isNearLane(x, y) else { continue }
            let label = SKLabelNode(text: labels[i % labels.count])
            label.fontName = "Menlo"
            label.fontSize = CGFloat.random(in: 8...12)
            label.fontColor = color.withAlphaComponent(CGFloat.random(in: 0.2...0.4))
            label.position = CGPoint(x: baseX + x, y: baseY + y)
            label.zRotation = CGFloat.random(in: -0.1...0.1)
            label.zPosition = zPos + 0.2
            node.addChild(label)
        }
    }

    /// Add SSD chip outlines for Storage sector - Dense "storage city"
    private func addStorageChips(to node: SKNode, in sector: MegaBoardSector, color: UIColor) {
        // PERFORMANCE OPTIMIZED: Uses batched paths instead of individual nodes
        let baseX = sector.worldX
        let baseY = sector.worldY
        let width = sector.width
        let height = sector.height
        let zPos: CGFloat = 3

        func isNearLane(_ x: CGFloat, _ y: CGFloat) -> Bool {
            if y > 500 && y < 900 && x > 300 && x < 1100 { return true }
            if x > 1000 && y > 400 && y < 700 { return true }
            return false
        }

        let chipColor = UIColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 1.0)
        let goldColor = UIColor(hex: "#d4a600") ?? .yellow
        let controllerColor = UIColor(red: 0.12, green: 0.12, blue: 0.15, alpha: 1.0)

        // Pre-generate positions for batching
        var nandChips: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, hasLabel: Bool)] = []
        var cacheChips: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat)] = []
        var pmicChips: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat)] = []
        var ceramicCaps: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat)] = []
        var resistors: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat)] = []
        var m2Contacts: [(x: CGFloat, y: CGFloat)] = []

        // ========== Generate NAND positions ==========
        for _ in 0..<15 {
            let x = CGFloat.random(in: 100...(width - 100))
            let y = CGFloat.random(in: 100...(height - 100))
            guard !isNearLane(x, y) else { continue }
            let chipW = CGFloat.random(in: 50...90)
            let chipH = CGFloat.random(in: 40...70)
            nandChips.append((x: x, y: y, w: chipW, h: chipH, hasLabel: Bool.random()))
        }

        // ========== Generate cache chip positions ==========
        for _ in 0..<10 {
            let x = CGFloat.random(in: 80...(width - 80))
            let y = CGFloat.random(in: 80...(height - 80))
            guard !isNearLane(x, y) else { continue }
            let cacheW: CGFloat = CGFloat.random(in: 25...40)
            let cacheH: CGFloat = CGFloat.random(in: 18...28)
            cacheChips.append((x: x, y: y, w: cacheW, h: cacheH))
        }

        // ========== Generate M.2 contact positions ==========
        let m2Y: CGFloat = 100
        if !isNearLane(width/2, m2Y) {
            let connW: CGFloat = 300
            for c in 0..<Int(connW / 5) {
                m2Contacts.append((x: 205 + CGFloat(c) * 5, y: m2Y + 5))
            }
        }

        // ========== Generate PMIC positions ==========
        for _ in 0..<20 {
            let x = CGFloat.random(in: 60...(width - 60))
            let y = CGFloat.random(in: 60...(height - 60))
            guard !isNearLane(x, y) else { continue }
            let pmicW: CGFloat = CGFloat.random(in: 12...20)
            let pmicH: CGFloat = CGFloat.random(in: 10...16)
            pmicChips.append((x: x, y: y, w: pmicW, h: pmicH))
        }

        // ========== Generate passive component positions ==========
        for _ in 0..<120 {
            let x = CGFloat.random(in: 30...(width - 30))
            let y = CGFloat.random(in: 30...(height - 30))
            guard !isNearLane(x, y) else { continue }
            let compW = CGFloat.random(in: 3...7)
            let compH = CGFloat.random(in: 2...5)
            if Bool.random() {
                ceramicCaps.append((x: x, y: y, w: compW, h: compH))
            } else {
                resistors.append((x: x, y: y, w: compW, h: compH))
            }
        }

        // ========== BATCHED NAND CHIPS ==========
        let nandPath = CGMutablePath()
        for chip in nandChips {
            nandPath.addRoundedRect(in: CGRect(x: baseX + chip.x - chip.w/2, y: baseY + chip.y - chip.h/2, width: chip.w, height: chip.h), cornerWidth: 3, cornerHeight: 3)
        }
        let nandNode = SKShapeNode(path: nandPath)
        nandNode.fillColor = chipColor
        nandNode.strokeColor = color.withAlphaComponent(0.5)
        nandNode.lineWidth = 1.5
        nandNode.zPosition = zPos
        node.addChild(nandNode)

        // NAND labels (individual - few nodes)
        for chip in nandChips where chip.hasLabel {
            let label = SKLabelNode(text: ["NAND", "3D", "TLC", "QLC"].randomElement()!)
            label.fontName = "Menlo"
            label.fontSize = 8
            label.fontColor = color.withAlphaComponent(0.5)
            label.position = CGPoint(x: baseX + chip.x, y: baseY + chip.y)
            label.horizontalAlignmentMode = .center
            label.verticalAlignmentMode = .center
            label.zPosition = zPos + 0.1
            node.addChild(label)
        }

        // ========== SSD CONTROLLER ICs (individual - large labeled) ==========
        let controllerPositions: [(x: CGFloat, y: CGFloat)] = [(250, 250), (900, 350), (400, 950)]
        for pos in controllerPositions {
            if !isNearLane(pos.x, pos.y) {
                let size: CGFloat = CGFloat.random(in: 60...80)
                let controller = SKShapeNode(rect: CGRect(x: -size/2, y: -size/2, width: size, height: size), cornerRadius: 4)
                controller.position = CGPoint(x: baseX + pos.x, y: baseY + pos.y)
                controller.fillColor = controllerColor
                controller.strokeColor = color
                controller.lineWidth = 2
                controller.zPosition = zPos + 0.2
                node.addChild(controller)

                let label = SKLabelNode(text: "CTRL")
                label.fontName = "Menlo-Bold"
                label.fontSize = 10
                label.fontColor = color.withAlphaComponent(0.6)
                label.position = CGPoint(x: baseX + pos.x, y: baseY + pos.y)
                label.horizontalAlignmentMode = .center
                label.verticalAlignmentMode = .center
                label.zPosition = zPos + 0.3
                node.addChild(label)
            }
        }

        // ========== BATCHED CACHE CHIPS ==========
        let cachePath = CGMutablePath()
        for chip in cacheChips {
            cachePath.addRoundedRect(in: CGRect(x: baseX + chip.x - chip.w/2, y: baseY + chip.y - chip.h/2, width: chip.w, height: chip.h), cornerWidth: 1, cornerHeight: 1)
        }
        let cacheNode = SKShapeNode(path: cachePath)
        cacheNode.fillColor = chipColor
        cacheNode.strokeColor = UIColor.cyan.withAlphaComponent(0.3)
        cacheNode.lineWidth = 1
        cacheNode.zPosition = zPos
        node.addChild(cacheNode)

        // ========== M.2 CONNECTOR (single node) ==========
        if !isNearLane(width/2, m2Y) {
            let connW: CGFloat = 300
            let connH: CGFloat = 25
            let connector = SKShapeNode(rect: CGRect(x: 0, y: 0, width: connW, height: connH), cornerRadius: 2)
            connector.position = CGPoint(x: baseX + 200, y: baseY + m2Y)
            connector.fillColor = UIColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1.0)
            connector.strokeColor = goldColor.withAlphaComponent(0.5)
            connector.lineWidth = 1
            connector.zPosition = zPos - 0.1
            node.addChild(connector)
        }

        // ========== BATCHED M.2 CONTACTS ==========
        if !m2Contacts.isEmpty {
            let contactPath = CGMutablePath()
            for pos in m2Contacts {
                contactPath.addRect(CGRect(x: baseX + pos.x, y: baseY + pos.y, width: 3, height: 15))
            }
            let contactNode = SKShapeNode(path: contactPath)
            contactNode.fillColor = goldColor.withAlphaComponent(0.4)
            contactNode.strokeColor = .clear
            contactNode.zPosition = zPos
            node.addChild(contactNode)
        }

        // ========== BATCHED PMIC CHIPS ==========
        let pmicPath = CGMutablePath()
        for chip in pmicChips {
            pmicPath.addRoundedRect(in: CGRect(x: baseX + chip.x - chip.w/2, y: baseY + chip.y - chip.h/2, width: chip.w, height: chip.h), cornerWidth: 1, cornerHeight: 1)
        }
        let pmicNode = SKShapeNode(path: pmicPath)
        pmicNode.fillColor = chipColor
        pmicNode.strokeColor = color.withAlphaComponent(0.2)
        pmicNode.lineWidth = 0.5
        pmicNode.zPosition = zPos - 0.1
        node.addChild(pmicNode)

        // ========== BATCHED CERAMIC CAPS ==========
        let capPath = CGMutablePath()
        for pos in ceramicCaps {
            capPath.addRect(CGRect(x: baseX + pos.x - pos.w/2, y: baseY + pos.y - pos.h/2, width: pos.w, height: pos.h))
        }
        let capNode = SKShapeNode(path: capPath)
        capNode.fillColor = UIColor(red: 0.6, green: 0.55, blue: 0.4, alpha: 0.3)
        capNode.strokeColor = .clear
        capNode.zPosition = zPos - 0.3
        node.addChild(capNode)

        // ========== BATCHED RESISTORS ==========
        let resPath = CGMutablePath()
        for pos in resistors {
            resPath.addRect(CGRect(x: baseX + pos.x - pos.w/2, y: baseY + pos.y - pos.h/2, width: pos.w, height: pos.h))
        }
        let resNode = SKShapeNode(path: resPath)
        resNode.fillColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 0.4)
        resNode.strokeColor = .clear
        resNode.zPosition = zPos - 0.3
        node.addChild(resNode)

        // ========== STORAGE LABELS (individual - few nodes) ==========
        let storageLabels = ["1TB", "2TB", "NVMe", "PCIe", "Gen4", "7000MB/s"]
        for i in 0..<6 {
            let x = CGFloat.random(in: 150...(width - 150))
            let y = CGFloat.random(in: 150...(height - 150))
            guard !isNearLane(x, y) else { continue }
            let label = SKLabelNode(text: storageLabels[i % storageLabels.count])
            label.fontName = "Menlo"
            label.fontSize = CGFloat.random(in: 7...10)
            label.fontColor = color.withAlphaComponent(CGFloat.random(in: 0.2...0.35))
            label.position = CGPoint(x: baseX + x, y: baseY + y)
            label.zPosition = zPos + 0.2
            node.addChild(label)
        }
    }

    /// Add I/O connector outlines - Dense "I/O hub city"
    private func addIOConnectors(to node: SKNode, in sector: MegaBoardSector, color: UIColor) {
        // PERFORMANCE OPTIMIZED: Uses batched paths instead of individual nodes
        let baseX = sector.worldX
        let baseY = sector.worldY
        let width = sector.width
        let height = sector.height
        let zPos: CGFloat = 3

        func isNearLane(_ x: CGFloat, _ y: CGFloat) -> Bool {
            if y > 500 && y < 900 && x > 300 && x < 1100 { return true }
            if x > 1000 && y > 400 && y < 700 { return true }
            return false
        }

        let portColor = UIColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1.0)
        let chipColor = UIColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 1.0)
        let blueUSB = UIColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 0.6)

        // Pre-generate positions for batching
        var usbAPorts: [(x: CGFloat, y: CGFloat)] = []
        var usbATongues: [(x: CGFloat, y: CGFloat)] = []
        var usbCPorts: [(x: CGFloat, y: CGFloat)] = []
        var hdmiPorts: [(x: CGFloat, y: CGFloat)] = []
        var audioPorts: [(x: CGFloat, y: CGFloat, colorIndex: Int)] = []
        var diodePositions: [(x: CGFloat, y: CGFloat)] = []
        var ferritePositions: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat)] = []
        var ceramicPositions: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat)] = []

        // ========== Generate USB-A positions ==========
        let usbARows: [(y: CGFloat, count: Int)] = [(150, 5), (250, 4), (1050, 5), (1150, 4)]
        for row in usbARows {
            if !isNearLane(400, row.y) {
                for i in 0..<row.count {
                    usbAPorts.append((x: 100 + CGFloat(i) * 80, y: row.y))
                    usbATongues.append((x: 105 + CGFloat(i) * 80, y: row.y + 9))
                }
            }
        }

        // ========== Generate USB-C positions ==========
        for _ in 0..<10 {
            let x = CGFloat.random(in: 100...(width - 100))
            let y = CGFloat.random(in: 350...500)
            guard !isNearLane(x, y) else { continue }
            usbCPorts.append((x: x, y: y))
        }

        // ========== Generate HDMI positions ==========
        let hdmiPositions: [(x: CGFloat, y: CGFloat)] = [(150, 400), (250, 400), (1050, 400), (1150, 400), (200, 900), (300, 900)]
        for pos in hdmiPositions {
            if !isNearLane(pos.x, pos.y) {
                hdmiPorts.append(pos)
            }
        }

        // ========== Generate audio jack positions ==========
        for i in 0..<8 {
            let x = CGFloat.random(in: 600...(width - 100))
            let y = CGFloat.random(in: 200...400)
            guard !isNearLane(x, y) else { continue }
            audioPorts.append((x: x, y: y, colorIndex: i % 6))
        }

        // ========== Generate diode positions ==========
        for _ in 0..<30 {
            let x = CGFloat.random(in: 80...(width - 80))
            let y = CGFloat.random(in: 80...(height - 80))
            guard !isNearLane(x, y) else { continue }
            diodePositions.append((x: x, y: y))
        }

        // ========== Generate passive component positions ==========
        for _ in 0..<100 {
            let x = CGFloat.random(in: 40...(width - 40))
            let y = CGFloat.random(in: 40...(height - 40))
            guard !isNearLane(x, y) else { continue }
            let compW = CGFloat.random(in: 3...6)
            let compH = CGFloat.random(in: 2...4)
            if Bool.random() {
                ferritePositions.append((x: x, y: y, w: compW, h: compH))
            } else {
                ceramicPositions.append((x: x, y: y, w: compW, h: compH))
            }
        }

        // ========== BATCHED USB-A PORTS ==========
        let usbAPath = CGMutablePath()
        for pos in usbAPorts {
            usbAPath.addRoundedRect(in: CGRect(x: baseX + pos.x, y: baseY + pos.y, width: 55, height: 30), cornerWidth: 2, cornerHeight: 2)
        }
        let usbANode = SKShapeNode(path: usbAPath)
        usbANode.fillColor = portColor
        usbANode.strokeColor = blueUSB
        usbANode.lineWidth = 1.5
        usbANode.zPosition = zPos
        node.addChild(usbANode)

        // ========== BATCHED USB-A TONGUES ==========
        let tonguePath = CGMutablePath()
        for pos in usbATongues {
            tonguePath.addRect(CGRect(x: baseX + pos.x, y: baseY + pos.y, width: 45, height: 12))
        }
        let tongueNode = SKShapeNode(path: tonguePath)
        tongueNode.fillColor = blueUSB.withAlphaComponent(0.3)
        tongueNode.strokeColor = .clear
        tongueNode.zPosition = zPos + 0.1
        node.addChild(tongueNode)

        // ========== BATCHED USB-C PORTS ==========
        let usbCPath = CGMutablePath()
        for pos in usbCPorts {
            usbCPath.addRoundedRect(in: CGRect(x: baseX + pos.x - 17.5, y: baseY + pos.y - 7, width: 35, height: 14), cornerWidth: 7, cornerHeight: 7)
        }
        let usbCNode = SKShapeNode(path: usbCPath)
        usbCNode.fillColor = portColor
        usbCNode.strokeColor = color.withAlphaComponent(0.6)
        usbCNode.lineWidth = 1
        usbCNode.zPosition = zPos
        node.addChild(usbCNode)

        // ========== BATCHED HDMI PORTS ==========
        let hdmiPath = CGMutablePath()
        for pos in hdmiPorts {
            hdmiPath.addRoundedRect(in: CGRect(x: baseX + pos.x - 30, y: baseY + pos.y - 12.5, width: 60, height: 25), cornerWidth: 3, cornerHeight: 3)
        }
        let hdmiNode = SKShapeNode(path: hdmiPath)
        hdmiNode.fillColor = portColor
        hdmiNode.strokeColor = color.withAlphaComponent(0.5)
        hdmiNode.lineWidth = 1.5
        hdmiNode.zPosition = zPos
        node.addChild(hdmiNode)

        // ========== AUDIO JACKS (individual - few nodes with different colors) ==========
        let audioColors: [UIColor] = [.green, .blue, .systemPink, .orange, .gray, .black]
        for port in audioPorts {
            let jack = SKShapeNode(circleOfRadius: 12)
            jack.position = CGPoint(x: baseX + port.x, y: baseY + port.y)
            jack.fillColor = portColor
            jack.strokeColor = audioColors[port.colorIndex].withAlphaComponent(0.5)
            jack.lineWidth = 2
            jack.zPosition = zPos
            node.addChild(jack)
        }

        // ========== BATCHED AUDIO HOLES ==========
        let holePath = CGMutablePath()
        for port in audioPorts {
            holePath.addEllipse(in: CGRect(x: baseX + port.x - 5, y: baseY + port.y - 5, width: 10, height: 10))
        }
        let holeNode = SKShapeNode(path: holePath)
        holeNode.fillColor = .black
        holeNode.strokeColor = .clear
        holeNode.zPosition = zPos + 0.1
        node.addChild(holeNode)

        // ========== USB CONTROLLER ICs (individual - large labeled) ==========
        let controllerPositions: [(x: CGFloat, y: CGFloat)] = [(400, 200), (800, 250), (500, 1000), (900, 950)]
        for (index, pos) in controllerPositions.enumerated() {
            if !isNearLane(pos.x, pos.y) {
                let size: CGFloat = CGFloat.random(in: 45...65)
                let ctrl = SKShapeNode(rect: CGRect(x: -size/2, y: -size/2, width: size, height: size), cornerRadius: 3)
                ctrl.position = CGPoint(x: baseX + pos.x, y: baseY + pos.y)
                ctrl.fillColor = chipColor
                ctrl.strokeColor = color
                ctrl.lineWidth = 1.5
                ctrl.zPosition = zPos + 0.1
                node.addChild(ctrl)

                let label = SKLabelNode(text: ["USB", "HUB", "xHCI", "PHY"][index % 4])
                label.fontName = "Menlo"
                label.fontSize = 8
                label.fontColor = color.withAlphaComponent(0.5)
                label.position = CGPoint(x: baseX + pos.x, y: baseY + pos.y)
                label.horizontalAlignmentMode = .center
                label.verticalAlignmentMode = .center
                label.zPosition = zPos + 0.2
                node.addChild(label)
            }
        }

        // ========== BATCHED ESD DIODES ==========
        let diodePath = CGMutablePath()
        for pos in diodePositions {
            diodePath.addRoundedRect(in: CGRect(x: baseX + pos.x - 6, y: baseY + pos.y - 4, width: 12, height: 8), cornerWidth: 1, cornerHeight: 1)
        }
        let diodeNode = SKShapeNode(path: diodePath)
        diodeNode.fillColor = chipColor
        diodeNode.strokeColor = color.withAlphaComponent(0.2)
        diodeNode.lineWidth = 0.5
        diodeNode.zPosition = zPos - 0.1
        node.addChild(diodeNode)

        // ========== BATCHED FERRITE BEADS ==========
        let ferritePath = CGMutablePath()
        for pos in ferritePositions {
            ferritePath.addRect(CGRect(x: baseX + pos.x - pos.w/2, y: baseY + pos.y - pos.h/2, width: pos.w, height: pos.h))
        }
        let ferriteNode = SKShapeNode(path: ferritePath)
        ferriteNode.fillColor = UIColor(red: 0.3, green: 0.3, blue: 0.35, alpha: 0.4)
        ferriteNode.strokeColor = .clear
        ferriteNode.zPosition = zPos - 0.3
        node.addChild(ferriteNode)

        // ========== BATCHED CERAMIC CAPS ==========
        let ceramicPath = CGMutablePath()
        for pos in ceramicPositions {
            ceramicPath.addRect(CGRect(x: baseX + pos.x - pos.w/2, y: baseY + pos.y - pos.h/2, width: pos.w, height: pos.h))
        }
        let ceramicNode = SKShapeNode(path: ceramicPath)
        ceramicNode.fillColor = UIColor(red: 0.6, green: 0.55, blue: 0.4, alpha: 0.3)
        ceramicNode.strokeColor = .clear
        ceramicNode.zPosition = zPos - 0.3
        node.addChild(ceramicNode)

        // ========== I/O LABELS (individual - few nodes) ==========
        let ioLabels = ["USB 3.2", "USB-C", "HDMI", "DP", "AUDIO", "10Gbps"]
        for i in 0..<8 {
            let x = CGFloat.random(in: 150...(width - 150))
            let y = CGFloat.random(in: 150...(height - 150))
            guard !isNearLane(x, y) else { continue }
            let label = SKLabelNode(text: ioLabels[i % ioLabels.count])
            label.fontName = "Menlo"
            label.fontSize = CGFloat.random(in: 7...10)
            label.fontColor = color.withAlphaComponent(CGFloat.random(in: 0.2...0.35))
            label.position = CGPoint(x: baseX + x, y: baseY + y)
            label.zPosition = zPos + 0.2
            node.addChild(label)
        }
    }

    /// Add network jack outline
    private func addNetworkJack(to node: SKNode, in sector: MegaBoardSector, color: UIColor) {
        // PERFORMANCE OPTIMIZED: Uses batched paths instead of individual nodes
        let baseX = sector.worldX
        let baseY = sector.worldY
        let width = sector.width
        let height = sector.height
        let zPos: CGFloat = 3

        func isNearLane(_ x: CGFloat, _ y: CGFloat) -> Bool {
            if y > 500 && y < 900 && x > 300 && x < 1100 { return true }
            if x > 1000 && y > 400 && y < 700 { return true }
            return false
        }

        let portColor = UIColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1.0)
        let goldColor = UIColor(hex: "#d4a600") ?? .yellow
        let chipColor = UIColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 1.0)
        let greenLED = UIColor.green
        let orangeLED = UIColor.orange

        // Pre-generate positions for batching
        var rj45Jacks: [(x: CGFloat, y: CGFloat)] = []
        var rj45Pins: [(x: CGFloat, y: CGFloat)] = []
        var greenLEDs: [(x: CGFloat, y: CGFloat)] = []
        var orangeLEDs: [(x: CGFloat, y: CGFloat)] = []
        var transformerPositions: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat)] = []
        var smallICPositions: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat)] = []
        var statusLEDs: [(x: CGFloat, y: CGFloat, r: CGFloat, colorType: Int)] = []
        var ferritePositions: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat)] = []
        var ceramicPositions: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat)] = []

        // ========== Generate RJ45 positions ==========
        let jackPositions: [(x: CGFloat, y: CGFloat)] = [
            (150, 200), (280, 200), (410, 200),
            (150, 350), (280, 350),
            (150, 950), (280, 950), (410, 950)
        ]
        let jackW: CGFloat = 70
        let jackH: CGFloat = 55
        for pos in jackPositions {
            if !isNearLane(pos.x, pos.y) {
                rj45Jacks.append(pos)
                for p in 0..<8 {
                    rj45Pins.append((x: pos.x + 8 + CGFloat(p) * 7, y: pos.y + jackH - 15))
                }
                greenLEDs.append((x: pos.x + 12, y: pos.y + 8))
                orangeLEDs.append((x: pos.x + jackW - 12, y: pos.y + 8))
            }
        }

        // ========== Generate transformer positions ==========
        for _ in 0..<8 {
            let x = CGFloat.random(in: 100...(width - 100))
            let y = CGFloat.random(in: 100...(height - 100))
            guard !isNearLane(x, y) else { continue }
            let magW: CGFloat = CGFloat.random(in: 35...55)
            let magH: CGFloat = CGFloat.random(in: 25...40)
            transformerPositions.append((x: x, y: y, w: magW, h: magH))
        }

        // ========== Generate small IC positions ==========
        for _ in 0..<25 {
            let x = CGFloat.random(in: 80...(width - 80))
            let y = CGFloat.random(in: 80...(height - 80))
            guard !isNearLane(x, y) else { continue }
            let icW: CGFloat = CGFloat.random(in: 15...28)
            let icH: CGFloat = CGFloat.random(in: 12...22)
            smallICPositions.append((x: x, y: y, w: icW, h: icH))
        }

        // ========== Generate status LED positions ==========
        for _ in 0..<15 {
            let x = CGFloat.random(in: 100...(width - 100))
            let y = CGFloat.random(in: 100...(height - 100))
            guard !isNearLane(x, y) else { continue }
            let r = CGFloat.random(in: 3...5)
            statusLEDs.append((x: x, y: y, r: r, colorType: Int.random(in: 0..<3)))
        }

        // ========== Generate passive component positions ==========
        for _ in 0..<120 {
            let x = CGFloat.random(in: 40...(width - 40))
            let y = CGFloat.random(in: 40...(height - 40))
            guard !isNearLane(x, y) else { continue }
            let compW = CGFloat.random(in: 3...6)
            let compH = CGFloat.random(in: 2...4)
            if Bool.random() {
                ferritePositions.append((x: x, y: y, w: compW, h: compH))
            } else {
                ceramicPositions.append((x: x, y: y, w: compW, h: compH))
            }
        }

        // ========== BATCHED RJ45 JACKS ==========
        let jackPath = CGMutablePath()
        for pos in rj45Jacks {
            jackPath.addRoundedRect(in: CGRect(x: baseX + pos.x, y: baseY + pos.y, width: jackW, height: jackH), cornerWidth: 3, cornerHeight: 3)
        }
        let jackNode = SKShapeNode(path: jackPath)
        jackNode.fillColor = portColor
        jackNode.strokeColor = color.withAlphaComponent(0.6)
        jackNode.lineWidth = 1.5
        jackNode.zPosition = zPos
        node.addChild(jackNode)

        // ========== BATCHED RJ45 PINS ==========
        let pinPath = CGMutablePath()
        for pos in rj45Pins {
            pinPath.addRect(CGRect(x: baseX + pos.x, y: baseY + pos.y, width: 4, height: 12))
        }
        let pinNode = SKShapeNode(path: pinPath)
        pinNode.fillColor = goldColor.withAlphaComponent(0.5)
        pinNode.strokeColor = .clear
        pinNode.zPosition = zPos + 0.1
        node.addChild(pinNode)

        // ========== BATCHED GREEN LEDs ==========
        let greenPath = CGMutablePath()
        for pos in greenLEDs {
            greenPath.addEllipse(in: CGRect(x: baseX + pos.x - 4, y: baseY + pos.y - 4, width: 8, height: 8))
        }
        let greenNode = SKShapeNode(path: greenPath)
        greenNode.fillColor = greenLED.withAlphaComponent(0.4)
        greenNode.strokeColor = .clear
        greenNode.zPosition = zPos + 0.1
        node.addChild(greenNode)

        // ========== BATCHED ORANGE LEDs ==========
        let orangePath = CGMutablePath()
        for pos in orangeLEDs {
            orangePath.addEllipse(in: CGRect(x: baseX + pos.x - 4, y: baseY + pos.y - 4, width: 8, height: 8))
        }
        let orangeNode = SKShapeNode(path: orangePath)
        orangeNode.fillColor = orangeLED.withAlphaComponent(0.4)
        orangeNode.strokeColor = .clear
        orangeNode.zPosition = zPos + 0.1
        node.addChild(orangeNode)

        // ========== ETHERNET PHY CHIPS (individual - large labeled) ==========
        let phyPositions: [(x: CGFloat, y: CGFloat)] = [(600, 200), (900, 300), (550, 950), (850, 1000)]
        for (index, pos) in phyPositions.enumerated() {
            if !isNearLane(pos.x, pos.y) {
                let size: CGFloat = CGFloat.random(in: 50...70)
                let phy = SKShapeNode(rect: CGRect(x: -size/2, y: -size/2, width: size, height: size), cornerRadius: 3)
                phy.position = CGPoint(x: baseX + pos.x, y: baseY + pos.y)
                phy.fillColor = chipColor
                phy.strokeColor = color
                phy.lineWidth = 2
                phy.zPosition = zPos + 0.1
                node.addChild(phy)

                let label = SKLabelNode(text: ["PHY", "MAC", "ETH", "NIC"][index % 4])
                label.fontName = "Menlo-Bold"
                label.fontSize = 9
                label.fontColor = color.withAlphaComponent(0.5)
                label.position = CGPoint(x: baseX + pos.x, y: baseY + pos.y)
                label.horizontalAlignmentMode = .center
                label.verticalAlignmentMode = .center
                label.zPosition = zPos + 0.2
                node.addChild(label)
            }
        }

        // ========== BATCHED TRANSFORMERS ==========
        let transPath = CGMutablePath()
        for pos in transformerPositions {
            transPath.addRoundedRect(in: CGRect(x: baseX + pos.x - pos.w/2, y: baseY + pos.y - pos.h/2, width: pos.w, height: pos.h), cornerWidth: 2, cornerHeight: 2)
        }
        let transNode = SKShapeNode(path: transPath)
        transNode.fillColor = UIColor(red: 0.15, green: 0.15, blue: 0.18, alpha: 1.0)
        transNode.strokeColor = color.withAlphaComponent(0.3)
        transNode.lineWidth = 1
        transNode.zPosition = zPos
        node.addChild(transNode)

        // ========== BATCHED SMALL ICs ==========
        let icPath = CGMutablePath()
        for pos in smallICPositions {
            icPath.addRoundedRect(in: CGRect(x: baseX + pos.x - pos.w/2, y: baseY + pos.y - pos.h/2, width: pos.w, height: pos.h), cornerWidth: 1, cornerHeight: 1)
        }
        let icNode = SKShapeNode(path: icPath)
        icNode.fillColor = chipColor
        icNode.strokeColor = color.withAlphaComponent(0.25)
        icNode.lineWidth = 0.5
        icNode.zPosition = zPos - 0.1
        node.addChild(icNode)

        // ========== BATCHED STATUS LEDs (by color) ==========
        let statusGreenPath = CGMutablePath()
        let statusOrangePath = CGMutablePath()
        let statusYellowPath = CGMutablePath()
        for led in statusLEDs {
            let rect = CGRect(x: baseX + led.x - led.r, y: baseY + led.y - led.r, width: led.r * 2, height: led.r * 2)
            switch led.colorType {
            case 0: statusGreenPath.addEllipse(in: rect)
            case 1: statusOrangePath.addEllipse(in: rect)
            default: statusYellowPath.addEllipse(in: rect)
            }
        }
        let statusGreenNode = SKShapeNode(path: statusGreenPath)
        statusGreenNode.fillColor = greenLED.withAlphaComponent(0.3)
        statusGreenNode.strokeColor = .clear
        statusGreenNode.zPosition = zPos
        node.addChild(statusGreenNode)

        let statusOrangeNode = SKShapeNode(path: statusOrangePath)
        statusOrangeNode.fillColor = orangeLED.withAlphaComponent(0.3)
        statusOrangeNode.strokeColor = .clear
        statusOrangeNode.zPosition = zPos
        node.addChild(statusOrangeNode)

        let statusYellowNode = SKShapeNode(path: statusYellowPath)
        statusYellowNode.fillColor = UIColor.yellow.withAlphaComponent(0.3)
        statusYellowNode.strokeColor = .clear
        statusYellowNode.zPosition = zPos
        node.addChild(statusYellowNode)

        // ========== BATCHED FERRITES ==========
        let ferritePath = CGMutablePath()
        for pos in ferritePositions {
            ferritePath.addRect(CGRect(x: baseX + pos.x - pos.w/2, y: baseY + pos.y - pos.h/2, width: pos.w, height: pos.h))
        }
        let ferriteNode = SKShapeNode(path: ferritePath)
        ferriteNode.fillColor = UIColor(red: 0.3, green: 0.3, blue: 0.35, alpha: 0.4)
        ferriteNode.strokeColor = .clear
        ferriteNode.zPosition = zPos - 0.3
        node.addChild(ferriteNode)

        // ========== BATCHED CERAMICS ==========
        let ceramicPath = CGMutablePath()
        for pos in ceramicPositions {
            ceramicPath.addRect(CGRect(x: baseX + pos.x - pos.w/2, y: baseY + pos.y - pos.h/2, width: pos.w, height: pos.h))
        }
        let ceramicNode = SKShapeNode(path: ceramicPath)
        ceramicNode.fillColor = UIColor(red: 0.6, green: 0.55, blue: 0.4, alpha: 0.3)
        ceramicNode.strokeColor = .clear
        ceramicNode.zPosition = zPos - 0.3
        node.addChild(ceramicNode)

        // ========== NETWORK LABELS (individual - few nodes) ==========
        let netLabels = ["1G LAN", "2.5G", "ETH", "RJ45", "Cat6", "PoE"]
        for i in 0..<8 {
            let x = CGFloat.random(in: 150...(width - 150))
            let y = CGFloat.random(in: 150...(height - 150))
            guard !isNearLane(x, y) else { continue }
            let label = SKLabelNode(text: netLabels[i % netLabels.count])
            label.fontName = "Menlo"
            label.fontSize = CGFloat.random(in: 7...10)
            label.fontColor = color.withAlphaComponent(CGFloat.random(in: 0.2...0.35))
            label.position = CGPoint(x: baseX + x, y: baseY + y)
            label.zPosition = zPos + 0.2
            node.addChild(label)
        }
    }

    /// Add cache memory blocks for processing sectors - Dense "processor city"
    private func addCacheBlocks(to node: SKNode, in sector: MegaBoardSector, color: UIColor) {
        // PERFORMANCE OPTIMIZED: Uses batched paths instead of individual nodes
        let baseX = sector.worldX
        let baseY = sector.worldY
        let width = sector.width
        let height = sector.height
        let zPos: CGFloat = 3

        func isNearLane(_ x: CGFloat, _ y: CGFloat) -> Bool {
            if y > 500 && y < 900 && x > 300 && x < 1100 { return true }
            if x > 1000 && y > 400 && y < 700 { return true }
            return false
        }

        let chipColor = UIColor(red: 0.1, green: 0.1, blue: 0.15, alpha: 1.0)
        let cacheColor = UIColor(red: 0.12, green: 0.12, blue: 0.18, alpha: 1.0)

        // Pre-generate positions for batching
        var cacheBlocks: [(x: CGFloat, y: CGFloat)] = []
        var cacheGridLabels: [(x: CGFloat, y: CGFloat, text: String)] = []
        var processorUnits: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat)] = []
        var registerBlocks: [(x: CGFloat, y: CGFloat)] = []
        var busLines: [(x1: CGFloat, y1: CGFloat, x2: CGFloat, y2: CGFloat)] = []
        var gatePositions: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat)] = []

        // ========== Generate cache grid positions ==========
        let cacheGridPositions: [(x: CGFloat, y: CGFloat, rows: Int, cols: Int)] = [
            (150, 200, 5, 8), (800, 150, 4, 6),
            (200, 900, 4, 7), (850, 950, 5, 5)
        ]
        let blockSize: CGFloat = 22
        for grid in cacheGridPositions {
            if !isNearLane(grid.x + CGFloat(grid.cols) * 20, grid.y + CGFloat(grid.rows) * 20) {
                for row in 0..<grid.rows {
                    for col in 0..<grid.cols {
                        cacheBlocks.append((x: grid.x + CGFloat(col) * blockSize, y: grid.y + CGFloat(row) * blockSize))
                    }
                }
                cacheGridLabels.append((x: grid.x + CGFloat(grid.cols) * blockSize / 2, y: grid.y - 15, text: ["L3", "L2", "SRAM", "CACHE"].randomElement()!))
            }
        }

        // ========== Generate processor unit positions ==========
        for _ in 0..<20 {
            let x = CGFloat.random(in: 100...(width - 100))
            let y = CGFloat.random(in: 100...(height - 100))
            guard !isNearLane(x, y) else { continue }
            let unitW = CGFloat.random(in: 30...50)
            let unitH = CGFloat.random(in: 25...40)
            processorUnits.append((x: x, y: y, w: unitW, h: unitH))
        }

        // ========== Generate register block positions ==========
        for _ in 0..<10 {
            let x = CGFloat.random(in: 150...(width - 150))
            let y = CGFloat.random(in: 150...(height - 150))
            guard !isNearLane(x, y) else { continue }
            registerBlocks.append((x: x, y: y))
        }

        // ========== Generate bus line positions ==========
        for _ in 0..<8 {
            let isHorizontal = Bool.random()
            let lineLength = CGFloat.random(in: 100...300)
            let x = CGFloat.random(in: 100...(width - 100))
            let y = CGFloat.random(in: 100...(height - 100))
            guard !isNearLane(x, y) else { continue }
            if isHorizontal {
                busLines.append((x1: x, y1: y, x2: x + lineLength, y2: y))
            } else {
                busLines.append((x1: x, y1: y, x2: x, y2: y + lineLength))
            }
        }

        // ========== Generate gate positions ==========
        for _ in 0..<100 {
            let x = CGFloat.random(in: 50...(width - 50))
            let y = CGFloat.random(in: 50...(height - 50))
            guard !isNearLane(x, y) else { continue }
            let gateW = CGFloat.random(in: 5...10)
            let gateH = CGFloat.random(in: 4...8)
            gatePositions.append((x: x, y: y, w: gateW, h: gateH))
        }

        // ========== BATCHED CACHE BLOCKS ==========
        let cachePath = CGMutablePath()
        for pos in cacheBlocks {
            cachePath.addRoundedRect(in: CGRect(x: baseX + pos.x, y: baseY + pos.y, width: blockSize - 3, height: blockSize - 3), cornerWidth: 1, cornerHeight: 1)
        }
        let cacheNode = SKShapeNode(path: cachePath)
        cacheNode.fillColor = cacheColor
        cacheNode.strokeColor = color.withAlphaComponent(0.4)
        cacheNode.lineWidth = 0.5
        cacheNode.zPosition = zPos
        node.addChild(cacheNode)

        // Cache grid labels (individual - few nodes)
        for lbl in cacheGridLabels {
            let label = SKLabelNode(text: lbl.text)
            label.fontName = "Menlo"
            label.fontSize = 8
            label.fontColor = color.withAlphaComponent(0.4)
            label.position = CGPoint(x: baseX + lbl.x, y: baseY + lbl.y)
            label.horizontalAlignmentMode = .center
            label.zPosition = zPos + 0.1
            node.addChild(label)
        }

        // ========== BATCHED PROCESSOR UNITS ==========
        let unitPath = CGMutablePath()
        for pos in processorUnits {
            unitPath.addRoundedRect(in: CGRect(x: baseX + pos.x - pos.w/2, y: baseY + pos.y - pos.h/2, width: pos.w, height: pos.h), cornerWidth: 2, cornerHeight: 2)
        }
        let unitNode = SKShapeNode(path: unitPath)
        unitNode.fillColor = chipColor
        unitNode.strokeColor = color.withAlphaComponent(0.5)
        unitNode.lineWidth = 1
        unitNode.zPosition = zPos
        node.addChild(unitNode)

        // ========== ALU/FPU BLOCKS (individual - large labeled) ==========
        let aluPositions: [(x: CGFloat, y: CGFloat)] = [
            (500, 300), (700, 350), (400, 450),
            (600, 850), (750, 900), (500, 1000)
        ]
        for (index, pos) in aluPositions.enumerated() {
            if !isNearLane(pos.x, pos.y) {
                let size: CGFloat = CGFloat.random(in: 40...60)
                let alu = SKShapeNode(rect: CGRect(x: -size/2, y: -size/2, width: size, height: size), cornerRadius: 3)
                alu.position = CGPoint(x: baseX + pos.x, y: baseY + pos.y)
                alu.fillColor = cacheColor
                alu.strokeColor = color
                alu.lineWidth = 1.5
                alu.zPosition = zPos + 0.1
                node.addChild(alu)

                let label = SKLabelNode(text: ["ALU", "FPU", "CU", "REG"][index % 4])
                label.fontName = "Menlo-Bold"
                label.fontSize = 9
                label.fontColor = color.withAlphaComponent(0.5)
                label.position = CGPoint(x: baseX + pos.x, y: baseY + pos.y)
                label.horizontalAlignmentMode = .center
                label.verticalAlignmentMode = .center
                label.zPosition = zPos + 0.2
                node.addChild(label)
            }
        }

        // ========== BATCHED REGISTER FILES ==========
        let regW: CGFloat = 8
        let regH: CGFloat = 6
        let regPath = CGMutablePath()
        for pos in registerBlocks {
            for row in 0..<2 {
                for col in 0..<4 {
                    regPath.addRect(CGRect(x: baseX + pos.x + CGFloat(col) * regW, y: baseY + pos.y + CGFloat(row) * regH, width: regW - 1, height: regH - 1))
                }
            }
        }
        let regNode = SKShapeNode(path: regPath)
        regNode.fillColor = chipColor
        regNode.strokeColor = color.withAlphaComponent(0.3)
        regNode.lineWidth = 0.5
        regNode.zPosition = zPos - 0.1
        node.addChild(regNode)

        // ========== BATCHED BUS LINES ==========
        let busPath = CGMutablePath()
        for line in busLines {
            busPath.move(to: CGPoint(x: baseX + line.x1, y: baseY + line.y1))
            busPath.addLine(to: CGPoint(x: baseX + line.x2, y: baseY + line.y2))
        }
        let busNode = SKShapeNode(path: busPath)
        busNode.strokeColor = color.withAlphaComponent(0.2)
        busNode.lineWidth = 2
        busNode.zPosition = zPos - 0.2
        node.addChild(busNode)

        // ========== BATCHED LOGIC GATES ==========
        let gatePath = CGMutablePath()
        for pos in gatePositions {
            gatePath.addRect(CGRect(x: baseX + pos.x - pos.w/2, y: baseY + pos.y - pos.h/2, width: pos.w, height: pos.h))
        }
        let gateNode = SKShapeNode(path: gatePath)
        gateNode.fillColor = chipColor.withAlphaComponent(0.6)
        gateNode.strokeColor = color.withAlphaComponent(0.15)
        gateNode.lineWidth = 0.5
        gateNode.zPosition = zPos - 0.3
        node.addChild(gateNode)

        // ========== PROCESSOR LABELS (individual - few nodes) ==========
        let procLabels = ["L3 CACHE", "32MB", "SRAM", "12-core", "REG", "ALU"]
        for i in 0..<6 {
            let x = CGFloat.random(in: 150...(width - 150))
            let y = CGFloat.random(in: 150...(height - 150))
            guard !isNearLane(x, y) else { continue }
            let label = SKLabelNode(text: procLabels[i % procLabels.count])
            label.fontName = "Menlo"
            label.fontSize = CGFloat.random(in: 7...10)
            label.fontColor = color.withAlphaComponent(CGFloat.random(in: 0.2...0.35))
            label.position = CGPoint(x: baseX + x, y: baseY + y)
            label.zPosition = zPos + 0.2
            node.addChild(label)
        }
    }

    /// Add trace bundles connecting to sector edges
    private func addSectorTraces(to node: SKNode, in sector: MegaBoardSector, color: UIColor) {
        let traceColor = UIColor(hex: MotherboardColors.copperTrace)?.withAlphaComponent(0.15) ?? UIColor.orange.withAlphaComponent(0.15)
        let traceCount = 6
        let traceSpacing: CGFloat = 8
        let traceWidth: CGFloat = 2

        // Add trace bundle going toward CPU (center of map)
        let sectorCenter = CGPoint(x: sector.worldX + sector.width / 2, y: sector.worldY + sector.height / 2)
        let cpuCenter = MotherboardLaneConfig.cpuCenter

        // Determine edge closest to CPU
        let dx = cpuCenter.x - sectorCenter.x
        let dy = cpuCenter.y - sectorCenter.y

        var startPoint: CGPoint
        var endPoint: CGPoint

        if abs(dx) > abs(dy) {
            // Horizontal traces
            if dx > 0 {
                // Traces go right
                startPoint = CGPoint(x: sector.worldX + sector.width - 100, y: sectorCenter.y)
                endPoint = CGPoint(x: sector.worldX + sector.width, y: sectorCenter.y)
            } else {
                // Traces go left
                startPoint = CGPoint(x: sector.worldX + 100, y: sectorCenter.y)
                endPoint = CGPoint(x: sector.worldX, y: sectorCenter.y)
            }
        } else {
            // Vertical traces
            if dy > 0 {
                // Traces go up
                startPoint = CGPoint(x: sectorCenter.x, y: sector.worldY + sector.height - 100)
                endPoint = CGPoint(x: sectorCenter.x, y: sector.worldY + sector.height)
            } else {
                // Traces go down
                startPoint = CGPoint(x: sectorCenter.x, y: sector.worldY + 100)
                endPoint = CGPoint(x: sectorCenter.x, y: sector.worldY)
            }
        }

        // Draw parallel traces
        let isHorizontal = abs(dx) > abs(dy)
        for i in 0..<traceCount {
            let offset = CGFloat(i - traceCount/2) * traceSpacing

            let trace = SKShapeNode()
            let path = CGMutablePath()

            if isHorizontal {
                path.move(to: CGPoint(x: startPoint.x, y: startPoint.y + offset))
                path.addLine(to: CGPoint(x: endPoint.x, y: endPoint.y + offset))
            } else {
                path.move(to: CGPoint(x: startPoint.x + offset, y: startPoint.y))
                path.addLine(to: CGPoint(x: endPoint.x + offset, y: endPoint.y))
            }

            trace.path = path
            trace.strokeColor = traceColor
            trace.lineWidth = traceWidth
            trace.zPosition = -3.5
            node.addChild(trace)
        }
    }

    /// Draw silkscreen-style labels around the board
    private func drawSilkscreenLabels() {
        let silkColor = UIColor.white.withAlphaComponent(0.25)

        // REV label in corner
        let revLabel = SKLabelNode(text: "REV 2.0")
        revLabel.fontName = "Menlo"
        revLabel.fontSize = 14
        revLabel.fontColor = silkColor
        revLabel.position = CGPoint(x: 80, y: 30)
        revLabel.horizontalAlignmentMode = .left
        revLabel.zPosition = -2
        backgroundLayer.addChild(revLabel)

        // Board name
        let boardLabel = SKLabelNode(text: "LEGENDARY_SURVIVORS_MB")
        boardLabel.fontName = "Menlo-Bold"
        boardLabel.fontSize = 12
        boardLabel.fontColor = silkColor
        boardLabel.position = CGPoint(x: size.width / 2, y: 30)
        boardLabel.horizontalAlignmentMode = .center
        boardLabel.zPosition = -2
        backgroundLayer.addChild(boardLabel)

        // PWR and GND labels near power sector
        let pwrLabel = SKLabelNode(text: "PWR +12V")
        pwrLabel.fontName = "Menlo"
        pwrLabel.fontSize = 10
        pwrLabel.fontColor = UIColor(hex: "#ffdd00")?.withAlphaComponent(0.4) ?? silkColor
        pwrLabel.position = CGPoint(x: 3100, y: 1500)  // Near PSU sector
        pwrLabel.horizontalAlignmentMode = .center
        pwrLabel.zPosition = -2
        backgroundLayer.addChild(pwrLabel)

        let gndLabel = SKLabelNode(text: "GND")
        gndLabel.fontName = "Menlo"
        gndLabel.fontSize = 10
        gndLabel.fontColor = silkColor
        gndLabel.position = CGPoint(x: 3100, y: 1480)
        gndLabel.horizontalAlignmentMode = .center
        gndLabel.zPosition = -2
        backgroundLayer.addChild(gndLabel)

        // Copyright/brand in opposite corner
        let brandLabel = SKLabelNode(text: "© LEGENDARY TECH")
        brandLabel.fontName = "Menlo"
        brandLabel.fontSize = 10
        brandLabel.fontColor = silkColor.withAlphaComponent(0.5)
        brandLabel.position = CGPoint(x: size.width - 80, y: 30)
        brandLabel.horizontalAlignmentMode = .right
        brandLabel.zPosition = -2
        backgroundLayer.addChild(brandLabel)
    }

    /// Draw motherboard districts as ghost outlines (locked) or lit (unlocked)
    private func drawMotherboardDistricts() {
        let config = MotherboardConfig.createDefault()
        let ghostColor = UIColor(hex: MotherboardColors.ghostMode) ?? UIColor.darkGray

        for district in config.districts {
            let districtNode = SKNode()

            // District outline
            let rect = CGRect(x: 0, y: 0, width: district.width, height: district.height)
            let outline = SKShapeNode(rect: rect, cornerRadius: 8)

            // Check if this is the CPU district (always active)
            let isActive = district.id == "cpu_district"

            if isActive {
                // Active district - full brightness
                outline.strokeColor = UIColor(hex: district.primaryColor) ?? UIColor.blue
                outline.lineWidth = 3
                outline.fillColor = UIColor(hex: district.primaryColor)?.withAlphaComponent(0.1) ?? UIColor.blue.withAlphaComponent(0.1)
                outline.glowWidth = 5
            } else {
                // Ghost district - dimmed at 15%
                outline.strokeColor = ghostColor.withAlphaComponent(0.4)
                outline.lineWidth = 1
                outline.fillColor = ghostColor.withAlphaComponent(0.05)
            }

            districtNode.addChild(outline)

            // District label (silkscreen text)
            let label = SKLabelNode(text: district.name.uppercased())
            label.fontName = "Menlo-Bold"
            label.fontSize = isActive ? 16 : 12
            label.fontColor = isActive ? UIColor.white : ghostColor
            label.position = CGPoint(x: district.width/2, y: district.height + 10)
            label.horizontalAlignmentMode = .center
            districtNode.addChild(label)

            // For locked districts, add "LOCKED" or cost text
            if !isActive {
                let lockedLabel = SKLabelNode(text: L10n.Common.locked)
                lockedLabel.fontName = "Menlo"
                lockedLabel.fontSize = 10
                lockedLabel.fontColor = ghostColor.withAlphaComponent(0.6)
                lockedLabel.position = CGPoint(x: district.width/2, y: district.height/2)
                lockedLabel.horizontalAlignmentMode = .center
                districtNode.addChild(lockedLabel)
            }

            // Position in scene (convert from game coords)
            districtNode.position = CGPoint(x: district.x, y: district.y)
            districtNode.zPosition = -3
            backgroundLayer.addChild(districtNode)
        }
    }

    /// Draw glowing CPU core at center
    private func drawCPUCore() {
        let cpuColor = UIColor(hex: MotherboardColors.cpuCore) ?? UIColor.blue
        let glowColor = UIColor(hex: MotherboardColors.activeGlow) ?? UIColor.green

        let cpuSize: CGFloat = MotherboardLaneConfig.cpuSize
        let cpuPosition = MotherboardLaneConfig.cpuCenter

        // Outer glow
        let outerGlow = SKShapeNode(rectOf: CGSize(width: cpuSize + 60, height: cpuSize + 60), cornerRadius: 20)
        outerGlow.position = cpuPosition
        outerGlow.fillColor = cpuColor.withAlphaComponent(0.1)
        outerGlow.strokeColor = glowColor.withAlphaComponent(0.5)
        outerGlow.lineWidth = 3
        outerGlow.glowWidth = 10  // Reduced from 20 for performance
        outerGlow.zPosition = -1
        outerGlow.blendMode = .add
        backgroundLayer.addChild(outerGlow)

        // CPU body
        let cpuBody = SKShapeNode(rectOf: CGSize(width: cpuSize, height: cpuSize), cornerRadius: 10)
        cpuBody.position = cpuPosition
        cpuBody.fillColor = UIColor(red: 0.15, green: 0.15, blue: 0.2, alpha: 1.0)
        cpuBody.strokeColor = cpuColor
        cpuBody.lineWidth = 4
        cpuBody.zPosition = 0
        backgroundLayer.addChild(cpuBody)

        // CPU die (inner bright square)
        let dieSize: CGFloat = 150
        let cpuDie = SKShapeNode(rectOf: CGSize(width: dieSize, height: dieSize), cornerRadius: 5)
        cpuDie.position = cpuPosition
        cpuDie.fillColor = cpuColor.withAlphaComponent(0.3)
        cpuDie.strokeColor = cpuColor
        cpuDie.lineWidth = 2
        cpuDie.zPosition = 1
        backgroundLayer.addChild(cpuDie)

        // CPU label
        let label = SKLabelNode(text: "CPU")
        label.fontName = "Menlo-Bold"
        label.fontSize = 32
        label.fontColor = UIColor.white
        label.position = CGPoint(x: cpuPosition.x, y: cpuPosition.y - 10)
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.zPosition = 2
        backgroundLayer.addChild(label)

        // Pulse animation for glow
        let pulseUp = SKAction.scale(to: 1.05, duration: 1.5)
        let pulseDown = SKAction.scale(to: 1.0, duration: 1.5)
        pulseUp.timingMode = .easeInEaseOut
        pulseDown.timingMode = .easeInEaseOut
        let pulse = SKAction.sequence([pulseUp, pulseDown])
        outerGlow.run(SKAction.repeatForever(pulse))
    }

    /// Setup parallax background layers for depth effect
    private func setupParallaxBackground() {
        // Clear existing parallax layers
        for (node, _) in parallaxLayers {
            node.removeFromParent()
        }
        parallaxLayers.removeAll()

        // Layer 1: Slow star field (z=-3, speed factor 0.1)
        let starLayer = createStarFieldLayer()
        starLayer.zPosition = -3
        backgroundLayer.addChild(starLayer)
        parallaxLayers.append((starLayer, 0.1))

        // Layer 2: Circuit grid pattern (z=-2, speed factor 0.3)
        let circuitLayer = createCircuitPatternLayer()
        circuitLayer.zPosition = -2
        backgroundLayer.addChild(circuitLayer)
        parallaxLayers.append((circuitLayer, 0.3))

        // Layer 3: Data flow particles (z=-1, speed factor 0.6)
        let dataFlowLayer = createDataFlowLayer()
        dataFlowLayer.zPosition = -1
        backgroundLayer.addChild(dataFlowLayer)
        parallaxLayers.append((dataFlowLayer, 0.6))

        // Initialize camera position tracking
        lastCameraPosition = cameraNode?.position ?? CGPoint(x: size.width / 2, y: size.height / 2)
    }

    /// Create star field background layer
    private func createStarFieldLayer() -> SKNode {
        let layer = SKNode()

        // Create small dots as distant stars
        let starCount = 50
        let layerSize = CGSize(width: size.width * 2, height: size.height * 2)

        for _ in 0..<starCount {
            let star = SKShapeNode(circleOfRadius: CGFloat.random(in: 1...2))
            star.fillColor = UIColor.white.withAlphaComponent(CGFloat.random(in: 0.2...0.5))
            star.strokeColor = .clear
            star.position = CGPoint(
                x: CGFloat.random(in: -layerSize.width/2...layerSize.width/2),
                y: CGFloat.random(in: -layerSize.height/2...layerSize.height/2)
            )

            // Subtle twinkle animation
            let fadeOut = SKAction.fadeAlpha(to: 0.1, duration: Double.random(in: 1...3))
            let fadeIn = SKAction.fadeAlpha(to: star.alpha, duration: Double.random(in: 1...3))
            let delay = SKAction.wait(forDuration: Double.random(in: 0...2))
            star.run(SKAction.repeatForever(SKAction.sequence([delay, fadeOut, fadeIn])))

            layer.addChild(star)
        }

        layer.position = CGPoint(x: size.width / 2, y: size.height / 2)
        return layer
    }

    /// Create circuit pattern parallax layer
    private func createCircuitPatternLayer() -> SKNode {
        let layer = SKNode()

        // Create faint circuit traces in background
        let traceCount = 15
        let layerSize = CGSize(width: size.width * 1.5, height: size.height * 1.5)

        for _ in 0..<traceCount {
            let startPoint = CGPoint(
                x: CGFloat.random(in: -layerSize.width/2...layerSize.width/2),
                y: CGFloat.random(in: -layerSize.height/2...layerSize.height/2)
            )

            let isHorizontal = Bool.random()
            let length = CGFloat.random(in: 50...150)
            let endPoint = isHorizontal
                ? CGPoint(x: startPoint.x + length, y: startPoint.y)
                : CGPoint(x: startPoint.x, y: startPoint.y + length)

            let path = UIBezierPath()
            path.move(to: startPoint)
            path.addLine(to: endPoint)

            let trace = SKShapeNode(path: path.cgPath)
            trace.strokeColor = DesignColors.tracePrimaryUI.withAlphaComponent(0.15)
            trace.lineWidth = 2
            trace.lineCap = .round
            layer.addChild(trace)

            // Add junction dot at end
            let dot = SKShapeNode(circleOfRadius: 3)
            dot.fillColor = DesignColors.tracePrimaryUI.withAlphaComponent(0.2)
            dot.strokeColor = .clear
            dot.position = endPoint
            layer.addChild(dot)
        }

        layer.position = CGPoint(x: size.width / 2, y: size.height / 2)
        return layer
    }

    /// Create data flow particles layer
    private func createDataFlowLayer() -> SKNode {
        let layer = SKNode()

        // Create floating data particles
        let particleCount = 20

        for _ in 0..<particleCount {
            let particle = SKShapeNode(rectOf: CGSize(width: 4, height: 4), cornerRadius: 1)
            particle.fillColor = DesignColors.primaryUI.withAlphaComponent(0.3)
            particle.strokeColor = .clear
            particle.position = CGPoint(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...size.height)
            )

            // Floating animation
            let moveUp = SKAction.moveBy(x: 0, y: 30, duration: Double.random(in: 2...4))
            let moveDown = SKAction.moveBy(x: 0, y: -30, duration: Double.random(in: 2...4))
            moveUp.timingMode = .easeInEaseOut
            moveDown.timingMode = .easeInEaseOut
            particle.run(SKAction.repeatForever(SKAction.sequence([moveUp, moveDown])))

            // Fade animation
            let fade = SKAction.sequence([
                SKAction.fadeAlpha(to: 0.1, duration: Double.random(in: 1.5...3)),
                SKAction.fadeAlpha(to: 0.3, duration: Double.random(in: 1.5...3))
            ])
            particle.run(SKAction.repeatForever(fade))

            layer.addChild(particle)
        }

        return layer
    }

    /// Update parallax layers based on camera movement
    private func updateParallaxLayers() {
        guard let cameraNode = cameraNode else { return }

        let cameraDelta = CGPoint(
            x: cameraNode.position.x - lastCameraPosition.x,
            y: cameraNode.position.y - lastCameraPosition.y
        )

        // Move each layer based on its speed factor (opposite to camera movement)
        for (layer, speedFactor) in parallaxLayers {
            layer.position.x -= cameraDelta.x * speedFactor
            layer.position.y -= cameraDelta.y * speedFactor
        }

        lastCameraPosition = cameraNode.position
    }

    private func setupPaths() {
        guard let state = state else { return }

        pathLayer.removeAllChildren()

        // Use different rendering based on map theme
        if isMotherboardMap {
            setupMotherboardPaths()

            // NOTE: Power flow particles removed - lanes should only have LEDs
            // startPowerFlowParticles()

            // Start ambient voltage arc effects for PSU sector (reduced frequency)
            startVoltageArcSystem()
        } else {
            setupStandardPaths()
        }
    }

    /// Standard path rendering for non-motherboard maps
    private func setupStandardPaths() {
        guard let state = state else { return }

        // Circuit trace dimensions - thinner for tech aesthetic
        let traceWidth: CGFloat = DesignLayout.pathWidth         // Main trace width
        let glowWidth: CGFloat = traceWidth + 8                  // Glow extends beyond trace

        // Draw each path as a glowing circuit trace
        for path in state.paths {
            let bezierPath = UIBezierPath()

            if let firstPoint = path.waypoints.first {
                bezierPath.move(to: convertToScene(firstPoint))

                for i in 1..<path.waypoints.count {
                    bezierPath.addLine(to: convertToScene(path.waypoints[i]))
                }
            }

            // Outer glow layer (soft cyan glow with additive blending)
            let glowNode = SKShapeNode()
            glowNode.path = bezierPath.cgPath
            glowNode.strokeColor = DesignColors.traceGlowUI.withAlphaComponent(0.25)
            glowNode.lineWidth = glowWidth
            glowNode.lineCap = .round
            glowNode.lineJoin = .round
            glowNode.zPosition = 0
            glowNode.glowWidth = 10  // Enhanced glow width
            glowNode.blendMode = .add  // Additive blending for brighter glow
            pathLayer.addChild(glowNode)

            // Dark border/outline for depth
            let borderNode = SKShapeNode()
            borderNode.path = bezierPath.cgPath
            borderNode.strokeColor = DesignColors.traceBorderUI
            borderNode.lineWidth = traceWidth + 4
            borderNode.lineCap = .round
            borderNode.lineJoin = .round
            borderNode.zPosition = 1
            pathLayer.addChild(borderNode)

            // Main circuit trace - bright cyan
            let pathNode = SKShapeNode()
            pathNode.path = bezierPath.cgPath
            pathNode.strokeColor = DesignColors.tracePrimaryUI
            pathNode.lineWidth = traceWidth
            pathNode.lineCap = .round
            pathNode.lineJoin = .round
            pathNode.zPosition = 2
            pathLayer.addChild(pathNode)

            // Inner highlight for 3D effect
            let highlightNode = SKShapeNode()
            highlightNode.path = bezierPath.cgPath
            highlightNode.strokeColor = UIColor.white.withAlphaComponent(0.3)
            highlightNode.lineWidth = traceWidth * 0.3
            highlightNode.lineCap = .round
            highlightNode.lineJoin = .round
            highlightNode.zPosition = 3
            pathLayer.addChild(highlightNode)

            // Add data flow direction indicators (chevrons)
            addPathChevrons(for: path, pathWidth: traceWidth)
        }
    }

    /// Motherboard-style copper trace paths for all 8 lanes
    /// Renders active lanes in full brightness, locked lanes dimmed at 25%
    private func setupMotherboardPaths() {
        guard let state = state else { return }

        let copperColor = UIColor(hex: MotherboardColors.copperTrace) ?? UIColor.orange
        let copperHighlight = UIColor(hex: MotherboardColors.copperHighlight) ?? UIColor(red: 0.83, green: 0.59, blue: 0.42, alpha: 1.0)
        let traceWidth: CGFloat = 24  // Thicker traces for PCB look

        // Get all lanes (we render all 8, some active, some locked)
        let allLanes = MotherboardLaneConfig.createAllLanes()
        let unlockedSectorIds = gameStateDelegate?.getUnlockedSectorIds() ?? Set([SectorID.power.rawValue])

        // Get player profile for unlock eligibility check
        let playerProfile = AppState.shared.currentPlayer

        for lane in allLanes {
            let isUnlocked = lane.isStarterLane || unlockedSectorIds.contains(lane.sectorId)
            let canUnlock = !isUnlocked && MegaBoardSystem.shared.canUnlockSector(lane.sectorId, profile: playerProfile).canUnlock
            let dimAlpha: CGFloat = isUnlocked ? 1.0 : (canUnlock ? 0.5 : 0.25)

            // Create Manhattan-style path (straight lines, 90° turns)
            let bezierPath = UIBezierPath()
            let path = lane.path

            if let firstPoint = path.waypoints.first {
                bezierPath.move(to: convertToScene(firstPoint))

                for i in 1..<path.waypoints.count {
                    bezierPath.addLine(to: convertToScene(path.waypoints[i]))
                }
            }

            // Outer dark border (PCB substrate showing through)
            let borderNode = SKShapeNode()
            borderNode.path = bezierPath.cgPath
            borderNode.strokeColor = UIColor(red: 0.08, green: 0.08, blue: 0.12, alpha: dimAlpha)
            borderNode.lineWidth = traceWidth + 6
            borderNode.lineCap = .square  // Manhattan geometry - square caps
            borderNode.lineJoin = .miter  // Sharp 90° corners
            borderNode.zPosition = 1
            borderNode.name = "lane_border_\(lane.id)"
            pathLayer.addChild(borderNode)

            // Main copper trace - dimmed gray for locked, copper for active
            let pathNode = SKShapeNode()
            pathNode.path = bezierPath.cgPath
            if isUnlocked {
                pathNode.strokeColor = copperColor
            } else {
                // Desaturated gray-copper for locked
                pathNode.strokeColor = UIColor(red: 0.45, green: 0.40, blue: 0.35, alpha: dimAlpha)
            }
            pathNode.lineWidth = traceWidth
            pathNode.lineCap = .square
            pathNode.lineJoin = .miter
            pathNode.zPosition = 2
            pathNode.name = "lane_path_\(lane.id)"
            pathLayer.addChild(pathNode)

            // Inner highlight for 3D copper effect
            let highlightNode = SKShapeNode()
            highlightNode.path = bezierPath.cgPath
            highlightNode.strokeColor = copperHighlight.withAlphaComponent(isUnlocked ? 0.6 : 0.1)
            highlightNode.lineWidth = traceWidth * 0.4
            highlightNode.lineCap = .square
            highlightNode.lineJoin = .miter
            highlightNode.zPosition = 3
            highlightNode.name = "lane_highlight_\(lane.id)"
            pathLayer.addChild(highlightNode)

            // Add data flow indicators only for active lanes
            if isUnlocked {
                addMotherboardPathChevrons(for: path, pathWidth: traceWidth)

                // Create power LEDs along the lane for visual feedback
                createLEDsForLane(lane)
            }

            // Add spawn point visual
            renderSpawnPoint(for: lane, isUnlocked: isUnlocked, canUnlock: canUnlock)
        }
    }

    /// Render spawn point for a lane - pulsing for active, highlighted for unlockable, dimmed for locked
    private func renderSpawnPoint(for lane: SectorLane, isUnlocked: Bool, canUnlock: Bool = false) {
        let themeColor = UIColor(hex: lane.themeColorHex) ?? UIColor.yellow
        let spawnPos = convertToScene(lane.spawnPoint)

        let container = SKNode()
        container.position = spawnPos
        container.name = "spawn_\(lane.id)"
        container.zPosition = 10

        if isUnlocked {
            // Active spawn point: Pulsing themed circle
            let outerRing = SKShapeNode(circleOfRadius: 50)
            outerRing.fillColor = themeColor.withAlphaComponent(0.2)
            outerRing.strokeColor = themeColor
            outerRing.lineWidth = 3
            outerRing.glowWidth = 10
            container.addChild(outerRing)

            let innerCircle = SKShapeNode(circleOfRadius: 30)
            innerCircle.fillColor = UIColor.black.withAlphaComponent(0.8)
            innerCircle.strokeColor = themeColor.withAlphaComponent(0.8)
            innerCircle.lineWidth = 2
            container.addChild(innerCircle)

            // Direction arrow pointing toward CPU
            let arrow = createDirectionArrow(from: lane.spawnPoint, color: themeColor)
            container.addChild(arrow)

            // Pulse animation
            let pulse = SKAction.sequence([
                SKAction.scale(to: 1.1, duration: 1.0),
                SKAction.scale(to: 1.0, duration: 1.0)
            ])
            outerRing.run(SKAction.repeatForever(pulse))
        } else if canUnlock {
            // Unlockable spawn point: Highlighted with theme color and pulsing animation
            let outerRing = SKShapeNode(circleOfRadius: 55)
            outerRing.fillColor = themeColor.withAlphaComponent(0.15)
            outerRing.strokeColor = themeColor.withAlphaComponent(0.8)
            outerRing.lineWidth = 3
            outerRing.glowWidth = 8
            container.addChild(outerRing)

            // Pulsing animation to draw attention
            let pulse = SKAction.sequence([
                SKAction.scale(to: 1.1, duration: 0.8),
                SKAction.scale(to: 1.0, duration: 0.8)
            ])
            outerRing.run(SKAction.repeatForever(pulse))

            // Lock icon with theme color
            let lockIcon = createLockIcon(themeColor: themeColor, size: 40)
            container.addChild(lockIcon)

            // "TAP TO UNLOCK" hint
            let hintLabel = SKLabelNode(text: "TAP TO UNLOCK")
            hintLabel.fontName = "Menlo-Bold"
            hintLabel.fontSize = 10
            hintLabel.fontColor = themeColor
            hintLabel.position = CGPoint(x: 0, y: -55)
            hintLabel.horizontalAlignmentMode = .center
            hintLabel.verticalAlignmentMode = .center
            container.addChild(hintLabel)

            // Cost label below hint
            let costLabel = SKLabelNode(text: "Ħ \(lane.unlockCost)")
            costLabel.fontName = "Menlo-Bold"
            costLabel.fontSize = 14
            costLabel.fontColor = themeColor
            costLabel.position = CGPoint(x: 0, y: -75)
            costLabel.horizontalAlignmentMode = .center
            costLabel.verticalAlignmentMode = .center
            container.addChild(costLabel)

            // Lane name label above
            let nameLabel = SKLabelNode(text: lane.displayName.uppercased())
            nameLabel.fontName = "Menlo-Bold"
            nameLabel.fontSize = 12
            nameLabel.fontColor = themeColor.withAlphaComponent(0.9)
            nameLabel.position = CGPoint(x: 0, y: 75)
            nameLabel.horizontalAlignmentMode = .center
            nameLabel.verticalAlignmentMode = .center
            container.addChild(nameLabel)
        } else {
            // Locked spawn point (prerequisites not met): Gray circle with lock icon
            let outerRing = SKShapeNode(circleOfRadius: 50)
            outerRing.fillColor = UIColor.gray.withAlphaComponent(0.1)
            outerRing.strokeColor = UIColor.gray.withAlphaComponent(0.3)
            outerRing.lineWidth = 2
            container.addChild(outerRing)

            // Lock icon
            let lockIcon = createLockIcon(themeColor: UIColor.gray, size: 40)
            container.addChild(lockIcon)

            // Cost label below (dimmed)
            let costLabel = SKLabelNode(text: "Ħ \(lane.unlockCost)")
            costLabel.fontName = "Menlo-Bold"
            costLabel.fontSize = 14
            costLabel.fontColor = UIColor.gray.withAlphaComponent(0.5)
            costLabel.position = CGPoint(x: 0, y: -70)
            costLabel.horizontalAlignmentMode = .center
            costLabel.verticalAlignmentMode = .center
            container.addChild(costLabel)

            // Lane name label above (dimmed)
            let nameLabel = SKLabelNode(text: lane.displayName.uppercased())
            nameLabel.fontName = "Menlo"
            nameLabel.fontSize = 10
            nameLabel.fontColor = UIColor.gray.withAlphaComponent(0.4)
            nameLabel.position = CGPoint(x: 0, y: 70)
            nameLabel.horizontalAlignmentMode = .center
            nameLabel.verticalAlignmentMode = .center
            container.addChild(nameLabel)
        }

        pathLayer.addChild(container)
    }

    /// Create direction arrow pointing from spawn toward CPU
    private func createDirectionArrow(from spawnPoint: CGPoint, color: UIColor) -> SKShapeNode {
        let cpuCenter = MotherboardLaneConfig.cpuCenter
        let dx = cpuCenter.x - spawnPoint.x
        let dy = cpuCenter.y - spawnPoint.y
        let angle = atan2(dy, dx)

        let arrowPath = UIBezierPath()
        let size: CGFloat = 15
        arrowPath.move(to: CGPoint(x: size, y: 0))
        arrowPath.addLine(to: CGPoint(x: -size/2, y: size * 0.6))
        arrowPath.addLine(to: CGPoint(x: -size/2, y: -size * 0.6))
        arrowPath.close()

        let arrow = SKShapeNode(path: arrowPath.cgPath)
        arrow.fillColor = color.withAlphaComponent(0.8)
        arrow.strokeColor = color
        arrow.lineWidth = 1
        arrow.zRotation = angle
        return arrow
    }

    /// Create lock icon for locked spawn points
    private func createLockIcon(themeColor: UIColor, size: CGFloat) -> SKNode {
        let container = SKNode()
        let color = themeColor.withAlphaComponent(0.6)

        // Lock body
        let body = SKShapeNode(rect: CGRect(x: -size/2, y: -size/2, width: size, height: size), cornerRadius: 4)
        body.fillColor = UIColor.black.withAlphaComponent(0.8)
        body.strokeColor = color
        body.lineWidth = 2
        container.addChild(body)

        // Shackle (arc above lock body)
        let shacklePath = UIBezierPath()
        let shackleWidth: CGFloat = size * 0.6
        shacklePath.move(to: CGPoint(x: -shackleWidth/2, y: size/2))
        shacklePath.addLine(to: CGPoint(x: -shackleWidth/2, y: size/2 + 8))
        shacklePath.addArc(
            withCenter: CGPoint(x: 0, y: size/2 + 8),
            radius: shackleWidth/2,
            startAngle: .pi,
            endAngle: 0,
            clockwise: true
        )
        shacklePath.addLine(to: CGPoint(x: shackleWidth/2, y: size/2))

        let shackle = SKShapeNode(path: shacklePath.cgPath)
        shackle.strokeColor = color
        shackle.lineWidth = 3
        shackle.lineCap = .round
        container.addChild(shackle)

        // Keyhole
        let keyhole = SKShapeNode(circleOfRadius: 5)
        keyhole.fillColor = color
        keyhole.strokeColor = .clear
        keyhole.position = CGPoint(x: 0, y: 4)
        container.addChild(keyhole)

        return container
    }

    /// Add data flow chevrons for motherboard paths
    private func addMotherboardPathChevrons(for path: EnemyPath, pathWidth: CGFloat) {
        guard path.waypoints.count >= 2 else { return }

        let chevronSpacing: CGFloat = 150
        let glowColor = UIColor(hex: MotherboardColors.activeGlow) ?? UIColor.green

        for i in 0..<(path.waypoints.count - 1) {
            let start = convertToScene(path.waypoints[i])
            let end = convertToScene(path.waypoints[i + 1])

            let dx = end.x - start.x
            let dy = end.y - start.y
            let segmentLength = sqrt(dx*dx + dy*dy)
            let angle = atan2(dy, dx)

            let chevronCount = Int(segmentLength / chevronSpacing)

            for j in 1...max(1, chevronCount) {
                let t = CGFloat(j) / CGFloat(chevronCount + 1)
                let x = start.x + dx * t
                let y = start.y + dy * t

                // Small glowing dot instead of chevron for PCB aesthetic
                let dot = SKShapeNode(circleOfRadius: 4)
                dot.position = CGPoint(x: x, y: y)
                dot.fillColor = glowColor.withAlphaComponent(0.8)
                dot.strokeColor = .clear
                dot.zPosition = 4
                dot.glowWidth = 3
                dot.blendMode = .add
                pathLayer.addChild(dot)

                // Pulse animation
                let fadeOut = SKAction.fadeAlpha(to: 0.3, duration: 0.8)
                let fadeIn = SKAction.fadeAlpha(to: 0.9, duration: 0.8)
                let delay = SKAction.wait(forDuration: Double(j) * 0.15)
                let pulse = SKAction.sequence([delay, SKAction.repeatForever(SKAction.sequence([fadeOut, fadeIn]))])
                dot.run(pulse)
            }
        }
    }

    // MARK: - Path LED System

    /// Create LED nodes along a lane path for visual feedback
    /// LEDs react to enemy proximity and type
    private func createLEDsForLane(_ lane: SectorLane) {
        let path = lane.path
        guard path.waypoints.count >= 2 else { return }

        let ledSpacing: CGFloat = 60  // LED every 60 points
        var leds: [SKShapeNode] = []

        // Get theme color for this lane's sector
        let themeColor = UIColor(hex: lane.themeColorHex) ?? UIColor.yellow

        // Calculate total path length and place LEDs evenly
        for i in 0..<(path.waypoints.count - 1) {
            let start = convertToScene(path.waypoints[i])
            let end = convertToScene(path.waypoints[i + 1])

            let dx = end.x - start.x
            let dy = end.y - start.y
            let segmentLength = sqrt(dx * dx + dy * dy)

            let ledCount = Int(segmentLength / ledSpacing)
            guard ledCount > 0 else { continue }

            for j in 1...ledCount {
                let t = CGFloat(j) / CGFloat(ledCount + 1)
                let x = start.x + dx * t
                let y = start.y + dy * t

                // Create LED node
                let led = SKShapeNode(circleOfRadius: 3)
                led.position = CGPoint(x: x, y: y)
                led.fillColor = themeColor.withAlphaComponent(0.3)  // Dim idle state
                led.strokeColor = themeColor.withAlphaComponent(0.5)
                led.lineWidth = 1
                led.glowWidth = 2  // Subtle glow
                led.zPosition = 5  // Above path, below enemies
                led.blendMode = .add
                led.name = "led_\(lane.id)_\(leds.count)"

                pathLayer.addChild(led)
                leds.append(led)
            }
        }

        pathLEDNodes[lane.id] = leds

        // Start idle heartbeat animation for this lane's LEDs
        startLEDIdleAnimation(for: lane.id, themeColor: themeColor)
    }

    /// Start the idle heartbeat pulse animation for LEDs
    private func startLEDIdleAnimation(for laneId: String, themeColor: UIColor) {
        guard let leds = pathLEDNodes[laneId] else { return }

        // Heartbeat pulse: dim -> bright -> dim (1.2s cycle)
        let dimColor = themeColor.withAlphaComponent(0.2)
        let brightColor = themeColor.withAlphaComponent(0.5)

        for (index, led) in leds.enumerated() {
            // Stagger the animation start by LED position
            let delay = Double(index) * 0.05

            let pulse = SKAction.sequence([
                SKAction.wait(forDuration: delay),
                SKAction.repeatForever(SKAction.sequence([
                    SKAction.group([
                        SKAction.customAction(withDuration: 0.3) { node, elapsed in
                            let shape = node as? SKShapeNode
                            let progress = elapsed / 0.3
                            shape?.glowWidth = 2 + 2 * progress  // 2 -> 4
                            shape?.fillColor = dimColor.interpolate(to: brightColor, progress: progress)
                        },
                    ]),
                    SKAction.group([
                        SKAction.customAction(withDuration: 0.9) { node, elapsed in
                            let shape = node as? SKShapeNode
                            let progress = elapsed / 0.9
                            shape?.glowWidth = 4 - 2 * progress  // 4 -> 2
                            shape?.fillColor = brightColor.interpolate(to: dimColor, progress: progress)
                        },
                    ]),
                ]))
            ])

            led.run(pulse, withKey: "idlePulse")
        }
    }

    /// Update LED states based on enemy proximity
    /// Called from update loop (every 3 frames for performance)
    // Cached lane config for LED updates (avoids per-frame allocation)
    private lazy var cachedLaneConfig: [SectorLane] = MotherboardLaneConfig.createAllLanes()
    private lazy var laneColorCache: [String: UIColor] = {
        var cache: [String: UIColor] = [:]
        for lane in MotherboardLaneConfig.createAllLanes() {
            cache[lane.id] = UIColor(hex: lane.themeColorHex) ?? UIColor.yellow
        }
        return cache
    }()

    private func updatePathLEDs(enemies: [TDEnemy]) {
        // Performance: only update every 3 frames
        ledUpdateCounter += 1
        guard ledUpdateCounter % 3 == 0 else { return }

        // Performance: skip LED updates when zoomed out
        guard currentScale < 0.8 else { return }

        // Performance: only update LEDs in visible area
        let visibleRect = calculateVisibleRect()
        let paddedRect = visibleRect.insetBy(dx: -150, dy: -150)

        // Group enemies by lane (only alive enemies)
        var enemiesByLane: [String: [TDEnemy]] = [:]
        for enemy in enemies where !enemy.isDead && !enemy.reachedCore {
            if let laneId = enemy.laneId {
                enemiesByLane[laneId, default: []].append(enemy)
            }
        }

        // Update each lane's LEDs
        for (laneId, leds) in pathLEDNodes {
            let laneEnemies = enemiesByLane[laneId] ?? []

            // Get lane theme color from cache
            let themeColor = laneColorCache[laneId] ?? UIColor.yellow

            for led in leds {
                // Skip LEDs outside visible area
                guard paddedRect.contains(led.position) else { continue }
                // Find nearest enemy to this LED
                let ledPosition = led.position
                var minDistance: CGFloat = .infinity
                var nearestEnemy: TDEnemy?

                for enemy in laneEnemies {
                    let enemyPos = convertToScene(enemy.position)
                    let dx = enemyPos.x - ledPosition.x
                    let dy = enemyPos.y - ledPosition.y
                    let distance = sqrt(dx * dx + dy * dy)

                    if distance < minDistance {
                        minDistance = distance
                        nearestEnemy = enemy
                    }
                }

                // Calculate intensity based on proximity (100pt range)
                let proximityRange: CGFloat = 100
                let intensity = max(0, 1 - minDistance / proximityRange)

                if intensity > 0.1, let enemy = nearestEnemy {
                    // Enemy nearby - override idle animation with active state
                    led.removeAction(forKey: "idlePulse")

                    // Determine color based on enemy type
                    let activeColor: UIColor
                    let activeGlow: CGFloat

                    switch enemy.type {
                    case "boss":
                        // Boss: white pulsing, extra wide glow
                        activeColor = UIColor.white
                        activeGlow = 8 + intensity * 4
                    case "tank":
                        // Tank: brighter, wider glow
                        activeColor = themeColor
                        activeGlow = 5 + intensity * 4
                    case "fast":
                        // Fast: orange tint
                        activeColor = UIColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 1.0)
                        activeGlow = 3 + intensity * 3
                    default:
                        // Basic: lane theme color
                        activeColor = themeColor
                        activeGlow = 2 + intensity * 4
                    }

                    // Apply active state
                    led.fillColor = activeColor.withAlphaComponent(0.4 + intensity * 0.6)
                    led.strokeColor = activeColor.withAlphaComponent(0.7 + intensity * 0.3)
                    led.glowWidth = activeGlow

                    // Boss special: rapid flicker
                    if enemy.type == "boss" || enemy.isBoss {
                        let flicker = SKAction.sequence([
                            SKAction.run { led.glowWidth = activeGlow * 1.3 },
                            SKAction.wait(forDuration: 0.05),
                            SKAction.run { led.glowWidth = activeGlow * 0.7 },
                            SKAction.wait(forDuration: 0.05),
                        ])
                        led.run(SKAction.repeatForever(flicker), withKey: "bossFlicker")
                    } else {
                        led.removeAction(forKey: "bossFlicker")
                    }
                } else {
                    // No enemy nearby - restore idle animation if not running
                    led.removeAction(forKey: "bossFlicker")
                    if led.action(forKey: "idlePulse") == nil {
                        startLEDIdleAnimationForSingleLED(led, themeColor: themeColor)
                    }
                }
            }
        }
    }

    /// Start idle animation for a single LED (when returning from active state)
    private func startLEDIdleAnimationForSingleLED(_ led: SKShapeNode, themeColor: UIColor) {
        let dimColor = themeColor.withAlphaComponent(0.2)
        let brightColor = themeColor.withAlphaComponent(0.5)

        let pulse = SKAction.repeatForever(SKAction.sequence([
            SKAction.group([
                SKAction.customAction(withDuration: 0.3) { node, elapsed in
                    let shape = node as? SKShapeNode
                    let progress = elapsed / 0.3
                    shape?.glowWidth = 2 + 2 * progress
                    shape?.fillColor = dimColor.interpolate(to: brightColor, progress: progress)
                },
            ]),
            SKAction.group([
                SKAction.customAction(withDuration: 0.9) { node, elapsed in
                    let shape = node as? SKShapeNode
                    let progress = elapsed / 0.9
                    shape?.glowWidth = 4 - 2 * progress
                    shape?.fillColor = brightColor.interpolate(to: dimColor, progress: progress)
                },
            ]),
        ]))

        led.run(pulse, withKey: "idlePulse")
    }

    /// Add direction indicator chevrons along the path
    private func addPathChevrons(for path: EnemyPath, pathWidth: CGFloat) {
        guard path.waypoints.count >= 2 else { return }

        // Place chevrons every ~100pt along the path
        let chevronSpacing: CGFloat = 100

        for i in 0..<(path.waypoints.count - 1) {
            let start = convertToScene(path.waypoints[i])
            let end = convertToScene(path.waypoints[i + 1])

            let dx = end.x - start.x
            let dy = end.y - start.y
            let segmentLength = sqrt(dx*dx + dy*dy)
            let angle = atan2(dy, dx)

            // Number of chevrons for this segment
            let chevronCount = Int(segmentLength / chevronSpacing)

            for j in 1...max(1, chevronCount) {
                let t = CGFloat(j) / CGFloat(chevronCount + 1)
                let x = start.x + dx * t
                let y = start.y + dy * t

                let chevron = createChevron()
                chevron.position = CGPoint(x: x, y: y)
                chevron.zRotation = angle
                chevron.zPosition = 2
                pathLayer.addChild(chevron)

                // Subtle fade animation for movement indication
                let fadeOut = SKAction.fadeAlpha(to: 0.2, duration: 1.0)
                let fadeIn = SKAction.fadeAlpha(to: 0.6, duration: 1.0)
                let delay = SKAction.wait(forDuration: Double(j) * 0.3)
                let sequence = SKAction.sequence([delay, fadeOut, fadeIn])
                chevron.run(SKAction.repeatForever(sequence))
            }
        }
    }

    /// Create a path direction chevron
    private func createChevron() -> SKShapeNode {
        let path = UIBezierPath()
        let size: CGFloat = 10
        path.move(to: CGPoint(x: -size, y: size * 0.6))
        path.addLine(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: -size, y: -size * 0.6))

        let chevron = SKShapeNode(path: path.cgPath)
        chevron.strokeColor = DesignColors.pathBorderUI.withAlphaComponent(0.6)
        chevron.fillColor = .clear
        chevron.lineWidth = 3
        chevron.lineCap = .round
        chevron.alpha = 0.5
        return chevron
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

    private func setupBlockers() {
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

    // MARK: - Placement Mode (Progressive Disclosure)

    /// Enter placement mode - brighten grid dots
    func enterPlacementMode(weaponType: String) {
        guard !isInPlacementMode else { return }

        isInPlacementMode = true
        placementWeaponType = weaponType

        // Brighten grid dots during placement (from ambient 0.3 to full visibility)
        gridDotsLayer.run(SKAction.fadeAlpha(to: 1.0, duration: DesignAnimations.Timing.quick))

        // Update grid dots to show only unoccupied slots
        updateGridDotsVisibility()
    }

    /// Exit placement mode - dim grid dots back to ambient level
    func exitPlacementMode() {
        guard isInPlacementMode else { return }

        isInPlacementMode = false
        placementWeaponType = nil

        // Dim grid dots back to ambient visibility
        gridDotsLayer.run(SKAction.fadeAlpha(to: 0.3, duration: DesignAnimations.Timing.quick))

        // Remove active slot highlight
        activeSlotHighlight?.removeFromParent()
        activeSlotHighlight = nil
    }

    /// Update grid dot visibility based on slot occupation
    private func updateGridDotsVisibility() {
        guard let state = state else { return }

        for slot in state.towerSlots {
            // Use SKNode instead of SKShapeNode since createGridDot now returns a container
            if let dotNode = gridDotsLayer.childNode(withName: "gridDot_\(slot.id)") {
                if slot.occupied {
                    dotNode.alpha = 0
                } else {
                    dotNode.alpha = 1
                }
            }
        }
    }

    /// Highlight the nearest valid slot during drag with enhanced visuals
    func highlightNearestSlot(_ slot: TowerSlot?, canAfford: Bool) {
        // Remove existing highlight
        activeSlotHighlight?.removeFromParent()
        activeSlotHighlight = nil

        guard let slot = slot, !slot.occupied else { return }

        // Create highlight container
        let container = SKNode()
        container.position = convertToScene(slot.position)
        container.name = "slotHighlight"
        container.zPosition = 8

        // Outer glow ring
        let outerRing = SKShapeNode(circleOfRadius: 45)
        outerRing.fillColor = .clear
        outerRing.strokeColor = canAfford ? DesignColors.primaryUI : DesignColors.dangerUI
        outerRing.lineWidth = 3
        outerRing.glowWidth = 10
        outerRing.alpha = 0.8
        container.addChild(outerRing)

        // Inner fill
        let innerFill = SKShapeNode(circleOfRadius: 35)
        innerFill.fillColor = (canAfford ? DesignColors.primaryUI : DesignColors.dangerUI).withAlphaComponent(0.2)
        innerFill.strokeColor = .clear
        container.addChild(innerFill)

        // Crosshair lines for targeting aesthetic
        let crosshairSize: CGFloat = 50
        let crosshairGap: CGFloat = 15
        let crosshairColor = canAfford ? DesignColors.primaryUI : DesignColors.dangerUI

        // Horizontal lines
        for xSign in [-1.0, 1.0] as [CGFloat] {
            let line = SKShapeNode()
            let path = CGMutablePath()
            path.move(to: CGPoint(x: crosshairGap * xSign, y: 0))
            path.addLine(to: CGPoint(x: crosshairSize * xSign, y: 0))
            line.path = path
            line.strokeColor = crosshairColor.withAlphaComponent(0.8)
            line.lineWidth = 2
            container.addChild(line)
        }

        // Vertical lines
        for ySign in [-1.0, 1.0] as [CGFloat] {
            let line = SKShapeNode()
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: crosshairGap * ySign))
            path.addLine(to: CGPoint(x: 0, y: crosshairSize * ySign))
            line.path = path
            line.strokeColor = crosshairColor.withAlphaComponent(0.8)
            line.lineWidth = 2
            container.addChild(line)
        }

        // Corner brackets for circuit board aesthetic
        let bracketSize: CGFloat = 12
        let bracketOffset: CGFloat = 32
        for (xSign, ySign) in [(1, 1), (1, -1), (-1, 1), (-1, -1)] as [(CGFloat, CGFloat)] {
            let bracket = SKShapeNode()
            let path = CGMutablePath()
            path.move(to: CGPoint(x: bracketOffset * xSign, y: (bracketOffset + bracketSize) * ySign))
            path.addLine(to: CGPoint(x: bracketOffset * xSign, y: bracketOffset * ySign))
            path.addLine(to: CGPoint(x: (bracketOffset + bracketSize) * xSign, y: bracketOffset * ySign))
            bracket.path = path
            bracket.strokeColor = crosshairColor.withAlphaComponent(0.6)
            bracket.lineWidth = 2
            bracket.lineCap = .round
            container.addChild(bracket)
        }

        // Pulse animation
        let pulse = SKAction.repeatForever(SKAction.sequence([
            SKAction.scale(to: 1.15, duration: 0.4),
            SKAction.scale(to: 1.0, duration: 0.4)
        ]))
        container.run(pulse)

        addChild(container)
        activeSlotHighlight = container
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
                    print("[TDGameScene] Idle spawn enabled - starting continuous enemy spawning")
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

                    // Log occasionally (every 10th enemy)
                    if state.idleEnemiesSpawned % 10 == 1 {
                        let (threatName, _) = IdleSpawnSystem.getThreatLevelInfo(threatLevel: state.idleThreatLevel)
                        print("[TD-Idle] Spawned \(enemy.type) | Total: \(state.idleEnemiesSpawned) | Threat: \(threatName) (\(String(format: "%.1f", state.idleThreatLevel)))")
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
        updateCameraPhysics(deltaTime: deltaTime)

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

        // TD Idle Mode: Log state changes (not every frame)
        let currentEnemyCount = state.enemies.filter { !$0.isDead && !$0.reachedCore }.count
        let currentThreatInt = Int(state.idleThreatLevel * 10)  // Track at 0.1 precision
        if currentEnemyCount != lastLoggedEnemyCount || currentThreatInt != lastLoggedWaveNumber {
            let (threatName, _) = IdleSpawnSystem.getThreatLevelInfo(threatLevel: state.idleThreatLevel)
            print("[TD-Idle] Threat: \(threatName) (\(String(format: "%.1f", state.idleThreatLevel))) | Enemies: \(currentEnemyCount) | Towers: \(state.towers.count) | Hash: \(state.hash) | Efficiency: \(Int(state.efficiency))%")
            lastLoggedEnemyCount = currentEnemyCount
            lastLoggedWaveNumber = currentThreatInt
        }

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

                // Only log first spawn of the wave
                if state.waveEnemiesSpawned == 1 {
                    print("[TD-Board] First enemy of wave \(wave.waveNumber) spawned: \(enemy.type) at (\(Int(enemy.x)), \(Int(enemy.y)))")
                }
            } else if state.waveEnemiesSpawned < state.waveEnemiesRemaining {
                print("[TD-Board] ERROR: spawnNextEnemy returned nil but spawned \(state.waveEnemiesSpawned)/\(state.waveEnemiesRemaining)")
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
                        state.stats.goldEarned += actualGold
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
                    state.stats.goldEarned += actualGold
                    state.stats.enemiesKilled += 1
                    state.virusesKilledTotal += 1  // For passive Data generation
                    state.waveEnemiesRemaining -= 1
                }

                state.enemies[i] = enemy
            }
        }
    }

    // MARK: - Scrolling Combat Text

    private func renderDamageEvents(state: inout TDGameState) {
        // Process and display new damage events
        for i in 0..<state.damageEvents.count {
            guard !state.damageEvents[i].displayed else { continue }

            let event = state.damageEvents[i]

            // Convert game position to scene position
            let scenePosition = convertToScene(event.position)

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
                combatText.show("IMMUNE", type: .shield, at: scenePosition)
            }

            state.damageEvents[i].displayed = true
        }

        // Clean up old damage events (older than 2 seconds)
        state.damageEvents.removeAll { state.gameTime - $0.timestamp > 2.0 }
    }

    // MARK: - Cleanup

    private func cleanupDeadEntities(state: inout TDGameState) {
        // Remove dead enemies
        state.enemies.removeAll { $0.isDead || $0.reachedCore }

        // Clean up previous positions for removed projectiles
        let activeProjectileIds = Set(state.projectiles.map { $0.id })
        projectilePrevPositions = projectilePrevPositions.filter { activeProjectileIds.contains($0.key) }
    }

    // MARK: - Visual Updates

    private func updateTowerVisuals(state: TDGameState) {
        // Remove old tower nodes
        for (id, node) in towerNodes {
            if !state.towers.contains(where: { $0.id == id }) {
                node.removeFromParent()
                towerNodes.removeValue(forKey: id)
                towerLastAttackTimes.removeValue(forKey: id)
                towerBarrelRotations.removeValue(forKey: id)
                pausedTowerAnimations.remove(id)  // Clean up animation LOD tracking
            }
        }

        // Update/create tower nodes
        for tower in state.towers {
            if let node = towerNodes[tower.id] {
                // Update existing
                node.position = convertToScene(tower.position)

                // Update range indicator visibility with animation
                let shouldShowRange = tower.id == selectedTowerId || isDragging
                if let rangeNode = node.childNode(withName: "range") {
                    if shouldShowRange && rangeNode.isHidden {
                        TowerAnimations.showRange(node: node, animated: true)
                    } else if !shouldShowRange && !rangeNode.isHidden {
                        TowerAnimations.hideRange(node: node, animated: true)
                    }
                }

                // Update rotation (barrel points to target) - Smooth interpolation
                if let barrel = node.childNode(withName: "barrel") {
                    let targetRotation = tower.rotation - .pi/2

                    // Get current tracked rotation, or initialize from node
                    let currentRotation = towerBarrelRotations[tower.id] ?? barrel.zRotation

                    // Calculate angle difference (normalized to -π to π)
                    var angleDiff = targetRotation - currentRotation
                    while angleDiff > .pi { angleDiff -= 2 * .pi }
                    while angleDiff < -.pi { angleDiff += 2 * .pi }

                    // Calculate maximum rotation this frame (based on deltaTime if available, else assume 1/60)
                    let deltaTime = lastUpdateTime > 0 ? (state.gameTime - (towerLastAttackTimes[tower.id] ?? state.gameTime - 1/60)) : 1/60
                    let maxDelta = barrelRotationSpeed * CGFloat(abs(deltaTime) > 0 ? min(abs(deltaTime), 0.1) : 1/60)

                    // Clamp rotation to max speed
                    let actualDelta: CGFloat
                    if abs(angleDiff) <= maxDelta {
                        actualDelta = angleDiff  // Snap if close enough
                    } else {
                        actualDelta = angleDiff > 0 ? maxDelta : -maxDelta
                    }

                    let newRotation = currentRotation + actualDelta
                    barrel.zRotation = newRotation
                    towerBarrelRotations[tower.id] = newRotation
                }

                // Update level indicator if level changed
                if let levelNode = node.childNode(withName: "levelIndicator") {
                    if let levelLabel = levelNode.childNode(withName: "levelLabel") as? SKLabelNode {
                        if levelLabel.text != "\(tower.level)" {
                            levelLabel.text = "\(tower.level)"
                        }
                    }
                }

                // Update cooldown arc
                updateCooldownArc(for: tower, node: node, currentTime: state.gameTime)

                // Detect firing (lastAttackTime changed) and trigger animation
                if let prevAttackTime = towerLastAttackTimes[tower.id] {
                    if tower.lastAttackTime > prevAttackTime {
                        triggerTowerFireAnimation(node: node, tower: tower)
                    }
                }
                towerLastAttackTimes[tower.id] = tower.lastAttackTime

            } else {
                // Create new tower node
                let node = createTowerNode(tower: tower)
                node.position = convertToScene(tower.position)
                towerLayer.addChild(node)
                towerNodes[tower.id] = node

                // Spawn placement particles
                spawnPlacementParticles(at: convertToScene(tower.position), color: UIColor(hex: tower.color) ?? .blue)

                // Haptic feedback
                HapticsService.shared.play(.towerPlace)
            }
        }
    }

    /// Trigger tower firing animation (recoil + muzzle flash)
    private func triggerTowerFireAnimation(node: SKNode, tower: Tower) {
        let towerColor = UIColor(hex: tower.color) ?? TowerColors.color(for: tower.weaponType)
        let archetype = TowerVisualFactory.TowerArchetype.from(weaponType: tower.weaponType)

        // Use enhanced archetype-specific muzzle flash
        TowerAnimations.playEnhancedMuzzleFlash(node: node, archetype: archetype, color: towerColor)
        TowerAnimations.playRecoil(node: node, intensity: archetype == .artillery ? 5.0 : 3.0)

        // Special effects for certain archetypes
        switch archetype {
        case .legendary:
            // Excalibur golden flash on attack
            if Bool.random() && Bool.random() {  // ~25% chance for special effect
                TowerAnimations.playLegendarySpecialEffect(node: node)
            }
        case .execute:
            // Null pointer glitch effect
            TowerAnimations.playExecuteEffect(node: node)
        case .tesla:
            // Tesla arc flash handled by idle animation
            break
        default:
            break
        }

        // Glow intensify on fire
        if let glow = node.childNode(withName: "glow") {
            glow.removeAction(forKey: "fireGlow")
            let intensify = SKAction.group([
                SKAction.scale(to: 1.3, duration: 0.05),
                SKAction.fadeAlpha(to: 1.3, duration: 0.05)
            ])
            let restore = SKAction.group([
                SKAction.scale(to: 1.0, duration: 0.15),
                SKAction.fadeAlpha(to: 1.0, duration: 0.15)
            ])
            restore.timingMode = .easeOut
            glow.run(SKAction.sequence([intensify, restore]), withKey: "fireGlow")
        }

        // Motherboard-specific effects
        if isMotherboardMap {
            let towerPos = CGPoint(x: tower.x, y: tower.y)

            // Trigger capacitor discharge if tower is in PSU sector area
            triggerCapacitorDischarge(near: convertToScene(towerPos))

            // NOTE: Trace pulses removed - lanes should only have LEDs
            // let towerColor = UIColor(hex: tower.color) ?? UIColor.yellow
            // spawnTracePulse(at: towerPos, color: towerColor)
        }
    }

    /// Update cooldown arc indicator on tower
    private func updateCooldownArc(for tower: Tower, node: SKNode, currentTime: TimeInterval) {
        guard let cooldownNode = node.childNode(withName: "cooldown") as? SKShapeNode else { return }

        // Guard against invalid attack speed (prevents NaN/Infinity angles)
        guard tower.attackSpeed > 0 else {
            cooldownNode.isHidden = true
            return
        }

        let attackInterval = 1.0 / tower.attackSpeed
        let timeSinceAttack = currentTime - tower.lastAttackTime
        let cooldownProgress = min(1.0, max(0.0, timeSinceAttack / attackInterval))

        // Guard against NaN progress values
        guard cooldownProgress.isFinite else {
            cooldownNode.isHidden = true
            return
        }

        if cooldownProgress < 1.0 && cooldownProgress > 0.0 {
            // Show and update cooldown arc
            cooldownNode.isHidden = false

            let radius: CGFloat = 18
            let startAngle = -CGFloat.pi / 2
            let endAngle = startAngle + (CGFloat.pi * 2 * CGFloat(cooldownProgress))

            let path = UIBezierPath(arcCenter: .zero, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
            cooldownNode.path = path.cgPath
        } else {
            cooldownNode.isHidden = true
        }
    }

    /// Spawn particles when tower is placed
    private func spawnPlacementParticles(at position: CGPoint, color: UIColor) {
        let particleCount = 12

        for i in 0..<particleCount {
            let particle = SKShapeNode(circleOfRadius: CGFloat.random(in: 2...4))
            particle.fillColor = color
            particle.strokeColor = .white
            particle.lineWidth = 1
            particle.position = position
            particle.zPosition = 50

            let angle = CGFloat(i) * (.pi * 2 / CGFloat(particleCount))
            let distance: CGFloat = 40

            let moveAction = SKAction.move(by: CGVector(dx: cos(angle) * distance, dy: sin(angle) * distance), duration: 0.3)
            moveAction.timingMode = .easeOut
            let fadeAction = SKAction.fadeOut(withDuration: 0.3)
            let group = SKAction.group([moveAction, fadeAction])
            let sequence = SKAction.sequence([group, SKAction.removeFromParent()])

            particle.run(sequence)
            particleLayer.addChild(particle)
        }
    }

    private func createTowerNode(tower: Tower) -> SKNode {
        // Use the new AAA Tower Visual Factory for rich, multi-layered visuals
        let towerColor = UIColor(hex: tower.color) ?? TowerColors.color(for: tower.weaponType)
        let rarityString: String
        switch tower.rarity {
        case .common: rarityString = "common"
        case .rare: rarityString = "rare"
        case .epic: rarityString = "epic"
        case .legendary: rarityString = "legendary"
        }

        return TowerVisualFactory.createTowerNode(
            weaponType: tower.weaponType,
            color: towerColor,
            range: tower.range,
            level: tower.level,
            damage: tower.damage,
            attackSpeed: tower.attackSpeed,
            projectileCount: tower.projectileCount,
            rarity: rarityString
        )
    }

    /// Update Level of Detail visibility based on camera zoom and viewport culling
    private func updateTowerLOD() {
        // Show details when zoomed in (scale < 0.4 means close-up)
        let showDetail = currentScale < 0.4
        let targetAlpha: CGFloat = showDetail ? 1.0 : 0.0

        // Calculate visible rect once for performance
        let visibleRect = calculateVisibleRect()
        // Expand rect slightly to avoid animation pop-in at edges
        let paddedRect = visibleRect.insetBy(dx: -100, dy: -100)

        for (towerId, node) in towerNodes {
            // LOD detail visibility based on zoom
            if let lodDetail = node.childNode(withName: "lodDetail") {
                // Only animate if needed
                if abs(lodDetail.alpha - targetAlpha) > 0.01 {
                    lodDetail.removeAction(forKey: "lodFade")
                    let fadeAction = SKAction.fadeAlpha(to: targetAlpha, duration: 0.2)
                    lodDetail.run(fadeAction, withKey: "lodFade")
                }
            }

            // Animation LOD: Pause animations for off-screen towers
            let isVisible = paddedRect.contains(node.position)

            if isVisible && pausedTowerAnimations.contains(towerId) {
                // Tower came into view - resume animations
                node.isPaused = false
                pausedTowerAnimations.remove(towerId)
            } else if !isVisible && !pausedTowerAnimations.contains(towerId) {
                // Tower went off-screen - pause animations
                node.isPaused = true
                pausedTowerAnimations.insert(towerId)
            }
        }
    }

    /// Calculate the visible rectangle in scene coordinates
    private func calculateVisibleRect() -> CGRect {
        guard let camera = cameraNode, let view = self.view else {
            return CGRect(x: 0, y: 0, width: size.width, height: size.height)
        }

        let viewWidth = view.bounds.width * currentScale
        let viewHeight = view.bounds.height * currentScale

        return CGRect(
            x: camera.position.x - viewWidth / 2,
            y: camera.position.y - viewHeight / 2,
            width: viewWidth,
            height: viewHeight
        )
    }

    // MARK: - Sector Visibility Culling (Performance)

    /// Update which sectors are visible and pause/resume ambient effects accordingly
    private func updateSectorVisibility(currentTime: TimeInterval) {
        // Only update every 0.5 seconds to avoid per-frame overhead
        guard currentTime - lastVisibilityUpdate >= visibilityUpdateInterval else { return }
        lastVisibilityUpdate = currentTime

        let visibleRect = calculateVisibleRect()
        // Expand rect to include sectors partially visible (sector size is 1400)
        let paddedRect = visibleRect.insetBy(dx: -700, dy: -700)

        let megaConfig = MegaBoardConfig.createDefault()
        var newVisibleSectors = Set<String>()

        for sector in megaConfig.sectors {
            let sectorRect = CGRect(
                x: sector.worldX,
                y: sector.worldY,
                width: sector.width,
                height: sector.height
            )

            if paddedRect.intersects(sectorRect) {
                newVisibleSectors.insert(sector.id)
            }
        }

        // Resume effects for sectors that came into view
        let sectorsNowVisible = newVisibleSectors.subtracting(visibleSectorIds)
        for sectorId in sectorsNowVisible {
            resumeSectorAmbientEffects(sectorId: sectorId)
        }

        // Pause effects for sectors that went out of view
        let sectorsNowHidden = visibleSectorIds.subtracting(newVisibleSectors)
        for sectorId in sectorsNowHidden {
            pauseSectorAmbientEffects(sectorId: sectorId)
        }

        visibleSectorIds = newVisibleSectors
    }

    /// Pause ambient effect actions for a sector
    private func pauseSectorAmbientEffects(sectorId: String) {
        // Each sector has actions with keys like "gpuHeat_gpu", "ramPulse_ram", etc.
        let actionKeys = [
            "gpuHeat_\(sectorId)",
            "ramPulse_\(sectorId)",
            "storageTrail_\(sectorId)",
            "networkRings_\(sectorId)",
            "ioBurst_\(sectorId)",
            "cacheFlash_\(sectorId)",
            "cacheLines_\(sectorId)"
        ]

        for key in actionKeys {
            backgroundLayer.removeAction(forKey: key)
        }
    }

    /// Resume ambient effect actions for a sector (re-start them)
    private func resumeSectorAmbientEffects(sectorId: String) {
        guard let sector = MegaBoardConfig.createDefault().sectors.first(where: { $0.id == sectorId }) else { return }

        // Re-start the appropriate ambient effects based on sector theme
        switch sector.theme {
        case .graphics:
            // GPU: Re-add heat shimmer spawning
            let themeColor = UIColor(hex: sector.theme.primaryColorHex) ?? .red
            let center = CGPoint(x: sector.worldX + sector.width / 2, y: sector.worldY + sector.height / 2)
            let spawnShimmer = SKAction.run { [weak self] in
                guard let self = self else { return }
                self.spawnHeatShimmer(at: center, color: themeColor)
            }
            let shimmerSequence = SKAction.repeatForever(SKAction.sequence([
                spawnShimmer,
                SKAction.wait(forDuration: 0.15)
            ]))
            backgroundLayer.run(shimmerSequence, withKey: "gpuHeat_\(sectorId)")

        case .memory:
            // RAM: Re-add data pulse
            let themeColor = UIColor(hex: sector.theme.primaryColorHex) ?? .green
            startRAMDataPulse(sector: sector, color: themeColor)

        case .storage:
            // Storage: Re-add data trail
            let themeColor = UIColor(hex: sector.theme.primaryColorHex) ?? .purple
            startStorageDataTrail(sector: sector, color: themeColor)

        case .network:
            // Network: Re-add signal rings
            startNetworkSectorAmbient(sector: sector)

        case .io:
            // I/O: Re-add data bursts
            let themeColor = UIColor(hex: sector.theme.primaryColorHex) ?? .orange
            startIODataBurst(sector: sector, color: themeColor)

        case .processing:
            // Cache: Re-add flash and speed lines
            startCacheSectorAmbient(sector: sector)

        case .power:
            // PSU has minimal effects, nothing to resume
            break
        }
    }

    // MARK: - Deprecated Tower Methods (Now handled by TowerVisualFactory)
    // The following methods have been replaced by TowerVisualFactory.swift:
    // - createWeaponBody() -> TowerVisualFactory.createTowerBody()
    // - createWeaponBarrel() -> TowerVisualFactory.createTowerBarrel()
    // - createMergeStars() -> TowerVisualFactory.createMergeIndicator()

    /// Create hexagon path (used by enemy nodes)
    private func createHexagonPath(radius: CGFloat) -> CGPath {
        let path = UIBezierPath()
        for i in 0..<6 {
            let angle = CGFloat(i) * .pi / 3 - .pi / 6
            let point = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.close()
        return path.cgPath
    }

    /// Create diamond path
    private func createDiamondPath(size: CGFloat) -> CGPath {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: size / 2))
        path.addLine(to: CGPoint(x: size / 2, y: 0))
        path.addLine(to: CGPoint(x: 0, y: -size / 2))
        path.addLine(to: CGPoint(x: -size / 2, y: 0))
        path.close()
        return path.cgPath
    }

    private func createEnemyNode(enemy: TDEnemy) -> SKNode {
        let container = SKNode()

        // Virus color based on enemy type/tier
        // Zero-Day: deep purple with white corona
        // Boss: white with warning glow
        // Tank: purple (tier 3)
        // Fast: orange (tier 2)
        // Basic: red (tier 1)
        let virusColor: UIColor
        if enemy.isZeroDay {
            virusColor = DesignColors.zeroDayVirusUI
        } else if enemy.isBoss {
            virusColor = DesignColors.enemyTier4UI
        } else {
            switch enemy.type {
            case "tank":
                virusColor = DesignColors.enemyTier3UI  // Purple
            case "fast":
                virusColor = DesignColors.enemyTier2UI  // Orange
            default:
                virusColor = DesignColors.enemyTier1UI  // Red
            }
        }

        // Virus body - hexagonal shape for tech aesthetic
        let body: SKShapeNode
        switch enemy.shape {
        case "triangle":
            // Triangle virus - fast/small
            let path = UIBezierPath()
            let size = enemy.size
            path.move(to: CGPoint(x: 0, y: size))
            path.addLine(to: CGPoint(x: -size * 0.866, y: -size/2))
            path.addLine(to: CGPoint(x: size * 0.866, y: -size/2))
            path.close()
            body = SKShapeNode(path: path.cgPath)
        case "hexagon":
            // Hexagon virus - standard
            body = SKShapeNode(path: createHexagonPath(radius: enemy.size))
        case "diamond":
            // Diamond virus - armored
            body = SKShapeNode(path: createDiamondPath(size: enemy.size * 2))
        default:
            // Default hexagon virus
            body = SKShapeNode(path: createHexagonPath(radius: enemy.size))
        }

        body.fillColor = virusColor.withAlphaComponent(0.85)
        body.strokeColor = enemy.isBoss ? DesignColors.warningUI : virusColor
        body.lineWidth = enemy.isBoss ? 3 : 2
        body.glowWidth = enemy.isBoss ? 6 : 3
        body.name = "body"
        container.addChild(body)

        // Inner detail - digital corruption pattern
        let innerSize = enemy.size * 0.5
        let innerPath = createHexagonPath(radius: innerSize)
        let innerNode = SKShapeNode(path: innerPath)
        innerNode.fillColor = UIColor.black.withAlphaComponent(0.3)
        innerNode.strokeColor = virusColor.withAlphaComponent(0.8)
        innerNode.lineWidth = 1
        container.addChild(innerNode)

        // Boss effects - different for Zero-Day vs regular boss
        if enemy.isZeroDay {
            // Zero-Day: Deep purple with white corona effect
            body.glowWidth = 15
            body.strokeColor = UIColor.white

            // Add white corona/ring effect
            let corona = SKShapeNode(circleOfRadius: enemy.size * 1.3)
            corona.strokeColor = UIColor.white.withAlphaComponent(0.6)
            corona.fillColor = .clear
            corona.lineWidth = 2
            corona.glowWidth = 10
            corona.zPosition = -1
            container.addChild(corona)

            // Corona pulse animation
            let coronaPulse = SKAction.sequence([
                SKAction.fadeAlpha(to: 0.3, duration: 0.6),
                SKAction.fadeAlpha(to: 0.8, duration: 0.6)
            ])
            corona.run(SKAction.repeatForever(coronaPulse))

            // Zero-Day indicator
            let zeroDayLabel = SKLabelNode(text: L10n.ZeroDay.indicator)
            zeroDayLabel.fontName = "Menlo-Bold"
            zeroDayLabel.fontSize = 10
            zeroDayLabel.fontColor = DesignColors.zeroDayVirusUI
            zeroDayLabel.position = CGPoint(x: 0, y: enemy.size + 20)
            zeroDayLabel.name = "bossIndicator"
            container.addChild(zeroDayLabel)

            // Menacing slow rotation
            let rotate = SKAction.rotate(byAngle: .pi * 2, duration: 6.0)
            body.run(SKAction.repeatForever(rotate))

        } else if enemy.immuneToTowers && enemy.isBoss {
            // Super Virus: TD boss immune to towers - orange/red with shield effect
            body.glowWidth = 15
            body.strokeColor = UIColor.orange

            // Super Virus indicator (top)
            let superVirusLabel = SKLabelNode(text: L10n.Enemy.superVirusIndicator)
            superVirusLabel.fontName = "Menlo-Bold"
            superVirusLabel.fontSize = 12
            superVirusLabel.fontColor = .orange
            superVirusLabel.position = CGPoint(x: 0, y: enemy.size + 28)
            superVirusLabel.name = "bossIndicator"
            container.addChild(superVirusLabel)

            // Immune indicator (below super virus label)
            let immuneLabel = SKLabelNode(text: L10n.Enemy.immuneToTowers)
            immuneLabel.fontName = "Menlo-Bold"
            immuneLabel.fontSize = 9
            immuneLabel.fontColor = UIColor.cyan
            immuneLabel.position = CGPoint(x: 0, y: enemy.size + 16)
            immuneLabel.name = "immuneIndicator"
            container.addChild(immuneLabel)

            // Shield ring effect (shows immunity)
            let shieldRing = SKShapeNode(circleOfRadius: enemy.size * 1.4)
            shieldRing.strokeColor = UIColor.orange.withAlphaComponent(0.7)
            shieldRing.fillColor = .clear
            shieldRing.lineWidth = 3
            shieldRing.glowWidth = 8
            shieldRing.zPosition = -1
            shieldRing.name = "shieldRing"
            container.addChild(shieldRing)

            // Shield pulse animation
            let shieldPulse = SKAction.sequence([
                SKAction.group([
                    SKAction.scale(to: 1.1, duration: 0.8),
                    SKAction.fadeAlpha(to: 0.4, duration: 0.8)
                ]),
                SKAction.group([
                    SKAction.scale(to: 1.0, duration: 0.8),
                    SKAction.fadeAlpha(to: 0.8, duration: 0.8)
                ])
            ])
            shieldRing.run(SKAction.repeatForever(shieldPulse))

            // Color cycle between red and orange
            let colorCycle = SKAction.sequence([
                SKAction.colorize(with: .red, colorBlendFactor: 0.6, duration: 0.6),
                SKAction.colorize(with: .orange, colorBlendFactor: 0.6, duration: 0.6)
            ])
            body.run(SKAction.repeatForever(colorCycle))

            // Slow menacing pulse
            let pulse = SKAction.sequence([
                SKAction.scale(to: 1.1, duration: 0.6),
                SKAction.scale(to: 0.95, duration: 0.6)
            ])
            body.run(SKAction.repeatForever(pulse), withKey: "bossPulse")

            // Rotation for inner detail
            let rotate = SKAction.rotate(byAngle: .pi * 2, duration: 5.0)
            innerNode.run(SKAction.repeatForever(rotate))

        } else if enemy.isBoss {
            // Regular boss: White with warning glow and color cycle
            body.glowWidth = 10

            // Boss indicator
            let bossLabel = SKLabelNode(text: L10n.Enemy.bossIndicator)
            bossLabel.fontName = "Menlo-Bold"
            bossLabel.fontSize = 10
            bossLabel.fontColor = DesignColors.warningUI
            bossLabel.position = CGPoint(x: 0, y: enemy.size + 16)
            bossLabel.name = "bossIndicator"
            container.addChild(bossLabel)

            // Color cycle effect for boss
            let colorCycle = SKAction.sequence([
                SKAction.colorize(with: .red, colorBlendFactor: 0.5, duration: 0.5),
                SKAction.colorize(with: .orange, colorBlendFactor: 0.5, duration: 0.5),
                SKAction.colorize(with: .yellow, colorBlendFactor: 0.5, duration: 0.5),
                SKAction.colorize(with: .white, colorBlendFactor: 0.0, duration: 0.5)
            ])
            body.run(SKAction.repeatForever(colorCycle))

            // Menacing pulse animation
            let pulse = SKAction.sequence([
                SKAction.scale(to: 1.15, duration: 0.4),
                SKAction.scale(to: 0.95, duration: 0.4)
            ])
            body.run(SKAction.repeatForever(pulse), withKey: "bossPulse")

            // Rotation for boss inner
            let rotate = SKAction.rotate(byAngle: .pi * 2, duration: 4.0)
            innerNode.run(SKAction.repeatForever(rotate))
        }

        // Slow effect overlay (ice blue, hidden by default)
        let slowOverlay = SKShapeNode(circleOfRadius: enemy.size * 0.9)
        slowOverlay.fillColor = DesignColors.primaryUI.withAlphaComponent(0.2)
        slowOverlay.strokeColor = DesignColors.primaryUI.withAlphaComponent(0.5)
        slowOverlay.lineWidth = 2
        slowOverlay.name = "slowOverlay"
        slowOverlay.isHidden = true
        container.addChild(slowOverlay)

        // Health bar background - dark
        let healthBarWidth = enemy.size * 1.5
        let healthBg = SKSpriteNode(color: DesignColors.backgroundUI.withAlphaComponent(0.8), size: CGSize(width: healthBarWidth + 2, height: 5))
        healthBg.position = CGPoint(x: 0, y: enemy.size + 8)
        container.addChild(healthBg)

        // Health bar - red for virus health
        let healthBar = SKSpriteNode(color: virusColor, size: CGSize(width: healthBarWidth, height: 3))
        healthBar.anchorPoint = CGPoint(x: 0, y: 0.5)
        healthBar.position = CGPoint(x: -healthBarWidth / 2, y: enemy.size + 8)
        healthBar.name = "healthBar"
        container.addChild(healthBar)

        return container
    }

    private func updateEnemyVisuals(state: TDGameState) {
        // Track enemies to remove
        var enemiesToRemove: [String] = []

        // Remove old enemy nodes with death animation
        for (id, node) in enemyNodes {
            if !state.enemies.contains(where: { $0.id == id && !$0.isDead }) {
                enemiesToRemove.append(id)
            }
        }

        for id in enemiesToRemove {
            if let node = enemyNodes[id] {
                // Death animation
                let shrink = SKAction.scale(to: 0.1, duration: 0.2)
                let fade = SKAction.fadeOut(withDuration: 0.2)
                let group = SKAction.group([shrink, fade])
                let remove = SKAction.removeFromParent()
                node.run(SKAction.sequence([group, remove]))
                enemyNodes.removeValue(forKey: id)
            }
        }

        // Update/create enemy nodes
        for enemy in state.enemies {
            if enemy.isDead || enemy.reachedCore { continue }

            if let node = enemyNodes[enemy.id] {
                // Update position
                node.position = convertToScene(enemy.position)

                // Update health bar
                if let healthBar = node.childNode(withName: "healthBar") as? SKSpriteNode {
                    let healthPercent = enemy.health / enemy.maxHealth
                    healthBar.xScale = healthPercent

                    // Color based on health
                    if healthPercent > 0.6 {
                        healthBar.color = .green
                    } else if healthPercent > 0.3 {
                        healthBar.color = .yellow
                    } else {
                        healthBar.color = .red
                    }
                }

                // Update slow effect with orbiting ice crystals
                if let slowOverlay = node.childNode(withName: "slowOverlay") as? SKShapeNode {
                    slowOverlay.isHidden = !enemy.isSlowed
                }

                // Manage orbiting frost crystals
                let frostCrystals = node.childNode(withName: "frostCrystals")
                if enemy.isSlowed {
                    if frostCrystals == nil {
                        // Create frost crystal container
                        let crystalContainer = createFrostCrystals(enemySize: enemy.size)
                        crystalContainer.name = "frostCrystals"
                        node.addChild(crystalContainer)
                    }

                    // Occasional frost particle effect
                    if Int.random(in: 0..<15) == 0 {
                        spawnSlowParticle(at: node.position)
                    }
                } else {
                    // Remove frost crystals when no longer slowed
                    frostCrystals?.removeFromParent()
                }

                // Tint body when slowed
                if let body = node.childNode(withName: "body") as? SKShapeNode {
                    if enemy.isSlowed {
                        body.fillColor = (UIColor(hex: enemy.color) ?? .red).blended(with: .cyan, ratio: 0.3)
                    } else {
                        body.fillColor = UIColor(hex: enemy.color) ?? .red
                    }
                }

                // Low health glitch effect (under 30% HP)
                let healthPercent = enemy.health / enemy.maxHealth
                let damageOverlay = node.childNode(withName: "damageOverlay")
                if healthPercent <= 0.3 {
                    if damageOverlay == nil {
                        // Add damage overlay with glitch jitter
                        let overlay = createDamageOverlay(enemySize: enemy.size)
                        overlay.name = "damageOverlay"
                        node.addChild(overlay)
                    }
                } else {
                    // Remove damage overlay when above threshold
                    damageOverlay?.removeFromParent()
                }

            } else {
                // Create new enemy node
                let node = createEnemyNode(enemy: enemy)
                node.position = convertToScene(enemy.position)
                enemyLayer.addChild(node)
                enemyNodes[enemy.id] = node
                print("[TDGameScene] Created enemy node - pos: \(node.position), size: \(enemy.size), type: \(enemy.type), enemyLayer.alpha: \(enemyLayer.alpha), enemyLayer.zPosition: \(enemyLayer.zPosition)")
            }
        }
    }

    /// Spawn frost particle for slowed enemies
    private func spawnSlowParticle(at position: CGPoint) {
        let particle = SKShapeNode(circleOfRadius: CGFloat.random(in: 2...4))
        particle.fillColor = .cyan.withAlphaComponent(0.6)
        particle.strokeColor = .clear
        particle.position = CGPoint(
            x: position.x + CGFloat.random(in: -10...10),
            y: position.y + CGFloat.random(in: -10...10)
        )
        particle.zPosition = 47

        let moveUp = SKAction.moveBy(x: CGFloat.random(in: -5...5), y: 20, duration: 0.5)
        let fade = SKAction.fadeOut(withDuration: 0.5)
        let group = SKAction.group([moveUp, fade])
        let remove = SKAction.removeFromParent()
        particle.run(SKAction.sequence([group, remove]))

        particleLayer.addChild(particle)
    }

    /// Create orbiting frost crystals for slowed enemies
    private func createFrostCrystals(enemySize: CGFloat) -> SKNode {
        let container = SKNode()
        container.zPosition = 50

        let crystalCount = 4
        let orbitRadius = enemySize * 0.9
        let crystalSize: CGFloat = 4

        for i in 0..<crystalCount {
            // Create diamond-shaped ice crystal
            let crystal = SKShapeNode()
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: crystalSize))
            path.addLine(to: CGPoint(x: crystalSize * 0.6, y: 0))
            path.addLine(to: CGPoint(x: 0, y: -crystalSize))
            path.addLine(to: CGPoint(x: -crystalSize * 0.6, y: 0))
            path.closeSubpath()
            crystal.path = path

            crystal.fillColor = UIColor.cyan.withAlphaComponent(0.7)
            crystal.strokeColor = UIColor.white.withAlphaComponent(0.9)
            crystal.lineWidth = 1
            crystal.glowWidth = 3
            crystal.blendMode = .add

            // Position in orbit
            let startAngle = CGFloat(i) * (2 * .pi / CGFloat(crystalCount))
            crystal.position = CGPoint(
                x: cos(startAngle) * orbitRadius,
                y: sin(startAngle) * orbitRadius
            )
            crystal.zRotation = startAngle

            container.addChild(crystal)
        }

        // Slow orbital rotation (3 seconds per revolution)
        let rotate = SKAction.repeatForever(SKAction.rotate(byAngle: 2 * .pi, duration: 3.0))
        container.run(rotate, withKey: "frostOrbit")

        // Subtle pulsing glow
        let pulseGlow = SKAction.repeatForever(SKAction.sequence([
            SKAction.customAction(withDuration: 0.5) { node, elapsed in
                for child in node.children {
                    if let shape = child as? SKShapeNode {
                        shape.glowWidth = 3 + 2 * sin(elapsed / 0.5 * .pi)
                    }
                }
            },
            SKAction.customAction(withDuration: 0.5) { node, elapsed in
                for child in node.children {
                    if let shape = child as? SKShapeNode {
                        shape.glowWidth = 5 - 2 * sin(elapsed / 0.5 * .pi)
                    }
                }
            }
        ]))
        container.run(pulseGlow, withKey: "frostPulse")

        return container
    }

    /// Create damage overlay for low health enemies (glitch effect)
    private func createDamageOverlay(enemySize: CGFloat) -> SKNode {
        let container = SKNode()
        container.zPosition = 49

        // Semi-transparent red overlay
        let overlay = SKShapeNode(circleOfRadius: enemySize * 0.6)
        overlay.fillColor = UIColor.red.withAlphaComponent(0.2)
        overlay.strokeColor = UIColor.red.withAlphaComponent(0.5)
        overlay.lineWidth = 1
        overlay.glowWidth = 4
        overlay.blendMode = .add
        container.addChild(overlay)

        // Glitch jitter animation (±2px every 0.3s)
        let glitch = SKAction.repeatForever(SKAction.sequence([
            SKAction.run {
                container.position = CGPoint(
                    x: CGFloat.random(in: -2...2),
                    y: CGFloat.random(in: -2...2)
                )
                overlay.alpha = CGFloat.random(in: 0.3...0.7)
            },
            SKAction.wait(forDuration: TimeInterval.random(in: 0.15...0.35)),
            SKAction.run {
                container.position = .zero
            },
            SKAction.wait(forDuration: TimeInterval.random(in: 0.2...0.4))
        ]))
        container.run(glitch, withKey: "damageGlitch")

        // Flickering pulse
        let pulse = SKAction.repeatForever(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.8, duration: 0.15),
            SKAction.fadeAlpha(to: 0.4, duration: 0.15)
        ]))
        overlay.run(pulse, withKey: "damagePulse")

        return container
    }

    private func updateProjectileVisuals(state: TDGameState) {
        // Remove old projectile nodes and trails
        for (id, node) in projectileNodes {
            if !state.projectiles.contains(where: { $0.id == id }) {
                node.removeFromParent()
                projectileNodes.removeValue(forKey: id)
                projectileTrails.removeValue(forKey: id)
            }
        }

        // Update/create projectile nodes and trails
        for proj in state.projectiles {
            let scenePos = convertToScene(CGPoint(x: proj.x, y: proj.y))

            if let node = projectileNodes[proj.id] {
                node.position = scenePos

                // Update trail (optimized - single path node)
                updateProjectileTrail(projId: proj.id, position: scenePos, color: UIColor(hex: proj.color) ?? .yellow)
            } else {
                // Create new projectile node
                let container = SKNode()
                container.position = scenePos

                let projectile = SKShapeNode(circleOfRadius: proj.radius)
                projectile.fillColor = UIColor(hex: proj.color) ?? .yellow
                projectile.strokeColor = .white
                projectile.lineWidth = 1
                projectile.name = "projectile"
                // REMOVED: glowWidth = 3 (expensive blur shader)
                container.addChild(projectile)

                // Trail: single SKShapeNode (will update path, not recreate nodes)
                let trailNode = SKShapeNode()
                trailNode.name = "trail"
                trailNode.zPosition = -1
                trailNode.lineCap = .round
                trailNode.lineJoin = .round
                // REMOVED: glowWidth, blendMode = .add
                container.addChild(trailNode)

                projectileLayer.addChild(container)
                projectileNodes[proj.id] = container

                // Initialize trail
                projectileTrails[proj.id] = [scenePos]
            }
        }
    }

    /// Update projectile trail - OPTIMIZED: single path instead of multiple nodes
    private func updateProjectileTrail(projId: String, position: CGPoint, color: UIColor) {
        // Get or create trail array
        var trail = projectileTrails[projId] ?? []

        // Add current position
        trail.append(position)

        // Limit trail length
        if trail.count > maxTrailLength {
            trail = Array(trail.suffix(maxTrailLength))
        }

        projectileTrails[projId] = trail

        // Update trail visual - OPTIMIZED: update single path instead of recreating nodes
        guard let node = projectileNodes[projId],
              let trailNode = node.childNode(withName: "trail") as? SKShapeNode,
              trail.count >= 2 else { return }

        // Build single path for entire trail (relative to projectile position)
        let path = CGMutablePath()
        let nodePos = node.position

        path.move(to: CGPoint(x: trail[0].x - nodePos.x, y: trail[0].y - nodePos.y))
        for i in 1..<trail.count {
            path.addLine(to: CGPoint(x: trail[i].x - nodePos.x, y: trail[i].y - nodePos.y))
        }

        // Update the single trail node's path (no node creation!)
        trailNode.path = path
        trailNode.strokeColor = color.withAlphaComponent(0.4)
        trailNode.lineWidth = 2
    }

    private func updateCoreVisual(state: TDGameState, currentTime: TimeInterval) {
        guard let coreContainer = backgroundLayer.childNode(withName: "core") else { return }

        // Get efficiency for color updates
        let efficiency = state.efficiency

        // Determine color based on efficiency
        let efficiencyColor: UIColor
        let glowIntensity: CGFloat
        if efficiency >= 70 {
            efficiencyColor = DesignColors.successUI  // Green
            glowIntensity = 15
        } else if efficiency >= 40 {
            efficiencyColor = DesignColors.warningUI  // Yellow/Amber
            glowIntensity = 10
        } else if efficiency >= 20 {
            efficiencyColor = UIColor.orange
            glowIntensity = 8
        } else {
            efficiencyColor = DesignColors.dangerUI   // Red - critical
            glowIntensity = 20  // More intense glow when critical
        }

        // Update CPU body stroke color
        if let cpuBody = coreContainer.childNode(withName: "cpuBody") as? SKShapeNode {
            cpuBody.strokeColor = efficiencyColor
            cpuBody.glowWidth = glowIntensity
        }

        // Update inner chip
        if let innerChip = coreContainer.childNode(withName: "innerChip") as? SKShapeNode {
            innerChip.strokeColor = efficiencyColor.withAlphaComponent(0.6)
        }

        // Update efficiency label
        if let efficiencyLabel = coreContainer.childNode(withName: "efficiencyLabel") as? SKLabelNode {
            efficiencyLabel.text = "\(Int(efficiency))%"
            efficiencyLabel.fontColor = efficiencyColor
        }

        // Update glow ring
        if let glowRing = coreContainer.childNode(withName: "glowRing") as? SKShapeNode {
            glowRing.strokeColor = efficiencyColor.withAlphaComponent(0.3)
            glowRing.glowWidth = glowIntensity
        }

        // Pulse effect - more intense when efficiency is low
        let baseScale = CoreSystem.getCorePulseScale(state: state, currentTime: currentTime)
        let pulseIntensity: CGFloat = efficiency < 30 ? 1.15 : 1.0  // More intense pulse when critical
        coreContainer.setScale(baseScale * pulseIntensity)
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        // Check for locked spawn point tap (8-lane mega-board)
        // Locked spawn points show unlock UI when tapped
        if isMotherboardMap {
            let allLanes = MotherboardLaneConfig.createAllLanes()
            let unlockedSectorIds = gameStateDelegate?.getUnlockedSectorIds() ?? Set([SectorID.power.rawValue])

            // Check locked lanes for spawn point tap
            for lane in allLanes {
                let isUnlocked = lane.isStarterLane || unlockedSectorIds.contains(lane.sectorId)

                // Only respond to taps on locked spawn points
                if !isUnlocked {
                    let spawnPos = convertToScene(lane.spawnPoint)
                    let hitRadius: CGFloat = 80  // Generous tap target

                    let dx = location.x - spawnPos.x
                    let dy = location.y - spawnPos.y
                    let distance = sqrt(dx*dx + dy*dy)

                    if distance < hitRadius {
                        print("[TDGameScene] Locked spawn point tapped: \(lane.displayName)")
                        HapticsService.shared.play(.light)
                        gameStateDelegate?.spawnPointTapped(lane)
                        return
                    }
                }
            }

            // Check for encryption gate tap (mega-board sector unlock)
            for (sectorId, gateNode) in gateNodes {
                if gateNode.contains(location) {
                    print("[TDGameScene] Encryption gate tapped: \(sectorId)")
                    HapticsService.shared.play(.light)
                    gameStateDelegate?.gateSelected(sectorId)
                    return
                }
            }
        }

        // Check for boss tap (to engage boss fight)
        if let state = state, state.bossActive, !state.bossEngaged,
           let bossId = state.activeBossId,
           let boss = state.enemies.first(where: { $0.id == bossId }) {
            let bossScenePos = convertToScene(boss.position)
            let bossTapRadius: CGFloat = max(boss.size * 1.5, 60)  // Generous tap target for boss
            let dx = location.x - bossScenePos.x
            let dy = location.y - bossScenePos.y
            let distance = sqrt(dx * dx + dy * dy)
            if distance < bossTapRadius {
                HapticsService.shared.play(.medium)
                gameStateDelegate?.bossTapped()
                return
            }
        }

        // Check for tower touch (start long-press timer for drag)
        // Use distance-based detection to avoid catching range indicator taps
        let towerTapRadius: CGFloat = 50  // Only tap the tower body, not the range
        for (towerId, node) in towerNodes {
            let dx = location.x - node.position.x
            let dy = location.y - node.position.y
            let distance = sqrt(dx * dx + dy * dy)
            if distance < towerTapRadius {
                dragStartPosition = location
                // Start long-press timer for drag-to-merge
                longPressTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
                    self?.startDraggingTower(towerId: towerId, from: location)
                }
                return
            }
        }

        // Check for slot selection
        for (slotId, node) in slotNodes {
            if node.contains(location) {
                selectedSlotId = slotId
                gameStateDelegate?.slotSelected(slotId)
                return
            }
        }

        // Deselect
        selectedSlotId = nil
        selectedTowerId = nil
        gameStateDelegate?.towerSelected(nil)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        // Cancel long-press if moved too far before timer
        if let startPos = dragStartPosition, !isDragging {
            let dx = location.x - startPos.x
            let dy = location.y - startPos.y
            if sqrt(dx*dx + dy*dy) > 10 {
                cancelLongPress()
            }
        }

        // Update drag position
        if isDragging, let dragNode = dragNode {
            dragNode.position = location
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        // Cancel any pending long-press
        cancelLongPress()

        if isDragging, let draggedId = draggedTowerId {
            // Check if dropped in removal zone (bottom of visible screen = deck area)
            let touchInView = touch.location(in: self.view)
            let viewHeight = self.view?.bounds.height ?? 800
            let removalZoneThreshold = viewHeight * 0.85  // Bottom 15% of screen

            if touchInView.y > removalZoneThreshold {
                // Tower dropped in removal zone - remove it
                performTowerRemoval(towerId: draggedId)
            }
            // Check for move to empty slot
            else if let targetSlotId = findEmptySlotAtLocation(location) {
                performTowerMove(towerId: draggedId, toSlotId: targetSlotId)
            }

            // End drag
            endDrag()
        } else {
            // Normal tap - select tower (use distance-based, not node bounds)
            let towerTapRadius: CGFloat = 50
            for (towerId, node) in towerNodes {
                let dx = location.x - node.position.x
                let dy = location.y - node.position.y
                let distance = sqrt(dx * dx + dy * dy)
                if distance < towerTapRadius {
                    selectedTowerId = selectedTowerId == towerId ? nil : towerId
                    gameStateDelegate?.towerSelected(selectedTowerId)
                    updateRangeIndicatorVisibility()
                    return
                }
            }
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        cancelLongPress()
        endDrag()
    }

    // MARK: - Drag Operations

    private func startDraggingTower(towerId: String, from position: CGPoint) {
        guard let tower = state?.towers.first(where: { $0.id == towerId }) else { return }

        isDragging = true
        draggedTowerId = towerId
        longPressTimer = nil

        // Find empty slots for repositioning
        if let state = state {
            validMoveSlots = Set(state.towerSlots.filter { !$0.occupied }.map { $0.id })
        }

        // Create drag visual
        let dragVisual = SKNode()

        // Ghost tower
        let ghost = SKShapeNode(circleOfRadius: 20)
        ghost.fillColor = (UIColor(hex: tower.color) ?? .blue).withAlphaComponent(0.7)
        ghost.strokeColor = .white
        ghost.lineWidth = 2
        ghost.glowWidth = 5
        dragVisual.addChild(ghost)

        // Move indicator
        let icon = SKLabelNode(text: "↔")
        icon.fontSize = 16
        icon.verticalAlignmentMode = .center
        dragVisual.addChild(icon)

        dragVisual.position = position
        dragVisual.zPosition = 100
        dragNode = dragVisual
        addChild(dragVisual)

        // Show empty slots as valid move targets
        showEmptySlotHighlights()

        // Dim the source tower
        if let sourceNode = towerNodes[towerId] {
            sourceNode.alpha = 0.3
        }

        // Haptic feedback
        HapticsService.shared.play(.selection)
    }

    /// Show highlights on all empty slots during tower drag
    private func showEmptySlotHighlights() {
        guard let state = state else { return }

        for slot in state.towerSlots where !slot.occupied {
            if let dotNode = gridDotsLayer.childNode(withName: "gridDot_\(slot.id)") {
                // Create move highlight
                let highlight = SKShapeNode(circleOfRadius: 35)
                highlight.fillColor = DesignColors.primaryUI.withAlphaComponent(0.15)
                highlight.strokeColor = DesignColors.primaryUI.withAlphaComponent(0.6)
                highlight.lineWidth = 2
                highlight.name = "moveHighlight"
                highlight.zPosition = 10
                dotNode.addChild(highlight)

                // Pulse animation
                let pulse = SKAction.sequence([
                    SKAction.scale(to: 1.1, duration: 0.5),
                    SKAction.scale(to: 1.0, duration: 0.5)
                ])
                highlight.run(SKAction.repeatForever(pulse))
            }
        }
    }

    /// Hide empty slot highlights
    private func hideEmptySlotHighlights() {
        gridDotsLayer.enumerateChildNodes(withName: "*/moveHighlight") { node, _ in
            node.removeFromParent()
        }
    }

    /// Find empty slot at drop location for tower repositioning
    private func findEmptySlotAtLocation(_ location: CGPoint) -> String? {
        guard let state = state else { return nil }

        for slot in state.towerSlots where validMoveSlots.contains(slot.id) {
            let slotScenePos = convertToScene(slot.position)
            let distance = hypot(slotScenePos.x - location.x, slotScenePos.y - location.y)
            if distance < 45 {  // Slightly larger hit area for easier placement
                return slot.id
            }
        }
        return nil
    }

    /// Move tower to a new empty slot
    private func performTowerMove(towerId: String, toSlotId: String) {
        guard var state = self.state,
              let towerIndex = state.towers.firstIndex(where: { $0.id == towerId }),
              let newSlotIndex = state.towerSlots.firstIndex(where: { $0.id == toSlotId }),
              !state.towerSlots[newSlotIndex].occupied
        else { return }

        let tower = state.towers[towerIndex]
        let oldSlotId = tower.slotId

        // Free old slot
        if let oldSlotIndex = state.towerSlots.firstIndex(where: { $0.id == oldSlotId }) {
            state.towerSlots[oldSlotIndex].occupied = false
            state.towerSlots[oldSlotIndex].towerId = nil
        }

        // Move tower to new slot
        let newSlot = state.towerSlots[newSlotIndex]
        state.towers[towerIndex].x = newSlot.x
        state.towers[towerIndex].y = newSlot.y
        state.towers[towerIndex].slotId = toSlotId

        // Occupy new slot
        state.towerSlots[newSlotIndex].occupied = true
        state.towerSlots[newSlotIndex].towerId = towerId

        self.state = state

        // Animate tower movement
        if let towerNode = towerNodes[towerId] {
            let newScenePos = convertToScene(CGPoint(x: newSlot.x, y: newSlot.y))
            let moveAction = SKAction.move(to: newScenePos, duration: 0.3)
            moveAction.timingMode = .easeOut
            towerNode.run(moveAction)
        }

        // Update slot visuals
        if let oldSlotIndex = state.towerSlots.firstIndex(where: { $0.id == oldSlotId }) {
            updateSlotVisual(slot: state.towerSlots[oldSlotIndex])
        }
        updateSlotVisual(slot: state.towerSlots[newSlotIndex])

        HapticsService.shared.play(.selection)

        // Persist and notify
        StorageService.shared.saveTDSession(TDSessionState.from(gameState: state))
        gameStateDelegate?.gameStateUpdated(state)
    }

    private func performTowerRemoval(towerId: String) {
        guard var state = state,
              let towerIndex = state.towers.firstIndex(where: { $0.id == towerId })
        else { return }

        let tower = state.towers[towerIndex]

        // Free the slot
        if let slotIndex = state.towerSlots.firstIndex(where: { $0.id == tower.slotId }) {
            state.towerSlots[slotIndex].occupied = false
            state.towerSlots[slotIndex].towerId = nil
        }

        // Remove tower from state
        state.towers.remove(at: towerIndex)

        // Animate removal
        if let towerNode = towerNodes[towerId] {
            let fadeOut = SKAction.fadeOut(withDuration: 0.2)
            let scaleDown = SKAction.scale(to: 0.5, duration: 0.2)
            let group = SKAction.group([fadeOut, scaleDown])
            let remove = SKAction.removeFromParent()
            towerNode.run(SKAction.sequence([group, remove]))
        }

        // Remove from tracking
        towerNodes.removeValue(forKey: towerId)

        // Update state
        self.state = state
        gameStateDelegate?.gameStateUpdated(state)

        // Persist
        StorageService.shared.saveTDSession(TDSessionState.from(gameState: state))

        // Feedback
        HapticsService.shared.play(.light)
    }

    private func endDrag() {
        isDragging = false

        // Remove drag visual
        dragNode?.removeFromParent()
        dragNode = nil

        // Restore source tower opacity
        if let sourceId = draggedTowerId, let sourceNode = towerNodes[sourceId] {
            sourceNode.alpha = 1.0
        }

        // Hide empty slot move highlights
        hideEmptySlotHighlights()

        draggedTowerId = nil
        validMoveSlots.removeAll()
        dragStartPosition = nil
    }

    private func cancelLongPress() {
        longPressTimer?.invalidate()
        longPressTimer = nil
    }

    // MARK: - Range Indicator

    private func updateRangeIndicatorVisibility() {
        for (towerId, node) in towerNodes {
            if let rangeNode = node.childNode(withName: "range") as? SKShapeNode {
                let isSelected = towerId == selectedTowerId
                rangeNode.isHidden = !isSelected

                if isSelected {
                    // Add subtle pulse animation
                    let pulse = SKAction.sequence([
                        SKAction.scale(to: 1.02, duration: 0.5),
                        SKAction.scale(to: 0.98, duration: 0.5)
                    ])
                    rangeNode.run(SKAction.repeatForever(pulse), withKey: "rangePulse")
                } else {
                    rangeNode.removeAction(forKey: "rangePulse")
                    rangeNode.setScale(1.0)
                }
            }
        }
    }

    // MARK: - Particle Effects

    /// Spawn portal animation when enemy enters the map
    func spawnPortalAnimation(at position: CGPoint, completion: (() -> Void)? = nil) {
        let portalDuration: TimeInterval = 0.8

        // Portal container
        let portal = SKNode()
        portal.position = position
        portal.zPosition = 40
        particleLayer.addChild(portal)

        // Outer expanding ring
        let outerRing = SKShapeNode(circleOfRadius: 5)
        outerRing.fillColor = .clear
        outerRing.strokeColor = DesignColors.dangerUI.withAlphaComponent(0.8)
        outerRing.lineWidth = 3
        outerRing.glowWidth = 8
        portal.addChild(outerRing)

        // Inner glow circle
        let innerGlow = SKShapeNode(circleOfRadius: 3)
        innerGlow.fillColor = DesignColors.dangerUI.withAlphaComponent(0.6)
        innerGlow.strokeColor = .clear
        innerGlow.glowWidth = 15
        portal.addChild(innerGlow)

        // Swirl particles
        let swirlCount = 6
        for i in 0..<swirlCount {
            let angle = CGFloat(i) * (.pi * 2 / CGFloat(swirlCount))
            let swirl = SKShapeNode(circleOfRadius: 2)
            swirl.fillColor = DesignColors.warningUI
            swirl.strokeColor = .clear
            swirl.glowWidth = 3
            swirl.position = CGPoint(x: cos(angle) * 8, y: sin(angle) * 8)
            portal.addChild(swirl)

            // Spiral inward animation
            let spiralIn = SKAction.customAction(withDuration: portalDuration * 0.7) { node, elapsed in
                let progress = elapsed / CGFloat(portalDuration * 0.7)
                let currentRadius = 8 * (1 - progress) + 2
                let rotationOffset = progress * .pi * 3
                let currentAngle = angle + rotationOffset
                node.position = CGPoint(x: cos(currentAngle) * currentRadius, y: sin(currentAngle) * currentRadius)
                node.alpha = 1 - progress * 0.5
            }
            swirl.run(spiralIn)
        }

        // Animate outer ring expanding
        let expandRing = SKAction.scale(to: 3.5, duration: portalDuration * 0.6)
        expandRing.timingMode = .easeOut
        let fadeRing = SKAction.fadeAlpha(to: 0, duration: portalDuration * 0.4)
        outerRing.run(SKAction.sequence([expandRing, fadeRing]))

        // Animate inner glow pulsing then contracting
        let pulseIn = SKAction.scale(to: 2.0, duration: portalDuration * 0.3)
        let pulseOut = SKAction.scale(to: 0.5, duration: portalDuration * 0.3)
        let contract = SKAction.scale(to: 0.1, duration: portalDuration * 0.2)
        let fadeOut = SKAction.fadeOut(withDuration: portalDuration * 0.2)
        pulseIn.timingMode = .easeOut
        pulseOut.timingMode = .easeIn
        innerGlow.run(SKAction.sequence([pulseIn, pulseOut, SKAction.group([contract, fadeOut])]))

        // Remove portal and call completion
        let wait = SKAction.wait(forDuration: portalDuration)
        let remove = SKAction.removeFromParent()
        let completeAction = SKAction.run {
            completion?()
        }
        portal.run(SKAction.sequence([wait, completeAction, remove]))
    }

    /// Spawn enemy death particles
    func spawnDeathParticles(at position: CGPoint, color: UIColor, isBoss: Bool = false) {
        let particleCount = isBoss ? 40 : Int.random(in: 15...25)

        for _ in 0..<particleCount {
            let particle = SKShapeNode(circleOfRadius: CGFloat.random(in: 2...6))
            particle.fillColor = color
            particle.strokeColor = color.withAlphaComponent(0.5)
            particle.position = position
            particle.zPosition = 45

            let angle = CGFloat.random(in: 0...(2 * .pi))
            let speed = CGFloat.random(in: 50...150)
            let duration = Double.random(in: 0.3...0.8)

            let moveAction = SKAction.move(by: CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed), duration: duration)
            moveAction.timingMode = .easeOut
            let fadeAction = SKAction.fadeOut(withDuration: duration)
            let rotateAction = SKAction.rotate(byAngle: CGFloat.random(in: -5...5), duration: duration)
            let group = SKAction.group([moveAction, fadeAction, rotateAction])
            let sequence = SKAction.sequence([group, SKAction.removeFromParent()])

            particle.run(sequence)
            particleLayer.addChild(particle)
        }
    }

    /// Spawn gold floaties when enemy is killed
    func spawnGoldFloaties(at position: CGPoint, goldValue: Int) {
        let floatCount = min(5, max(1, goldValue / 5))

        for i in 0..<floatCount {
            let goldStar = SKLabelNode(text: "⭐")
            goldStar.fontSize = 14
            goldStar.position = CGPoint(
                x: position.x + CGFloat.random(in: -10...10),
                y: position.y + CGFloat.random(in: -5...5)
            )
            goldStar.zPosition = 60

            let delay = SKAction.wait(forDuration: Double(i) * 0.1)
            let moveUp = SKAction.moveBy(x: CGFloat.random(in: -20...20), y: 50, duration: 0.8)
            moveUp.timingMode = .easeOut
            let fade = SKAction.fadeOut(withDuration: 0.8)
            let scale = SKAction.scale(to: 0.5, duration: 0.8)
            let group = SKAction.group([moveUp, fade, scale])
            let sequence = SKAction.sequence([delay, group, SKAction.removeFromParent()])

            goldStar.run(sequence)
            particleLayer.addChild(goldStar)
        }

        // Show gold amount text
        let goldLabel = SKLabelNode(text: "+\(goldValue)")
        goldLabel.fontName = "Helvetica-Bold"
        goldLabel.fontSize = 16
        goldLabel.fontColor = .yellow
        goldLabel.position = position
        goldLabel.zPosition = 61

        let moveUp = SKAction.moveBy(x: 0, y: 40, duration: 0.6)
        let fade = SKAction.fadeOut(withDuration: 0.6)
        let group = SKAction.group([moveUp, fade])
        let sequence = SKAction.sequence([group, SKAction.removeFromParent()])

        goldLabel.run(sequence)
        particleLayer.addChild(goldLabel)
    }

    /// Spawn impact sparks when projectile hits
    func spawnImpactSparks(at position: CGPoint, color: UIColor) {
        for _ in 0..<5 {
            let spark = SKShapeNode(circleOfRadius: CGFloat.random(in: 1...3))
            spark.fillColor = color
            spark.glowWidth = 2
            spark.position = position
            spark.zPosition = 46

            let angle = CGFloat.random(in: 0...(2 * .pi))
            let speed = CGFloat.random(in: 30...80)

            let moveAction = SKAction.move(by: CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed), duration: 0.2)
            let fadeAction = SKAction.fadeOut(withDuration: 0.2)
            let group = SKAction.group([moveAction, fadeAction])
            let sequence = SKAction.sequence([group, SKAction.removeFromParent()])

            spark.run(sequence)
            particleLayer.addChild(spark)
        }
    }

    /// Spawn core hit warning effect
    func spawnCoreHitEffect(at position: CGPoint) {
        for _ in 0..<20 {
            let particle = SKShapeNode(circleOfRadius: CGFloat.random(in: 3...6))
            particle.fillColor = .red
            particle.strokeColor = .orange
            particle.position = position
            particle.zPosition = 55

            let angle = CGFloat.random(in: 0...(2 * .pi))
            let speed = CGFloat.random(in: 60...120)

            let moveAction = SKAction.move(by: CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed), duration: 0.4)
            let fadeAction = SKAction.fadeOut(withDuration: 0.4)
            let group = SKAction.group([moveAction, fadeAction])
            let sequence = SKAction.sequence([group, SKAction.removeFromParent()])

            particle.run(sequence)
            particleLayer.addChild(particle)
        }

        // Screen flash
        let flash = SKSpriteNode(color: .red.withAlphaComponent(0.3), size: size)
        flash.position = CGPoint(x: size.width / 2, y: size.height / 2)
        flash.zPosition = 100
        addChild(flash)

        let fadeOut = SKAction.fadeOut(withDuration: 0.2)
        let remove = SKAction.removeFromParent()
        flash.run(SKAction.sequence([fadeOut, remove]))

        // Haptic feedback
        HapticsService.shared.play(.coreHit)
    }

    // MARK: - Actions

    func startWave() {
        guard var state = state, !state.waveInProgress, currentWaveIndex < waves.count else { return }

        WaveSystem.startWave(state: &state, wave: waves[currentWaveIndex])
        spawnTimer = 0

        self.state = state
    }

    // MARK: - Motherboard City (placeholder for new system)
    // Will implement: setupMotherboard(), updateComponentVisibility(), playInstallAnimation()

    /// Restore efficiency by setting the leak counter
    /// - Parameter leakCount: The new leak count (0 = 100%, 10 = 50%, 20 = 0%)
    func restoreEfficiency(to leakCount: Int) {
        state?.leakCounter = leakCount
        if let state = state {
            gameStateDelegate?.gameStateUpdated(state)
        }
    }

    /// Recover from System Freeze (0% efficiency state)
    /// Called when player chooses "Flush Memory" or completes "Manual Override"
    /// - Parameter restoreToEfficiency: Target efficiency (50 = 50%, i.e., leakCounter = 10)
    func recoverFromFreeze(restoreToEfficiency: CGFloat = 50) {
        guard var state = state, state.isSystemFrozen else { return }

        // Clear freeze state
        state.isSystemFrozen = false

        // Restore efficiency (50% = leakCounter of 10)
        // efficiency = 100 - leakCounter * 5
        // leakCounter = (100 - targetEfficiency) / 5
        let targetLeakCount = Int((100 - restoreToEfficiency) / 5)
        state.leakCounter = max(0, targetLeakCount)

        // Clear all enemies that were on the field (system "rebooted")
        for i in 0..<state.enemies.count {
            state.enemies[i].isDead = true
        }

        self.state = state
        gameStateDelegate?.gameStateUpdated(state)

        // Play recovery feedback
        HapticsService.shared.play(.success)

        // Visual recovery effect
        playRecoveryEffect()
    }

    /// Play visual effect for system recovery
    private func playRecoveryEffect() {
        guard let coreContainer = backgroundLayer.childNode(withName: "core") else { return }

        // Flash the core green
        let flashGreen = SKAction.run {
            if let cpuBody = coreContainer.childNode(withName: "cpuBody") as? SKShapeNode {
                cpuBody.strokeColor = DesignColors.successUI
                cpuBody.glowWidth = 15  // Reduced from 30 for performance
            }
        }
        let wait = SKAction.wait(forDuration: 0.3)
        let reset = SKAction.run { [weak self] in
            guard let self = self, let state = self.state else { return }
            self.updateCoreVisual(state: state, currentTime: CACurrentMediaTime())
        }
        let sequence = SKAction.sequence([flashGreen, wait, reset])
        coreContainer.run(sequence)

        // Expanding ring effect
        let ringNode = SKShapeNode(circleOfRadius: 10)
        ringNode.position = coreContainer.position
        ringNode.strokeColor = DesignColors.successUI
        ringNode.fillColor = .clear
        ringNode.lineWidth = 4
        ringNode.glowWidth = 8
        ringNode.zPosition = 100
        backgroundLayer.addChild(ringNode)

        let expand = SKAction.scale(to: 20, duration: 0.8)
        let fade = SKAction.fadeOut(withDuration: 0.8)
        let group = SKAction.group([expand, fade])
        let remove = SKAction.removeFromParent()
        ringNode.run(SKAction.sequence([group, remove]))
    }

    // MARK: - Overclock System

    /// Activate overclock mode (2x hash, 10x threat growth for 60 seconds)
    func activateOverclock() {
        guard var state = state else { return }

        if OverclockSystem.activateOverclock(state: &state) {
            self.state = state
            gameStateDelegate?.gameStateUpdated(state)
            HapticsService.shared.play(.heavy)

            // Visual feedback - pulse the CPU core orange
            playOverclockActivationEffect()
        }
    }

    /// Visual effect for overclock activation
    private func playOverclockActivationEffect() {
        guard let coreContainer = backgroundLayer.childNode(withName: "core") else { return }

        // Flash the core orange
        let flashOrange = SKAction.run {
            if let cpuBody = coreContainer.childNode(withName: "cpuBody") as? SKShapeNode {
                cpuBody.strokeColor = .orange
                cpuBody.glowWidth = 20
            }
        }
        let wait = SKAction.wait(forDuration: 0.5)
        let sequence = SKAction.sequence([flashOrange, wait])
        let pulse = SKAction.repeat(sequence, count: 3)
        coreContainer.run(pulse)
    }

    // MARK: - Boss Fight Results

    /// Called when boss fight is won - handle rewards and state cleanup
    func onBossFightWon(districtId: String) {
        guard var state = state else { return }

        // Process the boss fight win through TDBossSystem
        let reward = TDBossSystem.onBossFightWon(state: &state, districtId: districtId)

        // Apply hash reward
        state.hash += reward.hashReward

        // Sync to profile
        if let delegate = gameStateDelegate {
            AppState.shared.updatePlayer { profile in
                profile.hash = state.hash
                // Record boss defeat for progression
                if !profile.defeatedDistrictBosses.contains(districtId) {
                    profile.defeatedDistrictBosses.append(districtId)
                }
            }
        }

        self.state = state
        gameStateDelegate?.gameStateUpdated(state)

        HapticsService.shared.play(.legendary)
    }

    /// Called when boss fight is lost and player lets boss pass
    func onBossFightLost() {
        guard var state = state else { return }

        TDBossSystem.onBossFightLostLetPass(state: &state)

        self.state = state
        gameStateDelegate?.gameStateUpdated(state)

        HapticsService.shared.play(.defeat)
    }

    func placeTower(weaponType: String, slotId: String, profile: PlayerProfile) {
        guard var state = state else {
            print("[TDGameScene] placeTower failed - no state")
            return
        }

        print("[TDGameScene] placeTower - weaponType: \(weaponType), slotId: \(slotId), hash: \(state.hash), powerAvailable: \(state.powerAvailable)")

        // Check if this is a Protocol ID (System: Reboot) or a legacy weapon type
        let result: TowerPlacementResult
        if ProtocolLibrary.get(weaponType) != nil {
            // Use Protocol-based placement
            result = TowerSystem.placeTowerFromProtocol(state: &state, protocolId: weaponType, slotId: slotId, playerProfile: profile)
        } else {
            // Legacy weapon placement
            result = TowerSystem.placeTower(state: &state, weaponType: weaponType, slotId: slotId, playerProfile: profile)
        }

        switch result {
        case .success(let tower):
            print("[TDGameScene] Tower placed successfully - id: \(tower.id), damage: \(tower.damage)")
            // Update slot visual
            if let slotIndex = state.towerSlots.firstIndex(where: { $0.id == slotId }) {
                updateSlotVisual(slot: state.towerSlots[slotIndex])
            }
            self.state = state
            gameStateDelegate?.gameStateUpdated(state)

            // Persist tower placement
            StorageService.shared.saveTDSession(TDSessionState.from(gameState: state))
            HapticsService.shared.play(.towerPlace)

        case .insufficientGold(let required, let available):
            print("[TDGameScene] Tower placement failed - insufficientGold: required \(required), available \(available)")
            HapticsService.shared.play(.warning)
            gameStateDelegate?.placementFailed(result)

        case .insufficientPower(let required, let available):
            print("[TDGameScene] Tower placement failed - insufficientPower: required \(required), available \(available)")
            HapticsService.shared.play(.warning)
            gameStateDelegate?.placementFailed(result)

        case .slotOccupied:
            print("[TDGameScene] Tower placement failed - slot already occupied")
            HapticsService.shared.play(.warning)
            gameStateDelegate?.placementFailed(result)

        case .weaponLocked:
            print("[TDGameScene] Tower placement failed - weapon not unlocked")
            HapticsService.shared.play(.warning)
            gameStateDelegate?.placementFailed(result)

        case .invalidSlot:
            print("[TDGameScene] Tower placement failed - invalid slot")
            HapticsService.shared.play(.warning)
        }
    }

    func upgradeTower(_ towerId: String) {
        guard var state = state else { return }

        if TowerSystem.upgradeTower(state: &state, towerId: towerId) {
            self.state = state
            gameStateDelegate?.gameStateUpdated(state)

            // Persist upgrade
            StorageService.shared.saveTDSession(TDSessionState.from(gameState: state))
        }
    }

    func sellTower(_ towerId: String) {
        guard var state = state else { return }

        _ = TowerSystem.sellTower(state: &state, towerId: towerId)
        selectedTowerId = nil

        self.state = state
        gameStateDelegate?.gameStateUpdated(state)

        // Persist sale
        StorageService.shared.saveTDSession(TDSessionState.from(gameState: state))
    }

    // MARK: - Blocker Actions

    /// Place a blocker at a slot
    func placeBlocker(slotId: String) {
        guard var state = state else { return }

        let result = BlockerSystem.placeBlocker(state: &state, slotId: slotId)

        if case .success = result {
            self.state = state
            setupBlockers()  // Refresh blocker visuals
            setupPaths()     // Refresh paths (they may have changed)
            gameStateDelegate?.gameStateUpdated(state)
            HapticsService.shared.play(.medium)
        } else {
            HapticsService.shared.play(.warning)
        }
    }

    /// Remove a blocker
    func removeBlocker(blockerId: String) {
        guard var state = state else { return }

        BlockerSystem.removeBlocker(state: &state, blockerId: blockerId)

        self.state = state
        setupBlockers()
        setupPaths()
        gameStateDelegate?.gameStateUpdated(state)
        HapticsService.shared.play(.light)
    }

    /// Move a blocker to a new slot
    func moveBlocker(blockerId: String, toSlotId: String) {
        guard var state = state else { return }

        let result = BlockerSystem.moveBlocker(state: &state, blockerId: blockerId, toSlotId: toSlotId)

        if case .success = result {
            self.state = state
            setupBlockers()
            setupPaths()
            gameStateDelegate?.gameStateUpdated(state)
            HapticsService.shared.play(.medium)
        } else {
            HapticsService.shared.play(.warning)
        }
    }

    /// Check if a blocker can be placed at a slot
    func canPlaceBlockerAt(slotId: String) -> Bool {
        guard let state = state else { return false }
        return BlockerSystem.canPlaceBlockerAt(state: state, slotId: slotId)
    }

    /// Get preview of paths if blocker is placed
    func previewBlockerPaths(slotId: String) -> [EnemyPath]? {
        guard let state = state else { return nil }
        return BlockerSystem.previewPathsWithBlocker(state: state, slotId: slotId)
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

    private func convertToScene(_ point: CGPoint) -> CGPoint {
        // Convert from game coordinates (origin top-left) to SpriteKit (origin bottom-left)
        return CGPoint(x: point.x, y: size.height - point.y)
    }

    private func updateSlotVisual(slot: TowerSlot) {
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

// MARK: - UIColor Extension

extension UIColor {
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }

    /// Blend this color with another color
    func blended(with color: UIColor, ratio: CGFloat) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0

        self.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        color.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)

        let clampedRatio = max(0, min(1, ratio))
        return UIColor(
            red: r1 * (1 - clampedRatio) + r2 * clampedRatio,
            green: g1 * (1 - clampedRatio) + g2 * clampedRatio,
            blue: b1 * (1 - clampedRatio) + b2 * clampedRatio,
            alpha: a1 * (1 - clampedRatio) + a2 * clampedRatio
        )
    }

    /// Create a lighter version of this color
    func lighter(by percentage: CGFloat = 0.3) -> UIColor {
        return blended(with: .white, ratio: percentage)
    }

    /// Create a darker version of this color
    func darker(by percentage: CGFloat = 0.3) -> UIColor {
        return blended(with: .black, ratio: percentage)
    }

    /// Interpolate between this color and another (alias for blended)
    func interpolate(to color: UIColor, progress: CGFloat) -> UIColor {
        return blended(with: color, ratio: progress)
    }
}
