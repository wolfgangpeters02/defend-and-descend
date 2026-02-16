import Foundation
import UIKit
import Mixpanel

// MARK: - Analytics Service
// Centralized anonymous analytics using Mixpanel.
// Uses identifierForVendor as distinct_id — no PII collected.

final class AnalyticsService {

    static let shared = AnalyticsService()

    private let mixpanel: MixpanelInstance

    private init() {
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

        if let vendorId = UIDevice.current.identifierForVendor?.uuidString {
            mixpanel.identify(distinctId: vendorId)
        }
    }

    // MARK: - App Lifecycle

    func trackAppLaunched(firstLaunch: Bool) {
        mixpanel.track(event: "app_launched", properties: [
            "first_launch": firstLaunch
        ])
        mixpanel.flush()
    }

    func trackSessionStart() {
        mixpanel.track(event: "session_start")
    }

    func flush() {
        mixpanel.flush()
    }

    // MARK: - Tutorial

    func trackTutorialCompleted(type: String) {
        mixpanel.track(event: "tutorial_completed", properties: [
            "type": type
        ])
    }

    func trackFirstTowerPlaced() {
        mixpanel.track(event: "first_tower_placed")
    }

    // MARK: - Boss Fights

    func trackBossFightStarted(bossId: String, difficulty: String) {
        mixpanel.track(event: "boss_fight_started", properties: [
            "boss_id": bossId,
            "difficulty": difficulty
        ])
    }

    func trackBossFightCompleted(bossId: String, difficulty: String, victory: Bool, isFirstKill: Bool) {
        mixpanel.track(event: "boss_fight_completed", properties: [
            "boss_id": bossId,
            "difficulty": difficulty,
            "victory": victory,
            "first_kill": isFirstKill
        ])
    }

    func trackBlueprintDropped(bossId: String, protocolId: String) {
        mixpanel.track(event: "blueprint_dropped", properties: [
            "boss_id": bossId,
            "protocol_id": protocolId
        ])
    }

    // MARK: - Progression

    func trackProtocolCompiled(protocolId: String, cost: Int) {
        mixpanel.track(event: "protocol_compiled", properties: [
            "protocol_id": protocolId,
            "cost": cost
        ])
    }

    func trackProtocolUpgraded(protocolId: String, fromLevel: Int, toLevel: Int) {
        mixpanel.track(event: "protocol_upgraded", properties: [
            "protocol_id": protocolId,
            "from_level": fromLevel,
            "to_level": toLevel
        ])
    }

    func trackComponentUpgraded(component: String, fromLevel: Int, toLevel: Int) {
        mixpanel.track(event: "component_upgraded", properties: [
            "component": component,
            "from_level": fromLevel,
            "to_level": toLevel
        ])
    }

    func trackSectorUnlocked(sectorId: String, cost: Int) {
        mixpanel.track(event: "sector_unlocked", properties: [
            "sector_id": sectorId,
            "cost": cost
        ])
    }

    func trackLevelUp(newLevel: Int) {
        mixpanel.track(event: "level_up", properties: [
            "new_level": newLevel
        ])
    }

    func trackWaveCompleted(waveNumber: Int) {
        mixpanel.track(event: "wave_completed", properties: [
            "wave_number": waveNumber
        ])
    }

    // MARK: - Economy

    func trackOfflineEarningsClaimed(hashAmount: Int, timeAwayHours: Double) {
        mixpanel.track(event: "offline_earnings_claimed", properties: [
            "hash_amount": hashAmount,
            "time_away_hours": round(timeAwayHours * 10) / 10
        ])
    }
}
