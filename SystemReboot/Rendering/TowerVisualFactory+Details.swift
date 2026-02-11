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
        shard.glowWidth = 3
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

    static func addCornerBolts(to container: SKNode, size: CGFloat, color: UIColor) {
        let offset = size / 2 - 4
        let positions = [
            CGPoint(x: -offset, y: -offset),
            CGPoint(x: offset, y: -offset),
            CGPoint(x: -offset, y: offset),
            CGPoint(x: offset, y: offset)
        ]

        for (i, pos) in positions.enumerated() {
            let bolt = SKShapeNode(circleOfRadius: 3)
            bolt.fillColor = .gray
            bolt.strokeColor = color.withAlphaComponent(0.5)
            bolt.lineWidth = 1
            bolt.position = pos
            bolt.name = "bolt_\(i)"
            container.addChild(bolt)
        }
    }

    // MARK: - Frost Particles

    static func addFrostParticles(to container: SKNode, color: UIColor) {
        let particleContainer = SKNode()
        particleContainer.name = "frostParticles"
        container.addChild(particleContainer)
    }

    // MARK: - Capacitor Nodes

    static func addCapacitorNodes(to container: SKNode, color: UIColor) {
        let positions = [
            CGPoint(x: -14, y: -14),
            CGPoint(x: 14, y: -14),
            CGPoint(x: -14, y: 14),
            CGPoint(x: 14, y: 14)
        ]

        for (i, pos) in positions.enumerated() {
            let capacitor = SKShapeNode(rectOf: CGSize(width: 6, height: 8), cornerRadius: 1)
            capacitor.fillColor = color.withAlphaComponent(0.5)
            capacitor.strokeColor = color
            capacitor.lineWidth = 1
            capacitor.glowWidth = 2
            capacitor.position = pos
            capacitor.name = "capacitor_\(i)"
            container.addChild(capacitor)
        }
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

    static func addDivineRays(to container: SKNode, color: UIColor) {
        for i in 0..<4 {
            let angle = CGFloat(i) * .pi / 2
            let rayPath = UIBezierPath()
            rayPath.move(to: CGPoint(x: cos(angle) * 20, y: sin(angle) * 20))
            rayPath.addLine(to: CGPoint(x: cos(angle) * 40, y: sin(angle) * 40))

            let ray = SKShapeNode(path: rayPath.cgPath)
            ray.strokeColor = UIColor(hex: "fbbf24")?.withAlphaComponent(0.3) ?? .yellow.withAlphaComponent(0.3)
            ray.lineWidth = 3
            ray.glowWidth = 5
            ray.blendMode = .add
            ray.name = "divineRay_\(i)"
            container.addChild(ray)
        }
    }
}
