import Foundation

// MARK: - Unlocks (Sectors, Components, Boss Kills)

extension PlayerProfile {

    // MARK: - Sector Helpers (Active Mode)

    /// Check if a sector is unlocked
    func isSectorUnlocked(_ sectorId: String) -> Bool {
        return unlockedSectors.contains(sectorId)
    }

    /// Get best time for a sector
    func sectorBestTime(_ sectorId: String) -> TimeInterval? {
        return sectorBestTimes[sectorId]
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

    /// Record a district boss defeat (unlocks next component)
    mutating func recordDistrictBossDefeat(_ sectorId: SectorID) {
        let sectorIdString = sectorId.rawValue
        if !defeatedDistrictBosses.contains(sectorIdString) {
            defeatedDistrictBosses.append(sectorIdString)
            unlockedComponents.recordBossDefeat()
        }
    }
}
