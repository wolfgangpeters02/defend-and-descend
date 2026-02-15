import SpriteKit

// MARK: - Entity Renderer

class EntityRenderer {

    // MARK: - Player

    func createPlayerNode(size: CGFloat) -> SKNode {
        let container = SKNode()

        // Main body - cyan circle with glow
        let body = SKShapeNode(circleOfRadius: size)
        body.fillColor = SKColor(red: 0, green: 1, blue: 1, alpha: 1) // Cyan
        body.strokeColor = SKColor.white
        body.lineWidth = 2
        body.glowWidth = 0
        container.addChild(body)

        // Inner ring for detail
        let innerRing = SKShapeNode(circleOfRadius: size * 0.6)
        innerRing.fillColor = SKColor(red: 0, green: 0.8, blue: 0.8, alpha: 0.5)
        innerRing.strokeColor = .clear
        container.addChild(innerRing)

        // Center dot
        let center = SKShapeNode(circleOfRadius: size * 0.2)
        center.fillColor = SKColor.white
        center.strokeColor = .clear
        container.addChild(center)

        // Pulsing animation
        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.1, duration: 0.5),
            SKAction.scale(to: 1.0, duration: 0.5)
        ])
        innerRing.run(SKAction.repeatForever(pulse))

        return container
    }

    // MARK: - Enemy

    func createEnemyNode(enemy: Enemy) -> SKNode {
        let container = SKNode()

        let color = colorFromHex(enemy.color)
        let size = enemy.size ?? 20

        // Special rendering for Void Harbinger boss
        if enemy.isBoss && enemy.type == EnemyID.boss.rawValue && color == colorFromHex(BalanceConfig.VoidHarbinger.bossColor) {
            return createVoidHarbingerNode(size: size, color: color)
        }

        // Skip void_pylon enemies - they're rendered by boss mechanics in GameScene
        if enemy.type == EnemyID.voidPylon.rawValue {
            return SKNode()  // Empty node - pylon visuals handled by GameScene
        }

        // Special rendering for void minions
        if enemy.type == EnemyID.voidMinionSpawn.rawValue || enemy.type == EnemyID.voidElite.rawValue {
            return createVoidMinionNode(size: size, color: color, isElite: enemy.type == EnemyID.voidElite.rawValue)
        }

        switch enemy.shape ?? "circle" {
        case "square":
            // Tank virus — "Armored Payload" full composition
            let body = EntityRenderer.createTankVirusComposition(in: container, size: size, color: color)
            // Scale breathing — tanks don't spin, they breathe
            let breathe = SKAction.sequence([
                SKAction.scale(to: 1.03, duration: 1.0),
                SKAction.scale(to: 1.0, duration: 1.0)
            ])
            body.run(SKAction.repeatForever(breathe))

        case "triangle":
            // Fast virus — "Packet Runner" full composition
            let body = EntityRenderer.createFastVirusComposition(in: container, size: size, color: color)
            // Fast rotation (2s) — unstable speed
            let fastRotate = SKAction.rotate(byAngle: .pi * 2, duration: 2.0)
            container.run(SKAction.repeatForever(fastRotate))

        case "hexagon":
            if enemy.isBoss {
                // Boss: keep existing hexagon with glow + pulse
                let path = hexagonPath(size: size)
                let hexagon = SKShapeNode(path: path)
                hexagon.fillColor = color
                hexagon.strokeColor = color.darker(by: 0.3)
                hexagon.lineWidth = 2
                hexagon.glowWidth = 2.0
                hexagon.name = "body"
                container.addChild(hexagon)

                let pulse = SKAction.sequence([
                    SKAction.scale(to: 1.15, duration: 0.3),
                    SKAction.scale(to: 1.0, duration: 0.3)
                ])
                container.run(SKAction.repeatForever(pulse))
            } else {
                // Elite virus — full composition
                let body = EntityRenderer.createEliteVirusComposition(in: container, size: size, color: color)
                // Alpha flicker — glitchy presence
                let flicker = SKAction.sequence([
                    SKAction.fadeAlpha(to: 0.9, duration: 0.15),
                    SKAction.fadeAlpha(to: 1.0, duration: 0.15)
                ])
                body.run(SKAction.repeatForever(flicker))
            }

        default:
            // Basic virus — "Malware Blob" full composition
            let body = EntityRenderer.createBasicVirusComposition(in: container, size: size, color: color)
            // Subtle pulse on body
            let pulse = SKAction.sequence([
                SKAction.scale(to: 1.05, duration: 0.8),
                SKAction.scale(to: 0.95, duration: 0.8)
            ])
            body.run(SKAction.repeatForever(pulse))
            // Slow rotation (full turn every 4s) — viruses spin
            let rotate = SKAction.rotate(byAngle: .pi * 2, duration: 4.0)
            container.run(SKAction.repeatForever(rotate))
        }

        // Boss health bar is now shown in the UI overlay (GameContainerView)
        // No need for sprite-attached health bar

        // Store metadata for death animation (Phase 7B)
        container.userData = NSMutableDictionary()
        container.userData?["shape"] = enemy.isBoss ? "boss" : (enemy.shape ?? "circle")
        container.userData?["size"] = size
        container.userData?["color"] = color

        return container
    }

    /// Create specialized Void Harbinger boss visual
    private func createVoidHarbingerNode(size: CGFloat, color: SKColor) -> SKNode {
        let container = SKNode()

        // Outer void aura - dark swirling energy
        let aura = SKShapeNode(circleOfRadius: size * 1.3)
        aura.fillColor = SKColor.black.withAlphaComponent(0.4)
        aura.strokeColor = color.withAlphaComponent(0.6)
        aura.lineWidth = 3
        aura.glowWidth = 2.0  // Menacing outer glow (1 Void Harbinger in game)
        container.addChild(aura)

        // Main body - octagonal void core
        let octPath = CGMutablePath()
        for i in 0..<8 {
            let angle = CGFloat(i) * (.pi / 4) - (.pi / 8)
            let point = CGPoint(x: cos(angle) * size, y: sin(angle) * size)
            if i == 0 {
                octPath.move(to: point)
            } else {
                octPath.addLine(to: point)
            }
        }
        octPath.closeSubpath()

        let body = SKShapeNode(path: octPath)
        body.fillColor = SKColor(hex: BalanceConfig.VoidHarbinger.voidCoreColor) ?? SKColor.black
        body.strokeColor = color
        body.lineWidth = 4
        body.glowWidth = 1.5  // Void core shimmer
        container.addChild(body)

        // Inner eye/core - the "harbinger"
        let eye = SKShapeNode(circleOfRadius: size * 0.4)
        eye.fillColor = color
        eye.strokeColor = SKColor(hex: BalanceConfig.VoidHarbinger.harbingerEyeColor) ?? SKColor.magenta
        eye.lineWidth = 3
        eye.glowWidth = 1.5  // Hypnotic center glow
        container.addChild(eye)

        // Pupil
        let pupil = SKShapeNode(circleOfRadius: size * 0.15)
        pupil.fillColor = SKColor.black
        pupil.strokeColor = SKColor.clear
        container.addChild(pupil)

        // Orbiting void fragments (4 small orbs)
        for i in 0..<4 {
            let fragment = SKShapeNode(circleOfRadius: size * 0.15)
            fragment.fillColor = color.withAlphaComponent(0.8)
            fragment.strokeColor = SKColor.clear
            fragment.glowWidth = 1.0  // Eerie orbiting glow
            let angle = CGFloat(i) * (.pi / 2)
            fragment.position = CGPoint(x: cos(angle) * size * 0.8, y: sin(angle) * size * 0.8)
            fragment.name = "fragment_\(i)"
            container.addChild(fragment)
        }

        // Animations
        // Slow menacing pulse
        let bodyPulse = SKAction.sequence([
            SKAction.scale(to: 1.08, duration: 0.8),
            SKAction.scale(to: 0.95, duration: 0.8)
        ])
        body.run(SKAction.repeatForever(bodyPulse))

        // Eye intensity pulse
        let eyePulse = SKAction.sequence([
            SKAction.fadeAlpha(to: 1.0, duration: 0.4),
            SKAction.fadeAlpha(to: 0.6, duration: 0.4)
        ])
        eye.run(SKAction.repeatForever(eyePulse))

        // Rotating aura
        let auraRotate = SKAction.rotate(byAngle: -.pi * 2, duration: 6.0)
        aura.run(SKAction.repeatForever(auraRotate))

        // Orbiting fragments
        let fragmentRotate = SKAction.rotate(byAngle: .pi * 2, duration: 3.0)
        container.run(SKAction.repeatForever(fragmentRotate))

        return container
    }

    /// Create void minion visual — teardrop/wisp shape (Phase 5B)
    private func createVoidMinionNode(size: CGFloat, color: SKColor, isElite: Bool) -> SKNode {
        let container = SKNode()

        if isElite {
            // Elite minion: mini-octagon (matching harbinger) with orbiting sparks
            let octPath = CGMutablePath()
            for i in 0..<8 {
                let angle = CGFloat(i) * (.pi / 4) - (.pi / 8)
                let pt = CGPoint(x: cos(angle) * size, y: sin(angle) * size)
                if i == 0 { octPath.move(to: pt) } else { octPath.addLine(to: pt) }
            }
            octPath.closeSubpath()

            let body = SKShapeNode(path: octPath)
            body.fillColor = color
            body.strokeColor = SKColor(hex: BalanceConfig.VoidHarbinger.harbingerEyeColor) ?? SKColor.magenta
            body.lineWidth = 3
            body.glowWidth = 0
            body.name = "body"
            container.addChild(body)

            // Inner void core
            let core = SKShapeNode(circleOfRadius: size * 0.35)
            core.fillColor = SKColor.black.withAlphaComponent(0.6)
            core.strokeColor = color.withAlphaComponent(0.5)
            core.lineWidth = 1
            container.addChild(core)

            // Orbiting sparks (compound path, single node)
            let sparkPath = CGMutablePath()
            let sparkSize: CGFloat = size * 0.1
            for i in 0..<3 {
                let angle = CGFloat(i) * (2 * .pi / 3)
                let sx = cos(angle) * size * 0.7
                let sy = sin(angle) * size * 0.7
                sparkPath.addArc(center: CGPoint(x: sx, y: sy), radius: sparkSize,
                                 startAngle: 0, endAngle: .pi * 2, clockwise: false)
            }
            let sparks = SKShapeNode(path: sparkPath)
            sparks.fillColor = color.withAlphaComponent(0.8)
            sparks.strokeColor = .clear
            container.addChild(sparks)

            let rotate = SKAction.rotate(byAngle: .pi * 2, duration: 1.5)
            container.run(SKAction.repeatForever(rotate))

            // Elite pulse
            let pulse = SKAction.sequence([
                SKAction.scale(to: 1.08, duration: 0.3),
                SKAction.scale(to: 0.95, duration: 0.3)
            ])
            body.run(SKAction.repeatForever(pulse))

        } else {
            // Regular minion: teardrop/wisp shape with trailing fade
            let tearPath = CGMutablePath()
            // Teardrop: rounded top, pointed bottom
            tearPath.move(to: CGPoint(x: 0, y: size * 0.8))
            tearPath.addQuadCurve(to: CGPoint(x: size * 0.7, y: 0),
                                  control: CGPoint(x: size * 0.8, y: size * 0.7))
            tearPath.addQuadCurve(to: CGPoint(x: 0, y: -size * 1.1),
                                  control: CGPoint(x: size * 0.3, y: -size * 0.5))
            tearPath.addQuadCurve(to: CGPoint(x: -size * 0.7, y: 0),
                                  control: CGPoint(x: -size * 0.3, y: -size * 0.5))
            tearPath.addQuadCurve(to: CGPoint(x: 0, y: size * 0.8),
                                  control: CGPoint(x: -size * 0.8, y: size * 0.7))

            let body = SKShapeNode(path: tearPath)
            body.fillColor = color.withAlphaComponent(0.6)
            body.strokeColor = color.darker(by: 0.2)
            body.lineWidth = 2
            body.name = "body"
            container.addChild(body)

            // Trailing fade wisp (behind teardrop)
            let wispPath = CGMutablePath()
            wispPath.move(to: CGPoint(x: 0, y: -size * 1.1))
            wispPath.addQuadCurve(to: CGPoint(x: 0, y: -size * 1.8),
                                  control: CGPoint(x: size * 0.2, y: -size * 1.4))
            let wisp = SKShapeNode(path: wispPath)
            wisp.strokeColor = color.withAlphaComponent(0.25)
            wisp.lineWidth = 2
            wisp.lineCap = .round
            wisp.zPosition = -0.1
            container.addChild(wisp)

            // Inner void speck
            let speck = SKShapeNode(circleOfRadius: size * 0.2)
            speck.fillColor = SKColor.black.withAlphaComponent(0.5)
            speck.strokeColor = .clear
            speck.position = CGPoint(x: 0, y: size * 0.1)
            container.addChild(speck)

            // Wisp pulse
            let pulse = SKAction.sequence([
                SKAction.scale(to: 1.1, duration: 0.3),
                SKAction.scale(to: 0.95, duration: 0.3)
            ])
            body.run(SKAction.repeatForever(pulse))
        }

        return container
    }

    // MARK: - Projectile

    func createProjectileNode(projectile: Projectile) -> SKNode {
        let container = SKNode()

        let color = colorFromHex(projectile.color)
        let size = projectile.size ?? 5

        // Special rendering for Cyberboss energy blasts
        if projectile.weaponId == "cyberboss_blast" {
            // Outer energy ring
            let outerRing = SKShapeNode(circleOfRadius: size)
            outerRing.fillColor = color.withAlphaComponent(0.3)
            outerRing.strokeColor = color
            outerRing.lineWidth = 4
            outerRing.glowWidth = 0
            container.addChild(outerRing)

            // Middle energy core
            let middleCore = SKShapeNode(circleOfRadius: size * 0.7)
            middleCore.fillColor = color.withAlphaComponent(0.6)
            middleCore.strokeColor = SKColor.white.withAlphaComponent(0.5)
            middleCore.lineWidth = 2
            middleCore.glowWidth = 0
            container.addChild(middleCore)

            // Inner bright core
            let innerCore = SKShapeNode(circleOfRadius: size * 0.3)
            innerCore.fillColor = SKColor.white
            innerCore.strokeColor = color
            innerCore.lineWidth = 2
            innerCore.glowWidth = 0
            container.addChild(innerCore)

            // Pulsing animation - threatening and dramatic
            let pulseOuter = SKAction.sequence([
                SKAction.scale(to: 1.2, duration: 0.15),
                SKAction.scale(to: 0.9, duration: 0.15)
            ])
            outerRing.run(SKAction.repeatForever(pulseOuter))

            let pulseInner = SKAction.sequence([
                SKAction.scale(to: 1.3, duration: 0.1),
                SKAction.scale(to: 0.8, duration: 0.1)
            ])
            innerCore.run(SKAction.repeatForever(pulseInner))

            // Rotation for extra visual interest
            let rotate = SKAction.rotate(byAngle: .pi * 2, duration: 1.0)
            middleCore.run(SKAction.repeatForever(rotate))

            return container
        }

        // Special rendering for Void Harbinger Shadow Bolts
        if projectile.weaponId == "void_bolt" {
            // Dark void core with purple energy
            let voidCore = SKShapeNode(circleOfRadius: size)
            voidCore.fillColor = SKColor(hex: BalanceConfig.VoidHarbinger.voidCoreColor) ?? SKColor.black
            voidCore.strokeColor = color
            voidCore.lineWidth = 3
            voidCore.glowWidth = 0
            container.addChild(voidCore)

            // Inner swirling void
            let innerVoid = SKShapeNode(circleOfRadius: size * 0.5)
            innerVoid.fillColor = color.withAlphaComponent(0.8)
            innerVoid.strokeColor = SKColor(hex: BalanceConfig.VoidHarbinger.harbingerEyeColor) ?? SKColor.magenta
            innerVoid.lineWidth = 2
            innerVoid.glowWidth = 0
            container.addChild(innerVoid)

            // Void tendrils (3 small orbs orbiting)
            for i in 0..<3 {
                let tendril = SKShapeNode(circleOfRadius: size * 0.25)
                tendril.fillColor = color
                tendril.strokeColor = SKColor.clear
                tendril.glowWidth = 0
                let angle = CGFloat(i) * (2 * .pi / 3)
                tendril.position = CGPoint(x: cos(angle) * size * 0.8, y: sin(angle) * size * 0.8)
                tendril.name = "tendril_\(i)"
                container.addChild(tendril)
            }

            // Rotation animation - slower, more ominous
            let rotate = SKAction.rotate(byAngle: -.pi * 2, duration: 0.8)
            container.run(SKAction.repeatForever(rotate))

            // Pulse animation
            let pulse = SKAction.sequence([
                SKAction.scale(to: 1.15, duration: 0.2),
                SKAction.scale(to: 0.9, duration: 0.2)
            ])
            innerVoid.run(SKAction.repeatForever(pulse))

            return container
        }

        // Special rendering for Pylon Beams (homing)
        if projectile.weaponId == "pylon_beam" {
            // Energy beam with tracking visual
            let beamCore = SKShapeNode(circleOfRadius: size)
            beamCore.fillColor = color
            beamCore.strokeColor = SKColor(hex: BalanceConfig.VoidHarbinger.pylonBeamReticleColor) ?? SKColor.magenta
            beamCore.lineWidth = 2
            beamCore.glowWidth = 0
            container.addChild(beamCore)

            // Targeting reticle effect
            let reticle = SKShapeNode(circleOfRadius: size * 1.5)
            reticle.fillColor = SKColor.clear
            reticle.strokeColor = color.withAlphaComponent(0.5)
            reticle.lineWidth = 1
            container.addChild(reticle)

            // Spinning animation
            let spin = SKAction.rotate(byAngle: .pi * 2, duration: 0.5)
            reticle.run(SKAction.repeatForever(spin))

            return container
        }

        // Main projectile (default)
        let body = SKShapeNode(circleOfRadius: size)
        body.fillColor = color
        body.strokeColor = color.lighter(by: 0.3)
        body.lineWidth = 1
        body.glowWidth = 0
        container.addChild(body)

        // Trail effect
        if projectile.trail == true {
            let trail = SKShapeNode(circleOfRadius: size * 0.5)
            trail.fillColor = color.withAlphaComponent(0.5)
            trail.strokeColor = SKColor.clear
            trail.position = CGPoint(x: -projectile.velocityX * 0.02, y: projectile.velocityY * 0.02)
            container.addChild(trail)
        }

        return container
    }

    // MARK: - Pickup

    func createPickupNode(pickup: Pickup) -> SKNode {
        let container = SKNode()

        switch pickup.type {
        case .hash:
            // Cyan Hash hexagon (Ħ) - Universal currency
            let hashColor = SKColor(red: 0.024, green: 0.714, blue: 0.831, alpha: 1) // #06b6d4 cyan
            let hashColorLight = SKColor(red: 0.2, green: 0.85, blue: 0.95, alpha: 1) // lighter cyan for stroke

            // Create hexagon shape for Hash
            let size: CGFloat = 8
            let path = CGMutablePath()
            for i in 0..<6 {
                let angle = CGFloat(i) * .pi / 3 - .pi / 2
                let point = CGPoint(x: cos(angle) * size, y: sin(angle) * size)
                if i == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
            path.closeSubpath()

            let hashNode = SKShapeNode(path: path)
            hashNode.fillColor = hashColor
            hashNode.strokeColor = hashColorLight
            hashNode.lineWidth = 1.5
            hashNode.glowWidth = 0
            container.addChild(hashNode)

            // Spinning animation
            let spin = SKAction.rotate(byAngle: .pi * 2, duration: 2.0)
            container.run(SKAction.repeatForever(spin))

            // Bobbing animation (float effect)
            let bob = SKAction.sequence([
                SKAction.moveBy(x: 0, y: 3, duration: 0.4),
                SKAction.moveBy(x: 0, y: -3, duration: 0.4)
            ])
            container.run(SKAction.repeatForever(bob))

        case .health:
            let heart = SKLabelNode(text: "♥")
            heart.fontSize = 16
            heart.fontColor = SKColor.red
            heart.verticalAlignmentMode = .center
            container.addChild(heart)

            let pulse = SKAction.sequence([
                SKAction.scale(to: 1.2, duration: 0.3),
                SKAction.scale(to: 1.0, duration: 0.3)
            ])
            container.run(SKAction.repeatForever(pulse))

        case .xp:
            let orb = SKShapeNode(circleOfRadius: 5)
            orb.fillColor = SKColor.blue
            orb.strokeColor = SKColor.cyan
            orb.lineWidth = 1
            container.addChild(orb)
        }

        return container
    }

    // MARK: - Particle

    func createParticleNode(particle: Particle) -> SKNode {
        let container = SKNode()

        let color: SKColor
        if let hexColor = particle.color {
            color = colorFromHex(hexColor)
        } else {
            color = SKColor.white
        }

        let size = particle.size ?? 5

        switch particle.shape {
        case .star:
            let star = starPath(size: size, points: 5)
            let node = SKShapeNode(path: star)
            node.fillColor = color
            node.strokeColor = .clear
            container.addChild(node)

        case .spark:
            let spark = SKShapeNode(rectOf: CGSize(width: size * 2, height: size * 0.5))
            spark.fillColor = color
            spark.strokeColor = .clear
            container.addChild(spark)

        case .square:
            let square = SKShapeNode(rectOf: CGSize(width: size, height: size))
            square.fillColor = color
            square.strokeColor = .clear
            container.addChild(square)

        case .diamond:
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: size))
            path.addLine(to: CGPoint(x: size, y: 0))
            path.addLine(to: CGPoint(x: 0, y: -size))
            path.addLine(to: CGPoint(x: -size, y: 0))
            path.closeSubpath()

            let diamond = SKShapeNode(path: path)
            diamond.fillColor = color
            diamond.strokeColor = .clear
            container.addChild(diamond)

        default: // circle
            let circle = SKShapeNode(circleOfRadius: size)
            circle.fillColor = color
            circle.strokeColor = .clear
            container.addChild(circle)
        }

        // Apply rotation if specified
        if let rotation = particle.rotation {
            container.zRotation = rotation
        }

        return container
    }

    // MARK: - Path Helpers

    private func hexagonPath(size: CGFloat) -> CGPath {
        let path = CGMutablePath()
        for i in 0..<6 {
            let angle = CGFloat(i) * .pi / 3 - .pi / 2
            let x = cos(angle) * size
            let y = sin(angle) * size
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()
        return path
    }

    private func starPath(size: CGFloat, points: Int) -> CGPath {
        let path = CGMutablePath()
        let innerRadius = size * 0.4
        let outerRadius = size

        for i in 0..<(points * 2) {
            let angle = CGFloat(i) * .pi / CGFloat(points) - .pi / 2
            let radius = i % 2 == 0 ? outerRadius : innerRadius
            let x = cos(angle) * radius
            let y = sin(angle) * radius
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()
        return path
    }

    // MARK: - Color Helper

    private func colorFromHex(_ hex: String) -> SKColor {
        guard let (r, g, b) = ColorUtils.hexToRGB(hex) else {
            return SKColor.gray
        }
        return SKColor(red: r, green: g, blue: b, alpha: 1.0)
    }
}
