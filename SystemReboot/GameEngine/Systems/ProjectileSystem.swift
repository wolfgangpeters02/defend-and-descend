import Foundation
import CoreGraphics

// MARK: - Projectile System

class ProjectileSystem {

    /// Update all projectiles - movement and collision
    static func update(state: inout GameState, context: FrameContext) {
        var indicesToRemove: [Int] = []

        for i in 0..<state.projectiles.count {
            // Check lifetime
            let createdAt = state.projectiles[i].createdAt ?? context.timestamp
            if context.timestamp - createdAt > state.projectiles[i].lifetime {
                indicesToRemove.append(i)
                continue
            }

            // Homing projectiles
            if state.projectiles[i].isHoming, let targetId = state.projectiles[i].targetId {
                if let target = state.enemies.first(where: { $0.id == targetId && !$0.isDead }) {
                    let dx = target.x - state.projectiles[i].x
                    let dy = target.y - state.projectiles[i].y
                    let dist = sqrt(dx * dx + dy * dy)
                    let speed = state.projectiles[i].speed ?? BalanceConfig.ProjectileSystem.defaultProjectileSpeed

                    if dist > 0 {
                        state.projectiles[i].velocityX = (dx / dist) * speed
                        state.projectiles[i].velocityY = (dy / dist) * speed
                    }
                }
            }

            // Move projectile
            state.projectiles[i].x += state.projectiles[i].velocityX * CGFloat(context.deltaTime)
            state.projectiles[i].y += state.projectiles[i].velocityY * CGFloat(context.deltaTime)

            // Check obstacle collision
            var hitObstacle = false
            let projectileSize = state.projectiles[i].size ?? state.projectiles[i].radius
            for obstacle in state.arena.obstacles {
                if checkObstacleCollision(
                    x: state.projectiles[i].x,
                    y: state.projectiles[i].y,
                    size: projectileSize,
                    obstacle: obstacle
                ) {
                    hitObstacle = true
                    ParticleFactory.createImpactEffect(
                        state: &state,
                        x: state.projectiles[i].x,
                        y: state.projectiles[i].y,
                        weaponType: state.projectiles[i].sourceType ?? "default"
                    )
                    break
                }
            }

            if hitObstacle {
                indicesToRemove.append(i)
                continue
            }

            // Add trail particles
            if state.projectiles[i].trail == true {
                ParticleFactory.createWeaponTrail(
                    state: &state,
                    x: state.projectiles[i].x,
                    y: state.projectiles[i].y,
                    weaponType: state.projectiles[i].sourceType ?? "default"
                )
            }

            // Check collision with enemies using spatial grid (Phase 3: O(n) instead of O(n×m))
            var hit = false
            let searchRadius = projectileSize + BalanceConfig.ProjectileSystem.searchRadiusBuffer

            // Use spatial grid if available, otherwise fall back to brute force
            let candidates: [Enemy]
            if let grid = state.enemyGrid {
                candidates = grid.query(x: state.projectiles[i].x, y: state.projectiles[i].y, radius: searchRadius)
            } else {
                candidates = state.enemies
            }

            // Enemy projectiles hit the player, not enemies
            if state.projectiles[i].isEnemyProjectile {
                // Check collision with player
                if !state.player.invulnerable || state.player.invulnerableUntil < context.timestamp {
                    let dx = state.player.x - state.projectiles[i].x
                    let dy = state.player.y - state.projectiles[i].y
                    let dist = sqrt(dx * dx + dy * dy)
                    let playerSize = state.player.size

                    if dist < playerSize + projectileSize {
                        // Deal damage to player
                        PlayerSystem.damagePlayer(state: &state, rawDamage: state.projectiles[i].damage)

                        // Impact effect
                        ParticleFactory.createImpactEffect(
                            state: &state,
                            x: state.projectiles[i].x,
                            y: state.projectiles[i].y,
                            weaponType: "enemy"
                        )

                        // Brief invulnerability after hit
                        state.player.invulnerable = true
                        state.player.invulnerableUntil = context.timestamp + BalanceConfig.Player.invulnerabilityDuration

                        indicesToRemove.append(i)
                    }
                }
                continue
            }

            // Pylons are now Enemy objects (type: "void_pylon") so they're hit through normal
            // enemy collision below. EnemySystem.damageEnemy syncs damage to VoidHarbingerState.

            for enemy in candidates {
                if enemy.isDead { continue }

                // Skip invulnerable boss (VoidHarbinger Phase 2) - show IMMUNE text and let projectiles pass through to hit pylons
                if enemy.isBoss {
                    if let bossState = state.voidHarbingerState, bossState.isInvulnerable {
                        // Check if projectile would hit boss - show IMMUNE text
                        let dx = enemy.x - state.projectiles[i].x
                        let dy = enemy.y - state.projectiles[i].y
                        let dist = sqrt(dx * dx + dy * dy)
                        let enemySize = enemy.size ?? BalanceConfig.EnemyDefaults.collisionSize

                        if dist < enemySize + projectileSize {
                            // Emit IMMUNE scrolling combat text (throttle to avoid spam)
                            let immuneEvent = DamageEvent(
                                type: .immune,
                                amount: 0,
                                position: CGPoint(x: enemy.x, y: enemy.y),
                                timestamp: state.startTime + state.timeElapsed
                            )
                            state.damageEvents.append(immuneEvent)
                        }
                        continue
                    }
                }

                // Find enemy index for damage handling
                guard let j = state.enemies.firstIndex(where: { $0.id == enemy.id }) else { continue }

                let dx = enemy.x - state.projectiles[i].x
                let dy = enemy.y - state.projectiles[i].y
                let dist = sqrt(dx * dx + dy * dy)
                let enemySize = enemy.size ?? BalanceConfig.EnemyDefaults.collisionSize

                if dist < enemySize + projectileSize {
                    handleProjectileHit(state: &state, projectileIndex: i, enemyIndex: j)
                    hit = true

                    // Handle pierce
                    if var pierce = state.projectiles[i].pierceRemaining {
                        pierce -= 1
                        state.projectiles[i].pierceRemaining = pierce
                        if pierce <= 0 {
                            break
                        } else {
                            hit = false // Continue to next enemy
                        }
                    } else {
                        break
                    }
                }
            }

            if hit {
                indicesToRemove.append(i)
                continue
            }
        }

        // Remove projectiles (in reverse order to maintain indices)
        for index in indicesToRemove.sorted().reversed() {
            if index < state.projectiles.count {
                state.projectiles.remove(at: index)
            }
        }
    }

    /// Check collision with obstacle
    private static func checkObstacleCollision(
        x: CGFloat,
        y: CGFloat,
        size: CGFloat,
        obstacle: Obstacle
    ) -> Bool {
        return MathUtils.circleRectOverlap(
            circleX: x, circleY: y, radius: size,
            rectX: obstacle.x, rectY: obstacle.y,
            rectWidth: obstacle.width, rectHeight: obstacle.height
        )
    }

    /// Handle projectile hitting an enemy
    private static func handleProjectileHit(
        state: inout GameState,
        projectileIndex: Int,
        enemyIndex: Int
    ) {
        let proj = state.projectiles[projectileIndex]
        let enemy = state.enemies[enemyIndex]

        // Calculate damage with critical hit chance
        let isCritical = Double.random(in: 0...1) < BalanceConfig.ProjectileSystem.criticalHitChance
        let damage = isCritical ? proj.damage * BalanceConfig.ProjectileSystem.criticalHitMultiplier : proj.damage

        // Deal damage (with critical hit indicator for scrolling combat text)
        EnemySystem.damageEnemy(state: &state, enemyIndex: enemyIndex, damage: damage, isCritical: isCritical)

        // Impact effect
        ParticleFactory.createImpactEffect(
            state: &state,
            x: proj.x,
            y: proj.y,
            weaponType: proj.sourceType ?? "default"
        )

        // Lifesteal
        if let lifesteal = state.player.abilities?.lifesteal {
            let healAmount = proj.damage * lifesteal
            PlayerSystem.healPlayer(player: &state.player, amount: healAmount)

            // Emit healing event for scrolling combat text
            let healEvent = DamageEvent(
                type: .healing,
                amount: Int(healAmount),
                position: CGPoint(x: state.player.x, y: state.player.y),
                timestamp: state.startTime + state.timeElapsed
            )
            state.damageEvents.append(healEvent)

            // Healing particle (use state time instead of Date())
            state.particles.append(Particle(
                id: RandomUtils.generateId(),
                type: "data",
                x: state.player.x,
                y: state.player.y - 20,
                lifetime: 0.5,
                createdAt: state.startTime + state.timeElapsed,
                color: "#00ff00",
                size: 6,
                velocity: CGPoint(x: 0, y: -50)
            ))
        }

        // Apply slow
        if let slow = proj.slow, let slowDuration = proj.slowDuration {
            EnemySystem.slowEnemy(state: &state, enemyIndex: enemyIndex, slowAmount: slow, duration: slowDuration)
        }

        // Splash damage
        if let splash = proj.splash {
            for k in 0..<state.enemies.count {
                if state.enemies[k].id == enemy.id || state.enemies[k].isDead { continue }

                let dx = state.enemies[k].x - enemy.x
                let dy = state.enemies[k].y - enemy.y
                let dist = sqrt(dx * dx + dy * dy)

                if dist <= splash {
                    let splashDamage = proj.damage * BalanceConfig.ProjectileSystem.splashDamageMultiplier
                    EnemySystem.damageEnemy(state: &state, enemyIndex: k, damage: splashDamage)
                }
            }

            // Explosion effect
            ParticleFactory.createExplosion(
                state: &state,
                x: enemy.x,
                y: enemy.y,
                color: proj.color,
                count: Int(splash / 2),
                size: splash / 3
            )
        }
    }
}
