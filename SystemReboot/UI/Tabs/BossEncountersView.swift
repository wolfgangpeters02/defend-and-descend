import SwiftUI

// MARK: - Boss Encounters View

struct BossEncountersView: View {
    @ObservedObject var appState = AppState.shared
    @Binding var selectedDifficulty: BossDifficulty
    let onLaunch: (BossEncounter) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.Boss.encounters)
                        .font(DesignTypography.display(28))
                        .foregroundColor(.white)
                    Text(L10n.Boss.encountersDesc)
                        .font(DesignTypography.caption(12))
                        .foregroundColor(DesignColors.muted)
                }

                Spacer()

                // Hash balance
                HStack(spacing: 6) {
                    Text("Ħ")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(DesignColors.primary)
                    Text("\(appState.currentPlayer.hash)")
                        .font(DesignTypography.headline(18))
                        .foregroundColor(DesignColors.primary)
                }
            }
            .padding()

            // Difficulty selector
            difficultySelector

            ScrollView {
                VStack(spacing: 16) {
                    ForEach(BossEncounter.all) { boss in
                        BossCard(
                            boss: boss,
                            difficulty: selectedDifficulty,
                            isUnlocked: isBossUnlocked(boss),
                            onSelect: { onLaunch(boss) },
                            onUnlock: { unlockBoss(boss) }
                        )
                    }
                }
                .padding()
            }
        }
    }

    private var difficultySelector: some View {
        HStack(spacing: 8) {
            ForEach(BossDifficulty.allCases, id: \.self) { difficulty in
                Button {
                    HapticsService.shared.play(.selection)
                    selectedDifficulty = difficulty
                } label: {
                    VStack(spacing: 4) {
                        Text(difficulty.rawValue.uppercased())
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                        Text(difficultyReward(difficulty))
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                    }
                    .foregroundColor(selectedDifficulty == difficulty ? .black : difficultyColor(difficulty))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        selectedDifficulty == difficulty ?
                            difficultyColor(difficulty) : difficultyColor(difficulty).opacity(0.2)
                    )
                    .cornerRadius(8)
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private func difficultyColor(_ difficulty: BossDifficulty) -> Color {
        switch difficulty {
        case .easy: return DesignColors.secondary
        case .normal: return DesignColors.success
        case .hard: return DesignColors.warning
        case .nightmare: return DesignColors.danger
        }
    }

    private func difficultyReward(_ difficulty: BossDifficulty) -> String {
        switch difficulty {
        case .easy: return "+Ħ250"
        case .normal: return "+Ħ500"
        case .hard: return "+Ħ1500"
        case .nightmare: return "+Ħ3000"
        }
    }

    private func isBossUnlocked(_ boss: BossEncounter) -> Bool {
        boss.unlockCost == 0 || appState.currentPlayer.hash >= boss.unlockCost ||
            appState.currentPlayer.survivorStats.bossesDefeated > 0
    }

    private func unlockBoss(_ boss: BossEncounter) {
        guard appState.currentPlayer.hash >= boss.unlockCost else { return }
        HapticsService.shared.play(.medium)
        // For now, bosses unlock by defeating the first one
    }
}

// MARK: - Boss Card

struct BossCard: View {
    let boss: BossEncounter
    let difficulty: BossDifficulty
    let isUnlocked: Bool
    let onSelect: () -> Void
    let onUnlock: () -> Void

    @ObservedObject var appState = AppState.shared

    var body: some View {
        Button(action: isUnlocked ? onSelect : onUnlock) {
            HStack(spacing: 16) {
                // Boss icon
                ZStack {
                    Circle()
                        .fill(Color(hex: boss.color)?.opacity(0.2) ?? Color.red.opacity(0.2))
                        .frame(width: 60, height: 60)

                    Image(systemName: boss.iconName)
                        .font(.system(size: 28))
                        .foregroundColor(Color(hex: boss.color) ?? .red)
                }

                // Boss info
                VStack(alignment: .leading, spacing: 4) {
                    Text(boss.name)
                        .font(DesignTypography.headline(16))
                        .foregroundColor(isUnlocked ? .white : DesignColors.muted)

                    Text(boss.subtitle)
                        .font(DesignTypography.caption(11))
                        .foregroundColor(Color(hex: boss.color) ?? .red)

                    Text(boss.description)
                        .font(DesignTypography.caption(10))
                        .foregroundColor(DesignColors.muted)
                        .lineLimit(2)
                }

                Spacer()

                // Right side: Rewards or lock
                if isUnlocked {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(L10n.Common.rewards)
                            .font(DesignTypography.caption(8))
                            .foregroundColor(DesignColors.muted)

                        HStack(spacing: 4) {
                            ForEach(boss.rewards.prefix(2), id: \.self) { protocolId in
                                if let proto = ProtocolLibrary.get(protocolId) {
                                    Image(systemName: proto.iconName)
                                        .font(.system(size: 12))
                                        .foregroundColor(Color(hex: proto.color) ?? .cyan)
                                }
                            }
                        }

                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                            .foregroundColor(DesignColors.muted)
                    }
                } else {
                    VStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 20))
                            .foregroundColor(DesignColors.muted)

                        Text("Ħ\(boss.unlockCost)")
                            .font(DesignTypography.caption(10))
                            .foregroundColor(DesignColors.muted)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(DesignColors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isUnlocked ? Color(hex: boss.color)?.opacity(0.3) ?? Color.red.opacity(0.3) : Color.clear,
                                lineWidth: 1
                            )
                    )
            )
            .opacity(isUnlocked ? 1 : 0.6)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Boss Game View

struct BossGameView: View {
    let boss: BossEncounter
    let difficulty: BossDifficulty
    let `protocol`: Protocol
    let onExit: () -> Void
    var bossFightCoordinator: BossFightCoordinator? = nil

    @ObservedObject var appState = AppState.shared

    var body: some View {
        GameContainerView(
            gameMode: .boss,
            bossDifficulty: difficulty,
            onExit: onExit,
            onBossFightComplete: { _ in onExit() },
            bossFightCoordinator: bossFightCoordinator
        )
        .onAppear {
            // Set the boss type in AppState for GameContainerView to use
            appState.selectedArena = boss.bossId
        }
    }
}
