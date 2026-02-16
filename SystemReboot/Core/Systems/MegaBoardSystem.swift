import Foundation
import CoreGraphics

// MARK: - Mega-Board System
// Manages sector unlocks, visibility culling, and mega-board state

final class MegaBoardSystem {

    // MARK: - Singleton

    static let shared = MegaBoardSystem()
    private init() {}

    // MARK: - Properties

    /// The loaded mega-board configuration
    private(set) var config: MegaBoardConfig?

    /// Cache of unlocked sector IDs for quick lookup
    private var unlockedSectorCache: Set<String> = []

    // MARK: - Configuration Loading

    /// Load the default mega-board configuration
    func loadDefaultConfig() {
        config = MegaBoardConfig.createDefault()
    }

    // MARK: - Sector Queries

    /// Get all sectors in the mega-board
    var sectors: [MegaBoardSector] {
        config?.sectors ?? []
    }

    /// Get a sector by ID
    func sector(id: String) -> MegaBoardSector? {
        config?.sector(id: id)
    }

    /// Get a sector by SectorID enum
    func sector(id: SectorID) -> MegaBoardSector? {
        config?.sector(id: id.rawValue)
    }

    /// Get the starter sector (always unlocked)
    var starterSector: MegaBoardSector? {
        config?.sectors.first { $0.isStarterSector }
    }

    /// Get sectors visible in the given camera rect (for culling)
    func visibleSectors(in cameraRect: CGRect) -> [MegaBoardSector] {
        config?.visibleSectors(in: cameraRect) ?? []
    }

    /// Get sectors adjacent to a given sector
    func adjacentSectors(to sectorId: String) -> [MegaBoardSector] {
        config?.adjacentSectors(to: sectorId) ?? []
    }

    // MARK: - Unlock State

    /// Update the unlock cache from a player profile
    func updateUnlockCache(from profile: PlayerProfile) {
        unlockedSectorCache = Set(profile.unlockedTDSectors)

        // Always include starter sector
        if let starterSector = starterSector {
            unlockedSectorCache.insert(starterSector.id)
        }
    }

    /// Check if a sector is unlocked
    func isSectorUnlocked(_ sectorId: String, profile: PlayerProfile) -> Bool {
        // Starter sector is always unlocked
        if let sector = sector(id: sectorId), sector.isStarterSector {
            return true
        }

        return profile.unlockedTDSectors.contains(sectorId)
    }

    /// Check if a sector is unlocked (using SectorID enum)
    func isSectorUnlocked(_ sectorId: SectorID, profile: PlayerProfile) -> Bool {
        isSectorUnlocked(sectorId.rawValue, profile: profile)
    }

    /// Check if a sector can be unlocked (has prerequisites met)
    func canUnlockSector(_ sectorId: String, profile: PlayerProfile) -> (canUnlock: Bool, reason: String?) {
        guard let sector = sector(id: sectorId) else {
            return (false, "Sector not found")
        }

        // Already unlocked
        if isSectorUnlocked(sectorId, profile: profile) {
            return (false, "Already unlocked")
        }

        // Check prerequisites
        for prereqId in sector.prerequisiteSectorIds {
            if !isSectorUnlocked(prereqId, profile: profile) {
                if let prereqSector = self.sector(id: prereqId) {
                    return (false, "Requires: \(prereqSector.displayName)")
                }
                return (false, "Requires prerequisite sector")
            }
        }

        // Check cost
        if profile.hash < sector.unlockCost {
            return (false, "Need \(sector.unlockCost) Hash")
        }

        return (true, nil)
    }

    /// Get the unlock cost for a sector
    func unlockCost(for sectorId: String) -> Int? {
        sector(id: sectorId)?.unlockCost
    }

    /// Get sectors that are unlockable (prerequisites met, not yet unlocked)
    func unlockableSectors(for profile: PlayerProfile) -> [MegaBoardSector] {
        guard let config = config else { return [] }

        return config.sectors.filter { sector in
            !isSectorUnlocked(sector.id, profile: profile) &&
            canUnlockSector(sector.id, profile: profile).canUnlock
        }
    }

    /// Determine the visual render mode for a sector
    func getRenderMode(for sectorId: String, profile: PlayerProfile) -> SectorRenderMode {
        // Beyond MVP boundary = coming soon (visible but not unlockable)
        if BalanceConfig.SectorUnlock.isBeyondMVP(sectorId) {
            return .comingSoon
        }

        // Already unlocked = full rendering
        if isSectorUnlocked(sectorId, profile: profile) {
            return .unlocked
        }

        // Check if all required blueprints have been found (or compiled)
        if SectorSchematicLibrary.hasFoundRequiredBlueprints(for: sectorId, profile: profile) {
            return .unlockable
        }

        // Blueprints not found = locked/mystery
        return .locked
    }

    /// Get sectors that are locked and visible (adjacent to unlocked)
    func visibleLockedSectors(for profile: PlayerProfile) -> [MegaBoardSector] {
        guard let config = config else { return [] }

        var visibleLocked: Set<String> = []

        // For each unlocked sector, add its adjacent locked sectors
        for sector in config.sectors where isSectorUnlocked(sector.id, profile: profile) {
            for adjacent in adjacentSectors(to: sector.id) {
                if !isSectorUnlocked(adjacent.id, profile: profile) {
                    visibleLocked.insert(adjacent.id)
                }
            }
        }

        return visibleLocked.compactMap { sector(id: $0) }
    }

    /// Get visible locked sectors split by render mode
    func visibleLockedSectorsByMode(for profile: PlayerProfile) -> (locked: [MegaBoardSector], unlockable: [MegaBoardSector]) {
        let allVisible = visibleLockedSectors(for: profile)
        var locked: [MegaBoardSector] = []
        var unlockable: [MegaBoardSector] = []

        for sector in allVisible {
            switch getRenderMode(for: sector.id, profile: profile) {
            case .unlockable:
                unlockable.append(sector)
            case .locked, .comingSoon:
                locked.append(sector)
            case .unlocked:
                break  // Shouldn't happen for visible locked sectors
            }
        }

        return (locked, unlockable)
    }

    // MARK: - Camera Bounds

    /// Calculate camera bounds based on unlocked sectors
    /// Camera can only pan within unlocked sector area (with padding)
    func calculateCameraBounds(for profile: PlayerProfile, screenSize: CGSize, scale: CGFloat) -> CGRect {
        guard let config = config else {
            return CGRect(x: 0, y: 0, width: 1400, height: 1400)
        }

        // Get all unlocked sectors
        let unlockedSectors = config.sectors.filter { isSectorUnlocked($0.id, profile: profile) }

        guard !unlockedSectors.isEmpty else {
            // Default to starter sector bounds
            if let starter = starterSector {
                return starter.bounds
            }
            return CGRect(x: 0, y: 0, width: config.sectorWidth, height: config.sectorHeight)
        }

        // Calculate bounding rect of all unlocked sectors
        var minX = CGFloat.infinity
        var minY = CGFloat.infinity
        var maxX = -CGFloat.infinity
        var maxY = -CGFloat.infinity

        for sector in unlockedSectors {
            minX = min(minX, sector.worldX)
            minY = min(minY, sector.worldY)
            maxX = max(maxX, sector.worldX + sector.width)
            maxY = max(maxY, sector.worldY + sector.height)
        }

        // Add padding for visible locked sectors (can peek at them)
        let peekPadding: CGFloat = 200

        return CGRect(
            x: minX - peekPadding,
            y: minY - peekPadding,
            width: (maxX - minX) + peekPadding * 2,
            height: (maxY - minY) + peekPadding * 2
        )
    }

    // MARK: - Unlock Actions

    /// Attempt to unlock a sector
    /// Returns true if successful, updates profile
    @discardableResult
    func unlockSector(_ sectorId: String, profile: inout PlayerProfile) -> Bool {
        let result = canUnlockSector(sectorId, profile: profile)

        guard result.canUnlock else {
            return false
        }

        guard let sector = sector(id: sectorId) else { return false }

        // Deduct cost
        profile.hash -= sector.unlockCost

        // Add to unlocked list
        if !profile.unlockedTDSectors.contains(sectorId) {
            profile.unlockedTDSectors.append(sectorId)
        }

        // Update cache
        unlockedSectorCache.insert(sectorId)

        return true
    }

    /// Attempt to unlock a sector (using SectorID enum)
    @discardableResult
    func unlockSector(_ sectorId: SectorID, profile: inout PlayerProfile) -> Bool {
        unlockSector(sectorId.rawValue, profile: &profile)
    }
}

// MARK: - PlayerProfile TD Sector Helpers

extension PlayerProfile {
    /// Check if a TD mega-board sector is unlocked
    func isTDSectorUnlocked(_ sectorId: String) -> Bool {
        // Starter sector is always unlocked
        if sectorId == SectorID.starter.rawValue {
            return true
        }
        return unlockedTDSectors.contains(sectorId)
    }

    /// Check if a TD mega-board sector is unlocked (using SectorID)
    func isTDSectorUnlocked(_ sectorId: SectorID) -> Bool {
        isTDSectorUnlocked(sectorId.rawValue)
    }
}
