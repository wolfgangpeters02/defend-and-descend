import SpriteKit

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

    // MARK: - Acquire / Release

    /// Acquire a node of the specified type.
    /// - Parameters:
    ///   - type: Type key for the node (e.g., "enemy_basic", "projectile")
    ///   - creator: Factory function to create a new node if none available
    /// - Returns: A node ready for use
    func acquire(type: String, creator: () -> SKNode) -> SKNode {
        if var nodes = available[type], let node = nodes.popLast() {
            available[type] = nodes
            inUseCount[type, default: 0] += 1

            // Reset node state
            node.alpha = 1.0
            node.isHidden = false
            node.removeAllActions()
            node.zRotation = 0
            node.xScale = 1.0
            node.yScale = 1.0

            return node
        }

        // Create new node
        let node = creator()
        inUseCount[type, default: 0] += 1
        return node
    }

    /// Release a node back to the pool.
    /// - Parameters:
    ///   - node: The node to release
    ///   - type: Type key for the node
    func release(_ node: SKNode, type: String) {
        node.removeFromParent()
        node.removeAllActions()

        inUseCount[type, default: 0] -= 1

        if available[type] == nil {
            available[type] = []
        }

        if (available[type]?.count ?? 0) < maxPerType {
            available[type]?.append(node)
        }
        // If pool is full, node is discarded
    }

    /// Release all nodes of a specific type that match a predicate.
    /// - Parameters:
    ///   - type: Type key for the nodes
    ///   - nodes: Dictionary of id -> node
    ///   - activeIds: Set of IDs that should remain active
    /// - Returns: Updated dictionary with only active nodes
    func releaseInactive(
        type: String,
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
    func availableCount(for type: String) -> Int {
        return available[type]?.count ?? 0
    }

    /// Get the number of in-use nodes for a type.
    func inUseCount(for type: String) -> Int {
        return inUseCount[type] ?? 0
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

        let type = "enemy_\(enemy.type)"
        let node = acquire(type: type) {
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

        let node = acquire(type: "projectile") {
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

        let type = "pickup_\(pickup.type.rawValue)"
        let node = acquire(type: type) {
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

        let type = "particle_\(particle.type.rawValue)"
        let node = acquire(type: type) {
            renderer.createParticleNode(particle: particle)
        }
        existing[id] = node
        return node
    }

    // MARK: - Boss Mechanic Node Pooling

    /// Acquire or reuse a boss mechanic node (puddles, lasers, zones, etc.)
    func acquireBossMechanicNode(
        id: String,
        type: String,
        existing: inout [String: SKNode],
        creator: () -> SKNode
    ) -> SKNode {
        if let node = existing[id] {
            return node
        }

        let node = acquire(type: "boss_\(type)", creator: creator)
        existing[id] = node
        return node
    }

    /// Release boss mechanic nodes that are no longer active.
    func releaseBossMechanicNodes(
        type: String,
        nodes: inout [String: SKNode],
        activeIds: Set<String>
    ) {
        let keysToRemove = nodes.keys.filter { !activeIds.contains($0) }
        for key in keysToRemove {
            if let node = nodes[key] {
                release(node, type: "boss_\(type)")
                nodes.removeValue(forKey: key)
            }
        }
    }
}
