import SwiftUI
import SpriteKit

// MARK: - System Tab View
// Main hub with 4 modes: DEBUGGER (Survival), BOSS, MOTHERBOARD (TD), ARSENAL

enum SystemTab: String, CaseIterable {
    case debugger = "DEBUGGER"
    case boss = "BOSS"
    case motherboard = "BOARD"
    case arsenal = "ARSENAL"

    var icon: String {
        switch self {
        case .debugger: return "play.circle.fill"
        case .boss: return "flame.fill"
        case .motherboard: return "cpu"
        case .arsenal: return "shield.lefthalf.filled"
        }
    }

    var color: Color {
        switch self {
        case .debugger: return DesignColors.primary
        case .boss: return DesignColors.warning
        case .motherboard: return DesignColors.success
        case .arsenal: return DesignColors.secondary
        }
    }

    var subtitle: String {
        switch self {
        case .debugger: return "SURVIVAL"
        case .boss: return "ENCOUNTERS"
        case .motherboard: return "TD MODE"
        case .arsenal: return "PROTOCOLS"
        }
    }
}

struct SystemTabView: View {
    @ObservedObject var appState = AppState.shared
    @State private var selectedTab: SystemTab = .debugger
    @State private var showSurvivalGame = false
    @State private var showBossGame = false
    @State private var selectedBoss: BossEncounter?
    @State private var selectedDifficulty: BossDifficulty = .normal

    var onExit: (() -> Void)? = nil

    var body: some View {
        ZStack {
            // Background
            DesignColors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top navigation bar with exit button
                topNavigationBar

                // Content area
                contentView

                // Custom tab bar
                customTabBar
            }
        }
        .fullScreenCover(isPresented: $showSurvivalGame) {
            DebugGameView(
                sector: SectorLibrary.theRam,  // Memory Core arena
                protocol: appState.currentPlayer.equippedProtocol() ?? ProtocolLibrary.kernelPulse,
                onExit: {
                    showSurvivalGame = false
                }
            )
        }
        .fullScreenCover(item: $selectedBoss) { boss in
            BossGameView(
                boss: boss,
                difficulty: selectedDifficulty,
                protocol: appState.currentPlayer.equippedProtocol() ?? ProtocolLibrary.kernelPulse,
                onExit: {
                    selectedBoss = nil
                }
            )
        }
    }

    // MARK: - Content View

    @ViewBuilder
    private var contentView: some View {
        switch selectedTab {
        case .debugger:
            DebuggerModeView(onLaunch: {
                showSurvivalGame = true
            })
        case .boss:
            BossEncountersView(
                selectedDifficulty: $selectedDifficulty,
                onLaunch: { boss in
                    selectedBoss = boss
                }
            )
        case .motherboard:
            MotherboardView()
        case .arsenal:
            ArsenalView()
        }
    }

    // MARK: - Top Navigation Bar

    private var topNavigationBar: some View {
        HStack {
            // Exit button
            if let onExit = onExit {
                Button {
                    HapticsService.shared.play(.light)
                    onExit()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("MENU")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                    }
                    .foregroundColor(DesignColors.muted)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(DesignColors.surface.opacity(0.8))
                    .cornerRadius(8)
                }
            }

            Spacer()

            // Title
            Text("SYSTEM: REBOOT")
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .foregroundColor(DesignColors.primary)

            Spacer()

            // Placeholder for symmetry (same width as exit button)
            if onExit != nil {
                Color.clear
                    .frame(width: 80, height: 36)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(DesignColors.surface.opacity(0.5))
    }

    // MARK: - Custom Tab Bar

    private var customTabBar: some View {
        HStack(spacing: 0) {
            ForEach(SystemTab.allCases, id: \.self) { tab in
                tabButton(for: tab)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(
            DesignColors.surface
                .shadow(color: .black.opacity(0.5), radius: 10, y: -5)
        )
    }

    private func tabButton(for tab: SystemTab) -> some View {
        Button {
            HapticsService.shared.play(.selection)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: tab.icon)
                    .font(.system(size: 20, weight: selectedTab == tab ? .bold : .regular))
                    .foregroundColor(selectedTab == tab ? tab.color : DesignColors.muted)

                Text(tab.rawValue)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(selectedTab == tab ? tab.color : DesignColors.muted)

                Text(tab.subtitle)
                    .font(.system(size: 7, weight: .medium, design: .monospaced))
                    .foregroundColor(selectedTab == tab ? tab.color.opacity(0.7) : DesignColors.muted.opacity(0.5))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                selectedTab == tab ?
                    tab.color.opacity(0.15) : Color.clear
            )
            .cornerRadius(8)
        }
    }
}

// MARK: - Motherboard View (BOARD Tab) - Embedded TD Game

struct MotherboardView: View {
    @ObservedObject var appState = AppState.shared
    @StateObject private var embeddedGameController = EmbeddedTDGameController()
    @State private var showManualOverride = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Embedded TD Game Scene (always visible)
                EmbeddedTDGameView(controller: embeddedGameController)
                    .environmentObject(appState)

                // Transparent HUD overlay on top (with hit testing disabled for spacer area)
                VStack(spacing: 0) {
                    // Top HUD (semi-transparent)
                    motherboardHUD

                    // Spacer that passes touches through to the game
                    Color.clear
                        .contentShape(Rectangle())
                        .allowsHitTesting(false)

                    // Build deck at bottom (semi-transparent) with drag support
                    buildDeck(geometry: geometry)
                }

                // Drag preview overlay
                if embeddedGameController.isDraggingFromDeck,
                   let weaponType = embeddedGameController.draggedWeaponType {
                    dragPreviewOverlay(weaponType: weaponType, geometry: geometry)
                }

                // System Freeze overlay (0% efficiency)
                if embeddedGameController.isSystemFrozen && !showManualOverride {
                    SystemFreezeOverlay(
                        currentHash: embeddedGameController.gameState?.hash ?? 0,
                        onFlushMemory: {
                            // Deduct 10% Hash and recover
                            let hashCost = max(1, (embeddedGameController.gameState?.hash ?? 0) / 10)
                            appState.updatePlayer { profile in
                                profile.hash = max(0, profile.hash - hashCost)
                            }
                            embeddedGameController.flushMemory()
                        },
                        onManualOverride: {
                            // Launch Manual Override mini-game
                            withAnimation {
                                showManualOverride = true
                            }
                        }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }

                // Manual Override mini-game
                if showManualOverride {
                    ManualOverrideView(
                        onSuccess: {
                            withAnimation {
                                showManualOverride = false
                                embeddedGameController.manualOverrideSuccess()
                            }
                        },
                        onFailure: {
                            withAnimation {
                                showManualOverride = false
                                // Return to freeze overlay - they can try again or pay
                            }
                        },
                        onCancel: {
                            withAnimation {
                                showManualOverride = false
                                // Return to freeze overlay
                            }
                        }
                    )
                    .transition(.opacity)
                }
            }
            .coordinateSpace(name: "motherboardGameArea")
            .animation(.easeInOut(duration: 0.3), value: embeddedGameController.isSystemFrozen)
            .animation(.easeInOut(duration: 0.3), value: showManualOverride)
        }
    }

    private var motherboardHUD: some View {
        HStack {
            // Power (⚡) - PSU usage
            HStack(spacing: 4) {
                Image(systemName: "bolt.fill")
                    .foregroundColor(powerColor)
                Text("\(embeddedGameController.gameState?.powerUsed ?? 0)/\(embeddedGameController.gameState?.powerCapacity ?? 450)W")
                    .font(DesignTypography.caption(12))
                    .foregroundColor(powerColor)
            }

            Spacer()

            // Hash (Ħ) - Currency
            HStack(spacing: 4) {
                Image(systemName: "number.circle.fill")
                    .foregroundColor(.cyan)
                Text("\(embeddedGameController.gameState?.hash ?? appState.currentPlayer.hash)")
                    .font(DesignTypography.headline(16))
                    .foregroundColor(.cyan)
                Text("(+\(Int(appState.currentPlayer.globalUpgrades.hashPerSecond))/s)")
                    .font(DesignTypography.caption(10))
                    .foregroundColor(DesignColors.muted)
            }

            Spacer()

            // Efficiency bar
            HStack(spacing: 6) {
                let efficiency = (embeddedGameController.gameState?.efficiency ?? 100) / 100.0
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.3))
                        RoundedRectangle(cornerRadius: 4)
                            .fill(efficiencyColor)
                            .frame(width: geo.size.width * efficiency)
                    }
                }
                .frame(width: 80, height: 8)

                Text("\(Int((embeddedGameController.gameState?.efficiency ?? 100)))%")
                    .font(DesignTypography.caption(12))
                    .foregroundColor(efficiencyColor)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(DesignColors.surface.opacity(0.85))
    }

    private var efficiencyColor: Color {
        let eff = (embeddedGameController.gameState?.efficiency ?? 100) / 100.0
        if eff >= 0.7 { return DesignColors.success }
        if eff >= 0.4 { return DesignColors.warning }
        return DesignColors.danger
    }

    private var powerColor: Color {
        guard let state = embeddedGameController.gameState else { return DesignColors.success }
        let usage = Double(state.powerUsed) / Double(max(1, state.powerCapacity))
        if usage >= 0.95 { return DesignColors.danger }    // At capacity
        if usage >= 0.75 { return DesignColors.warning }   // Getting full
        if usage >= 0.50 { return .yellow }                 // Half used
        return DesignColors.success                         // Plenty available
    }

    private func buildDeck(geometry: GeometryProxy) -> some View {
        VStack(spacing: 8) {
            Text("DRAG FIREWALL TO DEPLOY")
                .font(DesignTypography.caption(11))
                .foregroundColor(DesignColors.muted)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(appState.currentPlayer.compiledProtocols, id: \.self) { protocolId in
                        if let proto = ProtocolLibrary.get(protocolId) {
                            EmbeddedProtocolDeckCard(
                                protocol: proto,
                                hash: embeddedGameController.gameState?.hash ?? 0,
                                onDragStart: { embeddedGameController.startDrag(weaponType: proto.id) },
                                onDragChanged: { value in embeddedGameController.updateDrag(value, geometry: geometry) },
                                onDragEnded: { embeddedGameController.endDrag(profile: appState.currentPlayer) }
                            )
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 12)
        .background(DesignColors.surface.opacity(0.85))
    }

    private func dragPreviewOverlay(weaponType: String, geometry: GeometryProxy) -> some View {
        ZStack {
            if let proto = ProtocolLibrary.get(weaponType) {
                let displayPosition = embeddedGameController.nearestValidSlot != nil && embeddedGameController.canAffordDraggedTower
                    ? embeddedGameController.convertGameToScreen(embeddedGameController.nearestValidSlot!.position, geometry: geometry)
                    : embeddedGameController.dragPosition
                let protoColor = Color(hex: proto.color) ?? DesignColors.primary
                let range = proto.firewallStats.range

                ZStack {
                    if embeddedGameController.nearestValidSlot != nil && embeddedGameController.canAffordDraggedTower {
                        Circle()
                            .fill(protoColor.opacity(0.1))
                            .frame(width: range * 0.6, height: range * 0.6)
                        Circle()
                            .stroke(protoColor.opacity(0.4), lineWidth: 2)
                            .frame(width: range * 0.6, height: range * 0.6)
                    }

                    Circle()
                        .fill(protoColor.opacity(0.7))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle().stroke(embeddedGameController.canAffordDraggedTower ? Color.white : DesignColors.danger, lineWidth: 2)
                        )
                        .shadow(color: embeddedGameController.canAffordDraggedTower ? protoColor.opacity(0.6) : DesignColors.danger.opacity(0.4), radius: 12)

                    Image(systemName: proto.iconName)
                        .font(DesignTypography.headline(18))
                        .foregroundColor(.white)

                    Text("\(TowerSystem.towerPlacementCost(rarity: proto.rarity))W")
                        .font(DesignTypography.caption(11))
                        .fontWeight(.bold)
                        .foregroundColor(embeddedGameController.canAffordDraggedTower ? DesignColors.primary : DesignColors.danger)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(DesignColors.surface.opacity(0.9))
                        .cornerRadius(4)
                        .offset(y: 32)
                }
                .position(displayPosition)
                .animation(.easeOut(duration: 0.1), value: embeddedGameController.nearestValidSlot?.id)
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Embedded TD Game Controller (Observable State)

class EmbeddedTDGameController: ObservableObject {
    @Published var scene: TDGameScene?
    @Published var gameState: TDGameState?
    @Published var isDraggingFromDeck = false
    @Published var draggedWeaponType: String?
    @Published var dragPosition: CGPoint = .zero
    @Published var nearestValidSlot: TowerSlot?
    @Published var canAffordDraggedTower = false
    @Published var isSystemFrozen = false  // True when efficiency hits 0%
    @Published var showSectorUnlockPanel = false
    @Published var selectedSectorForUnlock: String?

    private var delegateHandler: EmbeddedTDDelegateHandler?

    func setup(screenSize: CGSize, playerProfile: PlayerProfile) {
        guard scene == nil else { return }

        // Use the new Motherboard City map (4000x4000 PCB canvas)
        guard var state = TDGameStateFactory.createMotherboardGameState(playerProfile: playerProfile) else {
            print("[EmbeddedTDGameController] Failed to create Motherboard game state")
            return
        }

        // Restore saved session if one exists (towers, slots, resources)
        if let savedSession = StorageService.shared.loadTDSession() {
            savedSession.apply(to: &state)
            print("[EmbeddedTDGameController] Restored saved session with \(savedSession.towers.count) towers")
        }

        let waves = WaveSystem.generateWaves(totalWaves: 20)

        let handler = EmbeddedTDDelegateHandler()
        handler.onGameStateUpdated = { [weak self] newState in
            DispatchQueue.main.async {
                self?.gameState = newState
                // Track freeze state changes
                if newState.isSystemFrozen && !(self?.isSystemFrozen ?? false) {
                    self?.isSystemFrozen = true
                }
            }
        }
        handler.onSystemFrozen = { [weak self] in
            DispatchQueue.main.async {
                self?.isSystemFrozen = true
            }
        }
        handler.onGateSelected = { [weak self] sectorId in
            DispatchQueue.main.async {
                self?.selectedSectorForUnlock = sectorId
                self?.showSectorUnlockPanel = true
            }
        }

        // Scene size based on map dimensions
        let sceneSize = CGSize(width: state.map.width, height: state.map.height)

        let newScene = TDGameScene(size: sceneSize)
        newScene.scaleMode = .aspectFill
        newScene.gameStateDelegate = handler
        newScene.loadState(state, waves: waves)

        self.delegateHandler = handler
        self.gameState = state
        self.scene = newScene
    }

    // MARK: - Drag Handling

    func startDrag(weaponType: String) {
        isDraggingFromDeck = true
        draggedWeaponType = weaponType

        if let proto = ProtocolLibrary.get(weaponType) {
            let cost = TowerSystem.towerPlacementCost(rarity: proto.rarity)
            canAffordDraggedTower = (gameState?.hash ?? 0) >= cost
        }

        scene?.enterPlacementMode(weaponType: weaponType)
        HapticsService.shared.play(.selection)
    }

    func updateDrag(_ value: DragGesture.Value, geometry: GeometryProxy) {
        dragPosition = value.location

        guard let state = gameState else { return }

        let gamePos = convertScreenToGame(dragPosition, geometry: geometry)
        var nearest: TowerSlot?

        // Use camera scale for snap distance
        // When zoomed OUT (scale > 1), we need LARGER snap distance in game units
        // because game units appear smaller on screen
        let cameraScale = scene?.cameraScale ?? 1.0
        let baseSnapDistance: CGFloat = state.map.width > 2000 ? 200 : 80
        // Divide by scale so zoomed out = larger snap area
        let snapDistanceInGameUnits: CGFloat = baseSnapDistance / min(cameraScale, 1.0) * max(cameraScale, 1.0)

        var minDistance: CGFloat = snapDistanceInGameUnits

        // Debug: log occasionally
        if Int.random(in: 0...50) == 0 {
            print("[Drag] screen: \(dragPosition), game: \(gamePos), cameraScale: \(cameraScale), snapDist: \(snapDistanceInGameUnits)")
            print("[Drag] Total slots: \(state.towerSlots.count), unoccupied: \(state.towerSlots.filter { !$0.occupied }.count)")
            if let firstSlot = state.towerSlots.first {
                print("[Drag] First slot at: (\(firstSlot.x), \(firstSlot.y))")
            }
        }

        for slot in state.towerSlots where !slot.occupied {
            let dx = slot.x - gamePos.x
            let dy = slot.y - gamePos.y
            let distance = sqrt(dx*dx + dy*dy)
            if distance < minDistance {
                minDistance = distance
                nearest = slot
            }
        }

        if nearestValidSlot?.id != nearest?.id {
            nearestValidSlot = nearest
            scene?.highlightNearestSlot(nearest, canAfford: canAffordDraggedTower)

            if nearest != nil && canAffordDraggedTower {
                HapticsService.shared.play(.slotSnap)
                print("[Drag] Found nearest slot: \(nearest!.id) at (\(nearest!.x), \(nearest!.y))")
            }
        }
    }

    func endDrag(profile: PlayerProfile) {
        scene?.exitPlacementMode()

        defer {
            isDraggingFromDeck = false
            draggedWeaponType = nil
            nearestValidSlot = nil
        }

        print("[Drag] endDrag - weaponType: \(draggedWeaponType ?? "nil"), slot: \(nearestValidSlot?.id ?? "nil"), canAfford: \(canAffordDraggedTower), hash: \(gameState?.hash ?? 0)")

        if let weaponType = draggedWeaponType,
           let slot = nearestValidSlot,
           canAffordDraggedTower {
            print("[Drag] Placing tower \(weaponType) at slot \(slot.id)")
            scene?.placeTower(weaponType: weaponType, slotId: slot.id, profile: profile)
            HapticsService.shared.play(.towerPlace)
        } else {
            print("[Drag] NOT placing - missing: weaponType=\(draggedWeaponType != nil), slot=\(nearestValidSlot != nil), canAfford=\(canAffordDraggedTower)")
        }
    }

    // MARK: - Coordinate Conversion

    func convertScreenToGame(_ point: CGPoint, geometry: GeometryProxy) -> CGPoint {
        // Use scene's camera-aware conversion if available
        if let scene = scene {
            return scene.convertScreenToGame(screenPoint: point, viewSize: geometry.size)
        }

        // Fallback: simple conversion without camera
        let gameWidth = gameState?.map.width ?? 800
        let gameHeight = gameState?.map.height ?? 600
        let screenWidth = geometry.size.width
        let screenHeight = geometry.size.height
        let scaleX = screenWidth / gameWidth
        let scaleY = screenHeight / gameHeight
        let scale = max(scaleX, scaleY)
        let scaledWidth = gameWidth * scale
        let scaledHeight = gameHeight * scale
        let offsetX = (screenWidth - scaledWidth) / 2
        let offsetY = (screenHeight - scaledHeight) / 2

        return CGPoint(
            x: (point.x - offsetX) / scale,
            y: (point.y - offsetY) / scale
        )
    }

    func convertGameToScreen(_ point: CGPoint, geometry: GeometryProxy) -> CGPoint {
        // Use scene's camera-aware conversion if available
        if let scene = scene {
            return scene.convertGameToScreen(gamePoint: point, viewSize: geometry.size)
        }

        // Fallback: simple conversion without camera
        let gameWidth = gameState?.map.width ?? 800
        let gameHeight = gameState?.map.height ?? 600
        let screenWidth = geometry.size.width
        let screenHeight = geometry.size.height
        let scaleX = screenWidth / gameWidth
        let scaleY = screenHeight / gameHeight
        let scale = max(scaleX, scaleY)
        let scaledWidth = gameWidth * scale
        let scaledHeight = gameHeight * scale
        let offsetX = (screenWidth - scaledWidth) / 2
        let offsetY = (screenHeight - scaledHeight) / 2

        return CGPoint(
            x: point.x * scale + offsetX,
            y: point.y * scale + offsetY
        )
    }

    // MARK: - System Freeze Recovery

    /// Flush Memory: Pay 10% of current Hash to restore efficiency
    func flushMemory() {
        guard isSystemFrozen else { return }
        isSystemFrozen = false
        scene?.recoverFromFreeze(restoreToEfficiency: 50)
    }

    /// Manual Override complete: Restore efficiency without cost
    func manualOverrideSuccess() {
        guard isSystemFrozen else { return }
        isSystemFrozen = false
        scene?.recoverFromFreeze(restoreToEfficiency: 50)
    }

    /// Unlock a sector (decrypt it)
    func unlockSector(_ sectorId: String, appState: AppState) -> Bool {
        var profile = appState.currentPlayer
        let result = SectorUnlockSystem.shared.unlockSector(sectorId, profile: &profile)

        if result.success {
            // Update and save profile
            appState.currentPlayer = profile
            StorageService.shared.savePlayer(profile)

            // Play celebration
            HapticsService.shared.play(.legendary)

            // Refresh mega-board visuals
            scene?.refreshMegaBoardVisuals()

            // Close panel
            showSectorUnlockPanel = false
            selectedSectorForUnlock = nil
            return true
        } else {
            HapticsService.shared.play(.error)
            return false
        }
    }

    /// Dismiss sector unlock panel
    func dismissSectorUnlockPanel() {
        showSectorUnlockPanel = false
        selectedSectorForUnlock = nil
    }
}

// MARK: - Embedded TD Delegate Handler

private class EmbeddedTDDelegateHandler: TDGameSceneDelegate {
    var onGameStateUpdated: ((TDGameState) -> Void)?
    var onSystemFrozen: (() -> Void)?
    var onGateSelected: ((String) -> Void)?

    func gameStateUpdated(_ state: TDGameState) {
        onGameStateUpdated?(state)
    }

    func slotSelected(_ slotId: String) {
        // Not used in embedded view - drag-to-place only
    }

    func towerSelected(_ towerId: String?) {
        // Not used in embedded view
    }

    func gateSelected(_ sectorId: String) {
        onGateSelected?(sectorId)
    }

    func systemFrozen() {
        onSystemFrozen?()
    }
}

// MARK: - Embedded TD Game View (for BOARD tab)

struct EmbeddedTDGameView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var controller: EmbeddedTDGameController

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dark terminal background
                Color(hex: "0a0a0f")
                    .ignoresSafeArea()

                // SpriteKit scene
                if let scene = controller.scene {
                    SpriteView(scene: scene)
                        .ignoresSafeArea()
                } else {
                    // Loading state
                    VStack {
                        ProgressView()
                            .tint(DesignColors.primary)
                        Text("INITIALIZING_SYSTEM...")
                            .font(DesignTypography.caption(12))
                            .foregroundColor(DesignColors.muted)
                            .padding(.top, 8)
                    }
                }

                // Sector unlock panel overlay
                if controller.showSectorUnlockPanel, let sectorId = controller.selectedSectorForUnlock {
                    sectorUnlockPanel(sectorId: sectorId)
                }
            }
            .onChange(of: geometry.size) { newSize in
                if controller.scene == nil && newSize.width > 0 && newSize.height > 0 {
                    controller.setup(screenSize: newSize, playerProfile: appState.currentPlayer)
                }
            }
            .onAppear {
                if controller.scene == nil && geometry.size.width > 0 && geometry.size.height > 0 {
                    controller.setup(screenSize: geometry.size, playerProfile: appState.currentPlayer)
                }
            }
        }
    }

    // MARK: - Sector Unlock Panel

    @ViewBuilder
    private func sectorUnlockPanel(sectorId: String) -> some View {
        let status = SectorUnlockSystem.shared.getUnlockStatus(for: sectorId, profile: appState.currentPlayer)

        ZStack {
            // Dimmed background
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .onTapGesture {
                    controller.dismissSectorUnlockPanel()
                }

            // Panel
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.red)

                    Text("ENCRYPTED_SECTOR")
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)

                    Text(status?.displayName ?? "Unknown")
                        .font(.system(size: 18, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                }

                // Description
                if let desc = status?.description {
                    Text(desc)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                // Cost display
                if let status = status {
                    VStack(spacing: 12) {
                        // Cost
                        HStack(spacing: 8) {
                            Text("DECRYPT_COST:")
                                .font(.system(size: 14, weight: .medium, design: .monospaced))
                                .foregroundColor(.gray)

                            Text("Ħ \(status.unlockCost)")
                                .font(.system(size: 20, weight: .bold, design: .monospaced))
                                .foregroundColor(.cyan)
                        }

                        // Current balance
                        HStack(spacing: 8) {
                            Text("YOUR_BALANCE:")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundColor(.gray)

                            Text("Ħ \(status.currentHash)")
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundColor(status.canAfford ? .green : .orange)
                        }

                        // Status message
                        Text(status.statusMessage)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(status.canUnlock ? .green : .orange)
                            .padding(.top, 4)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(status.canUnlock ? Color.cyan.opacity(0.5) : Color.red.opacity(0.3), lineWidth: 1)
                            )
                    )
                }

                // Buttons
                HStack(spacing: 16) {
                    // Cancel
                    Button(action: {
                        HapticsService.shared.play(.light)
                        controller.dismissSectorUnlockPanel()
                    }) {
                        Text("CANCEL")
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .frame(width: 120, height: 50)
                            .background(Color.gray.opacity(0.3))
                            .cornerRadius(8)
                    }

                    // Decrypt
                    Button(action: {
                        _ = controller.unlockSector(sectorId, appState: appState)
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "key.fill")
                            Text("DECRYPT")
                        }
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(status?.canUnlock == true ? .black : .gray)
                        .frame(width: 140, height: 50)
                        .background(status?.canUnlock == true ? Color.cyan : Color.gray.opacity(0.3))
                        .cornerRadius(8)
                    }
                    .disabled(status?.canUnlock != true)
                }
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hex: "0a0a12") ?? .black)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.cyan.opacity(0.3), lineWidth: 2)
                    )
            )
            .padding(20)
        }
    }
}

// MARK: - Embedded Protocol Deck Card (with Drag Support)

struct EmbeddedProtocolDeckCard: View {
    let `protocol`: Protocol
    let hash: Int
    let onDragStart: () -> Void
    let onDragChanged: (DragGesture.Value) -> Void
    let onDragEnded: () -> Void

    @State private var isDragging = false

    private var cost: Int {
        TowerSystem.towerPlacementCost(rarity: `protocol`.rarity)
    }

    private var canAfford: Bool {
        hash >= cost
    }

    private var rarityColor: Color {
        RarityColors.color(for: `protocol`.rarity)
    }

    var body: some View {
        VStack(spacing: 4) {
            // Tower icon container - circuit board aesthetic
            ZStack {
                // Background circuit pattern
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: "0a0a12") ?? .black)
                    .frame(width: 56, height: 56)

                // Border with glow effect
                RoundedRectangle(cornerRadius: 8)
                    .stroke(rarityColor.opacity(canAfford ? 0.8 : 0.3), lineWidth: 2)
                    .frame(width: 56, height: 56)
                    .shadow(color: canAfford ? rarityColor.opacity(0.5) : .clear, radius: 8)

                // Protocol icon - simplified, geometric
                Image(systemName: `protocol`.iconName)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(canAfford ? .white : .gray)

                // Corner accent (circuit node)
                Circle()
                    .fill(rarityColor)
                    .frame(width: 8, height: 8)
                    .offset(x: 22, y: -22)
                    .opacity(canAfford ? 1 : 0.3)

                // Opposite corner node for balance
                Circle()
                    .fill(rarityColor.opacity(0.5))
                    .frame(width: 6, height: 6)
                    .offset(x: -22, y: 22)
                    .opacity(canAfford ? 0.8 : 0.2)
            }
            .scaleEffect(isDragging ? 0.9 : 1.0)

            // Cost label - terminal/monospace aesthetic
            HStack(spacing: 2) {
                Text("Ħ")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                Text("\(cost)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
            }
            .foregroundColor(canAfford ? DesignColors.primary : .red.opacity(0.7))
        }
        .opacity(canAfford ? 1.0 : 0.5)
        .animation(.easeOut(duration: 0.15), value: isDragging)
        .gesture(
            DragGesture(minimumDistance: 5, coordinateSpace: .named("motherboardGameArea"))
                .onChanged { value in
                    if canAfford {
                        if !isDragging {
                            isDragging = true
                            onDragStart()
                        }
                        onDragChanged(value)
                    }
                }
                .onEnded { _ in
                    isDragging = false
                    onDragEnded()
                }
        )
    }
}

// MARK: - System Freeze Overlay

struct SystemFreezeOverlay: View {
    let currentHash: Int
    let onFlushMemory: () -> Void
    let onManualOverride: () -> Void

    @State private var glitchOffset: CGFloat = 0
    @State private var scanLineOffset: CGFloat = 0

    private var flushCost: Int {
        max(1, currentHash / 10)  // 10% of current Hash
    }

    private var canAffordFlush: Bool {
        currentHash >= flushCost
    }

    var body: some View {
        ZStack {
            // Dark overlay with scan lines
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .overlay(
                    // Scan line effect
                    GeometryReader { geo in
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [.clear, .red.opacity(0.1), .clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: 100)
                            .offset(y: scanLineOffset)
                            .onAppear {
                                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                                    scanLineOffset = geo.size.height
                                }
                            }
                    }
                )

            // Main content
            VStack(spacing: 24) {
                // Glitchy title
                ZStack {
                    Text("SYSTEM FREEZE")
                        .font(.system(size: 36, weight: .black, design: .monospaced))
                        .foregroundColor(.red.opacity(0.5))
                        .offset(x: glitchOffset, y: -glitchOffset)

                    Text("SYSTEM FREEZE")
                        .font(.system(size: 36, weight: .black, design: .monospaced))
                        .foregroundColor(.cyan.opacity(0.5))
                        .offset(x: -glitchOffset, y: glitchOffset)

                    Text("SYSTEM FREEZE")
                        .font(.system(size: 36, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                }
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.1).repeatForever(autoreverses: true)) {
                        glitchOffset = 2
                    }
                }

                // Error message
                VStack(spacing: 8) {
                    Text("CRITICAL ERROR: EFFICIENCY 0%")
                        .font(DesignTypography.headline(16))
                        .foregroundColor(.red)

                    Text("All systems halted. Memory corrupted.")
                        .font(DesignTypography.body(14))
                        .foregroundColor(DesignColors.muted)

                    Text("Choose recovery method:")
                        .font(DesignTypography.body(14))
                        .foregroundColor(.white)
                        .padding(.top, 8)
                }

                // Recovery options
                VStack(spacing: 16) {
                    // Option 1: Flush Memory (pay Hash)
                    Button {
                        HapticsService.shared.play(.medium)
                        onFlushMemory()
                    } label: {
                        VStack(spacing: 6) {
                            HStack {
                                Image(systemName: "arrow.clockwise.circle.fill")
                                    .font(.system(size: 24))
                                Text("FLUSH MEMORY")
                                    .font(DesignTypography.headline(18))
                            }

                            HStack(spacing: 4) {
                                Text("Cost:")
                                    .foregroundColor(DesignColors.muted)
                                Image(systemName: "number.circle.fill")
                                    .foregroundColor(canAffordFlush ? DesignColors.primary : .red)
                                Text("\(flushCost)")
                                    .foregroundColor(canAffordFlush ? DesignColors.primary : .red)
                                Text("(10% of Hash)")
                                    .font(DesignTypography.caption(11))
                                    .foregroundColor(DesignColors.muted)
                            }
                            .font(DesignTypography.body(14))

                            Text("Restores 50% efficiency instantly")
                                .font(DesignTypography.caption(11))
                                .foregroundColor(DesignColors.muted)
                        }
                        .foregroundColor(canAffordFlush ? .white : DesignColors.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(canAffordFlush ? DesignColors.primary.opacity(0.2) : DesignColors.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(canAffordFlush ? DesignColors.primary : DesignColors.muted, lineWidth: 2)
                        )
                    }
                    .disabled(!canAffordFlush)

                    // Option 2: Manual Override (mini-game)
                    Button {
                        HapticsService.shared.play(.medium)
                        onManualOverride()
                    } label: {
                        VStack(spacing: 6) {
                            HStack {
                                Image(systemName: "gamecontroller.fill")
                                    .font(.system(size: 24))
                                Text("MANUAL OVERRIDE")
                                    .font(DesignTypography.headline(18))
                            }

                            Text("FREE - Survive 30 seconds")
                                .font(DesignTypography.body(14))
                                .foregroundColor(DesignColors.success)

                            Text("Complete challenge to restore system")
                                .font(DesignTypography.caption(11))
                                .foregroundColor(DesignColors.muted)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(DesignColors.success.opacity(0.2))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(DesignColors.success, lineWidth: 2)
                        )
                    }
                }
                .padding(.horizontal, 24)

                // Freeze count indicator
                Text("System has frozen \(1) time(s) this session")
                    .font(DesignTypography.caption(11))
                    .foregroundColor(DesignColors.muted)
                    .padding(.top, 8)
            }
            .padding()
        }
    }
}

// MARK: - Protocol Build Card

struct ProtocolBuildCard: View {
    let `protocol`: Protocol

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: `protocol`.iconName)
                .font(.system(size: 24))
                .foregroundColor(Color(hex: `protocol`.color) ?? .cyan)

            Text("\(Int(`protocol`.firewallStats.damage))W")
                .font(DesignTypography.caption(10))
                .foregroundColor(DesignColors.muted)
        }
        .frame(width: 60, height: 60)
        .background(DesignColors.surface)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(hex: `protocol`.color)?.opacity(0.5) ?? .cyan.opacity(0.5), lineWidth: 1)
        )
    }
}

// MARK: - Grid Pattern View

struct GridPatternView: View {
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let gridSize: CGFloat = 40
                let dotSize: CGFloat = 2

                for x in stride(from: 0, to: size.width, by: gridSize) {
                    for y in stride(from: 0, to: size.height, by: gridSize) {
                        let rect = CGRect(
                            x: x - dotSize/2,
                            y: y - dotSize/2,
                            width: dotSize,
                            height: dotSize
                        )
                        context.fill(
                            Path(ellipseIn: rect),
                            with: .color(.white.opacity(0.1))
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Arsenal View (ARSENAL Tab)

struct ArsenalView: View {
    @ObservedObject var appState = AppState.shared
    @State private var selectedProtocol: Protocol?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("ARSENAL")
                    .font(DesignTypography.display(28))
                    .foregroundColor(.white)

                Spacer()

                // Data balance
                HStack(spacing: 6) {
                    Image(systemName: "memorychip")
                        .foregroundColor(DesignColors.success)
                    Text("\(appState.currentPlayer.data)")
                        .font(DesignTypography.headline(18))
                        .foregroundColor(DesignColors.success)
                }
            }
            .padding()

            // Equipped protocol
            equippedSection

            Divider()
                .background(DesignColors.muted.opacity(0.3))
                .padding(.horizontal)

            // Protocol grid
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Compiled protocols
                    Text("COMPILED_PROTOCOLS")
                        .font(DesignTypography.caption(12))
                        .foregroundColor(DesignColors.muted)
                        .padding(.horizontal)

                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(ProtocolLibrary.all.filter { appState.currentPlayer.isProtocolCompiled($0.id) }) { proto in
                            ProtocolCard(
                                protocol: proto,
                                level: appState.currentPlayer.protocolLevel(proto.id),
                                isEquipped: appState.currentPlayer.equippedProtocolId == proto.id,
                                onTap: { selectedProtocol = proto }
                            )
                        }
                    }
                    .padding(.horizontal)

                    // Blueprints
                    Text("BLUEPRINTS")
                        .font(DesignTypography.caption(12))
                        .foregroundColor(DesignColors.muted)
                        .padding(.horizontal)
                        .padding(.top, 8)

                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(ProtocolLibrary.all.filter { !appState.currentPlayer.isProtocolCompiled($0.id) }) { proto in
                            ProtocolCard(
                                protocol: proto,
                                level: 1,
                                isLocked: true,
                                onTap: { selectedProtocol = proto }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
        }
        .sheet(item: $selectedProtocol) { proto in
            ProtocolDetailSheet(protocol: proto)
        }
    }

    private var equippedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("EQUIPPED_FOR_DEBUG")
                .font(DesignTypography.caption(12))
                .foregroundColor(DesignColors.muted)

            if let equipped = appState.currentPlayer.equippedProtocol() {
                HStack {
                    Image(systemName: equipped.iconName)
                        .font(.system(size: 32))
                        .foregroundColor(Color(hex: equipped.color) ?? .cyan)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(equipped.name)
                            .font(DesignTypography.headline(18))
                            .foregroundColor(.white)

                        Text("LV \(equipped.level)")
                            .font(DesignTypography.caption(12))
                            .foregroundColor(DesignColors.muted)
                    }

                    Spacer()
                }
                .padding()
                .background(DesignColors.surface)
                .cornerRadius(12)
            }
        }
        .padding()
    }
}

// MARK: - Protocol Card

struct ProtocolCard: View {
    let `protocol`: Protocol
    var level: Int = 1
    var isEquipped: Bool = false
    var isLocked: Bool = false
    var onTap: () -> Void = {}

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                ZStack {
                    Image(systemName: isLocked ? "lock.fill" : `protocol`.iconName)
                        .font(.system(size: 28))
                        .foregroundColor(
                            isLocked ? DesignColors.muted :
                                (Color(hex: `protocol`.color) ?? .cyan)
                        )
                }
                .frame(width: 50, height: 50)

                Text(`protocol`.name)
                    .font(DesignTypography.caption(10))
                    .foregroundColor(isLocked ? DesignColors.muted : .white)
                    .lineLimit(1)

                if isLocked {
                    Text("\(`protocol`.compileCost)◈")
                        .font(DesignTypography.caption(10))
                        .foregroundColor(DesignColors.muted)
                } else {
                    Text("LV \(level)")
                        .font(DesignTypography.caption(10))
                        .foregroundColor(DesignColors.muted)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                isEquipped ? DesignColors.primary.opacity(0.2) : DesignColors.surface
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isEquipped ? DesignColors.primary : Color.clear,
                        lineWidth: 2
                    )
            )
        }
    }
}

// MARK: - Protocol Detail Sheet

struct ProtocolDetailSheet: View {
    let `protocol`: Protocol
    @ObservedObject var appState = AppState.shared
    @Environment(\.dismiss) var dismiss

    var currentLevel: Int {
        appState.currentPlayer.protocolLevel(`protocol`.id)
    }

    var isCompiled: Bool {
        appState.currentPlayer.isProtocolCompiled(`protocol`.id)
    }

    var body: some View {
        NavigationView {
            ZStack {
                DesignColors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 12) {
                            Image(systemName: `protocol`.iconName)
                                .font(.system(size: 60))
                                .foregroundColor(Color(hex: `protocol`.color) ?? .cyan)

                            Text(`protocol`.name)
                                .font(DesignTypography.display(28))
                                .foregroundColor(.white)

                            Text(`protocol`.description)
                                .font(DesignTypography.body(14))
                                .foregroundColor(DesignColors.muted)
                                .multilineTextAlignment(.center)

                            if isCompiled {
                                Text("LV \(currentLevel)")
                                    .font(DesignTypography.headline(18))
                                    .foregroundColor(DesignColors.primary)
                            }
                        }
                        .padding()

                        // Stats
                        HStack(spacing: 20) {
                            // Firewall stats
                            VStack(alignment: .leading, spacing: 8) {
                                Text("FIREWALL_MODE")
                                    .font(DesignTypography.caption(11))
                                    .foregroundColor(DesignColors.muted)

                                ProtocolStatRow(label: "Damage", value: "\(Int(`protocol`.firewallStats.damage))")
                                ProtocolStatRow(label: "Range", value: "\(Int(`protocol`.firewallStats.range))")
                                ProtocolStatRow(label: "Fire Rate", value: String(format: "%.1f/s", `protocol`.firewallStats.fireRate))
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(DesignColors.surface)
                            .cornerRadius(12)

                            // Weapon stats
                            VStack(alignment: .leading, spacing: 8) {
                                Text("WEAPON_MODE")
                                    .font(DesignTypography.caption(11))
                                    .foregroundColor(DesignColors.muted)

                                ProtocolStatRow(label: "Damage", value: "\(Int(`protocol`.weaponStats.damage))")
                                ProtocolStatRow(label: "Fire Rate", value: String(format: "%.1f/s", `protocol`.weaponStats.fireRate))
                                ProtocolStatRow(label: "Projectiles", value: "\(`protocol`.weaponStats.projectileCount)")
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(DesignColors.surface)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)

                        // Actions
                        VStack(spacing: 12) {
                            if !isCompiled {
                                // Compile button
                                Button {
                                    compileProtocol()
                                } label: {
                                    HStack {
                                        Image(systemName: "hammer.fill")
                                        Text("COMPILE")
                                        Text("\(`protocol`.compileCost)◈")
                                            .foregroundColor(
                                                appState.currentPlayer.data >= `protocol`.compileCost ?
                                                    DesignColors.success : DesignColors.danger
                                            )
                                    }
                                    .font(DesignTypography.headline(16))
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(DesignColors.primary)
                                    .cornerRadius(12)
                                }
                                .disabled(appState.currentPlayer.data < `protocol`.compileCost)
                            } else {
                                // Equip button
                                if appState.currentPlayer.equippedProtocolId != `protocol`.id {
                                    Button {
                                        equipProtocol()
                                    } label: {
                                        HStack {
                                            Image(systemName: "checkmark.circle.fill")
                                            Text("EQUIP FOR DEBUG")
                                        }
                                        .font(DesignTypography.headline(16))
                                        .foregroundColor(.black)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(DesignColors.primary)
                                        .cornerRadius(12)
                                    }
                                }

                                // Upgrade button
                                if currentLevel < 10 {
                                    let cost = `protocol`.baseUpgradeCost * currentLevel
                                    Button {
                                        upgradeProtocol()
                                    } label: {
                                        HStack {
                                            Image(systemName: "arrow.up.circle.fill")
                                            Text("UPGRADE TO LV \(currentLevel + 1)")
                                            Text("\(cost)◈")
                                                .foregroundColor(
                                                    appState.currentPlayer.data >= cost ?
                                                        DesignColors.success : DesignColors.danger
                                                )
                                        }
                                        .font(DesignTypography.headline(16))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(DesignColors.surface)
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(DesignColors.primary, lineWidth: 1)
                                        )
                                    }
                                    .disabled(appState.currentPlayer.data < cost)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(DesignColors.primary)
                }
            }
        }
    }

    private func compileProtocol() {
        guard appState.currentPlayer.data >= `protocol`.compileCost else { return }
        HapticsService.shared.play(.medium)
        appState.updatePlayer { profile in
            profile.data -= `protocol`.compileCost
            profile.compiledProtocols.append(`protocol`.id)
            profile.protocolLevels[`protocol`.id] = 1
        }
    }

    private func equipProtocol() {
        HapticsService.shared.play(.selection)
        appState.updatePlayer { profile in
            profile.equippedProtocolId = `protocol`.id
        }
    }

    private func upgradeProtocol() {
        let cost = `protocol`.baseUpgradeCost * currentLevel
        guard appState.currentPlayer.data >= cost else { return }
        HapticsService.shared.play(.medium)
        appState.updatePlayer { profile in
            profile.data -= cost
            profile.protocolLevels[`protocol`.id] = currentLevel + 1
        }
    }
}

// MARK: - Protocol Stat Row

struct ProtocolStatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(DesignTypography.body(14))
                .foregroundColor(DesignColors.muted)
            Spacer()
            Text(value)
                .font(DesignTypography.headline(14))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Upgrades View (UPGRADES Tab)

struct UpgradesView: View {
    @ObservedObject var appState = AppState.shared

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("SYSTEM_UPGRADES")
                    .font(DesignTypography.display(28))
                    .foregroundColor(.white)

                Spacer()

                // Hash (Ħ) balance
                HStack(spacing: 6) {
                    Image(systemName: "number.circle.fill")
                        .foregroundColor(DesignColors.primary)
                    Text("\(appState.currentPlayer.hash)")
                        .font(DesignTypography.headline(18))
                        .foregroundColor(DesignColors.primary)
                }
            }
            .padding()

            ScrollView {
                VStack(spacing: 16) {
                    ForEach(GlobalUpgradeType.allCases, id: \.self) { upgradeType in
                        UpgradeCard(upgradeType: upgradeType)
                    }
                }
                .padding()
            }
        }
    }
}

// MARK: - Upgrade Card

struct UpgradeCard: View {
    let upgradeType: GlobalUpgradeType
    @ObservedObject var appState = AppState.shared

    private var upgrades: GlobalUpgrades {
        appState.currentPlayer.globalUpgrades
    }

    private var level: Int {
        upgrades.level(for: upgradeType)
    }

    private var cost: Int? {
        upgrades.upgradeCost(for: upgradeType)
    }

    private var isMaxed: Bool {
        upgrades.isMaxed(upgradeType)
    }

    private var canAfford: Bool {
        guard let c = cost else { return false }
        return appState.currentPlayer.hash >= c
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: upgradeType.icon)
                    .font(.system(size: 28))
                    .foregroundColor(Color(hex: upgradeType.color) ?? .cyan)

                VStack(alignment: .leading, spacing: 2) {
                    Text(upgradeType.rawValue)
                        .font(DesignTypography.headline(18))
                        .foregroundColor(.white)

                    Text(upgradeType.description)
                        .font(DesignTypography.caption(12))
                        .foregroundColor(DesignColors.muted)
                }

                Spacer()

                Text("LV \(level)")
                    .font(DesignTypography.headline(20))
                    .foregroundColor(Color(hex: upgradeType.color) ?? .cyan)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: upgradeType.color) ?? .cyan)
                        .frame(width: geo.size.width * (CGFloat(level) / CGFloat(GlobalUpgrades.maxLevel)))
                }
            }
            .frame(height: 8)

            // Current value
            Text(upgradeType.valueDescription(at: level))
                .font(DesignTypography.body(14))
                .foregroundColor(.white)

            // Upgrade button
            if isMaxed {
                Text("MAX_LEVEL")
                    .font(DesignTypography.headline(16))
                    .foregroundColor(DesignColors.muted)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(DesignColors.surface)
                    .cornerRadius(8)
            } else if let upgradeCost = cost {
                Button {
                    performUpgrade()
                } label: {
                    HStack {
                        if let nextValue = upgradeType.nextValueDescription(at: level) {
                            Text("Next: \(nextValue)")
                                .foregroundColor(.white)
                        }
                        Spacer()
                        Text("\(upgradeCost)⚡")
                            .foregroundColor(canAfford ? DesignColors.primary : DesignColors.danger)
                    }
                    .font(DesignTypography.headline(14))
                    .padding()
                    .background(DesignColors.surface)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(canAfford ? DesignColors.primary : DesignColors.muted, lineWidth: 1)
                    )
                }
                .disabled(!canAfford)
            }
        }
        .padding()
        .background(DesignColors.surface)
        .cornerRadius(16)
    }

    private func performUpgrade() {
        guard let upgradeCost = cost, canAfford else { return }
        HapticsService.shared.play(.medium)
        appState.updatePlayer { profile in
            profile.hash -= upgradeCost
            profile.globalUpgrades.upgrade(upgradeType)
        }
    }
}

// MARK: - Boss Encounter Model

struct BossEncounter: Identifiable {
    let id: String
    let name: String
    let subtitle: String
    let description: String
    let iconName: String
    let color: String
    let bossId: String  // Maps to boss AI type
    let rewards: [String]  // Protocol IDs that can drop
    let unlockCost: Int

    static let all: [BossEncounter] = [
        BossEncounter(
            id: "rogue_process",
            name: "ROGUE PROCESS",
            subtitle: "Cyberboss",
            description: "A corrupted system process. Spawns minions and fires laser beams.",
            iconName: "bolt.shield.fill",
            color: "#ff4444",
            bossId: "cyberboss",
            rewards: ["burst_protocol", "trace_route"],
            unlockCost: 0
        ),
        BossEncounter(
            id: "memory_leak",
            name: "MEMORY LEAK",
            subtitle: "Void Harbinger",
            description: "A void entity consuming memory. Creates gravity wells and shrinking arenas.",
            iconName: "tornado",
            color: "#a855f7",
            bossId: "void_harbinger",
            rewards: ["fork_bomb", "overflow"],
            unlockCost: 200
        )
    ]
}

// MARK: - Debugger Mode View (Survival)

struct DebuggerModeView: View {
    @ObservedObject var appState = AppState.shared
    let onLaunch: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("DEBUGGER_MODE")
                        .font(DesignTypography.display(28))
                        .foregroundColor(.white)
                    Text("Memory Core Survival")
                        .font(DesignTypography.caption(12))
                        .foregroundColor(DesignColors.muted)
                }

                Spacer()

                // Data balance
                HStack(spacing: 6) {
                    Text("◈")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(DesignColors.primary)
                    Text("\(appState.currentPlayer.data)")
                        .font(DesignTypography.headline(18))
                        .foregroundColor(DesignColors.primary)
                }
            }
            .padding()

            ScrollView {
                VStack(spacing: 24) {
                    // Loadout preview
                    loadoutSection

                    // Arena preview
                    arenaPreview

                    // Stats
                    statsSection

                    // Launch button
                    launchButton
                }
                .padding()
            }
        }
    }

    private var loadoutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("LOADOUT")
                .font(DesignTypography.caption(12))
                .foregroundColor(DesignColors.muted)

            if let equipped = appState.currentPlayer.equippedProtocol() {
                HStack {
                    Image(systemName: equipped.iconName)
                        .font(.system(size: 32))
                        .foregroundColor(Color(hex: equipped.color) ?? .cyan)
                        .frame(width: 50, height: 50)
                        .background(DesignColors.surface)
                        .cornerRadius(10)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(equipped.name)
                            .font(DesignTypography.headline(16))
                            .foregroundColor(.white)

                        Text("DMG: \(Int(equipped.weaponStats.damage)) | RATE: \(String(format: "%.1f", equipped.weaponStats.fireRate))/s")
                            .font(DesignTypography.caption(11))
                            .foregroundColor(DesignColors.muted)
                    }

                    Spacer()

                    Text("LV \(equipped.level)")
                        .font(DesignTypography.headline(16))
                        .foregroundColor(DesignColors.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(DesignColors.primary.opacity(0.2))
                        .cornerRadius(8)
                }
                .padding()
                .background(DesignColors.surface)
                .cornerRadius(12)
            }
        }
    }

    private var arenaPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ARENA")
                .font(DesignTypography.caption(12))
                .foregroundColor(DesignColors.muted)

            VStack(spacing: 12) {
                // Arena visual preview
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(hex: "#0a0a0f") ?? .black)
                        .frame(height: 120)

                    // Grid pattern
                    Image(systemName: "square.grid.3x3")
                        .font(.system(size: 60))
                        .foregroundColor(DesignColors.primary.opacity(0.1))

                    // RAM module icons
                    HStack(spacing: 30) {
                        ForEach(0..<3, id: \.self) { _ in
                            Image(systemName: "memorychip")
                                .font(.system(size: 20))
                                .foregroundColor(DesignColors.primary.opacity(0.3))
                        }
                    }
                }

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("MEMORY CORE")
                            .font(DesignTypography.headline(16))
                            .foregroundColor(.white)
                        Text("Endless survival with dynamic events")
                            .font(DesignTypography.caption(11))
                            .foregroundColor(DesignColors.muted)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("1000 × 800")
                            .font(DesignTypography.caption(10))
                            .foregroundColor(DesignColors.muted)
                        Text("6 RAM MODULES")
                            .font(DesignTypography.caption(10))
                            .foregroundColor(DesignColors.muted)
                    }
                }
            }
            .padding()
            .background(DesignColors.surface)
            .cornerRadius(12)
        }
    }

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PERSONAL BEST")
                .font(DesignTypography.caption(12))
                .foregroundColor(DesignColors.muted)

            HStack(spacing: 16) {
                statBox(
                    label: "LONGEST UPTIME",
                    value: formatTime(appState.currentPlayer.survivorStats.longestSurvival),
                    icon: "clock.fill",
                    color: DesignColors.primary
                )

                statBox(
                    label: "TOTAL KILLS",
                    value: "\(appState.currentPlayer.survivorStats.totalSurvivorKills)",
                    icon: "flame.fill",
                    color: DesignColors.warning
                )

                statBox(
                    label: "RUNS",
                    value: "\(appState.currentPlayer.survivorStats.arenaRuns)",
                    icon: "play.circle.fill",
                    color: DesignColors.success
                )
            }
        }
    }

    private func statBox(label: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)

            Text(value)
                .font(DesignTypography.headline(16))
                .foregroundColor(.white)

            Text(label)
                .font(DesignTypography.caption(8))
                .foregroundColor(DesignColors.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(DesignColors.surface)
        .cornerRadius(10)
    }

    private var launchButton: some View {
        Button {
            HapticsService.shared.play(.medium)
            onLaunch()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "play.fill")
                    .font(.system(size: 20, weight: .bold))
                Text("START DEBUG SESSION")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                LinearGradient(
                    colors: [DesignColors.primary, DesignColors.primary.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Boss Encounters View

struct BossEncountersView: View {
    @ObservedObject var appState = AppState.shared
    @Binding var selectedDifficulty: BossDifficulty
    let onLaunch: (BossEncounter) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("BOSS_ENCOUNTERS")
                        .font(DesignTypography.display(28))
                        .foregroundColor(.white)
                    Text("Direct boss fights for blueprints")
                        .font(DesignTypography.caption(12))
                        .foregroundColor(DesignColors.muted)
                }

                Spacer()

                // Data balance
                HStack(spacing: 6) {
                    Text("◈")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(DesignColors.primary)
                    Text("\(appState.currentPlayer.data)")
                        .font(DesignTypography.headline(18))
                        .foregroundColor(DesignColors.primary)
                }
            }
            .padding()

            // Difficulty selector
            difficultySelector

            ScrollView {
                VStack(spacing: 16) {
                    ForEach(BossEncounter.all) { boss in
                        BossCard(
                            boss: boss,
                            difficulty: selectedDifficulty,
                            isUnlocked: isBossUnlocked(boss),
                            onSelect: { onLaunch(boss) },
                            onUnlock: { unlockBoss(boss) }
                        )
                    }
                }
                .padding()
            }
        }
    }

    private var difficultySelector: some View {
        HStack(spacing: 8) {
            ForEach(BossDifficulty.allCases, id: \.self) { difficulty in
                Button {
                    HapticsService.shared.play(.selection)
                    selectedDifficulty = difficulty
                } label: {
                    VStack(spacing: 4) {
                        Text(difficulty.rawValue.uppercased())
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                        Text(difficultyReward(difficulty))
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                    }
                    .foregroundColor(selectedDifficulty == difficulty ? .black : difficultyColor(difficulty))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        selectedDifficulty == difficulty ?
                            difficultyColor(difficulty) : difficultyColor(difficulty).opacity(0.2)
                    )
                    .cornerRadius(8)
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private func difficultyColor(_ difficulty: BossDifficulty) -> Color {
        switch difficulty {
        case .normal: return DesignColors.success
        case .hard: return DesignColors.warning
        case .nightmare: return DesignColors.error
        }
    }

    private func difficultyReward(_ difficulty: BossDifficulty) -> String {
        switch difficulty {
        case .normal: return "+50◈"
        case .hard: return "+150◈"
        case .nightmare: return "+300◈"
        }
    }

    private func isBossUnlocked(_ boss: BossEncounter) -> Bool {
        boss.unlockCost == 0 || appState.currentPlayer.data >= boss.unlockCost ||
            appState.currentPlayer.survivorStats.bossesDefeated > 0
    }

    private func unlockBoss(_ boss: BossEncounter) {
        guard appState.currentPlayer.data >= boss.unlockCost else { return }
        HapticsService.shared.play(.medium)
        // For now, bosses unlock by defeating the first one
    }
}

// MARK: - Boss Card

struct BossCard: View {
    let boss: BossEncounter
    let difficulty: BossDifficulty
    let isUnlocked: Bool
    let onSelect: () -> Void
    let onUnlock: () -> Void

    @ObservedObject var appState = AppState.shared

    var body: some View {
        Button(action: isUnlocked ? onSelect : onUnlock) {
            HStack(spacing: 16) {
                // Boss icon
                ZStack {
                    Circle()
                        .fill(Color(hex: boss.color)?.opacity(0.2) ?? Color.red.opacity(0.2))
                        .frame(width: 60, height: 60)

                    Image(systemName: boss.iconName)
                        .font(.system(size: 28))
                        .foregroundColor(Color(hex: boss.color) ?? .red)
                }

                // Boss info
                VStack(alignment: .leading, spacing: 4) {
                    Text(boss.name)
                        .font(DesignTypography.headline(16))
                        .foregroundColor(isUnlocked ? .white : DesignColors.muted)

                    Text(boss.subtitle)
                        .font(DesignTypography.caption(11))
                        .foregroundColor(Color(hex: boss.color) ?? .red)

                    Text(boss.description)
                        .font(DesignTypography.caption(10))
                        .foregroundColor(DesignColors.muted)
                        .lineLimit(2)
                }

                Spacer()

                // Right side: Rewards or lock
                if isUnlocked {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("REWARDS")
                            .font(DesignTypography.caption(8))
                            .foregroundColor(DesignColors.muted)

                        HStack(spacing: 4) {
                            ForEach(boss.rewards.prefix(2), id: \.self) { protocolId in
                                if let proto = ProtocolLibrary.get(protocolId) {
                                    Image(systemName: proto.iconName)
                                        .font(.system(size: 12))
                                        .foregroundColor(Color(hex: proto.color) ?? .cyan)
                                }
                            }
                        }

                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                            .foregroundColor(DesignColors.muted)
                    }
                } else {
                    VStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 20))
                            .foregroundColor(DesignColors.muted)

                        Text("\(boss.unlockCost)◈")
                            .font(DesignTypography.caption(10))
                            .foregroundColor(DesignColors.muted)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(DesignColors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isUnlocked ? Color(hex: boss.color)?.opacity(0.3) ?? Color.red.opacity(0.3) : Color.clear,
                                lineWidth: 1
                            )
                    )
            )
            .opacity(isUnlocked ? 1 : 0.6)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Boss Game View

struct BossGameView: View {
    let boss: BossEncounter
    let difficulty: BossDifficulty
    let `protocol`: Protocol
    let onExit: () -> Void

    @ObservedObject var appState = AppState.shared

    var body: some View {
        GameContainerView(
            gameMode: .boss,
            bossDifficulty: difficulty,
            onExit: onExit
        )
        .onAppear {
            // Set the boss type in AppState for GameContainerView to use
            appState.selectedArena = boss.bossId
        }
    }
}

// MARK: - Legacy Debug View (kept for fallback)

struct DebugView: View {
    @ObservedObject var appState = AppState.shared
    let onLaunch: (Sector) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("DEBUG_MODE")
                    .font(DesignTypography.display(28))
                    .foregroundColor(.white)

                Spacer()

                // Data balance
                HStack(spacing: 6) {
                    Image(systemName: "memorychip")
                        .foregroundColor(DesignColors.success)
                    Text("\(appState.currentPlayer.data)")
                        .font(DesignTypography.headline(18))
                        .foregroundColor(DesignColors.success)
                }
            }
            .padding()

            // Loadout preview
            loadoutPreview

            Divider()
                .background(DesignColors.muted.opacity(0.3))
                .padding(.horizontal)

            // Sector selection
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("SELECT_SECTOR")
                        .font(DesignTypography.caption(12))
                        .foregroundColor(DesignColors.muted)
                        .padding(.horizontal)

                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(SectorLibrary.all) { sector in
                            SectorCard(
                                sector: sector,
                                isUnlocked: appState.currentPlayer.isSectorUnlocked(sector.id),
                                bestTime: appState.currentPlayer.sectorBestTime(sector.id),
                                onSelect: { onLaunch(sector) },
                                onUnlock: { unlockSector(sector) }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
        }
    }

    private var loadoutPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("LOADOUT")
                .font(DesignTypography.caption(12))
                .foregroundColor(DesignColors.muted)

            if let equipped = appState.currentPlayer.equippedProtocol() {
                HStack {
                    Image(systemName: equipped.iconName)
                        .font(.system(size: 28))
                        .foregroundColor(Color(hex: equipped.color) ?? .cyan)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(equipped.name)
                            .font(DesignTypography.headline(16))
                            .foregroundColor(.white)

                        Text("DMG: \(Int(equipped.weaponStats.damage)) | RATE: \(String(format: "%.1f", equipped.weaponStats.fireRate))/s")
                            .font(DesignTypography.caption(11))
                            .foregroundColor(DesignColors.muted)
                    }

                    Spacer()

                    Text("LV \(equipped.level)")
                        .font(DesignTypography.headline(16))
                        .foregroundColor(DesignColors.primary)
                }
                .padding()
                .background(DesignColors.surface)
                .cornerRadius(12)
            }
        }
        .padding()
    }

    private func unlockSector(_ sector: Sector) {
        guard appState.currentPlayer.data >= sector.unlockCost else { return }
        HapticsService.shared.play(.medium)
        appState.updatePlayer { profile in
            profile.data -= sector.unlockCost
            profile.unlockedSectors.append(sector.id)
        }
    }
}

// MARK: - Sector Card

struct SectorCard: View {
    let sector: Sector
    let isUnlocked: Bool
    var bestTime: TimeInterval?
    let onSelect: () -> Void
    let onUnlock: () -> Void

    @ObservedObject var appState = AppState.shared

    private var isDungeon: Bool {
        sector.gameMode == .dungeon
    }

    var body: some View {
        VStack(spacing: 12) {
            // Header
            VStack(spacing: 4) {
                Text(sector.name)
                    .font(DesignTypography.headline(16))
                    .foregroundColor(isUnlocked ? .white : DesignColors.muted)

                Text(sector.subtitle)
                    .font(DesignTypography.caption(11))
                    .foregroundColor(DesignColors.muted)
            }

            // Mode badge (Dungeon vs Arena)
            HStack(spacing: 6) {
                Image(systemName: isDungeon ? "door.left.hand.open" : "sparkles")
                    .font(.system(size: 10))
                Text(isDungeon ? "DUNGEON" : "ARENA")
                    .font(DesignTypography.caption(9))
            }
            .foregroundColor(isDungeon ? DesignColors.secondary : DesignColors.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background((isDungeon ? DesignColors.secondary : DesignColors.primary).opacity(0.15))
            .cornerRadius(4)

            // Difficulty badge
            Text(sector.difficulty.displayName)
                .font(DesignTypography.caption(10))
                .foregroundColor(Color(hex: sector.difficulty.color) ?? .green)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(hex: sector.difficulty.color)?.opacity(0.2) ?? .green.opacity(0.2))
                .cornerRadius(4)

            // Data multiplier
            Text("◈ x\(String(format: "%.1f", sector.dataMultiplier))")
                .font(DesignTypography.caption(11))
                .foregroundColor(DesignColors.success)

            // Best time or lock status
            if isUnlocked {
                if let time = bestTime {
                    Text("Best: \(formatTime(time))")
                        .font(DesignTypography.caption(10))
                        .foregroundColor(DesignColors.muted)
                }

                Button(action: onSelect) {
                    Text("LAUNCH")
                        .font(DesignTypography.headline(14))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(DesignColors.success)
                        .cornerRadius(8)
                }
            } else {
                let canAfford = appState.currentPlayer.data >= sector.unlockCost
                Button(action: onUnlock) {
                    HStack {
                        Image(systemName: "lock.fill")
                        Text("\(sector.unlockCost)◈")
                    }
                    .font(DesignTypography.headline(14))
                    .foregroundColor(canAfford ? .white : DesignColors.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(canAfford ? DesignColors.surface : DesignColors.surface)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(canAfford ? DesignColors.primary : DesignColors.muted, lineWidth: 1)
                    )
                }
                .disabled(!canAfford)
            }
        }
        .padding()
        .background(DesignColors.surface)
        .cornerRadius(16)
        .opacity(isUnlocked ? 1.0 : 0.7)
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

// MARK: - Debug Game View (Full Active Mode with Protocol Weapon)

struct DebugGameView: View {
    let sector: Sector
    let `protocol`: Protocol
    let onExit: () -> Void

    @ObservedObject var appState = AppState.shared
    @State private var gameState: GameState?
    @State private var gameScene: GameScene?
    @State private var showGameOver = false
    @State private var showVictory = false
    @State private var showExtractionAvailable = false
    @State private var extractionTimer: Timer?
    @State private var hasExtracted = false
    @State private var inputState = InputState()  // For joystick control

    // Extraction becomes available after this many seconds
    private let extractionTimeThreshold: TimeInterval = 180  // 3 minutes

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Game scene
                if let scene = gameScene {
                    SpriteView(scene: scene)
                        .ignoresSafeArea()
                } else {
                    // Show loading while waiting for valid geometry
                    DesignColors.background
                        .ignoresSafeArea()
                    VStack {
                        ProgressView()
                            .tint(DesignColors.primary)
                        Text("INITIALIZING...")
                            .font(DesignTypography.caption(12))
                            .foregroundColor(DesignColors.muted)
                            .padding(.top, 8)
                    }
                }

                // Virtual joystick for movement (no momentum for direct control)
                VirtualJoystick(
                    onMove: { angle, distance in
                        inputState.joystick = JoystickInput(angle: angle, distance: distance)
                        gameScene?.updateInput(inputState)
                    },
                    onStop: {
                        inputState.joystick = nil
                        gameScene?.updateInput(inputState)
                    },
                    config: JoystickConfig(enableMomentum: false)
                )

                // HUD overlay (only show when game is running)
                if gameScene != nil {
                    VStack {
                        debugHUD
                        Spacer()
                    }
                }

                // Extraction available overlay
                if showExtractionAvailable && !showGameOver && !showVictory {
                    extractionOverlay
                }

                // Game over overlay
                if showGameOver || showVictory {
                    debugGameOverOverlay
                }
            }
            .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
                // Check if extraction should become available
                if let state = gameState,
                   !showExtractionAvailable && !hasExtracted,
                   state.timeElapsed >= extractionTimeThreshold {
                    withAnimation(.spring(response: 0.5)) {
                        showExtractionAvailable = true
                    }
                    HapticsService.shared.play(.success)
                }
            }
            .onChange(of: geometry.size) { newSize in
                if gameScene == nil && newSize.width > 0 && newSize.height > 0 {
                    setupDebugGame(screenSize: newSize)
                }
            }
            .onAppear {
                print("[DebugGameView] onAppear - geometry: \(geometry.size), gameScene: \(gameScene == nil ? "nil" : "exists")")
                // Also try on appear in case geometry is already valid
                if gameScene == nil && geometry.size.width > 0 && geometry.size.height > 0 {
                    setupDebugGame(screenSize: geometry.size)
                }
            }
        }
    }

    private var debugHUD: some View {
        HStack {
            // Health
            if let state = gameState {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                    Text("\(Int(state.player.health))/\(Int(state.player.maxHealth))")
                        .font(DesignTypography.headline(14))
                        .foregroundColor(.white)
                }
            }

            Spacer()

            // Sector name
            Text(sector.name)
                .font(DesignTypography.headline(16))
                .foregroundColor(DesignColors.success)

            Spacer()

            // Data collected
            if let state = gameState {
                HStack(spacing: 4) {
                    Image(systemName: "memorychip")
                        .foregroundColor(DesignColors.success)
                    Text("\(Int(CGFloat(state.stats.enemiesKilled) * sector.dataMultiplier))")
                        .font(DesignTypography.headline(14))
                        .foregroundColor(DesignColors.success)
                }
            }

            Spacer()

            // Time
            if let state = gameState {
                Text(formatTime(state.timeElapsed))
                    .font(DesignTypography.headline(14))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.7))
    }

    private var extractionOverlay: some View {
        VStack {
            Spacer()

            VStack(spacing: 16) {
                // Header
                HStack {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(DesignColors.success)

                    Text("EXTRACTION AVAILABLE")
                        .font(DesignTypography.headline(18))
                        .foregroundColor(DesignColors.success)
                }

                // Current data
                if let state = gameState {
                    let baseData = state.stats.enemiesKilled
                    let multipliedData = Int(CGFloat(baseData) * sector.dataMultiplier)

                    HStack(spacing: 4) {
                        Image(systemName: "memorychip")
                            .foregroundColor(DesignColors.success)
                        Text("\(multipliedData) DATA SECURED")
                            .font(DesignTypography.body(14))
                            .foregroundColor(.white)
                    }
                }

                // Choice buttons
                HStack(spacing: 16) {
                    // Extract Now button
                    Button {
                        HapticsService.shared.play(.success)
                        hasExtracted = true
                        showExtractionAvailable = false
                        showVictory = true
                    } label: {
                        VStack(spacing: 4) {
                            Text("EXTRACT")
                                .font(DesignTypography.headline(16))
                            Text("Keep 100% Data")
                                .font(DesignTypography.caption(10))
                                .opacity(0.7)
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(DesignColors.success)
                        .cornerRadius(10)
                    }

                    // Continue button
                    Button {
                        HapticsService.shared.play(.light)
                        withAnimation {
                            showExtractionAvailable = false
                            hasExtracted = true  // Don't show extraction again
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Text("CONTINUE")
                                .font(DesignTypography.headline(16))
                            Text("Risk for more")
                                .font(DesignTypography.caption(10))
                                .opacity(0.7)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(DesignColors.danger.opacity(0.8))
                        .cornerRadius(10)
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(DesignColors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(DesignColors.success, lineWidth: 2)
                    )
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 100)  // Above virtual joystick area
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var debugGameOverOverlay: some View {
        ZStack {
            Color.black.opacity(0.9).ignoresSafeArea()

            VStack(spacing: 24) {
                // Title
                Text(showVictory ? "SECTOR_CLEANSED" : "DEBUG_FAILED")
                    .font(DesignTypography.display(32))
                    .foregroundColor(showVictory ? DesignColors.success : DesignColors.danger)

                // Stats
                if let state = gameState {
                    VStack(spacing: 12) {
                        let baseData = state.stats.enemiesKilled
                        let multipliedData = Int(CGFloat(baseData) * sector.dataMultiplier)
                        let finalData = showVictory ? multipliedData : multipliedData / 2

                        HStack {
                            Text("Viruses Eliminated")
                                .foregroundColor(DesignColors.muted)
                            Spacer()
                            Text("\(state.stats.enemiesKilled)")
                                .foregroundColor(.white)
                        }

                        HStack {
                            Text("Data Collected")
                                .foregroundColor(DesignColors.muted)
                            Spacer()
                            HStack(spacing: 4) {
                                Image(systemName: "memorychip")
                                    .foregroundColor(DesignColors.success)
                                Text("+\(finalData)")
                                    .foregroundColor(DesignColors.success)
                            }
                        }

                        HStack {
                            Text("Time Survived")
                                .foregroundColor(DesignColors.muted)
                            Spacer()
                            Text(formatTime(state.timeElapsed))
                                .foregroundColor(.white)
                        }
                    }
                    .font(DesignTypography.body(16))
                    .padding()
                    .background(DesignColors.surface)
                    .cornerRadius(12)
                    .frame(maxWidth: 300)
                }

                // Exit button
                Button {
                    // Award Data before exiting
                    if let state = gameState {
                        let baseData = state.stats.enemiesKilled
                        let multipliedData = Int(CGFloat(baseData) * sector.dataMultiplier)
                        let finalData = showVictory ? multipliedData : multipliedData / 2
                        appState.updatePlayer { profile in
                            profile.data += max(1, finalData)
                        }
                    }
                    onExit()
                } label: {
                    Text("COLLECT & EXIT")
                        .font(DesignTypography.headline(18))
                        .foregroundColor(.black)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 16)
                        .background(DesignColors.primary)
                        .cornerRadius(12)
                }
            }
            .padding()
        }
    }

    private func setupDebugGame(screenSize: CGSize) {
        print("[DebugGameView] setupDebugGame - screenSize: \(screenSize), sector.gameMode: \(sector.gameMode)")

        // Create game state based on sector's game mode
        var state: GameState
        if sector.gameMode == .dungeon, let bossType = sector.dungeonType {
            // Use boss mode - direct boss encounter
            state = GameStateFactory.shared.createBossGameState(
                gameProtocol: `protocol`,
                bossType: mapDungeonToBoss(bossType),
                difficulty: .normal,
                playerProfile: appState.currentPlayer
            )
            print("[DebugGameView] Created BOSS state - boss: \(state.activeBossId ?? "none")")
        } else {
            // Use survival mode (survival waves)
            state = GameStateFactory.shared.createDebugGameState(
                gameProtocol: `protocol`,
                sector: sector,
                playerProfile: appState.currentPlayer
            )
            print("[DebugGameView] Created SURVIVAL state - arena: \(state.arena.width)x\(state.arena.height)")
        }
        gameState = state

        print("[DebugGameView] Player at: (\(state.player.x), \(state.player.y))")

        // Create and configure scene
        let scene = GameScene()
        scene.configure(gameState: state, screenSize: screenSize)
        scene.onGameOver = { finalState in
            gameState = finalState
            if finalState.victory {
                showVictory = true
            } else {
                showGameOver = true
            }
            HapticsService.shared.play(finalState.victory ? .success : .warning)
        }
        scene.onStateUpdate = { updatedState in
            gameState = updatedState
        }

        gameScene = scene
    }

    /// Map old dungeon types to boss encounter IDs
    private func mapDungeonToBoss(_ dungeonType: String) -> String {
        switch dungeonType {
        case "cathedral": return "voidharbinger"
        case "void_raid": return "voidharbinger"
        case "heist": return "cyberboss"
        case "frozen": return "frost_titan"
        case "volcanic": return "inferno_lord"
        default: return "cyberboss"
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

// MARK: - Preview

#Preview {
    SystemTabView()
}
