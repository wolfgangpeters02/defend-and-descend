import Foundation

// MARK: - Blueprint Drop System
// Handles RNG-based blueprint drops from bosses

final class BlueprintDropSystem {
    static let shared = BlueprintDropSystem()
    private init() {}

    // MARK: - Drop Result

    /// Result of a blueprint drop calculation
    struct DropResult {
        let protocolId: String?     // nil = no drop
        let isFirstKill: Bool       // Was this their first kill of this boss?
        let wasGuaranteed: Bool     // Was this a guaranteed drop (first kill / pity)?
        let rollValue: Double?      // The RNG roll for debugging

        /// Whether a blueprint was dropped
        var didDrop: Bool { protocolId != nil }

        /// Empty result (no drop)
        static let noDrop = DropResult(
            protocolId: nil,
            isFirstKill: false,
            wasGuaranteed: false,
            rollValue: nil
        )
    }

    // MARK: - Drop Calculation

    /// Calculate blueprint drop for a boss defeat
    /// - Parameters:
    ///   - bossId: The boss that was defeated
    ///   - difficulty: The difficulty the boss was defeated on
    ///   - profile: The player's current profile
    /// - Returns: DropResult containing the dropped protocol (if any)
    func calculateDrop(
        bossId: String,
        difficulty: BossDifficulty,
        profile: PlayerProfile
    ) -> DropResult {
        // Get loot table for this boss
        guard let lootTable = LootTableLibrary.lootTable(for: bossId) else {
            return .noDrop
        }

        let killCount = profile.bossKillCount(bossId)
        let isFirstKill = killCount == 0

        // Get set of already owned blueprints + compiled protocols
        let ownedSet = Set(profile.protocolBlueprints + profile.compiledProtocols)

        // Filter to unowned blueprints only
        let availableEntries = lootTable.entries.filter { !ownedSet.contains($0.protocolId) }

        // If player owns all possible drops, no drop
        guard !availableEntries.isEmpty else {
            return DropResult(
                protocolId: nil,
                isFirstKill: isFirstKill,
                wasGuaranteed: false,
                rollValue: nil
            )
        }

        // FIRST KILL: Guaranteed drop
        if isFirstKill && lootTable.guaranteeOnFirstKill {
            let guaranteedEntry = availableEntries.first { $0.isFirstKillGuarantee }
                ?? availableEntries.max(by: { $0.weight < $1.weight })

            return DropResult(
                protocolId: guaranteedEntry?.protocolId,
                isFirstKill: true,
                wasGuaranteed: true,
                rollValue: 1.0
            )
        }

        // PITY SYSTEM: Check if player needs a guaranteed drop
        let killsSinceLastDrop = profile.killsSinceLastDrop(bossId)
        if killsSinceLastDrop >= LootTableLibrary.pityThreshold {
            let pityEntry = availableEntries.max(by: { $0.weight < $1.weight })
            return DropResult(
                protocolId: pityEntry?.protocolId,
                isFirstKill: false,
                wasGuaranteed: true,
                rollValue: 1.0
            )
        }

        // NORMAL ROLL: Calculate drop using RNG
        return rollForDrop(
            entries: availableEntries,
            difficulty: difficulty,
            killCount: killCount,
            isFirstKill: isFirstKill
        )
    }

    // MARK: - Private Helpers

    private func rollForDrop(
        entries: [LootTableEntry],
        difficulty: BossDifficulty,
        killCount: Int,
        isFirstKill: Bool
    ) -> DropResult {
        // Get difficulty multiplier
        let difficultyMult = LootTableLibrary.difficultyMultipliers[difficulty] ?? 1.0

        // Calculate diminishing returns based on kill count
        let diminishingMult = 1.0 / (1.0 + LootTableLibrary.diminishingFactor * Double(killCount))

        // Roll the dice
        let roll = Double.random(in: 0..<1)

        // Group entries by rarity and calculate effective rates
        var drops: [(protocolId: String, effectiveRate: Double)] = []

        for entry in entries {
            guard let proto = ProtocolLibrary.get(entry.protocolId) else { continue }
            let baseRate = LootTableLibrary.rarityBaseRates[proto.rarity] ?? 0.0

            // Legendary protocols only drop on minimum difficulty or higher
            if proto.rarity == .legendary && !meetsMinimumDifficulty(difficulty, minimum: LootTableLibrary.legendaryMinDifficulty) {
                continue
            }

            let effectiveRate = baseRate * difficultyMult * diminishingMult
            drops.append((entry.protocolId, effectiveRate))
        }

        // Sort by rate descending (more common first)
        drops.sort { $0.effectiveRate > $1.effectiveRate }

        // Normalize rates if they exceed 1.0 (can happen at high difficulty multipliers)
        let totalRate = drops.reduce(0.0) { $0 + $1.effectiveRate }
        let normalizedDrops: [(protocolId: String, effectiveRate: Double)]
        if totalRate > 1.0 {
            normalizedDrops = drops.map { ($0.protocolId, $0.effectiveRate / totalRate) }
        } else {
            normalizedDrops = drops
        }

        // Check roll against cumulative probability
        var cumulative: Double = 0
        for drop in normalizedDrops {
            cumulative += drop.effectiveRate
            if roll < cumulative {
                return DropResult(
                    protocolId: drop.protocolId,
                    isFirstKill: isFirstKill,
                    wasGuaranteed: false,
                    rollValue: roll
                )
            }
        }

        // No drop this time
        return DropResult(
            protocolId: nil,
            isFirstKill: isFirstKill,
            wasGuaranteed: false,
            rollValue: roll
        )
    }

    /// Check if difficulty meets or exceeds the minimum required
    private func meetsMinimumDifficulty(_ difficulty: BossDifficulty, minimum: BossDifficulty) -> Bool {
        let allCases = BossDifficulty.allCases
        guard let diffIndex = allCases.firstIndex(of: difficulty),
              let minIndex = allCases.firstIndex(of: minimum) else {
            return false
        }
        return diffIndex >= minIndex
    }
}
