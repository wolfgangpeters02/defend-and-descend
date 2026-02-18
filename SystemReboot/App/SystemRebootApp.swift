import SwiftUI

@main
struct SystemRebootApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var previousScenePhase: ScenePhase = .active
    private let memoryWarningObserver: NSObjectProtocol

    init() {
        let isFirstLaunch = !UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
        AnalyticsService.shared.trackAppLaunched(firstLaunch: isFirstLaunch)
        if isFirstLaunch {
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
        }

        #if DEBUG
        // Run boss fight test suite on launch (background thread)
        DispatchQueue.global(qos: .background).async { SimulationRunner.runBossFightTestSuite() }
        #endif

        // Respond to memory pressure by shedding caches
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { _ in
            AppState.shared.onMemoryWarning()
        }
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
                AnalyticsService.shared.flush()
            case .active:
                // Check for offline earnings when returning
                if previousScenePhase == .background {
                    AppState.shared.onAppForeground()
                    AnalyticsService.shared.trackSessionStart()
                }
            @unknown default:
                break
            }
            previousScenePhase = newPhase
        }
    }
}
