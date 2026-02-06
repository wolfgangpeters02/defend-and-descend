import Foundation
import CoreGraphics
import GameplayKit

// MARK: - Boss Fight Simulator
// Headless simulation of boss fights for balance testing

// MARK: - Helper for seeded random CGFloats

extension SeededRNG {
    func nextCGFloat(in range: ClosedRange<CGFloat>) -> CGFloat {
        let span = range.upperBound - range.lowerBound
        return range.lowerBound + CGFloat(nextDouble()) * span
    }
}

// MARK: - Configuration

struct BossSimulationConfig {
    let seed: UInt64
    let bossType: String                    // "cyberboss" or "void_harbinger"
    let difficulty: BossDifficulty
    let bot: BossBot
    let maxFightTime: TimeInterval          // Max fight duration before timeout
    let playerWeaponDamage: CGFloat         // Base player DPS
    let playerHealth: CGFloat               // Base player health
    let arenaSize: CGFloat                  // Arena width/height

    static let defaultConfig = BossSimulationConfig(
        seed: 42,
        bossType: "cyberboss",
        difficulty: .normal,
        bot: AggressiveBot(),
        maxFightTime: 300,
        playerWeaponDamage: 50,
        playerHealth: 200,
        arenaSize: 1500
    )
}

// MARK: - Result

struct BossSimulationResult {
    let bossType: String
    let difficulty: BossDifficulty
    let botName: String

    // Outcome
    var victory: Bool = false
    var fightDuration: TimeInterval = 0
    var playerHealthRemaining: CGFloat = 0
    var playerDeaths: Int = 0               // Times player would have died

    // Combat stats
    var totalDamageDealt: CGFloat = 0
    var totalDamageTaken: CGFloat = 0
    var minionKills: Int = 0
    var pylonsDestroyed: Int = 0

    // Phase tracking
    var timeInPhase: [Int: TimeInterval] = [1: 0, 2: 0, 3: 0, 4: 0]
    var phaseReached: Int = 1

    // Hazard avoidance
    var puddleHits: Int = 0
    var laserHits: Int = 0
    var voidZoneHits: Int = 0
    var projectileHits: Int = 0
    var riftHits: Int = 0

    // Summary
    var dps: CGFloat { totalDamageDealt / max(1, CGFloat(fightDuration)) }
    var damageTakenPerSecond: CGFloat { totalDamageTaken / max(1, CGFloat(fightDuration)) }
}

// MARK: - Simulator State

class BossSimulator {

    // Simulation state
    var currentTime: TimeInterval = 0
    var deltaTime: TimeInterval = 1.0 / 60.0  // 60 FPS simulation
    var rng: SeededRNG

    // Player state
    var playerX: CGFloat = 0
    var playerY: CGFloat = 0
    var playerHealth: CGFloat = 0
    var playerMaxHealth: CGFloat = 0
    var playerDamage: CGFloat = 0
    var playerSpeed: CGFloat = 200
    var playerInvulnerableUntil: TimeInterval = 0
    var playerAttackCooldown: TimeInterval = 0
    var playerAttackInterval: TimeInterval = 0.5

    // Boss state
    var bossX: CGFloat = 0
    var bossY: CGFloat = 0
    var bossHealth: CGFloat = 0
    var bossMaxHealth: CGFloat = 0
    var bossPhase: Int = 1
    var bossSpeed: CGFloat = 100
    var bossInvulnerable: Bool = false

    // Arena
    var arenaWidth: CGFloat = 1500
    var arenaHeight: CGFloat = 1500
    var arenaCenter: CGPoint { CGPoint(x: arenaWidth / 2, y: arenaHeight / 2) }

    // Hazards
    var puddles: [SimPuddle] = []
    var lasers: [SimLaser] = []
    var voidZones: [SimVoidZone] = []
    var projectiles: [SimProjectile] = []
    var minions: [SimMinion] = []
    var pylons: [SimPylon] = []
    var voidRifts: [SimVoidRift] = []
    var gravityWells: [SimGravityWell] = []

    // Cyberboss specific
    var cyberbossMode: CyberbossAI.CyberbossMode = .melee
    var modeTimer: TimeInterval = 0
    var lastMinionSpawn: TimeInterval = 0
    var lastPuddleSpawn: TimeInterval = 0
    var lastRangedAttack: TimeInterval = 0

    // Void Harbinger specific
    var lastVoidZoneSpawn: TimeInterval = 0
    var lastVolleyTime: TimeInterval = 0
    var lastMeteorTime: TimeInterval = 0
    var lastTeleportTime: TimeInterval = 0
    var shrinkingArenaRadius: CGFloat = 1500

    // Result tracking
    var result: BossSimulationResult

    // Config
    let config: BossSimulationConfig
    let bot: BossBot

    init(config: BossSimulationConfig) {
        self.config = config
        self.rng = SeededRNG(seed: config.seed)
        self.bot = config.bot
        self.result = BossSimulationResult(
            bossType: config.bossType,
            difficulty: config.difficulty,
            botName: config.bot.name
        )

        setupFight()
    }

    // MARK: - Setup

    private func setupFight() {
        arenaWidth = config.arenaSize
        arenaHeight = config.arenaSize

        // Player setup
        playerX = arenaWidth / 2
        playerY = arenaHeight * 0.8  // Start near bottom
        playerMaxHealth = config.playerHealth * config.difficulty.playerHealthMultiplier
        playerHealth = playerMaxHealth
        playerDamage = config.playerWeaponDamage * config.difficulty.playerDamageMultiplier

        // Boss setup
        bossX = arenaWidth / 2
        bossY = arenaHeight * 0.3  // Start near top
        bossMaxHealth = getBossBaseHealth() * config.difficulty.healthMultiplier
        bossHealth = bossMaxHealth
        bossSpeed = 100
        bossPhase = 1

        shrinkingArenaRadius = arenaWidth / 2
    }

    private func getBossBaseHealth() -> CGFloat {
        switch config.bossType {
        case "void_harbinger":
            return 5000
        default: // cyberboss
            return 4000
        }
    }

    // MARK: - Main Simulation Loop

    func run() -> BossSimulationResult {
        while currentTime < config.maxFightTime && !isGameOver() {
            update()
            currentTime += deltaTime
        }

        // Final results
        result.fightDuration = currentTime
        result.playerHealthRemaining = playerHealth
        result.victory = bossHealth <= 0
        result.phaseReached = bossPhase

        return result
    }

    private func isGameOver() -> Bool {
        return bossHealth <= 0 || playerHealth <= 0
    }

    private func update() {
        // Track phase time
        result.timeInPhase[bossPhase, default: 0] += deltaTime

        // Update boss phase
        updateBossPhase()

        // Update boss AI
        if config.bossType == "void_harbinger" {
            updateVoidHarbinger()
        } else {
            updateCyberboss()
        }

        // Get bot decision
        let context = createBotContext()
        let action = bot.decide(context: context)

        // Apply bot action
        applyBotAction(action)

        // Update hazards
        updateHazards()

        // Player attacks boss
        updatePlayerAttack()

        // Check hazard collisions
        checkHazardCollisions()
    }

    // MARK: - Phase Management

    private func updateBossPhase() {
        let healthPercent = bossHealth / bossMaxHealth

        if config.bossType == "void_harbinger" {
            if healthPercent <= 0.10 && bossPhase < 4 {
                bossPhase = 4
                enterVoidHarbingerPhase4()
            } else if healthPercent <= 0.40 && bossPhase < 3 {
                bossPhase = 3
                enterVoidHarbingerPhase3()
            } else if healthPercent <= 0.70 && bossPhase < 2 {
                bossPhase = 2
                enterVoidHarbingerPhase2()
            }
        } else {
            // Cyberboss
            if healthPercent <= 0.25 && bossPhase < 4 {
                bossPhase = 4
                enterCyberbossPhase4()
            } else if healthPercent <= 0.50 && bossPhase < 3 {
                bossPhase = 3
                enterCyberbossPhase3()
            } else if healthPercent <= 0.75 && bossPhase < 2 {
                bossPhase = 2
                enterCyberbossPhase2()
            }
        }
    }

    // MARK: - Cyberboss AI

    private func updateCyberboss() {
        switch bossPhase {
        case 1:
            updateCyberbossPhase1()
        case 2:
            updateCyberbossPhase2()
        case 3:
            updateCyberbossPhase3()
        case 4:
            updateCyberbossPhase4()
        default:
            break
        }
    }

    private func updateCyberbossPhase1() {
        // Mode switching
        modeTimer += deltaTime
        if modeTimer >= 5.0 {
            modeTimer = 0
            cyberbossMode = cyberbossMode == .melee ? .ranged : .melee
        }

        if cyberbossMode == .melee {
            // Chase player
            moveBossTowards(x: playerX, y: playerY, speed: bossSpeed * 1.2)
        } else {
            // Keep distance and shoot
            let dx = bossX - playerX
            let dy = bossY - playerY
            let dist = sqrt(dx * dx + dy * dy)

            if dist < 400 {
                moveBossAway(fromX: playerX, fromY: playerY, speed: bossSpeed * 0.6)
            } else if dist > 500 {
                moveBossTowards(x: playerX, y: playerY, speed: bossSpeed * 0.4)
            }

            // Fire ranged attack
            if currentTime - lastRangedAttack >= 1.2 {
                lastRangedAttack = currentTime
                fireRangedVolley()
            }
        }
    }

    private func updateCyberbossPhase2() {
        updateCyberbossPhase1()

        // Spawn minions
        if currentTime - lastMinionSpawn >= 8.0 {
            lastMinionSpawn = currentTime
            spawnMinions(count: 3)
        }
    }

    private func enterCyberbossPhase2() {
        // Phase 2 adds minions
    }

    private func updateCyberbossPhase3() {
        // Boss stationary, spawn puddles
        if currentTime - lastPuddleSpawn >= 2.0 {
            lastPuddleSpawn = currentTime
            spawnPuddles(count: rng.nextInt(in: 2...3))
        }

        // Reduced minion spawns
        if currentTime - lastMinionSpawn >= 10.0 {
            lastMinionSpawn = currentTime
            spawnMinions(count: 2)
        }
    }

    private func enterCyberbossPhase3() {
        // Stop moving
    }

    private func updateCyberbossPhase4() {
        // Rotating lasers
        for i in 0..<lasers.count {
            lasers[i].angle += 25 * CGFloat(deltaTime)
        }

        // Faster puddles
        if currentTime - lastPuddleSpawn >= 1.5 {
            lastPuddleSpawn = currentTime
            spawnPuddles(count: 3)
        }
    }

    private func enterCyberbossPhase4() {
        // Create 5 rotating lasers
        let beamCount = 5
        for i in 0..<beamCount {
            lasers.append(SimLaser(
                id: "laser_\(i)",
                originX: bossX,
                originY: bossY,
                angle: CGFloat(i) * 72,
                length: 800,
                damage: 50,
                lifetime: 0
            ))
        }
    }

    // MARK: - Void Harbinger AI

    private func updateVoidHarbinger() {
        switch bossPhase {
        case 1:
            updateVoidHarbingerPhase1()
        case 2:
            updateVoidHarbingerPhase2()
        case 3:
            updateVoidHarbingerPhase3()
        case 4:
            updateVoidHarbingerPhase4()
        default:
            break
        }
    }

    private func updateVoidHarbingerPhase1() {
        // Slow chase
        moveBossTowards(x: playerX, y: playerY, speed: bossSpeed * 0.6)

        // Void zones at player
        if currentTime - lastVoidZoneSpawn >= 8.0 {
            lastVoidZoneSpawn = currentTime
            spawnVoidZone(at: CGPoint(x: playerX, y: playerY))
        }

        // Shadow bolt volley
        if currentTime - lastVolleyTime >= 6.0 {
            lastVolleyTime = currentTime
            fireShadowBoltVolley()
        }

        // Minions
        if currentTime - lastMinionSpawn >= 15.0 {
            lastMinionSpawn = currentTime
            spawnMinions(count: 4)
        }
    }

    private func enterVoidHarbingerPhase2() {
        bossInvulnerable = true

        // Spawn 4 pylons
        let offsets: [(CGFloat, CGFloat)] = [
            (-300, -300), (300, -300), (-300, 300), (300, 300)
        ]
        for (i, offset) in offsets.enumerated() {
            pylons.append(SimPylon(
                id: "pylon_\(i)",
                x: arenaCenter.x + offset.0,
                y: arenaCenter.y + offset.1,
                health: 500,
                maxHealth: 500,
                lastBeamTime: 0
            ))
        }
    }

    private func updateVoidHarbingerPhase2() {
        // Boss stays center, invulnerable
        bossX = arenaCenter.x
        bossY = arenaCenter.y

        // Update pylons - fire beams
        for i in 0..<pylons.count where !pylons[i].destroyed {
            if currentTime - pylons[i].lastBeamTime >= 3.0 {
                pylons[i].lastBeamTime = currentTime
                fireHomingProjectile(fromX: pylons[i].x, fromY: pylons[i].y, damage: 30)
            }
        }

        // Check if all pylons destroyed - boss becomes vulnerable again
        let activeCount = pylons.filter { !$0.destroyed }.count
        if activeCount == 0 {
            bossInvulnerable = false
        }
    }

    private func enterVoidHarbingerPhase3() {
        bossInvulnerable = false

        // Create rotating void rifts
        for i in 0..<3 {
            voidRifts.append(SimVoidRift(
                id: "rift_\(i)",
                angle: CGFloat(i) * 120,
                rotationSpeed: 45,
                length: 700,
                damage: 50
            ))
        }

        // Create gravity wells
        gravityWells = [
            SimGravityWell(id: "gw_1", x: arenaCenter.x - 200, y: arenaCenter.y, pullRadius: 250, pullStrength: 50),
            SimGravityWell(id: "gw_2", x: arenaCenter.x + 200, y: arenaCenter.y, pullRadius: 250, pullStrength: 50)
        ]
    }

    private func updateVoidHarbingerPhase3() {
        // Chase at 0.8x
        moveBossTowards(x: playerX, y: playerY, speed: bossSpeed * 0.8)

        // Void zones
        if currentTime - lastVoidZoneSpawn >= 6.0 {
            lastVoidZoneSpawn = currentTime
            spawnVoidZone(at: CGPoint(x: playerX, y: playerY))
        }

        // Meteors
        if currentTime - lastMeteorTime >= 6.0 {
            lastMeteorTime = currentTime
            let offset: CGFloat = 100
            spawnVoidZone(at: CGPoint(
                x: playerX + rng.nextCGFloat(in: -offset...offset),
                y: playerY + rng.nextCGFloat(in: -offset...offset)
            ), radius: 100, damage: 80)
        }

        // Rotate rifts
        for i in 0..<voidRifts.count {
            voidRifts[i].angle += voidRifts[i].rotationSpeed * CGFloat(deltaTime)
        }
    }

    private func enterVoidHarbingerPhase4() {
        // Enrage - faster void zones
    }

    private func updateVoidHarbingerPhase4() {
        updateVoidHarbingerPhase3()

        // Teleport
        if currentTime - lastTeleportTime >= 3.0 {
            lastTeleportTime = currentTime
            let maxOffset = shrinkingArenaRadius * 0.6
            bossX = arenaCenter.x + rng.nextCGFloat(in: -maxOffset...maxOffset)
            bossY = arenaCenter.y + rng.nextCGFloat(in: -maxOffset...maxOffset)
        }

        // Shrink arena
        if shrinkingArenaRadius > 150 {
            shrinkingArenaRadius -= 30 * CGFloat(deltaTime)
        }

        // Outside arena damage
        let dx = playerX - arenaCenter.x
        let dy = playerY - arenaCenter.y
        let distFromCenter = sqrt(dx * dx + dy * dy)
        if distFromCenter > shrinkingArenaRadius {
            takeDamage(40 * CGFloat(deltaTime), source: "arena")
        }
    }

    // MARK: - Bot Context & Actions

    private func createBotContext() -> BossBotContext {
        return BossBotContext(
            playerX: playerX,
            playerY: playerY,
            playerHealth: playerHealth,
            playerMaxHealth: playerMaxHealth,
            bossX: bossX,
            bossY: bossY,
            bossHealth: bossHealth,
            bossMaxHealth: bossMaxHealth,
            bossPhase: bossPhase,
            bossInvulnerable: bossInvulnerable,
            arenaWidth: arenaWidth,
            arenaHeight: arenaHeight,
            puddles: puddles,
            lasers: lasers,
            voidZones: voidZones,
            projectiles: projectiles,
            minions: minions,
            pylons: pylons,
            voidRifts: voidRifts,
            gravityWells: gravityWells,
            shrinkingArenaRadius: shrinkingArenaRadius,
            arenaCenter: arenaCenter,
            currentTime: currentTime
        )
    }

    private func applyBotAction(_ action: BossBotAction) {
        switch action {
        case .move(let dx, let dy):
            let moveX = dx * playerSpeed * CGFloat(deltaTime)
            let moveY = dy * playerSpeed * CGFloat(deltaTime)
            playerX = clamp(playerX + moveX, min: 30, max: arenaWidth - 30)
            playerY = clamp(playerY + moveY, min: 30, max: arenaHeight - 30)

        case .moveTowards(let x, let y):
            let dx = x - playerX
            let dy = y - playerY
            let dist = sqrt(dx * dx + dy * dy)
            if dist > 1 {
                let moveX = (dx / dist) * playerSpeed * CGFloat(deltaTime)
                let moveY = (dy / dist) * playerSpeed * CGFloat(deltaTime)
                playerX = clamp(playerX + moveX, min: 30, max: arenaWidth - 30)
                playerY = clamp(playerY + moveY, min: 30, max: arenaHeight - 30)
            }

        case .idle:
            break
        }
    }

    // MARK: - Player Attack

    private func updatePlayerAttack() {
        guard currentTime >= playerAttackCooldown else { return }

        let attackRange: CGFloat = 300
        let damage = playerDamage * CGFloat(playerAttackInterval)

        // Priority 1: Attack pylons if boss is invulnerable
        let activePylons = pylons.filter { !$0.destroyed }
        if bossInvulnerable && !activePylons.isEmpty {
            // Find closest pylon
            var closestPylon: (index: Int, dist: CGFloat)?
            for (i, pylon) in pylons.enumerated() where !pylon.destroyed {
                let dx = pylon.x - playerX
                let dy = pylon.y - playerY
                let dist = sqrt(dx * dx + dy * dy)
                if dist <= attackRange {
                    if closestPylon == nil || dist < closestPylon!.dist {
                        closestPylon = (i, dist)
                    }
                }
            }

            if let target = closestPylon {
                playerAttackCooldown = currentTime + playerAttackInterval
                pylons[target.index].health -= damage
                result.totalDamageDealt += damage

                // Check if pylon destroyed
                if pylons[target.index].health <= 0 {
                    result.pylonsDestroyed += 1
                }
                return
            }
        }

        // Priority 2: Attack minions if any are close
        var closestMinion: (index: Int, dist: CGFloat)?
        for (i, minion) in minions.enumerated() where !minion.isDead {
            let dx = minion.x - playerX
            let dy = minion.y - playerY
            let dist = sqrt(dx * dx + dy * dy)
            if dist <= attackRange {
                if closestMinion == nil || dist < closestMinion!.dist {
                    closestMinion = (i, dist)
                }
            }
        }

        if let target = closestMinion {
            playerAttackCooldown = currentTime + playerAttackInterval
            minions[target.index].health -= damage

            if minions[target.index].health <= 0 {
                minions[target.index].isDead = true
                result.minionKills += 1
            }
            return
        }

        // Priority 3: Attack boss (if not invulnerable)
        guard !bossInvulnerable else { return }

        let dx = bossX - playerX
        let dy = bossY - playerY
        let dist = sqrt(dx * dx + dy * dy)

        if dist <= attackRange {
            playerAttackCooldown = currentTime + playerAttackInterval
            bossHealth -= damage
            result.totalDamageDealt += damage
        }
    }

    // MARK: - Hazard Updates

    private func updateHazards() {
        // Update puddles
        puddles = puddles.compactMap { puddle in
            var p = puddle
            p.lifetime += deltaTime
            if p.lifetime >= p.maxLifetime { return nil }
            return p
        }

        // Update void zones
        voidZones = voidZones.compactMap { zone in
            var z = zone
            z.lifetime += deltaTime
            z.isActive = z.lifetime >= z.warningTime
            if z.lifetime >= z.warningTime + z.activeTime { return nil }
            return z
        }

        // Update projectiles
        projectiles = projectiles.compactMap { proj in
            var p = proj
            p.x += p.velocityX * CGFloat(deltaTime)
            p.y += p.velocityY * CGFloat(deltaTime)
            p.lifetime += deltaTime

            // Homing
            if p.isHoming {
                let dx = playerX - p.x
                let dy = playerY - p.y
                let dist = sqrt(dx * dx + dy * dy)
                if dist > 0 {
                    let homingForce: CGFloat = 2.0
                    p.velocityX += (dx / dist) * homingForce
                    p.velocityY += (dy / dist) * homingForce
                }
            }

            if p.lifetime >= p.maxLifetime { return nil }
            return p
        }

        // Update minions - chase player
        for i in 0..<minions.count {
            guard !minions[i].isDead else { continue }

            let dx = playerX - minions[i].x
            let dy = playerY - minions[i].y
            let dist = sqrt(dx * dx + dy * dy)

            if dist > 0 {
                minions[i].x += (dx / dist) * minions[i].speed * CGFloat(deltaTime)
                minions[i].y += (dy / dist) * minions[i].speed * CGFloat(deltaTime)
            }
        }
    }

    // MARK: - Hazard Collisions

    private func checkHazardCollisions() {
        guard currentTime > playerInvulnerableUntil else { return }

        let playerRadius: CGFloat = 20

        // Puddles (active only, after warning)
        for puddle in puddles {
            guard puddle.lifetime >= puddle.warningTime else { continue }
            let dx = playerX - puddle.x
            let dy = playerY - puddle.y
            if sqrt(dx * dx + dy * dy) < puddle.radius + playerRadius {
                takeDamage(puddle.dps * CGFloat(deltaTime), source: "puddle")
                result.puddleHits += 1
            }
        }

        // Lasers
        for laser in lasers where laser.lifetime >= 1.0 {
            if isHitByLaser(laser) {
                takeDamage(laser.damage, source: "laser")
                result.laserHits += 1
                playerInvulnerableUntil = currentTime + 0.5
            }
        }

        // Void zones
        for zone in voidZones where zone.isActive {
            let dx = playerX - zone.x
            let dy = playerY - zone.y
            if sqrt(dx * dx + dy * dy) < zone.radius + playerRadius {
                takeDamage(zone.damage * CGFloat(deltaTime), source: "voidZone")
                result.voidZoneHits += 1
            }
        }

        // Projectiles
        for i in 0..<projectiles.count {
            let proj = projectiles[i]
            let dx = playerX - proj.x
            let dy = playerY - proj.y
            if sqrt(dx * dx + dy * dy) < proj.radius + playerRadius {
                takeDamage(proj.damage, source: "projectile")
                result.projectileHits += 1
                projectiles[i].lifetime = projectiles[i].maxLifetime // Remove
            }
        }

        // Void rifts
        for rift in voidRifts {
            if isHitByRift(rift) {
                takeDamage(rift.damage * CGFloat(deltaTime), source: "rift")
                result.riftHits += 1
            }
        }

        // Minion contact
        for minion in minions where !minion.isDead {
            let dx = playerX - minion.x
            let dy = playerY - minion.y
            if sqrt(dx * dx + dy * dy) < minion.size + playerRadius {
                takeDamage(minion.damage * CGFloat(deltaTime), source: "minion")
            }
        }

        // Gravity wells (pull effect)
        for well in gravityWells {
            let dx = well.x - playerX
            let dy = well.y - playerY
            let dist = sqrt(dx * dx + dy * dy)
            if dist < well.pullRadius && dist > 0 {
                let pullForce = well.pullStrength * (1 - dist / well.pullRadius)
                playerX += (dx / dist) * pullForce * CGFloat(deltaTime)
                playerY += (dy / dist) * pullForce * CGFloat(deltaTime)
            }
        }
    }

    private func isHitByLaser(_ laser: SimLaser) -> Bool {
        let angleRad = laser.angle * .pi / 180
        let endX = laser.originX + cos(angleRad) * laser.length
        let endY = laser.originY - sin(angleRad) * laser.length

        let dist = pointToLineDistance(px: playerX, py: playerY,
                                        x1: laser.originX, y1: laser.originY,
                                        x2: endX, y2: endY)
        return dist < 30  // laser width + player radius
    }

    private func isHitByRift(_ rift: SimVoidRift) -> Bool {
        let angleRad = rift.angle * .pi / 180
        let startX = arenaCenter.x
        let startY = arenaCenter.y
        let endX = startX + cos(angleRad) * rift.length
        let endY = startY + sin(angleRad) * rift.length

        let dist = pointToLineDistance(px: playerX, py: playerY,
                                        x1: startX, y1: startY,
                                        x2: endX, y2: endY)
        return dist < 40  // rift width + player radius
    }

    private func pointToLineDistance(px: CGFloat, py: CGFloat, x1: CGFloat, y1: CGFloat, x2: CGFloat, y2: CGFloat) -> CGFloat {
        let dx = x2 - x1
        let dy = y2 - y1
        let lengthSq = dx * dx + dy * dy

        guard lengthSq > 0 else {
            return sqrt((px - x1) * (px - x1) + (py - y1) * (py - y1))
        }

        var t = ((px - x1) * dx + (py - y1) * dy) / lengthSq
        t = max(0, min(1, t))

        let nearestX = x1 + t * dx
        let nearestY = y1 + t * dy

        return sqrt((px - nearestX) * (px - nearestX) + (py - nearestY) * (py - nearestY))
    }

    // MARK: - Damage Helpers

    private func takeDamage(_ amount: CGFloat, source: String) {
        let scaled = amount * config.difficulty.damageMultiplier
        playerHealth -= scaled
        result.totalDamageTaken += scaled

        if playerHealth <= 0 {
            result.playerDeaths += 1
            // Simulate revive for testing purposes (track deaths)
            playerHealth = playerMaxHealth * 0.5
            playerInvulnerableUntil = currentTime + 3.0
        }
    }

    // MARK: - Spawn Helpers

    private func spawnPuddles(count: Int) {
        for _ in 0..<count {
            puddles.append(SimPuddle(
                id: UUID().uuidString,
                x: rng.nextCGFloat(in: 100...(arenaWidth - 100)),
                y: rng.nextCGFloat(in: 100...(arenaHeight - 100)),
                radius: 60,
                dps: 10,
                lifetime: 0,
                maxLifetime: 5,
                warningTime: 1
            ))
        }
    }

    private func spawnVoidZone(at pos: CGPoint, radius: CGFloat = 80, damage: CGFloat = 40) {
        voidZones.append(SimVoidZone(
            id: UUID().uuidString,
            x: pos.x,
            y: pos.y,
            radius: radius,
            damage: damage,
            lifetime: 0,
            warningTime: 2,
            activeTime: 5,
            isActive: false
        ))
    }

    private func spawnMinions(count: Int) {
        for _ in 0..<count {
            let angle = rng.nextCGFloat(in: 0...(2 * .pi))
            let dist = rng.nextCGFloat(in: 100...200)

            minions.append(SimMinion(
                id: UUID().uuidString,
                x: bossX + cos(angle) * dist,
                y: bossY + sin(angle) * dist,
                health: 30,
                damage: 10,
                speed: 120,
                size: 20,
                isDead: false
            ))
        }
    }

    private func fireRangedVolley() {
        let count = 5
        let spread: CGFloat = 0.5  // radians
        let baseAngle = atan2(playerY - bossY, playerX - bossX)

        for i in 0..<count {
            let angle = baseAngle - spread / 2 + (spread / CGFloat(count - 1)) * CGFloat(i)
            projectiles.append(SimProjectile(
                id: UUID().uuidString,
                x: bossX,
                y: bossY,
                velocityX: cos(angle) * 300,
                velocityY: sin(angle) * 300,
                damage: 25,
                radius: 15,
                lifetime: 0,
                maxLifetime: 3,
                isHoming: false
            ))
        }
    }

    private func fireShadowBoltVolley() {
        let count = 8
        let baseAngle = atan2(playerY - bossY, playerX - bossX)

        for i in 0..<count {
            let offset = CGFloat(i - count / 2) * 0.15
            let angle = baseAngle + offset
            projectiles.append(SimProjectile(
                id: UUID().uuidString,
                x: bossX,
                y: bossY,
                velocityX: cos(angle) * 350,
                velocityY: sin(angle) * 350,
                damage: 20,
                radius: 12,
                lifetime: 0,
                maxLifetime: 4,
                isHoming: false
            ))
        }
    }

    private func fireHomingProjectile(fromX: CGFloat, fromY: CGFloat, damage: CGFloat) {
        let dx = playerX - fromX
        let dy = playerY - fromY
        let dist = sqrt(dx * dx + dy * dy)

        projectiles.append(SimProjectile(
            id: UUID().uuidString,
            x: fromX,
            y: fromY,
            velocityX: (dx / dist) * 400,
            velocityY: (dy / dist) * 400,
            damage: damage,
            radius: 10,
            lifetime: 0,
            maxLifetime: 5,
            isHoming: true
        ))
    }

    // MARK: - Movement Helpers

    private func moveBossTowards(x: CGFloat, y: CGFloat, speed: CGFloat) {
        let dx = x - bossX
        let dy = y - bossY
        let dist = sqrt(dx * dx + dy * dy)

        if dist > 0 {
            bossX += (dx / dist) * speed * CGFloat(deltaTime)
            bossY += (dy / dist) * speed * CGFloat(deltaTime)
        }
    }

    private func moveBossAway(fromX: CGFloat, fromY: CGFloat, speed: CGFloat) {
        let dx = bossX - fromX
        let dy = bossY - fromY
        let dist = sqrt(dx * dx + dy * dy)

        if dist > 0 {
            bossX += (dx / dist) * speed * CGFloat(deltaTime)
            bossY += (dy / dist) * speed * CGFloat(deltaTime)
        }

        // Clamp to arena
        bossX = clamp(bossX, min: 80, max: arenaWidth - 80)
        bossY = clamp(bossY, min: 80, max: arenaHeight - 80)
    }

    private func clamp(_ value: CGFloat, min: CGFloat, max: CGFloat) -> CGFloat {
        return Swift.min(Swift.max(value, min), max)
    }
}

// MARK: - Simulation Types

struct SimPuddle {
    let id: String
    var x: CGFloat
    var y: CGFloat
    let radius: CGFloat
    let dps: CGFloat
    var lifetime: TimeInterval
    let maxLifetime: TimeInterval
    let warningTime: TimeInterval
}

struct SimLaser {
    let id: String
    var originX: CGFloat
    var originY: CGFloat
    var angle: CGFloat
    let length: CGFloat
    let damage: CGFloat
    var lifetime: TimeInterval
}

struct SimVoidZone {
    let id: String
    var x: CGFloat
    var y: CGFloat
    let radius: CGFloat
    let damage: CGFloat
    var lifetime: TimeInterval
    let warningTime: TimeInterval
    let activeTime: TimeInterval
    var isActive: Bool
}

struct SimProjectile {
    let id: String
    var x: CGFloat
    var y: CGFloat
    var velocityX: CGFloat
    var velocityY: CGFloat
    let damage: CGFloat
    let radius: CGFloat
    var lifetime: TimeInterval
    let maxLifetime: TimeInterval
    let isHoming: Bool
}

struct SimMinion {
    let id: String
    var x: CGFloat
    var y: CGFloat
    var health: CGFloat
    let damage: CGFloat
    let speed: CGFloat
    let size: CGFloat
    var isDead: Bool
}

struct SimPylon {
    let id: String
    var x: CGFloat
    var y: CGFloat
    var health: CGFloat
    let maxHealth: CGFloat
    var lastBeamTime: TimeInterval
    var destroyed: Bool { health <= 0 }
}

struct SimVoidRift {
    let id: String
    var angle: CGFloat
    let rotationSpeed: CGFloat
    let length: CGFloat
    let damage: CGFloat
}

struct SimGravityWell {
    let id: String
    var x: CGFloat
    var y: CGFloat
    let pullRadius: CGFloat
    let pullStrength: CGFloat
}
