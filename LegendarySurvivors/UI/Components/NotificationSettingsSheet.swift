import SwiftUI
import UserNotifications

// MARK: - Notification Settings Sheet
// Settings panel for managing push notification preferences

struct NotificationSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appState = AppState.shared
    @State private var permissionStatus: UNAuthorizationStatus = .notDetermined
    @State private var isRequestingPermission = false

    var body: some View {
        VStack(spacing: 20) {
            // Header with X button
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

            // Header icon
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 48))
                .foregroundColor(DesignColors.primary)

            // Title
            Text(L10n.Settings.title)
                .font(DesignTypography.display(24))
                .foregroundColor(.white)

            // Settings list
            VStack(spacing: 16) {
                // Efficiency alerts toggle
                notificationToggleRow
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .padding(.top, 20)
        .background(Color(hex: "0a0a0f") ?? DesignColors.background)
        .presentationDetents([.height(380)])
        .presentationDragIndicator(.visible)
        .onAppear {
            checkPermissionStatus()
        }
    }

    // MARK: - Notification Toggle Row

    private var notificationToggleRow: some View {
        VStack(spacing: 12) {
            // Main toggle card
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
                                // Cancel any pending notifications when disabled
                                NotificationService.shared.cancelEfficiencyNotifications()
                            }
                        }
                    ))
                    .toggleStyle(SwitchToggleStyle(tint: DesignColors.primary))
                } else if permissionStatus == .denied {
                    // Permission denied - show settings button
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
                    // Permission not determined - show enable button
                    Button(action: requestPermission) {
                        if isRequestingPermission {
                            ProgressView()
                                .tint(DesignColors.primary)
                        } else {
                            Text(L10n.Settings.notifications)
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
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: "161b22") ?? Color.gray.opacity(0.2))
            )

            // Permission status message
            if permissionStatus == .denied {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text(L10n.Settings.permissionRequired)
                        .font(DesignTypography.caption(11))
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 4)
            }
        }
    }

    // MARK: - Actions

    private func checkPermissionStatus() {
        NotificationService.shared.checkPermissionStatus { status in
            permissionStatus = status

            // If permission was granted but notifications were never enabled, auto-enable
            if status == .authorized && !appState.currentPlayer.notificationsEnabled {
                // Don't auto-enable, let user choose
            }
        }
    }

    private func requestPermission() {
        isRequestingPermission = true
        NotificationService.shared.requestPermission { granted in
            isRequestingPermission = false
            permissionStatus = granted ? .authorized : .denied

            if granted {
                // Auto-enable notifications when permission is first granted
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
}

// MARK: - Preview

#Preview {
    NotificationSettingsSheet()
}
