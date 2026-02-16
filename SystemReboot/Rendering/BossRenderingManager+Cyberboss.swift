import SpriteKit

// MARK: - Cyberboss Rendering

extension BossRenderingManager {

    func renderCyberbossMechanics(bossState: CyberbossAI.CyberbossState, gameState: GameState) {
        guard let scene = scene else { return }
        guard let boss = cachedBossEnemy else { return }

        renderChainsawEffect(bossState: bossState, boss: boss, gameState: gameState)

        // Render damage puddles (with state caching to avoid redundant color updates)
        var activePuddleIds = Set<String>()
        for puddle in bossState.damagePuddles {
            activePuddleIds.insert(puddle.id)
            let nodeKey = "cyberboss_puddle_\(puddle.id)"

            let isWarningPhase = puddle.lifetime < puddle.warningDuration
            let isAboutToPop = puddle.lifetime > puddle.maxLifetime - BalanceConfig.Cyberboss.puddlePopThreshold

            let currentPhase: String
            if isWarningPhase { currentPhase = "warning" }
            else if isAboutToPop { currentPhase = "pop" }
            else { currentPhase = "active" }

            if let node = bossMechanicNodes[nodeKey] as? SKShapeNode {
                let cachedPhase = puddlePhaseCache[puddle.id]
                if cachedPhase != currentPhase {
                    puddlePhaseCache[puddle.id] = currentPhase

                    if isWarningPhase {
                        node.fillColor = DesignColors.warningUI.withAlphaComponent(0.1)
                        node.strokeColor = DesignColors.warningUI
                        node.lineWidth = 3
                        node.glowWidth = 0
                    } else if isAboutToPop {
                        node.fillColor = DesignColors.dangerUI.withAlphaComponent(0.5)
                        node.strokeColor = DesignColors.dangerUI
                        node.lineWidth = 5
                        node.glowWidth = 0
                    } else {
                        node.fillColor = DesignColors.dangerUI.withAlphaComponent(0.25)
                        node.strokeColor = DesignColors.dangerUI.withAlphaComponent(0.8)
                        node.lineWidth = 3
                        node.glowWidth = 0
                    }
                }
            } else {
                let puddleNode = SKShapeNode(circleOfRadius: puddle.radius)
                puddleNode.fillColor = DesignColors.warningUI.withAlphaComponent(0.1)
                puddleNode.strokeColor = DesignColors.warningUI
                puddleNode.lineWidth = 3
                puddleNode.glowWidth = 0
                puddleNode.position = CGPoint(x: puddle.x, y: gameState.arena.height - puddle.y)
                puddleNode.zPosition = 5
                puddleNode.name = nodeKey

                puddleNode.run(SKAction.repeatForever(puddlePulseAction), withKey: "pulse")

                scene.addChild(puddleNode)
                bossMechanicNodes[nodeKey] = puddleNode
                fadeInMechanicNode(puddleNode)
            }
        }

        // Remove puddles that no longer exist (8b: fade-out, 8d: pop burst)
        let puddlePrefix = "cyberboss_puddle_"
        for key in findKeysToRemove(prefix: puddlePrefix, activeIds: activePuddleIds) {
            let puddleId = String(key.dropFirst(puddlePrefix.count))

            // 8d: Puddle pop burst — scale pulse + red particles on pop-phase expiry
            if puddlePhaseCache[puddleId] == "pop", let node = bossMechanicNodes[key] {
                spawnVisualBurst(at: node.position, color: DesignColors.dangerUI, count: 8)
                // Brief scale pulse before fade-out
                node.run(SKAction.scale(to: 1.3, duration: 0.1))
            }

            puddlePhaseCache.removeValue(forKey: puddleId)
            fadeOutAndRemoveBossNode(key: key)
        }

        // Render laser beams
        var activeLaserIds = Set<String>()
        for beam in bossState.laserBeams {
            activeLaserIds.insert(beam.id)
            let nodeKey = "cyberboss_laser_\(beam.id)"

            let bossSceneX = boss.x
            let bossSceneY = gameState.arena.height - boss.y

            let laserColor: SKColor = beam.isActive ? DesignColors.dangerUI : SKColor.yellow
            let laserWidth: CGFloat = beam.isActive ? 8 : 4

            if let node = bossMechanicNodes[nodeKey] as? SKShapeNode {
                node.position = CGPoint(x: bossSceneX, y: bossSceneY)
                node.zRotation = beam.angle * .pi / 180
                node.strokeColor = laserColor
                node.lineWidth = laserWidth
            } else {
                let path = CGMutablePath()
                path.move(to: CGPoint.zero)
                path.addLine(to: CGPoint(x: beam.length, y: 0))

                let laserNode = SKShapeNode(path: path)
                laserNode.strokeColor = laserColor
                laserNode.lineWidth = laserWidth
                laserNode.glowWidth = 4
                laserNode.blendMode = .add
                laserNode.zPosition = 100
                laserNode.name = nodeKey
                laserNode.position = CGPoint(x: bossSceneX, y: bossSceneY)
                laserNode.zRotation = beam.angle * .pi / 180

                laserNode.run(SKAction.repeatForever(laserFlickerAction), withKey: "flicker")

                scene.addChild(laserNode)
                bossMechanicNodes[nodeKey] = laserNode
                fadeInMechanicNode(laserNode)
            }
        }

        // Remove lasers that no longer exist (8b: fade-out)
        for key in findKeysToRemove(prefix: "cyberboss_laser_", activeIds: activeLaserIds) {
            fadeOutAndRemoveBossNode(key: key)
        }

        renderPhaseIndicator(phase: bossState.phase, bossType: "cyberboss", gameState: gameState)

        // Phase-specific body visual escalation (Phase 4B)
        updateCyberbossBodyVisuals(phase: bossState.phase, boss: boss, gameState: gameState)
    }

    // MARK: - Cyberboss Phase Body Visuals

    /// Update Cyberboss body composition based on current phase.
    /// LED colors, pulse speed, glitch effects escalate per phase.
    func updateCyberbossBodyVisuals(phase: Int, boss: Enemy, gameState: GameState) {
        guard phase != cachedCyberbossPhase else { return }
        cachedCyberbossPhase = phase

        // Find boss body node (lazy cache)
        if cachedBossBodyNode == nil || cachedBossBodyNode?.parent == nil {
            let bossScenePos = CGPoint(x: boss.x, y: gameState.arena.height - boss.y)
            cachedBossBodyNode = enemyLayer?.children.first(where: {
                abs($0.position.x - bossScenePos.x) < 5 && abs($0.position.y - bossScenePos.y) < 5
            })
        }
        guard let bossNode = cachedBossBodyNode else { return }

        // Update status LEDs color based on phase
        if let leds = bossNode.childNode(withName: "statusLEDs") as? SKShapeNode {
            switch phase {
            case 1: leds.fillColor = UIColor.green
            case 2: leds.fillColor = UIColor.yellow
            case 3, 4: leds.fillColor = UIColor.red
            default: leds.fillColor = UIColor.green
            }
        }

        // Update threat ring intensity
        if let ring = bossNode.childNode(withName: "threatRing") as? SKShapeNode {
            switch phase {
            case 1:
                ring.strokeColor = UIColor.red.withAlphaComponent(0.4)
                ring.setScale(1.0)
            case 2:
                ring.strokeColor = UIColor.red.withAlphaComponent(0.6)
            case 3:
                ring.strokeColor = UIColor.red.withAlphaComponent(0.8)
                ring.setScale(1.1)
            case 4:
                ring.strokeColor = UIColor.red
                ring.setScale(1.15)
            default: break
            }
        }

        // Update eye scanner speed
        if let eye = bossNode.childNode(withName: "eye") as? SKShapeNode {
            eye.removeAction(forKey: "eyeSweep")
            let scanHeight = (boss.size ?? 60) * 0.4
            let sweepDuration: TimeInterval = phase >= 3 ? 1.0 : 2.0
            let sweep = SKAction.sequence([
                SKAction.moveTo(y: scanHeight, duration: sweepDuration),
                SKAction.moveTo(y: -scanHeight, duration: sweepDuration)
            ])
            eye.run(SKAction.repeatForever(sweep), withKey: "eyeSweep")

            // Phase 3+: eye turns red
            if phase >= 3 {
                eye.strokeColor = UIColor.red
                eye.lineWidth = 3
            }
        }

        // Phase 4: glitch jitter on chassis
        if let chassis = bossNode.childNode(withName: "chassis") as? SKShapeNode {
            if phase >= 4 {
                if chassis.action(forKey: "phaseJitter") == nil {
                    let jitter = SKAction.repeatForever(SKAction.sequence([
                        SKAction.customAction(withDuration: 0.05) { node, _ in
                            node.position = CGPoint(
                                x: CGFloat.random(in: -2...2),
                                y: CGFloat.random(in: -2...2)
                            )
                        },
                        SKAction.move(to: .zero, duration: 0.05)
                    ]))
                    chassis.run(jitter, withKey: "phaseJitter")
                }
            } else {
                chassis.removeAction(forKey: "phaseJitter")
            }
        }

        // Phase 2+: shield hexagon gains visual emphasis
        if let shield = bossNode.childNode(withName: "shield") as? SKShapeNode {
            if phase >= 2 {
                shield.strokeColor = UIColor.white
                shield.lineWidth = 4
            }
        }
    }

    // MARK: - Chainsaw Effect

    func renderChainsawEffect(bossState: CyberbossAI.CyberbossState, boss: Enemy, gameState: GameState) {
        guard let scene = scene else { return }
        let nodeKey = "cyberboss_chainsaw"

        let showChainsaw = bossState.mode == .melee && bossState.phase <= 2

        if showChainsaw {
            let bossSceneY = gameState.arena.height - boss.y
            let bossSize = boss.size ?? 60

            if let existingNode = bossMechanicNodes[nodeKey] {
                existingNode.position = CGPoint(x: boss.x, y: bossSceneY)
            } else {
                let chainsawNode = SKNode()
                chainsawNode.name = nodeKey
                chainsawNode.position = CGPoint(x: boss.x, y: bossSceneY)
                chainsawNode.zPosition = 49

                let dangerCircle = SKShapeNode(circleOfRadius: bossSize + 10)
                dangerCircle.fillColor = DesignColors.dangerUI.withAlphaComponent(0.15)
                dangerCircle.strokeColor = DesignColors.dangerUI.withAlphaComponent(0.6)
                dangerCircle.lineWidth = 2
                dangerCircle.glowWidth = 0
                dangerCircle.name = "dangerCircle"
                chainsawNode.addChild(dangerCircle)

                let teethCount = 8
                let teethRadius = bossSize + 20
                for i in 0..<teethCount {
                    let angle = CGFloat(i) * (2 * .pi / CGFloat(teethCount))
                    let toothX = cos(angle) * teethRadius
                    let toothY = sin(angle) * teethRadius

                    let toothPath = CGMutablePath()
                    let toothSize: CGFloat = 12
                    toothPath.move(to: CGPoint(x: 0, y: toothSize / 2))
                    toothPath.addLine(to: CGPoint(x: toothSize, y: 0))
                    toothPath.addLine(to: CGPoint(x: 0, y: -toothSize / 2))
                    toothPath.closeSubpath()

                    let toothNode = SKShapeNode(path: toothPath)
                    toothNode.fillColor = DesignColors.dangerUI.withAlphaComponent(0.8)
                    toothNode.strokeColor = DesignColors.dangerUI
                    toothNode.lineWidth = 1
                    toothNode.glowWidth = 0
                    toothNode.position = CGPoint(x: toothX, y: toothY)
                    toothNode.zRotation = angle
                    chainsawNode.addChild(toothNode)
                }

                let outerRing = SKShapeNode(circleOfRadius: bossSize + 28)
                outerRing.fillColor = .clear
                outerRing.strokeColor = DesignColors.warningUI.withAlphaComponent(0.4)
                outerRing.lineWidth = 1.5
                outerRing.name = "outerRing"
                chainsawNode.addChild(outerRing)

                chainsawNode.run(SKAction.repeatForever(chainsawRotateAction), withKey: "rotate")
                dangerCircle.run(SKAction.repeatForever(chainsawDangerPulseAction), withKey: "pulse")

                scene.addChild(chainsawNode)
                bossMechanicNodes[nodeKey] = chainsawNode
                fadeInMechanicNode(chainsawNode)
            }
        } else {
            if let node = bossMechanicNodes[nodeKey] {
                // Delay key removal until after fade-out to prevent duplicate creation
                node.run(SKAction.sequence([
                    SKAction.fadeOut(withDuration: 0.3),
                    SKAction.run { [weak self] in
                        self?.bossMechanicNodes.removeValue(forKey: nodeKey)
                    },
                    SKAction.removeFromParent()
                ]))
            }
        }
    }
}
