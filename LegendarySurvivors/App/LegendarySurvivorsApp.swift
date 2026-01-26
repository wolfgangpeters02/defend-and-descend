import SwiftUI

@main
struct LegendarySurvivorsApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var previousScenePhase: ScenePhase = .active

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .background:
                // Save timestamp when going to background
                AppState.shared.onAppBackground()
            case .active:
                // Check for offline earnings when returning
                if previousScenePhase == .background {
                    AppState.shared.onAppForeground()
                }
            default:
                break
            }
            previousScenePhase = newPhase
        }
    }
}
