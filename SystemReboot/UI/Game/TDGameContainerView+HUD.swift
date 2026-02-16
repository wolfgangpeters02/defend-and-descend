import SwiftUI

// MARK: - TDGameContainerView HUD
// Top bar, wave controls, CPU upgrade section

extension TDGameContainerView {

    // MARK: - Top Bar (Simplified HUD)
    // Clean, minimal HUD with only essential info

    var topBar: some View {
        VStack(spacing: 4) {
            // Row 1: Pause + Wave | Efficiency
            HStack(spacing: 10) {
                Button(action: {
                    isPaused = true
                    HapticsService.shared.play(.light)
                }) {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(8)
                }

                Text(L10n.Game.HUD.wave(gameState?.currentWave ?? 0))
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Spacer()

                HStack(spacing: 6) {
                    let efficiency = calculateEfficiency()
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(DesignColors.muted.opacity(0.3))
                            RoundedRectangle(cornerRadius: 4)
                                .fill(efficiencyColor)
                                .frame(width: geo.size.width * efficiency / 100)
                        }
                    }
                    .frame(width: 80, height: 10)

                    Text("\(Int(calculateEfficiency()))%")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(efficiencyColor)
                        .lineLimit(1)
                }
            }

            // Row 2: Power | Hash
            HStack {
                // Power usage (PSU capacity)
                HStack(spacing: 3) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 14))
                        .foregroundColor(powerColor)
                    Text("\(gameState?.powerUsed ?? 0)/\(gameState?.powerCapacity ?? 300)W")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(powerColor)
                        .lineLimit(1)
                }

                Spacer()

                // Hash balance with storage cap
                HStack(spacing: 3) {
                    Image(systemName: "number.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.cyan)
                    Text(NumberFormatUtils.hashWithCap(
                        current: gameState?.hash ?? 0,
                        max: gameState?.hashStorageCapacity ?? 25000
                    ))
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.7))
    }

    // MARK: - Wave Controls (Auto-start, no manual button needed)
    // Waves auto-start - this view just shows current wave status

    private var waveControls: some View {
        EmptyView()  // No manual controls needed - waves auto-start
    }

    // MARK: - CPU Upgrade Section

    var cpuUpgradeSection: some View {
        let cpuInfo = StorageService.shared.getCpuTierInfo()
        let canUpgrade = cpuInfo.nextCost != nil && appState.currentPlayer.hash >= (cpuInfo.nextCost ?? 0)

        return VStack(spacing: 12) {
            // Current CPU info
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.CPU.tier)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(DesignColors.textSecondary)
                    HStack(spacing: 4) {
                        Image(systemName: "cpu")
                            .font(DesignTypography.headline(22))
                        Text("\(cpuInfo.tier).0")
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                    }
                    .foregroundColor(.cyan)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.CPU.multiplier)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(DesignColors.textSecondary)
                    Text("\(String(format: "%.0f", cpuInfo.multiplier))x")
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(.green)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(L10n.CPU.watts)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(DesignColors.textSecondary)
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                        Text("\(appState.currentPlayer.hash)")
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                    }
                    .foregroundColor(.cyan)
                }
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)

            // Upgrade button (if not max tier)
            if let upgradeCost = cpuInfo.nextCost {
                Button(action: {
                    upgradeCpu()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.up.circle.fill")
                        Text(L10n.CPU.upgradeTo(cpuInfo.tier + 1))
                        Spacer()
                        Text("Ħ\(upgradeCost)")
                            .fontWeight(.bold)
                    }
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(canUpgrade ? .black : DesignColors.textSecondary)
                    .padding()
                    .background(canUpgrade ? DesignColors.primary : DesignColors.muted.opacity(0.3))
                    .cornerRadius(10)
                }
                .disabled(!canUpgrade)
            } else {
                Text(L10n.CPU.maxTier)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.yellow)
                    .padding()
                    .background(Color.yellow.opacity(0.2))
                    .cornerRadius(10)
            }
        }
        .frame(width: 280)
    }

    // MARK: - CPU Upgrade Action

    private func upgradeCpu() {
        // Use ComponentLevels system for CPU upgrades
        let profile = appState.currentPlayer
        guard let cost = profile.componentLevels.upgradeCost(for: .cpu),
              profile.hash >= cost else {
            HapticsService.shared.play(.warning)
            return
        }

        // Deduct cost and apply upgrade
        var updatedProfile = profile
        updatedProfile.hash -= cost
        updatedProfile.componentLevels.upgrade(.cpu)
        StorageService.shared.savePlayer(updatedProfile)
        appState.refreshPlayer()

        // Update game state's Hash generation
        if var state = gameState {
            state.baseHashPerSecond = appState.currentPlayer.componentLevels.hashPerSecond
            state.cpuMultiplier = appState.currentPlayer.tdStats.cpuMultiplier
            state.cpuTier = appState.currentPlayer.componentLevels.cpu
            state.networkHashMultiplier = appState.currentPlayer.componentLevels.hashMultiplier
            gameState = state
        }

        HapticsService.shared.play(.success)
    }
}
