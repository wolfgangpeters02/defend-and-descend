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
        state.leakCounter = leakCount
        self.state = state
        gameStateDelegate?.gameStateUpdated(state)
    }

    /// Recover from System Freeze (0% efficiency state)
    /// Called when player chooses "Flush Memory" or completes "Manual Override"
    /// - Parameter restoreToEfficiency: Target efficiency (50 = 50%, i.e., leakCounter = 10)
    func recoverFromFreeze(restoreToEfficiency: CGFloat = BalanceConfig.Freeze.recoveryTargetEfficiency) {
        guard var state = state, state.isSystemFrozen else { return }

        // Clear freeze state
        state.isSystemFrozen = false

        // Restore efficiency (50% = leakCounter of 10)
        // efficiency = 100 - leakCounter * 5
        // leakCounter = (100 - targetEfficiency) / 5
        let targetLeakCount = Int((100 - restoreToEfficiency) / 5)
        state.leakCounter = max(0, targetLeakCount)

        // Clear all enemies that were on the field (system "rebooted")
        for i in 0..<state.enemies.count {
            state.enemies[i].isDead = true
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
                cpuBody.glowWidth = 15  // Reduced from 30 for performance
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
        ringNode.glowWidth = 8
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
                cpuBody.glowWidth = 20
            }
        }
        let wait = SKAction.wait(forDuration: 0.5)
        let sequence = SKAction.sequence([flashOrange, wait])
        let pulse = SKAction.repeat(sequence, count: 3)
        coreContainer.run(pulse)
    }

    // MARK: - Boss Fight Results

    /// Called when boss fight is won - handle rewards and state cleanup
    func onBossFightWon(districtId: String) {
        guard var state = state else { return }

        // Process the boss fight win through TDBossSystem
        let reward = TDBossSystem.onBossFightWon(state: &state, districtId: districtId)

        // Apply hash reward
        state.hash += reward.hashReward

        // Sync to profile
        if let delegate = gameStateDelegate {
            AppState.shared.updatePlayer { profile in
                profile.hash = state.hash
                // Record boss defeat for progression
                if !profile.defeatedDistrictBosses.contains(districtId) {
                    profile.defeatedDistrictBosses.append(districtId)
                }
            }
        }

        self.state = state
        gameStateDelegate?.gameStateUpdated(state)

        HapticsService.shared.play(.legendary)
    }

    /// Called when boss fight is lost and player lets boss pass
    func onBossFightLost() {
        guard var state = state else { return }

        TDBossSystem.onBossFightLostLetPass(state: &state)

        self.state = state
        gameStateDelegate?.gameStateUpdated(state)

        HapticsService.shared.play(.defeat)
    }

    func placeTower(weaponType: String, slotId: String, profile: PlayerProfile) {
        guard var state = state else {
            return
        }

        // Check if this is a Protocol ID (System: Reboot) or a legacy weapon type
        let result: TowerPlacementResult
        if ProtocolLibrary.get(weaponType) != nil {
            // Use Protocol-based placement
            result = TowerSystem.placeTowerFromProtocol(state: &state, protocolId: weaponType, slotId: slotId, playerProfile: profile)
        } else {
            // Legacy weapon placement
            result = TowerSystem.placeTower(state: &state, weaponType: weaponType, slotId: slotId, playerProfile: profile)
        }

        switch result {
        case .success(let tower):
            // Update slot visual
            if let slotIndex = state.towerSlots.firstIndex(where: { $0.id == slotId }) {
                updateSlotVisual(slot: state.towerSlots[slotIndex])
            }
            self.state = state
            gameStateDelegate?.gameStateUpdated(state)

            // Persist tower placement
            StorageService.shared.saveTDSession(TDSessionState.from(gameState: state))
            HapticsService.shared.play(.towerPlace)

        case .insufficientGold:
            HapticsService.shared.play(.warning)
            gameStateDelegate?.placementFailed(result)

        case .insufficientPower:
            HapticsService.shared.play(.warning)
            gameStateDelegate?.placementFailed(result)

        case .slotOccupied:
            HapticsService.shared.play(.warning)
            gameStateDelegate?.placementFailed(result)

        case .weaponLocked:
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

            // Blueprint-based: Persist the new level to player profile
            // Update BOTH protocolLevels (used for tower placement) and weaponLevels (legacy)
            if let weaponType = result.weaponType, let newLevel = result.newLevel {
                AppState.shared.updatePlayer { profile in
                    profile.protocolLevels[weaponType] = newLevel
                    profile.weaponLevels[weaponType] = newLevel  // Legacy support
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
