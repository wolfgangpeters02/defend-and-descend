import SwiftUI

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
