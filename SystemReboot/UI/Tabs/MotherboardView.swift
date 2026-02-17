import SwiftUI

// MARK: - Motherboard View - Embedded TD Game with HUD

struct MotherboardView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @ObservedObject var appState = AppState.shared
    @ObservedObject var embeddedGameController: EmbeddedTDGameController  // Passed from parent to persist across lifecycle
    @Binding var showSystemMenu: Bool  // Controls Arsenal/Settings sheet
    @State private var showManualOverride = false
    @State private var showCurrencyInfo: CurrencyInfoType? = nil
    @State private var showBossTutorial = false
    @ObservedObject private var hintManager = TutorialHintManager.shared

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

                // Overclock ring (always present — adapts to ready/active/unavailable)
                overclockRing

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

    /// Scale factor for HUD chips: 1.0 on iPhone SE (320pt), up to 1.25 on larger phones, up to 1.5 on iPad
    private var hudScale: CGFloat {
        let maxScale: CGFloat = sizeClass == .regular ? 1.5 : 1.25
        return min(maxScale, max(1.0, UIScreen.main.bounds.width / 340))
    }

    private var motherboardHUD: some View {
        let s = hudScale
        let fontSize: CGFloat = round(10 * s)
        let iconSize: CGFloat = round(11 * s)
        let hPad: CGFloat = round(7 * s)
        let vPad: CGFloat = round(5 * s)
        let chipSpacing: CGFloat = round(6 * s)
        let innerSpacing: CGFloat = round(3 * s)
        let cornerR: CGFloat = round(6 * s)

        return HStack(spacing: chipSpacing) {
            // Watts chip - tappable for PSU info/upgrade
            HStack(spacing: innerSpacing) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: iconSize))
                Text("\(embeddedGameController.gameState?.powerUsed ?? 0)/\(embeddedGameController.gameState?.powerCapacity ?? 300)W")
                    .font(.system(size: fontSize, weight: .semibold, design: .monospaced))
                    .lineLimit(1)
                    .fixedSize()
            }
            .foregroundColor(embeddedGameController.powerShakeTriggered ? .red : powerColor)
            .padding(.horizontal, hPad)
            .padding(.vertical, vPad)
            .background(
                RoundedRectangle(cornerRadius: cornerR)
                    .fill(DesignColors.surface)
                    .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
            )
            .offset(x: embeddedGameController.powerShakeTriggered ? -3 : 0)
            .animation(embeddedGameController.powerShakeTriggered ?
                Animation.easeInOut(duration: 0.05).repeatCount(6, autoreverses: true) :
                .default, value: embeddedGameController.powerShakeTriggered)
            .onTapGesture { showCurrencyInfo = .power }

            // Efficiency chip - color-coded percentage
            Text("\(Int(embeddedGameController.gameState?.efficiency ?? 100))%")
                .font(.system(size: fontSize, weight: .bold, design: .monospaced))
                .foregroundColor(efficiencyColor)
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, hPad)
                .padding(.vertical, vPad)
                .background(
                    RoundedRectangle(cornerRadius: cornerR)
                        .fill(DesignColors.surface)
                        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                )

            // Hash chip - tappable for currency info
            HStack(spacing: innerSpacing) {
                Image(systemName: "number.circle.fill")
                    .font(.system(size: iconSize))
                Text("Ħ" + NumberFormatUtils.compact(
                    embeddedGameController.gameState?.hash ?? appState.currentPlayer.hash
                ))
                    .font(.system(size: fontSize, weight: .bold, design: .monospaced))
                    .lineLimit(1)
                    .fixedSize()
            }
            .foregroundColor(.cyan)
            .padding(.horizontal, hPad)
            .padding(.vertical, vPad)
            .background(
                RoundedRectangle(cornerRadius: cornerR)
                    .fill(DesignColors.surface)
                    .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
            )
            .onTapGesture { showCurrencyInfo = .hash }

            Spacer()

            // System chip - opens Arsenal/Settings
            Button {
                HapticsService.shared.play(.selection)
                showSystemMenu = true
            } label: {
                HStack(spacing: innerSpacing) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: fontSize))
                    Text(L10n.Motherboard.system)
                        .font(.system(size: fontSize, weight: .bold, design: .monospaced))
                        .lineLimit(1)
                        .fixedSize()
                }
                .foregroundColor(DesignColors.secondary)
                .padding(.horizontal, hPad)
                .padding(.vertical, vPad)
                .background(
                    RoundedRectangle(cornerRadius: cornerR)
                        .fill(DesignColors.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerR)
                                .stroke(DesignColors.secondary.opacity(0.5), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                )
            }
            .tutorialGlow(color: DesignColors.primary, isActive: hintManager.hasUnseenBlueprints)
        }
        .padding(.horizontal, round(12 * s))
        .padding(.vertical, round(6 * s))
        .sheet(item: $showCurrencyInfo) { info in
            CurrencyInfoSheet(info: info, onPSUUpgraded: { cost in
                // Sync PSU capacity and hash deduction to live game state
                if var state = embeddedGameController.gameState {
                    state.powerCapacity = appState.currentPlayer.componentLevels.powerCapacity
                    state.hash -= cost
                    embeddedGameController.gameState = state
                    embeddedGameController.scene?.state = state
                }
            })
        }
    }

    private var efficiencyColor: Color {
        DesignHelpers.efficiencyColor(embeddedGameController.gameState?.efficiency ?? 100)
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
                        .foregroundColor(Color(hex: tower.color) ?? RarityColors.color(for: tower.rarity))

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
                        Text("\(Int(tower.effectiveDamage))")
                            .font(DesignTypography.headline(14))
                            .foregroundColor(DesignColors.danger)
                    }
                    VStack(spacing: 2) {
                        Text(L10n.Stats.rng)
                            .font(DesignTypography.caption(9))
                            .foregroundColor(DesignColors.muted)
                        Text("\(Int(tower.effectiveRange))")
                            .font(DesignTypography.headline(14))
                            .foregroundColor(DesignColors.success)
                    }
                    VStack(spacing: 2) {
                        Text(L10n.Stats.spd)
                            .font(DesignTypography.caption(9))
                            .foregroundColor(DesignColors.muted)
                        Text(String(format: "%.1f", tower.effectiveAttackSpeed))
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
                            AudioManager.shared.play(.towerUpgrade)
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

    // MARK: - Overclock Ring (Unified Component)

    private enum OverclockState {
        case ready       // Can tap to activate
        case active      // Running — show progress ring + countdown
        case unavailable // Boss active — show disabled with reason
    }

    private var currentOverclockState: OverclockState {
        if embeddedGameController.overclockActive { return .active }
        if embeddedGameController.isBossActive { return .unavailable }
        return .ready
    }

    /// Always-visible overclock component that adapts to ready/active/unavailable
    private var overclockRing: some View {
        let state = currentOverclockState
        let ringSize: CGFloat = 52
        let duration = BalanceConfig.Overclock.duration
        let remaining = embeddedGameController.overclockTimeRemaining
        let progress = duration > 0 ? remaining / duration : 0

        return VStack {
            HStack {
                Spacer()

                Button {
                    guard state == .ready else { return }
                    HapticsService.shared.play(.heavy)
                    embeddedGameController.scene?.activateOverclock()
                } label: {
                    VStack(spacing: 3) {
                        ZStack {
                            // Background ring (track)
                            Circle()
                                .fill(DesignColors.surface.opacity(0.9))
                                .frame(width: ringSize, height: ringSize)

                            // Progress ring (active state only)
                            if state == .active {
                                Circle()
                                    .trim(from: 0, to: progress)
                                    .stroke(
                                        Color.orange,
                                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                                    )
                                    .rotationEffect(.degrees(-90))
                                    .frame(width: ringSize - 4, height: ringSize - 4)
                                    .animation(.linear(duration: 0.5), value: progress)
                            }

                            // Outer ring (state-dependent)
                            Circle()
                                .stroke(
                                    state == .unavailable
                                        ? DesignColors.muted.opacity(0.3)
                                        : Color.orange.opacity(state == .active ? 0.8 : 0.5),
                                    lineWidth: state == .active ? 3 : 2
                                )
                                .frame(width: ringSize, height: ringSize)

                            // Bolt icon
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(
                                    state == .unavailable ? DesignColors.muted : .orange
                                )
                        }

                        // Label below ring
                        switch state {
                        case .ready:
                            Text(L10n.TD.overclock)
                                .font(DesignTypography.caption(9))
                                .foregroundColor(.orange)
                        case .active:
                            Text(String(format: "%.0fs", remaining))
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(.orange)
                        case .unavailable:
                            Text(L10n.TD.bossActive)
                                .font(DesignTypography.caption(8))
                                .foregroundColor(DesignColors.muted)
                        }
                    }
                }
                .disabled(state != .ready)
            }
            .padding(.trailing, 16)
            .padding(.top, 60)

            Spacer()
        }
        .animation(.easeInOut(duration: 0.25), value: state == .active)
        .animation(.easeInOut(duration: 0.25), value: state == .unavailable)
    }
}
