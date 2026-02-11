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
    func renderSpawnPoint(for lane: SectorLane, isUnlocked: Bool, canUnlock: Bool = false) {
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
    func addMotherboardPathChevrons(for path: EnemyPath, pathWidth: CGFloat) {
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
    func createLEDsForLane(_ lane: SectorLane) {
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
    func startLEDIdleAnimation(for laneId: String, themeColor: UIColor) {
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
    func updatePathLEDs(enemies: [TDEnemy]) {
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
    func startLEDIdleAnimationForSingleLED(_ led: SKShapeNode, themeColor: UIColor) {
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
    func addPathChevrons(for path: EnemyPath, pathWidth: CGFloat) {
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
    func createChevron() -> SKShapeNode {
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

}
