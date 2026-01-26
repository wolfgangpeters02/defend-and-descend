import Foundation
import CoreGraphics

// MARK: - Projectile System

class ProjectileSystem {

    /// Update all projectiles - movement and collision
    static func update(state: inout GameState, deltaTime: TimeInterval) {
        let now = Date().timeIntervalSince1970

        var indicesToRemove: [Int] = []

        for i in 0..<state.projectiles.count {
            // Check lifetime
            let createdAt = state.projectiles[i].createdAt ?? now
            if now - createdAt > state.projectiles[i].lifetime {
                indicesToRemove.append(i)
                continue
            }

            // Homing projectiles
            if state.projectiles[i].isHoming, let targetId = state.projectiles[i].targetId {
                if let target = state.enemies.first(where: { $0.id == targetId && !$0.isDead }) {
                    let dx = target.x - state.projectiles[i].x
                    let dy = target.y - state.projectiles[i].y
                    let dist = sqrt(dx * dx + dy * dy)
                    let speed = state.projectiles[i].speed ?? 300

                    if dist > 0 {
                        state.projectiles[i].velocityX = (dx / dist) * speed
                        state.projectiles[i].velocityY = (dy / dist) * speed
                    }
                }
            }

            // Move projectile
            state.projectiles[i].x += state.projectiles[i].velocityX * CGFloat(deltaTime)
            state.projectiles[i].y += state.projectiles[i].velocityY * CGFloat(deltaTime)

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

            // Check collision with enemies
            var hit = false
            for j in 0..<state.enemies.count {
                if state.enemies[j].isDead { continue }

                let dx = state.enemies[j].x - state.projectiles[i].x
                let dy = state.enemies[j].y - state.projectiles[i].y
                let dist = sqrt(dx * dx + dy * dy)
                let enemySize = state.enemies[j].size ?? 20

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

        // Calculate damage (15% crit chance)
        let isCritical = Double.random(in: 0...1) < 0.15
        let damage = isCritical ? proj.damage * 2 : proj.damage

        // Deal damage
        EnemySystem.damageEnemy(state: &state, enemyIndex: enemyIndex, damage: damage)

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

            // Healing particle
            state.particles.append(Particle(
                id: RandomUtils.generateId(),
                type: "coin",
                x: state.player.x,
                y: state.player.y - 20,
                lifetime: 0.5,
                createdAt: Date().timeIntervalSince1970,
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
                    let splashDamage = proj.damage * 0.5
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
