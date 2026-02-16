import SwiftUI

// MARK: - Motherboard View - Embedded TD Game with HUD

struct MotherboardView: View {
    @ObservedObject var appState = AppState.shared
    @ObservedObject var embeddedGameController: EmbeddedTDGameController  // Passed from parent to persist across lifecycle
    @Binding var showSystemMenu: Bool  // Controls Arsenal/Settings sheet
    @State private var showManualOverride = false
    @State private var showCurrencyInfo: CurrencyInfoType? = nil
    @State private var showBossTutorial = false

    // Boss Fight Coordinator (replaces NotificationCenter pattern)
    @StateObject private var bossCoordinator = BossFightCoordinator()

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
                   let protocolId = embeddedGameController.draggedProtocolId {
                    dragPreviewOverlay(protocolId: protocolId, geometry: geometry)
                }

                // System Freeze overlay (0% efficiency)
                if embeddedGameController.isSystemFrozen && !showManualOverride {
                    SystemFreezeOverlay(
                        currentHash: appState.currentPlayer.hash,
                        onFlushMemory: {
                            let hashCost = FreezeRecoveryService.flushCost(currentHash: appState.currentPlayer.hash)
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
                // Hide during transitions: boss fight active/starting, loot modal, or tutorial
                if embeddedGameController.isBossActive &&
                   !embeddedGameController.showBossDifficultySelector &&
                   !embeddedGameController.bossAlertDismissed &&
                   !bossCoordinator.showBossFight &&
                   !bossCoordinator.showBossLootModal &&
                   !showBossTutorial {
                    bossAlertOverlay
                }

                // Boss tutorial overlay (FTUE — first boss ever)
                if showBossTutorial {
                    BossTutorialOverlay(
                        controller: embeddedGameController,
                        bossType: embeddedGameController.activeBossType ?? "cyberboss",
                        onEngage: {
                            withAnimation {
                                showBossTutorial = false
                                embeddedGameController.showBossDifficultySelector = true
                            }
                        }
                    )
                    .transition(.opacity)
                    .zIndex(45)
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

                // Camera tutorial overlay (FTUE — first-time players)
                if embeddedGameController.showCameraTutorial {
                    CameraTutorialOverlay(
                        controller: embeddedGameController,
                        onComplete: {
                            embeddedGameController.completeCameraTutorial()
                        }
                    )
                    .transition(.opacity)
                    .zIndex(50)
                }
            }
            .coordinateSpace(name: "motherboardGameArea")
            .animation(.easeInOut(duration: 0.3), value: embeddedGameController.isSystemFrozen)
            .animation(.easeInOut(duration: 0.3), value: showManualOverride)
            .animation(.easeInOut(duration: 0.3), value: embeddedGameController.isBossActive)
            .animation(.easeInOut(duration: 0.3), value: embeddedGameController.showCameraTutorial)
            .animation(.easeInOut(duration: 0.3), value: showBossTutorial)
            .onChange(of: embeddedGameController.isBossActive) { isActive in
                // FTUE: Show boss tutorial instead of normal alert for first boss ever
                if isActive && !appState.currentPlayer.hasSeenBossTutorial {
                    embeddedGameController.bossAlertDismissed = true  // Suppress normal alert
                    showBossTutorial = true
                }
            }
            .onChange(of: appState.currentPlayer.firstTowerPlaced) { placed in
                // Tutorial: complete when first tower is placed
                if placed && embeddedGameController.showCameraTutorial {
                    embeddedGameController.completeCameraTutorial()
                }
            }
        }
        .fullScreenCover(isPresented: $bossCoordinator.showBossFight) {
            if let bossType = embeddedGameController.activeBossType,
               let boss = BossEncounter.all.first(where: { $0.bossId == bossType }) {
                BossGameView(
                    boss: boss,
                    difficulty: bossCoordinator.selectedBossDifficulty,
                    protocol: appState.currentPlayer.equippedProtocol() ?? ProtocolLibrary.kernelPulse,
                    onExit: {
                        bossCoordinator.showBossFight = false
                    },
                    bossFightCoordinator: bossCoordinator
                )
            }
        }
        .fullScreenCover(isPresented: $bossCoordinator.showBossLootModal) {
            BossLootModalWrapper(
                reward: bossCoordinator.pendingBossLootReward,
                onCollect: {
                    bossCoordinator.onLootCollected()
                }
            )
        }
        .fullScreenCover(isPresented: $bossCoordinator.showCampaignComplete) {
            CampaignCompleteOverlay {
                bossCoordinator.showCampaignComplete = false
            }
        }
        .onAppear {
            setupBossCoordinator()
        }
    }

    /// Configure the boss fight coordinator with embedded-mode callbacks
    private func setupBossCoordinator() {
        bossCoordinator.onVictory = { [self] sectorId, difficulty in
            let isFirstKill = !appState.currentPlayer.defeatedSectorBosses.contains(sectorId)

            // Reset boss state on VICTORY only
            embeddedGameController.isBossActive = false
            embeddedGameController.activeBossType = nil

            // Notify the TD scene that boss was defeated (cleans up boss, resets threat level)
            embeddedGameController.scene?.onBossFightWon(sectorId: sectorId)
            embeddedGameController.scene?.isPaused = false

            let hashReward = difficulty.hashReward

            // Determine next sector from BalanceConfig (embedded uses BalanceConfig directly)
            var nextSectorUnlocked: String?
            if isFirstKill {
                nextSectorUnlocked = BalanceConfig.SectorUnlock.nextSector(after: sectorId)
            }

            return BossFightVictoryContext(
                hashReward: hashReward,
                isFirstKill: isFirstKill,
                nextSectorUnlocked: nextSectorUnlocked
            )
        }

        bossCoordinator.onDefeat = { [self] in
            // Boss fight lost/retreated - boss stays on board for retry
            if var state = embeddedGameController.gameState {
                state.bossEngaged = false
                state.bossSelectedDifficulty = nil
                embeddedGameController.gameState = state
                embeddedGameController.scene?.state = state
            }
            embeddedGameController.scene?.isPaused = false
        }

        bossCoordinator.onLootApplied = { [self] reward in
            // Sync hash to game state
            if reward.totalHashReward > 0 {
                embeddedGameController.gameState?.hash += reward.totalHashReward
            }
        }
    }

    private var motherboardHUD: some View {
        HStack {
            // Power (⚡) - PSU usage - tappable for info
            HStack(spacing: 4) {
                Image(systemName: "bolt.fill")
                    .foregroundColor(embeddedGameController.powerShakeTriggered ? .red : powerColor)
                Text("\(embeddedGameController.gameState?.powerUsed ?? 0)/\(embeddedGameController.gameState?.powerCapacity ?? 300)W")
                    .font(DesignTypography.caption(12))
                    .foregroundColor(embeddedGameController.powerShakeTriggered ? .red : powerColor)
            }
            .offset(x: embeddedGameController.powerShakeTriggered ? -3 : 0)
            .animation(embeddedGameController.powerShakeTriggered ?
                Animation.easeInOut(duration: 0.05).repeatCount(6, autoreverses: true) :
                .default, value: embeddedGameController.powerShakeTriggered)
            .onTapGesture { showCurrencyInfo = .power }

            Spacer()

            // Hash (Ħ) - Currency with storage cap - tappable for info
            HStack(spacing: 4) {
                Image(systemName: "number.circle.fill")
                    .foregroundColor(.cyan)
                Text(NumberFormatUtils.hashWithCap(
                    current: embeddedGameController.gameState?.hash ?? appState.currentPlayer.hash,
                    max: embeddedGameController.gameState?.hashStorageCapacity ?? appState.currentPlayer.hashStorageCapacity
                ))
                    .font(DesignTypography.headline(12))
                    .foregroundColor(.cyan)
                    .fixedSize()
            }
            .onTapGesture { showCurrencyInfo = .hash }

            Spacer()

            // Efficiency bar
            HStack(spacing: 4) {
                let efficiency = (embeddedGameController.gameState?.efficiency ?? 100) / 100.0
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.gray.opacity(0.3))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(efficiencyColor)
                            .frame(width: geo.size.width * efficiency)
                    }
                }
                .frame(width: 50, height: 6)

                Text("\(Int((embeddedGameController.gameState?.efficiency ?? 100)))%")
                    .font(DesignTypography.caption(11))
                    .foregroundColor(efficiencyColor)
                    .fixedSize()
            }
            .fixedSize()

            Spacer()
                .frame(width: 12)

            // SYSTEM button - opens Arsenal/Settings menu
            Button {
                HapticsService.shared.play(.selection)
                showSystemMenu = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 10))
                    Text(L10n.Motherboard.system)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                }
                .foregroundColor(DesignColors.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(DesignColors.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
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
        DesignHelpers.efficiencyColor(embeddedGameController.gameState?.efficiency ?? 100)
    }

    /// Format hash with compact notation for large numbers (1.2K, 3.4M, etc.)
    private func formatHashCompact(_ value: Int) -> String {
        if value >= 1_000_000 {
            let millions = Double(value) / 1_000_000.0
            return String(format: "%.1fM", millions)
        } else if value >= 10_000 {
            let thousands = Double(value) / 1_000.0
            return String(format: "%.1fK", thousands)
        } else {
            return "\(value)"
        }
    }

    private var powerColor: Color {
        guard let state = embeddedGameController.gameState else { return DesignHelpers.powerColor(usage: 0) }
        let usage = CGFloat(state.powerUsed) / CGFloat(max(1, state.powerCapacity))
        return DesignHelpers.powerColor(usage: usage)
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
                                onDragStart: { embeddedGameController.startDrag(protocolId: proto.id) },
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

    private func dragPreviewOverlay(protocolId: String, geometry: GeometryProxy) -> some View {
        ZStack {
            if let proto = ProtocolLibrary.get(protocolId) {
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

            // Configure coordinator for this fight
            bossCoordinator.selectedBossDifficulty = difficulty
            bossCoordinator.activeBossType = embeddedGameController.activeBossType
            bossCoordinator.currentBossSectorId = embeddedGameController.gameState?.activeBossSectorId

            // Pause TD scene before starting boss fight
            embeddedGameController.scene?.isPaused = true
            bossCoordinator.onFightStarted()
            // Small delay before showing boss fight to let animation complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                bossCoordinator.showBossFight = true
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

                Text("\(String(format: "%.1f", difficulty.healthMultiplier))x HP")
                    .font(DesignTypography.headline(14))
                    .foregroundColor(DesignColors.muted)
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
        DesignHelpers.difficultyColor(difficulty)
    }

    /// Overclock button (visible when not overclocking)
    private var overclockButton: some View {
        VStack {
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
            .padding(.top, 60)

            Spacer()
        }
    }

    /// Overclock active indicator
    private var overclockActiveIndicator: some View {
        VStack {
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
            .padding(.top, 60)

            Spacer()
        }
    }
}
