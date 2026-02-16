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
        platform.glowWidth = 0
        return platform
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

    // PERF: Batched 3 server rack slot nodes into single compound path (3→1 node)
    static func createServerRackBase(size: CGFloat, color: UIColor) -> SKShapeNode {
        let platform = SKShapeNode(rectOf: CGSize(width: size, height: size), cornerRadius: 3)
        platform.fillColor = UIColor.darkGray.withAlphaComponent(0.7)
        platform.strokeColor = color.withAlphaComponent(0.5)
        platform.lineWidth = 1

        // Server rack slots — batched into single compound path
        let slotsPath = CGMutablePath()
        let slotW = size - 8
        let slotH: CGFloat = 4
        for i in 0..<3 {
            let y = CGFloat(i - 1) * 8
            slotsPath.addRoundedRect(in: CGRect(x: -slotW / 2, y: y - slotH / 2, width: slotW, height: slotH),
                                      cornerWidth: 1, cornerHeight: 1)
        }
        let slots = SKShapeNode(path: slotsPath)
        slots.fillColor = color.withAlphaComponent(0.2)
        slots.strokeColor = color.withAlphaComponent(0.4)
        slots.lineWidth = 0.5
        platform.addChild(slots)

        return platform
    }

    static func createCorruptedPlatform(size: CGFloat, color: UIColor) -> SKShapeNode {
        let platform = SKShapeNode(rectOf: CGSize(width: size, height: size), cornerRadius: 2)
        platform.fillColor = UIColor.black.withAlphaComponent(0.8)
        platform.strokeColor = UIColor(hex: "ef4444") ?? .red
        platform.lineWidth = 2
        platform.glowWidth = 0

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
