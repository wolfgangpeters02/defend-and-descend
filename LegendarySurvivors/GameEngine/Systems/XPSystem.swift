import Foundation
import CoreGraphics

// MARK: - XP System

class XPSystem {

    // XP values by enemy type
    static let enemyXPValues: [String: Int] = [
        "basic": 1,
        "fast": 2,
        "tank": 5,
        "boss": 20,
        "cyberboss": 50,
        "voidharbinger": 100
    ]

    // Loot box thresholds
    static let tier1Threshold: CGFloat = 0.33
    static let tier2Threshold: CGFloat = 0.66
    static let tier3Threshold: CGFloat = 1.0

    /// Get XP multiplier based on item levels (higher levels = less XP)
    static func getXPMultiplier(weaponLevel: Int, powerupLevel: Int) -> CGFloat {
        let avgLevel = (weaponLevel + powerupLevel) / 2
        let reduction = CGFloat(avgLevel - 1) * 0.10 // 10% reduction per level
        return max(0.2, 1.0 - reduction) // Minimum 20%
    }

    /// Award XP for killing an enemy
    static func awardXP(state: inout GameState, enemyType: String, weaponLevel: Int, powerupLevel: Int) {
        let baseXP = enemyXPValues[enemyType] ?? 1
        let multiplier = getXPMultiplier(weaponLevel: weaponLevel, powerupLevel: powerupLevel)
        let xpGained = Int(CGFloat(baseXP) * multiplier)

        state.xp += xpGained
        updateXPBarProgress(state: &state)
    }

    /// Update XP bar progress
    static func updateXPBarProgress(state: inout GameState) {
        let xpRequired = 100 + (state.upgradeLevel) * 45
        state.xpBarProgress = min(1.0, CGFloat(state.xp) / CGFloat(xpRequired))
    }

    /// Get loot box tier based on XP progress
    static func getLootBoxTier(progress: CGFloat) -> Int {
        if progress >= tier3Threshold {
            return 3 // Golden
        } else if progress >= tier2Threshold {
            return 2 // Silver
        } else {
            return 1 // Wooden
        }
    }

    /// Get rarity chances based on loot box tier
    static func getLootBoxRarityChances(tier: Int) -> [Rarity: Double] {
        switch tier {
        case 3: // Golden - best odds
            return [
                .common: 10,
                .rare: 30,
                .epic: 40,
                .legendary: 20
            ]
        case 2: // Silver - medium odds
            return [
                .common: 40,
                .rare: 35,
                .epic: 20,
                .legendary: 5
            ]
        default: // Wooden - basic odds
            return [
                .common: 80,
                .rare: 15,
                .epic: 5,
                .legendary: 0
            ]
        }
    }

    /// Roll for loot box reward
    static func rollLootBox(tier: Int) -> Rarity {
        let chances = getLootBoxRarityChances(tier: tier)
        let totalWeight = chances.values.reduce(0, +)
        var random = Double.random(in: 0...totalWeight)

        for (rarity, weight) in chances.sorted(by: { $0.value > $1.value }) {
            random -= weight
            if random <= 0 {
                return rarity
            }
        }

        return .common
    }

    /// Get tier display name
    static func getTierName(_ tier: Int) -> String {
        switch tier {
        case 3: return "Golden"
        case 2: return "Silver"
        default: return "Wooden"
        }
    }

    /// Get tier color
    static func getTierColor(_ tier: Int) -> String {
        switch tier {
        case 3: return "#ffd700"
        case 2: return "#c0c0c0"
        default: return "#8b4513"
        }
    }
}
