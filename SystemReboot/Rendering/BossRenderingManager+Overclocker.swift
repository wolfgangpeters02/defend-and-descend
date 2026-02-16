import SpriteKit

// MARK: - Overclocker Rendering

extension BossRenderingManager {

    func renderOverclockerMechanics(bossState: OverclockerAI.OverclockerState, gameState: GameState) {
        guard let scene = scene else { return }
        guard let boss = cachedBossEnemy else { return }
        let bossPos = CGPoint(x: boss.x, y: boss.y)
        let arenaH = gameState.arena.height

        // Phase 1: Render rotating blades
        if bossState.phase == 1 {
            let bladeCount = BalanceConfig.Overclocker.bladeCount
            let bladeRadius = BalanceConfig.Overclocker.bladeOrbitRadius

            for i in 0..<bladeCount {
                let nodeKey = "overclocker_blade_\(i)"
                let angleOffset = CGFloat(i) * (2 * .pi / CGFloat(bladeCount))
                let currentAngle = bossState.bladeAngle + angleOffset

                let bladeNode: SKShapeNode
                if let existing = bossMechanicNodes[nodeKey] as? SKShapeNode {
                    bladeNode = existing
                } else {
                    let path = CGMutablePath()
                    path.move(to: .zero)
                    path.addLine(to: CGPoint(x: bladeRadius, y: 0))
                    bladeNode = SKShapeNode(path: path)
                    bladeNode.strokeColor = SKColor.orange
                    bladeNode.lineWidth = BalanceConfig.Overclocker.bladeWidth
                    bladeNode.lineCap = .round
                    bladeNode.zPosition = 100
                    scene.addChild(bladeNode)
                    bossMechanicNodes[nodeKey] = bladeNode
                    fadeInMechanicNode(bladeNode)
                }

                bladeNode.position = CGPoint(x: bossPos.x, y: arenaH - bossPos.y)
                bladeNode.zRotation = -currentAngle
            }
        } else {
            for i in 0..<BalanceConfig.Overclocker.bladeCount {
                fadeOutAndRemoveBossNode(key: "overclocker_blade_\(i)")
            }
        }

        // Phase 2: Render lava tiles
        if bossState.phase == 2 {
            let arenaRect = bossState.arenaRect
            let gridSize = CGFloat(BalanceConfig.Overclocker.tileGridSize)
            let tileW = arenaRect.width / gridSize
            let tileH = arenaRect.height / gridSize

            for i in 0..<BalanceConfig.Overclocker.tileCount {
                let nodeKey = "overclocker_tile_\(i)"
                let col = i % BalanceConfig.Overclocker.tileGridSize
                let row = i / BalanceConfig.Overclocker.tileGridSize

                let tileNode: SKShapeNode
                let isNew: Bool
                if let existing = bossMechanicNodes[nodeKey] as? SKShapeNode {
                    tileNode = existing
                    isNew = false
                } else {
                    tileNode = SKShapeNode(rectOf: CGSize(width: tileW - 4, height: tileH - 4), cornerRadius: 4)
                    tileNode.zPosition = 1
                    tileNode.lineWidth = 2
                    scene.addChild(tileNode)
                    bossMechanicNodes[nodeKey] = tileNode
                    fadeInMechanicNode(tileNode)
                    isNew = true
                }

                let tileX = arenaRect.minX + CGFloat(col) * tileW + tileW / 2
                let tileY = arenaRect.minY + CGFloat(row) * tileH + tileH / 2
                tileNode.position = CGPoint(x: tileX, y: arenaH - tileY)

                let currentState = bossState.tileStates[i]
                let previousState = tileStateCache[i]
                let stateChanged = !isNew && previousState != nil && previousState != currentState
                tileStateCache[i] = currentState

                switch currentState {
                case .normal:
                    tileNode.fillColor = SKColor.darkGray.withAlphaComponent(0.3)
                    tileNode.strokeColor = SKColor.gray
                case .warning:
                    tileNode.fillColor = SKColor.orange.withAlphaComponent(0.5)
                    tileNode.strokeColor = SKColor.yellow
                case .lava:
                    tileNode.fillColor = SKColor.red.withAlphaComponent(0.7)
                    tileNode.strokeColor = SKColor.orange
                case .safe:
                    tileNode.fillColor = SKColor.cyan.withAlphaComponent(0.4)
                    tileNode.strokeColor = SKColor.blue
                }

                // 8e: Scale pulse on state transition
                if stateChanged {
                    let pulse = SKAction.sequence([
                        SKAction.scale(to: 1.05, duration: 0.1),
                        SKAction.scale(to: 1.0, duration: 0.1)
                    ])
                    pulse.timingMode = .easeInEaseOut
                    tileNode.run(pulse, withKey: "tileTransition")

                    // Extra red flash for warning → lava transition
                    if previousState == .warning && currentState == .lava {
                        tileNode.run(SKAction.sequence([
                            SKAction.run { tileNode.fillColor = SKColor.white.withAlphaComponent(0.8) },
                            SKAction.wait(forDuration: 0.08),
                            SKAction.run { tileNode.fillColor = SKColor.red.withAlphaComponent(0.7) }
                        ]), withKey: "lavaFlash")
                    }
                }
            }
        } else {
            for i in 0..<BalanceConfig.Overclocker.tileCount {
                fadeOutAndRemoveBossNode(key: "overclocker_tile_\(i)")
                tileStateCache.removeValue(forKey: i)
            }
        }

        // Phase 3 & 4: Render steam trail
        if bossState.phase >= 3 {
            var activeSteamIds = Set<String>()
            for segment in bossState.steamTrail {
                activeSteamIds.insert(segment.id)
                let nodeKey = "overclocker_steam_\(segment.id)"

                let steamNode: SKShapeNode
                if let existing = bossMechanicNodes[nodeKey] as? SKShapeNode {
                    steamNode = existing
                } else {
                    steamNode = SKShapeNode(circleOfRadius: BalanceConfig.Overclocker.steamRadius)
                    steamNode.fillColor = SKColor.white.withAlphaComponent(0.3)
                    steamNode.strokeColor = SKColor.gray.withAlphaComponent(0.5)
                    steamNode.zPosition = 50
                    scene.addChild(steamNode)
                    bossMechanicNodes[nodeKey] = steamNode
                    fadeInMechanicNode(steamNode, targetAlpha: 1.0, duration: 0.1)
                }

                steamNode.position = CGPoint(x: segment.x, y: arenaH - segment.y)
            }

            // Clean up old steam segments (8b: fade-out)
            let steamKeysToRemove = bossMechanicNodes.keys.filter { $0.hasPrefix("overclocker_steam_") && !activeSteamIds.contains(String($0.dropFirst("overclocker_steam_".count))) }
            for key in steamKeysToRemove {
                fadeOutAndRemoveBossNode(key: key)
            }
        }

        // Phase 4: Render shredder ring
        if bossState.phase == 4 {
            let nodeKey = "overclocker_shredder"
            let shredderNode: SKShapeNode
            if let existing = bossMechanicNodes[nodeKey] as? SKShapeNode {
                shredderNode = existing
            } else {
                shredderNode = SKShapeNode(circleOfRadius: BalanceConfig.Overclocker.shredderRadius)
                shredderNode.fillColor = SKColor.red.withAlphaComponent(0.2)
                shredderNode.strokeColor = bossState.isSuctionActive ? SKColor.red : SKColor.orange
                shredderNode.lineWidth = 4
                shredderNode.zPosition = 99
                scene.addChild(shredderNode)
                bossMechanicNodes[nodeKey] = shredderNode
                fadeInMechanicNode(shredderNode)
            }

            shredderNode.position = CGPoint(x: bossPos.x, y: arenaH - bossPos.y)
            shredderNode.strokeColor = bossState.isSuctionActive ? SKColor.red : SKColor.orange
        } else {
            fadeOutAndRemoveBossNode(key: "overclocker_shredder")
        }

        renderPhaseIndicator(phase: bossState.phase, bossType: "overclocker", gameState: gameState)
        updateOverclockerBodyVisuals(phase: bossState.phase, boss: boss, gameState: gameState, isSuctionActive: bossState.isSuctionActive)
    }

    // MARK: - Overclocker Phase Body Visuals

    /// Update Overclocker body composition based on current phase.
    /// Warning ring, heat gauge, core clock speed, and thermal vents escalate per phase.
    func updateOverclockerBodyVisuals(phase: Int, boss: Enemy, gameState: GameState, isSuctionActive: Bool) {
        // Skip redundant updates (except phase 4 where suction state changes visuals)
        guard phase != cachedOverclockerPhase || phase == 4 else { return }
        cachedOverclockerPhase = phase

        // Find boss body node (lazy cache)
        if cachedBossBodyNode == nil || cachedBossBodyNode?.parent == nil {
            let bossScenePos = CGPoint(x: boss.x, y: gameState.arena.height - boss.y)
            cachedBossBodyNode = enemyLayer?.children.first(where: {
                abs($0.position.x - bossScenePos.x) < 5 && abs($0.position.y - bossScenePos.y) < 5
            })
        }
        guard let bossNode = cachedBossBodyNode else { return }

        let heatOrange = UIColor(hex: "ff4400") ?? UIColor.orange

        // Warning ring — alpha and scale escalate per phase
        if let ring = bossNode.childNode(withName: "warningRing") as? SKShapeNode {
            switch phase {
            case 1:
                ring.strokeColor = heatOrange.withAlphaComponent(0.35)
                ring.setScale(1.0)
            case 2:
                ring.strokeColor = heatOrange.withAlphaComponent(0.5)
                ring.setScale(1.05)
            case 3:
                ring.strokeColor = UIColor.red.withAlphaComponent(0.7)
                ring.setScale(1.1)
            case 4:
                ring.strokeColor = (isSuctionActive ? UIColor.red : heatOrange).withAlphaComponent(1.0)
                ring.setScale(1.15)
            default: break
            }
        }

        // Heat gauge — arc length, color, and lineWidth escalate per phase
        if let gauge = bossNode.childNode(withName: "heatGauge") as? SKShapeNode {
            let bossSize = boss.size ?? 60
            let gaugeRadius = bossSize * 1.15

            // Arc grows per phase: ~180° → ~225° → ~270° → ~315°
            let endAngle: CGFloat
            switch phase {
            case 1:
                gauge.strokeColor = heatOrange.withAlphaComponent(0.6)
                gauge.lineWidth = 3
                endAngle = -.pi * 0.25   // 180°
            case 2:
                gauge.strokeColor = heatOrange.withAlphaComponent(0.8)
                gauge.lineWidth = 4
                endAngle = -.pi * 0.5    // 225°
            case 3:
                gauge.strokeColor = UIColor.red.withAlphaComponent(0.8)
                gauge.lineWidth = 5
                endAngle = -.pi * 0.75   // 270°
            case 4:
                gauge.strokeColor = UIColor.red
                gauge.lineWidth = 6
                endAngle = -.pi          // 315°
            default:
                endAngle = -.pi * 0.25
            }

            let gaugePath = CGMutablePath()
            gaugePath.addArc(center: .zero, radius: gaugeRadius,
                             startAngle: .pi * 0.75, endAngle: endAngle,
                             clockwise: true)
            gauge.path = gaugePath
        }

        // Core clock — spin speed increases per phase
        if let clock = bossNode.childNode(withName: "coreClock") as? SKShapeNode {
            clock.removeAction(forKey: "clockSpin")
            let spinDuration: TimeInterval
            switch phase {
            case 1: spinDuration = 4.0
            case 2: spinDuration = 3.0
            case 3: spinDuration = 2.0
            case 4: spinDuration = 1.0
            default: spinDuration = 4.0
            }
            let spin = SKAction.rotate(byAngle: .pi * 2, duration: spinDuration)
            clock.run(SKAction.repeatForever(spin), withKey: "clockSpin")
        }

        // Thermal vents — glow brightens per phase
        if let vents = bossNode.childNode(withName: "thermalVents") as? SKShapeNode {
            switch phase {
            case 1: vents.fillColor = heatOrange.withAlphaComponent(0.4)
            case 2: vents.fillColor = heatOrange.withAlphaComponent(0.5)
            case 3: vents.fillColor = UIColor.red.withAlphaComponent(0.7)
            case 4: vents.fillColor = UIColor.red.withAlphaComponent(0.9)
            default: break
            }
        }

        // Body octagon — stroke shifts to red in later phases; phase 4 jitter
        if let body = bossNode.childNode(withName: "body") as? SKShapeNode {
            switch phase {
            case 1, 2:
                body.strokeColor = heatOrange
                body.removeAction(forKey: "phaseJitter")
            case 3:
                body.strokeColor = UIColor.red
                body.removeAction(forKey: "phaseJitter")
            case 4:
                body.strokeColor = UIColor.red
                if body.action(forKey: "phaseJitter") == nil {
                    let jitter = SKAction.repeatForever(SKAction.sequence([
                        SKAction.moveBy(x: CGFloat.random(in: -2...2),
                                        y: CGFloat.random(in: -2...2), duration: 0.05),
                        SKAction.move(to: .zero, duration: 0.05)
                    ]))
                    body.run(jitter, withKey: "phaseJitter")
                }
            default: break
            }
        }
    }
}
