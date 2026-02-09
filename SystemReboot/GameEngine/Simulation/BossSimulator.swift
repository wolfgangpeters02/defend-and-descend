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

// MARK: - Simulated Weapon Types

enum SimulatedWeaponType: String, CaseIterable {
    case kernelPulse = "kernel_pulse"       // Baseline damage
    case fragmenter = "burst_protocol"       // 50% DoT burn over 1.5s
    case pinger = "trace_route"              // Tags boss for +20% damage
    case throttler = "ice_shard"             // Slow + 10% stun chance
    case recursion = "fork_bomb"             // 3 child projectiles (50% damage each)
    case garbageCollector = "null_pointer"   // Lower DPS, marks for bonus

    var displayName: String {
        switch self {
        case .kernelPulse: return "Kernel Pulse"
        case .fragmenter: return "Fragmenter"
        case .pinger: return "Pinger"
        case .throttler: return "Throttler"
        case .recursion: return "Recursion"
        case .garbageCollector: return "Garbage Collector"
        }
    }

    var rarity: String {
        switch self {
        case .kernelPulse, .fragmenter: return "Common"
        case .pinger, .throttler: return "Rare"
        case .recursion: return "Epic"
        case .garbageCollector: return "Legendary"
        }
    }

    /// Base damage at level 1
    var baseDamage: CGFloat {
        switch self {
        case .kernelPulse: return 25
        case .fragmenter: return 20          // Lower upfront, +50% as DoT
        case .pinger: return 15              // Tags for team damage bonus
        case .throttler: return 18           // Utility-focused
        case .recursion: return 28           // Split into children (nerfed from 30)
        case .garbageCollector: return 20    // Support weapon (buffed from 12)
        }
    }

    /// Attack interval in seconds
    var attackInterval: TimeInterval {
        switch self {
        case .kernelPulse: return 0.4
        case .fragmenter: return 0.5
        case .pinger: return 0.6
        case .throttler: return 0.7
        case .recursion: return 0.8
        case .garbageCollector: return 0.5
        }
    }

    /// Attack range
    var range: CGFloat {
        switch self {
        case .kernelPulse: return 200
        case .fragmenter: return 180
        case .pinger: return 250
        case .throttler: return 220
        case .recursion: return 200
        case .garbageCollector: return 200
        }
    }
}

struct SimulatedWeapon {
    let type: SimulatedWeaponType
    let level: Int

    /// Damage scaled by level (diminishing returns: Lv1=1x, Lv5=3x, Lv10=5.5x)
    var damage: CGFloat {
        type.baseDamage * (1.0 + CGFloat(level - 1) * 0.5)
    }

    var attackInterval: TimeInterval { type.attackInterval }
    var range: CGFloat { type.range }

    /// Effective DPS accounting for attack interval and special mechanics
    var theoreticalDPS: CGFloat {
        let baseDPS = damage / CGFloat(attackInterval)
        switch type {
        case .fragmenter:
            return baseDPS * 1.5  // +50% from DoT
        case .pinger:
            return baseDPS * 1.2  // +20% damage bonus while tagged
        case .recursion:
            return baseDPS * 1.7  // 2 children at 35% each = +70% (nerfed from 2.5)
        case .garbageCollector:
            return baseDPS * 1.15 // Support weapon + 15% self-mark bonus (buffed from 0.8)
        default:
            return baseDPS
        }
    }
}

// MARK: - Configuration

struct BossSimulationConfig {
    let seed: UInt64
    let bossType: String                    // "cyberboss", "void_harbinger", "overclocker", "trojan_wyrm"
    let difficulty: BossDifficulty
    let bot: BossBot
    let maxFightTime: TimeInterval          // Max fight duration before timeout
    let playerWeaponDamage: CGFloat         // Base player DPS (legacy, use weapon instead)
    let playerHealth: CGFloat               // Base player health
    let arenaSize: CGFloat                  // Arena width/height
    let weapon: SimulatedWeapon?            // Optional weapon for detailed simulation

    static let defaultConfig = BossSimulationConfig(
        seed: 42,
        bossType: "cyberboss",
        difficulty: .normal,
        bot: AggressiveBot(),
        maxFightTime: 300,
        playerWeaponDamage: 50,
        playerHealth: 200,
        arenaSize: 1500,
        weapon: nil
    )
}

// MARK: - Result

struct BossSimulationResult {
    let bossType: String
    let difficulty: BossDifficulty
    let botName: String

    // Weapon info (optional)
    var weaponType: SimulatedWeaponType?
    var weaponLevel: Int = 1

    // Outcome
    var victory: Bool = false
    var fightDuration: TimeInterval = 0
    var playerHealthRemaining: CGFloat = 0
    var playerDeaths: Int = 0               // Times player would have died

    // Combat stats
    var totalDamageDealt: CGFloat = 0
    var dotDamageDealt: CGFloat = 0         // Damage from DoT effects
    var bonusDamageDealt: CGFloat = 0       // Damage from tags/marks
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

    // Overclocker specific
    var overclockerBladeAngle: CGFloat = 0
    var overclockerTileStates: [Int] = Array(repeating: 0, count: 16)  // 0=normal, 1=warning, 2=lava, 3=safe
    var lastTileChangeTime: TimeInterval = 0
    var steamTrail: [SimSteamSegment] = []
    var lastSteamDropTime: TimeInterval = 0
    var overclockerSuctionActive: Bool = false
    var overclockerSuctionTimer: TimeInterval = 0

    // Trojan Wyrm specific
    var wyrmSegments: [CGPoint] = []
    var wyrmHeadAngle: CGFloat = 0
    var wyrmWallY: CGFloat = 0
    var wyrmWallDirection: CGFloat = -1
    var wyrmGhostSegmentIndex: Int = -1
    var lastTurretFireTime: TimeInterval = 0
    var wyrmSubWorms: [SimSubWorm] = []
    var wyrmPhase4SubState: Int = 0  // 0=circling, 1=aiming, 2=lunging, 3=recovering
    var wyrmRingAngle: CGFloat = 0
    var wyrmRingRadius: CGFloat = 250
    var wyrmAimTimer: TimeInterval = 0
    var wyrmLungeTimer: TimeInterval = 0
    var wyrmLungeVelocity: CGPoint = .zero
    var wyrmRecoverTimer: TimeInterval = 0

    // Weapon-specific state
    var weapon: SimulatedWeapon?
    var bossTaggedUntil: TimeInterval = 0       // Pinger tag expiry
    var bossSlowedUntil: TimeInterval = 0       // Throttler slow expiry
    var bossStunnedUntil: TimeInterval = 0      // Throttler stun expiry
    var bossMarkedUntil: TimeInterval = 0       // Garbage Collector mark expiry
    var dotDamageRemaining: CGFloat = 0         // Fragmenter DoT damage pool
    var dotTickTimer: TimeInterval = 0          // Fragmenter DoT tick timer
    var pendingChildProjectiles: Int = 0        // Recursion children to apply

    // Result tracking
    var result: BossSimulationResult

    // Config
    let config: BossSimulationConfig
    let bot: BossBot

    init(config: BossSimulationConfig) {
        self.config = config
        self.rng = SeededRNG(seed: config.seed)
        self.bot = config.bot
        self.weapon = config.weapon
        self.result = BossSimulationResult(
            bossType: config.bossType,
            difficulty: config.difficulty,
            botName: config.bot.name,
            weaponType: config.weapon?.type,
            weaponLevel: config.weapon?.level ?? 1
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

        // Use weapon damage if provided, otherwise fall back to config
        if let weapon = weapon {
            playerDamage = weapon.damage * config.difficulty.playerDamageMultiplier
            playerAttackInterval = weapon.attackInterval
        } else {
            playerDamage = config.playerWeaponDamage * config.difficulty.playerDamageMultiplier
            playerAttackInterval = 0.5
        }

        // Boss setup
        bossX = arenaWidth / 2
        bossY = arenaHeight * 0.3  // Start near top
        bossMaxHealth = getBossBaseHealth() * config.difficulty.healthMultiplier
        bossHealth = bossMaxHealth
        bossSpeed = 100
        bossPhase = 1

        shrinkingArenaRadius = arenaWidth / 2

        setupBossSpecificState()
    }

    private func getBossBaseHealth() -> CGFloat {
        switch config.bossType {
        case "void_harbinger":
            return 5000
        case "overclocker":
            return 4500
        case "trojan_wyrm":
            return 5500
        default: // cyberboss
            return 4000
        }
    }

    private func setupBossSpecificState() {
        switch config.bossType {
        case "overclocker":
            overclockerBladeAngle = 0
            overclockerTileStates = Array(repeating: 0, count: 16)
            steamTrail = []

        case "trojan_wyrm":
            // Initialize 24 body segments
            let spacing: CGFloat = 45
            wyrmSegments = []
            for i in 1...24 {
                wyrmSegments.append(CGPoint(x: bossX, y: bossY - CGFloat(i) * spacing))
            }
            wyrmHeadAngle = CGFloat.random(in: 0...(2 * .pi))
            wyrmWallY = arenaHeight - 100
            wyrmGhostSegmentIndex = Int.random(in: 3..<21)

        default:
            break
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
        switch config.bossType {
        case "void_harbinger":
            updateVoidHarbinger()
        case "overclocker":
            updateOverclocker()
        case "trojan_wyrm":
            updateTrojanWyrm()
        default:
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

        switch config.bossType {
        case "void_harbinger":
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

        case "overclocker":
            if healthPercent <= 0.25 && bossPhase < 4 {
                bossPhase = 4
                enterOverclockerPhase4()
            } else if healthPercent <= 0.50 && bossPhase < 3 {
                bossPhase = 3
                enterOverclockerPhase3()
            } else if healthPercent <= 0.75 && bossPhase < 2 {
                bossPhase = 2
                enterOverclockerPhase2()
            }

        case "trojan_wyrm":
            if healthPercent <= 0.25 && bossPhase < 4 {
                bossPhase = 4
                enterTrojanWyrmPhase4()
            } else if healthPercent <= 0.50 && bossPhase < 3 {
                bossPhase = 3
                enterTrojanWyrmPhase3()
            } else if healthPercent <= 0.75 && bossPhase < 2 {
                bossPhase = 2
                enterTrojanWyrmPhase2()
            }

        default:
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

    // MARK: - Overclocker AI

    private func updateOverclocker() {
        switch bossPhase {
        case 1:
            updateOverclockerPhase1()
        case 2:
            updateOverclockerPhase2()
        case 3:
            updateOverclockerPhase3()
        case 4:
            updateOverclockerPhase4()
        default:
            break
        }
    }

    private func updateOverclockerPhase1() {
        // Rotate blades
        let rotationSpeed: CGFloat = 90 * (.pi / 180)  // 90 deg/s
        overclockerBladeAngle += rotationSpeed * CGFloat(deltaTime)
        if overclockerBladeAngle > .pi * 2 {
            overclockerBladeAngle -= .pi * 2
        }

        // Move towards center
        moveBossTowards(x: arenaCenter.x, y: arenaCenter.y, speed: 100)

        // Wind pushes player away from boss
        let windForce: CGFloat = 20
        let dx = playerX - bossX
        let dy = playerY - bossY
        let dist = sqrt(dx * dx + dy * dy)
        let maxDist: CGFloat = 600
        if dist < maxDist && dist > 1 {
            let strength = windForce * (1.0 - (dist / maxDist))
            let angle = atan2(dy, dx)
            playerX += cos(angle) * strength * CGFloat(deltaTime)
            playerY += sin(angle) * strength * CGFloat(deltaTime)
            playerX = clamp(playerX, min: 30, max: arenaWidth - 30)
            playerY = clamp(playerY, min: 30, max: arenaHeight - 30)
        }

        // Check blade collision (3 blades, 180 radius)
        let bladeRadius: CGFloat = 180
        let bladeCount = 3
        for i in 0..<bladeCount {
            let angleOffset = CGFloat(i) * (2 * .pi / CGFloat(bladeCount))
            let currentAngle = overclockerBladeAngle + angleOffset
            let bladeTipX = bossX + cos(currentAngle) * bladeRadius
            let bladeTipY = bossY + sin(currentAngle) * bladeRadius

            let bladeDist = pointToLineDistance(px: playerX, py: playerY,
                                                 x1: bossX, y1: bossY,
                                                 x2: bladeTipX, y2: bladeTipY)
            if bladeDist < 30 {
                takeDamage(80, source: "blade")
                playerInvulnerableUntil = currentTime + 0.5
                break
            }
        }
    }

    private func enterOverclockerPhase2() {
        overclockerTileStates = Array(repeating: 0, count: 16)
        lastTileChangeTime = 0
    }

    private func updateOverclockerPhase2() {
        let tileChangeInterval: TimeInterval = 3.0
        let warningDuration: TimeInterval = 1.0

        // Timer for floor pattern changes
        if lastTileChangeTime == 0 || currentTime - lastTileChangeTime > tileChangeInterval {
            lastTileChangeTime = currentTime

            // Reset grid
            var newTiles = Array(repeating: 0, count: 16)

            // Pick 2 safe zones
            var available = Array(0..<16)
            let safe1 = available.randomElement()!
            available.removeAll { $0 == safe1 }
            let safe2 = available.randomElement()!
            available.removeAll { $0 == safe2 }

            newTiles[safe1] = 3  // safe
            newTiles[safe2] = 3  // safe

            // Pick 4 warning zones
            for _ in 0..<4 {
                if let lavaIndex = available.randomElement() {
                    newTiles[lavaIndex] = 1  // warning
                    available.removeAll { $0 == lavaIndex }
                }
            }

            overclockerTileStates = newTiles
        }

        // Convert warnings to lava after warning duration
        let timeSinceChange = currentTime - lastTileChangeTime
        if timeSinceChange > warningDuration {
            for i in 0..<16 {
                if overclockerTileStates[i] == 1 {
                    overclockerTileStates[i] = 2  // lava
                }
            }
        }

        // Move boss to nearest safe zone
        var nearestSafeDist: CGFloat = .greatestFiniteMagnitude
        var targetPos = arenaCenter
        for i in 0..<16 where overclockerTileStates[i] == 3 {
            let tileCenter = getTileCenter(index: i)
            let dist = hypot(bossX - tileCenter.x, bossY - tileCenter.y)
            if dist < nearestSafeDist {
                nearestSafeDist = dist
                targetPos = tileCenter
            }
        }
        moveBossTowards(x: targetPos.x, y: targetPos.y, speed: 150)

        // Check player lava damage
        let col = Int((playerX - 0) / (arenaWidth / 4))
        let row = Int((playerY - 0) / (arenaHeight / 4))
        if col >= 0 && col < 4 && row >= 0 && row < 4 {
            let index = row * 4 + col
            if index < overclockerTileStates.count && overclockerTileStates[index] == 2 {
                takeDamage(60 * CGFloat(deltaTime), source: "lava")
            }
        }
    }

    private func enterOverclockerPhase3() {
        overclockerTileStates = Array(repeating: 0, count: 16)
        steamTrail = []
        lastSteamDropTime = 0
    }

    private func updateOverclockerPhase3() {
        // Chase player
        let chaseSpeed: CGFloat = 180
        moveBossTowards(x: playerX, y: playerY, speed: chaseSpeed)

        // Drop steam
        let steamDropInterval: TimeInterval = 0.15
        if currentTime - lastSteamDropTime > steamDropInterval {
            lastSteamDropTime = currentTime
            steamTrail.append(SimSteamSegment(
                id: UUID().uuidString,
                x: bossX,
                y: bossY,
                createdAt: currentTime
            ))

            // Cap trail length
            if steamTrail.count > 30 {
                steamTrail.removeFirst()
            }
        }

        // Steam damage
        let steamRadius: CGFloat = 40
        for segment in steamTrail {
            let dist = hypot(playerX - segment.x, playerY - segment.y)
            if dist < steamRadius {
                takeDamage(30 * CGFloat(deltaTime), source: "steam")
                break
            }
        }
    }

    private func enterOverclockerPhase4() {
        overclockerSuctionActive = false
        overclockerSuctionTimer = 0
    }

    private func updateOverclockerPhase4() {
        // Move towards center slowly
        moveBossTowards(x: arenaCenter.x, y: arenaCenter.y, speed: 50)

        // Toggle suction
        overclockerSuctionTimer += deltaTime
        let suctionPullDuration: TimeInterval = 4.0
        let suctionPauseDuration: TimeInterval = 2.0

        if overclockerSuctionActive {
            if overclockerSuctionTimer > suctionPullDuration {
                overclockerSuctionActive = false
                overclockerSuctionTimer = 0
            }
        } else {
            if overclockerSuctionTimer > suctionPauseDuration {
                overclockerSuctionActive = true
                overclockerSuctionTimer = 0
            }
        }

        // Vacuum pulls player toward boss
        if overclockerSuctionActive {
            let vacuumStrength: CGFloat = 80
            let dx = bossX - playerX
            let dy = bossY - playerY
            let angle = atan2(dy, dx)
            playerX += cos(angle) * vacuumStrength * CGFloat(deltaTime)
            playerY += sin(angle) * vacuumStrength * CGFloat(deltaTime)
            playerX = clamp(playerX, min: 30, max: arenaWidth - 30)
            playerY = clamp(playerY, min: 30, max: arenaHeight - 30)
        }

        // Continue steam trail
        let steamDropInterval: TimeInterval = 0.15
        if currentTime - lastSteamDropTime > steamDropInterval {
            lastSteamDropTime = currentTime
            steamTrail.append(SimSteamSegment(
                id: UUID().uuidString,
                x: bossX,
                y: bossY,
                createdAt: currentTime
            ))
            if steamTrail.count > 30 {
                steamTrail.removeFirst()
            }
        }

        // Steam damage
        let steamRadius: CGFloat = 40
        for segment in steamTrail {
            let dist = hypot(playerX - segment.x, playerY - segment.y)
            if dist < steamRadius {
                takeDamage(30 * CGFloat(deltaTime), source: "steam")
                break
            }
        }

        // Shredder damage when close to boss
        let shredderRadius: CGFloat = 80
        let distToBoss = hypot(playerX - bossX, playerY - bossY)
        if distToBoss < shredderRadius {
            takeDamage(100 * CGFloat(deltaTime), source: "shredder")
        }
    }

    private func getTileCenter(index: Int) -> CGPoint {
        let col = index % 4
        let row = index / 4
        let tileW = arenaWidth / 4
        let tileH = arenaHeight / 4
        return CGPoint(
            x: CGFloat(col) * tileW + tileW / 2,
            y: CGFloat(row) * tileH + tileH / 2
        )
    }

    // MARK: - Trojan Wyrm AI

    private func updateTrojanWyrm() {
        switch bossPhase {
        case 1:
            updateTrojanWyrmPhase1()
        case 2:
            updateTrojanWyrmPhase2()
        case 3:
            updateTrojanWyrmPhase3()
        case 4:
            updateTrojanWyrmPhase4()
        default:
            break
        }

        // Check body segment collisions
        checkWyrmBodyCollision()
    }

    private func updateTrojanWyrmPhase1() {
        let headSpeed = BalanceConfig.TrojanWyrm.headSpeed
        let turnSpeed = BalanceConfig.TrojanWyrm.turnSpeed
        let segmentSpacing = BalanceConfig.TrojanWyrm.segmentSpacing

        // Turn towards player
        let targetAngle = atan2(playerY - bossY, playerX - bossX)
        let diff = normalizeAngle(targetAngle - wyrmHeadAngle)
        let turnAmount = turnSpeed * CGFloat(deltaTime)
        if abs(diff) < turnAmount {
            wyrmHeadAngle = targetAngle
        } else {
            wyrmHeadAngle += (diff > 0 ? turnAmount : -turnAmount)
        }

        // Move head
        let newX = bossX + cos(wyrmHeadAngle) * headSpeed * CGFloat(deltaTime)
        let newY = bossY + sin(wyrmHeadAngle) * headSpeed * CGFloat(deltaTime)

        // Wall bounce
        let padding: CGFloat = 50
        if newX < padding || newX > arenaWidth - padding ||
           newY < padding || newY > arenaHeight - padding {
            wyrmHeadAngle += .pi
            bossX = clamp(bossX, min: padding, max: arenaWidth - padding)
            bossY = clamp(bossY, min: padding, max: arenaHeight - padding)
        } else {
            bossX = newX
            bossY = newY
        }

        // Drag body segments
        updateWyrmSegments(spacing: segmentSpacing)
    }

    private func enterTrojanWyrmPhase2() {
        wyrmWallY = arenaHeight - 100
        wyrmWallDirection = -1
        wyrmGhostSegmentIndex = Int.random(in: 3..<min(21, wyrmSegments.count))
    }

    private func updateTrojanWyrmPhase2() {
        let wallSweepSpeed = BalanceConfig.TrojanWyrm.wallSweepSpeed
        let segmentSpacing = BalanceConfig.TrojanWyrm.segmentSpacing

        // Move wall
        wyrmWallY += wallSweepSpeed * CGFloat(deltaTime) * wyrmWallDirection

        // Bounce at edges
        if wyrmWallY < 100 {
            wyrmWallDirection = 1
            wyrmWallY = 100
            wyrmGhostSegmentIndex = Int.random(in: 3..<min(21, wyrmSegments.count))
        } else if wyrmWallY > arenaHeight - 100 {
            wyrmWallDirection = -1
            wyrmWallY = arenaHeight - 100
            wyrmGhostSegmentIndex = Int.random(in: 3..<min(21, wyrmSegments.count))
        }

        // Rigid positioning
        let totalWidth = segmentSpacing * CGFloat(wyrmSegments.count)
        let startX = arenaCenter.x - totalWidth / 2
        bossX = startX
        bossY = wyrmWallY

        for i in 0..<wyrmSegments.count {
            wyrmSegments[i] = CGPoint(
                x: startX + segmentSpacing * CGFloat(i + 1),
                y: wyrmWallY
            )
        }

        // Turret fire from even segments
        let turretFireInterval = BalanceConfig.TrojanWyrm.turretFireInterval
        if currentTime - lastTurretFireTime > turretFireInterval {
            lastTurretFireTime = currentTime

            for i in stride(from: 0, to: wyrmSegments.count, by: 2) {
                if i == wyrmGhostSegmentIndex { continue }
                let seg = wyrmSegments[i]
                projectiles.append(SimProjectile(
                    id: UUID().uuidString,
                    x: seg.x,
                    y: seg.y,
                    velocityX: 0,
                    velocityY: -BalanceConfig.TrojanWyrm.turretProjectileSpeed,
                    damage: BalanceConfig.TrojanWyrm.turretProjectileDamage,
                    radius: BalanceConfig.TrojanWyrm.turretProjectileRadius,
                    lifetime: 0,
                    maxLifetime: BalanceConfig.TrojanWyrm.turretProjectileLifetime,
                    isHoming: false
                ))
            }
        }
    }

    private func enterTrojanWyrmPhase3() {
        wyrmSubWorms = []

        // Split into sub-worms (count from BalanceConfig)
        let subWormCount = BalanceConfig.TrojanWyrm.subWormCount
        let bodyCount = BalanceConfig.TrojanWyrm.subWormBodyCount
        let angleStep = (2 * CGFloat.pi) / CGFloat(subWormCount)

        for i in 0..<subWormCount {
            let angle = CGFloat(i) * angleStep
            let spawnDist: CGFloat = 200
            let pos = CGPoint(
                x: arenaCenter.x + cos(angle) * spawnDist,
                y: arenaCenter.y + sin(angle) * spawnDist
            )
            var body: [CGPoint] = []
            for k in 1...bodyCount {
                body.append(CGPoint(x: pos.x, y: pos.y - CGFloat(k * 20)))
            }
            wyrmSubWorms.append(SimSubWorm(
                id: i,
                headX: pos.x,
                headY: pos.y,
                body: body,
                angle: angle + .pi / 2
            ))
        }
    }

    private func updateTrojanWyrmPhase3() {
        let subWormSpeed = BalanceConfig.TrojanWyrm.subWormSpeed
        let subWormTurnSpeed = BalanceConfig.TrojanWyrm.subWormTurnSpeed
        let headDamage = BalanceConfig.TrojanWyrm.headContactDamage
        let bodyDamage = BalanceConfig.TrojanWyrm.bodyContactDamage

        for i in 0..<wyrmSubWorms.count {
            var worm = wyrmSubWorms[i]

            // Chase player
            let targetAngle = atan2(playerY - worm.headY, playerX - worm.headX)
            let diff = normalizeAngle(targetAngle - worm.angle)
            worm.angle += diff * CGFloat(deltaTime) * subWormTurnSpeed

            worm.headX += cos(worm.angle) * subWormSpeed * CGFloat(deltaTime)
            worm.headY += sin(worm.angle) * subWormSpeed * CGFloat(deltaTime)

            // Drag body
            var leader = CGPoint(x: worm.headX, y: worm.headY)
            for j in 0..<worm.body.count {
                let dx = leader.x - worm.body[j].x
                let dy = leader.y - worm.body[j].y
                let dist = sqrt(dx * dx + dy * dy)
                let spacing: CGFloat = 25
                if dist > spacing {
                    let angle = atan2(dy, dx)
                    worm.body[j] = CGPoint(
                        x: leader.x - cos(angle) * spacing,
                        y: leader.y - sin(angle) * spacing
                    )
                }
                leader = worm.body[j]
            }

            wyrmSubWorms[i] = worm

            // Check sub-worm collision with player
            let headDist = hypot(playerX - worm.headX, playerY - worm.headY)
            if headDist < BalanceConfig.TrojanWyrm.subWormHeadSize * 2 {
                takeDamage(headDamage, source: "wyrmHead")
                playerInvulnerableUntil = currentTime + 0.5
            }
            for seg in worm.body {
                let segDist = hypot(playerX - seg.x, playerY - seg.y)
                if segDist < BalanceConfig.TrojanWyrm.subWormBodySize * 2.5 {
                    takeDamage(bodyDamage, source: "wyrmBody")
                    playerInvulnerableUntil = currentTime + 0.3
                    break
                }
            }
        }
    }

    private func enterTrojanWyrmPhase4() {
        wyrmSubWorms = []
        wyrmPhase4SubState = 0  // circling
        wyrmRingRadius = BalanceConfig.TrojanWyrm.ringInitialRadius
        wyrmRingAngle = 0
        wyrmAimTimer = 0
        wyrmLungeTimer = 0
        wyrmRecoverTimer = 0
    }

    private func updateTrojanWyrmPhase4() {
        let ringShrinkRate = BalanceConfig.TrojanWyrm.ringShrinkRate
        let ringMinRadius = BalanceConfig.TrojanWyrm.ringMinRadius
        let ringRotationSpeed = BalanceConfig.TrojanWyrm.ringRotationSpeed
        let aimDuration = BalanceConfig.TrojanWyrm.aimDuration
        let lungeSpeed = BalanceConfig.TrojanWyrm.lungeSpeed
        let recoverDuration = BalanceConfig.TrojanWyrm.recoverDuration

        switch wyrmPhase4SubState {
        case 0:  // circling
            // Shrink ring
            wyrmRingRadius = max(ringMinRadius, wyrmRingRadius - ringShrinkRate * CGFloat(deltaTime))

            // Rotate ring
            wyrmRingAngle += ringRotationSpeed * CGFloat(deltaTime)

            // Position head on ring around player
            bossX = playerX + cos(wyrmRingAngle) * wyrmRingRadius
            bossY = playerY + sin(wyrmRingAngle) * wyrmRingRadius

            // Position segments in circle formation
            let angleStep = (2 * .pi) / CGFloat(wyrmSegments.count + 1)
            for i in 0..<wyrmSegments.count {
                let segAngle = wyrmRingAngle - CGFloat(i + 1) * angleStep
                wyrmSegments[i] = CGPoint(
                    x: playerX + cos(segAngle) * wyrmRingRadius,
                    y: playerY + sin(segAngle) * wyrmRingRadius
                )
            }

            // Check if player touches ring
            let distToHead = hypot(playerX - bossX, playerY - bossY)
            if distToHead < BalanceConfig.TrojanWyrm.headCollisionRadius * 1.8 {
                takeDamage(BalanceConfig.TrojanWyrm.headContactDamage * CGFloat(deltaTime), source: "ring")
            }
            for seg in wyrmSegments {
                let dist = hypot(playerX - seg.x, playerY - seg.y)
                if dist < BalanceConfig.TrojanWyrm.bodyCollisionRadius * 2 {
                    takeDamage(BalanceConfig.TrojanWyrm.bodyContactDamage * CGFloat(deltaTime), source: "ring")
                    break
                }
            }

            // Trigger lunge after circling
            wyrmAimTimer += deltaTime
            if wyrmAimTimer > 4.0 {
                wyrmPhase4SubState = 1  // aiming
                wyrmAimTimer = 0
            }

        case 1:  // aiming
            wyrmAimTimer += deltaTime
            if wyrmAimTimer > aimDuration {
                wyrmPhase4SubState = 2  // lunging

                // Calculate lunge vector
                let dx = playerX - bossX
                let dy = playerY - bossY
                let dist = sqrt(dx * dx + dy * dy)
                if dist > 0 {
                    wyrmLungeVelocity = CGPoint(
                        x: (dx / dist) * lungeSpeed,
                        y: (dy / dist) * lungeSpeed
                    )
                }
                wyrmLungeTimer = 0
            }

        case 2:  // lunging
            bossX += wyrmLungeVelocity.x * CGFloat(deltaTime)
            bossY += wyrmLungeVelocity.y * CGFloat(deltaTime)

            // Drag segments
            updateWyrmSegments(spacing: BalanceConfig.TrojanWyrm.segmentSpacing)

            // Check bounds or timeout
            wyrmLungeTimer += deltaTime
            let padding: CGFloat = 50
            if bossX < padding || bossX > arenaWidth - padding ||
               bossY < padding || bossY > arenaHeight - padding ||
               wyrmLungeTimer > 1.5 {
                wyrmPhase4SubState = 3  // recovering
                wyrmRecoverTimer = 0
            }

            // Lunge head does extra damage
            let distToHead = hypot(playerX - bossX, playerY - bossY)
            if distToHead < BalanceConfig.TrojanWyrm.headCollisionRadius * 2 {
                takeDamage(BalanceConfig.TrojanWyrm.lungeHeadDamage, source: "lunge")
                playerInvulnerableUntil = currentTime + 1.0
            }

        case 3:  // recovering
            wyrmRecoverTimer += deltaTime
            if wyrmRecoverTimer > recoverDuration {
                wyrmPhase4SubState = 0  // back to circling
                wyrmAimTimer = 0
                wyrmRingRadius = BalanceConfig.TrojanWyrm.ringInitialRadius  // Reset ring
            }

        default:
            break
        }
    }

    private func updateWyrmSegments(spacing: CGFloat) {
        var leader = CGPoint(x: bossX, y: bossY)
        for i in 0..<wyrmSegments.count {
            let dx = leader.x - wyrmSegments[i].x
            let dy = leader.y - wyrmSegments[i].y
            let dist = sqrt(dx * dx + dy * dy)

            if dist > spacing {
                let angle = atan2(dy, dx)
                wyrmSegments[i] = CGPoint(
                    x: leader.x - cos(angle) * spacing,
                    y: leader.y - sin(angle) * spacing
                )
            }
            leader = wyrmSegments[i]
        }
    }

    private func checkWyrmBodyCollision() {
        guard bossPhase == 1 || bossPhase == 4 else { return }
        guard currentTime > playerInvulnerableUntil else { return }

        // Head collision
        let headDist = hypot(playerX - bossX, playerY - bossY)
        if headDist < BalanceConfig.TrojanWyrm.headCollisionRadius * 1.8 {
            takeDamage(BalanceConfig.TrojanWyrm.headContactDamage, source: "wyrmHead")
            playerInvulnerableUntil = currentTime + 0.5
            return
        }

        // Body segment collision
        for (i, seg) in wyrmSegments.enumerated() {
            // Skip ghost segment in phase 2
            if bossPhase == 2 && i == wyrmGhostSegmentIndex { continue }

            let dist = hypot(playerX - seg.x, playerY - seg.y)
            if dist < BalanceConfig.TrojanWyrm.bodyCollisionRadius * 2 {
                takeDamage(BalanceConfig.TrojanWyrm.bodyContactDamage, source: "wyrmBody")
                playerInvulnerableUntil = currentTime + 0.3
                return
            }
        }
    }

    private func normalizeAngle(_ angle: CGFloat) -> CGFloat {
        var a = angle
        while a > .pi { a -= 2 * .pi }
        while a < -.pi { a += 2 * .pi }
        return a
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
        // Process DoT ticks (Fragmenter)
        updateDoTDamage()

        // Process pending child projectiles (Recursion)
        processChildProjectiles()

        guard currentTime >= playerAttackCooldown else { return }

        let attackRange: CGFloat = weapon?.range ?? 300
        var damage = playerDamage * CGFloat(playerAttackInterval)

        // Apply tag bonus if boss is tagged (Pinger)
        if currentTime < bossTaggedUntil {
            let bonusDamage = damage * 0.2
            damage += bonusDamage
            result.bonusDamageDealt += bonusDamage
        }

        // Apply mark bonus if boss is marked (Garbage Collector self-buff)
        if currentTime < bossMarkedUntil {
            let bonusDamage = damage * 0.15
            damage += bonusDamage
            result.bonusDamageDealt += bonusDamage
        }

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

            // Apply base damage
            bossHealth -= damage
            result.totalDamageDealt += damage

            // Apply weapon-specific effects
            applyWeaponEffects(baseDamage: damage)
        }
    }

    /// Apply weapon-specific effects on hit
    private func applyWeaponEffects(baseDamage: CGFloat) {
        guard let weapon = weapon else { return }

        switch weapon.type {
        case .fragmenter:
            // Add 50% of damage as DoT over 1.5s (3 ticks of 0.5s)
            let dotDamage = baseDamage * 0.5
            dotDamageRemaining += dotDamage

        case .pinger:
            // Tag boss for 4 seconds (+20% damage from all sources) - buffed from 3s
            bossTaggedUntil = currentTime + 4.0

        case .throttler:
            // Slow boss for 2 seconds
            bossSlowedUntil = currentTime + 2.0
            // 15% chance to stun for 0.5s (buffed from 10%)
            if rng.nextDouble() < 0.15 {
                bossStunnedUntil = currentTime + 0.5
            }

        case .recursion:
            // Queue 2 child projectiles (35% damage each, applied next frame) - nerfed from 3 children at 50%
            pendingChildProjectiles += 2

        case .garbageCollector:
            // Mark boss for 15% self-damage bonus for 2 seconds
            bossMarkedUntil = currentTime + 2.0

        case .kernelPulse:
            // No special effect - baseline weapon
            break
        }
    }

    /// Process DoT damage (Fragmenter burn)
    private func updateDoTDamage() {
        guard dotDamageRemaining > 0 else { return }

        let tickInterval: TimeInterval = 0.5
        dotTickTimer += deltaTime

        if dotTickTimer >= tickInterval {
            dotTickTimer = 0

            // Apply tick damage (1/3 of remaining over 3 ticks)
            let tickDamage = min(dotDamageRemaining, dotDamageRemaining / 3)
            bossHealth -= tickDamage
            result.dotDamageDealt += tickDamage
            result.totalDamageDealt += tickDamage
            dotDamageRemaining -= tickDamage
        }
    }

    /// Process child projectiles (Recursion)
    private func processChildProjectiles() {
        guard pendingChildProjectiles > 0, !bossInvulnerable else { return }

        // Apply child damage instantly (35% of base per child - nerfed from 50%)
        let childDamage = (playerDamage * CGFloat(playerAttackInterval)) * 0.35
        let totalChildDamage = childDamage * CGFloat(pendingChildProjectiles)

        bossHealth -= totalChildDamage
        result.totalDamageDealt += totalChildDamage
        pendingChildProjectiles = 0
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

struct SimSteamSegment {
    let id: String
    var x: CGFloat
    var y: CGFloat
    let createdAt: TimeInterval
}

struct SimSubWorm {
    let id: Int
    var headX: CGFloat
    var headY: CGFloat
    var body: [CGPoint]
    var angle: CGFloat
}
