import SpriteKit

// MARK: - Trojan Wyrm Rendering

extension BossRenderingManager {

    func renderTrojanWyrmMechanics(bossState: TrojanWyrmAI.TrojanWyrmState, gameState: GameState) {
        guard let scene = scene else { return }
        let arenaH = gameState.arena.height

        guard let boss = cachedBossEnemy else { return }

        let wyrmGreen = SKColor(red: 0, green: 1, blue: 0.27, alpha: 1.0)
        let wyrmDark = SKColor(red: 0, green: 0.6, blue: 0.15, alpha: 1.0)
        let wyrmLime = SKColor(red: 0.53, green: 1, blue: 0, alpha: 1.0)

        // Render body segments (Phase 1, 2, 4) with position history trailing
        if bossState.phase != 3 {
            // Record head position for smooth trailing
            let headScenePos = CGPoint(x: boss.x, y: arenaH - boss.y)
            wyrmHeadHistory.insert(headScenePos, at: 0)
            let maxHistory = bossState.segments.count * wyrmHistorySpacing + wyrmHistorySpacing
            if wyrmHeadHistory.count > maxHistory {
                wyrmHeadHistory.removeLast(wyrmHeadHistory.count - maxHistory)
            }

            let segCount = bossState.segments.count
            for (i, segment) in bossState.segments.enumerated() {
                let nodeKey = "trojanwyrm_seg_\(i)"
                let segNode: SKShapeNode
                if let existing = bossMechanicNodes[nodeKey] as? SKShapeNode {
                    segNode = existing
                } else {
                    // Taper: tail segments shrink gradually over last 6 segments
                    let taperStart = max(0, segCount - 6)
                    let baseR = BalanceConfig.TrojanWyrm.bodyCollisionRadius
                    let radius: CGFloat
                    if i >= taperStart {
                        let t = CGFloat(i - taperStart + 1) / 6.0
                        radius = baseR * (1.0 - t * 0.4)  // Shrinks to 60% at tip
                    } else {
                        radius = baseR
                    }
                    segNode = SKShapeNode(circleOfRadius: radius)
                    segNode.lineWidth = 2
                    segNode.zPosition = 100
                    scene.addChild(segNode)
                    bossMechanicNodes[nodeKey] = segNode
                }

                // Use history-based position for smooth trailing, fallback to game-state
                let historyIndex = (i + 1) * wyrmHistorySpacing
                if historyIndex < wyrmHeadHistory.count {
                    segNode.position = wyrmHeadHistory[historyIndex]
                } else {
                    segNode.position = CGPoint(x: segment.x, y: arenaH - segment.y)
                }

                if bossState.phase == 2 && i == bossState.ghostSegmentIndex {
                    segNode.fillColor = SKColor.cyan.withAlphaComponent(0.2)
                    segNode.strokeColor = SKColor.cyan
                } else {
                    // Alternating light/dark fills for caterpillar effect
                    let isEven = i % 2 == 0
                    segNode.fillColor = isEven
                        ? wyrmGreen.withAlphaComponent(0.7)
                        : wyrmDark.withAlphaComponent(0.7)
                    segNode.strokeColor = isEven
                        ? wyrmLime.withAlphaComponent(0.8)
                        : wyrmGreen.withAlphaComponent(0.6)
                }
            }

            // Tail wisp — trailing line behind the last segment
            let tailKey = "trojanwyrm_tailwisp"
            if segCount >= 2 {
                let tailWisp: SKShapeNode
                if let existing = bossMechanicNodes[tailKey] as? SKShapeNode {
                    tailWisp = existing
                } else {
                    tailWisp = SKShapeNode()
                    tailWisp.strokeColor = wyrmGreen.withAlphaComponent(0.25)
                    tailWisp.lineWidth = 1.5
                    tailWisp.lineCap = .round
                    tailWisp.zPosition = 99
                    scene.addChild(tailWisp)
                    bossMechanicNodes[tailKey] = tailWisp
                }
                // Draw a short trailing wisp from last segment extending away
                let lastSeg = bossState.segments[segCount - 1]
                let prevSeg = bossState.segments[segCount - 2]
                let dx = lastSeg.x - prevSeg.x
                let dy = lastSeg.y - prevSeg.y
                let wispLen: CGFloat = 20
                let wispPath = CGMutablePath()
                let lastPos = CGPoint(x: lastSeg.x, y: arenaH - lastSeg.y)
                wispPath.move(to: lastPos)
                wispPath.addLine(to: CGPoint(x: lastPos.x + dx * 0.5, y: lastPos.y - dy * 0.5))
                wispPath.addLine(to: CGPoint(x: lastPos.x + dx * 0.5 + wispLen * (dx / max(1, hypot(dx, dy))),
                                             y: lastPos.y - dy * 0.5 - wispLen * (dy / max(1, hypot(dx, dy)))))
                tailWisp.path = wispPath
            }

            // Render head with jaw/eye details
            let headKey = "trojanwyrm_head"
            let headContainer: SKNode
            if let existing = bossMechanicNodes[headKey] {
                headContainer = existing
            } else {
                headContainer = SKNode()
                headContainer.zPosition = 101

                // Head base circle
                let headBase = SKShapeNode(circleOfRadius: BalanceConfig.TrojanWyrm.headCollisionRadius + 5)
                headBase.fillColor = wyrmGreen.withAlphaComponent(0.9)
                headBase.strokeColor = SKColor.white
                headBase.lineWidth = 3
                headBase.name = "body"
                headContainer.addChild(headBase)

                // Add jaw, eyes, mandible details
                EntityRenderer.addTrojanWyrmHeadDetails(
                    to: headContainer,
                    size: BalanceConfig.TrojanWyrm.headCollisionRadius
                )

                scene.addChild(headContainer)
                bossMechanicNodes[headKey] = headContainer
            }
            headContainer.position = CGPoint(x: boss.x, y: arenaH - boss.y)

            // Orient head toward movement direction
            if bossState.segments.count > 0 {
                let firstSeg = bossState.segments[0]
                let dx = boss.x - firstSeg.x
                let dy = boss.y - firstSeg.y
                if dx != 0 || dy != 0 {
                    headContainer.zRotation = atan2(-dy, dx) - .pi / 2
                }
            }
        } else {
            // Clean up main body in Phase 3 and reset history
            wyrmHeadHistory.removeAll()
            for i in 0..<BalanceConfig.TrojanWyrm.segmentCount {
                removeBossNode(key: "trojanwyrm_seg_\(i)")
            }
            removeBossNode(key: "trojanwyrm_head")
            removeBossNode(key: "trojanwyrm_tailwisp")
        }

        // Phase 3: Render sub-worms with enhanced visuals
        if bossState.phase == 3 {
            for (wi, worm) in bossState.subWorms.enumerated() {
                // Sub-worm head — container with mini jaw details
                let headKey = "trojanwyrm_sw_\(wi)_head"
                let swHeadContainer: SKNode
                if let existing = bossMechanicNodes[headKey] {
                    swHeadContainer = existing
                } else {
                    swHeadContainer = SKNode()
                    swHeadContainer.zPosition = 101

                    let swHeadBase = SKShapeNode(circleOfRadius: BalanceConfig.TrojanWyrm.subWormHeadSize)
                    swHeadBase.fillColor = wyrmGreen.withAlphaComponent(0.9)
                    swHeadBase.strokeColor = SKColor.white
                    swHeadBase.lineWidth = 2
                    swHeadBase.name = "body"
                    swHeadContainer.addChild(swHeadBase)

                    // Mini jaw/eye details (scaled down)
                    EntityRenderer.addTrojanWyrmHeadDetails(
                        to: swHeadContainer,
                        size: BalanceConfig.TrojanWyrm.subWormHeadSize * 0.7
                    )

                    scene.addChild(swHeadContainer)
                    bossMechanicNodes[headKey] = swHeadContainer
                }
                swHeadContainer.position = CGPoint(x: worm.head.x, y: arenaH - worm.head.y)

                // Orient sub-worm head toward movement direction
                if let firstBody = worm.body.first {
                    let dx = worm.head.x - firstBody.x
                    let dy = worm.head.y - firstBody.y
                    if dx != 0 || dy != 0 {
                        swHeadContainer.zRotation = atan2(-dy, dx) - .pi / 2
                    }
                }

                // Sub-worm body segments with alternating fills
                for (si, seg) in worm.body.enumerated() {
                    let segKey = "trojanwyrm_sw_\(wi)_seg_\(si)"
                    let swSegNode: SKShapeNode
                    if let existing = bossMechanicNodes[segKey] as? SKShapeNode {
                        swSegNode = existing
                    } else {
                        // Taper sub-worm tail
                        let bodyCount = worm.body.count
                        let taperStart = max(0, bodyCount - 2)
                        let radius: CGFloat
                        if si >= taperStart {
                            let t = CGFloat(si - taperStart + 1) / 2.0
                            radius = BalanceConfig.TrojanWyrm.subWormBodySize * (1.0 - t * 0.3)
                        } else {
                            radius = BalanceConfig.TrojanWyrm.subWormBodySize
                        }
                        swSegNode = SKShapeNode(circleOfRadius: radius)
                        swSegNode.lineWidth = 1
                        swSegNode.zPosition = 100
                        scene.addChild(swSegNode)
                        bossMechanicNodes[segKey] = swSegNode
                    }
                    swSegNode.position = CGPoint(x: seg.x, y: arenaH - seg.y)

                    // Alternating caterpillar colors for sub-worms
                    let isEven = si % 2 == 0
                    swSegNode.fillColor = isEven
                        ? wyrmGreen.withAlphaComponent(0.6)
                        : wyrmDark.withAlphaComponent(0.6)
                    swSegNode.strokeColor = isEven
                        ? wyrmLime.withAlphaComponent(0.7)
                        : wyrmGreen.withAlphaComponent(0.5)
                }
            }
        } else {
            // Clean up sub-worms if not in Phase 3
            let swCleanupCount = max(BalanceConfig.TrojanWyrm.subWormCount, 8)  // Safe upper bound
            let swBodyCleanup = max(BalanceConfig.TrojanWyrm.subWormBodyCount, 8)
            for wi in 0..<swCleanupCount {
                removeBossNode(key: "trojanwyrm_sw_\(wi)_head")
                for si in 0..<swBodyCleanup {
                    removeBossNode(key: "trojanwyrm_sw_\(wi)_seg_\(si)")
                }
            }
        }

        renderPhaseIndicator(phase: bossState.phase, bossType: "trojanwyrm", gameState: gameState)

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
            removeBossNode(key: "trojanwyrm_aimline")
        }
    }
}
