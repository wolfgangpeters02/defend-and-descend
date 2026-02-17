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

        // Render pylons (Phase 2) — striking crystal towers with energy rings
        var activePylonIds = Set<String>()
        for pylon in bossState.pylons where !pylon.isDestroyed {
            activePylonIds.insert(pylon.id)
            let nodeKey = "voidharbinger_pylon_\(pylon.id)"

            if let container = bossMechanicNodes[nodeKey] {
                // Update health bar fill
                if let healthBar = container.childNode(withName: "healthFill") as? SKShapeNode {
                    let healthPercent = pylon.health / pylon.maxHealth
                    healthBar.xScale = max(0.01, healthPercent)
                    // Color shifts from green → yellow → red as health drops
                    if healthPercent < 0.33 {
                        healthBar.fillColor = DesignColors.dangerUI
                    } else if healthPercent < 0.66 {
                        healthBar.fillColor = DesignColors.warningUI
                    }
                }
            } else {
                let container = SKNode()
                container.position = CGPoint(x: pylon.x, y: gameState.arena.height - pylon.y)
                container.zPosition = 50
                container.name = nodeKey

                // Diamond-shaped crystal core
                let diamondPath = CGMutablePath()
                diamondPath.move(to: CGPoint(x: 0, y: 30))
                diamondPath.addLine(to: CGPoint(x: 20, y: 0))
                diamondPath.addLine(to: CGPoint(x: 0, y: -30))
                diamondPath.addLine(to: CGPoint(x: -20, y: 0))
                diamondPath.closeSubpath()

                let crystal = SKShapeNode(path: diamondPath)
                crystal.fillColor = DesignColors.secondaryUI.withAlphaComponent(0.7)
                crystal.strokeColor = DesignColors.secondaryUI
                crystal.lineWidth = 2
                crystal.glowWidth = 0
                crystal.name = "crystal"
                container.addChild(crystal)

                // Inner diamond glow
                let innerDiamond = CGMutablePath()
                innerDiamond.move(to: CGPoint(x: 0, y: 16))
                innerDiamond.addLine(to: CGPoint(x: 10, y: 0))
                innerDiamond.addLine(to: CGPoint(x: 0, y: -16))
                innerDiamond.addLine(to: CGPoint(x: -10, y: 0))
                innerDiamond.closeSubpath()

                let innerGlow = SKShapeNode(path: innerDiamond)
                innerGlow.fillColor = SKColor.white.withAlphaComponent(0.3)
                innerGlow.strokeColor = SKColor.clear
                innerGlow.zPosition = 0.1
                container.addChild(innerGlow)

                // Orbiting energy ring
                let ring = SKShapeNode(ellipseOf: CGSize(width: 56, height: 18))
                ring.fillColor = SKColor.clear
                ring.strokeColor = DesignColors.secondaryUI.withAlphaComponent(0.6)
                ring.lineWidth = 2
                ring.zPosition = 0.2
                ring.name = "ring"
                container.addChild(ring)

                let ringRotate = SKAction.rotate(byAngle: .pi * 2, duration: 2.0)
                ring.run(SKAction.repeatForever(ringRotate), withKey: "rotate")

                // Health bar
                let healthBg = SKShapeNode(rectOf: CGSize(width: 50, height: 6))
                healthBg.fillColor = DesignColors.surfaceUI
                healthBg.strokeColor = DesignColors.mutedUI
                healthBg.position = CGPoint(x: 0, y: -42)
                container.addChild(healthBg)

                let healthFill = SKShapeNode(rect: CGRect(x: -25, y: -3, width: 50, height: 6))
                healthFill.fillColor = DesignColors.successUI
                healthFill.strokeColor = SKColor.clear
                healthFill.position = CGPoint(x: 0, y: -42)
                healthFill.name = "healthFill"
                container.addChild(healthFill)

                // Crystal pulse animation
                crystal.run(SKAction.repeatForever(pylonCrystalPulseAction), withKey: "pulse")

                // Gentle alpha pulse on inner glow
                let glowDown = SKAction.fadeAlpha(to: 0.1, duration: 0.6)
                glowDown.timingMode = .easeInEaseOut
                let glowUp = SKAction.fadeAlpha(to: 0.4, duration: 0.6)
                glowUp.timingMode = .easeInEaseOut
                innerGlow.run(SKAction.repeatForever(SKAction.sequence([glowDown, glowUp])), withKey: "pulse")

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

        // Phase 4: body becomes semi-transparent + fragment particle trails
        if phase >= 4 {
            bossNode.alpha = 0.75
            // Eye color shifts to red
            if let eye = bossNode.children.first(where: {
                ($0 as? SKShapeNode)?.fillColor == (UIColor(hex: "8800ff") ?? UIColor.purple)
            }) as? SKShapeNode {
                eye.fillColor = UIColor.red.withAlphaComponent(0.9)
                eye.strokeColor = UIColor(hex: "ff0044") ?? UIColor.red
            }

            // Fragment particle trails — small fading dots spawned along orbit
            if let fragments = bossNode.childNode(withName: "fragments"),
               fragments.action(forKey: "fragmentTrails") == nil {
                let bossSize = cachedBossEnemy?.size ?? 60
                let voidColor = UIColor(hex: BalanceConfig.VoidHarbinger.bossColor) ?? UIColor.purple
                let spawnTrails = SKAction.run { [weak fragments] in
                    guard let fragments = fragments, fragments.parent != nil else { return }
                    // Spawn 2 trail dots at opposite fragment positions
                    for i in 0..<2 {
                        let baseAngle = CGFloat(i) * .pi
                        let worldAngle = baseAngle + fragments.zRotation
                        let fx = cos(worldAngle) * bossSize * 0.8
                        let fy = sin(worldAngle) * bossSize * 0.8
                        let dot = SKShapeNode(circleOfRadius: 2)
                        dot.fillColor = voidColor.withAlphaComponent(0.5)
                        dot.strokeColor = .clear
                        dot.position = CGPoint(x: fx, y: fy)
                        dot.zPosition = -0.1
                        fragments.parent?.addChild(dot)
                        dot.run(SKAction.sequence([
                            SKAction.group([
                                SKAction.fadeOut(withDuration: 0.4),
                                SKAction.scale(to: 0.2, duration: 0.4)
                            ]),
                            SKAction.removeFromParent()
                        ]))
                    }
                }
                let trailCycle = SKAction.sequence([spawnTrails, SKAction.wait(forDuration: 0.15)])
                fragments.run(SKAction.repeatForever(trailCycle), withKey: "fragmentTrails")
            }
        }
    }
}
