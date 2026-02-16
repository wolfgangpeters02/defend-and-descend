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
            range: firewallBaseStats.range * (1.0 + CGFloat(level - 1) * BalanceConfig.ProtocolScaling.rangePerLevel),
            fireRate: firewallBaseStats.fireRate * (1.0 + CGFloat(level - 1) * BalanceConfig.ProtocolScaling.fireRatePerLevel),
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
            fireRate: weaponBaseStats.fireRate * (1.0 + CGFloat(level - 1) * BalanceConfig.ProtocolScaling.fireRatePerLevel),
            projectileCount: weaponBaseStats.projectileCount,
            spread: weaponBaseStats.spread,
            pierce: weaponBaseStats.pierce,
            projectileSpeed: weaponBaseStats.projectileSpeed,
            special: weaponBaseStats.special
        )
    }

    /// Hash cost to upgrade to next level
    /// Uses centralized exponential formula from BalanceConfig
    var upgradeCost: Int {
        return BalanceConfig.exponentialUpgradeCost(baseCost: baseUpgradeCost, currentLevel: level)
    }

    /// Whether this protocol can be upgraded further
    var canUpgrade: Bool {
        return level < BalanceConfig.maxUpgradeLevel && isCompiled
    }

    /// Whether this protocol is at max level
    var isMaxLevel: Bool {
        return level >= BalanceConfig.maxUpgradeLevel
    }

    // MARK: - Level Scaling

    /// Level multiplier for damage/stats
    /// Uses centralized formula from BalanceConfig
    static func levelMultiplier(level: Int) -> CGFloat {
        return BalanceConfig.levelStatMultiplier(level: level)
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
            chain = BalanceConfig.ProtocolScaling.ricochetChainTargets
        case .explosive:
            splash = BalanceConfig.ProtocolScaling.explosiveSplashRadius
        case .lifesteal, .critical, .none:
            break
        }

        return Weapon(
            type: id,
            level: level,
            damage: stats.damage,
            range: BalanceConfig.ProtocolScaling.bossArenaWeaponRange,
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
            damage: BalanceConfig.ProtocolBaseStats.KernelPulse.firewallDamage,
            range: BalanceConfig.ProtocolBaseStats.KernelPulse.firewallRange,
            fireRate: BalanceConfig.ProtocolBaseStats.KernelPulse.firewallFireRate,
            projectileCount: BalanceConfig.ProtocolBaseStats.KernelPulse.firewallProjectileCount,
            pierce: BalanceConfig.ProtocolBaseStats.KernelPulse.firewallPierce,
            splash: BalanceConfig.ProtocolBaseStats.KernelPulse.firewallSplash,
            slow: BalanceConfig.ProtocolBaseStats.KernelPulse.firewallSlow,
            slowDuration: BalanceConfig.ProtocolBaseStats.KernelPulse.firewallSlowDuration,
            special: nil,
            powerDraw: BalanceConfig.ProtocolBaseStats.KernelPulse.firewallPowerDraw
        ),
        weaponBaseStats: WeaponStats(
            damage: BalanceConfig.ProtocolBaseStats.KernelPulse.weaponDamage,
            fireRate: BalanceConfig.ProtocolBaseStats.KernelPulse.weaponFireRate,
            projectileCount: BalanceConfig.ProtocolBaseStats.KernelPulse.weaponProjectileCount,
            spread: BalanceConfig.ProtocolBaseStats.KernelPulse.weaponSpread,
            pierce: BalanceConfig.ProtocolBaseStats.KernelPulse.weaponPierce,
            projectileSpeed: BalanceConfig.ProtocolBaseStats.KernelPulse.weaponProjectileSpeed,
            special: nil
        ),
        compileCost: BalanceConfig.ProtocolBaseStats.KernelPulse.compileCost,
        baseUpgradeCost: BalanceConfig.ProtocolBaseStats.KernelPulse.baseUpgradeCost
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
            damage: BalanceConfig.ProtocolBaseStats.BurstProtocol.firewallDamage,
            range: BalanceConfig.ProtocolBaseStats.BurstProtocol.firewallRange,
            fireRate: BalanceConfig.ProtocolBaseStats.BurstProtocol.firewallFireRate,
            projectileCount: BalanceConfig.ProtocolBaseStats.BurstProtocol.firewallProjectileCount,
            pierce: BalanceConfig.ProtocolBaseStats.BurstProtocol.firewallPierce,
            splash: BalanceConfig.ProtocolBaseStats.BurstProtocol.firewallSplash,
            slow: BalanceConfig.ProtocolBaseStats.BurstProtocol.firewallSlow,
            slowDuration: BalanceConfig.ProtocolBaseStats.BurstProtocol.firewallSlowDuration,
            special: nil,
            powerDraw: BalanceConfig.ProtocolBaseStats.BurstProtocol.firewallPowerDraw
        ),
        weaponBaseStats: WeaponStats(
            damage: BalanceConfig.ProtocolBaseStats.BurstProtocol.weaponDamage,
            fireRate: BalanceConfig.ProtocolBaseStats.BurstProtocol.weaponFireRate,
            projectileCount: BalanceConfig.ProtocolBaseStats.BurstProtocol.weaponProjectileCount,
            spread: BalanceConfig.ProtocolBaseStats.BurstProtocol.weaponSpread,
            pierce: BalanceConfig.ProtocolBaseStats.BurstProtocol.weaponPierce,
            projectileSpeed: BalanceConfig.ProtocolBaseStats.BurstProtocol.weaponProjectileSpeed,
            special: nil
        ),
        compileCost: BalanceConfig.ProtocolBaseStats.BurstProtocol.compileCost,
        baseUpgradeCost: BalanceConfig.ProtocolBaseStats.BurstProtocol.baseUpgradeCost
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
            damage: BalanceConfig.ProtocolBaseStats.TraceRoute.firewallDamage,
            range: BalanceConfig.ProtocolBaseStats.TraceRoute.firewallRange,
            fireRate: BalanceConfig.ProtocolBaseStats.TraceRoute.firewallFireRate,
            projectileCount: BalanceConfig.ProtocolBaseStats.TraceRoute.firewallProjectileCount,
            pierce: BalanceConfig.ProtocolBaseStats.TraceRoute.firewallPierce,
            splash: BalanceConfig.ProtocolBaseStats.TraceRoute.firewallSplash,
            slow: BalanceConfig.ProtocolBaseStats.TraceRoute.firewallSlow,
            slowDuration: BalanceConfig.ProtocolBaseStats.TraceRoute.firewallSlowDuration,
            special: nil,
            powerDraw: BalanceConfig.ProtocolBaseStats.TraceRoute.firewallPowerDraw
        ),
        weaponBaseStats: WeaponStats(
            damage: BalanceConfig.ProtocolBaseStats.TraceRoute.weaponDamage,
            fireRate: BalanceConfig.ProtocolBaseStats.TraceRoute.weaponFireRate,
            projectileCount: BalanceConfig.ProtocolBaseStats.TraceRoute.weaponProjectileCount,
            spread: BalanceConfig.ProtocolBaseStats.TraceRoute.weaponSpread,
            pierce: BalanceConfig.ProtocolBaseStats.TraceRoute.weaponPierce,
            projectileSpeed: BalanceConfig.ProtocolBaseStats.TraceRoute.weaponProjectileSpeed,
            special: nil
        ),
        compileCost: BalanceConfig.ProtocolBaseStats.TraceRoute.compileCost,
        baseUpgradeCost: BalanceConfig.ProtocolBaseStats.TraceRoute.baseUpgradeCost
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
            damage: BalanceConfig.ProtocolBaseStats.IceShard.firewallDamage,
            range: BalanceConfig.ProtocolBaseStats.IceShard.firewallRange,
            fireRate: BalanceConfig.ProtocolBaseStats.IceShard.firewallFireRate,
            projectileCount: BalanceConfig.ProtocolBaseStats.IceShard.firewallProjectileCount,
            pierce: BalanceConfig.ProtocolBaseStats.IceShard.firewallPierce,
            splash: BalanceConfig.ProtocolBaseStats.IceShard.firewallSplash,
            slow: BalanceConfig.ProtocolBaseStats.IceShard.firewallSlow,
            slowDuration: BalanceConfig.ProtocolBaseStats.IceShard.firewallSlowDuration,
            special: nil,
            powerDraw: BalanceConfig.ProtocolBaseStats.IceShard.firewallPowerDraw
        ),
        weaponBaseStats: WeaponStats(
            damage: BalanceConfig.ProtocolBaseStats.IceShard.weaponDamage,
            fireRate: BalanceConfig.ProtocolBaseStats.IceShard.weaponFireRate,
            projectileCount: BalanceConfig.ProtocolBaseStats.IceShard.weaponProjectileCount,
            spread: BalanceConfig.ProtocolBaseStats.IceShard.weaponSpread,
            pierce: BalanceConfig.ProtocolBaseStats.IceShard.weaponPierce,
            projectileSpeed: BalanceConfig.ProtocolBaseStats.IceShard.weaponProjectileSpeed,
            special: nil
        ),
        compileCost: BalanceConfig.ProtocolBaseStats.IceShard.compileCost,
        baseUpgradeCost: BalanceConfig.ProtocolBaseStats.IceShard.baseUpgradeCost
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
            damage: BalanceConfig.ProtocolBaseStats.ForkBomb.firewallDamage,
            range: BalanceConfig.ProtocolBaseStats.ForkBomb.firewallRange,
            fireRate: BalanceConfig.ProtocolBaseStats.ForkBomb.firewallFireRate,
            projectileCount: BalanceConfig.ProtocolBaseStats.ForkBomb.firewallProjectileCount,
            pierce: BalanceConfig.ProtocolBaseStats.ForkBomb.firewallPierce,
            splash: BalanceConfig.ProtocolBaseStats.ForkBomb.firewallSplash,
            slow: BalanceConfig.ProtocolBaseStats.ForkBomb.firewallSlow,
            slowDuration: BalanceConfig.ProtocolBaseStats.ForkBomb.firewallSlowDuration,
            special: nil,
            powerDraw: BalanceConfig.ProtocolBaseStats.ForkBomb.firewallPowerDraw
        ),
        weaponBaseStats: WeaponStats(
            damage: BalanceConfig.ProtocolBaseStats.ForkBomb.weaponDamage,
            fireRate: BalanceConfig.ProtocolBaseStats.ForkBomb.weaponFireRate,
            projectileCount: BalanceConfig.ProtocolBaseStats.ForkBomb.weaponProjectileCount,
            spread: BalanceConfig.ProtocolBaseStats.ForkBomb.weaponSpread,
            pierce: BalanceConfig.ProtocolBaseStats.ForkBomb.weaponPierce,
            projectileSpeed: BalanceConfig.ProtocolBaseStats.ForkBomb.weaponProjectileSpeed,
            special: nil
        ),
        compileCost: BalanceConfig.ProtocolBaseStats.ForkBomb.compileCost,
        baseUpgradeCost: BalanceConfig.ProtocolBaseStats.ForkBomb.baseUpgradeCost
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
            damage: BalanceConfig.ProtocolBaseStats.RootAccess.firewallDamage,
            range: BalanceConfig.ProtocolBaseStats.RootAccess.firewallRange,
            fireRate: BalanceConfig.ProtocolBaseStats.RootAccess.firewallFireRate,
            projectileCount: BalanceConfig.ProtocolBaseStats.RootAccess.firewallProjectileCount,
            pierce: BalanceConfig.ProtocolBaseStats.RootAccess.firewallPierce,
            splash: BalanceConfig.ProtocolBaseStats.RootAccess.firewallSplash,
            slow: BalanceConfig.ProtocolBaseStats.RootAccess.firewallSlow,
            slowDuration: BalanceConfig.ProtocolBaseStats.RootAccess.firewallSlowDuration,
            special: nil,
            powerDraw: BalanceConfig.ProtocolBaseStats.RootAccess.firewallPowerDraw
        ),
        weaponBaseStats: WeaponStats(
            damage: BalanceConfig.ProtocolBaseStats.RootAccess.weaponDamage,
            fireRate: BalanceConfig.ProtocolBaseStats.RootAccess.weaponFireRate,
            projectileCount: BalanceConfig.ProtocolBaseStats.RootAccess.weaponProjectileCount,
            spread: BalanceConfig.ProtocolBaseStats.RootAccess.weaponSpread,
            pierce: BalanceConfig.ProtocolBaseStats.RootAccess.weaponPierce,
            projectileSpeed: BalanceConfig.ProtocolBaseStats.RootAccess.weaponProjectileSpeed,
            special: nil
        ),
        compileCost: BalanceConfig.ProtocolBaseStats.RootAccess.compileCost,
        baseUpgradeCost: BalanceConfig.ProtocolBaseStats.RootAccess.baseUpgradeCost
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
            damage: BalanceConfig.ProtocolBaseStats.Overflow.firewallDamage,
            range: BalanceConfig.ProtocolBaseStats.Overflow.firewallRange,
            fireRate: BalanceConfig.ProtocolBaseStats.Overflow.firewallFireRate,
            projectileCount: BalanceConfig.ProtocolBaseStats.Overflow.firewallProjectileCount,
            pierce: BalanceConfig.ProtocolBaseStats.Overflow.firewallPierce,
            splash: BalanceConfig.ProtocolBaseStats.Overflow.firewallSplash,
            slow: BalanceConfig.ProtocolBaseStats.Overflow.firewallSlow,
            slowDuration: BalanceConfig.ProtocolBaseStats.Overflow.firewallSlowDuration,
            special: .chain,
            powerDraw: BalanceConfig.ProtocolBaseStats.Overflow.firewallPowerDraw
        ),
        weaponBaseStats: WeaponStats(
            damage: BalanceConfig.ProtocolBaseStats.Overflow.weaponDamage,
            fireRate: BalanceConfig.ProtocolBaseStats.Overflow.weaponFireRate,
            projectileCount: BalanceConfig.ProtocolBaseStats.Overflow.weaponProjectileCount,
            spread: BalanceConfig.ProtocolBaseStats.Overflow.weaponSpread,
            pierce: BalanceConfig.ProtocolBaseStats.Overflow.weaponPierce,
            projectileSpeed: BalanceConfig.ProtocolBaseStats.Overflow.weaponProjectileSpeed,
            special: .ricochet
        ),
        compileCost: BalanceConfig.ProtocolBaseStats.Overflow.compileCost,
        baseUpgradeCost: BalanceConfig.ProtocolBaseStats.Overflow.baseUpgradeCost
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
            damage: BalanceConfig.ProtocolBaseStats.NullPointer.firewallDamage,
            range: BalanceConfig.ProtocolBaseStats.NullPointer.firewallRange,
            fireRate: BalanceConfig.ProtocolBaseStats.NullPointer.firewallFireRate,
            projectileCount: BalanceConfig.ProtocolBaseStats.NullPointer.firewallProjectileCount,
            pierce: BalanceConfig.ProtocolBaseStats.NullPointer.firewallPierce,
            splash: BalanceConfig.ProtocolBaseStats.NullPointer.firewallSplash,
            slow: BalanceConfig.ProtocolBaseStats.NullPointer.firewallSlow,
            slowDuration: BalanceConfig.ProtocolBaseStats.NullPointer.firewallSlowDuration,
            special: .execute,
            powerDraw: BalanceConfig.ProtocolBaseStats.NullPointer.firewallPowerDraw
        ),
        weaponBaseStats: WeaponStats(
            damage: BalanceConfig.ProtocolBaseStats.NullPointer.weaponDamage,
            fireRate: BalanceConfig.ProtocolBaseStats.NullPointer.weaponFireRate,
            projectileCount: BalanceConfig.ProtocolBaseStats.NullPointer.weaponProjectileCount,
            spread: BalanceConfig.ProtocolBaseStats.NullPointer.weaponSpread,
            pierce: BalanceConfig.ProtocolBaseStats.NullPointer.weaponPierce,
            projectileSpeed: BalanceConfig.ProtocolBaseStats.NullPointer.weaponProjectileSpeed,
            special: .critical
        ),
        compileCost: BalanceConfig.ProtocolBaseStats.NullPointer.compileCost,
        baseUpgradeCost: BalanceConfig.ProtocolBaseStats.NullPointer.baseUpgradeCost
    )
}
