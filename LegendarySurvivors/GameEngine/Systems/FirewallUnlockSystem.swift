import Foundation

// MARK: - Firewall Unlock System
// System: Reboot - Firewalls are unlocked with Data currency
// Data is earned primarily in Active/Debugger mode

struct FirewallUnlockSystem {

    // MARK: - Firewall Definitions

    /// All firewall types with their unlock requirements
    static let firewallDefinitions: [FirewallDefinition] = [
        // Default unlocked firewalls
        FirewallDefinition(
            weaponId: "bow",
            firewallName: "Signal Firewall",
            description: "Basic single-target firewall. Reliable damage.",
            dataCost: 0,  // Free - default
            isDefault: true,
            tier: 0
        ),
        FirewallDefinition(
            weaponId: "ice_shard",
            firewallName: "Freeze Firewall",
            description: "Slows viruses, reducing their speed.",
            dataCost: 0,  // Free - default
            isDefault: true,
            tier: 0
        ),

        // Tier 1 - Early game unlocks (50 Data)
        FirewallDefinition(
            weaponId: "wand",
            firewallName: "Scan Firewall",
            description: "Magic-based firewall with homing projectiles.",
            dataCost: 50,
            isDefault: false,
            tier: 1
        ),
        FirewallDefinition(
            weaponId: "crossbow",
            firewallName: "Piercing Firewall",
            description: "Projectiles pierce through multiple viruses.",
            dataCost: 50,
            isDefault: false,
            tier: 1
        ),

        // Tier 2 - Mid game unlocks (100 Data)
        FirewallDefinition(
            weaponId: "cannon",
            firewallName: "Burst Firewall",
            description: "Area damage that hits groups of viruses.",
            dataCost: 100,
            isDefault: false,
            tier: 2
        ),
        FirewallDefinition(
            weaponId: "sword",
            firewallName: "Chain Firewall",
            description: "Attacks chain to nearby viruses.",
            dataCost: 100,
            isDefault: false,
            tier: 2
        ),

        // Tier 3 - Late game unlocks (200 Data)
        FirewallDefinition(
            weaponId: "laser",
            firewallName: "Laser Firewall",
            description: "High-speed continuous beam damage.",
            dataCost: 200,
            isDefault: false,
            tier: 3
        ),
        FirewallDefinition(
            weaponId: "staff",
            firewallName: "Overload Firewall",
            description: "Powerful magic with splash damage.",
            dataCost: 200,
            isDefault: false,
            tier: 3
        ),

        // Tier 4 - End game unlocks (500 Data)
        FirewallDefinition(
            weaponId: "flamethrower",
            firewallName: "Purge Firewall",
            description: "Devastating fire damage over time.",
            dataCost: 500,
            isDefault: false,
            tier: 4
        ),
        FirewallDefinition(
            weaponId: "katana",
            firewallName: "Execute Firewall",
            description: "Massive single-target damage. Boss killer.",
            dataCost: 500,
            isDefault: false,
            tier: 4
        )
    ]

    // MARK: - Unlock Methods

    /// Get all firewall definitions
    static func getAllFirewalls() -> [FirewallDefinition] {
        return firewallDefinitions
    }

    /// Get unlockable firewalls (non-default)
    static func getUnlockableFirewalls() -> [FirewallDefinition] {
        return firewallDefinitions.filter { !$0.isDefault }
    }

    /// Get firewalls by tier
    static func getFirewalls(tier: Int) -> [FirewallDefinition] {
        return firewallDefinitions.filter { $0.tier == tier }
    }

    /// Check if a firewall is unlocked for a player
    static func isUnlocked(weaponId: String, unlockedWeapons: [String]) -> Bool {
        // Check if it's a default firewall
        if let def = firewallDefinitions.first(where: { $0.weaponId == weaponId }), def.isDefault {
            return true
        }
        // Check player's unlocked weapons
        return unlockedWeapons.contains(weaponId)
    }

    /// Check if a firewall can be purchased
    static func canPurchase(weaponId: String, data: Int, unlockedWeapons: [String]) -> Bool {
        guard let def = firewallDefinitions.first(where: { $0.weaponId == weaponId }) else {
            return false
        }
        // Already unlocked
        if isUnlocked(weaponId: weaponId, unlockedWeapons: unlockedWeapons) {
            return false
        }
        // Enough Data
        return data >= def.dataCost
    }

    /// Get the cost of a firewall
    static func getCost(weaponId: String) -> Int? {
        return firewallDefinitions.first(where: { $0.weaponId == weaponId })?.dataCost
    }

    /// Get firewall definition by weapon ID
    static func getDefinition(weaponId: String) -> FirewallDefinition? {
        return firewallDefinitions.first(where: { $0.weaponId == weaponId })
    }

    /// Purchase a firewall unlock
    /// Returns: true if successful, false if not enough Data or already unlocked
    static func purchaseFirewall(weaponId: String, profile: inout PlayerProfile) -> Bool {
        guard let def = firewallDefinitions.first(where: { $0.weaponId == weaponId }) else {
            return false
        }

        // Check if already unlocked
        if profile.unlocks.weapons.contains(weaponId) {
            return false
        }

        // Check if enough Data
        guard profile.data >= def.dataCost else {
            return false
        }

        // Deduct Data and add weapon to unlocks
        profile.data -= def.dataCost
        profile.unlocks.weapons.append(weaponId)

        // Also add to weapon levels at level 1
        if profile.weaponLevels[weaponId] == nil {
            profile.weaponLevels[weaponId] = 1
        }

        return true
    }
}

// MARK: - Firewall Definition

struct FirewallDefinition: Identifiable {
    var id: String { weaponId }

    let weaponId: String       // Maps to WeaponConfig.id
    let firewallName: String   // Display name (e.g., "Burst Firewall")
    let description: String    // Short description
    let dataCost: Int          // Cost in Data currency
    let isDefault: Bool        // true if unlocked by default
    let tier: Int              // Unlock tier (0=default, 1-4=purchasable)

    /// Icon for this firewall type
    var icon: String {
        switch weaponId {
        case "bow", "crossbow": return "antenna.radiowaves.left.and.right"
        case "wand", "staff": return "wand.and.rays"
        case "cannon": return "burst.fill"
        case "ice_shard": return "snowflake"
        case "laser": return "rays"
        case "flamethrower": return "flame.fill"
        case "sword", "katana": return "bolt.fill"
        default: return "shield.fill"
        }
    }

    /// Tier display name
    var tierName: String {
        switch tier {
        case 0: return "DEFAULT"
        case 1: return "TIER I"
        case 2: return "TIER II"
        case 3: return "TIER III"
        case 4: return "TIER IV"
        default: return "TIER \(tier)"
        }
    }

    /// Color for tier
    var tierColor: String {
        switch tier {
        case 0: return "gray"
        case 1: return "blue"
        case 2: return "purple"
        case 3: return "orange"
        case 4: return "red"
        default: return "white"
        }
    }
}
