import SwiftUI

// MARK: - Upgrade Modal View

struct UpgradeModalView: View {
    let choices: [UpgradeChoice]
    let onSelect: (UpgradeChoice) -> Void

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                // Title
                Text("CHOOSE UPGRADE")
                    .font(.system(size: 28, weight: .black))
                    .foregroundColor(.cyan)

                Text("Level \(choices.isEmpty ? 1 : 1)")
                    .font(.caption)
                    .foregroundColor(.gray)

                // Upgrade choices
                HStack(spacing: 15) {
                    ForEach(choices) { choice in
                        UpgradeCardView(choice: choice) {
                            onSelect(choice)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Upgrade Card View

struct UpgradeCardView: View {
    let choice: UpgradeChoice
    let onTap: () -> Void

    private var rarityColor: Color {
        switch choice.rarity {
        case .common: return .gray
        case .rare: return .blue
        case .epic: return .purple
        case .legendary: return .yellow
        }
    }

    private var rarityGlow: Color {
        switch choice.rarity {
        case .legendary: return .yellow.opacity(0.5)
        case .epic: return .purple.opacity(0.4)
        case .rare: return .blue.opacity(0.3)
        default: return .clear
        }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // Rarity indicator
                Text(choice.rarity.rawValue.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(rarityColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(rarityColor.opacity(0.2))
                    )

                // Icon
                Text(choice.icon)
                    .font(.system(size: 40))

                // Name
                Text(choice.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                // Description
                Text(choice.description)
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .frame(height: 40)

                // Effect preview
                effectPreview
            }
            .frame(width: 140, height: 220)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(rarityColor, lineWidth: 2)
                    )
            )
            .shadow(color: rarityGlow, radius: 10)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var effectPreview: some View {
        Group {
            switch choice.effect.type {
            case .stat:
                HStack(spacing: 4) {
                    Image(systemName: statIcon(for: choice.effect.target))
                        .foregroundColor(.green)
                    Text(formatValue(choice.effect.value, isMultiplier: choice.effect.isMultiplier ?? false))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.green)
                }
            case .weapon:
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .foregroundColor(.orange)
                    Text(formatValue(choice.effect.value, isMultiplier: choice.effect.isMultiplier ?? false))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.orange)
                }
            case .ability:
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.purple)
                    Text("Special")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.purple)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.1))
        )
    }

    private func statIcon(for target: String) -> String {
        switch target {
        case "damage": return "flame.fill"
        case "maxHealth": return "heart.fill"
        case "speed": return "hare.fill"
        case "regen": return "cross.fill"
        case "armor": return "shield.fill"
        case "pickupRange": return "magnet"
        default: return "plus.circle.fill"
        }
    }

    private func formatValue(_ value: CGFloat, isMultiplier: Bool) -> String {
        if isMultiplier {
            let percent = Int((value - 1) * 100)
            return "+\(percent)%"
        } else {
            return "+\(Int(value))"
        }
    }
}

#Preview {
    UpgradeModalView(
        choices: [
            UpgradeChoice(
                id: "1",
                name: "Damage Boost",
                description: "Increase weapon damage",
                icon: "⚔️",
                rarity: .common,
                effect: UpgradeEffect(type: .stat, target: "damage", value: 1.2, isMultiplier: true)
            ),
            UpgradeChoice(
                id: "2",
                name: "Health Up",
                description: "Increase maximum health",
                icon: "❤️",
                rarity: .rare,
                effect: UpgradeEffect(type: .stat, target: "maxHealth", value: 25, isMultiplier: false)
            ),
            UpgradeChoice(
                id: "3",
                name: "Lifesteal",
                description: "Heal on hit",
                icon: "🧛",
                rarity: .epic,
                effect: UpgradeEffect(type: .ability, target: "lifesteal", value: 0.1, isMultiplier: false)
            )
        ],
        onSelect: { _ in }
    )
}
