import Foundation

// MARK: - Poolable Protocol

/// Protocol for objects that can be reused via object pooling.
protocol Poolable {
    /// Reset the object to its default state for reuse.
    mutating func reset()

    /// Whether this object is currently active/in use.
    var isActive: Bool { get set }
}

// MARK: - Object Pool

/// A generic object pool for reducing GC pressure.
/// Pre-allocates objects and reuses them instead of creating/destroying constantly.
///
/// Usage:
/// ```swift
/// let pool = ObjectPool<Particle>(maxSize: 500) { Particle.default }
/// var particle = pool.acquire()
/// particle.x = 100
/// pool.release(&particle)
/// ```
class ObjectPool<T: Poolable> {

    // MARK: - Properties

    private var available: [T] = []
    private var activeCount: Int = 0
    private let maxSize: Int
    private let factory: () -> T

    // MARK: - Initialization

    /// Create an object pool.
    /// - Parameters:
    ///   - maxSize: Maximum number of objects to keep in the pool
    ///   - prewarm: Number of objects to pre-create (default: 0)
    ///   - factory: Factory function to create new objects
    init(maxSize: Int, prewarm: Int = 0, factory: @escaping () -> T) {
        self.maxSize = maxSize
        self.factory = factory

        // Pre-warm the pool
        for _ in 0..<min(prewarm, maxSize) {
            var obj = factory()
            obj.isActive = false
            available.append(obj)
        }
    }

    // MARK: - Acquire / Release

    /// Acquire an object from the pool.
    /// Returns a pooled object if available, otherwise creates a new one.
    func acquire() -> T {
        if var obj = available.popLast() {
            obj.isActive = true
            activeCount += 1
            return obj
        }

        // Create new object
        var obj = factory()
        obj.isActive = true
        activeCount += 1
        return obj
    }

    /// Release an object back to the pool.
    /// - Parameter obj: The object to release
    func release(_ obj: inout T) {
        obj.reset()
        obj.isActive = false
        activeCount = max(0, activeCount - 1)

        if available.count < maxSize {
            available.append(obj)
        }
        // If pool is full, object is discarded (will be garbage collected)
    }

    /// Release all objects matching a predicate.
    /// - Parameter predicate: Function that returns true for objects to release
    /// - Parameter objects: Array of objects to check
    /// - Returns: Objects that should remain active
    func releaseMatching(in objects: inout [T], where predicate: (T) -> Bool) -> [T] {
        var remaining: [T] = []

        for var obj in objects {
            if predicate(obj) {
                release(&obj)
            } else {
                remaining.append(obj)
            }
        }

        return remaining
    }

    // MARK: - Stats

    /// Number of objects available in the pool.
    var availableCount: Int {
        return available.count
    }

    /// Number of objects currently in use.
    var inUseCount: Int {
        return activeCount
    }

    /// Clear all objects from the pool.
    func clear() {
        available.removeAll()
        activeCount = 0
    }
}

// MARK: - Particle Poolable Extension

extension Particle: Poolable {
    /// Default particle for pooling
    static var defaultParticle: Particle {
        Particle(
            id: "",
            type: .hit,
            x: 0,
            y: 0,
            lifetime: 0,
            createdAt: 0,
            color: nil,
            size: nil,
            velocity: nil,
            rotation: nil,
            rotationSpeed: nil,
            drag: nil,
            shape: nil,
            scale: nil
        )
    }

    var isActive: Bool {
        get { lifetime > 0 }
        set { if !newValue { lifetime = 0 } }
    }

    mutating func reset() {
        id = ""
        type = .hit
        x = 0
        y = 0
        lifetime = 0
        createdAt = 0
        color = nil
        size = nil
        velocity = nil
        rotation = nil
        rotationSpeed = nil
        drag = nil
        shape = nil
        scale = nil
    }
}

// MARK: - Projectile Poolable Extension

extension Projectile: Poolable {
    /// Default projectile for pooling
    static var defaultProjectile: Projectile {
        Projectile(
            id: "",
            weaponId: "",
            x: 0,
            y: 0,
            velocityX: 0,
            velocityY: 0,
            damage: 0,
            radius: 0,
            color: "#ffffff",
            lifetime: 0,
            piercing: 0,
            hitEnemies: [],
            isHoming: false,
            homingStrength: 0,
            targetId: nil,
            speed: nil,
            createdAt: nil,
            pierceRemaining: nil,
            sourceType: nil,
            splash: nil,
            slow: nil,
            slowDuration: nil,
            size: nil,
            trail: nil
        )
    }

    var isActive: Bool {
        get { lifetime > 0 }
        set { if !newValue { lifetime = 0 } }
    }

    mutating func reset() {
        id = ""
        weaponId = ""
        x = 0
        y = 0
        velocityX = 0
        velocityY = 0
        damage = 0
        radius = 0
        color = "#ffffff"
        lifetime = 0
        piercing = 0
        hitEnemies = []
        isHoming = false
        homingStrength = 0
        targetId = nil
        speed = nil
        createdAt = nil
        pierceRemaining = nil
        sourceType = nil
        splash = nil
        slow = nil
        slowDuration = nil
        size = nil
        trail = nil
    }
}
