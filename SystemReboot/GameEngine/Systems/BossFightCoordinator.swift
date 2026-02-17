import Foundation
import Combine

// MARK: - Boss Fight Coordinator
// Single source of truth for the boss fight lifecycle.
// Replaces the NotificationCenter pattern and consolidates duplicated logic
// from MotherboardView and TDGameContainerView.
// Step 2.5 of the refactoring roadmap.

class BossFightCoordinator: ObservableObject {

    // MARK: - Published State (drives UI modals)

    @Published var showBossFight = false
    @Published var showBossLootModal = false
    @Published var showCampaignComplete = false
    @Published var pendingBossLootReward: BossLootReward?

    // MARK: - Fight Context

    /// The sector where the current boss spawned (used for sector unlock on first-kill)
    var currentBossSectorId: String?

    /// Selected difficulty for the current fight
    var selectedBossDifficulty: BossDifficulty = .normal

    /// Boss type being fought (e.g. "cyberboss")
    var activeBossType: String?

    // MARK: - Callbacks (set by the hosting view)
    // These allow the coordinator to apply context-specific side effects
    // without depending on UI layer types.

    /// Called on victory before building the loot reward. Returns the sector ID and whether it's a first kill.
    /// For embedded (MotherboardView): resets boss state on controller, calls scene.onBossFightWon, unpauses.
    /// For standalone (TDGameContainerView): calls TDBossSystem.onBossFightWon on local state.
    var onVictory: ((_ sectorId: String, _ difficulty: BossDifficulty) -> BossFightVictoryContext)?

    /// Called on defeat. The hosting view handles its own state cleanup (unpause, reset engaged, etc.)
    var onDefeat: (() -> Void)?

    /// Called after loot rewards are applied to the player profile.
    /// For embedded: updates game state hash, may not need mega-board refresh.
    /// For standalone: may refresh mega-board visuals.
    var onLootApplied: ((_ reward: BossLootReward) -> Void)?

    // MARK: - Fight Lifecycle

    /// Call before presenting the boss fight to track analytics.
    func onFightStarted() {
        AnalyticsService.shared.trackBossFightStarted(
            bossId: activeBossType ?? "cyberboss",
            difficulty: selectedBossDifficulty.rawValue
        )
    }

    /// Called when the boss fight scene completes (replaces NotificationCenter pattern).
    /// This is the single entry point that both MotherboardView and TDGameContainerView use.
    func onFightCompleted(victory: Bool) {
        showBossFight = false

        if victory {
            let sectorId = currentBossSectorId ?? SectorID.power.rawValue
            let difficulty = selectedBossDifficulty
            let bossId = activeBossType ?? "cyberboss"

            // Let the hosting view do context-specific victory handling (scene cleanup, state reset)
            let context = onVictory?(sectorId, difficulty) ?? BossFightVictoryContext(
                hashReward: difficulty.hashReward,
                isFirstKill: false,
                nextSectorUnlocked: nil
            )

            // Calculate protocol drop
            let dropResult = BlueprintDropSystem.shared.calculateDrop(
                bossId: bossId,
                difficulty: difficulty,
                profile: AppState.shared.currentPlayer
            )

            // Get protocol rarity if dropped
            var protocolRarity: Rarity?
            if let protocolId = dropResult.protocolId,
               let proto = ProtocolLibrary.get(protocolId) {
                protocolRarity = proto.rarity
            }

            // Get sector info if first kill unlocked a new sector
            var sectorInfo: (id: String, name: String, themeColor: String)?
            if let nextSectorId = context.nextSectorUnlocked,
               let lane = MotherboardLaneConfig.getLane(forSectorId: nextSectorId) {
                sectorInfo = (nextSectorId, lane.displayName, lane.themeColorHex)
            }

            // Build the loot reward for display
            pendingBossLootReward = BossLootReward.create(
                difficulty: difficulty,
                hashReward: context.hashReward,
                protocolId: dropResult.protocolId,
                protocolRarity: protocolRarity,
                unlockedSector: sectorInfo,
                isFirstKill: context.isFirstKill
            )

            // Track boss victory and blueprint drop
            AnalyticsService.shared.trackBossFightCompleted(
                bossId: bossId,
                difficulty: difficulty.rawValue,
                victory: true,
                isFirstKill: context.isFirstKill
            )
            if let protocolId = dropResult.protocolId {
                AnalyticsService.shared.trackBlueprintDropped(bossId: bossId, protocolId: protocolId)
            }

            showBossLootModal = true
            HapticsService.shared.play(.success)
            AudioManager.shared.play(.bossDeath)
        } else {
            AnalyticsService.shared.trackBossFightCompleted(
                bossId: activeBossType ?? "cyberboss",
                difficulty: selectedBossDifficulty.rawValue,
                victory: false,
                isFirstKill: false
            )
            onDefeat?()
            HapticsService.shared.play(.defeat)
            AudioManager.shared.play(.defeat)
        }
    }

    /// Called when the player collects loot from the modal.
    /// Applies rewards to the player profile and dismisses the modal.
    func onLootCollected() {
        guard let reward = pendingBossLootReward else {
            showBossLootModal = false
            return
        }

        let sectorId = currentBossSectorId ?? SectorID.power.rawValue
        let bossId = activeBossType ?? "cyberboss"
        let difficulty = selectedBossDifficulty
        let wasCampaignCompleted = AppState.shared.currentPlayer.campaignCompleted

        // Apply all rewards to player profile
        AppState.shared.updatePlayer { profile in
            // Record the boss kill for drop system tracking (pity, diminishing returns)
            profile.recordBossKill(bossId, difficulty: difficulty)

            // Add hash reward
            profile.addHash(reward.totalHashReward)

            // Record boss defeat for progression (first-time only)
            if reward.unlockedSectorId != nil {
                _ = SectorUnlockSystem.shared.recordBossDefeat(sectorId, profile: &profile)
            }

            // Add protocol blueprint if dropped + record for pity tracking
            if let protocolId = reward.droppedProtocolId,
               !profile.protocolBlueprints.contains(protocolId) {
                profile.protocolBlueprints.append(protocolId)
                profile.recordBlueprintDrop(bossId, protocolId: protocolId)
                // Mark as unseen so SYS button and Arsenal card pulse
                TutorialHintManager.shared.addUnseenBlueprint(protocolId)
            }

            // Check if campaign just became complete (all MVP bosses defeated)
            if !profile.campaignCompleted &&
               BalanceConfig.SectorUnlock.isCampaignComplete(defeatedSectorBosses: profile.defeatedSectorBosses) {
                profile.campaignCompleted = true
            }
        }

        // Show campaign complete overlay if just completed
        if !wasCampaignCompleted && AppState.shared.currentPlayer.campaignCompleted {
            showCampaignComplete = true
        }

        // Let the hosting view do any context-specific post-loot work
        onLootApplied?(reward)

        // Dismiss modal and clean up
        pendingBossLootReward = nil
        showBossLootModal = false
        currentBossSectorId = nil
    }
}

// MARK: - Victory Context

/// Returned by the hosting view's `onVictory` callback with context-specific info
struct BossFightVictoryContext {
    let hashReward: Int
    let isFirstKill: Bool
    let nextSectorUnlocked: String?
}
