import Foundation
import CoreGraphics

// MARK: - Sector Unlock System
// Handles sector unlock validation, cost checking, and unlock execution

final class SectorUnlockSystem {

    // MARK: - Singleton

    static let shared = SectorUnlockSystem()
    private init() {}

    // MARK: - Unlock Result

    struct UnlockResult {
        let success: Bool
        let sectorId: String
        let message: String
        let hashSpent: Int

        static func success(sectorId: String, hashSpent: Int) -> UnlockResult {
            UnlockResult(success: true, sectorId: sectorId, message: "Sector decrypted!", hashSpent: hashSpent)
        }

        static func failure(sectorId: String, reason: String) -> UnlockResult {
            UnlockResult(success: false, sectorId: sectorId, message: reason, hashSpent: 0)
        }
    }

    // MARK: - Unlock Status

    struct UnlockStatus {
        let sectorId: String
        let displayName: String
        let description: String
        let unlockCost: Int
        let currentHash: Int
        let canAfford: Bool
        let prerequisitesMet: Bool
        let missingPrerequisites: [String]  // Display names of missing prereqs
        let isAlreadyUnlocked: Bool

        var canUnlock: Bool {
            canAfford && prerequisitesMet && !isAlreadyUnlocked
        }

        var statusMessage: String {
            if isAlreadyUnlocked {
                return L10n.Sector.alreadyDecrypted
            }
            if !prerequisitesMet {
                return L10n.Sector.requires(missingPrerequisites.joined(separator: ", "))
            }
            if !canAfford {
                return L10n.Sector.needMoreHash(unlockCost - currentHash)
            }
            return L10n.Sector.readyToDecrypt
        }
    }

    // MARK: - Status Queries

    /// Get detailed unlock status for a sector
    func getUnlockStatus(for sectorId: String, profile: PlayerProfile) -> UnlockStatus? {
        guard let sector = MegaBoardSystem.shared.sector(id: sectorId) else {
            return nil
        }

        let isUnlocked = MegaBoardSystem.shared.isSectorUnlocked(sectorId, profile: profile)
        let currentHash = profile.hash

        // Check sector prerequisites (adjacent sectors)
        var missingPrereqs: [String] = []
        for prereqId in sector.prerequisiteSectorIds {
            if !MegaBoardSystem.shared.isSectorUnlocked(prereqId, profile: profile) {
                if let prereqSector = MegaBoardSystem.shared.sector(id: prereqId) {
                    missingPrereqs.append(prereqSector.displayName)
                }
            }
        }

        // Check protocol requirements (schematic system)
        let missingProtocols = SectorSchematicLibrary.missingProtocolNames(for: sectorId, profile: profile)
        let protocolReqs = missingProtocols.map { "Compile: \($0)" }

        // Combine all prerequisites
        let allMissing = missingPrereqs + protocolReqs
        let prerequisitesMet = allMissing.isEmpty

        return UnlockStatus(
            sectorId: sectorId,
            displayName: sector.displayName,
            description: sector.description,
            unlockCost: sector.unlockCost,
            currentHash: currentHash,
            canAfford: currentHash >= sector.unlockCost,
            prerequisitesMet: prerequisitesMet,
            missingPrerequisites: allMissing,
            isAlreadyUnlocked: isUnlocked
        )
    }

    /// Get unlock status using SectorID enum
    func getUnlockStatus(for sectorId: SectorID, profile: PlayerProfile) -> UnlockStatus? {
        getUnlockStatus(for: sectorId.rawValue, profile: profile)
    }

    /// Check if a sector can be unlocked right now
    func canUnlock(sectorId: String, profile: PlayerProfile) -> Bool {
        getUnlockStatus(for: sectorId, profile: profile)?.canUnlock ?? false
    }

    // MARK: - Unlock Execution

    /// Attempt to unlock a sector
    /// Returns result indicating success/failure
    @discardableResult
    func unlockSector(_ sectorId: String, profile: inout PlayerProfile) -> UnlockResult {
        guard let status = getUnlockStatus(for: sectorId, profile: profile) else {
            return .failure(sectorId: sectorId, reason: "Sector not found")
        }

        // Validate
        if status.isAlreadyUnlocked {
            return .failure(sectorId: sectorId, reason: L10n.Sector.alreadyDecrypted)
        }

        if !status.prerequisitesMet {
            return .failure(sectorId: sectorId, reason: status.statusMessage)
        }

        if !status.canAfford {
            return .failure(sectorId: sectorId, reason: "Insufficient Hash")
        }

        // Execute unlock
        let cost = status.unlockCost
        profile.hash -= cost

        if !profile.unlockedTDSectors.contains(sectorId) {
            profile.unlockedTDSectors.append(sectorId)
        }

        // Update cache in MegaBoardSystem
        MegaBoardSystem.shared.updateUnlockCache(from: profile)

        print("[SectorUnlockSystem] Unlocked sector '\(status.displayName)' for \(cost) Hash")

        return .success(sectorId: sectorId, hashSpent: cost)
    }

    /// Attempt to unlock a sector using SectorID enum
    @discardableResult
    func unlockSector(_ sectorId: SectorID, profile: inout PlayerProfile) -> UnlockResult {
        unlockSector(sectorId.rawValue, profile: &profile)
    }

    // MARK: - Progression Helpers

    /// Get all sectors that can currently be unlocked
    func getUnlockableSectors(for profile: PlayerProfile) -> [MegaBoardSector] {
        MegaBoardSystem.shared.unlockableSectors(for: profile)
    }

    /// Get the next recommended sector to unlock (cheapest unlockable)
    func getRecommendedNextSector(for profile: PlayerProfile) -> MegaBoardSector? {
        let unlockable = getUnlockableSectors(for: profile)
        return unlockable.min { $0.unlockCost < $1.unlockCost }
    }

    /// Calculate total Hash needed to unlock all sectors
    func totalHashToUnlockAll(profile: PlayerProfile) -> Int {
        guard let config = MegaBoardSystem.shared.config else { return 0 }

        return config.sectors
            .filter { !MegaBoardSystem.shared.isSectorUnlocked($0.id, profile: profile) }
            .reduce(0) { $0 + $1.unlockCost }
    }

    /// Get unlock progress (sectors unlocked / total sectors)
    func getUnlockProgress(for profile: PlayerProfile) -> (unlocked: Int, total: Int, percentage: Double) {
        guard let config = MegaBoardSystem.shared.config else {
            return (0, 0, 0)
        }

        let total = config.sectors.count
        let unlocked = config.sectors.filter {
            MegaBoardSystem.shared.isSectorUnlocked($0.id, profile: profile)
        }.count

        let percentage = total > 0 ? Double(unlocked) / Double(total) * 100 : 0

        return (unlocked, total, percentage)
    }

    // MARK: - Partial Unlock (Future Feature)

    /// Add partial payment toward a sector unlock
    /// Stores progress in profile.tdSectorUnlockProgress
    func addPartialPayment(sectorId: String, amount: Int, profile: inout PlayerProfile) -> Int {
        guard let sector = MegaBoardSystem.shared.sector(id: sectorId) else { return 0 }
        guard !MegaBoardSystem.shared.isSectorUnlocked(sectorId, profile: profile) else { return 0 }

        // Get current progress
        let currentProgress = profile.tdSectorUnlockProgress[sectorId] ?? 0
        let remaining = sector.unlockCost - currentProgress

        // Calculate actual payment (don't overpay)
        let actualPayment = min(amount, min(remaining, profile.hash))

        if actualPayment > 0 {
            profile.hash -= actualPayment
            profile.tdSectorUnlockProgress[sectorId] = currentProgress + actualPayment

            // Check if fully paid
            if currentProgress + actualPayment >= sector.unlockCost {
                // Auto-unlock
                if !profile.unlockedTDSectors.contains(sectorId) {
                    profile.unlockedTDSectors.append(sectorId)
                }
                profile.tdSectorUnlockProgress.removeValue(forKey: sectorId)
                MegaBoardSystem.shared.updateUnlockCache(from: profile)
                print("[SectorUnlockSystem] Sector '\(sector.displayName)' fully paid and unlocked!")
            }
        }

        return actualPayment
    }

    /// Get partial payment progress for a sector
    func getPartialProgress(sectorId: String, profile: PlayerProfile) -> (paid: Int, total: Int, percentage: Double)? {
        guard let sector = MegaBoardSystem.shared.sector(id: sectorId) else { return nil }
        guard !MegaBoardSystem.shared.isSectorUnlocked(sectorId, profile: profile) else { return nil }

        let paid = profile.tdSectorUnlockProgress[sectorId] ?? 0
        let total = sector.unlockCost
        let percentage = total > 0 ? Double(paid) / Double(total) * 100 : 0

        return (paid, total, percentage)
    }

    // MARK: - Boss Defeat & Visibility

    /// Check if a district's boss has been defeated (visibility unlocked for next district)
    func isDistrictBossDefeated(_ districtId: String, profile: PlayerProfile) -> Bool {
        return profile.defeatedDistrictBosses.contains(districtId)
    }

    /// Check if a sector is visible (boss was defeated in previous sector or it's the starter)
    func isSectorVisible(_ sectorId: String, profile: PlayerProfile) -> Bool {
        // Starter sector is always visible
        if sectorId == SectorID.power.rawValue {
            return true
        }

        // Check if the previous sector's boss was defeated
        if let previousDistrictId = TDBossSystem.previousDistrict(forDistrict: sectorId) {
            return isDistrictBossDefeated(previousDistrictId, profile: profile)
        }

        return false
    }

    /// Record a district boss defeat (makes next district visible)
    /// Returns the next district that became visible, if any
    @discardableResult
    func recordBossDefeat(_ districtId: String, profile: inout PlayerProfile) -> String? {
        guard !profile.defeatedDistrictBosses.contains(districtId) else {
            return nil  // Already defeated
        }

        profile.defeatedDistrictBosses.append(districtId)

        // Get the next district that should become visible
        let nextDistrict = TDBossSystem.nextDistrictAfterDefeat(districtId)

        print("[SectorUnlockSystem] Boss in \(districtId) defeated - next district visible: \(nextDistrict ?? "none")")

        return nextDistrict
    }

    /// Get all sectors that are visible (can be seen but may not be unlocked)
    func getVisibleSectors(for profile: PlayerProfile) -> [MegaBoardSector] {
        guard let config = MegaBoardSystem.shared.config else { return [] }

        return config.sectors.filter { sector in
            isSectorVisible(sector.id, profile: profile)
        }
    }

    /// Get sectors that are visible but not yet unlocked (need Hash to unlock)
    func getVisibleButLockedSectors(for profile: PlayerProfile) -> [MegaBoardSector] {
        guard let config = MegaBoardSystem.shared.config else { return [] }

        return config.sectors.filter { sector in
            let isVisible = isSectorVisible(sector.id, profile: profile)
            let isUnlocked = MegaBoardSystem.shared.isSectorUnlocked(sector.id, profile: profile)
            return isVisible && !isUnlocked
        }
    }
}
