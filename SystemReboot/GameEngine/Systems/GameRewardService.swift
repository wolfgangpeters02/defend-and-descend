import Foundation
import CoreGraphics

// MARK: - Game Reward Service
// Single source of truth for all reward calculations (XP, Hash, level-up).
// Consolidates duplicated formulas from TDGameContainerView, AppState, and StorageService.
// Step 2.3 of the refactoring roadmap.

struct GameRewardService {

    // MARK: - Result Types

    struct TDRewardResult {
        let xpReward: Int
        let hashReward: Int
    }

    struct BossRewardResult {
        let xpReward: Int
        let hashReward: Int
    }

    // MARK: - TD Rewards

    /// Calculate XP and Hash rewards for a Tower Defense game
    static func calculateTDRewards(wavesCompleted: Int, enemiesKilled: Int, hashEarned: Int, victory: Bool) -> TDRewardResult {
        let xp = wavesCompleted * BalanceConfig.TDRewards.xpPerWave
            + enemiesKilled
            + (victory ? BalanceConfig.TDRewards.victoryXPBonus : 0)
        let hash = hashEarned / BalanceConfig.TDRewards.hashRewardDivisor
            + (victory ? wavesCompleted * BalanceConfig.TDRewards.victoryHashPerWave : 0)
        return TDRewardResult(xpReward: xp, hashReward: hash)
    }

    /// Record a TD game result onto a player profile (stats + rewards + level-up)
    static func applyTDResult(to profile: inout PlayerProfile, wavesCompleted: Int, enemiesKilled: Int, towersPlaced: Int, hashEarned: Int, victory: Bool) {
        // Stats
        profile.tdStats.gamesPlayed += 1
        if victory { profile.tdStats.gamesWon += 1 }
        profile.tdStats.totalWavesCompleted += wavesCompleted
        profile.tdStats.highestWave = max(profile.tdStats.highestWave, wavesCompleted)
        profile.tdStats.totalTowersPlaced += towersPlaced
        profile.tdStats.totalTDKills += enemiesKilled

        // Rewards
        let rewards = calculateTDRewards(wavesCompleted: wavesCompleted, enemiesKilled: enemiesKilled, hashEarned: hashEarned, victory: victory)
        profile.xp += rewards.xpReward
        profile.addHash(rewards.hashReward)

        // Level up
        checkLevelUp(profile: &profile)
    }

    // MARK: - Boss Rewards

    /// Calculate XP and Hash rewards for a boss run
    static func calculateBossRewards(kills: Int, time: TimeInterval, victory: Bool, hashEarned: Int) -> BossRewardResult {
        let xp = kills
            + Int(time / BalanceConfig.BossRunRewards.xpPerTimePeriod)
            + (victory ? BalanceConfig.BossRunRewards.victoryXPBonus : 0)

        let hash: Int
        if hashEarned > 0 {
            hash = victory ? hashEarned : Int(CGFloat(hashEarned) * BalanceConfig.BossRunRewards.deathHashPenalty)
        } else {
            // Legacy fallback
            let hashFromKills = kills / BalanceConfig.BossRunRewards.legacyHashPerKills
            let hashFromTime = Int(time / TimeInterval(BalanceConfig.BossRunRewards.legacyHashPerSeconds))
            let hashVictoryBonus = victory ? BalanceConfig.BossRunRewards.legacyVictoryHashBonus : 0
            hash = max(1, hashFromKills + hashFromTime + hashVictoryBonus)
        }

        return BossRewardResult(xpReward: xp, hashReward: hash)
    }

    /// Record a boss run onto a player profile (stats + rewards + level-up)
    static func applyBossResult(to profile: inout PlayerProfile, time: TimeInterval, kills: Int, victory: Bool, hashEarned: Int) {
        profile.totalRuns += 1
        profile.totalKills += kills
        if time > profile.bestTime { profile.bestTime = time }

        // Boss stats
        profile.bossStats.bossRuns += 1
        if victory {
            profile.bossStats.bossesCompleted += 1
            profile.bossStats.bossesDefeated += 1
        }

        profile.bossStats.totalBossKills += kills
        if time > profile.bossStats.longestBossFight {
            profile.bossStats.longestBossFight = time
        }

        // Rewards
        let rewards = calculateBossRewards(kills: kills, time: time, victory: victory, hashEarned: hashEarned)
        profile.xp += rewards.xpReward
        profile.addHash(rewards.hashReward)

        // Level up
        checkLevelUp(profile: &profile)
    }

    // MARK: - Level Up

    /// Process any pending level-ups based on current XP
    static func checkLevelUp(profile: inout PlayerProfile) {
        while profile.xp >= PlayerProfile.xpForLevel(profile.level) {
            profile.xp -= PlayerProfile.xpForLevel(profile.level)
            profile.level += 1
            AnalyticsService.shared.trackLevelUp(newLevel: profile.level)
        }
    }
}
