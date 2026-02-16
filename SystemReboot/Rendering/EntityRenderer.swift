import SpriteKit

// MARK: - Entity Renderer

class EntityRenderer {

    // MARK: - Player

    func createPlayerNode(size: CGFloat) -> SKNode {
        let container = SKNode()

        // Main body - cyan circle
        let body = SKShapeNode(circleOfRadius: size)
        body.fillColor = SKColor(red: 0, green: 1, blue: 1, alpha: 1) // Cyan
        body.strokeColor = SKColor.white
        body.lineWidth = 2
        body.glowWidth = 0
        container.addChild(body)

        // Center dot
        let center = SKShapeNode(circleOfRadius: size * 0.2)
        center.fillColor = SKColor.white
        center.strokeColor = .clear
        container.addChild(center)

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
            // Tank virus — "Armored Payload"
            EntityRenderer.createTankVirusComposition(in: container, size: size, color: color)

        case "triangle":
            // Fast virus — "Packet Runner"
            EntityRenderer.createFastVirusComposition(in: container, size: size, color: color)

        case "hexagon":
            if enemy.isBoss {
                // Boss: hexagon body
                let path = hexagonPath(size: size)
                let hexagon = SKShapeNode(path: path)
                hexagon.fillColor = color
                hexagon.strokeColor = color.darker(by: 0.3)
                hexagon.lineWidth = 2
                hexagon.glowWidth = 0
                hexagon.name = "body"
                container.addChild(hexagon)
            } else {
                // Elite virus
                EntityRenderer.createEliteVirusComposition(in: container, size: size, color: color)
            }

        default:
            // Basic virus — "Malware Blob"
            EntityRenderer.createBasicVirusComposition(in: container, size: size, color: color)
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

    /// Create specialized Void Harbinger boss visual.
    /// Delegates to the shared static composition (EntityRenderer+BossDetails)
    /// which correctly rotates only the fragments node, not the entire container.
    private func createVoidHarbingerNode(size: CGFloat, color: SKColor) -> SKNode {
        let container = SKNode()
        _ = EntityRenderer.createVoidHarbingerComposition(in: container, size: size)
        return container
    }

    /// Create void minion visual — simplified (Phase 5B)
    private func createVoidMinionNode(size: CGFloat, color: SKColor, isElite: Bool) -> SKNode {
        let container = SKNode()

        if isElite {
            // Elite minion: mini-octagon (matching harbinger), 1 node, no animations
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

        } else {
            // Regular minion: teardrop/wisp shape, 1 node, no animations
            let tearPath = CGMutablePath()
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
        }

        return container
    }

    // MARK: - Projectile

    func createProjectileNode(projectile: Projectile) -> SKNode {
        let container = SKNode()

        let color = colorFromHex(projectile.color)
        let size = projectile.size ?? 5

        // Special rendering for Cyberboss energy blasts (simplified: 1 node, no animations)
        if projectile.weaponId == "cyberboss_blast" {
            let blast = SKShapeNode(circleOfRadius: size)
            blast.fillColor = color.withAlphaComponent(0.5)
            blast.strokeColor = color
            blast.lineWidth = 3
            blast.glowWidth = 0
            container.addChild(blast)
            return container
        }

        // Special rendering for Void Harbinger Shadow Bolts (simplified: 1 node, no animations)
        if projectile.weaponId == "void_bolt" {
            let voidCore = SKShapeNode(circleOfRadius: size)
            voidCore.fillColor = SKColor(hex: BalanceConfig.VoidHarbinger.voidCoreColor) ?? SKColor.black
            voidCore.strokeColor = color
            voidCore.lineWidth = 3
            voidCore.glowWidth = 0
            container.addChild(voidCore)
            return container
        }

        // Special rendering for Pylon Beams (simplified: 1 node, no animations)
        if projectile.weaponId == "pylon_beam" {
            let beamCore = SKShapeNode(circleOfRadius: size)
            beamCore.fillColor = color
            beamCore.strokeColor = SKColor(hex: BalanceConfig.VoidHarbinger.pylonBeamReticleColor) ?? SKColor.magenta
            beamCore.lineWidth = 2
            beamCore.glowWidth = 0
            container.addChild(beamCore)
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

        case .health:
            let heart = SKLabelNode(text: "♥")
            heart.fontSize = 16
            heart.fontColor = SKColor.red
            heart.verticalAlignmentMode = .center
            container.addChild(heart)

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
        let color: SKColor
        if let hexColor = particle.color {
            color = colorFromHex(hexColor)
        } else {
            color = SKColor.white
        }

        let size = particle.size ?? 5

        // Return a single SKShapeNode directly (no container wrapper)
        let node: SKShapeNode
        switch particle.shape {
        case .star:
            node = SKShapeNode(path: starPath(size: size, points: 5))
        case .spark:
            node = SKShapeNode(rectOf: CGSize(width: size * 2, height: size * 0.5))
        case .square:
            node = SKShapeNode(rectOf: CGSize(width: size, height: size))
        case .diamond:
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: size))
            path.addLine(to: CGPoint(x: size, y: 0))
            path.addLine(to: CGPoint(x: 0, y: -size))
            path.addLine(to: CGPoint(x: -size, y: 0))
            path.closeSubpath()
            node = SKShapeNode(path: path)
        default:
            node = SKShapeNode(circleOfRadius: size)
        }

        node.fillColor = color
        node.strokeColor = .clear

        if let rotation = particle.rotation {
            node.zRotation = rotation
        }

        return node
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
