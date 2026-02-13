import SpriteKit

// MARK: - Particle Effect Service
// Extracted from TDGameScene+Effects (Step 4.3) — particle spawning,
// voltage arcs, screen shake, and boss effects with zero game-state
// dependencies beyond the scene layers and camera.

class ParticleEffectService {

    // MARK: - Scene References

    weak var scene: SKScene?
    weak var particleLayer: SKNode?
    weak var pathLayer: SKNode?
    weak var cameraNode: SKCameraNode?

    /// Current camera zoom level — queried from the camera controller each frame.
    var getCurrentScale: () -> CGFloat = { 1.0 }

    /// Current frame time — queried from the scene's `lastUpdateTime`.
    var getLastUpdateTime: () -> TimeInterval = { 0 }

    /// Number of active enemies — used to speed up power-flow particles during combat.
    var getEnemyCount: () -> Int = { 0 }

    /// Unlocked sector IDs — used by trace-pulse routing.
    var getUnlockedSectorIds: () -> Set<String> = { Set([SectorID.power.rawValue]) }

    // MARK: - Screen Shake State

    private var lastShakeTime: TimeInterval = 0
    var screenShakeCooldown: TimeInterval
    private var originalCameraPosition: CGPoint = .zero
    private(set) var isShaking: Bool = false

    // MARK: - Power Flow State

    var powerFlowEmitterRunning: Bool = false

    // MARK: - Map Config

    var isMotherboardMap: Bool = false

    // MARK: - Particle Pool (reuse circle nodes to reduce allocation spikes)

    private var circleParticlePool: [SKShapeNode] = []

    // MARK: - Init

    init(screenShakeCooldown: TimeInterval = BalanceConfig.TDRendering.screenShakeCooldown) {
        self.screenShakeCooldown = screenShakeCooldown
    }

    // MARK: - Configuration

    func configure(scene: SKScene, particleLayer: SKNode, pathLayer: SKNode,
                   cameraNode: SKCameraNode) {
        self.scene = scene
        self.particleLayer = particleLayer
        self.pathLayer = pathLayer
        self.cameraNode = cameraNode
    }

    // MARK: - Coordinate Conversion

    /// Convert from game coordinates (origin top-left) to SpriteKit (origin bottom-left).
    func convertToScene(_ point: CGPoint) -> CGPoint {
        guard let scene = scene else { return point }
        return CGPoint(x: point.x, y: scene.size.height - point.y)
    }

    // MARK: - Power Flow Particles

    /// Start the ambient power flow particle system for the PSU lane.
    /// Called once during motherboard setup.
    func startPowerFlowParticles() {
        guard !powerFlowEmitterRunning, let pathLayer = pathLayer else { return }
        powerFlowEmitterRunning = true

        let lanes = MotherboardLaneConfig.createAllLanes()
        guard let psuLane = lanes.first(where: { $0.sectorId == SectorID.power.rawValue }) else { return }

        let spawnInterval: TimeInterval = BalanceConfig.TDRendering.powerFlowSpawnInterval

        let spawnAction = SKAction.run { [weak self] in
            self?.spawnPowerFlowParticle(along: psuLane.path)
        }

        let wait = SKAction.wait(forDuration: spawnInterval)
        let sequence = SKAction.sequence([spawnAction, wait])

        pathLayer.run(SKAction.repeatForever(sequence), withKey: "powerFlowEmitter")
    }

    /// Spawn a single power flow particle that travels along the PSU path toward CPU.
    func spawnPowerFlowParticle(along path: EnemyPath) {
        guard path.waypoints.count >= 2, let pathLayer = pathLayer else { return }

        let psuYellow = UIColor(hex: "#ffdd00") ?? UIColor.yellow

        let particle = SKShapeNode(circleOfRadius: 3)
        particle.fillColor = psuYellow.withAlphaComponent(0.7)
        particle.strokeColor = psuYellow
        particle.lineWidth = 1
        particle.glowWidth = 1.0  // Short-lived PSU power flow
        particle.blendMode = .add
        particle.zPosition = 1.2  // Above path trace, below enemies (effective: 3+1.2=4.2)
        particle.name = "powerParticle"

        let startPoint = convertToScene(path.waypoints[0])
        particle.position = startPoint
        pathLayer.addChild(particle)

        let hasCombat = getEnemyCount() > 0
        let travelTime: TimeInterval = hasCombat ? 1.25 : 2.5

        var actions: [SKAction] = []

        for i in 0..<(path.waypoints.count - 1) {
            let from = convertToScene(path.waypoints[i])
            let to = convertToScene(path.waypoints[i + 1])

            let dx = to.x - from.x
            let dy = to.y - from.y
            let segmentLength = sqrt(dx * dx + dy * dy)

            let totalLength = calculatePathLength(path)
            let segmentTime = travelTime * (segmentLength / totalLength)

            actions.append(SKAction.move(to: to, duration: segmentTime))
        }

        actions.append(SKAction.fadeOut(withDuration: 0.2))
        actions.append(SKAction.removeFromParent())

        particle.run(SKAction.sequence(actions))
    }

    /// Calculate total length of a path.
    func calculatePathLength(_ path: EnemyPath) -> CGFloat {
        var totalLength: CGFloat = 0
        for i in 0..<(path.waypoints.count - 1) {
            let from = path.waypoints[i]
            let to = path.waypoints[i + 1]
            let dx = to.x - from.x
            let dy = to.y - from.y
            totalLength += sqrt(dx * dx + dy * dy)
        }
        return max(1, totalLength)
    }

    // MARK: - Trace Pulse Effects

    /// Spawn a trace pulse when a tower fires — travels along the copper trace toward CPU.
    func spawnTracePulse(at towerPosition: CGPoint, color: UIColor) {
        guard let pathLayer = pathLayer else { return }

        let lanes = MotherboardLaneConfig.createAllLanes()
        let unlockedSectorIds = getUnlockedSectorIds()

        var nearestLane: SectorLane?
        var nearestDistance: CGFloat = .infinity

        for lane in lanes {
            guard lane.isStarterLane || unlockedSectorIds.contains(lane.sectorId) else { continue }

            for waypoint in lane.path.waypoints {
                let dx = waypoint.x - towerPosition.x
                let dy = waypoint.y - towerPosition.y
                let dist = sqrt(dx * dx + dy * dy)
                if dist < nearestDistance {
                    nearestDistance = dist
                    nearestLane = lane
                }
            }
        }

        guard let lane = nearestLane, nearestDistance < 200 else { return }

        let pulseContainer = SKNode()
        pulseContainer.position = convertToScene(towerPosition)
        pulseContainer.zPosition = 2  // Above base effects, below UI
        pulseContainer.name = "tracePulse"

        let core = SKShapeNode(circleOfRadius: 10)
        core.fillColor = color.withAlphaComponent(0.9)
        core.strokeColor = color
        core.lineWidth = 2
        core.glowWidth = 2.0  // Bright energy pulse (transient ~0.5s)
        core.blendMode = .add
        core.name = "core"
        pulseContainer.addChild(core)

        let ring = SKShapeNode(circleOfRadius: 6)
        ring.fillColor = .clear
        ring.strokeColor = color.withAlphaComponent(0.6)
        ring.lineWidth = 3
        ring.glowWidth = 1.5  // Expanding energy ring (transient ~0.3s)
        ring.blendMode = .add
        ring.name = "ring"
        pulseContainer.addChild(ring)

        // Add to particleLayer (z=7) not pathLayer (z=3), so pulses render above towers
        (particleLayer ?? pathLayer).addChild(pulseContainer)

        let ringExpand = SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 3.0, duration: 0.3),
                SKAction.fadeOut(withDuration: 0.3)
            ]),
            SKAction.removeFromParent()
        ])
        ring.run(ringExpand)

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

        var actions: [SKAction] = []
        let travelSpeed = BalanceConfig.TDRendering.pulseTravelSpeed

        let startA = convertToScene(lane.path.waypoints[closestSegmentIndex])
        let startB = convertToScene(lane.path.waypoints[closestSegmentIndex + 1])
        let pathPoint = CGPoint(x: startA.x + (startB.x - startA.x) * closestT,
                                y: startA.y + (startB.y - startA.y) * closestT)

        let distToPath = distance(from: pulseContainer.position, to: pathPoint)
        if distToPath > 1 {
            actions.append(SKAction.move(to: pathPoint, duration: Double(distToPath / travelSpeed)))
        }

        for i in (closestSegmentIndex + 1)..<lane.path.waypoints.count {
            let waypoint = convertToScene(lane.path.waypoints[i])
            let prevPoint = i == closestSegmentIndex + 1 ? pathPoint : convertToScene(lane.path.waypoints[i - 1])
            let dist = distance(from: prevPoint, to: waypoint)
            actions.append(SKAction.move(to: waypoint, duration: Double(dist / travelSpeed)))
        }

        let totalDuration = actions.reduce(0) { $0 + $1.duration }
        let fadeAction = SKAction.fadeOut(withDuration: totalDuration)
        let shrinkAction = SKAction.scale(to: 0.3, duration: totalDuration)

        pulseContainer.run(SKAction.sequence([
            SKAction.group([
                SKAction.sequence(actions),
                fadeAction,
                shrinkAction
            ]),
            SKAction.removeFromParent()
        ]))
    }

    /// Find closest point on a line segment to a given point.
    func closestPointOnSegment(point: CGPoint, segmentStart: CGPoint, segmentEnd: CGPoint) -> (t: CGFloat, distance: CGFloat) {
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

    /// Simple distance helper.
    func distance(from a: CGPoint, to b: CGPoint) -> CGFloat {
        let dx = b.x - a.x
        let dy = b.y - a.y
        return sqrt(dx * dx + dy * dy)
    }

    // MARK: - Voltage Arc Effects

    /// Start the ambient voltage arc system for PSU sector.
    /// Creates random electric arcs between components.
    func startVoltageArcSystem() {
        guard isMotherboardMap, let pathLayer = pathLayer else { return }

        let arcAnchors = [
            CGPoint(x: 3000, y: 1800),
            CGPoint(x: 3200, y: 1600),
            CGPoint(x: 3800, y: 2200),
            CGPoint(x: 3400, y: 2000),
            CGPoint(x: 3600, y: 1700),
            CGPoint(x: 3100, y: 2400),
        ]

        let createArc = SKAction.run { [weak self] in
            guard let self = self else { return }
            guard arcAnchors.count >= 2 else { return }
            var indices = Array(0..<arcAnchors.count).shuffled()
            let startIdx = indices.removeFirst()
            let endIdx = indices.removeFirst()
            self.spawnVoltageArc(from: arcAnchors[startIdx], to: arcAnchors[endIdx])
        }

        let waitAction = SKAction.run { [weak self] in
            guard let self = self, let pathLayer = self.pathLayer else { return }
            let delay = TimeInterval.random(in: 8.0...15.0)
            pathLayer.run(SKAction.sequence([
                SKAction.wait(forDuration: delay),
                createArc,
                SKAction.run { self.scheduleNextArc() }
            ]), withKey: "voltageArcSchedule")
        }

        pathLayer.run(SKAction.sequence([
            SKAction.wait(forDuration: 2.0),
            createArc,
            waitAction
        ]), withKey: "voltageArcInit")
    }

    /// Schedule the next voltage arc.
    func scheduleNextArc() {
        guard isMotherboardMap, let pathLayer = pathLayer else { return }

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

        let delay = TimeInterval.random(in: 8.0...15.0)
        pathLayer.run(SKAction.sequence([
            SKAction.wait(forDuration: delay),
            createArc,
            SKAction.run { [weak self] in self?.scheduleNextArc() }
        ]), withKey: "voltageArcSchedule")
    }

    /// Spawn a single voltage arc between two points.
    func spawnVoltageArc(from start: CGPoint, to end: CGPoint) {
        guard let pathLayer = pathLayer else { return }

        let startScene = convertToScene(start)
        let endScene = convertToScene(end)

        let arcPath = createLightningPath(from: startScene, to: endScene, segments: Int.random(in: 2...3))

        let arc = SKShapeNode(path: arcPath)
        arc.strokeColor = UIColor.yellow.withAlphaComponent(0.6)
        arc.lineWidth = 1.5
        arc.glowWidth = 2.0  // Electric flash (transient ~0.13s)
        arc.blendMode = .add
        arc.zPosition = -2.5
        arc.name = "voltageArc"
        pathLayer.addChild(arc)

        let flashSequence = SKAction.sequence([
            SKAction.run { arc.glowWidth = 3.0 },
            SKAction.wait(forDuration: 0.02),
            SKAction.run { arc.glowWidth = 1.5 },
            SKAction.wait(forDuration: 0.03),
            SKAction.fadeOut(withDuration: 0.08),
            SKAction.removeFromParent()
        ])

        arc.run(flashSequence)
    }

    /// Create a jagged lightning bolt path between two points.
    func createLightningPath(from start: CGPoint, to end: CGPoint, segments: Int) -> CGPath {
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

            let offset = CGFloat.random(in: -20...20)
            let pointX = baseX + normPerpX * offset
            let pointY = baseY + normPerpY * offset

            path.addLine(to: CGPoint(x: pointX, y: pointY))
        }

        path.addLine(to: end)
        return path
    }

    /// Spawn a small spark effect at arc endpoint.
    func spawnArcSpark(at position: CGPoint) {
        guard let pathLayer = pathLayer else { return }

        let spark = SKShapeNode(circleOfRadius: 4)
        spark.position = position
        spark.fillColor = UIColor.white.withAlphaComponent(0.9)
        spark.strokeColor = .clear
        spark.glowWidth = 2.0  // Bright spark flash (transient ~0.1s)
        spark.blendMode = .add
        spark.zPosition = 1.5  // Above path elements, below enemies (effective: 3+1.5=4.5)
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

    /// Trigger screen shake with context-aware constraints.
    /// Only shakes when zoomed in, respects cooldown, and checks visibility.
    func triggerScreenShake(intensity: CGFloat, duration: TimeInterval, position: CGPoint? = nil) {
        guard let camera = cameraNode else { return }

        let scale = getCurrentScale()

        // RULE 1: Only shake when zoomed in (scale < 0.6)
        guard scale < 0.6 else { return }

        // RULE 2: If position provided, only shake if position is visible on screen
        if let pos = position {
            let scenePos = convertToScene(pos)
            if !isPositionVisible(scenePos) { return }
        }

        // RULE 3: Cooldown
        let currentTime = getLastUpdateTime()
        guard currentTime - lastShakeTime >= screenShakeCooldown else { return }
        lastShakeTime = currentTime

        // RULE 4: Don't start new shake if already shaking
        guard !isShaking else { return }

        isShaking = true
        originalCameraPosition = camera.position

        let shakeCount = Int(duration / 0.03)
        var shakeActions: [SKAction] = []

        for i in 0..<shakeCount {
            let progress = CGFloat(i) / CGFloat(shakeCount)
            let decayMultiplier = 1.0 - progress

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

        let resetAction = SKAction.run { [weak self] in
            guard let self = self, let camera = self.cameraNode else { return }
            camera.position = self.originalCameraPosition
            self.isShaking = false
        }
        shakeActions.append(resetAction)

        camera.run(SKAction.sequence(shakeActions), withKey: "screenShake")
    }

    /// Check if a scene position is visible in the current camera view.
    func isPositionVisible(_ scenePosition: CGPoint) -> Bool {
        guard let camera = cameraNode, let view = scene?.view else { return false }

        let scale = getCurrentScale()
        let viewWidth = view.bounds.width * scale
        let viewHeight = view.bounds.height * scale

        let visibleRect = CGRect(
            x: camera.position.x - viewWidth / 2,
            y: camera.position.y - viewHeight / 2,
            width: viewWidth,
            height: viewHeight
        )

        return visibleRect.contains(scenePosition)
    }

    /// Flash a color overlay on the screen (for impacts, damage, boss events).
    func flashOverlay(color: UIColor, alpha: CGFloat = 0.15, duration: TimeInterval = 0.15) {
        guard let camera = cameraNode, let view = scene?.view else { return }

        let scale = getCurrentScale()
        let overlaySize = CGSize(
            width: view.bounds.width * scale * 2,
            height: view.bounds.height * scale * 2
        )
        let overlay = SKShapeNode(rectOf: overlaySize)
        overlay.position = .zero
        overlay.fillColor = color
        overlay.strokeColor = .clear
        overlay.alpha = 0
        overlay.zPosition = 1000
        overlay.name = "flashOverlay"

        camera.addChild(overlay)

        let flashIn = SKAction.fadeAlpha(to: alpha, duration: duration * 0.2)
        let flashOut = SKAction.fadeOut(withDuration: duration * 0.8)
        let remove = SKAction.removeFromParent()

        overlay.run(SKAction.sequence([flashIn, flashOut, remove]))
    }

    // MARK: - Boss Effects

    /// Trigger boss entrance effects (warning rings + shake + flash).
    func triggerBossEntranceEffect(at position: CGPoint, bossColor: UIColor = .red) {
        let scenePos = convertToScene(position)

        for i in 0..<3 {
            let delay = TimeInterval(i) * 0.15
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.spawnWarningRing(at: scenePos, color: bossColor, delay: 0)
            }
        }

        triggerScreenShake(intensity: 6, duration: 0.25, position: position)
        flashOverlay(color: .yellow, alpha: 0.2, duration: 0.2)
    }

    /// Trigger boss death effects (massive explosion + rings + shake).
    func triggerBossDeathEffect(at position: CGPoint, bossColor: UIColor = .red) {
        let scenePos = convertToScene(position)

        spawnBossDeathExplosion(at: scenePos, color: bossColor)

        for i in 0..<5 {
            let delay = TimeInterval(i) * 0.1
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.spawnDeathRing(at: scenePos, color: bossColor, scale: 1.0 + CGFloat(i) * 0.3)
            }
        }

        triggerScreenShake(intensity: 8, duration: 0.35, position: position)
        flashOverlay(color: bossColor, alpha: 0.25, duration: 0.25)
    }

    /// Spawn expanding warning ring for boss entrance.
    func spawnWarningRing(at position: CGPoint, color: UIColor, delay: TimeInterval) {
        guard let particleLayer = particleLayer else { return }

        let ring = SKShapeNode(circleOfRadius: 20)
        ring.position = position
        ring.fillColor = .clear
        ring.strokeColor = color.withAlphaComponent(0.8)
        ring.lineWidth = 4
        ring.glowWidth = 8  // Short-lived dramatic effect (0.6s)
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

    /// Spawn death ring for boss death effect.
    func spawnDeathRing(at position: CGPoint, color: UIColor, scale: CGFloat) {
        guard let particleLayer = particleLayer else { return }

        let ring = SKShapeNode(circleOfRadius: 30)
        ring.position = position
        ring.fillColor = .clear
        ring.strokeColor = color.withAlphaComponent(0.9)
        ring.lineWidth = 6
        ring.glowWidth = 10  // Short-lived dramatic effect (0.5s)
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

    /// Acquire a circle particle from pool or create a new one.
    private func acquireCircleParticle(radius: CGFloat) -> SKShapeNode {
        if let node = circleParticlePool.popLast() {
            // Reset pooled node state
            node.alpha = 1.0
            node.isHidden = false
            node.removeAllActions()
            node.xScale = 1.0
            node.yScale = 1.0
            node.zRotation = 0
            // Rebuild path for new size
            node.path = CGPath(ellipseIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2), transform: nil)
            return node
        }
        return SKShapeNode(circleOfRadius: radius)
    }

    /// Return a circle particle to the pool (max 60 pooled).
    private func releaseCircleParticle(_ node: SKShapeNode) {
        node.removeFromParent()
        node.removeAllActions()
        if circleParticlePool.count < 60 {
            circleParticlePool.append(node)
        }
    }

    /// Spawn massive particle explosion for boss death (pooled to eliminate allocation spikes).
    func spawnBossDeathExplosion(at position: CGPoint, color: UIColor) {
        guard let particleLayer = particleLayer else { return }

        let particleCount = 50

        for _ in 0..<particleCount {
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let speed = CGFloat.random(in: 80...200)
            let size = CGFloat.random(in: 4...10)

            let particle = acquireCircleParticle(radius: size)
            particle.position = position
            particle.fillColor = color.withAlphaComponent(0.9)
            particle.strokeColor = .white.withAlphaComponent(0.5)
            particle.lineWidth = 1
            particle.glowWidth = 6  // Short-lived dramatic effect (0.5-1.0s)
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

            // Return to pool instead of destroying
            particle.run(SKAction.sequence([
                SKAction.group([move, fadeAndShrink]),
                SKAction.run { [weak self, weak particle] in
                    guard let self, let particle else { return }
                    self.releaseCircleParticle(particle)
                }
            ]))
        }
    }

    /// Trigger player damage flash (red overlay).
    func triggerDamageFlash() {
        let scale = getCurrentScale()
        guard scale < 0.6 else { return }
        flashOverlay(color: .red, alpha: 0.15, duration: 0.2)
        triggerScreenShake(intensity: 3, duration: 0.15, position: nil)
    }

    // MARK: - Particle Effects

    /// Spawn portal animation when enemy enters the map.
    func spawnPortalAnimation(at position: CGPoint, completion: (() -> Void)? = nil) {
        guard let particleLayer = particleLayer else { return }

        let portalDuration: TimeInterval = BalanceConfig.TDRendering.portalAnimationDuration

        let portal = SKNode()
        portal.position = position
        portal.zPosition = 40
        particleLayer.addChild(portal)

        let outerRing = SKShapeNode(circleOfRadius: 5)
        outerRing.fillColor = .clear
        outerRing.strokeColor = DesignColors.dangerUI.withAlphaComponent(0.8)
        outerRing.lineWidth = 3
        outerRing.glowWidth = 0
        portal.addChild(outerRing)

        let innerGlow = SKShapeNode(circleOfRadius: 3)
        innerGlow.fillColor = DesignColors.dangerUI.withAlphaComponent(0.6)
        innerGlow.strokeColor = .clear
        innerGlow.glowWidth = 0
        portal.addChild(innerGlow)

        let swirlCount = 6
        for i in 0..<swirlCount {
            let angle = CGFloat(i) * (.pi * 2 / CGFloat(swirlCount))
            let swirl = SKShapeNode(circleOfRadius: 2)
            swirl.fillColor = DesignColors.warningUI
            swirl.strokeColor = .clear
            swirl.glowWidth = 0
            swirl.position = CGPoint(x: cos(angle) * 8, y: sin(angle) * 8)
            portal.addChild(swirl)

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

        let expandRing = SKAction.scale(to: 3.5, duration: portalDuration * 0.6)
        expandRing.timingMode = .easeOut
        let fadeRing = SKAction.fadeAlpha(to: 0, duration: portalDuration * 0.4)
        outerRing.run(SKAction.sequence([expandRing, fadeRing]))

        let pulseIn = SKAction.scale(to: 2.0, duration: portalDuration * 0.3)
        let pulseOut = SKAction.scale(to: 0.5, duration: portalDuration * 0.3)
        let contract = SKAction.scale(to: 0.1, duration: portalDuration * 0.2)
        let fadeOut = SKAction.fadeOut(withDuration: portalDuration * 0.2)
        pulseIn.timingMode = .easeOut
        pulseOut.timingMode = .easeIn
        innerGlow.run(SKAction.sequence([pulseIn, pulseOut, SKAction.group([contract, fadeOut])]))

        let wait = SKAction.wait(forDuration: portalDuration)
        let remove = SKAction.removeFromParent()
        let completeAction = SKAction.run {
            completion?()
        }
        portal.run(SKAction.sequence([wait, completeAction, remove]))
    }

    /// Spawn enemy death particles.
    func spawnDeathParticles(at position: CGPoint, color: UIColor, isBoss: Bool = false) {
        guard let particleLayer = particleLayer else { return }

        let particleCount = isBoss ? 40 : Int.random(in: 15...25)

        for _ in 0..<particleCount {
            let particle = SKShapeNode(circleOfRadius: CGFloat.random(in: 2...6))
            particle.fillColor = color
            particle.strokeColor = color.withAlphaComponent(0.5)
            particle.glowWidth = isBoss ? 5 : 3  // Short-lived dramatic effect (0.3-0.8s)
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

    /// Spawn hash floaties when enemy is killed.
    func spawnHashFloaties(at position: CGPoint, hashValue: Int) {
        guard let particleLayer = particleLayer else { return }

        let floatCount = min(5, max(1, hashValue / 5))

        for i in 0..<floatCount {
            let hashStar = SKLabelNode(text: "⭐")
            hashStar.fontSize = 14
            hashStar.position = CGPoint(
                x: position.x + CGFloat.random(in: -10...10),
                y: position.y + CGFloat.random(in: -5...5)
            )
            hashStar.zPosition = 60

            let delay = SKAction.wait(forDuration: Double(i) * 0.1)
            let moveUp = SKAction.moveBy(x: CGFloat.random(in: -20...20), y: 50, duration: 0.8)
            moveUp.timingMode = .easeOut
            let fade = SKAction.fadeOut(withDuration: 0.8)
            let scale = SKAction.scale(to: 0.5, duration: 0.8)
            let group = SKAction.group([moveUp, fade, scale])
            let sequence = SKAction.sequence([delay, group, SKAction.removeFromParent()])

            hashStar.run(sequence)
            particleLayer.addChild(hashStar)
        }

        let hashLabel = SKLabelNode(text: "+\(hashValue)")
        hashLabel.fontName = "Helvetica-Bold"
        hashLabel.fontSize = 16
        hashLabel.fontColor = .yellow
        hashLabel.position = position
        hashLabel.zPosition = 61

        let moveUp = SKAction.moveBy(x: 0, y: 40, duration: 0.6)
        let fade = SKAction.fadeOut(withDuration: 0.6)
        let group = SKAction.group([moveUp, fade])
        let sequence = SKAction.sequence([group, SKAction.removeFromParent()])

        hashLabel.run(sequence)
        particleLayer.addChild(hashLabel)
    }

    /// Spawn impact sparks when projectile hits.
    func spawnImpactSparks(at position: CGPoint, color: UIColor) {
        guard let particleLayer = particleLayer else { return }

        for _ in 0..<5 {
            let spark = SKShapeNode(circleOfRadius: CGFloat.random(in: 1...3))
            spark.fillColor = color
            spark.glowWidth = 1.5  // Impact flash (transient ~0.2s)
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

    /// Spawn core hit warning effect.
    func spawnCoreHitEffect(at position: CGPoint) {
        guard let particleLayer = particleLayer, let scene = scene else { return }

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

        let flash = SKSpriteNode(color: .red.withAlphaComponent(0.3), size: scene.size)
        flash.position = CGPoint(x: scene.size.width / 2, y: scene.size.height / 2)
        flash.zPosition = 100
        scene.addChild(flash)

        let fadeOut = SKAction.fadeOut(withDuration: 0.2)
        let remove = SKAction.removeFromParent()
        flash.run(SKAction.sequence([fadeOut, remove]))

        HapticsService.shared.play(.coreHit)
    }
}
