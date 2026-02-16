import SwiftUI

// MARK: - Currency Info Sheet

struct CurrencyInfoSheet: View {
    let info: CurrencyInfoType
    var onPSUUpgraded: ((Int) -> Void)? = nil
    @ObservedObject var appState = AppState.shared
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(DesignColors.muted)
                }
            }
            .padding(.horizontal)

            // Icon and title
            VStack(spacing: 12) {
                Image(systemName: info.icon)
                    .font(.system(size: 48))
                    .foregroundColor(info.color)

                Text(info.title)
                    .font(DesignTypography.display(24))
                    .foregroundColor(.white)
            }

            // Description
            Text(info.description)
                .font(DesignTypography.body(14))
                .foregroundColor(DesignColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            // PSU Upgrade section (only for power info)
            if info == .power {
                psuUpgradeSection
            }

            Spacer()
        }
        .padding(.top, 20)
        .background(DesignColors.background)
        .presentationDetents([.height(info == .power ? 480 : 320)])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private var psuUpgradeSection: some View {
        let currentLevel = appState.currentPlayer.componentLevels.power
        let tierName = ComponentLevels.psuTierName(at: currentLevel)
        let currentCapacity = BalanceConfig.Components.psuCapacity(at: currentLevel)
        let nextCapacity = currentLevel < ComponentLevels.maxLevel ? BalanceConfig.Components.psuCapacity(at: currentLevel + 1) : nil
        let upgradeCost = appState.currentPlayer.componentLevels.upgradeCost(for: .power)
        let canAfford = upgradeCost != nil && appState.currentPlayer.hash >= upgradeCost!

        VStack(spacing: 16) {
            Divider()
                .background(DesignColors.muted.opacity(0.3))
                .padding(.horizontal)

            // Current PSU info
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.Currency.psuLevel)
                        .font(DesignTypography.caption(11))
                        .foregroundColor(DesignColors.muted)
                    Text("\(tierName) (\(currentCapacity)W)")
                        .font(DesignTypography.headline(16))
                        .foregroundColor(.yellow)
                }

                Spacer()

                if let nextCap = nextCapacity {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(L10n.Currency.nextLevel)
                            .font(DesignTypography.caption(11))
                            .foregroundColor(DesignColors.muted)
                        Text("\(nextCap)W")
                            .font(DesignTypography.headline(16))
                            .foregroundColor(.green)
                    }
                }
            }
            .padding(.horizontal, 24)

            // Upgrade button
            if let cost = upgradeCost {
                Button {
                    upgradePSU()
                } label: {
                    HStack {
                        Image(systemName: "bolt.badge.plus.fill")
                        Text(L10n.Currency.upgradePSU)
                        Spacer()
                        Text("Ħ \(cost)")
                            .font(DesignTypography.headline(14))
                    }
                    .font(DesignTypography.headline(14))
                    .foregroundColor(canAfford ? .black : DesignColors.muted)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(canAfford ? Color.yellow : DesignColors.surface)
                    .cornerRadius(12)
                }
                .disabled(!canAfford)
                .padding(.horizontal, 24)
            } else {
                Text(L10n.Currency.psuMaxed)
                    .font(DesignTypography.headline(14))
                    .foregroundColor(.green)
                    .padding(.horizontal, 24)
            }
        }
    }

    private func upgradePSU() {
        guard let cost = appState.currentPlayer.componentLevels.upgradeCost(for: .power),
              appState.currentPlayer.hash >= cost else { return }

        HapticsService.shared.play(.success)
        appState.updatePlayer { profile in
            profile.hash -= cost
            profile.componentLevels.upgrade(.power)
        }
        onPSUUpgraded?(cost)
    }
}
