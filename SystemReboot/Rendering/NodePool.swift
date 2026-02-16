import SpriteKit

// MARK: - Node Pool Type

/// Type-safe keys for the node pool, preventing typos and mismatches.
enum NodePoolType: Hashable {
    // Standard entity types
    case enemy
    case projectile
    case tdProjectile

    case pickup
    case particle

    // Boss mechanic types
    case bossPuddle
    case bossLaser
    case bossZone
    case bossPylon
    case bossRift
    case bossWell
    case bossMisc

    var key: String {
        switch self {
        case .enemy: return "enemy"
        case .projectile: return "projectile"
        case .tdProjectile: return "td_projectile"
        case .pickup: return "pickup"
        case .particle: return "particle"
        case .bossPuddle: return "boss_puddle"
        case .bossLaser: return "boss_laser"
        case .bossZone: return "boss_zone"
        case .bossPylon: return "boss_pylon"
        case .bossRift: return "boss_rift"
        case .bossWell: return "boss_well"
        case .bossMisc: return "boss_misc"
        }
    }
}

// MARK: - Node Pool

/// A pool for reusing SpriteKit nodes to reduce allocation overhead.
/// Nodes are stored by type key and reused when available.
class NodePool {

    // MARK: - Properties

    private var available: [String: [SKNode]] = [:]
    private var inUseCount: [String: Int] = [:]
    private let maxPerType: Int

    // MARK: - Initialization

    /// Create a node pool.
    /// - Parameter maxPerType: Maximum nodes to keep per type (default: 100)
    init(maxPerType: Int = 100) {
        self.maxPerType = maxPerType
    }

    // MARK: - Pre-warming

    /// Pre-create nodes for a type during loading screens to avoid runtime allocation spikes.
    func prewarm(type: NodePoolType, count: Int, creator: () -> SKNode) {
        let key = type.key
        if available[key] == nil {
            available[key] = []
        }
        let currentCount = available[key]?.count ?? 0
        let toCreate = min(count - currentCount, maxPerType - currentCount)
        guard toCreate > 0 else { return }
        for _ in 0..<toCreate {
            let node = creator()
            available[key]?.append(node)
        }
    }

    // MARK: - Acquire / Release

    /// Acquire a node of the specified type.
    /// - Parameters:
    ///   - type: Type-safe pool key
    ///   - creator: Factory function to create a new node if none available
    /// - Returns: A node ready for use
    func acquire(type: NodePoolType, creator: () -> SKNode) -> SKNode {
        let key = type.key
        if var nodes = available[key], let node = nodes.popLast() {
            available[key] = nodes
            inUseCount[key, default: 0] += 1

            // Reset node state for reuse
            node.alpha = 1.0
            node.isHidden = false
            node.zRotation = 0
            node.xScale = 1.0
            node.yScale = 1.0
            node.removeAllActions()
            // Strip leftover children from previous use (e.g. muzzle flashes, particles)
            for child in node.children where child.name == nil || child.name?.hasPrefix("temp_") == true {
                child.removeFromParent()
            }

            return node
        }

        // Create new node
        let node = creator()
        inUseCount[key, default: 0] += 1
        return node
    }

    /// Release a node back to the pool.
    func release(_ node: SKNode, type: NodePoolType) {
        let key = type.key
        node.removeFromParent()
        node.removeAllActions()

        // Guard against negative counts (double-release or mismatched type keys)
        let current = inUseCount[key, default: 0]
        inUseCount[key] = max(current - 1, 0)

        if available[key] == nil {
            available[key] = []
        }

        if (available[key]?.count ?? 0) < maxPerType {
            available[key]?.append(node)
        }
        // If pool is full, node is discarded
    }

    /// Release all nodes of a specific type that are no longer active.
    func releaseInactive(
        type: NodePoolType,
        nodes: inout [String: SKNode],
        activeIds: Set<String>
    ) {
        for (id, node) in nodes where !activeIds.contains(id) {
            release(node, type: type)
            nodes.removeValue(forKey: id)
        }
    }

    // MARK: - Stats

    /// Get the number of available nodes for a type.
    func availableCount(for type: NodePoolType) -> Int {
        return available[type.key]?.count ?? 0
    }

    /// Get the number of in-use nodes for a type.
    func inUseCount(for type: NodePoolType) -> Int {
        return inUseCount[type.key] ?? 0
    }

    /// Total available nodes across all types.
    var totalAvailable: Int {
        return available.values.reduce(0) { $0 + $1.count }
    }

    /// Clear all nodes from the pool.
    func clear() {
        available.removeAll()
        inUseCount.removeAll()
    }
}

// MARK: - Node Pool Extensions

extension NodePool {
    /// Acquire or update an enemy node.
    func acquireEnemyNode(
        id: String,
        existing: inout [String: SKNode],
        renderer: EntityRenderer,
        enemy: Enemy
    ) -> SKNode {
        if let node = existing[id] {
            return node
        }

        let node = acquire(type: .enemy) {
            renderer.createEnemyNode(enemy: enemy)
        }
        existing[id] = node
        return node
    }

    /// Acquire or update a projectile node.
    func acquireProjectileNode(
        id: String,
        existing: inout [String: SKNode],
        renderer: EntityRenderer,
        projectile: Projectile
    ) -> SKNode {
        if let node = existing[id] {
            return node
        }

        let node = acquire(type: .projectile) {
            renderer.createProjectileNode(projectile: projectile)
        }
        existing[id] = node
        return node
    }

    /// Acquire or update a pickup node.
    func acquirePickupNode(
        id: String,
        existing: inout [String: SKNode],
        renderer: EntityRenderer,
        pickup: Pickup
    ) -> SKNode {
        if let node = existing[id] {
            return node
        }

        let node = acquire(type: .pickup) {
            renderer.createPickupNode(pickup: pickup)
        }
        existing[id] = node
        return node
    }

    /// Acquire or update a particle node.
    func acquireParticleNode(
        id: String,
        existing: inout [String: SKNode],
        renderer: EntityRenderer,
        particle: Particle
    ) -> SKNode {
        if let node = existing[id] {
            return node
        }

        let node = acquire(type: .particle) {
            renderer.createParticleNode(particle: particle)
        }
        existing[id] = node
        return node
    }
}
