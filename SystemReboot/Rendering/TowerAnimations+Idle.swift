import SpriteKit
import UIKit

// MARK: - Idle Animations

extension TowerAnimations {

    /// Updated by the scene each frame for zoom-based particle gating
    static var currentCameraScale: CGFloat = 1.0

    // MARK: - Start Idle Animation

    static func startIdleAnimation(node: SKNode, archetype: TowerVisualFactory.TowerArchetype, color: UIColor) {
        // Core glow pulse (all towers)
        startCorePulse(node: node, color: color, archetype: archetype)

        // Archetype-specific idle animations
        switch archetype {
        case .scanner:
            startReticleIdleAnimation(node: node, color: color)
        case .payload:
            startArtilleryIdleAnimation(node: node, color: color)
        case .cryowall:
            startFrostIdleAnimation(node: node, color: color)
        case .rootkit:
            startBeamIdleAnimation(node: node, color: color)
        case .overload:
            startTeslaIdleAnimation(node: node, color: color)
        case .forkbomb:
            startMultishotIdleAnimation(node: node, color: color)
        case .exception:
            startExecuteIdleAnimation(node: node, color: color)
        }

        // Merge indicator pulse (all towers)
        startMergeIndicatorPulse(node: node)
    }

    // MARK: - Core Pulse Animation

    private static func startCorePulse(node: SKNode, color: UIColor, archetype: TowerVisualFactory.TowerArchetype) {
        // Single glow pulse (Performance: collapsed from 3 separate animations)
        if let glow = node.childNode(withName: "glow") {
            let pulseOut = SKAction.group([
                SKAction.scale(to: 1.08, duration: 1.5),
                SKAction.fadeAlpha(to: 0.7, duration: 1.5)
            ])
            let pulseIn = SKAction.group([
                SKAction.scale(to: 1.0, duration: 1.5),
                SKAction.fadeAlpha(to: 1.0, duration: 1.5)
            ])
            pulseOut.timingMode = .easeInEaseOut
            pulseIn.timingMode = .easeInEaseOut
            glow.run(SKAction.repeatForever(SKAction.sequence([pulseOut, pulseIn])), withKey: AnimationKey.idlePulse)
        }
    }

    // MARK: - Projectile (Reticle) Idle

    private static func startReticleIdleAnimation(node: SKNode, color: UIColor) {
        guard let body = node.childNode(withName: "body") as? SKShapeNode else { return }

        // Outer ring slow rotation
        if let outerRing = body.childNode(withName: "outerRing") as? SKShapeNode {
            let rotate = SKAction.rotate(byAngle: .pi * 2, duration: 12)
            outerRing.run(SKAction.repeatForever(rotate), withKey: AnimationKey.idleRotation)
        }

        // Corner brackets pulse inward/outward
        for i in 0..<4 {
            if let bracket = body.childNode(withName: "bracket_\(i)") {
                let originalScale = bracket.xScale
                let pulseIn = SKAction.scale(to: originalScale * 0.9, duration: 0.8)
                let pulseOut = SKAction.scale(to: originalScale, duration: 0.8)
                pulseIn.timingMode = .easeInEaseOut
                pulseOut.timingMode = .easeInEaseOut

                let delay = SKAction.wait(forDuration: Double(i) * 0.15)
                let pulse = SKAction.repeatForever(SKAction.sequence([pulseIn, pulseOut]))
                bracket.run(SKAction.sequence([delay, pulse]), withKey: AnimationKey.bracketPulse)
            }
        }

        // Center dot glow pulse
        if let centerDot = body.childNode(withName: "centerDot") as? SKShapeNode {
            let pulse = SKAction.repeatForever(SKAction.sequence([
                SKAction.fadeAlpha(to: 1.0, duration: 0.6),
                SKAction.fadeAlpha(to: 0.5, duration: 0.6)
            ]))
            centerDot.run(pulse)
        }
    }

    // MARK: - Artillery Idle

    private static func startArtilleryIdleAnimation(node: SKNode, color: UIColor) {
        guard let body = node.childNode(withName: "body") as? SKShapeNode else { return }

        // Ammo glow pulse
        if let ammoGlow = body.childNode(withName: "ammoGlow") as? SKShapeNode {
            let pulse = SKAction.repeatForever(SKAction.sequence([
                SKAction.group([
                    SKAction.scale(to: 1.2, duration: 0.8),
                    SKAction.fadeAlpha(to: 0.7, duration: 0.8)
                ]),
                SKAction.group([
                    SKAction.scale(to: 1.0, duration: 0.8),
                    SKAction.fadeAlpha(to: 1.0, duration: 0.8)
                ])
            ]))
            ammoGlow.run(pulse)
        }

        // Subtle barrel sway
        if let barrel = node.childNode(withName: "barrel") {
            let sway = SKAction.repeatForever(SKAction.sequence([
                SKAction.rotate(toAngle: 0.03, duration: 2.0),
                SKAction.rotate(toAngle: -0.03, duration: 2.0)
            ]))
            barrel.run(sway, withKey: AnimationKey.idleFloat)
        }

        // Corner bolts pulse (batched node)
        if let platform = node.childNode(withName: "basePlatform"),
           let bolts = platform.childNode(withName: "bolts") as? SKShapeNode {
            let pulse = SKAction.repeatForever(SKAction.sequence([
                SKAction.fadeAlpha(to: 0.6, duration: 0.3),
                SKAction.fadeAlpha(to: 1.0, duration: 0.3),
                SKAction.wait(forDuration: 1.0)
            ]))
            bolts.run(pulse)
        }
    }

    // MARK: - Frost Idle

    private static func startFrostIdleAnimation(node: SKNode, color: UIColor) {
        // Orbiting ice shards
        if let details = node.childNode(withName: "details") {
            for i in 0..<3 {
                if let shard = details.childNode(withName: "iceShard_\(i)") {
                    let duration: TimeInterval = 6.0 + Double(i) * 0.5
                    let orbit = SKAction.repeatForever(SKAction.rotate(byAngle: .pi * 2, duration: duration))
                    shard.run(orbit, withKey: AnimationKey.orbiting)

                    // Individual shard float
                    let float = SKAction.repeatForever(SKAction.sequence([
                        SKAction.moveBy(x: 0, y: 2, duration: 1.0),
                        SKAction.moveBy(x: 0, y: -2, duration: 1.0)
                    ]))
                    shard.run(float, withKey: AnimationKey.idleFloat)
                }
            }
        }

        // Frost particle spawning
        startFrostParticleEmission(node: node, color: color)

        // Crystal body shimmer
        if let body = node.childNode(withName: "body") as? SKShapeNode {
            let shimmer = SKAction.repeatForever(SKAction.sequence([
                SKAction.fadeAlpha(to: 0.7, duration: 0.5),
                SKAction.fadeAlpha(to: 1.0, duration: 0.5)
            ]))
            body.run(shimmer)
        }

        // Crystal barrel tip pulse
        if let barrel = node.childNode(withName: "barrel") {
            for child in barrel.children {
                if let shape = child as? SKShapeNode {
                    let pulse = SKAction.repeatForever(SKAction.sequence([
                        SKAction.fadeAlpha(to: 0.6, duration: 0.4),
                        SKAction.fadeAlpha(to: 1.0, duration: 0.4)
                    ]))
                    shape.run(pulse)
                }
            }
        }
    }

    private static func startFrostParticleEmission(node: SKNode, color: UIColor) {
        let emitParticle = SKAction.run { [weak node] in
            guard let node = node else { return }
            guard TowerAnimations.currentCameraScale < 0.5 else { return }

            let particle = SKShapeNode(circleOfRadius: CGFloat.random(in: 1...2))
            particle.fillColor = UIColor.cyan.withAlphaComponent(0.7)
            particle.strokeColor = .clear
            particle.glowWidth = 0
            particle.blendMode = .add

            let angle = CGFloat.random(in: 0...(.pi * 2))
            let radius = CGFloat.random(in: 8...18)
            particle.position = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
            particle.zPosition = 5

            let rise = SKAction.moveBy(x: CGFloat.random(in: -5...5), y: CGFloat.random(in: 15...25), duration: 1.5)
            let fade = SKAction.fadeOut(withDuration: 1.5)
            let scale = SKAction.scale(to: 0.3, duration: 1.5)

            particle.run(SKAction.sequence([
                SKAction.group([rise, fade, scale]),
                SKAction.removeFromParent()
            ]))

            node.addChild(particle)
        }

        let wait = SKAction.wait(forDuration: 0.3, withRange: 0.2)
        node.run(SKAction.repeatForever(SKAction.sequence([emitParticle, wait])), withKey: AnimationKey.frostParticles)
    }

    // MARK: - Beam (Tech Emitter) Idle

    private static func startBeamIdleAnimation(node: SKNode, color: UIColor) {
        guard let body = node.childNode(withName: "body") as? SKShapeNode else { return }

        // Lens pulse
        if let lens = body.childNode(withName: "lens") as? SKShapeNode {
            let pulse = SKAction.repeatForever(SKAction.sequence([
                SKAction.group([
                    SKAction.scale(to: 1.1, duration: 0.8),
                    SKAction.fadeAlpha(to: 0.7, duration: 0.8)
                ]),
                SKAction.group([
                    SKAction.scale(to: 1.0, duration: 0.8),
                    SKAction.fadeAlpha(to: 1.0, duration: 0.8)
                ])
            ]))
            lens.run(pulse)
        }

        // Capacitor charging pulse (batched node)
        if let platform = node.childNode(withName: "basePlatform"),
           let capacitors = platform.childNode(withName: "capacitors") as? SKShapeNode {
            let charge = SKAction.repeatForever(SKAction.sequence([
                SKAction.run { capacitors.fillColor = color.lighter(by: 0.3) },
                SKAction.wait(forDuration: 0.3),
                SKAction.run { capacitors.fillColor = color.withAlphaComponent(0.5) },
                SKAction.wait(forDuration: 1.3)
            ]))
            capacitors.run(charge)
        }

        // Barrel focus lens glow
        if let barrel = node.childNode(withName: "barrel") {
            if let focusLens = barrel.childNode(withName: "focusLens") as? SKShapeNode {
                let pulse = SKAction.repeatForever(SKAction.sequence([
                    SKAction.fadeAlpha(to: 0.6, duration: 0.6),
                    SKAction.fadeAlpha(to: 1.0, duration: 0.6)
                ]))
                focusLens.run(pulse)
            }
        }
    }

    // MARK: - Tesla Idle

    private static func startTeslaIdleAnimation(node: SKNode, color: UIColor) {
        guard let body = node.childNode(withName: "body") as? SKShapeNode else { return }

        // Conductor pulse
        if let conductor = body.childNode(withName: "conductor") as? SKShapeNode {
            let pulse = SKAction.repeatForever(SKAction.sequence([
                SKAction.fadeAlpha(to: 0.6, duration: 0.3),
                SKAction.fadeAlpha(to: 1.0, duration: 0.3)
            ]))
            conductor.run(pulse)
        }

        // Discharge node random arcs
        startElectricArcAnimation(node: node, body: body, color: color)

        // Tesla sphere crackle
        if let barrel = node.childNode(withName: "barrel") {
            if let sphere = barrel.childNode(withName: "teslaSphere") as? SKShapeNode {
                let crackle = SKAction.repeatForever(SKAction.sequence([
                    SKAction.fadeAlpha(to: 1.0, duration: 0.1),
                    SKAction.fadeAlpha(to: 0.5, duration: 0.1),
                    SKAction.wait(forDuration: 0.3)
                ]))
                sphere.run(crackle)
            }
        }
    }

    /// Number of reusable arc nodes per Tesla tower
    private static let teslaArcPoolSize = 3

    private static func startElectricArcAnimation(node: SKNode, body: SKShapeNode, color: UIColor) {
        // Pre-create reusable arc nodes (pooled, avoids per-flash allocation)
        var arcPool: [SKShapeNode] = []
        for i in 0..<teslaArcPoolSize {
            let arc = SKShapeNode()
            arc.strokeColor = UIColor.cyan.withAlphaComponent(0.8)
            arc.lineWidth = 1.5
            arc.glowWidth = 0
            arc.blendMode = .add
            arc.zPosition = 4
            arc.alpha = 0
            arc.name = "arcPool_\(i)"
            body.addChild(arc)
            arcPool.append(arc)
        }

        var arcIndex = 0
        let createArc = SKAction.run { [weak body] in
            guard let body = body else { return }
            guard TowerAnimations.currentCameraScale < 0.5 else { return }

            // Pick two random discharge nodes
            let node1 = Int.random(in: 0..<4)
            var node2 = Int.random(in: 0..<4)
            while node2 == node1 { node2 = Int.random(in: 0..<4) }

            guard let discharge1 = body.childNode(withName: "dischargeNode_\(node1)"),
                  let discharge2 = body.childNode(withName: "dischargeNode_\(node2)") else { return }

            // Reuse pooled arc node (round-robin)
            guard let arc = body.childNode(withName: "arcPool_\(arcIndex % teslaArcPoolSize)") as? SKShapeNode else { return }
            arcIndex += 1

            // Update path and flash
            arc.path = createLightningPath(from: discharge1.position, to: discharge2.position)
            arc.removeAllActions()
            arc.alpha = 1.0
            arc.run(SKAction.sequence([
                SKAction.wait(forDuration: 0.05),
                SKAction.fadeOut(withDuration: 0.1)
            ]))
        }

        let wait = SKAction.wait(forDuration: 0.3, withRange: 0.4)
        node.run(SKAction.repeatForever(SKAction.sequence([createArc, wait])), withKey: AnimationKey.electricArcs)
    }

    private static func createLightningPath(from start: CGPoint, to end: CGPoint) -> CGPath {
        let path = UIBezierPath()
        path.move(to: start)

        let segments = 4
        let dx = (end.x - start.x) / CGFloat(segments)
        let dy = (end.y - start.y) / CGFloat(segments)

        for i in 1..<segments {
            let baseX = start.x + dx * CGFloat(i)
            let baseY = start.y + dy * CGFloat(i)
            let offset = CGFloat.random(in: -4...4)
            path.addLine(to: CGPoint(x: baseX + offset, y: baseY + offset))
        }

        path.addLine(to: end)
        return path.cgPath
    }

    // MARK: - Multishot Idle

    private static func startMultishotIdleAnimation(node: SKNode, color: UIColor) {
        guard let body = node.childNode(withName: "body") as? SKShapeNode else { return }

        // Hub pulse
        if let hub = body.childNode(withName: "hub") as? SKShapeNode {
            let pulse = SKAction.repeatForever(SKAction.sequence([
                SKAction.group([
                    SKAction.scale(to: 1.1, duration: 0.6),
                    SKAction.fadeAlpha(to: 0.7, duration: 0.6)
                ]),
                SKAction.group([
                    SKAction.scale(to: 1.0, duration: 0.6),
                    SKAction.fadeAlpha(to: 1.0, duration: 0.6)
                ])
            ]))
            hub.run(pulse)
        }

        // Process nodes sequence pulse
        for i in 0..<5 {
            if let processNode = body.childNode(withName: "processNode_\(i)") as? SKShapeNode {
                let delay = Double(i) * 0.2
                let pulse = SKAction.sequence([
                    SKAction.wait(forDuration: delay),
                    SKAction.repeatForever(SKAction.sequence([
                        SKAction.run {
                            processNode.fillColor = color
                        },
                        SKAction.wait(forDuration: 0.15),
                        SKAction.run {
                            processNode.fillColor = color.withAlphaComponent(0.7)
                        },
                        SKAction.wait(forDuration: 0.85)
                    ]))
                ])
                processNode.run(pulse)
            }
        }

        // Data flow along connections
        startDataFlowAnimation(node: node, body: body, color: color)
    }

    private static func startDataFlowAnimation(node: SKNode, body: SKShapeNode, color: UIColor) {
        let createDot = SKAction.run { [weak body] in
            guard let body = body else { return }
            guard TowerAnimations.currentCameraScale < 0.5 else { return }

            let nodeIndex = Int.random(in: 0..<5)
            guard let processNode = body.childNode(withName: "processNode_\(nodeIndex)") else { return }

            let dot = SKShapeNode(circleOfRadius: 2)
            dot.fillColor = color.lighter(by: 0.3)
            dot.strokeColor = .clear
            dot.glowWidth = 0
            dot.blendMode = .add
            dot.position = .zero
            dot.zPosition = 3

            let targetPos = processNode.position
            let move = SKAction.move(to: targetPos, duration: 0.4)
            move.timingMode = .easeIn

            dot.run(SKAction.sequence([
                move,
                SKAction.fadeOut(withDuration: 0.1),
                SKAction.removeFromParent()
            ]))

            body.addChild(dot)
        }

        let wait = SKAction.wait(forDuration: 0.3, withRange: 0.2)
        node.run(SKAction.repeatForever(SKAction.sequence([createDot, wait])), withKey: AnimationKey.dataFlow)
    }

    // MARK: - Execute Idle

    private static func startExecuteIdleAnimation(node: SKNode, color: UIColor) {
        guard let body = node.childNode(withName: "body") as? SKShapeNode else { return }

        // Warning triangle pulse
        if let triangle = body.childNode(withName: "warningTriangle") as? SKShapeNode {
            let pulse = SKAction.repeatForever(SKAction.sequence([
                SKAction.fadeAlpha(to: 1.0, duration: 0.3),
                SKAction.fadeAlpha(to: 0.5, duration: 0.7)
            ]))
            triangle.run(pulse)
        }

        // Exclamation blink
        if let exclamation = body.childNode(withName: "exclamation") as? SKLabelNode {
            let blink = SKAction.repeatForever(SKAction.sequence([
                SKAction.fadeAlpha(to: 0.3, duration: 0.2),
                SKAction.fadeAlpha(to: 1.0, duration: 0.2),
                SKAction.wait(forDuration: 0.6)
            ]))
            exclamation.run(blink)
        }

        // Glitch effect
        startGlitchAnimation(node: node, body: body)

        // Falling code particles
        startCodeParticleEmission(node: node)
    }

    private static func startGlitchAnimation(node: SKNode, body: SKShapeNode) {
        let jitter = SKAction.run { [weak body] in
            guard let body = body else { return }
            body.position = CGPoint(
                x: CGFloat.random(in: -2...2),
                y: CGFloat.random(in: -2...2)
            )
        }
        let reset = SKAction.run { [weak body] in
            body?.position = .zero
        }
        let glitch = SKAction.sequence([jitter, SKAction.wait(forDuration: 0.05), reset])
        let wait = SKAction.wait(forDuration: 0.5, withRange: 0.8)
        node.run(SKAction.repeatForever(SKAction.sequence([glitch, wait])), withKey: AnimationKey.glitchEffect)
    }

    private static func startCodeParticleEmission(node: SKNode) {
        let emitCode = SKAction.run { [weak node] in
            guard let node = node else { return }
            guard TowerAnimations.currentCameraScale < 0.5 else { return }

            let codeChars = ["0", "1", "!", "?", "#", "@", "%"]
            let code = SKLabelNode(text: codeChars.randomElement() ?? "0")
            code.fontName = "Menlo"
            code.fontSize = 8
            code.fontColor = UIColor(hex: "ef4444")?.withAlphaComponent(0.7) ?? .red.withAlphaComponent(0.7)
            code.position = CGPoint(
                x: CGFloat.random(in: -15...15),
                y: CGFloat.random(in: 10...20)
            )
            code.zPosition = 4

            let fall = SKAction.moveBy(x: CGFloat.random(in: -5...5), y: -30, duration: 1.5)
            let fade = SKAction.fadeOut(withDuration: 1.5)

            code.run(SKAction.sequence([
                SKAction.group([fall, fade]),
                SKAction.removeFromParent()
            ]))

            node.addChild(code)
        }

        let wait = SKAction.wait(forDuration: 0.25, withRange: 0.15)
        node.run(SKAction.repeatForever(SKAction.sequence([emitCode, wait])), withKey: "codeParticles")
    }

    // MARK: - Merge Indicator Pulse

    private static func startMergeIndicatorPulse(node: SKNode) {
        guard let starIndicator = node.childNode(withName: "starIndicator") else { return }

        let pulse = SKAction.repeatForever(SKAction.sequence([
            SKAction.scale(to: 1.15, duration: 0.5),
            SKAction.scale(to: 1.0, duration: 0.5)
        ]))
        pulse.timingMode = .easeInEaseOut
        starIndicator.run(pulse, withKey: "starPulse")
    }
}
