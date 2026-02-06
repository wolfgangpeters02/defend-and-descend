import SwiftUI

@main
struct SystemRebootApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var previousScenePhase: ScenePhase = .active

    init() {
        #if DEBUG
        // Run balance test suite on launch (background thread)
        DispatchQueue.global(qos: .background).async { SimulationRunner.runBalanceTestSuite() }
        #endif
    }

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
