import SwiftUI
import SpriteKit

// MARK: - Currency Info Types

enum CurrencyInfoType: String, Identifiable {
    case hash
    case power

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hash: return L10n.Currency.hashTitle
        case .power: return L10n.Currency.powerTitle
        }
    }

    var description: String {
        switch self {
        case .hash:
            return L10n.Currency.hashDescription
        case .power:
            return L10n.Currency.powerDescription
        }
    }

    var icon: String {
        switch self {
        case .hash: return "number.circle.fill"
        case .power: return "bolt.fill"
        }
    }

    var color: Color {
        switch self {
        case .hash: return .cyan
        case .power: return .yellow
        }
    }
}

// MARK: - System Tab View
// Main game hub - motherboard game with HUD, Arsenal accessible via SYS button

struct SystemTabView: View {
    @ObservedObject var appState = AppState.shared
    @StateObject private var embeddedGameController = EmbeddedTDGameController()  // Persists across view lifecycle
    @State private var showSystemMenu = false  // Arsenal/Settings sheet
    @State private var selectedBoss: BossEncounter?
    @State private var selectedDifficulty: BossDifficulty = .normal

    var onExit: (() -> Void)? = nil

    var body: some View {
        ZStack {
            // Background
            DesignColors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top navigation bar only shown if there's an exit button
                if onExit != nil {
                    topNavigationBar
                }

                // Main game board (no tab bar - system menu accessed via HUD)
                MotherboardView(
                    embeddedGameController: embeddedGameController,
                    showSystemMenu: $showSystemMenu
                )
            }
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
        .sheet(isPresented: $showSystemMenu) {
            SystemMenuSheet()
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
                        Text(L10n.Common.menu)
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
            Text(L10n.System.title)
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

}

// MARK: - Motherboard View - Embedded TD Game with HUD

struct MotherboardView: View {
    @ObservedObject var appState = AppState.shared
    @ObservedObject var embeddedGameController: EmbeddedTDGameController  // Passed from parent to persist across lifecycle
    @Binding var showSystemMenu: Bool  // Controls Arsenal/Settings sheet
    @State private var showManualOverride = false
    @State private var showCurrencyInfo: CurrencyInfoType? = nil

    // Boss Loot Modal state
    @State private var showBossLootModal = false
    @State private var pendingBossLootReward: BossLootReward?
    @State private var bossFightNotificationObserver: NSObjectProtocol?

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

                // Tower upgrade panel (when tower is selected)
                if let towerId = embeddedGameController.selectedTowerId,
                   let tower = embeddedGameController.gameState?.towers.first(where: { $0.id == towerId }) {
                    towerUpgradePanel(tower: tower)
                }

                // Boss alert overlay (when boss spawns and not yet engaged)
                // Hide during transitions: boss fight active/starting, or loot modal showing
                if embeddedGameController.isBossActive &&
                   !embeddedGameController.showBossDifficultySelector &&
                   !embeddedGameController.bossAlertDismissed &&
                   !embeddedGameController.showBossFight &&
                   !showBossLootModal {
                    bossAlertOverlay
                }

                // Boss difficulty selector modal
                if embeddedGameController.showBossDifficultySelector {
                    bossDifficultySelector
                }

                // Overclock button (bottom right, above build deck)
                if !embeddedGameController.overclockActive && !embeddedGameController.isBossActive {
                    overclockButton
                }

                // Overclock active indicator
                if embeddedGameController.overclockActive {
                    overclockActiveIndicator
                }
            }
            .coordinateSpace(name: "motherboardGameArea")
            .animation(.easeInOut(duration: 0.3), value: embeddedGameController.isSystemFrozen)
            .animation(.easeInOut(duration: 0.3), value: showManualOverride)
            .animation(.easeInOut(duration: 0.3), value: embeddedGameController.isBossActive)
        }
        .fullScreenCover(isPresented: $embeddedGameController.showBossFight) {
            if let bossType = embeddedGameController.activeBossType,
               let boss = BossEncounter.all.first(where: { $0.bossId == bossType }) {
                BossGameView(
                    boss: boss,
                    difficulty: embeddedGameController.selectedBossDifficulty,
                    protocol: appState.currentPlayer.equippedProtocol() ?? ProtocolLibrary.kernelPulse,
                    onExit: { [weak embeddedGameController] in
                        // Only dismiss the fullScreenCover here
                        // State cleanup happens in notification handler (handleBossFightCompletion)
                        embeddedGameController?.showBossFight = false
                    }
                )
            }
        }
        .fullScreenCover(isPresented: $showBossLootModal) {
            BossLootModalWrapper(
                reward: pendingBossLootReward,
                onCollect: {
                    handleBossLootCollected()
                }
            )
        }
        .onAppear {
            // Register for boss fight completion notifications
            bossFightNotificationObserver = NotificationCenter.default.addObserver(
                forName: .bossFightCompleted,
                object: nil,
                queue: .main
            ) { notification in
                print("[MotherboardView] Received bossFightCompleted notification")
                guard let userInfo = notification.userInfo,
                      let victory = userInfo["victory"] as? Bool else {
                    print("[MotherboardView] Invalid notification userInfo")
                    return
                }
                print("[MotherboardView] Boss fight complete: victory=\(victory)")
                // Small delay to let fullScreenCover dismiss animation complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.handleBossFightCompletion(victory: victory)
                }
            }
        }
        .onDisappear {
            // Remove notification observer
            if let observer = bossFightNotificationObserver {
                NotificationCenter.default.removeObserver(observer)
                bossFightNotificationObserver = nil
            }
        }
    }

    // MARK: - Boss Fight Completion Handler

    private func handleBossFightCompletion(victory: Bool) {
        print("[MotherboardView] handleBossFightCompletion called, victory=\(victory)")

        let difficulty = embeddedGameController.selectedBossDifficulty
        let bossId = embeddedGameController.activeBossType ?? "cyberboss"

        // Unpause the scene
        embeddedGameController.scene?.isPaused = false

        if victory {
            // Get the district ID from the game state (where the boss actually spawned from)
            let districtId = embeddedGameController.gameState?.activeBossDistrictId ?? SectorID.power.rawValue

            // Reset boss state on VICTORY only
            embeddedGameController.isBossActive = false
            embeddedGameController.activeBossType = nil

            // Notify the TD scene that boss was defeated
            embeddedGameController.scene?.onBossFightWon(districtId: districtId)

            // Calculate hash reward based on difficulty
            let hashReward = difficulty.hashReward

            // Calculate protocol drop using BlueprintDropSystem
            let dropResult = BlueprintDropSystem.shared.calculateDrop(
                bossId: bossId,
                difficulty: difficulty,
                profile: appState.currentPlayer
            )

            print("[MotherboardView] Protocol drop: \(dropResult.protocolId ?? "none")")

            // Get protocol rarity if dropped
            var protocolRarity: Rarity?
            if let protocolId = dropResult.protocolId,
               let proto = ProtocolLibrary.get(protocolId) {
                protocolRarity = proto.rarity
            }

            // Build the loot reward for display
            pendingBossLootReward = BossLootReward.create(
                difficulty: difficulty,
                hashReward: hashReward,
                protocolId: dropResult.protocolId,
                protocolRarity: protocolRarity,
                unlockedSector: nil,
                isFirstKill: false
            )

            print("[MotherboardView] Created reward with \(pendingBossLootReward?.items.count ?? 0) items, showing modal...")

            // Show loot modal
            showBossLootModal = true

            HapticsService.shared.play(.success)
        } else {
            // Boss fight lost/retreated - boss stays on board for retry
            // Reset bossEngaged so player can tap to fight again
            if var state = embeddedGameController.gameState {
                state.bossEngaged = false
                state.bossSelectedDifficulty = nil
                embeddedGameController.gameState = state
                embeddedGameController.scene?.state = state
            }
            // Don't reset isBossActive or activeBossType - boss is still there!
            HapticsService.shared.play(.defeat)
        }
    }

    /// Apply rewards and dismiss the loot modal
    private func handleBossLootCollected() {
        guard let reward = pendingBossLootReward else {
            showBossLootModal = false
            return
        }

        // Apply hash reward (uses convenience property)
        let hashAmount = reward.totalHashReward
        if hashAmount > 0 {
            appState.updatePlayer { profile in
                profile.hash += hashAmount
            }
            // Also update the game state hash
            embeddedGameController.gameState?.hash += hashAmount
        }

        // Apply protocol unlock (uses convenience property)
        if let protocolId = reward.droppedProtocolId {
            appState.updatePlayer { profile in
                if !profile.compiledProtocols.contains(protocolId) {
                    profile.compiledProtocols.append(protocolId)
                }
            }
        }

        print("[MotherboardView] Loot collected! Hash: \(hashAmount)")

        // Dismiss modal
        pendingBossLootReward = nil
        showBossLootModal = false
    }

    private var motherboardHUD: some View {
        HStack {
            // Power (⚡) - PSU usage - tappable for info
            HStack(spacing: 4) {
                Image(systemName: "bolt.fill")
                    .foregroundColor(embeddedGameController.powerShakeTriggered ? .red : powerColor)
                Text("\(embeddedGameController.gameState?.powerUsed ?? 0)/\(embeddedGameController.gameState?.powerCapacity ?? 450)W")
                    .font(DesignTypography.caption(12))
                    .foregroundColor(embeddedGameController.powerShakeTriggered ? .red : powerColor)
            }
            .offset(x: embeddedGameController.powerShakeTriggered ? -3 : 0)
            .animation(embeddedGameController.powerShakeTriggered ?
                Animation.easeInOut(duration: 0.05).repeatCount(6, autoreverses: true) :
                .default, value: embeddedGameController.powerShakeTriggered)
            .onTapGesture { showCurrencyInfo = .power }

            Spacer()

            // Hash (Ħ) - Currency - tappable for info
            HStack(spacing: 4) {
                Image(systemName: "number.circle.fill")
                    .foregroundColor(.cyan)
                Text("\(embeddedGameController.gameState?.hash ?? appState.currentPlayer.hash)")
                    .font(DesignTypography.headline(16))
                    .foregroundColor(.cyan)
                Text(L10n.Stats.perSecond(Int(appState.currentPlayer.globalUpgrades.hashPerSecond)))
                    .font(DesignTypography.caption(10))
                    .foregroundColor(DesignColors.muted)
            }
            .onTapGesture { showCurrencyInfo = .hash }

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
                    .fixedSize()
            }
            .fixedSize()

            Spacer()
                .frame(width: 12)

            // SYS button - opens Arsenal/Settings menu
            Button {
                HapticsService.shared.play(.selection)
                showSystemMenu = true
            } label: {
                Text("SYS")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(DesignColors.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(DesignColors.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(DesignColors.secondary.opacity(0.5), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(DesignColors.surface.opacity(0.85))
        .sheet(item: $showCurrencyInfo) { info in
            CurrencyInfoSheet(info: info)
        }
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

    @ViewBuilder
    private func towerUpgradePanel(tower: Tower) -> some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 12) {
                // Header with tower name and close button
                HStack {
                    Text(tower.towerName)
                        .font(DesignTypography.headline(16))
                        .foregroundColor(Color(hex: tower.color) ?? .white)

                    Text(L10n.Common.lv(tower.level))
                        .font(DesignTypography.caption(12))
                        .foregroundColor(DesignColors.muted)

                    Spacer()

                    Button {
                        embeddedGameController.selectedTowerId = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(DesignColors.muted)
                    }
                }

                // Tower stats
                HStack(spacing: 16) {
                    VStack(spacing: 2) {
                        Text(L10n.Stats.dmg)
                            .font(DesignTypography.caption(9))
                            .foregroundColor(DesignColors.muted)
                        Text("\(Int(tower.damage))")
                            .font(DesignTypography.headline(14))
                            .foregroundColor(DesignColors.danger)
                    }
                    VStack(spacing: 2) {
                        Text(L10n.Stats.rng)
                            .font(DesignTypography.caption(9))
                            .foregroundColor(DesignColors.muted)
                        Text("\(Int(tower.range))")
                            .font(DesignTypography.headline(14))
                            .foregroundColor(DesignColors.success)
                    }
                    VStack(spacing: 2) {
                        Text(L10n.Stats.spd)
                            .font(DesignTypography.caption(9))
                            .foregroundColor(DesignColors.muted)
                        Text(String(format: "%.1f", tower.attackSpeed))
                            .font(DesignTypography.headline(14))
                            .foregroundColor(DesignColors.primary)
                    }
                }

                // Upgrade/Sell buttons
                HStack(spacing: 12) {
                    if tower.canUpgrade {
                        let canAfford = (embeddedGameController.gameState?.hash ?? 0) >= tower.upgradeCost
                        Button {
                            embeddedGameController.scene?.upgradeTower(tower.id)
                            HapticsService.shared.play(.success)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.circle.fill")
                                Text(L10n.Upgrade.upgrade)
                                Spacer()
                                Text("Ħ\(tower.upgradeCost)")
                                    .fontWeight(.bold)
                            }
                            .font(DesignTypography.headline(14))
                            .foregroundColor(canAfford ? .black : DesignColors.muted)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(canAfford ? DesignColors.primary : DesignColors.surface)
                            .cornerRadius(8)
                        }
                        .disabled(!canAfford)
                    } else {
                        Text(L10n.Common.maxLevel)
                            .font(DesignTypography.headline(14))
                            .foregroundColor(.green)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(DesignColors.surface)
                            .cornerRadius(8)
                    }

                    Button {
                        embeddedGameController.scene?.sellTower(tower.id)
                        embeddedGameController.selectedTowerId = nil
                        HapticsService.shared.play(.light)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "trash.fill")
                            Text(L10n.Common.recycle)
                        }
                        .font(DesignTypography.headline(14))
                        .foregroundColor(.red)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(DesignColors.surface)
                        .cornerRadius(8)
                    }
                }

                // Hint text
                Text(L10n.Motherboard.tapToUpgrade)
                    .font(DesignTypography.caption(10))
                    .foregroundColor(DesignColors.muted)
            }
            .padding()
            .background(DesignColors.surface.opacity(0.95))
            .cornerRadius(16)
            .padding(.horizontal)
            .padding(.bottom, 120)  // Above the deck
        }
    }

    private func buildDeck(geometry: GeometryProxy) -> some View {
        VStack(spacing: 8) {
            Text(L10n.Motherboard.dragToDeploy)
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

                    Text("Ħ\(TowerSystem.towerPlacementCost(rarity: proto.rarity))")
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

    // MARK: - Boss UI Components

    /// Alert overlay when boss spawns
    private var bossAlertOverlay: some View {
        VStack {
            Spacer()

            VStack(spacing: 16) {
                // Warning icon with pulsing animation
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.red)

                Text(L10n.Boss.superVirusDetected)
                    .font(DesignTypography.headline(20))
                    .foregroundColor(.white)

                if let bossType = embeddedGameController.activeBossType {
                    Text(bossType == "cyberboss" ? L10n.Boss.cyberboss : L10n.Boss.voidHarbinger)
                        .font(DesignTypography.headline(16))
                        .foregroundColor(bossType == "cyberboss" ? .red : .purple)
                }

                Text(L10n.Boss.immuneToFirewalls)
                    .font(DesignTypography.caption(12))
                    .foregroundColor(DesignColors.muted)
                    .multilineTextAlignment(.center)

                // Engage button
                Button {
                    HapticsService.shared.play(.selection)
                    withAnimation {
                        embeddedGameController.showBossDifficultySelector = true
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "target")
                        Text(L10n.Boss.engageTarget)
                    }
                    .font(DesignTypography.headline(16))
                    .foregroundColor(.black)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(DesignColors.danger)
                    .cornerRadius(12)
                }

                // Ignore button - let boss pass
                Button {
                    HapticsService.shared.play(.light)
                    withAnimation {
                        // Dismiss the alert - boss keeps walking toward CPU
                        embeddedGameController.bossAlertDismissed = true
                    }
                } label: {
                    Text(L10n.Boss.ignoreHint)
                        .font(DesignTypography.caption(12))
                        .foregroundColor(DesignColors.muted)
                        .padding(.vertical, 8)
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(DesignColors.surface.opacity(0.95))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.red.opacity(0.5), lineWidth: 2)
                    )
            )
            .padding(.horizontal, 32)

            Spacer()
        }
        .background(Color.black.opacity(0.4))
    }

    /// Difficulty selector modal
    private var bossDifficultySelector: some View {
        VStack {
            Spacer()

            VStack(spacing: 20) {
                Text(L10n.Boss.selectDifficulty)
                    .font(DesignTypography.headline(18))
                    .foregroundColor(.white)

                ForEach(BossDifficulty.allCases, id: \.self) { difficulty in
                    difficultyButton(difficulty)
                }

                // Cancel button
                Button {
                    HapticsService.shared.play(.light)
                    withAnimation {
                        embeddedGameController.showBossDifficultySelector = false
                    }
                } label: {
                    Text(L10n.Common.cancel)
                        .font(DesignTypography.headline(14))
                        .foregroundColor(DesignColors.muted)
                        .padding(.vertical, 12)
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(DesignColors.surface.opacity(0.95))
            )
            .padding(.horizontal, 32)

            Spacer()
        }
        .background(Color.black.opacity(0.6))
    }

    /// Individual difficulty option button
    private func difficultyButton(_ difficulty: BossDifficulty) -> some View {
        Button {
            HapticsService.shared.play(.medium)
            embeddedGameController.selectedBossDifficulty = difficulty
            embeddedGameController.showBossDifficultySelector = false

            // Engage boss through the system (sets bossEngaged and bossSelectedDifficulty in state)
            if var state = embeddedGameController.gameState {
                _ = TDBossSystem.engageBoss(state: &state, difficulty: difficulty)
                embeddedGameController.gameState = state
                embeddedGameController.scene?.state = state
            }

            // Pause TD scene before starting boss fight
            embeddedGameController.scene?.isPaused = true
            // Small delay before showing boss fight to let animation complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                embeddedGameController.showBossFight = true
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(difficulty.displayName)
                        .font(DesignTypography.headline(16))
                        .foregroundColor(difficultyColor(difficulty))

                    Text("Ħ\(difficulty.hashReward)")
                        .font(DesignTypography.caption(12))
                        .foregroundColor(.cyan)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(difficulty.blueprintChance * 100))%")
                        .font(DesignTypography.headline(14))
                        .foregroundColor(DesignColors.warning)

                    Text(L10n.Boss.blueprintDrop)
                        .font(DesignTypography.caption(10))
                        .foregroundColor(DesignColors.muted)
                }
            }
            .padding()
            .background(DesignColors.surface)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(difficultyColor(difficulty).opacity(0.5), lineWidth: 1)
            )
        }
    }

    /// Color for each difficulty
    private func difficultyColor(_ difficulty: BossDifficulty) -> Color {
        switch difficulty {
        case .easy: return .green
        case .normal: return .blue
        case .hard: return .orange
        case .nightmare: return .red
        }
    }

    /// Overclock button (visible when not overclocking)
    private var overclockButton: some View {
        VStack {
            Spacer()

            HStack {
                Spacer()

                Button {
                    HapticsService.shared.play(.heavy)
                    embeddedGameController.scene?.activateOverclock()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "bolt.circle.fill")
                            .font(.system(size: 32))
                        Text(L10n.TD.overclock)
                            .font(DesignTypography.caption(10))
                    }
                    .foregroundColor(.orange)
                    .padding(12)
                    .background(
                        Circle()
                            .fill(DesignColors.surface.opacity(0.9))
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.orange.opacity(0.5), lineWidth: 2)
                    )
                }
            }
            .padding(.trailing, 16)
            .padding(.bottom, 130)  // Above the build deck
        }
    }

    /// Overclock active indicator
    private var overclockActiveIndicator: some View {
        VStack {
            Spacer()

            HStack {
                Spacer()

                VStack(spacing: 4) {
                    Image(systemName: "bolt.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.orange)

                    Text(L10n.TD.overclocking)
                        .font(DesignTypography.caption(9))
                        .foregroundColor(.orange)

                    Text(String(format: "%.0fs", embeddedGameController.overclockTimeRemaining))
                        .font(DesignTypography.headline(14))
                        .foregroundColor(.white)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.orange.opacity(0.3))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.orange, lineWidth: 2)
                        )
                )
            }
            .padding(.trailing, 16)
            .padding(.bottom, 130)
        }
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
    @Published var powerShakeTriggered = false  // Triggers shake animation on power indicator
    @Published var selectedTowerId: String?  // Selected tower for upgrade panel

    // Boss system state
    @Published var isBossActive = false
    @Published var activeBossType: String?
    @Published var showBossDifficultySelector = false
    @Published var bossAlertDismissed = false  // User dismissed alert to let boss pass
    @Published var overclockActive = false
    @Published var overclockTimeRemaining: TimeInterval = 0

    // Boss fight state (for launching boss fight fullscreen)
    @Published var showBossFight = false
    @Published var selectedBossDifficulty: BossDifficulty = .normal

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
                // Track boss state
                if newState.bossActive && !newState.bossEngaged {
                    if !(self?.isBossActive ?? false) {
                        self?.isBossActive = true
                        self?.activeBossType = newState.activeBossType
                    }
                } else if !newState.bossActive {
                    self?.isBossActive = false
                    self?.activeBossType = nil
                    self?.bossAlertDismissed = false  // Reset for next boss
                }
                // Track overclock state
                self?.overclockActive = newState.overclockActive
                self?.overclockTimeRemaining = newState.overclockTimeRemaining
                // Sync hash to player profile so other tabs see updated balance
                if newState.hash != AppState.shared.currentPlayer.hash {
                    AppState.shared.updatePlayer { profile in
                        profile.hash = newState.hash
                    }
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
        handler.onGetUnlockedSectorIds = {
            // Get unlocked sectors from AppState (which holds current player)
            // PSU is always included as the starter sector
            var sectors = AppState.shared.currentPlayer.unlockedSectorIds
            sectors.insert(SectorID.power.rawValue)  // Ensure PSU is always unlocked
            return sectors
        }
        handler.onPlacementFailed = { [weak self] reason in
            DispatchQueue.main.async {
                // Trigger power shake for insufficient power
                if case .insufficientPower = reason {
                    self?.powerShakeTriggered = true
                    // Reset after animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self?.powerShakeTriggered = false
                    }
                }
            }
        }
        handler.onTowerSelected = { [weak self] towerId in
            DispatchQueue.main.async {
                self?.selectedTowerId = towerId
            }
        }
        handler.onBossSpawned = { [weak self] bossType in
            DispatchQueue.main.async {
                self?.isBossActive = true
                self?.activeBossType = bossType
                self?.bossAlertDismissed = false  // Reset so alert shows for new boss
                HapticsService.shared.play(.warning)
            }
        }
        handler.onBossReachedCPU = { [weak self] in
            DispatchQueue.main.async {
                self?.isBossActive = false
                self?.activeBossType = nil
                self?.bossAlertDismissed = false  // Reset for next boss
                HapticsService.shared.play(.defeat)
            }
        }
        handler.onBossTapped = { [weak self] in
            DispatchQueue.main.async {
                // Show difficulty selector when boss is tapped
                self?.bossAlertDismissed = false  // Reset in case alert was dismissed
                self?.showBossDifficultySelector = true
            }
        }

        // Scene size based on map dimensions
        let sceneSize = CGSize(width: state.map.width, height: state.map.height)

        let newScene = TDGameScene(size: sceneSize)
        newScene.backgroundColor = .black  // Set immediately to avoid grey flash
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
    var onGetUnlockedSectorIds: (() -> Set<String>)?
    var onPlacementFailed: ((TowerPlacementResult) -> Void)?
    var onTowerSelected: ((String?) -> Void)?
    var onBossSpawned: ((String) -> Void)?
    var onBossReachedCPU: (() -> Void)?
    var onBossTapped: (() -> Void)?

    func gameStateUpdated(_ state: TDGameState) {
        onGameStateUpdated?(state)
    }

    func slotSelected(_ slotId: String) {
        // Not used in embedded view - drag-to-place only
    }

    func towerSelected(_ towerId: String?) {
        onTowerSelected?(towerId)
    }

    func gateSelected(_ sectorId: String) {
        onGateSelected?(sectorId)
    }

    func systemFrozen() {
        onSystemFrozen?()
    }

    func getUnlockedSectorIds() -> Set<String> {
        // Get unlocked sectors from player profile via callback
        // PSU (power) is always unlocked as the starter sector
        return onGetUnlockedSectorIds?() ?? Set([SectorID.power.rawValue])
    }

    func spawnPointTapped(_ lane: SectorLane) {
        // Trigger sector unlock panel for the lane's sector
        onGateSelected?(lane.sectorId)
    }

    func placementFailed(_ reason: TowerPlacementResult) {
        onPlacementFailed?(reason)
    }

    func bossSpawned(type: String) {
        DispatchQueue.main.async { [weak self] in
            self?.onBossSpawned?(type)
        }
    }

    func bossReachedCPU() {
        DispatchQueue.main.async { [weak self] in
            self?.onBossReachedCPU?()
        }
    }

    func bossTapped() {
        DispatchQueue.main.async { [weak self] in
            self?.onBossTapped?()
        }
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
                        Text(L10n.Motherboard.initializing)
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

                    Text(L10n.Sector.encrypted)
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)

                    Text(status?.displayName ?? L10n.Common.unknown)
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
                            Text(L10n.Sector.decryptCost)
                                .font(.system(size: 14, weight: .medium, design: .monospaced))
                                .foregroundColor(.gray)

                            Text("Ħ \(status.unlockCost)")
                                .font(.system(size: 20, weight: .bold, design: .monospaced))
                                .foregroundColor(.cyan)
                        }

                        // Current balance
                        HStack(spacing: 8) {
                            Text(L10n.Sector.yourBalance)
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
                        Text(L10n.Common.cancel)
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
                            Text(L10n.Sector.decrypt)
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
    @State private var legendaryPulse = false

    private var cost: Int {
        TowerSystem.towerPlacementCost(rarity: `protocol`.rarity)
    }

    private var canAfford: Bool {
        hash >= cost
    }

    private var rarityColor: Color {
        RarityColors.color(for: `protocol`.rarity)
    }

    // Glow intensity scales with rarity
    private var glowRadius: CGFloat {
        switch `protocol`.rarity {
        case .common: return 4
        case .rare: return 8
        case .epic: return 12
        case .legendary: return 16
        }
    }

    private var glowOpacity: Double {
        switch `protocol`.rarity {
        case .common: return 0.3
        case .rare: return 0.5
        case .epic: return 0.6
        case .legendary: return 0.7
        }
    }

    private var isHighRarity: Bool {
        `protocol`.rarity == .epic || `protocol`.rarity == .legendary
    }

    var body: some View {
        VStack(spacing: 4) {
            // Tower icon container - circuit board aesthetic
            ZStack {
                // Outer glow for epic/legendary
                if isHighRarity && canAfford {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(rarityColor.opacity(0.15))
                        .frame(width: 64, height: 64)
                        .blur(radius: 8)
                        .scaleEffect(legendaryPulse ? 1.15 : 1.0)
                }

                // Background circuit pattern
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: "0a0a12") ?? .black)
                    .frame(width: 56, height: 56)

                // Border with rarity-scaled glow effect
                RoundedRectangle(cornerRadius: 8)
                    .stroke(rarityColor.opacity(canAfford ? 0.9 : 0.3), lineWidth: isHighRarity ? 2.5 : 2)
                    .frame(width: 56, height: 56)
                    .shadow(color: canAfford ? rarityColor.opacity(glowOpacity) : .clear, radius: glowRadius)

                // Protocol icon - simplified, geometric
                Image(systemName: `protocol`.iconName)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(canAfford ? .white : .gray)
                    .shadow(color: canAfford && isHighRarity ? rarityColor.opacity(0.5) : .clear, radius: 4)

                // Corner accent (circuit node) - larger for higher rarity
                Circle()
                    .fill(rarityColor)
                    .frame(width: isHighRarity ? 10 : 8, height: isHighRarity ? 10 : 8)
                    .offset(x: 22, y: -22)
                    .opacity(canAfford ? 1 : 0.3)

                // Opposite corner node for balance
                Circle()
                    .fill(rarityColor.opacity(0.5))
                    .frame(width: isHighRarity ? 8 : 6, height: isHighRarity ? 8 : 6)
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
            .foregroundColor(canAfford ? rarityColor : .red.opacity(0.7))

            // Stats row - power and damage
            HStack(spacing: 6) {
                // Power consumption
                HStack(spacing: 1) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 8))
                    Text("\(`protocol`.firewallStats.powerDraw)")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                }
                .foregroundColor(.yellow.opacity(0.8))

                // Damage
                HStack(spacing: 1) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 8))
                    Text("\(Int(`protocol`.firewallStats.damage))")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                }
                .foregroundColor(.orange.opacity(0.8))
            }
        }
        .opacity(canAfford ? 1.0 : 0.5)
        .animation(.easeOut(duration: 0.15), value: isDragging)
        .onAppear {
            // Subtle pulse for legendary cards
            if `protocol`.rarity == .legendary {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    legendaryPulse = true
                }
            }
        }
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
                    Text(L10n.Freeze.header)
                        .font(.system(size: 36, weight: .black, design: .monospaced))
                        .foregroundColor(.red.opacity(0.5))
                        .offset(x: glitchOffset, y: -glitchOffset)

                    Text(L10n.Freeze.header)
                        .font(.system(size: 36, weight: .black, design: .monospaced))
                        .foregroundColor(.cyan.opacity(0.5))
                        .offset(x: -glitchOffset, y: glitchOffset)

                    Text(L10n.Freeze.header)
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
                    Text(L10n.Freeze.criticalError)
                        .font(DesignTypography.headline(16))
                        .foregroundColor(.red)

                    Text(L10n.Freeze.allSystemsHalted)
                        .font(DesignTypography.body(14))
                        .foregroundColor(DesignColors.muted)

                    Text(L10n.Freeze.chooseRecoveryMethod)
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
                                Text(L10n.Freeze.flushMemory)
                                    .font(DesignTypography.headline(18))
                            }

                            HStack(spacing: 4) {
                                Text(L10n.Common.cost)
                                    .foregroundColor(DesignColors.muted)
                                Image(systemName: "number.circle.fill")
                                    .foregroundColor(canAffordFlush ? DesignColors.primary : .red)
                                Text("\(flushCost)")
                                    .foregroundColor(canAffordFlush ? DesignColors.primary : .red)
                                Text(L10n.Freeze.hashPercent)
                                    .font(DesignTypography.caption(11))
                                    .foregroundColor(DesignColors.muted)
                            }
                            .font(DesignTypography.body(14))

                            Text(L10n.Freeze.restoresEfficiency)
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
                                Text(L10n.Freeze.manualOverride)
                                    .font(DesignTypography.headline(18))
                            }

                            Text(L10n.Freeze.freeSurvive)
                                .font(DesignTypography.body(14))
                                .foregroundColor(DesignColors.success)

                            Text(L10n.Freeze.completeChallenge)
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
                Text(L10n.Freeze.frozenTimesSession(1))
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

            Text("\(Int(`protocol`.firewallStats.damage))")
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

// MARK: - System Menu Sheet (Arsenal + Settings)

struct SystemMenuSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ArsenalView()
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(DesignColors.muted)
                        }
                    }
                }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Arsenal View

struct ArsenalView: View {
    @ObservedObject var appState = AppState.shared
    @State private var selectedProtocol: Protocol?
    @State private var showCurrencyInfo: CurrencyInfoType? = nil
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(L10n.Tabs.arsenal)
                    .font(DesignTypography.display(28))
                    .foregroundColor(.white)

                Spacer()

                // Settings gear icon
                Button(action: { showSettings = true }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 20))
                        .foregroundColor(DesignColors.muted)
                }
                .padding(.trailing, 12)

                // Hash balance - tappable for info
                HStack(spacing: 6) {
                    Text("Ħ")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(DesignColors.primary)
                    Text("\(appState.currentPlayer.hash)")
                        .font(DesignTypography.headline(18))
                        .foregroundColor(DesignColors.primary)
                }
                .onTapGesture { showCurrencyInfo = .hash }
            }
            .padding()
            .sheet(item: $showCurrencyInfo) { info in
                CurrencyInfoSheet(info: info)
            }
            .sheet(isPresented: $showSettings) {
                NotificationSettingsSheet()
            }

            // Equipped protocol
            equippedSection

            Divider()
                .background(DesignColors.muted.opacity(0.3))
                .padding(.horizontal)

            // Protocol grid
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Compiled protocols
                    Text(L10n.Arsenal.compiled)
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

                    // Blueprints (owned but not compiled)
                    let ownedBlueprints = ProtocolLibrary.all.filter {
                        appState.currentPlayer.hasBlueprint($0.id) && !appState.currentPlayer.isProtocolCompiled($0.id)
                    }

                    if !ownedBlueprints.isEmpty {
                        Text(L10n.Arsenal.blueprints)
                            .font(DesignTypography.caption(12))
                            .foregroundColor(DesignColors.primary)
                            .padding(.horizontal)
                            .padding(.top, 8)

                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            ForEach(ownedBlueprints) { proto in
                                ProtocolCard(
                                    protocol: proto,
                                    level: 1,
                                    isBlueprint: true,
                                    onTap: { selectedProtocol = proto }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Undiscovered (no blueprint, not compiled, not starter)
                    let undiscoveredProtocols = ProtocolLibrary.all.filter {
                        !appState.currentPlayer.isProtocolCompiled($0.id) &&
                        !appState.currentPlayer.hasBlueprint($0.id) &&
                        $0.id != ProtocolLibrary.starterProtocolId
                    }

                    if !undiscoveredProtocols.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.Arsenal.undiscovered)
                                .font(DesignTypography.caption(12))
                                .foregroundColor(DesignColors.muted)

                            Text(L10n.Arsenal.defeatBossesHint)
                                .font(DesignTypography.caption(10))
                                .foregroundColor(DesignColors.muted.opacity(0.7))
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)

                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            ForEach(undiscoveredProtocols) { proto in
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
            Text(L10n.Arsenal.equippedForDebug)
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

                        Text(L10n.Common.lv(equipped.level))
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
    var isBlueprint: Bool = false  // Owned blueprint, not yet compiled
    var onTap: () -> Void = {}

    // Rarity-based color for borders and effects
    private var rarityColor: Color {
        RarityColors.color(for: `protocol`.rarity)
    }

    private var iconColor: Color {
        if isLocked {
            return DesignColors.muted
        } else if isBlueprint {
            return (Color(hex: `protocol`.color) ?? .cyan).opacity(0.7)
        } else {
            return Color(hex: `protocol`.color) ?? .cyan
        }
    }

    // Border color based on state and rarity
    private var borderColor: Color {
        if isLocked {
            return DesignColors.muted.opacity(0.3)
        } else if isEquipped {
            return rarityColor
        } else if isBlueprint {
            return rarityColor.opacity(0.6)
        } else {
            // Compiled - show rarity outline
            return rarityColor.opacity(0.5)
        }
    }

    private var borderWidth: CGFloat {
        isEquipped ? 2.5 : 1.5
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                ZStack {
                    // Rarity glow effect for non-locked cards
                    if !isLocked {
                        Circle()
                            .fill(rarityColor.opacity(isEquipped ? 0.25 : 0.1))
                            .frame(width: 50, height: 50)
                    }

                    Image(systemName: isLocked ? "lock.fill" : `protocol`.iconName)
                        .font(.system(size: 28))
                        .foregroundColor(iconColor)

                    // Blueprint badge
                    if isBlueprint {
                        Image(systemName: "doc.badge.gearshape.fill")
                            .font(.system(size: 12))
                            .foregroundColor(rarityColor)
                            .offset(x: 18, y: -18)
                    }

                    // Rarity dot indicator (top-left corner)
                    if !isLocked {
                        Circle()
                            .fill(rarityColor)
                            .frame(width: 6, height: 6)
                            .offset(x: -20, y: -20)
                    }
                }
                .frame(width: 50, height: 50)

                Text(`protocol`.name)
                    .font(DesignTypography.caption(10))
                    .foregroundColor(isLocked ? DesignColors.muted : .white)
                    .lineLimit(1)

                if isLocked {
                    // Show which boss drops this
                    if let boss = LootTableLibrary.bossesDropping(`protocol`.id).first {
                        Text(LootTableLibrary.bossDisplayName(boss))
                            .font(DesignTypography.caption(8))
                            .foregroundColor(DesignColors.danger.opacity(0.7))
                    } else {
                        Text("Ħ\(`protocol`.compileCost)")
                            .font(DesignTypography.caption(10))
                            .foregroundColor(DesignColors.muted)
                    }
                } else if isBlueprint {
                    Text("Ħ\(`protocol`.compileCost)")
                        .font(DesignTypography.caption(10))
                        .foregroundColor(rarityColor)
                } else {
                    Text(L10n.Common.lv(level))
                        .font(DesignTypography.caption(10))
                        .foregroundColor(DesignColors.muted)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                isEquipped ? rarityColor.opacity(0.15) :
                    isBlueprint ? rarityColor.opacity(0.08) :
                    DesignColors.surface
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
            .shadow(
                color: isEquipped ? rarityColor.opacity(0.4) : .clear,
                radius: 8
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

    var hasBlueprint: Bool {
        let isStarter = `protocol`.id == ProtocolLibrary.starterProtocolId
        return isStarter || appState.currentPlayer.hasBlueprint(`protocol`.id)
    }

    /// Protocol with player's level applied for accurate stat display
    var leveledProtocol: Protocol {
        var proto = `protocol`
        proto.level = currentLevel
        return proto
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
                                Text(L10n.Common.lv(currentLevel))
                                    .font(DesignTypography.headline(18))
                                    .foregroundColor(DesignColors.primary)
                            }
                        }
                        .padding()

                        // Stats
                        HStack(spacing: 20) {
                            // Firewall stats
                            VStack(alignment: .leading, spacing: 8) {
                                Text(L10n.Mode.firewall)
                                    .font(DesignTypography.caption(11))
                                    .foregroundColor(DesignColors.muted)

                                ProtocolStatRow(label: L10n.Stats.damage, value: "\(Int(leveledProtocol.firewallStats.damage))")
                                ProtocolStatRow(label: L10n.Stats.range, value: "\(Int(leveledProtocol.firewallStats.range))")
                                ProtocolStatRow(label: L10n.Stats.fireRate, value: String(format: "%.1f/s", leveledProtocol.firewallStats.fireRate))
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(DesignColors.surface)
                            .cornerRadius(12)

                            // Weapon stats
                            VStack(alignment: .leading, spacing: 8) {
                                Text(L10n.Mode.weapon)
                                    .font(DesignTypography.caption(11))
                                    .foregroundColor(DesignColors.muted)

                                ProtocolStatRow(label: L10n.Stats.damage, value: "\(Int(leveledProtocol.weaponStats.damage))")
                                ProtocolStatRow(label: L10n.Stats.fireRate, value: String(format: "%.1f/s", leveledProtocol.weaponStats.fireRate))
                                ProtocolStatRow(label: L10n.Stats.projectiles, value: "\(leveledProtocol.weaponStats.projectileCount)")
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
                                if hasBlueprint {
                                    // Has blueprint - show compile button
                                    Button {
                                        compileProtocol()
                                    } label: {
                                        HStack {
                                            Image(systemName: "hammer.fill")
                                            Text(L10n.Arsenal.compile)
                                            Text("Ħ\(`protocol`.compileCost)")
                                                .foregroundColor(
                                                    appState.currentPlayer.hash >= `protocol`.compileCost ?
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
                                    .disabled(appState.currentPlayer.hash < `protocol`.compileCost)
                                } else {
                                    // No blueprint - show "Blueprint Required" message
                                    VStack(spacing: 8) {
                                        HStack {
                                            Image(systemName: "lock.fill")
                                            Text(L10n.Arsenal.blueprintRequired)
                                        }
                                        .font(DesignTypography.headline(16))
                                        .foregroundColor(DesignColors.muted)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(DesignColors.surface)
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(DesignColors.muted.opacity(0.3), lineWidth: 1)
                                        )

                                        Text(L10n.Arsenal.defeatBossesHint)
                                            .font(DesignTypography.caption(12))
                                            .foregroundColor(DesignColors.muted.opacity(0.7))
                                    }
                                }
                            } else {
                                // Equip button
                                if appState.currentPlayer.equippedProtocolId != `protocol`.id {
                                    Button {
                                        equipProtocol()
                                    } label: {
                                        HStack {
                                            Image(systemName: "checkmark.circle.fill")
                                            Text(L10n.Arsenal.equipForDebug)
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
                                            Text(L10n.Arsenal.upgradeTo(currentLevel + 1))
                                            Text("Ħ\(cost)")
                                                .foregroundColor(
                                                    appState.currentPlayer.hash >= cost ?
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
                                    .disabled(appState.currentPlayer.hash < cost)
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
                    Button(L10n.Common.done) {
                        dismiss()
                    }
                    .foregroundColor(DesignColors.primary)
                }
            }
        }
    }

    private func compileProtocol() {
        // Check blueprint ownership (starter protocol is always available)
        let isStarter = `protocol`.id == ProtocolLibrary.starterProtocolId
        guard isStarter || appState.currentPlayer.hasBlueprint(`protocol`.id) else {
            print("[Arsenal] Cannot compile - no blueprint for \(`protocol`.id)")
            return
        }

        guard appState.currentPlayer.hash >= `protocol`.compileCost else { return }
        HapticsService.shared.play(.medium)
        appState.updatePlayer { profile in
            profile.hash -= `protocol`.compileCost
            profile.compiledProtocols.append(`protocol`.id)
            profile.protocolLevels[`protocol`.id] = 1
            // Remove from blueprints (now compiled)
            profile.protocolBlueprints.removeAll { $0 == `protocol`.id }
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
        guard appState.currentPlayer.hash >= cost else { return }
        HapticsService.shared.play(.medium)
        appState.updatePlayer { profile in
            profile.hash -= cost
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
                Text(L10n.SystemUpgrades.title)
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

                Text(L10n.Common.lv(level))
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
                Text(L10n.Common.maxLevel)
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
                            Text(L10n.Common.next(nextValue))
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
                    Text(L10n.Boss.encounters)
                        .font(DesignTypography.display(28))
                        .foregroundColor(.white)
                    Text(L10n.Boss.encountersDesc)
                        .font(DesignTypography.caption(12))
                        .foregroundColor(DesignColors.muted)
                }

                Spacer()

                // Hash balance
                HStack(spacing: 6) {
                    Text("Ħ")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(DesignColors.primary)
                    Text("\(appState.currentPlayer.hash)")
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
        case .easy: return DesignColors.secondary
        case .normal: return DesignColors.success
        case .hard: return DesignColors.warning
        case .nightmare: return DesignColors.danger
        }
    }

    private func difficultyReward(_ difficulty: BossDifficulty) -> String {
        switch difficulty {
        case .easy: return "+Ħ250"
        case .normal: return "+Ħ500"
        case .hard: return "+Ħ1500"
        case .nightmare: return "+Ħ3000"
        }
    }

    private func isBossUnlocked(_ boss: BossEncounter) -> Bool {
        boss.unlockCost == 0 || appState.currentPlayer.hash >= boss.unlockCost ||
            appState.currentPlayer.survivorStats.bossesDefeated > 0
    }

    private func unlockBoss(_ boss: BossEncounter) {
        guard appState.currentPlayer.hash >= boss.unlockCost else { return }
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
                        Text(L10n.Common.rewards)
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

                        Text("Ħ\(boss.unlockCost)")
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
            onExit: onExit,
            onBossFightComplete: { _ in onExit() }  // Just exit when fight ends
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
                Text(L10n.Debug.mode)
                    .font(DesignTypography.display(28))
                    .foregroundColor(.white)

                Spacer()

                // Hash balance
                HStack(spacing: 6) {
                    Text("Ħ")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(DesignColors.primary)
                    Text("\(appState.currentPlayer.hash)")
                        .font(DesignTypography.headline(18))
                        .foregroundColor(DesignColors.primary)
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
                    Text(L10n.Sector.select)
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
            Text(L10n.Common.loadout)
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

                        Text(L10n.Stats.dmgRate(Int(equipped.weaponStats.damage), rate: String(format: "%.1f", equipped.weaponStats.fireRate)))
                            .font(DesignTypography.caption(11))
                            .foregroundColor(DesignColors.muted)
                    }

                    Spacer()

                    Text(L10n.Common.lv(equipped.level))
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
        guard appState.currentPlayer.hash >= sector.unlockCost else { return }
        HapticsService.shared.play(.medium)
        appState.updatePlayer { profile in
            profile.hash -= sector.unlockCost
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
                Text(isDungeon ? L10n.Mode.dungeon : L10n.Mode.arena)
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

            // Hash multiplier
            Text("Ħ x\(String(format: "%.1f", sector.hashMultiplier))")
                .font(DesignTypography.caption(11))
                .foregroundColor(DesignColors.success)

            // Best time or lock status
            if isUnlocked {
                if let time = bestTime {
                    Text(L10n.Stats.best(formatTime(time)))
                        .font(DesignTypography.caption(10))
                        .foregroundColor(DesignColors.muted)
                }

                Button(action: onSelect) {
                    Text(L10n.Common.launch)
                        .font(DesignTypography.headline(14))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(DesignColors.success)
                        .cornerRadius(8)
                }
            } else {
                let canAfford = appState.currentPlayer.hash >= sector.unlockCost
                Button(action: onUnlock) {
                    HStack {
                        Image(systemName: "lock.fill")
                        Text("Ħ\(sector.unlockCost)")
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
    @State private var currentScreenSize: CGSize = .zero

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
                        Text(L10n.Motherboard.initializing)
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
                    currentScreenSize = newSize
                    setupDebugGame(screenSize: newSize)
                }
            }
            .onAppear {
                print("[DebugGameView] onAppear - geometry: \(geometry.size), gameScene: \(gameScene == nil ? "nil" : "exists")")
                // Also try on appear in case geometry is already valid
                if gameScene == nil && geometry.size.width > 0 && geometry.size.height > 0 {
                    currentScreenSize = geometry.size
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

            // Hash collected
            if let state = gameState {
                let hashAmount = Int(CGFloat(state.stats.enemiesKilled) * sector.hashMultiplier)
                HStack(spacing: 4) {
                    Text("Ħ")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(DesignColors.primary)
                    Text("\(hashAmount)")
                        .font(DesignTypography.headline(14))
                        .foregroundColor(DesignColors.primary)
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

                    Text(L10n.Extraction.available)
                        .font(DesignTypography.headline(18))
                        .foregroundColor(DesignColors.success)
                }

                // Current hash
                if let state = gameState {
                    let baseHash = state.stats.enemiesKilled
                    let multipliedHash = Int(CGFloat(baseHash) * sector.hashMultiplier)

                    HStack(spacing: 4) {
                        Text("Ħ")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(DesignColors.primary)
                        Text(L10n.Extraction.hashSecured(multipliedHash))
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
                            Text(L10n.Extraction.extract)
                                .font(DesignTypography.headline(16))
                            Text(L10n.Extraction.keepHash)
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
                            Text(L10n.Common.continueAction)
                                .font(DesignTypography.headline(16))
                            Text(L10n.Extraction.riskForMore)
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
                Text(showVictory ? L10n.Extraction.sectorCleansed : L10n.Debug.failed)
                    .font(DesignTypography.display(32))
                    .foregroundColor(showVictory ? DesignColors.success : DesignColors.danger)

                // Stats
                if let state = gameState {
                    VStack(spacing: 12) {
                        let baseHash = state.stats.enemiesKilled
                        let multipliedHash = Int(CGFloat(baseHash) * sector.hashMultiplier)
                        let finalHash = showVictory ? multipliedHash : multipliedHash / 2

                        HStack {
                            Text(L10n.Extraction.virusesEliminated)
                                .foregroundColor(DesignColors.muted)
                            Spacer()
                            Text("\(state.stats.enemiesKilled)")
                                .foregroundColor(.white)
                        }

                        HStack {
                            Text(L10n.Extraction.hashEarned)
                                .foregroundColor(DesignColors.muted)
                            Spacer()
                            HStack(spacing: 4) {
                                Text("Ħ")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(DesignColors.primary)
                                Text("+\(finalHash)")
                                    .foregroundColor(DesignColors.primary)
                            }
                        }

                        HStack {
                            Text(L10n.GameOver.timeSurvived)
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

                // Buttons
                HStack(spacing: 16) {
                    // Retry button
                    Button {
                        showGameOver = false
                        showVictory = false
                        setupDebugGame(screenSize: currentScreenSize)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.counterclockwise")
                            Text(L10n.Common.retry)
                        }
                        .font(DesignTypography.headline(16))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(DesignColors.surface)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(DesignColors.primary.opacity(0.5), lineWidth: 1)
                        )
                    }

                    // Exit button
                    Button {
                        // Award Hash before exiting
                        if let state = gameState {
                            let baseHash = state.stats.enemiesKilled
                            let multipliedHash = Int(CGFloat(baseHash) * sector.hashMultiplier)
                            let finalHash = showVictory ? multipliedHash : multipliedHash / 2
                            appState.updatePlayer { profile in
                                profile.addHash(max(1, finalHash))
                            }
                        }
                        onExit()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle")
                            Text(L10n.Common.collectAndExit)
                        }
                        .font(DesignTypography.headline(16))
                        .foregroundColor(.black)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(DesignColors.primary)
                        .cornerRadius(10)
                    }
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

// MARK: - Currency Info Sheet

struct CurrencyInfoSheet: View {
    let info: CurrencyInfoType
    @ObservedObject var appState = AppState.shared
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(DesignColors.muted)
                }
            }
            .padding(.horizontal)

            // Icon and title
            VStack(spacing: 12) {
                Image(systemName: info.icon)
                    .font(.system(size: 48))
                    .foregroundColor(info.color)

                Text(info.title)
                    .font(DesignTypography.display(24))
                    .foregroundColor(.white)
            }

            // Description
            Text(info.description)
                .font(DesignTypography.body(14))
                .foregroundColor(DesignColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            // PSU Upgrade section (only for power info)
            if info == .power {
                psuUpgradeSection
            }

            Spacer()
        }
        .padding(.top, 20)
        .background(DesignColors.background)
        .presentationDetents([.height(info == .power ? 480 : 320)])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private var psuUpgradeSection: some View {
        let currentLevel = appState.currentPlayer.globalUpgrades.psuLevel
        let tierName = GlobalUpgrades.psuTierName(at: currentLevel)
        let currentCapacity = GlobalUpgrades.powerCapacity(at: currentLevel)
        let nextCapacity = currentLevel < GlobalUpgrades.maxLevel ? GlobalUpgrades.powerCapacity(at: currentLevel + 1) : nil
        let upgradeCost = appState.currentPlayer.globalUpgrades.psuUpgradeCost
        let canAfford = upgradeCost != nil && appState.currentPlayer.hash >= upgradeCost!

        VStack(spacing: 16) {
            Divider()
                .background(DesignColors.muted.opacity(0.3))
                .padding(.horizontal)

            // Current PSU info
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.Currency.psuLevel)
                        .font(DesignTypography.caption(11))
                        .foregroundColor(DesignColors.muted)
                    Text("\(tierName) (\(currentCapacity)W)")
                        .font(DesignTypography.headline(16))
                        .foregroundColor(.yellow)
                }

                Spacer()

                if let nextCap = nextCapacity {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(L10n.Currency.nextLevel)
                            .font(DesignTypography.caption(11))
                            .foregroundColor(DesignColors.muted)
                        Text("\(nextCap)W")
                            .font(DesignTypography.headline(16))
                            .foregroundColor(.green)
                    }
                }
            }
            .padding(.horizontal, 24)

            // Upgrade button
            if let cost = upgradeCost {
                Button {
                    upgradePSU()
                } label: {
                    HStack {
                        Image(systemName: "bolt.badge.plus.fill")
                        Text(L10n.Currency.upgradePSU)
                        Spacer()
                        Text("Ħ \(cost)")
                            .font(DesignTypography.headline(14))
                    }
                    .font(DesignTypography.headline(14))
                    .foregroundColor(canAfford ? .black : DesignColors.muted)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(canAfford ? Color.yellow : DesignColors.surface)
                    .cornerRadius(12)
                }
                .disabled(!canAfford)
                .padding(.horizontal, 24)
            } else {
                Text(L10n.Currency.psuMaxed)
                    .font(DesignTypography.headline(14))
                    .foregroundColor(.green)
                    .padding(.horizontal, 24)
            }
        }
    }

    private func upgradePSU() {
        guard let cost = appState.currentPlayer.globalUpgrades.psuUpgradeCost,
              appState.currentPlayer.hash >= cost else { return }

        HapticsService.shared.play(.success)
        appState.updatePlayer { profile in
            profile.hash -= cost
            profile.globalUpgrades.psuLevel += 1
        }
    }
}

// MARK: - Preview

#Preview {
    SystemTabView()
}
