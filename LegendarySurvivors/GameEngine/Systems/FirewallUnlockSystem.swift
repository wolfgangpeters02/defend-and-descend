import Foundation

// MARK: - Firewall Unlock System
// System: Reboot - Firewalls are unlocked with Data currency
// Data is earned primarily in Active/Debugger mode

struct FirewallUnlockSystem {

    // MARK: - Firewall Definitions

    /// All firewall types with their unlock requirements (Protocol-based unified system)
    static let firewallDefinitions: [FirewallDefinition] = [
        // Default unlocked protocols
        FirewallDefinition(
            weaponId: "kernel_pulse",
            firewallName: "Kernel Pulse",
            description: "Standard single-target protocol. Reliable damage.",
            dataCost: 0,  // Free - default
            isDefault: true,
            tier: 0
        ),
        FirewallDefinition(
            weaponId: "burst_protocol",
            firewallName: "Burst Protocol",
            description: "Shotgun-style spread. Hits multiple targets.",
            dataCost: 0,  // Free - default
            isDefault: true,
            tier: 0
        ),

        // Tier 1 - Early game unlocks (50 Data)
        FirewallDefinition(
            weaponId: "trace_route",
            firewallName: "Trace Route",
            description: "Sniper protocol. Pierces through multiple viruses.",
            dataCost: 50,
            isDefault: false,
            tier: 1
        ),
        FirewallDefinition(
            weaponId: "ice_shard",
            firewallName: "Freeze Protocol",
            description: "Slows viruses, reducing their speed.",
            dataCost: 50,
            isDefault: false,
            tier: 1
        ),

        // Tier 2 - Mid game unlocks (150 Data)
        FirewallDefinition(
            weaponId: "fork_bomb",
            firewallName: "Fork Bomb",
            description: "Multi-shot spread. Fires multiple projectiles.",
            dataCost: 150,
            isDefault: false,
            tier: 2
        ),
        FirewallDefinition(
            weaponId: "root_access",
            firewallName: "Root Access",
            description: "Railgun beam. Massive single-target damage.",
            dataCost: 150,
            isDefault: false,
            tier: 2
        ),

        // Tier 3 - End game unlocks (300 Data)
        FirewallDefinition(
            weaponId: "overflow",
            firewallName: "Overflow",
            description: "Chain lightning. Ricochets to nearby targets.",
            dataCost: 300,
            isDefault: false,
            tier: 3
        ),
        FirewallDefinition(
            weaponId: "null_pointer",
            firewallName: "Null Pointer",
            description: "Execute protocol. Instant kill on low-HP targets.",
            dataCost: 300,
            isDefault: false,
            tier: 3
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

    /// Icon for this firewall type (Protocol-based)
    var icon: String {
        switch weaponId {
        case "kernel_pulse": return "dot.circle"
        case "burst_protocol": return "burst.fill"
        case "trace_route": return "scope"
        case "ice_shard": return "snowflake"
        case "fork_bomb": return "arrow.triangle.branch"
        case "root_access": return "terminal.fill"
        case "overflow": return "bolt.horizontal"
        case "null_pointer": return "exclamationmark.triangle.fill"
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
        case 0: return "gray"      // Default protocols
        case 1: return "blue"      // Rare tier
        case 2: return "purple"    // Epic tier
        case 3: return "orange"    // Legendary tier
        default: return "white"
        }
    }
}
