import SpriteKit
import SwiftUI

extension TDGameScene {

    // MARK: - PCB Trace Helper

    /// Draw a single PCB trace path
    /// - Parameters:
    ///   - points: Array of (x, y) offsets from sector origin
    ///   - node: Parent node to add trace to
    ///   - baseX/baseY: Sector world origin
    ///   - zPos: Z position for layering
    ///   - lineWidth: Trace thickness (6pt for main, 3pt for secondary)
    ///   - alpha: Copper color alpha (0.15 for main, 0.1 for secondary)
    func drawPCBTrace(points: [(x: CGFloat, y: CGFloat)], to node: SKNode,
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
    func addPSUTraces(to node: SKNode, baseX: CGFloat, baseY: CGFloat, zPos: CGFloat) {
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
    func startPowerFlowParticles() {
        guard !powerFlowEmitterRunning else { return }
        powerFlowEmitterRunning = true

        // Get PSU lane path
        let lanes = MotherboardLaneConfig.createAllLanes()
        guard let psuLane = lanes.first(where: { $0.sectorId == SectorID.power.rawValue }) else { return }

        // Schedule repeating spawn action
        let spawnInterval: TimeInterval = BalanceConfig.TDRendering.powerFlowSpawnInterval

        let spawnAction = SKAction.run { [weak self] in
            self?.spawnPowerFlowParticle(along: psuLane.path)
        }

        let wait = SKAction.wait(forDuration: spawnInterval)
        let sequence = SKAction.sequence([spawnAction, wait])

        pathLayer.run(SKAction.repeatForever(sequence), withKey: "powerFlowEmitter")
    }

    /// Spawn a single power flow particle that travels along the PSU path toward CPU
    func spawnPowerFlowParticle(along path: EnemyPath) {
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
    func calculatePathLength(_ path: EnemyPath) -> CGFloat {
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
    func spawnTracePulse(at towerPosition: CGPoint, color: UIColor) {
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
        let travelSpeed = BalanceConfig.TDRendering.pulseTravelSpeed

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

    /// Simple distance helper
    func distance(from a: CGPoint, to b: CGPoint) -> CGFloat {
        let dx = b.x - a.x
        let dy = b.y - a.y
        return sqrt(dx * dx + dy * dy)
    }

    // MARK: - Voltage Arc Effects

    /// Start the ambient voltage arc system for PSU sector
    /// Creates random electric arcs between components
    func startVoltageArcSystem() {
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
    func scheduleNextArc() {
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
    func spawnVoltageArc(from start: CGPoint, to end: CGPoint) {
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
    func spawnArcSpark(at position: CGPoint) {
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
    func isPositionVisible(_ scenePosition: CGPoint) -> Bool {
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
    func spawnWarningRing(at position: CGPoint, color: UIColor, delay: TimeInterval) {
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
    func spawnDeathRing(at position: CGPoint, color: UIColor, scale: CGFloat) {
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
    func spawnBossDeathExplosion(at position: CGPoint, color: UIColor) {
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


    // MARK: - Particle Effects

    /// Spawn portal animation when enemy enters the map
    func spawnPortalAnimation(at position: CGPoint, completion: (() -> Void)? = nil) {
        let portalDuration: TimeInterval = BalanceConfig.TDRendering.portalAnimationDuration

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

}
