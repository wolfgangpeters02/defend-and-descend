import Foundation
import CoreGraphics

// MARK: - Loot Table Types (used by BalanceConfig.BossLoot)

/// A single entry in a boss's loot table
struct LootTableEntry {
    let protocolId: String
    let weight: Int              // Higher = more likely within same tier
    let isFirstKillGuarantee: Bool  // Guaranteed on first kill of this boss
}

/// Defines the complete loot table for a boss
struct BossLootTable {
    let bossId: String
    let entries: [LootTableEntry]
    let guaranteeOnFirstKill: Bool  // At least one drop on first kill

    /// Get all protocol IDs this boss can drop
    var possibleDrops: [String] {
        entries.map { $0.protocolId }
    }
}

// MARK: - Balance Config
// Centralized game balance values for easy tuning
// All hardcoded numbers should live here for discoverability

struct BalanceConfig {

    // MARK: - Core Formulas
    // Centralized formulas used by Protocols, Towers, Components, etc.
    // ALL upgrade cost calculations should call these functions

    /// Maximum upgrade level for protocols, towers, and components
    static let maxUpgradeLevel: Int = 10

    /// Exponential upgrade cost formula: baseCost × 2^(level-1)
    /// Level 1→2: base, Level 2→3: 2x, Level 3→4: 4x, ... Level 9→10: 256x
    /// Example: Common protocol (base 50): Total Lv1→10 = 25,550 Hash
    static func exponentialUpgradeCost(baseCost: Int, currentLevel: Int) -> Int {
        guard currentLevel < maxUpgradeLevel else { return 0 }
        return baseCost * Int(pow(2.0, Double(currentLevel - 1)))
    }

    /// Level damage/stat multiplier: diminishing returns curve
    /// Level 1 = 1.0x, Level 5 ≈ 2.6x, Level 10 ≈ 4.0x
    /// Used by Protocol and Tower damage scaling
    static func levelStatMultiplier(level: Int) -> CGFloat {
        return pow(CGFloat(level), 0.6)
    }

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

        /// Arena edge padding for player movement clamping
        static let boundsPadding: CGFloat = 30

        /// Health percentage restored on revive
        static let reviveHealthPercent: CGFloat = 0.5

        /// Speed of pickups being magnetized toward player
        static let pickupMagnetSpeed: CGFloat = 400

        /// Player weapon projectile speed (survivor/boss mode)
        static let weaponProjectileSpeed: CGFloat = 500

        /// Maximum player armor (damage reduction cap in boss/survivor mode)
        static let maxArmor: CGFloat = 0.75
    }

    // MARK: - Enemy Time Scaling (Survivor Mode)

    struct EnemyScaling {
        /// HP increase per minute (+10%)
        static let hpScalingPerMinute: CGFloat = 0.10

        /// Damage increase per minute (+5%)
        static let damageScalingPerMinute: CGFloat = 0.05
    }

    // MARK: - Spawn System

    struct Spawn {
        /// Edge spawn margin (distance from arena edge)
        static let edgeMargin: CGFloat = 50

        /// Default enemy activation radius
        static let defaultActivationRadius: CGFloat = 400
    }

    // MARK: - Enemy Defaults
    // Default fallback values when enemy config is missing
    // Note: Uses Double for config compatibility (EnemyConfig uses Double)

    struct EnemyDefaults {
        /// Default health when config is missing (Double for EnemyConfig compat)
        static let health: Double = 20

        /// Default speed when config is missing (Double for EnemyConfig compat)
        static let speed: Double = 80

        /// Default damage when config is missing (Double for EnemyConfig compat)
        static let damage: Double = 10

        /// Default visual size when config is missing (Double for EnemyConfig compat)
        static let size: Double = 12

        /// Default collision size for enemy interactions (CGFloat for game logic)
        static let collisionSize: CGFloat = 20

        /// Default hash/xp value when config is missing
        static let hashValue: Int = 1

        /// Default boss size when config is missing
        static let bossSize: CGFloat = 60

        /// Default enemy color (hex)
        static let color: String = "#ff4444"

        /// Default enemy shape
        static let shape: String = "circle"
    }

    // MARK: - Threat Level Display
    // Thresholds for UI display of threat level names/colors

    struct ThreatDisplay {
        /// Low threat threshold (0 to this value)
        static let lowMax: CGFloat = 2

        /// Medium threat threshold (low to this value)
        static let mediumMax: CGFloat = 5

        /// High threat threshold (medium to this value)
        static let highMax: CGFloat = 10

        /// Critical threat threshold (high to this value)
        static let criticalMax: CGFloat = 20

        /// Colors for each threat level
        static let lowColor: String = "#44ff44"       // Green
        static let mediumColor: String = "#ffff44"    // Yellow
        static let highColor: String = "#ff8844"      // Orange
        static let criticalColor: String = "#ff4444"  // Red
        static let extremeColor: String = "#ff00ff"   // Magenta
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

        /// Wave composition tier thresholds
        /// Tier 1 (early): waves 1 to earlyWaveMax - basic only
        /// Tier 2 (mid-early): waves earlyWaveMax+1 to midEarlyWaveMax - basic + fast
        /// Tier 3 (mid): waves midEarlyWaveMax+1 to midWaveMax - basic + fast + tank
        /// Tier 4 (late): waves midWaveMax+1 onwards - all types + bosses
        static let earlyWaveMax: Int = 3
        static let midEarlyWaveMax: Int = 6
        static let midWaveMax: Int = 10
    }

    // MARK: - Threat Level Scaling (Idle TD Mode)

    struct ThreatLevel {
        /// Maximum threat level (caps enemy scaling so Lv10 towers remain viable)
        /// At threat 100: enemies have +1485% HP, +198% speed, +495% damage
        /// A Lv10 tower (10x damage) can still handle this with proper placement
        static let maxThreatLevel: CGFloat = 100.0

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

        /// Base idle spawn rate (seconds between spawns at threat 0)
        static let baseIdleSpawnRate: TimeInterval = 2.0

        /// Minimum spawn interval (floor at high threat)
        static let minSpawnInterval: TimeInterval = 0.3

        /// Spawn rate scaling with threat (divisor increases with threat)
        static let spawnRateThreatScaling: CGFloat = 0.1

        /// Online threat growth rate (per second)
        static let onlineThreatGrowthRate: CGFloat = 0.01

        /// Offline threat growth rate (10% of online rate)
        static let offlineThreatGrowthRate: CGFloat = 0.001

        /// Efficiency loss per leaked enemy (5%)
        static let efficiencyPerLeak: CGFloat = 0.05

        /// Level bonus per tower/protocol level (+5% stats)
        static let levelBonusPercent: CGFloat = 0.05

        /// Maximum enemies on screen (performance cap)
        static let maxEnemiesOnScreen: Int = 50
    }

    // MARK: - Tower Economy

    struct Towers {
        /// Placement cost by rarity (Hash) - also used as base upgrade cost
        static let placementCosts: [Rarity: Int] = [
            .common: 50,
            .rare: 100,
            .epic: 200,
            .legendary: 400
        ]

        /// Base upgrade cost by rarity (same as placement cost)
        /// Upgrade cost formula: baseUpgradeCost × 2^(level-1)
        /// Total Lv1→10 for common: 50 × (1+2+4+8+16+32+64+128+256) = 25,550 Ħ
        static func baseUpgradeCost(for rarity: Rarity) -> Int {
            return placementCosts[rarity] ?? 50
        }

        /// Upgrade investment per level (for refund calculation)
        static let upgradeInvestmentPerLevel: Int = 75

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

        /// Lead targeting look-ahead (path progress increment for direction estimation)
        static let leadTargetingLookAhead: CGFloat = 0.05
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
        // Base health for boss arena fight
        static let baseHealth: CGFloat = 4000

        // Phase thresholds (health percentage)
        static let phase2Threshold: CGFloat = 0.75
        static let phase3Threshold: CGFloat = 0.50
        static let phase4Threshold: CGFloat = 0.25

        // Mode switching (Phase 1-2)
        static let modeSwitchInterval: Double = 5.0

        // Minion spawns (higher cap + faster interval than VH because Cyberboss minions are weaker fodder)
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

        // Melee AoE range (added to boss size)
        static let meleeRangeAoE: CGFloat = 30

        // Arena bounds padding
        static let boundsPadding: CGFloat = 20

        // Minion spawn distance range
        static let minionSpawnDistanceMin: CGFloat = 80
        static let minionSpawnDistanceMax: CGFloat = 150

        // Movement behavior multipliers
        static let rangedMoveAwaySpeed: CGFloat = 0.5      // Speed when moving away from player
        static let rangedMoveCloserSpeed: CGFloat = 0.3    // Speed when closing distance
        static let rangedStrafeSpeed: CGFloat = 0.4        // Speed when strafing
        static let rangedDistanceThreshold: CGFloat = 150  // Extra distance before moving closer

        // Projectile settings
        static let rangedProjectileLifetime: TimeInterval = 5.0
        static let rangedSpawnOffset: CGFloat = 5          // Extra offset from boss for projectile spawn
        static let rangedProjectileSizeRatio: CGFloat = 0.35  // Projectile size as ratio of boss size

        // Damage puddle spawn area margin
        static let puddleSpawnMargin: CGFloat = 100

        // Pop damage threshold (how close to end of lifetime to trigger pop)
        static let puddlePopThreshold: TimeInterval = 0.1

        // Minion spawn collision padding
        static let minionSpawnPadding: CGFloat = 10

        // Laser hit invulnerability duration
        static let laserHitInvulnerability: TimeInterval = 0.5

        // Obstacle destruction particles
        static let obstacleParticleColor: String = "#6b7280"
        static let obstacleParticleCount: Int = 15
        static let obstacleParticleSize: CGFloat = 12

        // Mode indicator colors
        static let meleeModeColor: String = "#ff4444"
        static let rangedModeColor: String = "#4444ff"

        // Projectile color
        static let rangedProjectileColor: String = "#00ffff"

        // Simulation hit radius (laser width + player radius, used by BossSimulator)
        static let simLaserHitRadius: CGFloat = 30
    }

    // MARK: - Void Harbinger Configuration

    struct VoidHarbinger {
        // Base health for boss arena fight
        static let baseHealth: CGFloat = 5000

        // Phase thresholds (health percentage)
        // Uses 70/40/20 split (30-30-20-20) for longer early phases vs Cyberboss/Overclocker's equal 25% split
        static let phase2Threshold: CGFloat = 0.70
        static let phase3Threshold: CGFloat = 0.40
        static let phase4Threshold: CGFloat = 0.20  // Phase 4 covers 20% HP (was 0.10)

        // Boss body color (used for entity identification)
        static let bossColor: String = "#8800ff"

        // Visual colors (used by EntityRenderer and BossRenderingManager)
        static let voidCoreColor: String = "#1a0033"         // Dark purple void core
        static let harbingerEyeColor: String = "#ff00ff"     // Magenta eye/core glow
        static let pylonBeamColor: String = "#ff00aa"        // Pylon beam projectile color
        static let pylonBeamReticleColor: String = "#ff66cc" // Pylon beam reticle stroke

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
        static let meteorDamage: CGFloat = 60  // Was 80, highest single-mechanic value

        // Shadow bolt volley
        static let volleyInterval: Double = 6.0
        static let volleyProjectileCount: Int = 8
        static let volleyProjectileSpeed: CGFloat = 350
        static let volleyProjectileDamage: CGFloat = 20
        static let volleyProjectileRadius: CGFloat = 10
        static let volleySpreadAngle: CGFloat = 0.2       // Angle between each projectile
        static let volleyProjectileLifetime: TimeInterval = 4.0
        static let volleyProjectileColor: String = "#8800ff"

        // Minion spawns (lower cap + slower interval than Cyberboss because VH minions are stronger)
        static let minionSpawnInterval: Double = 15.0
        static let minionCount: Int = 4
        static let minionHealth: CGFloat = 30
        static let minionDamage: CGFloat = 10
        static let minionSpeed: CGFloat = 120
        static let minionXP: Int = 5
        static let minionColor: String = "#6600aa"
        static let maxMinionsOnScreen: Int = 20

        // Elite minions (Phase 3+)
        static let eliteMinionInterval: Double = 20.0
        static let eliteMinionHealth: CGFloat = 200
        static let eliteMinionDamage: CGFloat = 25
        static let eliteMinionSpeed: CGFloat = 80
        static let eliteMinionXP: Int = 50
        static let eliteMinionColor: String = "#aa00ff"

        // Pylons (Phase 2)
        static let pylonCount: Int = 4
        static let pylonHealth: CGFloat = 500
        static let pylonSize: CGFloat = 40
        static let pylonXP: Int = 10
        static let pylonColor: String = "#aa00ff"
        static let pylonBeamInterval: Double = 3.0
        static let pylonBeamSpeed: CGFloat = 400
        static let pylonBeamDamage: CGFloat = 30
        static let pylonBeamRadius: CGFloat = 8
        static let pylonBeamHomingStrength: CGFloat = 2.0
        static let pylonBeamLifetime: TimeInterval = 3.0

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

        // Position offsets (for 1200x900 arena)
        static let pylonOffsetX: CGFloat = 500
        static let pylonOffsetY: CGFloat = 350
        static let voidRiftDistance: CGFloat = 200
        static let gravityWellOffsetX: CGFloat = 300
        static let phase1ChaseMultiplier: CGFloat = 0.6
        static let phase3ChaseMultiplier: CGFloat = 0.8
        static let eliteMinionSpawnDistance: CGFloat = 150

        // Void minion spawn distance range
        static let minionSpawnDistanceMin: CGFloat = 100
        static let minionSpawnDistanceMax: CGFloat = 200

        // Meteor spawn offset from player
        static let meteorSpawnOffset: CGFloat = 100

        // Teleport offset ratio (0.6 = 60% of arena radius)
        static let teleportOffsetRatio: CGFloat = 0.6

        // Simulation hit radius (rift width + player radius, used by BossSimulator)
        static let simRiftHitRadius: CGFloat = 40
    }

    // MARK: - Overclocker Boss

    struct Overclocker {
        // Base health for boss arena fight
        static let baseHealth: CGFloat = 4500

        // Phase thresholds (health percentage)
        static let phase2Threshold: CGFloat = 0.75
        static let phase3Threshold: CGFloat = 0.50
        static let phase4Threshold: CGFloat = 0.25

        // Phase 1 - Turbine (Wind + Rotating Blades)
        static let windForce: CGFloat = 20.0           // Applied to velocity
        static let bladeCount: Int = 3
        static let bladeOrbitRadius: CGFloat = 250
        static let bladeRotationSpeed: CGFloat = 90    // Degrees per second
        static let bladeDamage: CGFloat = 25           // Per hit
        static let bladeWidth: CGFloat = 30

        // Phase 2 - Heat Sink (Lava Grid)
        static let tileGridSize: Int = 4               // 4×4 grid
        static let tileCount: Int = 16                 // tileGridSize²
        static let safeTileCount: Int = 2              // Safe zones per cycle
        static let warningTileCount: Int = 4           // Tiles that become lava per cycle
        static let tileChangeInterval: Double = 5.0
        static let tileWarningDuration: Double = 2.0
        static let lavaTileDPS: CGFloat = 40           // DPS while standing on lava (was 60)
        static let phase2BossMoveSpeed: CGFloat = 150  // Phase 2 boss movement speed to safe zone

        // Phase 3 - Overheat (Chase + Steam Trail)
        static let chaseSpeed: CGFloat = 160.0
        static let steamDropInterval: Double = 0.2
        static let steamRadius: CGFloat = 35
        static let steamDPS: CGFloat = 40              // DPS while in steam
        static let maxSteamSegments: Int = 80

        // Phase 4 - Suction (Vacuum + Shredder)
        static let vacuumPullStrength: CGFloat = 25.0
        static let suctionPullDuration: Double = 2.5
        static let suctionPauseDuration: Double = 1.5
        static let shredderRadius: CGFloat = 140
        static let shredderDPS: CGFloat = 100          // High damage when too close

        // Movement speeds
        static let phase1CenterSpeed: CGFloat = 100    // Phase 1 boss move speed toward center
        static let phase4CenterSpeed: CGFloat = 50     // Phase 4 boss move speed toward center

        // Wind mechanic
        static let windMaxDistance: CGFloat = 600       // Wind force max distance

        // Contact damage
        static let contactCooldown: Double = 0.5       // Contact damage cooldown
        static let contactRadius: CGFloat = 60         // Contact damage radius
        static let contactDamage: CGFloat = 25         // Contact damage amount
        static let contactKnockback: CGFloat = 100     // Contact knockback force
    }

    // MARK: - Trojan Wyrm Boss

    struct TrojanWyrm {
        // Base health for boss arena fight
        static let baseHealth: CGFloat = 5500

        // Phase thresholds (health percentage)
        // Uses 70/40/20 split (30-30-20-20) for longer early phases vs Cyberboss/Overclocker's equal 25% split
        static let phase2Threshold: CGFloat = 0.70
        static let phase3Threshold: CGFloat = 0.40
        static let phase4Threshold: CGFloat = 0.20  // Phase 4 covers 20% HP (was 0.10)

        // Body geometry
        static let segmentCount: Int = 24
        static let segmentSpacing: CGFloat = 45.0
        static let headCollisionRadius: CGFloat = 28
        static let bodyCollisionRadius: CGFloat = 18

        // Phase 1 - Packet Loss (Snake movement)
        static let headSpeed: CGFloat = 170            // Slightly slower for fairness
        static let turnSpeed: CGFloat = 2.2            // Radians per second (less aggressive)
        static let headContactDamage: CGFloat = 15     // Reduced from 30 (24 segments = lots of hits)
        static let bodyContactDamage: CGFloat = 4      // Reduced from 10 (cumulative damage was too high)
        static let bodyKnockbackStrength: CGFloat = 80 // Reduced to let player escape
        static let bodyDamageMitigation: CGFloat = 0.60  // 40% damage passes through (was 0.80 = 20%)
        static let boundsPadding: CGFloat = 30

        // Phase 2 - Firewall (Wall sweep)
        static let wallMargin: CGFloat = 100           // Wall bounce margin from arena edges
        static let wallSweepSpeed: CGFloat = 70        // Slightly slower sweep
        static let turretFireInterval: Double = 1.8    // Slower fire rate
        static let turretProjectileSpeed: CGFloat = 220
        static let turretProjectileDamage: CGFloat = 12 // Reduced from 20
        static let turretProjectileRadius: CGFloat = 8
        static let turretProjectileLifetime: TimeInterval = 4.0
        static let turretProjectileColor: String = "#00ff44" // Lime green

        // Phase 3 - Data Corruption (Sub-worms)
        static let subWormCount: Int = 3               // Reduced from 4
        static let subWormBodyCount: Int = 4           // Reduced from 5
        static let subWormSpeed: CGFloat = 180         // Reduced from 240 (less aggressive)
        static let subWormTurnSpeed: CGFloat = 3.0     // Reduced from 4.0
        static let subWormHeadSize: CGFloat = 18
        static let subWormBodySize: CGFloat = 10
        static let subWormBodyMitigation: CGFloat = 0.80

        // Phase 4 - Format C: (Constricting ring)
        static let circlingDuration: Double = 4.0      // Time spent circling before aiming
        static let ringInitialRadius: CGFloat = 250
        static let ringMinRadius: CGFloat = 130        // Slightly larger min (more escape room)
        static let ringShrinkRate: CGFloat = 4         // Slower shrink
        static let ringRotationSpeed: CGFloat = 0.8    // Radians per second (slower rotation)
        static let aimDuration: Double = 1.2           // More warning time
        static let lungeSpeed: CGFloat = 500           // Reduced from 600
        static let lungeDuration: Double = 1.5         // Lunge timeout
        static let lungeBoundsPadding: CGFloat = 50    // Bounds padding for lunge stop
        static let lungeHeadDamage: CGFloat = 30       // Reduced from 60
        static let recoverDuration: Double = 1.8       // Longer recovery = more punish window

        // Sub-worm geometry (Phase 3)
        static let subWormSpawnDistance: CGFloat = 200  // Sub-worm spawn distance from center
        static let subWormSegmentSpacing: CGFloat = 20  // Sub-worm initial segment spacing
        static let subWormBodySpacing: CGFloat = 25     // Sub-worm body drag spacing

        // Contact damage
        static let contactCooldown: Double = 0.5       // Contact damage cooldown
        static let contactPadding: CGFloat = 20        // Extra padding on collision radii

        // Simulation collision multipliers (used by BossSimulator for approximated hitboxes)
        static let simHeadCollisionMultiplier: CGFloat = 1.8   // Head hitbox scaling in sim
        static let simBodyCollisionMultiplier: CGFloat = 2.0   // Body hitbox scaling in sim
        static let simSubWormCollisionMultiplier: CGFloat = 2.5 // Sub-worm body hitbox scaling in sim
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

        // MARK: Event Durations

        /// Memory Surge duration and warning
        static let memorySurgeDuration: TimeInterval = 8.0
        static let memorySurgeWarningDuration: TimeInterval = 2.0
        static let memorySurgeMinTime: TimeInterval = 60

        /// Buffer Overflow duration and warning
        static let bufferOverflowDuration: TimeInterval = 15.0
        static let bufferOverflowWarningDuration: TimeInterval = 3.0

        /// Thermal Throttle duration
        static let thermalThrottleDuration: TimeInterval = 12.0
        static let thermalThrottleWarningDuration: TimeInterval = 2.0

        /// Cache Flush duration
        static let cacheFlushDuration: TimeInterval = 3.0
        static let cacheFlushWarningDuration: TimeInterval = 2.0

        /// Data Corruption duration
        static let dataCorruptionDuration: TimeInterval = 10.0
        static let dataCorruptionWarningDuration: TimeInterval = 2.0

        /// Virus Swarm duration
        static let virusSwarmDuration: TimeInterval = 5.0
        static let virusSwarmWarningDuration: TimeInterval = 3.0

        /// System Restore duration
        static let systemRestoreDuration: TimeInterval = 8.0
        static let systemRestoreWarningDuration: TimeInterval = 2.0

        /// Min survival time for event tiers
        static let tier1MinTime: TimeInterval = 60
        static let tier2MinTime: TimeInterval = 180
        static let tier3MinTime: TimeInterval = 300

        // MARK: Event Effects

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
        static let healingZoneSpawnMargin: CGFloat = 80

        /// Virus Swarm: enemy count and stats
        static let virusSwarmCount: Int = 50
        static let swarmVirusHealth: CGFloat = 5
        static let swarmVirusSpeed: CGFloat = 200
        static let swarmVirusDamage: CGFloat = 5
        static let virusSpreadOffset: CGFloat = 20
        static let virusRowOffset: CGFloat = 15

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

    // MARK: - Efficiency System (TD Mode)

    struct Efficiency {
        /// Base leak decay interval in seconds (modified by RAM upgrade)
        static let leakDecayInterval: TimeInterval = 5.0

        /// Efficiency warning threshold (haptic feedback when drops below)
        static let warningThreshold: CGFloat = 25
    }

    // MARK: - TD Hash Economy
    // Idle tower defense mode - Hash generation and scaling

    struct HashEconomy {
        /// Base Hash per second at CPU level 1
        /// 1 Ħ/sec = 3,600/hour = ~7 hours to max a common tower (25,550 Ħ)
        static let baseHashPerSecond: CGFloat = 1.0

        /// CPU level scaling multiplier (1.5x per level)
        /// Lv1: 1, Lv2: 1.5, Lv3: 2.25, Lv5: 5, Lv10: 38
        static let cpuLevelScaling: CGFloat = 1.5

        /// Offline earnings rate (percentage of active rate)
        static let offlineEarningsRate: CGFloat = 0.2  // 20%

        /// Maximum offline accumulation time (hours)
        static let maxOfflineHours: CGFloat = 8.0

        /// Calculate Hash per second at a given CPU level
        static func hashPerSecond(at cpuLevel: Int) -> CGFloat {
            return baseHashPerSecond * pow(cpuLevelScaling, CGFloat(cpuLevel - 1))
        }
    }

    // MARK: - Potion System

    struct Potions {
        /// Max charges for each potion type
        static let healthMaxCharge: CGFloat = 100
        static let bombMaxCharge: CGFloat = 150
        static let magnetMaxCharge: CGFloat = 75
        static let shieldMaxCharge: CGFloat = 100

        /// Charge multipliers (how fast each potion charges)
        static let healthChargeMultiplier: CGFloat = 2.0
        static let bombChargeMultiplier: CGFloat = 1.0
        static let magnetChargeMultiplier: CGFloat = 1.5
        static let shieldChargeMultiplier: CGFloat = 1.2

        /// Health potion: restore percentage of max HP
        static let healthRestorePercent: CGFloat = 0.5  // 50%

        /// Magnet potion: expanded pickup range
        static let magnetPickupRange: CGFloat = 2000

        /// Shield potion: invulnerability duration
        static let shieldDuration: TimeInterval = 5.0

        /// Bomb potion: screen flash duration
        static let bombFlashDuration: TimeInterval = 0.3

        /// Magnet potion: expanded range duration
        static let magnetDuration: TimeInterval = 0.5
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

    // MARK: - TD Core

    struct TDCore {
        /// Core initial health
        static let baseHealth: CGFloat = 100

        /// Core base damage per attack
        static let baseDamage: CGFloat = 10

        /// Core base attack range
        static let baseRange: CGFloat = 150

        /// Core base attacks per second
        static let baseAttackSpeed: CGFloat = 1.0

        /// Level bonus per player level (+2%)
        static let levelBonusPercent: CGFloat = 0.02

        /// Core attack projectile speed
        static let projectileSpeed: CGFloat = 300

        /// Core attack projectile radius
        static let projectileRadius: CGFloat = 6

        /// Core attack projectile lifetime
        static let projectileLifetime: TimeInterval = 2.0

        /// Core upgrade values
        static let healthUpgradeBonus: CGFloat = 20
        static let damageUpgradeMultiplier: CGFloat = 1.15
        static let rangeUpgradeBonus: CGFloat = 20
        static let attackSpeedUpgradeMultiplier: CGFloat = 1.1
        static let armorUpgradeBonus: CGFloat = 0.05
        static let maxArmor: CGFloat = 0.5

        /// Core upgrade base costs
        static let healthUpgradeCost: Int = 50
        static let damageUpgradeCost: Int = 75
        static let rangeUpgradeCost: Int = 60
        static let attackSpeedUpgradeCost: Int = 100
        static let armorUpgradeCost: Int = 80

        /// Health thresholds for color changes
        static let healthyThreshold: CGFloat = 0.6
        static let damagedThreshold: CGFloat = 0.3

        /// Pulse animation speed range
        static let minPulseSpeed: CGFloat = 2.0
        static let maxPulseSpeedVariation: CGFloat = 3.0

        /// Pulse intensity multiplier for visual feedback (more visible at low health)
        static let pulseIntensity: CGFloat = 0.05
    }

    // MARK: - TD Boss Integration
    // Bosses spawn at threat milestones, immune to towers
    // Player must manually engage or let them pass

    struct TDBoss {
        /// Threat level interval for boss spawns (every 6 threat)
        static let threatMilestoneInterval: Int = 6

        /// Boss walk speed (slower than regular enemies)
        static let walkSpeed: CGFloat = 25

        /// Time for boss to reach CPU (gives player time to engage)
        static let pathDuration: TimeInterval = 60

        /// Efficiency loss when boss reaches CPU (4 leaks = 20%)
        static let efficiencyLossOnIgnore: Int = 4

        /// Boss visual size
        static let bossSize: CGFloat = 80

        /// TD Boss health (immune to towers anyway)
        static let health: CGFloat = 99999

        /// Threat reduction on boss victory (% of current threat removed)
        /// Easy gives no relief (threat keeps climbing), Nightmare fully resets
        static let threatReduction: [String: CGFloat] = [
            "Easy": 0.0,        // No relief — threat stays, enemies keep scaling
            "Normal": 0.33,     // Moderate relief
            "Hard": 0.66,       // Major relief
            "Nightmare": 1.0    // Full reset (current behavior)
        ]

        /// Minimum seconds between boss victory and next boss spawn
        static let cooldownAfterVictory: TimeInterval = 180
    }

    // MARK: - TD Session Defaults

    struct TDSession {
        /// Starting hash for new TD sessions
        static let startingHash: Int = 100

        /// Starting PSU power capacity (watts)
        static let startingPowerCapacity: Int = 300

        /// Default hash storage cap
        static let defaultHashStorageCapacity: Int = 25000

        /// Efficiency loss per leaked virus (percentage points)
        static let efficiencyLossPerLeak: CGFloat = 5

        /// Calculate efficiency percentage from leak count
        static func efficiencyForLeakCount(_ leakCount: Int) -> CGFloat {
            max(0, min(100, 100 - CGFloat(leakCount) * efficiencyLossPerLeak))
        }

        /// Calculate leak count needed for a target efficiency percentage
        static func leakCountForEfficiency(_ efficiency: CGFloat) -> Int {
            max(0, Int((100 - efficiency) / efficiencyLossPerLeak))
        }

        /// Starting blocker slots
        static let startingBlockerSlots: Int = 3

        /// Base snap-to-slot distance in screen points (scaled by camera zoom)
        static let baseSnapScreenDistance: CGFloat = 60

        /// Snap-to-slot distance for large maps (width > 2000)
        static let largeMapSnapScreenDistance: CGFloat = 100

        /// Virus kills required to generate 1 Data (soft-lock prevention)
        static let virusKillsPerData: Int = 1000

        /// Total waves per session (legacy, used by simulation)
        static let totalWaves: Int = 20

        /// Hash sync throttle interval (seconds between profile saves)
        static let hashSyncInterval: TimeInterval = 1.0
    }

    // MARK: - TD Rewards

    struct TDRewards {
        /// XP per wave completed
        static let xpPerWave: Int = 10

        /// Bonus XP for victory
        static let victoryXPBonus: Int = 50

        /// Hash reward divisor (earn 20% of session hash — was 10% at divisor 10)
        static let hashRewardDivisor: Int = 5

        /// Victory hash bonus per wave (20 waves = 1,000 Ħ — was 100 Ħ)
        static let victoryHashPerWave: Int = 50

        /// Death penalty: fraction of hash kept (0.5 = 50%)
        static let deathHashPenalty: CGFloat = 0.5
    }

    // MARK: - Survivor Mode Rewards

    struct SurvivorRewards {
        /// XP granted per N seconds survived (1 XP per this many seconds)
        static let xpPerTimePeriod: TimeInterval = 10

        /// Bonus XP for winning / extracting
        static let victoryXPBonus: Int = 25

        /// Hash reward divisor (earn 1/N of collected coins)
        static let hashRewardDivisor: Int = 10

        /// Fraction of session hash kept on death (0.5 = 50%)
        static let deathHashPenalty: CGFloat = 0.5

        /// Legacy fallback: hash per N kills
        static let legacyHashPerKills: Int = 20

        /// Legacy fallback: hash per N seconds
        static let legacyHashPerSeconds: Int = 30

        /// Legacy fallback: victory hash bonus
        static let legacyVictoryHashBonus: Int = 10
    }

    // MARK: - Boss Difficulty Scaling
    // Multipliers and rewards per difficulty level

    struct BossDifficultyConfig {
        /// Boss health multipliers by difficulty
        /// Scaled up to counter weapon mastery (Level 10 = 10x damage)
        static let healthMultipliers: [String: CGFloat] = [
            "Easy": 1.2,       // Learning mode — slightly forgiving (was 1.0)
            "Normal": 1.5,     // A real fight even with mid-level weapons
            "Hard": 3.0,       // Level 5 weapon (5x) still needs good play
            "Nightmare": 6.0   // Level 10 weapon (10x) → TTK still 60% of base
        ]

        /// Boss damage multipliers by difficulty
        static let damageMultipliers: [String: CGFloat] = [
            "Easy": 0.7,       // Forgiving but not trivial (was 0.5)
            "Normal": 1.0,
            "Hard": 1.5,       // Mistakes punished (was 1.3)
            "Nightmare": 2.5   // Unforgiving (was 1.8)
        ]

        /// Player health multipliers by difficulty
        static let playerHealthMultipliers: [String: CGFloat] = [
            "Easy": 1.5,       // Safety net (was 2.0)
            "Normal": 1.0,
            "Hard": 1.0,
            "Nightmare": 0.8   // Glass cannon pressure (was 1.0)
        ]

        /// Player damage multipliers by difficulty
        static let playerDamageMultipliers: [String: CGFloat] = [
            "Easy": 1.5,       // Helpful but not steamroll (was 2.0)
            "Normal": 1.0,     // No training wheels (was 1.5)
            "Hard": 1.0,
            "Nightmare": 1.0
        ]

        /// Hash rewards by difficulty
        /// Steep scaling rewards skill: Easy:Normal:Hard:Nightmare ≈ 1:6:20:50
        static let hashRewards: [String: Int] = [
            "Easy": 500,       // Training mode (was 1000)
            "Normal": 3000,    // Standard progression
            "Hard": 10000,     // Big paydays (was 8000)
            "Nightmare": 25000 // Jackpot (was 20000)
        ]

    }

    // MARK: - Tower Upgrades
    // Per-level stat increases when upgrading towers

    struct TowerUpgrades {
        /// Damage multiplier per level (+10%)
        static let damageMultiplier: CGFloat = 1.1

        /// Range multiplier per level (+5%)
        static let rangeMultiplier: CGFloat = 1.05

        /// Attack speed multiplier per level (+3%)
        static let attackSpeedMultiplier: CGFloat = 1.03

        /// Chain lightning target count
        static let chainTargets: Int = 3
    }

    // MARK: - CPU Tier Upgrades

    struct CPU {
        /// Multiplier for each CPU tier (1x, 2x, 4x, 8x, 16x)
        static let tierMultipliers: [CGFloat] = [1.0, 2.0, 4.0, 8.0, 16.0]

        /// Cost in Hash to upgrade to next tier (tier 1→2, 2→3, 3→4, 4→5)
        /// Tier 5 (16x) is a late-game investment (was 100K)
        static let upgradeCosts: [Int] = [1000, 5000, 25000, 500000]

        /// Maximum CPU tier
        static let maxTier: Int = 5

        /// Get multiplier for a given tier (1-indexed)
        static func multiplier(tier: Int) -> CGFloat {
            let index = max(0, min(tier - 1, tierMultipliers.count - 1))
            return tierMultipliers[index]
        }

        /// Get upgrade cost for current tier, nil if already at max
        static func upgradeCost(currentTier: Int) -> Int? {
            let index = currentTier - 1
            guard index >= 0 && index < upgradeCosts.count else { return nil }
            return upgradeCosts[index]
        }
    }

    // MARK: - Tower Power Draw

    struct TowerPower {
        /// Default power draw per tower (Watts)
        static let defaultPowerDraw: Int = 20

        /// Power draw by rarity
        static let powerDrawByRarity: [Rarity: Int] = [
            .common: 15,
            .rare: 20,
            .epic: 30,
            .legendary: 40
        ]

        /// Get power draw for a given rarity
        static func powerDraw(for rarity: Rarity) -> Int {
            return powerDrawByRarity[rarity] ?? defaultPowerDraw
        }
    }

    // MARK: - Overclock System
    // Player can overclock CPU for risk/reward gameplay

    struct Overclock {
        /// Duration of overclock effect
        static let duration: TimeInterval = 45  // Shorter burst (was 60)

        /// Hash generation multiplier during overclock
        static let hashMultiplier: CGFloat = 4.0  // Meaningful boost (was 2.0)

        /// Threat growth multiplier during overclock
        static let threatMultiplier: CGFloat = 3.0  // Fair trade (was 10.0)

        /// Power demand multiplier during overclock
        static let powerDemandMultiplier: CGFloat = 1.5  // Less punishing (was 2.0)
    }

    // MARK: - Boss Loot Modal
    // Settings for the post-boss loot reveal experience

    struct BossRewards {
        /// Difficulty-based Hash bonus for defeating a boss
        /// Scales steeply to reward higher difficulty
        static let difficultyHashBonus: [BossDifficulty: Int] = [
            .easy: 100,        // Training mode (was 250)
            .normal: 500,
            .hard: 2000,       // Worth the risk (was 1500)
            .nightmare: 5000   // Major reward (was 3000)
        ]
    }

    struct BossLootReveal {
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

    // MARK: - Input

    struct Input {
        /// Joystick responsiveness curve exponent (lower = more responsive at low distances)
        static let joystickResponsivenessCurve: CGFloat = 0.7
    }

    // MARK: - Effect Zones

    struct EffectZones {
        /// Default ice zone speed multiplier
        static let defaultIceSpeedMultiplier: CGFloat = 1.5

        /// Default speed boost zone multiplier
        static let defaultSpeedZoneMultiplier: CGFloat = 1.5
    }

    // MARK: - Particles

    struct Particles {
        /// Hit particle lifetime (when enemies take damage)
        static let hitParticleLifetime: TimeInterval = 0.2

        /// Player hit particle lifetime (when player takes damage - longer for visibility)
        static let playerHitParticleLifetime: TimeInterval = 0.3
        static let playerHitParticleSize: CGFloat = 10

        /// Phoenix revive particles
        static let phoenixParticleCount: Int = 50
        static let phoenixParticleBaseSpeed: CGFloat = 100
        static let phoenixParticleSpeedVariation: CGFloat = 100
        static let phoenixParticleLifetime: TimeInterval = 1.0
        static let phoenixParticleSize: CGFloat = 8

        /// Heal particles (potion)
        static let healParticleCount: Int = 20
        static let healParticleSpeedMin: CGFloat = 30
        static let healParticleSpeedMax: CGFloat = 80
        static let healParticleVelocityOffset: CGFloat = -30  // Upward drift for healing effect

        /// Shield particles
        static let shieldParticleCount: Int = 30

        /// Boss rage particles
        static let rageParticleCount: Int = 30
        static let rageParticleSize: CGFloat = 15

        /// Death explosion particles
        static let deathParticleCountNormal: Int = 15
        static let deathParticleCountBoss: Int = 40

        /// Blood splatter particles
        static let bloodParticleCountNormal: Int = 10
        static let bloodParticleCountBoss: Int = 20

        /// Collection particle (when picking up hash)
        static let collectionParticleLifetime: TimeInterval = 0.5
        static let collectionParticleSize: CGFloat = 12
        static let collectionParticleVelocity: CGFloat = -50

        /// Bomb explosion particles per enemy
        static let bombParticleCountPerEnemy: Int = 10

        /// Magnet trail particles
        static let magnetParticleLifetime: TimeInterval = 0.3
        static let magnetParticleSize: CGFloat = 4

        /// Shield activation particles
        static let shieldActivationParticleLifetime: TimeInterval = 0.5
        static let shieldActivationParticleSize: CGFloat = 6
        static let shieldActivationParticleSpeed: CGFloat = 50
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

    // MARK: - Abilities

    struct Abilities {
        /// Explosion on kill damage
        static let explosionOnKillDamage: CGFloat = 50

        /// Explosion on kill particle count
        static let explosionParticleCount: Int = 25
    }

    // MARK: - Leveling & XP

    struct Leveling {
        /// Level bonus: +5% stats per level
        static let bonusPerLevel: CGFloat = 0.05

        /// XP required formula: base + ((level - 1) × perLevel)
        static let baseXPRequired: Int = 100
        static let xpPerLevel: Int = 75  // Weapon mastery XP progression

        /// Weapon mastery max level
        static let maxWeaponLevel: Int = 10

        /// Max player level (survivor mode)
        static let maxPlayerLevel: Int = 20
    }

    // MARK: - Upgrade Rarity Weights (Survivor Mode)

    struct UpgradeRarity {
        /// Weight for common upgrades appearing in survivor mode selection
        static let commonWeight: Double = 60
        /// Weight for rare upgrades
        static let rareWeight: Double = 25
        /// Weight for epic upgrades
        static let epicWeight: Double = 12
        /// Weight for legendary upgrades
        static let legendaryWeight: Double = 3
    }

    // MARK: - Boss Loot System
    // Single source of truth for blueprint drop rates, loot tables, and boss metadata.
    // Used by BlueprintDropSystem for all drop calculations.

    struct BossLoot {

        // MARK: - Drop Rate Constants

        /// Drop rates per difficulty per rarity
        /// Each row sums to < 1.0 — remainder = no drop
        /// Replaces the old rarityBaseRates × difficultyMultipliers system
        static let dropRates: [String: [Rarity: Double]] = [
            "Easy":      [.common: 0.35, .rare: 0.12, .epic: 0.00, .legendary: 0.00],  // 47% total
            "Normal":    [.common: 0.40, .rare: 0.20, .epic: 0.06, .legendary: 0.02],  // 68% total
            "Hard":      [.common: 0.35, .rare: 0.25, .epic: 0.12, .legendary: 0.05],  // 77% total
            "Nightmare": [.common: 0.30, .rare: 0.25, .epic: 0.18, .legendary: 0.10]   // 83% total
        ]

        /// Pity system: guaranteed drop every N kills without a drop
        static let pityThreshold: Int = 10

        /// Diminishing returns factor (higher = faster diminishment)
        /// Formula: 1 / (1 + factor × killCount)
        static let diminishingFactor: Double = 0.1

        // MARK: - Boss Loot Tables

        /// Cyberboss - Hacking/Tech theme
        /// Drops: Burst Protocol (C), Trace Route (R), Ice Shard (R)
        static let cyberboss = BossLootTable(
            bossId: "cyberboss",
            entries: [
                LootTableEntry(
                    protocolId: "burst_protocol",
                    weight: 100,
                    isFirstKillGuarantee: true
                ),
                LootTableEntry(
                    protocolId: "trace_route",
                    weight: 60,
                    isFirstKillGuarantee: false
                ),
                LootTableEntry(
                    protocolId: "ice_shard",
                    weight: 40,
                    isFirstKillGuarantee: false
                )
            ],
            guaranteeOnFirstKill: true
        )

        /// Void Harbinger - Chaos/Corruption theme
        /// Drops: Fork Bomb (E), Root Access (E), Overflow (L)
        static let voidHarbinger = BossLootTable(
            bossId: "void_harbinger",
            entries: [
                LootTableEntry(
                    protocolId: "fork_bomb",
                    weight: 60,
                    isFirstKillGuarantee: true
                ),
                LootTableEntry(
                    protocolId: "root_access",
                    weight: 40,
                    isFirstKillGuarantee: false
                ),
                LootTableEntry(
                    protocolId: "overflow",
                    weight: 100,
                    isFirstKillGuarantee: false
                )
            ],
            guaranteeOnFirstKill: true
        )

        /// Overclocker - Heat/PSU theme
        /// Drops: Ice Shard (R), Null Pointer (L)
        static let overclocker = BossLootTable(
            bossId: "overclocker",
            entries: [
                LootTableEntry(
                    protocolId: "ice_shard",
                    weight: 100,
                    isFirstKillGuarantee: true
                ),
                LootTableEntry(
                    protocolId: "null_pointer",
                    weight: 100,
                    isFirstKillGuarantee: false
                )
            ],
            guaranteeOnFirstKill: true
        )

        /// Trojan Wyrm - Network/Worm theme
        /// Drops: Root Access (E)
        static let trojanWyrm = BossLootTable(
            bossId: "trojan_wyrm",
            entries: [
                LootTableEntry(
                    protocolId: "root_access",
                    weight: 100,
                    isFirstKillGuarantee: true
                )
            ],
            guaranteeOnFirstKill: true
        )

        /// All loot tables
        static let all: [BossLootTable] = [
            cyberboss,
            voidHarbinger,
            overclocker,
            trojanWyrm
        ]

        // MARK: - Helpers

        /// Get loot table for a boss by ID
        static func lootTable(for bossId: String) -> BossLootTable? {
            return all.first { $0.bossId == bossId }
        }

        /// Get which boss drops a specific protocol
        static func bossesDropping(_ protocolId: String) -> [String] {
            return all.filter { table in
                table.entries.contains { $0.protocolId == protocolId }
            }.map { $0.bossId }
        }

        /// Get display name for a boss
        static func bossDisplayName(_ bossId: String) -> String {
            switch bossId {
            case "cyberboss": return "Cyberboss"
            case "void_harbinger": return "Void Harbinger"
            case "overclocker": return "Overclocker"
            case "trojan_wyrm": return "Trojan Wyrm"
            default: return bossId.capitalized
            }
        }
    }

    // MARK: - Sector Unlock System
    // Players unlock sectors by: 1) Defeating previous boss (visibility) 2) Paying Hash (unlock)
    // Fixed progression: PSU (starter) → RAM → GPU → Cache → Storage → Expansion → Network → I/O → CPU

    struct SectorUnlock {
        /// Sector unlock order (index 0 = starter, always unlocked)
        /// Each boss defeat makes the NEXT sector VISIBLE
        /// Player must then pay Hash to actually UNLOCK the sector
        static let unlockOrder: [String] = [
            "psu",        // 0 - Starter (free, no boss defeat needed)
            "ram",        // 1 - After PSU boss
            "gpu",        // 2 - After RAM boss
            "cache",      // 3 - After GPU boss
            "storage",    // 4 - After Cache boss
            "expansion",  // 5 - After Storage boss
            "network",    // 6 - After Expansion boss
            "io",         // 7 - After Network boss
            "cpu"         // 8 - After I/O boss (final unlock)
        ]

        /// Hash cost to unlock each sector (index matches unlockOrder)
        /// PSU is free, then costs escalate significantly
        static let hashCosts: [Int] = [
            0,           // PSU - starter, always free
            25_000,      // RAM - first paid unlock
            50_000,      // GPU
            75_000,      // Cache
            100_000,     // Storage
            150_000,     // Expansion
            200_000,     // Network
            300_000,     // I/O
            500_000      // CPU - final unlock, most expensive
        ]

        /// Blueprint drop chance on first boss kill (100% = guaranteed)
        static let firstKillBlueprintChance: CGFloat = 1.0

        /// Get unlock cost for a sector
        static func unlockCost(for sectorId: String) -> Int {
            guard let index = unlockOrder.firstIndex(of: sectorId) else { return 0 }
            guard index < hashCosts.count else { return 0 }
            return hashCosts[index]
        }

        /// Get the sector that becomes visible after defeating a boss in the given sector
        /// Returns nil if this is the last sector
        static func nextSector(after sectorId: String) -> String? {
            guard let index = unlockOrder.firstIndex(of: sectorId) else { return nil }
            let nextIndex = index + 1
            guard nextIndex < unlockOrder.count else { return nil }
            return unlockOrder[nextIndex]
        }

        /// Get the sector whose boss must be defeated to make this sector visible
        /// Returns nil for the starter sector
        static func previousSector(for sectorId: String) -> String? {
            guard let index = unlockOrder.firstIndex(of: sectorId), index > 0 else { return nil }
            return unlockOrder[index - 1]
        }

        /// Get unlock order index for a sector (0 = starter)
        static func unlockIndex(for sectorId: String) -> Int? {
            return unlockOrder.firstIndex(of: sectorId)
        }

        /// Check if a sector is the starter (always unlocked, no cost)
        static func isStarterSector(_ sectorId: String) -> Bool {
            return sectorId == unlockOrder.first
        }

        /// Check if a sector is the final unlock
        static func isFinalSector(_ sectorId: String) -> Bool {
            return sectorId == unlockOrder.last
        }

        /// Total Hash needed to unlock all sectors
        static var totalUnlockCost: Int {
            return hashCosts.reduce(0, +)
        }
    }

    // MARK: - Sector Hash Bonus
    // Enemies on later sectors give bonus hash - risk/reward for expanding
    // PSU (starter) = 1.0x, later sectors progressively more rewarding

    struct SectorHashBonus {
        /// Hash multiplier by sector (later = more rewarding)
        /// Makes expanding to new sectors worthwhile despite increased difficulty
        static let multipliers: [String: CGFloat] = [
            "psu": 1.0,        // Starter - baseline
            "ram": 1.2,        // +20% - first expansion reward
            "gpu": 1.4,        // +40%
            "cache": 1.6,      // +60%
            "storage": 1.8,    // +80%
            "expansion": 2.0,  // +100% - double hash!
            "network": 2.2,    // +120%
            "io": 2.5,         // +150%
            "cpu": 3.0         // +200% - triple hash for the final sector
        ]

        /// Get hash multiplier for a sector
        static func multiplier(for sectorId: String) -> CGFloat {
            return multipliers[sectorId] ?? 1.0
        }
    }

    // MARK: - Component Upgrades (Sector-based system)
    // Each sector has a component that can be upgraded (Lv 1-10)
    // Component unlock order matches sector unlock order from SectorUnlock

    struct Components {
        /// Maximum level for all component upgrades
        static let maxLevel: Int = 10

        /// Upgrade cost formula: baseCost × 2^(level-1)
        /// Total Lv1→10: baseCost × 511 (sum of 2^0 to 2^8)

        // MARK: - Unlock Order
        /// Fixed progression order - references SectorUnlock.unlockOrder
        static var unlockOrder: [String] {
            return SectorUnlock.unlockOrder
        }

        // MARK: - PSU (Power Supply) - Starter Component
        /// Power capacity in Watts per level
        static let psuCapacities: [Int] = [300, 400, 550, 700, 900, 1100, 1350, 1600, 1900, 2300]
        static let psuBaseCost: Int = 500

        static func psuCapacity(at level: Int) -> Int {
            return psuCapacities[min(max(level - 1, 0), psuCapacities.count - 1)]
        }

        // MARK: - Storage (SSD) - Hash Capacity + Offline Rate
        /// Hash storage capacity: base × 2^(level-1)
        static let storageBaseCapacity: Int = 15000     // Was 25000
        static let storageCapacityMultiplier: Double = 1.8  // Was 2.0 — Lv10 ≈ 3.2M (was 12.8M)
        /// Offline earning rate: 20% at Lv1, scales to 60% at Lv10
        static let storageBaseOfflineRate: CGFloat = 0.20
        static let storageOfflineRatePerLevel: CGFloat = 0.044  // (0.60 - 0.20) / 9
        static let storageBaseCost: Int = 400

        static func storageCapacity(at level: Int) -> Int {
            return Int(Double(storageBaseCapacity) * pow(storageCapacityMultiplier, Double(level - 1)))
        }

        static func storageOfflineRate(at level: Int) -> CGFloat {
            return storageBaseOfflineRate + CGFloat(level - 1) * storageOfflineRatePerLevel
        }

        // MARK: - RAM (Memory Module) - Efficiency Recovery
        /// Efficiency recovery multiplier: 1.0x at Lv1, 2.0x at Lv10
        static let ramBaseEfficiencyRegen: CGFloat = 1.0
        static let ramEfficiencyRegenPerLevel: CGFloat = 0.111  // (2.0 - 1.0) / 9
        static let ramBaseCost: Int = 400

        /// RAM health bonus (for Active/Boss mode): base + (level-1) × perLevel
        static let ramBaseHealth: CGFloat = 100
        static let ramHealthPerLevel: CGFloat = 20

        static func ramEfficiencyRegen(at level: Int) -> CGFloat {
            return ramBaseEfficiencyRegen + CGFloat(level - 1) * ramEfficiencyRegenPerLevel
        }

        // MARK: - GPU (Graphics Card) - Global Tower Damage
        /// Damage multiplier: 1.0x at Lv1, 1.5x at Lv10 (+50%)
        static let gpuBaseDamageMultiplier: CGFloat = 1.0
        static let gpuDamagePerLevel: CGFloat = 0.055  // (1.5 - 1.0) / 9
        static let gpuBaseCost: Int = 600

        static func gpuDamageMultiplier(at level: Int) -> CGFloat {
            return gpuBaseDamageMultiplier + CGFloat(level - 1) * gpuDamagePerLevel
        }

        // MARK: - Cache (Cache Chip) - Global Attack Speed
        /// Attack speed multiplier: 1.0x at Lv1, 1.3x at Lv10 (+30%)
        static let cacheBaseAttackSpeed: CGFloat = 1.0
        static let cacheAttackSpeedPerLevel: CGFloat = 0.033  // (1.3 - 1.0) / 9
        static let cacheBaseCost: Int = 550

        static func cacheAttackSpeedMultiplier(at level: Int) -> CGFloat {
            return cacheBaseAttackSpeed + CGFloat(level - 1) * cacheAttackSpeedPerLevel
        }

        // MARK: - Expansion (Expansion Card) - Extra Tower Slots
        /// Extra slots: Lv1=0, Lv2-4=+1, Lv5-7=+2, Lv8-10=+3
        /// First upgrade immediately gives benefit (no dead zone)
        static let expansionBaseCost: Int = 800

        static func expansionExtraSlots(at level: Int) -> Int {
            if level >= 8 { return 3 }
            if level >= 5 { return 2 }
            if level >= 2 { return 1 }
            return 0
        }

        // MARK: - I/O (I/O Controller) - Pickup Radius
        /// Pickup radius multiplier: 1.0x at Lv1, 2.5x at Lv10
        static let ioBasePickupRadius: CGFloat = 1.0
        static let ioPickupRadiusPerLevel: CGFloat = 0.167  // (2.5 - 1.0) / 9
        static let ioBaseCost: Int = 450

        static func ioPickupRadiusMultiplier(at level: Int) -> CGFloat {
            return ioBasePickupRadius + CGFloat(level - 1) * ioPickupRadiusPerLevel
        }

        // MARK: - Network (Network Card) - Global Hash Multiplier
        /// Hash multiplier: 1.0x at Lv1, 1.5x at Lv10 (+50% all Hash)
        static let networkBaseHashMultiplier: CGFloat = 1.0
        static let networkHashMultiplierPerLevel: CGFloat = 0.055  // (1.5 - 1.0) / 9
        static let networkBaseCost: Int = 1000

        static func networkHashMultiplier(at level: Int) -> CGFloat {
            return networkBaseHashMultiplier + CGFloat(level - 1) * networkHashMultiplierPerLevel
        }

        // MARK: - CPU (Processor) - Hash Generation Rate
        /// Hash/second: uses exponential scaling from HashEconomy
        /// 1 Ħ/s at Lv1, ~38 Ħ/s at Lv10
        static let cpuBaseCost: Int = 750

        static func cpuHashPerSecond(at level: Int) -> CGFloat {
            return HashEconomy.hashPerSecond(at: level)
        }

        // MARK: - Helper Functions

        /// Get base upgrade cost for a component type
        static func baseCost(for componentId: String) -> Int {
            switch componentId {
            case "psu": return psuBaseCost
            case "storage": return storageBaseCost
            case "ram": return ramBaseCost
            case "gpu": return gpuBaseCost
            case "cache": return cacheBaseCost
            case "expansion": return expansionBaseCost
            case "io": return ioBaseCost
            case "network": return networkBaseCost
            case "cpu": return cpuBaseCost
            default: return 500
            }
        }

        /// Calculate upgrade cost for a component at a given level
        /// Uses centralized exponential formula from BalanceConfig
        static func upgradeCost(for componentId: String, at level: Int) -> Int? {
            guard level < maxLevel else { return nil }
            let base = baseCost(for: componentId)
            return BalanceConfig.exponentialUpgradeCost(baseCost: base, currentLevel: level)
        }

        /// Get unlock order index for a component (0 = starter)
        static func unlockIndex(for componentId: String) -> Int? {
            return unlockOrder.firstIndex(of: componentId)
        }

        /// Check if a component is unlocked based on defeated bosses count
        static func isUnlocked(componentId: String, defeatedBossCount: Int) -> Bool {
            guard let index = unlockIndex(for: componentId) else { return false }
            // PSU (index 0) is always unlocked
            // RAM (index 1) unlocks after defeating 1 boss (PSU boss)
            return index <= defeatedBossCount
        }
    }

    // MARK: - XP System (Survivor Mode)

    struct XPSystem {
        /// XP values by enemy type
        static let basicEnemyXP: Int = 1
        static let fastEnemyXP: Int = 2
        static let tankEnemyXP: Int = 5
        static let bossEnemyXP: Int = 20
        static let cyberbossXP: Int = 50
        static let voidHarbingerXP: Int = 100

        /// Hash value for killing a boss enemy (survival/arena mode)
        static let bossKillHashValue: Int = 50

        /// XP multiplier reduction per weapon level (higher levels = less XP)
        static let xpReductionPerLevel: CGFloat = 0.10  // 10% reduction per level
        static let minXPMultiplier: CGFloat = 0.2       // Minimum 20% XP

        /// Loot box tier thresholds (based on XP bar progress)
        static let tier1Threshold: CGFloat = 0.33  // Wooden
        static let tier2Threshold: CGFloat = 0.66  // Silver
        static let tier3Threshold: CGFloat = 1.0   // Golden

        /// Loot box rarity weights by tier (common, rare, epic, legendary)
        /// Golden box - best odds
        static let goldenCommonWeight: Double = 10
        static let goldenRareWeight: Double = 30
        static let goldenEpicWeight: Double = 40
        static let goldenLegendaryWeight: Double = 20

        /// Silver box - medium odds
        static let silverCommonWeight: Double = 40
        static let silverRareWeight: Double = 35
        static let silverEpicWeight: Double = 20
        static let silverLegendaryWeight: Double = 5

        /// Wooden box - basic odds
        static let woodenCommonWeight: Double = 80
        static let woodenRareWeight: Double = 15
        static let woodenEpicWeight: Double = 5
        static let woodenLegendaryWeight: Double = 0
    }

    // MARK: - Protocol Scaling (Tower/Weapon Level Scaling)

    struct ProtocolScaling {
        /// Range scaling per level (+5%)
        static let rangePerLevel: CGFloat = 0.05

        /// Fire rate scaling per level (+3%)
        static let fireRatePerLevel: CGFloat = 0.03

        /// Ricochet ability chain targets
        static let ricochetChainTargets: Int = 3

        /// Explosive ability splash radius
        static let explosiveSplashRadius: CGFloat = 50

        /// Weapon range for boss arena conversion
        static let bossArenaWeaponRange: CGFloat = 600
    }

    // MARK: - Protocol Base Stats
    // Per-protocol base stats for Firewall (TD) and Weapon (Boss/Debug) modes
    // These are level-1 values before any scaling is applied
    // Special abilities (.chain, .execute, etc.) stay in Protocol.swift

    struct ProtocolBaseStats {

        struct KernelPulse {
            // Firewall (Tower) Stats
            static let firewallDamage: CGFloat = 8
            static let firewallRange: CGFloat = 120
            static let firewallFireRate: CGFloat = 1.0
            static let firewallProjectileCount: Int = 1
            static let firewallPierce: Int = 1
            static let firewallSplash: CGFloat = 0
            static let firewallSlow: CGFloat = 0
            static let firewallSlowDuration: TimeInterval = 0
            static let firewallPowerDraw: Int = 15
            // Weapon (Active/Debug) Stats
            static let weaponDamage: CGFloat = 8
            static let weaponFireRate: CGFloat = 2.0
            static let weaponProjectileCount: Int = 1
            static let weaponSpread: CGFloat = 0
            static let weaponPierce: Int = 1
            static let weaponProjectileSpeed: CGFloat = 400
            // Costs
            static let compileCost: Int = 0
            static let baseUpgradeCost: Int = 50
        }

        struct BurstProtocol {
            static let firewallDamage: CGFloat = 10
            static let firewallRange: CGFloat = 140
            static let firewallFireRate: CGFloat = 0.8
            static let firewallProjectileCount: Int = 1
            static let firewallPierce: Int = 1
            static let firewallSplash: CGFloat = 40
            static let firewallSlow: CGFloat = 0
            static let firewallSlowDuration: TimeInterval = 0
            static let firewallPowerDraw: Int = 20
            static let weaponDamage: CGFloat = 6
            static let weaponFireRate: CGFloat = 0.8
            static let weaponProjectileCount: Int = 5
            static let weaponSpread: CGFloat = 0.5
            static let weaponPierce: Int = 1
            static let weaponProjectileSpeed: CGFloat = 350
            static let compileCost: Int = 100
            static let baseUpgradeCost: Int = 50
        }

        struct TraceRoute {
            static let firewallDamage: CGFloat = 50
            static let firewallRange: CGFloat = 250
            static let firewallFireRate: CGFloat = 0.4
            static let firewallProjectileCount: Int = 1
            static let firewallPierce: Int = 3
            static let firewallSplash: CGFloat = 0
            static let firewallSlow: CGFloat = 0
            static let firewallSlowDuration: TimeInterval = 0
            static let firewallPowerDraw: Int = 35
            static let weaponDamage: CGFloat = 40
            static let weaponFireRate: CGFloat = 0.5
            static let weaponProjectileCount: Int = 1
            static let weaponSpread: CGFloat = 0
            static let weaponPierce: Int = 5
            static let weaponProjectileSpeed: CGFloat = 800
            static let compileCost: Int = 200
            static let baseUpgradeCost: Int = 100
        }

        struct IceShard {
            static let firewallDamage: CGFloat = 5
            static let firewallRange: CGFloat = 130
            static let firewallFireRate: CGFloat = 1.5
            static let firewallProjectileCount: Int = 1
            static let firewallPierce: Int = 1
            static let firewallSplash: CGFloat = 0
            static let firewallSlow: CGFloat = 0.5
            static let firewallSlowDuration: TimeInterval = 2.0
            static let firewallPowerDraw: Int = 30
            static let weaponDamage: CGFloat = 4
            static let weaponFireRate: CGFloat = 3.0
            static let weaponProjectileCount: Int = 1
            static let weaponSpread: CGFloat = 0
            static let weaponPierce: Int = 1
            static let weaponProjectileSpeed: CGFloat = 500
            static let compileCost: Int = 200
            static let baseUpgradeCost: Int = 100
        }

        struct ForkBomb {
            static let firewallDamage: CGFloat = 12
            static let firewallRange: CGFloat = 140
            static let firewallFireRate: CGFloat = 0.7
            static let firewallProjectileCount: Int = 3
            static let firewallPierce: Int = 1
            static let firewallSplash: CGFloat = 0
            static let firewallSlow: CGFloat = 0
            static let firewallSlowDuration: TimeInterval = 0
            static let firewallPowerDraw: Int = 40
            static let weaponDamage: CGFloat = 10
            static let weaponFireRate: CGFloat = 1.0
            static let weaponProjectileCount: Int = 8
            static let weaponSpread: CGFloat = 0.8
            static let weaponPierce: Int = 1
            static let weaponProjectileSpeed: CGFloat = 380
            static let compileCost: Int = 400
            static let baseUpgradeCost: Int = 200
        }

        struct RootAccess {
            static let firewallDamage: CGFloat = 80
            static let firewallRange: CGFloat = 160
            static let firewallFireRate: CGFloat = 0.3
            static let firewallProjectileCount: Int = 1
            static let firewallPierce: Int = 1
            static let firewallSplash: CGFloat = 0
            static let firewallSlow: CGFloat = 0
            static let firewallSlowDuration: TimeInterval = 0
            static let firewallPowerDraw: Int = 75
            static let weaponDamage: CGFloat = 60
            static let weaponFireRate: CGFloat = 0.4
            static let weaponProjectileCount: Int = 1
            static let weaponSpread: CGFloat = 0
            static let weaponPierce: Int = 1
            static let weaponProjectileSpeed: CGFloat = 600
            static let compileCost: Int = 400
            static let baseUpgradeCost: Int = 200
        }

        struct Overflow {
            static let firewallDamage: CGFloat = 15
            static let firewallRange: CGFloat = 150
            static let firewallFireRate: CGFloat = 0.8
            static let firewallProjectileCount: Int = 1
            static let firewallPierce: Int = 1
            static let firewallSplash: CGFloat = 0
            static let firewallSlow: CGFloat = 0
            static let firewallSlowDuration: TimeInterval = 0
            static let firewallPowerDraw: Int = 120
            static let weaponDamage: CGFloat = 12
            static let weaponFireRate: CGFloat = 1.2
            static let weaponProjectileCount: Int = 1
            static let weaponSpread: CGFloat = 0
            static let weaponPierce: Int = 1
            static let weaponProjectileSpeed: CGFloat = 450
            static let compileCost: Int = 800
            static let baseUpgradeCost: Int = 400
        }

        struct NullPointer {
            static let firewallDamage: CGFloat = 25
            static let firewallRange: CGFloat = 140
            static let firewallFireRate: CGFloat = 0.6
            static let firewallProjectileCount: Int = 1
            static let firewallPierce: Int = 1
            static let firewallSplash: CGFloat = 0
            static let firewallSlow: CGFloat = 0
            static let firewallSlowDuration: TimeInterval = 0
            static let firewallPowerDraw: Int = 100
            static let weaponDamage: CGFloat = 20
            static let weaponFireRate: CGFloat = 0.8
            static let weaponProjectileCount: Int = 1
            static let weaponSpread: CGFloat = 0
            static let weaponPierce: Int = 1
            static let weaponProjectileSpeed: CGFloat = 500
            static let compileCost: Int = 800
            static let baseUpgradeCost: Int = 400
        }
    }

    // MARK: - Pillar System (Boss Fight Cover)

    struct Pillar {
        /// Damage per second bosses deal to pillars when blocking line-of-sight
        static let bossPillarDPS: CGFloat = 20

        /// Default pillar size
        static let defaultSize: CGFloat = 80

        /// Default pillar health
        static let defaultHealth: CGFloat = 300
    }

    // MARK: - Blocker System (TD Pathfinding)

    struct BlockerSystem {
        /// Detour distance for pathfinding around blockers
        static let detourDistance: CGFloat = 60

        /// Blocker collision radius
        static let blockRadius: CGFloat = 40
    }

    // MARK: - Arena Layouts

    struct Arena {
        /// Boss arena dimensions
        static let bossArenaWidth: CGFloat = 1200
        static let bossArenaHeight: CGFloat = 900

        /// Spawn distance multiplier for survival mode
        static let spawnDistanceMultiplier: CGFloat = 0.6

        /// Cache flush invulnerability duration
        static let cacheFlushInvulnerability: TimeInterval = 1.0
    }

    // MARK: - Tower Placement (TD Mode Slots)

    struct TowerPlacement {
        /// Tower slot size
        static let slotSize: CGFloat = 40

        /// Margin from map edges
        static let edgeMargin: CGFloat = 60

        /// Slot spacing along paths
        static let pathSlotSpacing: CGFloat = 80

        /// Max distance from path to slot
        static let maxPathDistance: CGFloat = 100

        /// Motherboard slot size
        static let motherboardSlotSize: CGFloat = 60

        /// Minimum distance between slots
        static let minSlotDistance: CGFloat = 70

        /// CPU exclusion radius (no towers near CPU)
        static let cpuExclusionRadius: CGFloat = 280

        /// Distance from CPU center for defense slot placement
        static let cpuDefenseSlotOffset: CGFloat = 330
    }

    // MARK: - Projectile System

    struct ProjectileSystem {
        /// Splash damage multiplier (percentage of direct damage)
        static let splashDamageMultiplier: CGFloat = 0.5

        /// Search radius buffer for enemy detection
        static let searchRadiusBuffer: CGFloat = 30

        /// Weapon system projectile spacing for multi-shot
        static let multiShotSpacing: CGFloat = 10

        /// Critical hit chance (15% = 0.15)
        static let criticalHitChance: Double = 0.15

        /// Critical hit damage multiplier
        static let criticalHitMultiplier: CGFloat = 2.0

        /// Default projectile speed fallback
        static let defaultProjectileSpeed: CGFloat = 300

        /// Player weapon projectile radius
        static let playerProjectileRadius: CGFloat = 5

        /// Spawn offset from player edge
        static let spawnOffset: CGFloat = 10

        /// Chain lightning damage multiplier per bounce (70% of previous hit)
        static let chainDamageMultiplier: CGFloat = 0.7

        /// Chain lightning search range for next target
        static let chainSearchRange: CGFloat = 120
    }

    // MARK: - Overclock Duplicate Values (TD State)
    // Note: These are also stored in TDTypes for state initialization
    // The canonical values are here in BalanceConfig.Overclock

    // MARK: - Manual Override Minigame

    struct ManualOverride {
        /// Duration of survival challenge
        static let duration: TimeInterval = 30.0

        /// Player movement speed
        static let playerSpeed: CGFloat = 200

        /// Initial hazard spawn interval
        static let initialHazardSpawnInterval: TimeInterval = 1.5

        /// Invincibility duration after hit
        static let invincibilityDuration: TimeInterval = 1.5

        /// Starting health (lives)
        static let maxHealth: Int = 3

        /// Hazard movement speed range
        static let hazardSpeedMin: CGFloat = 150
        static let hazardSpeedMax: CGFloat = 250

        /// Hazard velocity variance (perpendicular to main direction)
        static let hazardVelocityVariance: CGFloat = 50

        /// Sweep hazard gap size (pixels the player can fit through)
        static let sweepGapSize: CGFloat = 70

        /// Sweep hazard velocity (points per second)
        static let sweepVelocity: CGFloat = 80

        /// Expanding hazard growth rate (radius increase per second)
        static let expandingGrowthRate: CGFloat = 80

        /// Player collision radius for hit detection
        static let playerCollisionRadius: CGFloat = 15

        /// Hazard collision radius for projectile hit detection
        static let hazardCollisionRadius: CGFloat = 15

        /// Difficulty escalation interval (seconds between spawn rate increases)
        static let difficultyEscalationInterval: TimeInterval = 5

        /// Spawn interval reduction per escalation tick
        static let spawnIntervalReduction: TimeInterval = 0.2

        /// Minimum hazard spawn interval (floor for difficulty scaling)
        static let minHazardSpawnInterval: TimeInterval = 0.5

        // MARK: Visual Tuning

        /// Player shield aura radius
        static let playerShieldRadius: CGFloat = 28

        /// Player additive glow layer radius
        static let playerGlowRadius: CGFloat = 24

        /// Player octagon body radius
        static let playerBodyRadius: CGFloat = 18

        /// Player bright core radius
        static let playerCoreRadius: CGFloat = 8

        /// Player orbit dots distance from center
        static let playerOrbitRadius: CGFloat = 18

        /// Player orbit rotation period (seconds per revolution)
        static let playerOrbitSpeed: TimeInterval = 4.0

        /// Interval between ambient data flow particle spawns
        static let ambientParticleInterval: TimeInterval = 0.8

        /// Maximum concurrent ambient particles
        static let maxAmbientParticles: Int = 6

        /// Duration of screen glitch effect on damage
        static let damageGlitchDuration: TimeInterval = 0.3

        /// Number of scatter fragments on damage hit
        static let damageFragmentCount: Int = 8
    }

    // MARK: - TD Rendering

    struct TDRendering {
        /// Initial delay before wave 1 starts
        static let gameStartDelay: TimeInterval = 2.0

        /// Screen shake cooldown
        static let screenShakeCooldown: TimeInterval = 0.5

        /// Visibility update interval for sector culling
        static let visibilityUpdateInterval: TimeInterval = 0.5

        /// Data pulse travel speed (points per second)
        static let pulseTravelSpeed: CGFloat = 600

        /// Tower barrel rotation speed (radians per second) for smooth aiming
        static let barrelRotationSpeed: CGFloat = 8.0

        /// Max ambient particles per sector (performance cap)
        static let maxAmbientParticles: Int = 30

        /// Power flow particle spawn interval (seconds between particles)
        static let powerFlowSpawnInterval: TimeInterval = 1.0

        /// Enemy portal spawn animation duration
        static let portalAnimationDuration: TimeInterval = 0.8
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

    /// Linear level bonus: 1.0 + (level-1) × bonusRate
    /// Used by CoreSystem (TDCore.levelBonusPercent) and LevelingSystem (ThreatLevel.levelBonusPercent)
    static func linearLevelBonus(level: Int, bonusRate: CGFloat) -> CGFloat {
        return 1.0 + CGFloat(level - 1) * bonusRate
    }

    /// Get tower placement cost
    static func towerCost(rarity: Rarity) -> Int {
        return Towers.placementCosts[rarity] ?? 50
    }

    // MARK: - Tower Special Effects (Protocol Mechanics)
    // These constants define the status effects applied by each tower type

    /// Throttler (ice_shard) - Slow + stun chance
    struct Throttler {
        /// Slow amount (0.5 = 50% speed reduction)
        static let slowAmount: CGFloat = 0.5
        /// Slow duration in seconds
        static let slowDuration: TimeInterval = 2.0
        /// Chance to stun on hit (0.1 = 10%)
        static let stunChance: Double = 0.1
        /// Stun duration in seconds
        static let stunDuration: TimeInterval = 0.5
        /// Immunity window after stun expires (prevents permastun)
        static let stunImmunityDuration: TimeInterval = 1.0
    }

    /// Pinger (trace_route) - Tags enemies for bonus damage from all sources
    struct Pinger {
        /// Bonus damage multiplier when tagged (0.2 = +20%)
        static let tagDamageBonus: CGFloat = 0.2
        /// Tag duration in seconds
        static let tagDuration: TimeInterval = 3.0
    }

    /// Garbage Collector (null_pointer) - Marks enemies for hash bonus on death
    struct GarbageCollector {
        /// Duration of the mark effect (longer = more synergy window for ally kills)
        static let markDuration: TimeInterval = 3.0
        /// Bonus hash when marked enemy dies
        static let hashBonus: Int = 5
    }

    /// Fragmenter (burst_protocol) - DoT burn effect
    struct Fragmenter {
        /// Burn damage as percent of impact damage (0.5 = 50%)
        static let burnDamagePercent: CGFloat = 0.5
        /// Total burn duration
        static let burnDuration: TimeInterval = 1.5
        /// Time between burn ticks
        static let burnTickInterval: TimeInterval = 0.5
    }

    /// Recursion (fork_bomb) - Splits into child projectiles on impact
    struct Recursion {
        /// Number of child projectiles spawned
        static let childCount: Int = 3
        /// Child damage as percent of parent (0.5 = 50%)
        static let childDamagePercent: CGFloat = 0.5
    }

    // MARK: - Simulation

    struct Simulation {
        /// Physics tick rate for headless simulation (60 FPS equivalent)
        static let defaultTickRate: TimeInterval = 1.0 / 60.0

        /// How often bots make decisions (seconds)
        static let botDecisionInterval: TimeInterval = 0.5

        /// Default max game time for simulations (5 minutes)
        static let defaultMaxGameTime: TimeInterval = 300

        /// How often to sample efficiency for graphs
        static let efficiencySampleInterval: TimeInterval = 5.0

        /// Power usage threshold that triggers "wall" detection
        static let powerWallThreshold: CGFloat = 0.95

        /// Storage usage threshold that triggers "wall" detection
        static let storageWallThreshold: CGFloat = 0.90

        // MARK: - Boss Sim Weapon Effects

        /// Pinger tag duration (boss takes bonus damage while tagged)
        static let pingerTagDuration: TimeInterval = 4.0

        /// Throttler slow duration
        static let throttlerSlowDuration: TimeInterval = 2.0

        /// Throttler stun duration (on crit)
        static let throttlerStunDuration: TimeInterval = 0.5

        /// Garbage Collector mark duration
        static let garbageCollectorMarkDuration: TimeInterval = 2.0

        /// Fragmenter DoT tick interval
        static let fragmenterTickInterval: TimeInterval = 0.5

        /// Fragmenter DoT damage multiplier (fraction of base damage)
        static let fragmenterDotMultiplier: CGFloat = 0.5

        /// Recursion child projectile damage multiplier
        static let recursionChildDamageMultiplier: CGFloat = 0.35

        /// Projectile homing force (acceleration)
        static let projectileHomingForce: CGFloat = 2.0

        /// Boss arena edge padding (clamp margin)
        static let bossArenaPadding: CGFloat = 80

        /// Minion spawn margin from arena edges
        static let minionSpawnMargin: CGFloat = 100

        // MARK: - Adaptive Bot Thresholds

        /// Efficiency below this triggers "panic mode" — prioritize defense over economy
        /// Lower threshold (40%) gives bot more time to establish defenses before panic kicks in
        static let botPanicEfficiencyThreshold: CGFloat = 40.0

        /// Power usage above this fraction → stop placing new towers, focus upgrades
        static let botPowerCeilingThreshold: CGFloat = 0.85

        /// Efficiency above this allows overclock (RushOC uses 70, Adaptive is more conservative)
        static let botSafeOverclockThreshold: CGFloat = 80.0

        /// How many seconds of hash income to keep in reserve
        static let botHashReserveSeconds: CGFloat = 10.0

        // MARK: - Component Level Presets

        /// Early game: all components at level 1
        static let earlyGame = ComponentLevels(
            power: 1, storage: 1, ram: 1, gpu: 1, cache: 1,
            expansion: 1, io: 1, network: 1, cpu: 1
        )

        /// Mid game: some upgrades done
        static let midGame = ComponentLevels(
            power: 3, storage: 2, ram: 2, gpu: 1, cache: 2,
            expansion: 1, io: 1, network: 1, cpu: 3
        )

        /// Late game: significant upgrades
        static let lateGame = ComponentLevels(
            power: 5, storage: 4, ram: 4, gpu: 3, cache: 4,
            expansion: 2, io: 2, network: 2, cpu: 5
        )

        /// End game: near max components
        static let endGame = ComponentLevels(
            power: 8, storage: 6, ram: 6, gpu: 5, cache: 6,
            expansion: 4, io: 4, network: 4, cpu: 8
        )
    }

    // MARK: - Motherboard Layout

    struct Motherboard {
        /// Total canvas size (3 sectors × 1400)
        static let canvasSize: CGFloat = 4200

        /// Size of each sector
        static let sectorSize: CGFloat = 1400

        /// CPU core visual size (IHS body)
        static let cpuSize: CGFloat = 300

        /// CPU inner silicon die size
        static let cpuDieSize: CGFloat = 200

        /// CPU socket retention frame size
        static let cpuSocketFrameSize: CGFloat = 800

        /// Number of pins per side on CPU
        static let cpuPinsPerSide: Int = 12

        /// Number of heatsink fins around CPU
        static let cpuFinCount: Int = 16

        /// CPU outer glow ring radius
        static let cpuGlowRingRadius: CGFloat = 200
    }

    // MARK: - System Freeze

    struct Freeze {
        /// Divisor for flush memory cost (hash / this = cost, i.e. 10% of current hash)
        static let recoveryHashDivisor: Int = 10

        /// Minimum flush cost (even with very low hash)
        static let minimumFlushCost: Int = 1

        /// Target efficiency after flush memory recovery (percentage points)
        static let recoveryTargetEfficiency: CGFloat = 50

        /// Target efficiency after manual override success (percentage points)
        static let manualOverrideRecoveryEfficiency: CGFloat = 100
    }

    // MARK: - Offline Earnings

    struct OfflineEarnings {
        /// Minimum hash earned to show the welcome-back modal
        static let minimumDisplayThreshold: Int = 10
    }

    // MARK: - Offline Simulation

    struct OfflineSimulation {
        /// Base enemy HP used for offline defense calculations
        static let baseEnemyHP: CGFloat = 20

        /// Defense threshold ratio — need this fraction of offense to hold (0.8 = 80%)
        static let defenseThreshold: CGFloat = 0.8

        /// Maximum leaks per hour when defense is 0%
        static let maxLeaksPerHour: CGFloat = 10.0

        /// Maximum offline time cap in seconds (24 hours)
        static let maxOfflineSeconds: TimeInterval = 86400

        /// Minimum notification schedule time (seconds)
        static let minNotificationTime: TimeInterval = 300

        /// Maximum notification schedule time (seconds)
        static let maxNotificationTime: TimeInterval = 86400
    }

    // MARK: - TD Maps

    struct TDMaps {
        /// Maps that support tower defense mode
        static let supportedMaps: [String] = [
            TDMapID.grasslands.rawValue, TDMapID.volcano.rawValue,
            TDMapID.iceCave.rawValue, TDMapID.castle.rawValue,
            TDMapID.space.rawValue, TDMapID.temple.rawValue
        ]
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
            "dropRates": [
                "Easy": BossLoot.dropRates["Easy"] ?? [:],
                "Normal": BossLoot.dropRates["Normal"] ?? [:],
                "Hard": BossLoot.dropRates["Hard"] ?? [:],
                "Nightmare": BossLoot.dropRates["Nightmare"] ?? [:]
            ],
            "pityThreshold": BossLoot.pityThreshold,
            "diminishingFactor": BossLoot.diminishingFactor
        ]

        let towerPowerDict: [String: Any] = [
            "common": TowerPower.powerDraw(for: .common),
            "rare": TowerPower.powerDraw(for: .rare),
            "epic": TowerPower.powerDraw(for: .epic),
            "legendary": TowerPower.powerDraw(for: .legendary)
        ]

        let powerGridDict: [String: Any] = [
            "basePowerBudget": CPU.tierMultipliers[0],
            "towerPower": towerPowerDict,
            "cpuTierMultipliers": CPU.tierMultipliers.map { Double($0) },
            "cpuUpgradeCosts": CPU.upgradeCosts,
            "cpuMaxTier": CPU.maxTier
        ]

        let cyberbossDict: [String: Any] = [
            "baseHealth": Double(Cyberboss.baseHealth),
            "phase2Threshold": Double(Cyberboss.phase2Threshold),
            "phase3Threshold": Double(Cyberboss.phase3Threshold),
            "phase4Threshold": Double(Cyberboss.phase4Threshold),
            "laserBeamDamage": Double(Cyberboss.laserBeamDamage),
            "puddleDPS": Double(Cyberboss.puddleDPS)
        ]

        let voidHarbingerDict: [String: Any] = [
            "baseHealth": Double(VoidHarbinger.baseHealth),
            "phase2Threshold": Double(VoidHarbinger.phase2Threshold),
            "phase3Threshold": Double(VoidHarbinger.phase3Threshold),
            "phase4Threshold": Double(VoidHarbinger.phase4Threshold)
        ]

        let overclockerDict: [String: Any] = [
            "baseHealth": Double(Overclocker.baseHealth),
            "phase2Threshold": Double(Overclocker.phase2Threshold),
            "phase3Threshold": Double(Overclocker.phase3Threshold),
            "phase4Threshold": Double(Overclocker.phase4Threshold)
        ]

        let trojanWyrmDict: [String: Any] = [
            "baseHealth": Double(TrojanWyrm.baseHealth),
            "phase2Threshold": Double(TrojanWyrm.phase2Threshold),
            "phase3Threshold": Double(TrojanWyrm.phase3Threshold),
            "phase4Threshold": Double(TrojanWyrm.phase4Threshold)
        ]

        let bossesDict: [String: Any] = [
            "cyberboss": cyberbossDict,
            "voidHarbinger": voidHarbingerDict,
            "overclocker": overclockerDict,
            "trojanWyrm": trojanWyrmDict
        ]

        let overclockDict: [String: Any] = [
            "duration": Overclock.duration,
            "hashMultiplier": Double(Overclock.hashMultiplier),
            "threatMultiplier": Double(Overclock.threatMultiplier),
            "powerDemandMultiplier": Double(Overclock.powerDemandMultiplier)
        ]

        let hashEconomyDict: [String: Any] = [
            "baseHashPerSecond": Double(HashEconomy.baseHashPerSecond),
            "cpuLevelScaling": Double(HashEconomy.cpuLevelScaling),
            "offlineEarningsRate": Double(HashEconomy.offlineEarningsRate),
            "maxOfflineHours": Double(HashEconomy.maxOfflineHours)
        ]

        let protocolScalingDict: [String: Any] = [
            "rangePerLevel": Double(ProtocolScaling.rangePerLevel),
            "fireRatePerLevel": Double(ProtocolScaling.fireRatePerLevel),
            "maxUpgradeLevel": maxUpgradeLevel
        ]

        let componentCostsDict: [String: Int] = [
            "psu": Components.psuBaseCost,
            "ram": Components.ramBaseCost,
            "gpu": Components.gpuBaseCost,
            "cache": Components.cacheBaseCost,
            "storage": Components.storageBaseCost,
            "expansion": Components.expansionBaseCost,
            "network": Components.networkBaseCost,
            "io": Components.ioBaseCost,
            "cpu": Components.cpuBaseCost
        ]

        let componentsDict: [String: Any] = [
            "maxLevel": Components.maxLevel,
            "baseCosts": componentCostsDict,
            "psuCapacities": Components.psuCapacities,
            "gpuDamagePerLevel": Double(Components.gpuDamagePerLevel),
            "cacheAttackSpeedPerLevel": Double(Components.cacheAttackSpeedPerLevel),
            "ramEfficiencyRegenPerLevel": Double(Components.ramEfficiencyRegenPerLevel),
            "networkHashMultiplierPerLevel": Double(Components.networkHashMultiplierPerLevel),
            "ioPickupRadiusPerLevel": Double(Components.ioPickupRadiusPerLevel),
            "storageBaseCapacity": Components.storageBaseCapacity
        ]

        let efficiencyDict: [String: Any] = [
            "leakDecayInterval": Efficiency.leakDecayInterval,
            "warningThreshold": Double(Efficiency.warningThreshold)
        ]

        let freezeDict: [String: Any] = [
            "recoveryHashDivisor": Freeze.recoveryHashDivisor,
            "recoveryTargetEfficiency": Double(Freeze.recoveryTargetEfficiency)
        ]

        let sectorUnlockDict: [String: Any] = [
            "unlockOrder": SectorUnlock.unlockOrder,
            "hashCosts": SectorUnlock.hashCosts,
            "totalUnlockCost": SectorUnlock.totalUnlockCost,
            "firstKillBlueprintChance": Double(SectorUnlock.firstKillBlueprintChance)
        ]

        let sectorHashBonusDict: [String: Double] = Dictionary(
            uniqueKeysWithValues: SectorHashBonus.multipliers.map { ($0.key, Double($0.value)) }
        )

        func protoStatsDict(
            fwDmg: CGFloat, fwRng: CGFloat, fwRate: CGFloat, fwProj: Int, fwPierce: Int,
            fwSplash: CGFloat, fwSlow: CGFloat, fwSlowDur: TimeInterval, fwPower: Int,
            wpDmg: CGFloat, wpRate: CGFloat, wpProj: Int, wpSpread: CGFloat,
            wpPierce: Int, wpSpeed: CGFloat,
            compile: Int, upgrade: Int, rarity: String
        ) -> [String: Any] {
            [
                "rarity": rarity,
                "firewall": [
                    "damage": Double(fwDmg), "range": Double(fwRng), "fireRate": Double(fwRate),
                    "projectileCount": fwProj, "pierce": fwPierce, "splash": Double(fwSplash),
                    "slow": Double(fwSlow), "slowDuration": fwSlowDur, "powerDraw": fwPower
                ] as [String: Any],
                "weapon": [
                    "damage": Double(wpDmg), "fireRate": Double(wpRate),
                    "projectileCount": wpProj, "spread": Double(wpSpread),
                    "pierce": wpPierce, "projectileSpeed": Double(wpSpeed)
                ] as [String: Any],
                "compileCost": compile, "baseUpgradeCost": upgrade
            ]
        }

        typealias PBS = ProtocolBaseStats
        let protocolBaseStatsDict: [String: Any] = [
            "kernel_pulse": protoStatsDict(
                fwDmg: PBS.KernelPulse.firewallDamage, fwRng: PBS.KernelPulse.firewallRange, fwRate: PBS.KernelPulse.firewallFireRate,
                fwProj: PBS.KernelPulse.firewallProjectileCount, fwPierce: PBS.KernelPulse.firewallPierce,
                fwSplash: PBS.KernelPulse.firewallSplash, fwSlow: PBS.KernelPulse.firewallSlow, fwSlowDur: PBS.KernelPulse.firewallSlowDuration,
                fwPower: PBS.KernelPulse.firewallPowerDraw, wpDmg: PBS.KernelPulse.weaponDamage, wpRate: PBS.KernelPulse.weaponFireRate,
                wpProj: PBS.KernelPulse.weaponProjectileCount, wpSpread: PBS.KernelPulse.weaponSpread,
                wpPierce: PBS.KernelPulse.weaponPierce, wpSpeed: PBS.KernelPulse.weaponProjectileSpeed,
                compile: PBS.KernelPulse.compileCost, upgrade: PBS.KernelPulse.baseUpgradeCost, rarity: "common"),
            "burst_protocol": protoStatsDict(
                fwDmg: PBS.BurstProtocol.firewallDamage, fwRng: PBS.BurstProtocol.firewallRange, fwRate: PBS.BurstProtocol.firewallFireRate,
                fwProj: PBS.BurstProtocol.firewallProjectileCount, fwPierce: PBS.BurstProtocol.firewallPierce,
                fwSplash: PBS.BurstProtocol.firewallSplash, fwSlow: PBS.BurstProtocol.firewallSlow, fwSlowDur: PBS.BurstProtocol.firewallSlowDuration,
                fwPower: PBS.BurstProtocol.firewallPowerDraw, wpDmg: PBS.BurstProtocol.weaponDamage, wpRate: PBS.BurstProtocol.weaponFireRate,
                wpProj: PBS.BurstProtocol.weaponProjectileCount, wpSpread: PBS.BurstProtocol.weaponSpread,
                wpPierce: PBS.BurstProtocol.weaponPierce, wpSpeed: PBS.BurstProtocol.weaponProjectileSpeed,
                compile: PBS.BurstProtocol.compileCost, upgrade: PBS.BurstProtocol.baseUpgradeCost, rarity: "common"),
            "trace_route": protoStatsDict(
                fwDmg: PBS.TraceRoute.firewallDamage, fwRng: PBS.TraceRoute.firewallRange, fwRate: PBS.TraceRoute.firewallFireRate,
                fwProj: PBS.TraceRoute.firewallProjectileCount, fwPierce: PBS.TraceRoute.firewallPierce,
                fwSplash: PBS.TraceRoute.firewallSplash, fwSlow: PBS.TraceRoute.firewallSlow, fwSlowDur: PBS.TraceRoute.firewallSlowDuration,
                fwPower: PBS.TraceRoute.firewallPowerDraw, wpDmg: PBS.TraceRoute.weaponDamage, wpRate: PBS.TraceRoute.weaponFireRate,
                wpProj: PBS.TraceRoute.weaponProjectileCount, wpSpread: PBS.TraceRoute.weaponSpread,
                wpPierce: PBS.TraceRoute.weaponPierce, wpSpeed: PBS.TraceRoute.weaponProjectileSpeed,
                compile: PBS.TraceRoute.compileCost, upgrade: PBS.TraceRoute.baseUpgradeCost, rarity: "rare"),
            "ice_shard": protoStatsDict(
                fwDmg: PBS.IceShard.firewallDamage, fwRng: PBS.IceShard.firewallRange, fwRate: PBS.IceShard.firewallFireRate,
                fwProj: PBS.IceShard.firewallProjectileCount, fwPierce: PBS.IceShard.firewallPierce,
                fwSplash: PBS.IceShard.firewallSplash, fwSlow: PBS.IceShard.firewallSlow, fwSlowDur: PBS.IceShard.firewallSlowDuration,
                fwPower: PBS.IceShard.firewallPowerDraw, wpDmg: PBS.IceShard.weaponDamage, wpRate: PBS.IceShard.weaponFireRate,
                wpProj: PBS.IceShard.weaponProjectileCount, wpSpread: PBS.IceShard.weaponSpread,
                wpPierce: PBS.IceShard.weaponPierce, wpSpeed: PBS.IceShard.weaponProjectileSpeed,
                compile: PBS.IceShard.compileCost, upgrade: PBS.IceShard.baseUpgradeCost, rarity: "rare"),
            "fork_bomb": protoStatsDict(
                fwDmg: PBS.ForkBomb.firewallDamage, fwRng: PBS.ForkBomb.firewallRange, fwRate: PBS.ForkBomb.firewallFireRate,
                fwProj: PBS.ForkBomb.firewallProjectileCount, fwPierce: PBS.ForkBomb.firewallPierce,
                fwSplash: PBS.ForkBomb.firewallSplash, fwSlow: PBS.ForkBomb.firewallSlow, fwSlowDur: PBS.ForkBomb.firewallSlowDuration,
                fwPower: PBS.ForkBomb.firewallPowerDraw, wpDmg: PBS.ForkBomb.weaponDamage, wpRate: PBS.ForkBomb.weaponFireRate,
                wpProj: PBS.ForkBomb.weaponProjectileCount, wpSpread: PBS.ForkBomb.weaponSpread,
                wpPierce: PBS.ForkBomb.weaponPierce, wpSpeed: PBS.ForkBomb.weaponProjectileSpeed,
                compile: PBS.ForkBomb.compileCost, upgrade: PBS.ForkBomb.baseUpgradeCost, rarity: "epic"),
            "root_access": protoStatsDict(
                fwDmg: PBS.RootAccess.firewallDamage, fwRng: PBS.RootAccess.firewallRange, fwRate: PBS.RootAccess.firewallFireRate,
                fwProj: PBS.RootAccess.firewallProjectileCount, fwPierce: PBS.RootAccess.firewallPierce,
                fwSplash: PBS.RootAccess.firewallSplash, fwSlow: PBS.RootAccess.firewallSlow, fwSlowDur: PBS.RootAccess.firewallSlowDuration,
                fwPower: PBS.RootAccess.firewallPowerDraw, wpDmg: PBS.RootAccess.weaponDamage, wpRate: PBS.RootAccess.weaponFireRate,
                wpProj: PBS.RootAccess.weaponProjectileCount, wpSpread: PBS.RootAccess.weaponSpread,
                wpPierce: PBS.RootAccess.weaponPierce, wpSpeed: PBS.RootAccess.weaponProjectileSpeed,
                compile: PBS.RootAccess.compileCost, upgrade: PBS.RootAccess.baseUpgradeCost, rarity: "epic"),
            "overflow": protoStatsDict(
                fwDmg: PBS.Overflow.firewallDamage, fwRng: PBS.Overflow.firewallRange, fwRate: PBS.Overflow.firewallFireRate,
                fwProj: PBS.Overflow.firewallProjectileCount, fwPierce: PBS.Overflow.firewallPierce,
                fwSplash: PBS.Overflow.firewallSplash, fwSlow: PBS.Overflow.firewallSlow, fwSlowDur: PBS.Overflow.firewallSlowDuration,
                fwPower: PBS.Overflow.firewallPowerDraw, wpDmg: PBS.Overflow.weaponDamage, wpRate: PBS.Overflow.weaponFireRate,
                wpProj: PBS.Overflow.weaponProjectileCount, wpSpread: PBS.Overflow.weaponSpread,
                wpPierce: PBS.Overflow.weaponPierce, wpSpeed: PBS.Overflow.weaponProjectileSpeed,
                compile: PBS.Overflow.compileCost, upgrade: PBS.Overflow.baseUpgradeCost, rarity: "legendary"),
            "null_pointer": protoStatsDict(
                fwDmg: PBS.NullPointer.firewallDamage, fwRng: PBS.NullPointer.firewallRange, fwRate: PBS.NullPointer.firewallFireRate,
                fwProj: PBS.NullPointer.firewallProjectileCount, fwPierce: PBS.NullPointer.firewallPierce,
                fwSplash: PBS.NullPointer.firewallSplash, fwSlow: PBS.NullPointer.firewallSlow, fwSlowDur: PBS.NullPointer.firewallSlowDuration,
                fwPower: PBS.NullPointer.firewallPowerDraw, wpDmg: PBS.NullPointer.weaponDamage, wpRate: PBS.NullPointer.weaponFireRate,
                wpProj: PBS.NullPointer.weaponProjectileCount, wpSpread: PBS.NullPointer.weaponSpread,
                wpPierce: PBS.NullPointer.weaponPierce, wpSpeed: PBS.NullPointer.weaponProjectileSpeed,
                compile: PBS.NullPointer.compileCost, upgrade: PBS.NullPointer.baseUpgradeCost, rarity: "legendary")
        ]

        let upgradeRarityDict: [String: Double] = [
            "commonWeight": UpgradeRarity.commonWeight,
            "rareWeight": UpgradeRarity.rareWeight,
            "epicWeight": UpgradeRarity.epicWeight,
            "legendaryWeight": UpgradeRarity.legendaryWeight
        ]

        let playerDict: [String: Any] = [
            "baseHealth": Double(Player.baseHealth),
            "baseSpeed": Double(Player.baseSpeed),
            "pickupRange": Double(Player.pickupRange),
            "baseRegen": Double(Player.baseRegen),
            "maxArmor": Double(Player.maxArmor)
        ]

        let config: [String: Any] = [
            "waves": wavesDict,
            "threatLevel": threatDict,
            "survivalEconomy": economyDict,
            "towers": towersDict,
            "dropRates": dropsDict,
            "powerGrid": powerGridDict,
            "bosses": bossesDict,
            "overclock": overclockDict,
            "hashEconomy": hashEconomyDict,
            "protocolScaling": protocolScalingDict,
            "protocolBaseStats": protocolBaseStatsDict,
            "components": componentsDict,
            "efficiency": efficiencyDict,
            "freeze": freezeDict,
            "sectorUnlock": sectorUnlockDict,
            "sectorHashBonus": sectorHashBonusDict,
            "upgradeRarity": upgradeRarityDict,
            "player": playerDict
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
