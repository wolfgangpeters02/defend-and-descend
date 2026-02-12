import SpriteKit
import SwiftUI

extension TDGameScene {

    func setupPaths() {
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
    func setupStandardPaths() {
        guard let state = state else { return }

        // Circuit trace dimensions - thinner for tech aesthetic
        let traceWidth: CGFloat = DesignLayout.pathWidth         // Main trace width
        let glowWidth: CGFloat = 0                  // PERF: was traceWidth + 8 (GPU Gaussian blur)

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
            glowNode.glowWidth = 0  // PERF: was 10 (GPU Gaussian blur)
            glowNode.blendMode = .add  // Additive blending for brighter glow
            pathLayer.addChild(glowNode)

            // Dark border/outline for depth
            let borderNode = SKShapeNode()
            borderNode.path = bezierPath.cgPath
            borderNode.strokeColor = DesignColors.traceBorderUI
            borderNode.lineWidth = traceWidth + 4
            borderNode.lineCap = .round
            borderNode.lineJoin = .round
            borderNode.zPosition = 0.2
            pathLayer.addChild(borderNode)

            // Main circuit trace - bright cyan
            let pathNode = SKShapeNode()
            pathNode.path = bezierPath.cgPath
            pathNode.strokeColor = DesignColors.tracePrimaryUI
            pathNode.lineWidth = traceWidth
            pathNode.lineCap = .round
            pathNode.lineJoin = .round
            pathNode.zPosition = 0.4
            pathLayer.addChild(pathNode)

            // Inner highlight for 3D effect
            let highlightNode = SKShapeNode()
            highlightNode.path = bezierPath.cgPath
            highlightNode.strokeColor = UIColor.white.withAlphaComponent(0.3)
            highlightNode.lineWidth = traceWidth * 0.3
            highlightNode.lineCap = .round
            highlightNode.lineJoin = .round
            highlightNode.zPosition = 0.6
            pathLayer.addChild(highlightNode)

            // Add data flow direction indicators (chevrons)
            addPathChevrons(for: path, pathWidth: traceWidth)
        }
    }

    /// Motherboard-style copper trace paths for all 8 lanes
    /// Renders active lanes in full brightness, locked lanes dimmed at 25%
    func setupMotherboardPaths() {
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
            let renderMode: SectorRenderMode = isUnlocked ? .unlocked : MegaBoardSystem.shared.getRenderMode(for: lane.sectorId, profile: playerProfile)
            let dimAlpha: CGFloat
            switch renderMode {
            case .unlocked: dimAlpha = 1.0
            case .unlockable: dimAlpha = 0.5
            case .locked: dimAlpha = 0.2
            }

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
            borderNode.zPosition = 0.2
            borderNode.name = "lane_border_\(lane.id)"
            pathLayer.addChild(borderNode)

            // Main copper trace color based on render mode
            let pathNode = SKShapeNode()
            pathNode.path = bezierPath.cgPath
            switch renderMode {
            case .unlocked:
                pathNode.strokeColor = copperColor
            case .unlockable:
                // Theme-tinted copper for blueprint-found sectors
                let themeColor = UIColor(hex: lane.themeColorHex) ?? UIColor.yellow
                pathNode.strokeColor = themeColor.withAlphaComponent(dimAlpha)
            case .locked:
                // Desaturated gray-copper for locked (no blueprints)
                pathNode.strokeColor = UIColor(red: 0.45, green: 0.40, blue: 0.35, alpha: dimAlpha)
            }
            pathNode.lineWidth = traceWidth
            pathNode.lineCap = .square
            pathNode.lineJoin = .miter
            pathNode.zPosition = 0.4
            pathNode.name = "lane_path_\(lane.id)"
            pathLayer.addChild(pathNode)

            // Inner highlight for 3D copper effect with subtle powered glow
            let highlightNode = SKShapeNode()
            highlightNode.path = bezierPath.cgPath
            let highlightAlpha: CGFloat = renderMode == .unlocked ? 0.6 : (renderMode == .unlockable ? 0.25 : 0.1)
            highlightNode.strokeColor = copperHighlight.withAlphaComponent(highlightAlpha)
            highlightNode.lineWidth = traceWidth * 0.4
            highlightNode.lineCap = .square
            highlightNode.lineJoin = .miter
            highlightNode.glowWidth = renderMode == .unlocked ? 3 : 0  // Powered-trace glow for active lanes only
            highlightNode.zPosition = 0.6
            highlightNode.name = "lane_highlight_\(lane.id)"
            pathLayer.addChild(highlightNode)
            if renderMode == .unlocked { glowNodes.append((highlightNode, 3)) }

            // Add animated data flow dash overlay for active lanes
            if renderMode == .unlocked {
                let flowNode = SKShapeNode()
                let dashLengths: [CGFloat] = [6, 14]  // Short dash, long gap = data packet look
                flowNode.path = bezierPath.cgPath.copy(dashingWithPhase: 0, lengths: dashLengths)
                let themeColor = UIColor(hex: lane.themeColorHex) ?? UIColor.yellow
                flowNode.strokeColor = themeColor.withAlphaComponent(0.6)
                flowNode.lineWidth = 3
                flowNode.lineCap = .round
                flowNode.glowWidth = 2  // Small glow for data packets (only 8 lanes)
                flowNode.zPosition = 0.8
                flowNode.name = "lane_flow_\(lane.id)"
                pathLayer.addChild(flowNode)
                glowNodes.append((flowNode, 2))
                // Store ref for animation: (node, original bezier path, dash lengths)
                laneFlowNodes[lane.id] = (flowNode, bezierPath.cgPath, dashLengths)

                // Create power LEDs along the lane for visual feedback
                createLEDsForLane(lane)
            }

            // Add spawn point visual
            renderSpawnPoint(for: lane, renderMode: renderMode)
        }
    }

    /// Render spawn point for a lane based on sector render mode
    /// - `.unlocked`: Pulsing themed circle with direction arrow
    /// - `.unlockable`: Highlighted with theme color, lock icon, cost label
    /// - `.locked`: Dim gray circle with lock icon
    func renderSpawnPoint(for lane: SectorLane, renderMode: SectorRenderMode) {
        let themeColor = UIColor(hex: lane.themeColorHex) ?? UIColor.yellow
        let spawnPos = convertToScene(lane.spawnPoint)

        let container = SKNode()
        container.position = spawnPos
        container.name = "spawn_\(lane.id)"
        container.zPosition = 1.5  // Above path elements, below enemies (effective: 3+1.5=4.5 < enemy 5)

        if renderMode == .unlocked {
            // Active spawn point: Pulsing themed circle
            let outerRing = SKShapeNode(circleOfRadius: 50)
            outerRing.fillColor = themeColor.withAlphaComponent(0.2)
            outerRing.strokeColor = themeColor
            outerRing.lineWidth = 3
            outerRing.glowWidth = 0  // PERF: was 10 (GPU Gaussian blur)
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
        } else if renderMode == .unlockable {
            // Unlockable spawn point: Highlighted with theme color and pulsing animation
            let outerRing = SKShapeNode(circleOfRadius: 55)
            outerRing.fillColor = themeColor.withAlphaComponent(0.15)
            outerRing.strokeColor = themeColor.withAlphaComponent(0.8)
            outerRing.lineWidth = 3
            outerRing.glowWidth = 0  // PERF: was 8 (GPU Gaussian blur)
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
            let hintLabel = SKLabelNode(text: L10n.TD.tapToUnlock)
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
    func createDirectionArrow(from spawnPoint: CGPoint, color: UIColor) -> SKShapeNode {
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
    func createLockIcon(themeColor: UIColor, size: CGFloat) -> SKNode {
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
    /// Performance: Single compound path per route instead of individual dot nodes
    func addMotherboardPathChevrons(for path: EnemyPath, pathWidth: CGFloat) {
        guard path.waypoints.count >= 2 else { return }

        let chevronSpacing: CGFloat = 150
        let glowColor = UIColor(hex: MotherboardColors.activeGlow) ?? UIColor.green
        let compoundPath = CGMutablePath()
        let dotRadius: CGFloat = 4

        for i in 0..<(path.waypoints.count - 1) {
            let start = convertToScene(path.waypoints[i])
            let end = convertToScene(path.waypoints[i + 1])

            let dx = end.x - start.x
            let dy = end.y - start.y
            let segmentLength = sqrt(dx*dx + dy*dy)

            let chevronCount = Int(segmentLength / chevronSpacing)

            for j in 1...max(1, chevronCount) {
                let t = CGFloat(j) / CGFloat(chevronCount + 1)
                let x = start.x + dx * t
                let y = start.y + dy * t
                compoundPath.addEllipse(in: CGRect(x: x - dotRadius, y: y - dotRadius, width: dotRadius * 2, height: dotRadius * 2))
            }
        }

        let batchedDots = SKShapeNode(path: compoundPath)
        batchedDots.fillColor = glowColor.withAlphaComponent(0.8)
        batchedDots.strokeColor = .clear
        batchedDots.zPosition = 0.7  // Above path trace, below enemies (effective: 3+0.7=3.7)
        batchedDots.blendMode = .add
        pathLayer.addChild(batchedDots)

        // Single shared pulse animation for the entire batch
        let fadeOut = SKAction.fadeAlpha(to: 0.3, duration: 0.8)
        let fadeIn = SKAction.fadeAlpha(to: 0.9, duration: 0.8)
        batchedDots.run(SKAction.repeatForever(SKAction.sequence([fadeOut, fadeIn])))
    }

    // MARK: - Path LED System

    /// Create LED nodes along a lane path for visual feedback
    /// LEDs react to enemy proximity and type
    func createLEDsForLane(_ lane: SectorLane) {
        let path = lane.path
        guard path.waypoints.count >= 2 else { return }

        let ledSpacing: CGFloat = 100  // LED every 100 points (reduced from 60 for performance)
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
                let led = SKShapeNode(circleOfRadius: 4.5)
                led.position = CGPoint(x: x, y: y)
                led.fillColor = themeColor.withAlphaComponent(0.5)  // Visible idle state
                led.strokeColor = themeColor.withAlphaComponent(0.7)
                led.lineWidth = 1.5
                led.glowWidth = 0  // Managed dynamically by updateLEDGlow()
                led.zPosition = 0.9  // Above path highlight, below enemies (effective: 3+0.9=3.9 < enemy 5)
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

    /// Initialize LEDs to dim idle state (animation driven by updatePathLEDs shared loop)
    func startLEDIdleAnimation(for laneId: String, themeColor: UIColor) {
        guard let leds = pathLEDNodes[laneId] else { return }
        let dimColor = themeColor.withAlphaComponent(0.35)
        for led in leds {
            led.fillColor = dimColor
        }
    }

    /// Update LED states based on enemy proximity + shared idle animation
    /// Called from update loop (every 3 frames for performance)
    func updatePathLEDs(enemies: [TDEnemy], currentTime: TimeInterval) {
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

        // Zoom-gated glow: enable LED glow only when zoomed in (few on screen)
        let enableGlow = currentScale < 0.6
        let targetGlow: CGFloat = enableGlow ? 2.5 : 0

        // Update each lane's LEDs
        for (laneId, leds) in pathLEDNodes {
            let laneEnemies = enemiesByLane[laneId] ?? []
            let themeColor = laneColorCache[laneId] ?? UIColor.yellow
            let dimColor = themeColor.withAlphaComponent(0.35)
            let brightColor = themeColor.withAlphaComponent(0.7)

            for (ledIndex, led) in leds.enumerated() {
                // Skip LEDs outside visible area
                guard paddedRect.contains(led.position) else { continue }

                // Find nearest enemy to this LED
                let ledPosition = led.position
                var minDistanceSq: CGFloat = .infinity
                var nearestEnemy: TDEnemy?

                for enemy in laneEnemies {
                    let enemyPos = convertToScene(enemy.position)
                    let dx = enemyPos.x - ledPosition.x
                    let dy = enemyPos.y - ledPosition.y
                    let distanceSq = dx * dx + dy * dy

                    if distanceSq < minDistanceSq {
                        minDistanceSq = distanceSq
                        nearestEnemy = enemy
                    }
                }

                // Calculate intensity based on proximity (100pt range)
                let proximityRange: CGFloat = 100
                let minDistance = sqrt(minDistanceSq)
                let intensity = max(0, 1 - minDistance / proximityRange)

                if intensity > 0.1, let enemy = nearestEnemy {
                    // Enemy nearby - show active state with boosted glow
                    let activeColor: UIColor
                    switch enemy.type {
                    case "boss":
                        activeColor = UIColor.white
                    case "fast":
                        activeColor = UIColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 1.0)
                    default:
                        activeColor = themeColor
                    }
                    led.fillColor = activeColor.withAlphaComponent(0.5 + intensity * 0.5)
                    led.strokeColor = activeColor.withAlphaComponent(0.8 + intensity * 0.2)
                    led.glowWidth = enableGlow ? 2.5 + intensity * 3.0 : 0
                } else {
                    // No enemy nearby - shared idle heartbeat via sine wave
                    // 1.2s cycle with per-LED stagger based on index
                    let phase = currentTime * (2.0 * .pi / 1.2) + Double(ledIndex) * 0.3
                    let pulse = CGFloat((sin(phase) + 1.0) * 0.5)  // 0..1
                    led.fillColor = dimColor.interpolate(to: brightColor, progress: pulse)
                    led.strokeColor = themeColor.withAlphaComponent(0.4 + 0.3 * pulse)
                    led.glowWidth = targetGlow * (0.5 + 0.5 * pulse)
                }
            }
        }
    }

    /// Animate dashed flow overlays — advances the dash phase to create flowing data effect
    /// Called from update loop every 6 frames (low frequency is fine for this visual)
    func updateLaneFlowAnimation(deltaTime: TimeInterval) {
        // Advance phase (20 points/second = smooth flow speed)
        laneFlowPhase += CGFloat(deltaTime) * 20.0
        // Wrap phase to prevent floating point growth
        let dashCycleLength: CGFloat = 20  // 6 (dash) + 14 (gap)
        if laneFlowPhase > dashCycleLength {
            laneFlowPhase -= dashCycleLength
        }

        for (_, flowData) in laneFlowNodes {
            let dashLengths = flowData.dashLengths
            flowData.node.path = flowData.path.copy(dashingWithPhase: laneFlowPhase, lengths: dashLengths)
        }
    }

    /// Add direction indicator chevrons along the path
    /// Performance: Single compound path per route instead of individual chevron nodes
    func addPathChevrons(for path: EnemyPath, pathWidth: CGFloat) {
        guard path.waypoints.count >= 2 else { return }

        let chevronSpacing: CGFloat = 100
        let chevronSize: CGFloat = 10
        let compoundPath = CGMutablePath()

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

                // Add rotated chevron shape to compound path
                let cosA = cos(angle)
                let sinA = sin(angle)
                let p1 = CGPoint(x: x + (-chevronSize * cosA - chevronSize * 0.6 * sinA),
                                 y: y + (-chevronSize * sinA + chevronSize * 0.6 * cosA))
                let p2 = CGPoint(x: x, y: y)
                let p3 = CGPoint(x: x + (-chevronSize * cosA + chevronSize * 0.6 * sinA),
                                 y: y + (-chevronSize * sinA - chevronSize * 0.6 * cosA))
                compoundPath.move(to: p1)
                compoundPath.addLine(to: p2)
                compoundPath.addLine(to: p3)
            }
        }

        let batchedChevrons = SKShapeNode(path: compoundPath)
        batchedChevrons.strokeColor = DesignColors.pathBorderUI.withAlphaComponent(0.6)
        batchedChevrons.fillColor = .clear
        batchedChevrons.lineWidth = 3
        batchedChevrons.lineCap = .round
        batchedChevrons.alpha = 0.5
        batchedChevrons.zPosition = 0.7  // Above path trace, below enemies (effective: 3+0.7=3.7)
        pathLayer.addChild(batchedChevrons)

        // Single shared pulse animation
        let fadeOut = SKAction.fadeAlpha(to: 0.2, duration: 1.0)
        let fadeIn = SKAction.fadeAlpha(to: 0.6, duration: 1.0)
        batchedChevrons.run(SKAction.repeatForever(SKAction.sequence([fadeOut, fadeIn])))
    }

}
