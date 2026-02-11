import Foundation
import CoreGraphics

// MARK: - Boss State Types
// Extracted from Boss AI files so both AI systems AND rendering can reference these
// without creating an implicit dependency between layers.

// MARK: - Cyberboss State

extension CyberbossAI {

    struct CyberbossState {
        var phase: Int = 1
        var mode: CyberbossMode = .melee
        var modeTimer: Double = 0
        var modeSwitchInterval: Double = BalanceConfig.Cyberboss.modeSwitchInterval

        var lastMinionSpawnTime: Double = 0
        var minionSpawnInterval: Double = BalanceConfig.Cyberboss.minionSpawnIntervalPhase1

        var lastPuddleSpawnTime: Double = 0
        var puddleSpawnInterval: Double = BalanceConfig.Cyberboss.puddleSpawnIntervalPhase3

        var lastRangedAttackTime: Double = 0
        var rangedAttackCooldown: Double = BalanceConfig.Cyberboss.rangedAttackCooldown

        var laserBeams: [LaserBeam] = []
        var laserRotationSpeed: CGFloat = BalanceConfig.Cyberboss.laserRotationSpeed

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
        var lifetime: Double = 0           // How long this beam has existed
        let warningDuration: Double = BalanceConfig.Cyberboss.puddleWarningDuration  // Warning before active
        var isActive: Bool { lifetime >= warningDuration }
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
}

// MARK: - Void Harbinger State

extension VoidHarbingerAI {

    struct VoidHarbingerState {
        var phase: Int = 1

        // Phase 1
        var voidZones: [VoidZone] = []
        var lastVoidZoneTime: Double = 0
        var voidZoneInterval: Double = BalanceConfig.VoidHarbinger.voidZoneIntervalPhase1

        var lastVolleyTime: Double = 0
        var volleyInterval: Double = BalanceConfig.VoidHarbinger.volleyInterval

        var lastMinionSpawnTime: Double = 0
        var minionSpawnInterval: Double = BalanceConfig.VoidHarbinger.minionSpawnInterval

        // Phase 2 (Pylon phase)
        var pylons: [Pylon] = []
        var pylonsDestroyed: Int = 0
        var isInvulnerable: Bool = false

        // Phase 3
        var voidRifts: [VoidRift] = []
        var gravityWells: [GravityWell] = []
        var lastMeteorTime: Double = 0
        var meteorInterval: Double = BalanceConfig.VoidHarbinger.meteorInterval

        var lastEliteMinionTime: Double = 0
        var eliteMinionInterval: Double = BalanceConfig.VoidHarbinger.eliteMinionInterval

        // Phase 4 (Enrage)
        var lastTeleportTime: Double = 0
        var teleportInterval: Double = BalanceConfig.VoidHarbinger.teleportInterval

        var arenaRadius: CGFloat = BalanceConfig.VoidHarbinger.arenaStartRadius
        var minArenaRadius: CGFloat = BalanceConfig.VoidHarbinger.arenaMinRadius
        var arenaShrinkRate: CGFloat = BalanceConfig.VoidHarbinger.arenaShrinkRate
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
}

// MARK: - Overclocker State

extension OverclockerAI {

    struct OverclockerState {
        var phase: Int = 1
        var arenaCenter: CGPoint = .zero
        var arenaRect: CGRect = .zero

        // Phase 1 - Turbine (Wind + Rotating Blades)
        var bladeAngle: CGFloat = 0

        // Phase 2 - Heat Sink (4x4 Lava Grid)
        var tileStates: [TileState] = Array(repeating: .normal, count: 16)
        var lastTileChangeTime: Double = 0
        var bossTargetTileIndex: Int? = nil

        // Phase 3 - Overheat (Chase + Steam Trail)
        var steamTrail: [SteamSegment] = []
        var lastSteamDropTime: Double = 0

        // Phase 4 - Suction (Vacuum + Shredder)
        var isSuctionActive: Bool = false
        var suctionTimer: Double = 0

        // Shared
        var lastContactDamageTime: Double = 0
    }

    enum TileState: Int {
        case normal = 0   // Dark/Inactive
        case warning = 1  // Orange/Flashing (0 damage)
        case lava = 2     // Red/Glowing (Dealing damage)
        case safe = 3     // Blue/Cool (Safe zone)
    }

    struct SteamSegment {
        let id: String
        var x: CGFloat
        var y: CGFloat
        var createdAt: Double
    }
}

// MARK: - Trojan Wyrm State

extension TrojanWyrmAI {

    enum Phase4SubState {
        case circling
        case aiming
        case lunging
        case recovering
    }

    struct Segment {
        var x: CGFloat
        var y: CGFloat

        init(x: CGFloat, y: CGFloat) {
            self.x = x
            self.y = y
        }

        var cgPoint: CGPoint {
            CGPoint(x: x, y: y)
        }
    }

    struct SubWorm {
        let id: Int
        var head: Segment
        var body: [Segment]
        var angle: CGFloat
    }

    struct TrojanWyrmState {
        var phase: Int = 1
        var arenaCenter: CGPoint = .zero
        var arenaRect: CGRect = .zero

        // Phase 1 - Packet Loss
        // Head position is stored in the Enemy entity (boss.x, boss.y)
        var segments: [Segment] = [] // The 24 body segments
        var headAngle: CGFloat = 0
        var turnTimer: Double = 0

        // Phase 2 - Firewall
        var wallY: CGFloat = 0
        var wallDirection: CGFloat = -1 // -1 = down (towards player), 1 = up
        var ghostSegmentIndex: Int = -1
        var lastTurretFireTime: Double = 0
        var wallInitialized: Bool = false

        // Phase 3 - Data Corruption
        var subWorms: [SubWorm] = []
        var subWormsInitialized: Bool = false

        // Phase 4 - Format C:
        var phase4Initialized: Bool = false
        var phase4SubState: Phase4SubState = .circling
        var ringAngle: CGFloat = 0
        var ringRadius: CGFloat = 250

        // Lunge Data
        var aimTimer: Double = 0
        var lungeTimer: Double = 0
        var lungeHeadX: CGFloat = 0
        var lungeHeadY: CGFloat = 0
        var lungeTargetX: CGFloat = 0
        var lungeTargetY: CGFloat = 0
        var lungeVelocityX: CGFloat = 0
        var lungeVelocityY: CGFloat = 0
        var recoverTimer: Double = 0

        // Shared
        var lastContactDamageTime: Double = 0
        var originalBossSize: CGFloat?
    }
}
