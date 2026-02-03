import Foundation
import CoreGraphics

// MARK: - Leveling System

class LevelingSystem {

    static var maxLevel: Int { BalanceConfig.Leveling.maxPlayerLevel }
    static var levelBonusPercent: CGFloat { BalanceConfig.ThreatLevel.levelBonusPercent }

    /// Get weapon level from player profile
    static func getWeaponLevel(profile: PlayerProfile, weaponId: String) -> Int {
        return profile.weaponLevels[weaponId] ?? 1
    }

    /// Check if item is unlocked
    static func isItemUnlocked(profile: PlayerProfile, category: String, id: String) -> Bool {
        switch category {
        case "weapon":
            return profile.unlocks.weapons.contains(id)
        case "arena":
            return profile.unlocks.arenas.contains(id)
        default:
            return false
        }
    }

    /// Get level damage/effect multiplier
    static func getLevelMultiplier(level: Int) -> CGFloat {
        return 1.0 + CGFloat(level - 1) * levelBonusPercent
    }

    /// Get level bonus text for display
    static func getLevelBonusText(level: Int) -> String {
        let bonus = Int((getLevelMultiplier(level: level) - 1) * 100)
        return "+\(bonus)%"
    }

    /// Check if item can level up
    static func canLevelUp(currentLevel: Int) -> Bool {
        return currentLevel < maxLevel
    }

    /// Calculate XP needed for next level
    static func xpNeededForLevel(_ level: Int) -> Int {
        return BalanceConfig.xpRequired(level: level)
    }

    /// Unlock a new item
    static func unlockItem(profile: inout PlayerProfile, category: String, id: String) -> Bool {
        switch category {
        case "weapon":
            if !profile.unlocks.weapons.contains(id) {
                profile.unlocks.weapons.append(id)
                profile.weaponLevels[id] = 1
                return true
            }
        case "arena":
            if !profile.unlocks.arenas.contains(id) {
                profile.unlocks.arenas.append(id)
                return true
            }
        default:
            break
        }
        return false
    }

    /// Level up an item
    static func levelUpItem(profile: inout PlayerProfile, category: String, id: String) -> Bool {
        switch category {
        case "weapon":
            let currentLevel = profile.weaponLevels[id] ?? 1
            if currentLevel < maxLevel {
                profile.weaponLevels[id] = currentLevel + 1
                return true
            }
        default:
            break
        }
        return false
    }
}
