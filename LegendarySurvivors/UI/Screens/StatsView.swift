import SwiftUI

// MARK: - Stats View

struct StatsView: View {
    @ObservedObject var appState = AppState.shared
    let onBack: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 20) {
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

                    Text("STATISTICS")
                        .font(.system(size: 24, weight: .black))
                        .foregroundColor(.cyan)

                    Spacer()

                    // Placeholder for symmetry
                    Image(systemName: "chevron.left")
                        .opacity(0)
                }
                .padding(.horizontal)

                ScrollView {
                    VStack(spacing: 20) {
                        // Player info with unified progression
                        VStack(spacing: 12) {
                            Text(appState.currentPlayer.displayName)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)

                            // Level and XP
                            HStack(spacing: 20) {
                                VStack {
                                    Text("Level")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Text("\(appState.currentPlayer.level)")
                                        .font(.title)
                                        .fontWeight(.bold)
                                        .foregroundColor(.cyan)
                                }

                                VStack {
                                    Text("XP")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Text("\(appState.currentPlayer.xp)/\(PlayerProfile.xpForLevel(appState.currentPlayer.level))")
                                        .font(.subheadline)
                                        .foregroundColor(.white)
                                }

                                VStack {
                                    Text("Gold")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Text("\(appState.currentPlayer.gold)")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.yellow)
                                }
                            }

                            Text("Playing since \(formattedDate)")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.05))
                        )
                        .padding(.horizontal)

                        // Global stats
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                            StatCard(
                                icon: "gamecontroller.fill",
                                value: "\(appState.currentPlayer.totalRuns)",
                                label: "Total Runs",
                                color: .cyan
                            )

                            StatCard(
                                icon: "flame.fill",
                                value: formatNumber(appState.currentPlayer.totalKills),
                                label: "Total Kills",
                                color: .orange
                            )
                        }
                        .padding(.horizontal)

                        // Survivor Mode Stats
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "figure.run")
                                    .foregroundColor(.green)
                                Text("SURVIVOR MODE")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.green)
                            }

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                MiniStatCard(
                                    value: "\(appState.currentPlayer.survivorStats.arenaRuns)",
                                    label: "Arena Runs",
                                    color: .green
                                )
                                MiniStatCard(
                                    value: "\(appState.currentPlayer.survivorStats.dungeonRuns)",
                                    label: "Dungeon Runs",
                                    color: .green
                                )
                                MiniStatCard(
                                    value: "\(appState.currentPlayer.survivorStats.dungeonsCompleted)",
                                    label: "Dungeons Won",
                                    color: .green
                                )
                                MiniStatCard(
                                    value: formatTime(appState.currentPlayer.survivorStats.longestSurvival),
                                    label: "Longest Survival",
                                    color: .green
                                )
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.green.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal)

                        // Tower Defense Mode Stats
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "building.columns.fill")
                                    .foregroundColor(.purple)
                                Text("TOWER DEFENSE MODE")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.purple)
                            }

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                MiniStatCard(
                                    value: "\(appState.currentPlayer.tdStats.gamesPlayed)",
                                    label: "Games Played",
                                    color: .purple
                                )
                                MiniStatCard(
                                    value: "\(appState.currentPlayer.tdStats.gamesWon)",
                                    label: "Games Won",
                                    color: .purple
                                )
                                MiniStatCard(
                                    value: "\(appState.currentPlayer.tdStats.highestWave)",
                                    label: "Best Wave",
                                    color: .purple
                                )
                                MiniStatCard(
                                    value: "\(appState.currentPlayer.tdStats.totalTowersPlaced)",
                                    label: "Towers Placed",
                                    color: .purple
                                )
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.purple.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal)

                        // Collection progress
                        VStack(alignment: .leading, spacing: 12) {
                            Text("COLLECTION PROGRESS")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.gray)

                            CollectionProgressRow(
                                category: "Weapons",
                                unlocked: appState.currentPlayer.unlocks.weapons.count,
                                total: GameConfigLoader.shared.config?.weapons.count ?? 0,
                                color: .red
                            )

                            CollectionProgressRow(
                                category: "Powerups",
                                unlocked: appState.currentPlayer.unlocks.powerups.count,
                                total: GameConfigLoader.shared.config?.powerups.count ?? 0,
                                color: .purple
                            )

                            CollectionProgressRow(
                                category: "Arenas",
                                unlocked: appState.currentPlayer.unlocks.arenas.count,
                                total: GameConfigLoader.shared.config?.arenas.count ?? 0,
                                color: .blue
                            )
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.05))
                        )
                        .padding(.horizontal)

                        // Mastery levels
                        VStack(alignment: .leading, spacing: 12) {
                            Text("TOP MASTERY LEVELS")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.gray)

                            ForEach(topMasteryItems.prefix(5), id: \.id) { item in
                                HStack {
                                    Text(item.name)
                                        .foregroundColor(.white)
                                        .font(.system(size: 14))

                                    Spacer()

                                    Text("Lv.\(item.level)")
                                        .foregroundColor(.cyan)
                                        .font(.system(size: 14, weight: .bold))

                                    // Level bar
                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            Rectangle()
                                                .fill(Color.gray.opacity(0.3))
                                            Rectangle()
                                                .fill(Color.cyan)
                                                .frame(width: geo.size.width * CGFloat(item.level) / 20.0)
                                        }
                                    }
                                    .frame(width: 60, height: 4)
                                    .cornerRadius(2)
                                }
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.05))
                        )
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 30)
                }
            }
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        if let date = ISO8601DateFormatter().date(from: appState.currentPlayer.createdAt) {
            return formatter.string(from: date)
        }
        return "Unknown"
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    private func formatNumber(_ number: Int) -> String {
        if number >= 1000000 {
            return String(format: "%.1fM", Double(number) / 1000000)
        } else if number >= 1000 {
            return String(format: "%.1fK", Double(number) / 1000)
        }
        return "\(number)"
    }

    private var topMasteryItems: [(id: String, name: String, level: Int)] {
        var items: [(id: String, name: String, level: Int)] = []

        for (id, level) in appState.currentPlayer.weaponLevels {
            if let config = GameConfigLoader.shared.getWeapon(id) {
                items.append((id: id, name: config.name, level: level))
            }
        }

        for (id, level) in appState.currentPlayer.powerupLevels {
            if let config = GameConfigLoader.shared.getPowerUp(id) {
                items.append((id: id, name: config.name, level: level))
            }
        }

        return items.sorted { $0.level > $1.level }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)

            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Mini Stat Card

struct MiniStatCard: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)

            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.gray)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.1))
        )
    }
}

// MARK: - Collection Progress Row

struct CollectionProgressRow: View {
    let category: String
    let unlocked: Int
    let total: Int
    let color: Color

    private var progress: CGFloat {
        guard total > 0 else { return 0 }
        return CGFloat(unlocked) / CGFloat(total)
    }

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(category)
                    .font(.system(size: 14))
                    .foregroundColor(.white)

                Spacer()

                Text("\(unlocked)/\(total)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(color)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                    Rectangle()
                        .fill(color)
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 6)
            .cornerRadius(3)
        }
    }
}

#Preview {
    StatsView(onBack: {})
}
