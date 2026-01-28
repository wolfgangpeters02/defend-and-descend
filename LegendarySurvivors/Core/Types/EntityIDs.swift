import Foundation

// MARK: - Type-Safe Entity IDs
// These enums provide compile-time safety for entity lookups.
// String raw values match JSON config keys exactly.

// MARK: - Weapon IDs (Legacy System)

/// Legacy weapon types from GameConfig.json
/// Used in the older survivor mode
enum WeaponID: String, CaseIterable, Codable {
    case bow
    case cannon
    case iceShard = "ice_shard"
    case laser
    case staff
    case bomb
    case lightning
    case flamethrower
    case excalibur
}

// MARK: - Protocol IDs (New System)

/// Protocol IDs for the unified Protocol system
/// Used in both TD (as Firewalls) and Active (as Weapons) modes
enum ProtocolID: String, CaseIterable, Codable {
    case kernelPulse = "kernel_pulse"
    case burstProtocol = "burst_protocol"
    case traceRoute = "trace_route"
    case iceShard = "ice_shard"
    case forkBomb = "fork_bomb"
    case rootAccess = "root_access"
    case overflow
    case nullPointer = "null_pointer"

    /// The starter protocol all players begin with
    static let starter: ProtocolID = .kernelPulse
}

// MARK: - Powerup IDs

/// Powerup/class types from GameConfig.json
enum PowerupID: String, CaseIterable, Codable {
    case tank
    case berserker
    case sniper
    case gunslinger
    case giant
    case assassin
    case warrior
    case mage
    case godmode
}

// MARK: - Arena IDs

/// Arena/map types for survivor mode from GameConfig.json
enum ArenaID: String, CaseIterable, Codable {
    case grasslands
    case volcano
    case iceCave = "ice_cave"
    case castle
    case space
    case temple
    case voidrealm

    /// The starter arena for new players
    static let starter: ArenaID = .grasslands
}

// MARK: - Enemy IDs

/// Enemy types from GameConfig.json
enum EnemyID: String, CaseIterable, Codable {
    case basic
    case fast
    case tank
    case boss
    case cyberboss
    case voidharbinger
    case voidminion

    /// Whether this enemy type is a boss
    var isBoss: Bool {
        switch self {
        case .boss, .cyberboss, .voidharbinger:
            return true
        default:
            return false
        }
    }
}

// MARK: - TD Map IDs

/// Tower Defense map IDs from TDConfig.json
enum TDMapID: String, CaseIterable, Codable {
    case grasslands
    case volcano
    case iceCave = "ice_cave"
    case castle
    case space
    case temple
    case motherboard

    /// The starter map for TD mode
    static let starter: TDMapID = .motherboard

    /// Whether this map uses the large mega-board layout
    var isMegaBoard: Bool {
        return self == .motherboard
    }
}

// MARK: - Sector IDs (Mega-Board)

/// Motherboard sector IDs for the mega-board system
enum SectorID: String, CaseIterable, Codable {
    // Core sectors
    case cpu
    case ram
    case gpu
    case storage
    case io

    // Expansion sectors
    case network
    case power
    case cache
    case expansion     // PCIe expansion bay

    /// The starting sector (always unlocked)
    static let starter: SectorID = .ram

    /// Display name for UI
    var displayName: String {
        switch self {
        case .cpu: return "CPU"
        case .ram: return "RAM"
        case .gpu: return "GPU"
        case .storage: return "Storage"
        case .io: return "I/O Port"
        case .network: return "Network"
        case .power: return "Power"
        case .cache: return "Cache"
        case .expansion: return "Expansion"
        }
    }
}

// MARK: - Upgrade IDs

/// Global upgrade types that persist across runs
enum GlobalUpgradeID: String, CaseIterable, Codable {
    case hashPerSecond
    case startingHash
    case maxTowers
    case towerDamage
    case towerRange
    case efficiencyRegen
}

// MARK: - Core Upgrade IDs

/// Upgrades for the core/guardian in TD mode
enum CoreUpgradeID: String, CaseIterable, Codable {
    case health
    case damage
    case range
    case attackSpeed
    case armor

    var displayName: String {
        switch self {
        case .health: return "Health"
        case .damage: return "Damage"
        case .range: return "Range"
        case .attackSpeed: return "Attack Speed"
        case .armor: return "Armor"
        }
    }
}

// MARK: - Currency IDs

/// Currency types in the game (System: Reboot)
/// Note: Power (⚡) is NOT a currency - it's a capacity/ceiling managed by PSU level
enum CurrencyID: String, CaseIterable, Codable {
    case hash     // Hash (Ħ) - Primary soft currency, earned passively in Motherboard mode
    case data     // Data (◈) - Research currency, earned in Debug/Active mode

    var displayName: String {
        switch self {
        case .hash: return "Hash"
        case .data: return "Data"
        }
    }

    var symbol: String {
        switch self {
        case .hash: return "Ħ"
        case .data: return "◈"
        }
    }

    var icon: String {
        switch self {
        case .hash: return "number.circle.fill"
        case .data: return "memorychip"
        }
    }
}

// MARK: - Upgrade Target Types

/// Target types for stat/weapon/ability upgrades
enum UpgradeTargetType: String, Codable, CaseIterable {
    // Stat upgrades
    case damage
    case maxHealth
    case speed
    case regen
    case armor
    case pickupRange

    // Weapon upgrades
    case attackSpeed
    case range
    case projectileCount
    case pierce
    case splash
    case homing

    // Ability upgrades
    case lifesteal
    case revive
    case thorns
    case explosionOnKill
    case orbitalStrike
    case timeFreeze
    case allStats
}

// MARK: - Hazard Damage Types

/// Damage types for arena hazards
enum HazardDamageType: String, Codable, CaseIterable {
    case fire
    case ice
    case cold       // Alias for ice effects
    case poison
    case physical
    case void
    case laser
    case lava
    case corruption
    case necrotic
    case generic

    /// Alternative initializer for backwards compatibility
    init(from string: String) {
        self = HazardDamageType(rawValue: string) ?? .generic
    }
}

// MARK: - Effect Zone Types

/// Types of effect zones in arenas
enum EffectZoneType: String, Codable, CaseIterable {
    case ice
    case speedBoost
    case healing
    case damage
    case slow
    case powerZone = "power_zone"

    /// Alternative initializer for backwards compatibility
    init(from string: String) {
        self = EffectZoneType(rawValue: string) ?? .damage
    }
}

// MARK: - Particle Types

/// Types of visual particles
enum ParticleType: String, Codable, CaseIterable {
    case explosion
    case hit
    case data  // Changed from coin - Data pickups
    case blood
    case muzzle
    case impact
    case trail
    case legendary

    /// Alternative initializer for backwards compatibility
    init(from string: String) {
        self = ParticleType(rawValue: string) ?? .hit
    }
}

// MARK: - Pickup Types

/// Types of collectible pickups
enum PickupType: String, Codable, CaseIterable {
    case data  // Changed from coin - Data currency pickups
    case health
    case xp
    case powerup

    /// Alternative initializer for backwards compatibility
    init(from string: String) {
        self = PickupType(rawValue: string) ?? .data
    }
}

// MARK: - Validation Extension

#if DEBUG
extension EntityIDs {
    /// Validates that all enum cases match the JSON config keys
    /// Call this during app launch in debug builds
    static func validateAgainstConfig() {
        // This would compare enum cases against GameConfigLoader
        // For now, this is a placeholder for future validation
        print("[EntityIDs] Validation not yet implemented")
    }
}

/// Namespace for validation
enum EntityIDs {}
#endif
