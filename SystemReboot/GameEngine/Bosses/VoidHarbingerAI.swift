import Foundation
import CoreGraphics

// MARK: - Void Harbinger AI

/// WoW-style Raid Boss with 4 phases, pylons, void rifts, gravity wells, and shrinking arena
class VoidHarbingerAI {

    // State types defined in BossStates.swift

    // MARK: - Initialization

    static func createInitialState(arenaCenter: CGPoint) -> VoidHarbingerState {
        var state = VoidHarbingerState()
        state.arenaCenter = arenaCenter
        return state
    }

    // MARK: - Main Update

    static func update(
        boss: inout Enemy,
        bossState: inout VoidHarbingerState,
        gameState: inout GameState,
        deltaTime: TimeInterval
    ) {
        // Determine target phase based on health (advance one phase at a time to prevent skipping)
        let healthPercent = boss.health / boss.maxHealth
        let targetPhase: Int = healthPercent <= BalanceConfig.VoidHarbinger.phase4Threshold ? 4 :
                               healthPercent <= BalanceConfig.VoidHarbinger.phase3Threshold ? 3 :
                               healthPercent <= BalanceConfig.VoidHarbinger.phase2Threshold ? 2 : 1

        // Phase 2 pylon check: clear invulnerability when all pylons destroyed
        // Must run outside phase advancement since boss takes no damage while invulnerable
        if bossState.phase == 2 && bossState.pylonsDestroyed >= 4 {
            bossState.isInvulnerable = false
        }

        if targetPhase > bossState.phase {
            // Phase 2 locks until all pylons are destroyed
            if bossState.phase == 2 && bossState.pylonsDestroyed < 4 {
                // Stay in phase 2 — don't advance
            } else {
                let nextPhase = bossState.phase + 1
                switch nextPhase {
                case 2: enterPhase2(bossState: &bossState, boss: boss, gameState: &gameState)
                case 3: enterPhase3(bossState: &bossState, boss: boss)
                case 4: enterPhase4(bossState: &bossState, boss: boss)
                default: break
                }
                bossState.phase = nextPhase
            }
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

        // Apply movement (convert velocity to position)
        applyMovement(boss: &boss, gameState: &gameState, deltaTime: deltaTime)

        // Update void zones
        updateVoidZones(bossState: &bossState, gameState: &gameState, deltaTime: deltaTime)

        // Update pylons
        updatePylons(bossState: &bossState, gameState: &gameState, deltaTime: deltaTime)

        // Update void rifts
        updateVoidRifts(bossState: &bossState, gameState: &gameState, deltaTime: deltaTime)

        // Update gravity wells
        applyGravityWells(bossState: bossState, gameState: &gameState, deltaTime: deltaTime)

        // Update shrinking arena (Phase 4)
        if bossState.phase == 4 {
            updateShrinkingArena(bossState: &bossState, gameState: &gameState, deltaTime: deltaTime)
        }
    }

    // MARK: - Phase Transitions

    private static func enterPhase2(
        bossState: inout VoidHarbingerState,
        boss: Enemy,
        gameState: inout GameState
    ) {
        bossState.isInvulnerable = true
        bossState.pylonsDestroyed = 0

        // Spawn 4 pylons around the arena
        let arenaWidth = gameState.arena.width
        let arenaHeight = gameState.arena.height
        let center = CGPoint(x: arenaWidth / 2, y: arenaHeight / 2)

        bossState.pylons = []
        // Spread pylons wider for larger arenas
        let offsetX = BalanceConfig.VoidHarbinger.pylonOffsetX
        let offsetY = BalanceConfig.VoidHarbinger.pylonOffsetY
        let pylonPositions: [(CGFloat, CGFloat)] = [
            (center.x - offsetX, center.y - offsetY),
            (center.x + offsetX, center.y - offsetY),
            (center.x - offsetX, center.y + offsetY),
            (center.x + offsetX, center.y + offsetY)
        ]

        for pos in pylonPositions {
            let pylonId = RandomUtils.generateId()

            // Add pylon to boss state (for tracking beams, etc.)
            bossState.pylons.append(Pylon(
                id: pylonId,
                x: pos.0,
                y: pos.1,
                health: BalanceConfig.VoidHarbinger.pylonHealth,
                maxHealth: BalanceConfig.VoidHarbinger.pylonHealth,
                lastBeamTime: 0,
                beamInterval: BalanceConfig.VoidHarbinger.pylonBeamInterval,
                isDestroyed: false
            ))

            // ALSO spawn as Enemy so auto-targeting works
            var pylonEnemy = Enemy(
                id: pylonId,  // Same ID as pylon for easy linking
                type: "void_pylon",
                x: pos.0,
                y: pos.1,
                health: BalanceConfig.VoidHarbinger.pylonHealth,
                maxHealth: BalanceConfig.VoidHarbinger.pylonHealth,
                damage: 0,  // Pylons don't deal contact damage
                speed: 0,   // Pylons don't move
                xpValue: BalanceConfig.VoidHarbinger.pylonXP,
                color: BalanceConfig.VoidHarbinger.pylonColor
            )
            pylonEnemy.pylonId = pylonId
            pylonEnemy.size = BalanceConfig.VoidHarbinger.pylonSize
            gameState.enemies.append(pylonEnemy)
        }
    }

    private static func enterPhase3(bossState: inout VoidHarbingerState, boss: Enemy) {
        bossState.isInvulnerable = false

        // Create rotating void rifts
        let riftCount = BalanceConfig.VoidHarbinger.voidRiftCount
        let angleStep = 360.0 / CGFloat(riftCount)
        bossState.voidRifts = []
        for i in 0..<riftCount {
            bossState.voidRifts.append(VoidRift(
                id: RandomUtils.generateId(),
                angle: CGFloat(i) * angleStep,
                distanceFromCenter: BalanceConfig.VoidHarbinger.voidRiftDistance,
                rotationSpeed: BalanceConfig.VoidHarbinger.voidRiftRotationSpeed,
                width: BalanceConfig.VoidHarbinger.voidRiftWidth,
                damage: BalanceConfig.VoidHarbinger.voidRiftDamage
            ))
        }

        // Create gravity wells
        let gravityOffset = BalanceConfig.VoidHarbinger.gravityWellOffsetX
        bossState.gravityWells = [
            GravityWell(
                id: RandomUtils.generateId(),
                x: bossState.arenaCenter.x - gravityOffset,
                y: bossState.arenaCenter.y,
                pullRadius: BalanceConfig.VoidHarbinger.gravityWellPullRadius,
                pullStrength: BalanceConfig.VoidHarbinger.gravityWellPullStrength
            ),
            GravityWell(
                id: RandomUtils.generateId(),
                x: bossState.arenaCenter.x + gravityOffset,
                y: bossState.arenaCenter.y,
                pullRadius: BalanceConfig.VoidHarbinger.gravityWellPullRadius,
                pullStrength: BalanceConfig.VoidHarbinger.gravityWellPullStrength
            )
        ]
    }

    private static func enterPhase4(bossState: inout VoidHarbingerState, boss: Enemy) {
        // Start shrinking arena
        bossState.voidZoneInterval = BalanceConfig.VoidHarbinger.voidZoneIntervalPhase4
    }

    // MARK: - Phase Updates

    private static func updatePhase1(
        boss: inout Enemy,
        bossState: inout VoidHarbingerState,
        gameState: inout GameState,
        deltaTime: TimeInterval
    ) {
        // Chase player slowly
        moveTowardsPlayer(boss: &boss, gameState: gameState, speedMultiplier: BalanceConfig.VoidHarbinger.phase1ChaseMultiplier)

        // Spawn void zones
        if gameState.gameTime - bossState.lastVoidZoneTime >= bossState.voidZoneInterval {
            bossState.lastVoidZoneTime = gameState.gameTime
            spawnVoidZone(at: CGPoint(x: gameState.player.x, y: gameState.player.y), bossState: &bossState)
        }

        // Shadow bolt volley
        if gameState.gameTime - bossState.lastVolleyTime >= bossState.volleyInterval {
            bossState.lastVolleyTime = gameState.gameTime
            fireShadowBoltVolley(boss: boss, gameState: &gameState)
        }

        // Spawn minions
        if gameState.gameTime - bossState.lastMinionSpawnTime >= bossState.minionSpawnInterval {
            bossState.lastMinionSpawnTime = gameState.gameTime
            spawnVoidMinions(count: BalanceConfig.VoidHarbinger.minionCount, near: boss, gameState: &gameState)
        }
    }

    private static func updatePhase2(
        boss: inout Enemy,
        bossState: inout VoidHarbingerState,
        gameState: inout GameState,
        deltaTime: TimeInterval
    ) {
        // Boss stays in center and is invulnerable
        let center = bossState.arenaCenter
        boss.x = center.x
        boss.y = center.y
        boss.velocityX = 0
        boss.velocityY = 0

        // Pylons fire beams at player
        // (handled in updatePylons)
    }

    private static func updatePhase3(
        boss: inout Enemy,
        bossState: inout VoidHarbingerState,
        gameState: inout GameState,
        deltaTime: TimeInterval
    ) {
        // Continue phase 1 behavior
        moveTowardsPlayer(boss: &boss, gameState: gameState, speedMultiplier: BalanceConfig.VoidHarbinger.phase3ChaseMultiplier)

        // Void zones
        if gameState.gameTime - bossState.lastVoidZoneTime >= bossState.voidZoneInterval {
            bossState.lastVoidZoneTime = gameState.gameTime
            spawnVoidZone(at: CGPoint(x: gameState.player.x, y: gameState.player.y), bossState: &bossState)
        }

        // Meteor strikes
        if gameState.gameTime - bossState.lastMeteorTime >= bossState.meteorInterval {
            bossState.lastMeteorTime = gameState.gameTime
            // Create meteor warning at player position
            let offset = BalanceConfig.VoidHarbinger.meteorSpawnOffset
            spawnVoidZone(
                at: CGPoint(x: gameState.player.x + CGFloat.random(in: -offset...offset),
                           y: gameState.player.y + CGFloat.random(in: -offset...offset)),
                bossState: &bossState,
                radius: BalanceConfig.VoidHarbinger.meteorRadius,
                damage: BalanceConfig.VoidHarbinger.meteorDamage
            )
        }

        // Elite minions
        if gameState.gameTime - bossState.lastEliteMinionTime >= bossState.eliteMinionInterval {
            bossState.lastEliteMinionTime = gameState.gameTime
            spawnEliteMinion(near: boss, gameState: &gameState)
        }
    }

    private static func updatePhase4(
        boss: inout Enemy,
        bossState: inout VoidHarbingerState,
        gameState: inout GameState,
        deltaTime: TimeInterval
    ) {
        // Continue phase 3 mechanics
        updatePhase3(boss: &boss, bossState: &bossState, gameState: &gameState, deltaTime: deltaTime)

        // Random teleports
        if gameState.gameTime - bossState.lastTeleportTime >= bossState.teleportInterval {
            bossState.lastTeleportTime = gameState.gameTime
            teleportBoss(boss: &boss, bossState: bossState)
        }
    }

    // MARK: - Movement

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

    private static func teleportBoss(boss: inout Enemy, bossState: VoidHarbingerState) {
        let maxOffset = bossState.arenaRadius * BalanceConfig.VoidHarbinger.teleportOffsetRatio
        boss.x = bossState.arenaCenter.x + CGFloat.random(in: -maxOffset...maxOffset)
        boss.y = bossState.arenaCenter.y + CGFloat.random(in: -maxOffset...maxOffset)
    }

    /// Apply velocity to position (with arena bounds checking)
    private static func applyMovement(
        boss: inout Enemy,
        gameState: inout GameState,
        deltaTime: TimeInterval
    ) {
        // Calculate new position from velocity
        let moveX = boss.velocityX * CGFloat(deltaTime)
        let moveY = boss.velocityY * CGFloat(deltaTime)

        var newX = boss.x + moveX
        var newY = boss.y + moveY

        let bossSize = boss.size ?? BalanceConfig.EnemyDefaults.bossSize

        // Keep boss within arena bounds
        let margin: CGFloat = bossSize
        newX = max(margin, min(gameState.arena.width - margin, newX))
        newY = max(margin, min(gameState.arena.height - margin, newY))

        boss.x = newX
        boss.y = newY
    }

    // MARK: - Attacks

    private static func spawnVoidZone(
        at position: CGPoint,
        bossState: inout VoidHarbingerState,
        radius: CGFloat = BalanceConfig.VoidHarbinger.voidZoneRadius,
        damage: CGFloat = BalanceConfig.VoidHarbinger.voidZoneDamage
    ) {
        let zone = VoidZone(
            id: RandomUtils.generateId(),
            x: position.x,
            y: position.y,
            radius: radius,
            warningTime: BalanceConfig.VoidHarbinger.voidZoneWarningTime,
            activeTime: BalanceConfig.VoidHarbinger.voidZoneActiveTime,
            lifetime: 0,
            isActive: false,
            damage: damage
        )
        bossState.voidZones.append(zone)
    }

    private static func fireShadowBoltVolley(boss: Enemy, gameState: inout GameState) {
        // Fire projectiles in a spread
        let projectileCount = BalanceConfig.VoidHarbinger.volleyProjectileCount
        let baseAngle = atan2(gameState.player.y - boss.y, gameState.player.x - boss.x)

        for i in 0..<projectileCount {
            let angleOffset = CGFloat(i - projectileCount / 2) * BalanceConfig.VoidHarbinger.volleySpreadAngle
            let angle = baseAngle + angleOffset

            let projectile = Projectile(
                id: RandomUtils.generateId(),
                weaponId: "void_bolt",
                x: boss.x,
                y: boss.y,
                velocityX: cos(angle) * BalanceConfig.VoidHarbinger.volleyProjectileSpeed,
                velocityY: sin(angle) * BalanceConfig.VoidHarbinger.volleyProjectileSpeed,
                damage: BalanceConfig.VoidHarbinger.volleyProjectileDamage,
                radius: BalanceConfig.VoidHarbinger.volleyProjectileRadius,
                color: BalanceConfig.VoidHarbinger.volleyProjectileColor,
                lifetime: BalanceConfig.VoidHarbinger.volleyProjectileLifetime,
                piercing: 0,
                hitEnemies: [],
                isHoming: false,
                homingStrength: 0,
                isEnemyProjectile: true
            )
            gameState.projectiles.append(projectile)
        }
    }

    private static func spawnVoidMinions(count: Int, near boss: Enemy, gameState: inout GameState) {
        let currentMinions = gameState.enemies.filter {
            $0.type == EnemyID.voidMinionSpawn.rawValue || $0.type == EnemyID.voidElite.rawValue
        }.count
        let allowed = max(0, BalanceConfig.VoidHarbinger.maxMinionsOnScreen - currentMinions)
        let spawnCount = min(count, allowed)

        for _ in 0..<spawnCount {
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let distance = CGFloat.random(in: BalanceConfig.VoidHarbinger.minionSpawnDistanceMin...BalanceConfig.VoidHarbinger.minionSpawnDistanceMax)

            let x = boss.x + cos(angle) * distance
            let y = boss.y + sin(angle) * distance

            let enemy = Enemy(
                id: RandomUtils.generateId(),
                type: "void_minion",
                x: x,
                y: y,
                health: BalanceConfig.VoidHarbinger.minionHealth,
                maxHealth: BalanceConfig.VoidHarbinger.minionHealth,
                damage: BalanceConfig.VoidHarbinger.minionDamage,
                speed: BalanceConfig.VoidHarbinger.minionSpeed,
                xpValue: BalanceConfig.VoidHarbinger.minionXP,
                color: BalanceConfig.VoidHarbinger.minionColor,
                velocityX: 0,
                velocityY: 0
            )
            gameState.enemies.append(enemy)
        }
    }

    private static func spawnEliteMinion(near boss: Enemy, gameState: inout GameState) {
        let currentMinions = gameState.enemies.filter {
            $0.type == EnemyID.voidMinionSpawn.rawValue || $0.type == EnemyID.voidElite.rawValue
        }.count
        guard currentMinions < BalanceConfig.VoidHarbinger.maxMinionsOnScreen else { return }

        let angle = CGFloat.random(in: 0...(2 * .pi))
        let distance = BalanceConfig.VoidHarbinger.eliteMinionSpawnDistance

        let enemy = Enemy(
            id: RandomUtils.generateId(),
            type: "void_elite",
            x: boss.x + cos(angle) * distance,
            y: boss.y + sin(angle) * distance,
            health: BalanceConfig.VoidHarbinger.eliteMinionHealth,
            maxHealth: BalanceConfig.VoidHarbinger.eliteMinionHealth,
            damage: BalanceConfig.VoidHarbinger.eliteMinionDamage,
            speed: BalanceConfig.VoidHarbinger.eliteMinionSpeed,
            xpValue: BalanceConfig.VoidHarbinger.eliteMinionXP,
            color: BalanceConfig.VoidHarbinger.eliteMinionColor,
            velocityX: 0,
            velocityY: 0
        )
        gameState.enemies.append(enemy)
    }

    // MARK: - Void Zone Updates

    private static func updateVoidZones(
        bossState: inout VoidHarbingerState,
        gameState: inout GameState,
        deltaTime: TimeInterval
    ) {
        bossState.voidZones = bossState.voidZones.compactMap { zone in
            var mutableZone = zone
            mutableZone.lifetime += deltaTime

            // Check if warning period ended
            if !mutableZone.isActive && mutableZone.lifetime >= mutableZone.warningTime {
                mutableZone.isActive = true
            }

            // Check if zone expired
            if mutableZone.lifetime >= mutableZone.warningTime + mutableZone.activeTime {
                return nil
            }

            // Apply damage if active
            if mutableZone.isActive {
                let dx = gameState.player.x - mutableZone.x
                let dy = gameState.player.y - mutableZone.y
                let distance = sqrt(dx * dx + dy * dy)

                if distance < mutableZone.radius &&
                   gameState.player.invulnerableUntil < gameState.currentFrameTime {
                    PlayerSystem.damagePlayer(state: &gameState, rawDamage: mutableZone.damage * CGFloat(deltaTime))
                }
            }

            return mutableZone
        }
    }

    // MARK: - Pylon Updates

    private static func updatePylons(
        bossState: inout VoidHarbingerState,
        gameState: inout GameState,
        deltaTime: TimeInterval
    ) {
        guard bossState.phase == 2 else { return }

        for i in 0..<bossState.pylons.count {
            guard !bossState.pylons[i].isDestroyed else { continue }

            // Fire beam at player
            if gameState.gameTime - bossState.pylons[i].lastBeamTime >= bossState.pylons[i].beamInterval {
                bossState.pylons[i].lastBeamTime = gameState.gameTime
                firePylonBeam(pylon: bossState.pylons[i], gameState: &gameState)
            }

            // Check if pylon takes damage from player projectiles
            // (This would be handled in the main projectile collision system)
        }

        // Count destroyed pylons
        bossState.pylonsDestroyed = bossState.pylons.filter { $0.isDestroyed }.count
    }

    private static func firePylonBeam(pylon: Pylon, gameState: inout GameState) {
        let dx = gameState.player.x - pylon.x
        let dy = gameState.player.y - pylon.y
        let distance = sqrt(dx * dx + dy * dy)

        if distance > 0 {
            let projectile = Projectile(
                id: RandomUtils.generateId(),
                weaponId: "pylon_beam",
                x: pylon.x,
                y: pylon.y,
                velocityX: (dx / distance) * BalanceConfig.VoidHarbinger.pylonBeamSpeed,
                velocityY: (dy / distance) * BalanceConfig.VoidHarbinger.pylonBeamSpeed,
                damage: BalanceConfig.VoidHarbinger.pylonBeamDamage,
                radius: BalanceConfig.VoidHarbinger.pylonBeamRadius,
                color: BalanceConfig.VoidHarbinger.pylonBeamColor,
                lifetime: BalanceConfig.VoidHarbinger.pylonBeamLifetime,
                piercing: 0,
                hitEnemies: [],
                isHoming: true,
                homingStrength: BalanceConfig.VoidHarbinger.pylonBeamHomingStrength,
                isEnemyProjectile: true
            )
            gameState.projectiles.append(projectile)
        }
    }

    /// Damage a pylon (called from projectile collision system)
    static func damagePylon(pylonId: String, damage: CGFloat, bossState: inout VoidHarbingerState) {
        for i in 0..<bossState.pylons.count {
            if bossState.pylons[i].id == pylonId && !bossState.pylons[i].isDestroyed {
                bossState.pylons[i].health -= damage
                if bossState.pylons[i].health <= 0 {
                    bossState.pylons[i].isDestroyed = true
                }
                break
            }
        }
    }

    // MARK: - Void Rift Updates

    private static func updateVoidRifts(
        bossState: inout VoidHarbingerState,
        gameState: inout GameState,
        deltaTime: TimeInterval
    ) {
        guard bossState.phase >= 3 else { return }

        let center = bossState.arenaCenter

        for i in 0..<bossState.voidRifts.count {
            // Rotate rift
            bossState.voidRifts[i].angle += bossState.voidRifts[i].rotationSpeed * CGFloat(deltaTime)
            if bossState.voidRifts[i].angle >= 360 {
                bossState.voidRifts[i].angle -= 360
            }

            // Check player collision
            let rift = bossState.voidRifts[i]
            let angleRad = rift.angle * .pi / 180

            // Rift extends from center
            let riftStartX = center.x
            let riftStartY = center.y
            let riftEndX = center.x + cos(angleRad) * BalanceConfig.VoidHarbinger.voidRiftLength
            let riftEndY = center.y + sin(angleRad) * BalanceConfig.VoidHarbinger.voidRiftLength

            let distance = pointToLineDistance(
                px: gameState.player.x, py: gameState.player.y,
                x1: riftStartX, y1: riftStartY,
                x2: riftEndX, y2: riftEndY
            )

            if distance < rift.width / 2 + BalanceConfig.Player.size &&
               gameState.player.invulnerableUntil < gameState.currentFrameTime {
                PlayerSystem.damagePlayer(state: &gameState, rawDamage: rift.damage * CGFloat(deltaTime))
            }
        }
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

    // MARK: - Gravity Well Updates

    private static func applyGravityWells(
        bossState: VoidHarbingerState,
        gameState: inout GameState,
        deltaTime: TimeInterval
    ) {
        guard bossState.phase >= 3 else { return }

        for well in bossState.gravityWells {
            let dx = well.x - gameState.player.x
            let dy = well.y - gameState.player.y
            let distance = sqrt(dx * dx + dy * dy)

            if distance < well.pullRadius && distance > 0 {
                // Apply pull force
                let pullForce = well.pullStrength * (1 - distance / well.pullRadius)
                gameState.player.x += (dx / distance) * pullForce * CGFloat(deltaTime)
                gameState.player.y += (dy / distance) * pullForce * CGFloat(deltaTime)
            }
        }
    }

    // MARK: - Shrinking Arena

    private static func updateShrinkingArena(
        bossState: inout VoidHarbingerState,
        gameState: inout GameState,
        deltaTime: TimeInterval
    ) {
        // Shrink arena
        if bossState.arenaRadius > bossState.minArenaRadius {
            bossState.arenaRadius -= bossState.arenaShrinkRate * CGFloat(deltaTime)
            bossState.arenaRadius = max(bossState.arenaRadius, bossState.minArenaRadius)
        }

        // Damage player if outside arena
        let dx = gameState.player.x - bossState.arenaCenter.x
        let dy = gameState.player.y - bossState.arenaCenter.y
        let distanceFromCenter = sqrt(dx * dx + dy * dy)

        if distanceFromCenter > bossState.arenaRadius {
            // Damage per second outside
            PlayerSystem.damagePlayer(state: &gameState, rawDamage: BalanceConfig.VoidHarbinger.outsideArenaDPS * CGFloat(deltaTime))

            // Push player back towards center
            if distanceFromCenter > 0 {
                let pushStrength = BalanceConfig.VoidHarbinger.outsideArenaPushStrength
                gameState.player.x -= (dx / distanceFromCenter) * pushStrength * CGFloat(deltaTime)
                gameState.player.y -= (dy / distanceFromCenter) * pushStrength * CGFloat(deltaTime)
            }
        }
    }

    // MARK: - Rendering Data

    static func getRenderData(
        bossState: VoidHarbingerState,
        boss: Enemy
    ) -> VoidHarbingerRenderData {
        return VoidHarbingerRenderData(
            phase: bossState.phase,
            voidZones: bossState.voidZones,
            pylons: bossState.pylons,
            voidRifts: bossState.voidRifts,
            gravityWells: bossState.gravityWells,
            arenaRadius: bossState.arenaRadius,
            arenaCenter: bossState.arenaCenter,
            isInvulnerable: bossState.isInvulnerable,
            bossX: boss.x,
            bossY: boss.y
        )
    }

    struct VoidHarbingerRenderData {
        let phase: Int
        let voidZones: [VoidZone]
        let pylons: [Pylon]
        let voidRifts: [VoidRift]
        let gravityWells: [GravityWell]
        let arenaRadius: CGFloat
        let arenaCenter: CGPoint
        let isInvulnerable: Bool
        let bossX: CGFloat
        let bossY: CGFloat
    }
}
