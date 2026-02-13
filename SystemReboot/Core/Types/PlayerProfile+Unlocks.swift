import Foundation

// MARK: - Unlocks (Debug Arenas, Components, Boss Kills)

extension PlayerProfile {

    // MARK: - Debug Arena Helpers (Active Mode)

    /// Check if a debug arena is unlocked
    func isDebugArenaUnlocked(_ arenaId: String) -> Bool {
        return unlockedSectors.contains(arenaId)
    }

    /// Get best time for a debug arena
    func debugArenaBestTime(_ arenaId: String) -> TimeInterval? {
        return sectorBestTimes[arenaId]
    }

    // MARK: - TD Sector Helpers (Motherboard Map)

    /// Set of unlocked TD sector IDs (for efficient lookup)
    var unlockedSectorIds: Set<String> {
        return Set(unlockedTDSectors)
    }

    // Note: isTDSectorUnlocked and unlockTDSector are in MegaBoardSystem.swift extension

    // MARK: - Component Helpers

    /// Check if a component type is unlocked
    func isComponentUnlocked(_ type: UpgradeableComponent) -> Bool {
        return unlockedComponents.isUnlocked(type)
    }

    /// Get level of a component
    func componentLevel(_ type: UpgradeableComponent) -> Int {
        return componentLevels[type]
    }

    /// Check if a component can be upgraded
    func canUpgradeComponent(_ type: UpgradeableComponent) -> Bool {
        guard isComponentUnlocked(type) else { return false }
        return componentLevels.canUpgrade(type)
    }

    /// Get upgrade cost for a component (nil if max level or locked)
    func componentUpgradeCost(_ type: UpgradeableComponent) -> Int? {
        guard isComponentUnlocked(type) else { return nil }
        return componentLevels.upgradeCost(for: type)
    }

    /// Upgrade a component if affordable
    mutating func upgradeComponent(_ type: UpgradeableComponent) -> Bool {
        guard let cost = componentUpgradeCost(type),
              hash >= cost else { return false }
        hash -= cost
        componentLevels.upgrade(type)
        return true
    }

    /// Record a sector boss defeat (unlocks next component)
    mutating func recordSectorBossDefeat(_ sectorId: SectorID) {
        let sectorIdString = sectorId.rawValue
        if !defeatedSectorBosses.contains(sectorIdString) {
            defeatedSectorBosses.append(sectorIdString)
            unlockedComponents.recordBossDefeat()
        }
    }
}
