import SwiftUI

@main
struct SystemRebootApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var previousScenePhase: ScenePhase = .active

    init() {
        #if DEBUG
        // Run boss fight test suite on launch (background thread)
        DispatchQueue.global(qos: .background).async { SimulationRunner.runBossFightTestSuite() }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .inactive:
                // Save state when becoming inactive (e.g. notification center, control center)
                // so data is preserved if the system kills the app before reaching .background
                AppState.shared.onAppBackground()
            case .background:
                // Save timestamp when going to background
                AppState.shared.onAppBackground()
            case .active:
                // Check for offline earnings when returning
                if previousScenePhase == .background {
                    AppState.shared.onAppForeground()
                }
            @unknown default:
                break
            }
            previousScenePhase = newPhase
        }
    }
}
