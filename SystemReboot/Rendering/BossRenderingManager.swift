import SpriteKit

// MARK: - Boss Rendering Manager
// Extracted from GameScene+BossRendering (Step 4.1) — all boss mechanics
// rendering for 4 bosses with zero game-logic dependencies.

class BossRenderingManager {

    // MARK: - Scene References

    weak var scene: SKScene?
    var nodePool: NodePool!

    // MARK: - Node Tracking

    var bossMechanicNodes: [String: SKNode] = [:]

    // MARK: - Cached SKActions (avoid recreating every frame)

    lazy var laserFlickerAction: SKAction = {
        let down = SKAction.fadeAlpha(to: 0.8, duration: 0.08)
        down.timingMode = .easeOut
        let up = SKAction.fadeAlpha(to: 1.0, duration: 0.08)
        up.timingMode = .easeIn
        return SKAction.sequence([down, up])
    }()

    lazy var puddlePulseAction: SKAction = {
        let up = SKAction.scale(to: 1.15, duration: 0.3)
        up.timingMode = .easeInEaseOut
        let down = SKAction.scale(to: 1.0, duration: 0.3)
        down.timingMode = .easeInEaseOut
        return SKAction.sequence([up, down])
    }()

    lazy var voidZonePulseAction: SKAction = {
        let up = SKAction.scale(to: 1.1, duration: 0.4)
        up.timingMode = .easeInEaseOut
        let down = SKAction.scale(to: 1.0, duration: 0.4)
        down.timingMode = .easeInEaseOut
        return SKAction.sequence([up, down])
    }()

    lazy var pylonCrystalPulseAction: SKAction = {
        let up = SKAction.scale(to: 1.2, duration: 0.5)
        up.timingMode = .easeInEaseOut
        let down = SKAction.scale(to: 1.0, duration: 0.5)
        down.timingMode = .easeInEaseOut
        return SKAction.sequence([up, down])
    }()

    lazy var gravityWellRotateAction: SKAction = {
        SKAction.rotate(byAngle: .pi * 2, duration: 3)
    }()

    lazy var arenaBoundaryPulseAction: SKAction = {
        let down = SKAction.fadeAlpha(to: 0.5, duration: 0.5)
        down.timingMode = .easeInEaseOut
        let up = SKAction.fadeAlpha(to: 1.0, duration: 0.5)
        up.timingMode = .easeInEaseOut
        return SKAction.sequence([down, up])
    }()

    lazy var riftPulseAction: SKAction = {
        let down = SKAction.fadeAlpha(to: 0.5, duration: 0.4)
        down.timingMode = .easeInEaseOut
        let up = SKAction.fadeAlpha(to: 0.8, duration: 0.4)
        up.timingMode = .easeInEaseOut
        return SKAction.sequence([down, up])
    }()

    lazy var chainsawRotateAction: SKAction = {
        SKAction.rotate(byAngle: .pi * 2, duration: 0.8)
    }()

    lazy var chainsawDangerPulseAction: SKAction = {
        let up = SKAction.scale(to: 1.1, duration: 0.2)
        up.timingMode = .easeInEaseOut
        let down = SKAction.scale(to: 1.0, duration: 0.2)
        down.timingMode = .easeInEaseOut
        return SKAction.sequence([up, down])
    }()

    lazy var damageFlashAction: SKAction = {
        let down = SKAction.fadeAlpha(to: 0.4, duration: 0.06)
        down.timingMode = .easeOut
        let up = SKAction.fadeAlpha(to: 1.0, duration: 0.09)
        up.timingMode = .easeIn
        return SKAction.sequence([down, up])
    }()

    // MARK: - State Caching

    var puddlePhaseCache: [String: String] = [:]  // id -> "warning", "active", "pop"
    var zonePhaseCache: [String: Bool] = [:]       // id -> isActive
    var lastIndicatorPhase: [String: Int] = [:]    // bossType -> last phase (for transition detection)
    var tileStateCache: [Int: OverclockerAI.TileState] = [:]  // tile index -> last state (8e transition detection)

    // MARK: - Boss Body Visual References

    weak var enemyLayer: SKNode?
    var cachedBossBodyNode: SKNode?
    var cachedBossEnemy: Enemy?  // Cached per frame to avoid repeated O(n) searches
    var lastKnownBossHealth: CGFloat = -1
    var cachedCyberbossPhase: Int = -1
    var cachedVoidHarbingerPhase: Int = -1
    var cachedOverclockerPhase: Int = -1

    /// Head position history for smooth Trojan Wyrm trailing (scene coordinates).
    var wyrmHeadHistory: [CGPoint] = []
    /// Frames of spacing between each body segment in the history buffer.
    let wyrmHistorySpacing: Int = 3

    // MARK: - Cached CGPaths (11f)

    /// Shared rift CGPath — all void rifts use the same length.
    static let cachedRiftPath: CGPath = {
        let path = CGMutablePath()
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: BalanceConfig.VoidHarbinger.voidRiftLength, y: 0))
        return path
    }()

    // MARK: - Configuration

    func configure(scene: SKScene, nodePool: NodePool, enemyLayer: SKNode? = nil) {
        self.scene = scene
        self.nodePool = nodePool
        self.enemyLayer = enemyLayer
    }

    // MARK: - Public Rendering API

    func renderFrame(gameState: GameState) {
        // Cache boss enemy lookup once per frame (avoids 6 O(n) scans)
        cachedBossEnemy = gameState.enemies.first(where: { $0.isBoss && !$0.isDead })

        // 6a: Detect health decrease and trigger damage flash
        if let boss = cachedBossEnemy {
            if lastKnownBossHealth >= 0 && boss.health < lastKnownBossHealth {
                triggerBossDamageFlash()
            }
            lastKnownBossHealth = boss.health
        }

        if let bossState = gameState.cyberbossState {
            renderCyberbossMechanics(bossState: bossState, gameState: gameState)
        } else {
            cleanupBossNodes(prefix: "cyberboss_")
        }

        if let bossState = gameState.voidHarbingerState {
            renderVoidHarbingerMechanics(bossState: bossState, gameState: gameState)
        } else {
            cleanupBossNodes(prefix: "voidharbinger_")
        }

        if let bossState = gameState.overclockerState {
            renderOverclockerMechanics(bossState: bossState, gameState: gameState)
        } else {
            cleanupBossNodes(prefix: "overclocker_")
        }

        if let bossState = gameState.trojanWyrmState {
            renderTrojanWyrmMechanics(bossState: bossState, gameState: gameState)
        } else {
            cleanupBossNodes(prefix: "trojanwyrm_")
        }
    }

    // MARK: - Boss Damage Flash

    private func triggerBossDamageFlash() {
        // Find the boss body node via the cached container
        if cachedBossBodyNode == nil || cachedBossBodyNode?.parent == nil,
           let boss = cachedBossEnemy {
            let bossScenePos = CGPoint(x: boss.x, y: (scene?.size.height ?? 0) - boss.y)
            cachedBossBodyNode = enemyLayer?.children.first(where: {
                abs($0.position.x - bossScenePos.x) < 5 && abs($0.position.y - bossScenePos.y) < 5
            })
        }

        if let bodyNode = cachedBossBodyNode?.childNode(withName: "body") {
            bodyNode.run(damageFlashAction, withKey: "damageFlash")
        }
    }

    // MARK: - Cleanup

    func cleanup() {
        for (key, node) in bossMechanicNodes {
            nodePool.release(node, type: poolTypeForKey(key))
        }
        bossMechanicNodes.removeAll()
        puddlePhaseCache.removeAll()
        zonePhaseCache.removeAll()
        lastIndicatorPhase.removeAll()
        tileStateCache.removeAll()
        cachedBossBodyNode = nil
        lastKnownBossHealth = -1
        cachedCyberbossPhase = -1
        cachedVoidHarbingerPhase = -1
        cachedOverclockerPhase = -1
        wyrmHeadHistory.removeAll()
    }

    func cleanupBossNodes(prefix: String) {
        let keysToRemove = bossMechanicNodes.keys.filter { $0.hasPrefix(prefix) }
        for key in keysToRemove {
            if let node = bossMechanicNodes[key] {
                nodePool.release(node, type: poolTypeForKey(key))
            }
            bossMechanicNodes.removeValue(forKey: key)
        }
    }

    /// Map a boss mechanic node key to its pool type for proper release.
    func poolTypeForKey(_ key: String) -> NodePoolType {
        if key.contains("puddle") { return .bossPuddle }
        if key.contains("laser") { return .bossLaser }
        if key.contains("zone") { return .bossZone }
        if key.contains("pylon") { return .bossPylon }
        if key.contains("rift") { return .bossRift }
        if key.contains("well") { return .bossWell }
        return .bossMisc
    }

    /// Remove a boss mechanic node by key, releasing it through the pool.
    func removeBossNode(key: String) {
        guard let node = bossMechanicNodes[key] else { return }
        nodePool.release(node, type: poolTypeForKey(key))
        bossMechanicNodes.removeValue(forKey: key)
    }

    // MARK: - Spawn/Despawn Animations (Stage 8)

    /// 8a: Fade in a newly created mechanic node from alpha 0.
    func fadeInMechanicNode(_ node: SKNode, targetAlpha: CGFloat = 1.0, duration: TimeInterval = 0.15) {
        node.alpha = 0
        node.run(SKAction.fadeAlpha(to: targetAlpha, duration: duration))
    }

    /// 8b: Fade out and remove a mechanic node, then release to pool.
    /// Removes the key from tracking immediately so new nodes can be created.
    func fadeOutAndRemoveBossNode(key: String, duration: TimeInterval = 0.2) {
        guard let node = bossMechanicNodes.removeValue(forKey: key) else { return }
        let poolType = poolTypeForKey(key)
        node.run(SKAction.sequence([
            SKAction.group([
                SKAction.fadeOut(withDuration: duration),
                SKAction.scale(to: 0.85, duration: duration)
            ]),
            SKAction.run { [weak self] in
                node.alpha = 1.0
                node.setScale(1.0)
                self?.nodePool.release(node, type: poolType)
            }
        ]))
    }

    /// 8c/8d: Spawn a visual-only particle burst at a position using SKActions.
    /// Creates small shape nodes that radiate outward and fade — no GameState needed.
    func spawnVisualBurst(at position: CGPoint, color: SKColor, count: Int = 12) {
        guard let scene = scene else { return }
        for _ in 0..<count {
            let particle = SKShapeNode(circleOfRadius: CGFloat.random(in: 2...4))
            particle.fillColor = color
            particle.strokeColor = color.withAlphaComponent(0.5)
            particle.position = position
            particle.zPosition = 150
            particle.blendMode = .add
            scene.addChild(particle)

            let angle = CGFloat.random(in: 0...(2 * .pi))
            let speed = CGFloat.random(in: 40...100)
            let dx = cos(angle) * speed
            let dy = sin(angle) * speed
            let lifetime = TimeInterval.random(in: 0.3...0.6)

            particle.run(SKAction.sequence([
                SKAction.group([
                    SKAction.moveBy(x: dx, y: dy, duration: lifetime),
                    SKAction.fadeOut(withDuration: lifetime),
                    SKAction.scale(to: 0.3, duration: lifetime)
                ]),
                SKAction.removeFromParent()
            ]))
        }
    }

    // MARK: - Utilities

    func findKeysToRemove(prefix: String, activeIds: Set<String>) -> [String] {
        let prefixCount = prefix.count
        var keysToRemove: [String] = []
        keysToRemove.reserveCapacity(bossMechanicNodes.count / 4)

        for key in bossMechanicNodes.keys {
            guard key.hasPrefix(prefix) else { continue }
            let id = String(key.dropFirst(prefixCount))
            if !activeIds.contains(id) {
                keysToRemove.append(key)
            }
        }
        return keysToRemove
    }

    func pointToLineDistance(point: CGPoint, lineStart: CGPoint, lineEnd: CGPoint) -> CGFloat {
        let dx = lineEnd.x - lineStart.x
        let dy = lineEnd.y - lineStart.y
        let lengthSquared = dx * dx + dy * dy

        if lengthSquared == 0 {
            return sqrt(pow(point.x - lineStart.x, 2) + pow(point.y - lineStart.y, 2))
        }

        let t = max(0, min(1, ((point.x - lineStart.x) * dx + (point.y - lineStart.y) * dy) / lengthSquared))
        let projX = lineStart.x + t * dx
        let projY = lineStart.y + t * dy

        return sqrt(pow(point.x - projX, 2) + pow(point.y - projY, 2))
    }

    // MARK: - Phase Indicator (7b: glow, color-coding, fade in/out)

    func renderPhaseIndicator(phase: Int, bossType: String, isInvulnerable: Bool = false, gameState: GameState) {
        guard let scene = scene else { return }
        let nodeKey = "\(bossType)_phase_indicator"

        // 7a: Detect phase transition
        let previousPhase = lastIndicatorPhase[bossType] ?? 0
        let isTransition = previousPhase > 0 && phase != previousPhase
        lastIndicatorPhase[bossType] = phase

        if isTransition {
            triggerPhaseTransitionEffects(phase: phase, bossType: bossType, gameState: gameState)
        }

        // 7b: Phase color coding
        let phaseColor: UIColor
        if isInvulnerable {
            phaseColor = DesignColors.warningUI
        } else {
            switch phase {
            case 1: phaseColor = UIColor(hex: "22c55e") ?? .green
            case 2: phaseColor = UIColor(hex: "fbbf24") ?? .yellow
            case 3: phaseColor = UIColor(hex: "f97316") ?? .orange
            case 4: phaseColor = UIColor(hex: "ef4444") ?? .red
            default: phaseColor = DesignColors.primaryUI
            }
        }

        let labelText = isInvulnerable ? L10n.Boss.phaseInvulnerable(phase) : L10n.Boss.phase(phase)

        if let container = bossMechanicNodes[nodeKey] {
            // Update text and color on existing indicator
            if let label = container.childNode(withName: "phaseLabel") as? SKLabelNode {
                label.text = labelText
                label.fontColor = phaseColor
            }
            if let glow = container.childNode(withName: "phaseGlow") as? SKLabelNode {
                glow.text = labelText
                glow.fontColor = phaseColor
            }

            // On phase change, re-trigger fade-in → hold → fade-out
            if isTransition {
                container.removeAction(forKey: "phaseFade")
                container.alpha = 0
                let fadeIn = SKAction.fadeAlpha(to: 1.0, duration: 0.3)
                fadeIn.timingMode = .easeOut
                let wait = SKAction.wait(forDuration: 3.0)
                let fadeOut = SKAction.fadeAlpha(to: 0, duration: 0.5)
                fadeOut.timingMode = .easeIn
                container.run(SKAction.sequence([fadeIn, wait, fadeOut]), withKey: "phaseFade")
            }
        } else {
            // Create phase indicator with glow layer
            let container = SKNode()
            container.position = CGPoint(x: gameState.arena.width / 2, y: gameState.arena.height - 60)
            container.zPosition = 200
            container.name = nodeKey

            // Glow layer behind label
            let glow = SKLabelNode(fontNamed: "Menlo-Bold")
            glow.text = labelText
            glow.fontSize = 18
            glow.fontColor = phaseColor
            glow.verticalAlignmentMode = .center
            glow.horizontalAlignmentMode = .center
            glow.alpha = 0.4
            glow.setScale(1.2)
            glow.name = "phaseGlow"
            container.addChild(glow)

            // Main label
            let label = SKLabelNode(fontNamed: "Menlo-Bold")
            label.text = labelText
            label.fontSize = 18
            label.fontColor = phaseColor
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .center
            label.name = "phaseLabel"
            container.addChild(label)

            // Fade in on creation, hold 3s, then fade out
            container.alpha = 0
            let fadeIn = SKAction.fadeAlpha(to: 1.0, duration: 0.3)
            fadeIn.timingMode = .easeOut
            let wait = SKAction.wait(forDuration: 3.0)
            let fadeOut = SKAction.fadeAlpha(to: 0, duration: 0.5)
            fadeOut.timingMode = .easeIn
            container.run(SKAction.sequence([fadeIn, wait, fadeOut]), withKey: "phaseFade")

            scene.addChild(container)
            bossMechanicNodes[nodeKey] = container
        }
    }

    // MARK: - Phase Transition Effects (7a)

    private func triggerPhaseTransitionEffects(phase: Int, bossType: String, gameState: GameState) {
        // 1. Boss body scale pulse (1.0 → 1.15 → 1.0 over 0.4s)
        if let bodyNode = cachedBossBodyNode {
            let scaleUp = SKAction.scale(to: 1.15, duration: 0.2)
            scaleUp.timingMode = .easeInEaseOut
            let scaleDown = SKAction.scale(to: 1.0, duration: 0.2)
            scaleDown.timingMode = .easeInEaseOut
            bodyNode.run(SKAction.sequence([scaleUp, scaleDown]), withKey: "phaseTransition")
        }

        // 2. Screen flash + shake via GameScene
        let flashColor: SKColor
        switch bossType {
        case "cyberboss":     flashColor = SKColor.cyan
        case "voidharbinger": flashColor = SKColor.magenta
        case "overclocker":   flashColor = SKColor.orange
        case "trojanwyrm":    flashColor = SKColor.green
        default:              flashColor = SKColor.white
        }

        if let gameScene = scene as? GameScene {
            gameScene.flashScreen(color: flashColor, intensity: 0.15, duration: 0.2)
            gameScene.shakeScreen(intensity: 6, duration: 0.3)
        }

        // 3. SCT dramatic text at boss position
        if let boss = cachedBossEnemy {
            let bossScenePos = CGPoint(x: boss.x, y: gameState.arena.height - boss.y + 60)
            let phaseText = L10n.Boss.phase(phase).uppercased()
            scene?.combatText.show(phaseText, type: .levelUp, at: bossScenePos, config: .dramatic)
        }
    }
}
