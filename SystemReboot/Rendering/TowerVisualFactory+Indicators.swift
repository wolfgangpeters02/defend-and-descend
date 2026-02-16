import SpriteKit
import UIKit

// MARK: - Tower Indicators

extension TowerVisualFactory {

    // MARK: - Level Indicator

    /// Create a level indicator showing tower level (1-10) as small pips
    static func createLevelIndicator(level: Int, archetype: TowerArchetype, color: UIColor) -> SKNode {
        let container = SKNode()

        // Show level as a compact badge
        let bgNode = SKShapeNode(rectOf: CGSize(width: 20, height: 12), cornerRadius: 3)
        bgNode.fillColor = UIColor.black.withAlphaComponent(0.8)
        bgNode.strokeColor = color.withAlphaComponent(0.6)
        bgNode.lineWidth = 1
        container.addChild(bgNode)

        // Level text
        let levelLabel = SKLabelNode(text: "\(level)")
        levelLabel.fontSize = 9
        levelLabel.fontName = "Menlo-Bold"
        levelLabel.fontColor = .white
        levelLabel.verticalAlignmentMode = .center
        levelLabel.horizontalAlignmentMode = .center
        levelLabel.name = "levelLabel"
        container.addChild(levelLabel)

        return container
    }

    // MARK: - Star Indicator (Merge Level)

    /// Create star indicator showing tower merge level (0-3 stars)
    /// Returns empty node for 0 stars (no visual)
    static func createStarIndicator(starLevel: Int, color: UIColor) -> SKNode {
        let container = SKNode()
        guard starLevel > 0 else { return container }

        // Build star string (e.g. "★★★")
        let starString = String(repeating: "\u{2605}", count: starLevel)

        // Background pill
        let bgWidth: CGFloat = CGFloat(12 + starLevel * 12)
        let bg = SKShapeNode(rectOf: CGSize(width: bgWidth, height: 16), cornerRadius: 4)
        bg.fillColor = UIColor.black.withAlphaComponent(0.85)
        bg.strokeColor = UIColor.yellow.withAlphaComponent(0.8)
        bg.lineWidth = 1.5
        bg.zPosition = -1
        container.addChild(bg)

        // Single label with all stars (more reliable rendering)
        let starLabel = SKLabelNode(text: starString)
        starLabel.fontSize = 12
        starLabel.fontName = "HelveticaNeue-Bold"
        starLabel.fontColor = .yellow
        starLabel.verticalAlignmentMode = .center
        starLabel.horizontalAlignmentMode = .center
        starLabel.name = "starChar"
        container.addChild(starLabel)

        return container
    }

    // MARK: - Range Indicator

    static func createRangeIndicator(range: CGFloat, color: UIColor) -> SKShapeNode {
        // Dashed outer ring using UIBezierPath with dash pattern
        let dashedPath = UIBezierPath(arcCenter: .zero, radius: range, startAngle: 0, endAngle: .pi * 2, clockwise: true)
        let dashPattern: [CGFloat] = [8, 4]
        dashedPath.setLineDash(dashPattern, count: dashPattern.count, phase: 0)

        let rangeCircle = SKShapeNode(path: dashedPath.cgPath)
        rangeCircle.fillColor = color.withAlphaComponent(0.12)
        rangeCircle.strokeColor = color.withAlphaComponent(0.5)
        rangeCircle.lineWidth = 2
        rangeCircle.glowWidth = 1.5  // Shown on select only (1 tower at a time)

        return rangeCircle
    }

    // MARK: - Cooldown Arc

    static func createCooldownArc(color: UIColor) -> SKShapeNode {
        let arc = SKShapeNode()
        arc.strokeColor = color.withAlphaComponent(0.8)
        arc.lineWidth = 3
        arc.lineCap = .round
        return arc
    }

    // MARK: - LOD Detail

    static func createLODDetail(damage: CGFloat, attackSpeed: CGFloat, projectileCount: Int, level: Int, color: UIColor) -> SKNode {
        let container = SKNode()

        // DPS calculation
        let dps = damage * attackSpeed * CGFloat(projectileCount)

        // DPS label background
        let dpsBg = SKShapeNode(rectOf: CGSize(width: 54, height: 16), cornerRadius: 3)
        dpsBg.fillColor = UIColor.black.withAlphaComponent(0.8)
        dpsBg.strokeColor = color.withAlphaComponent(0.6)
        dpsBg.lineWidth = 1
        dpsBg.position = CGPoint(x: 0, y: 30)
        container.addChild(dpsBg)

        // DPS label
        let dpsLabel = SKLabelNode(text: L10n.Stats.dpsValue(dps))
        dpsLabel.fontSize = 10
        dpsLabel.fontName = "Menlo-Bold"
        dpsLabel.fontColor = .white
        dpsLabel.verticalAlignmentMode = .center
        dpsLabel.horizontalAlignmentMode = .center
        dpsLabel.position = CGPoint(x: 0, y: 30)
        dpsLabel.name = "dpsLabel"
        container.addChild(dpsLabel)

        // Level badge
        let levelBadge = SKShapeNode(circleOfRadius: 9)
        levelBadge.fillColor = UIColor.black.withAlphaComponent(0.9)
        levelBadge.strokeColor = color
        levelBadge.lineWidth = 1.5
        levelBadge.position = CGPoint(x: 22, y: 16)
        container.addChild(levelBadge)

        let levelLabel = SKLabelNode(text: "\(level)")
        levelLabel.fontSize = 10
        levelLabel.fontName = "Menlo-Bold"
        levelLabel.fontColor = .white
        levelLabel.verticalAlignmentMode = .center
        levelLabel.horizontalAlignmentMode = .center
        levelLabel.position = CGPoint(x: 22, y: 16)
        levelLabel.name = "levelLabel"
        container.addChild(levelLabel)

        return container
    }

    // MARK: - Rarity Ring

    /// Creates a colored ring around the tower base indicating rarity
    static func createRarityRing(rarity: RarityTier) -> SKNode {
        let container = SKNode()

        // Get rarity color
        let rarityColor = RarityColors.uiColor(for: rarityColorString(rarity))

        // Ring radius and width based on rarity
        let radius: CGFloat
        let lineWidth: CGFloat
        let glowWidth: CGFloat

        switch rarity {
        case .common:
            radius = 22
            lineWidth = 1.5
            glowWidth = 0
        case .rare:
            radius = 23
            lineWidth = 2.0
            glowWidth = 0
        case .epic:
            radius = 24
            lineWidth = 2.5
            glowWidth = 1.0
        case .legendary:
            radius = 25
            lineWidth = 3.0
            glowWidth = 2.0
        }

        // Outer glow ring
        let glowRing = SKShapeNode(circleOfRadius: radius)
        glowRing.strokeColor = rarityColor.withAlphaComponent(rarity == .legendary ? 0.5 : 0.3)
        glowRing.lineWidth = lineWidth + 4
        glowRing.fillColor = .clear
        glowRing.glowWidth = glowWidth
        container.addChild(glowRing)

        // Main rarity ring
        let ring = SKShapeNode(circleOfRadius: radius)
        ring.strokeColor = rarityColor.withAlphaComponent(rarity == .common ? 0.4 : (rarity == .legendary ? 0.85 : 0.7))
        ring.lineWidth = lineWidth
        ring.fillColor = .clear
        container.addChild(ring)

        // Add corner accent nodes for epic/legendary
        if rarity == .epic || rarity == .legendary {
            let nodeCount = rarity == .legendary ? 8 : 4
            let nodeRadius: CGFloat = rarity == .legendary ? 3 : 2.5

            for i in 0..<nodeCount {
                let angle = CGFloat(i) * (2 * .pi / CGFloat(nodeCount)) - .pi / 2
                let x = cos(angle) * radius
                let y = sin(angle) * radius

                let node = SKShapeNode(circleOfRadius: nodeRadius)
                node.fillColor = rarityColor
                node.strokeColor = rarityColor.withAlphaComponent(0.5)
                node.lineWidth = 1
                node.glowWidth = rarity == .legendary ? 1.5 : 0.8
                node.position = CGPoint(x: x, y: y)
                container.addChild(node)
            }
        }

        // Legendary gets rotating inner ring
        if rarity == .legendary {
            let innerRing = SKShapeNode(circleOfRadius: radius - 4)
            innerRing.strokeColor = rarityColor.withAlphaComponent(0.3)
            innerRing.lineWidth = 1
            innerRing.fillColor = .clear
            innerRing.name = "legendaryInnerRing"

            // Rotating animation
            let rotate = SKAction.rotate(byAngle: .pi * 2, duration: 8.0)
            innerRing.run(SKAction.repeatForever(rotate))
            container.addChild(innerRing)
        }

        return container
    }

    /// Convert RarityTier to string for RarityColors lookup
    private static func rarityColorString(_ rarity: RarityTier) -> String {
        switch rarity {
        case .common: return "common"
        case .rare: return "rare"
        case .epic: return "epic"
        case .legendary: return "legendary"
        }
    }
}
