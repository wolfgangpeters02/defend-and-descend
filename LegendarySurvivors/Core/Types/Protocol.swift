import Foundation
import CoreGraphics

// MARK: - Protocol (Dual-Purpose Card)
// In Motherboard/TD mode: Functions as a Firewall (tower)
// In Debug/Active mode: Functions as a Weapon

struct Protocol: Identifiable, Codable, Equatable {
    let id: String                    // "kernel_pulse", "burst_protocol"
    let name: String                  // "Kernel Pulse", "Burst Protocol"
    let description: String           // Flavor text
    let rarity: Rarity
    var level: Int                    // 1-10, affects all stats
    var isCompiled: Bool              // false = locked blueprint, true = usable

    // Visual
    let iconName: String              // SF Symbol name
    let color: String                 // Hex color for glow/theme

    // Base stats (before level scaling)
    let firewallBaseStats: FirewallStats
    let weaponBaseStats: WeaponStats

    // Costs (Hash currency)
    let compileCost: Int              // Hash cost to unlock
    let baseUpgradeCost: Int          // Base Hash cost to level up

    // MARK: - Computed Properties

    /// Current firewall stats after level scaling
    var firewallStats: FirewallStats {
        let multiplier = Self.levelMultiplier(level: level)
        return FirewallStats(
            damage: firewallBaseStats.damage * multiplier,
            range: firewallBaseStats.range * (1.0 + CGFloat(level - 1) * 0.05),
            fireRate: firewallBaseStats.fireRate * (1.0 + CGFloat(level - 1) * 0.03),
            projectileCount: firewallBaseStats.projectileCount,
            pierce: firewallBaseStats.pierce,
            splash: firewallBaseStats.splash * multiplier,
            slow: firewallBaseStats.slow,
            slowDuration: firewallBaseStats.slowDuration,
            special: firewallBaseStats.special,
            powerDraw: firewallBaseStats.powerDraw  // Power doesn't scale with level
        )
    }

    /// Current weapon stats after level scaling
    var weaponStats: WeaponStats {
        let multiplier = Self.levelMultiplier(level: level)
        return WeaponStats(
            damage: weaponBaseStats.damage * multiplier,
            fireRate: weaponBaseStats.fireRate * (1.0 + CGFloat(level - 1) * 0.03),
            projectileCount: weaponBaseStats.projectileCount,
            spread: weaponBaseStats.spread,
            pierce: weaponBaseStats.pierce,
            projectileSpeed: weaponBaseStats.projectileSpeed,
            special: weaponBaseStats.special
        )
    }

    /// Hash cost to upgrade to next level
    var upgradeCost: Int {
        guard level < 10 else { return 0 }
        return baseUpgradeCost * level
    }

    /// Whether this protocol can be upgraded further
    var canUpgrade: Bool {
        return level < 10 && isCompiled
    }

    /// Whether this protocol is at max level
    var isMaxLevel: Bool {
        return level >= 10
    }

    // MARK: - Level Scaling

    /// Level multiplier: each level = +100% stats (aggressive scaling like WoW/progression games)
    /// Level 1 = 1.0x, Level 5 = 5.0x, Level 10 = 10.0x
    static func levelMultiplier(level: Int) -> CGFloat {
        return CGFloat(level)
    }

    // MARK: - Mutations

    /// Level up the protocol
    mutating func levelUp() {
        guard canUpgrade else { return }
        level += 1
    }

    /// Compile (unlock) the protocol
    mutating func compile() {
        isCompiled = true
    }

    // MARK: - Weapon Conversion (for Active/Debug Mode)

    /// Convert this Protocol to a Weapon for use in Active mode
    func toWeapon() -> Weapon {
        let stats = weaponStats

        // Determine special abilities
        var homing = false
        var chain: Int? = nil
        var splash: CGFloat? = nil

        switch stats.special {
        case .homing:
            homing = true
        case .ricochet:
            chain = 3  // Bounces to 3 targets
        case .explosive:
            splash = 50  // AoE radius
        case .lifesteal, .critical, .none:
            break
        }

        return Weapon(
            type: id,
            level: level,
            damage: stats.damage,
            range: 600,  // Boss arena is 1200x900, need range to reach across
            attackSpeed: stats.fireRate,
            lastAttackTime: 0,
            projectileCount: stats.projectileCount,
            pierce: stats.pierce,
            splash: splash,
            homing: homing,
            slow: nil,
            slowDuration: nil,
            chain: chain,
            color: color,
            particleEffect: nil,
            towerName: name
        )
    }

    // MARK: - Equatable

    static func == (lhs: Protocol, rhs: Protocol) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Firewall Stats (TD Mode)

struct FirewallStats: Codable, Equatable {
    var damage: CGFloat               // Damage per hit
    var range: CGFloat                // Attack range in points
    var fireRate: CGFloat             // Attacks per second
    var projectileCount: Int          // Multi-shot
    var pierce: Int                   // Enemies hit per projectile
    var splash: CGFloat               // AoE radius (0 = none)
    var slow: CGFloat                 // Slow percentage (0-1)
    var slowDuration: TimeInterval    // How long slow lasts
    var special: ProtocolFirewallAbility?     // Unique ability
    var powerDraw: Int                // Power consumption in Watts

    static let zero = FirewallStats(
        damage: 0, range: 0, fireRate: 0, projectileCount: 0,
        pierce: 0, splash: 0, slow: 0, slowDuration: 0, special: nil, powerDraw: 0
    )
}

// MARK: - Weapon Stats (Active Mode)

struct WeaponStats: Codable, Equatable {
    var damage: CGFloat               // Damage per hit
    var fireRate: CGFloat             // Attacks per second
    var projectileCount: Int          // Projectiles per shot
    var spread: CGFloat               // Spread angle for multi-shot (radians)
    var pierce: Int                   // Enemies hit per projectile
    var projectileSpeed: CGFloat      // How fast projectiles travel
    var special: ProtocolWeaponAbility?       // Unique ability

    static let zero = WeaponStats(
        damage: 0, fireRate: 0, projectileCount: 0, spread: 0,
        pierce: 0, projectileSpeed: 0, special: nil
    )
}

// MARK: - Special Abilities

enum ProtocolFirewallAbility: String, Codable, Equatable {
    case homing                       // Projectiles track enemies
    case chain                        // Damage chains to nearby enemies
    case burn                         // DoT effect
    case freeze                       // Stun on hit
    case execute                      // Bonus damage to low HP
}

enum ProtocolWeaponAbility: String, Codable, Equatable {
    case homing
    case explosive                    // AoE on impact
    case ricochet                     // Bounces between enemies
    case lifesteal                    // Heal on hit
    case critical                     // Chance for 2x damage
}

// MARK: - Protocol Library

struct ProtocolLibrary {
    /// All available protocols in the game
    static let all: [Protocol] = [
        kernelPulse,
        burstProtocol,
        traceRoute,
        iceShard,
        forkBomb,
        rootAccess,
        overflow,
        nullPointer
    ]

    /// Get a protocol by ID (type-safe)
    static func get(_ id: ProtocolID) -> Protocol? {
        return all.first { $0.id == id.rawValue }
    }

    /// Get a protocol by string ID (for legacy code/JSON loading)
    static func get(_ id: String) -> Protocol? {
        return all.first { $0.id == id }
    }

    /// Starting protocol (player begins with this compiled)
    static let starterProtocolId = ProtocolID.starter.rawValue

    // MARK: - Protocol Definitions

    /// Kernel Pulse - Basic turret / Auto-pistol
    static let kernelPulse = Protocol(
        id: "kernel_pulse",
        name: "Kernel Pulse",
        description: "Standard system defense. Reliable and efficient.",
        rarity: .common,
        level: 1,
        isCompiled: true,
        iconName: "dot.circle.and.hand.point.up.left.fill",
        color: "#00d4ff",
        firewallBaseStats: FirewallStats(
            damage: 10,
            range: 120,
            fireRate: 1.0,
            projectileCount: 1,
            pierce: 1,
            splash: 0,
            slow: 0,
            slowDuration: 0,
            special: nil,
            powerDraw: 15  // Common: 15W
        ),
        weaponBaseStats: WeaponStats(
            damage: 8,
            fireRate: 2.0,
            projectileCount: 1,
            spread: 0,
            pierce: 1,
            projectileSpeed: 400,
            special: nil
        ),
        compileCost: 0,
        baseUpgradeCost: 50
    )

    /// Burst Protocol - Splash tower / Shotgun
    static let burstProtocol = Protocol(
        id: "burst_protocol",
        name: "Burst Protocol",
        description: "Overwhelm threats with concentrated firepower.",
        rarity: .common,
        level: 1,
        isCompiled: false,
        iconName: "burst.fill",
        color: "#f97316",
        firewallBaseStats: FirewallStats(
            damage: 8,
            range: 100,
            fireRate: 0.8,
            projectileCount: 1,
            pierce: 1,
            splash: 40,
            slow: 0,
            slowDuration: 0,
            special: nil,
            powerDraw: 20  // Common: 20W
        ),
        weaponBaseStats: WeaponStats(
            damage: 6,
            fireRate: 0.8,
            projectileCount: 5,
            spread: 0.5,
            pierce: 1,
            projectileSpeed: 350,
            special: nil
        ),
        compileCost: 100,
        baseUpgradeCost: 50
    )

    /// Trace Route - Sniper tower / Railgun
    static let traceRoute = Protocol(
        id: "trace_route",
        name: "Trace Route",
        description: "Precision strikes from extreme range.",
        rarity: .rare,
        level: 1,
        isCompiled: false,
        iconName: "scope",
        color: "#3b82f6",
        firewallBaseStats: FirewallStats(
            damage: 50,
            range: 250,
            fireRate: 0.4,
            projectileCount: 1,
            pierce: 3,
            splash: 0,
            slow: 0,
            slowDuration: 0,
            special: nil,
            powerDraw: 35  // Rare: 35W
        ),
        weaponBaseStats: WeaponStats(
            damage: 40,
            fireRate: 0.5,
            projectileCount: 1,
            spread: 0,
            pierce: 5,
            projectileSpeed: 800,
            special: nil
        ),
        compileCost: 200,
        baseUpgradeCost: 100
    )

    /// Ice Shard - Slow tower / Freeze gun
    static let iceShard = Protocol(
        id: "ice_shard",
        name: "Ice Shard",
        description: "Cryogenic defense that slows system threats.",
        rarity: .rare,
        level: 1,
        isCompiled: false,
        iconName: "snowflake",
        color: "#22d3ee",
        firewallBaseStats: FirewallStats(
            damage: 5,
            range: 130,
            fireRate: 1.5,
            projectileCount: 1,
            pierce: 1,
            splash: 0,
            slow: 0.5,
            slowDuration: 2.0,
            special: nil,
            powerDraw: 30  // Rare: 30W
        ),
        weaponBaseStats: WeaponStats(
            damage: 4,
            fireRate: 3.0,
            projectileCount: 1,
            spread: 0,
            pierce: 1,
            projectileSpeed: 500,
            special: nil
        ),
        compileCost: 200,
        baseUpgradeCost: 100
    )

    /// Fork Bomb - Multi-target tower / Spread cannon
    static let forkBomb = Protocol(
        id: "fork_bomb",
        name: "Fork Bomb",
        description: "Recursive attack pattern overwhelms multiple targets.",
        rarity: .epic,
        level: 1,
        isCompiled: false,
        iconName: "arrow.triangle.branch",
        color: "#a855f7",
        firewallBaseStats: FirewallStats(
            damage: 12,
            range: 140,
            fireRate: 0.7,
            projectileCount: 3,
            pierce: 1,
            splash: 0,
            slow: 0,
            slowDuration: 0,
            special: nil,
            powerDraw: 60  // Epic: 60W
        ),
        weaponBaseStats: WeaponStats(
            damage: 10,
            fireRate: 1.0,
            projectileCount: 8,
            spread: 0.8,
            pierce: 1,
            projectileSpeed: 380,
            special: nil
        ),
        compileCost: 400,
        baseUpgradeCost: 200
    )

    /// Root Access - High damage single target / Laser beam
    static let rootAccess = Protocol(
        id: "root_access",
        name: "Root Access",
        description: "Elevated privileges grant devastating power.",
        rarity: .epic,
        level: 1,
        isCompiled: false,
        iconName: "terminal.fill",
        color: "#ef4444",
        firewallBaseStats: FirewallStats(
            damage: 80,
            range: 160,
            fireRate: 0.3,
            projectileCount: 1,
            pierce: 1,
            splash: 0,
            slow: 0,
            slowDuration: 0,
            special: nil,
            powerDraw: 75  // Epic: 75W
        ),
        weaponBaseStats: WeaponStats(
            damage: 60,
            fireRate: 0.4,
            projectileCount: 1,
            spread: 0,
            pierce: 1,
            projectileSpeed: 600,
            special: nil
        ),
        compileCost: 400,
        baseUpgradeCost: 200
    )

    /// Overflow - Chain lightning tower / Arc weapon
    static let overflow = Protocol(
        id: "overflow",
        name: "Overflow",
        description: "Buffer overflow causes cascading system failures.",
        rarity: .legendary,
        level: 1,
        isCompiled: false,
        iconName: "bolt.horizontal.fill",
        color: "#f59e0b",
        firewallBaseStats: FirewallStats(
            damage: 15,
            range: 150,
            fireRate: 0.8,
            projectileCount: 1,
            pierce: 1,
            splash: 0,
            slow: 0,
            slowDuration: 0,
            special: .chain,
            powerDraw: 120  // Legendary: 120W
        ),
        weaponBaseStats: WeaponStats(
            damage: 12,
            fireRate: 1.2,
            projectileCount: 1,
            spread: 0,
            pierce: 1,
            projectileSpeed: 450,
            special: .ricochet
        ),
        compileCost: 800,
        baseUpgradeCost: 400
    )

    /// Null Pointer - Execute tower / Instakill crits
    static let nullPointer = Protocol(
        id: "null_pointer",
        name: "Null Pointer",
        description: "Critical exception terminates processes instantly.",
        rarity: .legendary,
        level: 1,
        isCompiled: false,
        iconName: "exclamationmark.triangle.fill",
        color: "#dc2626",
        firewallBaseStats: FirewallStats(
            damage: 25,
            range: 140,
            fireRate: 0.6,
            projectileCount: 1,
            pierce: 1,
            splash: 0,
            slow: 0,
            slowDuration: 0,
            special: .execute,
            powerDraw: 100  // Legendary: 100W
        ),
        weaponBaseStats: WeaponStats(
            damage: 20,
            fireRate: 0.8,
            projectileCount: 1,
            spread: 0,
            pierce: 1,
            projectileSpeed: 500,
            special: .critical
        ),
        compileCost: 800,
        baseUpgradeCost: 400
    )
}
