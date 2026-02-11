import SpriteKit

// MARK: - Boss Rendering Manager
// Extracted from GameScene+BossRendering (Step 4.1) — all boss mechanics
// rendering for 4 bosses with zero game-logic dependencies.

class BossRenderingManager {

    // MARK: - Scene References

    weak var scene: SKScene?
    var nodePool: NodePool!

    // MARK: - Node Tracking

    var bossMechanicNodes: [String: SKNode] = [:]

    // MARK: - Cached SKActions (avoid recreating every frame)

    lazy var laserFlickerAction: SKAction = {
        SKAction.sequence([
            SKAction.fadeAlpha(to: 0.8, duration: 0.08),
            SKAction.fadeAlpha(to: 1.0, duration: 0.08)
        ])
    }()

    lazy var puddlePulseAction: SKAction = {
        SKAction.sequence([
            SKAction.scale(to: 1.15, duration: 0.3),
            SKAction.scale(to: 1.0, duration: 0.3)
        ])
    }()

    lazy var voidZonePulseAction: SKAction = {
        SKAction.sequence([
            SKAction.scale(to: 1.1, duration: 0.4),
            SKAction.scale(to: 1.0, duration: 0.4)
        ])
    }()

    lazy var pylonCrystalPulseAction: SKAction = {
        SKAction.sequence([
            SKAction.scale(to: 1.2, duration: 0.5),
            SKAction.scale(to: 1.0, duration: 0.5)
        ])
    }()

    lazy var gravityWellRotateAction: SKAction = {
        SKAction.rotate(byAngle: .pi * 2, duration: 3)
    }()

    lazy var arenaBoundaryPulseAction: SKAction = {
        SKAction.sequence([
            SKAction.fadeAlpha(to: 0.5, duration: 0.5),
            SKAction.fadeAlpha(to: 1.0, duration: 0.5)
        ])
    }()

    lazy var chainsawRotateAction: SKAction = {
        SKAction.rotate(byAngle: .pi * 2, duration: 0.8)
    }()

    lazy var chainsawDangerPulseAction: SKAction = {
        SKAction.sequence([
            SKAction.scale(to: 1.1, duration: 0.2),
            SKAction.scale(to: 1.0, duration: 0.2)
        ])
    }()

    // MARK: - State Caching

    var bossMechanicFrameCounter: Int = 0
    var puddlePhaseCache: [String: String] = [:]  // id -> "warning", "active", "pop"
    var zonePhaseCache: [String: Bool] = [:]       // id -> isActive

    // MARK: - Configuration

    func configure(scene: SKScene, nodePool: NodePool) {
        self.scene = scene
        self.nodePool = nodePool
    }

    // MARK: - Public Rendering API

    func renderFrame(gameState: GameState) {
        if let bossState = gameState.cyberbossState {
            renderCyberbossMechanics(bossState: bossState, gameState: gameState)
        } else {
            cleanupBossNodes(prefix: "cyberboss_")
        }

        if let bossState = gameState.voidHarbingerState {
            renderVoidHarbingerMechanics(bossState: bossState, gameState: gameState)
        } else {
            cleanupBossNodes(prefix: "voidharbinger_")
        }

        if let bossState = gameState.overclockerState {
            renderOverclockerMechanics(bossState: bossState, gameState: gameState)
        } else {
            cleanupBossNodes(prefix: "overclocker_")
        }

        if let bossState = gameState.trojanWyrmState {
            renderTrojanWyrmMechanics(bossState: bossState, gameState: gameState)
        } else {
            cleanupBossNodes(prefix: "trojanwyrm_")
        }
    }

    // MARK: - Cleanup

    func cleanup() {
        for (_, node) in bossMechanicNodes {
            node.removeFromParent()
        }
        bossMechanicNodes.removeAll()
        puddlePhaseCache.removeAll()
        zonePhaseCache.removeAll()
    }

    func cleanupBossNodes(prefix: String) {
        let keysToRemove = bossMechanicNodes.keys.filter { $0.hasPrefix(prefix) }
        for key in keysToRemove {
            if let node = bossMechanicNodes[key] {
                let poolType: String
                if key.contains("puddle") { poolType = "boss_puddle" }
                else if key.contains("laser") { poolType = "boss_laser" }
                else if key.contains("zone") { poolType = "boss_zone" }
                else if key.contains("pylon") { poolType = "boss_pylon" }
                else if key.contains("rift") { poolType = "boss_rift" }
                else if key.contains("well") { poolType = "boss_well" }
                else { poolType = "boss_misc" }
                nodePool.release(node, type: poolType)
            }
            bossMechanicNodes.removeValue(forKey: key)
        }
    }

    // MARK: - Utilities

    func findKeysToRemove(prefix: String, activeIds: Set<String>) -> [String] {
        let prefixCount = prefix.count
        var keysToRemove: [String] = []
        keysToRemove.reserveCapacity(bossMechanicNodes.count / 4)

        for key in bossMechanicNodes.keys {
            guard key.hasPrefix(prefix) else { continue }
            let id = String(key.dropFirst(prefixCount))
            if !activeIds.contains(id) {
                keysToRemove.append(key)
            }
        }
        return keysToRemove
    }

    func pointToLineDistance(point: CGPoint, lineStart: CGPoint, lineEnd: CGPoint) -> CGFloat {
        let dx = lineEnd.x - lineStart.x
        let dy = lineEnd.y - lineStart.y
        let lengthSquared = dx * dx + dy * dy

        if lengthSquared == 0 {
            return sqrt(pow(point.x - lineStart.x, 2) + pow(point.y - lineStart.y, 2))
        }

        let t = max(0, min(1, ((point.x - lineStart.x) * dx + (point.y - lineStart.y) * dy) / lengthSquared))
        let projX = lineStart.x + t * dx
        let projY = lineStart.y + t * dy

        return sqrt(pow(point.x - projX, 2) + pow(point.y - projY, 2))
    }

    // MARK: - Phase Indicator

    func renderPhaseIndicator(phase: Int, bossType: String, isInvulnerable: Bool = false, gameState: GameState) {
        guard let scene = scene else { return }
        let nodeKey = "\(bossType)_phase_indicator"

        if let label = bossMechanicNodes[nodeKey] as? SKLabelNode {
            label.text = isInvulnerable ? L10n.Boss.phaseInvulnerable(phase) : L10n.Boss.phase(phase)
            label.fontColor = isInvulnerable ? DesignColors.warningUI : DesignColors.primaryUI
        } else {
            let label = SKLabelNode(text: L10n.Boss.phase(phase))
            label.fontName = "Menlo-Bold"
            label.fontSize = 18
            label.fontColor = DesignColors.primaryUI
            label.position = CGPoint(x: gameState.arena.width / 2, y: gameState.arena.height - 60)
            label.zPosition = 200
            label.name = nodeKey

            scene.addChild(label)
            bossMechanicNodes[nodeKey] = label
        }
    }

    // MARK: - Cyberboss Rendering

    func renderCyberbossMechanics(bossState: CyberbossAI.CyberbossState, gameState: GameState) {
        guard let scene = scene else { return }
        guard let boss = gameState.enemies.first(where: { $0.isBoss && !$0.isDead }) else { return }

        renderChainsawEffect(bossState: bossState, boss: boss, gameState: gameState)

        // Render damage puddles (with state caching to avoid redundant color updates)
        var activePuddleIds = Set<String>()
        for puddle in bossState.damagePuddles {
            activePuddleIds.insert(puddle.id)
            let nodeKey = "cyberboss_puddle_\(puddle.id)"

            let isWarningPhase = puddle.lifetime < puddle.warningDuration
            let isAboutToPop = puddle.lifetime > puddle.maxLifetime - 0.5

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
            }
        }

        // Remove puddles that no longer exist
        let puddlePrefix = "cyberboss_puddle_"
        for key in findKeysToRemove(prefix: puddlePrefix, activeIds: activePuddleIds) {
            if let node = bossMechanicNodes[key] {
                nodePool.release(node, type: "boss_puddle")
            }
            let puddleId = String(key.dropFirst(puddlePrefix.count))
            puddlePhaseCache.removeValue(forKey: puddleId)
            bossMechanicNodes.removeValue(forKey: key)
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
                laserNode.glowWidth = 0
                laserNode.zPosition = 100
                laserNode.name = nodeKey
                laserNode.position = CGPoint(x: bossSceneX, y: bossSceneY)
                laserNode.zRotation = beam.angle * .pi / 180

                laserNode.run(SKAction.repeatForever(laserFlickerAction), withKey: "flicker")

                scene.addChild(laserNode)
                bossMechanicNodes[nodeKey] = laserNode
            }
        }

        // Remove lasers that no longer exist
        for key in findKeysToRemove(prefix: "cyberboss_laser_", activeIds: activeLaserIds) {
            if let node = bossMechanicNodes[key] {
                nodePool.release(node, type: "boss_laser")
            }
            bossMechanicNodes.removeValue(forKey: key)
        }

        renderPhaseIndicator(phase: bossState.phase, bossType: "cyberboss", gameState: gameState)
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
                dangerCircle.glowWidth = 4
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
                    toothNode.glowWidth = 2
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
            }
        } else {
            if let node = bossMechanicNodes[nodeKey] {
                node.run(SKAction.sequence([
                    SKAction.fadeOut(withDuration: 0.3),
                    SKAction.removeFromParent()
                ]))
                bossMechanicNodes.removeValue(forKey: nodeKey)
            }
        }
    }

    // MARK: - Void Harbinger Rendering

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
                    zoneNode.glowWidth = 4
                } else {
                    zoneNode.fillColor = DesignColors.warningUI.withAlphaComponent(0.1)
                    zoneNode.strokeColor = DesignColors.warningUI
                    zoneNode.run(SKAction.repeatForever(voidZonePulseAction), withKey: "pulse")
                }

                scene.addChild(zoneNode)
                bossMechanicNodes[nodeKey] = zoneNode
            }
        }

        // Remove zones that no longer exist
        let zonePrefix = "voidharbinger_zone_"
        for key in findKeysToRemove(prefix: zonePrefix, activeIds: activeZoneIds) {
            if let node = bossMechanicNodes[key] {
                nodePool.release(node, type: "boss_zone")
            }
            let zoneId = String(key.dropFirst(zonePrefix.count))
            zonePhaseCache.removeValue(forKey: zoneId)
            bossMechanicNodes.removeValue(forKey: key)
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
                pylonBody.glowWidth = 3
                container.addChild(pylonBody)

                let crystal = SKShapeNode(circleOfRadius: 12)
                crystal.fillColor = DesignColors.secondaryUI
                crystal.strokeColor = DesignColors.primaryUI.withAlphaComponent(0.6)
                crystal.position = CGPoint(x: 0, y: 40)
                crystal.glowWidth = 6
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
            }
        }

        // Remove destroyed pylons
        for key in findKeysToRemove(prefix: "voidharbinger_pylon_", activeIds: activePylonIds) {
            if let node = bossMechanicNodes[key] {
                nodePool.release(node, type: "boss_pylon")
            }
            bossMechanicNodes.removeValue(forKey: key)
        }

        // Render shield around boss during Phase 2
        let shieldKey = "voidharbinger_shield"
        let bossEnemy = gameState.enemies.first { $0.isBoss && !$0.isDead }
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
                shieldNode.glowWidth = 8
                shieldNode.position = bossScenePos
                shieldNode.zPosition = 45
                shieldNode.name = shieldKey

                let shieldPulse = SKAction.sequence([
                    SKAction.group([
                        SKAction.scale(to: 1.08, duration: 0.8),
                        SKAction.fadeAlpha(to: 0.7, duration: 0.8)
                    ]),
                    SKAction.group([
                        SKAction.scale(to: 1.0, duration: 0.8),
                        SKAction.fadeAlpha(to: 1.0, duration: 0.8)
                    ])
                ])
                shieldNode.run(SKAction.repeatForever(shieldPulse), withKey: "pulse")

                let rotation = SKAction.rotate(byAngle: .pi * 2, duration: 12)
                shieldNode.run(SKAction.repeatForever(rotation), withKey: "rotate")

                scene.addChild(shieldNode)
                bossMechanicNodes[shieldKey] = shieldNode
            }
        } else {
            if let shield = bossMechanicNodes[shieldKey] {
                shield.removeFromParent()
                bossMechanicNodes.removeValue(forKey: shieldKey)
            }
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
                    lineNode.glowWidth = 4
                    lineNode.zPosition = 40
                    lineNode.name = lineKey

                    let linePulse = SKAction.sequence([
                        SKAction.fadeAlpha(to: 0.4, duration: 0.3),
                        SKAction.fadeAlpha(to: 1.0, duration: 0.3)
                    ])
                    lineNode.run(SKAction.repeatForever(linePulse), withKey: "pulse")

                    scene.addChild(lineNode)
                    bossMechanicNodes[lineKey] = lineNode
                }
            }
        }

        // Remove lines for destroyed pylons or when not in Phase 2
        for key in findKeysToRemove(prefix: "voidharbinger_pylonline_", activeIds: activeLineIds) {
            if let node = bossMechanicNodes[key] {
                node.removeFromParent()
            }
            bossMechanicNodes.removeValue(forKey: key)
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

                let pulse = SKAction.sequence([
                    SKAction.fadeAlpha(to: 0.5, duration: 0.5),
                    SKAction.fadeAlpha(to: 1.0, duration: 0.5)
                ])
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
                        arrowNode.glowWidth = 4
                        arrowNode.position = CGPoint(x: clampedX, y: clampedY)
                        arrowNode.zRotation = angle
                        arrowNode.zPosition = 150
                        arrowNode.name = arrowKey

                        let arrowPulse = SKAction.sequence([
                            SKAction.scale(to: 1.2, duration: 0.3),
                            SKAction.scale(to: 1.0, duration: 0.3)
                        ])
                        arrowNode.run(SKAction.repeatForever(arrowPulse), withKey: "pulse")

                        scene.addChild(arrowNode)
                        bossMechanicNodes[arrowKey] = arrowNode
                    }
                } else {
                    if let arrow = bossMechanicNodes[arrowKey] {
                        arrow.removeFromParent()
                        bossMechanicNodes.removeValue(forKey: arrowKey)
                    }
                }
            }
        } else {
            let hintKey = "voidharbinger_pylon_hint"
            if let hint = bossMechanicNodes[hintKey] {
                hint.removeFromParent()
                bossMechanicNodes.removeValue(forKey: hintKey)
            }

            let arrowPrefix = "voidharbinger_pylon_arrow_"
            for key in bossMechanicNodes.keys where key.hasPrefix(arrowPrefix) {
                if let arrow = bossMechanicNodes[key] {
                    arrow.removeFromParent()
                }
                bossMechanicNodes.removeValue(forKey: key)
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
                let riftLength = BalanceConfig.VoidHarbinger.voidRiftLength
                let path = CGMutablePath()
                path.move(to: CGPoint.zero)
                path.addLine(to: CGPoint(x: riftLength, y: 0))

                let riftNode = SKShapeNode(path: path)
                riftNode.strokeColor = DesignColors.secondaryUI
                riftNode.lineWidth = rift.width
                riftNode.glowWidth = 6
                riftNode.alpha = 0.8
                riftNode.zPosition = 10
                riftNode.name = nodeKey
                riftNode.position = CGPoint(x: centerSceneX, y: centerSceneY)
                riftNode.zRotation = rift.angle * .pi / 180

                scene.addChild(riftNode)
                bossMechanicNodes[nodeKey] = riftNode
            }
        }

        // Remove rifts that no longer exist
        for key in findKeysToRemove(prefix: "voidharbinger_rift_", activeIds: activeRiftIds) {
            if let node = bossMechanicNodes[key] {
                nodePool.release(node, type: "boss_rift")
            }
            bossMechanicNodes.removeValue(forKey: key)
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
                innerCircle.glowWidth = 8
                wellNode.addChild(innerCircle)

                wellNode.run(SKAction.repeatForever(gravityWellRotateAction), withKey: "rotate")

                scene.addChild(wellNode)
                bossMechanicNodes[nodeKey] = wellNode
            }
        }

        // Remove wells that no longer exist
        for key in findKeysToRemove(prefix: "voidharbinger_well_", activeIds: activeWellIds) {
            if let node = bossMechanicNodes[key] {
                nodePool.release(node, type: "boss_well")
            }
            bossMechanicNodes.removeValue(forKey: key)
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
                arenaNode.glowWidth = 4
                arenaNode.zPosition = 3
                arenaNode.name = arenaKey
                arenaNode.position = CGPoint(x: bossState.arenaCenter.x, y: centerSceneY)
                arenaNode.xScale = currentScale
                arenaNode.yScale = currentScale

                arenaNode.run(SKAction.repeatForever(arenaBoundaryPulseAction), withKey: "pulse")

                scene.addChild(arenaNode)
                bossMechanicNodes[arenaKey] = arenaNode
            }
        } else {
            if let node = bossMechanicNodes["voidharbinger_arena"] {
                node.removeFromParent()
                bossMechanicNodes.removeValue(forKey: "voidharbinger_arena")
            }
        }

        renderPhaseIndicator(phase: bossState.phase, bossType: "voidharbinger", isInvulnerable: bossState.isInvulnerable, gameState: gameState)
    }

    // MARK: - Overclocker Rendering

    func renderOverclockerMechanics(bossState: OverclockerAI.OverclockerState, gameState: GameState) {
        guard let scene = scene else { return }
        guard let boss = gameState.enemies.first(where: { $0.isBoss && !$0.isDead }) else { return }
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
                }

                bladeNode.position = CGPoint(x: bossPos.x, y: arenaH - bossPos.y)
                bladeNode.zRotation = -currentAngle
            }
        } else {
            for i in 0..<3 {
                let nodeKey = "overclocker_blade_\(i)"
                if let node = bossMechanicNodes[nodeKey] {
                    node.removeFromParent()
                    bossMechanicNodes.removeValue(forKey: nodeKey)
                }
            }
        }

        // Phase 2: Render lava tiles
        if bossState.phase == 2 {
            let arenaRect = bossState.arenaRect
            let tileW = arenaRect.width / 4
            let tileH = arenaRect.height / 4

            for i in 0..<16 {
                let nodeKey = "overclocker_tile_\(i)"
                let col = i % 4
                let row = i / 4

                let tileNode: SKShapeNode
                if let existing = bossMechanicNodes[nodeKey] as? SKShapeNode {
                    tileNode = existing
                } else {
                    tileNode = SKShapeNode(rectOf: CGSize(width: tileW - 4, height: tileH - 4), cornerRadius: 4)
                    tileNode.zPosition = 1
                    tileNode.lineWidth = 2
                    scene.addChild(tileNode)
                    bossMechanicNodes[nodeKey] = tileNode
                }

                let tileX = arenaRect.minX + CGFloat(col) * tileW + tileW / 2
                let tileY = arenaRect.minY + CGFloat(row) * tileH + tileH / 2
                tileNode.position = CGPoint(x: tileX, y: arenaH - tileY)

                switch bossState.tileStates[i] {
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
            }
        } else {
            for i in 0..<16 {
                let nodeKey = "overclocker_tile_\(i)"
                if let node = bossMechanicNodes[nodeKey] {
                    node.removeFromParent()
                    bossMechanicNodes.removeValue(forKey: nodeKey)
                }
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
                }

                steamNode.position = CGPoint(x: segment.x, y: arenaH - segment.y)
            }

            // Clean up old steam segments
            let keysToRemove = bossMechanicNodes.keys.filter { $0.hasPrefix("overclocker_steam_") && !activeSteamIds.contains(String($0.dropFirst("overclocker_steam_".count))) }
            for key in keysToRemove {
                bossMechanicNodes[key]?.removeFromParent()
                bossMechanicNodes.removeValue(forKey: key)
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
            }

            shredderNode.position = CGPoint(x: bossPos.x, y: arenaH - bossPos.y)
            shredderNode.strokeColor = bossState.isSuctionActive ? SKColor.red : SKColor.orange
        } else {
            if let node = bossMechanicNodes["overclocker_shredder"] {
                node.removeFromParent()
                bossMechanicNodes.removeValue(forKey: "overclocker_shredder")
            }
        }
    }

    // MARK: - Trojan Wyrm Rendering

    func renderTrojanWyrmMechanics(bossState: TrojanWyrmAI.TrojanWyrmState, gameState: GameState) {
        guard let scene = scene else { return }
        let arenaH = gameState.arena.height

        guard let boss = gameState.enemies.first(where: { $0.isBoss && !$0.isDead }) else { return }

        // Render body segments (Phase 1, 2, 4)
        if bossState.phase != 3 {
            for (i, segment) in bossState.segments.enumerated() {
                let nodeKey = "trojanwyrm_seg_\(i)"
                let segNode: SKShapeNode
                if let existing = bossMechanicNodes[nodeKey] as? SKShapeNode {
                    segNode = existing
                } else {
                    segNode = SKShapeNode(circleOfRadius: BalanceConfig.TrojanWyrm.bodyCollisionRadius)
                    segNode.lineWidth = 2
                    segNode.zPosition = 100
                    scene.addChild(segNode)
                    bossMechanicNodes[nodeKey] = segNode
                }

                segNode.position = CGPoint(x: segment.x, y: arenaH - segment.y)

                if bossState.phase == 2 && i == bossState.ghostSegmentIndex {
                    segNode.fillColor = SKColor.cyan.withAlphaComponent(0.2)
                    segNode.strokeColor = SKColor.cyan
                } else {
                    segNode.fillColor = SKColor(red: 0, green: 1, blue: 0.27, alpha: 0.7)
                    segNode.strokeColor = SKColor(red: 0, green: 0.8, blue: 0.2, alpha: 1.0)
                }
            }

            // Render head glow
            let headKey = "trojanwyrm_head"
            let headNode: SKShapeNode
            if let existing = bossMechanicNodes[headKey] as? SKShapeNode {
                headNode = existing
            } else {
                headNode = SKShapeNode(circleOfRadius: BalanceConfig.TrojanWyrm.headCollisionRadius + 5)
                headNode.fillColor = SKColor(red: 0, green: 1, blue: 0.27, alpha: 0.9)
                headNode.strokeColor = SKColor.white
                headNode.lineWidth = 3
                headNode.zPosition = 101
                scene.addChild(headNode)
                bossMechanicNodes[headKey] = headNode
            }
            headNode.position = CGPoint(x: boss.x, y: arenaH - boss.y)
        } else {
            // Clean up main body in Phase 3
            for i in 0..<BalanceConfig.TrojanWyrm.segmentCount {
                let nodeKey = "trojanwyrm_seg_\(i)"
                if let node = bossMechanicNodes[nodeKey] {
                    node.removeFromParent()
                    bossMechanicNodes.removeValue(forKey: nodeKey)
                }
            }
            if let node = bossMechanicNodes["trojanwyrm_head"] {
                node.removeFromParent()
                bossMechanicNodes.removeValue(forKey: "trojanwyrm_head")
            }
        }

        // Phase 3: Render sub-worms
        if bossState.phase == 3 {
            for (wi, worm) in bossState.subWorms.enumerated() {
                let headKey = "trojanwyrm_sw_\(wi)_head"
                let swHeadNode: SKShapeNode
                if let existing = bossMechanicNodes[headKey] as? SKShapeNode {
                    swHeadNode = existing
                } else {
                    swHeadNode = SKShapeNode(circleOfRadius: BalanceConfig.TrojanWyrm.subWormHeadSize)
                    swHeadNode.fillColor = SKColor(red: 0, green: 1, blue: 0.27, alpha: 0.9)
                    swHeadNode.strokeColor = SKColor.white
                    swHeadNode.lineWidth = 2
                    swHeadNode.zPosition = 101
                    scene.addChild(swHeadNode)
                    bossMechanicNodes[headKey] = swHeadNode
                }
                swHeadNode.position = CGPoint(x: worm.head.x, y: arenaH - worm.head.y)

                for (si, seg) in worm.body.enumerated() {
                    let segKey = "trojanwyrm_sw_\(wi)_seg_\(si)"
                    let swSegNode: SKShapeNode
                    if let existing = bossMechanicNodes[segKey] as? SKShapeNode {
                        swSegNode = existing
                    } else {
                        swSegNode = SKShapeNode(circleOfRadius: BalanceConfig.TrojanWyrm.subWormBodySize)
                        swSegNode.fillColor = SKColor(red: 0, green: 1, blue: 0.27, alpha: 0.6)
                        swSegNode.strokeColor = SKColor(red: 0, green: 0.8, blue: 0.2, alpha: 1.0)
                        swSegNode.lineWidth = 1
                        swSegNode.zPosition = 100
                        scene.addChild(swSegNode)
                        bossMechanicNodes[segKey] = swSegNode
                    }
                    swSegNode.position = CGPoint(x: seg.x, y: arenaH - seg.y)
                }
            }
        } else {
            // Clean up sub-worms if not in Phase 3
            for wi in 0..<4 {
                if let node = bossMechanicNodes["trojanwyrm_sw_\(wi)_head"] {
                    node.removeFromParent()
                    bossMechanicNodes.removeValue(forKey: "trojanwyrm_sw_\(wi)_head")
                }
                for si in 0..<5 {
                    let segKey = "trojanwyrm_sw_\(wi)_seg_\(si)"
                    if let node = bossMechanicNodes[segKey] {
                        node.removeFromParent()
                        bossMechanicNodes.removeValue(forKey: segKey)
                    }
                }
            }
        }

        // Phase 4: Render aim line during aiming state
        if bossState.phase == 4 && bossState.phase4SubState == .aiming {
            let aimKey = "trojanwyrm_aimline"
            let playerPos = CGPoint(x: gameState.player.x, y: gameState.player.y)
            let headPos = CGPoint(x: boss.x, y: boss.y)

            let aimNode: SKShapeNode
            if let existing = bossMechanicNodes[aimKey] as? SKShapeNode {
                aimNode = existing
            } else {
                aimNode = SKShapeNode()
                aimNode.strokeColor = SKColor.red
                aimNode.lineWidth = 3
                aimNode.zPosition = 102
                scene.addChild(aimNode)
                bossMechanicNodes[aimKey] = aimNode
            }

            let path = CGMutablePath()
            path.move(to: CGPoint(x: headPos.x, y: arenaH - headPos.y))
            path.addLine(to: CGPoint(x: playerPos.x, y: arenaH - playerPos.y))
            aimNode.path = path
        } else {
            if let node = bossMechanicNodes["trojanwyrm_aimline"] {
                node.removeFromParent()
                bossMechanicNodes.removeValue(forKey: "trojanwyrm_aimline")
            }
        }
    }
}
