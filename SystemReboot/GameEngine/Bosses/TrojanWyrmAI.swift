import Foundation
import CoreGraphics

// MARK: - Trojan Wyrm AI

/// Network Worm Boss with 4 phases: Snake movement, Firewall wall, Split into sub-worms, Constricting ring
class TrojanWyrmAI {

    // Types and state defined in BossStates.swift

    // MARK: - Initialization

    static func createInitialState(arenaCenter: CGPoint, arenaRect: CGRect) -> TrojanWyrmState {
        var state = TrojanWyrmState()
        state.arenaCenter = arenaCenter
        state.arenaRect = arenaRect
        state.phase = 1

        // Initialize 24 segments trailing downwards
        let spacing = BalanceConfig.TrojanWyrm.segmentSpacing
        for i in 1...BalanceConfig.TrojanWyrm.segmentCount {
            let seg = Segment(
                x: arenaCenter.x,
                y: arenaCenter.y - CGFloat(i) * spacing
            )
            state.segments.append(seg)
        }

        state.headAngle = CGFloat.random(in: 0...(2 * .pi))
        return state
    }

    // MARK: - Main Update

    static func update(
        boss: inout Enemy,
        bossState: inout TrojanWyrmState,
        gameState: inout GameState,
        deltaTime: TimeInterval
    ) {
        let healthPercent = boss.health / boss.maxHealth
        let playerPos = CGPoint(x: gameState.player.x, y: gameState.player.y)
        let currentTime = gameState.gameTime
        let arenaRect = bossState.arenaRect

        // Determine phase based on health
        let oldPhase = bossState.phase
        if healthPercent <= BalanceConfig.TrojanWyrm.phase4Threshold {
            bossState.phase = 4
        } else if healthPercent <= BalanceConfig.TrojanWyrm.phase3Threshold {
            bossState.phase = 3
        } else if healthPercent <= BalanceConfig.TrojanWyrm.phase2Threshold {
            bossState.phase = 2
        } else {
            bossState.phase = 1
        }

        // Handle phase transitions
        if bossState.phase != oldPhase {
            enterPhase(bossState.phase, bossState: &bossState, boss: boss, playerPos: playerPos, arenaRect: arenaRect)
        }

        // Execute phase behavior
        switch bossState.phase {
        case 1:
            updatePhase1(boss: &boss, bossState: &bossState, playerPos: playerPos, deltaTime: deltaTime, arenaRect: arenaRect)
        case 2:
            updatePhase2(boss: &boss, bossState: &bossState, gameState: &gameState, deltaTime: deltaTime, currentTime: currentTime, arenaRect: arenaRect)
        case 3:
            updatePhase3(boss: &boss, bossState: &bossState, playerPos: playerPos, deltaTime: deltaTime)
        case 4:
            updatePhase4(boss: &boss, bossState: &bossState, playerPos: playerPos, deltaTime: deltaTime, arenaRect: arenaRect)
        default:
            break
        }

        // Check player contact damage
        checkContactDamage(bossState: &bossState, gameState: &gameState, boss: boss, currentTime: currentTime)
    }

    // MARK: - Phase Transitions

    private static func enterPhase(_ phase: Int, bossState: inout TrojanWyrmState, boss: Enemy, playerPos: CGPoint, arenaRect: CGRect) {
        switch phase {
        case 2:
            // Setup Firewall
            bossState.wallInitialized = true
            bossState.wallY = arenaRect.maxY - 100
            bossState.wallDirection = -1 // Move down
            let maxGhostIndex = bossState.segments.count - 3
            bossState.ghostSegmentIndex = maxGhostIndex > 3 ? Int.random(in: 3..<maxGhostIndex) : 0

        case 3:
            // Setup Sub-worms
            bossState.subWormsInitialized = true
            bossState.subWorms = []

            let offsets: [CGFloat] = [0, .pi / 2, .pi, 3 * .pi / 2]
            for (i, angle) in offsets.enumerated() {
                let spawnDist = BalanceConfig.TrojanWyrm.subWormSpawnDistance
                let pos = CGPoint(
                    x: arenaRect.midX + cos(angle) * spawnDist,
                    y: arenaRect.midY + sin(angle) * spawnDist
                )

                var miniSegs: [Segment] = []
                for k in 1...BalanceConfig.TrojanWyrm.subWormBodyCount {
                    miniSegs.append(Segment(x: pos.x, y: pos.y - CGFloat(k) * BalanceConfig.TrojanWyrm.subWormSegmentSpacing))
                }

                bossState.subWorms.append(SubWorm(
                    id: i,
                    head: Segment(x: pos.x, y: pos.y),
                    body: miniSegs,
                    angle: angle + .pi / 2
                ))
            }

        case 4:
            // Setup Ring
            bossState.phase4Initialized = true
            bossState.phase4SubState = .circling
            bossState.ringRadius = BalanceConfig.TrojanWyrm.ringInitialRadius
            bossState.ringAngle = 0
            bossState.aimTimer = 0
            bossState.lungeTimer = 0
            bossState.recoverTimer = 0

            // Clear sub-worms
            bossState.subWorms = []

        default:
            break
        }
    }

    // MARK: - Phase 1: Packet Loss (Snake Movement)

    private static func updatePhase1(
        boss: inout Enemy,
        bossState: inout TrojanWyrmState,
        playerPos: CGPoint,
        deltaTime: TimeInterval,
        arenaRect: CGRect
    ) {
        let config = BalanceConfig.TrojanWyrm.self
        let headPos = CGPoint(x: boss.x, y: boss.y)

        // Turn towards player gradually
        let targetAngle = atan2(playerPos.y - headPos.y, playerPos.x - headPos.x)
        let diff = normalizeAngle(targetAngle - bossState.headAngle)
        let turnAmount = CGFloat(deltaTime) * config.turnSpeed
        if abs(diff) < turnAmount {
            bossState.headAngle = targetAngle
        } else {
            bossState.headAngle += (diff > 0 ? turnAmount : -turnAmount)
        }

        // Move Head
        let newX = boss.x + cos(bossState.headAngle) * config.headSpeed * CGFloat(deltaTime)
        let newY = boss.y + sin(bossState.headAngle) * config.headSpeed * CGFloat(deltaTime)

        // Wall Bounce
        let padding = config.boundsPadding
        if newX < arenaRect.minX + padding || newX > arenaRect.maxX - padding ||
           newY < arenaRect.minY + padding || newY > arenaRect.maxY - padding {
            bossState.headAngle += .pi // 180 flip
            boss.x = max(arenaRect.minX + padding, min(arenaRect.maxX - padding, boss.x))
            boss.y = max(arenaRect.minY + padding, min(arenaRect.maxY - padding, boss.y))
        } else {
            boss.x = newX
            boss.y = newY
        }

        // Drag Body
        updateSegments(head: CGPoint(x: boss.x, y: boss.y), segments: &bossState.segments, spacing: config.segmentSpacing)
    }

    // MARK: - Phase 2: Firewall (Wall Sweep)

    private static func updatePhase2(
        boss: inout Enemy,
        bossState: inout TrojanWyrmState,
        gameState: inout GameState,
        deltaTime: TimeInterval,
        currentTime: Double,
        arenaRect: CGRect
    ) {
        let config = BalanceConfig.TrojanWyrm.self

        // Move Wall
        bossState.wallY += config.wallSweepSpeed * CGFloat(deltaTime) * bossState.wallDirection

        // Bounce at edges and re-randomize ghost gap
        let maxGhostIdx = bossState.segments.count - 3
        if bossState.wallY < arenaRect.minY + 100 {
            bossState.wallDirection = 1
            bossState.wallY = arenaRect.minY + 100
            bossState.ghostSegmentIndex = maxGhostIdx > 3 ? Int.random(in: 3..<maxGhostIdx) : 0
        } else if bossState.wallY > arenaRect.maxY - 100 {
            bossState.wallDirection = -1
            bossState.wallY = arenaRect.maxY - 100
            bossState.ghostSegmentIndex = maxGhostIdx > 3 ? Int.random(in: 3..<maxGhostIdx) : 0
        }

        // Rigid grid positioning (no drag)
        // Head in center, segments spread horizontally
        let spacing = config.segmentSpacing
        let totalWidth = spacing * CGFloat(bossState.segments.count)
        let startX = arenaRect.midX - totalWidth / 2

        boss.x = startX
        boss.y = bossState.wallY

        for i in 0..<bossState.segments.count {
            bossState.segments[i].x = startX + spacing * CGFloat(i + 1)
            bossState.segments[i].y = bossState.wallY
        }

        // Turret Fire
        if currentTime - bossState.lastTurretFireTime > config.turretFireInterval {
            bossState.lastTurretFireTime = currentTime

            // Fire from even segments (except ghost)
            for i in stride(from: 0, to: bossState.segments.count, by: 2) {
                if i == bossState.ghostSegmentIndex { continue }

                let seg = bossState.segments[i]
                let projectile = Projectile(
                    id: RandomUtils.generateId(),
                    weaponId: "trojan_turret",
                    x: seg.x,
                    y: seg.y,
                    velocityX: 0,
                    velocityY: -config.turretProjectileSpeed, // Fire downward
                    damage: config.turretProjectileDamage,
                    radius: config.turretProjectileRadius,
                    color: "#00ff44",
                    lifetime: config.turretProjectileLifetime,
                    piercing: 0,
                    hitEnemies: [],
                    isHoming: false,
                    homingStrength: 0,
                    isEnemyProjectile: true,
                    sourceType: "boss"
                )
                gameState.projectiles.append(projectile)
            }
        }
    }

    // MARK: - Phase 3: Data Corruption (Sub-worms)

    private static func updatePhase3(
        boss: inout Enemy,
        bossState: inout TrojanWyrmState,
        playerPos: CGPoint,
        deltaTime: TimeInterval
    ) {
        let config = BalanceConfig.TrojanWyrm.self

        // Hide main boss (we use sub-worms instead)
        if bossState.originalBossSize == nil {
            bossState.originalBossSize = boss.size
        }
        boss.size = 1 // Tiny hitbox

        for i in 0..<bossState.subWorms.count {
            var worm = bossState.subWorms[i]

            // Chase Player
            let headPos = worm.head.cgPoint
            let targetAngle = atan2(playerPos.y - headPos.y, playerPos.x - headPos.x)
            let diff = normalizeAngle(targetAngle - worm.angle)
            worm.angle += diff * CGFloat(deltaTime * Double(config.subWormTurnSpeed))

            let speed = config.subWormSpeed
            worm.head.x += cos(worm.angle) * speed * CGFloat(deltaTime)
            worm.head.y += sin(worm.angle) * speed * CGFloat(deltaTime)

            // Drag Body
            updateSegments(head: worm.head.cgPoint, segments: &worm.body, spacing: BalanceConfig.TrojanWyrm.subWormBodySpacing)

            bossState.subWorms[i] = worm
        }
    }

    // MARK: - Phase 4: Format C: (Constricting Ring + Lunge)

    private static func updatePhase4(
        boss: inout Enemy,
        bossState: inout TrojanWyrmState,
        playerPos: CGPoint,
        deltaTime: TimeInterval,
        arenaRect: CGRect
    ) {
        let config = BalanceConfig.TrojanWyrm.self

        // Restore boss size after Phase 3 shrink
        if let originalSize = bossState.originalBossSize {
            boss.size = originalSize
            bossState.originalBossSize = nil
        }

        switch bossState.phase4SubState {
        case .circling:
            // Shrink Ring
            bossState.ringRadius = max(
                config.ringMinRadius,
                bossState.ringRadius - config.ringShrinkRate * CGFloat(deltaTime)
            )

            // Rotate ring
            bossState.ringAngle += config.ringRotationSpeed * CGFloat(deltaTime)

            // Position head on ring
            boss.x = playerPos.x + cos(bossState.ringAngle) * bossState.ringRadius
            boss.y = playerPos.y + sin(bossState.ringAngle) * bossState.ringRadius

            // Position segments in circle formation
            let angleStep = (2 * .pi) / CGFloat(bossState.segments.count + 1)
            for i in 0..<bossState.segments.count {
                let segAngle = bossState.ringAngle - CGFloat(i + 1) * angleStep
                bossState.segments[i].x = playerPos.x + cos(segAngle) * bossState.ringRadius
                bossState.segments[i].y = playerPos.y + sin(segAngle) * bossState.ringRadius
            }

            // Trigger lunge after circling for a while
            bossState.aimTimer += deltaTime
            if bossState.aimTimer > 4.0 {
                bossState.phase4SubState = .aiming
                bossState.aimTimer = 0
            }

        case .aiming:
            // Stop rotation, telegraph attack
            bossState.aimTimer += deltaTime

            if bossState.aimTimer > config.aimDuration {
                bossState.phase4SubState = .lunging
                bossState.lungeTimer = 0

                // Calculate lunge vector
                let dx = playerPos.x - boss.x
                let dy = playerPos.y - boss.y
                let dist = sqrt(dx * dx + dy * dy)
                if dist > 0 {
                    bossState.lungeVelocityX = (dx / dist) * config.lungeSpeed
                    bossState.lungeVelocityY = (dy / dist) * config.lungeSpeed
                }
                bossState.lungeTargetX = playerPos.x
                bossState.lungeTargetY = playerPos.y
            }

        case .lunging:
            // Linear move
            boss.x += bossState.lungeVelocityX * CGFloat(deltaTime)
            boss.y += bossState.lungeVelocityY * CGFloat(deltaTime)

            // Drag physics resumes for lunge
            updateSegments(head: CGPoint(x: boss.x, y: boss.y), segments: &bossState.segments, spacing: BalanceConfig.TrojanWyrm.segmentSpacing)

            // Check bounds or timeout
            bossState.lungeTimer += deltaTime
            let padding: CGFloat = 50
            if boss.x < arenaRect.minX + padding || boss.x > arenaRect.maxX - padding ||
               boss.y < arenaRect.minY + padding || boss.y > arenaRect.maxY - padding ||
               bossState.lungeTimer > 1.5 {
                bossState.phase4SubState = .recovering
                bossState.recoverTimer = 0
            }

        case .recovering:
            bossState.recoverTimer += deltaTime
            if bossState.recoverTimer > config.recoverDuration {
                bossState.phase4SubState = .circling
                bossState.aimTimer = 0
                bossState.ringRadius = config.ringInitialRadius // Reset ring
            }
        }
    }

    // MARK: - Collision Detection

    /// Check projectile collisions with body segments (called from GameScene after ProjectileSystem)
    static func checkBodySegmentCollisions(
        bossState: inout TrojanWyrmState,
        gameState: inout GameState,
        boss: inout Enemy
    ) {
        let config = BalanceConfig.TrojanWyrm.self
        var indicesToRemove: [Int] = []
        var totalDamage: CGFloat = 0

        let headPos = CGPoint(x: boss.x, y: boss.y)
        let headRadius = config.headCollisionRadius
        let bodyRadius = config.bodyCollisionRadius
        let bodyMitigation = config.bodyDamageMitigation

        for (index, proj) in gameState.projectiles.enumerated() {
            // Skip enemy projectiles
            if proj.isEnemyProjectile { continue }

            let projPos = CGPoint(x: proj.x, y: proj.y)
            let projRadius = proj.radius
            var hit = false
            var damage: CGFloat = 0

            if bossState.phase == 3 {
                // Check sub-worms
                for worm in bossState.subWorms {
                    // Check sub-worm head
                    let subHeadDist = hypot(projPos.x - worm.head.x, projPos.y - worm.head.y)
                    if subHeadDist < config.subWormHeadSize + projRadius {
                        hit = true
                        damage = proj.damage
                        break
                    }
                    // Check sub-worm body
                    for seg in worm.body {
                        let segDist = hypot(projPos.x - seg.x, projPos.y - seg.y)
                        if segDist < config.subWormBodySize + projRadius {
                            hit = true
                            damage = proj.damage * (1 - config.subWormBodyMitigation)
                            break
                        }
                    }
                    if hit { break }
                }
            } else {
                // Check main head (only for Phase 1 - other phases use tiny hitbox)
                if bossState.phase == 1 {
                    let headDist = hypot(projPos.x - headPos.x, projPos.y - headPos.y)
                    if headDist < headRadius + projRadius {
                        hit = true
                        damage = proj.damage
                    }
                }

                // Check body segments (all phases)
                if !hit {
                    for (i, seg) in bossState.segments.enumerated() {
                        // Skip ghost segment in Phase 2
                        if bossState.phase == 2 && i == bossState.ghostSegmentIndex { continue }

                        let segDist = hypot(projPos.x - seg.x, projPos.y - seg.y)
                        if segDist < bodyRadius + projRadius {
                            hit = true
                            damage = proj.damage * (1 - bodyMitigation)
                            break
                        }
                    }
                }
            }

            if hit {
                totalDamage += damage
                indicesToRemove.append(index)
            }
        }

        // Apply damage to boss
        if totalDamage > 0 {
            boss.health -= totalDamage
        }

        // Remove consumed projectiles (reverse order)
        for index in indicesToRemove.sorted(by: >) {
            if index < gameState.projectiles.count {
                gameState.projectiles.remove(at: index)
            }
        }
    }

    /// Check player contact damage
    private static func checkContactDamage(
        bossState: inout TrojanWyrmState,
        gameState: inout GameState,
        boss: Enemy,
        currentTime: Double
    ) {
        let config = BalanceConfig.TrojanWyrm.self
        let contactCooldown = BalanceConfig.TrojanWyrm.contactCooldown

        guard currentTime - bossState.lastContactDamageTime > contactCooldown else { return }

        let playerPos = CGPoint(x: gameState.player.x, y: gameState.player.y)
        var contactMade = false
        var damageAmount: CGFloat = 0
        var knockbackSource: CGPoint = .zero

        if bossState.phase == 3 {
            // Check sub-worms
            for worm in bossState.subWorms {
                let headDist = hypot(playerPos.x - worm.head.x, playerPos.y - worm.head.y)
                if headDist < config.subWormHeadSize + 20 {
                    contactMade = true
                    damageAmount = config.headContactDamage
                    knockbackSource = worm.head.cgPoint
                    break
                }
                for seg in worm.body {
                    let segDist = hypot(playerPos.x - seg.x, playerPos.y - seg.y)
                    if segDist < config.subWormBodySize + 20 {
                        contactMade = true
                        damageAmount = config.bodyContactDamage
                        knockbackSource = seg.cgPoint
                        break
                    }
                }
                if contactMade { break }
            }
        } else {
            // Check main head
            let headPos = CGPoint(x: boss.x, y: boss.y)
            let headDist = hypot(playerPos.x - headPos.x, playerPos.y - headPos.y)

            // Phase 4 lunge head does extra damage
            if bossState.phase == 4 && bossState.phase4SubState == .lunging {
                if headDist < config.headCollisionRadius + 20 {
                    contactMade = true
                    damageAmount = config.lungeHeadDamage
                    knockbackSource = headPos
                }
            } else if headDist < config.headCollisionRadius + 20 {
                contactMade = true
                damageAmount = config.headContactDamage
                knockbackSource = headPos
            }

            // Check body segments
            if !contactMade {
                for (i, seg) in bossState.segments.enumerated() {
                    // Skip ghost segment in Phase 2
                    if bossState.phase == 2 && i == bossState.ghostSegmentIndex { continue }

                    let segDist = hypot(playerPos.x - seg.x, playerPos.y - seg.y)
                    if segDist < config.bodyCollisionRadius + 20 {
                        contactMade = true
                        damageAmount = config.bodyContactDamage
                        knockbackSource = seg.cgPoint
                        break
                    }
                }
            }
        }

        if contactMade {
            PlayerSystem.damagePlayer(state: &gameState, rawDamage: damageAmount)
            bossState.lastContactDamageTime = currentTime

            // Knockback
            let angle = atan2(playerPos.y - knockbackSource.y, playerPos.x - knockbackSource.x)
            let knockback = config.bodyKnockbackStrength
            gameState.player.x += cos(angle) * knockback
            gameState.player.y += sin(angle) * knockback
        }
    }

    // MARK: - Helpers

    /// Update body segments using drag chain kinematics
    static func updateSegments(head: CGPoint, segments: inout [Segment], spacing: CGFloat) {
        var leader = head

        for i in 0..<segments.count {
            let dx = leader.x - segments[i].x
            let dy = leader.y - segments[i].y
            let dist = sqrt(dx * dx + dy * dy)

            if dist > spacing {
                let angle = atan2(dy, dx)
                segments[i].x = leader.x - cos(angle) * spacing
                segments[i].y = leader.y - sin(angle) * spacing
            }

            leader = CGPoint(x: segments[i].x, y: segments[i].y)
        }
    }

    private static func normalizeAngle(_ angle: CGFloat) -> CGFloat {
        var a = angle
        while a > .pi { a -= 2 * .pi }
        while a < -.pi { a += 2 * .pi }
        return a
    }
}
