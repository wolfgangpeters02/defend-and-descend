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

                // Tower selection menu (legacy - for slot tapping)
                if showTowerMenu, let slotId = selectedSlotId {
                    towerSelectionMenu(slotId: slotId)
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

                // Pause overlay
                if isPaused {
                    pauseOverlay
                }

                // Game over overlay
                if showGameOver {
                    gameOverOverlay
                }
            }
        }
        .onAppear {
            setupGame()
        }
        .navigationBarHidden(true)
    }

    // MARK: - Top Bar (Mobile-First HUD)
    // Full-width bar with large, readable stats

    private var topBar: some View {
        HStack(spacing: 0) {
            // Left: Pause + Wave
            HStack(spacing: 12) {
                // Pause button
                Button(action: {
                    isPaused = true
                    HapticsService.shared.play(.light)
                }) {
                    Image(systemName: "pause.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(10)
                }

                // Wave indicator - large and clear
                VStack(alignment: .leading, spacing: 2) {
                    Text("WAVE")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.gray)
                    Text("\(gameState?.currentWave ?? 0)/20")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
            }

            Spacer()

            // Center: CPU Efficiency (most important)
            HStack(spacing: 8) {
                Image(systemName: "cpu")
                    .font(.title2)
                    .foregroundColor(efficiencyColor)

                // Efficiency percentage
                let efficiency = calculateEfficiency()
                Text("\(Int(efficiency))%")
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundColor(efficiencyColor)

                // Mini efficiency bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.3))
                        RoundedRectangle(cornerRadius: 2)
                            .fill(efficiencyColor)
                            .frame(width: geo.size.width * efficiency / 100)
                    }
                }
                .frame(width: 40, height: 6)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.5))
            .cornerRadius(10)

            Spacer()

            // Right: Watts + Viruses
            HStack(spacing: 16) {
                // Watts - primary currency
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .font(.title2)
                        .foregroundColor(.cyan)
                    Text("\(gameState?.gold ?? 0)")
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)
                }

                // Viruses remaining during wave
                if let state = gameState, state.waveInProgress {
                    HStack(spacing: 4) {
                        Image(systemName: "ladybug.fill")
                            .font(.title3)
                            .foregroundColor(.red)
                        Text("\(state.enemies.filter { !$0.isDead && !$0.reachedCore }.count)")
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.8), Color.black.opacity(0.4)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
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

            // Dragged tower preview - follows finger
            if let weapon = GameConfigLoader.shared.getWeapon(weaponType) {
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
                        .font(.title3)
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

        // Check affordability
        if let weapon = GameConfigLoader.shared.getWeapon(weaponType) {
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
            var minDistance: CGFloat = DesignLayout.snapDistance // 50pt snap distance

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

    private func convertGameToScreen(_ point: CGPoint, geometry: GeometryProxy) -> CGPoint {
        // Game coordinates are 800x600, need to map to screen
        let scaleX = geometry.size.width / 800
        let scaleY = (geometry.size.height - 120) / 600 // Account for deck height
        let scale = min(scaleX, scaleY)

        let offsetX = (geometry.size.width - 800 * scale) / 2
        let offsetY = (geometry.size.height - 120 - 600 * scale) / 2

        return CGPoint(
            x: point.x * scale + offsetX,
            y: (600 - point.y) * scale + offsetY // Flip Y axis
        )
    }

    private func convertScreenToGame(_ point: CGPoint, geometry: GeometryProxy) -> CGPoint {
        let scaleX = geometry.size.width / 800
        let scaleY = (geometry.size.height - 120) / 600
        let scale = min(scaleX, scaleY)

        let offsetX = (geometry.size.width - 800 * scale) / 2
        let offsetY = (geometry.size.height - 120 - 600 * scale) / 2

        return CGPoint(
            x: (point.x - offsetX) / scale,
            y: 600 - (point.y - offsetY) / scale
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
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()

                // Merge stars
                HStack(spacing: 2) {
                    ForEach(0..<tower.mergeLevel, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }
                    ForEach(0..<(3 - tower.mergeLevel), id: \.self) { _ in
                        Image(systemName: "star")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }

            Text("Level: \(tower.level)/10")
                .font(.caption)
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
            .font(.caption)

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
                        .font(.title3)
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

    // MARK: - Helpers

    private func getAvailableTowers() -> [WeaponConfig] {
        let config = GameConfigLoader.shared
        return appState.currentPlayer.unlocks.weapons.compactMap { config.getWeapon($0) }
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

    /// Calculate efficiency based on lives remaining (will be replaced with leak counter later)
    private func calculateEfficiency() -> CGFloat {
        guard let state = gameState else { return 100 }
        // For now, map lives to efficiency: 20 lives = 100%, 0 lives = 0%
        let maxLives: CGFloat = 20
        let currentLives = CGFloat(state.lives)
        return max(0, min(100, (currentLives / maxLives) * 100))
    }

    /// Color for efficiency display
    private var efficiencyColor: Color {
        let efficiency = calculateEfficiency()
        if efficiency >= 70 { return .green }
        if efficiency >= 40 { return .yellow }
        if efficiency >= 20 { return .orange }
        return .red
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
        // Check if slot is empty
        if let slot = gameState?.towerSlots.first(where: { $0.id == slotId }), !slot.occupied {
            selectedSlotId = slotId
            showTowerMenu = true
        }
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
                    .font(.title)
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
            DragGesture(minimumDistance: 5)
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
                .font(.caption2)
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
                .font(.caption)
            Text("\(value)")
                .foregroundColor(.white)
                .fontWeight(.bold)
                .font(.subheadline)
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
                .font(.caption2)
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
                .font(.title2)
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
