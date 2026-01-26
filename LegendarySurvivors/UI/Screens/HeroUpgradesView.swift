import SwiftUI

// MARK: - Hero Upgrades View
// System: Reboot - Upgrade hero stats with Watts currency
// Watts are earned in Idle/Motherboard mode

struct HeroUpgradesView: View {
    @EnvironmentObject var appState: AppState
    let onBack: () -> Void

    @State private var showUpgradeResult: UpgradeResult?

    enum UpgradeResult {
        case success(HeroUpgradeType)
        case insufficientWatts
    }

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color(red: 0.04, green: 0.08, blue: 0.12), Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                header

                // Currency display
                currencyBar

                // Upgrade list
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(HeroUpgradeType.allCases, id: \.self) { upgradeType in
                            HeroUpgradeCard(
                                upgradeType: upgradeType,
                                info: appState.heroUpgradeInfo(for: upgradeType),
                                onUpgrade: { upgradeHero(upgradeType) }
                            )
                        }
                    }
                    .padding()
                }

                // Hero stats summary
                heroStatsSummary
            }

            // Upgrade result toast
            if let result = showUpgradeResult {
                upgradeResultToast(result)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(10)
            }

            Spacer()

            VStack(spacing: 4) {
                Text("HERO UPGRADES")
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)
                Text("Enhance Debugger capabilities")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.gray)
            }

            Spacer()

            // Placeholder for symmetry
            Color.clear.frame(width: 44, height: 44)
        }
        .padding()
    }

    // MARK: - Currency Bar

    private var currencyBar: some View {
        HStack(spacing: 24) {
            // Watts balance
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill")
                    .font(.title2)
                    .foregroundColor(.cyan)
                VStack(alignment: .leading, spacing: 2) {
                    Text("WATTS")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.gray)
                    Text("\(appState.currentPlayer.gold)")
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)
                }
            }

            Spacer()

            // Hint
            Text("Earn Watts in Motherboard mode")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.black.opacity(0.5))
    }

    // MARK: - Hero Stats Summary

    private var heroStatsSummary: some View {
        let upgrades = appState.currentPlayer.heroUpgrades

        return VStack(spacing: 12) {
            Text("CURRENT BONUSES")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)

            HStack(spacing: 24) {
                HeroStatBadge(icon: "heart.fill", label: "HP", value: "+\(Int(upgrades.hpBonus))", color: .red)
                HeroStatBadge(icon: "flame.fill", label: "DMG", value: "+\(Int((upgrades.damageMultiplier - 1) * 100))%", color: .orange)
                HeroStatBadge(icon: "hare.fill", label: "SPD", value: "+\(Int((upgrades.speedMultiplier - 1) * 100))%", color: .green)
                HeroStatBadge(icon: "magnet", label: "RNG", value: "+\(Int((upgrades.pickupRangeMultiplier - 1) * 100))%", color: .purple)
            }
        }
        .padding()
        .background(Color.black.opacity(0.5))
    }

    // MARK: - Actions

    private func upgradeHero(_ type: HeroUpgradeType) {
        if appState.upgradeHeroStat(type) {
            showUpgradeResult = .success(type)
            HapticsService.shared.play(.success)
        } else {
            showUpgradeResult = .insufficientWatts
            HapticsService.shared.play(.warning)
        }

        // Clear result after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showUpgradeResult = nil
            }
        }
    }

    private func upgradeResultToast(_ result: UpgradeResult) -> some View {
        VStack {
            HStack(spacing: 12) {
                switch result {
                case .success(let type):
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("\(type.rawValue) UPGRADED!")
                        .foregroundColor(.green)
                case .insufficientWatts:
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                    Text("Not enough Watts")
                        .foregroundColor(.red)
                }
            }
            .font(.system(size: 16, weight: .bold, design: .monospaced))
            .padding()
            .background(Color.black.opacity(0.9))
            .cornerRadius(10)

            Spacer()
        }
        .padding(.top, 100)
    }
}

// MARK: - Hero Upgrade Card

struct HeroUpgradeCard: View {
    let upgradeType: HeroUpgradeType
    let info: (level: Int, cost: Int, canAfford: Bool, isMaxed: Bool)
    let onUpgrade: () -> Void

    private var iconColor: Color {
        switch upgradeType {
        case .maxHp: return .red
        case .damage: return .orange
        case .speed: return .green
        case .pickupRange: return .purple
        }
    }

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: upgradeType.icon)
                    .font(.title2)
                    .foregroundColor(iconColor)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(upgradeType.rawValue.uppercased())
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)

                Text(upgradeType.description)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.gray)

                // Level progress
                HStack(spacing: 4) {
                    Text("Level \(info.level)/\(HeroUpgrades.maxLevel)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.gray)

                    // Level dots
                    HStack(spacing: 2) {
                        ForEach(0..<HeroUpgrades.maxLevel, id: \.self) { i in
                            Circle()
                                .fill(i < info.level ? iconColor : Color.gray.opacity(0.3))
                                .frame(width: 6, height: 6)
                        }
                    }
                }
            }

            Spacer()

            // Upgrade button
            if info.isMaxed {
                Text("MAX")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.yellow)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.yellow.opacity(0.2))
                    .cornerRadius(8)
            } else {
                Button(action: onUpgrade) {
                    VStack(spacing: 2) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title3)
                        HStack(spacing: 2) {
                            Image(systemName: "bolt.fill")
                                .font(.caption2)
                            Text("\(info.cost)")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                        }
                    }
                    .foregroundColor(info.canAfford ? .cyan : .gray)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(info.canAfford ? Color.cyan.opacity(0.2) : Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(info.canAfford ? Color.cyan.opacity(0.5) : Color.gray.opacity(0.3), lineWidth: 1)
                    )
                }
                .disabled(!info.canAfford)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(iconColor.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Hero Stat Badge

struct HeroStatBadge: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.gray)
        }
    }
}

// MARK: - Preview

#Preview {
    HeroUpgradesView(onBack: {})
        .environmentObject(AppState.shared)
}
