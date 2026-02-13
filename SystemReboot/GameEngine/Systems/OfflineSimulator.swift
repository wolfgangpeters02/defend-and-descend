import Foundation
import CoreGraphics

// MARK: - Offline Simulator
// Extracted from StorageService (Phase 2.1)
// Game domain logic for offline earnings simulation:
// threat growth, defense analysis, leak rate prediction, efficiency degradation

struct OfflineSimulator {

    // MARK: - Offline Earnings Calculation

    /// Calculate offline earnings with defense simulation
    /// - Parameters:
    ///   - tdStats: The player's TD mode stats (threat level, defense strength, etc.)
    ///   - lastActiveTimestamp: When the player last left
    /// - Returns: Earnings result, or nil if no meaningful time has passed
    static func calculateEarnings(tdStats: TDModeStats) -> OfflineEarningsResult? {
        // Check if we have a valid last active timestamp
        guard tdStats.lastActiveTimestamp > 0 else {
            return nil
        }

        let now = Date().timeIntervalSince1970
        let timeAway = now - tdStats.lastActiveTimestamp

        // Minimum 1 minute away to earn anything
        guard timeAway >= 60 else {
            return nil
        }

        // Cap at max offline time
        let cappedTime = min(timeAway, BalanceConfig.OfflineSimulation.maxOfflineSeconds)

        // ---- OFFLINE SIMULATION ----

        // 1. Calculate threat growth (from BalanceConfig)
        // Capped at max threat level to keep Lv10 towers viable
        let offlineThreatGrowthRate = BalanceConfig.ThreatLevel.offlineThreatGrowthRate
        let startThreatLevel = tdStats.lastThreatLevel
        let threatGrowth = CGFloat(cappedTime) * offlineThreatGrowthRate
        let endThreatLevel = min(
            BalanceConfig.ThreatLevel.maxThreatLevel,
            startThreatLevel + threatGrowth
        )

        // 2. Calculate defense vs. offense
        // Defense strength = sum of tower DPS (stored when player left)
        let defenseStrength = tdStats.towerDefenseStrength
        let laneCount = max(1, tdStats.activeLaneCount)

        // Offense strength = f(threat level, lanes)
        // Use BalanceConfig for scaling values
        let avgThreatLevel = (startThreatLevel + endThreatLevel) / 2
        let healthMultiplier = 1.0 + (avgThreatLevel - 1.0) * BalanceConfig.ThreatLevel.healthScaling
        let spawnRateMultiplier = 1.0 + avgThreatLevel * BalanceConfig.ThreatLevel.spawnRateThreatScaling
        let baseEnemyHP = BalanceConfig.OfflineSimulation.baseEnemyHP
        let offenseStrengthPerLane = baseEnemyHP * healthMultiplier * spawnRateMultiplier
        let totalOffenseStrength = offenseStrengthPerLane * CGFloat(laneCount)

        // 3. Calculate leak rate
        // If defense < offense, enemies leak through
        let defenseRatio = defenseStrength > 0 ? defenseStrength / totalOffenseStrength : 0
        let defenseThreshold = BalanceConfig.OfflineSimulation.defenseThreshold

        var leaksPerHour: CGFloat = 0
        if defenseRatio < defenseThreshold {
            // Leaks scale with how overwhelmed defense is
            // At 0% defense: ~10 leaks per hour
            // At 50% defense: ~5 leaks per hour
            // At 80% defense: 0 leaks
            let deficitRatio = 1.0 - (defenseRatio / defenseThreshold)
            leaksPerHour = deficitRatio * BalanceConfig.OfflineSimulation.maxLeaksPerHour
        }

        // 4. Calculate total leaks
        let hoursOffline = CGFloat(cappedTime) / 3600.0
        let totalLeaks = Int(leaksPerHour * hoursOffline)

        // 5. Calculate new efficiency
        let startLeakCounter = tdStats.lastLeakCounter
        let newLeakCounter = startLeakCounter + totalLeaks
        let startEfficiency = max(0, min(100, 100 - CGFloat(startLeakCounter) * BalanceConfig.TDSession.efficiencyLossPerLeak))
        let newEfficiency = max(0, min(100, 100 - CGFloat(newLeakCounter) * BalanceConfig.TDSession.efficiencyLossPerLeak))

        // 6. Calculate average efficiency during offline period
        let avgEfficiency = (startEfficiency + newEfficiency) / 2

        // 7. Calculate hash earned based on average efficiency
        let baseRate = tdStats.baseHashPerSecond
        let cpuMultiplier = tdStats.cpuMultiplier
        let networkMultiplier = tdStats.networkHashMultiplier
        let offlineMultiplier: CGFloat = BalanceConfig.HashEconomy.offlineEarningsRate

        let hashEarned = Int(cappedTime * Double(baseRate * cpuMultiplier * networkMultiplier * (avgEfficiency / 100) * offlineMultiplier))

        return OfflineEarningsResult(
            hashEarned: hashEarned,
            timeAwaySeconds: timeAway,
            cappedTimeSeconds: cappedTime,
            wasCapped: timeAway > BalanceConfig.OfflineSimulation.maxOfflineSeconds,
            leaksOccurred: totalLeaks,
            newThreatLevel: endThreatLevel,
            newEfficiency: newEfficiency,
            startEfficiency: startEfficiency,
            defenseStrength: defenseStrength,
            offenseStrength: totalOffenseStrength
        )
    }

    // MARK: - Efficiency Notification Scheduling

    /// Estimate time until efficiency reaches 0% and schedule a notification
    /// - Parameters:
    ///   - efficiency: Current efficiency percentage
    ///   - threatLevel: Current threat level
    ///   - towerDefenseStrength: Total tower DPS
    ///   - activeLaneCount: Number of active lanes
    static func scheduleEfficiencyNotification(
        efficiency: CGFloat,
        threatLevel: CGFloat,
        towerDefenseStrength: CGFloat,
        activeLaneCount: Int
    ) {
        // Use the same calculation as offline simulation to estimate leak rate
        let offlineThreatGrowthRate = BalanceConfig.ThreatLevel.offlineThreatGrowthRate

        // Estimate average threat over next max offline period
        let estimatedAvgThreat = threatLevel + (CGFloat(BalanceConfig.OfflineSimulation.maxOfflineSeconds) * offlineThreatGrowthRate / 2)

        // Expected enemy HP at this threat level (base HP 20, scaling from BalanceConfig)
        let baseEnemyHP = BalanceConfig.OfflineSimulation.baseEnemyHP
        let avgEnemyHP = baseEnemyHP * (1 + estimatedAvgThreat * BalanceConfig.ThreatLevel.healthScaling)

        // Expected spawn rate from BalanceConfig
        let baseSpawnInterval = BalanceConfig.ThreatLevel.baseIdleSpawnRate
        let avgSpawnInterval = max(
            BalanceConfig.ThreatLevel.minSpawnInterval,
            baseSpawnInterval / (1 + estimatedAvgThreat * BalanceConfig.ThreatLevel.spawnRateThreatScaling)
        )
        let enemiesPerSecond = 1.0 / avgSpawnInterval

        // Total enemy HP per second = enemies/sec * HP per enemy * lanes
        let enemyHPPerSecond = enemiesPerSecond * avgEnemyHP * CGFloat(activeLaneCount)

        // Defense strength (tower DPS)
        let defensePerSecond = towerDefenseStrength

        // If defense < offense, calculate leak rate
        guard defensePerSecond < enemyHPPerSecond else {
            // Defense is strong enough - no notification needed
            NotificationService.shared.cancelEfficiencyNotifications()
            return
        }

        // HP deficit per second
        let hpDeficitPerSecond = enemyHPPerSecond - defensePerSecond

        // One leak = one enemy getting through
        // Estimate leaks per hour based on HP deficit
        let hpDeficitPerHour = hpDeficitPerSecond * 3600
        let leaksPerHour = hpDeficitPerHour / avgEnemyHP

        // Efficiency loss per leak from BalanceConfig
        let efficiencyPerLeak = BalanceConfig.ThreatLevel.efficiencyPerLeak
        let leaksUntilZero = efficiency / efficiencyPerLeak

        // Time until 0% efficiency
        guard leaksPerHour > 0 else { return }
        let hoursUntilZero = leaksUntilZero / leaksPerHour
        let secondsUntilZero = hoursUntilZero * 3600

        // Schedule notification within valid time range
        if secondsUntilZero >= BalanceConfig.OfflineSimulation.minNotificationTime
            && secondsUntilZero <= BalanceConfig.OfflineSimulation.maxNotificationTime {
            NotificationService.shared.scheduleEfficiencyZeroNotification(
                estimatedTimeUntilZero: secondsUntilZero
            )
        }
    }
}

// MARK: - Offline Earnings Result

struct OfflineEarningsResult {
    let hashEarned: Int
    let timeAwaySeconds: TimeInterval
    let cappedTimeSeconds: TimeInterval
    let wasCapped: Bool

    // Simulation Results
    let leaksOccurred: Int
    let newThreatLevel: CGFloat
    let newEfficiency: CGFloat
    let startEfficiency: CGFloat

    // Defense vs Offense (helps player understand why leaks occurred)
    let defenseStrength: CGFloat       // Tower DPS
    let offenseStrength: CGFloat       // Enemy HP/sec incoming

    /// Format time away as human-readable string
    var formattedTimeAway: String {
        let hours = Int(timeAwaySeconds) / 3600
        let minutes = (Int(timeAwaySeconds) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    /// Whether leaks occurred during offline time
    var hadLeaks: Bool {
        return leaksOccurred > 0
    }

    /// Damage report for UI display
    var damageReport: String {
        if leaksOccurred == 0 {
            return "Defense held. No breaches detected."
        } else if newEfficiency <= 0 {
            return "System compromised. \(leaksOccurred) breaches. Efficiency: 0%"
        } else {
            return "\(leaksOccurred) breaches detected. Efficiency: \(Int(newEfficiency))%"
        }
    }
}
