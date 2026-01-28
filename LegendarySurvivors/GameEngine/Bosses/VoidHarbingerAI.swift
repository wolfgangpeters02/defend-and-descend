import Foundation
import CoreGraphics

// MARK: - Void Harbinger AI

/// WoW-style Raid Boss with 4 phases, pylons, void rifts, gravity wells, and shrinking arena
class VoidHarbingerAI {

    // MARK: - State

    struct VoidHarbingerState {
        var phase: Int = 1

        // Phase 1
        var voidZones: [VoidZone] = []
        var lastVoidZoneTime: Double = 0
        var voidZoneInterval: Double = 8.0

        var lastVolleyTime: Double = 0
        var volleyInterval: Double = 6.0

        var lastMinionSpawnTime: Double = 0
        var minionSpawnInterval: Double = 15.0

        // Phase 2 (Pylon phase)
        var pylons: [Pylon] = []
        var pylonsDestroyed: Int = 0
        var isInvulnerable: Bool = false

        // Phase 3
        var voidRifts: [VoidRift] = []
        var gravityWells: [GravityWell] = []
        var lastMeteorTime: Double = 0
        var meteorInterval: Double = 6.0

        var lastEliteMinionTime: Double = 0
        var eliteMinionInterval: Double = 20.0

        // Phase 4 (Enrage)
        var lastTeleportTime: Double = 0
        var teleportInterval: Double = 3.0

        var arenaRadius: CGFloat = 1500
        var minArenaRadius: CGFloat = 150
        var arenaShrinkRate: CGFloat = 30 // pixels per second
        var arenaCenter: CGPoint = .zero
    }

    struct VoidZone {
        let id: String
        var x: CGFloat
        var y: CGFloat
        var radius: CGFloat
        var warningTime: Double // 2 sec warning before active
        var activeTime: Double // 5 sec active duration
        var lifetime: Double
        var isActive: Bool
        let damage: CGFloat
    }

    struct Pylon: Identifiable {
        let id: String
        var x: CGFloat
        var y: CGFloat
        var health: CGFloat
        var maxHealth: CGFloat
        var lastBeamTime: Double
        let beamInterval: Double
        var isDestroyed: Bool
    }

    struct VoidRift {
        let id: String
        var angle: CGFloat
        let distanceFromCenter: CGFloat
        let rotationSpeed: CGFloat // degrees per second
        let width: CGFloat
        let damage: CGFloat
    }

    struct GravityWell {
        let id: String
        var x: CGFloat
        var y: CGFloat
        let pullRadius: CGFloat
        let pullStrength: CGFloat
    }

    struct MeteorStrike {
        let id: String
        var x: CGFloat
        var y: CGFloat
        var warningTime: Double
        var hasImpacted: Bool
        let impactRadius: CGFloat
        let damage: CGFloat
    }

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
        // Determine phase based on health
        let healthPercent = boss.health / boss.maxHealth

        if healthPercent <= 0.1 {
            if bossState.phase != 4 {
                enterPhase4(bossState: &bossState, boss: boss)
            }
            bossState.phase = 4
        } else if healthPercent <= 0.4 {
            if bossState.phase != 3 {
                enterPhase3(bossState: &bossState, boss: boss)
            }
            bossState.phase = 3
        } else if healthPercent <= 0.7 {
            if bossState.phase != 2 && bossState.pylonsDestroyed < 4 {
                enterPhase2(bossState: &bossState, boss: boss, gameState: gameState)
            }
            // Stay in phase 2 until all pylons destroyed
            if bossState.phase == 2 && bossState.pylonsDestroyed >= 4 {
                bossState.isInvulnerable = false
            } else {
                bossState.phase = 2
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
        gameState: GameState
    ) {
        bossState.isInvulnerable = true
        bossState.pylonsDestroyed = 0

        // Spawn 4 pylons around the arena
        let arenaWidth = gameState.arena.width
        let arenaHeight = gameState.arena.height
        let center = CGPoint(x: arenaWidth / 2, y: arenaHeight / 2)

        bossState.pylons = []
        let pylonPositions: [(CGFloat, CGFloat)] = [
            (center.x - 400, center.y - 400),
            (center.x + 400, center.y - 400),
            (center.x - 400, center.y + 400),
            (center.x + 400, center.y + 400)
        ]

        for pos in pylonPositions {
            bossState.pylons.append(Pylon(
                id: RandomUtils.generateId(),
                x: pos.0,
                y: pos.1,
                health: 500,
                maxHealth: 500,
                lastBeamTime: 0,
                beamInterval: 3.0,
                isDestroyed: false
            ))
        }
    }

    private static func enterPhase3(bossState: inout VoidHarbingerState, boss: Enemy) {
        bossState.isInvulnerable = false

        // Create 3 rotating void rifts
        bossState.voidRifts = []
        for i in 0..<3 {
            bossState.voidRifts.append(VoidRift(
                id: RandomUtils.generateId(),
                angle: CGFloat(i) * 120,
                distanceFromCenter: 200,
                rotationSpeed: 45,
                width: 40,
                damage: 50
            ))
        }

        // Create 2 gravity wells
        bossState.gravityWells = [
            GravityWell(
                id: RandomUtils.generateId(),
                x: bossState.arenaCenter.x - 300,
                y: bossState.arenaCenter.y,
                pullRadius: 250,
                pullStrength: 50
            ),
            GravityWell(
                id: RandomUtils.generateId(),
                x: bossState.arenaCenter.x + 300,
                y: bossState.arenaCenter.y,
                pullRadius: 250,
                pullStrength: 50
            )
        ]
    }

    private static func enterPhase4(bossState: inout VoidHarbingerState, boss: Enemy) {
        // Start shrinking arena
        bossState.voidZoneInterval = 2.0 // Faster void zones
    }

    // MARK: - Phase Updates

    private static func updatePhase1(
        boss: inout Enemy,
        bossState: inout VoidHarbingerState,
        gameState: inout GameState,
        deltaTime: TimeInterval
    ) {
        // Chase player slowly
        moveTowardsPlayer(boss: &boss, gameState: gameState, speedMultiplier: 0.6)

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
            spawnVoidMinions(count: 4, near: boss, gameState: &gameState)
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
        moveTowardsPlayer(boss: &boss, gameState: gameState, speedMultiplier: 0.8)

        // Void zones
        if gameState.gameTime - bossState.lastVoidZoneTime >= bossState.voidZoneInterval {
            bossState.lastVoidZoneTime = gameState.gameTime
            spawnVoidZone(at: CGPoint(x: gameState.player.x, y: gameState.player.y), bossState: &bossState)
        }

        // Meteor strikes
        if gameState.gameTime - bossState.lastMeteorTime >= bossState.meteorInterval {
            bossState.lastMeteorTime = gameState.gameTime
            // Create meteor warning at player position
            spawnVoidZone(
                at: CGPoint(x: gameState.player.x + CGFloat.random(in: -100...100),
                           y: gameState.player.y + CGFloat.random(in: -100...100)),
                bossState: &bossState,
                radius: 100,
                damage: 80
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
        let maxOffset = bossState.arenaRadius * 0.6
        boss.x = bossState.arenaCenter.x + CGFloat.random(in: -maxOffset...maxOffset)
        boss.y = bossState.arenaCenter.y + CGFloat.random(in: -maxOffset...maxOffset)
    }

    // MARK: - Attacks

    private static func spawnVoidZone(
        at position: CGPoint,
        bossState: inout VoidHarbingerState,
        radius: CGFloat = 80,
        damage: CGFloat = 40
    ) {
        let zone = VoidZone(
            id: RandomUtils.generateId(),
            x: position.x,
            y: position.y,
            radius: radius,
            warningTime: 2.0,
            activeTime: 5.0,
            lifetime: 0,
            isActive: false,
            damage: damage
        )
        bossState.voidZones.append(zone)
    }

    private static func fireShadowBoltVolley(boss: Enemy, gameState: inout GameState) {
        // Fire 8 projectiles in a spread
        let projectileCount = 8
        let baseAngle = atan2(gameState.player.y - boss.y, gameState.player.x - boss.x)

        for i in 0..<projectileCount {
            let angleOffset = CGFloat(i - projectileCount / 2) * 0.2
            let angle = baseAngle + angleOffset

            let projectile = Projectile(
                id: RandomUtils.generateId(),
                weaponId: "void_bolt",
                x: boss.x,
                y: boss.y,
                velocityX: cos(angle) * 350,
                velocityY: sin(angle) * 350,
                damage: 20,
                radius: 10,
                color: "#8800ff",
                lifetime: 4.0,
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
        for _ in 0..<count {
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let distance: CGFloat = CGFloat.random(in: 100...200)

            let x = boss.x + cos(angle) * distance
            let y = boss.y + sin(angle) * distance

            // Create void minion (custom fast enemy type)
            let enemy = Enemy(
                id: RandomUtils.generateId(),
                type: "void_minion",
                x: x,
                y: y,
                health: 30,
                maxHealth: 30,
                damage: 10,
                speed: 120,
                xpValue: 5,
                color: "#6600aa",
                velocityX: 0,
                velocityY: 0
            )
            gameState.enemies.append(enemy)
        }
    }

    private static func spawnEliteMinion(near boss: Enemy, gameState: inout GameState) {
        let angle = CGFloat.random(in: 0...(2 * .pi))
        let distance: CGFloat = 150

        let enemy = Enemy(
            id: RandomUtils.generateId(),
            type: "void_elite",
            x: boss.x + cos(angle) * distance,
            y: boss.y + sin(angle) * distance,
            health: 200,
            maxHealth: 200,
            damage: 25,
            speed: 80,
            xpValue: 50,
            color: "#aa00ff",
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
                   gameState.player.invulnerableUntil < gameState.gameTime {
                    gameState.player.health -= mutableZone.damage * CGFloat(deltaTime)
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
                velocityX: (dx / distance) * 400,
                velocityY: (dy / distance) * 400,
                damage: 30,
                radius: 8,
                color: "#ff00aa",
                lifetime: 3.0,
                piercing: 0,
                hitEnemies: [],
                isHoming: true,
                homingStrength: 2.0,
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
            let riftEndX = center.x + cos(angleRad) * 500
            let riftEndY = center.y + sin(angleRad) * 500

            let distance = pointToLineDistance(
                px: gameState.player.x, py: gameState.player.y,
                x1: riftStartX, y1: riftStartY,
                x2: riftEndX, y2: riftEndY
            )

            if distance < rift.width / 2 + 15 && // 15 = player radius
               gameState.player.invulnerableUntil < gameState.gameTime {
                gameState.player.health -= rift.damage * CGFloat(deltaTime)
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
            // 40 damage per second outside
            gameState.player.health -= 40 * CGFloat(deltaTime)

            // Push player back towards center
            if distanceFromCenter > 0 {
                let pushStrength: CGFloat = 100
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
