import Foundation
import CoreGraphics

// MARK: - Spatial Grid

/// A uniform grid spatial hash for efficient spatial queries.
/// Provides O(1) cell lookup and O(n) collision detection instead of O(n^2).
///
/// Usage:
/// ```swift
/// let grid = SpatialGrid<Enemy>(cellSize: 100)
/// grid.clear()
/// for enemy in enemies {
///     grid.insert(enemy, at: CGPoint(x: enemy.x, y: enemy.y))
/// }
/// let nearby = grid.query(x: projectile.x, y: projectile.y, radius: 50)
/// ```
class SpatialGrid<T: Identifiable> {

    // MARK: - Properties

    private let cellSize: CGFloat
    private var cells: [Int: [T]] = [:]
    private var entityPositions: [T.ID: CGPoint] = [:]

    // MARK: - Initialization

    /// Create a spatial grid with the specified cell size.
    /// - Parameter cellSize: Size of each grid cell. Larger values = fewer cells but more entities per cell.
    ///                       Recommended: slightly larger than the largest entity radius.
    init(cellSize: CGFloat = 100) {
        self.cellSize = cellSize
    }

    // MARK: - Cell Hash

    /// Compute the cell hash for a position.
    /// Uses Cantor pairing function for unique 2D -> 1D mapping.
    func cellHash(x: CGFloat, y: CGFloat) -> Int {
        let cellX = Int(floor(x / cellSize))
        let cellY = Int(floor(y / cellSize))
        // Cantor pairing function (handles negative coordinates)
        let shiftedX = cellX >= 0 ? 2 * cellX : -2 * cellX - 1
        let shiftedY = cellY >= 0 ? 2 * cellY : -2 * cellY - 1
        return (shiftedX + shiftedY) * (shiftedX + shiftedY + 1) / 2 + shiftedY
    }

    /// Get the cell coordinates for a position.
    func cellCoords(x: CGFloat, y: CGFloat) -> (Int, Int) {
        return (Int(floor(x / cellSize)), Int(floor(y / cellSize)))
    }

    // MARK: - Insert / Remove / Update

    /// Insert an entity at the specified position.
    func insert(_ entity: T, at position: CGPoint) {
        let hash = cellHash(x: position.x, y: position.y)
        if cells[hash] == nil {
            cells[hash] = []
        }
        cells[hash]?.append(entity)
        entityPositions[entity.id] = position
    }

    /// Remove an entity from its current position.
    func remove(id: T.ID) {
        guard let position = entityPositions[id] else { return }
        let hash = cellHash(x: position.x, y: position.y)
        cells[hash]?.removeAll { $0.id == id }
        entityPositions.removeValue(forKey: id)
    }

    /// Update an entity's position in the grid.
    func update(_ entity: T, from oldPos: CGPoint, to newPos: CGPoint) {
        let oldHash = cellHash(x: oldPos.x, y: oldPos.y)
        let newHash = cellHash(x: newPos.x, y: newPos.y)

        if oldHash != newHash {
            // Entity moved to a different cell
            cells[oldHash]?.removeAll { $0.id == entity.id }
            if cells[newHash] == nil {
                cells[newHash] = []
            }
            cells[newHash]?.append(entity)
        }
        entityPositions[entity.id] = newPos
    }

    // MARK: - Query

    /// Query entities within a radius of a point.
    /// - Parameters:
    ///   - x: X coordinate of query center
    ///   - y: Y coordinate of query center
    ///   - radius: Search radius
    /// - Returns: All entities that might be within the radius (includes entities in overlapping cells)
    func query(x: CGFloat, y: CGFloat, radius: CGFloat) -> [T] {
        var results: [T] = []

        // Calculate which cells we need to check
        let cellRadius = Int(ceil(radius / cellSize))
        let (centerCellX, centerCellY) = cellCoords(x: x, y: y)

        // Check all cells in the bounding box
        for dx in -cellRadius...cellRadius {
            for dy in -cellRadius...cellRadius {
                let cellX = centerCellX + dx
                let cellY = centerCellY + dy
                let hash = hashForCell(cellX: cellX, cellY: cellY)

                if let entitiesInCell = cells[hash] {
                    results.append(contentsOf: entitiesInCell)
                }
            }
        }

        return results
    }

    /// Query entities within a rectangular region.
    func queryRect(minX: CGFloat, minY: CGFloat, maxX: CGFloat, maxY: CGFloat) -> [T] {
        var results: [T] = []

        let (minCellX, minCellY) = cellCoords(x: minX, y: minY)
        let (maxCellX, maxCellY) = cellCoords(x: maxX, y: maxY)

        for cellX in minCellX...maxCellX {
            for cellY in minCellY...maxCellY {
                let hash = hashForCell(cellX: cellX, cellY: cellY)
                if let entitiesInCell = cells[hash] {
                    results.append(contentsOf: entitiesInCell)
                }
            }
        }

        return results
    }

    /// Clear all entities from the grid.
    func clear() {
        cells.removeAll(keepingCapacity: true)
        entityPositions.removeAll(keepingCapacity: true)
    }

    // MARK: - Helpers

    /// Compute hash for a cell coordinate directly.
    private func hashForCell(cellX: Int, cellY: Int) -> Int {
        let shiftedX = cellX >= 0 ? 2 * cellX : -2 * cellX - 1
        let shiftedY = cellY >= 0 ? 2 * cellY : -2 * cellY - 1
        return (shiftedX + shiftedY) * (shiftedX + shiftedY + 1) / 2 + shiftedY
    }

    // MARK: - Debug

    /// Get the number of occupied cells.
    var occupiedCellCount: Int {
        return cells.count
    }

    /// Get the total number of entities in the grid.
    var entityCount: Int {
        return entityPositions.count
    }
}

// MARK: - Spatial Grid Extensions for Common Types

extension SpatialGrid where T == Enemy {
    /// Rebuild the grid from an array of enemies.
    func rebuild(from enemies: [Enemy]) {
        clear()
        for enemy in enemies where !enemy.isDead {
            insert(enemy, at: CGPoint(x: enemy.x, y: enemy.y))
        }
    }

    /// Query for enemies within range of a point, with actual distance check.
    func queryWithDistance(x: CGFloat, y: CGFloat, radius: CGFloat) -> [(enemy: Enemy, distance: CGFloat)] {
        let candidates = query(x: x, y: y, radius: radius)
        var results: [(enemy: Enemy, distance: CGFloat)] = []

        for enemy in candidates {
            let dx = enemy.x - x
            let dy = enemy.y - y
            let distance = sqrt(dx * dx + dy * dy)
            if distance <= radius {
                results.append((enemy, distance))
            }
        }

        return results.sorted { $0.distance < $1.distance }
    }

    /// Find the nearest enemy within range.
    func findNearest(x: CGFloat, y: CGFloat, range: CGFloat) -> Enemy? {
        let candidates = queryWithDistance(x: x, y: y, radius: range)
        return candidates.first?.enemy
    }
}
