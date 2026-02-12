import SpriteKit
import UIKit

// MARK: - Detail Elements

extension TowerVisualFactory {

    // MARK: - Archetype Detail Elements

    static func createDetailElements(archetype: TowerArchetype, weaponType: String, color: UIColor, rarity: RarityTier) -> SKNode {
        let container = SKNode()

        switch archetype {
        case .frost:
            // Orbiting ice shards
            for i in 0..<3 {
                let shard = createIceShard(index: i, color: color)
                shard.name = "iceShard_\(i)"
                container.addChild(shard)
            }

        case .tesla:
            // Electric arc nodes
            addElectricArcs(to: container, color: color)

        case .legendary:
            // Divine particles and light rays
            addDivineParticles(to: container)

        case .execute:
            // Glitch artifacts
            addGlitchArtifacts(to: container)

        default:
            break
        }

        return container
    }

    private static func createIceShard(index: Int, color: UIColor) -> SKNode {
        let container = SKNode()

        let angle = CGFloat(index) * 2 * .pi / 3
        let radius: CGFloat = 22

        let shard = SKShapeNode(rectOf: CGSize(width: 4, height: 10), cornerRadius: 1)
        shard.fillColor = color.withAlphaComponent(0.8)
        shard.strokeColor = .cyan
        shard.lineWidth = 1
        shard.glowWidth = 1.0  // Frost shimmer (3 shards per tower)
        shard.position = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
        shard.zRotation = angle + .pi / 2
        container.addChild(shard)

        return container
    }

    private static func addElectricArcs(to container: SKNode, color: UIColor) {
        // Static arc placeholder - animation will create dynamic arcs
        let arcIndicator = SKNode()
        arcIndicator.name = "arcContainer"
        container.addChild(arcIndicator)
    }

    private static func addDivineParticles(to container: SKNode) {
        // Particle container for animation
        let particleContainer = SKNode()
        particleContainer.name = "divineParticles"
        container.addChild(particleContainer)
    }

    private static func addGlitchArtifacts(to container: SKNode) {
        // Glitch container for animation
        let glitchContainer = SKNode()
        glitchContainer.name = "glitchContainer"
        container.addChild(glitchContainer)
    }

    // MARK: - Circuit Traces

    static func addCircuitTraces(to container: SKNode, style: CircuitStyle, color: UIColor) {
        let tracePath = UIBezierPath()

        switch style {
        case .targeting:
            // Cross pattern traces
            tracePath.move(to: CGPoint(x: -20, y: 0))
            tracePath.addLine(to: CGPoint(x: -8, y: 0))
            tracePath.move(to: CGPoint(x: 8, y: 0))
            tracePath.addLine(to: CGPoint(x: 20, y: 0))
            tracePath.move(to: CGPoint(x: 0, y: -20))
            tracePath.addLine(to: CGPoint(x: 0, y: -8))
            tracePath.move(to: CGPoint(x: 0, y: 8))
            tracePath.addLine(to: CGPoint(x: 0, y: 20))
        }

        let traces = SKShapeNode(path: tracePath.cgPath)
        traces.strokeColor = color.withAlphaComponent(0.3)
        traces.lineWidth = 1
        traces.name = "circuitTraces"
        container.addChild(traces)
    }

    enum CircuitStyle {
        case targeting
    }

    // MARK: - Corner Bolts
    // PERF: Batched 4 individual bolt nodes into single compound path (4→1 node)

    static func addCornerBolts(to container: SKNode, size: CGFloat, color: UIColor) {
        let offset = size / 2 - 4
        let boltRadius: CGFloat = 3
        let positions = [
            CGPoint(x: -offset, y: -offset),
            CGPoint(x: offset, y: -offset),
            CGPoint(x: -offset, y: offset),
            CGPoint(x: offset, y: offset)
        ]

        let boltsPath = CGMutablePath()
        for pos in positions {
            boltsPath.addEllipse(in: CGRect(x: pos.x - boltRadius, y: pos.y - boltRadius,
                                             width: boltRadius * 2, height: boltRadius * 2))
        }

        let bolts = SKShapeNode(path: boltsPath)
        bolts.fillColor = .gray
        bolts.strokeColor = color.withAlphaComponent(0.5)
        bolts.lineWidth = 1
        bolts.name = "bolts"
        container.addChild(bolts)
    }

    // MARK: - Frost Particles

    static func addFrostParticles(to container: SKNode, color: UIColor) {
        let particleContainer = SKNode()
        particleContainer.name = "frostParticles"
        container.addChild(particleContainer)
    }

    // MARK: - Capacitor Nodes
    // PERF: Batched 4 individual capacitor nodes into single compound path (4→1 node)

    static func addCapacitorNodes(to container: SKNode, color: UIColor) {
        let positions = [
            CGPoint(x: -14, y: -14),
            CGPoint(x: 14, y: -14),
            CGPoint(x: -14, y: 14),
            CGPoint(x: 14, y: 14)
        ]

        let capsPath = CGMutablePath()
        for pos in positions {
            capsPath.addRoundedRect(in: CGRect(x: pos.x - 3, y: pos.y - 4, width: 6, height: 8),
                                     cornerWidth: 1, cornerHeight: 1)
        }

        let caps = SKShapeNode(path: capsPath)
        caps.fillColor = color.withAlphaComponent(0.5)
        caps.strokeColor = color
        caps.lineWidth = 1
        caps.glowWidth = 0
        caps.name = "capacitors"
        container.addChild(caps)
    }

    // MARK: - Hazard Stripes

    static func addHazardStripes(to container: SKNode) {
        let stripePath = UIBezierPath()
        for i in 0..<4 {
            let x = CGFloat(i - 2) * 8 + 4
            stripePath.move(to: CGPoint(x: x, y: -15))
            stripePath.addLine(to: CGPoint(x: x + 4, y: -15))
            stripePath.addLine(to: CGPoint(x: x - 4, y: -11))
            stripePath.addLine(to: CGPoint(x: x - 8, y: -11))
            stripePath.close()
        }

        let stripes = SKShapeNode(path: stripePath.cgPath)
        stripes.fillColor = .yellow
        stripes.strokeColor = .clear
        stripes.alpha = 0.5
        stripes.name = "hazardStripes"
        container.addChild(stripes)
    }

    // MARK: - Divine Rays
    // PERF: Batched 4 individual ray nodes into single compound path (4→1 node)

    static func addDivineRays(to container: SKNode, color: UIColor) {
        let raysPath = CGMutablePath()
        for i in 0..<4 {
            let angle = CGFloat(i) * .pi / 2
            raysPath.move(to: CGPoint(x: cos(angle) * 20, y: sin(angle) * 20))
            raysPath.addLine(to: CGPoint(x: cos(angle) * 40, y: sin(angle) * 40))
        }

        let rays = SKShapeNode(path: raysPath)
        rays.strokeColor = UIColor(hex: "fbbf24")?.withAlphaComponent(0.4) ?? .yellow.withAlphaComponent(0.4)
        rays.lineWidth = 3
        rays.glowWidth = 1.5  // Divine radiance (1 batched node per legendary tower)
        rays.blendMode = .add
        rays.name = "divineRays"
        container.addChild(rays)
    }
}
