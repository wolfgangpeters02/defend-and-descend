import SwiftUI

// MARK: - Upgrades View (UPGRADES Tab)

struct UpgradesView: View {
    @ObservedObject var appState = AppState.shared

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(L10n.SystemUpgrades.title)
                    .font(DesignTypography.display(28))
                    .foregroundColor(.white)

                Spacer()

                // Hash (Ħ) balance
                HStack(spacing: 6) {
                    Image(systemName: "number.circle.fill")
                        .foregroundColor(DesignColors.primary)
                    Text("\(appState.currentPlayer.hash)")
                        .font(DesignTypography.headline(18))
                        .foregroundColor(DesignColors.primary)
                }
            }
            .padding()

            ScrollView {
                VStack(spacing: 16) {
                    ForEach(UpgradeableComponent.allCases) { component in
                        if appState.currentPlayer.unlockedComponents.isUnlocked(component) {
                            UpgradeCard(component: component)
                        }
                    }
                }
                .padding()
            }
        }
    }
}

// MARK: - Upgrade Card

struct UpgradeCard: View {
    let component: UpgradeableComponent
    @ObservedObject var appState = AppState.shared

    private var levels: ComponentLevels {
        appState.currentPlayer.componentLevels
    }

    private var level: Int {
        levels[component]
    }

    private var cost: Int? {
        levels.upgradeCost(for: component)
    }

    private var isMaxed: Bool {
        !levels.canUpgrade(component)
    }

    private var canAfford: Bool {
        guard let c = cost else { return false }
        return appState.currentPlayer.hash >= c
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: component.sfSymbol)
                    .font(.system(size: 28))
                    .foregroundColor(Color(hex: component.color) ?? .cyan)

                VStack(alignment: .leading, spacing: 2) {
                    Text(component.displayName)
                        .font(DesignTypography.headline(18))
                        .foregroundColor(.white)

                    Text(component.effectDescription)
                        .font(DesignTypography.caption(12))
                        .foregroundColor(DesignColors.muted)
                }

                Spacer()

                Text(L10n.Common.lv(level))
                    .font(DesignTypography.headline(20))
                    .foregroundColor(Color(hex: component.color) ?? .cyan)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(DesignColors.muted.opacity(0.3))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: component.color) ?? .cyan)
                        .frame(width: geo.size.width * (CGFloat(level) / CGFloat(ComponentLevels.maxLevel)))
                }
            }
            .frame(height: 8)

            // Current value
            Text(component.effectValue(at: level))
                .font(DesignTypography.body(14))
                .foregroundColor(.white)

            // Upgrade button
            if isMaxed {
                Text(L10n.Common.maxLevel)
                    .font(DesignTypography.headline(16))
                    .foregroundColor(DesignColors.muted)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(DesignColors.surface)
                    .cornerRadius(8)
            } else if let upgradeCost = cost {
                Button {
                    performUpgrade()
                } label: {
                    HStack {
                        if let nextValue = nextValueDescription() {
                            Text(L10n.Common.next(nextValue))
                                .foregroundColor(.white)
                        }
                        Spacer()
                        Text("\(upgradeCost)⚡")
                            .foregroundColor(canAfford ? DesignColors.primary : DesignColors.danger)
                    }
                    .font(DesignTypography.headline(14))
                    .padding()
                    .background(DesignColors.surface)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(canAfford ? DesignColors.primary : DesignColors.muted, lineWidth: 1)
                    )
                }
                .disabled(!canAfford)
            }
        }
        .padding()
        .background(DesignColors.surface)
        .cornerRadius(16)
    }

    private func nextValueDescription() -> String? {
        guard level < ComponentLevels.maxLevel else { return nil }
        return component.effectValue(at: level + 1)
    }

    private func performUpgrade() {
        guard let upgradeCost = cost, canAfford else { return }
        HapticsService.shared.play(.medium)
        AnalyticsService.shared.trackComponentUpgraded(component: component.rawValue, fromLevel: level, toLevel: level + 1)
        appState.updatePlayer { profile in
            profile.hash -= upgradeCost
            profile.componentLevels.upgrade(component)
        }
    }
}
