import SpriteKit
import UIKit

// MARK: - Tower Body Creation

extension TowerVisualFactory {

    // MARK: - Tower Bodies

    static func createTowerBody(archetype: TowerArchetype, protocolId: String, color: UIColor, rarity: RarityTier) -> SKShapeNode {
        switch archetype {
        case .scanner:
            return createReticleBody(color: color, rarity: rarity)
        case .payload:
            return createArtilleryBody(color: color, rarity: rarity)
        case .cryowall:
            return createCrystalBody(color: color, rarity: rarity)
        case .rootkit:
            return createEmitterBody(color: color, rarity: rarity)
        case .overload:
            return createTeslaBody(color: color, rarity: rarity)
        case .forkbomb:
            return createReplicatorBody(color: color, rarity: rarity)
        case .exception:
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
