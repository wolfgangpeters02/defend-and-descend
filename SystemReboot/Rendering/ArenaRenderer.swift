import SpriteKit

// MARK: - Arena Renderer

class ArenaRenderer {

    /// Get arena background color
    static func getBackgroundColor(for arenaType: String) -> SKColor {
        switch arenaType {
        case "city":
            return SKColor(red: 0.1, green: 0.1, blue: 0.15, alpha: 1.0)
        case "forest":
            return SKColor(red: 0.05, green: 0.15, blue: 0.05, alpha: 1.0)
        case "volcano":
            return SKColor(red: 0.2, green: 0.05, blue: 0.0, alpha: 1.0)
        case "ice_cave":
            return SKColor(red: 0.1, green: 0.15, blue: 0.2, alpha: 1.0)
        case "desert":
            return SKColor(red: 0.25, green: 0.2, blue: 0.1, alpha: 1.0)
        case "space":
            return SKColor(red: 0.02, green: 0.02, blue: 0.08, alpha: 1.0)
        case "jungle":
            return SKColor(red: 0.05, green: 0.12, blue: 0.03, alpha: 1.0)
        case "graveyard":
            return SKColor(red: 0.08, green: 0.08, blue: 0.1, alpha: 1.0)
        case "temple":
            return SKColor(red: 0.15, green: 0.12, blue: 0.08, alpha: 1.0)
        case "castle":
            return SKColor(red: 0.12, green: 0.1, blue: 0.15, alpha: 1.0)
        case "underwater":
            return SKColor(red: 0.0, green: 0.1, blue: 0.2, alpha: 1.0)
        case "cybercity":
            return SKColor(red: 0.05, green: 0.0, blue: 0.1, alpha: 1.0)
        case "hell":
            return SKColor(red: 0.15, green: 0.0, blue: 0.0, alpha: 1.0)
        case "heaven":
            return SKColor(red: 0.9, green: 0.9, blue: 1.0, alpha: 1.0)
        case "voidrealm":
            return SKColor(red: 0.02, green: 0.0, blue: 0.05, alpha: 1.0)
        default:
            return SKColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
        }
    }

    /// Get obstacle color for arena type
    static func getObstacleColor(for arenaType: String, obstacleType: String) -> SKColor {
        switch arenaType {
        case "city":
            return SKColor(red: 0.3, green: 0.3, blue: 0.35, alpha: 1.0)
        case "forest":
            return SKColor(red: 0.3, green: 0.2, blue: 0.1, alpha: 1.0) // Tree trunks
        case "volcano":
            return SKColor(red: 0.2, green: 0.15, blue: 0.1, alpha: 1.0) // Rocks
        case "ice_cave":
            return SKColor(red: 0.5, green: 0.6, blue: 0.7, alpha: 1.0) // Ice
        case "desert":
            return SKColor(red: 0.6, green: 0.5, blue: 0.3, alpha: 1.0) // Sandstone
        case "space":
            return SKColor(red: 0.3, green: 0.3, blue: 0.4, alpha: 1.0) // Metal
        case "graveyard":
            return SKColor(red: 0.4, green: 0.4, blue: 0.45, alpha: 1.0) // Tombstones
        case "cybercity":
            return SKColor(red: 0.1, green: 0.1, blue: 0.15, alpha: 1.0) // Neon buildings
        default:
            return SKColor.gray
        }
    }

    /// Get hazard color
    static func getHazardColor(for hazardType: String) -> SKColor {
        switch hazardType {
        case "lava":
            return SKColor(red: 1.0, green: 0.3, blue: 0.0, alpha: 0.8)
        case "spikes":
            return SKColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 0.9)
        case "acid":
            return SKColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 0.7)
        case "void":
            return SKColor(red: 0.2, green: 0.0, blue: 0.3, alpha: 0.9)
        case "fire":
            return SKColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 0.7)
        case "ice":
            return SKColor(red: 0.5, green: 0.8, blue: 1.0, alpha: 0.6)
        default:
            return SKColor.red.withAlphaComponent(0.7)
        }
    }

    /// Get effect zone visual
    static func getEffectZoneColor(for zoneType: String) -> (color: SKColor, alpha: CGFloat) {
        switch zoneType {
        case "ice":
            return (SKColor.cyan, 0.2)
        case "speedBoost":
            return (SKColor.yellow, 0.15)
        case "healing":
            return (SKColor.green, 0.2)
        case "damage":
            return (SKColor.red, 0.25)
        case "slow":
            return (SKColor.purple, 0.2)
        default:
            return (SKColor.white, 0.1)
        }
    }

    /// Create obstacle node with arena-specific styling
    static func createObstacleNode(obstacle: Obstacle, arenaType: String) -> SKNode {
        let node = SKShapeNode(rectOf: CGSize(width: obstacle.width, height: obstacle.height), cornerRadius: 4)

        let baseColor = getObstacleColor(for: arenaType, obstacleType: obstacle.type)
        node.fillColor = baseColor
        node.strokeColor = baseColor.lighter(by: 0.1)
        node.lineWidth = 2

        // Add detail based on arena type
        switch arenaType {
        case "city":
            // Windows pattern
            addBuildingWindows(to: node, width: obstacle.width, height: obstacle.height)
        case "forest":
            // Tree canopy
            addTreeCanopy(to: node, width: obstacle.width)
        case "graveyard":
            // Tombstone detail
            node.fillColor = SKColor.darkGray
        default:
            break
        }

        return node
    }

    private static func addBuildingWindows(to node: SKShapeNode, width: CGFloat, height: CGFloat) {
        let windowSize: CGFloat = 8
        let spacing: CGFloat = 12
        let cols = Int((width - 10) / spacing)
        let rows = Int((height - 10) / spacing)

        for row in 0..<rows {
            for col in 0..<cols {
                let windowNode = SKShapeNode(rectOf: CGSize(width: windowSize, height: windowSize))
                windowNode.fillColor = RandomUtils.randomBool(probability: 0.6)
                    ? SKColor.yellow.withAlphaComponent(0.7)
                    : SKColor.black.withAlphaComponent(0.5)
                windowNode.strokeColor = .clear
                windowNode.position = CGPoint(
                    x: -width/2 + 8 + CGFloat(col) * spacing,
                    y: height/2 - 8 - CGFloat(row) * spacing
                )
                node.addChild(windowNode)
            }
        }
    }

    private static func addTreeCanopy(to node: SKShapeNode, width: CGFloat) {
        let canopy = SKShapeNode(circleOfRadius: width * 0.8)
        canopy.fillColor = SKColor(red: 0.1, green: 0.4, blue: 0.1, alpha: 0.9)
        canopy.strokeColor = SKColor(red: 0.05, green: 0.3, blue: 0.05, alpha: 1.0)
        canopy.lineWidth = 2
        canopy.position = CGPoint(x: 0, y: width * 0.5)
        node.addChild(canopy)
    }

    /// Create hazard node with animation
    static func createHazardNode(hazard: Hazard) -> SKNode {
        let node = SKShapeNode(rectOf: CGSize(width: hazard.width, height: hazard.height))
        node.fillColor = getHazardColor(for: hazard.type)
        node.strokeColor = .clear

        // Pulsing animation
        let pulse = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.5, duration: 0.5),
            SKAction.fadeAlpha(to: 0.8, duration: 0.5)
        ])
        node.run(SKAction.repeatForever(pulse))

        // Add glow effect for lava
        if hazard.type == "lava" {
            node.glowWidth = 1.5  // Lava hazard glow (boss fight only)

            // Bubbling effect
            let bubble = SKAction.sequence([
                SKAction.scale(to: 1.02, duration: 0.3),
                SKAction.scale(to: 1.0, duration: 0.3)
            ])
            node.run(SKAction.repeatForever(bubble))
        }

        return node
    }

    /// Create effect zone node
    static func createEffectZoneNode(zone: ArenaEffectZone) -> SKNode {
        let (color, alpha) = getEffectZoneColor(for: zone.type.rawValue)

        let node = SKShapeNode(rectOf: CGSize(width: zone.width, height: zone.height))
        node.fillColor = color.withAlphaComponent(alpha)
        node.strokeColor = color.withAlphaComponent(alpha + 0.1)
        node.lineWidth = 2

        // Subtle animation
        let glow = SKAction.sequence([
            SKAction.fadeAlpha(to: alpha * 0.5, duration: 1.0),
            SKAction.fadeAlpha(to: alpha, duration: 1.0)
        ])
        node.run(SKAction.repeatForever(glow))

        return node
    }

    /// Create atmospheric particles for arena
    static func createAtmosphericEmitter(for arenaType: String, size: CGSize) -> SKEmitterNode? {
        let emitter = SKEmitterNode()

        switch arenaType {
        case "volcano":
            // Ember particles
            emitter.particleTexture = nil
            emitter.particleBirthRate = 5
            emitter.particleLifetime = 3
            emitter.particlePosition = CGPoint(x: size.width / 2, y: 0)
            emitter.particlePositionRange = CGVector(dx: size.width, dy: 0)
            emitter.particleSpeed = 50
            emitter.particleSpeedRange = 30
            emitter.emissionAngle = .pi / 2
            emitter.emissionAngleRange = .pi / 4
            emitter.particleColor = .orange
            emitter.particleColorBlendFactor = 1.0
            emitter.particleScale = 0.1
            emitter.particleScaleRange = 0.05
            emitter.particleAlpha = 0.8
            emitter.particleAlphaSpeed = -0.3

        case "ice_cave":
            // Snow particles
            emitter.particleBirthRate = 10
            emitter.particleLifetime = 5
            emitter.particlePosition = CGPoint(x: size.width / 2, y: size.height)
            emitter.particlePositionRange = CGVector(dx: size.width, dy: 0)
            emitter.particleSpeed = 30
            emitter.particleSpeedRange = 20
            emitter.emissionAngle = -.pi / 2
            emitter.emissionAngleRange = .pi / 6
            emitter.particleColor = .white
            emitter.particleColorBlendFactor = 1.0
            emitter.particleScale = 0.05
            emitter.particleScaleRange = 0.03
            emitter.particleAlpha = 0.6

        case "space":
            // Stars twinkling
            emitter.particleBirthRate = 2
            emitter.particleLifetime = 2
            emitter.particlePosition = CGPoint(x: size.width / 2, y: size.height / 2)
            emitter.particlePositionRange = CGVector(dx: size.width, dy: size.height)
            emitter.particleSpeed = 0
            emitter.particleColor = .white
            emitter.particleColorBlendFactor = 1.0
            emitter.particleScale = 0.02
            emitter.particleScaleRange = 0.02
            emitter.particleAlpha = 0.8
            emitter.particleAlphaSpeed = -0.4

        case "graveyard":
            // Fog/mist
            emitter.particleBirthRate = 3
            emitter.particleLifetime = 4
            emitter.particlePosition = CGPoint(x: size.width / 2, y: 50)
            emitter.particlePositionRange = CGVector(dx: size.width, dy: 100)
            emitter.particleSpeed = 10
            emitter.particleSpeedRange = 5
            emitter.emissionAngle = .pi / 2
            emitter.emissionAngleRange = .pi / 4
            emitter.particleColor = SKColor(white: 0.7, alpha: 0.3)
            emitter.particleColorBlendFactor = 1.0
            emitter.particleScale = 0.5
            emitter.particleScaleRange = 0.3
            emitter.particleAlpha = 0.3
            emitter.particleAlphaSpeed = -0.1

        default:
            return nil
        }

        return emitter
    }
}
