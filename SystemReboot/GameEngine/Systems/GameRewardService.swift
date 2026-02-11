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

    struct SurvivorRewardResult {
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

    // MARK: - Survivor Rewards

    /// Calculate XP and Hash rewards for a Survivor (arena/dungeon) run
    static func calculateSurvivorRewards(kills: Int, time: TimeInterval, victory: Bool, extracted: Bool, hashEarned: Int) -> SurvivorRewardResult {
        let xp = kills
            + Int(time / BalanceConfig.SurvivorRewards.xpPerTimePeriod)
            + (victory || extracted ? BalanceConfig.SurvivorRewards.victoryXPBonus : 0)

        let hash: Int
        if hashEarned > 0 {
            hash = extracted ? hashEarned : Int(CGFloat(hashEarned) * BalanceConfig.SurvivorRewards.deathHashPenalty)
        } else {
            // Legacy fallback
            let hashFromKills = kills / BalanceConfig.SurvivorRewards.legacyHashPerKills
            let hashFromTime = Int(time / TimeInterval(BalanceConfig.SurvivorRewards.legacyHashPerSeconds))
            let hashVictoryBonus = victory ? BalanceConfig.SurvivorRewards.legacyVictoryHashBonus : 0
            hash = max(1, hashFromKills + hashFromTime + hashVictoryBonus)
        }

        return SurvivorRewardResult(xpReward: xp, hashReward: hash)
    }

    /// Record a survivor run onto a player profile (stats + rewards + level-up)
    static func applySurvivorResult(to profile: inout PlayerProfile, time: TimeInterval, kills: Int, gameMode: GameMode, victory: Bool, hashEarned: Int, extracted: Bool) {
        profile.totalRuns += 1
        profile.totalKills += kills
        if time > profile.bestTime { profile.bestTime = time }

        // Mode-specific stats
        if gameMode == .survival || gameMode == .arena {
            profile.survivorStats.arenaRuns += 1
        } else if gameMode == .boss || gameMode == .dungeon {
            profile.survivorStats.dungeonRuns += 1
            if victory {
                profile.survivorStats.dungeonsCompleted += 1
                profile.survivorStats.bossesDefeated += 1
            }
        }

        profile.survivorStats.totalSurvivorKills += kills
        if time > profile.survivorStats.longestSurvival {
            profile.survivorStats.longestSurvival = time
        }

        // Rewards
        let rewards = calculateSurvivorRewards(kills: kills, time: time, victory: victory, extracted: extracted, hashEarned: hashEarned)
        profile.xp += rewards.xpReward
        profile.addHash(rewards.hashReward)

        // Level up
        checkLevelUp(profile: &profile)
    }

    // MARK: - Boss Rewards (Standalone / Survivor Boss)

    /// Calculate XP and Hash rewards for a standalone boss defeat
    static func calculateBossRewards(difficulty: BossDifficulty) -> BossRewardResult {
        let hashBonus = BalanceConfig.BossRewards.difficultyHashBonus[difficulty] ?? 500
        let xpReward = 100 + (difficulty == .nightmare ? 100 : difficulty == .hard ? 50 : 0)
        return BossRewardResult(xpReward: xpReward, hashReward: hashBonus)
    }

    /// Record a standalone boss defeat onto a player profile (stats + rewards + blueprint + level-up)
    @discardableResult
    static func applyBossDefeatResult(to profile: inout PlayerProfile, bossId: String, difficulty: BossDifficulty, time: TimeInterval, kills: Int) -> BlueprintDropSystem.DropResult {
        // Calculate drop BEFORE recording the kill (for first-kill detection)
        let dropResult = BlueprintDropSystem.shared.calculateDrop(
            bossId: bossId,
            difficulty: difficulty,
            profile: profile
        )

        // Record the boss kill
        profile.recordBossKill(bossId, difficulty: difficulty)
        profile.survivorStats.bossesDefeated += 1
        profile.totalKills += kills

        // Rewards
        let rewards = calculateBossRewards(difficulty: difficulty)
        profile.addHash(rewards.hashReward)
        profile.xp += rewards.xpReward

        // Award blueprint if one dropped
        if let protocolId = dropResult.protocolId {
            if !profile.hasBlueprint(protocolId) && !profile.isProtocolCompiled(protocolId) {
                profile.protocolBlueprints.append(protocolId)
                profile.recordBlueprintDrop(bossId, protocolId: protocolId)
            }
        }

        // Level up
        checkLevelUp(profile: &profile)

        return dropResult
    }

    // MARK: - Level Up

    /// Process any pending level-ups based on current XP
    static func checkLevelUp(profile: inout PlayerProfile) {
        while profile.xp >= PlayerProfile.xpForLevel(profile.level) {
            profile.xp -= PlayerProfile.xpForLevel(profile.level)
            profile.level += 1
        }
    }
}
