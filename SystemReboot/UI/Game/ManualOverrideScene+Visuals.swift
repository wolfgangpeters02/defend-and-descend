import SpriteKit

// MARK: - Manual Override Scene Visual Compositions
// Extracted from ManualOverrideScene to keep ManualOverrideView.swift under 800 lines.
// Provides multi-node compositions matching the TD board's visual quality:
// layered glow/body/detail nodes, compound paths, and additive blending.

extension ManualOverrideScene {

    // MARK: - Background (Circuit Board Aesthetic)

    /// Creates the full circuit board background: grid + copper traces.
    func createCircuitBackground() -> SKNode {
        let container = SKNode()
        container.zPosition = 0

        // Layer 1: Circuit grid (uses DesignSystem helper)
        let grid = SpriteKitDesign.createCircuitGridNode(size: size, gridSpacing: 40)
        container.addChild(grid)

        // Layer 2: Copper traces along play area edges
        let traces = createEdgeTraces()
        traces.zPosition = 0.5
        container.addChild(traces)

        return container
    }

    /// Starts ambient data-flow particles traveling along traces.
    func startAmbientDataFlow() {
        let spawn = SKAction.run { [weak self] in
            self?.spawnDataFlowParticle()
        }
        let wait = SKAction.wait(forDuration: BalanceConfig.ManualOverride.ambientParticleInterval)
        run(SKAction.repeatForever(SKAction.sequence([spawn, wait])), withKey: "ambientDataFlow")
    }

    private func createEdgeTraces() -> SKNode {
        let container = SKNode()
        let inset: CGFloat = 25
        let bottom: CGFloat = 110
        let top = size.height - 110

        // Left vertical trace
        let leftTrace = SpriteKitDesign.createCircuitTrace(
            from: CGPoint(x: inset, y: bottom + 20),
            to: CGPoint(x: inset, y: top - 20), width: 2)
        leftTrace.alpha = 0.4
        container.addChild(leftTrace)

        // Right vertical trace
        let rightTrace = SpriteKitDesign.createCircuitTrace(
            from: CGPoint(x: size.width - inset, y: bottom + 20),
            to: CGPoint(x: size.width - inset, y: top - 20), width: 2)
        rightTrace.alpha = 0.4
        container.addChild(rightTrace)

        // Bottom horizontal trace
        let bottomTrace = SpriteKitDesign.createCircuitTrace(
            from: CGPoint(x: inset + 20, y: bottom),
            to: CGPoint(x: size.width - inset - 20, y: bottom), width: 2)
        bottomTrace.alpha = 0.35
        container.addChild(bottomTrace)

        // Top horizontal trace
        let topTrace = SpriteKitDesign.createCircuitTrace(
            from: CGPoint(x: inset + 20, y: top),
            to: CGPoint(x: size.width - inset - 20, y: top), width: 2)
        topTrace.alpha = 0.35
        container.addChild(topTrace)

        return container
    }

    private func spawnDataFlowParticle() {
        let existing = children.filter { $0.name == "dataParticle" }.count
        guard existing < BalanceConfig.ManualOverride.maxAmbientParticles else { return }

        let dot = SKShapeNode(circleOfRadius: 1.5)
        dot.fillColor = DesignColors.primaryUI.withAlphaComponent(0.6)
        dot.strokeColor = .clear
        dot.blendMode = .add
        dot.name = "dataParticle"
        dot.zPosition = 1

        let inset: CGFloat = 25
        let bottom: CGFloat = 110
        let top = size.height - 110

        // Pick a random trace to travel along
        let traceIndex = Int.random(in: 0...3)
        let start: CGPoint
        let end: CGPoint
        switch traceIndex {
        case 0: // Left, bottom to top
            start = CGPoint(x: inset, y: bottom + 20)
            end = CGPoint(x: inset, y: top - 20)
        case 1: // Right, top to bottom
            start = CGPoint(x: size.width - inset, y: top - 20)
            end = CGPoint(x: size.width - inset, y: bottom + 20)
        case 2: // Bottom, left to right
            start = CGPoint(x: inset + 20, y: bottom)
            end = CGPoint(x: size.width - inset - 20, y: bottom)
        default: // Top, right to left
            start = CGPoint(x: size.width - inset - 20, y: top)
            end = CGPoint(x: inset + 20, y: top)
        }

        dot.position = start
        addChild(dot)

        let travel = SKAction.move(to: end, duration: TimeInterval.random(in: 2.0...3.0))
        travel.timingMode = .easeInEaseOut
        let fade = SKAction.fadeOut(withDuration: 0.3)
        dot.run(SKAction.sequence([travel, fade, SKAction.removeFromParent()]))
    }

    // MARK: - Boundary (Copper Double-Stroke Border)

    /// Creates a circuit board-themed play area border with corner solder pads.
    func createCircuitBorder() -> SKNode {
        let container = SKNode()
        container.zPosition = 1

        let playRect = CGRect(x: 20, y: 100, width: size.width - 40, height: size.height - 200)

        // Outer border - dark copper
        let outer = SKShapeNode(rect: playRect, cornerRadius: 8)
        outer.strokeColor = DesignColors.traceBorderUI.withAlphaComponent(0.6)
        outer.fillColor = .clear
        outer.lineWidth = 3
        container.addChild(outer)

        // Inner border - lighter copper
        let innerRect = playRect.insetBy(dx: 3, dy: 3)
        let inner = SKShapeNode(rect: innerRect, cornerRadius: 6)
        inner.strokeColor = DesignColors.tracePrimaryUI.withAlphaComponent(0.3)
        inner.fillColor = .clear
        inner.lineWidth = 1
        container.addChild(inner)

        // Corner solder pads (4 as compound path)
        let padRadius: CGFloat = 5
        let padPath = CGMutablePath()
        let corners = [
            CGPoint(x: playRect.minX, y: playRect.minY),
            CGPoint(x: playRect.maxX, y: playRect.minY),
            CGPoint(x: playRect.minX, y: playRect.maxY),
            CGPoint(x: playRect.maxX, y: playRect.maxY)
        ]
        for corner in corners {
            padPath.addEllipse(in: CGRect(
                x: corner.x - padRadius, y: corner.y - padRadius,
                width: padRadius * 2, height: padRadius * 2))
        }
        let pads = SKShapeNode(path: padPath)
        pads.fillColor = DesignColors.tracePrimaryUI.withAlphaComponent(0.5)
        pads.strokeColor = DesignColors.traceGlowUI.withAlphaComponent(0.3)
        pads.lineWidth = 1
        pads.zPosition = 0.5
        container.addChild(pads)

        return container
    }

    // MARK: - Player Composition (Circuit Defender)

    /// Creates a multi-node player composition: shield, glow, octagon body, core, orbit ring.
    func createPlayerComposition(at position: CGPoint) -> SKNode {
        let container = SKNode()
        container.position = position
        container.zPosition = 10
        container.name = "player"

        let bodyRadius = BalanceConfig.ManualOverride.playerBodyRadius

        // Shield aura (z: -1) — outer firewall ring
        let shield = SKShapeNode(circleOfRadius: BalanceConfig.ManualOverride.playerShieldRadius)
        shield.fillColor = .clear
        shield.strokeColor = DesignColors.primaryUI.withAlphaComponent(0.2)
        shield.lineWidth = 1.5
        shield.zPosition = -1
        shield.name = "shield"
        container.addChild(shield)

        let breathe = SKAction.sequence([
            SKAction.scale(to: 1.08, duration: 1.5),
            SKAction.scale(to: 1.0, duration: 1.5)
        ])
        breathe.timingMode = .easeInEaseOut
        shield.run(SKAction.repeatForever(breathe))

        // Glow layer (z: -0.5) — additive energy field
        let glow = SKShapeNode(circleOfRadius: BalanceConfig.ManualOverride.playerGlowRadius)
        glow.fillColor = DesignColors.primaryUI.withAlphaComponent(0.15)
        glow.strokeColor = .clear
        glow.blendMode = .add
        glow.zPosition = -0.5
        container.addChild(glow)

        let glowPulse = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.25, duration: 1.2),
            SKAction.fadeAlpha(to: 0.15, duration: 1.2)
        ])
        glow.run(SKAction.repeatForever(glowPulse))

        // Body (z: 0) — octagon
        let bodyPath = UIBezierPath()
        for i in 0..<8 {
            let angle = CGFloat(i) * .pi / 4 - .pi / 8
            let point = CGPoint(x: cos(angle) * bodyRadius, y: sin(angle) * bodyRadius)
            if i == 0 { bodyPath.move(to: point) } else { bodyPath.addLine(to: point) }
        }
        bodyPath.close()

        let body = SKShapeNode(path: bodyPath.cgPath)
        body.fillColor = DesignColors.primaryUI.withAlphaComponent(0.7)
        body.strokeColor = DesignColors.primaryUI
        body.lineWidth = 2
        body.name = "body"
        container.addChild(body)

        // Core (z: 0.5) — bright center
        let core = SKShapeNode(circleOfRadius: BalanceConfig.ManualOverride.playerCoreRadius)
        core.fillColor = UIColor.white.withAlphaComponent(0.8)
        core.strokeColor = .clear
        core.blendMode = .add
        core.zPosition = 0.5
        core.name = "core"
        container.addChild(core)

        let corePulse = SKAction.sequence([
            SKAction.scale(to: 1.2, duration: 0.6),
            SKAction.scale(to: 1.0, duration: 0.6)
        ])
        core.run(SKAction.repeatForever(corePulse))

        // Orbit ring (z: 1) — 4 rotating data dots (compound path)
        let orbitRing = SKNode()
        orbitRing.zPosition = 1
        orbitRing.name = "orbitRing"

        let dotPath = CGMutablePath()
        let dotRadius: CGFloat = 2.5
        let orbitR = BalanceConfig.ManualOverride.playerOrbitRadius
        for i in 0..<4 {
            let angle = CGFloat(i) * .pi / 2
            let cx = cos(angle) * orbitR
            let cy = sin(angle) * orbitR
            dotPath.addEllipse(in: CGRect(
                x: cx - dotRadius, y: cy - dotRadius,
                width: dotRadius * 2, height: dotRadius * 2))
        }
        let dots = SKShapeNode(path: dotPath)
        dots.fillColor = DesignColors.primaryUI.withAlphaComponent(0.6)
        dots.strokeColor = .clear
        orbitRing.addChild(dots)

        let orbit = SKAction.rotate(
            byAngle: .pi * 2,
            duration: BalanceConfig.ManualOverride.playerOrbitSpeed)
        orbitRing.run(SKAction.repeatForever(orbit))
        container.addChild(orbitRing)

        return container
    }

    /// Updates the player's visual state based on current health.
    func updatePlayerDamageState(playerNode: SKNode, health: Int, maxHealth: Int) {
        guard let body = playerNode.childNode(withName: "body") as? SKShapeNode,
              let shield = playerNode.childNode(withName: "shield") as? SKShapeNode else { return }

        let healthRatio = CGFloat(health) / CGFloat(maxHealth)

        // Body color shifts from cyan toward red as health drops
        let bodyColor: UIColor
        if healthRatio > 0.66 {
            bodyColor = DesignColors.primaryUI
        } else if healthRatio > 0.33 {
            bodyColor = DesignColors.primaryUI.blended(with: DesignColors.warningUI, ratio: 0.4)
        } else {
            bodyColor = DesignColors.primaryUI.blended(with: DesignColors.dangerUI, ratio: 0.5)
        }
        body.fillColor = bodyColor.withAlphaComponent(0.7)
        body.strokeColor = bodyColor

        // Shield weakens
        shield.strokeColor = DesignColors.primaryUI.withAlphaComponent(0.2 * healthRatio)
    }

    // MARK: - Projectile Hazard (Virus Composition)

    /// Creates a multi-node projectile virus: membrane, body, nucleus, flagella.
    func createProjectileVirusNode(at position: CGPoint) -> SKNode {
        let container = SKNode()
        container.position = position
        container.zPosition = 5
        container.name = "hazard"

        let radius = BalanceConfig.ManualOverride.hazardCollisionRadius
        let color = DesignColors.dangerUI

        // Membrane ring — outer cell wall
        let membrane = SKShapeNode(circleOfRadius: radius * 1.2)
        membrane.fillColor = .clear
        membrane.strokeColor = color.withAlphaComponent(0.25)
        membrane.lineWidth = 1
        membrane.zPosition = -0.1
        container.addChild(membrane)

        let membraneRotate = SKAction.rotate(byAngle: -.pi * 2, duration: 8.0)
        membrane.run(SKAction.repeatForever(membraneRotate))

        // Body — main circle
        let body = SKShapeNode(circleOfRadius: radius)
        body.fillColor = color
        body.strokeColor = color.darker(by: 0.3)
        body.lineWidth = 2
        body.name = "body"
        container.addChild(body)

        // Breathing pulse
        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.05, duration: 0.4),
            SKAction.scale(to: 1.0, duration: 0.4)
        ])
        body.run(SKAction.repeatForever(pulse))

        // Nucleus — inner darker core
        let nucleus = SKShapeNode(circleOfRadius: radius * 0.35)
        nucleus.fillColor = color.darker(by: 0.5)
        nucleus.strokeColor = color.withAlphaComponent(0.5)
        nucleus.lineWidth = 1
        nucleus.zPosition = 0.1
        container.addChild(nucleus)

        let nucleusRotate = SKAction.rotate(byAngle: -.pi * 2, duration: 6.0)
        nucleus.run(SKAction.repeatForever(nucleusRotate))

        // Flagella — 3 trailing tentacles (compound path)
        let flagellaPath = CGMutablePath()
        for i in 0..<3 {
            let baseAngle = CGFloat(i) * (2 * .pi / 3) + .pi
            let startR = radius * 0.8
            let endR = radius * 1.5
            let ctrlR = radius * 1.2
            let startPt = CGPoint(x: cos(baseAngle) * startR, y: sin(baseAngle) * startR)
            let endPt = CGPoint(x: cos(baseAngle) * endR, y: sin(baseAngle) * endR)
            let ctrlPt = CGPoint(x: cos(baseAngle + 0.3) * ctrlR, y: sin(baseAngle + 0.3) * ctrlR)
            flagellaPath.move(to: startPt)
            flagellaPath.addQuadCurve(to: endPt, control: ctrlPt)
        }
        let flagella = SKShapeNode(path: flagellaPath)
        flagella.strokeColor = color.withAlphaComponent(0.35)
        flagella.lineWidth = 1.5
        flagella.lineCap = .round
        flagella.zPosition = -0.2
        container.addChild(flagella)

        // Slow rotation of entire virus
        let rotate = SKAction.rotate(byAngle: .pi * 2, duration: 4.0)
        container.run(SKAction.repeatForever(rotate))

        return container
    }

    // MARK: - Expanding Hazard (Virus Infection Spread)

    /// Shows an octagonal warning with crosshair, then calls completion when done.
    func createExpandingWarning(at position: CGPoint, completion: @escaping () -> Void) {
        let warningContainer = SKNode()
        warningContainer.position = position
        warningContainer.zPosition = 4
        addChild(warningContainer)

        let color = DesignColors.warningUI
        let warningRadius: CGFloat = 30

        // Octagonal warning shape
        let octPath = UIBezierPath()
        for i in 0..<8 {
            let angle = CGFloat(i) * .pi / 4 - .pi / 8
            let point = CGPoint(x: cos(angle) * warningRadius, y: sin(angle) * warningRadius)
            if i == 0 { octPath.move(to: point) } else { octPath.addLine(to: point) }
        }
        octPath.close()

        let octShape = SKShapeNode(path: octPath.cgPath)
        octShape.strokeColor = color
        octShape.fillColor = color.withAlphaComponent(0.1)
        octShape.lineWidth = 2
        warningContainer.addChild(octShape)

        // Crosshair inside (compound path)
        let crossPath = CGMutablePath()
        let crossLen = warningRadius * 0.5
        crossPath.move(to: CGPoint(x: 0, y: crossLen))
        crossPath.addLine(to: CGPoint(x: 0, y: -crossLen))
        crossPath.move(to: CGPoint(x: -crossLen, y: 0))
        crossPath.addLine(to: CGPoint(x: crossLen, y: 0))
        let cross = SKShapeNode(path: crossPath)
        cross.strokeColor = color.withAlphaComponent(0.4)
        cross.lineWidth = 1
        warningContainer.addChild(cross)

        // 3 rapid pulses then remove
        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.15, duration: 0.2),
            SKAction.scale(to: 1.0, duration: 0.2)
        ])
        warningContainer.run(SKAction.repeat(pulse, count: 3)) {
            warningContainer.removeFromParent()
            completion()
        }
    }

    /// Creates a multi-node expanding hazard: corruption ring, body, glitch overlay.
    func createExpandingHazardNode(at position: CGPoint) -> SKNode {
        let container = SKNode()
        container.position = position
        container.zPosition = 5
        container.name = "hazard"

        let color = DesignColors.dangerUI

        // Corruption ring — tracks expanding radius + 3pt
        let ring = SKShapeNode(circleOfRadius: 8) // will be updated per frame
        ring.fillColor = .clear
        ring.strokeColor = color.withAlphaComponent(0.2)
        ring.lineWidth = 1
        ring.zPosition = -0.1
        ring.name = "corruptionRing"
        container.addChild(ring)

        // Body — growing circle
        let body = SKShapeNode(circleOfRadius: 5) // will be updated per frame
        body.fillColor = color.withAlphaComponent(0.6)
        body.strokeColor = color
        body.lineWidth = 2
        body.name = "body"
        container.addChild(body)

        // Glitch overlay — jittering band
        let glitch = SKShapeNode(rectOf: CGSize(width: 10, height: 2))
        glitch.fillColor = color.withAlphaComponent(0.12)
        glitch.strokeColor = color.withAlphaComponent(0.25)
        glitch.lineWidth = 1
        glitch.zPosition = 0.2
        glitch.name = "glitchOverlay"
        container.addChild(glitch)

        // Glitch jitter animation
        let jitter = SKAction.repeatForever(SKAction.sequence([
            SKAction.run {
                glitch.position = CGPoint(
                    x: CGFloat.random(in: -3...3),
                    y: CGFloat.random(in: -3...3))
                glitch.alpha = CGFloat.random(in: 0.1...0.35)
            },
            SKAction.wait(forDuration: 0.12),
            SKAction.run {
                glitch.position = .zero
                glitch.alpha = 0.15
            },
            SKAction.wait(forDuration: TimeInterval.random(in: 0.2...0.4))
        ]))
        glitch.run(jitter)

        return container
    }

    /// Updates expanding hazard child nodes to match current radius.
    func updateExpandingHazardVisuals(node: SKNode, currentRadius: CGFloat) {
        if let ring = node.childNode(withName: "corruptionRing") as? SKShapeNode {
            let ringR = currentRadius + 3
            ring.path = CGPath(
                ellipseIn: CGRect(x: -ringR, y: -ringR, width: ringR * 2, height: ringR * 2),
                transform: nil)
        }
        if let body = node.childNode(withName: "body") as? SKShapeNode {
            body.path = CGPath(
                ellipseIn: CGRect(x: -currentRadius, y: -currentRadius,
                                  width: currentRadius * 2, height: currentRadius * 2),
                transform: nil)
        }
        if let glitch = node.childNode(withName: "glitchOverlay") as? SKShapeNode {
            let w = max(currentRadius * 0.8, 4)
            let h = max(currentRadius * 0.15, 2)
            glitch.path = CGPath(rect: CGRect(x: -w / 2, y: -h / 2, width: w, height: h), transform: nil)
        }
    }

    // MARK: - Sweep Hazard (Firewall Scan Line)

    /// Creates a multi-node sweep: scan line, leading edge, gap indicator.
    func createSweepScanNode(
        hazard: ManualOverrideSystem.Hazard,
        sceneSize: CGSize
    ) -> SKNode {
        guard case .sweep(_, let isHorizontal, let gapStart, let gapEnd) = hazard.kind else {
            return SKNode()
        }

        let container = SKNode()
        container.position = hazard.position
        container.zPosition = 5
        container.name = "hazard"

        let color = DesignColors.dangerUI

        // Scan line (two segments with gap)
        let linePath = CGMutablePath()
        if isHorizontal {
            linePath.move(to: CGPoint(x: 0, y: 0))
            linePath.addLine(to: CGPoint(x: gapStart, y: 0))
            linePath.move(to: CGPoint(x: gapEnd, y: 0))
            linePath.addLine(to: CGPoint(x: sceneSize.width, y: 0))
        } else {
            let playAreaBottom: CGFloat = 120
            let playAreaTop = sceneSize.height - 120
            linePath.move(to: CGPoint(x: 0, y: playAreaBottom))
            linePath.addLine(to: CGPoint(x: 0, y: gapStart))
            linePath.move(to: CGPoint(x: 0, y: gapEnd))
            linePath.addLine(to: CGPoint(x: 0, y: playAreaTop))
        }
        let scanLine = SKShapeNode(path: linePath)
        scanLine.strokeColor = color.withAlphaComponent(0.7)
        scanLine.lineWidth = 6
        scanLine.glowWidth = 3
        scanLine.name = "scanLine"
        container.addChild(scanLine)

        // Leading edge — bright white bar at front of sweep
        let edgeLength: CGFloat = 15
        let edgePath = CGMutablePath()
        if isHorizontal {
            edgePath.move(to: CGPoint(x: 0, y: -edgeLength / 2))
            edgePath.addLine(to: CGPoint(x: 0, y: edgeLength / 2))
        } else {
            edgePath.move(to: CGPoint(x: -edgeLength / 2, y: 0))
            edgePath.addLine(to: CGPoint(x: edgeLength / 2, y: 0))
        }
        let leadingEdge = SKShapeNode(path: edgePath)
        leadingEdge.strokeColor = UIColor.white.withAlphaComponent(0.8)
        leadingEdge.lineWidth = 5
        leadingEdge.blendMode = .add
        leadingEdge.zPosition = 0.5
        leadingEdge.name = "leadingEdge"
        // Position at the gap center for visibility
        if isHorizontal {
            leadingEdge.position = CGPoint(x: (gapStart + gapEnd) / 2, y: 0)
        } else {
            leadingEdge.position = CGPoint(x: 0, y: (gapStart + gapEnd) / 2)
        }
        container.addChild(leadingEdge)

        // Gap indicator — green safe zone highlight
        let gapWidth = gapEnd - gapStart
        let gapNode: SKShapeNode
        if isHorizontal {
            gapNode = SKShapeNode(rectOf: CGSize(width: gapWidth, height: 20), cornerRadius: 3)
            gapNode.position = CGPoint(x: (gapStart + gapEnd) / 2, y: 0)
        } else {
            gapNode = SKShapeNode(rectOf: CGSize(width: 20, height: gapWidth), cornerRadius: 3)
            gapNode.position = CGPoint(x: 0, y: (gapStart + gapEnd) / 2)
        }
        gapNode.fillColor = DesignColors.successUI.withAlphaComponent(0.1)
        gapNode.strokeColor = DesignColors.successUI.withAlphaComponent(0.3)
        gapNode.lineWidth = 1
        gapNode.zPosition = 1
        gapNode.name = "gapIndicator"
        container.addChild(gapNode)

        return container
    }

    // MARK: - Damage Effects

    /// Plays upgraded damage effects: particle burst + screen glitch + red flash.
    func playUpgradedDamageEffects(playerPosition: CGPoint) {
        HapticsService.shared.play(.warning)

        // 1. Particle burst — scatter fragments from player
        spawnDamageFragments(at: playerPosition)

        // 2. Screen glitch — horizontal white bars flashing
        playScreenGlitch()

        // 3. Red flash overlay (dimmer than before)
        let flash = SKShapeNode(rect: CGRect(origin: .zero, size: size))
        flash.fillColor = UIColor.red.withAlphaComponent(0.2)
        flash.strokeColor = .clear
        flash.zPosition = 100
        flash.position = .zero
        addChild(flash)
        flash.run(SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.3),
            SKAction.removeFromParent()
        ]))

        // 4. Camera shake + zoom punch
        let shake = SKAction.sequence([
            SKAction.moveBy(x: 8, y: 0, duration: 0.04),
            SKAction.moveBy(x: -16, y: 0, duration: 0.04),
            SKAction.moveBy(x: 12, y: 0, duration: 0.04),
            SKAction.moveBy(x: -8, y: 0, duration: 0.04),
            SKAction.moveBy(x: 4, y: 0, duration: 0.04)
        ])
        let zoomPunch = SKAction.sequence([
            SKAction.scale(to: 1.02, duration: 0.06),
            SKAction.scale(to: 1.0, duration: 0.09)
        ])
        camera?.run(SKAction.group([shake, zoomPunch]))
    }

    private func spawnDamageFragments(at position: CGPoint) {
        let count = BalanceConfig.ManualOverride.damageFragmentCount
        let color = DesignColors.dangerUI

        for i in 0..<count {
            let angle = CGFloat(i) * (2 * .pi / CGFloat(count)) + CGFloat.random(in: -0.3...0.3)
            let frag = SKShapeNode(circleOfRadius: CGFloat.random(in: 2...4))
            frag.fillColor = color
            frag.strokeColor = .clear
            frag.position = position
            frag.zPosition = 50
            addChild(frag)

            let speed: CGFloat = 60
            let move = SKAction.moveBy(x: cos(angle) * speed, y: sin(angle) * speed, duration: 0.35)
            move.timingMode = .easeOut
            let fade = SKAction.fadeOut(withDuration: 0.35)
            let scale = SKAction.scale(to: 0.3, duration: 0.35)
            frag.run(SKAction.sequence([
                SKAction.group([move, fade, scale]),
                SKAction.removeFromParent()
            ]))
        }
    }

    private func playScreenGlitch() {
        let glitchAction = SKAction.repeat(SKAction.sequence([
            SKAction.run { [weak self] in
                guard let self else { return }
                for _ in 0..<3 {
                    let barHeight = CGFloat.random(in: 3...8)
                    let bar = SKShapeNode(rectOf: CGSize(width: self.size.width, height: barHeight))
                    bar.fillColor = UIColor.white.withAlphaComponent(0.15)
                    bar.strokeColor = .clear
                    bar.position = CGPoint(
                        x: self.size.width / 2,
                        y: CGFloat.random(in: 0...self.size.height))
                    bar.zPosition = 99
                    bar.name = "glitchBar"
                    self.addChild(bar)
                }
            },
            SKAction.wait(forDuration: 0.05),
            SKAction.run { [weak self] in
                self?.children.filter { $0.name == "glitchBar" }.forEach { $0.removeFromParent() }
            },
            SKAction.wait(forDuration: 0.05)
        ]), count: 3)
        run(glitchAction)
    }

    // MARK: - Hazard Removal Animations

    /// Projectile pop: scale up briefly, then shrink + fade.
    func animateProjectileRemoval(_ node: SKNode) {
        let pop = SKAction.scale(to: 1.3, duration: 0.04)
        pop.timingMode = .easeOut
        let shrink = SKAction.scale(to: 0, duration: 0.1)
        shrink.timingMode = .easeIn
        let fade = SKAction.fadeOut(withDuration: 0.1)
        node.run(SKAction.sequence([
            pop,
            SKAction.group([shrink, fade]),
            SKAction.removeFromParent()
        ]))
    }

    /// Expanding collapse: shrink + scatter 4 small fragments.
    func animateExpandingRemoval(_ node: SKNode) {
        // Scatter fragments
        let color = DesignColors.dangerUI
        for i in 0..<4 {
            let angle = CGFloat(i) * (.pi / 2) + CGFloat.random(in: -0.3...0.3)
            let frag = SKShapeNode(circleOfRadius: 2)
            frag.fillColor = color.withAlphaComponent(0.5)
            frag.strokeColor = .clear
            frag.position = node.position
            frag.zPosition = 50
            node.parent?.addChild(frag)

            let move = SKAction.moveBy(x: cos(angle) * 30, y: sin(angle) * 30, duration: 0.25)
            move.timingMode = .easeOut
            frag.run(SKAction.sequence([
                SKAction.group([move, SKAction.fadeOut(withDuration: 0.25)]),
                SKAction.removeFromParent()
            ]))
        }

        // Shrink main node
        let shrink = SKAction.scale(to: 0, duration: 0.2)
        node.run(SKAction.sequence([shrink, SKAction.removeFromParent()]))
    }

    /// Sweep flash: brightness pulse then fade.
    func animateSweepRemoval(_ node: SKNode) {
        let flashUp = SKAction.fadeAlpha(to: 1.0, duration: 0.04)
        let fadeOut = SKAction.fadeOut(withDuration: 0.15)
        node.run(SKAction.sequence([flashUp, fadeOut, SKAction.removeFromParent()]))
    }
}
