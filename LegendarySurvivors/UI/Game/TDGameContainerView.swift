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
                if let state = gameState, state.zeroDayActive {
                    zeroDayAlertOverlay
                }

                // Pause overlay
                if isPaused {
                    pauseOverlay
                }

                // Game over overlay
                if showGameOver {
                    gameOverOverlay
                }
            }
            .coordinateSpace(name: "gameArea")
        }
        .onAppear {
            setupGame()
        }
        .navigationBarHidden(true)
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

                    Text("SYSTEM BREACH DETECTED")
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

                // MANUAL OVERRIDE button
                Button(action: {
                    initiateManualOverride()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "person.fill.viewfinder")
                            .font(DesignTypography.headline(18))
                        Text("MANUAL OVERRIDE")
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

        // TODO: Transition to boss fight mode
        // For now, show an alert that this feature is coming
        // In full implementation, this would:
        // 1. Pause the TD game
        // 2. Launch a special boss fight in Active/Survivor mode
        // 3. On victory: apply ZeroDaySystem.onZeroDayDefeated rewards
        // 4. On defeat: return to TD with Zero-Day still active

        // Placeholder: Just remove the Zero-Day for now
        if var state = gameState {
            let reward = ZeroDaySystem.onZeroDayDefeated(state: &state)
            gameState = state

            // Apply rewards to player
            appState.updatePlayer { profile in
                profile.data += reward.dataBonus
                profile.gold += reward.wattsBonus
            }

            HapticsService.shared.play(.success)
        }
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

            // Right: Watts only (clean)
            HStack(spacing: 4) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 16))
                    .foregroundColor(DesignColors.primary)
                Text("\(gameState?.gold ?? 0)")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(DesignColors.primary)
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
                                watts: gameState?.gold ?? 0,
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
                                gold: gameState?.gold ?? 0,
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
            canAffordDraggedTower = (gameState?.gold ?? 0) >= cost
        } else if let weapon = GameConfigLoader.shared.getWeapon(weaponType) {
            let cost = TowerSystem.towerPlacementCost(rarity: Rarity(rawValue: weapon.rarity) ?? .common)
            canAffordDraggedTower = (gameState?.gold ?? 0) >= cost
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

            // Calculate scale-adjusted snap distance (50 screen pixels worth)
            let gameAreaHeight = geometry.size.height - topHUDHeight - bottomDeckHeight
            let gameAreaWidth = geometry.size.width
            let scaleX = gameAreaWidth / 800
            let scaleY = gameAreaHeight / 600
            let scale = min(scaleX, scaleY)
            let snapDistanceInGameUnits = 60 / scale  // 60 screen pixels converted to game units

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
    // Top HUD height ~50pt, Bottom deck height ~110pt

    private let topHUDHeight: CGFloat = 50
    private let bottomDeckHeight: CGFloat = 110

    private func convertGameToScreen(_ point: CGPoint, geometry: GeometryProxy) -> CGPoint {
        // Game area is between top HUD and bottom deck
        let gameAreaHeight = geometry.size.height - topHUDHeight - bottomDeckHeight
        let gameAreaWidth = geometry.size.width

        // Calculate scale to fit 800x600 game into available space
        let scaleX = gameAreaWidth / 800
        let scaleY = gameAreaHeight / 600
        let scale = min(scaleX, scaleY)

        // Center the game area
        let scaledWidth = 800 * scale
        let scaledHeight = 600 * scale
        let offsetX = (gameAreaWidth - scaledWidth) / 2
        let offsetY = topHUDHeight + (gameAreaHeight - scaledHeight) / 2

        // Game coordinates and SwiftUI both have origin top-left, Y increases downward
        // No Y flip needed
        return CGPoint(
            x: point.x * scale + offsetX,
            y: point.y * scale + offsetY
        )
    }

    private func convertScreenToGame(_ point: CGPoint, geometry: GeometryProxy) -> CGPoint {
        let gameAreaHeight = geometry.size.height - topHUDHeight - bottomDeckHeight
        let gameAreaWidth = geometry.size.width

        let scaleX = gameAreaWidth / 800
        let scaleY = gameAreaHeight / 600
        let scale = min(scaleX, scaleY)

        let scaledWidth = 800 * scale
        let scaledHeight = 600 * scale
        let offsetX = (gameAreaWidth - scaledWidth) / 2
        let offsetY = topHUDHeight + (gameAreaHeight - scaledHeight) / 2

        // Game coordinates and SwiftUI both have origin top-left, Y increases downward
        // No Y flip needed
        return CGPoint(
            x: (point.x - offsetX) / scale,
            y: (point.y - offsetY) / scale
        )
    }

    // MARK: - Tower Selection Menu

    private func towerSelectionMenu(slotId: String) -> some View {
        VStack(spacing: 12) {
            Text("DEPLOY FIREWALL")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(.cyan)

            ForEach(getAvailableTowers(), id: \.id) { weapon in
                let cost = TowerSystem.towerPlacementCost(rarity: Rarity(rawValue: weapon.rarity) ?? .common)
                let canAfford = (gameState?.gold ?? 0) >= cost

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
                        .background((gameState?.gold ?? 0) >= tower.upgradeCost ? Color.cyan : Color.gray)
                        .cornerRadius(6)
                    }
                    .disabled((gameState?.gold ?? 0) < tower.upgradeCost)
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
                    Text("SYSTEM PAUSED")
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
        let canUpgrade = cpuInfo.nextCost != nil && appState.currentPlayer.gold >= (cpuInfo.nextCost ?? 0)

        return VStack(spacing: 12) {
            // Current CPU info
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CPU TIER")
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
                        Text("\(appState.currentPlayer.gold)")
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
                Text("MAX CPU TIER")
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
              profile.watts >= cost else {
            HapticsService.shared.play(.warning)
            return
        }

        // Deduct cost and apply upgrade
        var updatedProfile = profile
        updatedProfile.watts -= cost
        updatedProfile.globalUpgrades.upgrade(.cpu)
        StorageService.shared.savePlayer(updatedProfile)
        appState.refreshPlayer()

        // Update game state's Watts generation
        if var state = gameState {
            state.baseWattsPerSecond = appState.currentPlayer.globalUpgrades.wattsPerSecond
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
                    Text(gameState?.victory == true ? "SYSTEM SECURE" : "SYSTEM BREACH")
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

        let newScene = TDGameScene(size: CGSize(width: 800, height: 600))
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

    /// Current Watts per second income rate
    private var wattsPerSecond: CGFloat {
        return gameState?.wattsPerSecond ?? 0
    }

    // MARK: - State Updates

    fileprivate func updateGameState(_ state: TDGameState) {
        self.gameState = state

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
        profile.gold += wattsReward   // Watts is stored as gold for now

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
}

// MARK: - Tower Deck Card (Large Touch-Friendly)

struct TowerDeckCard: View {
    let weapon: WeaponConfig
    let gold: Int
    let onDragStart: () -> Void
    let onDragChanged: (DragGesture.Value) -> Void
    let onDragEnded: () -> Void

    @State private var isDragging = false

    private var cost: Int {
        TowerSystem.towerPlacementCost(rarity: Rarity(rawValue: weapon.rarity) ?? .common)
    }

    private var canAfford: Bool {
        gold >= cost
    }

    private var rarityColor: Color {
        switch weapon.rarity.lowercased() {
        case "common": return .gray
        case "rare": return .blue
        case "epic": return .purple
        case "legendary": return .orange
        default: return .gray
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            // Large tower icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(rarityColor.opacity(canAfford ? 0.5 : 0.2))
                    .frame(width: 60, height: 60)

                // Weapon type icon - larger
                Image(systemName: iconForWeapon(weapon.id))
                    .font(DesignTypography.display(28))
                    .foregroundColor(canAfford ? .white : .gray)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(rarityColor.opacity(canAfford ? 1 : 0.4), lineWidth: 3)
            )
            .scaleEffect(isDragging ? 0.85 : 1.0)
            .shadow(color: canAfford ? rarityColor.opacity(0.5) : .clear, radius: 5)

            // Cost label - larger and clearer
            HStack(spacing: 3) {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: 12))
                Text("\(cost)")
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundColor(canAfford ? .yellow : .red)
        }
        .opacity(canAfford ? 1.0 : 0.5)
        .animation(.easeOut(duration: 0.15), value: isDragging)
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
        switch weaponType {
        case "bow", "crossbow": return "arrow.up.right"
        case "wand", "staff": return "sparkles"
        case "cannon", "bomb": return "burst.fill"
        case "ice_shard": return "snowflake"
        case "laser": return "rays"
        case "flamethrower": return "flame.fill"
        case "sword", "katana": return "bolt.fill"
        default: return "square.fill"
        }
    }
}

// MARK: - Protocol Deck Card (System: Reboot - Firewall selection)

struct ProtocolDeckCard: View {
    let `protocol`: Protocol
    let watts: Int
    let onDragStart: () -> Void
    let onDragChanged: (DragGesture.Value) -> Void
    let onDragEnded: () -> Void

    @State private var isDragging = false

    private var cost: Int {
        TowerSystem.towerPlacementCost(rarity: `protocol`.rarity)
    }

    private var canAfford: Bool {
        watts >= cost
    }

    private var rarityColor: Color {
        RarityColors.color(for: `protocol`.rarity)
    }

    var body: some View {
        VStack(spacing: 4) {
            // Large firewall icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(rarityColor.opacity(canAfford ? 0.5 : 0.2))
                    .frame(width: 60, height: 60)

                // Protocol icon
                Image(systemName: `protocol`.iconName)
                    .font(DesignTypography.display(28))
                    .foregroundColor(canAfford ? .white : .gray)

                // Level badge
                if `protocol`.level > 1 {
                    Text("L\(`protocol`.level)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(4)
                        .offset(x: 20, y: -20)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(rarityColor.opacity(canAfford ? 1 : 0.4), lineWidth: 3)
            )
            .scaleEffect(isDragging ? 0.85 : 1.0)
            .shadow(color: canAfford ? rarityColor.opacity(0.5) : .clear, radius: 5)

            // Cost label (Watts)
            HStack(spacing: 3) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 12))
                Text("\(cost)")
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundColor(canAfford ? DesignColors.primary : .red)
        }
        .opacity(canAfford ? 1.0 : 0.5)
        .animation(.easeOut(duration: 0.15), value: isDragging)
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

// MARK: - Preview

struct TDGameContainerView_Previews: PreviewProvider {
    static var previews: some View {
        TDGameContainerView(mapId: "grasslands")
            .environmentObject(AppState.shared)
    }
}
