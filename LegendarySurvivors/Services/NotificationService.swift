import Foundation
import UserNotifications

// MARK: - Notification Service
// Handles local push notifications for efficiency alerts

class NotificationService {
    static let shared = NotificationService()

    private let notificationCenter = UNUserNotificationCenter.current()

    // Notification identifiers
    private enum NotificationID {
        static let efficiencyZero = "efficiency_zero_alert"
    }

    private init() {}

    // MARK: - Permission

    /// Request notification permission from user
    func requestPermission(completion: @escaping (Bool) -> Void) {
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("[NotificationService] Permission error: \(error.localizedDescription)")
                }
                completion(granted)
            }
        }
    }

    /// Check current authorization status
    func checkPermissionStatus(completion: @escaping (UNAuthorizationStatus) -> Void) {
        notificationCenter.getNotificationSettings { settings in
            DispatchQueue.main.async {
                completion(settings.authorizationStatus)
            }
        }
    }

    // MARK: - Efficiency Alerts

    /// Schedule a notification for when efficiency hits 0%
    /// Called during offline simulation when we calculate that efficiency will drop to 0
    func scheduleEfficiencyZeroNotification(estimatedTimeUntilZero: TimeInterval) {
        // Don't schedule if less than 1 minute away
        guard estimatedTimeUntilZero > 60 else { return }

        // Check if notifications are enabled in player settings
        guard AppState.shared.currentPlayer.notificationsEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "notification.efficiency.title")
        content.body = String(localized: "notification.efficiency.body")
        content.sound = .default
        content.badge = 1

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: estimatedTimeUntilZero,
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: NotificationID.efficiencyZero,
            content: content,
            trigger: trigger
        )

        notificationCenter.add(request) { error in
            if let error = error {
                print("[NotificationService] Failed to schedule notification: \(error.localizedDescription)")
            } else {
                print("[NotificationService] Scheduled efficiency alert for \(Int(estimatedTimeUntilZero / 60)) minutes from now")
            }
        }
    }

    /// Cancel any pending efficiency notifications (e.g., when player returns)
    func cancelEfficiencyNotifications() {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [NotificationID.efficiencyZero])
        // Also clear the badge
        UNUserNotificationCenter.current().setBadgeCount(0) { _ in }
    }

    /// Called when player returns - clear pending notifications
    func onPlayerReturned() {
        cancelEfficiencyNotifications()
    }

    // MARK: - Offline Simulation Integration

    /// Calculate and schedule notification based on offline simulation prediction
    /// This estimates when efficiency will hit 0 based on current defense strength
    func scheduleFromOfflineSimulation(
        currentEfficiency: CGFloat,
        leakRatePerHour: CGFloat,
        towerDefenseStrength: CGFloat
    ) {
        guard currentEfficiency > 0, leakRatePerHour > 0 else { return }

        // Each leak = 5% efficiency loss
        // Calculate hours until 0% efficiency
        let efficiencyPerLeak: CGFloat = 0.05
        let leaksUntilZero = currentEfficiency / efficiencyPerLeak
        let hoursUntilZero = leaksUntilZero / leakRatePerHour

        // Convert to seconds and schedule
        let secondsUntilZero = hoursUntilZero * 3600

        // Cap at 24 hours (don't schedule too far out)
        guard secondsUntilZero < 86400 else { return }

        scheduleEfficiencyZeroNotification(estimatedTimeUntilZero: secondsUntilZero)
    }
}
