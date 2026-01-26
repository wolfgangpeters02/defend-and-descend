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
    private var activeSlotHighlight: SKShapeNode? // Highlights nearest valid slot during drag
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

    // Selection
    private var selectedSlotId: String?
    private var selectedTowerId: String?

    // Drag state for merging
    private var isDragging = false
    private var draggedTowerId: String?
    private var dragStartPosition: CGPoint?
    private var dragNode: SKNode?
    private var longPressTimer: Timer?
    private var validMergeTargets: Set<String> = []

    // Particle layer
    private var particleLayer: SKNode!

    // MARK: - Setup

    override func didMove(to view: SKView) {
        backgroundColor = .black
        // Only setup layers if not already done (loadState may have been called first)
        if backgroundLayer == nil {
            setupLayers()
        }
    }

    private func setupLayers() {
        // Create layer hierarchy (z-order matters for progressive disclosure)
        backgroundLayer = SKNode()
        backgroundLayer.zPosition = 0
        addChild(backgroundLayer)

        // Grid dots layer - below path, only visible during placement
        gridDotsLayer = SKNode()
        gridDotsLayer.zPosition = 1
        gridDotsLayer.alpha = 0  // Hidden by default
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
    }

    private func setupBackground() {
        guard let state = state else { return }

        // Clear existing
        backgroundLayer.removeAllChildren()

        // Background color
        let bg = SKSpriteNode(color: UIColor(hex: state.map.backgroundColor) ?? .darkGray, size: size)
        bg.position = CGPoint(x: size.width/2, y: size.height/2)
        backgroundLayer.addChild(bg)

        // Draw obstacles
        for obstacle in state.map.obstacles {
            let node = SKSpriteNode(
                color: UIColor(hex: obstacle.color) ?? .gray,
                size: CGSize(width: obstacle.width, height: obstacle.height)
            )
            node.position = CGPoint(x: obstacle.x + obstacle.width/2, y: size.height - obstacle.y - obstacle.height/2)
            backgroundLayer.addChild(node)
        }

        // Draw hazards
        for hazard in state.map.hazards {
            let node = SKSpriteNode(
                color: hazardColor(for: hazard.type).withAlphaComponent(0.6),
                size: CGSize(width: hazard.width, height: hazard.height)
            )
            node.position = CGPoint(x: hazard.x + hazard.width/2, y: size.height - hazard.y - hazard.height/2)
            backgroundLayer.addChild(node)
        }
    }

    private func setupPaths() {
        guard let state = state else { return }

        pathLayer.removeAllChildren()

        // Path dimensions from design system
        let pathWidth: CGFloat = DesignLayout.pathWidth        // 70pt wide
        let borderWidth: CGFloat = DesignLayout.pathBorderWidth // 4pt border

        // Draw each path with improved visibility
        for path in state.paths {
            let bezierPath = UIBezierPath()

            if let firstPoint = path.waypoints.first {
                bezierPath.move(to: convertToScene(firstPoint))

                for i in 1..<path.waypoints.count {
                    bezierPath.addLine(to: convertToScene(path.waypoints[i]))
                }
            }

            // Dark border/outline (behind main path)
            let borderNode = SKShapeNode()
            borderNode.path = bezierPath.cgPath
            borderNode.strokeColor = DesignColors.pathBorderUI
            borderNode.lineWidth = pathWidth + (borderWidth * 2)
            borderNode.lineCap = .round
            borderNode.lineJoin = .round
            borderNode.zPosition = 0
            pathLayer.addChild(borderNode)

            // Main path fill - tan gradient effect (using solid color for SpriteKit)
            let pathNode = SKShapeNode()
            pathNode.path = bezierPath.cgPath
            pathNode.strokeColor = DesignColors.pathFillLightUI
            pathNode.lineWidth = pathWidth
            pathNode.lineCap = .round
            pathNode.lineJoin = .round
            pathNode.zPosition = 1
            pathLayer.addChild(pathNode)

            // Add direction chevrons along the path
            addPathChevrons(for: path, pathWidth: pathWidth)
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

    /// Create a subtle grid dot for placement mode (progressive disclosure)
    private func createGridDot(slot: TowerSlot) -> SKShapeNode {
        let dotSize = DesignLayout.gridDotSize
        let dot = SKShapeNode(circleOfRadius: dotSize / 2)

        if slot.occupied {
            // No dot for occupied slots
            dot.fillColor = .clear
            dot.strokeColor = .clear
        } else {
            // Subtle muted dot
            dot.fillColor = DesignColors.mutedUI.withAlphaComponent(DesignLayout.gridDotOpacity)
            dot.strokeColor = .clear
        }

        return dot
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

    /// Enter placement mode - show grid dots with fade in
    func enterPlacementMode(weaponType: String) {
        guard !isInPlacementMode else { return }

        isInPlacementMode = true
        placementWeaponType = weaponType

        // Fade in grid dots
        gridDotsLayer.run(SKAction.fadeIn(withDuration: DesignAnimations.Timing.quick))

        // Update grid dots to show only unoccupied slots
        updateGridDotsVisibility()
    }

    /// Exit placement mode - hide grid dots with fade out
    func exitPlacementMode() {
        guard isInPlacementMode else { return }

        isInPlacementMode = false
        placementWeaponType = nil

        // Fade out grid dots
        gridDotsLayer.run(SKAction.fadeOut(withDuration: DesignAnimations.Timing.quick))

        // Remove active slot highlight
        activeSlotHighlight?.removeFromParent()
        activeSlotHighlight = nil
    }

    /// Update grid dot visibility based on slot occupation
    private func updateGridDotsVisibility() {
        guard let state = state else { return }

        for slot in state.towerSlots {
            if let dotNode = gridDotsLayer.childNode(withName: "gridDot_\(slot.id)") as? SKShapeNode {
                if slot.occupied {
                    dotNode.alpha = 0
                } else {
                    dotNode.alpha = 1
                }
            }
        }
    }

    /// Highlight the nearest valid slot during drag
    func highlightNearestSlot(_ slot: TowerSlot?, canAfford: Bool) {
        // Remove existing highlight
        activeSlotHighlight?.removeFromParent()
        activeSlotHighlight = nil

        guard let slot = slot, !slot.occupied else { return }

        // Create new highlight
        let highlight = SKShapeNode(circleOfRadius: 20)
        highlight.fillColor = canAfford
            ? DesignColors.primaryUI.withAlphaComponent(0.3)
            : DesignColors.dangerUI.withAlphaComponent(0.2)
        highlight.strokeColor = canAfford
            ? DesignColors.primaryUI
            : DesignColors.dangerUI
        highlight.lineWidth = 3
        highlight.glowWidth = canAfford ? 10 : 5
        highlight.position = convertToScene(slot.position)
        highlight.zPosition = 8

        // Pulse animation
        let scaleUp = SKAction.scale(to: 1.1, duration: 0.3)
        let scaleDown = SKAction.scale(to: 0.95, duration: 0.3)
        let pulse = SKAction.sequence([scaleUp, scaleDown])
        highlight.run(SKAction.repeatForever(pulse))

        addChild(highlight)
        activeSlotHighlight = highlight
    }

    private func setupCore() {
        guard let state = state else { return }

        let coreNode = SKShapeNode(circleOfRadius: 25)
        coreNode.fillColor = .yellow
        coreNode.strokeColor = .orange
        coreNode.lineWidth = 3
        coreNode.position = convertToScene(state.core.position)
        coreNode.name = "core"

        // Glow effect
        coreNode.glowWidth = 5

        backgroundLayer.addChild(coreNode)
    }

    // MARK: - Update Loop

    override func update(_ currentTime: TimeInterval) {
        guard var state = state, !state.isPaused, !state.isGameOver else { return }

        // Calculate delta time
        let deltaTime = lastUpdateTime == 0 ? 0 : currentTime - lastUpdateTime
        lastUpdateTime = currentTime

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

        // Efficiency System (System: Reboot)
        PathSystem.updateLeakDecay(state: &state, deltaTime: deltaTime)
        PathSystem.updateWattsIncome(state: &state, deltaTime: deltaTime)

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
                if gameStartDelay <= 0 {
                    hasStartedFirstWave = true
                    startWave()
                }
            } else if state.nextWaveCountdown <= 0 && currentWaveIndex < waves.count {
                // Auto-start next wave when countdown finishes
                startWave()
            }
        }

        // Update visuals
        updateTowerVisuals(state: state)
        updateEnemyVisuals(state: state)
        updateProjectileVisuals(state: state)
        updateCoreVisual(state: state, currentTime: currentTime)

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

            // Spawn next enemy
            if let enemy = WaveSystem.spawnNextEnemy(state: &state, wave: wave, currentTime: currentTime) {
                state.enemies.append(enemy)
            }
        }
    }

    // MARK: - Projectile Updates

    private func updateProjectiles(state: inout TDGameState, deltaTime: TimeInterval, currentTime: TimeInterval) {
        for i in (0..<state.projectiles.count).reversed() {
            var proj = state.projectiles[i]

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

    private func processCollisions(state: inout TDGameState) {
        for projIndex in (0..<state.projectiles.count).reversed() {
            var proj = state.projectiles[projIndex]

            // Skip enemy projectiles
            if proj.isEnemyProjectile { continue }

            for enemyIndex in 0..<state.enemies.count {
                var enemy = state.enemies[enemyIndex]
                if enemy.isDead || enemy.reachedCore { continue }

                // Check collision
                let dx = proj.x - enemy.x
                let dy = proj.y - enemy.y
                let distance = sqrt(dx*dx + dy*dy)
                let hitRadius = (proj.radius) + (enemy.size / 2)

                if distance < hitRadius && !proj.hitEnemies.contains(enemy.id) {
                    // Apply damage
                    enemy.health -= proj.damage
                    state.stats.damageDealt += proj.damage

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
                        state.gold += enemy.goldValue
                        state.stats.goldEarned += enemy.goldValue
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

                if let slow = slow, let duration = slowDuration {
                    enemy.applySlow(amount: slow, duration: duration, currentTime: state.gameTime)
                }

                if enemy.health <= 0 {
                    enemy.isDead = true
                    state.gold += enemy.goldValue
                    state.stats.goldEarned += enemy.goldValue
                    state.stats.enemiesKilled += 1
                    state.virusesKilledTotal += 1  // For passive Data generation
                    state.waveEnemiesRemaining -= 1
                }

                state.enemies[i] = enemy
            }
        }
    }

    // MARK: - Cleanup

    private func cleanupDeadEntities(state: inout TDGameState) {
        // Remove dead enemies
        state.enemies.removeAll { $0.isDead || $0.reachedCore }
    }

    // MARK: - Visual Updates

    private func updateTowerVisuals(state: TDGameState) {
        // Remove old tower nodes
        for (id, node) in towerNodes {
            if !state.towers.contains(where: { $0.id == id }) {
                node.removeFromParent()
                towerNodes.removeValue(forKey: id)
            }
        }

        // Update/create tower nodes
        for tower in state.towers {
            if let node = towerNodes[tower.id] {
                // Update existing
                node.position = convertToScene(tower.position)

                // Update range indicator visibility
                if let rangeNode = node.childNode(withName: "range") as? SKShapeNode {
                    let shouldShow = tower.id == selectedTowerId || isDragging
                    if shouldShow != !rangeNode.isHidden {
                        rangeNode.isHidden = !shouldShow
                    }
                }

                // Update rotation (barrel points to target)
                if let barrel = node.childNode(withName: "barrel") {
                    barrel.zRotation = tower.rotation - .pi/2
                }

                // Update merge stars if level changed
                if let starsNode = node.childNode(withName: "stars") {
                    let currentStarCount = starsNode.children.count
                    if currentStarCount != tower.mergeLevel {
                        starsNode.removeFromParent()
                        let newStars = createMergeStars(count: tower.mergeLevel)
                        newStars.name = "stars"
                        newStars.position = CGPoint(x: 0, y: -22)
                        node.addChild(newStars)
                    }
                }

                // Update cooldown arc
                updateCooldownArc(for: tower, node: node, currentTime: state.gameTime)

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
        let container = SKNode()
        let towerColor = UIColor(hex: tower.color) ?? .blue

        // Tower base/body - weapon-specific style
        let body = createWeaponBody(for: tower.weaponType, color: towerColor)
        body.name = "body"
        container.addChild(body)

        // Barrel/turret
        let barrel = createWeaponBarrel(for: tower.weaponType, color: towerColor)
        barrel.name = "barrel"
        barrel.anchorPoint = CGPoint(x: 0.5, y: 0)
        container.addChild(barrel)

        // Merge stars (1-3)
        let starsNode = createMergeStars(count: tower.mergeLevel)
        starsNode.name = "stars"
        starsNode.position = CGPoint(x: 0, y: -22)
        container.addChild(starsNode)

        // Range indicator (hidden by default)
        let range = SKShapeNode(circleOfRadius: tower.range)
        range.fillColor = towerColor.withAlphaComponent(0.1)
        range.strokeColor = towerColor.withAlphaComponent(0.4)
        range.lineWidth = 2
        range.name = "range"
        range.isHidden = true
        container.addChild(range)

        // Cooldown arc (hidden by default, fills when on cooldown)
        let cooldownArc = SKShapeNode()
        cooldownArc.strokeColor = towerColor.withAlphaComponent(0.8)
        cooldownArc.lineWidth = 3
        cooldownArc.lineCap = .round
        cooldownArc.name = "cooldown"
        cooldownArc.isHidden = true
        container.addChild(cooldownArc)

        // Merge highlight (for valid merge targets)
        let mergeHighlight = SKShapeNode(circleOfRadius: 25)
        mergeHighlight.fillColor = .clear
        mergeHighlight.strokeColor = .green
        mergeHighlight.lineWidth = 3
        mergeHighlight.glowWidth = 5
        mergeHighlight.name = "mergeHighlight"
        mergeHighlight.isHidden = true
        container.addChild(mergeHighlight)

        return container
    }

    /// Create weapon-specific body shape
    private func createWeaponBody(for weaponType: String, color: UIColor) -> SKShapeNode {
        let body: SKShapeNode

        switch weaponType {
        case "bow", "crossbow":
            // Archer platform - circle
            body = SKShapeNode(circleOfRadius: 15)
            body.fillColor = color
            body.strokeColor = .white
            body.lineWidth = 2
        case "wand", "staff":
            // Mage tower - hexagon
            let path = createHexagonPath(radius: 16)
            body = SKShapeNode(path: path)
            body.fillColor = color
            body.strokeColor = .cyan
            body.lineWidth = 2
            body.glowWidth = 3
        case "cannon", "bomb":
            // Artillery - large square
            body = SKShapeNode(rectOf: CGSize(width: 32, height: 32), cornerRadius: 4)
            body.fillColor = color
            body.strokeColor = .gray
            body.lineWidth = 3
        case "ice_shard":
            // Crystal spire - diamond
            let path = createDiamondPath(size: 30)
            body = SKShapeNode(path: path)
            body.fillColor = color
            body.strokeColor = .cyan
            body.lineWidth = 2
            body.glowWidth = 4
        case "laser", "flamethrower":
            // Tech tower - rounded rect
            body = SKShapeNode(rectOf: CGSize(width: 28, height: 28), cornerRadius: 8)
            body.fillColor = color
            body.strokeColor = .white
            body.lineWidth = 2
        default:
            // Default square
            body = SKShapeNode(rectOf: CGSize(width: 30, height: 30), cornerRadius: 5)
            body.fillColor = color
            body.strokeColor = .white
            body.lineWidth = 2
        }

        return body
    }

    /// Create weapon-specific barrel/projectile indicator
    private func createWeaponBarrel(for weaponType: String, color: UIColor) -> SKSpriteNode {
        let barrel: SKSpriteNode

        switch weaponType {
        case "cannon", "bomb":
            barrel = SKSpriteNode(color: .darkGray, size: CGSize(width: 10, height: 18))
        case "laser", "flamethrower":
            barrel = SKSpriteNode(color: color.withAlphaComponent(0.8), size: CGSize(width: 6, height: 22))
        case "wand", "staff":
            barrel = SKSpriteNode(color: .clear, size: CGSize(width: 4, height: 16))
            // Add glowing orb at top
            let orb = SKShapeNode(circleOfRadius: 5)
            orb.fillColor = color
            orb.glowWidth = 6
            orb.position = CGPoint(x: 0, y: 18)
            barrel.addChild(orb)
        default:
            barrel = SKSpriteNode(color: .darkGray, size: CGSize(width: 8, height: 20))
        }

        return barrel
    }

    /// Create merge star indicators
    private func createMergeStars(count: Int) -> SKNode {
        let container = SKNode()
        let starSpacing: CGFloat = 12

        for i in 0..<count {
            let xOffset = CGFloat(i - (count - 1)) * starSpacing / 2 + CGFloat(i) * starSpacing / 2
            let star = SKShapeNode(circleOfRadius: 4)
            star.fillColor = .yellow
            star.strokeColor = .orange
            star.lineWidth = 1
            star.glowWidth = 2
            star.position = CGPoint(x: xOffset - CGFloat(count - 1) * starSpacing / 2, y: 0)

            // Animate stars with subtle pulse
            let pulse = SKAction.sequence([
                SKAction.scale(to: 1.2, duration: 0.5),
                SKAction.scale(to: 1.0, duration: 0.5)
            ])
            star.run(SKAction.repeatForever(pulse))

            container.addChild(star)
        }

        return container
    }

    /// Create hexagon path
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
        let enemyColor = UIColor(hex: enemy.color) ?? .red

        // Enemy body based on shape
        let body: SKShapeNode
        switch enemy.shape {
        case "triangle":
            let path = UIBezierPath()
            let size = enemy.size
            path.move(to: CGPoint(x: 0, y: size))
            path.addLine(to: CGPoint(x: -size * 0.866, y: -size/2))
            path.addLine(to: CGPoint(x: size * 0.866, y: -size/2))
            path.close()
            body = SKShapeNode(path: path.cgPath)
        case "hexagon":
            body = SKShapeNode(path: createHexagonPath(radius: enemy.size))
        case "diamond":
            body = SKShapeNode(path: createDiamondPath(size: enemy.size * 2))
        default:
            body = SKShapeNode(rectOf: CGSize(width: enemy.size, height: enemy.size), cornerRadius: 3)
        }

        body.fillColor = enemyColor
        body.strokeColor = enemy.isBoss ? .yellow : .white
        body.lineWidth = enemy.isBoss ? 3 : 1
        body.name = "body"
        container.addChild(body)

        // Boss glow effect
        if enemy.isBoss {
            body.glowWidth = 5

            // Boss crown
            let crown = SKLabelNode(text: "")
            crown.fontSize = 14
            crown.position = CGPoint(x: 0, y: enemy.size + 18)
            crown.name = "crown"
            container.addChild(crown)

            // Pulse animation for boss
            let pulse = SKAction.sequence([
                SKAction.scale(to: 1.1, duration: 0.5),
                SKAction.scale(to: 1.0, duration: 0.5)
            ])
            body.run(SKAction.repeatForever(pulse), withKey: "bossPulse")
        }

        // Slow effect overlay (hidden by default)
        let slowOverlay = SKShapeNode(circleOfRadius: enemy.size * 0.8)
        slowOverlay.fillColor = .cyan.withAlphaComponent(0.3)
        slowOverlay.strokeColor = .cyan.withAlphaComponent(0.6)
        slowOverlay.lineWidth = 2
        slowOverlay.name = "slowOverlay"
        slowOverlay.isHidden = true
        container.addChild(slowOverlay)

        // Health bar background
        let healthBarWidth = enemy.size * 1.5
        let healthBg = SKSpriteNode(color: .black.withAlphaComponent(0.5), size: CGSize(width: healthBarWidth + 2, height: 6))
        healthBg.position = CGPoint(x: 0, y: enemy.size + 8)
        container.addChild(healthBg)

        // Health bar
        let healthBar = SKSpriteNode(color: .green, size: CGSize(width: healthBarWidth, height: 4))
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
        // Remove old projectile nodes
        for (id, node) in projectileNodes {
            if !state.projectiles.contains(where: { $0.id == id }) {
                node.removeFromParent()
                projectileNodes.removeValue(forKey: id)
            }
        }

        // Update/create projectile nodes
        for proj in state.projectiles {
            if let node = projectileNodes[proj.id] {
                node.position = convertToScene(CGPoint(x: proj.x, y: proj.y))
            } else {
                let node = SKShapeNode(circleOfRadius: proj.radius)
                node.fillColor = UIColor(hex: proj.color) ?? .yellow
                node.strokeColor = .white
                node.lineWidth = 1
                node.position = convertToScene(CGPoint(x: proj.x, y: proj.y))
                projectileLayer.addChild(node)
                projectileNodes[proj.id] = node
            }
        }
    }

    private func updateCoreVisual(state: TDGameState, currentTime: TimeInterval) {
        guard let coreNode = backgroundLayer.childNode(withName: "core") as? SKShapeNode else { return }

        // Update color based on health
        let healthPercent = state.core.health / state.core.maxHealth
        if healthPercent > 0.6 {
            coreNode.fillColor = .yellow
        } else if healthPercent > 0.3 {
            coreNode.fillColor = .orange
        } else {
            coreNode.fillColor = .red
        }

        // Pulse effect
        let scale = CoreSystem.getCorePulseScale(state: state, currentTime: currentTime)
        coreNode.setScale(scale)
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

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
            // Check for merge drop
            if let targetId = findMergeTargetAtLocation(location), targetId != draggedId {
                performMerge(sourceTowerId: draggedId, targetTowerId: targetId)
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
        guard let tower = state?.towers.first(where: { $0.id == towerId }),
              tower.canMerge else { return }

        isDragging = true
        draggedTowerId = towerId
        longPressTimer = nil

        // Find valid merge targets
        if let state = state {
            validMergeTargets = Set(TowerSystem.findMergeTargets(state: state, towerId: towerId).map { $0.id })
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

        // Merge indicator
        let mergeIcon = SKLabelNode(text: "⭐")
        mergeIcon.fontSize = 16
        mergeIcon.verticalAlignmentMode = .center
        dragVisual.addChild(mergeIcon)

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

        // Dim the source tower
        if let sourceNode = towerNodes[towerId] {
            sourceNode.alpha = 0.3
        }

        // Haptic feedback
        HapticsService.shared.play(.selection)
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

        draggedTowerId = nil
        validMergeTargets.removeAll()
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

    func placeTower(weaponType: String, slotId: String, profile: PlayerProfile) {
        guard var state = state else { return }

        let result = TowerSystem.placeTower(state: &state, weaponType: weaponType, slotId: slotId, playerProfile: profile)

        if case .success = result {
            // Update slot visual
            if let slotIndex = state.towerSlots.firstIndex(where: { $0.id == slotId }) {
                updateSlotVisual(slot: state.towerSlots[slotIndex])
            }
            self.state = state
            gameStateDelegate?.gameStateUpdated(state)
        }
    }

    func upgradeTower(_ towerId: String) {
        guard var state = state else { return }

        if TowerSystem.upgradeTower(state: &state, towerId: towerId) {
            self.state = state
            gameStateDelegate?.gameStateUpdated(state)
        }
    }

    func sellTower(_ towerId: String) {
        guard var state = state else { return }

        _ = TowerSystem.sellTower(state: &state, towerId: towerId)
        selectedTowerId = nil

        self.state = state
        gameStateDelegate?.gameStateUpdated(state)
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

    // MARK: - Helpers

    private func convertToScene(_ point: CGPoint) -> CGPoint {
        // Convert from game coordinates (origin top-left) to SpriteKit (origin bottom-left)
        return CGPoint(x: point.x, y: size.height - point.y)
    }

    private func updateSlotVisual(slot: TowerSlot) {
        // Update grid dot visibility based on occupation
        if let dotNode = gridDotsLayer.childNode(withName: "gridDot_\(slot.id)") as? SKShapeNode {
            if slot.occupied {
                dotNode.fillColor = .clear
                dotNode.alpha = 0
            } else {
                dotNode.fillColor = DesignColors.mutedUI.withAlphaComponent(DesignLayout.gridDotOpacity)
                dotNode.alpha = isInPlacementMode ? 1 : 0
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
}
