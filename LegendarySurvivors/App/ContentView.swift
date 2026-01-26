import SwiftUI

// MARK: - App Navigation State

enum AppScreen: Equatable {
    case mainMenu
    case modeSelect      // Choose Survivor or TD
    case loadout         // Survivor loadout
    case tdMapSelect     // TD map selection
    case collection
    case stats
    case playingSurvivor(GameMode)
    case playingTD(String)  // Map ID

    static func == (lhs: AppScreen, rhs: AppScreen) -> Bool {
        switch (lhs, rhs) {
        case (.mainMenu, .mainMenu): return true
        case (.modeSelect, .modeSelect): return true
        case (.loadout, .loadout): return true
        case (.tdMapSelect, .tdMapSelect): return true
        case (.collection, .collection): return true
        case (.stats, .stats): return true
        case (.playingSurvivor(let a), .playingSurvivor(let b)): return a == b
        case (.playingTD(let a), .playingTD(let b)): return a == b
        default: return false
        }
    }
}

// MARK: - Content View

struct ContentView: View {
    @StateObject private var appState = AppState.shared
    @State private var currentScreen: AppScreen = .mainMenu

    var body: some View {
        ZStack {
            switch currentScreen {
            case .mainMenu:
                MainMenuView(
                    onPlay: { currentScreen = .modeSelect },
                    onCollection: { currentScreen = .collection },
                    onStats: { currentScreen = .stats }
                )
                .transition(.opacity)

            case .modeSelect:
                ModeSelectView(
                    onSelectSurvivor: { currentScreen = .loadout },
                    onSelectTD: { currentScreen = .tdMapSelect },
                    onBack: { currentScreen = .mainMenu }
                )
                .transition(.move(edge: .trailing))

            case .loadout:
                LoadoutSelectView(
                    onStartRun: { mode in
                        currentScreen = .playingSurvivor(mode)
                    },
                    onBack: { currentScreen = .modeSelect }
                )
                .transition(.move(edge: .trailing))

            case .tdMapSelect:
                TDMapSelectView(
                    onStartGame: { mapId in
                        currentScreen = .playingTD(mapId)
                    },
                    onBack: { currentScreen = .modeSelect }
                )
                .environmentObject(appState)
                .transition(.move(edge: .trailing))

            case .collection:
                CollectionView(
                    onBack: { currentScreen = .mainMenu }
                )
                .transition(.move(edge: .trailing))

            case .stats:
                StatsView(
                    onBack: { currentScreen = .mainMenu }
                )
                .transition(.move(edge: .trailing))

            case .playingSurvivor(let mode):
                GameContainerView(
                    gameMode: mode,
                    onExit: {
                        currentScreen = .mainMenu
                    }
                )
                .ignoresSafeArea()
                .transition(.opacity)

            case .playingTD(let mapId):
                TDGameContainerView(mapId: mapId)
                    .environmentObject(appState)
                    .ignoresSafeArea()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: screenKey)
        .environmentObject(appState)
    }

    // Helper for animation
    private var screenKey: String {
        switch currentScreen {
        case .mainMenu: return "mainMenu"
        case .modeSelect: return "modeSelect"
        case .loadout: return "loadout"
        case .tdMapSelect: return "tdMapSelect"
        case .collection: return "collection"
        case .stats: return "stats"
        case .playingSurvivor: return "playingSurvivor"
        case .playingTD: return "playingTD"
        }
    }
}

// MARK: - Mode Select View

struct ModeSelectView: View {
    @EnvironmentObject var appState: AppState

    let onSelectSurvivor: () -> Void
    let onSelectTD: () -> Void
    let onBack: () -> Void

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color.indigo.opacity(0.8), Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 30) {
                // Header
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
                }
                .padding(.horizontal)

                // Title
                VStack(spacing: 8) {
                    Text("GUARDIAN")
                        .font(.system(size: 42, weight: .black))
                        .foregroundColor(.white)

                    Text("Choose Your Mode")
                        .font(.title3)
                        .foregroundColor(.gray)
                }

                // Player level & gold
                HStack(spacing: 30) {
                    VStack {
                        Text("Level")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("\(appState.currentPlayer.level)")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }

                    Divider()
                        .frame(height: 40)
                        .background(Color.white.opacity(0.3))

                    VStack {
                        Text("Gold")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("\(appState.currentPlayer.gold)")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.yellow)
                    }
                }
                .padding()
                .background(Color.black.opacity(0.3))
                .cornerRadius(15)

                Spacer()

                // Mode buttons
                VStack(spacing: 20) {
                    // Survivor Mode
                    ModeCard(
                        title: "SURVIVOR",
                        subtitle: "Arena & Dungeon",
                        description: "Control the Guardian directly. Dodge enemies, collect power-ups, and survive!",
                        icon: "figure.run",
                        color: .green,
                        stats: [
                            "Runs": "\(appState.currentPlayer.survivorStats.arenaRuns + appState.currentPlayer.survivorStats.dungeonRuns)",
                            "Kills": "\(appState.currentPlayer.survivorStats.totalSurvivorKills)"
                        ],
                        action: onSelectSurvivor
                    )

                    // Tower Defense Mode
                    ModeCard(
                        title: "TOWER DEFENSE",
                        subtitle: "Strategic Defense",
                        description: "Place towers to defend the Guardian Core. Survive 20 waves of enemies!",
                        icon: "building.columns.fill",
                        color: .purple,
                        stats: [
                            "Wins": "\(appState.currentPlayer.tdStats.gamesWon)",
                            "Best Wave": "\(appState.currentPlayer.tdStats.highestWave)"
                        ],
                        action: onSelectTD
                    )
                }
                .padding(.horizontal)

                Spacer()

                // Shared progression note
                Text("All modes share weapons, XP, and gold!")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.bottom)
            }
        }
    }
}

// MARK: - Mode Card

struct ModeCard: View {
    let title: String
    let subtitle: String
    let description: String
    let icon: String
    let color: Color
    let stats: [String: String]
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundColor(color)
                    .frame(width: 60)

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(color)

                    Text(description)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(2)

                    // Stats
                    HStack(spacing: 12) {
                        ForEach(Array(stats.keys.sorted()), id: \.self) { key in
                            HStack(spacing: 4) {
                                Text(key + ":")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                Text(stats[key] ?? "0")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .padding(.top, 4)
                }

                Spacer()

                // Arrow
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.black.opacity(0.4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(color.opacity(0.5), lineWidth: 1)
                    )
            )
        }
    }
}

#Preview {
    ContentView()
}
