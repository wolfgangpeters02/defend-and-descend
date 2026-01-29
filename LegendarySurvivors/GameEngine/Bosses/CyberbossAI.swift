import Foundation
import CoreGraphics

// MARK: - Cyberboss AI

/// 4-Phase Heist Boss with mode switching, minions, damage puddles, and laser beams
class CyberbossAI {

    // MARK: - State

    struct CyberbossState {
        var phase: Int = 1
        var mode: CyberbossMode = .melee
        var modeTimer: Double = 0
        var modeSwitchInterval: Double = 5.0

        var lastMinionSpawnTime: Double = 0
        var minionSpawnInterval: Double = 10.0

        var lastPuddleSpawnTime: Double = 0
        var puddleSpawnInterval: Double = 2.0

        var laserBeams: [LaserBeam] = []
        var laserRotationSpeed: CGFloat = 25.0 // degrees per second (slowed for playability)

        var damagePuddles: [DamagePuddle] = []

        var isInvulnerable: Bool = false
    }

    enum CyberbossMode {
        case melee
        case ranged
    }

    struct LaserBeam {
        let id: String
        var angle: CGFloat
        let length: CGFloat
        let damage: CGFloat
    }

    struct DamagePuddle {
        let id: String
        var x: CGFloat
        var y: CGFloat
        let radius: CGFloat
        let damage: CGFloat         // DPS while active
        let popDamage: CGFloat      // Burst damage when puddle pops
        let damageInterval: Double
        var lastDamageTime: Double
        var lifetime: Double
        let maxLifetime: Double     // Total duration (4 seconds)
        let warningDuration: Double // Warning phase (1 second, no damage)
        var hasPopped: Bool = false // Track if pop damage was already dealt
    }

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

        if healthPercent <= 0.25 {
            if bossState.phase != 4 {
                enterPhase4(bossState: &bossState, boss: boss)
            }
            bossState.phase = 4
        } else if healthPercent <= 0.5 {
            if bossState.phase != 3 {
                enterPhase3(bossState: &bossState, boss: boss)
            }
            bossState.phase = 3
        } else if healthPercent <= 0.75 {
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

        // Apply movement with collision checking
        applyMovement(boss: &boss, gameState: gameState, deltaTime: deltaTime)

        // Update damage puddles
        updateDamagePuddles(bossState: &bossState, gameState: &gameState, deltaTime: deltaTime)

        // Update laser beams
        updateLaserBeams(bossState: &bossState, boss: boss, gameState: &gameState, deltaTime: deltaTime)
    }

    // MARK: - Movement Application

    private static func applyMovement(
        boss: inout Enemy,
        gameState: GameState,
        deltaTime: TimeInterval
    ) {
        // Calculate new position from velocity
        let moveX = boss.velocityX * CGFloat(deltaTime)
        let moveY = boss.velocityY * CGFloat(deltaTime)

        var newX = boss.x + moveX
        var newY = boss.y + moveY

        let bossSize = boss.size ?? 60

        // Resolve obstacle collisions
        for obstacle in gameState.arena.obstacles {
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
        let padding: CGFloat = bossSize + 20
        newX = max(padding, min(gameState.arena.width - padding, newX))
        newY = max(padding, min(gameState.arena.height - padding, newY))

        // Apply final position
        boss.x = newX
        boss.y = newY
    }

    // MARK: - Phase Transitions

    private static func enterPhase2(bossState: inout CyberbossState) {
        // Continue mode switching, add minion spawns
        bossState.minionSpawnInterval = 8.0
    }

    private static func enterPhase3(bossState: inout CyberbossState, boss: Enemy) {
        // Stop moving, start spawning damage puddles
        bossState.puddleSpawnInterval = 2.0
    }

    private static func enterPhase4(bossState: inout CyberbossState, boss: Enemy) {
        // Create 5 rotating laser beams
        bossState.laserBeams = []
        for i in 0..<5 {
            bossState.laserBeams.append(LaserBeam(
                id: RandomUtils.generateId(),
                angle: CGFloat(i) * 72.0, // Evenly spaced
                length: 800,  // Increased for larger arena (was 500)
                damage: 50    // Survivable damage - player can take 1-2 hits
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
            boss.color = bossState.mode == .melee ? "#ff4444" : "#4444ff"
        }

        // Movement behavior based on mode
        if bossState.mode == .melee {
            // Chase player aggressively
            moveTowardsPlayer(boss: &boss, gameState: gameState, speedMultiplier: 1.2)
        } else {
            // Keep distance and shoot
            moveAwayFromPlayer(boss: &boss, gameState: gameState, preferredDistance: 300)
            fireRangedAttack(boss: boss, gameState: &gameState)
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
            spawnMinions(boss: boss, gameState: &gameState)
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

        // Continue spawning minions to keep player moving
        if gameState.gameTime - bossState.lastMinionSpawnTime >= bossState.minionSpawnInterval {
            bossState.lastMinionSpawnTime = gameState.gameTime
            spawnMinions(boss: boss, gameState: &gameState)
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

        // Continue spawning puddles at faster rate
        bossState.puddleSpawnInterval = 1.5
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
        preferredDistance: CGFloat = 450  // Increased for larger arena (was 300)
    ) {
        let dx = boss.x - gameState.player.x
        let dy = boss.y - gameState.player.y
        let distance = sqrt(dx * dx + dy * dy)

        if distance < preferredDistance && distance > 0 {
            // Move away
            boss.velocityX = (dx / distance) * boss.speed * 0.5
            boss.velocityY = (dy / distance) * boss.speed * 0.5
        } else if distance > preferredDistance + 150 {
            // Move closer (increased threshold for larger arena)
            boss.velocityX = -(dx / distance) * boss.speed * 0.3
            boss.velocityY = -(dy / distance) * boss.speed * 0.3
        } else {
            // Strafe
            boss.velocityX = (dy / distance) * boss.speed * 0.4
            boss.velocityY = -(dx / distance) * boss.speed * 0.4
        }
    }

    // MARK: - Attacks

    private static func fireRangedAttack(boss: Enemy, gameState: inout GameState) {
        let dx = gameState.player.x - boss.x
        let dy = gameState.player.y - boss.y
        let distance = sqrt(dx * dx + dy * dy)

        if distance > 0 {
            let bossSize = boss.size ?? 60
            let projectileSize = bossSize * 0.4 // 40% of boss size - visible but not huge

            // Spawn projectile outside boss hitbox
            let spawnOffset = bossSize + projectileSize + 5
            let spawnX = boss.x + (dx / distance) * spawnOffset
            let spawnY = boss.y + (dy / distance) * spawnOffset

            let projectile = Projectile(
                id: RandomUtils.generateId(),
                weaponId: "cyberboss_blast",
                x: spawnX,
                y: spawnY,
                velocityX: (dx / distance) * 200, // Slower for dramatic effect
                velocityY: (dy / distance) * 200,
                damage: 35, // Higher damage for slower projectile
                radius: projectileSize,
                color: "#00ffff", // Cyan energy blast
                lifetime: 6.0,
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

    private static func spawnMinions(boss: Enemy, gameState: inout GameState) {
        // Spawn 5-6 fast enemies and 4-5 tank enemies
        let fastCount = Int.random(in: 5...6)
        let tankCount = Int.random(in: 4...5)

        for _ in 0..<fastCount {
            spawnMinion(type: "fast", near: boss, gameState: &gameState)
        }

        for _ in 0..<tankCount {
            spawnMinion(type: "tank", near: boss, gameState: &gameState)
        }
    }

    private static func spawnMinion(type: String, near boss: Enemy, gameState: inout GameState) {
        let angle = CGFloat.random(in: 0...(2 * .pi))
        let distance: CGFloat = CGFloat.random(in: 80...150)

        let x = boss.x + cos(angle) * distance
        let y = boss.y + sin(angle) * distance

        if let config = GameConfigLoader.shared.getEnemy(type) {
            let enemy = Enemy(
                id: RandomUtils.generateId(),
                type: type,
                x: x,
                y: y,
                health: config.health,
                maxHealth: config.health,
                damage: config.damage,
                speed: config.speed,
                xpValue: config.coinValue, // XP derived from coin value
                color: config.color,
                velocityX: 0,
                velocityY: 0
            )
            gameState.enemies.append(enemy)
        }
    }

    private static func spawnDamagePuddles(
        boss: Enemy,
        bossState: inout CyberbossState,
        gameState: GameState
    ) {
        // Spawn 3-5 puddles around the arena
        let count = Int.random(in: 3...5)

        for _ in 0..<count {
            let arenaWidth = gameState.arena.width
            let arenaHeight = gameState.arena.height

            let puddle = DamagePuddle(
                id: RandomUtils.generateId(),
                x: CGFloat.random(in: 100...(arenaWidth - 100)),
                y: CGFloat.random(in: 100...(arenaHeight - 100)),
                radius: 60,
                damage: 10,             // 10 DPS while active (reduced from 30)
                popDamage: 30,          // 30 burst damage when puddle pops
                damageInterval: 0.5,    // Tick every 0.5 seconds (so 2 ticks per second = 10 DPS)
                lastDamageTime: 0,
                lifetime: 0,
                maxLifetime: 4.0,       // Total 4 second duration (reduced from 8)
                warningDuration: 1.0,   // 1 second warning phase (no damage)
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
            let aboutToPop = mutablePuddle.lifetime >= mutablePuddle.maxLifetime - 0.1
            let isExpired = mutablePuddle.lifetime >= mutablePuddle.maxLifetime

            // Deal pop damage right before removal
            if aboutToPop && !mutablePuddle.hasPopped {
                mutablePuddle.hasPopped = true

                // Check if player is in puddle for pop damage
                let dx = gameState.player.x - mutablePuddle.x
                let dy = gameState.player.y - mutablePuddle.y
                let distance = sqrt(dx * dx + dy * dy)

                if distance < mutablePuddle.radius {
                    gameState.player.health -= mutablePuddle.popDamage

                    // Check for death
                    if gameState.player.health <= 0 {
                        gameState.player.health = 0
                        gameState.isGameOver = true
                        gameState.victory = false
                    }

                    // Visual feedback - pop damage
                    let damageEvent = DamageEvent(
                        type: .playerDamage,
                        amount: Int(mutablePuddle.popDamage),
                        position: CGPoint(x: gameState.player.x, y: gameState.player.y),
                        timestamp: gameState.startTime + gameState.timeElapsed
                    )
                    gameState.damageEvents.append(damageEvent)
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

            // Active phase - deal DPS damage
            let dx = gameState.player.x - mutablePuddle.x
            let dy = gameState.player.y - mutablePuddle.y
            let distance = sqrt(dx * dx + dy * dy)

            if distance < mutablePuddle.radius &&
               gameState.gameTime - mutablePuddle.lastDamageTime >= mutablePuddle.damageInterval {
                mutablePuddle.lastDamageTime = gameState.gameTime
                let tickDamage = mutablePuddle.damage * CGFloat(mutablePuddle.damageInterval) // 10 DPS * 0.5s = 5 damage per tick
                gameState.player.health -= tickDamage

                // Check for death
                if gameState.player.health <= 0 {
                    gameState.player.health = 0
                    gameState.isGameOver = true
                    gameState.victory = false
                }

                // Visual feedback - damage event for scrolling combat text
                let damageEvent = DamageEvent(
                    type: .playerDamage,
                    amount: Int(tickDamage),
                    position: CGPoint(x: gameState.player.x, y: gameState.player.y),
                    timestamp: gameState.startTime + gameState.timeElapsed
                )
                gameState.damageEvents.append(damageEvent)
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

        // Rotate all beams
        for i in 0..<bossState.laserBeams.count {
            bossState.laserBeams[i].angle += bossState.laserRotationSpeed * CGFloat(deltaTime)
            if bossState.laserBeams[i].angle >= 360 {
                bossState.laserBeams[i].angle -= 360
            }
        }

        // Check player collision with any beam
        if gameState.player.invulnerableUntil < gameState.gameTime {
            for beam in bossState.laserBeams {
                if isPlayerHitByLaser(
                    beam: beam,
                    bossX: boss.x, bossY: boss.y,
                    playerX: gameState.player.x, playerY: gameState.player.y
                ) {
                    // Instant kill damage
                    gameState.player.health -= beam.damage
                    gameState.player.invulnerableUntil = gameState.gameTime + 0.5

                    // Check for death
                    if gameState.player.health <= 0 {
                        gameState.player.health = 0
                        gameState.isGameOver = true
                        gameState.victory = false
                    }

                    // Visual feedback
                    let damageEvent = DamageEvent(
                        type: .playerDamage,
                        amount: Int(beam.damage),
                        position: CGPoint(x: gameState.player.x, y: gameState.player.y),
                        timestamp: gameState.startTime + gameState.timeElapsed
                    )
                    gameState.damageEvents.append(damageEvent)
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
        let playerRadius: CGFloat = 15
        let beamWidth: CGFloat = 10

        // Calculate beam endpoint
        let angleRad = beam.angle * .pi / 180
        let endX = bossX + cos(angleRad) * beam.length
        let endY = bossY + sin(angleRad) * beam.length

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
