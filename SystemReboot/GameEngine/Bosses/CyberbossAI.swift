import Foundation
import CoreGraphics

// MARK: - Cyberboss AI

/// 4-Phase Heist Boss with mode switching, minions, damage puddles, and laser beams
class CyberbossAI {

    // State types defined in BossStates.swift

    // MARK: - Initialization

    static func createInitialState() -> CyberbossState {
        return CyberbossState()
    }

    // MARK: - Main Update

    static func update(
        boss: inout Enemy,
        bossState: inout CyberbossState,
        gameState: inout GameState,
        deltaTime: TimeInterval
    ) {
        // Determine phase based on health
        let healthPercent = boss.health / boss.maxHealth

        if healthPercent <= BalanceConfig.Cyberboss.phase4Threshold {
            if bossState.phase != 4 {
                enterPhase4(bossState: &bossState, boss: boss)
            }
            bossState.phase = 4
        } else if healthPercent <= BalanceConfig.Cyberboss.phase3Threshold {
            if bossState.phase != 3 {
                enterPhase3(bossState: &bossState, boss: boss)
            }
            bossState.phase = 3
        } else if healthPercent <= BalanceConfig.Cyberboss.phase2Threshold {
            if bossState.phase != 2 {
                enterPhase2(bossState: &bossState)
            }
            bossState.phase = 2
        }

        // Update based on current phase
        switch bossState.phase {
        case 1:
            updatePhase1(boss: &boss, bossState: &bossState, gameState: &gameState, deltaTime: deltaTime)
        case 2:
            updatePhase2(boss: &boss, bossState: &bossState, gameState: &gameState, deltaTime: deltaTime)
        case 3:
            updatePhase3(boss: &boss, bossState: &bossState, gameState: &gameState, deltaTime: deltaTime)
        case 4:
            updatePhase4(boss: &boss, bossState: &bossState, gameState: &gameState, deltaTime: deltaTime)
        default:
            break
        }

        // Apply movement with collision checking and obstacle destruction
        applyMovement(boss: &boss, bossState: bossState, gameState: &gameState, deltaTime: deltaTime)

        // Update damage puddles
        updateDamagePuddles(bossState: &bossState, gameState: &gameState, deltaTime: deltaTime)

        // Update laser beams
        updateLaserBeams(bossState: &bossState, boss: boss, gameState: &gameState, deltaTime: deltaTime)
    }

    // MARK: - Movement Application

    /// Melee damage per second dealt to obstacles and player when boss is in melee mode
    private static var meleeDPS: CGFloat { BalanceConfig.Cyberboss.meleeDPS }

    private static func applyMovement(
        boss: inout Enemy,
        bossState: CyberbossState,
        gameState: inout GameState,
        deltaTime: TimeInterval
    ) {
        // Calculate new position from velocity
        let moveX = boss.velocityX * CGFloat(deltaTime)
        let moveY = boss.velocityY * CGFloat(deltaTime)

        var newX = boss.x + moveX
        var newY = boss.y + moveY

        let bossSize = boss.size ?? BalanceConfig.EnemyDefaults.bossSize
        let meleeRange = bossSize + BalanceConfig.Cyberboss.meleeRangeAoE // AoE melee range around boss
        let isMeleeMode = bossState.mode == .melee && bossState.phase <= 2

        // In melee mode, deal AoE damage to obstacles and push through them
        if isMeleeMode {
            let meleeDamage = meleeDPS * CGFloat(deltaTime)

            for i in 0..<gameState.arena.obstacles.count {
                let obstacle = gameState.arena.obstacles[i]

                // Check if obstacle is in melee range
                let obstacleCenterX = obstacle.x + obstacle.width / 2
                let obstacleCenterY = obstacle.y + obstacle.height / 2
                let dx = obstacleCenterX - boss.x
                let dy = obstacleCenterY - boss.y
                let distToObstacle = sqrt(dx * dx + dy * dy)

                if distToObstacle < meleeRange + max(obstacle.width, obstacle.height) / 2 {
                    // Damage destructible obstacles
                    if gameState.arena.obstacles[i].isDestructible,
                       var health = gameState.arena.obstacles[i].health {
                        health -= meleeDamage
                        gameState.arena.obstacles[i].health = max(0, health)

                        // Destroy if health depleted
                        if health <= 0 {
                            // Destruction particles
                            ParticleFactory.createExplosion(
                                state: &gameState,
                                x: obstacleCenterX,
                                y: obstacleCenterY,
                                color: BalanceConfig.Cyberboss.obstacleParticleColor,
                                count: BalanceConfig.Cyberboss.obstacleParticleCount,
                                size: BalanceConfig.Cyberboss.obstacleParticleSize
                            )
                        }
                    }
                }
            }

            // Remove destroyed obstacles
            gameState.arena.obstacles.removeAll { obstacle in
                guard obstacle.isDestructible, let health = obstacle.health else { return false }
                return health <= 0
            }
        }

        // Resolve obstacle collisions (only for obstacles that still exist)
        for obstacle in gameState.arena.obstacles {
            // Skip destroyed obstacles
            if obstacle.isDestructible, let health = obstacle.health, health <= 0 {
                continue
            }

            // Check X movement
            if MathUtils.circleRectOverlap(
                circleX: newX, circleY: boss.y, radius: bossSize,
                rectX: obstacle.x, rectY: obstacle.y,
                rectWidth: obstacle.width, rectHeight: obstacle.height
            ) {
                newX = boss.x // Revert X
            }

            // Check Y movement
            if MathUtils.circleRectOverlap(
                circleX: newX, circleY: newY, radius: bossSize,
                rectX: obstacle.x, rectY: obstacle.y,
                rectWidth: obstacle.width, rectHeight: obstacle.height
            ) {
                newY = boss.y // Revert Y
            }
        }

        // Keep boss within arena bounds (with padding)
        let padding = bossSize + BalanceConfig.Cyberboss.boundsPadding
        newX = max(padding, min(gameState.arena.width - padding, newX))
        newY = max(padding, min(gameState.arena.height - padding, newY))

        // Apply final position
        boss.x = newX
        boss.y = newY
    }

    // MARK: - Phase Transitions

    private static func enterPhase2(bossState: inout CyberbossState) {
        // Continue mode switching, add minion spawns
        bossState.minionSpawnInterval = BalanceConfig.Cyberboss.minionSpawnIntervalPhase2
    }

    private static func enterPhase3(bossState: inout CyberbossState, boss: Enemy) {
        // Stop moving, start spawning damage puddles
        bossState.puddleSpawnInterval = BalanceConfig.Cyberboss.puddleSpawnIntervalPhase3
    }

    private static func enterPhase4(bossState: inout CyberbossState, boss: Enemy) {
        // Increase puddle spawn rate for Phase 4
        bossState.puddleSpawnInterval = BalanceConfig.Cyberboss.puddleSpawnIntervalPhase4

        // Create rotating laser beams
        let beamCount = BalanceConfig.Cyberboss.laserBeamCount
        let angleStep = 360.0 / CGFloat(beamCount)
        bossState.laserBeams = []
        for i in 0..<beamCount {
            bossState.laserBeams.append(LaserBeam(
                id: RandomUtils.generateId(),
                angle: CGFloat(i) * angleStep,
                length: BalanceConfig.Cyberboss.laserBeamLength,
                damage: BalanceConfig.Cyberboss.laserBeamDamage
            ))
        }
    }

    // MARK: - Phase Updates

    private static func updatePhase1(
        boss: inout Enemy,
        bossState: inout CyberbossState,
        gameState: inout GameState,
        deltaTime: TimeInterval
    ) {
        // Mode switching every 5 seconds
        bossState.modeTimer += deltaTime

        if bossState.modeTimer >= bossState.modeSwitchInterval {
            bossState.modeTimer = 0
            bossState.mode = bossState.mode == .melee ? .ranged : .melee

            // Change boss color to indicate mode
            boss.color = bossState.mode == .melee ? BalanceConfig.Cyberboss.meleeModeColor : BalanceConfig.Cyberboss.rangedModeColor
        }

        // Movement behavior based on mode
        if bossState.mode == .melee {
            // Chase player aggressively
            moveTowardsPlayer(boss: &boss, gameState: gameState, speedMultiplier: BalanceConfig.Cyberboss.meleeChaseSpeedMultiplier)
        } else {
            // Keep distance and shoot
            moveAwayFromPlayer(boss: &boss, gameState: gameState, preferredDistance: BalanceConfig.Cyberboss.rangedPreferredDistance)
            fireRangedAttack(boss: boss, bossState: &bossState, gameState: &gameState)
        }
    }

    private static func updatePhase2(
        boss: inout Enemy,
        bossState: inout CyberbossState,
        gameState: inout GameState,
        deltaTime: TimeInterval
    ) {
        // Continue phase 1 behavior
        updatePhase1(boss: &boss, bossState: &bossState, gameState: &gameState, deltaTime: deltaTime)

        // Spawn minions periodically
        if gameState.gameTime - bossState.lastMinionSpawnTime >= bossState.minionSpawnInterval {
            bossState.lastMinionSpawnTime = gameState.gameTime
            spawnMinions(boss: boss, gameState: &gameState, phase: 2)
        }
    }

    private static func updatePhase3(
        boss: inout Enemy,
        bossState: inout CyberbossState,
        gameState: inout GameState,
        deltaTime: TimeInterval
    ) {
        // Boss becomes stationary
        boss.velocityX = 0
        boss.velocityY = 0

        // Continue spawning minions to keep player moving (reduced cap for performance)
        if gameState.gameTime - bossState.lastMinionSpawnTime >= bossState.minionSpawnInterval {
            bossState.lastMinionSpawnTime = gameState.gameTime
            spawnMinions(boss: boss, gameState: &gameState, phase: 3)
        }

        // Spawn damage puddles
        if gameState.gameTime - bossState.lastPuddleSpawnTime >= bossState.puddleSpawnInterval {
            bossState.lastPuddleSpawnTime = gameState.gameTime
            spawnDamagePuddles(boss: boss, bossState: &bossState, gameState: gameState)
        }
    }

    private static func updatePhase4(
        boss: inout Enemy,
        bossState: inout CyberbossState,
        gameState: inout GameState,
        deltaTime: TimeInterval
    ) {
        // Boss stays stationary with rotating lasers
        boss.velocityX = 0
        boss.velocityY = 0

        // Continue spawning puddles at faster rate (interval set in enterPhase4)
        if gameState.gameTime - bossState.lastPuddleSpawnTime >= bossState.puddleSpawnInterval {
            bossState.lastPuddleSpawnTime = gameState.gameTime
            spawnDamagePuddles(boss: boss, bossState: &bossState, gameState: gameState)
        }
    }

    // MARK: - Movement Helpers

    private static func moveTowardsPlayer(
        boss: inout Enemy,
        gameState: GameState,
        speedMultiplier: CGFloat
    ) {
        let dx = gameState.player.x - boss.x
        let dy = gameState.player.y - boss.y
        let distance = sqrt(dx * dx + dy * dy)

        if distance > 0 {
            boss.velocityX = (dx / distance) * boss.speed * speedMultiplier
            boss.velocityY = (dy / distance) * boss.speed * speedMultiplier
        }
    }

    private static func moveAwayFromPlayer(
        boss: inout Enemy,
        gameState: GameState,
        preferredDistance: CGFloat = BalanceConfig.Cyberboss.rangedPreferredDistance
    ) {
        let dx = boss.x - gameState.player.x
        let dy = boss.y - gameState.player.y
        let distance = sqrt(dx * dx + dy * dy)

        if distance < preferredDistance && distance > 0 {
            // Move away
            boss.velocityX = (dx / distance) * boss.speed * BalanceConfig.Cyberboss.rangedMoveAwaySpeed
            boss.velocityY = (dy / distance) * boss.speed * BalanceConfig.Cyberboss.rangedMoveAwaySpeed
        } else if distance > preferredDistance + BalanceConfig.Cyberboss.rangedDistanceThreshold {
            // Move closer
            boss.velocityX = -(dx / distance) * boss.speed * BalanceConfig.Cyberboss.rangedMoveCloserSpeed
            boss.velocityY = -(dy / distance) * boss.speed * BalanceConfig.Cyberboss.rangedMoveCloserSpeed
        } else {
            // Strafe
            boss.velocityX = (dy / distance) * boss.speed * BalanceConfig.Cyberboss.rangedStrafeSpeed
            boss.velocityY = -(dx / distance) * boss.speed * BalanceConfig.Cyberboss.rangedStrafeSpeed
        }
    }

    // MARK: - Attacks

    private static func fireRangedAttack(boss: Enemy, bossState: inout CyberbossState, gameState: inout GameState) {
        // Check cooldown - fire spread volley periodically
        guard gameState.gameTime - bossState.lastRangedAttackTime >= bossState.rangedAttackCooldown else {
            return
        }
        bossState.lastRangedAttackTime = gameState.gameTime

        let dx = gameState.player.x - boss.x
        let dy = gameState.player.y - boss.y
        let distance = sqrt(dx * dx + dy * dy)

        if distance > 0 {
            let bossSize = boss.size ?? BalanceConfig.EnemyDefaults.bossSize
            let projectileSize = bossSize * BalanceConfig.Cyberboss.rangedProjectileSizeRatio
            let baseAngle = atan2(dy, dx)

            // Fire projectiles in a fan spread
            let projectileCount = BalanceConfig.Cyberboss.rangedProjectileCount
            let spreadAngle = BalanceConfig.Cyberboss.rangedSpreadAngle
            let angleStep = spreadAngle / CGFloat(projectileCount - 1)
            let startAngle = baseAngle - spreadAngle / 2

            let projectileSpeed = BalanceConfig.Cyberboss.rangedProjectileSpeed
            let spawnOffset = bossSize + projectileSize + BalanceConfig.Cyberboss.rangedSpawnOffset

            for i in 0..<projectileCount {
                let angle = startAngle + CGFloat(i) * angleStep
                let dirX = cos(angle)
                let dirY = sin(angle)

                let spawnX = boss.x + dirX * spawnOffset
                let spawnY = boss.y + dirY * spawnOffset

                let projectile = Projectile(
                    id: RandomUtils.generateId(),
                    weaponId: "cyberboss_blast",
                    x: spawnX,
                    y: spawnY,
                    velocityX: dirX * projectileSpeed,
                    velocityY: dirY * projectileSpeed,
                    damage: BalanceConfig.Cyberboss.rangedProjectileDamage,
                    radius: projectileSize,
                    color: BalanceConfig.Cyberboss.rangedProjectileColor,
                    lifetime: BalanceConfig.Cyberboss.rangedProjectileLifetime,
                    piercing: 0,
                    hitEnemies: [],
                    isHoming: false,
                    homingStrength: 0,
                    isEnemyProjectile: true,
                    trail: true // Enable trail for visual effect
                )
                gameState.projectiles.append(projectile)
            }
        }
    }

    /// Maximum minions allowed on screen during boss fight (prevents lag from enemy accumulation)
    private static var maxMinionsOnScreen: Int { BalanceConfig.Cyberboss.maxMinionsOnScreen }
    /// Reduced cap for Phase 3 (puddles + minions = performance concern)
    private static var maxMinionsPhase3: Int { BalanceConfig.Cyberboss.maxMinionsOnScreen / 2 }  // 12 instead of 25

    private static func spawnMinions(boss: Enemy, gameState: inout GameState, phase: Int = 2) {
        // Count current minions (non-boss enemies that are alive)
        let currentMinions = gameState.enemies.filter { !$0.isBoss && !$0.isDead }.count

        // Use lower cap in Phase 3 (puddles already add visual complexity)
        let effectiveCap = phase >= 3 ? maxMinionsPhase3 : maxMinionsOnScreen

        // Don't spawn if we're at or above the cap
        guard currentMinions < effectiveCap else { return }

        // Calculate how many we can spawn without exceeding cap
        let availableSlots = effectiveCap - currentMinions

        // Spawn fast enemies and tank enemies (capped)
        let fastCount = min(Int.random(in: BalanceConfig.Cyberboss.fastMinionCountMin...BalanceConfig.Cyberboss.fastMinionCountMax), availableSlots)
        let remainingSlots = availableSlots - fastCount
        let tankCount = min(Int.random(in: BalanceConfig.Cyberboss.tankMinionCountMin...BalanceConfig.Cyberboss.tankMinionCountMax), remainingSlots)

        for _ in 0..<fastCount {
            spawnMinion(type: EnemyID.fast.rawValue, near: boss, gameState: &gameState)
        }

        for _ in 0..<tankCount {
            spawnMinion(type: EnemyID.tank.rawValue, near: boss, gameState: &gameState)
        }
    }

    private static func spawnMinion(type: String, near boss: Enemy, gameState: inout GameState) {
        guard let config = GameConfigLoader.shared.getEnemy(type) else { return }

        let enemySize = CGFloat(config.size)

        // Try multiple spawn positions to avoid obstacles
        for _ in 0..<10 {
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let distance = CGFloat.random(in: BalanceConfig.Cyberboss.minionSpawnDistanceMin...BalanceConfig.Cyberboss.minionSpawnDistanceMax)

            let x = boss.x + cos(angle) * distance
            let y = boss.y + sin(angle) * distance

            // Check if position is inside any obstacle
            var collidesWithObstacle = false
            for obstacle in gameState.arena.obstacles {
                if MathUtils.circleRectOverlap(
                    circleX: x, circleY: y, radius: enemySize,
                    rectX: obstacle.x, rectY: obstacle.y,
                    rectWidth: obstacle.width, rectHeight: obstacle.height
                ) {
                    collidesWithObstacle = true
                    break
                }
            }

            // Also check arena bounds
            let padding: CGFloat = enemySize + BalanceConfig.Cyberboss.minionSpawnPadding
            let inBounds = x >= padding && x <= gameState.arena.width - padding &&
                          y >= padding && y <= gameState.arena.height - padding

            if !collidesWithObstacle && inBounds {
                let enemy = Enemy(
                    id: RandomUtils.generateId(),
                    type: type,
                    x: x,
                    y: y,
                    health: config.health,
                    maxHealth: config.health,
                    damage: config.damage,
                    speed: config.speed,
                    xpValue: config.hashValue,
                    color: config.color,
                    velocityX: 0,
                    velocityY: 0
                )
                gameState.enemies.append(enemy)
                return
            }
        }

        // Fallback: spawn at boss position (will walk out)
        let enemy = Enemy(
            id: RandomUtils.generateId(),
            type: type,
            x: boss.x,
            y: boss.y,
            health: config.health,
            maxHealth: config.health,
            damage: config.damage,
            speed: config.speed,
            xpValue: config.hashValue,
            color: config.color,
            velocityX: 0,
            velocityY: 0
        )
        gameState.enemies.append(enemy)
    }

    private static func spawnDamagePuddles(
        boss: Enemy,
        bossState: inout CyberbossState,
        gameState: GameState
    ) {
        // Spawn puddles around the arena
        let count = Int.random(in: BalanceConfig.Cyberboss.puddleCountMin...BalanceConfig.Cyberboss.puddleCountMax)

        for _ in 0..<count {
            let arenaWidth = gameState.arena.width
            let arenaHeight = gameState.arena.height
            let margin = BalanceConfig.Cyberboss.puddleSpawnMargin

            let puddle = DamagePuddle(
                id: RandomUtils.generateId(),
                x: CGFloat.random(in: margin...(arenaWidth - margin)),
                y: CGFloat.random(in: margin...(arenaHeight - margin)),
                radius: BalanceConfig.Cyberboss.puddleRadius,
                damage: BalanceConfig.Cyberboss.puddleDPS,
                popDamage: BalanceConfig.Cyberboss.puddlePopDamage,
                damageInterval: BalanceConfig.Cyberboss.puddleDamageInterval,
                lastDamageTime: 0,
                lifetime: 0,
                maxLifetime: BalanceConfig.Cyberboss.puddleMaxLifetime,
                warningDuration: BalanceConfig.Cyberboss.puddleWarningDuration,
                hasPopped: false
            )
            bossState.damagePuddles.append(puddle)
        }
    }

    // MARK: - Damage Puddle Updates

    private static func updateDamagePuddles(
        bossState: inout CyberbossState,
        gameState: inout GameState,
        deltaTime: TimeInterval
    ) {
        // Update lifetime and remove expired puddles
        bossState.damagePuddles = bossState.damagePuddles.compactMap { puddle in
            var mutablePuddle = puddle
            mutablePuddle.lifetime += deltaTime

            // Check if puddle should pop (at end of lifetime)
            let aboutToPop = mutablePuddle.lifetime >= mutablePuddle.maxLifetime - BalanceConfig.Cyberboss.puddlePopThreshold
            let isExpired = mutablePuddle.lifetime >= mutablePuddle.maxLifetime

            // Deal pop damage right before removal
            if aboutToPop && !mutablePuddle.hasPopped {
                mutablePuddle.hasPopped = true

                // Check if player is in puddle for pop damage (include player radius for accurate collision)
                let dx = gameState.player.x - mutablePuddle.x
                let dy = gameState.player.y - mutablePuddle.y
                let distance = sqrt(dx * dx + dy * dy)
                let playerRadius = BalanceConfig.Player.size

                if distance < mutablePuddle.radius + playerRadius {
                    PlayerSystem.damagePlayer(state: &gameState, rawDamage: mutablePuddle.popDamage)
                }
            }

            if isExpired {
                return nil // Remove expired puddle
            }

            // Skip damage during warning phase (first 1 second)
            let isWarningPhase = mutablePuddle.lifetime < mutablePuddle.warningDuration
            if isWarningPhase {
                return mutablePuddle // No damage during warning
            }

            // Active phase - deal DPS damage (include player radius for accurate collision)
            let dx = gameState.player.x - mutablePuddle.x
            let dy = gameState.player.y - mutablePuddle.y
            let distance = sqrt(dx * dx + dy * dy)
            let playerRadius = BalanceConfig.Player.size

            if distance < mutablePuddle.radius + playerRadius &&
               gameState.gameTime - mutablePuddle.lastDamageTime >= mutablePuddle.damageInterval {
                mutablePuddle.lastDamageTime = gameState.gameTime
                let tickDamage = mutablePuddle.damage * CGFloat(mutablePuddle.damageInterval)
                PlayerSystem.damagePlayer(state: &gameState, rawDamage: tickDamage)
            }

            return mutablePuddle
        }
    }

    // MARK: - Laser Beam Updates

    private static func updateLaserBeams(
        bossState: inout CyberbossState,
        boss: Enemy,
        gameState: inout GameState,
        deltaTime: TimeInterval
    ) {
        guard !bossState.laserBeams.isEmpty else { return }

        // Update lifetime and rotate all beams
        for i in 0..<bossState.laserBeams.count {
            bossState.laserBeams[i].lifetime += deltaTime
            bossState.laserBeams[i].angle += bossState.laserRotationSpeed * CGFloat(deltaTime)
            if bossState.laserBeams[i].angle >= 360 {
                bossState.laserBeams[i].angle -= 360
            }
        }

        // Check player collision with ACTIVE beams only (use currentFrameTime for consistent time base)
        if gameState.player.invulnerableUntil < gameState.currentFrameTime {
            for beam in bossState.laserBeams {
                // Skip beams still in warning phase
                guard beam.isActive else { continue }

                let hit = isPlayerHitByLaser(
                    beam: beam,
                    bossX: boss.x, bossY: boss.y,
                    playerX: gameState.player.x, playerY: gameState.player.y
                )
                if hit {
                    PlayerSystem.damagePlayer(state: &gameState, rawDamage: beam.damage)
                    gameState.player.invulnerableUntil = gameState.currentFrameTime + BalanceConfig.Cyberboss.laserHitInvulnerability
                    break
                }
            }
        }
    }

    private static func isPlayerHitByLaser(
        beam: LaserBeam,
        bossX: CGFloat, bossY: CGFloat,
        playerX: CGFloat, playerY: CGFloat
    ) -> Bool {
        let playerRadius = BalanceConfig.Player.size
        let beamWidth = BalanceConfig.Cyberboss.laserBeamWidth

        // Calculate beam endpoint (negate sin for Y-down coordinate system to match SpriteKit rendering)
        let angleRad = beam.angle * .pi / 180
        let endX = bossX + cos(angleRad) * beam.length
        let endY = bossY - sin(angleRad) * beam.length

        // Point-to-line distance
        let distance = pointToLineDistance(
            px: playerX, py: playerY,
            x1: bossX, y1: bossY,
            x2: endX, y2: endY
        )

        return distance < playerRadius + beamWidth / 2
    }

    private static func pointToLineDistance(
        px: CGFloat, py: CGFloat,
        x1: CGFloat, y1: CGFloat,
        x2: CGFloat, y2: CGFloat
    ) -> CGFloat {
        let dx = x2 - x1
        let dy = y2 - y1
        let lengthSquared = dx * dx + dy * dy

        if lengthSquared == 0 {
            return sqrt((px - x1) * (px - x1) + (py - y1) * (py - y1))
        }

        var t = ((px - x1) * dx + (py - y1) * dy) / lengthSquared
        t = max(0, min(1, t))

        let nearestX = x1 + t * dx
        let nearestY = y1 + t * dy

        return sqrt((px - nearestX) * (px - nearestX) + (py - nearestY) * (py - nearestY))
    }

    // MARK: - Rendering Data

    static func getRenderData(
        bossState: CyberbossState,
        boss: Enemy
    ) -> CyberbossRenderData {
        return CyberbossRenderData(
            phase: bossState.phase,
            mode: bossState.mode,
            laserBeams: bossState.laserBeams,
            damagePuddles: bossState.damagePuddles,
            bossX: boss.x,
            bossY: boss.y
        )
    }

    struct CyberbossRenderData {
        let phase: Int
        let mode: CyberbossMode
        let laserBeams: [LaserBeam]
        let damagePuddles: [DamagePuddle]
        let bossX: CGFloat
        let bossY: CGFloat
    }
}
