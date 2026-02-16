import Foundation
import CoreGraphics

// MARK: - XP System

class XPSystem {

    // XP values by enemy type (from BalanceConfig)
    static let enemyXPValues: [String: Int] = [
        EnemyID.basic.rawValue: BalanceConfig.XPSystem.basicEnemyXP,
        EnemyID.fast.rawValue: BalanceConfig.XPSystem.fastEnemyXP,
        EnemyID.tank.rawValue: BalanceConfig.XPSystem.tankEnemyXP,
        EnemyID.boss.rawValue: BalanceConfig.XPSystem.bossEnemyXP,
        EnemyID.cyberboss.rawValue: BalanceConfig.XPSystem.cyberbossXP,
        EnemyID.voidharbinger.rawValue: BalanceConfig.XPSystem.voidHarbingerXP
    ]

    // Loot box thresholds (from BalanceConfig)
    static var tier1Threshold: CGFloat { BalanceConfig.XPSystem.tier1Threshold }
    static var tier2Threshold: CGFloat { BalanceConfig.XPSystem.tier2Threshold }
    static var tier3Threshold: CGFloat { BalanceConfig.XPSystem.tier3Threshold }

    /// Get XP multiplier based on protocol level (higher levels = less XP)
    static func getXPMultiplier(protocolLevel: Int) -> CGFloat {
        let reduction = CGFloat(protocolLevel - 1) * BalanceConfig.XPSystem.xpReductionPerLevel
        return max(BalanceConfig.XPSystem.minXPMultiplier, 1.0 - reduction)
    }

    /// Award XP for killing an enemy
    static func awardXP(state: inout GameState, enemyType: String, protocolLevel: Int) {
        let baseXP = enemyXPValues[enemyType] ?? 1
        let multiplier = getXPMultiplier(protocolLevel: protocolLevel)
        let xpGained = Int(CGFloat(baseXP) * multiplier)

        state.xp += xpGained
        updateXPBarProgress(state: &state)
    }

    /// Update XP bar progress
    static func updateXPBarProgress(state: inout GameState) {
        let xpRequired = BalanceConfig.xpRequired(level: state.upgradeLevel + 1)
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
                .common: BalanceConfig.XPSystem.goldenCommonWeight,
                .rare: BalanceConfig.XPSystem.goldenRareWeight,
                .epic: BalanceConfig.XPSystem.goldenEpicWeight,
                .legendary: BalanceConfig.XPSystem.goldenLegendaryWeight
            ]
        case 2: // Silver - medium odds
            return [
                .common: BalanceConfig.XPSystem.silverCommonWeight,
                .rare: BalanceConfig.XPSystem.silverRareWeight,
                .epic: BalanceConfig.XPSystem.silverEpicWeight,
                .legendary: BalanceConfig.XPSystem.silverLegendaryWeight
            ]
        default: // Wooden - basic odds
            return [
                .common: BalanceConfig.XPSystem.woodenCommonWeight,
                .rare: BalanceConfig.XPSystem.woodenRareWeight,
                .epic: BalanceConfig.XPSystem.woodenEpicWeight,
                .legendary: BalanceConfig.XPSystem.woodenLegendaryWeight
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
        case 3: return TierColors.gold
        case 2: return TierColors.silver
        default: return TierColors.bronze
        }
    }
}
