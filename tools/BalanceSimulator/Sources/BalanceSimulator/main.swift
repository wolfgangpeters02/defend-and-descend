#!/usr/bin/env swift
//
//  Balance Simulator CLI
//  Focused analysis for the 8 key balance areas
//
//  All values sourced directly from BalanceConfig.swift (symlinked).
//  No hardcoded balance values — always in sync with the game.
//
//  Usage:
//    cd tools/BalanceSimulator && swift run BalanceSimulator [command]
//
//  Commands:
//    protocols   Protocol level costs & damage scaling
//    hash        Hash economy (production, storage, offline)
//    power       Power grid (PSU budget, tower limits)
//    threat      Threat system (scaling, enemy unlocks)
//    bosses      Boss tuning (HP, damage, phases)
//    all         Run all analyses
//    reference   Generate HTML balance reference dashboard
//    help        Show this help
//

import Foundation
import CoreGraphics

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

    let maxLevel = BalanceConfig.maxUpgradeLevel

    printCauseEffect(
        "Level multiplier increases",
        "Higher levels deal more damage, but costs grow exponentially"
    )

    printSubheader("Damage Progression")
    print("\n  Level  Damage Mult  DPS Gain")
    print("  " + String(repeating: "-", count: 35))

    for level in 1...maxLevel {
        let dmgMult = Double(BalanceConfig.levelStatMultiplier(level: level))
        let prevMult = level > 1 ? Double(BalanceConfig.levelStatMultiplier(level: level - 1)) : 0
        let dpsGain = level > 1 ? ((dmgMult - prevMult) / prevMult * 100) : 0

        let dpsGainStr = level > 1 ? String(format: "+%.0f%%", dpsGain) : "-"
        print("  \(String(format: "%2d", level))       \(String(format: "%.1f", dmgMult))x        \(dpsGainStr)")
    }

    // Base upgrade costs from tower placement costs (same values)
    let commonBase = BalanceConfig.Towers.placementCosts[.common] ?? 50
    let rareBase = BalanceConfig.Towers.placementCosts[.rare] ?? 100
    let epicBase = BalanceConfig.Towers.placementCosts[.epic] ?? 200
    let legendaryBase = BalanceConfig.Towers.placementCosts[.legendary] ?? 400

    printSubheader("Upgrade Costs (Exponential: base * 2^(level-1))")
    print("\n  Level  Common    Rare      Epic      Legendary")
    print("  " + String(repeating: "-", count: 50))

    var totals: [Rarity: Int] = [.common: 0, .rare: 0, .epic: 0, .legendary: 0]

    for level in 2...maxLevel {
        let common = BalanceConfig.exponentialUpgradeCost(baseCost: commonBase, currentLevel: level - 1)
        let rare = BalanceConfig.exponentialUpgradeCost(baseCost: rareBase, currentLevel: level - 1)
        let epic = BalanceConfig.exponentialUpgradeCost(baseCost: epicBase, currentLevel: level - 1)
        let legendary = BalanceConfig.exponentialUpgradeCost(baseCost: legendaryBase, currentLevel: level - 1)

        totals[.common]! += common
        totals[.rare]! += rare
        totals[.epic]! += epic
        totals[.legendary]! += legendary

        print(String(format: "  %2d     %6d    %6d    %6d    %6d",
            level, common, rare, epic, legendary))
    }

    printSubheader("Total Cost to Max (Lv1 -> Lv\(maxLevel))")
    printRow("Common Protocol", "\(totals[.common]!) Hash")
    printRow("Rare Protocol", "\(totals[.rare]!) Hash")
    printRow("Epic Protocol", "\(totals[.epic]!) Hash")
    printRow("Legendary Protocol", "\(totals[.legendary]!) Hash")
}

func analyzeHash() {
    printHeader("HASH ECONOMY")

    printCauseEffect(
        "CPU level increases",
        "Hash/sec grows exponentially (base * mult^(level-1))"
    )

    let maxLevel = BalanceConfig.Components.maxLevel

    printSubheader("Hash Rate by CPU Level")
    print("\n  CPU Lv  Hash/sec   10min Earnings")
    print("  " + String(repeating: "-", count: 40))

    for level in 1...maxLevel {
        let rate = Double(BalanceConfig.HashEconomy.hashPerSecond(at: level))
        let tenMin = rate * 600
        print("  \(String(format: "%2d", level))       \(String(format: "%6.2f", rate))     \(formatNumber(tenMin))")
    }

    printSubheader("Storage Capacity (Exponential: base * 2^(level-1))")
    print("\n  Level  Capacity   Fill Time (CPU Lv1)")
    print("  " + String(repeating: "-", count: 45))

    let baseRate = Double(BalanceConfig.HashEconomy.hashPerSecond(at: 1))
    for level in 1...maxLevel {
        let capacity = BalanceConfig.Components.storageCapacity(at: level)
        let fillTime = Double(capacity) / baseRate
        let capStr = formatNumber(Double(capacity)).padding(toLength: 8, withPad: " ", startingAt: 0)
        print("  \(String(format: "%2d", level))     \(capStr)      \(formatTime(fillTime))")
    }

    printSubheader("Offline Earnings")
    let offlineRate = Double(BalanceConfig.HashEconomy.offlineEarningsRate)
    let maxHours = Double(BalanceConfig.HashEconomy.maxOfflineHours)
    let rate1 = Double(BalanceConfig.HashEconomy.hashPerSecond(at: 1))
    let rate5 = Double(BalanceConfig.HashEconomy.hashPerSecond(at: 5))
    let offline1 = rate1 * offlineRate * maxHours * 3600
    let offline5 = rate5 * offlineRate * maxHours * 3600

    printRow("Offline Rate", "\(Int(offlineRate * 100))% of online")
    printRow("Max Offline Hours", "\(Int(maxHours))h")
    printRow("\(Int(maxHours))h @ CPU Lv1", "\(formatNumber(offline1)) Hash")
    printRow("\(Int(maxHours))h @ CPU Lv5", "\(formatNumber(offline5)) Hash")

    printSubheader("Overclock")
    printRow("Duration", "\(Int(BalanceConfig.Overclock.duration))s")
    printRow("Hash Multiplier", "\(Double(BalanceConfig.Overclock.hashMultiplier))x")
    printRow("Power Multiplier", "\(Double(BalanceConfig.Overclock.powerDemandMultiplier))x")
}

func analyzePower() {
    printHeader("POWER GRID")

    printCauseEffect(
        "Power demand exceeds budget",
        "Towers shut down. Must balance tower count against PSU capacity."
    )

    let maxLevel = BalanceConfig.Components.maxLevel
    let tCommon = BalanceConfig.TowerPower.powerDraw(for: .common)
    let tRare = BalanceConfig.TowerPower.powerDraw(for: .rare)
    let tEpic = BalanceConfig.TowerPower.powerDraw(for: .epic)
    let tLegendary = BalanceConfig.TowerPower.powerDraw(for: .legendary)

    printSubheader("Power Budget by PSU Level")
    print("\n  PSU Lv  Budget    Max Common  Max Rare  Max Epic  Max Legendary")
    print("  " + String(repeating: "-", count: 65))

    for level in 1...maxLevel {
        let budget = BalanceConfig.Components.psuCapacity(at: level)
        print(String(format: "  %2d       %4dW     %4d        %4d      %4d      %4d",
            level, budget, budget / tCommon, budget / tRare, budget / tEpic, budget / tLegendary))
    }

    printSubheader("Tower Power Draw")
    printRow("Common", "\(tCommon)W")
    printRow("Rare", "\(tRare)W")
    printRow("Epic", "\(tEpic)W")
    printRow("Legendary", "\(tLegendary)W")

    printSubheader("Strategic Insight")
    let lvl5Budget = BalanceConfig.Components.psuCapacity(at: 5)
    print("  At PSU Lv5 (\(lvl5Budget)W budget):")
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

    let onlineRate = Double(BalanceConfig.ThreatLevel.onlineThreatGrowthRate)
    let healthScale = Double(BalanceConfig.ThreatLevel.healthScaling)
    let speedScale = Double(BalanceConfig.ThreatLevel.speedScaling)
    let damageScale = Double(BalanceConfig.ThreatLevel.damageScaling)

    printSubheader("Enemy Unlock Timeline (Online Play)")
    print("\n  Event          Threat   Time        HP Mult   Spd Mult   Dmg Mult")
    print("  " + String(repeating: "-", count: 70))

    let events: [(String, Double)] = [
        ("Fast Enemy", Double(BalanceConfig.ThreatLevel.fastEnemyThreshold)),
        ("Swarm Enemy", Double(BalanceConfig.ThreatLevel.swarmEnemyThreshold)),
        ("Tank Enemy", Double(BalanceConfig.ThreatLevel.tankEnemyThreshold)),
        ("Elite Enemy", Double(BalanceConfig.ThreatLevel.eliteEnemyThreshold)),
        ("Mini-Boss", Double(BalanceConfig.ThreatLevel.bossEnemyThreshold))
    ]

    for (name, threshold) in events {
        let time = threshold / onlineRate
        let hpMult = 1 + (threshold - 1) * healthScale
        let spdMult = 1 + (threshold - 1) * speedScale
        let dmgMult = 1 + (threshold - 1) * damageScale

        let paddedName = name.padding(toLength: 12, withPad: " ", startingAt: 0)
        let timeStr = formatTime(time).padding(toLength: 8, withPad: " ", startingAt: 0)
        print("  \(paddedName)   \(String(format: "%4.1f", threshold))     \(timeStr)    \(String(format: "%.2f", hpMult))x      \(String(format: "%.2f", spdMult))x      \(String(format: "%.2f", dmgMult))x")
    }

    printSubheader("Stat Scaling Formula")
    printRow("HP Scaling", "+\(Int(healthScale * 100))% per threat level")
    printRow("Speed Scaling", "+\(Int(speedScale * 100))% per threat level")
    printRow("Damage Scaling", "+\(Int(damageScale * 100))% per threat level")
    printRow("Max Threat Cap", "\(Int(Double(BalanceConfig.ThreatLevel.maxThreatLevel)))")

    printSubheader("Threat at Key Milestones")
    let threat5min = 5 * 60 * onlineRate
    let threat10min = 10 * 60 * onlineRate
    let hp5min = 1 + (threat5min - 1) * healthScale
    let hp10min = 1 + (threat10min - 1) * healthScale

    printRow("5 min online", String(format: "Threat %.1f (HP: %.1fx)", threat5min, hp5min))
    printRow("10 min online", String(format: "Threat %.1f (HP: %.1fx)", threat10min, hp10min))
}

func analyzeBosses() {
    printHeader("BOSS TUNING")

    printCauseEffect(
        "Boss HP/damage increases",
        "Fights take longer and punish mistakes more"
    )

    // Cyberboss
    let cbHealth = Double(BalanceConfig.Cyberboss.baseHealth)
    let waveScale = Double(BalanceConfig.Waves.healthScalingPerWave)
    let cbP2 = Double(BalanceConfig.Cyberboss.phase2Threshold)
    let cbP3 = Double(BalanceConfig.Cyberboss.phase3Threshold)
    let cbP4 = Double(BalanceConfig.Cyberboss.phase4Threshold)

    printSubheader("Cyberboss (TD Mode)")

    print("\n  Boss HP by Wave:")
    print("  Wave   Boss HP     Phase 2 @   Phase 3 @   Phase 4 @")
    print("  " + String(repeating: "-", count: 55))

    for wave in stride(from: 5, through: 30, by: 5) {
        let hp = cbHealth * (1 + Double(wave - 1) * waveScale)
        let p2 = hp * cbP2
        let p3 = hp * cbP3
        let p4 = hp * cbP4

        let hpStr = formatNumber(hp).padding(toLength: 8, withPad: " ", startingAt: 0)
        let p2Str = formatNumber(p2).padding(toLength: 8, withPad: " ", startingAt: 0)
        let p3Str = formatNumber(p3).padding(toLength: 8, withPad: " ", startingAt: 0)
        let p4Str = formatNumber(p4).padding(toLength: 8, withPad: " ", startingAt: 0)
        print("  \(String(format: "%3d", wave))    \(hpStr)    \(p2Str)    \(p3Str)    \(p4Str)")
    }

    printSubheader("Cyberboss Abilities")
    print("\n  Ability        Damage          Timing              Threat Level")
    print("  " + String(repeating: "-", count: 65))

    let laserDmg = Double(BalanceConfig.Cyberboss.laserBeamDamage)
    let puddleDPS = Double(BalanceConfig.Cyberboss.puddleDPS)
    let puddleLife = BalanceConfig.Cyberboss.puddleMaxLifetime
    let puddleWarn = BalanceConfig.Cyberboss.puddleWarningDuration
    let spawnMin = BalanceConfig.Cyberboss.fastMinionCountMin
    let spawnMax = BalanceConfig.Cyberboss.fastMinionCountMax
    let spawnInterval = BalanceConfig.Cyberboss.minionSpawnIntervalPhase1

    print(String(format: "  Laser Beam     %.0f (instant)    Rotating             Phase 4",
        laserDmg))
    print(String(format: "  Acid Puddle    %.0f/sec         %.1fs warn, %.1fs life  Phase 3+",
        puddleDPS, puddleWarn, puddleLife))
    print(String(format: "  Spawn Adds     %d-%d enemies    Every %.0fs            Phase 1+",
        spawnMin, spawnMax, spawnInterval))

}

func runAll() {
    analyzeProtocols()
    analyzeHash()
    analyzePower()
    analyzeThreat()
    analyzeBosses()

    printHeader("CROSS-SYSTEM INSIGHTS")

    // Calculate some cross-system balance checks
    let hashAt5Min = Double(BalanceConfig.HashEconomy.hashPerSecond(at: 1)) * 5 * 60
    let epicPlacementCost = BalanceConfig.Towers.placementCosts[.epic] ?? 200

    print("\n  Balance Check: Hash vs Upgrades")
    printRow("Hash in 5min (CPU Lv1)", formatNumber(hashAt5Min))
    printRow("Epic Tower Cost", "\(epicPlacementCost)")
    printRow("Can afford epic in 5min?", hashAt5Min >= Double(epicPlacementCost) ? "YES" : "NO")

    print("\n  Balance Check: Power vs Towers")
    let maxLevel = BalanceConfig.Components.maxLevel
    let maxBudget = BalanceConfig.Components.psuCapacity(at: maxLevel)
    let legendaryPower = BalanceConfig.TowerPower.powerDraw(for: .legendary)
    let maxLegendary = maxBudget / legendaryPower
    printRow("Max power (PSU Lv\(maxLevel))", "\(maxBudget)W")
    printRow("Max legendary towers", "\(maxLegendary)")

    print("\n  Balance Check: Threat vs Progression")
    let timeToBoss = Double(BalanceConfig.ThreatLevel.bossEnemyThreshold) / Double(BalanceConfig.ThreatLevel.onlineThreatGrowthRate)
    let hashByThen = Double(BalanceConfig.HashEconomy.hashPerSecond(at: 1)) * timeToBoss
    printRow("Time to mini-boss unlock", formatTime(timeToBoss))
    printRow("Hash earned by then (Lv1)", formatNumber(hashByThen))
}

func printHelp() {
    print("""

    Balance Simulator CLI
    Focused analysis for 8 key balance areas
    Values sourced from BalanceConfig.swift (always in sync)

    Usage: swift run BalanceSimulator [command]

    Commands:
      protocols   Protocol level costs & damage scaling
      hash        Hash economy (production, storage, offline)
      power       Power grid (PSU budget, tower limits)
      threat      Threat system (scaling, enemy unlocks)
      bosses      Boss tuning (HP, damage, phases)
      all         Run all analyses with cross-system insights
      reference   Generate HTML balance reference (balance-reference.html)
      help        Show this help

    Examples:
      swift run BalanceSimulator protocols
      swift run BalanceSimulator all
      swift run BalanceSimulator reference

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
case "reference", "ref", "html":
    let html = HTMLGenerator.generate()
    let outputPath = args.count > 2 ? args[2] : "../../balance-reference.html"
    do {
        try html.write(toFile: outputPath, atomically: true, encoding: .utf8)
        print("Generated: \(outputPath)")
    } catch {
        print("Error writing file: \(error)")
        exit(1)
    }
case "help", "--help", "-h":
    printHelp()
default:
    print("Unknown command: \(command)")
    printHelp()
    exit(1)
}

print("")  // Final newline
