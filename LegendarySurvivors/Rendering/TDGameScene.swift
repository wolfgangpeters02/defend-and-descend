import SpriteKit
import SwiftUI

// MARK: - TD Game Scene
// SpriteKit scene for Tower Defense rendering

class TDGameScene: SKScene {

    // MARK: - Properties

    weak var gameStateDelegate: TDGameSceneDelegate?

    private var state: TDGameState?
    private var lastUpdateTime: TimeInterval = 0
    private var spawnTimer: TimeInterval = 0
    private var currentWaveIndex: Int = 0
    private var waves: [TDWave] = []
    private var gameStartDelay: TimeInterval = 2.0  // Initial delay before wave 1
    private var hasStartedFirstWave: Bool = false

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
    private var validMergeTargets: Set<String> = []
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

    // Motherboard City rendering
    private var isMotherboardMap: Bool {
        state?.map.theme == "motherboard"
    }

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

        // CRITICAL: Suppress camera panning when in tower placement mode
        // This prevents the "wishy-washy" UX where map moves while placing towers
        if isInPlacementMode {
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

        // Clear existing visuals
        megaBoardRenderer?.removeAllGhostSectors()
        megaBoardRenderer?.removeAllEncryptionGates()
        megaBoardRenderer?.removeAllDataBuses()
        gateNodes.removeAll()

        // Rebuild
        setupMegaBoardVisuals()
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

        // 2. PCB Grid pattern (subtle copper grid)
        let gridNode = createPCBGridNode()
        gridNode.zPosition = -4
        backgroundLayer.addChild(gridNode)

        // 3. Draw districts as ghost outlines
        drawMotherboardDistricts()

        // 4. Draw system buses (copper traces)
        drawSystemBuses()

        // 5. Draw CPU core (always visible and glowing)
        drawCPUCore()
    }

    /// Create subtle PCB grid pattern
    private func createPCBGridNode() -> SKNode {
        let gridNode = SKNode()
        let gridSpacing: CGFloat = 100  // 100pt grid cells (40x40 grid on 4000x4000)
        let lineColor = UIColor(hex: MotherboardColors.ghostMode)?.withAlphaComponent(0.3) ?? UIColor.darkGray.withAlphaComponent(0.3)

        // Vertical lines
        for x in stride(from: 0, through: size.width, by: gridSpacing) {
            let line = SKShapeNode()
            let path = CGMutablePath()
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
            line.path = path
            line.strokeColor = lineColor
            line.lineWidth = 1
            gridNode.addChild(line)
        }

        // Horizontal lines
        for y in stride(from: 0, through: size.height, by: gridSpacing) {
            let line = SKShapeNode()
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            line.path = path
            line.strokeColor = lineColor
            line.lineWidth = 1
            gridNode.addChild(line)
        }

        return gridNode
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
                let lockedLabel = SKLabelNode(text: "LOCKED")
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

    /// Draw system buses as copper traces
    /// Only draws ACTIVE buses - inactive/locked buses are not rendered
    private func drawSystemBuses() {
        // Currently disabled - we only show the enemy paths (neon lines)
        // The copper traces were causing visual clutter
        // TODO: Re-enable when sector unlock system shows unlocked sectors
        return

        /*
        let config = MotherboardConfig.createDefault()
        let copperColor = UIColor(hex: MotherboardColors.copperTrace) ?? UIColor.orange

        for bus in config.buses {
            // Skip inactive buses entirely - no ghost rendering
            guard bus.isActive else { continue }

            for segment in bus.segments {
                let path = CGMutablePath()
                path.move(to: segment.start)
                path.addLine(to: segment.end)

                // Outer glow
                let glowNode = SKShapeNode(path: path)
                glowNode.strokeColor = copperColor.withAlphaComponent(0.3)
                glowNode.lineWidth = bus.width + 16
                glowNode.lineCap = .round
                glowNode.zPosition = -2.5
                glowNode.blendMode = .add
                backgroundLayer.addChild(glowNode)

                // Main trace
                let traceNode = SKShapeNode(path: path)
                traceNode.strokeColor = copperColor
                traceNode.lineWidth = bus.width
                traceNode.lineCap = .square  // Manhattan geometry - square caps
                traceNode.zPosition = -2
                backgroundLayer.addChild(traceNode)

                // Center highlight
                let highlightNode = SKShapeNode(path: path)
                highlightNode.strokeColor = UIColor.white.withAlphaComponent(0.2)
                highlightNode.lineWidth = bus.width * 0.3
                highlightNode.lineCap = .square
                highlightNode.zPosition = -1.5
                backgroundLayer.addChild(highlightNode)
            }
        }
        */
    }

    /// Draw glowing CPU core at center
    private func drawCPUCore() {
        let cpuColor = UIColor(hex: MotherboardColors.cpuCore) ?? UIColor.blue
        let glowColor = UIColor(hex: MotherboardColors.activeGlow) ?? UIColor.green

        let cpuSize: CGFloat = 300
        let cpuPosition = CGPoint(x: 2000, y: 2000)

        // Outer glow
        let outerGlow = SKShapeNode(rectOf: CGSize(width: cpuSize + 60, height: cpuSize + 60), cornerRadius: 20)
        outerGlow.position = cpuPosition
        outerGlow.fillColor = cpuColor.withAlphaComponent(0.1)
        outerGlow.strokeColor = glowColor.withAlphaComponent(0.5)
        outerGlow.lineWidth = 3
        outerGlow.glowWidth = 20
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

    /// Motherboard-style copper trace paths
    private func setupMotherboardPaths() {
        guard let state = state else { return }

        let copperColor = UIColor(hex: MotherboardColors.copperTrace) ?? UIColor.orange
        let copperHighlight = UIColor(hex: MotherboardColors.copperHighlight) ?? UIColor(red: 0.83, green: 0.59, blue: 0.42, alpha: 1.0)
        let traceWidth: CGFloat = 24  // Thicker traces for PCB look

        for path in state.paths {
            // Create Manhattan-style path (straight lines, 90° turns)
            let bezierPath = UIBezierPath()

            if let firstPoint = path.waypoints.first {
                bezierPath.move(to: convertToScene(firstPoint))

                for i in 1..<path.waypoints.count {
                    bezierPath.addLine(to: convertToScene(path.waypoints[i]))
                }
            }

            // Outer dark border (PCB substrate showing through)
            let borderNode = SKShapeNode()
            borderNode.path = bezierPath.cgPath
            borderNode.strokeColor = UIColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 1.0)
            borderNode.lineWidth = traceWidth + 6
            borderNode.lineCap = .square  // Manhattan geometry - square caps
            borderNode.lineJoin = .miter  // Sharp 90° corners
            borderNode.zPosition = 1
            pathLayer.addChild(borderNode)

            // Main copper trace
            let pathNode = SKShapeNode()
            pathNode.path = bezierPath.cgPath
            pathNode.strokeColor = copperColor
            pathNode.lineWidth = traceWidth
            pathNode.lineCap = .square
            pathNode.lineJoin = .miter
            pathNode.zPosition = 2
            pathLayer.addChild(pathNode)

            // Inner highlight for 3D copper effect
            let highlightNode = SKShapeNode()
            highlightNode.path = bezierPath.cgPath
            highlightNode.strokeColor = copperHighlight.withAlphaComponent(0.6)
            highlightNode.lineWidth = traceWidth * 0.4
            highlightNode.lineCap = .square
            highlightNode.lineJoin = .miter
            highlightNode.zPosition = 3
            pathLayer.addChild(highlightNode)

            // Add data flow indicators (smaller, subtler)
            addMotherboardPathChevrons(for: path, pathWidth: traceWidth)
        }
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
        glowRing.glowWidth = 20
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

        // Process wave spawning
        if state.waveInProgress {
            processWaveSpawning(state: &state, currentTime: currentTime, deltaTime: deltaTime)
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

        // Check wave completion
        if state.waveInProgress && WaveSystem.isWaveComplete(state: state) {
            if currentWaveIndex < waves.count {
                WaveSystem.completeWave(state: &state, wave: waves[currentWaveIndex])
                currentWaveIndex += 1  // Move to next wave
                HapticsService.shared.play(.waveComplete)
            }
        }

        // Check victory
        if WaveSystem.checkVictory(state: state, totalWaves: waves.count) && !state.isGameOver {
            state.victory = true
            state.isGameOver = true
            HapticsService.shared.play(.legendary)
        }

        // Update wave countdown
        WaveSystem.updateWaveCountdown(state: &state, deltaTime: deltaTime)

        // Auto-start waves
        if !state.waveInProgress && !state.isGameOver {
            if !hasStartedFirstWave {
                // Initial delay before wave 1
                gameStartDelay -= deltaTime
                if gameStartDelay <= 0 && currentWaveIndex < waves.count {
                    hasStartedFirstWave = true
                    print("[TDGameScene] Starting first wave! currentWaveIndex: \(currentWaveIndex), waves.count: \(waves.count)")
                    // Start wave directly on local state (not via startWave() which modifies self.state)
                    WaveSystem.startWave(state: &state, wave: waves[currentWaveIndex])
                    spawnTimer = 0
                    print("[TDGameScene] After startWave - waveInProgress: \(state.waveInProgress), waveEnemiesRemaining: \(state.waveEnemiesRemaining)")
                }
            } else if state.nextWaveCountdown <= 0 && currentWaveIndex < waves.count {
                // Auto-start next wave when countdown finishes
                // Start wave directly on local state
                WaveSystem.startWave(state: &state, wave: waves[currentWaveIndex])
                spawnTimer = 0
            }
        }

        // Update camera physics (inertia scrolling)
        updateCameraPhysics(deltaTime: deltaTime)

        // Update parallax background
        updateParallaxLayers()

        // Update visuals
        updateTowerVisuals(state: state)
        updateEnemyVisuals(state: state)
        updateProjectileVisuals(state: state)
        updateCoreVisual(state: state, currentTime: currentTime)

        // Update Level of Detail based on zoom
        updateTowerLOD()

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

            // Debug: log spawn attempt
            print("[TDGameScene] Attempting spawn - waveEnemiesSpawned: \(state.waveEnemiesSpawned), waveEnemiesRemaining: \(state.waveEnemiesRemaining), wave.enemies: \(wave.enemies.count)")

            // Spawn next enemy with portal animation
            if let enemy = WaveSystem.spawnNextEnemy(state: &state, wave: wave, currentTime: currentTime) {
                state.enemies.append(enemy)
                let spawnPosition = convertToScene(enemy.position)
                spawnPortalAnimation(at: spawnPosition)
                print("[TDGameScene] Spawned enemy '\(enemy.type)' at (\(enemy.x), \(enemy.y)) -> scene pos: \(spawnPosition)")
            } else {
                print("[TDGameScene] spawnNextEnemy returned nil!")
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
                        spawnDeathParticles(at: deathPos, color: UIColor(hex: enemy.color) ?? .red, isBoss: enemy.isBoss)
                        spawnGoldFloaties(at: deathPos, goldValue: enemy.goldValue)
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

                // Update rotation (barrel points to target)
                if let barrel = node.childNode(withName: "barrel") {
                    barrel.zRotation = tower.rotation - .pi/2
                }

                // Update merge indicators if level changed
                if let starsNode = node.childNode(withName: "stars") {
                    let currentStarCount = starsNode.children.count
                    if currentStarCount != tower.mergeLevel {
                        starsNode.removeFromParent()
                        let towerColor = UIColor(hex: tower.color) ?? TowerColors.color(for: tower.weaponType)
                        let archetype = TowerVisualFactory.TowerArchetype.from(weaponType: tower.weaponType)
                        let newIndicator = TowerVisualFactory.createMergeIndicator(
                            count: tower.mergeLevel,
                            archetype: archetype,
                            color: towerColor
                        )
                        newIndicator.name = "stars"
                        newIndicator.position = CGPoint(x: 0, y: -24)
                        node.addChild(newIndicator)
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

        // Use the new animation system for muzzle flash and recoil
        TowerAnimations.playMuzzleFlash(node: node, duration: TowerEffects.muzzleFlashDuration)
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
    }

    /// Update cooldown arc indicator on tower
    private func updateCooldownArc(for tower: Tower, node: SKNode, currentTime: TimeInterval) {
        guard let cooldownNode = node.childNode(withName: "cooldown") as? SKShapeNode else { return }

        let attackInterval = 1.0 / tower.attackSpeed
        let timeSinceAttack = currentTime - tower.lastAttackTime
        let cooldownProgress = min(1.0, timeSinceAttack / attackInterval)

        if cooldownProgress < 1.0 {
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
            mergeLevel: tower.mergeLevel,
            level: tower.level,
            damage: tower.damage,
            attackSpeed: tower.attackSpeed,
            projectileCount: tower.projectileCount,
            rarity: rarityString
        )
    }

    /// Update Level of Detail visibility based on camera zoom
    private func updateTowerLOD() {
        // Show details when zoomed in (scale < 0.4 means close-up)
        let showDetail = currentScale < 0.4
        let targetAlpha: CGFloat = showDetail ? 1.0 : 0.0

        for (_, node) in towerNodes {
            if let lodDetail = node.childNode(withName: "lodDetail") {
                // Only animate if needed
                if abs(lodDetail.alpha - targetAlpha) > 0.01 {
                    lodDetail.removeAction(forKey: "lodFade")
                    let fadeAction = SKAction.fadeAlpha(to: targetAlpha, duration: 0.2)
                    lodDetail.run(fadeAction, withKey: "lodFade")
                }
            }
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
            let zeroDayLabel = SKLabelNode(text: "⚠ ZERO-DAY")
            zeroDayLabel.fontName = "Menlo-Bold"
            zeroDayLabel.fontSize = 10
            zeroDayLabel.fontColor = DesignColors.zeroDayVirusUI
            zeroDayLabel.position = CGPoint(x: 0, y: enemy.size + 20)
            zeroDayLabel.name = "bossIndicator"
            container.addChild(zeroDayLabel)

            // Menacing slow rotation
            let rotate = SKAction.rotate(byAngle: .pi * 2, duration: 6.0)
            body.run(SKAction.repeatForever(rotate))

        } else if enemy.isBoss {
            // Regular boss: White with warning glow and color cycle
            body.glowWidth = 10

            // Boss indicator
            let bossLabel = SKLabelNode(text: "⚠ BOSS")
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

                // Update slow effect
                if let slowOverlay = node.childNode(withName: "slowOverlay") as? SKShapeNode {
                    slowOverlay.isHidden = !enemy.isSlowed

                    // Add frost particle effect when slowed
                    if enemy.isSlowed && Int.random(in: 0..<10) == 0 {
                        spawnSlowParticle(at: node.position)
                    }
                }

                // Tint body when slowed
                if let body = node.childNode(withName: "body") as? SKShapeNode {
                    if enemy.isSlowed {
                        body.fillColor = (UIColor(hex: enemy.color) ?? .red).blended(with: .cyan, ratio: 0.3)
                    } else {
                        body.fillColor = UIColor(hex: enemy.color) ?? .red
                    }
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

                // Update trail
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
                projectile.glowWidth = 3
                container.addChild(projectile)

                // Trail container
                let trailNode = SKNode()
                trailNode.name = "trail"
                trailNode.zPosition = -1
                container.addChild(trailNode)

                projectileLayer.addChild(container)
                projectileNodes[proj.id] = container

                // Initialize trail
                projectileTrails[proj.id] = [scenePos]
            }
        }
    }

    /// Update projectile trail with glowing effect
    private func updateProjectileTrail(projId: String, position: CGPoint, color: UIColor) {
        // Get or create trail array
        var trail = projectileTrails[projId] ?? []

        // Add current position
        trail.append(position)

        // Limit trail length
        if trail.count > maxTrailLength {
            trail.removeFirst(trail.count - maxTrailLength)
        }

        projectileTrails[projId] = trail

        // Update trail visual
        guard let node = projectileNodes[projId],
              let trailNode = node.childNode(withName: "trail"),
              trail.count >= 2 else { return }

        // Remove old trail segments
        trailNode.removeAllChildren()

        // Draw new trail segments with fading effect
        for i in 0..<(trail.count - 1) {
            let startPos = CGPoint(x: trail[i].x - node.position.x, y: trail[i].y - node.position.y)
            let endPos = CGPoint(x: trail[i + 1].x - node.position.x, y: trail[i + 1].y - node.position.y)

            let path = UIBezierPath()
            path.move(to: startPos)
            path.addLine(to: endPos)

            let segment = SKShapeNode(path: path.cgPath)

            // Fade based on position in trail (older = more faded)
            let alpha = CGFloat(i + 1) / CGFloat(trail.count) * 0.6
            segment.strokeColor = color.withAlphaComponent(alpha)
            segment.lineWidth = max(1, 3 * alpha)
            segment.lineCap = .round
            segment.blendMode = .add  // Additive blending for glow effect
            segment.glowWidth = 2 * alpha

            trailNode.addChild(segment)
        }
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

        // Check for encryption gate tap (mega-board)
        // Use direct position-based hit detection for reliability
        if isMotherboardMap {
            let profile = AppState.shared.currentPlayer
            let visibleGates = MegaBoardSystem.shared.visibleGates(for: profile)

            for gate in visibleGates {
                // Create a hit rect around the gate position
                let hitRect = CGRect(
                    x: gate.position.x - gate.gateWidth / 2 - 20,  // Extra padding for easier tapping
                    y: gate.position.y - gate.gateHeight / 2 - 20,
                    width: gate.gateWidth + 40,
                    height: gate.gateHeight + 40
                )

                if hitRect.contains(location) {
                    print("[TDGameScene] Gate tapped: \(gate.sectorId) at \(gate.position)")
                    HapticsService.shared.play(.light)
                    gameStateDelegate?.gateSelected(gate.sectorId)
                    return
                }
            }
        }

        // Check for tower touch (start long-press timer for drag)
        for (towerId, node) in towerNodes {
            if node.contains(location) {
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

            // Update valid merge targets highlighting
            updateMergeTargetHighlights(at: location)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        // Cancel any pending long-press
        cancelLongPress()

        if isDragging, let draggedId = draggedTowerId {
            // Check for merge drop first (higher priority)
            if let targetId = findMergeTargetAtLocation(location), targetId != draggedId {
                performMerge(sourceTowerId: draggedId, targetTowerId: targetId)
            }
            // Check for move to empty slot
            else if let targetSlotId = findEmptySlotAtLocation(location) {
                performTowerMove(towerId: draggedId, toSlotId: targetSlotId)
            }

            // End drag
            endDrag()
        } else {
            // Normal tap - select tower
            for (towerId, node) in towerNodes {
                if node.contains(location) {
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

        // Find valid merge targets (only if tower can merge)
        if let state = state {
            if tower.canMerge {
                validMergeTargets = Set(TowerSystem.findMergeTargets(state: state, towerId: towerId).map { $0.id })
            } else {
                validMergeTargets = []
            }

            // Find empty slots for repositioning
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

        // Move/merge indicator
        let icon = SKLabelNode(text: tower.canMerge ? "⭐" : "↔")
        icon.fontSize = 16
        icon.verticalAlignmentMode = .center
        dragVisual.addChild(icon)

        dragVisual.position = position
        dragVisual.zPosition = 100
        dragNode = dragVisual
        addChild(dragVisual)

        // Show range on all valid merge targets
        for targetId in validMergeTargets {
            if let node = towerNodes[targetId] {
                if let highlight = node.childNode(withName: "mergeHighlight") as? SKShapeNode {
                    highlight.isHidden = false
                    // Pulse animation
                    let pulse = SKAction.sequence([
                        SKAction.scale(to: 1.1, duration: 0.3),
                        SKAction.scale(to: 1.0, duration: 0.3)
                    ])
                    highlight.run(SKAction.repeatForever(pulse), withKey: "pulse")
                }
            }
        }

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

    private func updateMergeTargetHighlights(at location: CGPoint) {
        // Reset all highlights
        for (towerId, node) in towerNodes {
            if let highlight = node.childNode(withName: "mergeHighlight") as? SKShapeNode {
                if validMergeTargets.contains(towerId) {
                    // Check if hovering over this target
                    let distance = hypot(node.position.x - location.x, node.position.y - location.y)
                    if distance < 40 {
                        highlight.strokeColor = .yellow
                        highlight.glowWidth = 8
                    } else {
                        highlight.strokeColor = .green
                        highlight.glowWidth = 5
                    }
                }
            }
        }
    }

    private func findMergeTargetAtLocation(_ location: CGPoint) -> String? {
        for (towerId, node) in towerNodes {
            if validMergeTargets.contains(towerId) {
                let distance = hypot(node.position.x - location.x, node.position.y - location.y)
                if distance < 40 {
                    return towerId
                }
            }
        }
        return nil
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

    private func performMerge(sourceTowerId: String, targetTowerId: String) {
        guard var state = state else { return }

        let result = TowerSystem.mergeTowers(state: &state, sourceTowerId: sourceTowerId, targetTowerId: targetTowerId)

        switch result {
        case .success(let mergedTower, _):
            // Spawn merge particles
            let targetPos = towerNodes[targetTowerId]?.position ?? .zero
            spawnMergeParticles(at: targetPos, color: UIColor(hex: mergedTower.color) ?? .yellow)

            // Haptic feedback
            HapticsService.shared.play(.legendary)

            // Update state
            self.state = state
            gameStateDelegate?.gameStateUpdated(state)

            // Persist merge
            StorageService.shared.saveTDSession(TDSessionState.from(gameState: state))

        default:
            // Merge failed - play error feedback
            HapticsService.shared.play(.error)
        }
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

        // Hide all merge highlights
        for (_, node) in towerNodes {
            if let highlight = node.childNode(withName: "mergeHighlight") as? SKShapeNode {
                highlight.isHidden = true
                highlight.removeAction(forKey: "pulse")
            }
        }

        // Hide empty slot move highlights
        hideEmptySlotHighlights()

        draggedTowerId = nil
        validMergeTargets.removeAll()
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

    private func spawnMergeParticles(at position: CGPoint, color: UIColor) {
        let particleCount = Int.random(in: 35...65)

        for _ in 0..<particleCount {
            let particle = SKShapeNode(circleOfRadius: CGFloat.random(in: 2...5))
            particle.fillColor = [color, .yellow, .orange, .white].randomElement()!
            particle.strokeColor = .clear
            particle.position = position
            particle.zPosition = 50

            let angle = CGFloat.random(in: 0...(2 * .pi))
            let speed = CGFloat.random(in: 80...200)
            let dx = cos(angle) * speed
            let dy = sin(angle) * speed

            let moveAction = SKAction.move(by: CGVector(dx: dx, dy: dy), duration: 0.6)
            moveAction.timingMode = .easeOut
            let fadeAction = SKAction.fadeOut(withDuration: 0.6)
            let scaleAction = SKAction.scale(to: 0.1, duration: 0.6)
            let group = SKAction.group([moveAction, fadeAction, scaleAction])
            let sequence = SKAction.sequence([group, SKAction.removeFromParent()])

            particle.run(sequence)
            particleLayer.addChild(particle)
        }
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
                cpuBody.glowWidth = 30
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

    func placeTower(weaponType: String, slotId: String, profile: PlayerProfile) {
        guard var state = state else { return }

        // Check if this is a Protocol ID (System: Reboot) or a legacy weapon type
        let result: TowerPlacementResult
        if ProtocolLibrary.get(weaponType) != nil {
            // Use Protocol-based placement
            result = TowerSystem.placeTowerFromProtocol(state: &state, protocolId: weaponType, slotId: slotId, playerProfile: profile)
        } else {
            // Legacy weapon placement
            result = TowerSystem.placeTower(state: &state, weaponType: weaponType, slotId: slotId, playerProfile: profile)
        }

        if case .success = result {
            // Update slot visual
            if let slotIndex = state.towerSlots.firstIndex(where: { $0.id == slotId }) {
                updateSlotVisual(slot: state.towerSlots[slotIndex])
            }
            self.state = state
            gameStateDelegate?.gameStateUpdated(state)

            // Persist tower placement
            StorageService.shared.saveTDSession(TDSessionState.from(gameState: state))
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

    /// Get current camera scale (zoom level)
    var cameraScale: CGFloat {
        currentScale
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
}
