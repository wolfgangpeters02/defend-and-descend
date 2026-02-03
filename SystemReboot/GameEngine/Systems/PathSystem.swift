import Foundation
import CoreGraphics

// MARK: - Path System
// Handles enemy movement along paths in TD mode

class PathSystem {

    // MARK: - Path Following

    /// Update all enemy positions along paths
    static func updateEnemyPositions(state: inout TDGameState, deltaTime: TimeInterval, currentTime: TimeInterval) {
        for i in 0..<state.enemies.count {
            if state.enemies[i].isDead || state.enemies[i].reachedCore {
                continue
            }

            updateEnemyPosition(state: &state, enemyIndex: i, deltaTime: deltaTime, currentTime: currentTime)
        }
    }

    /// Update single enemy position
    private static func updateEnemyPosition(
        state: inout TDGameState,
        enemyIndex: Int,
        deltaTime: TimeInterval,
        currentTime: TimeInterval
    ) {
        var enemy = state.enemies[enemyIndex]

        // Update slow status
        enemy.updateSlow(currentTime: currentTime)

        // Get path for this enemy
        guard state.paths.indices.contains(enemy.pathIndex) else { return }
        let path = state.paths[enemy.pathIndex]

        // Calculate movement
        let speed = enemy.currentSpeed
        let distanceToMove = speed * CGFloat(deltaTime)
        let pathLength = path.length

        // Update progress
        let progressDelta = distanceToMove / pathLength
        enemy.pathProgress += progressDelta

        // Check if reached end
        if enemy.pathProgress >= 1.0 {
            enemy.pathProgress = 1.0
            enemy.reachedCore = true
        }

        // Update position from path progress
        let newPosition = path.positionAt(progress: enemy.pathProgress)
        enemy.x = newPosition.x
        enemy.y = newPosition.y

        // Save changes
        state.enemies[enemyIndex] = enemy
    }

    // MARK: - Core Damage (Efficiency System)

    /// Process enemies that reached the core
    /// System: Reboot - Uses efficiency instead of lives. No game over from leaks.
    static func processReachedCore(state: inout TDGameState) {
        for i in (0..<state.enemies.count).reversed() {
            let enemy = state.enemies[i]

            if enemy.reachedCore && !enemy.isDead {
                // Deal damage to core (visual/feedback only)
                state.core.takeDamage(enemy.damage)

                // Efficiency System: Increment leak counter instead of decrementing lives
                // Each leak reduces efficiency by 5% (up to 20 leaks = 0% efficiency)
                let previousEfficiency = state.efficiency
                state.leakCounter += 1

                // Mark enemy as handled
                state.enemies[i].isDead = true
                state.waveEnemiesRemaining -= 1

                // Haptic feedback based on efficiency drop severity
                if state.efficiency <= 0 && previousEfficiency > 0 {
                    // Efficiency hit 0% - SYSTEM FREEZE triggered!
                    state.isSystemFrozen = true
                    state.freezeCount += 1
                    HapticsService.shared.play(.defeat)
                } else if state.efficiency <= BalanceConfig.Efficiency.warningThreshold && previousEfficiency > BalanceConfig.Efficiency.warningThreshold {
                    // Efficiency dropped below warning threshold
                    HapticsService.shared.play(.warning)
                } else {
                    // Normal leak - light feedback
                    HapticsService.shared.play(.light)
                }

                // Note: System freeze pauses game, player must recover via UI options
            }
        }
    }

    /// Decay leak counter over time (call from game loop)
    /// Leak counter decreases by 1 every 5 seconds (modified by RAM upgrade)
    static func updateLeakDecay(state: inout TDGameState, deltaTime: TimeInterval) {
        state.leakDecayTimer += deltaTime
        // RAM upgrade speeds up efficiency recovery (higher multiplier = faster decay)
        let decayInterval = BalanceConfig.Efficiency.leakDecayInterval / state.efficiencyRegenMultiplier
        if state.leakDecayTimer >= decayInterval && state.leakCounter > 0 {
            state.leakCounter -= 1
            state.leakDecayTimer = 0
        }
    }

    /// Update Hash income based on efficiency
    static func updateHashIncome(state: inout TDGameState, deltaTime: TimeInterval) {
        // Accumulate fractional hash
        state.hashAccumulator += state.hashPerSecond * CGFloat(deltaTime)

        // Convert to whole hash (subject to HDD storage cap)
        let wholeHash = Int(state.hashAccumulator)
        if wholeHash > 0 {
            let actualAdded = state.addHash(wholeHash)
            state.hashAccumulator -= CGFloat(wholeHash)
            state.stats.goldEarned += actualAdded
        }
    }

    // MARK: - Path Utilities

    /// Get distance from enemy to core
    static func distanceToCore(enemy: TDEnemy, path: EnemyPath) -> CGFloat {
        return (1.0 - enemy.pathProgress) * path.length
    }

    /// Check if point is on or near path
    static func isNearPath(point: CGPoint, paths: [EnemyPath], threshold: CGFloat = 30) -> Bool {
        for path in paths {
            for waypoint in path.waypoints {
                let dx = point.x - waypoint.x
                let dy = point.y - waypoint.y
                if sqrt(dx*dx + dy*dy) < threshold {
                    return true
                }
            }
        }
        return false
    }

    /// Get closest point on path to a given point
    static func closestPointOnPath(point: CGPoint, path: EnemyPath) -> (point: CGPoint, progress: CGFloat) {
        guard path.waypoints.count > 1 else {
            return (path.waypoints.first ?? .zero, 0)
        }

        var closestPoint = path.waypoints[0]
        var closestDistance = CGFloat.infinity
        var closestProgress: CGFloat = 0
        var accumulatedLength: CGFloat = 0

        for i in 1..<path.waypoints.count {
            let from = path.waypoints[i-1]
            let to = path.waypoints[i]

            let segmentLength = hypot(to.x - from.x, to.y - from.y)
            let closest = closestPointOnSegment(point: point, from: from, to: to)
            let distance = hypot(closest.x - point.x, closest.y - point.y)

            if distance < closestDistance {
                closestDistance = distance
                closestPoint = closest

                // Calculate progress
                let distFromStart = hypot(closest.x - from.x, closest.y - from.y)
                closestProgress = (accumulatedLength + distFromStart) / path.length
            }

            accumulatedLength += segmentLength
        }

        return (closestPoint, closestProgress)
    }

    /// Find closest point on line segment
    private static func closestPointOnSegment(point: CGPoint, from: CGPoint, to: CGPoint) -> CGPoint {
        let dx = to.x - from.x
        let dy = to.y - from.y
        let lengthSquared = dx*dx + dy*dy

        if lengthSquared == 0 {
            return from
        }

        let t = max(0, min(1, ((point.x - from.x) * dx + (point.y - from.y) * dy) / lengthSquared))
        return CGPoint(x: from.x + t * dx, y: from.y + t * dy)
    }

    // MARK: - Path Visualization

    /// Get points for drawing path
    static func getPathDrawPoints(path: EnemyPath, segments: Int = 50) -> [CGPoint] {
        var points: [CGPoint] = []
        for i in 0...segments {
            let progress = CGFloat(i) / CGFloat(segments)
            points.append(path.positionAt(progress: progress))
        }
        return points
    }

    // MARK: - Multi-Path Support

    /// Get least congested path index
    static func getLeastCongestedPath(state: TDGameState) -> Int {
        guard state.paths.count > 1 else { return 0 }

        var enemyCountsPerPath: [Int] = Array(repeating: 0, count: state.paths.count)

        for enemy in state.enemies {
            if !enemy.isDead && !enemy.reachedCore {
                enemyCountsPerPath[enemy.pathIndex] += 1
            }
        }

        return enemyCountsPerPath.enumerated().min(by: { $0.element < $1.element })?.offset ?? 0
    }
}
