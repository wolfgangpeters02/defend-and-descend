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
        body.glowWidth = 3
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

        switch enemy.shape ?? "circle" {
        case "square":
            let square = SKShapeNode(rectOf: CGSize(width: size * 2, height: size * 2))
            square.fillColor = color
            square.strokeColor = color.darker(by: 0.3)
            square.lineWidth = 2
            container.addChild(square)

        case "triangle":
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: size))
            path.addLine(to: CGPoint(x: -size * 0.866, y: -size * 0.5))
            path.addLine(to: CGPoint(x: size * 0.866, y: -size * 0.5))
            path.closeSubpath()

            let triangle = SKShapeNode(path: path)
            triangle.fillColor = color
            triangle.strokeColor = color.darker(by: 0.3)
            triangle.lineWidth = 2
            container.addChild(triangle)

        case "hexagon":
            let path = hexagonPath(size: size)
            let hexagon = SKShapeNode(path: path)
            hexagon.fillColor = color
            hexagon.strokeColor = color.darker(by: 0.3)
            hexagon.lineWidth = 2
            container.addChild(hexagon)

            // Boss glow effect
            if enemy.isBoss {
                hexagon.glowWidth = 5

                let pulse = SKAction.sequence([
                    SKAction.scale(to: 1.15, duration: 0.3),
                    SKAction.scale(to: 1.0, duration: 0.3)
                ])
                container.run(SKAction.repeatForever(pulse))
            }

        default: // Circle
            let circle = SKShapeNode(circleOfRadius: size)
            circle.fillColor = color
            circle.strokeColor = color.darker(by: 0.3)
            circle.lineWidth = 2
            container.addChild(circle)
        }

        // Health bar for bosses
        if enemy.isBoss {
            let healthBarWidth = size * 3
            let healthBarHeight: CGFloat = 6

            let bgBar = SKShapeNode(rectOf: CGSize(width: healthBarWidth, height: healthBarHeight))
            bgBar.fillColor = SKColor.darkGray
            bgBar.strokeColor = SKColor.white
            bgBar.lineWidth = 1
            bgBar.position = CGPoint(x: 0, y: size + 15)
            bgBar.name = "healthBarBg"
            container.addChild(bgBar)

            let healthPercent = enemy.health / enemy.maxHealth
            let fillBar = SKShapeNode(rect: CGRect(
                x: -healthBarWidth / 2,
                y: -healthBarHeight / 2,
                width: healthBarWidth * healthPercent,
                height: healthBarHeight
            ))
            fillBar.fillColor = SKColor.red
            fillBar.strokeColor = SKColor.clear
            fillBar.position = bgBar.position
            fillBar.name = "healthBarFill"
            container.addChild(fillBar)
        }

        return container
    }

    // MARK: - Projectile

    func createProjectileNode(projectile: Projectile) -> SKNode {
        let container = SKNode()

        let color = colorFromHex(projectile.color)
        let size = projectile.size ?? 5

        // Main projectile
        let body = SKShapeNode(circleOfRadius: size)
        body.fillColor = color
        body.strokeColor = color.lighter(by: 0.3)
        body.lineWidth = 1
        body.glowWidth = 2
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
        case "coin":
            // Blue data triangle (◈ shape) - Dark Terminal aesthetic
            let dataColor = SKColor(red: 0, green: 0.831, blue: 1, alpha: 1) // #00d4ff cyan
            let dataColorLight = SKColor(red: 0.4, green: 0.9, blue: 1, alpha: 1) // lighter cyan for stroke

            // Create diamond/rhombus shape (◈)
            let size: CGFloat = 8
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: size))           // top
            path.addLine(to: CGPoint(x: size * 0.7, y: 0))  // right
            path.addLine(to: CGPoint(x: 0, y: -size))       // bottom
            path.addLine(to: CGPoint(x: -size * 0.7, y: 0)) // left
            path.closeSubpath()

            let dataTriangle = SKShapeNode(path: path)
            dataTriangle.fillColor = dataColor
            dataTriangle.strokeColor = dataColorLight
            dataTriangle.lineWidth = 1.5
            dataTriangle.glowWidth = 3
            container.addChild(dataTriangle)

            // Spinning animation
            let spin = SKAction.rotate(byAngle: .pi * 2, duration: 2.0)
            container.run(SKAction.repeatForever(spin))

            // Bobbing animation (float effect)
            let bob = SKAction.sequence([
                SKAction.moveBy(x: 0, y: 3, duration: 0.4),
                SKAction.moveBy(x: 0, y: -3, duration: 0.4)
            ])
            container.run(SKAction.repeatForever(bob))

        case "health":
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

        default:
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
