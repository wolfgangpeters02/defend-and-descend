import Foundation
import CoreGraphics

// MARK: - Enemy System

class EnemySystem {

    // MARK: - Enemy Spawning

    /// Spawn a new enemy
    static func spawnEnemy(
        state: inout GameState,
        type: String,
        config: EnemyConfig,
        spawnOptions: SpawnOptions? = nil
    ) -> Enemy {
        let arena = state.arena
        let player = state.player
        let enemySize = CGFloat(config.size)

        // Find a valid spawn position
        let spawnPos = findValidSpawnPosition(
            state: state,
            size: enemySize,
            preferredX: spawnOptions?.x,
            preferredY: spawnOptions?.y
        )

        // Apply time-based scaling
        let minutesElapsed = state.timeElapsed / 60
        let hpScaling = 1 + (minutesElapsed * BalanceConfig.EnemyScaling.hpScalingPerMinute)
        let damageScaling = 1 + (minutesElapsed * BalanceConfig.EnemyScaling.damageScalingPerMinute)

        let enemyHealth = CGFloat(config.health) * CGFloat(hpScaling)
        var enemySpeed = CGFloat(config.speed)
        var enemyDamage = CGFloat(config.damage) * CGFloat(damageScaling)

        // Apply arena global modifiers
        if let modifier = arena.globalModifier {
            if let speedMult = modifier.enemySpeedMultiplier {
                enemySpeed *= speedMult
            }
            if let damageMult = modifier.enemyDamageMultiplier {
                enemyDamage *= damageMult
            }
        }

        return Enemy(
            id: RandomUtils.generateId(),
            type: type,
            x: spawnPos.x,
            y: spawnPos.y,
            health: enemyHealth,
            maxHealth: enemyHealth,
            damage: enemyDamage,
            speed: enemySpeed,
            xpValue: config.hashValue, // Use hashValue as XP
            color: config.color,
            velocityX: 0,
            velocityY: 0,
            currentSpeed: enemySpeed,
            hashValue: config.hashValue,
            targetX: player.x,
            targetY: player.y,
            size: CGFloat(config.size),
            isSlowed: false,
            slowAmount: 0,
            slowEndTime: 0,
            isDead: false,
            isBoss: config.isBoss ?? false,
            bossPhase: config.isBoss == true ? 1 : nil,
            inactive: spawnOptions?.inactive ?? false,
            activationRadius: spawnOptions?.activationRadius ?? BalanceConfig.Spawn.defaultActivationRadius,
            shape: config.shape
        )
    }

    /// Find a valid spawn position
    private static func findValidSpawnPosition(
        state: GameState,
        size: CGFloat,
        preferredX: CGFloat?,
        preferredY: CGFloat?
    ) -> (x: CGFloat, y: CGFloat) {
        let arena = state.arena
        let maxAttempts = 20

        for attempt in 0..<maxAttempts {
            var testX: CGFloat
            var testY: CGFloat

            if attempt == 0, let x = preferredX, let y = preferredY {
                testX = x
                testY = y
            } else {
                // Arena mode - spawn at edges
                let edge = Int.random(in: 0...3)
                let margin = BalanceConfig.Spawn.edgeMargin

                switch edge {
                case 0: // Top
                    testX = margin + CGFloat.random(in: 0...(arena.width - margin * 2))
                    testY = margin
                case 1: // Right
                    testX = arena.width - margin
                    testY = margin + CGFloat.random(in: 0...(arena.height - margin * 2))
                case 2: // Bottom
                    testX = margin + CGFloat.random(in: 0...(arena.width - margin * 2))
                    testY = arena.height - margin
                default: // Left
                    testX = margin
                    testY = margin + CGFloat.random(in: 0...(arena.height - margin * 2))
                }
            }

            // Check obstacle collision
            if !checkObstacleCollisionAtPosition(x: testX, y: testY, size: size, obstacles: arena.obstacles) {
                return (testX, testY)
            }
        }

        // Fallback to center
        return (arena.width / 2, arena.height / 2)
    }

    private static func checkObstacleCollisionAtPosition(
        x: CGFloat,
        y: CGFloat,
        size: CGFloat,
        obstacles: [Obstacle]
    ) -> Bool {
        for obstacle in obstacles {
            if MathUtils.circleRectOverlap(
                circleX: x, circleY: y, radius: size,
                rectX: obstacle.x, rectY: obstacle.y,
                rectWidth: obstacle.width, rectHeight: obstacle.height
            ) {
                return true
            }
        }
        return false
    }

    // MARK: - Update

    /// Update all enemies
    static func update(state: inout GameState, context: FrameContext) {
        let player = state.player

        for i in 0..<state.enemies.count {
            if state.enemies[i].isDead { continue }

            // Skip bosses with custom AI - they handle their own movement
            if state.enemies[i].isBoss && state.activeBossType != nil {
                continue
            }

            // Skip pylons - they don't move (but can be damaged)
            if state.enemies[i].type == "void_pylon" {
                continue
            }

            // Proximity activation
            if state.enemies[i].inactive == true {
                let dx = player.x - state.enemies[i].x
                let dy = player.y - state.enemies[i].y
                let distanceToPlayer = sqrt(dx * dx + dy * dy)
                let activationRadius = state.enemies[i].activationRadius ?? BalanceConfig.Spawn.defaultActivationRadius

                if distanceToPlayer < activationRadius {
                    state.enemies[i].inactive = false
                } else {
                    continue // Skip movement for inactive enemies
                }
            }

            // Update slow status
            if state.enemies[i].isSlowed && context.timestamp > state.enemies[i].slowEndTime {
                state.enemies[i].isSlowed = false
                state.enemies[i].slowAmount = 0
                state.enemies[i].currentSpeed = state.enemies[i].speed
            }

            // Boss phase system
            if state.enemies[i].isBoss, let phase = state.enemies[i].bossPhase {
                let hpPercent = state.enemies[i].health / state.enemies[i].maxHealth
                var newPhase = phase

                if hpPercent <= BalanceConfig.BossPhaseScaling.phase4Threshold && phase < 4 {
                    newPhase = 4
                } else if hpPercent <= BalanceConfig.BossPhaseScaling.phase3Threshold && phase < 3 {
                    newPhase = 3
                } else if hpPercent <= BalanceConfig.BossPhaseScaling.phase2Threshold && phase < 2 {
                    newPhase = 2
                }

                if newPhase != phase {
                    state.enemies[i].bossPhase = newPhase
                    state.enemies[i].speed *= BalanceConfig.BossPhaseScaling.phaseSpeedMultiplier
                    state.enemies[i].currentSpeed = state.enemies[i].speed
                    state.enemies[i].damage *= BalanceConfig.BossPhaseScaling.phaseDamageMultiplier

                    // Rage particles
                    ParticleFactory.createExplosion(
                        state: &state,
                        x: state.enemies[i].x,
                        y: state.enemies[i].y,
                        color: "#ff0000",
                        count: BalanceConfig.Particles.rageParticleCount,
                        size: BalanceConfig.Particles.rageParticleSize
                    )
                }
            }

            // Update target to player position
            state.enemies[i].targetX = player.x
            state.enemies[i].targetY = player.y

            // Calculate direction to player
            let targetX = state.enemies[i].targetX ?? player.x
            let targetY = state.enemies[i].targetY ?? player.y
            let dx = targetX - state.enemies[i].x
            let dy = targetY - state.enemies[i].y
            let dist = sqrt(dx * dx + dy * dy)
            let enemySize = state.enemies[i].size ?? BalanceConfig.EnemyDefaults.collisionSize

            if dist > enemySize + player.size {
                let speed = state.enemies[i].currentSpeed ?? state.enemies[i].speed
                let moveX = (dx / dist) * speed * CGFloat(context.deltaTime)
                let moveY = (dy / dist) * speed * CGFloat(context.deltaTime)

                var newX = state.enemies[i].x + moveX
                var newY = state.enemies[i].y + moveY

                // Obstacle collision
                if !state.arena.obstacles.isEmpty {
                    let resolved = resolveObstacleCollision(
                        oldX: state.enemies[i].x,
                        oldY: state.enemies[i].y,
                        size: enemySize,
                        newX: newX,
                        newY: newY,
                        obstacles: state.arena.obstacles
                    )
                    newX = resolved.x
                    newY = resolved.y
                }

                state.enemies[i].x = newX
                state.enemies[i].y = newY
            }
        }

        // Remove dead enemies (compact in-place, avoids allocating new array)
        var writeIndex = 0
        for i in 0..<state.enemies.count {
            if !state.enemies[i].isDead {
                state.enemies[writeIndex] = state.enemies[i]
                writeIndex += 1
            }
        }
        state.enemies.removeSubrange(writeIndex..<state.enemies.count)
    }

    /// Resolve obstacle collision
    private static func resolveObstacleCollision(
        oldX: CGFloat, oldY: CGFloat, size: CGFloat,
        newX: CGFloat, newY: CGFloat,
        obstacles: [Obstacle]
    ) -> (x: CGFloat, y: CGFloat) {
        var resolvedX = newX
        var resolvedY = newY

        for obs in obstacles {
            if MathUtils.circleRectOverlap(
                circleX: newX, circleY: oldY, radius: size,
                rectX: obs.x, rectY: obs.y, rectWidth: obs.width, rectHeight: obs.height
            ) {
                resolvedX = oldX
            }
            if MathUtils.circleRectOverlap(
                circleX: resolvedX, circleY: newY, radius: size,
                rectX: obs.x, rectY: obs.y, rectWidth: obs.width, rectHeight: obs.height
            ) {
                resolvedY = oldY
            }
        }

        return (resolvedX, resolvedY)
    }

    // MARK: - Damage

    /// Damage an enemy
    static func damageEnemy(state: inout GameState, enemyIndex: Int, damage: CGFloat, isCritical: Bool = false, damageType: DamageEventType = .damage) {
        guard enemyIndex < state.enemies.count else { return }

        let enemy = state.enemies[enemyIndex]
        state.enemies[enemyIndex].health -= damage
        state.stats.damageDealt += damage

        // Sync pylon damage with VoidHarbinger state (keeps health bars in sync)
        if enemy.type == "void_pylon", let pylonId = enemy.pylonId {
            if var bossState = state.voidHarbingerState {
                VoidHarbingerAI.damagePylon(pylonId: pylonId, damage: damage, bossState: &bossState)
                state.voidHarbingerState = bossState
            }
        }

        // Emit scrolling combat text event
        let eventType: DamageEventType = isCritical ? .critical : damageType
        let damageEvent = DamageEvent(
            type: eventType,
            amount: Int(damage),
            position: CGPoint(x: enemy.x, y: enemy.y),
            timestamp: state.startTime + state.timeElapsed
        )
        state.damageEvents.append(damageEvent)

        // Hit particle (use state time instead of Date())
        let enemySize = state.enemies[enemyIndex].size ?? BalanceConfig.EnemyDefaults.collisionSize
        state.particles.append(Particle(
            id: RandomUtils.generateId(),
            type: "hit",
            x: state.enemies[enemyIndex].x,
            y: state.enemies[enemyIndex].y,
            lifetime: BalanceConfig.Particles.hitParticleLifetime,
            createdAt: state.startTime + state.timeElapsed,
            color: state.enemies[enemyIndex].color,
            size: enemySize / 2
        ))

        // Check death
        if state.enemies[enemyIndex].health <= 0 {
            killEnemy(state: &state, enemyIndex: enemyIndex)
        }
    }

    /// Kill an enemy
    private static func killEnemy(state: inout GameState, enemyIndex: Int) {
        let enemy = state.enemies[enemyIndex]
        let enemySize = enemy.size ?? BalanceConfig.EnemyDefaults.collisionSize
        state.enemies[enemyIndex].isDead = true
        state.stats.enemiesKilled += 1

        // Sync pylon destruction with VoidHarbinger state
        if enemy.type == "void_pylon", let pylonId = enemy.pylonId {
            if var bossState = state.voidHarbingerState {
                VoidHarbingerAI.damagePylon(pylonId: pylonId, damage: 99999, bossState: &bossState)
                state.voidHarbingerState = bossState
            }
        }

        // Death explosion
        ParticleFactory.createExplosion(
            state: &state,
            x: enemy.x,
            y: enemy.y,
            color: enemy.color,
            count: enemy.isBoss ? BalanceConfig.Particles.deathParticleCountBoss : BalanceConfig.Particles.deathParticleCountNormal,
            size: enemySize * (enemy.isBoss ? 1.5 : 1.0)
        )

        // Blood splatter
        ParticleFactory.createBloodParticles(
            state: &state,
            x: enemy.x,
            y: enemy.y,
            count: enemy.isBoss ? BalanceConfig.Particles.bloodParticleCountBoss : BalanceConfig.Particles.bloodParticleCountNormal
        )

        // Drop Hash pickup
        PickupSystem.dropHash(state: &state, x: enemy.x, y: enemy.y, value: enemy.hashValue ?? BalanceConfig.EnemyDefaults.hashValue)

        // Explosion on kill ability
        if let explosionRadius = state.player.abilities?.explosionOnKill {
            ParticleFactory.createExplosion(
                state: &state,
                x: enemy.x,
                y: enemy.y,
                color: "#ff6600",
                count: BalanceConfig.Abilities.explosionParticleCount,
                size: explosionRadius / 3
            )

            // Damage nearby enemies
            for i in 0..<state.enemies.count {
                if state.enemies[i].id == enemy.id || state.enemies[i].isDead { continue }

                let dx = state.enemies[i].x - enemy.x
                let dy = state.enemies[i].y - enemy.y
                let dist = sqrt(dx * dx + dy * dy)

                if dist <= explosionRadius {
                    damageEnemy(state: &state, enemyIndex: i, damage: BalanceConfig.Abilities.explosionOnKillDamage)
                }
            }
        }
    }

    /// Apply slow effect to enemy
    static func slowEnemy(state: inout GameState, enemyIndex: Int, slowAmount: CGFloat, duration: TimeInterval) {
        guard enemyIndex < state.enemies.count else { return }

        let currentTime = state.startTime + state.timeElapsed
        state.enemies[enemyIndex].isSlowed = true
        state.enemies[enemyIndex].slowAmount = max(state.enemies[enemyIndex].slowAmount, slowAmount)
        state.enemies[enemyIndex].slowEndTime = max(
            state.enemies[enemyIndex].slowEndTime,
            currentTime + duration
        )
        state.enemies[enemyIndex].currentSpeed = state.enemies[enemyIndex].speed * (1 - state.enemies[enemyIndex].slowAmount)
    }
}

// MARK: - Spawn Options

struct SpawnOptions {
    var x: CGFloat?
    var y: CGFloat?
    var inactive: Bool?
    var activationRadius: CGFloat?
}
