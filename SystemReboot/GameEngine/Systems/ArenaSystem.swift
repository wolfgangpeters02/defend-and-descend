import Foundation
import CoreGraphics

// MARK: - Arena System
// Simplified collision detection utilities for survival and boss modes

class ArenaSystem {

    // MARK: - Obstacle Collision

    /// Check if a circle collides with a rectangle obstacle
    static func checkObstacleCollision(
        x: CGFloat, y: CGFloat, radius: CGFloat,
        obstacle: Obstacle
    ) -> Bool {
        // Find closest point on rectangle to circle center
        let closestX = max(obstacle.x, min(x, obstacle.x + obstacle.width))
        let closestY = max(obstacle.y, min(y, obstacle.y + obstacle.height))

        // Calculate distance from closest point to circle center
        let distanceX = x - closestX
        let distanceY = y - closestY
        let distanceSquared = distanceX * distanceX + distanceY * distanceY

        return distanceSquared < radius * radius
    }

    /// Check if a point is inside a rectangular zone
    static func isInsideZone(x: CGFloat, y: CGFloat, zone: ArenaEffectZone) -> Bool {
        return x >= zone.x && x <= zone.x + zone.width &&
               y >= zone.y && y <= zone.y + zone.height
    }

    /// Check if a point is inside a hazard
    static func isInsideHazard(x: CGFloat, y: CGFloat, hazard: Hazard) -> Bool {
        return x >= hazard.x && x <= hazard.x + hazard.width &&
               y >= hazard.y && y <= hazard.y + hazard.height
    }

    /// Resolve collision by sliding along obstacle
    static func resolveObstacleCollision(
        x: CGFloat, y: CGFloat, radius: CGFloat,
        velocityX: CGFloat, velocityY: CGFloat,
        obstacle: Obstacle
    ) -> (newX: CGFloat, newY: CGFloat, newVelX: CGFloat, newVelY: CGFloat) {
        // Find closest point on rectangle
        let closestX = max(obstacle.x, min(x, obstacle.x + obstacle.width))
        let closestY = max(obstacle.y, min(y, obstacle.y + obstacle.height))

        // Calculate penetration vector
        let dx = x - closestX
        let dy = y - closestY
        let distance = sqrt(dx * dx + dy * dy)

        if distance < 0.001 {
            // Point is inside rectangle, push out based on velocity
            return (x - velocityX, y - velocityY, 0, 0)
        }

        // Normalize and push out
        let penetration = radius - distance
        let nx = dx / distance
        let ny = dy / distance

        let newX = x + nx * penetration
        let newY = y + ny * penetration

        // Slide velocity along surface
        let dot = velocityX * nx + velocityY * ny
        let newVelX = velocityX - dot * nx
        let newVelY = velocityY - dot * ny

        return (newX, newY, newVelX, newVelY)
    }

    // MARK: - Player Obstacle Collision

    /// Process all obstacle collisions for player using arena obstacles
    static func processPlayerObstacleCollisions(state: inout GameState) {
        let playerRadius = state.player.size

        for obstacle in state.arena.obstacles {
            if checkObstacleCollision(
                x: state.player.x, y: state.player.y,
                radius: playerRadius, obstacle: obstacle
            ) {
                let result = resolveObstacleCollision(
                    x: state.player.x, y: state.player.y,
                    radius: playerRadius,
                    velocityX: state.player.velocityX,
                    velocityY: state.player.velocityY,
                    obstacle: obstacle
                )

                state.player.x = result.newX
                state.player.y = result.newY
                state.player.velocityX = result.newVelX
                state.player.velocityY = result.newVelY
            }
        }
    }

    // MARK: - Enemy Obstacle Collision

    /// Process obstacle collisions for all enemies
    static func processEnemyObstacleCollisions(state: inout GameState) {
        for i in 0..<state.enemies.count {
            let enemyRadius = state.enemies[i].size ?? CGFloat(BalanceConfig.EnemyDefaults.size)

            for obstacle in state.arena.obstacles {
                if checkObstacleCollision(
                    x: state.enemies[i].x, y: state.enemies[i].y,
                    radius: enemyRadius, obstacle: obstacle
                ) {
                    let result = resolveObstacleCollision(
                        x: state.enemies[i].x, y: state.enemies[i].y,
                        radius: enemyRadius,
                        velocityX: state.enemies[i].velocityX,
                        velocityY: state.enemies[i].velocityY,
                        obstacle: obstacle
                    )

                    state.enemies[i].x = result.newX
                    state.enemies[i].y = result.newY
                    state.enemies[i].velocityX = result.newVelX
                    state.enemies[i].velocityY = result.newVelY
                }
            }
        }
    }

    // MARK: - Projectile Obstacle Collision

    /// Check if projectile hits an obstacle (destroys projectile)
    static func processProjectileObstacleCollisions(state: inout GameState) {
        state.projectiles = state.projectiles.filter { projectile in
            for obstacle in state.arena.obstacles {
                // Simple point-in-rectangle check for projectiles
                if projectile.x >= obstacle.x &&
                   projectile.x <= obstacle.x + obstacle.width &&
                   projectile.y >= obstacle.y &&
                   projectile.y <= obstacle.y + obstacle.height {
                    return false // Remove projectile
                }
            }
            return true // Keep projectile
        }
    }

    // MARK: - Boundary Checks

    /// Keep player within arena bounds
    static func constrainPlayerToArena(state: inout GameState) {
        let margin = state.player.size
        let arena = state.arena

        state.player.x = max(margin, min(arena.width - margin, state.player.x))
        state.player.y = max(margin, min(arena.height - margin, state.player.y))
    }

    /// Check if position is within arena bounds
    static func isWithinArena(x: CGFloat, y: CGFloat, arena: ArenaData, margin: CGFloat = 0) -> Bool {
        return x >= margin && x <= arena.width - margin &&
               y >= margin && y <= arena.height - margin
    }
}
