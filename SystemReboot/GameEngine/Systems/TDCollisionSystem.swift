import Foundation
import CoreGraphics

// MARK: - TD Collision System
// Extracted from TDGameScene (Step 4.6)
// Pure geometry + math for swept-sphere collision detection, splash damage, and
// projectile-vs-enemy resolution. Zero rendering dependencies.

struct TDCollisionSystem {

    // MARK: - Visual Event (output for scene to render)

    /// Events produced by collision processing that require visual effects.
    /// The scene converts game-space positions and triggers particle/haptic feedback.
    struct VisualEvent {
        enum Kind {
            case impact(color: String)
            case kill(color: String, hashValue: Int, isBoss: Bool)
        }
        let position: CGPoint  // Game-space coordinates
        let kind: Kind
    }

    // MARK: - Collision Processing

    /// Swept collision detection between projectiles and enemies.
    /// Mutates state (damage, stats, hash, death flags) and returns visual events for the scene.
    static func processCollisions(
        state: inout TDGameState,
        prevPositions: [String: CGPoint]
    ) -> [VisualEvent] {
        var events: [VisualEvent] = []

        // Precompute enemy ID → index map (O(n) once, replaces O(n) filter per projectile)
        var enemyIndexMap: [String: Int] = [:]
        enemyIndexMap.reserveCapacity(state.enemies.count)
        for i in 0..<state.enemies.count {
            enemyIndexMap[state.enemies[i].id] = i
        }

        for projIndex in (0..<state.projectiles.count).reversed() {
            var proj = state.projectiles[projIndex]

            // Skip enemy projectiles
            if proj.isEnemyProjectile { continue }

            // Get previous position for swept collision (fallback to current if first frame)
            let prevPos = prevPositions[proj.id] ?? CGPoint(x: proj.x, y: proj.y)
            let currPos = CGPoint(x: proj.x, y: proj.y)

            // Use spatial grid to narrow enemy candidates (O(1) cell lookup vs O(n) brute force)
            let searchRadius = max(proj.radius + 30, hypot(currPos.x - prevPos.x, currPos.y - prevPos.y) + 30)
            let midX = (prevPos.x + currPos.x) * 0.5
            let midY = (prevPos.y + currPos.y) * 0.5

            let candidateIndices: [Int]
            if let grid = state.enemyGrid {
                let candidates = grid.query(x: midX, y: midY, radius: searchRadius)
                candidateIndices = candidates.compactMap { enemyIndexMap[$0.id] }
            } else {
                candidateIndices = Array(state.enemies.indices)
            }

            var projConsumed = false

            for enemyIndex in candidateIndices {
                var enemy = state.enemies[enemyIndex]
                if enemy.isDead || enemy.reachedCore { continue }

                // Swept collision: check if projectile path intersects enemy circle
                let hitRadius = proj.radius + (enemy.size / 2)
                let enemyCenter = CGPoint(x: enemy.x, y: enemy.y)

                let collision = lineIntersectsCircle(
                    lineStart: prevPos,
                    lineEnd: currPos,
                    circleCenter: enemyCenter,
                    circleRadius: hitRadius
                )

                if collision && !proj.hitEnemies.contains(enemy.id) {
                    // Apply damage
                    enemy.health -= proj.damage
                    state.stats.damageDealt += proj.damage

                    // Emit scrolling combat text event
                    let damageEvent = DamageEvent(
                        type: .damage,
                        amount: Int(proj.damage),
                        position: CGPoint(x: enemy.x, y: enemy.y),
                        timestamp: state.gameTime
                    )
                    state.damageEvents.append(damageEvent)

                    // Apply slow
                    if let slow = proj.slow, let duration = proj.slowDuration {
                        enemy.applySlow(amount: slow, duration: duration, currentTime: state.gameTime)
                    }

                    // Mark as hit
                    proj.hitEnemies.append(enemy.id)

                    // Visual: impact sparks
                    events.append(VisualEvent(
                        position: CGPoint(x: enemy.x, y: enemy.y),
                        kind: .impact(color: proj.color)
                    ))
                    AudioManager.shared.play(.enemyHit)

                    // Splash damage
                    if let splash = proj.splash, splash > 0 {
                        applySplashDamage(
                            state: &state,
                            center: CGPoint(x: enemy.x, y: enemy.y),
                            radius: splash,
                            damage: proj.damage * BalanceConfig.ProjectileSystem.splashDamageMultiplier,
                            slow: proj.slow,
                            slowDuration: proj.slowDuration,
                            enemyIndexMap: enemyIndexMap
                        )
                    }

                    // Check enemy death
                    if enemy.health <= 0 {
                        enemy.isDead = true
                        let actualHash = state.addHash(enemy.hashValue)
                        state.stats.hashEarned += actualHash
                        state.stats.enemiesKilled += 1
                        state.virusesKilledTotal += 1  // For passive Data generation
                        state.waveEnemiesRemaining -= 1

                        // Visual: death particles + hash floaties + boss effects
                        events.append(VisualEvent(
                            position: CGPoint(x: enemy.x, y: enemy.y),
                            kind: .kill(color: enemy.color, hashValue: enemy.hashValue, isBoss: enemy.isBoss)
                        ))
                        AudioManager.shared.play(.enemyDeath)
                    }

                    state.enemies[enemyIndex] = enemy

                    // Handle pierce
                    if proj.piercing > 0 {
                        proj.piercing -= 1
                    } else {
                        projConsumed = true
                        break
                    }
                }
            }

            // Swap-remove consumed projectiles (O(1) vs O(n) shift)
            if projConsumed {
                state.projectiles.swapAt(projIndex, state.projectiles.count - 1)
                state.projectiles.removeLast()
            } else {
                state.projectiles[projIndex] = proj
            }
        }

        return events
    }

    // MARK: - Geometry

    /// Check if a line segment intersects a circle (swept sphere collision).
    /// Prevents fast-moving projectiles from tunneling through enemies.
    static func lineIntersectsCircle(
        lineStart: CGPoint,
        lineEnd: CGPoint,
        circleCenter: CGPoint,
        circleRadius: CGFloat
    ) -> Bool {
        // Vector from line start to line end
        let d = CGPoint(x: lineEnd.x - lineStart.x, y: lineEnd.y - lineStart.y)
        // Vector from line start to circle center
        let f = CGPoint(x: lineStart.x - circleCenter.x, y: lineStart.y - circleCenter.y)

        let a = d.x * d.x + d.y * d.y
        let b = 2 * (f.x * d.x + f.y * d.y)
        let c = f.x * f.x + f.y * f.y - circleRadius * circleRadius

        var discriminant = b * b - 4 * a * c

        // No intersection at all
        if discriminant < 0 {
            return false
        }

        discriminant = sqrt(discriminant)

        // Check if intersection is within the line segment (t between 0 and 1)
        let t1 = (-b - discriminant) / (2 * a)
        let t2 = (-b + discriminant) / (2 * a)

        // Either intersection point is on the segment
        if t1 >= 0 && t1 <= 1 {
            return true
        }
        if t2 >= 0 && t2 <= 1 {
            return true
        }

        // Also check if either endpoint is inside the circle (segment fully inside)
        let startDist = sqrt(f.x * f.x + f.y * f.y)
        let endDx = lineEnd.x - circleCenter.x
        let endDy = lineEnd.y - circleCenter.y
        let endDist = sqrt(endDx * endDx + endDy * endDy)

        return startDist <= circleRadius || endDist <= circleRadius
    }

    // MARK: - Splash Damage

    /// Apply area-of-effect damage around a center point.
    /// Damages all living enemies within radius, applying slow if present.
    static func applySplashDamage(
        state: inout TDGameState,
        center: CGPoint,
        radius: CGFloat,
        damage: CGFloat,
        slow: CGFloat?,
        slowDuration: TimeInterval?,
        enemyIndexMap: [String: Int]? = nil
    ) {
        // Use spatial grid to narrow candidates
        let candidateIndices: [Int]
        if let grid = state.enemyGrid {
            let candidates = grid.query(x: center.x, y: center.y, radius: radius)
            if let indexMap = enemyIndexMap {
                candidateIndices = candidates.compactMap { indexMap[$0.id] }
            } else {
                let candidateIds = Set(candidates.map { $0.id })
                candidateIndices = state.enemies.indices.filter { candidateIds.contains(state.enemies[$0].id) }
            }
        } else {
            candidateIndices = Array(state.enemies.indices)
        }

        for i in candidateIndices {
            var enemy = state.enemies[i]
            if enemy.isDead || enemy.reachedCore { continue }

            let dx = enemy.x - center.x
            let dy = enemy.y - center.y
            let distance = sqrt(dx * dx + dy * dy)

            if distance < radius {
                enemy.health -= damage
                state.stats.damageDealt += damage

                // Emit splash damage event
                let splashEvent = DamageEvent(
                    type: .damage,
                    amount: Int(damage),
                    position: CGPoint(x: enemy.x, y: enemy.y),
                    timestamp: state.gameTime
                )
                state.damageEvents.append(splashEvent)

                if let slow = slow, let duration = slowDuration {
                    enemy.applySlow(amount: slow, duration: duration, currentTime: state.gameTime)
                }

                if enemy.health <= 0 {
                    enemy.isDead = true
                    let actualHash = state.addHash(enemy.hashValue)
                    state.stats.hashEarned += actualHash
                    state.stats.enemiesKilled += 1
                    state.virusesKilledTotal += 1
                    state.waveEnemiesRemaining -= 1
                }

                state.enemies[i] = enemy
            }
        }
    }
}
