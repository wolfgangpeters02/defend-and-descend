import SpriteKit

// MARK: - Enemy Archetype Visual Compositions
// Phase 3: Multi-node archetype-specific visuals for each enemy type.
// Shared between EntityRenderer (boss mode) and TDGameScene (TD mode).
// Performance: compound paths for small decorative groups, no per-enemy glow.

extension EntityRenderer {

    // MARK: - Cached CGPaths

    /// Static path cache keyed by rounded size (Int(size * 10)) to avoid per-enemy CGPath allocation.
    /// Paths are identical across all instances of the same type/size.
    private static var cachedFlagellaPaths: [Int: CGPath] = [:]
    private static var cachedFastVirusBodyPaths: [Int: CGPath] = [:]
    private static var cachedTankBoltPaths: [Int: CGPath] = [:]
    private static var cachedTankSeamPaths: [Int: CGPath] = [:]
    private static var cachedEliteCrosshairPaths: [Int: CGPath] = [:]

    private static func sizeKey(_ size: CGFloat) -> Int { Int(size * 10) }

    private static func flagellaPath(for size: CGFloat) -> CGPath {
        let key = sizeKey(size)
        if let cached = cachedFlagellaPaths[key] { return cached }
        let path = CGMutablePath()
        for i in 0..<3 {
            let baseAngle = CGFloat(i) * (2 * .pi / 3) + .pi / 6
            let startR = size * 0.9
            let startPt = CGPoint(x: cos(baseAngle) * startR, y: sin(baseAngle) * startR)
            let midR = size * 1.5
            let endR = size * 1.9
            let wobble: CGFloat = size * 0.3
            path.move(to: startPt)
            path.addCurve(
                to: CGPoint(x: cos(baseAngle) * endR, y: sin(baseAngle) * endR),
                control1: CGPoint(x: cos(baseAngle) * midR + wobble, y: sin(baseAngle) * midR + wobble),
                control2: CGPoint(x: cos(baseAngle) * (midR + endR) / 2 - wobble, y: sin(baseAngle) * (midR + endR) / 2)
            )
        }
        cachedFlagellaPaths[key] = path
        return path
    }

    private static func fastVirusBodyPath(for size: CGFloat) -> CGPath {
        let key = sizeKey(size)
        if let cached = cachedFastVirusBodyPaths[key] { return cached }
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: size * 1.2))
        path.addLine(to: CGPoint(x: -size * 0.65, y: 0))
        path.addLine(to: CGPoint(x: 0, y: -size * 0.5))
        path.addLine(to: CGPoint(x: size * 0.65, y: 0))
        path.closeSubpath()
        cachedFastVirusBodyPaths[key] = path
        return path
    }

    private static func tankBoltPath(for size: CGFloat) -> CGPath {
        let key = sizeKey(size)
        if let cached = cachedTankBoltPaths[key] { return cached }
        let path = CGMutablePath()
        let plateSize: CGFloat = size * 0.22
        let plateOffset = size * 0.62
        let offsets: [(CGFloat, CGFloat)] = [(-1, -1), (1, -1), (-1, 1), (1, 1)]
        for (dx, dy) in offsets {
            let cx = dx * plateOffset
            let cy = dy * plateOffset
            path.addRect(CGRect(x: cx - plateSize / 2, y: cy - plateSize / 2,
                                width: plateSize, height: plateSize))
        }
        cachedTankBoltPaths[key] = path
        return path
    }

    private static func tankSeamPath(for size: CGFloat) -> CGPath {
        let key = sizeKey(size)
        if let cached = cachedTankSeamPaths[key] { return cached }
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -size * 0.75, y: 0))
        path.addLine(to: CGPoint(x: size * 0.75, y: 0))
        cachedTankSeamPaths[key] = path
        return path
    }

    private static func eliteCrosshairPath(for size: CGFloat) -> CGPath {
        let key = sizeKey(size)
        if let cached = cachedEliteCrosshairPaths[key] { return cached }
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: size * 0.45))
        path.addLine(to: CGPoint(x: 0, y: -size * 0.45))
        path.move(to: CGPoint(x: -size * 0.45, y: 0))
        path.addLine(to: CGPoint(x: size * 0.45, y: 0))
        cachedEliteCrosshairPaths[key] = path
        return path
    }

    // MARK: - 3A. Basic Virus — "Malware Blob"
    // Theme: Organic, pulsating threat. Simple but alive.
    // Nodes: body, membrane ring, nucleus, flagella (compound path) = 4

    /// Creates the "Malware Blob" composition for basic virus enemies.
    /// Body + nucleus + flagella tendrils = 3 nodes. Tendrils make rotation visible.
    /// - Returns: The body SKShapeNode for animation hookup by the caller.
    @discardableResult
    static func createBasicVirusComposition(in container: SKNode, size: CGFloat, color: UIColor) -> SKShapeNode {
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
        nucleus.strokeColor = .clear
        nucleus.zPosition = 0.1
        container.addChild(nucleus)

        // Flagella tendrils — 3 wavy appendages (compound path, single node, cached)
        let flagella = SKShapeNode(path: flagellaPath(for: size))
        flagella.strokeColor = color.withAlphaComponent(0.5)
        flagella.lineWidth = 1.5
        flagella.lineCap = .round
        flagella.fillColor = .clear
        flagella.zPosition = -0.1
        container.addChild(flagella)

        return body
    }

    // MARK: - 3B. Fast Virus — "Packet Runner"
    // Theme: Sleek, angular, aerodynamic. Data packet in transit.
    // Nodes: body (diamond/chevron), speed lines, core dot, directional arrow = 4

    /// Creates the "Packet Runner" composition for fast virus enemies.
    /// Body + core dot = 2 nodes. Core dot provides visual center reference.
    @discardableResult
    static func createFastVirusComposition(in container: SKNode, size: CGFloat, color: UIColor) -> SKShapeNode {
        // Body — elongated diamond/chevron (pointy top, shorter bottom, cached)
        let body = SKShapeNode(path: fastVirusBodyPath(for: size))
        body.fillColor = color
        body.strokeColor = color.lighter(by: 0.2)
        body.lineWidth = 2
        body.name = "body"
        container.addChild(body)

        // Core dot — bright center point for visual clarity at speed
        let core = SKShapeNode(circleOfRadius: size * 0.2)
        core.fillColor = color.lighter(by: 0.5)
        core.strokeColor = .clear
        core.zPosition = 0.1
        container.addChild(core)

        return body
    }

    // MARK: - 3C. Tank Virus — "Armored Payload"
    // Theme: Heavy, layered, industrial. Ransomware that's hard to crack.
    // Nodes: body (rounded rect), outer armor, armor plates (compound), inner core = 4

    /// Creates the "Armored Payload" composition for tank virus enemies.
    /// Body + bolts + armor seam = 3 nodes.
    @discardableResult
    static func createTankVirusComposition(in container: SKNode, size: CGFloat, color: UIColor) -> SKShapeNode {
        // Body — rounded rectangle
        let bodySize = CGSize(width: size * 1.8, height: size * 1.8)
        let body = SKShapeNode(rectOf: bodySize, cornerRadius: size * 0.25)
        body.fillColor = color
        body.strokeColor = color.darker(by: 0.3)
        body.lineWidth = 3
        body.name = "body"
        container.addChild(body)

        // Armor plates — 4 bolt heads at corners (compound path, single node, cached)
        let plates = SKShapeNode(path: tankBoltPath(for: size))
        plates.fillColor = color.darker(by: 0.4)
        plates.strokeColor = .clear
        plates.lineWidth = 0
        plates.zPosition = 0.1
        container.addChild(plates)

        // Armor seam — horizontal weld line across the body (cached)
        let seam = SKShapeNode(path: tankSeamPath(for: size))
        seam.strokeColor = color.darker(by: 0.5).withAlphaComponent(0.6)
        seam.lineWidth = 1.5
        seam.zPosition = 0.2
        container.addChild(seam)

        return body
    }

    // MARK: - 3D. Elite Virus
    // Theme: Glitchy, unstable, dangerous. Corrupted data visualization.
    // Nodes: aura ring, body (irregular hex), crosshair, glitch overlay, data fragments = 5

    /// Creates the elite virus composition for elite virus enemies.
    /// Body + crosshair = 2 nodes. Vertex jitter is randomized per-instance.
    @discardableResult
    static func createEliteVirusComposition(in container: SKNode, size: CGFloat, color: UIColor) -> SKShapeNode {
        // Body — irregular hexagon (per-instance randomized vertex jitter for "corrupted" look)
        let bodyPath = CGMutablePath()
        for i in 0..<6 {
            let angle = CGFloat(i) * (.pi / 3) - (.pi / 2)
            let radiusJitter = size * CGFloat.random(in: 0.88...1.08)
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

        // Inner crosshair pattern — circuit trace feel (compound path, single node, cached)
        let crosshair = SKShapeNode(path: eliteCrosshairPath(for: size))
        crosshair.strokeColor = color.withAlphaComponent(0.4)
        crosshair.lineWidth = 1
        crosshair.zPosition = 0.1
        container.addChild(crosshair)

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

            // Spawn fragments for dramatic boss death
            spawnDeathFragments(at: node.position, in: node.parent, count: 5,
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

            // No fragments for basic virus death — just the pop animation
        }
    }

    /// Spawns a lightweight death effect (node-pool compatible).
    /// Skipped entirely when many enemies are on screen (>10 siblings) to preserve FPS.
    static func spawnDeathEffect(
        at position: CGPoint,
        in parent: SKNode?,
        shape: String,
        color: UIColor,
        size: CGFloat
    ) {
        guard let parent = parent else { return }

        // Skip death effects entirely when scene is busy (performance)
        if parent.children.count > 15 && shape != "boss" {
            return
        }

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

        // Only spawn fragments for boss deaths (skip for regular enemies)
        if shape == "boss" {
            spawnDeathFragments(at: position, in: parent, count: 6,
                                color: color, size: size * 0.15,
                                speed: size * 2, shape: .diamond)
        }
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
