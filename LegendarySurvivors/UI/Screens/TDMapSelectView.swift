import SwiftUI

// MARK: - TD Map Select View
// Map selection screen for Tower Defense mode

struct TDMapSelectView: View {
    @EnvironmentObject var appState: AppState

    let onStartGame: (String) -> Void
    let onBack: () -> Void

    @State private var selectedMap: String?

    init(onStartGame: @escaping (String) -> Void = { _ in }, onBack: @escaping () -> Void = {}) {
        self.onStartGame = onStartGame
        self.onBack = onBack
    }

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color.purple.opacity(0.8), Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                // Header
                headerView

                // Player info
                playerInfoCard

                // Map grid
                mapGrid

                Spacer()

                // Start button
                if let mapId = selectedMap {
                    startButton(mapId: mapId)
                }
            }
            .padding()
        }
    }

    // MARK: - Header

    private var headerView: some View {
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

            VStack {
                Text("TOWER DEFENSE")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text("Select a Map")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

            Spacer()

            // Placeholder for symmetry
            Color.clear
                .frame(width: 44, height: 44)
        }
    }

    // MARK: - Player Info

    private var playerInfoCard: some View {
        HStack(spacing: 20) {
            // Level
            VStack {
                Text("Level")
                    .font(.caption)
                    .foregroundColor(.gray)
                Text("\(appState.currentPlayer.level)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }

            Divider()
                .frame(height: 40)
                .background(Color.white.opacity(0.3))

            // TD Stats
            VStack {
                Text("TD Wins")
                    .font(.caption)
                    .foregroundColor(.gray)
                Text("\(appState.currentPlayer.tdStats.gamesWon)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
            }

            Divider()
                .frame(height: 40)
                .background(Color.white.opacity(0.3))

            // Best wave
            VStack {
                Text("Best Wave")
                    .font(.caption)
                    .foregroundColor(.gray)
                Text("\(appState.currentPlayer.tdStats.highestWave)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.yellow)
            }

            Divider()
                .frame(height: 40)
                .background(Color.white.opacity(0.3))

            // Gold
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
        .padding()
        .background(Color.black.opacity(0.4))
        .cornerRadius(15)
    }

    // MARK: - Map Grid

    private var mapGrid: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(getAvailableMaps(), id: \.id) { arena in
                    mapCard(arena: arena)
                }
            }
        }
    }

    private func mapCard(arena: ArenaConfig) -> some View {
        let isUnlocked = appState.currentPlayer.unlocks.arenas.contains(arena.id)
        let isSelected = selectedMap == arena.id

        return Button(action: {
            if isUnlocked {
                selectedMap = arena.id
            }
        }) {
            VStack(spacing: 8) {
                // Map preview
                ZStack {
                    Rectangle()
                        .fill(Color(hex: arena.backgroundColor) ?? Color.gray)
                        .aspectRatio(4/3, contentMode: .fit)
                        .cornerRadius(10)

                    if !isUnlocked {
                        Color.black.opacity(0.6)
                            .cornerRadius(10)
                        Image(systemName: "lock.fill")
                            .font(.title)
                            .foregroundColor(.white)
                    }
                }

                // Map name
                Text(arena.name)
                    .font(.headline)
                    .foregroundColor(isUnlocked ? .white : .gray)

                // Rarity badge
                Text(arena.rarity.capitalized)
                    .font(.caption)
                    .foregroundColor(rarityColor(arena.rarity))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(rarityColor(arena.rarity).opacity(0.2))
                    .cornerRadius(4)

                // Path count (TD-specific)
                if let pathCount = getPathCount(for: arena.id) {
                    Text("\(pathCount) Path\(pathCount > 1 ? "s" : "")")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.black.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(isSelected ? Color.yellow : Color.clear, lineWidth: 3)
                    )
            )
            .opacity(isUnlocked ? 1 : 0.6)
        }
        .disabled(!isUnlocked)
    }

    // MARK: - Start Button

    private func startButton(mapId: String) -> some View {
        Button(action: {
            onStartGame(mapId)
        }) {
            HStack {
                Image(systemName: "play.fill")
                Text("Start Defense")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.green)
            .cornerRadius(15)
        }
    }

    // MARK: - Helpers

    private func getAvailableMaps() -> [ArenaConfig] {
        let config = GameConfigLoader.shared
        guard let arenas = config.config?.arenas else { return [] }

        // Filter to maps that support TD (have paths defined)
        return arenas.values
            .filter { shouldShowInTD($0.id) }
            .sorted { rarityOrder($0.rarity) < rarityOrder($1.rarity) }
    }

    private func shouldShowInTD(_ mapId: String) -> Bool {
        // Maps that have TD path configurations
        let tdMaps = ["grasslands", "volcano", "ice_cave", "castle", "space", "temple"]
        return tdMaps.contains(mapId)
    }

    private func getPathCount(for mapId: String) -> Int? {
        // Get path count from TDConfig
        switch mapId {
        case "grasslands", "ice_cave", "space", "temple": return 1
        case "volcano": return 2
        case "castle": return 3
        default: return nil
        }
    }

    private func rarityColor(_ rarity: String) -> Color {
        switch rarity {
        case "common": return .gray
        case "rare": return .blue
        case "epic": return .purple
        case "legendary": return .orange
        default: return .gray
        }
    }

    private func rarityOrder(_ rarity: String) -> Int {
        switch rarity {
        case "common": return 0
        case "rare": return 1
        case "epic": return 2
        case "legendary": return 3
        default: return 4
        }
    }
}

// MARK: - Color Extension

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Preview

struct TDMapSelectView_Previews: PreviewProvider {
    static var previews: some View {
        TDMapSelectView(
            onStartGame: { _ in },
            onBack: {}
        )
        .environmentObject(AppState.shared)
    }
}
