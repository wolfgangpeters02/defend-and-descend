import SpriteKit

// MARK: - Enemy Archetype Visual Compositions
// Phase 3: Multi-node archetype-specific visuals for each enemy type.
// Shared between EntityRenderer (boss mode) and TDGameScene (TD mode).
// Performance: compound paths for small decorative groups, no per-enemy glow.

extension EntityRenderer {

    // MARK: - 3A. Basic Virus — "Malware Blob"
    // Theme: Organic, pulsating threat. Simple but alive.
    // Nodes: body, membrane ring, nucleus, flagella (compound path) = 4

    /// Creates the full "Malware Blob" composition for basic virus enemies.
    /// - Returns: The body SKShapeNode for animation hookup by the caller.
    @discardableResult
    static func createBasicVirusComposition(in container: SKNode, size: CGFloat, color: UIColor) -> SKShapeNode {
        // Membrane ring — outer "cell wall"
        let membrane = SKShapeNode(circleOfRadius: size * 1.2)
        membrane.fillColor = .clear
        membrane.strokeColor = color.withAlphaComponent(0.25)
        membrane.lineWidth = 1
        membrane.zPosition = -0.1
        container.addChild(membrane)

        // Membrane slow counter-rotation
        let membraneRotate = SKAction.rotate(byAngle: -.pi * 2, duration: 8.0)
        membrane.run(SKAction.repeatForever(membraneRotate))

        // Body — main circle
        let body = SKShapeNode(circleOfRadius: size)
        body.fillColor = color
        body.strokeColor = color.darker(by: 0.3)
        body.lineWidth = 2
        body.name = "body"
        container.addChild(body)

        // Nucleus — inner darker core
        let nucleus = SKShapeNode(circleOfRadius: size * 0.35)
        nucleus.fillColor = color.darker(by: 0.5)
        nucleus.strokeColor = color.withAlphaComponent(0.5)
        nucleus.lineWidth = 1
        nucleus.zPosition = 0.1
        container.addChild(nucleus)

        // Nucleus slow rotation
        let nucleusRotate = SKAction.rotate(byAngle: -.pi * 2, duration: 6.0)
        nucleus.run(SKAction.repeatForever(nucleusRotate))

        // Flagella — 3 trailing curved tentacles (compound path, single node)
        let flagellaPath = CGMutablePath()
        for i in 0..<3 {
            let baseAngle = CGFloat(i) * (2 * .pi / 3) + .pi // spread behind/below
            let startR = size * 0.8
            let endR = size * 1.5
            let ctrlR = size * 1.2
            let startPt = CGPoint(x: cos(baseAngle) * startR, y: sin(baseAngle) * startR)
            let endPt = CGPoint(x: cos(baseAngle) * endR, y: sin(baseAngle) * endR)
            let ctrlPt = CGPoint(x: cos(baseAngle + 0.3) * ctrlR, y: sin(baseAngle + 0.3) * ctrlR)
            flagellaPath.move(to: startPt)
            flagellaPath.addQuadCurve(to: endPt, control: ctrlPt)
        }
        let flagella = SKShapeNode(path: flagellaPath)
        flagella.strokeColor = color.withAlphaComponent(0.35)
        flagella.lineWidth = 1.5
        flagella.lineCap = .round
        flagella.zPosition = -0.2
        container.addChild(flagella)

        return body
    }

    // MARK: - 3B. Fast Virus — "Packet Runner"
    // Theme: Sleek, angular, aerodynamic. Data packet in transit.
    // Nodes: body (diamond/chevron), speed lines, core dot, directional arrow = 4

    /// Creates the full "Packet Runner" composition for fast virus enemies.
    @discardableResult
    static func createFastVirusComposition(in container: SKNode, size: CGFloat, color: UIColor) -> SKShapeNode {
        // Body — elongated diamond/chevron (pointy top, shorter bottom)
        let bodyPath = CGMutablePath()
        bodyPath.move(to: CGPoint(x: 0, y: size * 1.2))         // Top point (elongated)
        bodyPath.addLine(to: CGPoint(x: -size * 0.65, y: 0))    // Left
        bodyPath.addLine(to: CGPoint(x: 0, y: -size * 0.5))     // Bottom (shorter)
        bodyPath.addLine(to: CGPoint(x: size * 0.65, y: 0))     // Right
        bodyPath.closeSubpath()

        let body = SKShapeNode(path: bodyPath)
        body.fillColor = color
        body.strokeColor = color.lighter(by: 0.2)
        body.lineWidth = 2
        body.name = "body"
        container.addChild(body)

        // Speed lines — 2 trailing dashes behind (compound path, single node)
        let speedPath = CGMutablePath()
        speedPath.move(to: CGPoint(x: -size * 0.25, y: -size * 0.5))
        speedPath.addLine(to: CGPoint(x: -size * 0.25, y: -size * 1.3))
        speedPath.move(to: CGPoint(x: size * 0.25, y: -size * 0.5))
        speedPath.addLine(to: CGPoint(x: size * 0.25, y: -size * 1.3))
        let speedLines = SKShapeNode(path: speedPath)
        speedLines.strokeColor = color.withAlphaComponent(0.3)
        speedLines.lineWidth = 1.5
        speedLines.lineCap = .round
        speedLines.zPosition = -0.1
        container.addChild(speedLines)

        // Core dot — bright center
        let core = SKShapeNode(circleOfRadius: size * 0.15)
        core.fillColor = color.lighter(by: 0.5)
        core.strokeColor = .clear
        core.zPosition = 0.1
        container.addChild(core)

        // Core pulse
        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.3, duration: 0.3),
            SKAction.scale(to: 0.8, duration: 0.3)
        ])
        core.run(SKAction.repeatForever(pulse))

        // Directional arrow — tiny forward indicator embedded in body
        let arrowPath = CGMutablePath()
        arrowPath.move(to: CGPoint(x: -size * 0.15, y: size * 0.25))
        arrowPath.addLine(to: CGPoint(x: 0, y: size * 0.65))
        arrowPath.addLine(to: CGPoint(x: size * 0.15, y: size * 0.25))
        let arrow = SKShapeNode(path: arrowPath)
        arrow.strokeColor = color.lighter(by: 0.3)
        arrow.fillColor = .clear
        arrow.lineWidth = 1.5
        arrow.lineCap = .round
        arrow.zPosition = 0.1
        container.addChild(arrow)

        return body
    }

    // MARK: - 3C. Tank Virus — "Armored Payload"
    // Theme: Heavy, layered, industrial. Ransomware that's hard to crack.
    // Nodes: body (rounded rect), outer armor, armor plates (compound), inner core = 4

    /// Creates the full "Armored Payload" composition for tank virus enemies.
    @discardableResult
    static func createTankVirusComposition(in container: SKNode, size: CGFloat, color: UIColor) -> SKShapeNode {
        // Body — rounded rectangle (not plain square)
        let bodySize = CGSize(width: size * 1.8, height: size * 1.8)
        let body = SKShapeNode(rectOf: bodySize, cornerRadius: size * 0.25)
        body.fillColor = color
        body.strokeColor = color.darker(by: 0.3)
        body.lineWidth = 3
        body.name = "body"
        container.addChild(body)

        // Outer armor border — double-stroke effect
        let outerSize = CGSize(width: size * 1.8 + 6, height: size * 1.8 + 6)
        let outerBorder = SKShapeNode(rectOf: outerSize, cornerRadius: size * 0.3)
        outerBorder.fillColor = .clear
        outerBorder.strokeColor = color.darker(by: 0.5)
        outerBorder.lineWidth = 1.5
        container.addChild(outerBorder)

        // Armor plates — 4 bolt heads at corners (compound path, single node)
        let platePath = CGMutablePath()
        let plateSize: CGFloat = size * 0.22
        let plateOffset = size * 0.62
        let offsets: [(CGFloat, CGFloat)] = [(-1, -1), (1, -1), (-1, 1), (1, 1)]
        for (dx, dy) in offsets {
            let cx = dx * plateOffset
            let cy = dy * plateOffset
            platePath.addRect(CGRect(x: cx - plateSize / 2, y: cy - plateSize / 2,
                                     width: plateSize, height: plateSize))
        }
        let plates = SKShapeNode(path: platePath)
        plates.fillColor = color.darker(by: 0.4)
        plates.strokeColor = color.withAlphaComponent(0.5)
        plates.lineWidth = 1
        plates.zPosition = 0.1
        container.addChild(plates)

        // Inner core — lock/keyhole icon
        let corePath = CGMutablePath()
        // Lock body (small rectangle)
        corePath.addRect(CGRect(x: -size * 0.18, y: -size * 0.3,
                                width: size * 0.36, height: size * 0.3))
        // Lock ring (arc above body)
        corePath.addArc(center: CGPoint(x: 0, y: 0), radius: size * 0.2,
                        startAngle: 0, endAngle: .pi, clockwise: false)
        let core = SKShapeNode(path: corePath)
        core.fillColor = color.darker(by: 0.6)
        core.strokeColor = color.withAlphaComponent(0.4)
        core.lineWidth = 1.5
        core.zPosition = 0.1
        container.addChild(core)

        return body
    }

    // MARK: - 3D. Elite Virus
    // Theme: Glitchy, unstable, dangerous. Corrupted data visualization.
    // Nodes: aura ring, body (irregular hex), crosshair, glitch overlay, data fragments = 5

    /// Creates the full elite virus composition for elite virus enemies.
    @discardableResult
    static func createEliteVirusComposition(in container: SKNode, size: CGFloat, color: UIColor) -> SKShapeNode {
        // Aura ring — outer threat indicator
        let aura = SKShapeNode(circleOfRadius: size * 1.3)
        aura.fillColor = .clear
        aura.strokeColor = color.withAlphaComponent(0.35)
        aura.lineWidth = 1.5
        aura.zPosition = -0.1
        container.addChild(aura)

        // Aura breathing
        let auraPulse = SKAction.sequence([
            SKAction.scale(to: 1.06, duration: 0.6),
            SKAction.scale(to: 0.96, duration: 0.6)
        ])
        aura.run(SKAction.repeatForever(auraPulse))

        // Body — irregular hexagon (glitched vertices for "corrupted" look)
        let bodyPath = CGMutablePath()
        for i in 0..<6 {
            let angle = CGFloat(i) * (.pi / 3) - (.pi / 2)
            let radiusJitter: CGFloat = (i % 2 == 0) ? size * 1.05 : size * 0.92
            let point = CGPoint(x: cos(angle) * radiusJitter, y: sin(angle) * radiusJitter)
            if i == 0 {
                bodyPath.move(to: point)
            } else {
                bodyPath.addLine(to: point)
            }
        }
        bodyPath.closeSubpath()

        let body = SKShapeNode(path: bodyPath)
        body.fillColor = color
        body.strokeColor = color.lighter(by: 0.3)
        body.lineWidth = 2
        body.name = "body"
        container.addChild(body)

        // Inner crosshair pattern — circuit trace feel
        let crossPath = CGMutablePath()
        crossPath.move(to: CGPoint(x: 0, y: size * 0.45))
        crossPath.addLine(to: CGPoint(x: 0, y: -size * 0.45))
        crossPath.move(to: CGPoint(x: -size * 0.45, y: 0))
        crossPath.addLine(to: CGPoint(x: size * 0.45, y: 0))
        // Small corner ticks
        let tickLen: CGFloat = size * 0.12
        for (cx, cy) in [(size * 0.3, size * 0.3), (-size * 0.3, size * 0.3),
                          (size * 0.3, -size * 0.3), (-size * 0.3, -size * 0.3)] as [(CGFloat, CGFloat)] {
            crossPath.move(to: CGPoint(x: cx - tickLen, y: cy))
            crossPath.addLine(to: CGPoint(x: cx + tickLen, y: cy))
            crossPath.move(to: CGPoint(x: cx, y: cy - tickLen))
            crossPath.addLine(to: CGPoint(x: cx, y: cy + tickLen))
        }
        let crosshair = SKShapeNode(path: crossPath)
        crosshair.strokeColor = color.withAlphaComponent(0.4)
        crosshair.lineWidth = 1
        crosshair.zPosition = 0.1
        container.addChild(crosshair)

        // Glitch overlay — jittering semi-transparent band
        let glitch = SKShapeNode(rectOf: CGSize(width: size * 1.2, height: size * 0.25))
        glitch.fillColor = color.withAlphaComponent(0.12)
        glitch.strokeColor = color.withAlphaComponent(0.25)
        glitch.lineWidth = 1
        glitch.zPosition = 0.2
        container.addChild(glitch)

        // Glitch jitter animation
        let jitter = SKAction.repeatForever(SKAction.sequence([
            SKAction.run {
                glitch.position = CGPoint(
                    x: CGFloat.random(in: -size * 0.15...size * 0.15),
                    y: CGFloat.random(in: -size * 0.15...size * 0.15)
                )
                glitch.alpha = CGFloat.random(in: 0.1...0.35)
            },
            SKAction.wait(forDuration: 0.12),
            SKAction.run {
                glitch.position = .zero
                glitch.alpha = 0.15
            },
            SKAction.wait(forDuration: TimeInterval.random(in: 0.2...0.5))
        ]))
        glitch.run(jitter)

        // Data fragments — 3 orbiting small diamonds (compound path, single node)
        let fragmentPath = CGMutablePath()
        let fragSize: CGFloat = size * 0.12
        for i in 0..<3 {
            let angle = CGFloat(i) * (2 * .pi / 3)
            let cx = cos(angle) * size * 0.65
            let cy = sin(angle) * size * 0.65
            fragmentPath.move(to: CGPoint(x: cx, y: cy + fragSize))
            fragmentPath.addLine(to: CGPoint(x: cx + fragSize, y: cy))
            fragmentPath.addLine(to: CGPoint(x: cx, y: cy - fragSize))
            fragmentPath.addLine(to: CGPoint(x: cx - fragSize, y: cy))
            fragmentPath.closeSubpath()
        }
        let fragments = SKShapeNode(path: fragmentPath)
        fragments.fillColor = color.withAlphaComponent(0.6)
        fragments.strokeColor = .clear
        fragments.zPosition = 0.1
        container.addChild(fragments)

        // Orbit fragments around body
        let orbit = SKAction.rotate(byAngle: .pi * 2, duration: 2.5)
        fragments.run(SKAction.repeatForever(orbit))

        return body
    }

    // MARK: - Type-Specific Death Animations (Phase 7B)

    /// Creates a type-specific death animation for an enemy node.
    /// The node runs the animation and removes itself when done.
    static func runDeathAnimation(on node: SKNode, shape: String, color: UIColor, size: CGFloat) {
        // Stop all existing actions
        node.removeAllActions()

        switch shape {
        case "triangle":
            // Fast virus: streak/smear in movement direction + fade
            let streak = SKAction.moveBy(x: 0, y: size * 2, duration: 0.15)
            streak.timingMode = .easeIn
            let scaleX = SKAction.scaleX(to: 0.3, duration: 0.15)
            let fade = SKAction.fadeOut(withDuration: 0.15)
            let group = SKAction.group([streak, scaleX, fade])
            node.run(SKAction.sequence([group, SKAction.removeFromParent()]))

        case "square":
            // Tank virus: crack/armor plates separate + slow collapse
            let expand = SKAction.scale(to: 1.15, duration: 0.06)
            expand.timingMode = .easeOut
            let hold = SKAction.wait(forDuration: 0.08)
            let shrink = SKAction.scale(to: 0.7, duration: 0.2)
            shrink.timingMode = .easeIn
            let fade = SKAction.fadeOut(withDuration: 0.2)
            let collapse = SKAction.group([shrink, fade])
            node.run(SKAction.sequence([expand, hold, collapse, SKAction.removeFromParent()]))

            // Spawn 4 plate fragments scattering outward
            spawnDeathFragments(at: node.position, in: node.parent, count: 4,
                                color: color.darker(by: 0.3), size: size * 0.3,
                                speed: size * 1.5, shape: .square)

        case "hexagon":
            // Elite virus: glitch-out (rapid jitter) + dissolve
            let jitterCount = 6
            var jitterActions: [SKAction] = []
            for _ in 0..<jitterCount {
                let dx = CGFloat.random(in: -size * 0.3...size * 0.3)
                let dy = CGFloat.random(in: -size * 0.3...size * 0.3)
                jitterActions.append(SKAction.moveBy(x: dx, y: dy, duration: 0.03))
                jitterActions.append(SKAction.moveBy(x: -dx, y: -dy, duration: 0.02))
            }
            let jitter = SKAction.sequence(jitterActions)
            let fade = SKAction.fadeOut(withDuration: 0.15)
            let dissolve = SKAction.group([jitter, fade])
            node.run(SKAction.sequence([dissolve, SKAction.removeFromParent()]))

        case "boss":
            // Boss: dramatic expand, flash white, shatter
            let flash = SKAction.sequence([
                SKAction.colorize(with: .white, colorBlendFactor: 1.0, duration: 0.05),
                SKAction.wait(forDuration: 0.05)
            ])
            let expand = SKAction.scale(to: 1.5, duration: 0.15)
            expand.timingMode = .easeOut
            let shrink = SKAction.scale(to: 0, duration: 0.2)
            shrink.timingMode = .easeIn
            let fade = SKAction.fadeOut(withDuration: 0.2)
            let shatter = SKAction.group([shrink, fade])
            node.run(SKAction.sequence([flash, expand, shatter, SKAction.removeFromParent()]))

            // Spawn 8 fragments for dramatic boss death
            spawnDeathFragments(at: node.position, in: node.parent, count: 8,
                                color: color, size: size * 0.2,
                                speed: size * 3, shape: .diamond)

        default:
            // Basic virus: pop + 4 small fragments scatter
            let pop = SKAction.scale(to: 1.3, duration: 0.04)
            pop.timingMode = .easeOut
            let shrink = SKAction.scale(to: 0, duration: 0.1)
            shrink.timingMode = .easeIn
            let fade = SKAction.fadeOut(withDuration: 0.1)
            let collapse = SKAction.group([shrink, fade])
            node.run(SKAction.sequence([pop, collapse, SKAction.removeFromParent()]))

            // Spawn 4 small circle fragments
            spawnDeathFragments(at: node.position, in: node.parent, count: 4,
                                color: color, size: size * 0.15,
                                speed: size * 2, shape: .circle)
        }
    }

    /// Spawns a lightweight death effect (node-pool compatible).
    /// Creates a temporary flash + fragments without needing the original node.
    static func spawnDeathEffect(
        at position: CGPoint,
        in parent: SKNode?,
        shape: String,
        color: UIColor,
        size: CGFloat
    ) {
        guard let parent = parent else { return }

        // Quick flash at death position
        let flash = SKShapeNode(circleOfRadius: size * 0.8)
        flash.fillColor = .white
        flash.strokeColor = .clear
        flash.alpha = 0.6
        flash.position = position
        flash.zPosition = 150
        parent.addChild(flash)

        let flashFade = SKAction.sequence([
            SKAction.scale(to: 1.4, duration: 0.06),
            SKAction.group([
                SKAction.fadeOut(withDuration: 0.1),
                SKAction.scale(to: 0.5, duration: 0.1)
            ]),
            SKAction.removeFromParent()
        ])
        flash.run(flashFade)

        // Type-specific fragment count and shape
        let fragShape: FragmentShape
        let fragCount: Int
        switch shape {
        case "triangle":
            fragShape = .diamond
            fragCount = 2
        case "square":
            fragShape = .square
            fragCount = 4
        case "hexagon":
            fragShape = .diamond
            fragCount = 3
        case "boss":
            fragShape = .diamond
            fragCount = 8
        default:
            fragShape = .circle
            fragCount = 3
        }

        spawnDeathFragments(at: position, in: parent, count: fragCount,
                            color: color, size: size * 0.15,
                            speed: size * 2, shape: fragShape)
    }

    // MARK: - Type-Specific Spawn Animations (Phase 7C)

    /// Runs a type-specific spawn animation on an enemy node.
    static func runSpawnAnimation(on node: SKNode, shape: String) {
        switch shape {
        case "triangle":
            // Fast virus: slide-in from offset + snap
            node.alpha = 0
            let offset: CGFloat = 30
            node.position.y += offset
            let slideIn = SKAction.moveBy(x: 0, y: -offset, duration: 0.15)
            slideIn.timingMode = .easeOut
            let fadeIn = SKAction.fadeIn(withDuration: 0.1)
            node.run(SKAction.group([slideIn, fadeIn]))

        case "square":
            // Tank virus: drop-in (scale from 1.5 to 1.0) + heavy settle
            node.setScale(1.5)
            node.alpha = 0.6
            let dropScale = SKAction.scale(to: 1.0, duration: 0.2)
            dropScale.timingMode = .easeIn
            let fadeIn = SKAction.fadeIn(withDuration: 0.15)
            let settle = SKAction.sequence([
                SKAction.scale(to: 0.95, duration: 0.05),
                SKAction.scale(to: 1.0, duration: 0.05)
            ])
            node.run(SKAction.sequence([
                SKAction.group([dropScale, fadeIn]),
                settle
            ]))

        case "hexagon":
            // Elite virus: glitch-in (rapid alpha flicker)
            node.alpha = 0
            var flickerActions: [SKAction] = []
            for _ in 0..<5 {
                flickerActions.append(SKAction.fadeAlpha(to: CGFloat.random(in: 0.3...0.8), duration: 0.03))
                flickerActions.append(SKAction.fadeAlpha(to: 0, duration: 0.02))
            }
            flickerActions.append(SKAction.fadeIn(withDuration: 0.05))
            node.run(SKAction.sequence(flickerActions))

        case "boss":
            // Boss: dramatic emergence (scale from 0 with flash)
            node.setScale(0)
            node.alpha = 0
            let emerge = SKAction.scale(to: 1.1, duration: 0.4)
            emerge.timingMode = .easeOut
            let fadeIn = SKAction.fadeIn(withDuration: 0.3)
            let settle = SKAction.scale(to: 1.0, duration: 0.15)
            settle.timingMode = .easeInEaseOut
            node.run(SKAction.sequence([
                SKAction.group([emerge, fadeIn]),
                settle
            ]))

        default:
            // Basic virus: scale from 0 + fade in
            node.setScale(0)
            node.alpha = 0
            let scaleUp = SKAction.scale(to: 1.0, duration: 0.2)
            scaleUp.timingMode = .easeOut
            let fadeIn = SKAction.fadeIn(withDuration: 0.15)
            node.run(SKAction.group([scaleUp, fadeIn]))
        }
    }

    /// Fragment shape type for death effects
    enum FragmentShape {
        case circle, square, diamond
    }

    /// Spawns temporary death fragment particles that scatter and fade.
    /// Capped at 8 fragments per call for performance.
    private static func spawnDeathFragments(
        at position: CGPoint,
        in parent: SKNode?,
        count: Int,
        color: UIColor,
        size: CGFloat,
        speed: CGFloat,
        shape: FragmentShape
    ) {
        guard let parent = parent else { return }
        let cappedCount = min(count, 8)

        for i in 0..<cappedCount {
            let angle = CGFloat(i) * (2 * .pi / CGFloat(cappedCount)) + CGFloat.random(in: -0.3...0.3)
            let frag: SKShapeNode
            switch shape {
            case .circle:
                frag = SKShapeNode(circleOfRadius: size)
            case .square:
                frag = SKShapeNode(rectOf: CGSize(width: size * 2, height: size * 2))
            case .diamond:
                let dPath = CGMutablePath()
                dPath.move(to: CGPoint(x: 0, y: size))
                dPath.addLine(to: CGPoint(x: size, y: 0))
                dPath.addLine(to: CGPoint(x: 0, y: -size))
                dPath.addLine(to: CGPoint(x: -size, y: 0))
                dPath.closeSubpath()
                frag = SKShapeNode(path: dPath)
            }
            frag.fillColor = color
            frag.strokeColor = .clear
            frag.position = position
            frag.zPosition = 150
            parent.addChild(frag)

            let dx = cos(angle) * speed
            let dy = sin(angle) * speed
            let move = SKAction.moveBy(x: dx, y: dy, duration: 0.35)
            move.timingMode = .easeOut
            let fade = SKAction.fadeOut(withDuration: 0.35)
            let scale = SKAction.scale(to: 0.3, duration: 0.35)
            let group = SKAction.group([move, fade, scale])
            frag.run(SKAction.sequence([group, SKAction.removeFromParent()]))
        }
    }
}
