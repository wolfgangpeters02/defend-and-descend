import SpriteKit
import UIKit

// MARK: - Tower Animation System
// Rich, multi-stage animations for AAA tower visuals

final class TowerAnimations {

    // MARK: - Animation State

    enum TowerState {
        case idle
        case targeting
        case charging
        case firing
        case cooldown
    }

    // MARK: - Animation Keys

    private enum AnimationKey {
        static let idlePulse = "idlePulse"
        static let idleRotation = "idleRotation"
        static let idleFloat = "idleFloat"
        static let orbiting = "orbiting"
        static let electricArcs = "electricArcs"
        static let frostParticles = "frostParticles"
        static let divineParticles = "divineParticles"
        static let glitchEffect = "glitchEffect"
        static let bracketPulse = "bracketPulse"
        static let flameFlicker = "flameFlicker"
        static let dataFlow = "dataFlow"
        static let runeOrbit = "runeOrbit"
    }

    // MARK: - Start Idle Animation

    static func startIdleAnimation(node: SKNode, archetype: TowerVisualFactory.TowerArchetype, color: UIColor) {
        // Core glow pulse (all towers)
        startCorePulse(node: node, color: color, archetype: archetype)

        // Archetype-specific idle animations
        switch archetype {
        case .projectile:
            startReticleIdleAnimation(node: node, color: color)
        case .artillery:
            startArtilleryIdleAnimation(node: node, color: color)
        case .frost:
            startFrostIdleAnimation(node: node, color: color)
        case .magic:
            startMagicIdleAnimation(node: node, color: color)
        case .beam:
            startBeamIdleAnimation(node: node, color: color)
        case .tesla:
            startTeslaIdleAnimation(node: node, color: color)
        case .pyro:
            startPyroIdleAnimation(node: node, color: color)
        case .legendary:
            startLegendaryIdleAnimation(node: node, color: color)
        case .multishot:
            startMultishotIdleAnimation(node: node, color: color)
        case .execute:
            startExecuteIdleAnimation(node: node, color: color)
        }

        // Merge indicator pulse (all towers)
        startMergeIndicatorPulse(node: node)
    }

    // MARK: - Core Pulse Animation

    private static func startCorePulse(node: SKNode, color: UIColor, archetype: TowerVisualFactory.TowerArchetype) {
        // Outer glow breathing
        if let outerGlow = node.childNode(withName: "outerGlow") {
            let breatheOut = SKAction.group([
                SKAction.scale(to: 1.12, duration: 1.8),
                SKAction.fadeAlpha(to: 0.6, duration: 1.8)
            ])
            let breatheIn = SKAction.group([
                SKAction.scale(to: 1.0, duration: 1.8),
                SKAction.fadeAlpha(to: 1.0, duration: 1.8)
            ])
            breatheOut.timingMode = .easeInEaseOut
            breatheIn.timingMode = .easeInEaseOut

            let breathe = SKAction.repeatForever(SKAction.sequence([breatheOut, breatheIn]))
            outerGlow.run(breathe, withKey: AnimationKey.idlePulse)

            // Rotate outer ring if present (epic+ rarity)
            if let outerRing = outerGlow.childNode(withName: "outerRing") {
                let rotate = SKAction.rotate(byAngle: .pi * 2, duration: 20)
                outerRing.run(SKAction.repeatForever(rotate), withKey: AnimationKey.idleRotation)
            }
        }

        // Mid glow pulse (offset timing)
        if let midGlow = node.childNode(withName: "midGlow") {
            let pulseOut = SKAction.group([
                SKAction.scale(to: 1.08, duration: 1.5),
                SKAction.fadeAlpha(to: 0.75, duration: 1.5)
            ])
            let pulseIn = SKAction.group([
                SKAction.scale(to: 1.0, duration: 1.5),
                SKAction.fadeAlpha(to: 1.0, duration: 1.5)
            ])
            pulseOut.timingMode = .easeInEaseOut
            pulseIn.timingMode = .easeInEaseOut

            let pulse = SKAction.repeatForever(SKAction.sequence([
                SKAction.wait(forDuration: 0.4),
                pulseOut,
                pulseIn
            ]))
            midGlow.run(pulse, withKey: AnimationKey.idlePulse)
        }

        // Core glow tight pulse
        if let coreGlow = node.childNode(withName: "glow") {
            let pulseOut = SKAction.group([
                SKAction.scale(to: 1.05, duration: 1.2),
                SKAction.fadeAlpha(to: 0.85, duration: 1.2)
            ])
            let pulseIn = SKAction.group([
                SKAction.scale(to: 1.0, duration: 1.2),
                SKAction.fadeAlpha(to: 1.0, duration: 1.2)
            ])
            pulseOut.timingMode = .easeInEaseOut
            pulseIn.timingMode = .easeInEaseOut

            coreGlow.run(SKAction.repeatForever(SKAction.sequence([pulseOut, pulseIn])), withKey: AnimationKey.idlePulse)

            // Core highlight shimmer
            if let highlight = coreGlow.childNode(withName: "coreHighlight") {
                let shimmer = SKAction.sequence([
                    SKAction.fadeAlpha(to: 0.5, duration: 0.8),
                    SKAction.fadeAlpha(to: 1.0, duration: 0.8)
                ])
                highlight.run(SKAction.repeatForever(shimmer))
            }
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
            let brighten = SKAction.run {
                centerDot.glowWidth = 6
            }
            let dim = SKAction.run {
                centerDot.glowWidth = 4
            }
            let pulse = SKAction.repeatForever(SKAction.sequence([
                brighten,
                SKAction.wait(forDuration: 0.6),
                dim,
                SKAction.wait(forDuration: 0.6)
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

        // Capacitor sequence pulse (if platform has them)
        if let platform = node.childNode(withName: "basePlatform") {
            for i in 0..<4 {
                if let capacitor = platform.childNode(withName: "capacitor_\(i)") as? SKShapeNode {
                    let delay = Double(i) * 0.3
                    let pulse = SKAction.sequence([
                        SKAction.wait(forDuration: delay),
                        SKAction.repeatForever(SKAction.sequence([
                            SKAction.run { capacitor.glowWidth = 4 },
                            SKAction.wait(forDuration: 0.2),
                            SKAction.run { capacitor.glowWidth = 2 },
                            SKAction.wait(forDuration: 1.0)
                        ]))
                    ])
                    capacitor.run(pulse)
                }
            }
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
                SKAction.run { body.glowWidth = 8 },
                SKAction.wait(forDuration: 0.5),
                SKAction.run { body.glowWidth = 6 },
                SKAction.wait(forDuration: 0.5)
            ]))
            body.run(shimmer)
        }

        // Crystal barrel tip pulse
        if let barrel = node.childNode(withName: "barrel") {
            for child in barrel.children {
                if let shape = child as? SKShapeNode, shape.glowWidth > 0 {
                    let pulse = SKAction.repeatForever(SKAction.sequence([
                        SKAction.run { shape.glowWidth = 8 },
                        SKAction.wait(forDuration: 0.4),
                        SKAction.run { shape.glowWidth = 5 },
                        SKAction.wait(forDuration: 0.4)
                    ]))
                    shape.run(pulse)
                }
            }
        }
    }

    private static func startFrostParticleEmission(node: SKNode, color: UIColor) {
        let emitParticle = SKAction.run { [weak node] in
            guard let node = node else { return }

            let particle = SKShapeNode(circleOfRadius: CGFloat.random(in: 1...2))
            particle.fillColor = UIColor.cyan.withAlphaComponent(0.7)
            particle.strokeColor = .clear
            particle.glowWidth = 2
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

    // MARK: - Magic Idle

    private static func startMagicIdleAnimation(node: SKNode, color: UIColor) {
        guard let body = node.childNode(withName: "body") as? SKShapeNode else { return }

        // Power orb pulse
        if let orb = body.childNode(withName: "powerOrb") as? SKShapeNode {
            let pulse = SKAction.repeatForever(SKAction.sequence([
                SKAction.group([
                    SKAction.scale(to: 1.15, duration: 1.0),
                    SKAction.run { orb.glowWidth = 12 }
                ]),
                SKAction.group([
                    SKAction.scale(to: 1.0, duration: 1.0),
                    SKAction.run { orb.glowWidth = 8 }
                ])
            ]))
            orb.run(pulse)
        }

        // Rune orbit animation
        for i in 0..<3 {
            if let runeOrbit = body.childNode(withName: "runeOrbit_\(i)") {
                let duration: TimeInterval = 4.0 + Double(i) * 0.3
                let direction: CGFloat = (i % 2 == 0) ? 1 : -1
                let orbit = SKAction.rotate(byAngle: .pi * 2 * direction, duration: duration)
                runeOrbit.run(SKAction.repeatForever(orbit), withKey: AnimationKey.runeOrbit)
            }
        }

        // Magic circle rotation (in platform)
        if let platform = node.childNode(withName: "basePlatform") {
            let rotate = SKAction.rotate(byAngle: -.pi * 2, duration: 15)
            platform.run(SKAction.repeatForever(rotate), withKey: AnimationKey.idleRotation)
        }

        // Emitter orb glow
        if let barrel = node.childNode(withName: "barrel") {
            if let emitterOrb = barrel.childNode(withName: "emitterOrb") as? SKShapeNode {
                let pulse = SKAction.repeatForever(SKAction.sequence([
                    SKAction.run { emitterOrb.glowWidth = 12 },
                    SKAction.wait(forDuration: 0.5),
                    SKAction.run { emitterOrb.glowWidth = 6 },
                    SKAction.wait(forDuration: 0.5)
                ]))
                emitterOrb.run(pulse)
            }
        }
    }

    // MARK: - Beam (Tech Emitter) Idle

    private static func startBeamIdleAnimation(node: SKNode, color: UIColor) {
        guard let body = node.childNode(withName: "body") as? SKShapeNode else { return }

        // Lens pulse
        if let lens = body.childNode(withName: "lens") as? SKShapeNode {
            let pulse = SKAction.repeatForever(SKAction.sequence([
                SKAction.group([
                    SKAction.scale(to: 1.1, duration: 0.8),
                    SKAction.run { lens.glowWidth = 8 }
                ]),
                SKAction.group([
                    SKAction.scale(to: 1.0, duration: 0.8),
                    SKAction.run { lens.glowWidth = 4 }
                ])
            ]))
            lens.run(pulse)
        }

        // Capacitor charging sequence
        if let platform = node.childNode(withName: "basePlatform") {
            for i in 0..<4 {
                if let capacitor = platform.childNode(withName: "capacitor_\(i)") as? SKShapeNode {
                    let delay = Double(i) * 0.4
                    let charge = SKAction.sequence([
                        SKAction.wait(forDuration: delay),
                        SKAction.repeatForever(SKAction.sequence([
                            SKAction.run {
                                capacitor.fillColor = color.lighter(by: 0.3)
                                capacitor.glowWidth = 5
                            },
                            SKAction.wait(forDuration: 0.3),
                            SKAction.run {
                                capacitor.fillColor = color.withAlphaComponent(0.5)
                                capacitor.glowWidth = 2
                            },
                            SKAction.wait(forDuration: 1.3)
                        ]))
                    ])
                    capacitor.run(charge)
                }
            }
        }

        // Barrel focus lens glow
        if let barrel = node.childNode(withName: "barrel") {
            if let focusLens = barrel.childNode(withName: "focusLens") as? SKShapeNode {
                let pulse = SKAction.repeatForever(SKAction.sequence([
                    SKAction.run { focusLens.glowWidth = 6 },
                    SKAction.wait(forDuration: 0.6),
                    SKAction.run { focusLens.glowWidth = 3 },
                    SKAction.wait(forDuration: 0.6)
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
                SKAction.run { conductor.glowWidth = 6 },
                SKAction.wait(forDuration: 0.3),
                SKAction.run { conductor.glowWidth = 3 },
                SKAction.wait(forDuration: 0.3)
            ]))
            conductor.run(pulse)
        }

        // Discharge node random arcs
        startElectricArcAnimation(node: node, body: body, color: color)

        // Tesla sphere crackle
        if let barrel = node.childNode(withName: "barrel") {
            if let sphere = barrel.childNode(withName: "teslaSphere") as? SKShapeNode {
                let crackle = SKAction.repeatForever(SKAction.sequence([
                    SKAction.run { sphere.glowWidth = 12 },
                    SKAction.wait(forDuration: 0.1),
                    SKAction.run { sphere.glowWidth = 6 },
                    SKAction.wait(forDuration: CGFloat.random(in: 0.2...0.8))
                ]))
                sphere.run(crackle)
            }
        }
    }

    private static func startElectricArcAnimation(node: SKNode, body: SKShapeNode, color: UIColor) {
        // Create random arcs between discharge nodes
        let createArc = SKAction.run { [weak node, weak body] in
            guard let node = node, let body = body else { return }

            // Pick two random nodes
            let node1 = Int.random(in: 0..<4)
            var node2 = Int.random(in: 0..<4)
            while node2 == node1 { node2 = Int.random(in: 0..<4) }

            guard let discharge1 = body.childNode(withName: "dischargeNode_\(node1)"),
                  let discharge2 = body.childNode(withName: "dischargeNode_\(node2)") else { return }

            let pos1 = discharge1.position
            let pos2 = discharge2.position

            // Create jagged lightning path
            let arcPath = createLightningPath(from: pos1, to: pos2)
            let arc = SKShapeNode(path: arcPath)
            arc.strokeColor = UIColor.cyan.withAlphaComponent(0.8)
            arc.lineWidth = 1.5
            arc.glowWidth = 4
            arc.blendMode = .add
            arc.zPosition = 4

            body.addChild(arc)

            // Quick flash and fade
            arc.run(SKAction.sequence([
                SKAction.wait(forDuration: 0.05),
                SKAction.fadeOut(withDuration: 0.1),
                SKAction.removeFromParent()
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

    // MARK: - Pyro Idle

    private static func startPyroIdleAnimation(node: SKNode, color: UIColor) {
        guard let body = node.childNode(withName: "body") as? SKShapeNode else { return }

        // Pilot flame flicker
        if let pilotFlame = body.childNode(withName: "pilotFlame") as? SKShapeNode {
            let flicker = SKAction.repeatForever(SKAction.sequence([
                SKAction.group([
                    SKAction.scale(to: CGFloat.random(in: 0.8...1.2), duration: 0.1),
                    SKAction.run { pilotFlame.glowWidth = CGFloat.random(in: 4...8) }
                ]),
                SKAction.wait(forDuration: 0.05)
            ]))
            pilotFlame.run(flicker, withKey: AnimationKey.flameFlicker)
        }

        // Heat shimmer effect
        startHeatShimmer(node: node, color: color)

        // Fuel tank level animation
        if let leftTank = body.childNode(withName: "leftTank") as? SKShapeNode,
           let rightTank = body.childNode(withName: "rightTank") as? SKShapeNode {

            let tankPulse = SKAction.repeatForever(SKAction.sequence([
                SKAction.run {
                    leftTank.fillColor = UIColor.darkGray.withAlphaComponent(0.9)
                    rightTank.fillColor = UIColor.darkGray.withAlphaComponent(0.7)
                },
                SKAction.wait(forDuration: 0.8),
                SKAction.run {
                    leftTank.fillColor = UIColor.darkGray.withAlphaComponent(0.7)
                    rightTank.fillColor = UIColor.darkGray.withAlphaComponent(0.9)
                },
                SKAction.wait(forDuration: 0.8)
            ]))
            body.run(tankPulse)
        }
    }

    private static func startHeatShimmer(node: SKNode, color: UIColor) {
        let emitShimmer = SKAction.run { [weak node] in
            guard let node = node else { return }

            let shimmer = SKShapeNode(rectOf: CGSize(width: CGFloat.random(in: 2...4), height: CGFloat.random(in: 3...6)), cornerRadius: 1)
            shimmer.fillColor = UIColor.orange.withAlphaComponent(0.3)
            shimmer.strokeColor = .clear
            shimmer.blendMode = .add
            shimmer.position = CGPoint(
                x: CGFloat.random(in: -8...8),
                y: CGFloat.random(in: 5...12)
            )
            shimmer.zPosition = 6

            let rise = SKAction.moveBy(x: CGFloat.random(in: -3...3), y: 20, duration: 0.8)
            let fade = SKAction.fadeOut(withDuration: 0.8)
            let scale = SKAction.scale(to: 0.5, duration: 0.8)

            shimmer.run(SKAction.sequence([
                SKAction.group([rise, fade, scale]),
                SKAction.removeFromParent()
            ]))

            node.addChild(shimmer)
        }

        let wait = SKAction.wait(forDuration: 0.15, withRange: 0.1)
        node.run(SKAction.repeatForever(SKAction.sequence([emitShimmer, wait])), withKey: "heatShimmer")
    }

    // MARK: - Legendary Idle

    private static func startLegendaryIdleAnimation(node: SKNode, color: UIColor) {
        guard let body = node.childNode(withName: "body") as? SKShapeNode else { return }

        // Sword rotation
        if let sword = body.childNode(withName: "sword") as? SKShapeNode {
            let rotate = SKAction.rotate(byAngle: .pi * 2, duration: 8)
            sword.run(SKAction.repeatForever(rotate), withKey: AnimationKey.idleRotation)

            // Sword float
            let float = SKAction.repeatForever(SKAction.sequence([
                SKAction.moveBy(x: 0, y: 3, duration: 1.5),
                SKAction.moveBy(x: 0, y: -3, duration: 1.5)
            ]))
            sword.run(float, withKey: AnimationKey.idleFloat)

            // Sword glow pulse
            let glow = SKAction.repeatForever(SKAction.sequence([
                SKAction.run { sword.glowWidth = 12 },
                SKAction.wait(forDuration: 0.8),
                SKAction.run { sword.glowWidth = 6 },
                SKAction.wait(forDuration: 0.8)
            ]))
            sword.run(glow)
        }

        // Sacred geometry rotation (opposite direction)
        if let platform = node.childNode(withName: "basePlatform") {
            if let geometry = platform.childNode(withName: "sacredGeometry") {
                let rotate = SKAction.rotate(byAngle: -.pi * 2, duration: 12)
                geometry.run(SKAction.repeatForever(rotate))
            }
        }

        // Divine particle emission
        startDivineParticleEmission(node: node)

        // Divine ray pulse
        if let platform = node.childNode(withName: "basePlatform") {
            for i in 0..<4 {
                if let ray = platform.childNode(withName: "divineRay_\(i)") as? SKShapeNode {
                    let delay = Double(i) * 0.2
                    let pulse = SKAction.sequence([
                        SKAction.wait(forDuration: delay),
                        SKAction.repeatForever(SKAction.sequence([
                            SKAction.fadeAlpha(to: 0.6, duration: 0.5),
                            SKAction.fadeAlpha(to: 0.2, duration: 0.5)
                        ]))
                    ])
                    ray.run(pulse)
                }
            }
        }

        // Divine beam in barrel
        if let barrel = node.childNode(withName: "barrel") {
            if let beam = barrel.childNode(withName: "divineBeam") as? SKShapeNode {
                let pulse = SKAction.repeatForever(SKAction.sequence([
                    SKAction.fadeAlpha(to: 0.5, duration: 0.6),
                    SKAction.fadeAlpha(to: 0.2, duration: 0.6)
                ]))
                beam.run(pulse)
            }
        }
    }

    private static func startDivineParticleEmission(node: SKNode) {
        let emitParticle = SKAction.run { [weak node] in
            guard let node = node else { return }

            let particle = SKShapeNode(circleOfRadius: CGFloat.random(in: 1.5...3))
            particle.fillColor = UIColor(hex: "fbbf24")?.withAlphaComponent(0.8) ?? .yellow.withAlphaComponent(0.8)
            particle.strokeColor = .clear
            particle.glowWidth = 4
            particle.blendMode = .add

            let angle = CGFloat.random(in: 0...(.pi * 2))
            let radius = CGFloat.random(in: 5...20)
            particle.position = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
            particle.zPosition = 5

            let rise = SKAction.moveBy(x: 0, y: CGFloat.random(in: 20...35), duration: 2.0)
            let fade = SKAction.fadeOut(withDuration: 2.0)
            let scale = SKAction.scale(to: 0.2, duration: 2.0)

            particle.run(SKAction.sequence([
                SKAction.group([rise, fade, scale]),
                SKAction.removeFromParent()
            ]))

            node.addChild(particle)
        }

        let wait = SKAction.wait(forDuration: 0.2, withRange: 0.15)
        node.run(SKAction.repeatForever(SKAction.sequence([emitParticle, wait])), withKey: AnimationKey.divineParticles)
    }

    // MARK: - Multishot Idle

    private static func startMultishotIdleAnimation(node: SKNode, color: UIColor) {
        guard let body = node.childNode(withName: "body") as? SKShapeNode else { return }

        // Hub pulse
        if let hub = body.childNode(withName: "hub") as? SKShapeNode {
            let pulse = SKAction.repeatForever(SKAction.sequence([
                SKAction.group([
                    SKAction.scale(to: 1.1, duration: 0.6),
                    SKAction.run { hub.glowWidth = 6 }
                ]),
                SKAction.group([
                    SKAction.scale(to: 1.0, duration: 0.6),
                    SKAction.run { hub.glowWidth = 4 }
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
                            processNode.glowWidth = 5
                        },
                        SKAction.wait(forDuration: 0.15),
                        SKAction.run {
                            processNode.fillColor = color.withAlphaComponent(0.7)
                            processNode.glowWidth = 3
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

            let nodeIndex = Int.random(in: 0..<5)
            guard let processNode = body.childNode(withName: "processNode_\(nodeIndex)") else { return }

            let dot = SKShapeNode(circleOfRadius: 2)
            dot.fillColor = color.lighter(by: 0.3)
            dot.strokeColor = .clear
            dot.glowWidth = 3
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
                SKAction.run { triangle.glowWidth = 10 },
                SKAction.wait(forDuration: 0.3),
                SKAction.run { triangle.glowWidth = 4 },
                SKAction.wait(forDuration: 0.7)
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
        let glitch = SKAction.run { [weak body] in
            guard let body = body else { return }

            // Random position jitter
            let originalPos = CGPoint.zero
            body.position = CGPoint(
                x: originalPos.x + CGFloat.random(in: -2...2),
                y: originalPos.y + CGFloat.random(in: -2...2)
            )

            // Quick return
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                body.position = originalPos
            }
        }

        let wait = SKAction.wait(forDuration: 0.5, withRange: 0.8)
        node.run(SKAction.repeatForever(SKAction.sequence([glitch, wait])), withKey: AnimationKey.glitchEffect)
    }

    private static func startCodeParticleEmission(node: SKNode) {
        let emitCode = SKAction.run { [weak node] in
            guard let node = node else { return }

            let codeChars = ["0", "1", "!", "?", "#", "@", "%"]
            let code = SKLabelNode(text: codeChars.randomElement()!)
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
        guard let stars = node.childNode(withName: "stars") else { return }

        for i in 0..<3 {
            if let indicator = stars.childNode(withName: "mergeIndicator_\(i)") as? SKShapeNode {
                let delay = Double(i) * 0.15
                let pulse = SKAction.sequence([
                    SKAction.wait(forDuration: delay),
                    SKAction.repeatForever(SKAction.sequence([
                        SKAction.scale(to: 1.2, duration: 0.5),
                        SKAction.scale(to: 1.0, duration: 0.5)
                    ]))
                ])
                indicator.run(pulse)
            }
        }
    }

    // MARK: - Combat Animations

    /// Play muzzle flash animation
    static func playMuzzleFlash(node: SKNode, duration: TimeInterval = 0.15) {
        guard let barrel = node.childNode(withName: "barrel"),
              let flash = barrel.childNode(withName: "muzzleFlash") else { return }

        flash.removeAllActions()
        flash.alpha = 1.0
        flash.setScale(1.0)

        let flashSequence = SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 1.3, duration: duration * 0.3),
                SKAction.fadeAlpha(to: 0.8, duration: duration * 0.3)
            ]),
            SKAction.group([
                SKAction.scale(to: 0.8, duration: duration * 0.7),
                SKAction.fadeAlpha(to: 0, duration: duration * 0.7)
            ])
        ])

        flash.run(flashSequence)
    }

    /// Play recoil animation
    static func playRecoil(node: SKNode, intensity: CGFloat = 3.0) {
        guard let body = node.childNode(withName: "body"),
              let barrel = node.childNode(withName: "barrel") else { return }

        let originalBarrelY = barrel.position.y

        // Barrel recoil
        let recoil = SKAction.sequence([
            SKAction.moveBy(x: 0, y: -intensity, duration: 0.05),
            SKAction.move(to: CGPoint(x: barrel.position.x, y: originalBarrelY), duration: 0.15)
        ])
        recoil.timingMode = .easeOut
        barrel.run(recoil)

        // Body shake
        let shake = SKAction.sequence([
            SKAction.moveBy(x: 0, y: -intensity * 0.5, duration: 0.03),
            SKAction.moveBy(x: 0, y: intensity * 0.5, duration: 0.07)
        ])
        body.run(shake)
    }

    /// Show range indicator
    static func showRange(node: SKNode, animated: Bool = true) {
        guard let range = node.childNode(withName: "range") else { return }

        range.isHidden = false

        if animated {
            range.alpha = 0
            range.setScale(0.8)
            let show = SKAction.group([
                SKAction.fadeIn(withDuration: 0.2),
                SKAction.scale(to: 1.0, duration: 0.2)
            ])
            range.run(show)
        }
    }

    /// Hide range indicator
    static func hideRange(node: SKNode, animated: Bool = true) {
        guard let range = node.childNode(withName: "range") else { return }

        if animated {
            let hide = SKAction.sequence([
                SKAction.group([
                    SKAction.fadeOut(withDuration: 0.15),
                    SKAction.scale(to: 0.9, duration: 0.15)
                ]),
                SKAction.run { range.isHidden = true }
            ])
            range.run(hide)
        } else {
            range.isHidden = true
        }
    }

    /// Update cooldown arc
    static func updateCooldownArc(node: SKNode, progress: CGFloat, color: UIColor) {
        guard let cooldown = node.childNode(withName: "cooldown") as? SKShapeNode else { return }

        if progress <= 0 || progress >= 1 {
            cooldown.isHidden = true
            return
        }

        cooldown.isHidden = false

        let radius: CGFloat = 20
        let startAngle: CGFloat = .pi / 2
        let endAngle = startAngle - (progress * .pi * 2)

        let path = UIBezierPath(
            arcCenter: .zero,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )

        cooldown.path = path.cgPath
    }

    /// Show merge highlight
    static func showMergeHighlight(node: SKNode) {
        guard let highlight = node.childNode(withName: "mergeHighlight") as? SKShapeNode else { return }

        highlight.isHidden = false
        highlight.alpha = 0

        let pulse = SKAction.repeatForever(SKAction.sequence([
            SKAction.fadeAlpha(to: 1.0, duration: 0.3),
            SKAction.fadeAlpha(to: 0.5, duration: 0.3)
        ]))
        highlight.run(pulse, withKey: "mergeHighlightPulse")
    }

    /// Hide merge highlight
    static func hideMergeHighlight(node: SKNode) {
        guard let highlight = node.childNode(withName: "mergeHighlight") else { return }

        highlight.removeAction(forKey: "mergeHighlightPulse")
        highlight.run(SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.15),
            SKAction.run { highlight.isHidden = true }
        ]))
    }

    /// Play targeting lock-on animation
    static func playTargetingLockOn(node: SKNode, color: UIColor) {
        guard let body = node.childNode(withName: "body") else { return }

        // Contract brackets inward (for projectile types)
        for i in 0..<4 {
            if let bracket = body.childNode(withName: "bracket_\(i)") {
                let contractIn = SKAction.scale(to: 0.85, duration: 0.1)
                contractIn.timingMode = .easeOut
                bracket.run(contractIn)
            }
        }

        // Intensify glow
        if let glow = node.childNode(withName: "glow") {
            let intensify = SKAction.sequence([
                SKAction.run {
                    if let shape = glow.children.first as? SKShapeNode {
                        shape.glowWidth = 8
                    }
                },
                SKAction.wait(forDuration: 0.3),
                SKAction.run {
                    if let shape = glow.children.first as? SKShapeNode {
                        shape.glowWidth = 5
                    }
                }
            ])
            glow.run(intensify)
        }
    }

    /// Reset targeting animation
    static func resetTargeting(node: SKNode) {
        guard let body = node.childNode(withName: "body") else { return }

        for i in 0..<4 {
            if let bracket = body.childNode(withName: "bracket_\(i)") {
                let expand = SKAction.scale(to: 1.0, duration: 0.15)
                expand.timingMode = .easeOut
                bracket.run(expand)
            }
        }
    }

    /// Play charging animation (for beam/laser types)
    static func playChargingAnimation(node: SKNode, duration: TimeInterval, color: UIColor) {
        // Capacitor fill animation
        if let platform = node.childNode(withName: "basePlatform") {
            for i in 0..<4 {
                if let capacitor = platform.childNode(withName: "capacitor_\(i)") as? SKShapeNode {
                    let chargeDelay = duration * Double(i) / 4.0
                    let charge = SKAction.sequence([
                        SKAction.wait(forDuration: chargeDelay),
                        SKAction.run {
                            capacitor.fillColor = color
                            capacitor.glowWidth = 6
                        }
                    ])
                    capacitor.run(charge)
                }
            }
        }

        // Lens intensify
        if let body = node.childNode(withName: "body") as? SKShapeNode {
            if let lens = body.childNode(withName: "lens") as? SKShapeNode {
                let charge = SKAction.sequence([
                    SKAction.group([
                        SKAction.scale(to: 1.3, duration: duration),
                        SKAction.run { lens.glowWidth = 10 }
                    ])
                ])
                lens.run(charge)
            }
        }
    }

    /// Reset charging animation
    static func resetChargingAnimation(node: SKNode, color: UIColor) {
        if let platform = node.childNode(withName: "basePlatform") {
            for i in 0..<4 {
                if let capacitor = platform.childNode(withName: "capacitor_\(i)") as? SKShapeNode {
                    capacitor.fillColor = color.withAlphaComponent(0.5)
                    capacitor.glowWidth = 2
                }
            }
        }

        if let body = node.childNode(withName: "body") as? SKShapeNode {
            if let lens = body.childNode(withName: "lens") as? SKShapeNode {
                lens.run(SKAction.scale(to: 1.0, duration: 0.2))
                lens.glowWidth = 4
            }
        }
    }

    /// Play legendary special effect (Excalibur)
    static func playLegendarySpecialEffect(node: SKNode) {
        // Screen-wide golden flash effect
        let flash = SKShapeNode(circleOfRadius: 100)
        flash.fillColor = UIColor(hex: "fbbf24")?.withAlphaComponent(0.3) ?? .yellow.withAlphaComponent(0.3)
        flash.strokeColor = .clear
        flash.glowWidth = 20
        flash.blendMode = .add
        flash.zPosition = 100

        node.addChild(flash)

        let expand = SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 3.0, duration: 0.3),
                SKAction.fadeOut(withDuration: 0.3)
            ]),
            SKAction.removeFromParent()
        ])
        flash.run(expand)

        // Sword spin burst
        if let body = node.childNode(withName: "body"),
           let sword = body.childNode(withName: "sword") {
            sword.run(SKAction.rotate(byAngle: .pi * 4, duration: 0.5))
        }
    }

    /// Play execute effect (NullPointer)
    static func playExecuteEffect(node: SKNode) {
        // Fatal error flash
        let flash = SKShapeNode(circleOfRadius: 50)
        flash.fillColor = UIColor(hex: "ef4444")?.withAlphaComponent(0.5) ?? .red.withAlphaComponent(0.5)
        flash.strokeColor = .clear
        flash.glowWidth = 15
        flash.blendMode = .add
        flash.zPosition = 100

        node.addChild(flash)

        let effect = SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 2.0, duration: 0.2),
                SKAction.fadeOut(withDuration: 0.2)
            ]),
            SKAction.removeFromParent()
        ])
        flash.run(effect)

        // Glitch intensify
        if let body = node.childNode(withName: "body") {
            let glitchIntense = SKAction.sequence([
                SKAction.moveBy(x: 3, y: 0, duration: 0.02),
                SKAction.moveBy(x: -6, y: 0, duration: 0.02),
                SKAction.moveBy(x: 3, y: 0, duration: 0.02),
                SKAction.moveBy(x: 0, y: 3, duration: 0.02),
                SKAction.moveBy(x: 0, y: -3, duration: 0.02)
            ])
            body.run(glitchIntense)
        }
    }
}
