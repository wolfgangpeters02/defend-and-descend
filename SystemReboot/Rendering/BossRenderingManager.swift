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
        for (_, node) in bossMechanicNodes {
            node.removeFromParent()
        }
        bossMechanicNodes.removeAll()
        puddlePhaseCache.removeAll()
        zonePhaseCache.removeAll()
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
                let poolType: String
                if key.contains("puddle") { poolType = "boss_puddle" }
                else if key.contains("laser") { poolType = "boss_laser" }
                else if key.contains("zone") { poolType = "boss_zone" }
                else if key.contains("pylon") { poolType = "boss_pylon" }
                else if key.contains("rift") { poolType = "boss_rift" }
                else if key.contains("well") { poolType = "boss_well" }
                else { poolType = "boss_misc" }
                nodePool.release(node, type: poolType)
            }
            bossMechanicNodes.removeValue(forKey: key)
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

    // MARK: - Phase Indicator

    func renderPhaseIndicator(phase: Int, bossType: String, isInvulnerable: Bool = false, gameState: GameState) {
        guard let scene = scene else { return }
        let nodeKey = "\(bossType)_phase_indicator"

        if let label = bossMechanicNodes[nodeKey] as? SKLabelNode {
            label.text = isInvulnerable ? L10n.Boss.phaseInvulnerable(phase) : L10n.Boss.phase(phase)
            label.fontColor = isInvulnerable ? DesignColors.warningUI : DesignColors.primaryUI
        } else {
            let label = SKLabelNode(text: L10n.Boss.phase(phase))
            label.fontName = "Menlo-Bold"
            label.fontSize = 18
            label.fontColor = DesignColors.primaryUI
            label.position = CGPoint(x: gameState.arena.width / 2, y: gameState.arena.height - 60)
            label.zPosition = 200
            label.name = nodeKey

            scene.addChild(label)
            bossMechanicNodes[nodeKey] = label
        }
    }
}
