#!/usr/bin/env swift
//
//  Balance Simulator CLI
//  Runs automated simulations for game balance analysis
//
//  Usage:
//    swift main.swift [command] [options]
//
//  Commands:
//    waves       Simulate wave progression
//    drops       Monte Carlo drop simulation
//    economy     Economy flow analysis
//    threat      Threat level scaling
//    all         Run all simulations
//    analyze     AI-ready analysis output (JSON)
//

import Foundation

// MARK: - Balance Config (Mirror of BalanceConfig.swift)

struct BalanceConfig {
    struct Waves {
        static var healthScalingPerWave: Double = 0.15
        static var speedScalingPerWave: Double = 0.02
        static var baseEnemyCount: Int = 5
        static var enemiesPerWave: Int = 2
        static var bossWaveInterval: Int = 5
        static var bossHealthMultiplier: Double = 2.0
        static var bossSpeedMultiplier: Double = 0.8
        static var hashBonusPerWave: Int = 10
    }

    struct ThreatLevel {
        static var healthScaling: Double = 0.15
        static var speedScaling: Double = 0.02
        static var damageScaling: Double = 0.05
        static var fastEnemyThreshold: Double = 2.0
        static var tankEnemyThreshold: Double = 5.0
        static var bossEnemyThreshold: Double = 10.0
        static var fastEnemyWeightPerThreat: Double = 15
        static var tankEnemyWeightPerThreat: Double = 10
        static var bossEnemyWeightPerThreat: Double = 2
    }

    struct Towers {
        static var placementCosts: [String: Int] = [
            "common": 50,
            "rare": 100,
            "epic": 200,
            "legendary": 400
        ]
        static var refundRate: Double = 0.5
        static var projectileSpeed: Double = 600
    }

    struct SurvivalEconomy {
        static var extractionTime: Double = 180
        static var hashPerSecond: Double = 2.0
        static var hashBonusPerMinute: Double = 0.5
    }

    struct DropRates {
        static var common: Double = 0.60
        static var rare: Double = 0.30
        static var epic: Double = 0.08
        static var legendary: Double = 0.02
        static var easyMultiplier: Double = 0.5
        static var normalMultiplier: Double = 1.0
        static var hardMultiplier: Double = 1.5
        static var nightmareMultiplier: Double = 2.5
        static var pityThreshold: Int = 10
        static var diminishingFactor: Double = 0.1
    }

    static func waveHealthMultiplier(wave: Int) -> Double {
        return 1.0 + Double(wave - 1) * Waves.healthScalingPerWave
    }

    static func waveSpeedMultiplier(wave: Int) -> Double {
        return 1.0 + Double(wave - 1) * Waves.speedScalingPerWave
    }

    static func threatHealthMultiplier(threat: Double) -> Double {
        return 1.0 + (threat - 1.0) * ThreatLevel.healthScaling
    }
}

// MARK: - Simulation Results

struct WaveSimulation: Codable {
    struct WaveData: Codable {
        let wave: Int
        let enemyHP: Double
        let enemySpeed: Double
        let enemyCount: Int
        let totalWaveHP: Double
        let isBossWave: Bool
        let hashReward: Int
    }

    let waves: [WaveData]
    let insights: [String]
}

struct DropSimulation: Codable {
    struct DropResult: Codable {
        let common: Int
        let rare: Int
        let epic: Int
        let legendary: Int
        let noDrop: Int
        let totalDrops: Int
        let dropRate: Double
    }

    let kills: Int
    let difficulty: String
    let results: DropResult
    let insights: [String]
}

struct EconomySimulation: Codable {
    struct TimePoint: Codable {
        let seconds: Int
        let totalHash: Int
        let hashRate: Double
    }

    let timeline: [TimePoint]
    let timeToAfford: [String: Int]
    let insights: [String]
}

struct ThreatSimulation: Codable {
    struct ThreatPoint: Codable {
        let threat: Double
        let hpMultiplier: Double
        let speedMultiplier: Double
        let damageMultiplier: Double
        let availableEnemyTypes: [String]
    }

    let points: [ThreatPoint]
    let milestones: [String: Double]
    let insights: [String]
}

struct FullAnalysis: Codable {
    let timestamp: String
    let waves: WaveSimulation
    let drops: DropSimulation
    let economy: EconomySimulation
    let threat: ThreatSimulation
    let recommendations: [String]
}

// MARK: - Simulators

func simulateWaves(totalWaves: Int = 20, baseEnemyHP: Double = 20) -> WaveSimulation {
    var waves: [WaveSimulation.WaveData] = []
    var insights: [String] = []

    for w in 1...totalWaves {
        let hpMult = BalanceConfig.waveHealthMultiplier(wave: w)
        let speedMult = BalanceConfig.waveSpeedMultiplier(wave: w)
        let enemyCount = BalanceConfig.Waves.baseEnemyCount + w * BalanceConfig.Waves.enemiesPerWave
        let isBoss = w % BalanceConfig.Waves.bossWaveInterval == 0

        let enemyHP = baseEnemyHP * hpMult * (isBoss ? BalanceConfig.Waves.bossHealthMultiplier : 1.0)
        let totalHP = baseEnemyHP * hpMult * Double(enemyCount)

        waves.append(WaveSimulation.WaveData(
            wave: w,
            enemyHP: enemyHP,
            enemySpeed: speedMult,
            enemyCount: enemyCount,
            totalWaveHP: totalHP,
            isBossWave: isBoss,
            hashReward: w * BalanceConfig.Waves.hashBonusPerWave
        ))
    }

    // Generate insights (handle variable wave counts)
    let totalHashFromWaves = waves.reduce(0) { $0 + $1.hashReward }
    guard let lastWave = waves.last, let firstWave = waves.first else {
        return WaveSimulation(waves: waves, insights: ["ERROR: No waves generated"])
    }
    let growth = lastWave.enemyHP / firstWave.enemyHP

    if growth > 5 {
        insights.append("WARNING: Wave \(totalWaves) enemies have \(String(format: "%.1f", growth))x HP - may feel too spongy")
    } else if growth < 2 && totalWaves >= 10 {
        insights.append("WARNING: Wave \(totalWaves) only \(String(format: "%.1f", growth))x HP - late game may be too easy")
    } else {
        insights.append("OK: Scaling balanced (\(String(format: "%.1f", growth))x at wave \(totalWaves))")
    }

    insights.append("INFO: Total hash from \(totalWaves) waves: \(totalHashFromWaves)")
    let epicCost = BalanceConfig.Towers.placementCosts["epic"] ?? 200
    insights.append("INFO: Can afford \(totalHashFromWaves / epicCost) epic towers")

    return WaveSimulation(waves: waves, insights: insights)
}

func simulateDrops(kills: Int = 1000, difficulty: String = "normal") -> DropSimulation {
    var results = (common: 0, rare: 0, epic: 0, legendary: 0, noDrop: 0)
    var insights: [String] = []
    var killsSinceLastDrop = 0

    let diffMult: Double
    switch difficulty {
    case "easy": diffMult = BalanceConfig.DropRates.easyMultiplier
    case "hard": diffMult = BalanceConfig.DropRates.hardMultiplier
    case "nightmare": diffMult = BalanceConfig.DropRates.nightmareMultiplier
    default: diffMult = BalanceConfig.DropRates.normalMultiplier
    }

    for k in 1...kills {
        killsSinceLastDrop += 1
        let dim = 1.0 / (1.0 + BalanceConfig.DropRates.diminishingFactor * Double(k))

        // Pity check
        if killsSinceLastDrop >= BalanceConfig.DropRates.pityThreshold {
            results.common += 1
            killsSinceLastDrop = 0
            continue
        }

        let roll = Double.random(in: 0..<1)
        var cumulative = 0.0

        // Legendary
        cumulative += BalanceConfig.DropRates.legendary * diffMult * dim
        if roll < cumulative {
            results.legendary += 1
            killsSinceLastDrop = 0
            continue
        }

        // Epic
        cumulative += BalanceConfig.DropRates.epic * diffMult * dim
        if roll < cumulative {
            results.epic += 1
            killsSinceLastDrop = 0
            continue
        }

        // Rare
        cumulative += BalanceConfig.DropRates.rare * diffMult * dim
        if roll < cumulative {
            results.rare += 1
            killsSinceLastDrop = 0
            continue
        }

        // Common
        cumulative += BalanceConfig.DropRates.common * diffMult * dim
        if roll < cumulative {
            results.common += 1
            killsSinceLastDrop = 0
            continue
        }

        results.noDrop += 1
    }

    let totalDrops = results.common + results.rare + results.epic + results.legendary
    let dropRate = Double(totalDrops) / Double(kills) * 100

    // Insights
    insights.append("INFO: Drop rate: \(String(format: "%.1f", dropRate))%")
    insights.append("INFO: Legendary drop rate: \(String(format: "%.2f", Double(results.legendary) / Double(kills) * 100))%")

    if results.legendary == 0 && kills >= 100 {
        insights.append("WARNING: No legendaries in \(kills) kills - rate may be too low")
    }

    if dropRate < 50 {
        insights.append("WARNING: Overall drop rate below 50% - may feel unrewarding")
    }

    return DropSimulation(
        kills: kills,
        difficulty: difficulty,
        results: DropSimulation.DropResult(
            common: results.common,
            rare: results.rare,
            epic: results.epic,
            legendary: results.legendary,
            noDrop: results.noDrop,
            totalDrops: totalDrops,
            dropRate: dropRate
        ),
        insights: insights
    )
}

func simulateEconomy(durationSeconds: Int = 600) -> EconomySimulation {
    var timeline: [EconomySimulation.TimePoint] = []
    var totalHash: Double = 0
    var insights: [String] = []

    for sec in stride(from: 0, through: durationSeconds, by: 30) {
        let minutes = Double(sec) / 60.0
        let rate = BalanceConfig.SurvivalEconomy.hashPerSecond + minutes * BalanceConfig.SurvivalEconomy.hashBonusPerMinute
        totalHash += rate * 30

        timeline.append(EconomySimulation.TimePoint(
            seconds: sec,
            totalHash: Int(totalHash),
            hashRate: rate
        ))
    }

    // Time to afford each rarity
    var timeToAfford: [String: Int] = [:]
    for (rarity, cost) in BalanceConfig.Towers.placementCosts {
        for point in timeline {
            if point.totalHash >= cost {
                timeToAfford[rarity] = point.seconds
                break
            }
        }
    }

    // Insights
    let hash3min = timeline.first(where: { $0.seconds >= 180 })?.totalHash ?? 0
    let hash5min = timeline.first(where: { $0.seconds >= 300 })?.totalHash ?? 0

    insights.append("INFO: Hash at extraction (3min): \(hash3min)")
    insights.append("INFO: Hash at 5min: \(hash5min)")

    if hash3min < BalanceConfig.Towers.placementCosts["rare"]! {
        insights.append("WARNING: Can't afford Rare tower by extraction time")
    }

    if hash5min < BalanceConfig.Towers.placementCosts["epic"]! {
        insights.append("WARNING: Epic towers may be unreachable in typical 5min runs")
    }

    return EconomySimulation(timeline: timeline, timeToAfford: timeToAfford, insights: insights)
}

func simulateThreat(maxThreat: Double = 20, growthRate: Double = 0.1) -> ThreatSimulation {
    var points: [ThreatSimulation.ThreatPoint] = []
    var insights: [String] = []

    for t in stride(from: 1.0, through: maxThreat, by: 1.0) {
        let hpMult = 1.0 + (t - 1.0) * BalanceConfig.ThreatLevel.healthScaling
        let speedMult = 1.0 + (t - 1.0) * BalanceConfig.ThreatLevel.speedScaling
        let damageMult = 1.0 + (t - 1.0) * BalanceConfig.ThreatLevel.damageScaling

        var types = ["basic"]
        if t >= BalanceConfig.ThreatLevel.fastEnemyThreshold { types.append("fast") }
        if t >= BalanceConfig.ThreatLevel.tankEnemyThreshold { types.append("tank") }
        if t >= BalanceConfig.ThreatLevel.bossEnemyThreshold { types.append("boss") }

        points.append(ThreatSimulation.ThreatPoint(
            threat: t,
            hpMultiplier: hpMult,
            speedMultiplier: speedMult,
            damageMultiplier: damageMult,
            availableEnemyTypes: types
        ))
    }

    // Milestones (time in minutes to reach each threshold)
    let milestones: [String: Double] = [
        "fast_unlocks": BalanceConfig.ThreatLevel.fastEnemyThreshold / growthRate / 60,
        "tank_unlocks": BalanceConfig.ThreatLevel.tankEnemyThreshold / growthRate / 60,
        "boss_unlocks": BalanceConfig.ThreatLevel.bossEnemyThreshold / growthRate / 60
    ]

    // Insights
    if milestones["fast_unlocks"]! < 0.5 {
        insights.append("WARNING: Fast enemies appear very quickly - new players may struggle")
    }

    if milestones["boss_unlocks"]! > 10 {
        insights.append("WARNING: Boss enemies take \(String(format: "%.0f", milestones["boss_unlocks"]!)) min - too slow?")
    }

    let hp5min = 1.0 + ((5 * 60 * growthRate) - 1.0) * BalanceConfig.ThreatLevel.healthScaling
    insights.append("INFO: HP multiplier at 5 min: \(String(format: "%.1f", hp5min))x")

    return ThreatSimulation(points: points, milestones: milestones, insights: insights)
}

func runFullAnalysis() -> FullAnalysis {
    let waves = simulateWaves()
    let drops = simulateDrops()
    let economy = simulateEconomy()
    let threat = simulateThreat()

    var recommendations: [String] = []

    // Cross-system analysis
    let hash5min = economy.timeline.first(where: { $0.seconds >= 300 })?.totalHash ?? 0
    let epicCost = BalanceConfig.Towers.placementCosts["epic"]!

    if hash5min < epicCost * 2 {
        recommendations.append("BALANCE: Consider increasing hash rate or reducing epic tower cost")
    }

    if waves.waves[9].enemyHP > 100 && drops.results.dropRate < 70 {
        recommendations.append("BALANCE: Wave 10 HP is high but drop rate is low - players may feel underpowered")
    }

    if threat.milestones["boss_unlocks"]! > 8 {
        recommendations.append("BALANCE: Boss enemies appear late - consider lowering threshold")
    }

    let formatter = ISO8601DateFormatter()

    return FullAnalysis(
        timestamp: formatter.string(from: Date()),
        waves: waves,
        drops: drops,
        economy: economy,
        threat: threat,
        recommendations: recommendations
    )
}

// MARK: - CLI

func printJSON<T: Encodable>(_ value: T) {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    if let data = try? encoder.encode(value),
       let json = String(data: data, encoding: .utf8) {
        print(json)
    }
}

func printHelp() {
    print("""
    Balance Simulator CLI

    Usage: swift main.swift [command] [options]

    Commands:
      waves [count]         Simulate wave progression (default: 20 waves)
      drops [kills] [diff]  Monte Carlo drop simulation (default: 1000 kills, normal)
      economy [seconds]     Economy flow analysis (default: 600 seconds)
      threat [max]          Threat level scaling (default: max 20)
      all                   Run all simulations
      analyze               Full AI-ready analysis (JSON)
      help                  Show this help

    Options:
      --json                Output as JSON (default for analyze)
      --csv                 Output as CSV

    Examples:
      swift main.swift waves 30
      swift main.swift drops 5000 nightmare
      swift main.swift analyze > analysis.json
    """)
}

// Main
let args = CommandLine.arguments

if args.count < 2 {
    printHelp()
    exit(0)
}

let command = args[1]

switch command {
case "waves":
    let count = args.count > 2 ? Int(args[2]) ?? 20 : 20
    let result = simulateWaves(totalWaves: count)
    printJSON(result)

case "drops":
    let kills = args.count > 2 ? Int(args[2]) ?? 1000 : 1000
    let diff = args.count > 3 ? args[3] : "normal"
    let result = simulateDrops(kills: kills, difficulty: diff)
    printJSON(result)

case "economy":
    let duration = args.count > 2 ? Int(args[2]) ?? 600 : 600
    let result = simulateEconomy(durationSeconds: duration)
    printJSON(result)

case "threat":
    let maxThreat = args.count > 2 ? Double(args[2]) ?? 20 : 20
    let result = simulateThreat(maxThreat: maxThreat)
    printJSON(result)

case "all":
    print("=== Wave Simulation ===")
    printJSON(simulateWaves())
    print("\n=== Drop Simulation ===")
    printJSON(simulateDrops())
    print("\n=== Economy Simulation ===")
    printJSON(simulateEconomy())
    print("\n=== Threat Simulation ===")
    printJSON(simulateThreat())

case "analyze":
    let analysis = runFullAnalysis()
    printJSON(analysis)

case "help", "--help", "-h":
    printHelp()

default:
    print("Unknown command: \(command)")
    printHelp()
    exit(1)
}
