import SpriteKit
import SwiftUI

extension TDGameScene {

    // MARK: - Actions

    func startWave() {
        guard var state = state, !state.waveInProgress, currentWaveIndex < waves.count else { return }

        WaveSystem.startWave(state: &state, wave: waves[currentWaveIndex])
        spawnTimer = 0

        self.state = state
    }

    // MARK: - Motherboard City (placeholder for new system)
    // Will implement: setupMotherboard(), updateComponentVisibility(), playInstallAnimation()

    /// Restore efficiency by setting the leak counter
    /// - Parameter leakCount: The new leak count (0 = 100%, 10 = 50%, 20 = 0%)
    func restoreEfficiency(to leakCount: Int) {
        guard var state = state else { return }
        FreezeRecoveryService.restoreEfficiency(state: &state, toLeakCount: leakCount)
        self.state = state
        gameStateDelegate?.gameStateUpdated(state)
    }

    /// Recover from System Freeze (0% efficiency state)
    /// Called when player chooses "Flush Memory" or completes "Manual Override"
    /// - Parameter restoreToEfficiency: Target efficiency (50 = 50%, i.e., leakCounter = 10)
    func recoverFromFreeze(restoreToEfficiency: CGFloat = BalanceConfig.Freeze.recoveryTargetEfficiency) {
        guard var state = state else { return }

        guard FreezeRecoveryService.recoverFromFreeze(state: &state, targetEfficiency: restoreToEfficiency) else {
            return
        }

        self.state = state
        gameStateDelegate?.gameStateUpdated(state)

        // Play recovery feedback
        HapticsService.shared.play(.success)

        // Visual recovery effect
        playRecoveryEffect()
    }

    /// Play visual effect for system recovery
    func playRecoveryEffect() {
        guard let coreContainer = backgroundLayer.childNode(withName: "core") else { return }

        // Flash the core green
        let flashGreen = SKAction.run {
            if let cpuBody = coreContainer.childNode(withName: "cpuBody") as? SKShapeNode {
                cpuBody.strokeColor = DesignColors.successUI
                cpuBody.glowWidth = 4.0  // Recovery flash (transient ~0.3s)
            }
        }
        let wait = SKAction.wait(forDuration: 0.3)
        let reset = SKAction.run { [weak self] in
            guard let self = self, let state = self.state else { return }
            self.updateCoreVisual(state: state, currentTime: CACurrentMediaTime())
        }
        let sequence = SKAction.sequence([flashGreen, wait, reset])
        coreContainer.run(sequence)

        // Expanding ring effect
        let ringNode = SKShapeNode(circleOfRadius: 10)
        ringNode.position = coreContainer.position
        ringNode.strokeColor = DesignColors.successUI
        ringNode.fillColor = .clear
        ringNode.lineWidth = 4
        ringNode.glowWidth = 3.0  // Recovery ring (transient ~0.8s)
        ringNode.zPosition = 100
        backgroundLayer.addChild(ringNode)

        let expand = SKAction.scale(to: 20, duration: 0.8)
        let fade = SKAction.fadeOut(withDuration: 0.8)
        let group = SKAction.group([expand, fade])
        let remove = SKAction.removeFromParent()
        ringNode.run(SKAction.sequence([group, remove]))
    }

    // MARK: - Overclock System

    /// Activate overclock mode (2x hash, 10x threat growth for 60 seconds)
    func activateOverclock() {
        guard var state = state else { return }

        if OverclockSystem.activateOverclock(state: &state) {
            self.state = state
            gameStateDelegate?.gameStateUpdated(state)
            HapticsService.shared.play(.heavy)

            // Visual feedback - pulse the CPU core orange
            playOverclockActivationEffect()
        }
    }

    /// Visual effect for overclock activation
    func playOverclockActivationEffect() {
        guard let coreContainer = backgroundLayer.childNode(withName: "core") else { return }

        // Flash the core orange
        let flashOrange = SKAction.run {
            if let cpuBody = coreContainer.childNode(withName: "cpuBody") as? SKShapeNode {
                cpuBody.strokeColor = .orange
                cpuBody.glowWidth = 0  // PERF: was 20 (GPU Gaussian blur)
            }
        }
        let wait = SKAction.wait(forDuration: 0.5)
        let sequence = SKAction.sequence([flashOrange, wait])
        let pulse = SKAction.repeat(sequence, count: 3)
        coreContainer.run(pulse)
    }

    // MARK: - Boss Fight Results

    /// Called when boss fight is won - handle game state cleanup
    /// Profile rewards (hash, blueprints, sector unlock) are applied by BossFightCoordinator.onLootCollected()
    func onBossFightWon(sectorId: String) {
        guard var state = state else { return }

        // Process the boss fight win through TDBossSystem (threat reset, efficiency reset, boss removal)
        let reward = TDBossSystem.onBossFightWon(state: &state, sectorId: sectorId)

        // Apply hash reward to game state
        state.hash += reward.hashReward

        self.state = state
        gameStateDelegate?.gameStateUpdated(state)
    }

    /// Called when boss fight is lost and player lets boss pass
    func onBossFightLost() {
        guard var state = state else { return }

        TDBossSystem.onBossFightLostLetPass(state: &state)

        self.state = state
        gameStateDelegate?.gameStateUpdated(state)

        HapticsService.shared.play(.defeat)
    }

    func placeTower(protocolId: String, slotId: String, profile: PlayerProfile) {
        guard var state = state else {
            return
        }

        let result = TowerSystem.placeTowerFromProtocol(state: &state, protocolId: protocolId, slotId: slotId, playerProfile: profile)

        switch result {
        case .success(_):
            // Update slot visual
            if let slotIndex = state.towerSlots.firstIndex(where: { $0.id == slotId }) {
                updateSlotVisual(slot: state.towerSlots[slotIndex])
            }
            self.state = state
            gameStateDelegate?.gameStateUpdated(state)

            // Persist tower placement
            StorageService.shared.saveTDSession(TDSessionState.from(gameState: state))
            HapticsService.shared.play(.towerPlace)

        case .insufficientHash:
            HapticsService.shared.play(.warning)
            gameStateDelegate?.placementFailed(result)

        case .insufficientPower:
            HapticsService.shared.play(.warning)
            gameStateDelegate?.placementFailed(result)

        case .slotOccupied:
            HapticsService.shared.play(.warning)
            gameStateDelegate?.placementFailed(result)

        case .protocolLocked:
            HapticsService.shared.play(.warning)
            gameStateDelegate?.placementFailed(result)

        case .invalidSlot:
            HapticsService.shared.play(.warning)
        }
    }

    func upgradeTower(_ towerId: String) {
        guard var state = state else { return }

        let result = TowerSystem.upgradeTower(state: &state, towerId: towerId)

        if result.success {
            self.state = state
            gameStateDelegate?.gameStateUpdated(state)

            // Persist the new level to player profile
            if let protocolId = result.protocolId, let newLevel = result.newLevel {
                AppState.shared.updatePlayer { profile in
                    profile.protocolLevels[protocolId] = newLevel
                }
            }

            // Persist session
            StorageService.shared.saveTDSession(TDSessionState.from(gameState: state))
        }
    }

    func sellTower(_ towerId: String) {
        guard var state = state else { return }

        _ = TowerSystem.sellTower(state: &state, towerId: towerId)
        selectedTowerId = nil

        self.state = state
        gameStateDelegate?.gameStateUpdated(state)

        // Persist sale
        StorageService.shared.saveTDSession(TDSessionState.from(gameState: state))
    }

    // MARK: - Blocker Actions

    /// Place a blocker at a slot
    func placeBlocker(slotId: String) {
        guard var state = state else { return }

        let result = BlockerSystem.placeBlocker(state: &state, slotId: slotId)

        if case .success = result {
            self.state = state
            setupBlockers()  // Refresh blocker visuals
            setupPaths()     // Refresh paths (they may have changed)
            gameStateDelegate?.gameStateUpdated(state)
            HapticsService.shared.play(.medium)
        } else {
            HapticsService.shared.play(.warning)
        }
    }

    /// Remove a blocker
    func removeBlocker(blockerId: String) {
        guard var state = state else { return }

        BlockerSystem.removeBlocker(state: &state, blockerId: blockerId)

        self.state = state
        setupBlockers()
        setupPaths()
        gameStateDelegate?.gameStateUpdated(state)
        HapticsService.shared.play(.light)
    }

    /// Move a blocker to a new slot
    func moveBlocker(blockerId: String, toSlotId: String) {
        guard var state = state else { return }

        let result = BlockerSystem.moveBlocker(state: &state, blockerId: blockerId, toSlotId: toSlotId)

        if case .success = result {
            self.state = state
            setupBlockers()
            setupPaths()
            gameStateDelegate?.gameStateUpdated(state)
            HapticsService.shared.play(.medium)
        } else {
            HapticsService.shared.play(.warning)
        }
    }

    /// Check if a blocker can be placed at a slot
    func canPlaceBlockerAt(slotId: String) -> Bool {
        guard let state = state else { return false }
        return BlockerSystem.canPlaceBlockerAt(state: state, slotId: slotId)
    }

    /// Get preview of paths if blocker is placed
    func previewBlockerPaths(slotId: String) -> [EnemyPath]? {
        guard let state = state else { return nil }
        return BlockerSystem.previewPathsWithBlocker(state: state, slotId: slotId)
    }

}
