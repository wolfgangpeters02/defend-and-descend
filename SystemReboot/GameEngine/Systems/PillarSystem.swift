import Foundation
import CoreGraphics

// MARK: - Pillar System

/// Handles destructible pillar mechanics in boss fights.
/// Bosses damage pillars when players hide behind them for cover.
class PillarSystem {

    /// Damage per second bosses deal to pillars when line-of-sight is blocked
    private static var bossPillarDPS: CGFloat { BalanceConfig.Pillar.bossPillarDPS }

    /// Update pillar system - checks for line-of-sight blocking and damages pillars
    static func update(state: inout GameState, deltaTime: TimeInterval) {
        // Only active in boss mode with pillars
        guard state.gameMode == .boss,
              !state.arena.obstacles.isEmpty else { return }

        // Find the active boss
        guard let boss = state.enemies.first(where: { $0.isBoss && !$0.isDead }) else { return }

        let playerPos = CGPoint(x: state.player.x, y: state.player.y)
        let bossPos = CGPoint(x: boss.x, y: boss.y)

        // Check each destructible pillar
        for i in 0..<state.arena.obstacles.count {
            guard state.arena.obstacles[i].isDestructible,
                  let health = state.arena.obstacles[i].health,
                  health > 0 else { continue }

            let obstacle = state.arena.obstacles[i]
            let obstacleRect = CGRect(
                x: obstacle.x,
                y: obstacle.y,
                width: obstacle.width,
                height: obstacle.height
            )

            // Check if pillar blocks line-of-sight between boss and player
            if lineIntersectsRect(from: bossPos, to: playerPos, rect: obstacleRect) {
                // Boss damages this pillar
                let damage = bossPillarDPS * CGFloat(deltaTime)
                state.arena.obstacles[i].health = max(0, health - damage)

                // Check for destruction
                if state.arena.obstacles[i].health == 0 {
                    destroyPillar(state: &state, pillarIndex: i)
                }
            }
        }
    }

    /// Destroy a pillar with particle effects
    private static func destroyPillar(state: inout GameState, pillarIndex: Int) {
        let pillar = state.arena.obstacles[pillarIndex]

        // Create explosion particles at pillar center
        let centerX = pillar.x + pillar.width / 2
        let centerY = pillar.y + pillar.height / 2

        ParticleFactory.createExplosion(
            state: &state,
            x: centerX,
            y: centerY,
            color: "#6b7280",  // Gray debris
            count: 20,
            size: 15
        )

        // Create secondary debris particles
        ParticleFactory.createExplosion(
            state: &state,
            x: centerX,
            y: centerY,
            color: "#9ca3af",  // Lighter gray
            count: 15,
            size: 10
        )
    }

    /// Check if a line segment intersects a rectangle
    private static func lineIntersectsRect(from start: CGPoint, to end: CGPoint, rect: CGRect) -> Bool {
        // Check if either endpoint is inside the rect
        if rect.contains(start) || rect.contains(end) {
            return true
        }

        // Check line against each edge of the rectangle
        let topLeft = CGPoint(x: rect.minX, y: rect.minY)
        let topRight = CGPoint(x: rect.maxX, y: rect.minY)
        let bottomLeft = CGPoint(x: rect.minX, y: rect.maxY)
        let bottomRight = CGPoint(x: rect.maxX, y: rect.maxY)

        // Check all four edges
        if lineSegmentsIntersect(start, end, topLeft, topRight) { return true }
        if lineSegmentsIntersect(start, end, topRight, bottomRight) { return true }
        if lineSegmentsIntersect(start, end, bottomRight, bottomLeft) { return true }
        if lineSegmentsIntersect(start, end, bottomLeft, topLeft) { return true }

        return false
    }

    /// Check if two line segments intersect
    private static func lineSegmentsIntersect(_ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint, _ p4: CGPoint) -> Bool {
        let d1 = direction(p3, p4, p1)
        let d2 = direction(p3, p4, p2)
        let d3 = direction(p1, p2, p3)
        let d4 = direction(p1, p2, p4)

        if ((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
           ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0)) {
            return true
        }

        if d1 == 0 && onSegment(p3, p4, p1) { return true }
        if d2 == 0 && onSegment(p3, p4, p2) { return true }
        if d3 == 0 && onSegment(p1, p2, p3) { return true }
        if d4 == 0 && onSegment(p1, p2, p4) { return true }

        return false
    }

    /// Cross product direction
    private static func direction(_ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint) -> CGFloat {
        return (p3.x - p1.x) * (p2.y - p1.y) - (p2.x - p1.x) * (p3.y - p1.y)
    }

    /// Check if point is on segment
    private static func onSegment(_ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint) -> Bool {
        return min(p1.x, p2.x) <= p3.x && p3.x <= max(p1.x, p2.x) &&
               min(p1.y, p2.y) <= p3.y && p3.y <= max(p1.y, p2.y)
    }

    // MARK: - Rendering Helpers

    /// Get pillar health percentage for rendering health bars
    static func getPillarHealthPercent(obstacle: Obstacle) -> CGFloat? {
        guard obstacle.isDestructible,
              let health = obstacle.health,
              let maxHealth = obstacle.maxHealth,
              maxHealth > 0 else {
            return nil
        }
        return health / maxHealth
    }

    /// Check if a pillar is still standing (has health > 0)
    static func isPillarAlive(obstacle: Obstacle) -> Bool {
        guard obstacle.isDestructible,
              let health = obstacle.health else {
            return true  // Non-destructible obstacles are always "alive"
        }
        return health > 0
    }
}
