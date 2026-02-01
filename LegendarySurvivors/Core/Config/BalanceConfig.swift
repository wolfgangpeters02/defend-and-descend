import Foundation
import CoreGraphics

// MARK: - Balance Config
// Centralized game balance values for easy tuning
// All hardcoded numbers should live here for discoverability

struct BalanceConfig {

    // MARK: - Player Stats

    struct Player {
        /// Base health at level 1, before upgrades
        static let baseHealth: CGFloat = 200

        /// Base movement speed (units/second)
        static let baseSpeed: CGFloat = 200

        /// Player hitbox radius
        static let size: CGFloat = 15

        /// Base pickup magnet radius
        static let pickupRange: CGFloat = 50

        /// Base health regeneration per second
        static let baseRegen: CGFloat = 1.5

        /// Duration of invulnerability after taking damage
        static let invulnerabilityDuration: TimeInterval = 0.5

        /// Duration of invulnerability after revive
        static let reviveInvulnerabilityDuration: TimeInterval = 3.0

        /// Speed of coins/pickups being magnetized toward player
        static let coinMagnetSpeed: CGFloat = 400
    }

    // MARK: - Wave Scaling (TD Mode)

    struct Waves {
        /// Health multiplier increase per wave (+15% = 0.15)
        static let healthScalingPerWave: CGFloat = 0.15

        /// Speed multiplier increase per wave (+2% = 0.02)
        static let speedScalingPerWave: CGFloat = 0.02

        /// Base enemy count formula: baseCount + (waveNumber * countPerWave)
        static let baseEnemyCount: Int = 5
        static let enemiesPerWave: Int = 2

        /// Boss waves occur every N waves
        static let bossWaveInterval: Int = 5

        /// Boss health multiplier (on top of wave scaling)
        static let bossHealthMultiplier: CGFloat = 2.0

        /// Boss speed multiplier (slower than normal)
        static let bossSpeedMultiplier: CGFloat = 0.8

        /// Minimum delay between enemy spawns (gets faster over waves)
        static let minSpawnDelay: CGFloat = 0.3
        static let baseSpawnDelay: CGFloat = 0.8
        static let spawnDelayReductionPerWave: CGFloat = 0.02

        /// Bonus Hash per wave completion (waveNumber × this value)
        static let hashBonusPerWave: Int = 10

        /// Seconds between waves
        static let waveCooldown: TimeInterval = 10.0
    }

    // MARK: - Threat Level Scaling (Idle TD Mode)

    struct ThreatLevel {
        /// Health scaling per threat level (+15%)
        static let healthScaling: CGFloat = 0.15

        /// Speed scaling per threat level (+2%)
        static let speedScaling: CGFloat = 0.02

        /// Damage scaling per threat level (+5%)
        static let damageScaling: CGFloat = 0.05

        /// Threat level thresholds for enemy type unlocks
        static let fastEnemyThreshold: CGFloat = 2.0
        static let swarmEnemyThreshold: CGFloat = 4.0   // Swarm enemies - weak but fast
        static let tankEnemyThreshold: CGFloat = 5.0
        static let eliteEnemyThreshold: CGFloat = 8.0   // Stronger fast enemies
        static let bossEnemyThreshold: CGFloat = 10.0

        /// Weight scaling for enemy types (how fast they ramp up)
        static let fastEnemyWeightPerThreat: CGFloat = 15  // max 60
        static let swarmEnemyWeightPerThreat: CGFloat = 12 // max 50
        static let tankEnemyWeightPerThreat: CGFloat = 10  // max 40
        static let eliteEnemyWeightPerThreat: CGFloat = 8  // max 30
        static let bossEnemyWeightPerThreat: CGFloat = 2   // max 10

        /// Max weights for each enemy type
        static let fastEnemyMaxWeight: Int = 60
        static let swarmEnemyMaxWeight: Int = 50
        static let tankEnemyMaxWeight: Int = 40
        static let eliteEnemyMaxWeight: Int = 30
        static let bossEnemyMaxWeight: Int = 10
    }

    // MARK: - Tower Economy

    struct Towers {
        /// Placement cost by rarity (Hash)
        static let placementCosts: [Rarity: Int] = [
            .common: 50,
            .rare: 100,
            .epic: 200,
            .legendary: 400
        ]

        /// Upgrade cost formula: baseUpgradeCost × level
        /// (baseUpgradeCost is defined per Protocol in Protocol.swift)
        static let upgradeInvestmentPerLevel: Int = 75  // For refund calculation

        /// Refund percentage when selling (50%)
        static let refundRate: CGFloat = 0.5

        /// Projectile settings
        static let projectileSpeed: CGFloat = 600
        static let projectileHitboxRadius: CGFloat = 8
        static let projectileLifetime: TimeInterval = 3.0
        static let homingStrength: CGFloat = 8.0
        static let multiShotSpreadAngle: CGFloat = 0.15

        /// Lead targeting prediction cap (seconds)
        static let maxPredictionTime: CGFloat = 0.8
    }

    // MARK: - Boss Scaling (Survivor Mode)

    struct BossSurvivor {
        /// Time-based health scaling: 1 + (minutes × this)
        static let healthScalingPerMinute: Double = 0.10

        /// Base health multiplier for boss spawns
        static let baseHealthMultiplier: Double = 4.0

        /// Spawn interval in seconds
        static let spawnInterval: TimeInterval = 120

        /// Phase transition health thresholds (percentage)
        static let phase2Threshold: CGFloat = 0.75
        static let phase3Threshold: CGFloat = 0.50
        static let phase4Threshold: CGFloat = 0.25

        /// Phase bonuses
        static let phaseSpeedMultiplier: CGFloat = 1.2
        static let phaseDamageMultiplier: CGFloat = 1.15
    }

    // MARK: - Cyberboss Configuration

    struct Cyberboss {
        // Phase thresholds (health percentage)
        static let phase2Threshold: CGFloat = 0.75
        static let phase3Threshold: CGFloat = 0.50
        static let phase4Threshold: CGFloat = 0.25

        // Mode switching (Phase 1-2)
        static let modeSwitchInterval: Double = 5.0

        // Minion spawns
        static let minionSpawnIntervalPhase1: Double = 10.0
        static let minionSpawnIntervalPhase2: Double = 8.0
        static let maxMinionsOnScreen: Int = 25
        static let fastMinionCountMin: Int = 5
        static let fastMinionCountMax: Int = 6
        static let tankMinionCountMin: Int = 4
        static let tankMinionCountMax: Int = 5

        // Melee mode
        static let meleeDPS: CGFloat = 150
        static let meleeChaseSpeedMultiplier: CGFloat = 1.2

        // Ranged mode
        static let rangedAttackCooldown: Double = 1.2
        static let rangedProjectileCount: Int = 5
        static let rangedSpreadAngle: CGFloat = .pi / 4.5  // ~40 degrees total
        static let rangedProjectileSpeed: CGFloat = 180
        static let rangedProjectileDamage: CGFloat = 25
        static let rangedPreferredDistance: CGFloat = 450

        // Damage puddles (Phase 3-4)
        static let puddleSpawnIntervalPhase3: Double = 2.0
        static let puddleSpawnIntervalPhase4: Double = 1.5
        static let puddleCountMin: Int = 2  // Reduced from 3 for performance
        static let puddleCountMax: Int = 3  // Reduced from 5 for performance
        static let puddleRadius: CGFloat = 60
        static let puddleDPS: CGFloat = 10
        static let puddlePopDamage: CGFloat = 30
        static let puddleDamageInterval: Double = 0.5
        static let puddleMaxLifetime: Double = 4.0
        static let puddleWarningDuration: Double = 1.0

        // Laser beams (Phase 4)
        static let laserBeamCount: Int = 5
        static let laserBeamLength: CGFloat = 800
        static let laserBeamDamage: CGFloat = 50
        static let laserRotationSpeed: CGFloat = 25.0  // degrees per second
        static let laserBeamWidth: CGFloat = 10
    }

    // MARK: - Void Harbinger Configuration

    struct VoidHarbinger {
        // Phase thresholds (health percentage)
        static let phase2Threshold: CGFloat = 0.70
        static let phase3Threshold: CGFloat = 0.40
        static let phase4Threshold: CGFloat = 0.10

        // Void zones
        static let voidZoneIntervalPhase1: Double = 8.0
        static let voidZoneIntervalPhase4: Double = 2.0
        static let voidZoneRadius: CGFloat = 80
        static let voidZoneDamage: CGFloat = 40  // DPS
        static let voidZoneWarningTime: Double = 2.0
        static let voidZoneActiveTime: Double = 5.0

        // Meteor strikes (Phase 3+)
        static let meteorInterval: Double = 6.0
        static let meteorRadius: CGFloat = 100
        static let meteorDamage: CGFloat = 80

        // Shadow bolt volley
        static let volleyInterval: Double = 6.0
        static let volleyProjectileCount: Int = 8
        static let volleyProjectileSpeed: CGFloat = 350
        static let volleyProjectileDamage: CGFloat = 20
        static let volleyProjectileRadius: CGFloat = 10

        // Minion spawns
        static let minionSpawnInterval: Double = 15.0
        static let minionCount: Int = 4
        static let minionHealth: CGFloat = 30
        static let minionDamage: CGFloat = 10
        static let minionSpeed: CGFloat = 120
        static let minionXP: Int = 5

        // Elite minions (Phase 3+)
        static let eliteMinionInterval: Double = 20.0
        static let eliteMinionHealth: CGFloat = 200
        static let eliteMinionDamage: CGFloat = 25
        static let eliteMinionSpeed: CGFloat = 80
        static let eliteMinionXP: Int = 50

        // Pylons (Phase 2)
        static let pylonCount: Int = 4
        static let pylonHealth: CGFloat = 500
        static let pylonBeamInterval: Double = 3.0
        static let pylonBeamSpeed: CGFloat = 400
        static let pylonBeamDamage: CGFloat = 30
        static let pylonBeamRadius: CGFloat = 8
        static let pylonBeamHomingStrength: CGFloat = 2.0

        // Void rifts (Phase 3+)
        static let voidRiftCount: Int = 3
        static let voidRiftRotationSpeed: CGFloat = 45  // degrees per second
        static let voidRiftWidth: CGFloat = 40
        static let voidRiftDamage: CGFloat = 50  // DPS
        static let voidRiftLength: CGFloat = 700

        // Gravity wells (Phase 3+)
        static let gravityWellCount: Int = 2
        static let gravityWellPullRadius: CGFloat = 250
        static let gravityWellPullStrength: CGFloat = 50

        // Teleport (Phase 4)
        static let teleportInterval: Double = 3.0

        // Shrinking arena (Phase 4)
        static let arenaStartRadius: CGFloat = 1500
        static let arenaMinRadius: CGFloat = 150
        static let arenaShrinkRate: CGFloat = 30  // pixels per second
        static let outsideArenaDPS: CGFloat = 40
        static let outsideArenaPushStrength: CGFloat = 100
    }

    // MARK: - Survival Events

    struct SurvivalEvents {
        /// Event interval settings
        static let baseEventInterval: TimeInterval = 60
        static let minEventInterval: TimeInterval = 40
        static let intervalReductionPerMinute: TimeInterval = 5
        static let intervalRandomRange: ClosedRange<Double> = -5...5

        /// First event triggers at this time
        static let firstEventTime: TimeInterval = 60

        /// Memory Surge: speed boost
        static let memorySurgeSpeedBoost: CGFloat = 1.5  // +50%
        static let memorySurgeSpawnRate: CGFloat = 2.0   // 2x spawns

        /// Thermal Throttle: slow + damage boost
        static let thermalThrottleSpeedMult: CGFloat = 0.7   // -30%
        static let thermalThrottleDamageMult: CGFloat = 1.5  // +50%

        /// Buffer Overflow: kill zone damage per second
        static let bufferOverflowDamagePerSecond: CGFloat = 25.0
        static let bufferOverflowZoneDepth: CGFloat = 100

        /// Data Corruption: damage per second when touching corrupted obstacle
        static let dataCorruptionDamagePerSecond: CGFloat = 15.0
        static let maxCorruptedObstacles: Int = 3

        /// System Restore: healing per second in zone
        static let systemRestoreHealPerSecond: CGFloat = 5.0
        static let systemRestoreZoneRadius: CGFloat = 60

        /// Virus Swarm: enemy count
        static let virusSwarmCount: Int = 50

        /// Cache Flush: cooldown before can trigger again
        static let cacheFlushCooldown: TimeInterval = 120
    }

    // MARK: - Survival Economy

    struct SurvivalEconomy {
        /// Time until extraction is available (seconds)
        static let extractionTime: TimeInterval = 180  // 3 minutes

        /// Base Hash earned per second
        static let hashPerSecond: CGFloat = 2.0

        /// Bonus Hash per minute survived (adds to base rate)
        static let hashBonusPerMinute: CGFloat = 0.5
    }

    // MARK: - Pickups

    struct Pickups {
        /// How long pickups stay on screen before despawning
        static let lifetime: TimeInterval = 10.0

        /// Projectile base lifetime before despawning
        static let projectileLifetime: TimeInterval = 2.0
    }

    // MARK: - Timing

    struct Timing {
        /// Upgrade selection interval (survivor mode)
        static let upgradeInterval: TimeInterval = 60  // 1 minute
    }

    // MARK: - TD Boss Integration
    // Bosses spawn at threat milestones, immune to towers
    // Player must manually engage or let them pass

    struct TDBoss {
        /// Threat level interval for boss spawns (every 10 threat)
        static let threatMilestoneInterval: Int = 10

        /// Boss walk speed (slower than regular enemies)
        static let walkSpeed: CGFloat = 25

        /// Efficiency loss when boss reaches CPU (4 leaks = 20%)
        static let efficiencyLossOnIgnore: Int = 4

        /// Boss visual size
        static let bossSize: CGFloat = 80
    }

    // MARK: - Overclock System
    // Player can overclock CPU for risk/reward gameplay

    struct Overclock {
        /// Duration of overclock effect
        static let duration: TimeInterval = 60

        /// Hash generation multiplier during overclock
        static let hashMultiplier: CGFloat = 2.0

        /// Threat growth multiplier during overclock
        static let threatMultiplier: CGFloat = 10.0

        /// Power demand multiplier during overclock
        static let powerDemandMultiplier: CGFloat = 2.0
    }

    // MARK: - Boss Loot Modal
    // Settings for the post-boss loot reveal experience

    struct BossLoot {
        /// Number of taps required to decrypt each item
        static let tapsToDecrypt: Int = 2

        /// Auto-advance delay if player doesn't tap (seconds)
        static let autoAdvanceDelay: TimeInterval = 2.0

        /// Delay between sequential card reveals (seconds)
        static let revealDelay: TimeInterval = 0.3

        /// Animation duration for decrypt reveal
        static let decryptDuration: TimeInterval = 0.4

        /// Glitch animation offset range
        static let glitchOffsetRange: ClosedRange<CGFloat> = -5...5
    }

    // MARK: - Performance Limits

    struct Limits {
        /// Maximum particles on screen
        static let maxParticles: Int = 500

        /// Maximum projectiles on screen
        static let maxProjectiles: Int = 1000

        /// Particle update interval (batch processing)
        static let particleUpdateInterval: TimeInterval = 0.05
    }

    // MARK: - Visual Effects

    struct Visual {
        /// Screen shake on hit
        static let screenShakeDuration: TimeInterval = 0.2
        static let screenShakeIntensity: CGFloat = 5

        /// Health bar sizing
        static let healthBarWidth: CGFloat = 50
        static let healthBarHeight: CGFloat = 6
        static let healthBarOffset: CGFloat = 25

        /// Trail effects
        static let trailLifetime: TimeInterval = 0.5
        static let trailSpawnChance: Double = 0.3
    }

    // MARK: - Leveling & XP

    struct Leveling {
        /// Level bonus: +5% stats per level
        static let bonusPerLevel: CGFloat = 0.05

        /// XP required formula: base + ((level - 1) × perLevel)
        static let baseXPRequired: Int = 100
        static let xpPerLevel: Int = 50

        /// Weapon mastery max level
        static let maxWeaponLevel: Int = 10

        /// Weapon mastery damage formula: base + (level × perLevel)
        static let baseDamageMultiplier: CGFloat = 1.0
        static let damagePerLevel: CGFloat = 1.0  // Level 10 = 10x damage
    }

    // MARK: - Drop Rates (See also: LootTables.swift)

    struct DropRates {
        /// Base drop rates by rarity
        static let common: Double = 0.60
        static let rare: Double = 0.30
        static let epic: Double = 0.08
        static let legendary: Double = 0.02

        /// Difficulty multipliers
        static let easyMultiplier: Double = 0.5
        static let normalMultiplier: Double = 1.0
        static let hardMultiplier: Double = 1.5
        static let nightmareMultiplier: Double = 2.5

        /// Pity system: guaranteed drop after N kills without one
        static let pityThreshold: Int = 10

        /// Diminishing returns: 1 / (1 + factor × killCount)
        static let diminishingFactor: Double = 0.1
    }
}

// MARK: - Balance Helpers

extension BalanceConfig {

    /// Calculate wave health multiplier
    static func waveHealthMultiplier(waveNumber: Int) -> CGFloat {
        return 1.0 + CGFloat(waveNumber - 1) * Waves.healthScalingPerWave
    }

    /// Calculate wave speed multiplier
    static func waveSpeedMultiplier(waveNumber: Int) -> CGFloat {
        return 1.0 + CGFloat(waveNumber - 1) * Waves.speedScalingPerWave
    }

    /// Calculate threat level health multiplier
    static func threatHealthMultiplier(threatLevel: CGFloat) -> CGFloat {
        return 1.0 + (threatLevel - 1.0) * ThreatLevel.healthScaling
    }

    /// Calculate threat level speed multiplier
    static func threatSpeedMultiplier(threatLevel: CGFloat) -> CGFloat {
        return 1.0 + (threatLevel - 1.0) * ThreatLevel.speedScaling
    }

    /// Calculate threat level damage multiplier
    static func threatDamageMultiplier(threatLevel: CGFloat) -> CGFloat {
        return 1.0 + (threatLevel - 1.0) * ThreatLevel.damageScaling
    }

    /// Calculate spawn delay for a wave
    static func spawnDelay(waveNumber: Int) -> CGFloat {
        return max(
            Waves.minSpawnDelay,
            Waves.baseSpawnDelay - CGFloat(waveNumber) * Waves.spawnDelayReductionPerWave
        )
    }

    /// Calculate XP required for a level
    static func xpRequired(level: Int) -> Int {
        return Leveling.baseXPRequired + (level - 1) * Leveling.xpPerLevel
    }

    /// Calculate level bonus multiplier
    static func levelMultiplier(level: Int) -> CGFloat {
        return 1.0 + CGFloat(level - 1) * Leveling.bonusPerLevel
    }

    /// Get tower placement cost
    static func towerCost(rarity: Rarity) -> Int {
        return Towers.placementCosts[rarity] ?? 50
    }
}

// MARK: - JSON Export (for Balance Simulator sync)

extension BalanceConfig {

    /// Export current balance config as JSON for use with tools/balance-simulator.html
    static func exportJSON() -> String {
        // Build sub-dictionaries separately to help compiler
        let wavesDict: [String: Any] = [
            "healthScalingPerWave": Waves.healthScalingPerWave,
            "speedScalingPerWave": Waves.speedScalingPerWave,
            "baseEnemyCount": Waves.baseEnemyCount,
            "enemiesPerWave": Waves.enemiesPerWave,
            "bossWaveInterval": Waves.bossWaveInterval,
            "bossHealthMultiplier": Waves.bossHealthMultiplier,
            "bossSpeedMultiplier": Waves.bossSpeedMultiplier,
            "hashBonusPerWave": Waves.hashBonusPerWave
        ]

        let threatDict: [String: Any] = [
            "healthScaling": ThreatLevel.healthScaling,
            "speedScaling": ThreatLevel.speedScaling,
            "damageScaling": ThreatLevel.damageScaling,
            "fastEnemyThreshold": ThreatLevel.fastEnemyThreshold,
            "tankEnemyThreshold": ThreatLevel.tankEnemyThreshold,
            "bossEnemyThreshold": ThreatLevel.bossEnemyThreshold
        ]

        let economyDict: [String: Any] = [
            "hashPerSecond": SurvivalEconomy.hashPerSecond,
            "hashBonusPerMinute": SurvivalEconomy.hashBonusPerMinute,
            "extractionTime": SurvivalEconomy.extractionTime
        ]

        let costsDict: [String: Int] = [
            "common": Towers.placementCosts[.common] ?? 50,
            "rare": Towers.placementCosts[.rare] ?? 100,
            "epic": Towers.placementCosts[.epic] ?? 200,
            "legendary": Towers.placementCosts[.legendary] ?? 400
        ]

        let towersDict: [String: Any] = [
            "placementCosts": costsDict,
            "refundRate": Towers.refundRate
        ]

        let dropsDict: [String: Any] = [
            "common": DropRates.common,
            "rare": DropRates.rare,
            "epic": DropRates.epic,
            "legendary": DropRates.legendary,
            "easyMultiplier": DropRates.easyMultiplier,
            "normalMultiplier": DropRates.normalMultiplier,
            "hardMultiplier": DropRates.hardMultiplier,
            "nightmareMultiplier": DropRates.nightmareMultiplier,
            "pityThreshold": DropRates.pityThreshold,
            "diminishingFactor": DropRates.diminishingFactor
        ]

        let config: [String: Any] = [
            "waves": wavesDict,
            "threatLevel": threatDict,
            "survivalEconomy": economyDict,
            "towers": towersDict,
            "dropRates": dropsDict
        ]

        if let data = try? JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted, .sortedKeys]),
           let json = String(data: data, encoding: .utf8) {
            return json
        }
        return "{}"
    }

    /// Print balance config to console (for debugging)
    static func printConfig() {
        print("=== BalanceConfig Export ===")
        print(exportJSON())
    }
}
