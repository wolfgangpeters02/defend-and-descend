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
// NOTE: These are simplified boss-fight weapon stats for Monte Carlo simulation.
// They intentionally differ from ProtocolBaseStats (which tracks tower/firewall mode).
// SimulatedWeaponType models player-held weapons in boss encounters with abstracted
// DPS multipliers for special effects (DoT, slow, split, etc.).

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
        BalanceConfig.Simulation.weaponDamage[rawValue] ?? 25
    }

    /// Attack interval in seconds
    var attackInterval: TimeInterval {
        BalanceConfig.Simulation.weaponAttackInterval[rawValue] ?? 0.5
    }

    /// Attack range
    var range: CGFloat {
        BalanceConfig.Simulation.weaponRange[rawValue] ?? 200
    }
}

struct SimulatedWeapon {
    let type: SimulatedWeaponType
    let level: Int

    /// Damage scaled by level (diminishing returns: Lv1=1x, Lv5=3x, Lv10=5.5x)
    var damage: CGFloat {
        type.baseDamage * (1.0 + CGFloat(level - 1) * BalanceConfig.Simulation.weaponDamageScalingPerLevel)
    }

    var attackInterval: TimeInterval { type.attackInterval }
    var range: CGFloat { type.range }

    /// Effective DPS accounting for attack interval and special mechanics
    var theoreticalDPS: CGFloat {
        let baseDPS = damage / CGFloat(attackInterval)
        switch type {
        case .fragmenter:
            return baseDPS * BalanceConfig.Simulation.fragmenterDPSMultiplier
        case .pinger:
            return baseDPS * BalanceConfig.Simulation.pingerDPSMultiplier
        case .recursion:
            return baseDPS * BalanceConfig.Simulation.recursionDPSMultiplier
        case .garbageCollector:
            return baseDPS * BalanceConfig.Simulation.garbageCollectorDPSMultiplier
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
    let playerWeaponDamage: CGFloat         // Base player DPS (fallback when no weapon specified)
    let playerHealth: CGFloat               // Base player health
    let arenaSize: CGFloat                  // Arena width/height
    let weapon: SimulatedWeapon?            // Optional weapon for detailed simulation

    static let defaultConfig = BossSimulationConfig(
        seed: 42,
        bossType: "cyberboss",
        difficulty: .normal,
        bot: AggressiveBot(),
        maxFightTime: BalanceConfig.Simulation.defaultMaxGameTime,
        playerWeaponDamage: BalanceConfig.Simulation.bossPlayerWeaponDamage,
        playerHealth: BalanceConfig.Player.baseHealth,
        arenaSize: BalanceConfig.Simulation.bossArenaSize,
        weapon: nil
    )
}

// MARK: - Result

struct BossSimulationResult {
    let bossType: String
    let difficulty: BossDifficulty
    let botName: String

    // Protocol info (optional)
    var protocolType: SimulatedWeaponType?
    var protocolLevel: Int = 1

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
    var playerSpeed: CGFloat = BalanceConfig.Simulation.bossPlayerSpeed
    var playerInvulnerableUntil: TimeInterval = 0
    var playerAttackCooldown: TimeInterval = 0
    var playerAttackInterval: TimeInterval = BalanceConfig.Simulation.bossPlayerAttackInterval

    // Boss state
    var bossX: CGFloat = 0
    var bossY: CGFloat = 0
    var bossHealth: CGFloat = 0
    var bossMaxHealth: CGFloat = 0
    var bossPhase: Int = 1
    var bossSpeed: CGFloat = BalanceConfig.Simulation.bossDefaultSpeed
    var bossInvulnerable: Bool = false

    // Arena
    var arenaWidth: CGFloat = BalanceConfig.Simulation.bossArenaSize
    var arenaHeight: CGFloat = BalanceConfig.Simulation.bossArenaSize
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
            protocolType: config.weapon?.type,
            protocolLevel: config.weapon?.level ?? 1
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
            return BalanceConfig.VoidHarbinger.baseHealth
        case "overclocker":
            return BalanceConfig.Overclocker.baseHealth
        case "trojan_wyrm":
            return BalanceConfig.TrojanWyrm.baseHealth
        default: // cyberboss
            return BalanceConfig.Cyberboss.baseHealth
        }
    }

    private func setupBossSpecificState() {
        switch config.bossType {
        case "overclocker":
            overclockerBladeAngle = 0
            overclockerTileStates = Array(repeating: 0, count: 16)
            steamTrail = []

        case "trojan_wyrm":
            // Initialize body segments
            let spacing = BalanceConfig.TrojanWyrm.segmentSpacing
            let segCount = BalanceConfig.TrojanWyrm.segmentCount
            wyrmSegments = []
            for i in 1...segCount {
                wyrmSegments.append(CGPoint(x: bossX, y: bossY - CGFloat(i) * spacing))
            }
            wyrmHeadAngle = CGFloat.random(in: 0...(2 * .pi))
            wyrmWallY = arenaHeight - BalanceConfig.TrojanWyrm.wallMargin
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
            if healthPercent <= BalanceConfig.VoidHarbinger.phase4Threshold && bossPhase < 4 {
                bossPhase = 4
                enterVoidHarbingerPhase4()
            } else if healthPercent <= BalanceConfig.VoidHarbinger.phase3Threshold && bossPhase < 3 {
                bossPhase = 3
                enterVoidHarbingerPhase3()
            } else if healthPercent <= BalanceConfig.VoidHarbinger.phase2Threshold && bossPhase < 2 {
                bossPhase = 2
                enterVoidHarbingerPhase2()
            }

        case "overclocker":
            if healthPercent <= BalanceConfig.Overclocker.phase4Threshold && bossPhase < 4 {
                bossPhase = 4
                enterOverclockerPhase4()
            } else if healthPercent <= BalanceConfig.Overclocker.phase3Threshold && bossPhase < 3 {
                bossPhase = 3
                enterOverclockerPhase3()
            } else if healthPercent <= BalanceConfig.Overclocker.phase2Threshold && bossPhase < 2 {
                bossPhase = 2
                enterOverclockerPhase2()
            }

        case "trojan_wyrm":
            if healthPercent <= BalanceConfig.TrojanWyrm.phase4Threshold && bossPhase < 4 {
                bossPhase = 4
                enterTrojanWyrmPhase4()
            } else if healthPercent <= BalanceConfig.TrojanWyrm.phase3Threshold && bossPhase < 3 {
                bossPhase = 3
                enterTrojanWyrmPhase3()
            } else if healthPercent <= BalanceConfig.TrojanWyrm.phase2Threshold && bossPhase < 2 {
                bossPhase = 2
                enterTrojanWyrmPhase2()
            }

        default:
            // Cyberboss
            if healthPercent <= BalanceConfig.Cyberboss.phase4Threshold && bossPhase < 4 {
                bossPhase = 4
                enterCyberbossPhase4()
            } else if healthPercent <= BalanceConfig.Cyberboss.phase3Threshold && bossPhase < 3 {
                bossPhase = 3
                enterCyberbossPhase3()
            } else if healthPercent <= BalanceConfig.Cyberboss.phase2Threshold && bossPhase < 2 {
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
        if modeTimer >= BalanceConfig.Cyberboss.modeSwitchInterval {
            modeTimer = 0
            cyberbossMode = cyberbossMode == .melee ? .ranged : .melee
        }

        if cyberbossMode == .melee {
            // Chase player
            moveBossTowards(x: playerX, y: playerY, speed: bossSpeed * BalanceConfig.Cyberboss.meleeChaseSpeedMultiplier)
        } else {
            // Keep distance and shoot
            let dx = bossX - playerX
            let dy = bossY - playerY
            let dist = sqrt(dx * dx + dy * dy)

            if dist < 400 {
                moveBossAway(fromX: playerX, fromY: playerY, speed: bossSpeed * BalanceConfig.Cyberboss.rangedMoveAwaySpeed)
            } else if dist > 500 {
                moveBossTowards(x: playerX, y: playerY, speed: bossSpeed * BalanceConfig.Cyberboss.rangedMoveCloserSpeed)
            }

            // Fire ranged attack
            if currentTime - lastRangedAttack >= BalanceConfig.Cyberboss.rangedAttackCooldown {
                lastRangedAttack = currentTime
                fireRangedVolley()
            }
        }
    }

    private func updateCyberbossPhase2() {
        updateCyberbossPhase1()

        // Spawn minions
        if currentTime - lastMinionSpawn >= BalanceConfig.Cyberboss.minionSpawnIntervalPhase2 {
            lastMinionSpawn = currentTime
            spawnMinions(count: 3)
        }
    }

    private func enterCyberbossPhase2() {
        // Phase 2 adds minions
    }

    private func updateCyberbossPhase3() {
        // Boss stationary, spawn puddles
        if currentTime - lastPuddleSpawn >= BalanceConfig.Cyberboss.puddleSpawnIntervalPhase3 {
            lastPuddleSpawn = currentTime
            spawnPuddles(count: rng.nextInt(in: BalanceConfig.Cyberboss.puddleCountMin...BalanceConfig.Cyberboss.puddleCountMax))
        }

        // Reduced minion spawns
        if currentTime - lastMinionSpawn >= BalanceConfig.Cyberboss.minionSpawnIntervalPhase1 {
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
            lasers[i].angle += BalanceConfig.Cyberboss.laserRotationSpeed * CGFloat(deltaTime)
        }

        // Faster puddles
        if currentTime - lastPuddleSpawn >= BalanceConfig.Cyberboss.puddleSpawnIntervalPhase4 {
            lastPuddleSpawn = currentTime
            spawnPuddles(count: 3)
        }
    }

    private func enterCyberbossPhase4() {
        // Create rotating lasers
        let beamCount = BalanceConfig.Cyberboss.laserBeamCount
        let angleSpacing = CGFloat(360) / CGFloat(beamCount)
        for i in 0..<beamCount {
            lasers.append(SimLaser(
                id: "laser_\(i)",
                originX: bossX,
                originY: bossY,
                angle: CGFloat(i) * angleSpacing,
                length: BalanceConfig.Cyberboss.laserBeamLength,
                damage: BalanceConfig.Cyberboss.laserBeamDamage,
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
        moveBossTowards(x: playerX, y: playerY, speed: bossSpeed * BalanceConfig.VoidHarbinger.phase1ChaseMultiplier)

        // Void zones at player
        if currentTime - lastVoidZoneSpawn >= BalanceConfig.VoidHarbinger.voidZoneIntervalPhase1 {
            lastVoidZoneSpawn = currentTime
            spawnVoidZone(at: CGPoint(x: playerX, y: playerY))
        }

        // Shadow bolt volley
        if currentTime - lastVolleyTime >= BalanceConfig.VoidHarbinger.volleyInterval {
            lastVolleyTime = currentTime
            fireShadowBoltVolley()
        }

        // Minions
        if currentTime - lastMinionSpawn >= BalanceConfig.VoidHarbinger.minionSpawnInterval {
            lastMinionSpawn = currentTime
            spawnMinions(count: BalanceConfig.VoidHarbinger.minionCount)
        }
    }

    private func enterVoidHarbingerPhase2() {
        bossInvulnerable = true

        // Spawn pylons
        let ox = BalanceConfig.VoidHarbinger.pylonOffsetX
        let oy = BalanceConfig.VoidHarbinger.pylonOffsetY
        let offsets: [(CGFloat, CGFloat)] = [
            (-ox, -oy), (ox, -oy), (-ox, oy), (ox, oy)
        ]
        for (i, offset) in offsets.enumerated() {
            pylons.append(SimPylon(
                id: "pylon_\(i)",
                x: arenaCenter.x + offset.0,
                y: arenaCenter.y + offset.1,
                health: BalanceConfig.VoidHarbinger.pylonHealth,
                maxHealth: BalanceConfig.VoidHarbinger.pylonHealth,
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
            if currentTime - pylons[i].lastBeamTime >= BalanceConfig.VoidHarbinger.pylonBeamInterval {
                pylons[i].lastBeamTime = currentTime
                fireHomingProjectile(fromX: pylons[i].x, fromY: pylons[i].y, damage: BalanceConfig.VoidHarbinger.pylonBeamDamage)
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
        let riftCount = BalanceConfig.VoidHarbinger.voidRiftCount
        let riftAngleSpacing = CGFloat(360) / CGFloat(riftCount)
        for i in 0..<riftCount {
            voidRifts.append(SimVoidRift(
                id: "rift_\(i)",
                angle: CGFloat(i) * riftAngleSpacing,
                rotationSpeed: BalanceConfig.VoidHarbinger.voidRiftRotationSpeed,
                length: BalanceConfig.VoidHarbinger.voidRiftLength,
                damage: BalanceConfig.VoidHarbinger.voidRiftDamage
            ))
        }

        // Create gravity wells
        let gwOffset = BalanceConfig.VoidHarbinger.gravityWellOffsetX
        let gwRadius = BalanceConfig.VoidHarbinger.gravityWellPullRadius
        let gwStrength = BalanceConfig.VoidHarbinger.gravityWellPullStrength
        gravityWells = [
            SimGravityWell(id: "gw_1", x: arenaCenter.x - gwOffset, y: arenaCenter.y, pullRadius: gwRadius, pullStrength: gwStrength),
            SimGravityWell(id: "gw_2", x: arenaCenter.x + gwOffset, y: arenaCenter.y, pullRadius: gwRadius, pullStrength: gwStrength)
        ]
    }

    private func updateVoidHarbingerPhase3() {
        // Chase at phase 3 speed
        moveBossTowards(x: playerX, y: playerY, speed: bossSpeed * BalanceConfig.VoidHarbinger.phase3ChaseMultiplier)

        // Void zones
        if currentTime - lastVoidZoneSpawn >= BalanceConfig.VoidHarbinger.voidZoneIntervalPhase1 * 0.75 {
            lastVoidZoneSpawn = currentTime
            spawnVoidZone(at: CGPoint(x: playerX, y: playerY))
        }

        // Meteors
        if currentTime - lastMeteorTime >= BalanceConfig.VoidHarbinger.meteorInterval {
            lastMeteorTime = currentTime
            let offset = BalanceConfig.VoidHarbinger.meteorSpawnOffset
            spawnVoidZone(at: CGPoint(
                x: playerX + rng.nextCGFloat(in: -offset...offset),
                y: playerY + rng.nextCGFloat(in: -offset...offset)
            ), radius: BalanceConfig.VoidHarbinger.meteorRadius, damage: BalanceConfig.VoidHarbinger.meteorDamage)
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
        if currentTime - lastTeleportTime >= BalanceConfig.VoidHarbinger.teleportInterval {
            lastTeleportTime = currentTime
            let maxOffset = shrinkingArenaRadius * BalanceConfig.VoidHarbinger.teleportOffsetRatio
            bossX = arenaCenter.x + rng.nextCGFloat(in: -maxOffset...maxOffset)
            bossY = arenaCenter.y + rng.nextCGFloat(in: -maxOffset...maxOffset)
        }

        // Shrink arena
        if shrinkingArenaRadius > BalanceConfig.VoidHarbinger.arenaMinRadius {
            shrinkingArenaRadius -= BalanceConfig.VoidHarbinger.arenaShrinkRate * CGFloat(deltaTime)
        }

        // Outside arena damage
        let dx = playerX - arenaCenter.x
        let dy = playerY - arenaCenter.y
        let distFromCenter = sqrt(dx * dx + dy * dy)
        if distFromCenter > shrinkingArenaRadius {
            takeDamage(BalanceConfig.VoidHarbinger.outsideArenaDPS * CGFloat(deltaTime), source: "arena")
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
        let rotationSpeed: CGFloat = BalanceConfig.Overclocker.bladeRotationSpeed * (.pi / 180)
        overclockerBladeAngle += rotationSpeed * CGFloat(deltaTime)
        if overclockerBladeAngle > .pi * 2 {
            overclockerBladeAngle -= .pi * 2
        }

        // Move towards center
        moveBossTowards(x: arenaCenter.x, y: arenaCenter.y, speed: BalanceConfig.Overclocker.phase1CenterSpeed)

        // Wind pushes player away from boss
        let windForce = BalanceConfig.Overclocker.windForce
        let dx = playerX - bossX
        let dy = playerY - bossY
        let dist = sqrt(dx * dx + dy * dy)
        let maxDist = BalanceConfig.Overclocker.windMaxDistance
        if dist < maxDist && dist > 1 {
            let strength = windForce * (1.0 - (dist / maxDist))
            let angle = atan2(dy, dx)
            playerX += cos(angle) * strength * CGFloat(deltaTime)
            playerY += sin(angle) * strength * CGFloat(deltaTime)
            playerX = clamp(playerX, min: BalanceConfig.Player.boundsPadding, max: arenaWidth - BalanceConfig.Player.boundsPadding)
            playerY = clamp(playerY, min: BalanceConfig.Player.boundsPadding, max: arenaHeight - BalanceConfig.Player.boundsPadding)
        }

        // Check blade collision
        let bladeRadius = BalanceConfig.Overclocker.bladeOrbitRadius
        let bladeCount = BalanceConfig.Overclocker.bladeCount
        for i in 0..<bladeCount {
            let angleOffset = CGFloat(i) * (2 * .pi / CGFloat(bladeCount))
            let currentAngle = overclockerBladeAngle + angleOffset
            let bladeTipX = bossX + cos(currentAngle) * bladeRadius
            let bladeTipY = bossY + sin(currentAngle) * bladeRadius

            let bladeDist = pointToLineDistance(px: playerX, py: playerY,
                                                 x1: bossX, y1: bossY,
                                                 x2: bladeTipX, y2: bladeTipY)
            if bladeDist < BalanceConfig.Overclocker.bladeWidth {
                takeDamage(BalanceConfig.Overclocker.bladeDamage, source: "blade")
                playerInvulnerableUntil = currentTime + BalanceConfig.Player.invulnerabilityDuration
                break
            }
        }
    }

    private func enterOverclockerPhase2() {
        overclockerTileStates = Array(repeating: 0, count: 16)
        lastTileChangeTime = 0
    }

    private func updateOverclockerPhase2() {
        let tileChangeInterval = BalanceConfig.Overclocker.tileChangeInterval
        let warningDuration = BalanceConfig.Overclocker.tileWarningDuration

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
        moveBossTowards(x: targetPos.x, y: targetPos.y, speed: BalanceConfig.Overclocker.phase2BossMoveSpeed)

        // Check player lava damage
        let col = Int((playerX - 0) / (arenaWidth / 4))
        let row = Int((playerY - 0) / (arenaHeight / 4))
        if col >= 0 && col < 4 && row >= 0 && row < 4 {
            let index = row * 4 + col
            if index < overclockerTileStates.count && overclockerTileStates[index] == 2 {
                takeDamage(BalanceConfig.Overclocker.lavaTileDPS * CGFloat(deltaTime), source: "lava")
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
        moveBossTowards(x: playerX, y: playerY, speed: BalanceConfig.Overclocker.chaseSpeed)

        // Drop steam
        let steamDropInterval = BalanceConfig.Overclocker.steamDropInterval
        if currentTime - lastSteamDropTime > steamDropInterval {
            lastSteamDropTime = currentTime
            steamTrail.append(SimSteamSegment(
                id: UUID().uuidString,
                x: bossX,
                y: bossY,
                createdAt: currentTime
            ))

            // Cap trail length
            if steamTrail.count > BalanceConfig.Overclocker.maxSteamSegments {
                steamTrail.removeFirst()
            }
        }

        // Steam damage
        for segment in steamTrail {
            let dist = hypot(playerX - segment.x, playerY - segment.y)
            if dist < BalanceConfig.Overclocker.steamRadius {
                takeDamage(BalanceConfig.Overclocker.steamDPS * CGFloat(deltaTime), source: "steam")
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
        moveBossTowards(x: arenaCenter.x, y: arenaCenter.y, speed: BalanceConfig.Overclocker.phase4CenterSpeed)

        // Toggle suction
        overclockerSuctionTimer += deltaTime
        let suctionPullDuration = BalanceConfig.Overclocker.suctionPullDuration
        let suctionPauseDuration = BalanceConfig.Overclocker.suctionPauseDuration

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
            let vacuumStrength = BalanceConfig.Overclocker.vacuumPullStrength
            let dx = bossX - playerX
            let dy = bossY - playerY
            let angle = atan2(dy, dx)
            playerX += cos(angle) * vacuumStrength * CGFloat(deltaTime)
            playerY += sin(angle) * vacuumStrength * CGFloat(deltaTime)
            playerX = clamp(playerX, min: BalanceConfig.Player.boundsPadding, max: arenaWidth - BalanceConfig.Player.boundsPadding)
            playerY = clamp(playerY, min: BalanceConfig.Player.boundsPadding, max: arenaHeight - BalanceConfig.Player.boundsPadding)
        }

        // Continue steam trail
        let steamDropInterval = BalanceConfig.Overclocker.steamDropInterval
        if currentTime - lastSteamDropTime > steamDropInterval {
            lastSteamDropTime = currentTime
            steamTrail.append(SimSteamSegment(
                id: UUID().uuidString,
                x: bossX,
                y: bossY,
                createdAt: currentTime
            ))
            if steamTrail.count > BalanceConfig.Overclocker.maxSteamSegments {
                steamTrail.removeFirst()
            }
        }

        // Steam damage
        for segment in steamTrail {
            let dist = hypot(playerX - segment.x, playerY - segment.y)
            if dist < BalanceConfig.Overclocker.steamRadius {
                takeDamage(BalanceConfig.Overclocker.steamDPS * CGFloat(deltaTime), source: "steam")
                break
            }
        }

        // Shredder damage when close to boss
        let distToBoss = hypot(playerX - bossX, playerY - bossY)
        if distToBoss < BalanceConfig.Overclocker.shredderRadius {
            takeDamage(BalanceConfig.Overclocker.shredderDPS * CGFloat(deltaTime), source: "shredder")
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
        let padding = BalanceConfig.TrojanWyrm.lungeBoundsPadding
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
        wyrmWallY = arenaHeight - BalanceConfig.TrojanWyrm.wallMargin
        wyrmWallDirection = -1
        wyrmGhostSegmentIndex = Int.random(in: 3..<min(21, wyrmSegments.count))
    }

    private func updateTrojanWyrmPhase2() {
        let wallSweepSpeed = BalanceConfig.TrojanWyrm.wallSweepSpeed
        let segmentSpacing = BalanceConfig.TrojanWyrm.segmentSpacing

        // Move wall
        wyrmWallY += wallSweepSpeed * CGFloat(deltaTime) * wyrmWallDirection

        // Bounce at edges
        let wallMargin = BalanceConfig.TrojanWyrm.wallMargin
        if wyrmWallY < wallMargin {
            wyrmWallDirection = 1
            wyrmWallY = wallMargin
            wyrmGhostSegmentIndex = Int.random(in: 3..<min(21, wyrmSegments.count))
        } else if wyrmWallY > arenaHeight - wallMargin {
            wyrmWallDirection = -1
            wyrmWallY = arenaHeight - wallMargin
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
            let spawnDist = BalanceConfig.TrojanWyrm.subWormSpawnDistance
            let pos = CGPoint(
                x: arenaCenter.x + cos(angle) * spawnDist,
                y: arenaCenter.y + sin(angle) * spawnDist
            )
            var body: [CGPoint] = []
            for k in 1...bodyCount {
                body.append(CGPoint(x: pos.x, y: pos.y - CGFloat(k) * BalanceConfig.TrojanWyrm.subWormSegmentSpacing))
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
                let spacing = BalanceConfig.TrojanWyrm.subWormBodySpacing
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
                playerInvulnerableUntil = currentTime + BalanceConfig.Player.invulnerabilityDuration
            }
            for seg in worm.body {
                let segDist = hypot(playerX - seg.x, playerY - seg.y)
                if segDist < BalanceConfig.TrojanWyrm.subWormBodySize * BalanceConfig.TrojanWyrm.simSubWormCollisionMultiplier {
                    takeDamage(bodyDamage, source: "wyrmBody")
                    playerInvulnerableUntil = currentTime + BalanceConfig.TrojanWyrm.contactCooldown
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
            if distToHead < BalanceConfig.TrojanWyrm.headCollisionRadius * BalanceConfig.TrojanWyrm.simHeadCollisionMultiplier {
                takeDamage(BalanceConfig.TrojanWyrm.headContactDamage * CGFloat(deltaTime), source: "ring")
            }
            for seg in wyrmSegments {
                let dist = hypot(playerX - seg.x, playerY - seg.y)
                if dist < BalanceConfig.TrojanWyrm.bodyCollisionRadius * BalanceConfig.TrojanWyrm.simBodyCollisionMultiplier {
                    takeDamage(BalanceConfig.TrojanWyrm.bodyContactDamage * CGFloat(deltaTime), source: "ring")
                    break
                }
            }

            // Trigger lunge after circling
            wyrmAimTimer += deltaTime
            if wyrmAimTimer > BalanceConfig.TrojanWyrm.circlingDuration {
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
            let lungePadding = BalanceConfig.TrojanWyrm.lungeBoundsPadding
            if bossX < lungePadding || bossX > arenaWidth - lungePadding ||
               bossY < lungePadding || bossY > arenaHeight - lungePadding ||
               wyrmLungeTimer > BalanceConfig.TrojanWyrm.lungeDuration {
                wyrmPhase4SubState = 3  // recovering
                wyrmRecoverTimer = 0
            }

            // Lunge head does extra damage
            let distToHead = hypot(playerX - bossX, playerY - bossY)
            if distToHead < BalanceConfig.TrojanWyrm.headCollisionRadius * BalanceConfig.TrojanWyrm.simBodyCollisionMultiplier {
                takeDamage(BalanceConfig.TrojanWyrm.lungeHeadDamage, source: "lunge")
                playerInvulnerableUntil = currentTime + BalanceConfig.TrojanWyrm.lungeDuration
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
        if headDist < BalanceConfig.TrojanWyrm.headCollisionRadius * BalanceConfig.TrojanWyrm.simHeadCollisionMultiplier {
            takeDamage(BalanceConfig.TrojanWyrm.headContactDamage, source: "wyrmHead")
            playerInvulnerableUntil = currentTime + BalanceConfig.Player.invulnerabilityDuration
            return
        }

        // Body segment collision
        for (i, seg) in wyrmSegments.enumerated() {
            // Skip ghost segment in phase 2
            if bossPhase == 2 && i == wyrmGhostSegmentIndex { continue }

            let dist = hypot(playerX - seg.x, playerY - seg.y)
            if dist < BalanceConfig.TrojanWyrm.bodyCollisionRadius * BalanceConfig.TrojanWyrm.simBodyCollisionMultiplier {
                takeDamage(BalanceConfig.TrojanWyrm.bodyContactDamage, source: "wyrmBody")
                playerInvulnerableUntil = currentTime + BalanceConfig.TrojanWyrm.contactCooldown
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
            playerX = clamp(playerX + moveX, min: BalanceConfig.Player.boundsPadding, max: arenaWidth - BalanceConfig.Player.boundsPadding)
            playerY = clamp(playerY + moveY, min: BalanceConfig.Player.boundsPadding, max: arenaHeight - BalanceConfig.Player.boundsPadding)

        case .moveTowards(let x, let y):
            let dx = x - playerX
            let dy = y - playerY
            let dist = sqrt(dx * dx + dy * dy)
            if dist > 1 {
                let moveX = (dx / dist) * playerSpeed * CGFloat(deltaTime)
                let moveY = (dy / dist) * playerSpeed * CGFloat(deltaTime)
                playerX = clamp(playerX + moveX, min: BalanceConfig.Player.boundsPadding, max: arenaWidth - BalanceConfig.Player.boundsPadding)
                playerY = clamp(playerY + moveY, min: BalanceConfig.Player.boundsPadding, max: arenaHeight - BalanceConfig.Player.boundsPadding)
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
            let bonusDamage = damage * BalanceConfig.Simulation.pingerTagBonusDamage
            damage += bonusDamage
            result.bonusDamageDealt += bonusDamage
        }

        // Apply mark bonus if boss is marked (Garbage Collector self-buff)
        if currentTime < bossMarkedUntil {
            let bonusDamage = damage * BalanceConfig.Simulation.garbageCollectorMarkBonusDamage
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
            // Add DoT over 1.5s (3 ticks)
            let dotDamage = baseDamage * BalanceConfig.Simulation.fragmenterDotMultiplier
            dotDamageRemaining += dotDamage

        case .pinger:
            // Tag boss (+20% damage from all sources)
            bossTaggedUntil = currentTime + BalanceConfig.Simulation.pingerTagDuration

        case .throttler:
            // Slow boss
            bossSlowedUntil = currentTime + BalanceConfig.Simulation.throttlerSlowDuration
            // Chance to stun
            if rng.nextDouble() < BalanceConfig.Simulation.throttlerStunChance {
                bossStunnedUntil = currentTime + BalanceConfig.Simulation.throttlerStunDuration
            }

        case .recursion:
            // Queue child projectiles (35% damage each, applied next frame)
            pendingChildProjectiles += BalanceConfig.Simulation.recursionChildCount

        case .garbageCollector:
            // Mark boss for 15% self-damage bonus
            bossMarkedUntil = currentTime + BalanceConfig.Simulation.garbageCollectorMarkDuration

        case .kernelPulse:
            // No special effect - baseline weapon
            break
        }
    }

    /// Process DoT damage (Fragmenter burn)
    private func updateDoTDamage() {
        guard dotDamageRemaining > 0 else { return }

        let tickInterval = BalanceConfig.Simulation.fragmenterTickInterval
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

        // Apply child damage instantly
        let childDamage = (playerDamage * CGFloat(playerAttackInterval)) * BalanceConfig.Simulation.recursionChildDamageMultiplier
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
                    let homingForce = BalanceConfig.Simulation.projectileHomingForce
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

        let playerRadius = BalanceConfig.Simulation.bossPlayerCollisionRadius

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
        for laser in lasers where laser.lifetime >= BalanceConfig.Simulation.bossLaserCollisionMinLifetime {
            if isHitByLaser(laser) {
                takeDamage(laser.damage, source: "laser")
                result.laserHits += 1
                playerInvulnerableUntil = currentTime + BalanceConfig.Cyberboss.laserHitInvulnerability
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
        return dist < BalanceConfig.Cyberboss.simLaserHitRadius
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
        return dist < BalanceConfig.VoidHarbinger.simRiftHitRadius
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
            playerHealth = playerMaxHealth * BalanceConfig.Player.reviveHealthPercent
            playerInvulnerableUntil = currentTime + BalanceConfig.Player.reviveInvulnerabilityDuration
        }
    }

    // MARK: - Spawn Helpers

    private func spawnPuddles(count: Int) {
        for _ in 0..<count {
            puddles.append(SimPuddle(
                id: UUID().uuidString,
                x: rng.nextCGFloat(in: BalanceConfig.Simulation.minionSpawnMargin...(arenaWidth - BalanceConfig.Simulation.minionSpawnMargin)),
                y: rng.nextCGFloat(in: BalanceConfig.Simulation.minionSpawnMargin...(arenaHeight - BalanceConfig.Simulation.minionSpawnMargin)),
                radius: BalanceConfig.Cyberboss.puddleRadius,
                dps: BalanceConfig.Cyberboss.puddleDPS,
                lifetime: 0,
                maxLifetime: BalanceConfig.Cyberboss.puddleMaxLifetime,
                warningTime: BalanceConfig.Cyberboss.puddleWarningDuration
            ))
        }
    }

    private func spawnVoidZone(at pos: CGPoint,
                               radius: CGFloat = BalanceConfig.VoidHarbinger.voidZoneRadius,
                               damage: CGFloat = BalanceConfig.VoidHarbinger.voidZoneDamage) {
        voidZones.append(SimVoidZone(
            id: UUID().uuidString,
            x: pos.x,
            y: pos.y,
            radius: radius,
            damage: damage,
            lifetime: 0,
            warningTime: BalanceConfig.VoidHarbinger.voidZoneWarningTime,
            activeTime: BalanceConfig.VoidHarbinger.voidZoneActiveTime,
            isActive: false
        ))
    }

    private func spawnMinions(count: Int) {
        for _ in 0..<count {
            let angle = rng.nextCGFloat(in: 0...(2 * .pi))
            let dist = rng.nextCGFloat(in: BalanceConfig.VoidHarbinger.minionSpawnDistanceMin...BalanceConfig.VoidHarbinger.minionSpawnDistanceMax)

            minions.append(SimMinion(
                id: UUID().uuidString,
                x: bossX + cos(angle) * dist,
                y: bossY + sin(angle) * dist,
                health: BalanceConfig.VoidHarbinger.minionHealth,
                damage: BalanceConfig.VoidHarbinger.minionDamage,
                speed: BalanceConfig.VoidHarbinger.minionSpeed,
                size: 20,
                isDead: false
            ))
        }
    }

    private func fireRangedVolley() {
        let count = BalanceConfig.Cyberboss.rangedProjectileCount
        let spread = BalanceConfig.Cyberboss.rangedSpreadAngle
        let baseAngle = atan2(playerY - bossY, playerX - bossX)

        for i in 0..<count {
            let angle = baseAngle - spread / 2 + (spread / CGFloat(count - 1)) * CGFloat(i)
            projectiles.append(SimProjectile(
                id: UUID().uuidString,
                x: bossX,
                y: bossY,
                velocityX: cos(angle) * BalanceConfig.Cyberboss.rangedProjectileSpeed,
                velocityY: sin(angle) * BalanceConfig.Cyberboss.rangedProjectileSpeed,
                damage: BalanceConfig.Cyberboss.rangedProjectileDamage,
                radius: 15,
                lifetime: 0,
                maxLifetime: BalanceConfig.Cyberboss.rangedProjectileLifetime,
                isHoming: false
            ))
        }
    }

    private func fireShadowBoltVolley() {
        let count = BalanceConfig.VoidHarbinger.volleyProjectileCount
        let baseAngle = atan2(playerY - bossY, playerX - bossX)

        for i in 0..<count {
            let offset = CGFloat(i - count / 2) * BalanceConfig.VoidHarbinger.volleySpreadAngle
            let angle = baseAngle + offset
            projectiles.append(SimProjectile(
                id: UUID().uuidString,
                x: bossX,
                y: bossY,
                velocityX: cos(angle) * BalanceConfig.VoidHarbinger.volleyProjectileSpeed,
                velocityY: sin(angle) * BalanceConfig.VoidHarbinger.volleyProjectileSpeed,
                damage: BalanceConfig.VoidHarbinger.volleyProjectileDamage,
                radius: BalanceConfig.VoidHarbinger.volleyProjectileRadius,
                lifetime: 0,
                maxLifetime: BalanceConfig.VoidHarbinger.volleyProjectileLifetime,
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
            velocityX: (dx / dist) * BalanceConfig.VoidHarbinger.pylonBeamSpeed,
            velocityY: (dy / dist) * BalanceConfig.VoidHarbinger.pylonBeamSpeed,
            damage: damage,
            radius: BalanceConfig.VoidHarbinger.pylonBeamRadius,
            lifetime: 0,
            maxLifetime: BalanceConfig.VoidHarbinger.pylonBeamLifetime,
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
        let bossPadding = BalanceConfig.Simulation.bossArenaPadding
        bossX = clamp(bossX, min: bossPadding, max: arenaWidth - bossPadding)
        bossY = clamp(bossY, min: bossPadding, max: arenaHeight - bossPadding)
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
