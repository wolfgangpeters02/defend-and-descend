import SwiftUI
import UserNotifications

// MARK: - Settings Sheet
// Comprehensive settings panel with notifications, debug options, and account management

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appState = AppState.shared
    @State private var permissionStatus: UNAuthorizationStatus = .notDetermined
    @State private var isRequestingPermission = false
    @State private var showResetConfirmation = false

    #if DEBUG
    @State private var selectedDebugBoss: BossEncounter?
    #endif

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Audio Section
                    audioSection

                    // Notifications Section
                    notificationsSection

                    #if DEBUG
                    // Debug (only in development builds)
                    debugSection
                    #endif

                    // Danger Zone
                    dangerZoneSection
                }
                .padding()
            }
            .background(Color(hex: "0a0a0f") ?? DesignColors.background)
            .navigationTitle(L10n.Settings.title)
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
        .onAppear {
            checkPermissionStatus()
        }
        .alert(L10n.Settings.resetAlertTitle, isPresented: $showResetConfirmation) {
            Button(L10n.Common.cancel, role: .cancel) { }
            Button(L10n.Settings.reset, role: .destructive) {
                resetAccount()
            }
        } message: {
            Text(L10n.Settings.resetAlertMessage)
        }
        #if DEBUG
        .fullScreenCover(item: $selectedDebugBoss) { boss in
            BossGameView(
                boss: boss,
                difficulty: .easy,
                protocol: appState.currentPlayer.equippedProtocol() ?? ProtocolLibrary.kernelPulse,
                onExit: { selectedDebugBoss = nil }
            )
        }
        #endif
    }

    // MARK: - Audio Section

    private var audioSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: L10n.Settings.audio, icon: "speaker.wave.2.fill")

            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.Settings.soundEffects)
                            .font(DesignTypography.headline(16))
                            .foregroundColor(.white)

                        Text(L10n.Settings.soundEffectsDesc)
                            .font(DesignTypography.caption(12))
                            .foregroundColor(DesignColors.muted)
                    }

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { AudioManager.shared.soundEnabled },
                        set: { newValue in
                            AudioManager.shared.soundEnabled = newValue
                            HapticsService.shared.play(.selection)
                        }
                    ))
                    .toggleStyle(SwitchToggleStyle(tint: DesignColors.primary))
                }
            }
            .padding(16)
            .background(settingsCardBackground)
        }
    }

    // MARK: - Notifications Section

    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: L10n.Settings.notifications, icon: "bell.badge.fill")

            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.Settings.efficiencyAlerts)
                            .font(DesignTypography.headline(16))
                            .foregroundColor(.white)

                        Text(L10n.Settings.efficiencyAlertsDesc)
                            .font(DesignTypography.caption(12))
                            .foregroundColor(DesignColors.muted)
                    }

                    Spacer()

                    if permissionStatus == .authorized {
                        Toggle("", isOn: Binding(
                            get: { appState.currentPlayer.notificationsEnabled },
                            set: { newValue in
                                appState.currentPlayer.notificationsEnabled = newValue
                                StorageService.shared.savePlayer(appState.currentPlayer)
                                HapticsService.shared.play(.selection)
                                if !newValue {
                                    NotificationService.shared.cancelEfficiencyNotifications()
                                }
                            }
                        ))
                        .toggleStyle(SwitchToggleStyle(tint: DesignColors.primary))
                    } else if permissionStatus == .denied {
                        Button(action: openSystemSettings) {
                            Text(L10n.Settings.openSettings)
                                .font(DesignTypography.caption(12))
                                .foregroundColor(DesignColors.primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(DesignColors.primary.opacity(0.2))
                                .cornerRadius(8)
                        }
                    } else {
                        Button(action: requestPermission) {
                            if isRequestingPermission {
                                ProgressView()
                                    .tint(DesignColors.primary)
                            } else {
                                Text(L10n.Settings.enable)
                                    .font(DesignTypography.caption(12))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(DesignColors.primary)
                                    .cornerRadius(8)
                            }
                        }
                        .disabled(isRequestingPermission)
                    }
                }
                .padding(16)
                .background(settingsCardBackground)

                if permissionStatus == .denied {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text(L10n.Settings.permissionRequired)
                            .font(DesignTypography.caption(11))
                            .foregroundColor(.orange)
                    }
                }
            }
        }
    }

    // MARK: - Debug Section

    #if DEBUG
    private var debugSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: L10n.Settings.debug, icon: "ladybug.fill", color: .orange)

            VStack(spacing: 12) {
                // Debug Overlay toggle
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.Settings.debugOverlay)
                            .font(DesignTypography.headline(16))
                            .foregroundColor(.white)

                        Text(L10n.Settings.debugOverlayDesc)
                            .font(DesignTypography.caption(12))
                            .foregroundColor(DesignColors.muted)
                    }

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { appState.showDebugOverlay },
                        set: { newValue in
                            appState.showDebugOverlay = newValue
                            HapticsService.shared.play(.selection)
                        }
                    ))
                    .toggleStyle(SwitchToggleStyle(tint: .orange))
                }

                Divider().background(DesignColors.muted.opacity(0.3))

                // God Mode toggle
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.Settings.godMode)
                            .font(DesignTypography.headline(16))
                            .foregroundColor(.white)

                        Text(L10n.Settings.godModeDesc)
                            .font(DesignTypography.caption(12))
                            .foregroundColor(DesignColors.muted)
                    }

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { appState.godMode },
                        set: { newValue in
                            appState.godMode = newValue
                            HapticsService.shared.play(.selection)
                        }
                    ))
                    .toggleStyle(SwitchToggleStyle(tint: .orange))
                }

                Divider().background(DesignColors.muted.opacity(0.3))

                // Quick actions row
                HStack(spacing: 12) {
                    // +25K Hash
                    Button {
                        appState.debugHashPending += 25000
                        appState.updatePlayer { profile in
                            profile.hash += 25000
                        }
                        HapticsService.shared.play(.success)
                    } label: {
                        Text(L10n.Settings.addHash)
                            .font(DesignTypography.headline(14))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(DesignColors.primary)
                            .cornerRadius(8)
                    }

                    // Unlock All Sectors
                    Button {
                        debugUnlockAllSectors()
                    } label: {
                        let allUnlocked = BalanceConfig.SectorUnlock.unlockOrder.allSatisfy {
                            appState.currentPlayer.defeatedSectorBosses.contains($0)
                        }
                        Text(allUnlocked ? L10n.Settings.allSectorsUnlocked : L10n.Settings.unlockAllSectors)
                            .font(DesignTypography.headline(14))
                            .foregroundColor(allUnlocked ? DesignColors.muted : .black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(allUnlocked ? DesignColors.surface : Color.orange)
                            .cornerRadius(8)
                    }
                    .disabled(BalanceConfig.SectorUnlock.unlockOrder.allSatisfy {
                        appState.currentPlayer.defeatedSectorBosses.contains($0)
                    })
                }

                // Unlock All Protocols (blueprints)
                Button {
                    debugUnlockAllProtocols()
                } label: {
                    let allHave = ProtocolLibrary.all.allSatisfy { proto in
                        appState.currentPlayer.isProtocolCompiled(proto.id) || appState.currentPlayer.hasBlueprint(proto.id)
                    }
                    Text(allHave ? L10n.Settings.allProtocolsUnlocked : L10n.Settings.unlockAllProtocols)
                        .font(DesignTypography.headline(14))
                        .foregroundColor(allHave ? DesignColors.muted : .black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(allHave ? DesignColors.surface : Color.orange)
                        .cornerRadius(8)
                }
                .disabled(ProtocolLibrary.all.allSatisfy { proto in
                    appState.currentPlayer.isProtocolCompiled(proto.id) || appState.currentPlayer.hasBlueprint(proto.id)
                })

                Divider().background(DesignColors.muted.opacity(0.3))

                // Boss Arena
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.Settings.bossArena)
                        .font(DesignTypography.headline(14))
                        .foregroundColor(.orange)

                    Text(L10n.Settings.bossArenaDesc)
                        .font(DesignTypography.caption(12))
                        .foregroundColor(DesignColors.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ForEach(BossEncounter.all) { boss in
                        debugBossRow(boss: boss)
                    }
                }
            }
            .padding(16)
            .background(settingsCardBackground)
        }
    }

    private func debugBossRow(boss: BossEncounter) -> some View {
        let killRecord = appState.currentPlayer.bossKillRecords[boss.bossId]
        let isDefeated = killRecord != nil && (killRecord?.totalKills ?? 0) > 0
        let bossColor = Color(hex: boss.color) ?? .red

        return HStack {
            Image(systemName: boss.iconName)
                .font(.system(size: 24))
                .foregroundColor(bossColor)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(boss.name)
                    .font(DesignTypography.headline(14))
                    .foregroundColor(.white)

                if isDefeated {
                    Text(L10n.Settings.defeated)
                        .font(DesignTypography.caption(10))
                        .foregroundColor(DesignColors.success)
                } else {
                    Text(L10n.Settings.notEncountered)
                        .font(DesignTypography.caption(10))
                        .foregroundColor(DesignColors.muted)
                }
            }

            Spacer()

            Button {
                selectedDebugBoss = boss
            } label: {
                Text(L10n.Settings.fight)
                    .font(DesignTypography.caption(12))
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(bossColor)
                    .cornerRadius(8)
            }
        }
        .padding(.vertical, 4)
    }

    private func debugUnlockAllSectors() {
        appState.updatePlayer { profile in
            for sectorId in BalanceConfig.SectorUnlock.unlockOrder {
                SectorUnlockSystem.shared.recordBossDefeat(sectorId, profile: &profile)
            }
        }
        HapticsService.shared.play(.success)
    }

    private func debugUnlockAllProtocols() {
        appState.updatePlayer { profile in
            for proto in ProtocolLibrary.all {
                // Skip if already compiled or already has blueprint
                if profile.isProtocolCompiled(proto.id) || profile.hasBlueprint(proto.id) {
                    continue
                }
                profile.protocolBlueprints.append(proto.id)
            }
        }
        HapticsService.shared.play(.success)
    }
    #endif

    // MARK: - Danger Zone Section

    private var dangerZoneSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: L10n.Settings.dangerZone, icon: "exclamationmark.triangle.fill", color: .red)

            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.Settings.resetAccount)
                            .font(DesignTypography.headline(16))
                            .foregroundColor(.white)

                        Text(L10n.Settings.resetAccountDesc)
                            .font(DesignTypography.caption(12))
                            .foregroundColor(DesignColors.muted)
                    }

                    Spacer()

                    Button {
                        showResetConfirmation = true
                    } label: {
                        Text(L10n.Settings.reset)
                            .font(DesignTypography.caption(12))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.red)
                            .cornerRadius(8)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(DesignColors.surfaceElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.red.opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }

    // MARK: - Helpers

    private func sectionHeader(title: String, icon: String, color: Color = DesignColors.primary) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
            Text(title)
                .font(DesignTypography.caption(12))
                .foregroundColor(color)
        }
    }

    private var settingsCardBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(DesignColors.surfaceElevated)
    }

    // MARK: - Actions

    private func checkPermissionStatus() {
        NotificationService.shared.checkPermissionStatus { status in
            permissionStatus = status
        }
    }

    private func requestPermission() {
        isRequestingPermission = true
        NotificationService.shared.requestPermission { granted in
            isRequestingPermission = false
            permissionStatus = granted ? .authorized : .denied
            if granted {
                appState.currentPlayer.notificationsEnabled = true
                StorageService.shared.savePlayer(appState.currentPlayer)
                HapticsService.shared.play(.success)
            }
        }
    }

    private func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private func resetAccount() {
        HapticsService.shared.play(.warning)

        // Reset player profile to default
        var freshProfile = PlayerProfile.defaultProfile
        freshProfile.id = appState.currentPlayer.id // Keep same ID

        // Save and update
        StorageService.shared.savePlayer(freshProfile)
        appState.currentPlayer = freshProfile

        // Clear TD session state (towers, slots, resources)
        StorageService.shared.clearTDSession()

        // Signal TD game controller to reinitialize
        appState.tdResetRequested = true

        // Reset tutorial state - clear any active hints
        TutorialHintManager.shared.activeHints.removeAll()

        // Dismiss settings
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    SettingsSheet()
}
