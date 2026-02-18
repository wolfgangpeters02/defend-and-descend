import Foundation
import UIKit
import Mixpanel

// MARK: - Analytics Service
// Centralized anonymous analytics using Mixpanel.
// Uses identifierForVendor as distinct_id — no PII collected.

final class AnalyticsService {

    static let shared = AnalyticsService()

    private static let analyticsEnabledKey = "analyticsEnabled"

    private let mixpanel: MixpanelInstance

    /// Whether analytics collection is enabled (user opt-in, defaults to true)
    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Self.analyticsEnabledKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.analyticsEnabledKey)
            if !newValue {
                // Opt-out: clear queued events and reset distinct ID (GDPR)
                mixpanel.reset()
            } else {
                // Re-identify on opt-in
                if let vendorId = UIDevice.current.identifierForVendor?.uuidString {
                    mixpanel.identify(distinctId: vendorId)
                }
            }
        }
    }

    private init() {
        // Default: analytics ON for new installs
        UserDefaults.standard.register(defaults: [Self.analyticsEnabledKey: true])

        mixpanel = Mixpanel.initialize(
            token: "f15129361422ad3dc2fec2951da3b77f",
            trackAutomaticEvents: false,
            flushInterval: 60,
            serverURL: "https://api-eu.mixpanel.com"
        )

        // Disable IP-based geolocation — no city/region/country derived from IP
        mixpanel.useIPAddressForGeoLocation = false

        #if DEBUG
        mixpanel.loggingEnabled = true
        #endif

        if isEnabled, let vendorId = UIDevice.current.identifierForVendor?.uuidString {
            mixpanel.identify(distinctId: vendorId)
        }
    }

    // MARK: - Data Deletion (GDPR)

    /// Delete all analytics data and reset identity
    func deleteAllData() {
        mixpanel.reset()
    }

    // MARK: - App Lifecycle

    func trackAppLaunched(firstLaunch: Bool) {
        guard isEnabled else { return }
        mixpanel.track(event: "app_launched", properties: [
            "first_launch": firstLaunch
        ])
        mixpanel.flush()
    }

    func trackSessionStart() {
        guard isEnabled else { return }
        mixpanel.track(event: "session_start")
    }

    func flush() {
        guard isEnabled else { return }
        mixpanel.flush()
    }

    // MARK: - Tutorial

    func trackTutorialCompleted(type: String) {
        guard isEnabled else { return }
        mixpanel.track(event: "tutorial_completed", properties: [
            "type": type
        ])
    }

    func trackFirstTowerPlaced() {
        guard isEnabled else { return }
        mixpanel.track(event: "first_tower_placed")
    }

    // MARK: - Boss Fights

    func trackBossFightStarted(bossId: String, difficulty: String) {
        guard isEnabled else { return }
        mixpanel.track(event: "boss_fight_started", properties: [
            "boss_id": bossId,
            "difficulty": difficulty
        ])
    }

    func trackBossFightCompleted(bossId: String, difficulty: String, victory: Bool, isFirstKill: Bool) {
        guard isEnabled else { return }
        mixpanel.track(event: "boss_fight_completed", properties: [
            "boss_id": bossId,
            "difficulty": difficulty,
            "victory": victory,
            "first_kill": isFirstKill
        ])
    }

    func trackBlueprintDropped(bossId: String, protocolId: String) {
        guard isEnabled else { return }
        mixpanel.track(event: "blueprint_dropped", properties: [
            "boss_id": bossId,
            "protocol_id": protocolId
        ])
    }

    // MARK: - Progression

    func trackProtocolCompiled(protocolId: String, cost: Int) {
        guard isEnabled else { return }
        mixpanel.track(event: "protocol_compiled", properties: [
            "protocol_id": protocolId,
            "cost": cost
        ])
    }

    func trackProtocolUpgraded(protocolId: String, fromLevel: Int, toLevel: Int) {
        guard isEnabled else { return }
        mixpanel.track(event: "protocol_upgraded", properties: [
            "protocol_id": protocolId,
            "from_level": fromLevel,
            "to_level": toLevel
        ])
    }

    func trackComponentUpgraded(component: String, fromLevel: Int, toLevel: Int) {
        guard isEnabled else { return }
        mixpanel.track(event: "component_upgraded", properties: [
            "component": component,
            "from_level": fromLevel,
            "to_level": toLevel
        ])
    }

    func trackSectorUnlocked(sectorId: String, cost: Int) {
        guard isEnabled else { return }
        mixpanel.track(event: "sector_unlocked", properties: [
            "sector_id": sectorId,
            "cost": cost
        ])
    }

    func trackLevelUp(newLevel: Int) {
        guard isEnabled else { return }
        mixpanel.track(event: "level_up", properties: [
            "new_level": newLevel
        ])
    }

    func trackWaveCompleted(waveNumber: Int) {
        guard isEnabled else { return }
        mixpanel.track(event: "wave_completed", properties: [
            "wave_number": waveNumber
        ])
    }

    // MARK: - Economy

    func trackOfflineEarningsClaimed(hashAmount: Int, timeAwayHours: Double) {
        guard isEnabled else { return }
        mixpanel.track(event: "offline_earnings_claimed", properties: [
            "hash_amount": hashAmount,
            "time_away_hours": round(timeAwayHours * 10) / 10
        ])
    }
}
