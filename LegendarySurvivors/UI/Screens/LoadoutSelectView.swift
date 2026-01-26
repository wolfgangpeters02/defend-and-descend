import SwiftUI

// MARK: - Loadout Select View (Slot Machine)

struct LoadoutSelectView: View {
    @ObservedObject var appState = AppState.shared
    let onStartRun: (GameMode) -> Void
    let onBack: () -> Void

    @State private var weaponFlip = false
    @State private var powerupFlip = false
    @State private var arenaFlip = false

    var body: some View {
        GeometryReader { geometry in
            let isPortrait = geometry.size.height > geometry.size.width

            ZStack {
                // Background
                Color.black.ignoresSafeArea()

                VStack(spacing: isPortrait ? 20 : 15) {
                    // Header
                    HStack {
                        Button(action: {
                            HapticsService.shared.play(.light)
                            onBack()
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.title2)
                                .foregroundColor(.white)
                        }

                        Spacer()

                        Text("LOADOUT")
                            .font(.system(size: 24, weight: .black))
                            .foregroundColor(.cyan)

                        Spacer()

                        // Placeholder for symmetry
                        Image(systemName: "chevron.left")
                            .opacity(0)
                    }
                    .padding(.horizontal)

                    // Synergy indicator
                    if let synergy = appState.currentSynergy {
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundColor(.yellow)
                            Text(synergy.name)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.yellow)
                            Text("- \(synergy.description)")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.yellow.opacity(0.1))
                                .overlay(Capsule().stroke(Color.yellow.opacity(0.3), lineWidth: 1))
                        )
                    }

                    // Selectors
                    if isPortrait {
                        VStack(spacing: 20) {
                            loadoutSelector(
                                title: "WEAPON",
                                items: appState.unlockedWeapons,
                                selected: appState.selectedWeapon,
                                onPrev: { withAnimation(.spring(response: 0.3)) { appState.selectPreviousWeapon() } },
                                onNext: { withAnimation(.spring(response: 0.3)) { appState.selectNextWeapon() } },
                                getConfig: { GameConfigLoader.shared.getWeapon($0) },
                                level: appState.weaponLevel(for: appState.selectedWeapon)
                            )

                            loadoutSelector(
                                title: "POWERUP",
                                items: appState.unlockedPowerups,
                                selected: appState.selectedPowerup,
                                onPrev: { withAnimation(.spring(response: 0.3)) { appState.selectPreviousPowerup() } },
                                onNext: { withAnimation(.spring(response: 0.3)) { appState.selectNextPowerup() } },
                                getConfig: { id in
                                    if let config = GameConfigLoader.shared.getPowerUp(id) {
                                        return (name: config.name, rarity: config.rarity, icon: config.icon, description: config.description)
                                    }
                                    return nil
                                },
                                level: appState.powerupLevel(for: appState.selectedPowerup)
                            )

                            loadoutSelector(
                                title: "ARENA",
                                items: appState.unlockedArenas,
                                selected: appState.selectedArena,
                                onPrev: { withAnimation(.spring(response: 0.3)) { appState.selectPreviousArena() } },
                                onNext: { withAnimation(.spring(response: 0.3)) { appState.selectNextArena() } },
                                getConfig: { id in
                                    if let config = GameConfigLoader.shared.getArena(id) {
                                        return (name: config.name, rarity: config.rarity, icon: "🏟️", description: "")
                                    }
                                    return nil
                                },
                                level: nil
                            )
                        }
                    } else {
                        HStack(spacing: 15) {
                            // Compact landscape layout
                            compactSelector(title: "WEAPON", id: appState.selectedWeapon, onPrev: appState.selectPreviousWeapon, onNext: appState.selectNextWeapon)
                            compactSelector(title: "POWERUP", id: appState.selectedPowerup, onPrev: appState.selectPreviousPowerup, onNext: appState.selectNextPowerup)
                            compactSelector(title: "ARENA", id: appState.selectedArena, onPrev: appState.selectPreviousArena, onNext: appState.selectNextArena)
                        }
                        .padding(.horizontal)
                    }

                    Spacer()

                    // Start buttons
                    VStack(spacing: 12) {
                        Button(action: {
                            HapticsService.shared.play(.medium)
                            onStartRun(.arena)
                        }) {
                            HStack {
                                Image(systemName: "infinity")
                                Text("ARENA MODE")
                            }
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.black)
                            .frame(maxWidth: 300)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.cyan)
                            )
                        }

                        Button(action: {
                            HapticsService.shared.play(.medium)
                            onStartRun(.dungeon)
                        }) {
                            HStack {
                                Image(systemName: "door.left.hand.closed")
                                Text("DUNGEON MODE")
                            }
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.purple)
                            .frame(maxWidth: 300)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.purple, lineWidth: 2)
                            )
                        }
                    }
                    .padding(.bottom, 30)
                }
            }
        }
    }

    // MARK: - Loadout Selector

    private func loadoutSelector<T>(
        title: String,
        items: [String],
        selected: String,
        onPrev: @escaping () -> Void,
        onNext: @escaping () -> Void,
        getConfig: (String) -> T?,
        level: Int?
    ) -> some View where T: Any {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.gray)

            HStack(spacing: 20) {
                Button(action: {
                    HapticsService.shared.play(.selection)
                    onPrev()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(.white)
                }

                // Card
                VStack(spacing: 8) {
                    Text(selected.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)

                    if let lvl = level {
                        Text("Lv. \(lvl)")
                            .font(.system(size: 12))
                            .foregroundColor(.cyan)
                    }
                }
                .frame(width: 150, height: 80)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                        )
                )

                Button(action: {
                    HapticsService.shared.play(.selection)
                    onNext()
                }) {
                    Image(systemName: "chevron.right")
                        .font(.title2)
                        .foregroundColor(.white)
                }
            }

            // Counter
            if let index = items.firstIndex(of: selected) {
                Text("\(index + 1)/\(items.count)")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }
        }
    }

    private func compactSelector(title: String, id: String, onPrev: @escaping () -> Void, onNext: @escaping () -> Void) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.gray)

            HStack(spacing: 8) {
                Button(action: onPrev) {
                    Image(systemName: "chevron.left")
                        .font(.caption)
                        .foregroundColor(.white)
                }

                Text(id.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 80)

                Button(action: onNext) {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.white)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.1))
            )
        }
    }
}

#Preview {
    LoadoutSelectView(
        onStartRun: { _ in },
        onBack: {}
    )
}
