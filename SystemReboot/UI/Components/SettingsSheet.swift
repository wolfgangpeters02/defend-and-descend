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

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Notifications Section
                    notificationsSection

                    // Debug
                    debugSection

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

    private var debugSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: L10n.Settings.debug, icon: "ladybug.fill", color: .orange)

            VStack(spacing: 12) {
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
            }
            .padding(16)
            .background(settingsCardBackground)
        }
    }

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
