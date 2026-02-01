import Foundation

// MARK: - Loot Table System
// Defines what blueprints each boss can drop and at what rates

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

// MARK: - Loot Table Library

struct LootTableLibrary {

    // MARK: - Drop Rate Constants

    /// Base drop rates by rarity
    static let rarityBaseRates: [Rarity: Double] = [
        .common: 0.60,      // 60% base
        .rare: 0.30,        // 30% base
        .epic: 0.08,        // 8% base
        .legendary: 0.02    // 2% base
    ]

    /// Difficulty multipliers for drop rates
    static let difficultyMultipliers: [BossDifficulty: Double] = [
        .easy: 0.5,         // 50% - practice mode
        .normal: 1.0,       // 100% - standard
        .hard: 1.5,         // 150% - rewarding
        .nightmare: 2.5     // 250% - very rewarding
    ]

    /// Nightmare unlocks legendary drops (other difficulties don't)
    static let legendaryMinDifficulty: BossDifficulty = .normal

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
                isFirstKillGuarantee: true  // Guaranteed first drop
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
                isFirstKillGuarantee: true  // Guaranteed first drop
            ),
            LootTableEntry(
                protocolId: "root_access",
                weight: 40,
                isFirstKillGuarantee: false
            ),
            LootTableEntry(
                protocolId: "overflow",
                weight: 100,  // High weight in legendary tier
                isFirstKillGuarantee: false
            )
        ],
        guaranteeOnFirstKill: true
    )

    /// Frost Titan - Ice/Slow theme (future boss)
    /// Drops: Ice Shard (R), Null Pointer (L)
    static let frostTitan = BossLootTable(
        bossId: "frost_titan",
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

    /// Inferno Lord - Fire/Destruction theme (future boss)
    /// Drops: Root Access (E), Overflow (L), Null Pointer (L)
    static let infernoLord = BossLootTable(
        bossId: "inferno_lord",
        entries: [
            LootTableEntry(
                protocolId: "root_access",
                weight: 60,
                isFirstKillGuarantee: true
            ),
            LootTableEntry(
                protocolId: "overflow",
                weight: 50,
                isFirstKillGuarantee: false
            ),
            LootTableEntry(
                protocolId: "null_pointer",
                weight: 50,
                isFirstKillGuarantee: false
            )
        ],
        guaranteeOnFirstKill: true
    )

    /// All loot tables
    static let all: [BossLootTable] = [
        cyberboss,
        voidHarbinger,
        frostTitan,
        infernoLord
    ]

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
        case "frost_titan": return "Frost Titan"
        case "inferno_lord": return "Inferno Lord"
        default: return bossId.capitalized
        }
    }
}
