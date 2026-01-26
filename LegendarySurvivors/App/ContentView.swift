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
            // Background - Terminal/cyber aesthetic
            LinearGradient(
                colors: [Color(red: 0.04, green: 0.08, blue: 0.12), Color.black],
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

                // Title - System: Reboot branding
                VStack(spacing: 8) {
                    Text("SYSTEM: REBOOT")
                        .font(.system(size: 32, weight: .black, design: .monospaced))
                        .foregroundColor(.cyan)

                    Text("SELECT PROTOCOL")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(.gray)
                }

                // Player stats - Watts currency
                HStack(spacing: 30) {
                    VStack {
                        Text("LEVEL")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(.gray)
                        Text("\(appState.currentPlayer.level)")
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }

                    Divider()
                        .frame(height: 40)
                        .background(Color.cyan.opacity(0.3))

                    VStack {
                        HStack(spacing: 4) {
                            Image(systemName: "bolt.fill")
                                .font(.caption)
                            Text("WATTS")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                        }
                        .foregroundColor(.gray)
                        Text("\(appState.currentPlayer.gold)")
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .foregroundColor(.cyan)
                    }
                }
                .padding()
                .background(Color.black.opacity(0.5))
                .cornerRadius(15)
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                )

                Spacer()

                // Mode buttons - System: Reboot themed
                VStack(spacing: 20) {
                    // Motherboard Mode (Idle/TD)
                    ModeCard(
                        title: "MOTHERBOARD",
                        subtitle: "Idle Defense",
                        description: "Deploy Firewalls to protect the CPU. Earn Watts while you're away.",
                        icon: "cpu",
                        color: .cyan,
                        stats: [
                            "Secure": "\(appState.currentPlayer.tdStats.gamesWon)",
                            "Best Wave": "\(appState.currentPlayer.tdStats.highestWave)"
                        ],
                        action: onSelectTD
                    )

                    // Debugger Mode (Active/Survivor)
                    ModeCard(
                        title: "DEBUGGER",
                        subtitle: "Manual Override",
                        description: "Enter corrupted sectors. Extract Data to unlock new Firewalls.",
                        icon: "ant.fill",
                        color: .green,
                        stats: [
                            "Runs": "\(appState.currentPlayer.survivorStats.arenaRuns + appState.currentPlayer.survivorStats.dungeonRuns)",
                            "Viruses": "\(appState.currentPlayer.survivorStats.totalSurvivorKills)"
                        ],
                        action: onSelectSurvivor
                    )
                }
                .padding(.horizontal)

                Spacer()

                // Dependency loop note
                Text("Motherboard earns Watts • Debugger unlocks Firewalls")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
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
