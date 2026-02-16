#!/usr/bin/env swift
//
//  Balance Simulator CLI
//  Focused analysis for the 10 key balance areas
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
//    waves       Wave composition, DPS requirements, tower coverage
//    components  Component ROI, upgrade costs, optimal upgrade order
//    all         Run all analyses
//    simulate    Scenario simulation (passive/active/speedrun, duration in seconds)
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

    typealias PBS = BalanceConfig.ProtocolBaseStats

    printSubheader("Per-Protocol Base Stats (Firewall Mode)")
    print("\n  Protocol         Rarity     DMG  RNG  Rate  Pierce Splash Slow   Power  DPS")
    print("  " + String(repeating: "-", count: 78))

    let protocols: [(String, String, CGFloat, CGFloat, CGFloat, Int, CGFloat, CGFloat, Int)] = [
        ("Kernel Pulse",  "Common",    PBS.KernelPulse.firewallDamage,  PBS.KernelPulse.firewallRange,  PBS.KernelPulse.firewallFireRate,  PBS.KernelPulse.firewallPierce,  PBS.KernelPulse.firewallSplash,  PBS.KernelPulse.firewallSlow,  PBS.KernelPulse.firewallPowerDraw),
        ("Burst Protocol","Common",    PBS.BurstProtocol.firewallDamage, PBS.BurstProtocol.firewallRange, PBS.BurstProtocol.firewallFireRate, PBS.BurstProtocol.firewallPierce, PBS.BurstProtocol.firewallSplash, PBS.BurstProtocol.firewallSlow, PBS.BurstProtocol.firewallPowerDraw),
        ("Trace Route",   "Rare",      PBS.TraceRoute.firewallDamage,   PBS.TraceRoute.firewallRange,   PBS.TraceRoute.firewallFireRate,   PBS.TraceRoute.firewallPierce,   PBS.TraceRoute.firewallSplash,   PBS.TraceRoute.firewallSlow,   PBS.TraceRoute.firewallPowerDraw),
        ("Ice Shard",     "Rare",      PBS.IceShard.firewallDamage,     PBS.IceShard.firewallRange,     PBS.IceShard.firewallFireRate,     PBS.IceShard.firewallPierce,     PBS.IceShard.firewallSplash,     PBS.IceShard.firewallSlow,     PBS.IceShard.firewallPowerDraw),
        ("Fork Bomb",     "Epic",      PBS.ForkBomb.firewallDamage,     PBS.ForkBomb.firewallRange,     PBS.ForkBomb.firewallFireRate,     PBS.ForkBomb.firewallPierce,     PBS.ForkBomb.firewallSplash,     PBS.ForkBomb.firewallSlow,     PBS.ForkBomb.firewallPowerDraw),
        ("Root Access",   "Epic",      PBS.RootAccess.firewallDamage,   PBS.RootAccess.firewallRange,   PBS.RootAccess.firewallFireRate,   PBS.RootAccess.firewallPierce,   PBS.RootAccess.firewallSplash,   PBS.RootAccess.firewallSlow,   PBS.RootAccess.firewallPowerDraw),
        ("Overflow",      "Legendary", PBS.Overflow.firewallDamage,     PBS.Overflow.firewallRange,     PBS.Overflow.firewallFireRate,     PBS.Overflow.firewallPierce,     PBS.Overflow.firewallSplash,     PBS.Overflow.firewallSlow,     PBS.Overflow.firewallPowerDraw),
        ("Null Pointer",  "Legendary", PBS.NullPointer.firewallDamage,  PBS.NullPointer.firewallRange,  PBS.NullPointer.firewallFireRate,  PBS.NullPointer.firewallPierce,  PBS.NullPointer.firewallSplash,  PBS.NullPointer.firewallSlow,  PBS.NullPointer.firewallPowerDraw),
    ]

    for (name, rarity, dmg, rng, rate, pierce, splash, slow, power) in protocols {
        let dps = dmg * rate
        let paddedName = name.padding(toLength: 16, withPad: " ", startingAt: 0)
        let paddedRarity = rarity.padding(toLength: 10, withPad: " ", startingAt: 0)
        let slowStr = slow > 0 ? String(format: "%.0f%%", slow * 100) : "-"
        let splashStr = splash > 0 ? String(format: "%.0f", Double(splash)) : "-"
        print(String(format: "  %@ %@ %3.0f  %3.0f  %4.1f  %3d    %-6@ %-6@ %3dW   %.1f",
            paddedName, paddedRarity, Double(dmg), Double(rng), Double(rate), pierce, splashStr, slowStr, power, Double(dps)))
    }

    printSubheader("Per-Protocol Base Stats (Weapon Mode)")
    print("\n  Protocol         DMG  Rate  ProjCount  Spread  Pierce  Speed   DPS")
    print("  " + String(repeating: "-", count: 68))

    let weapons: [(String, CGFloat, CGFloat, Int, CGFloat, Int, CGFloat)] = [
        ("Kernel Pulse",   PBS.KernelPulse.weaponDamage,  PBS.KernelPulse.weaponFireRate,  PBS.KernelPulse.weaponProjectileCount,  PBS.KernelPulse.weaponSpread,  PBS.KernelPulse.weaponPierce,  PBS.KernelPulse.weaponProjectileSpeed),
        ("Burst Protocol", PBS.BurstProtocol.weaponDamage, PBS.BurstProtocol.weaponFireRate, PBS.BurstProtocol.weaponProjectileCount, PBS.BurstProtocol.weaponSpread, PBS.BurstProtocol.weaponPierce, PBS.BurstProtocol.weaponProjectileSpeed),
        ("Trace Route",    PBS.TraceRoute.weaponDamage,   PBS.TraceRoute.weaponFireRate,   PBS.TraceRoute.weaponProjectileCount,   PBS.TraceRoute.weaponSpread,   PBS.TraceRoute.weaponPierce,   PBS.TraceRoute.weaponProjectileSpeed),
        ("Ice Shard",      PBS.IceShard.weaponDamage,     PBS.IceShard.weaponFireRate,     PBS.IceShard.weaponProjectileCount,     PBS.IceShard.weaponSpread,     PBS.IceShard.weaponPierce,     PBS.IceShard.weaponProjectileSpeed),
        ("Fork Bomb",      PBS.ForkBomb.weaponDamage,     PBS.ForkBomb.weaponFireRate,     PBS.ForkBomb.weaponProjectileCount,     PBS.ForkBomb.weaponSpread,     PBS.ForkBomb.weaponPierce,     PBS.ForkBomb.weaponProjectileSpeed),
        ("Root Access",    PBS.RootAccess.weaponDamage,   PBS.RootAccess.weaponFireRate,   PBS.RootAccess.weaponProjectileCount,   PBS.RootAccess.weaponSpread,   PBS.RootAccess.weaponPierce,   PBS.RootAccess.weaponProjectileSpeed),
        ("Overflow",       PBS.Overflow.weaponDamage,     PBS.Overflow.weaponFireRate,     PBS.Overflow.weaponProjectileCount,     PBS.Overflow.weaponSpread,     PBS.Overflow.weaponPierce,     PBS.Overflow.weaponProjectileSpeed),
        ("Null Pointer",   PBS.NullPointer.weaponDamage,  PBS.NullPointer.weaponFireRate,  PBS.NullPointer.weaponProjectileCount,  PBS.NullPointer.weaponSpread,  PBS.NullPointer.weaponPierce,  PBS.NullPointer.weaponProjectileSpeed),
    ]

    for (name, dmg, rate, projCount, spread, pierce, speed) in weapons {
        let dps = dmg * rate * CGFloat(projCount)
        let paddedName = name.padding(toLength: 16, withPad: " ", startingAt: 0)
        print(String(format: "  %@  %3.0f  %4.1f  %5d      %4.1f    %3d     %3.0f    %.1f",
            paddedName, Double(dmg), Double(rate), projCount, Double(spread), pierce, Double(speed), Double(dps)))
    }
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

func analyzeWaves() {
    printHeader("WAVE ANALYSIS (TD MODE)")

    let totalWaves = BalanceConfig.TDSession.totalWaves

    printCauseEffect(
        "Wave number increases",
        "Enemy HP/speed scale up, new types appear, spawn delay decreases"
    )

    // Wave composition table
    printSubheader("Wave Composition (Waves 1-\(totalWaves))")
    print("\n  Wave  Enemies  HP Mult  Spd Mult  Spawn Delay  Composition         Boss?  Hash Bonus")
    print("  " + String(repeating: "-", count: 90))

    var cumulativeHash = 0
    for w in 1...totalWaves {
        let hpMult = Double(BalanceConfig.waveHealthMultiplier(waveNumber: w))
        let spdMult = Double(BalanceConfig.waveSpeedMultiplier(waveNumber: w))
        let count = BalanceConfig.Waves.baseEnemyCount + w * BalanceConfig.Waves.enemiesPerWave
        let delay = max(Double(BalanceConfig.Waves.minSpawnDelay),
                       Double(BalanceConfig.Waves.baseSpawnDelay) - Double(w) * Double(BalanceConfig.Waves.spawnDelayReductionPerWave))
        let isBoss = w % BalanceConfig.Waves.bossWaveInterval == 0
        let bonus = w * BalanceConfig.Waves.hashBonusPerWave
        cumulativeHash += bonus

        let comp: String
        if w <= BalanceConfig.Waves.earlyWaveMax { comp = "Basic" }
        else if w <= BalanceConfig.Waves.midEarlyWaveMax { comp = "Basic+Fast" }
        else if w <= BalanceConfig.Waves.midWaveMax { comp = "Basic+Fast+Tank" }
        else { comp = "All types" }

        let waveStr = isBoss ? "\(String(format: "%3d", w))*" : "\(String(format: "%3d", w)) "
        let compPad = comp.padding(toLength: 18, withPad: " ", startingAt: 0)
        print("  \(waveStr)    \(String(format: "%3d", count))     \(String(format: "%5.2f", hpMult))x   \(String(format: "%5.2f", spdMult))x    \(String(format: "%5.2f", delay))s       \(compPad) \(isBoss ? "YES" : " - ")    \(bonus) H (cum: \(cumulativeHash))")
    }
    print("\n  * = Boss wave (every \(BalanceConfig.Waves.bossWaveInterval) waves)")

    // Total wave HP calculation
    printSubheader("Total Wave HP (DPS Requirements)")
    print("\n  Wave  Total HP     Wave Duration  DPS Required  DPS/Tower (3T)  DPS/Tower (5T)")
    print("  " + String(repeating: "-", count: 80))

    let baseHP = BalanceConfig.EnemyDefaults.health

    for w in 1...totalWaves {
        let hpMult = Double(BalanceConfig.waveHealthMultiplier(waveNumber: w))
        let count = BalanceConfig.Waves.baseEnemyCount + w * BalanceConfig.Waves.enemiesPerWave
        let delay = max(Double(BalanceConfig.Waves.minSpawnDelay),
                       Double(BalanceConfig.Waves.baseSpawnDelay) - Double(w) * Double(BalanceConfig.Waves.spawnDelayReductionPerWave))
        let isBoss = w % BalanceConfig.Waves.bossWaveInterval == 0

        // Calculate total wave HP
        var totalHP = Double(count) * baseHP * hpMult
        if isBoss {
            totalHP += baseHP * hpMult * Double(BalanceConfig.Waves.bossHealthMultiplier)
        }

        // Wave duration = spawn delay * enemy count (approximate)
        let waveDuration = delay * Double(count)
        let dpsRequired = totalHP / waveDuration
        let dps3Towers = dpsRequired / 3.0
        let dps5Towers = dpsRequired / 5.0

        print("  \(String(format: "%3d", w))   \(formatNumber(totalHP).padding(toLength: 9, withPad: " ", startingAt: 0))  \(formatTime(waveDuration).padding(toLength: 12, withPad: " ", startingAt: 0))  \(String(format: "%8.1f", dpsRequired))      \(String(format: "%8.1f", dps3Towers))      \(String(format: "%8.1f", dps5Towers))")
    }

    // Tower DPS reference
    typealias PBS = BalanceConfig.ProtocolBaseStats
    printSubheader("Tower DPS Reference (Firewall Mode)")
    print("\n  Protocol         Rarity      Lv1 DPS   Lv5 DPS   Lv10 DPS")
    print("  " + String(repeating: "-", count: 60))

    let towerDPS: [(String, String, CGFloat, CGFloat)] = [
        ("Kernel Pulse",   "Common",    PBS.KernelPulse.firewallDamage,  PBS.KernelPulse.firewallFireRate),
        ("Burst Protocol", "Common",    PBS.BurstProtocol.firewallDamage, PBS.BurstProtocol.firewallFireRate),
        ("Trace Route",    "Rare",      PBS.TraceRoute.firewallDamage,   PBS.TraceRoute.firewallFireRate),
        ("Ice Shard",      "Rare",      PBS.IceShard.firewallDamage,     PBS.IceShard.firewallFireRate),
        ("Fork Bomb",      "Epic",      PBS.ForkBomb.firewallDamage,     PBS.ForkBomb.firewallFireRate),
        ("Root Access",    "Epic",      PBS.RootAccess.firewallDamage,   PBS.RootAccess.firewallFireRate),
        ("Overflow",       "Legendary", PBS.Overflow.firewallDamage,     PBS.Overflow.firewallFireRate),
        ("Null Pointer",   "Legendary", PBS.NullPointer.firewallDamage,  PBS.NullPointer.firewallFireRate),
    ]

    let dmgMult = Double(BalanceConfig.TowerUpgrades.damageMultiplier)
    let asMult = Double(BalanceConfig.TowerUpgrades.attackSpeedMultiplier)

    for (name, rarity, dmg, rate) in towerDPS {
        let baseDPS = Double(dmg * rate)
        let lv5DPS = baseDPS * pow(dmgMult, 4) * pow(asMult, 4)
        let lv10DPS = baseDPS * pow(dmgMult, 9) * pow(asMult, 9)
        let paddedName = name.padding(toLength: 16, withPad: " ", startingAt: 0)
        let paddedRarity = rarity.padding(toLength: 10, withPad: " ", startingAt: 0)
        print("  \(paddedName) \(paddedRarity)  \(String(format: "%7.1f", baseDPS))   \(String(format: "%7.1f", lv5DPS))   \(String(format: "%7.1f", lv10DPS))")
    }

    // Can N towers clear wave Y?
    printSubheader("Can Towers Clear Each Wave?")
    print("  Assumes 3 Kernel Pulse (Common) towers, all same level.")
    print("  Comparing combined DPS vs wave DPS requirement.\n")
    print("  Wave  Required DPS  3x KP Lv1  3x KP Lv5  3x KP Lv10  Verdict (Lv1)")
    print("  " + String(repeating: "-", count: 75))

    let kpBaseDPS = Double(PBS.KernelPulse.firewallDamage * PBS.KernelPulse.firewallFireRate)
    let kpLv5DPS = kpBaseDPS * pow(dmgMult, 4) * pow(asMult, 4)
    let kpLv10DPS = kpBaseDPS * pow(dmgMult, 9) * pow(asMult, 9)

    for w in stride(from: 1, through: totalWaves, by: 1) {
        let hpMult = Double(BalanceConfig.waveHealthMultiplier(waveNumber: w))
        let count = BalanceConfig.Waves.baseEnemyCount + w * BalanceConfig.Waves.enemiesPerWave
        let delay = max(Double(BalanceConfig.Waves.minSpawnDelay),
                       Double(BalanceConfig.Waves.baseSpawnDelay) - Double(w) * Double(BalanceConfig.Waves.spawnDelayReductionPerWave))
        let isBoss = w % BalanceConfig.Waves.bossWaveInterval == 0
        var totalHP = Double(count) * baseHP * hpMult
        if isBoss { totalHP += baseHP * hpMult * Double(BalanceConfig.Waves.bossHealthMultiplier) }
        let waveDuration = delay * Double(count)
        let dpsReq = totalHP / waveDuration

        let combined1 = kpBaseDPS * 3
        let combined5 = kpLv5DPS * 3
        let combined10 = kpLv10DPS * 3

        let verdict = combined1 >= dpsReq ? "OK" : (combined5 >= dpsReq ? "Need Lv5+" : "Need Lv10+")

        print("  \(String(format: "%3d", w))   \(String(format: "%10.1f", dpsReq))    \(String(format: "%8.1f", combined1))   \(String(format: "%8.1f", combined5))   \(String(format: "%9.1f", combined10))   \(verdict)")
    }
}

func analyzeComponents() {
    printHeader("COMPONENT ANALYSIS")

    printCauseEffect(
        "Component level increases",
        "Effect scales linearly, but cost grows exponentially"
    )

    let maxLevel = BalanceConfig.Components.maxLevel

    // Component overview
    printSubheader("Component Overview")
    print("\n  Component    Base Cost  Total to Max  Effect @ Lv1          Effect @ Lv10")
    print("  " + String(repeating: "-", count: 80))

    let components: [(id: String, name: String, e1: String, e10: String)] = [
        ("psu", "PSU",       "\(BalanceConfig.Components.psuCapacity(at: 1))W",
         "\(BalanceConfig.Components.psuCapacity(at: 10))W"),
        ("storage", "Storage",   "\(formatNumber(Double(BalanceConfig.Components.storageCapacity(at: 1)))) cap",
         "\(formatNumber(Double(BalanceConfig.Components.storageCapacity(at: 10)))) cap"),
        ("ram", "RAM",       String(format: "%.2fx recovery", Double(BalanceConfig.Components.ramEfficiencyRegen(at: 1))),
         String(format: "%.2fx recovery", Double(BalanceConfig.Components.ramEfficiencyRegen(at: 10)))),
        ("gpu", "GPU",       String(format: "%.2fx tower dmg", Double(BalanceConfig.Components.gpuDamageMultiplier(at: 1))),
         String(format: "%.2fx tower dmg", Double(BalanceConfig.Components.gpuDamageMultiplier(at: 10)))),
        ("cache", "Cache",     String(format: "%.2fx atk speed", Double(BalanceConfig.Components.cacheAttackSpeedMultiplier(at: 1))),
         String(format: "%.2fx atk speed", Double(BalanceConfig.Components.cacheAttackSpeedMultiplier(at: 10)))),
        ("expansion", "Expansion",  "+\(BalanceConfig.Components.expansionExtraSlots(at: 1)) tower slots",
         "+\(BalanceConfig.Components.expansionExtraSlots(at: 10)) tower slots"),
        ("io", "I/O",       String(format: "%.2fx pickup", Double(BalanceConfig.Components.ioPickupRadiusMultiplier(at: 1))),
         String(format: "%.2fx pickup", Double(BalanceConfig.Components.ioPickupRadiusMultiplier(at: 10)))),
        ("network", "Network",   String(format: "%.2fx hash mult", Double(BalanceConfig.Components.networkHashMultiplier(at: 1))),
         String(format: "%.2fx hash mult", Double(BalanceConfig.Components.networkHashMultiplier(at: 10)))),
        ("cpu", "CPU",       String(format: "%.2f H/s", Double(BalanceConfig.Components.cpuHashPerSecond(at: 1))),
         String(format: "%.1f H/s", Double(BalanceConfig.Components.cpuHashPerSecond(at: 10)))),
    ]

    for c in components {
        let baseCost = BalanceConfig.Components.baseCost(for: c.id)
        var totalCost = 0
        for lv in 1..<maxLevel {
            totalCost += BalanceConfig.exponentialUpgradeCost(baseCost: baseCost, currentLevel: lv)
        }
        let paddedName = c.name.padding(toLength: 10, withPad: " ", startingAt: 0)
        let e1Pad = c.e1.padding(toLength: 20, withPad: " ", startingAt: 0)
        print("  \(paddedName) \(String(format: "%6d", baseCost))     \(formatNumber(Double(totalCost)).padding(toLength: 10, withPad: " ", startingAt: 0))  \(e1Pad) \(c.e10)")
    }

    // Per-level costs and effects
    printSubheader("Per-Level Upgrade Costs")
    print("\n  Level  PSU      Storage  RAM      GPU      Cache    Expansion  I/O      Network  CPU")
    print("  " + String(repeating: "-", count: 100))

    for lv in 1..<maxLevel {
        var cells: [String] = [String(format: "%2d→%2d", lv, lv + 1)]
        for compId in ["psu", "storage", "ram", "gpu", "cache", "expansion", "io", "network", "cpu"] {
            let cost = BalanceConfig.exponentialUpgradeCost(baseCost: BalanceConfig.Components.baseCost(for: compId), currentLevel: lv)
            cells.append(formatNumber(Double(cost)).padding(toLength: 7, withPad: " ", startingAt: 0))
        }
        print("  \(cells.joined(separator: "  "))")
    }

    // ROI Analysis
    printSubheader("ROI Analysis (Cost per Effect Gained)")
    print("\n  Component    Lv1→2 Cost  Gain per Level         Cost/Gain  Priority")
    print("  " + String(repeating: "-", count: 80))

    // Calculate ROI for each component
    struct CompROI {
        let id: String
        let name: String
        let cost12: Int
        let gainDesc: String
        let costPerGain: Double  // Lower = better ROI
    }

    var roiList: [CompROI] = []

    // PSU: gain = extra watts
    let psuCost = BalanceConfig.Components.baseCost(for: "psu")
    let psuGain = BalanceConfig.Components.psuCapacity(at: 2) - BalanceConfig.Components.psuCapacity(at: 1)
    roiList.append(CompROI(id: "psu", name: "PSU", cost12: psuCost,
                           gainDesc: "+\(psuGain)W power",
                           costPerGain: Double(psuCost) / Double(psuGain)))

    // GPU: gain = damage multiplier increase
    let gpuCost = BalanceConfig.Components.baseCost(for: "gpu")
    let gpuGain = Double(BalanceConfig.Components.gpuDamageMultiplier(at: 2) - BalanceConfig.Components.gpuDamageMultiplier(at: 1))
    roiList.append(CompROI(id: "gpu", name: "GPU", cost12: gpuCost,
                           gainDesc: String(format: "+%.3fx tower dmg", gpuGain),
                           costPerGain: Double(gpuCost) / (gpuGain * 100)))  // per 1% gain

    // Cache: gain = attack speed increase
    let cacheCost = BalanceConfig.Components.baseCost(for: "cache")
    let cacheGain = Double(BalanceConfig.Components.cacheAttackSpeedMultiplier(at: 2) - BalanceConfig.Components.cacheAttackSpeedMultiplier(at: 1))
    roiList.append(CompROI(id: "cache", name: "Cache", cost12: cacheCost,
                           gainDesc: String(format: "+%.3fx atk speed", cacheGain),
                           costPerGain: Double(cacheCost) / (cacheGain * 100)))

    // CPU: gain = hash/sec increase
    let cpuCost = BalanceConfig.Components.baseCost(for: "cpu")
    let cpuGain = Double(BalanceConfig.Components.cpuHashPerSecond(at: 2) - BalanceConfig.Components.cpuHashPerSecond(at: 1))
    roiList.append(CompROI(id: "cpu", name: "CPU", cost12: cpuCost,
                           gainDesc: String(format: "+%.2f H/s", cpuGain),
                           costPerGain: Double(cpuCost) / cpuGain))

    // Network: gain = hash multiplier increase
    let netCost = BalanceConfig.Components.baseCost(for: "network")
    let netGain = Double(BalanceConfig.Components.networkHashMultiplier(at: 2) - BalanceConfig.Components.networkHashMultiplier(at: 1))
    roiList.append(CompROI(id: "network", name: "Network", cost12: netCost,
                           gainDesc: String(format: "+%.3fx hash mult", netGain),
                           costPerGain: Double(netCost) / (netGain * 100)))

    // Storage: gain = capacity increase
    let storageCost = BalanceConfig.Components.baseCost(for: "storage")
    let storageGain = BalanceConfig.Components.storageCapacity(at: 2) - BalanceConfig.Components.storageCapacity(at: 1)
    roiList.append(CompROI(id: "storage", name: "Storage", cost12: storageCost,
                           gainDesc: "+\(formatNumber(Double(storageGain))) cap",
                           costPerGain: Double(storageCost) / Double(storageGain)))

    // RAM: gain = efficiency regen increase
    let ramCost = BalanceConfig.Components.baseCost(for: "ram")
    let ramGain = Double(BalanceConfig.Components.ramEfficiencyRegen(at: 2) - BalanceConfig.Components.ramEfficiencyRegen(at: 1))
    roiList.append(CompROI(id: "ram", name: "RAM", cost12: ramCost,
                           gainDesc: String(format: "+%.3fx regen", ramGain),
                           costPerGain: Double(ramCost) / (ramGain * 100)))

    // Sort by cost/gain for priority ranking
    let sorted = roiList.sorted { $0.costPerGain < $1.costPerGain }
    for (i, roi) in sorted.enumerated() {
        let priority: String
        switch i {
        case 0: priority = "*** BEST ***"
        case 1: priority = "** HIGH **"
        case 2: priority = "* GOOD *"
        default: priority = ""
        }
        let paddedName = roi.name.padding(toLength: 10, withPad: " ", startingAt: 0)
        let gainPad = roi.gainDesc.padding(toLength: 21, withPad: " ", startingAt: 0)
        print("  \(paddedName) \(String(format: "%6d", roi.cost12))      \(gainPad) \(String(format: "%7.1f", roi.costPerGain))    \(priority)")
    }

    // Optimal upgrade path
    printSubheader("Optimal Upgrade Order (Budget-Based)")
    let budgets = [1000, 2500, 5000, 10000, 25000]
    for budget in budgets {
        var remaining = budget
        var upgrades: [String] = []
        var levels: [String: Int] = [:]
        for c in components { levels[c.id] = 1 }

        // Greedy: always pick cheapest available upgrade
        while true {
            var cheapest: (id: String, cost: Int)? = nil
            for c in components {
                let lv = levels[c.id]!
                guard lv < maxLevel else { continue }
                let cost = BalanceConfig.exponentialUpgradeCost(
                    baseCost: BalanceConfig.Components.baseCost(for: c.id),
                    currentLevel: lv
                )
                if cost <= remaining {
                    if cheapest == nil || cost < cheapest!.cost {
                        cheapest = (c.id, cost)
                    }
                }
            }
            guard let best = cheapest else { break }
            remaining -= best.cost
            levels[best.id]! += 1
            upgrades.append("\(best.id.uppercased())→\(levels[best.id]!)")
        }

        let spent = budget - remaining
        print("\n  Budget: \(formatNumber(Double(budget))) Hash (spent \(formatNumber(Double(spent))))")
        if upgrades.isEmpty {
            print("    No affordable upgrades")
        } else {
            // Group by component
            var grouped: [String: Int] = [:]
            for c in components {
                let finalLv = levels[c.id]!
                if finalLv > 1 { grouped[c.name] = finalLv }
            }
            let summary = grouped.map { "\($0.key) Lv\($0.value)" }.sorted().joined(separator: ", ")
            print("    Result: \(summary)")
            print("    Path: \(upgrades.joined(separator: " → "))")
        }
    }
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
    analyzeWaves()
    analyzeComponents()

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
    Focused analysis for 10 key balance areas
    Values sourced from BalanceConfig.swift (always in sync)

    Usage: swift run BalanceSimulator [command]

    Commands:
      protocols   Protocol level costs & damage scaling
      hash        Hash economy (production, storage, offline)
      power       Power grid (PSU budget, tower limits)
      threat      Threat system (scaling, enemy unlocks)
      bosses      Boss tuning (HP, damage, phases)
      waves       Wave composition, DPS requirements, tower coverage
      components  Component ROI, upgrade costs, optimal upgrade order
      all         Run all analyses with cross-system insights
      simulate    Scenario simulation (passive/active/speedrun)
      reference   Generate HTML balance reference (balance-reference.html)
      help        Show this help

    Simulate usage:
      swift run BalanceSimulator simulate passive 3600
      swift run BalanceSimulator simulate active 3600
      swift run BalanceSimulator simulate speedrun 7200

    Examples:
      swift run BalanceSimulator protocols
      swift run BalanceSimulator waves
      swift run BalanceSimulator components
      swift run BalanceSimulator all
      swift run BalanceSimulator simulate active 1800

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
case "waves", "wave":
    analyzeWaves()
case "components", "component", "comp":
    analyzeComponents()
case "all":
    runAll()
case "simulate", "sim":
    let scenario = args.count > 2 ? args[2].lowercased() : "passive"
    let duration = args.count > 3 ? Int(args[3]) ?? 3600 : 3600
    SimulationEngine.run(scenario: scenario, durationSeconds: duration)
case "reference", "ref", "html":
    let html = HTMLGenerator.generate()
    let outputPath = args.count > 2 ? args[2] : "../balance-reference.html"
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
