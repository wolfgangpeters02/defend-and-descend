import SpriteKit
import UIKit

// MARK: - Tower Body Creation

extension TowerVisualFactory {

    // MARK: - Tower Bodies

    static func createTowerBody(archetype: TowerArchetype, protocolId: String, color: UIColor, rarity: RarityTier) -> SKShapeNode {
        switch archetype {
        case .projectile:
            return createReticleBody(color: color, rarity: rarity)
        case .artillery:
            return createArtilleryBody(color: color, rarity: rarity)
        case .frost:
            return createCrystalBody(color: color, rarity: rarity)
        case .magic:
            return createArcaneBody(color: color, rarity: rarity)
        case .beam:
            return createEmitterBody(color: color, rarity: rarity)
        case .tesla:
            return createTeslaBody(color: color, rarity: rarity)
        case .pyro:
            return createIncineratorBody(color: color, rarity: rarity)
        case .legendary:
            return createDivineBody(color: color)
        case .multishot:
            return createReplicatorBody(color: color, rarity: rarity)
        case .execute:
            return createExceptionBody(color: color)
        }
    }

    // MARK: - Projectile Archetype (Reticle)

    private static func createReticleBody(color: UIColor, rarity: RarityTier) -> SKShapeNode {
        let container = SKShapeNode()
        container.fillColor = .clear
        container.strokeColor = .clear

        // Outer targeting ring
        let outerRing = SKShapeNode(circleOfRadius: 16)
        outerRing.fillColor = .clear
        outerRing.strokeColor = color
        outerRing.lineWidth = 2
        outerRing.glowWidth = 0
        outerRing.name = "outerRing"
        container.addChild(outerRing)

        // Inner targeting ring
        let innerRing = SKShapeNode(circleOfRadius: 10)
        innerRing.fillColor = color.withAlphaComponent(0.2)
        innerRing.strokeColor = color.withAlphaComponent(0.8)
        innerRing.lineWidth = 1.5
        container.addChild(innerRing)

        // Crosshairs (4 lines)
        for i in 0..<4 {
            let angle = CGFloat(i) * .pi / 2
            let crosshair = createCrosshairLine(angle: angle, innerRadius: 12, outerRadius: 18, color: color)
            crosshair.name = "crosshair_\(i)"
            container.addChild(crosshair)
        }

        // Corner brackets (4)
        for i in 0..<4 {
            let angle = CGFloat(i) * .pi / 2 + .pi / 4
            let bracket = createCornerBracket(angle: angle, radius: 14, color: color)
            bracket.name = "bracket_\(i)"
            container.addChild(bracket)
        }

        // Center dot
        let centerDot = SKShapeNode(circleOfRadius: 3)
        centerDot.fillColor = color
        centerDot.strokeColor = .white
        centerDot.lineWidth = 1
        centerDot.glowWidth = 0
        centerDot.name = "centerDot"
        container.addChild(centerDot)

        return container
    }

    private static func createCrosshairLine(angle: CGFloat, innerRadius: CGFloat, outerRadius: CGFloat, color: UIColor) -> SKShapeNode {
        let path = UIBezierPath()
        let innerPoint = CGPoint(x: cos(angle) * innerRadius, y: sin(angle) * innerRadius)
        let outerPoint = CGPoint(x: cos(angle) * outerRadius, y: sin(angle) * outerRadius)
        path.move(to: innerPoint)
        path.addLine(to: outerPoint)

        let line = SKShapeNode(path: path.cgPath)
        line.strokeColor = color
        line.lineWidth = 2
        line.lineCap = .round
        return line
    }

    private static func createCornerBracket(angle: CGFloat, radius: CGFloat, color: UIColor) -> SKShapeNode {
        let path = UIBezierPath()
        let bracketLength: CGFloat = 6
        let bracketWidth: CGFloat = 4

        let center = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)

        // L-shaped bracket
        let perpAngle1 = angle + .pi / 2
        let perpAngle2 = angle

        let p1 = CGPoint(x: center.x + cos(perpAngle1) * bracketLength, y: center.y + sin(perpAngle1) * bracketLength)
        let p2 = center
        let p3 = CGPoint(x: center.x + cos(perpAngle2) * bracketWidth, y: center.y + sin(perpAngle2) * bracketWidth)

        path.move(to: p1)
        path.addLine(to: p2)
        path.addLine(to: p3)

        let bracket = SKShapeNode(path: path.cgPath)
        bracket.strokeColor = color
        bracket.lineWidth = 2
        bracket.lineCap = .square
        return bracket
    }

    // MARK: - Artillery Archetype

    private static func createArtilleryBody(color: UIColor, rarity: RarityTier) -> SKShapeNode {
        let body = SKShapeNode(rectOf: CGSize(width: 28, height: 28), cornerRadius: 4)
        body.fillColor = color
        body.strokeColor = UIColor.gray
        body.lineWidth = 3

        // Armored plating lines
        let platePath = UIBezierPath()
        platePath.move(to: CGPoint(x: -14, y: 8))
        platePath.addLine(to: CGPoint(x: 14, y: 8))
        platePath.move(to: CGPoint(x: -14, y: -8))
        platePath.addLine(to: CGPoint(x: 14, y: -8))

        let plates = SKShapeNode(path: platePath.cgPath)
        plates.strokeColor = color.darker(by: 0.3)
        plates.lineWidth = 2
        body.addChild(plates)

        // Central ammo indicator
        let ammoGlow = SKShapeNode(circleOfRadius: 6)
        ammoGlow.fillColor = color.lighter(by: 0.3)
        ammoGlow.strokeColor = .clear
        ammoGlow.glowWidth = 0
        ammoGlow.blendMode = .add
        ammoGlow.name = "ammoGlow"
        body.addChild(ammoGlow)

        return body
    }

    // MARK: - Frost Archetype (Crystal)

    private static func createCrystalBody(color: UIColor, rarity: RarityTier) -> SKShapeNode {
        // Multi-faceted crystal shape
        let path = UIBezierPath()
        let size: CGFloat = 16

        // 6-pointed crystal
        for i in 0..<6 {
            let angle = CGFloat(i) * .pi / 3 - .pi / 2
            let radius = (i % 2 == 0) ? size : size * 0.6
            let point = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.close()

        let crystal = SKShapeNode(path: path.cgPath)
        crystal.fillColor = color.withAlphaComponent(0.7)
        crystal.strokeColor = UIColor.cyan
        crystal.lineWidth = 2
        crystal.glowWidth = 0

        // Inner crystal facet
        let innerPath = UIBezierPath()
        let innerSize: CGFloat = 8
        for i in 0..<6 {
            let angle = CGFloat(i) * .pi / 3 - .pi / 2 + .pi / 6
            let point = CGPoint(x: cos(angle) * innerSize, y: sin(angle) * innerSize)
            if i == 0 {
                innerPath.move(to: point)
            } else {
                innerPath.addLine(to: point)
            }
        }
        innerPath.close()

        let innerCrystal = SKShapeNode(path: innerPath.cgPath)
        innerCrystal.fillColor = UIColor.white.withAlphaComponent(0.3)
        innerCrystal.strokeColor = UIColor.cyan.withAlphaComponent(0.8)
        innerCrystal.lineWidth = 1
        crystal.addChild(innerCrystal)

        return crystal
    }

    // MARK: - Magic Archetype (Arcane)

    private static func createArcaneBody(color: UIColor, rarity: RarityTier) -> SKShapeNode {
        let container = SKShapeNode()
        container.fillColor = .clear
        container.strokeColor = .clear

        // Floating orb platform
        let orbPlatform = SKShapeNode(circleOfRadius: 12)
        orbPlatform.fillColor = color.withAlphaComponent(0.3)
        orbPlatform.strokeColor = color
        orbPlatform.lineWidth = 2
        orbPlatform.glowWidth = 0
        container.addChild(orbPlatform)

        // Central power orb
        let orb = SKShapeNode(circleOfRadius: 8)
        orb.fillColor = color
        orb.strokeColor = .white
        orb.lineWidth = 1
        orb.glowWidth = 0
        orb.blendMode = .add
        orb.name = "powerOrb"
        container.addChild(orb)

        // Orbiting rune symbols (3)
        for i in 0..<3 {
            let angle = CGFloat(i) * 2 * .pi / 3
            let runeOrbit = SKNode()
            runeOrbit.name = "runeOrbit_\(i)"

            let rune = createRuneSymbol(index: i, color: color)
            rune.position = CGPoint(x: cos(angle) * 16, y: sin(angle) * 16)
            runeOrbit.addChild(rune)
            container.addChild(runeOrbit)
        }

        return container
    }

    private static func createRuneSymbol(index: Int, color: UIColor) -> SKShapeNode {
        let rune = SKShapeNode(circleOfRadius: 4)
        rune.fillColor = color.withAlphaComponent(0.8)
        rune.strokeColor = .white
        rune.lineWidth = 1
        rune.glowWidth = 0
        rune.name = "rune_\(index)"
        return rune
    }

    // MARK: - Beam Archetype (Tech Emitter)

    private static func createEmitterBody(color: UIColor, rarity: RarityTier) -> SKShapeNode {
        let body = SKShapeNode(rectOf: CGSize(width: 26, height: 26), cornerRadius: 6)
        body.fillColor = color.withAlphaComponent(0.8)
        body.strokeColor = .white
        body.lineWidth = 2

        // Central lens
        let lens = SKShapeNode(circleOfRadius: 8)
        lens.fillColor = color.lighter(by: 0.4)
        lens.strokeColor = .white
        lens.lineWidth = 2
        lens.glowWidth = 0
        lens.name = "lens"
        body.addChild(lens)

        // Lens inner ring
        let lensInner = SKShapeNode(circleOfRadius: 4)
        lensInner.fillColor = .white.withAlphaComponent(0.5)
        lensInner.strokeColor = .clear
        lensInner.glowWidth = 0
        lens.addChild(lensInner)

        return body
    }

    // MARK: - Tesla Archetype

    private static func createTeslaBody(color: UIColor, rarity: RarityTier) -> SKShapeNode {
        let container = SKShapeNode()
        container.fillColor = .clear
        container.strokeColor = .clear

        // Cylindrical base representation
        let base = SKShapeNode(ellipseOf: CGSize(width: 28, height: 14))
        base.fillColor = color.withAlphaComponent(0.6)
        base.strokeColor = .white
        base.lineWidth = 2
        base.position = CGPoint(x: 0, y: -4)
        container.addChild(base)

        // Central conductor spike
        let spike = SKShapeNode(rectOf: CGSize(width: 6, height: 20), cornerRadius: 2)
        spike.fillColor = color
        spike.strokeColor = UIColor.cyan
        spike.lineWidth = 2
        spike.glowWidth = 0
        spike.position = CGPoint(x: 0, y: 4)
        spike.name = "conductor"
        container.addChild(spike)

        // Discharge nodes (4)
        for i in 0..<4 {
            let angle = CGFloat(i) * .pi / 2
            let node = SKShapeNode(circleOfRadius: 3)
            node.fillColor = UIColor.cyan
            node.strokeColor = .white
            node.lineWidth = 1
            node.glowWidth = 0
            node.position = CGPoint(x: cos(angle) * 12, y: sin(angle) * 12 + 4)
            node.name = "dischargeNode_\(i)"
            container.addChild(node)
        }

        return container
    }

    // MARK: - Pyro Archetype (Incinerator)

    private static func createIncineratorBody(color: UIColor, rarity: RarityTier) -> SKShapeNode {
        let body = SKShapeNode(rectOf: CGSize(width: 28, height: 24), cornerRadius: 4)
        body.fillColor = color.withAlphaComponent(0.8)
        body.strokeColor = .gray
        body.lineWidth = 3

        // Fuel tanks (2 cylinders)
        let leftTank = SKShapeNode(ellipseOf: CGSize(width: 8, height: 16))
        leftTank.fillColor = UIColor.darkGray
        leftTank.strokeColor = color
        leftTank.lineWidth = 1
        leftTank.position = CGPoint(x: -8, y: 0)
        leftTank.name = "leftTank"
        body.addChild(leftTank)

        let rightTank = SKShapeNode(ellipseOf: CGSize(width: 8, height: 16))
        rightTank.fillColor = UIColor.darkGray
        rightTank.strokeColor = color
        rightTank.lineWidth = 1
        rightTank.position = CGPoint(x: 8, y: 0)
        rightTank.name = "rightTank"
        body.addChild(rightTank)

        // Pilot flame indicator
        let pilotFlame = SKShapeNode(circleOfRadius: 4)
        pilotFlame.fillColor = UIColor.orange
        pilotFlame.strokeColor = UIColor.yellow
        pilotFlame.lineWidth = 1
        pilotFlame.glowWidth = 0
        pilotFlame.blendMode = .add
        pilotFlame.name = "pilotFlame"
        body.addChild(pilotFlame)

        return body
    }

    // MARK: - Legendary Archetype (Divine)

    private static func createDivineBody(color: UIColor) -> SKShapeNode {
        let container = SKShapeNode()
        container.fillColor = .clear
        container.strokeColor = .clear

        // Sacred circle base
        let circle = SKShapeNode(circleOfRadius: 18)
        circle.fillColor = UIColor(hex: "f59e0b")?.withAlphaComponent(0.3) ?? color.withAlphaComponent(0.3)
        circle.strokeColor = UIColor(hex: "f59e0b") ?? color
        circle.lineWidth = 2
        circle.glowWidth = 0
        container.addChild(circle)

        // Floating sword silhouette
        let swordPath = createSwordPath()
        let sword = SKShapeNode(path: swordPath)
        sword.fillColor = UIColor(hex: "fbbf24") ?? .yellow
        sword.strokeColor = .white
        sword.lineWidth = 1
        sword.glowWidth = 0
        sword.name = "sword"
        container.addChild(sword)

        // Divine aura particles (handled in detail elements)

        return container
    }

    private static func createSwordPath() -> CGPath {
        let path = UIBezierPath()
        // Simplified sword shape
        path.move(to: CGPoint(x: 0, y: 14))     // Tip
        path.addLine(to: CGPoint(x: 3, y: 4))   // Right edge
        path.addLine(to: CGPoint(x: 6, y: 2))   // Right guard
        path.addLine(to: CGPoint(x: 6, y: 0))
        path.addLine(to: CGPoint(x: 2, y: 0))   // Handle top
        path.addLine(to: CGPoint(x: 2, y: -10)) // Handle
        path.addLine(to: CGPoint(x: 4, y: -12)) // Pommel
        path.addLine(to: CGPoint(x: 0, y: -14)) // Pommel bottom
        path.addLine(to: CGPoint(x: -4, y: -12))
        path.addLine(to: CGPoint(x: -2, y: -10))
        path.addLine(to: CGPoint(x: -2, y: 0))
        path.addLine(to: CGPoint(x: -6, y: 0))
        path.addLine(to: CGPoint(x: -6, y: 2))  // Left guard
        path.addLine(to: CGPoint(x: -3, y: 4))  // Left edge
        path.close()
        return path.cgPath
    }

    // MARK: - Multishot Archetype (Replicator)

    private static func createReplicatorBody(color: UIColor, rarity: RarityTier) -> SKShapeNode {
        let container = SKShapeNode()
        container.fillColor = .clear
        container.strokeColor = .clear

        // Central hub
        let hub = SKShapeNode(circleOfRadius: 8)
        hub.fillColor = color
        hub.strokeColor = .white
        hub.lineWidth = 2
        hub.glowWidth = 0
        hub.name = "hub"
        container.addChild(hub)

        // Process nodes (5 in pentagon)
        for i in 0..<5 {
            let angle = CGFloat(i) * 2 * .pi / 5 - .pi / 2
            let node = SKShapeNode(circleOfRadius: 5)
            node.fillColor = color.withAlphaComponent(0.7)
            node.strokeColor = color
            node.lineWidth = 1
            node.glowWidth = 0
            node.position = CGPoint(x: cos(angle) * 14, y: sin(angle) * 14)
            node.name = "processNode_\(i)"
            container.addChild(node)

            // Connection line to hub
            let linePath = UIBezierPath()
            linePath.move(to: .zero)
            linePath.addLine(to: node.position)
            let line = SKShapeNode(path: linePath.cgPath)
            line.strokeColor = color.withAlphaComponent(0.5)
            line.lineWidth = 1
            line.name = "connection_\(i)"
            container.addChild(line)
        }

        return container
    }

    // MARK: - Execute Archetype (Exception)

    private static func createExceptionBody(color: UIColor) -> SKShapeNode {
        let container = SKShapeNode()
        container.fillColor = .clear
        container.strokeColor = .clear

        // Warning triangle
        let trianglePath = UIBezierPath()
        let size: CGFloat = 18
        trianglePath.move(to: CGPoint(x: 0, y: size))
        trianglePath.addLine(to: CGPoint(x: -size * 0.866, y: -size * 0.5))
        trianglePath.addLine(to: CGPoint(x: size * 0.866, y: -size * 0.5))
        trianglePath.close()

        let triangle = SKShapeNode(path: trianglePath.cgPath)
        triangle.fillColor = UIColor(hex: "ef4444")?.withAlphaComponent(0.8) ?? .red.withAlphaComponent(0.8)
        triangle.strokeColor = UIColor(hex: "ef4444") ?? .red
        triangle.lineWidth = 2
        triangle.glowWidth = 0
        triangle.name = "warningTriangle"
        container.addChild(triangle)

        // Exclamation mark
        let exclamation = SKLabelNode(text: "!")
        exclamation.fontName = "Menlo-Bold"
        exclamation.fontSize = 16
        exclamation.fontColor = .white
        exclamation.verticalAlignmentMode = .center
        exclamation.horizontalAlignmentMode = .center
        exclamation.position = CGPoint(x: 0, y: 2)
        exclamation.name = "exclamation"
        container.addChild(exclamation)

        return container
    }
}
