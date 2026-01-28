import SwiftUI
import SpriteKit

// MARK: - Motherboard View (Idle Mode)
// Main SwiftUI view for System Defense / Idle mode
// You are an AI protecting a computer system from viruses
// Implements progressive disclosure: show only what's needed, when it's needed

struct TDGameContainerView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @State private var gameState: TDGameState?
    @State private var scene: TDGameScene?
    @State private var delegateHandler: TDGameSceneDelegateHandler?
    @State private var selectedSlotId: String?
    @State private var selectedTowerId: String?
    @State private var showTowerMenu = false
    @State private var showGameOver = false
    @State private var isPaused = false

    // Drag-from-deck state (progressive disclosure - grid only visible during drag)
    @State private var isDraggingFromDeck = false
    @State private var draggedWeaponType: String?
    @State private var dragPosition: CGPoint = .zero
    @State private var nearestValidSlot: TowerSlot?
    @State private var canAffordDraggedTower = false
    @State private var previousNearestSlot: TowerSlot?  // For snap detection

    // Blocker mode state
    @State private var isBlockerModeActive = false
    @State private var selectedBlockerSlotId: String?

    // System Freeze state (0% efficiency)
    @State private var showSystemFreeze = false
    @State private var isPerformingManualOverride = false

    // Zero-Day Boss Fight state
    @State private var showZeroDayBossFight = false
    @State private var zeroDayBossFightResult: ZeroDayBossFightResult?

    // Sector unlock panel state (mega-board)
    @State private var showSectorUnlockPanel = false
    @State private var selectedSectorForUnlock: String?

    let mapId: String

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Game scene - full screen
                if let scene = scene {
                    SpriteView(scene: scene)
                        .ignoresSafeArea()
                }

                // HUD overlay - respects safe areas
                VStack(spacing: 0) {
                    // Top bar - below notch
                    topBar
                        .safeAreaInset(edge: .top) { Color.clear.frame(height: 0) }

                    Spacer()

                    // Tower deck at bottom - above home indicator
                    towerDeck(geometry: geometry)
                        .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 0) }
                }

                // Selected tower info panel
                if let towerId = selectedTowerId,
                   let tower = gameState?.towers.first(where: { $0.id == towerId }) {
                    towerInfoPanel(tower: tower, geometry: geometry)
                }

                // Drag preview overlay
                if isDraggingFromDeck, let weaponType = draggedWeaponType {
                    dragPreviewOverlay(weaponType: weaponType, geometry: geometry)
                }

                // Zero-Day Alert overlay (System Breach)
                if let state = gameState, state.zeroDayActive, !showSystemFreeze {
                    zeroDayAlertOverlay
                }

                // System Freeze overlay (0% efficiency)
                if showSystemFreeze {
                    systemFreezeOverlay
                }

                // Pause overlay
                if isPaused && !showSystemFreeze {
                    pauseOverlay
                }

                // Game over overlay
                if showGameOver {
                    gameOverOverlay
                }

                // Sector unlock panel (mega-board)
                if showSectorUnlockPanel, let sectorId = selectedSectorForUnlock {
                    sectorUnlockPanel(sectorId: sectorId)
                }
            }
            .coordinateSpace(name: "gameArea")
        }
        .onAppear {
            setupGame()
        }
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $showZeroDayBossFight) {
            ZeroDayBossFightView(
                onComplete: { result in
                    zeroDayBossFightResult = result
                    handleZeroDayBossFightResult(result)
                    showZeroDayBossFight = false
                }
            )
        }
    }

    // MARK: - Zero-Day Alert Overlay (System Breach)

    private var zeroDayAlertOverlay: some View {
        VStack {
            Spacer()

            // Alert banner at bottom of screen (above tower deck)
            VStack(spacing: 12) {
                // Warning header
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(DesignTypography.headline(22))
                        .foregroundColor(.red)

                    Text("SYSTEM_BREACH_DETECTED")
                        .font(.system(size: 18, weight: .black, design: .monospaced))
                        .foregroundColor(.red)

                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(DesignTypography.headline(22))
                        .foregroundColor(.red)
                }

                Text("Zero-Day virus detected! Firewalls ineffective.")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.gray)

                Text("Efficiency draining: -2%/sec")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.orange)

                // MANUAL_OVERRIDE button
                Button(action: {
                    initiateManualOverride()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "person.fill.viewfinder")
                            .font(DesignTypography.headline(18))
                        Text("MANUAL_OVERRIDE")
                            .font(.system(size: 16, weight: .black, design: .monospaced))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.green)
                    )
                    .shadow(color: .green.opacity(0.6), radius: 10)
                }
                .padding(.top, 4)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.95))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.red.opacity(0.8), lineWidth: 2)
                    )
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 130) // Above tower deck
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: gameState?.zeroDayActive)
    }

    // MARK: - Manual Override (Zero-Day Boss Fight)

    private func initiateManualOverride() {
        HapticsService.shared.play(.warning)

        // Pause the TD game and launch boss fight
        isPaused = true
        showZeroDayBossFight = true
    }

    private func handleZeroDayBossFightResult(_ result: ZeroDayBossFightResult) {
        isPaused = false

        switch result {
        case .victory(let dataBonus, let wattsBonus):
            // Apply rewards and remove Zero-Day
            if var state = gameState {
                _ = ZeroDaySystem.onZeroDayDefeated(state: &state)
                gameState = state
                scene?.restoreEfficiency(to: max(0, state.leakCounter - 5))  // Bonus: restore some efficiency
            }

            appState.updatePlayer { profile in
                profile.data += dataBonus
                profile.addHash(wattsBonus)
            }

            HapticsService.shared.play(.success)

        case .defeat:
            // Zero-Day remains active, efficiency penalty
            if var state = gameState {
                state.leakCounter = min(20, state.leakCounter + 5)  // -25% efficiency penalty
                gameState = state
            }
            HapticsService.shared.play(.defeat)

        case .fled:
            // Zero-Day remains active, no penalty
            HapticsService.shared.play(.light)
        }
    }

    // MARK: - System Freeze Overlay (0% Efficiency)

    private var systemFreezeOverlay: some View {
        ZStack {
            // Dark overlay with scan line effect
            Color.black.opacity(0.95)
                .ignoresSafeArea()

            // Glitch-style lines
            VStack(spacing: 4) {
                ForEach(0..<50, id: \.self) { _ in
                    Rectangle()
                        .fill(Color.red.opacity(Double.random(in: 0.05...0.15)))
                        .frame(height: CGFloat.random(in: 1...3))
                }
            }
            .ignoresSafeArea()

            VStack(spacing: 24) {
                // Critical error header
                VStack(spacing: 12) {
                    Image(systemName: "xmark.octagon.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.red)

                    Text("SYSTEM_FREEZE")
                        .font(.system(size: 32, weight: .black, design: .monospaced))
                        .foregroundColor(.red)

                    Text("CRITICAL ERROR: EFFICIENCY 0%")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(.gray)

                    Text("Watts generation halted")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.orange)
                }

                // Reboot options
                VStack(spacing: 16) {
                    Text("SELECT_REBOOT_PROTOCOL")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)

                    // Option 1: Flush Memory (Pay Watts)
                    let flushCost = max(100, appState.currentPlayer.hash / 10)  // 10% of banked Watts
                    let canAffordFlush = appState.currentPlayer.hash >= flushCost

                    Button(action: {
                        performFlushMemory(cost: flushCost)
                    }) {
                        VStack(spacing: 6) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 18, weight: .bold))
                                Text("FLUSH MEMORY")
                                    .font(.system(size: 16, weight: .black, design: .monospaced))
                            }

                            Text("Cost: \(flushCost)⚡ → Restore to 50%")
                                .font(.system(size: 11, design: .monospaced))
                                .opacity(0.8)
                        }
                        .foregroundColor(canAffordFlush ? .black : .gray)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(canAffordFlush ? Color.cyan : Color.gray.opacity(0.3))
                        )
                    }
                    .disabled(!canAffordFlush)

                    // Option 2: Manual Override (Survival mini-game)
                    Button(action: {
                        performManualOverrideReboot()
                    }) {
                        VStack(spacing: 6) {
                            HStack(spacing: 8) {
                                Image(systemName: "person.fill.viewfinder")
                                    .font(.system(size: 18, weight: .bold))
                                Text("MANUAL_OVERRIDE")
                                    .font(.system(size: 16, weight: .black, design: .monospaced))
                            }

                            Text("Survive 30 seconds → Restore to 100%")
                                .font(.system(size: 11, design: .monospaced))
                                .opacity(0.8)
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.green)
                        )
                    }
                }
                .padding(.horizontal, 40)
            }
        }
        .transition(.opacity)
    }

    private func performFlushMemory(cost: Int) {
        HapticsService.shared.play(.medium)

        // Deduct cost
        appState.updatePlayer { profile in
            profile.hash -= cost
        }

        // Restore efficiency to 50%
        // Note: We update the scene's state indirectly - the scene will pick up changes
        // through the game loop. For immediate effect, we need to update the scene's internal state.
        scene?.restoreEfficiency(to: 10)  // 50% efficiency = 10 leaks (100 - 10*5 = 50)

        withAnimation {
            showSystemFreeze = false
        }
    }

    private func performManualOverrideReboot() {
        HapticsService.shared.play(.warning)
        isPerformingManualOverride = true

        // TODO: Launch 30-second survival mini-game
        // For now, just restore to 100% as placeholder
        scene?.restoreEfficiency(to: 0)  // 100% efficiency = 0 leaks

        withAnimation {
            showSystemFreeze = false
            isPerformingManualOverride = false
        }

        HapticsService.shared.play(.success)
    }

    // MARK: - Top Bar (Simplified HUD)
    // Clean, minimal HUD with only essential info

    private var topBar: some View {
        HStack(spacing: 16) {
            // Left: Pause + Wave
            HStack(spacing: 10) {
                Button(action: {
                    isPaused = true
                    HapticsService.shared.play(.light)
                }) {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(8)
                }

                Text("WAVE \(gameState?.currentWave ?? 0)")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }

            Spacer()

            // Center: Efficiency bar (wider, more visible)
            HStack(spacing: 6) {
                let efficiency = calculateEfficiency()
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.3))
                        RoundedRectangle(cornerRadius: 4)
                            .fill(efficiencyColor)
                            .frame(width: geo.size.width * efficiency / 100)
                    }
                }
                .frame(width: 80, height: 10)

                Text("\(Int(efficiency))%")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(efficiencyColor)
            }

            Spacer()

            // Right: Power & Hash
            HStack(spacing: 12) {
                // Power usage (PSU capacity)
                HStack(spacing: 3) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 14))
                        .foregroundColor(powerColor)
                    Text("\(gameState?.powerUsed ?? 0)/\(gameState?.powerCapacity ?? 450)W")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(powerColor)
                }

                // Hash balance
                HStack(spacing: 3) {
                    Image(systemName: "number.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.cyan)
                    Text("\(gameState?.hash ?? 0)")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.7))
    }

    // MARK: - Wave Controls (Auto-start, no manual button needed)
    // Waves auto-start - this view just shows current wave status

    private var waveControls: some View {
        EmptyView()  // No manual controls needed - waves auto-start
    }

    // MARK: - Tower Deck (Large Touch-Friendly)

    private func towerDeck(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            // Hint text
            Text("DRAG FIREWALL TO DEPLOY")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.gray)
                .padding(.top, 6)

            // Scrollable tower cards - large and touch-friendly
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // Use Protocol-based deck if player has compiled protocols
                    let protocols = getCompiledProtocols()
                    if !protocols.isEmpty {
                        ForEach(protocols) { proto in
                            ProtocolDeckCard(
                                protocol: proto,
                                hash: gameState?.hash ?? 0,
                                onDragStart: { startDragFromDeck(weaponType: proto.id) },
                                onDragChanged: { value in updateDragPosition(value, geometry: geometry) },
                                onDragEnded: { endDragFromDeck() }
                            )
                        }
                    } else {
                        // Fallback to legacy weapon system
                        ForEach(getAvailableTowers(), id: \.id) { weapon in
                            TowerDeckCard(
                                weapon: weapon,
                                gold: gameState?.hash ?? 0,
                                onDragStart: { startDragFromDeck(weaponType: weapon.id) },
                                onDragChanged: { value in updateDragPosition(value, geometry: geometry) },
                                onDragEnded: { endDragFromDeck() }
                            )
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
        .frame(height: 110)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.95), Color.black.opacity(0.7)],
                startPoint: .bottom,
                endPoint: .top
            )
        )
    }

    // MARK: - Drag Preview Overlay (Progressive Disclosure)
    // Note: Grid dots are now shown in the SpriteKit scene, not here
    // This overlay only shows the dragged tower preview

    private func dragPreviewOverlay(weaponType: String, geometry: GeometryProxy) -> some View {
        ZStack {
            // The grid dots are rendered in TDGameScene now (progressive disclosure)
            // Only the dragged tower preview is shown here in SwiftUI

            // Check if this is a Protocol (System: Reboot) or legacy weapon
            if let proto = ProtocolLibrary.get(weaponType) {
                // Protocol-based preview
                let displayPosition = nearestValidSlot != nil && canAffordDraggedTower
                    ? convertGameToScreen(nearestValidSlot!.position, geometry: geometry)
                    : dragPosition
                let protoColor = Color(hex: proto.color) ?? DesignColors.primary
                let range = proto.firewallStats.range

                ZStack {
                    // Range preview circle (shown when snapped to valid slot)
                    if nearestValidSlot != nil && canAffordDraggedTower {
                        Circle()
                            .fill(protoColor.opacity(DesignLayout.rangeCircleFillOpacity))
                            .frame(width: range * 0.6, height: range * 0.6)

                        Circle()
                            .stroke(protoColor.opacity(DesignLayout.rangeCircleStrokeOpacity), lineWidth: 2)
                            .frame(width: range * 0.6, height: range * 0.6)
                    }

                    // Tower preview body
                    Circle()
                        .fill(protoColor.opacity(DesignLayout.towerPreviewOpacity))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle()
                                .stroke(
                                    canAffordDraggedTower ? Color.white : DesignColors.danger,
                                    lineWidth: 2
                                )
                        )
                        .shadow(
                            color: canAffordDraggedTower
                                ? protoColor.opacity(0.6)
                                : DesignColors.danger.opacity(0.4),
                            radius: canAffordDraggedTower ? 12 : 6
                        )

                    // Protocol icon
                    Image(systemName: proto.iconName)
                        .font(DesignTypography.headline(18))
                        .foregroundColor(.white)

                    // Cost indicator (Watts)
                    Text("\(TowerSystem.towerPlacementCost(rarity: proto.rarity))W")
                        .font(DesignTypography.caption(11))
                        .fontWeight(.bold)
                        .foregroundColor(canAffordDraggedTower ? DesignColors.primary : DesignColors.danger)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(DesignColors.surface.opacity(0.9))
                        .cornerRadius(4)
                        .offset(y: 32)
                }
                .position(displayPosition)
                .animation(DesignAnimations.quick, value: nearestValidSlot?.id)

            } else if let weapon = GameConfigLoader.shared.getWeapon(weaponType) {
                // Legacy weapon preview
                let displayPosition = nearestValidSlot != nil && canAffordDraggedTower
                    ? convertGameToScreen(nearestValidSlot!.position, geometry: geometry)
                    : dragPosition

                ZStack {
                    // Range preview circle (shown when snapped to valid slot)
                    if nearestValidSlot != nil && canAffordDraggedTower {
                        Circle()
                            .fill(RarityColors.color(for: weapon.rarity).opacity(DesignLayout.rangeCircleFillOpacity))
                            .frame(width: CGFloat(weapon.range) * 0.6, height: CGFloat(weapon.range) * 0.6)

                        Circle()
                            .stroke(RarityColors.color(for: weapon.rarity).opacity(DesignLayout.rangeCircleStrokeOpacity), lineWidth: 2)
                            .frame(width: CGFloat(weapon.range) * 0.6, height: CGFloat(weapon.range) * 0.6)
                    }

                    // Tower preview body
                    Circle()
                        .fill(RarityColors.color(for: weapon.rarity).opacity(DesignLayout.towerPreviewOpacity))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle()
                                .stroke(
                                    canAffordDraggedTower ? Color.white : DesignColors.danger,
                                    lineWidth: 2
                                )
                        )
                        .shadow(
                            color: canAffordDraggedTower
                                ? DesignColors.primary.opacity(0.6)
                                : DesignColors.danger.opacity(0.4),
                            radius: canAffordDraggedTower ? 12 : 6
                        )

                    // Weapon icon
                    Image(systemName: iconForWeapon(weapon.id))
                        .font(DesignTypography.headline(18))
                        .foregroundColor(.white)

                    // Cost indicator (Watts)
                    Text("\(TowerSystem.towerPlacementCost(rarity: Rarity(rawValue: weapon.rarity) ?? .common))W")
                        .font(DesignTypography.caption(11))
                        .fontWeight(.bold)
                        .foregroundColor(canAffordDraggedTower ? DesignColors.primary : DesignColors.danger)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(DesignColors.surface.opacity(0.9))
                        .cornerRadius(4)
                        .offset(y: 32)
                }
                .position(displayPosition)
                .animation(DesignAnimations.quick, value: nearestValidSlot?.id)
            }
        }
        .allowsHitTesting(false)
    }

    /// Get SF Symbol icon for firewall type (System: Reboot themed)
    private func iconForWeapon(_ weaponType: String) -> String {
        // Check if this is a Protocol ID first
        if let proto = ProtocolLibrary.get(weaponType) {
            return proto.iconName
        }

        // Legacy weapon icons
        switch weaponType {
        case "bow", "crossbow": return "antenna.radiowaves.left.and.right"  // Signal firewall
        case "wand", "staff": return "wand.and.rays"                        // Magic/scan firewall
        case "cannon", "bomb": return "burst.fill"                          // Burst firewall
        case "ice_shard": return "snowflake"                                // Freeze firewall
        case "laser": return "rays"                                         // Laser firewall
        case "flamethrower": return "flame.fill"                            // Purge firewall
        case "sword", "katana": return "bolt.fill"                          // Chain firewall
        default: return "shield.fill"                                       // Basic firewall
        }
    }

    // MARK: - Drag Handling (Progressive Disclosure)

    private func startDragFromDeck(weaponType: String) {
        isDraggingFromDeck = true
        draggedWeaponType = weaponType
        previousNearestSlot = nil

        // Check affordability - Protocol or legacy weapon
        if let proto = ProtocolLibrary.get(weaponType) {
            let cost = TowerSystem.towerPlacementCost(rarity: proto.rarity)
            canAffordDraggedTower = (gameState?.hash ?? 0) >= cost
        } else if let weapon = GameConfigLoader.shared.getWeapon(weaponType) {
            let cost = TowerSystem.towerPlacementCost(rarity: Rarity(rawValue: weapon.rarity) ?? .common)
            canAffordDraggedTower = (gameState?.hash ?? 0) >= cost
        }

        // Enter placement mode - shows grid dots (progressive disclosure)
        scene?.enterPlacementMode(weaponType: weaponType)

        HapticsService.shared.play(.selection)
    }

    private func updateDragPosition(_ value: DragGesture.Value, geometry: GeometryProxy) {
        dragPosition = value.location

        // Find nearest valid slot
        if let state = gameState {
            let gamePos = convertScreenToGame(dragPosition, geometry: geometry)
            var nearest: TowerSlot?

            // Calculate scale-adjusted snap distance (60 screen pixels worth)
            // Use camera scale if available, otherwise compute from view/scene ratio
            let cameraScale = scene?.cameraScale ?? 1.0
            // Snap distance in game units: larger when zoomed out, smaller when zoomed in
            let snapDistanceInGameUnits: CGFloat = 60 * cameraScale

            var minDistance: CGFloat = snapDistanceInGameUnits

            for slot in state.towerSlots where !slot.occupied {
                let dx = slot.x - gamePos.x
                let dy = slot.y - gamePos.y
                let distance = sqrt(dx*dx + dy*dy)
                if distance < minDistance {
                    minDistance = distance
                    nearest = slot
                }
            }

            // Check if we snapped to a new slot
            if nearestValidSlot?.id != nearest?.id {
                previousNearestSlot = nearestValidSlot
                nearestValidSlot = nearest

                // Update scene highlight
                scene?.highlightNearestSlot(nearest, canAfford: canAffordDraggedTower)

                // Snap haptic when entering a new valid slot
                if nearest != nil && canAffordDraggedTower {
                    HapticsService.shared.play(.slotSnap)
                }
            }
        }
    }

    private func endDragFromDeck() {
        // Exit placement mode - hides grid dots
        scene?.exitPlacementMode()

        defer {
            isDraggingFromDeck = false
            draggedWeaponType = nil
            nearestValidSlot = nil
            previousNearestSlot = nil
        }

        // Place tower if valid
        if let weaponType = draggedWeaponType,
           let slot = nearestValidSlot,
           canAffordDraggedTower {
            scene?.placeTower(weaponType: weaponType, slotId: slot.id, profile: appState.currentPlayer)
            HapticsService.shared.play(.towerPlace)
        }
    }

    // MARK: - Coordinate Conversion
    // The SpriteView renders full-screen with .aspectFill scaleMode
    // Game space is 800x600, screen space varies by device
    // With aspectFill, the scene is scaled up until it fills the screen (may crop edges)

    private let topHUDHeight: CGFloat = 50
    private let bottomDeckHeight: CGFloat = 110

    private func convertGameToScreen(_ point: CGPoint, geometry: GeometryProxy) -> CGPoint {
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

    private func convertScreenToGame(_ point: CGPoint, geometry: GeometryProxy) -> CGPoint {
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

    // MARK: - Tower Selection Menu

    private func towerSelectionMenu(slotId: String) -> some View {
        VStack(spacing: 12) {
            Text("DEPLOY_FIREWALL")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(.cyan)

            ForEach(getAvailableTowers(), id: \.id) { weapon in
                let cost = TowerSystem.towerPlacementCost(rarity: Rarity(rawValue: weapon.rarity) ?? .common)
                let canAfford = (gameState?.hash ?? 0) >= cost

                Button(action: {
                    placeTower(weaponType: weapon.id, slotId: slotId)
                }) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(weapon.towerName ?? weapon.name)
                                .font(.system(size: 14, weight: .medium, design: .monospaced))
                            Text("DMG: \(Int(weapon.damage)) | RNG: \(Int(weapon.range))")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.gray)
                        }

                        Spacer()

                        Text("\(cost)W")
                            .foregroundColor(canAfford ? .cyan : .red)
                            .fontWeight(.bold)
                            .font(.system(size: 14, design: .monospaced))
                    }
                    .padding(10)
                    .background(rarityColor(weapon.rarity).opacity(0.3))
                    .cornerRadius(8)
                }
                .disabled(!canAfford)
                .opacity(canAfford ? 1 : 0.5)
            }

            Button("CANCEL") {
                showTowerMenu = false
                selectedSlotId = nil
            }
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundColor(.gray)
            .padding(.top, 8)
        }
        .padding(16)
        .background(Color.black.opacity(0.95))
        .cornerRadius(16)
        .frame(maxWidth: 300)
    }

    // MARK: - Tower Info Panel

    private func towerInfoPanel(tower: Tower, geometry: GeometryProxy) -> some View {
        let towerScreenPos = convertGameToScreen(tower.position, geometry: geometry)
        // Position panel to the side of the tower, avoiding edges
        let panelX = towerScreenPos.x > geometry.size.width / 2
            ? towerScreenPos.x - 120
            : towerScreenPos.x + 120
        let panelY = min(max(towerScreenPos.y, 150), geometry.size.height - 200)

        return VStack(alignment: .leading, spacing: 8) {
            // Header with name and merge stars
            HStack {
                Text(tower.towerName)
                    .font(DesignTypography.headline(16))
                    .foregroundColor(.white)

                Spacer()

                // Merge stars
                HStack(spacing: 2) {
                    ForEach(0..<tower.mergeLevel, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(DesignTypography.caption(12))
                            .foregroundColor(.yellow)
                    }
                    ForEach(0..<(3 - tower.mergeLevel), id: \.self) { _ in
                        Image(systemName: "star")
                            .font(DesignTypography.caption(12))
                            .foregroundColor(.gray)
                    }
                }
            }

            Text("Level: \(tower.level)/10")
                .font(DesignTypography.caption(12))
                .foregroundColor(.gray)

            Divider().background(Color.white.opacity(0.3))

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    TDStatRow(icon: "flame.fill", label: "DMG", value: String(format: "%.1f", tower.damage), color: .orange)
                    TDStatRow(icon: "scope", label: "RNG", value: String(format: "%.0f", tower.range), color: .blue)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    TDStatRow(icon: "bolt.fill", label: "SPD", value: String(format: "%.2f/s", tower.attackSpeed), color: .yellow)
                    TDStatRow(icon: "chart.line.uptrend.xyaxis", label: "DPS", value: String(format: "%.1f", tower.damage * tower.attackSpeed), color: .green)
                }
            }
            .font(DesignTypography.caption(12))

            Divider().background(Color.white.opacity(0.3))

            // Action buttons
            HStack(spacing: 8) {
                if tower.canUpgrade {
                    Button(action: { upgradeTower(tower.id) }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.circle.fill")
                            Text("\(tower.upgradeCost)W")
                        }
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background((gameState?.hash ?? 0) >= tower.upgradeCost ? Color.cyan : Color.gray)
                        .cornerRadius(6)
                    }
                    .disabled((gameState?.hash ?? 0) < tower.upgradeCost)
                }

                Button(action: { sellTower(tower.id) }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.uturn.backward.circle.fill")
                        Text("Recycle")
                    }
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.8))
                    .cornerRadius(6)
                }

                // Close button
                Spacer()
                Button(action: { selectedTowerId = nil }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(DesignTypography.headline(18))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .foregroundColor(.white)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.95))
                .shadow(color: rarityColorForTower(tower).opacity(0.5), radius: 8)
        )
        .frame(width: 200)
        .position(x: panelX, y: panelY)
    }

    private func rarityColorForTower(_ tower: Tower) -> Color {
        // Get rarity from weapon config
        if let weapon = GameConfigLoader.shared.getWeapon(tower.weaponType) {
            return rarityColor(weapon.rarity)
        }
        return .gray
    }

    // MARK: - Pause Overlay

    private var pauseOverlay: some View {
        ZStack {
            Color.black.opacity(0.9)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                VStack(spacing: 8) {
                    Text("SYSTEM_PAUSED")
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)
                    Text("Defense protocols suspended")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(.gray)
                }

                // CPU Upgrade Section
                cpuUpgradeSection

                VStack(spacing: 16) {
                    Button(action: {
                        isPaused = false
                        HapticsService.shared.play(.light)
                    }) {
                        Text("RESUME")
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundColor(.black)
                            .frame(width: 220, height: 56)
                            .background(Color.green)
                            .cornerRadius(12)
                    }

                    Button(action: {
                        HapticsService.shared.play(.light)
                        dismiss()
                    }) {
                        Text("ABORT")
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .frame(width: 220, height: 56)
                            .background(Color.red.opacity(0.8))
                            .cornerRadius(12)
                    }
                }
            }
        }
    }

    // MARK: - CPU Upgrade Section

    private var cpuUpgradeSection: some View {
        let cpuInfo = StorageService.shared.getCpuTierInfo()
        let canUpgrade = cpuInfo.nextCost != nil && appState.currentPlayer.hash >= (cpuInfo.nextCost ?? 0)

        return VStack(spacing: 12) {
            // Current CPU info
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CPU_TIER")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.gray)
                    HStack(spacing: 4) {
                        Image(systemName: "cpu")
                            .font(DesignTypography.headline(22))
                        Text("\(cpuInfo.tier).0")
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                    }
                    .foregroundColor(.cyan)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("MULTIPLIER")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.gray)
                    Text("\(String(format: "%.0f", cpuInfo.multiplier))x")
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(.green)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("WATTS")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.gray)
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                        Text("\(appState.currentPlayer.hash)")
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                    }
                    .foregroundColor(.cyan)
                }
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)

            // Upgrade button (if not max tier)
            if let upgradeCost = cpuInfo.nextCost {
                Button(action: {
                    upgradeCpu()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.up.circle.fill")
                        Text("UPGRADE TO CPU \(cpuInfo.tier + 1).0")
                        Spacer()
                        Text("\(upgradeCost)W")
                            .fontWeight(.bold)
                    }
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(canUpgrade ? .black : .gray)
                    .padding()
                    .background(canUpgrade ? Color.cyan : Color.gray.opacity(0.3))
                    .cornerRadius(10)
                }
                .disabled(!canUpgrade)
            } else {
                Text("MAX CPU_TIER")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.yellow)
                    .padding()
                    .background(Color.yellow.opacity(0.2))
                    .cornerRadius(10)
            }
        }
        .frame(width: 280)
    }

    // MARK: - CPU Upgrade Action

    private func upgradeCpu() {
        // Use GlobalUpgrades system for CPU upgrades
        let profile = appState.currentPlayer
        guard let cost = profile.globalUpgrades.cpuUpgradeCost,
              profile.hash >= cost else {
            HapticsService.shared.play(.warning)
            return
        }

        // Deduct cost and apply upgrade
        var updatedProfile = profile
        updatedProfile.hash -= cost
        updatedProfile.globalUpgrades.upgrade(.cpu)
        StorageService.shared.savePlayer(updatedProfile)
        appState.refreshPlayer()

        // Update game state's Hash generation
        if var state = gameState {
            state.baseHashPerSecond = appState.currentPlayer.globalUpgrades.hashPerSecond
            state.cpuTier = appState.currentPlayer.globalUpgrades.cpuLevel
            gameState = state
        }

        HapticsService.shared.play(.success)
    }

    // MARK: - Game Over Overlay

    private var gameOverOverlay: some View {
        ZStack {
            Color.black.opacity(0.95)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                // Victory/Defeat title - System: Reboot themed
                VStack(spacing: 8) {
                    Text(gameState?.victory == true ? "SYSTEM_SECURE" : "SYSTEM_BREACH")
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .foregroundColor(gameState?.victory == true ? .green : .red)

                    Text(gameState?.victory == true ? "All threats neutralized" : "CPU integrity compromised")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(.gray)
                }

                // Stats card
                if let state = gameState {
                    VStack(spacing: 16) {
                        GameEndStatRow(label: "Waves", value: "\(state.wavesCompleted)/20", icon: "waveform.path", color: .purple)
                        GameEndStatRow(label: "Viruses", value: "\(state.stats.enemiesKilled)", icon: "ladybug.fill", color: .red)
                        GameEndStatRow(label: "Watts", value: "\(state.stats.goldEarned)", icon: "bolt.fill", color: .cyan)
                    }
                    .padding(24)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                    )
                }

                Button(action: {
                    HapticsService.shared.play(.light)
                    dismiss()
                }) {
                    Text("EXIT")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(.black)
                        .frame(width: 220, height: 56)
                        .background(Color.cyan)
                        .cornerRadius(12)
                }
            }
        }
    }

    // MARK: - Sector Unlock Panel (Mega-Board)

    private func sectorUnlockPanel(sectorId: String) -> some View {
        let status = SectorUnlockSystem.shared.getUnlockStatus(for: sectorId, profile: appState.currentPlayer)

        return ZStack {
            // Dimmed background
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .onTapGesture {
                    showSectorUnlockPanel = false
                    selectedSectorForUnlock = nil
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
                        showSectorUnlockPanel = false
                        selectedSectorForUnlock = nil
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
                        unlockSelectedSector()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "lock.open.fill")
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
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(white: 0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.cyan.opacity(0.3), lineWidth: 2)
                    )
            )
            .padding(24)
        }
    }

    // MARK: - Game Setup

    private func setupGame() {
        guard let state = TDGameStateFactory.createTDGameState(mapId: mapId, playerProfile: appState.currentPlayer) else {
            return
        }

        let waves = WaveSystem.generateWaves(totalWaves: 20)

        let handler = TDGameSceneDelegateHandler()
        handler.onGameStateUpdated = { newState in
            self.updateGameState(newState)
        }
        handler.onSlotSelected = { slotId in
            self.handleSlotSelected(slotId)
        }
        handler.onTowerSelected = { towerId in
            self.handleTowerSelected(towerId)
        }
        handler.onGateSelected = { sectorId in
            self.handleGateSelected(sectorId)
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

    // MARK: - Actions

    private func startWave() {
        scene?.startWave()
    }

    private func placeTower(weaponType: String, slotId: String) {
        scene?.placeTower(weaponType: weaponType, slotId: slotId, profile: appState.currentPlayer)
        showTowerMenu = false
        selectedSlotId = nil
    }

    private func upgradeTower(_ towerId: String) {
        scene?.upgradeTower(towerId)
    }

    private func sellTower(_ towerId: String) {
        scene?.sellTower(towerId)
        selectedTowerId = nil
    }

    // MARK: - Blocker Actions

    /// Toggle blocker placement mode
    private func toggleBlockerMode() {
        isBlockerModeActive.toggle()
        HapticsService.shared.play(.selection)

        if isBlockerModeActive {
            // Exit any other active mode
            selectedTowerId = nil
            showTowerMenu = false
        }
    }

    /// Place a blocker at a slot
    private func placeBlocker(slotId: String) {
        scene?.placeBlocker(slotId: slotId)
        // Stay in blocker mode for multiple placements
    }

    /// Remove a blocker
    private func removeBlocker(blockerId: String) {
        scene?.removeBlocker(blockerId: blockerId)
    }

    // MARK: - Helpers

    private func getAvailableTowers() -> [WeaponConfig] {
        let config = GameConfigLoader.shared
        return appState.currentPlayer.unlocks.weapons.compactMap { config.getWeapon($0) }
    }

    /// Get compiled Protocols from player profile (System: Reboot - Firewall deck)
    private func getCompiledProtocols() -> [Protocol] {
        return appState.currentPlayer.compiledProtocols.compactMap { protocolId in
            guard var proto = ProtocolLibrary.get(protocolId) else { return nil }
            // Apply player's level to the protocol
            proto.level = appState.currentPlayer.protocolLevel(protocolId)
            return proto
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

    // MARK: - Efficiency System (System: Reboot)

    /// Get efficiency from game state (0-100%)
    /// Efficiency = 100 - (leakCounter * 5)
    /// Each virus reaching CPU reduces efficiency by 5%
    private func calculateEfficiency() -> CGFloat {
        return gameState?.efficiency ?? 100
    }

    /// Color for efficiency display
    private var efficiencyColor: Color {
        let efficiency = calculateEfficiency()
        if efficiency >= 70 { return .green }
        if efficiency >= 40 { return .yellow }
        if efficiency >= 20 { return .orange }
        return .red
    }

    /// Color for power usage display
    private var powerColor: Color {
        guard let state = gameState else { return .green }
        let usage = Double(state.powerUsed) / Double(max(1, state.powerCapacity))
        if usage >= 0.95 { return .red }      // At capacity
        if usage >= 0.75 { return .orange }   // Getting full
        if usage >= 0.50 { return .yellow }   // Half used
        return .green                          // Plenty available
    }

    /// Current Hash per second income rate
    private var hashPerSecond: CGFloat {
        return gameState?.hashPerSecond ?? 0
    }

    // MARK: - State Updates

    fileprivate func updateGameState(_ state: TDGameState) {
        let previousEfficiency = self.gameState?.efficiency ?? 100
        self.gameState = state

        // Check for System Freeze (efficiency hit 0%)
        if state.efficiency <= 0 && previousEfficiency > 0 && !showSystemFreeze {
            withAnimation(.easeInOut(duration: 0.3)) {
                showSystemFreeze = true
            }
            HapticsService.shared.play(.defeat)
        }

        if state.isGameOver {
            showGameOver = true
            saveGameResult(state: state)
        }
    }

    fileprivate func handleSlotSelected(_ slotId: String) {
        // Legacy tap-to-place disabled - use drag-to-place only
        // This provides a cleaner UX with progressive disclosure
    }

    fileprivate func handleTowerSelected(_ towerId: String?) {
        selectedTowerId = towerId
    }

    fileprivate func handleGateSelected(_ sectorId: String) {
        selectedSectorForUnlock = sectorId
        showSectorUnlockPanel = true
    }

    private func unlockSelectedSector() {
        guard let sectorId = selectedSectorForUnlock else { return }

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
        } else {
            HapticsService.shared.play(.error)
        }
    }

    private func saveGameResult(state: TDGameState) {
        // Update player profile with TD stats
        var profile = appState.currentPlayer
        profile.tdStats.gamesPlayed += 1
        if state.victory {
            profile.tdStats.gamesWon += 1
        }
        profile.tdStats.totalWavesCompleted += state.wavesCompleted
        profile.tdStats.highestWave = max(profile.tdStats.highestWave, state.wavesCompleted)
        profile.tdStats.totalTowersPlaced += state.stats.towersPlaced
        profile.tdStats.totalTDKills += state.stats.enemiesKilled

        // Award Data and Watts (System: Reboot currencies)
        let dataReward = state.wavesCompleted * 10 + state.stats.enemiesKilled + (state.victory ? 50 : 0)
        let wattsReward = state.stats.goldEarned / 10 + (state.victory ? state.wavesCompleted * 5 : 0)

        profile.xp += dataReward      // Data is stored as XP for now
        profile.addHash(wattsReward)   // Hash (subject to HDD storage cap)

        // Check level up
        while profile.xp >= PlayerProfile.xpForLevel(profile.level) {
            profile.xp -= PlayerProfile.xpForLevel(profile.level)
            profile.level += 1
        }

        appState.updatePlayer { $0 = profile }
    }
}

// MARK: - Scene Delegate Handler

private class TDGameSceneDelegateHandler: TDGameSceneDelegate {
    var onGameStateUpdated: ((TDGameState) -> Void)?
    var onSlotSelected: ((String) -> Void)?
    var onTowerSelected: ((String?) -> Void)?
    var onGateSelected: ((String) -> Void)?
    var onSystemFrozen: (() -> Void)?

    func gameStateUpdated(_ state: TDGameState) {
        DispatchQueue.main.async { [weak self] in
            self?.onGameStateUpdated?(state)
        }
    }

    func slotSelected(_ slotId: String) {
        DispatchQueue.main.async { [weak self] in
            self?.onSlotSelected?(slotId)
        }
    }

    func towerSelected(_ towerId: String?) {
        DispatchQueue.main.async { [weak self] in
            self?.onTowerSelected?(towerId)
        }
    }

    func gateSelected(_ sectorId: String) {
        DispatchQueue.main.async { [weak self] in
            self?.onGateSelected?(sectorId)
        }
    }

    func systemFrozen() {
        DispatchQueue.main.async { [weak self] in
            self?.onSystemFrozen?()
        }
    }
}

// MARK: - Tower Deck Card (Large Touch-Friendly)

struct TowerDeckCard: View {
    let weapon: WeaponConfig
    let gold: Int
    let onDragStart: () -> Void
    let onDragChanged: (DragGesture.Value) -> Void
    let onDragEnded: () -> Void

    @State private var isDragging = false
    @State private var pulseAnimation = false

    private var cost: Int {
        TowerSystem.towerPlacementCost(rarity: Rarity(rawValue: weapon.rarity) ?? .common)
    }

    private var canAfford: Bool {
        gold >= cost
    }

    private var rarityColor: Color {
        RarityColors.color(for: weapon.rarity)
    }

    private var archetypeColor: Color {
        // Match the tower archetype colors
        switch weapon.id.lowercased() {
        case "bow", "crossbow", "trace_route", "kernel_pulse":
            return Color(hex: "00d4ff") ?? .cyan
        case "cannon", "bomb", "burst_protocol":
            return Color(hex: "f97316") ?? .orange
        case "ice_shard", "snowflake":
            return Color(hex: "06b6d4") ?? .cyan
        case "staff", "wand":
            return Color(hex: "a855f7") ?? .purple
        case "laser", "root_access":
            return Color(hex: "ef4444") ?? .red
        case "lightning", "overflow":
            return Color(hex: "22d3ee") ?? .cyan
        case "flamethrower":
            return Color(hex: "f97316") ?? .orange
        case "excalibur", "sword", "katana":
            return Color(hex: "f59e0b") ?? .orange
        case "fork_bomb":
            return Color(hex: "8b5cf6") ?? .purple
        case "null_pointer":
            return Color(hex: "ef4444") ?? .red
        default:
            return .cyan
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            // Enhanced tower icon with archetype styling
            ZStack {
                // Outer glow layer (for epic/legendary)
                if weapon.rarity.lowercased() == "legendary" || weapon.rarity.lowercased() == "epic" {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(rarityColor.opacity(0.2))
                        .frame(width: 64, height: 64)
                        .blur(radius: 4)
                        .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                }

                // Main card background
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                archetypeColor.opacity(canAfford ? 0.4 : 0.15),
                                rarityColor.opacity(canAfford ? 0.3 : 0.1)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)

                // Circuit pattern overlay
                TowerCardCircuitPattern()
                    .stroke(archetypeColor.opacity(0.2), lineWidth: 0.5)
                    .frame(width: 56, height: 56)
                    .clipped()

                // Weapon type icon with archetype styling
                ZStack {
                    // Icon glow
                    Image(systemName: iconForWeapon(weapon.id))
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(archetypeColor.opacity(0.5))
                        .blur(radius: 4)

                    // Main icon
                    Image(systemName: iconForWeapon(weapon.id))
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(canAfford ? .white : .gray)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                rarityColor.opacity(canAfford ? 1 : 0.4),
                                archetypeColor.opacity(canAfford ? 0.7 : 0.3)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 2
                    )
            )
            .overlay(
                // Rarity indicator corners
                RarityCorners(rarity: weapon.rarity, color: rarityColor)
                    .opacity(canAfford ? 1 : 0.4)
            )
            .scaleEffect(isDragging ? 0.85 : 1.0)
            .shadow(color: canAfford ? archetypeColor.opacity(0.4) : .clear, radius: 6)

            // Cost label with enhanced styling
            HStack(spacing: 3) {
                Image(systemName: "bitcoinsign.circle.fill")
                    .font(.system(size: 11))
                Text("\(cost)")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
            }
            .foregroundColor(canAfford ? .yellow : .red)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.black.opacity(0.5))
            .cornerRadius(4)
        }
        .opacity(canAfford ? 1.0 : 0.5)
        .animation(.easeOut(duration: 0.15), value: isDragging)
        .onAppear {
            if weapon.rarity.lowercased() == "legendary" {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    pulseAnimation = true
                }
            }
        }
        .gesture(
            DragGesture(minimumDistance: 5, coordinateSpace: .named("gameArea"))
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

    private func iconForWeapon(_ weaponType: String) -> String {
        // Enhanced icon selection matching tower archetypes
        switch weaponType.lowercased() {
        case "bow", "crossbow":
            return "scope"  // Targeting reticle
        case "trace_route":
            return "scope"  // Sniper scope
        case "kernel_pulse":
            return "dot.circle.and.hand.point.up.left.fill"  // Targeting
        case "wand", "staff":
            return "wand.and.stars"  // Arcane magic
        case "cannon":
            return "cylinder.split.1x2.fill"  // Artillery barrel
        case "bomb":
            return "burst.fill"  // Explosion
        case "burst_protocol":
            return "burst.fill"  // Shotgun burst
        case "ice_shard", "snowflake":
            return "snowflake"  // Ice crystal
        case "laser":
            return "rays"  // Beam emitter
        case "root_access":
            return "terminal.fill"  // Railgun/terminal
        case "lightning", "overflow":
            return "bolt.horizontal.fill"  // Tesla/chain
        case "flamethrower":
            return "flame.fill"  // Fire
        case "excalibur", "sword", "katana":
            return "sparkle"  // Divine/legendary (fallback from shield)
        case "fork_bomb":
            return "arrow.triangle.branch"  // Multi-shot branching
        case "null_pointer":
            return "exclamationmark.triangle.fill"  // Error/execute
        default:
            return "square.fill"
        }
    }
}

// MARK: - Tower Card Circuit Pattern

struct TowerCardCircuitPattern: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let step: CGFloat = 12

        // Horizontal traces
        for y in stride(from: step, to: rect.height, by: step * 2) {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: rect.width * 0.3, y: y))

            path.move(to: CGPoint(x: rect.width * 0.7, y: y))
            path.addLine(to: CGPoint(x: rect.width, y: y))
        }

        // Vertical traces
        for x in stride(from: step, to: rect.width, by: step * 2) {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: rect.height * 0.25))

            path.move(to: CGPoint(x: x, y: rect.height * 0.75))
            path.addLine(to: CGPoint(x: x, y: rect.height))
        }

        return path
    }
}

// MARK: - Rarity Corner Indicators

struct RarityCorners: View {
    let rarity: String
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let cornerSize: CGFloat = rarity.lowercased() == "legendary" ? 8 : 6

            // Top-left corner
            Path { path in
                path.move(to: CGPoint(x: 2, y: cornerSize + 2))
                path.addLine(to: CGPoint(x: 2, y: 2))
                path.addLine(to: CGPoint(x: cornerSize + 2, y: 2))
            }
            .stroke(color, lineWidth: 2)

            // Top-right corner
            Path { path in
                path.move(to: CGPoint(x: geo.size.width - cornerSize - 2, y: 2))
                path.addLine(to: CGPoint(x: geo.size.width - 2, y: 2))
                path.addLine(to: CGPoint(x: geo.size.width - 2, y: cornerSize + 2))
            }
            .stroke(color, lineWidth: 2)

            // Bottom-left corner
            Path { path in
                path.move(to: CGPoint(x: 2, y: geo.size.height - cornerSize - 2))
                path.addLine(to: CGPoint(x: 2, y: geo.size.height - 2))
                path.addLine(to: CGPoint(x: cornerSize + 2, y: geo.size.height - 2))
            }
            .stroke(color, lineWidth: 2)

            // Bottom-right corner
            Path { path in
                path.move(to: CGPoint(x: geo.size.width - cornerSize - 2, y: geo.size.height - 2))
                path.addLine(to: CGPoint(x: geo.size.width - 2, y: geo.size.height - 2))
                path.addLine(to: CGPoint(x: geo.size.width - 2, y: geo.size.height - cornerSize - 2))
            }
            .stroke(color, lineWidth: 2)
        }
    }
}

// MARK: - Protocol Deck Card (System: Reboot - Firewall selection)

struct ProtocolDeckCard: View {
    let `protocol`: Protocol
    let hash: Int
    let onDragStart: () -> Void
    let onDragChanged: (DragGesture.Value) -> Void
    let onDragEnded: () -> Void

    @State private var isDragging = false
    @State private var pulseAnimation = false
    @State private var glitchOffset: CGFloat = 0

    private var cost: Int {
        TowerSystem.towerPlacementCost(rarity: `protocol`.rarity)
    }

    private var canAfford: Bool {
        hash >= cost
    }

    private var rarityColor: Color {
        RarityColors.color(for: `protocol`.rarity)
    }

    private var archetypeColor: Color {
        // Match protocol to tower archetype colors
        switch `protocol`.id.lowercased() {
        case "kernel_pulse":
            return Color(hex: "00d4ff") ?? .cyan
        case "burst_protocol":
            return Color(hex: "f97316") ?? .orange
        case "trace_route":
            return Color(hex: "00d4ff") ?? .cyan
        case "ice_shard":
            return Color(hex: "06b6d4") ?? .cyan
        case "fork_bomb":
            return Color(hex: "8b5cf6") ?? .purple
        case "root_access":
            return Color(hex: "ef4444") ?? .red
        case "overflow":
            return Color(hex: "22d3ee") ?? .cyan
        case "null_pointer":
            return Color(hex: "ef4444") ?? .red
        default:
            return .cyan
        }
    }

    private var enhancedIcon: String {
        // Enhanced icons for protocols
        switch `protocol`.id.lowercased() {
        case "kernel_pulse":
            return "dot.circle.and.hand.point.up.left.fill"
        case "burst_protocol":
            return "burst.fill"
        case "trace_route":
            return "scope"
        case "ice_shard":
            return "snowflake"
        case "fork_bomb":
            return "arrow.triangle.branch"
        case "root_access":
            return "terminal.fill"
        case "overflow":
            return "bolt.horizontal.fill"
        case "null_pointer":
            return "exclamationmark.triangle.fill"
        default:
            return `protocol`.iconName
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            // Enhanced firewall icon with protocol styling
            ZStack {
                // Outer glow for epic/legendary
                if `protocol`.rarity == .legendary || `protocol`.rarity == .epic {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(rarityColor.opacity(0.2))
                        .frame(width: 64, height: 64)
                        .blur(radius: 4)
                        .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                }

                // Main card with gradient
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                archetypeColor.opacity(canAfford ? 0.4 : 0.15),
                                rarityColor.opacity(canAfford ? 0.3 : 0.1)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)

                // Circuit pattern
                TowerCardCircuitPattern()
                    .stroke(archetypeColor.opacity(0.2), lineWidth: 0.5)
                    .frame(width: 56, height: 56)
                    .clipped()

                // Glitch effect for null_pointer
                if `protocol`.id.lowercased() == "null_pointer" {
                    Image(systemName: enhancedIcon)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.red.opacity(0.5))
                        .offset(x: glitchOffset, y: 0)
                }

                // Protocol icon with glow
                ZStack {
                    Image(systemName: enhancedIcon)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(archetypeColor.opacity(0.5))
                        .blur(radius: 4)

                    Image(systemName: enhancedIcon)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(canAfford ? .white : .gray)
                }

                // Level badge (enhanced)
                if `protocol`.level > 1 {
                    HStack(spacing: 2) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 7, weight: .bold))
                        Text("\(`protocol`.level)")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [archetypeColor.opacity(0.8), rarityColor.opacity(0.8)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(4)
                    .offset(x: 18, y: -22)
                }

                // Compiled indicator
                if `protocol`.isCompiled {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 1)
                        )
                        .offset(x: -22, y: -22)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                rarityColor.opacity(canAfford ? 1 : 0.4),
                                archetypeColor.opacity(canAfford ? 0.7 : 0.3)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 2
                    )
            )
            .overlay(
                RarityCorners(rarity: rarityString, color: rarityColor)
                    .opacity(canAfford ? 1 : 0.4)
            )
            .scaleEffect(isDragging ? 0.85 : 1.0)
            .shadow(color: canAfford ? archetypeColor.opacity(0.4) : .clear, radius: 6)

            // Cost label (Hash/Watts)
            HStack(spacing: 3) {
                Image(systemName: "number.circle.fill")
                    .font(.system(size: 11))
                Text("\(cost)")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
            }
            .foregroundColor(canAfford ? DesignColors.primary : .red)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.black.opacity(0.5))
            .cornerRadius(4)
        }
        .opacity(canAfford ? 1.0 : 0.5)
        .animation(.easeOut(duration: 0.15), value: isDragging)
        .onAppear {
            if `protocol`.rarity == .legendary {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    pulseAnimation = true
                }
            }
            if `protocol`.id.lowercased() == "null_pointer" {
                startGlitchAnimation()
            }
        }
        .gesture(
            DragGesture(minimumDistance: 5, coordinateSpace: .named("gameArea"))
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

    private var rarityString: String {
        switch `protocol`.rarity {
        case .common: return "common"
        case .rare: return "rare"
        case .epic: return "epic"
        case .legendary: return "legendary"
        }
    }

    private func startGlitchAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            if Bool.random() {
                withAnimation(.linear(duration: 0.05)) {
                    glitchOffset = CGFloat.random(in: -2...2)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    withAnimation(.linear(duration: 0.05)) {
                        glitchOffset = 0
                    }
                }
            }
        }
    }
}

// MARK: - TD Stat Row

struct TDStatRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(DesignTypography.caption(10))
            Text("\(label):")
                .foregroundColor(.gray)
            Text(value)
                .foregroundColor(.white)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Resource Indicator

struct ResourceIndicator: View {
    let icon: String
    let value: Int
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(DesignTypography.caption(12))
            Text("\(value)")
                .foregroundColor(.white)
                .fontWeight(.bold)
                .font(DesignTypography.body(14))
        }
    }
}

// MARK: - Wave Progress Bar

struct WaveProgressBar: View {
    let current: Int
    let total: Int

    private var progress: CGFloat {
        guard total > 0 else { return 1.0 }
        return CGFloat(total - current) / CGFloat(total)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.gray.opacity(0.3))

                // Progress fill
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [.green, .yellow]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * progress)
            }
        }
        .frame(height: 4)
    }
}

// MARK: - Countdown Bar

struct CountdownBar: View {
    let seconds: TimeInterval
    let maxSeconds: TimeInterval

    private var progress: CGFloat {
        CGFloat(seconds / maxSeconds)
    }

    var body: some View {
        VStack(spacing: 2) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.3))

                    // Progress fill
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.yellow)
                        .frame(width: geometry.size.width * progress)
                }
            }
            .frame(height: 4)

            Text("Next: \(Int(seconds))s")
                .font(DesignTypography.caption(10))
                .foregroundColor(.yellow)
        }
    }
}

// MARK: - Game End Stat Row

private struct GameEndStatRow: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(DesignTypography.headline(22))
                .foregroundColor(color)
                .frame(width: 32)
            Text(label)
                .font(.system(size: 18))
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Zero-Day Boss Fight

enum ZeroDayBossFightResult {
    case victory(dataBonus: Int, wattsBonus: Int)
    case defeat
    case fled
}

struct ZeroDayBossFightView: View {
    let onComplete: (ZeroDayBossFightResult) -> Void

    @ObservedObject var appState = AppState.shared
    @State private var gameState: GameState?
    @State private var gameScene: GameScene?
    @State private var showResult = false
    @State private var didWin = false
    @State private var timeRemaining: TimeInterval = 30  // 30 second survival
    @State private var timer: Timer?

    private let survivalDuration: TimeInterval = 30

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Game scene
                if let scene = gameScene {
                    SpriteView(scene: scene)
                        .ignoresSafeArea()
                } else {
                    Color.black.ignoresSafeArea()
                    ProgressView()
                        .tint(.red)
                }

                // HUD
                VStack {
                    // Top bar
                    HStack {
                        // Flee button
                        Button {
                            timer?.invalidate()
                            onComplete(.fled)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark")
                                Text("FLEE")
                            }
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.red)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(8)
                        }

                        Spacer()

                        // Title
                        Text("ZERO-DAY_OVERRIDE")
                            .font(.system(size: 16, weight: .black, design: .monospaced))
                            .foregroundColor(.red)

                        Spacer()

                        // Timer
                        Text(String(format: "%.1f", timeRemaining))
                            .font(.system(size: 24, weight: .black, design: .monospaced))
                            .foregroundColor(timeRemaining > 10 ? .green : .red)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(8)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    Spacer()

                    // Health bar
                    if let state = gameState {
                        HStack {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.red)
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.gray.opacity(0.3))
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.red)
                                        .frame(width: geo.size.width * CGFloat(state.player.health / state.player.maxHealth))
                                }
                            }
                            .frame(height: 12)
                            Text("\(Int(state.player.health))")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 100)
                    }
                }

                // Result overlay
                if showResult {
                    resultOverlay
                }
            }
            .onChange(of: geometry.size) { newSize in
                if gameScene == nil && newSize.width > 0 && newSize.height > 0 {
                    setupBossFight(screenSize: newSize)
                }
            }
            .onAppear {
                if geometry.size.width > 0 && geometry.size.height > 0 {
                    setupBossFight(screenSize: geometry.size)
                }
            }
            .onDisappear {
                timer?.invalidate()
            }
        }
    }

    private var resultOverlay: some View {
        ZStack {
            Color.black.opacity(0.9).ignoresSafeArea()

            VStack(spacing: 24) {
                if didWin {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)

                    Text("ZERO-DAY_NEUTRALIZED")
                        .font(.system(size: 28, weight: .black, design: .monospaced))
                        .foregroundColor(.green)

                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "memorychip")
                                .foregroundColor(.green)
                            Text("+50 DATA")
                                .foregroundColor(.green)
                        }
                        HStack {
                            Image(systemName: "bolt.fill")
                                .foregroundColor(.cyan)
                            Text("+500 WATTS")
                                .foregroundColor(.cyan)
                        }
                    }
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                } else {
                    Image(systemName: "xmark.shield.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.red)

                    Text("OVERRIDE FAILED")
                        .font(.system(size: 28, weight: .black, design: .monospaced))
                        .foregroundColor(.red)

                    Text("-25% Efficiency")
                        .font(.system(size: 16, design: .monospaced))
                        .foregroundColor(.orange)
                }

                Button {
                    if didWin {
                        onComplete(.victory(dataBonus: 50, wattsBonus: 500))
                    } else {
                        onComplete(.defeat)
                    }
                } label: {
                    Text("CONTINUE")
                        .font(.system(size: 18, weight: .black, design: .monospaced))
                        .foregroundColor(.black)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 14)
                        .background(didWin ? Color.green : Color.orange)
                        .cornerRadius(12)
                }
            }
        }
    }

    private func setupBossFight(screenSize: CGSize) {
        // Create a simple arena state for the boss fight using Protocol
        let protocolId = appState.currentPlayer.equippedProtocolId ?? "kernel_pulse"
        let gameProtocol = ProtocolLibrary.all.first { $0.id == protocolId } ?? ProtocolLibrary.kernelPulse
        let state = GameStateFactory.shared.createArenaGameState(
            gameProtocol: gameProtocol,
            powerUpType: "tank",
            arenaType: "grasslands",
            playerProfile: appState.currentPlayer
        )
        gameState = state

        // Create and configure scene
        let scene = GameScene()
        scene.configure(gameState: state, screenSize: screenSize)
        scene.onGameOver = { finalState in
            timer?.invalidate()
            gameState = finalState
            didWin = false
            showResult = true
            HapticsService.shared.play(.defeat)
        }
        scene.onStateUpdate = { updatedState in
            gameState = updatedState
        }

        gameScene = scene

        // Start countdown timer
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            timeRemaining -= 0.1
            if timeRemaining <= 0 {
                timer?.invalidate()
                didWin = true
                showResult = true
                HapticsService.shared.play(.success)
            }
        }
    }
}

// MARK: - Preview

struct TDGameContainerView_Previews: PreviewProvider {
    static var previews: some View {
        TDGameContainerView(mapId: "grasslands")
            .environmentObject(AppState.shared)
    }
}
