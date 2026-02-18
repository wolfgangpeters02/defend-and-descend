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

        // Phase escalation colors
        let (fillAlphaBoost, strokeAlphaBoost, headStrokeColor) = trojanWyrmPhaseColors(phase: bossState.phase)

        // Phase 2 turret telegraph: segments flash white-lime before turret fire
        let turretTelegraphActive = bossState.phase == 2 && isTurretAboutToFire(bossState: bossState, gameTime: gameState.gameTime)

        // Render body segments (Phase 1, 2, 4) using game-state positions from drag-chain kinematics
        if bossState.phase != 3 {
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
                    fadeInMechanicNode(segNode)
                }

                segNode.position = CGPoint(x: segment.x, y: arenaH - segment.y)

                if bossState.phase == 2 && i == bossState.ghostSegmentIndex {
                    segNode.fillColor = SKColor.cyan.withAlphaComponent(0.2)
                    segNode.strokeColor = SKColor.cyan
                } else if turretTelegraphActive && i % 2 == 0 {
                    // Pre-fire telegraph: even segments (turret positions) flash white-lime
                    let telegraphProgress = turretTelegraphProgress(bossState: bossState, gameTime: gameState.gameTime)
                    let flashAlpha: CGFloat = 0.5 + telegraphProgress * 0.5
                    segNode.fillColor = SKColor.white.withAlphaComponent(flashAlpha)
                    segNode.strokeColor = wyrmLime.withAlphaComponent(flashAlpha)
                    segNode.lineWidth = 3
                } else {
                    // Alternating light/dark fills for caterpillar effect + phase escalation
                    let isEven = i % 2 == 0
                    segNode.fillColor = isEven
                        ? wyrmGreen.withAlphaComponent(0.7 + fillAlphaBoost)
                        : wyrmDark.withAlphaComponent(0.7 + fillAlphaBoost)
                    segNode.strokeColor = isEven
                        ? wyrmLime.withAlphaComponent(0.8 + strokeAlphaBoost)
                        : wyrmGreen.withAlphaComponent(0.6 + strokeAlphaBoost)
                    segNode.lineWidth = 2
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
                    fadeInMechanicNode(tailWisp)
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
                fadeInMechanicNode(headContainer)
            }
            headContainer.position = CGPoint(x: boss.x, y: arenaH - boss.y)

            // Phase escalation: update head visuals per phase
            if let headBase = headContainer.childNode(withName: "body") as? SKShapeNode {
                headBase.strokeColor = headStrokeColor
                if bossState.phase == 4 {
                    headBase.fillColor = wyrmLime.withAlphaComponent(0.95)
                }
            }

            // Phase 4 head jitter (instability pattern matching Cyberboss/Overclocker Phase 4)
            if bossState.phase == 4 {
                let jitterX = CGFloat.random(in: -1.5...1.5)
                let jitterY = CGFloat.random(in: -1.5...1.5)
                headContainer.position.x += jitterX
                headContainer.position.y += jitterY
            }

            // Phase 4 aiming: head pulse
            if bossState.phase == 4 && bossState.phase4SubState == .aiming {
                if headContainer.action(forKey: "aimPulse") == nil {
                    let pulse = SKAction.sequence([
                        SKAction.scale(to: 1.2, duration: 0.15),
                        SKAction.scale(to: 1.0, duration: 0.15)
                    ])
                    headContainer.run(SKAction.repeatForever(pulse), withKey: "aimPulse")
                }
            } else {
                if headContainer.action(forKey: "aimPulse") != nil {
                    headContainer.removeAction(forKey: "aimPulse")
                    headContainer.setScale(1.0)
                }
            }

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
            // Phase 2→3 transition: scatter body segments outward with particle bursts
            let previousPhase = cachedTrojanWyrmPhase
            if previousPhase == 2 {
                renderTrojanWyrmSplitAnimation(bossState: bossState, arenaH: arenaH)
            } else {
                // Normal Phase 3 cleanup (8b: fade-out)
                for i in 0..<BalanceConfig.TrojanWyrm.segmentCount {
                    fadeOutAndRemoveBossNode(key: "trojanwyrm_seg_\(i)")
                }
                fadeOutAndRemoveBossNode(key: "trojanwyrm_head")
                fadeOutAndRemoveBossNode(key: "trojanwyrm_tailwisp")
            }
        }

        // Update cached phase for transition detection
        cachedTrojanWyrmPhase = bossState.phase

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

                    // Phase 3 escalation: red eye glow on sub-worm heads
                    let eyeGlow = SKShapeNode(circleOfRadius: 4)
                    eyeGlow.fillColor = SKColor.red.withAlphaComponent(0.6)
                    eyeGlow.strokeColor = .clear
                    eyeGlow.position = CGPoint(x: 0, y: BalanceConfig.TrojanWyrm.subWormHeadSize * 0.3)
                    eyeGlow.zPosition = 3
                    eyeGlow.glowWidth = 3
                    swHeadContainer.addChild(eyeGlow)

                    scene.addChild(swHeadContainer)
                    bossMechanicNodes[headKey] = swHeadContainer
                    fadeInMechanicNode(swHeadContainer)
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
                        fadeInMechanicNode(swSegNode)
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
            // Clean up sub-worms if not in Phase 3 (8f: staggered despawn + green burst)
            let swCleanupCount = max(BalanceConfig.TrojanWyrm.subWormCount, 8)
            let swBodyCleanup = max(BalanceConfig.TrojanWyrm.subWormBodyCount, 8)
            let wyrmGreenBurst = SKColor(red: 0, green: 1, blue: 0.27, alpha: 1.0)

            for wi in 0..<swCleanupCount {
                let headKey = "trojanwyrm_sw_\(wi)_head"
                let stagger = TimeInterval(wi) * 0.1

                // 8f: Green particle burst at each sub-worm head before despawn
                if let headNode = bossMechanicNodes[headKey] {
                    let headPos = headNode.position
                    // Stagger the burst and fade-out for cascade effect
                    if stagger > 0 {
                        headNode.run(SKAction.sequence([
                            SKAction.wait(forDuration: stagger),
                            SKAction.run { [weak self] in
                                self?.spawnVisualBurst(at: headPos, color: wyrmGreenBurst, count: 8)
                            },
                            SKAction.group([
                                SKAction.fadeOut(withDuration: 0.3),
                                SKAction.scale(to: 0.85, duration: 0.3)
                            ]),
                            SKAction.run { [weak self] in
                                headNode.alpha = 1.0
                                headNode.setScale(1.0)
                                self?.nodePool.release(headNode, type: .bossMisc)
                            }
                        ]))
                        bossMechanicNodes.removeValue(forKey: headKey)
                    } else {
                        spawnVisualBurst(at: headPos, color: wyrmGreenBurst, count: 8)
                        fadeOutAndRemoveBossNode(key: headKey)
                    }
                }

                for si in 0..<swBodyCleanup {
                    let segKey = "trojanwyrm_sw_\(wi)_seg_\(si)"
                    if stagger > 0, let segNode = bossMechanicNodes[segKey] {
                        segNode.run(SKAction.sequence([
                            SKAction.wait(forDuration: stagger),
                            SKAction.group([
                                SKAction.fadeOut(withDuration: 0.3),
                                SKAction.scale(to: 0.85, duration: 0.3)
                            ]),
                            SKAction.run { [weak self] in
                                segNode.alpha = 1.0
                                segNode.setScale(1.0)
                                self?.nodePool.release(segNode, type: .bossMisc)
                            }
                        ]))
                        bossMechanicNodes.removeValue(forKey: segKey)
                    } else {
                        fadeOutAndRemoveBossNode(key: segKey)
                    }
                }
            }
        }

        renderPhaseIndicator(phase: bossState.phase, bossType: "trojanwyrm", gameState: gameState)

        // Phase 4: Render ring radius indicator
        renderTrojanWyrmRingIndicator(bossState: bossState, gameState: gameState, arenaH: arenaH)

        // Phase 4: Render aim line during aiming state with enhanced telegraph
        if bossState.phase == 4 && bossState.phase4SubState == .aiming {
            renderTrojanWyrmAimLine(bossState: bossState, gameState: gameState, boss: boss, arenaH: arenaH)
        } else {
            fadeOutAndRemoveBossNode(key: "trojanwyrm_aimline")
        }
    }

    // MARK: - Phase 2 Turret Telegraph

    /// Returns true if turrets are about to fire (within 0.3s of next fire)
    private func isTurretAboutToFire(bossState: TrojanWyrmAI.TrojanWyrmState, gameTime: Double) -> Bool {
        let timeSinceFire = gameTime - bossState.lastTurretFireTime
        let interval = BalanceConfig.TrojanWyrm.turretFireInterval
        return timeSinceFire > (interval - 0.3) && timeSinceFire <= interval
    }

    /// Returns 0→1 progress through the telegraph window (0.3s before fire)
    private func turretTelegraphProgress(bossState: TrojanWyrmAI.TrojanWyrmState, gameTime: Double) -> CGFloat {
        let timeSinceFire = gameTime - bossState.lastTurretFireTime
        let interval = BalanceConfig.TrojanWyrm.turretFireInterval
        let telegraphStart = interval - 0.3
        return min(1, max(0, CGFloat((timeSinceFire - telegraphStart) / 0.3)))
    }

    // MARK: - Phase 2→3 Split Animation

    /// Scatter body segments outward with particle bursts on Phase 2→3 transition
    private func renderTrojanWyrmSplitAnimation(bossState: TrojanWyrmAI.TrojanWyrmState, arenaH: CGFloat) {
        let centerX = bossState.arenaCenter.x
        let centerY = arenaH - bossState.arenaCenter.y
        let wyrmGreenBurst = SKColor(red: 0, green: 1, blue: 0.27, alpha: 1.0)

        for i in 0..<BalanceConfig.TrojanWyrm.segmentCount {
            let segKey = "trojanwyrm_seg_\(i)"
            guard let segNode = bossMechanicNodes.removeValue(forKey: segKey) else { continue }

            // Calculate radial vector from center
            let dx = segNode.position.x - centerX
            let dy = segNode.position.y - centerY
            let dist = max(1, hypot(dx, dy))
            let normX = dx / dist
            let normY = dy / dist
            let flyDistance: CGFloat = 80 + CGFloat.random(in: 0...40)

            let stagger = TimeInterval(i) * 0.02
            let finalPos = CGPoint(x: segNode.position.x + normX * flyDistance,
                                   y: segNode.position.y + normY * flyDistance)

            segNode.run(SKAction.sequence([
                SKAction.wait(forDuration: stagger),
                SKAction.group([
                    SKAction.move(to: finalPos, duration: 0.35),
                    SKAction.fadeOut(withDuration: 0.4),
                    SKAction.scale(to: 0.5, duration: 0.4)
                ]),
                SKAction.run { [weak self] in
                    self?.spawnVisualBurst(at: finalPos, color: wyrmGreenBurst, count: 4)
                    segNode.alpha = 1.0
                    segNode.setScale(1.0)
                    self?.nodePool.release(segNode, type: .bossMisc)
                }
            ]))
        }

        // Head scatter
        if let headNode = bossMechanicNodes.removeValue(forKey: "trojanwyrm_head") {
            let headFinal = CGPoint(x: headNode.position.x, y: headNode.position.y + 60)
            headNode.run(SKAction.sequence([
                SKAction.group([
                    SKAction.move(to: headFinal, duration: 0.3),
                    SKAction.fadeOut(withDuration: 0.35),
                    SKAction.scale(to: 0.6, duration: 0.35)
                ]),
                SKAction.run { [weak self] in
                    self?.spawnVisualBurst(at: headFinal, color: wyrmGreenBurst, count: 10)
                    headNode.alpha = 1.0
                    headNode.setScale(1.0)
                    self?.nodePool.release(headNode, type: .bossMisc)
                }
            ]))
        }
        fadeOutAndRemoveBossNode(key: "trojanwyrm_tailwisp")
    }

    // MARK: - Phase 4 Ring Indicator

    /// Dashed circle showing the constricting ring boundary with green→yellow→red color shift
    private func renderTrojanWyrmRingIndicator(bossState: TrojanWyrmAI.TrojanWyrmState, gameState: GameState, arenaH: CGFloat) {
        let ringKey = "trojanwyrm_ring"

        guard bossState.phase == 4,
              bossState.phase4SubState == .circling || bossState.phase4SubState == .aiming else {
            fadeOutAndRemoveBossNode(key: ringKey)
            return
        }

        let ringNode: SKShapeNode
        if let existing = bossMechanicNodes[ringKey] as? SKShapeNode {
            ringNode = existing
        } else {
            ringNode = SKShapeNode()
            ringNode.fillColor = .clear
            ringNode.lineWidth = 2
            ringNode.zPosition = 98
            scene?.addChild(ringNode)
            bossMechanicNodes[ringKey] = ringNode
            fadeInMechanicNode(ringNode, targetAlpha: 0.3)
        }

        // Update ring path to match current radius with dashed pattern
        let radius = bossState.ringRadius
        let dashedPath = CGMutablePath()
        let dashLength: CGFloat = 8
        let gapLength: CGFloat = 4
        let circumference = 2 * .pi * radius
        let segmentLength = dashLength + gapLength
        let segmentCount = Int(circumference / segmentLength)

        for s in 0..<segmentCount {
            let startAngle = CGFloat(s) * segmentLength / radius
            let endAngle = startAngle + dashLength / radius
            dashedPath.addArc(center: .zero, radius: radius,
                              startAngle: startAngle, endAngle: endAngle, clockwise: false)
        }
        ringNode.path = dashedPath

        // Position at ring center (drifts independently of player)
        ringNode.position = CGPoint(x: bossState.ringCenterX, y: arenaH - bossState.ringCenterY)

        // Color interpolation: green (250px) → yellow (190px) → red (130px)
        let ringColor = trojanWyrmRingColor(radius: radius)
        ringNode.strokeColor = ringColor
        ringNode.alpha = 0.3
    }

    /// Interpolate ring color based on radius: green → yellow → red
    private func trojanWyrmRingColor(radius: CGFloat) -> SKColor {
        let maxR = BalanceConfig.TrojanWyrm.ringInitialRadius  // 250
        let midR: CGFloat = 190
        let minR = BalanceConfig.TrojanWyrm.ringMinRadius      // 130

        if radius >= midR {
            // Green → Yellow
            let t = min(1, max(0, CGFloat((radius - midR) / (maxR - midR))))
            return SKColor(red: 1.0 - t, green: 1.0, blue: 0, alpha: 1.0)
        } else {
            // Yellow → Red
            let t = min(1, max(0, CGFloat((radius - minR) / (midR - minR))))
            return SKColor(red: 1.0, green: t, blue: 0, alpha: 1.0)
        }
    }

    // MARK: - Phase 4 Enhanced Aim Line

    /// Aim line with yellow→red transition, glow, and trailing particles
    private func renderTrojanWyrmAimLine(bossState: TrojanWyrmAI.TrojanWyrmState, gameState: GameState, boss: Enemy, arenaH: CGFloat) {
        let aimKey = "trojanwyrm_aimline"
        let playerPos = CGPoint(x: gameState.player.x, y: gameState.player.y)
        let headPos = CGPoint(x: boss.x, y: boss.y)

        let aimNode: SKShapeNode
        if let existing = bossMechanicNodes[aimKey] as? SKShapeNode {
            aimNode = existing
        } else {
            aimNode = SKShapeNode()
            aimNode.zPosition = 102
            scene?.addChild(aimNode)
            bossMechanicNodes[aimKey] = aimNode
            fadeInMechanicNode(aimNode)
        }

        // Yellow → Red over aim duration (1.2s)
        let aimProgress = min(1, max(0, CGFloat(bossState.aimTimer / BalanceConfig.TrojanWyrm.aimDuration)))
        let aimColor = SKColor(red: 1.0, green: 1.0 - aimProgress, blue: 0, alpha: 1.0)
        aimNode.strokeColor = aimColor
        aimNode.lineWidth = 3 + aimProgress * 2  // 3 → 5
        aimNode.glowWidth = aimProgress * 2       // 0 → 2

        let path = CGMutablePath()
        path.move(to: CGPoint(x: headPos.x, y: arenaH - headPos.y))
        path.addLine(to: CGPoint(x: playerPos.x, y: arenaH - playerPos.y))
        aimNode.path = path

        // Trailing particles along aim line (2-3 per frame, lime colored)
        let particleCount = Int.random(in: 2...3)
        for _ in 0..<particleCount {
            let t = CGFloat.random(in: 0.1...0.9)
            let px = headPos.x + (playerPos.x - headPos.x) * t
            let py = (arenaH - headPos.y) + ((arenaH - playerPos.y) - (arenaH - headPos.y)) * t
            let particlePos = CGPoint(x: px, y: py)
            spawnAimLineParticle(at: particlePos)
        }
    }

    /// Small lime particle that fades quickly along the aim line
    private func spawnAimLineParticle(at position: CGPoint) {
        guard let scene = scene else { return }
        let particle = SKShapeNode(circleOfRadius: 2)
        particle.fillColor = SKColor(red: 0.53, green: 1, blue: 0, alpha: 0.8)
        particle.strokeColor = .clear
        particle.position = position
        particle.zPosition = 101
        scene.addChild(particle)

        let drift = CGPoint(x: CGFloat.random(in: -5...5), y: CGFloat.random(in: -5...5))
        particle.run(SKAction.sequence([
            SKAction.group([
                SKAction.move(by: CGVector(dx: drift.x, dy: drift.y), duration: 0.25),
                SKAction.fadeOut(withDuration: 0.25),
                SKAction.scale(to: 0.3, duration: 0.25)
            ]),
            SKAction.removeFromParent()
        ]))
    }

    // MARK: - Per-Phase Visual Escalation

    /// Returns (fillAlphaBoost, strokeAlphaBoost, headStrokeColor) based on current phase
    private func trojanWyrmPhaseColors(phase: Int) -> (CGFloat, CGFloat, SKColor) {
        switch phase {
        case 2:
            // Phase 2: Brighter strokes, white head outline
            return (0.05, 0.2, SKColor.white)
        case 4:
            // Phase 4: Most saturated fills, white head outline
            return (0.15, 0.2, SKColor.white)
        default:
            // Phase 1: Base green (default), Phase 3: main body not rendered
            return (0.0, 0.0, SKColor.white)
        }
    }
}
