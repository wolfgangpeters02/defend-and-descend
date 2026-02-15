import Foundation
import CoreGraphics

// MARK: - Player System

class PlayerSystem {
    /// Update player based on input
    static func update(state: inout GameState, input: InputState, context: FrameContext) {
        // Check invulnerability (use context.timestamp for consistent time base across all systems)
        if state.player.invulnerable && context.timestamp > state.player.invulnerableUntil {
            state.player.invulnerable = false
        }

        // Apply regeneration
        if state.player.regen > 0 {
            state.player.health = min(
                state.player.maxHealth,
                state.player.health + state.player.regen * CGFloat(context.deltaTime)
            )
        }

        // Handle movement input
        var moveX: CGFloat = 0
        var moveY: CGFloat = 0

        if let joystick = input.joystick {
            // Mobile joystick input - more responsive
            let distance = min(1, joystick.distance)
            // Apply curve for responsiveness at lower distances
            let responsiveDistance = pow(distance, BalanceConfig.Input.joystickResponsivenessCurve)
            moveX = cos(joystick.angle) * responsiveDistance
            moveY = sin(joystick.angle) * responsiveDistance
        } else {
            // Keyboard input
            if input.up { moveY -= 1 }
            if input.down { moveY += 1 }
            if input.left { moveX -= 1 }
            if input.right { moveX += 1 }
        }

        // Normalize diagonal movement
        if moveX != 0 && moveY != 0 {
            let length = sqrt(moveX * moveX + moveY * moveY)
            moveX /= length
            moveY /= length
        }

        state.player.moving = moveX != 0 || moveY != 0

        // Apply movement
        if state.player.moving {
            // Effect zone modifiers
            let iceMultiplier = state.player.onIce ? state.player.iceSpeedMultiplier : 1.0
            let speedZoneMultiplier = state.player.inSpeedZone ? state.player.speedZoneMultiplier : 1.0
            let effectiveSpeed = state.player.speed * iceMultiplier * speedZoneMultiplier

            state.player.velocityX = moveX * effectiveSpeed
            state.player.velocityY = moveY * effectiveSpeed

            let oldX = state.player.x
            let oldY = state.player.y
            var newX = state.player.x + state.player.velocityX * CGFloat(context.deltaTime)
            var newY = state.player.y + state.player.velocityY * CGFloat(context.deltaTime)

            // Check obstacle collision and resolve
            if !state.arena.obstacles.isEmpty {
                let resolved = resolveObstacleCollision(
                    oldX: oldX,
                    oldY: oldY,
                    size: state.player.size,
                    newX: newX,
                    newY: newY,
                    obstacles: state.arena.obstacles
                )
                newX = resolved.x
                newY = resolved.y
            }

            state.player.x = newX
            state.player.y = newY

            // Constrain to arena bounds
            state.player.x = max(state.player.size, min(state.arena.width - state.player.size, state.player.x))
            state.player.y = max(state.player.size, min(state.arena.height - state.player.size, state.player.y))

            // Add trail effect
            if RandomUtils.randomBool(probability: BalanceConfig.Visual.trailSpawnChance) {
                state.player.trail.append(TrailEffect(
                    x: state.player.x,
                    y: state.player.y,
                    lifetime: BalanceConfig.Visual.trailLifetime,
                    createdAt: context.timestamp
                ))
            }
        } else {
            state.player.velocityX = 0
            state.player.velocityY = 0
        }

        // Update trail
        state.player.trail = state.player.trail.filter { context.timestamp - $0.createdAt < $0.lifetime }

        // Collision with obstacles
        checkObstacleCollision(player: &state.player, obstacles: state.arena.obstacles)

        // Collision with hazards
        checkHazardCollision(state: &state, context: context)

        // Effect zone checks
        checkEffectZones(state: &state, context: context)

        // Enemy collision (contact damage)
        checkEnemyCollision(state: &state)
    }

    /// Resolve collision with obstacles (returns adjusted position)
    private static func resolveObstacleCollision(
        oldX: CGFloat, oldY: CGFloat, size: CGFloat,
        newX: CGFloat, newY: CGFloat,
        obstacles: [Obstacle]
    ) -> (x: CGFloat, y: CGFloat) {
        var resolvedX = newX
        var resolvedY = newY

        for obs in obstacles {
            // Try X movement first
            if MathUtils.circleRectOverlap(
                circleX: newX, circleY: oldY, radius: size,
                rectX: obs.x, rectY: obs.y, rectWidth: obs.width, rectHeight: obs.height
            ) {
                resolvedX = oldX
            }

            // Try Y movement
            if MathUtils.circleRectOverlap(
                circleX: resolvedX, circleY: newY, radius: size,
                rectX: obs.x, rectY: obs.y, rectWidth: obs.width, rectHeight: obs.height
            ) {
                resolvedY = oldY
            }
        }

        return (resolvedX, resolvedY)
    }

    /// Check collision with obstacles and push player out
    private static func checkObstacleCollision(player: inout Player, obstacles: [Obstacle]) {
        for obs in obstacles {
            // Circle-rectangle collision
            let closestX = MathUtils.clamp(value: player.x, min: obs.x, max: obs.x + obs.width)
            let closestY = MathUtils.clamp(value: player.y, min: obs.y, max: obs.y + obs.height)

            let distX = player.x - closestX
            let distY = player.y - closestY
            let distSq = distX * distX + distY * distY

            if distSq < player.size * player.size {
                // Push player out
                let dist = sqrt(distSq)
                if dist > 0 {
                    let pushX = (distX / dist) * (player.size - dist)
                    let pushY = (distY / dist) * (player.size - dist)
                    player.x += pushX
                    player.y += pushY
                }
            }
        }
    }

    /// Check collision with hazards and deal damage
    private static func checkHazardCollision(state: inout GameState, context: FrameContext) {
        for hazard in state.arena.hazards {
            let closestX = MathUtils.clamp(value: state.player.x, min: hazard.x, max: hazard.x + hazard.width)
            let closestY = MathUtils.clamp(value: state.player.y, min: hazard.y, max: hazard.y + hazard.height)

            let distX = state.player.x - closestX
            let distY = state.player.y - closestY
            let distSq = distX * distX + distY * distY

            if distSq < state.player.size * state.player.size {
                // Deal damage over time
                damagePlayer(state: &state, rawDamage: hazard.damage * CGFloat(context.deltaTime))
            }
        }
    }

    /// Check effect zones (ice, speed, healing)
    private static func checkEffectZones(state: inout GameState, context: FrameContext) {
        // Reset zone states
        state.player.onIce = false
        state.player.inSpeedZone = false

        guard let zones = state.arena.effectZones else { return }

        for zone in zones {
            let inZone = state.player.x >= zone.x &&
                        state.player.x <= zone.x + zone.width &&
                        state.player.y >= zone.y &&
                        state.player.y <= zone.y + zone.height

            if inZone {
                switch zone.type {
                case .ice:
                    state.player.onIce = true
                    state.player.iceSpeedMultiplier = zone.speedMultiplier ?? BalanceConfig.EffectZones.defaultIceSpeedMultiplier
                case .speedBoost:
                    state.player.inSpeedZone = true
                    state.player.speedZoneMultiplier = zone.speedMultiplier ?? BalanceConfig.EffectZones.defaultSpeedZoneMultiplier
                case .healing:
                    if let healPerSec = zone.healPerSecond {
                        state.player.health = min(
                            state.player.maxHealth,
                            state.player.health + healPerSec * CGFloat(context.deltaTime)
                        )
                    }
                case .damage, .slow, .powerZone:
                    break
                }
            }
        }
    }

    /// Check collision with enemies and deal contact damage
    private static func checkEnemyCollision(state: inout GameState) {
        if state.player.invulnerable { return }

        for i in 0..<state.enemies.count {
            if state.enemies[i].isDead { continue }

            let dx = state.player.x - state.enemies[i].x
            let dy = state.player.y - state.enemies[i].y
            let distSq = dx * dx + dy * dy
            let minDist = state.player.size + (state.enemies[i].size ?? BalanceConfig.EnemyDefaults.collisionSize)

            if distSq < minDist * minDist {
                // Cyberboss in ranged mode doesn't deal contact damage
                if state.enemies[i].isBoss,
                   state.activeBossType == .cyberboss,
                   let bossState = state.cyberbossState,
                   bossState.mode == .ranged {
                    continue // Skip contact damage for Cyberboss in ranged mode
                }

                // Deal contact damage
                let damageDealt = state.enemies[i].damage * (1 - state.player.armor)
                damagePlayer(state: &state, rawDamage: state.enemies[i].damage)

                // Thorns: reflect damage back to enemy
                if let thorns = state.player.abilities?.thorns {
                    let thornsDamage = damageDealt * thorns
                    state.enemies[i].health -= thornsDamage
                    if state.enemies[i].health <= 0 {
                        state.enemies[i].isDead = true
                    }
                }

                // Brief invulnerability (use currentFrameTime for consistent time base)
                state.player.invulnerable = true
                state.player.invulnerableUntil = state.currentFrameTime + BalanceConfig.Player.invulnerabilityDuration

                break // Only one enemy hits per frame
            }
        }
    }

    /// Deal damage to player
    static func damagePlayer(state: inout GameState, rawDamage: CGFloat) {
        // Apply armor
        let damage = rawDamage * (1 - state.player.armor)
        state.player.health -= damage
        state.stats.damageTaken += damage

        // Use currentFrameTime for consistent time base (context.timestamp)
        let frameTime = state.currentFrameTime

        // Emit scrolling combat text event for player damage
        let damageEvent = DamageEvent(
            type: .playerDamage,
            amount: Int(damage),
            position: CGPoint(x: state.player.x, y: state.player.y),
            timestamp: frameTime
        )
        state.damageEvents.append(damageEvent)

        // Create hit particle
        state.particles.append(Particle(
            id: RandomUtils.generateId(),
            type: "hit",
            x: state.player.x,
            y: state.player.y,
            lifetime: BalanceConfig.Particles.playerHitParticleLifetime,
            createdAt: frameTime,
            color: "#ff4444",
            size: BalanceConfig.Particles.playerHitParticleSize
        ))

        // Check death
        if state.player.health <= 0 {
            // Phoenix Revive
            if let revives = state.player.abilities?.revive, revives > 0 {
                state.player.abilities?.revive = revives - 1
                state.player.health = state.player.maxHealth
                state.player.invulnerable = true
                state.player.invulnerableUntil = frameTime + BalanceConfig.Player.reviveInvulnerabilityDuration

                // Phoenix particle effect
                for i in 0..<BalanceConfig.Particles.phoenixParticleCount {
                    let angle = (CGFloat.pi * 2 * CGFloat(i)) / CGFloat(BalanceConfig.Particles.phoenixParticleCount)
                    let speed = BalanceConfig.Particles.phoenixParticleBaseSpeed + CGFloat.random(in: 0...BalanceConfig.Particles.phoenixParticleSpeedVariation)
                    state.particles.append(Particle(
                        id: "\(RandomUtils.generateId())-phoenix-\(i)",
                        type: "legendary",
                        x: state.player.x,
                        y: state.player.y,
                        lifetime: BalanceConfig.Particles.phoenixParticleLifetime,
                        createdAt: frameTime,
                        color: "#ff6600",
                        size: BalanceConfig.Particles.phoenixParticleSize,
                        velocity: CGPoint(x: cos(angle) * speed, y: sin(angle) * speed)
                    ))
                }
            } else {
                state.player.health = 0
                state.isGameOver = true
                state.victory = false
            }
        }
    }

    /// Heal player
    static func healPlayer(player: inout Player, amount: CGFloat) {
        player.health = min(player.maxHealth, player.health + amount)
    }
}
