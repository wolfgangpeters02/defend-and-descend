import SpriteKit

// MARK: - Void Harbinger Rendering

extension BossRenderingManager {

    func renderVoidHarbingerMechanics(bossState: VoidHarbingerAI.VoidHarbingerState, gameState: GameState) {
        guard let scene = scene else { return }

        // Render void zones (with state caching)
        var activeZoneIds = Set<String>()
        for zone in bossState.voidZones {
            activeZoneIds.insert(zone.id)
            let nodeKey = "voidharbinger_zone_\(zone.id)"

            if let node = bossMechanicNodes[nodeKey] as? SKShapeNode {
                let cachedIsActive = zonePhaseCache[zone.id]
                if cachedIsActive != zone.isActive {
                    zonePhaseCache[zone.id] = zone.isActive

                    if zone.isActive {
                        node.fillColor = DesignColors.secondaryUI.withAlphaComponent(0.3)
                        node.strokeColor = DesignColors.secondaryUI.withAlphaComponent(0.8)
                        node.removeAction(forKey: "pulse")
                    } else {
                        node.fillColor = DesignColors.warningUI.withAlphaComponent(0.1)
                        node.strokeColor = DesignColors.warningUI
                    }
                }
            } else {
                let zoneNode = SKShapeNode(circleOfRadius: zone.radius)
                zoneNode.position = CGPoint(x: zone.x, y: gameState.arena.height - zone.y)
                zoneNode.zPosition = 5
                zoneNode.lineWidth = 2
                zoneNode.name = nodeKey

                if zone.isActive {
                    zoneNode.fillColor = DesignColors.secondaryUI.withAlphaComponent(0.3)
                    zoneNode.strokeColor = DesignColors.secondaryUI.withAlphaComponent(0.8)
                    zoneNode.glowWidth = 2
                } else {
                    zoneNode.fillColor = DesignColors.warningUI.withAlphaComponent(0.1)
                    zoneNode.strokeColor = DesignColors.warningUI
                    zoneNode.run(SKAction.repeatForever(voidZonePulseAction), withKey: "pulse")
                }

                scene.addChild(zoneNode)
                bossMechanicNodes[nodeKey] = zoneNode
                fadeInMechanicNode(zoneNode)
            }
        }

        // Remove zones that no longer exist (8b: fade-out)
        let zonePrefix = "voidharbinger_zone_"
        for key in findKeysToRemove(prefix: zonePrefix, activeIds: activeZoneIds) {
            let zoneId = String(key.dropFirst(zonePrefix.count))
            zonePhaseCache.removeValue(forKey: zoneId)
            fadeOutAndRemoveBossNode(key: key)
        }

        // Render pylons (Phase 2)
        var activePylonIds = Set<String>()
        for pylon in bossState.pylons where !pylon.isDestroyed {
            activePylonIds.insert(pylon.id)
            let nodeKey = "voidharbinger_pylon_\(pylon.id)"

            if let container = bossMechanicNodes[nodeKey] {
                if let healthBar = container.childNode(withName: "healthFill") as? SKShapeNode {
                    let healthPercent = pylon.health / pylon.maxHealth
                    healthBar.xScale = max(0.01, healthPercent)
                }
            } else {
                let container = SKNode()
                container.position = CGPoint(x: pylon.x, y: gameState.arena.height - pylon.y)
                container.zPosition = 50
                container.name = nodeKey

                let pylonBody = SKShapeNode(rectOf: CGSize(width: 40, height: 60), cornerRadius: 5)
                pylonBody.fillColor = DesignColors.secondaryUI.withAlphaComponent(0.8)
                pylonBody.strokeColor = DesignColors.secondaryUI
                pylonBody.lineWidth = 2
                pylonBody.glowWidth = 0
                container.addChild(pylonBody)

                let crystal = SKShapeNode(circleOfRadius: 12)
                crystal.fillColor = DesignColors.secondaryUI
                crystal.strokeColor = DesignColors.primaryUI.withAlphaComponent(0.6)
                crystal.position = CGPoint(x: 0, y: 40)
                crystal.glowWidth = 0
                container.addChild(crystal)

                let healthBg = SKShapeNode(rectOf: CGSize(width: 50, height: 6))
                healthBg.fillColor = DesignColors.surfaceUI
                healthBg.strokeColor = DesignColors.mutedUI
                healthBg.position = CGPoint(x: 0, y: -45)
                container.addChild(healthBg)

                let healthFill = SKShapeNode(rect: CGRect(x: -25, y: -3, width: 50, height: 6))
                healthFill.fillColor = DesignColors.successUI
                healthFill.strokeColor = SKColor.clear
                healthFill.position = CGPoint(x: 0, y: -45)
                healthFill.name = "healthFill"
                container.addChild(healthFill)

                crystal.run(SKAction.repeatForever(pylonCrystalPulseAction), withKey: "pulse")

                scene.addChild(container)
                bossMechanicNodes[nodeKey] = container
                fadeInMechanicNode(container)
            }
        }

        // Remove destroyed pylons (8b: fade-out, 8c: destruction burst)
        for key in findKeysToRemove(prefix: "voidharbinger_pylon_", activeIds: activePylonIds) {
            if let node = bossMechanicNodes[key] {
                // 8c: Pylon destruction burst — purple particles + shake + SCT
                spawnVisualBurst(at: node.position, color: DesignColors.secondaryUI, count: 15)
                if let gameScene = scene as? GameScene {
                    gameScene.shakeScreen(intensity: 4, duration: 0.2)
                }
                let sctPos = CGPoint(x: node.position.x, y: node.position.y + 40)
                scene.combatText.show(L10n.Boss.shieldDown, type: .execute, at: sctPos, config: .dramatic)
            }
            fadeOutAndRemoveBossNode(key: key)
        }

        // Render shield around boss during Phase 2
        let shieldKey = "voidharbinger_shield"
        let bossEnemy = cachedBossEnemy
        if bossState.phase == 2 && bossState.isInvulnerable, let boss = bossEnemy {
            let bossScenePos = CGPoint(x: boss.x, y: gameState.arena.height - boss.y)

            if let shieldNode = bossMechanicNodes[shieldKey] as? SKShapeNode {
                shieldNode.position = bossScenePos
            } else {
                let shieldRadius: CGFloat = 80
                let hexPath = CGMutablePath()
                for i in 0..<6 {
                    let angle = CGFloat(i) * .pi / 3 - .pi / 6
                    let point = CGPoint(
                        x: cos(angle) * shieldRadius,
                        y: sin(angle) * shieldRadius
                    )
                    if i == 0 {
                        hexPath.move(to: point)
                    } else {
                        hexPath.addLine(to: point)
                    }
                }
                hexPath.closeSubpath()

                let shieldNode = SKShapeNode(path: hexPath)
                shieldNode.fillColor = DesignColors.secondaryUI.withAlphaComponent(0.15)
                shieldNode.strokeColor = DesignColors.secondaryUI.withAlphaComponent(0.8)
                shieldNode.lineWidth = 3
                shieldNode.glowWidth = 0
                shieldNode.position = bossScenePos
                shieldNode.zPosition = 45
                shieldNode.name = shieldKey

                let shieldUp = SKAction.group([
                    SKAction.scale(to: 1.08, duration: 0.8),
                    SKAction.fadeAlpha(to: 0.7, duration: 0.8)
                ])
                shieldUp.timingMode = .easeInEaseOut
                let shieldDown = SKAction.group([
                    SKAction.scale(to: 1.0, duration: 0.8),
                    SKAction.fadeAlpha(to: 1.0, duration: 0.8)
                ])
                shieldDown.timingMode = .easeInEaseOut
                let shieldPulse = SKAction.sequence([shieldUp, shieldDown])
                shieldNode.run(SKAction.repeatForever(shieldPulse), withKey: "pulse")

                let rotation = SKAction.rotate(byAngle: .pi * 2, duration: 12)
                shieldNode.run(SKAction.repeatForever(rotation), withKey: "rotate")

                scene.addChild(shieldNode)
                bossMechanicNodes[shieldKey] = shieldNode
                fadeInMechanicNode(shieldNode)
            }
        } else {
            fadeOutAndRemoveBossNode(key: shieldKey)
        }

        // Render energy lines from pylons to boss (Phase 2)
        var activeLineIds = Set<String>()
        if bossState.phase == 2, let boss = bossEnemy {
            let bossScenePos = CGPoint(x: boss.x, y: gameState.arena.height - boss.y)

            for pylon in bossState.pylons where !pylon.isDestroyed {
                activeLineIds.insert(pylon.id)
                let lineKey = "voidharbinger_pylonline_\(pylon.id)"
                let pylonScenePos = CGPoint(x: pylon.x, y: gameState.arena.height - pylon.y)

                if let lineNode = bossMechanicNodes[lineKey] as? SKShapeNode {
                    let linePath = CGMutablePath()
                    linePath.move(to: pylonScenePos)
                    linePath.addLine(to: bossScenePos)
                    lineNode.path = linePath
                } else {
                    let linePath = CGMutablePath()
                    linePath.move(to: pylonScenePos)
                    linePath.addLine(to: bossScenePos)

                    let lineNode = SKShapeNode(path: linePath)
                    lineNode.strokeColor = DesignColors.secondaryUI.withAlphaComponent(0.6)
                    lineNode.lineWidth = 2
                    lineNode.glowWidth = 2
                    lineNode.blendMode = .add
                    lineNode.zPosition = 40
                    lineNode.name = lineKey

                    let lineDown = SKAction.fadeAlpha(to: 0.4, duration: 0.3)
                    lineDown.timingMode = .easeInEaseOut
                    let lineUp = SKAction.fadeAlpha(to: 1.0, duration: 0.3)
                    lineUp.timingMode = .easeInEaseOut
                    let linePulse = SKAction.sequence([lineDown, lineUp])
                    lineNode.run(SKAction.repeatForever(linePulse), withKey: "pulse")

                    scene.addChild(lineNode)
                    bossMechanicNodes[lineKey] = lineNode
                    fadeInMechanicNode(lineNode)
                }
            }
        }

        // Remove lines for destroyed pylons or when not in Phase 2 (8b/8c: flash + fade-out)
        for key in findKeysToRemove(prefix: "voidharbinger_pylonline_", activeIds: activeLineIds) {
            // 8c: Flash white briefly before fading to simulate line snapping
            if let lineNode = bossMechanicNodes[key] as? SKShapeNode {
                lineNode.strokeColor = SKColor.white
                lineNode.glowWidth = 4
            }
            fadeOutAndRemoveBossNode(key: key)
        }

        // Render pylon direction indicators (Phase 2 only)
        if bossState.phase == 2 && !bossState.pylons.filter({ !$0.isDestroyed }).isEmpty {
            let hintKey = "voidharbinger_pylon_hint"
            if bossMechanicNodes[hintKey] == nil {
                let hintLabel = SKLabelNode(text: L10n.Boss.destroyPylons)
                hintLabel.fontName = "Menlo-Bold"
                hintLabel.fontSize = 20
                hintLabel.fontColor = DesignColors.warningUI
                hintLabel.position = CGPoint(x: gameState.arena.width / 2, y: gameState.arena.height - 90)
                hintLabel.zPosition = 200
                hintLabel.name = hintKey

                let hintDown = SKAction.fadeAlpha(to: 0.5, duration: 0.5)
                hintDown.timingMode = .easeInEaseOut
                let hintUp = SKAction.fadeAlpha(to: 1.0, duration: 0.5)
                hintUp.timingMode = .easeInEaseOut
                let pulse = SKAction.sequence([hintDown, hintUp])
                hintLabel.run(SKAction.repeatForever(pulse), withKey: "pulse")

                scene.addChild(hintLabel)
                bossMechanicNodes[hintKey] = hintLabel
            }

            let playerScenePos = CGPoint(x: gameState.player.x, y: gameState.arena.height - gameState.player.y)

            for pylon in bossState.pylons where !pylon.isDestroyed {
                let arrowKey = "voidharbinger_pylon_arrow_\(pylon.id)"
                let pylonScenePos = CGPoint(x: pylon.x, y: gameState.arena.height - pylon.y)

                let dx = pylonScenePos.x - playerScenePos.x
                let dy = pylonScenePos.y - playerScenePos.y
                let distance = sqrt(dx * dx + dy * dy)

                if distance > 200 {
                    let angle = atan2(dy, dx)

                    let arrowDistance: CGFloat = 120
                    let arrowX = playerScenePos.x + cos(angle) * arrowDistance
                    let arrowY = playerScenePos.y + sin(angle) * arrowDistance

                    let clampedX = max(50, min(gameState.arena.width - 50, arrowX))
                    let clampedY = max(50, min(gameState.arena.height - 50, arrowY))

                    if let arrow = bossMechanicNodes[arrowKey] as? SKShapeNode {
                        arrow.position = CGPoint(x: clampedX, y: clampedY)
                        arrow.zRotation = angle
                    } else {
                        let arrowPath = CGMutablePath()
                        arrowPath.move(to: CGPoint(x: -15, y: -8))
                        arrowPath.addLine(to: CGPoint(x: 15, y: 0))
                        arrowPath.addLine(to: CGPoint(x: -15, y: 8))
                        arrowPath.addLine(to: CGPoint(x: -10, y: 0))
                        arrowPath.closeSubpath()

                        let arrowNode = SKShapeNode(path: arrowPath)
                        arrowNode.fillColor = DesignColors.warningUI
                        arrowNode.strokeColor = DesignColors.warningUI.withAlphaComponent(0.8)
                        arrowNode.lineWidth = 2
                        arrowNode.glowWidth = 0
                        arrowNode.position = CGPoint(x: clampedX, y: clampedY)
                        arrowNode.zRotation = angle
                        arrowNode.zPosition = 150
                        arrowNode.name = arrowKey

                        let arrowUp = SKAction.scale(to: 1.2, duration: 0.3)
                        arrowUp.timingMode = .easeInEaseOut
                        let arrowDown = SKAction.scale(to: 1.0, duration: 0.3)
                        arrowDown.timingMode = .easeInEaseOut
                        let arrowPulse = SKAction.sequence([arrowUp, arrowDown])
                        arrowNode.run(SKAction.repeatForever(arrowPulse), withKey: "pulse")

                        scene.addChild(arrowNode)
                        bossMechanicNodes[arrowKey] = arrowNode
                        fadeInMechanicNode(arrowNode)
                    }
                } else {
                    fadeOutAndRemoveBossNode(key: arrowKey)
                }
            }
        } else {
            fadeOutAndRemoveBossNode(key: "voidharbinger_pylon_hint")

            let arrowPrefix = "voidharbinger_pylon_arrow_"
            let arrowKeys = bossMechanicNodes.keys.filter { $0.hasPrefix(arrowPrefix) }
            for key in arrowKeys {
                fadeOutAndRemoveBossNode(key: key)
            }
        }

        // Render void rifts (Phase 3+)
        var activeRiftIds = Set<String>()
        for rift in bossState.voidRifts {
            activeRiftIds.insert(rift.id)
            let nodeKey = "voidharbinger_rift_\(rift.id)"

            let centerSceneX = bossState.arenaCenter.x
            let centerSceneY = gameState.arena.height - bossState.arenaCenter.y

            if let node = bossMechanicNodes[nodeKey] as? SKShapeNode {
                node.position = CGPoint(x: centerSceneX, y: centerSceneY)
                node.zRotation = rift.angle * .pi / 180
            } else {
                // 11f: Cached rift path — all rifts share the same length
                let riftNode = SKShapeNode(path: Self.cachedRiftPath)
                riftNode.strokeColor = DesignColors.secondaryUI
                riftNode.lineWidth = rift.width
                riftNode.glowWidth = 0
                riftNode.alpha = 0.8
                riftNode.zPosition = 10
                riftNode.name = nodeKey
                riftNode.position = CGPoint(x: centerSceneX, y: centerSceneY)
                riftNode.zRotation = rift.angle * .pi / 180

                // 11a: Alpha oscillation + line width pulse
                riftNode.run(SKAction.repeatForever(riftPulseAction), withKey: "riftPulse")

                scene.addChild(riftNode)
                bossMechanicNodes[nodeKey] = riftNode
                fadeInMechanicNode(riftNode, targetAlpha: 0.8)
            }
        }

        // Remove rifts that no longer exist (8b: fade-out)
        for key in findKeysToRemove(prefix: "voidharbinger_rift_", activeIds: activeRiftIds) {
            fadeOutAndRemoveBossNode(key: key)
        }

        // Render gravity wells (Phase 3+)
        var activeWellIds = Set<String>()
        for well in bossState.gravityWells {
            activeWellIds.insert(well.id)
            let nodeKey = "voidharbinger_well_\(well.id)"

            if bossMechanicNodes[nodeKey] == nil {
                let wellNode = SKShapeNode(circleOfRadius: well.pullRadius)
                wellNode.fillColor = SKColor.black.withAlphaComponent(0.25)
                wellNode.strokeColor = DesignColors.secondaryUI.withAlphaComponent(0.7)
                wellNode.lineWidth = 2
                wellNode.position = CGPoint(x: well.x, y: gameState.arena.height - well.y)
                wellNode.zPosition = 4
                wellNode.name = nodeKey

                let innerCircle = SKShapeNode(circleOfRadius: 30)
                innerCircle.fillColor = SKColor.black.withAlphaComponent(0.7)
                innerCircle.strokeColor = DesignColors.secondaryUI
                innerCircle.glowWidth = 4
                wellNode.addChild(innerCircle)

                wellNode.run(SKAction.repeatForever(gravityWellRotateAction), withKey: "rotate")

                // 11b: Spawn inward-pulling particles on a cycle
                let pullRadius = well.pullRadius
                let spawnPull = SKAction.run { [weak wellNode] in
                    guard let wellNode = wellNode, wellNode.parent != nil else { return }
                    for _ in 0..<4 {
                        let angle = CGFloat.random(in: 0...(2 * .pi))
                        let dot = SKShapeNode(circleOfRadius: 1.5)
                        dot.fillColor = DesignColors.secondaryUI.withAlphaComponent(0.6)
                        dot.strokeColor = .clear
                        dot.position = CGPoint(x: cos(angle) * pullRadius, y: sin(angle) * pullRadius)
                        dot.zPosition = 1
                        wellNode.addChild(dot)
                        dot.run(SKAction.sequence([
                            SKAction.group([
                                SKAction.move(to: .zero, duration: 0.5),
                                SKAction.fadeOut(withDuration: 0.5),
                                SKAction.scale(to: 0.3, duration: 0.5)
                            ]),
                            SKAction.removeFromParent()
                        ]))
                    }
                }
                let pullCycle = SKAction.sequence([spawnPull, SKAction.wait(forDuration: 0.5)])
                wellNode.run(SKAction.repeatForever(pullCycle), withKey: "pullParticles")

                scene.addChild(wellNode)
                bossMechanicNodes[nodeKey] = wellNode
                fadeInMechanicNode(wellNode)
            }
        }

        // Remove wells that no longer exist (8b: fade-out)
        for key in findKeysToRemove(prefix: "voidharbinger_well_", activeIds: activeWellIds) {
            fadeOutAndRemoveBossNode(key: key)
        }

        // Render shrinking arena boundary (Phase 4)
        if bossState.phase == 4 {
            let arenaKey = "voidharbinger_arena"
            let centerSceneY = gameState.arena.height - bossState.arenaCenter.y

            let initialRadius = BalanceConfig.VoidHarbinger.arenaStartRadius
            let currentScale = bossState.arenaRadius / initialRadius

            if let node = bossMechanicNodes[arenaKey] as? SKShapeNode {
                node.xScale = currentScale
                node.yScale = currentScale
            } else {
                let arenaNode = SKShapeNode(circleOfRadius: initialRadius)
                arenaNode.fillColor = SKColor.clear
                arenaNode.strokeColor = DesignColors.dangerUI
                arenaNode.lineWidth = 4
                arenaNode.glowWidth = 0
                arenaNode.zPosition = 3
                arenaNode.name = arenaKey
                arenaNode.position = CGPoint(x: bossState.arenaCenter.x, y: centerSceneY)
                arenaNode.xScale = currentScale
                arenaNode.yScale = currentScale

                arenaNode.run(SKAction.repeatForever(arenaBoundaryPulseAction), withKey: "pulse")

                scene.addChild(arenaNode)
                bossMechanicNodes[arenaKey] = arenaNode
                fadeInMechanicNode(arenaNode)
            }
        } else {
            fadeOutAndRemoveBossNode(key: "voidharbinger_arena")
        }

        renderPhaseIndicator(phase: bossState.phase, bossType: "voidharbinger", isInvulnerable: bossState.isInvulnerable, gameState: gameState)

        // Phase-specific body visual escalation (Phase 5A)
        updateVoidHarbingerBodyVisuals(phase: bossState.phase, gameState: gameState)
    }

    // MARK: - Void Harbinger Phase Body Visuals

    /// Update Void Harbinger body based on current phase.
    /// Fragment speed, aura thickness, body cracks escalate per phase.
    func updateVoidHarbingerBodyVisuals(phase: Int, gameState: GameState) {
        guard phase != cachedVoidHarbingerPhase else { return }
        cachedVoidHarbingerPhase = phase

        // Find boss body node
        if cachedBossBodyNode == nil || cachedBossBodyNode?.parent == nil {
            guard let boss = cachedBossEnemy else { return }
            let bossScenePos = CGPoint(x: boss.x, y: gameState.arena.height - boss.y)
            cachedBossBodyNode = enemyLayer?.children.first(where: {
                abs($0.position.x - bossScenePos.x) < 5 && abs($0.position.y - bossScenePos.y) < 5
            })
        }
        guard let bossNode = cachedBossBodyNode else { return }

        // Phase 2+: fragment orbit speeds up
        if phase >= 2 {
            bossNode.removeAction(forKey: "fragmentRotate")
            let orbitDuration: TimeInterval = phase >= 3 ? 1.5 : 2.0
            let fragmentRotate = SKAction.rotate(byAngle: .pi * 2, duration: orbitDuration)
            bossNode.run(SKAction.repeatForever(fragmentRotate), withKey: "fragmentRotate")
        }

        // Phase 2+: aura stroke thickens
        if let aura = bossNode.childNode(withName: "aura") as? SKShapeNode {
            switch phase {
            case 2: aura.lineWidth = 4
            case 3: aura.lineWidth = 5
            case 4:
                aura.lineWidth = 6
                // Phase 4: aura expands
                aura.setScale(1.2)
            default: break
            }
        }

        // Phase 3+: body crack lines (lazily created)
        if phase >= 3 {
            let crackKey = "voidCracks"
            if bossNode.childNode(withName: crackKey) == nil {
                let bossSize = (cachedBossEnemy?.size ?? 60)
                let crackPath = CGMutablePath()
                // 3-4 crack lines radiating from center
                for i in 0..<4 {
                    let angle = CGFloat(i) * (.pi / 2) + 0.3
                    let innerR = bossSize * 0.3
                    let outerR = bossSize * 0.85
                    crackPath.move(to: CGPoint(x: cos(angle) * innerR, y: sin(angle) * innerR))
                    // Jagged line
                    let midR = (innerR + outerR) / 2
                    let jitter: CGFloat = bossSize * 0.1
                    crackPath.addLine(to: CGPoint(x: cos(angle + 0.1) * midR + jitter,
                                                  y: sin(angle + 0.1) * midR))
                    crackPath.addLine(to: CGPoint(x: cos(angle) * outerR, y: sin(angle) * outerR))
                }
                let cracks = SKShapeNode(path: crackPath)
                cracks.strokeColor = UIColor(hex: "ff00ff")?.withAlphaComponent(0.6) ?? UIColor.magenta.withAlphaComponent(0.6)
                cracks.lineWidth = 1.5
                cracks.lineCap = .round
                cracks.zPosition = 0.3
                cracks.name = crackKey
                bossNode.addChild(cracks)

                // Crack flicker
                let flicker = SKAction.sequence([
                    SKAction.fadeAlpha(to: 0.3, duration: 0.2),
                    SKAction.fadeAlpha(to: 0.8, duration: 0.2)
                ])
                cracks.run(SKAction.repeatForever(flicker))
            }
        }

        // Phase 4: body becomes semi-transparent
        if phase >= 4 {
            bossNode.alpha = 0.75
            // Eye color shifts to red
            if let eye = bossNode.children.first(where: {
                ($0 as? SKShapeNode)?.fillColor == (UIColor(hex: "8800ff") ?? UIColor.purple)
            }) as? SKShapeNode {
                eye.fillColor = UIColor.red.withAlphaComponent(0.9)
                eye.strokeColor = UIColor(hex: "ff0044") ?? UIColor.red
            }
        }
    }
}
