import SpriteKit
import UIKit

// MARK: - Platform Creation

extension TowerVisualFactory {

    // MARK: - Platform Helpers

    static func createOctagonPlatform(radius: CGFloat, color: UIColor) -> SKShapeNode {
        let path = UIBezierPath()
        for i in 0..<8 {
            let angle = CGFloat(i) * .pi / 4 - .pi / 8
            let point = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.close()

        let platform = SKShapeNode(path: path.cgPath)
        platform.fillColor = color.withAlphaComponent(0.15)
        platform.strokeColor = color.withAlphaComponent(0.4)
        platform.lineWidth = 1
        return platform
    }

    static func createReinforcedSquare(size: CGFloat, color: UIColor) -> SKShapeNode {
        let platform = SKShapeNode(rectOf: CGSize(width: size, height: size), cornerRadius: 3)
        platform.fillColor = color.withAlphaComponent(0.15)
        platform.strokeColor = color.withAlphaComponent(0.5)
        platform.lineWidth = 2
        return platform
    }

    static func createCrystalBase(size: CGFloat, color: UIColor) -> SKShapeNode {
        let path = createDiamondPath(size: size)
        let platform = SKShapeNode(path: path)
        platform.fillColor = color.withAlphaComponent(0.1)
        platform.strokeColor = UIColor.cyan.withAlphaComponent(0.4)
        platform.lineWidth = 1
        platform.glowWidth = 3
        return platform
    }

    static func createArcaneCircle(radius: CGFloat, color: UIColor) -> SKShapeNode {
        let container = SKShapeNode()
        container.fillColor = .clear
        container.strokeColor = .clear

        // Outer circle
        let outer = SKShapeNode(circleOfRadius: radius)
        outer.fillColor = .clear
        outer.strokeColor = color.withAlphaComponent(0.5)
        outer.lineWidth = 2
        outer.glowWidth = 3
        container.addChild(outer)

        // Inner circle
        let inner = SKShapeNode(circleOfRadius: radius * 0.7)
        inner.fillColor = color.withAlphaComponent(0.1)
        inner.strokeColor = color.withAlphaComponent(0.3)
        inner.lineWidth = 1
        container.addChild(inner)

        // Rune markers
        for i in 0..<6 {
            let angle = CGFloat(i) * .pi / 3
            let marker = SKShapeNode(circleOfRadius: 2)
            marker.fillColor = color
            marker.strokeColor = .clear
            marker.glowWidth = 2
            marker.position = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
            container.addChild(marker)
        }

        return container
    }

    static func createTechGrid(size: CGFloat, color: UIColor) -> SKShapeNode {
        let platform = SKShapeNode(rectOf: CGSize(width: size, height: size), cornerRadius: 4)
        platform.fillColor = color.withAlphaComponent(0.1)
        platform.strokeColor = color.withAlphaComponent(0.4)
        platform.lineWidth = 1

        // Grid lines
        let gridPath = UIBezierPath()
        let half = size / 2
        let third = size / 3

        // Horizontal
        gridPath.move(to: CGPoint(x: -half, y: third - half))
        gridPath.addLine(to: CGPoint(x: half, y: third - half))
        gridPath.move(to: CGPoint(x: -half, y: 2 * third - half))
        gridPath.addLine(to: CGPoint(x: half, y: 2 * third - half))

        // Vertical
        gridPath.move(to: CGPoint(x: third - half, y: -half))
        gridPath.addLine(to: CGPoint(x: third - half, y: half))
        gridPath.move(to: CGPoint(x: 2 * third - half, y: -half))
        gridPath.addLine(to: CGPoint(x: 2 * third - half, y: half))

        let grid = SKShapeNode(path: gridPath.cgPath)
        grid.strokeColor = color.withAlphaComponent(0.2)
        grid.lineWidth = 0.5
        platform.addChild(grid)

        return platform
    }

    static func createInsulatorBase(radius: CGFloat, color: UIColor) -> SKShapeNode {
        let platform = SKShapeNode(circleOfRadius: radius)
        platform.fillColor = UIColor.darkGray.withAlphaComponent(0.8)
        platform.strokeColor = color.withAlphaComponent(0.6)
        platform.lineWidth = 2

        // Insulator rings
        let ringPath = UIBezierPath()
        ringPath.addArc(withCenter: .zero, radius: radius * 0.7, startAngle: 0, endAngle: .pi * 2, clockwise: true)
        let ring = SKShapeNode(path: ringPath.cgPath)
        ring.strokeColor = color.withAlphaComponent(0.3)
        ring.lineWidth = 1
        platform.addChild(ring)

        return platform
    }

    static func createIndustrialBase(size: CGFloat, color: UIColor) -> SKShapeNode {
        let platform = SKShapeNode(rectOf: CGSize(width: size, height: size - 4), cornerRadius: 2)
        platform.fillColor = UIColor.darkGray.withAlphaComponent(0.8)
        platform.strokeColor = .gray
        platform.lineWidth = 2
        return platform
    }

    static func createSacredPlatform(radius: CGFloat, color: UIColor) -> SKShapeNode {
        let container = SKShapeNode()
        container.fillColor = .clear
        container.strokeColor = .clear

        // Outer ring
        let outer = SKShapeNode(circleOfRadius: radius)
        outer.fillColor = UIColor(hex: "f59e0b")?.withAlphaComponent(0.15) ?? color.withAlphaComponent(0.15)
        outer.strokeColor = UIColor(hex: "fbbf24") ?? .yellow
        outer.lineWidth = 2
        outer.glowWidth = 4
        container.addChild(outer)

        // Inner sacred geometry (hexagram)
        let innerPath = UIBezierPath()
        for i in 0..<6 {
            let angle = CGFloat(i) * .pi / 3 - .pi / 2
            let point = CGPoint(x: cos(angle) * radius * 0.8, y: sin(angle) * radius * 0.8)
            if i == 0 {
                innerPath.move(to: point)
            } else {
                innerPath.addLine(to: point)
            }
        }
        innerPath.close()

        let inner = SKShapeNode(path: innerPath.cgPath)
        inner.fillColor = .clear
        inner.strokeColor = UIColor(hex: "fbbf24")?.withAlphaComponent(0.5) ?? .yellow.withAlphaComponent(0.5)
        inner.lineWidth = 1
        inner.name = "sacredGeometry"
        container.addChild(inner)

        return container
    }

    static func createServerRackBase(size: CGFloat, color: UIColor) -> SKShapeNode {
        let platform = SKShapeNode(rectOf: CGSize(width: size, height: size), cornerRadius: 3)
        platform.fillColor = UIColor.darkGray.withAlphaComponent(0.7)
        platform.strokeColor = color.withAlphaComponent(0.5)
        platform.lineWidth = 1

        // Server rack slots
        for i in 0..<3 {
            let slot = SKShapeNode(rectOf: CGSize(width: size - 8, height: 4), cornerRadius: 1)
            slot.fillColor = color.withAlphaComponent(0.2)
            slot.strokeColor = color.withAlphaComponent(0.4)
            slot.lineWidth = 0.5
            slot.position = CGPoint(x: 0, y: CGFloat(i - 1) * 8)
            platform.addChild(slot)
        }

        return platform
    }

    static func createCorruptedPlatform(size: CGFloat, color: UIColor) -> SKShapeNode {
        let platform = SKShapeNode(rectOf: CGSize(width: size, height: size), cornerRadius: 2)
        platform.fillColor = UIColor.black.withAlphaComponent(0.8)
        platform.strokeColor = UIColor(hex: "ef4444") ?? .red
        platform.lineWidth = 2
        platform.glowWidth = 4

        return platform
    }

    // MARK: - Utility Helpers

    private static func createDiamondPath(size: CGFloat) -> CGPath {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: size / 2))
        path.addLine(to: CGPoint(x: size / 2, y: 0))
        path.addLine(to: CGPoint(x: 0, y: -size / 2))
        path.addLine(to: CGPoint(x: -size / 2, y: 0))
        path.close()
        return path.cgPath
    }
}
