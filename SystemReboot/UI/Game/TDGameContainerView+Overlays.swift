import SwiftUI

// MARK: - TDGameContainerView Overlays
// Boss alert, Boss difficulty selector, Overclock, System Freeze

extension TDGameContainerView {

    // MARK: - TD Boss Alert Overlay

    var bossAlertOverlay: some View {
        VStack {
            Spacer()

            // Alert banner at bottom of screen (above tower deck)
            VStack(spacing: 12) {
                // Warning header
                HStack(spacing: 8) {
                    Image(systemName: "bolt.shield.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.orange)

                    Text(L10n.Boss.superVirusDetected)
                        .font(.system(size: 18, weight: .black, design: .monospaced))
                        .foregroundColor(.orange)

                    Image(systemName: "bolt.shield.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.orange)
                }

                if let bossType = gameState?.activeBossType {
                    Text(bossType == "cyberboss" ? L10n.Boss.cyberboss : L10n.Boss.voidHarbinger)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }

                Text(L10n.Boss.immuneToFirewalls)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(DesignColors.textSecondary)

                Text(L10n.Boss.ignoreHint)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.red.opacity(0.8))

                // ENGAGE button
                Button(action: {
                    showBossDifficultySelector = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "person.fill.viewfinder")
                            .font(.system(size: 18, weight: .bold))
                        Text(L10n.Boss.engageTarget)
                            .font(.system(size: 16, weight: .black, design: .monospaced))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.orange)
                    )
                    .shadow(color: .orange.opacity(0.6), radius: 10)
                }
                .padding(.top, 4)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.95))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.orange.opacity(0.8), lineWidth: 2)
                    )
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 130) // Above tower deck
        }
    }

    // MARK: - Boss Difficulty Selector

    var bossDifficultySelectorOverlay: some View {
        ZStack {
            // Dim background
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    showBossDifficultySelector = false
                }

            // Modal
            VStack(spacing: 16) {
                Text(L10n.Boss.selectDifficulty)
                    .font(.system(size: 20, weight: .black, design: .monospaced))
                    .foregroundColor(.white)

                if let bossType = gameState?.activeBossType {
                    Text(bossType == "cyberboss" ? L10n.Boss.cyberboss : L10n.Boss.voidHarbinger)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.orange)
                }

                // Difficulty buttons
                ForEach(BossDifficulty.allCases, id: \.self) { difficulty in
                    difficultyButton(difficulty: difficulty)
                }

                // Cancel button
                Button(action: {
                    showBossDifficultySelector = false
                }) {
                    Text(L10n.Common.cancel)
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(DesignColors.textSecondary)
                        .padding(.vertical, 8)
                }
                .padding(.top, 8)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.95))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.orange.opacity(0.5), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 40)
        }
    }

    private func difficultyButton(difficulty: BossDifficulty) -> some View {
        Button(action: {
            selectedBossDifficulty = difficulty
            showBossDifficultySelector = false
            startBossFight(difficulty: difficulty)
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(difficulty.displayName)
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(difficultyColor(difficulty))

                    Text("\(difficulty.hashReward) Ħ")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(DesignColors.textSecondary)
                }

                Spacer()

                Text("\(String(format: "%.1f", difficulty.healthMultiplier))x HP")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(difficultyColor(difficulty).opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(difficultyColor(difficulty).opacity(0.5), lineWidth: 1)
                    )
            )
        }
    }

    private func difficultyColor(_ difficulty: BossDifficulty) -> Color {
        DesignHelpers.difficultyColor(difficulty)
    }

    private func startBossFight(difficulty: BossDifficulty) {
        guard var state = gameState else { return }

        // Engage the boss
        guard let engagement = TDBossSystem.engageBoss(state: &state, difficulty: difficulty) else {
            return
        }

        gameState = state
        bossCoordinator.currentBossSectorId = engagement.sectorId
        bossCoordinator.selectedBossDifficulty = difficulty
        bossCoordinator.activeBossType = state.activeBossType

        // Pause TD and transition to boss fight
        isPaused = true
        bossCoordinator.onFightStarted()
        bossCoordinator.showBossFight = true

        HapticsService.shared.play(.warning)
    }

    // MARK: - Overclock Button

    var overclockButton: some View {
        let canOverclock = gameState?.canOverclock ?? false
        let buttonColor: Color = canOverclock ? .orange : .gray

        return VStack {
            HStack {
                Spacer()

                Button(action: {
                    if canOverclock {
                        activateOverclock()
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "bolt.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(buttonColor)

                        Text(L10n.TD.overclock)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(buttonColor)

                        if !canOverclock, gameState?.bossActive == true {
                            Text(L10n.TD.bossActive)
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundColor(.red.opacity(0.7))
                        }
                    }
                    .padding(12)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.8))
                            .overlay(
                                Circle()
                                    .stroke(buttonColor.opacity(0.5), lineWidth: 2)
                            )
                    )
                }
                .padding(.trailing, 20)
            }
            .padding(.top, 60)

            Spacer()
        }
    }

    var overclockActiveIndicator: some View {
        VStack {
            HStack {
                Spacer()

                VStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.orange)

                    Text(L10n.TD.overclocking)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.orange)

                    if let state = gameState {
                        Text("\(Int(state.overclockTimeRemaining))s")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }

                    Text(L10n.TD.hashMultiplier)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.green)

                    Text(L10n.TD.threatMultiplier)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.red)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.9))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.orange, lineWidth: 2)
                        )
                )
                .padding(.trailing, 20)
            }

            Spacer()
        }
        .padding(.top, 100)
    }

    private func activateOverclock() {
        guard var state = gameState else { return }

        if OverclockSystem.activateOverclock(state: &state) {
            gameState = state
            HapticsService.shared.play(.heavy)
        }
    }

    // MARK: - System Freeze Overlay (0% Efficiency)

    var systemFreezeOverlay: some View {
        ZStack {
            // Dark overlay with scan line effect
            Color.black.opacity(0.95)
                .ignoresSafeArea()

            // Glitch-style lines (pre-computed to avoid non-deterministic rendering)
            VStack(spacing: 4) {
                ForEach(0..<50, id: \.self) { i in
                    let seed = Double(i)
                    Rectangle()
                        .fill(Color.red.opacity(0.05 + (seed.truncatingRemainder(dividingBy: 3)) * 0.05))
                        .frame(height: CGFloat(1 + Int(seed) % 3))
                }
            }
            .ignoresSafeArea()

            VStack(spacing: 24) {
                // Critical error header
                VStack(spacing: 12) {
                    Image(systemName: "xmark.octagon.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.red)

                    Text(L10n.Freeze.header)
                        .font(.system(size: 32, weight: .black, design: .monospaced))
                        .foregroundColor(.red)

                    Text(L10n.Freeze.criticalError)
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(DesignColors.textSecondary)

                    Text(L10n.Freeze.hashHalted)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.orange)
                }

                // Reboot options
                VStack(spacing: 16) {
                    Text(L10n.Freeze.selectReboot)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(DesignColors.textSecondary)

                    // Option 1: Flush Memory (Pay Hash)
                    let flushCost = FreezeRecoveryService.flushCost(currentHash: appState.currentPlayer.hash)
                    let canAffordFlush = FreezeRecoveryService.canAffordFlush(currentHash: appState.currentPlayer.hash)

                    Button(action: {
                        performFlushMemory(cost: flushCost)
                    }) {
                        VStack(spacing: 6) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 18, weight: .bold))
                                Text(L10n.Freeze.flushMemory)
                                    .font(.system(size: 16, weight: .black, design: .monospaced))
                            }

                            Text(L10n.Freeze.flushCost(flushCost))
                                .font(.system(size: 11, design: .monospaced))
                                .opacity(0.8)
                        }
                        .foregroundColor(canAffordFlush ? .black : DesignColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(canAffordFlush ? DesignColors.primary : DesignColors.muted.opacity(0.3))
                        )
                    }
                    .disabled(!canAffordFlush)

                    // Option 2: Manual Override (Survival mini-game)
                    Button(action: {
                        performManualOverrideReboot()
                    }) {
                        VStack(spacing: 6) {
                            HStack(spacing: 8) {
                                Image(systemName: "person.fill.viewfinder")
                                    .font(.system(size: 18, weight: .bold))
                                Text(L10n.Freeze.manualOverride)
                                    .font(.system(size: 16, weight: .black, design: .monospaced))
                            }

                            Text(L10n.Freeze.overrideSurvive)
                                .font(.system(size: 11, design: .monospaced))
                                .opacity(0.8)
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.green)
                        )
                    }
                }
                .padding(.horizontal, 40)
            }
        }
        .transition(.opacity)
    }

    private func performFlushMemory(cost: Int) {
        HapticsService.shared.play(.medium)

        // Deduct cost
        appState.updatePlayer { profile in
            profile.hash -= cost
        }

        // Restore efficiency to target via FreezeRecoveryService
        let targetLeakCount = FreezeRecoveryService.leakCountForEfficiency(BalanceConfig.Freeze.recoveryTargetEfficiency)
        scene?.restoreEfficiency(to: targetLeakCount)

        withAnimation {
            showSystemFreeze = false
        }
    }

    private func performManualOverrideReboot() {
        HapticsService.shared.play(.warning)
        isPerformingManualOverride = true

        // Restore efficiency to configured recovery level
        let targetLeakCount = FreezeRecoveryService.leakCountForEfficiency(BalanceConfig.Freeze.manualOverrideRecoveryEfficiency)
        scene?.restoreEfficiency(to: targetLeakCount)

        withAnimation {
            showSystemFreeze = false
            isPerformingManualOverride = false
        }

        HapticsService.shared.play(.success)
    }
}
