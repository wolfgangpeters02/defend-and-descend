import Foundation
import CoreGraphics

// MARK: - Progression (XP, Levels, Hash Management)

extension PlayerProfile {

    // XP required for next level (uses BalanceConfig)
    static func xpForLevel(_ level: Int) -> Int {
        return BalanceConfig.xpRequired(level: level)
    }

    // MARK: - Currency Helpers (System: Reboot)

    /// Maximum hash storage capacity based on Storage component level
    var hashStorageCapacity: Int {
        return componentLevels.hashStorageCapacity
    }

    /// Add hash with storage cap enforcement
    /// Returns the actual amount added (may be less if hitting cap)
    @discardableResult
    mutating func addHash(_ amount: Int) -> Int {
        let cap = hashStorageCapacity
        let spaceAvailable = max(0, cap - hash)
        let actualAdded = min(amount, spaceAvailable)
        hash += actualAdded
        return actualAdded
    }

    /// Check if hash storage is full
    var isHashStorageFull: Bool {
        return hash >= hashStorageCapacity
    }

    /// Percentage of hash storage used (0.0 - 1.0)
    var hashStoragePercent: Double {
        guard hashStorageCapacity > 0 else { return 0 }
        return Double(hash) / Double(hashStorageCapacity)
    }
}
