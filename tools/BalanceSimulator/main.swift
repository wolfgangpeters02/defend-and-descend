#!/usr/bin/env swift
//
//  Balance Simulator CLI
//  Focused analysis for the 8 key balance areas
//
//  Usage:
//    swift main.swift [command]
//
//  Commands:
//    protocols   Protocol level costs & damage scaling
//    hash        Hash economy (production, storage, offline)
//    power       Power grid (CPU budget, tower limits)
//    threat      Threat system (scaling, enemy unlocks)
//    bosses      Boss tuning (HP, damage, phases)
//    all         Run all analyses
//    help        Show this help
//

import Foundation

// MARK: - Balance Config (Mirrors BalanceConfig.swift — keep in sync!)
// These values are duplicated from SystemReboot/Core/Config/BalanceConfig.swift
// because this CLI tool cannot import from the app module.
// Use BalanceConfig.exportJSON() to verify sync.

struct Config {

    // Protocol Scaling — mirrors BalanceConfig.ProtocolScaling
    struct ProtocolScaling {
        static let damageMultiplierPerLevel: Double = 1.0  // Level = multiplier
        static let rangePerLevel: Double = 0.05
        static let fireRatePerLevel: Double = 0.03
        static let maxLevel: Int = 10

        // Base upgrade costs by rarity
        static let baseCosts: [String: Int] = [
            "common": 50,
            "rare": 100,
            "epic": 200,
            "legendary": 400
        ]
    }

    // Hash Economy — mirrors BalanceConfig.HashEconomy
    struct HashEconomy {
        static let baseHashPerSecond: Double = 1.0
        static let cpuLevelMultiplier: Double = 1.5
        static let baseStorageCapacity: Int = 500
        static let storagePerUpgrade: Int = 500
        static let maxStorageTier: Int = 8
        static let offlineEarningsRate: Double = 0.2
        static let maxOfflineHours: Double = 8.0
    }

    // Overclock — mirrors BalanceConfig.Overclock
    struct Overclock {
        static let duration: Double = 60
        static let hashMultiplier: Double = 2.0
        static let powerMultiplier: Double = 2.0
    }

    // Power Grid — mirrors BalanceConfig.TowerPower + BalanceConfig.CPU
    struct PowerGrid {
        static let basePowerBudget: Int = 100
        static let powerPerCPULevel: Int = 50
        static let maxCPULevel: Int = 10

        // Tower power draw by rarity — must match BalanceConfig.TowerPower.powerDrawByRarity
        static let towerPower: [String: Int] = [
            "common": 15,
            "rare": 20,
            "epic": 30,
            "legendary": 40
        ]
    }

    // Threat Level — mirrors BalanceConfig.ThreatLevel
    struct ThreatLevel {
        static let maxThreatLevel: Double = 100.0
        static let onlineGrowthRate: Double = 0.01  // per second
        static let offlineGrowthRate: Double = 0.001
        static let healthScaling: Double = 0.15
        static let speedScaling: Double = 0.02
        static let damageScaling: Double = 0.05

        // Enemy unlock thresholds
        static let fastThreshold: Double = 2.0
        static let swarmThreshold: Double = 4.0
        static let tankThreshold: Double = 5.0
        static let eliteThreshold: Double = 8.0
        static let bossThreshold: Double = 10.0
    }

    // Cyberboss — mirrors BalanceConfig.Cyberboss
    struct Cyberboss {
        static let baseHealth: Double = 4000
        static let healthScalingPerWave: Double = 0.15
        static let laserDamage: Double = 50
        static let laserWarningDuration: Double = 1.5
        static let puddleDamagePerSecond: Double = 20
        static let puddleDuration: Double = 5.0
        static let spawnWaveSize: Int = 5
        static let spawnInterval: Double = 8.0
        static let phase2Threshold: Double = 0.75
        static let phase3Threshold: Double = 0.50
        static let phase4Threshold: Double = 0.25
    }

    // Zero-Day Virus — mirrors BalanceConfig.ZeroDay
    struct ZeroDay {
        static let baseHealth: Double = 9999
        static let speed: Double = 30
        static let efficiencyDrainRate: Double = 2.0
        static let minWavesBeforeSpawn: Int = 3
        static let defeatHashBonus: Int = 525
        static let defeatEfficiencyRestore: Int = 30
    }
}

// MARK: - Output Helpers

func printHeader(_ title: String) {
    print("\n" + String(repeating: "=", count: 60))
    print(" \(title)")
    print(String(repeating: "=", count: 60))
}

func printSubheader(_ title: String) {
    print("\n--- \(title) ---")
}

func printRow(_ label: String, _ value: String) {
    let padding = 35 - label.count
    print("  \(label)" + String(repeating: " ", count: max(1, padding)) + value)
}

func printCauseEffect(_ cause: String, _ effect: String) {
    print("\n  IF: \(cause)")
    print("  THEN: \(effect)")
}

func formatNumber(_ n: Double) -> String {
    if n >= 1_000_000 {
        return String(format: "%.1fM", n / 1_000_000)
    } else if n >= 1_000 {
        return String(format: "%.1fK", n / 1_000)
    } else if n == floor(n) {
        return String(format: "%.0f", n)
    } else {
        return String(format: "%.2f", n)
    }
}

func formatTime(_ seconds: Double) -> String {
    if seconds < 60 {
        return String(format: "%.0fs", seconds)
    } else if seconds < 3600 {
        return String(format: "%.1fm", seconds / 60)
    } else {
        return String(format: "%.1fh", seconds / 3600)
    }
}

// MARK: - Analysis Functions

func analyzeProtocols() {
    printHeader("PROTOCOL LEVELING")

    printCauseEffect(
        "Level multiplier increases",
        "Higher levels deal more damage, but costs grow exponentially"
    )

    printSubheader("Damage Progression")
    print("\n  Level  Damage Mult  DPS Gain")
    print("  " + String(repeating: "-", count: 35))

    for level in 1...Config.ProtocolScaling.maxLevel {
        let dmgMult = Double(level) * Config.ProtocolScaling.damageMultiplierPerLevel
        let prevMult = level > 1 ? Double(level - 1) * Config.ProtocolScaling.damageMultiplierPerLevel : 0
        let dpsGain = level > 1 ? ((dmgMult - prevMult) / prevMult * 100) : 0

        let dpsGainStr = level > 1 ? String(format: "+%.0f%%", dpsGain) : "-"
        print("  \(String(format: "%2d", level))       \(String(format: "%.1f", dmgMult))x        \(dpsGainStr)")
    }

    printSubheader("Upgrade Costs (Exponential: base * 2^(level-1))")
    print("\n  Level  Common    Rare      Epic      Legendary")
    print("  " + String(repeating: "-", count: 50))

    var totals: [String: Int] = ["common": 0, "rare": 0, "epic": 0, "legendary": 0]

    for level in 2...Config.ProtocolScaling.maxLevel {
        let multiplier = Int(pow(2.0, Double(level - 2)))

        let common = Config.ProtocolScaling.baseCosts["common"]! * multiplier
        let rare = Config.ProtocolScaling.baseCosts["rare"]! * multiplier
        let epic = Config.ProtocolScaling.baseCosts["epic"]! * multiplier
        let legendary = Config.ProtocolScaling.baseCosts["legendary"]! * multiplier

        totals["common"]! += common
        totals["rare"]! += rare
        totals["epic"]! += epic
        totals["legendary"]! += legendary

        print(String(format: "  %2d     %6d    %6d    %6d    %6d",
            level, common, rare, epic, legendary))
    }

    printSubheader("Total Cost to Max (Lv1 -> Lv10)")
    printRow("Common Protocol", "\(totals["common"]!) Hash")
    printRow("Rare Protocol", "\(totals["rare"]!) Hash")
    printRow("Epic Protocol", "\(totals["epic"]!) Hash")
    printRow("Legendary Protocol", "\(totals["legendary"]!) Hash")
}

func analyzeHash() {
    printHeader("HASH ECONOMY")

    printCauseEffect(
        "CPU level increases",
        "Hash/sec grows exponentially (base * mult^(level-1))"
    )

    printSubheader("Hash Rate by CPU Level")
    print("\n  CPU Lv  Hash/sec   10min Earnings")
    print("  " + String(repeating: "-", count: 40))

    for level in 1...10 {
        let rate = Config.HashEconomy.baseHashPerSecond * pow(Config.HashEconomy.cpuLevelMultiplier, Double(level - 1))
        let tenMin = rate * 600
        print("  \(String(format: "%2d", level))       \(String(format: "%6.2f", rate))     \(formatNumber(tenMin))")
    }

    printSubheader("Storage Capacity")
    print("\n  Tier  Capacity   Fill Time (Lv1 CPU)")
    print("  " + String(repeating: "-", count: 40))

    let baseRate = Config.HashEconomy.baseHashPerSecond
    for tier in 1...Config.HashEconomy.maxStorageTier {
        let capacity = Config.HashEconomy.baseStorageCapacity + (tier - 1) * Config.HashEconomy.storagePerUpgrade
        let fillTime = Double(capacity) / baseRate
        print("  \(String(format: "%2d", tier))     \(String(format: "%5d", capacity))      \(formatTime(fillTime))")
    }

    printSubheader("Offline Earnings")
    let rate1 = Config.HashEconomy.baseHashPerSecond
    let rate5 = Config.HashEconomy.baseHashPerSecond * pow(Config.HashEconomy.cpuLevelMultiplier, 4)
    let offline8h1 = rate1 * Config.HashEconomy.offlineEarningsRate * 8 * 3600
    let offline8h5 = rate5 * Config.HashEconomy.offlineEarningsRate * 8 * 3600

    printRow("Offline Rate", "\(Int(Config.HashEconomy.offlineEarningsRate * 100))% of online")
    printRow("Max Offline Hours", "\(Int(Config.HashEconomy.maxOfflineHours))h")
    printRow("8h @ CPU Lv1", "\(formatNumber(offline8h1)) Hash")
    printRow("8h @ CPU Lv5", "\(formatNumber(offline8h5)) Hash")

    printSubheader("Overclock")
    printRow("Duration", "\(Int(Config.Overclock.duration))s")
    printRow("Hash Multiplier", "\(Config.Overclock.hashMultiplier)x")
    printRow("Power Multiplier", "\(Config.Overclock.powerMultiplier)x")
}

func analyzePower() {
    printHeader("POWER GRID")

    printCauseEffect(
        "Power demand exceeds budget",
        "Towers shut down. Must balance tower count against CPU capacity."
    )

    printSubheader("Power Budget by CPU Level")
    print("\n  CPU Lv  Budget    Max Common  Max Rare  Max Epic  Max Legendary")
    print("  " + String(repeating: "-", count: 65))

    let tCommon = Config.PowerGrid.towerPower["common"]!
    let tRare = Config.PowerGrid.towerPower["rare"]!
    let tEpic = Config.PowerGrid.towerPower["epic"]!
    let tLegendary = Config.PowerGrid.towerPower["legendary"]!

    for level in 1...Config.PowerGrid.maxCPULevel {
        let budget = Config.PowerGrid.basePowerBudget + level * Config.PowerGrid.powerPerCPULevel
        print(String(format: "  %2d       %4dW     %4d        %4d      %4d      %4d",
            level, budget, budget / tCommon, budget / tRare, budget / tEpic, budget / tLegendary))
    }

    printSubheader("Tower Power Draw")
    printRow("Common", "\(tCommon)W")
    printRow("Rare", "\(tRare)W")
    printRow("Epic", "\(tEpic)W")
    printRow("Legendary", "\(tLegendary)W")

    printSubheader("Strategic Insight")
    let lvl5Budget = Config.PowerGrid.basePowerBudget + 5 * Config.PowerGrid.powerPerCPULevel
    print("  At CPU Lv5 (\(lvl5Budget)W budget):")
    print("  - Option A: \(lvl5Budget / tCommon) common towers (high quantity)")
    print("  - Option B: \(lvl5Budget / tEpic) epic + \((lvl5Budget % tEpic) / tCommon) common (quality mix)")
    print("  - Option C: \(lvl5Budget / tLegendary) legendary (elite setup)")
}

func analyzeThreat() {
    printHeader("THREAT SYSTEM")

    printCauseEffect(
        "Threat growth rate increases",
        "Enemies get stronger faster, new types unlock sooner"
    )

    printSubheader("Enemy Unlock Timeline (Online Play)")
    print("\n  Event          Threat   Time        HP Mult   Spd Mult   Dmg Mult")
    print("  " + String(repeating: "-", count: 70))

    let events: [(String, Double)] = [
        ("Fast Enemy", Config.ThreatLevel.fastThreshold),
        ("Swarm Enemy", Config.ThreatLevel.swarmThreshold),
        ("Tank Enemy", Config.ThreatLevel.tankThreshold),
        ("Elite Enemy", Config.ThreatLevel.eliteThreshold),
        ("Mini-Boss", Config.ThreatLevel.bossThreshold)
    ]

    for (name, threshold) in events {
        let time = threshold / Config.ThreatLevel.onlineGrowthRate
        let hpMult = 1 + (threshold - 1) * Config.ThreatLevel.healthScaling
        let spdMult = 1 + (threshold - 1) * Config.ThreatLevel.speedScaling
        let dmgMult = 1 + (threshold - 1) * Config.ThreatLevel.damageScaling

        let paddedName = name.padding(toLength: 12, withPad: " ", startingAt: 0)
        let timeStr = formatTime(time).padding(toLength: 8, withPad: " ", startingAt: 0)
        print("  \(paddedName)   \(String(format: "%4.1f", threshold))     \(timeStr)    \(String(format: "%.2f", hpMult))x      \(String(format: "%.2f", spdMult))x      \(String(format: "%.2f", dmgMult))x")
    }

    printSubheader("Stat Scaling Formula")
    printRow("HP Scaling", "+\(Int(Config.ThreatLevel.healthScaling * 100))% per threat level")
    printRow("Speed Scaling", "+\(Int(Config.ThreatLevel.speedScaling * 100))% per threat level")
    printRow("Damage Scaling", "+\(Int(Config.ThreatLevel.damageScaling * 100))% per threat level")
    printRow("Max Threat Cap", "\(Int(Config.ThreatLevel.maxThreatLevel))")

    printSubheader("Threat at Key Milestones")
    let threat5min = 5 * 60 * Config.ThreatLevel.onlineGrowthRate
    let threat10min = 10 * 60 * Config.ThreatLevel.onlineGrowthRate
    let hp5min = 1 + (threat5min - 1) * Config.ThreatLevel.healthScaling
    let hp10min = 1 + (threat10min - 1) * Config.ThreatLevel.healthScaling

    printRow("5 min online", String(format: "Threat %.1f (HP: %.1fx)", threat5min, hp5min))
    printRow("10 min online", String(format: "Threat %.1f (HP: %.1fx)", threat10min, hp10min))
}

func analyzeBosses() {
    printHeader("BOSS TUNING")

    printCauseEffect(
        "Boss HP/damage increases",
        "Fights take longer and punish mistakes more"
    )

    printSubheader("Cyberboss (TD Mode)")

    print("\n  Boss HP by Wave:")
    print("  Wave   Boss HP     Phase 2 @   Phase 3 @   Phase 4 @")
    print("  " + String(repeating: "-", count: 55))

    for wave in stride(from: 5, through: 30, by: 5) {
        let hp = Config.Cyberboss.baseHealth * (1 + Double(wave - 1) * Config.Cyberboss.healthScalingPerWave)
        let p2 = hp * Config.Cyberboss.phase2Threshold
        let p3 = hp * Config.Cyberboss.phase3Threshold
        let p4 = hp * Config.Cyberboss.phase4Threshold

        let hpStr = formatNumber(hp).padding(toLength: 8, withPad: " ", startingAt: 0)
        let p2Str = formatNumber(p2).padding(toLength: 8, withPad: " ", startingAt: 0)
        let p3Str = formatNumber(p3).padding(toLength: 8, withPad: " ", startingAt: 0)
        let p4Str = formatNumber(p4).padding(toLength: 8, withPad: " ", startingAt: 0)
        print("  \(String(format: "%3d", wave))    \(hpStr)    \(p2Str)    \(p3Str)    \(p4Str)")
    }

    printSubheader("Cyberboss Abilities")
    print("\n  Ability        Damage          Timing           Threat Level")
    print("  " + String(repeating: "-", count: 60))
    print(String(format: "  Laser Beam     %.0f (instant)    %.1fs warning      High",
        Config.Cyberboss.laserDamage, Config.Cyberboss.laserWarningDuration))
    print(String(format: "  Acid Puddle    %.0f/sec         %.1fs duration     Medium",
        Config.Cyberboss.puddleDamagePerSecond, Config.Cyberboss.puddleDuration))
    print(String(format: "  Spawn Adds     %d enemies      Every %.0fs        Low",
        Config.Cyberboss.spawnWaveSize, Config.Cyberboss.spawnInterval))

    printSubheader("Zero-Day Virus (Survival Mode)")
    printRow("Base HP", formatNumber(Config.ZeroDay.baseHealth))
    printRow("Speed", "\(Int(Config.ZeroDay.speed))")
    printRow("Efficiency Drain", "\(Config.ZeroDay.efficiencyDrainRate)/sec")
    printRow("Min Waves Before Spawn", "\(Config.ZeroDay.minWavesBeforeSpawn)")
    printRow("Defeat Hash Bonus", "\(Config.ZeroDay.defeatHashBonus)")
    printRow("Defeat Efficiency Restore", "\(Config.ZeroDay.defeatEfficiencyRestore)%")
}

func runAll() {
    analyzeProtocols()
    analyzeHash()
    analyzePower()
    analyzeThreat()
    analyzeBosses()

    printHeader("CROSS-SYSTEM INSIGHTS")

    // Calculate some cross-system balance checks
    let hashAt5Min = Config.HashEconomy.baseHashPerSecond * 5 * 60
    let epicPlacementCost = 200  // Typical epic tower placement

    print("\n  Balance Check: Hash vs Upgrades")
    printRow("Hash in 5min (CPU Lv1)", formatNumber(hashAt5Min))
    printRow("Epic Tower Cost", "\(epicPlacementCost)")
    printRow("Can afford epic in 5min?", hashAt5Min >= Double(epicPlacementCost) ? "YES" : "NO")

    print("\n  Balance Check: Power vs Towers")
    let maxBudget = Config.PowerGrid.basePowerBudget + 10 * Config.PowerGrid.powerPerCPULevel
    let maxLegendary = maxBudget / Config.PowerGrid.towerPower["legendary"]!
    printRow("Max power (CPU Lv10)", "\(maxBudget)W")
    printRow("Max legendary towers", "\(maxLegendary)")

    print("\n  Balance Check: Threat vs Progression")
    let timeToBoss = Config.ThreatLevel.bossThreshold / Config.ThreatLevel.onlineGrowthRate
    printRow("Time to mini-boss unlock", formatTime(timeToBoss))
    printRow("Hash earned by then (Lv1)", formatNumber(Config.HashEconomy.baseHashPerSecond * timeToBoss))
}

func printHelp() {
    print("""

    Balance Simulator CLI
    Focused analysis for 8 key balance areas

    Usage: swift main.swift [command]

    Commands:
      protocols   Protocol level costs & damage scaling
      hash        Hash economy (production, storage, offline)
      power       Power grid (CPU budget, tower limits)
      threat      Threat system (scaling, enemy unlocks)
      bosses      Boss tuning (HP, damage, phases)
      all         Run all analyses with cross-system insights
      help        Show this help

    Examples:
      swift main.swift protocols
      swift main.swift all
      swift main.swift all > balance-report.txt

    """)
}

// MARK: - Main

let args = CommandLine.arguments

if args.count < 2 {
    printHelp()
    exit(0)
}

let command = args[1].lowercased()

switch command {
case "protocols", "protocol":
    analyzeProtocols()
case "hash", "economy":
    analyzeHash()
case "power", "energy":
    analyzePower()
case "threat":
    analyzeThreat()
case "bosses", "boss":
    analyzeBosses()
case "all":
    runAll()
case "help", "--help", "-h":
    printHelp()
default:
    print("Unknown command: \(command)")
    printHelp()
    exit(1)
}

print("")  // Final newline
