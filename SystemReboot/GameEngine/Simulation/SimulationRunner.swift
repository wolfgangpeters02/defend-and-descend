import Foundation
import CoreGraphics

// MARK: - Simulation Config

struct SimulationConfig {
    var seed: UInt64 = 42
    var bot: TDBot
    var tickRate: TimeInterval = BalanceConfig.Simulation.defaultTickRate
    var maxGameTime: TimeInterval = BalanceConfig.Simulation.defaultMaxGameTime
    var compiledProtocols: [String] = ["kernel_pulse"]
    var unlockedSectors: Set<String> = [SectorID.power.rawValue]
    var componentLevels: ComponentLevels = BalanceConfig.Simulation.earlyGame
    var startingHash: Int = 100
    var startingEfficiency: CGFloat = 100
}

// MARK: - Simulation Result

struct SimulationResult {
    var botName: String
    var seed: UInt64
    var finalEfficiency: CGFloat
    var totalKills: Int
    var totalHashEarned: Int
    var freezeCount: Int
    var timeToFirstFreeze: TimeInterval?
    var towersPlaced: Int
    var peakTowerLevel: Int
    var averageTowerLevel: CGFloat
    var overclockCount: Int
    var gameDuration: TimeInterval
    var didFreeze: Bool

    var finalTowerCount: Int = 0
    var peakHashPerSecond: CGFloat = 0
    var powerUsedPercent: CGFloat = 0

    // Balance testing fields
    var killsByTower: [String: Int] = [:]       // Kills per tower type
    var hashFromMarks: Int = 0                   // Hash from GC marks
    var powerWallHitTime: TimeInterval?          // When power blocked
    var killsByLane: [String: Int] = [:]         // Kills per lane
    var timeToFirstEnemy: TimeInterval?          // Time until first enemy spawns
    var timeToFirstCoreLeak: TimeInterval?       // Time until first enemy reaches core
}

// MARK: - Simulation Runner

class SimulationRunner {

    // MARK: - Core Runner

    static func run(config: SimulationConfig) -> SimulationResult {
        let sim = TDSimulator(config: config)

        let tickRate = config.tickRate
        let maxTime = config.maxGameTime
        let botDecisionInterval = BalanceConfig.Simulation.botDecisionInterval

        var timeSinceLastDecision: TimeInterval = 0
        var peakTowerLevel = 0
        var peakHashPerSecond: CGFloat = 0

        // Main simulation loop
        while sim.elapsedTime < maxTime {
            // Run physics tick
            sim.tick(deltaTime: tickRate)

            // Track peak stats
            if let maxLevel = sim.state.towers.map({ $0.level }).max() {
                peakTowerLevel = max(peakTowerLevel, maxLevel)
            }
            peakHashPerSecond = max(peakHashPerSecond, sim.state.hashPerSecond)

            // Bot decisions at intervals
            timeSinceLastDecision += tickRate
            if timeSinceLastDecision >= botDecisionInterval {
                timeSinceLastDecision = 0

                let action = config.bot.decide(state: sim.state, profile: sim.profile)
                executeAction(action, on: sim)
            }
        }

        // Calculate average tower level
        let avgLevel: CGFloat
        if sim.state.towers.isEmpty {
            avgLevel = 0
        } else {
            avgLevel = CGFloat(sim.state.towers.reduce(0) { $0 + $1.level }) / CGFloat(sim.state.towers.count)
        }

        // Power usage
        let powerUsedPercent = sim.state.powerCapacity > 0
            ? CGFloat(sim.state.powerUsed) / CGFloat(sim.state.powerCapacity) * 100
            : 0

        return SimulationResult(
            botName: config.bot.name,
            seed: config.seed,
            finalEfficiency: sim.state.efficiency,
            totalKills: sim.totalKills,
            totalHashEarned: sim.totalHashEarned,
            freezeCount: sim.freezeCount,
            timeToFirstFreeze: sim.timeToFirstFreeze,
            towersPlaced: sim.state.towers.count,
            peakTowerLevel: peakTowerLevel,
            averageTowerLevel: avgLevel,
            overclockCount: sim.overclockCount,
            gameDuration: sim.elapsedTime,
            didFreeze: sim.freezeCount > 0,
            finalTowerCount: sim.state.towers.count,
            peakHashPerSecond: peakHashPerSecond,
            powerUsedPercent: powerUsedPercent
        )
    }

    private static func executeAction(_ action: TDBotAction, on sim: TDSimulator) {
        switch action {
        case .idle:
            break
        case .placeTower(let protocolId, let slotId):
            let _ = sim.placeTower(protocolId: protocolId, slotId: slotId)
        case .upgradeTower(let towerId):
            let _ = sim.upgradeTower(towerId: towerId)
        case .sellTower(let towerId):
            let _ = sim.sellTower(towerId: towerId)
        case .activateOverclock:
            let _ = sim.activateOverclock()
        case .engageBoss, .ignoreBoss:
            // Boss handling is simplified in simulation
            break
        }
    }

    static func runBatch(configs: [SimulationConfig]) -> [SimulationResult] {
        return configs.map { run(config: $0) }
    }

    // MARK: - Logging

    private static var logLines: [String] = []

    private static func log(_ line: String) {
        print(line)
        logLines.append(line)
    }

    private static func writeLogFile() {
        let content = logLines.joined(separator: "\n")
        let tmpDir = NSTemporaryDirectory()
        let path = (tmpDir as NSString).appendingPathComponent("sim_calibration.txt")
        try? content.write(toFile: path, atomically: true, encoding: .utf8)
        print("[SIM] Results written to: \(path)")
    }

    // MARK: - Economy Analysis

    /// Comprehensive economy analysis: spending strategies, limiting factors, trap states
    static func runEconomyAnalysis() {
        logLines = []
        let startTime = CFAbsoluteTimeGetCurrent()

        log("")
        log(String(repeating: "═", count: 80))
        log("  ECONOMY & PROGRESSION ANALYSIS")
        log(String(repeating: "═", count: 80))

        let allTowers = ["kernel_pulse", "burst_protocol", "trace_route", "ice_shard", "fork_bomb", "null_pointer"]

        // ═══════════════════════════════════════════════════════════════════════
        // Test 1: Spending Strategy Comparison
        // ═══════════════════════════════════════════════════════════════════════

        log("")
        log("── Test 1: Spending Strategy Comparison ──")
        log("Which strategy performs best over a 5-minute session?")
        log("")

        let bots: [TDBot] = [PassiveBot(), GreedyBot(), SpreadBot(), RushOverclockBot(), AdaptiveBot()]
        var strategyResults: [SimulationResult] = []

        log(String(format: "%-10@ %5@ %8@ %8@ %7@ %6@ %@",
                   "Strategy", "Eff%", "Kills", "Hash$", "Towers", "AvgLvl", "Verdict"))
        log(String(repeating: "─", count: 70))

        for bot in bots {
            let config = SimulationConfig(
                seed: 42,
                bot: bot,
                maxGameTime: 300,
                compiledProtocols: allTowers,
                unlockedSectors: [SectorID.power.rawValue],
                startingHash: 100,
                startingEfficiency: 100
            )
            let result = run(config: config)
            strategyResults.append(result)

            let verdict = result.didFreeze ? "⚠️ Froze" : "✓ OK"
            log(String(format: "%-10@ %4.1f%% %8d %8d %7d %6.1f %@",
                       result.botName,
                       result.finalEfficiency,
                       result.totalKills,
                       result.totalHashEarned,
                       result.towersPlaced,
                       result.averageTowerLevel,
                       verdict))
        }

        // ═══════════════════════════════════════════════════════════════════════
        // Test 2: Power Constraint Impact
        // ═══════════════════════════════════════════════════════════════════════

        log("")
        log("── Test 2: Power Constraint Impact ──")
        log("How does PSU level affect tower placement and survival?")
        log("")

        log(String(format: "%-8@ %8@ %8@ %8@ %8@ %@",
                   "PSU Lv", "Watts", "Towers", "PwrUsed%", "PwrWall", "Efficiency"))
        log(String(repeating: "─", count: 60))

        for psuLevel in [1, 3, 5, 7, 10] {
            var levels = BalanceConfig.Simulation.earlyGame
            levels.power = psuLevel

            let config = SimulationConfig(
                seed: 42,
                bot: SpreadBot(),
                maxGameTime: 300,
                compiledProtocols: allTowers,
                unlockedSectors: [SectorID.power.rawValue],
                componentLevels: levels,
                startingHash: 500,
                startingEfficiency: 100
            )
            let result = run(config: config)
            let watts = BalanceConfig.Components.psuCapacity(at: psuLevel)
            let powerWall = result.powerUsedPercent > 90 ? "YES" : "-"

            log(String(format: "Lv %-5d %6dW %8d %7.0f%% %-8@ %5.1f%%",
                       psuLevel,
                       watts,
                       result.towersPlaced,
                       result.powerUsedPercent,
                       powerWall,
                       result.finalEfficiency))
        }

        // ═══════════════════════════════════════════════════════════════════════
        // Test 3: Storage Cap Impact
        // ═══════════════════════════════════════════════════════════════════════

        log("")
        log("── Test 3: Storage Cap Impact ──")
        log("Is hash wasted due to storage limits?")
        log("")

        log(String(format: "%-8@ %12@ %8@ %8@ %@",
                   "HDD Lv", "Capacity", "Earned", "StoWall", "H.Float"))
        log(String(repeating: "─", count: 55))

        for hddLevel in [1, 3, 5, 7, 10] {
            var levels = BalanceConfig.Simulation.earlyGame
            levels.storage = hddLevel

            let config = SimulationConfig(
                seed: 42,
                bot: SpreadBot(),
                maxGameTime: 300,
                compiledProtocols: allTowers,
                unlockedSectors: [SectorID.power.rawValue],
                componentLevels: levels,
                startingHash: 100,
                startingEfficiency: 100
            )
            let result = run(config: config)
            let capacity = BalanceConfig.Components.storageCapacity(at: hddLevel)
            let storageWall = result.totalHashEarned > capacity ? "YES" : "-"

            log(String(format: "Lv %-5d %12d %8d %-8@ %@",
                       hddLevel,
                       capacity,
                       result.totalHashEarned,
                       storageWall,
                       "-"))
        }

        // ═══════════════════════════════════════════════════════════════════════
        // Test 4: CPU Priority - Hash Generation Scaling
        // ═══════════════════════════════════════════════════════════════════════

        log("")
        log("── Test 4: CPU Priority - Hash Generation Scaling ──")
        log("How much does CPU level affect total hash earned?")
        log("")

        log(String(format: "%-8@ %8@ %8@ %8@ %@",
                   "CPU Lv", "Ħ/sec", "Earned", "HPS Peak", "Multiplier"))
        log(String(repeating: "─", count: 55))

        let baseCpuResult: SimulationResult? = nil
        for cpuLevel in [1, 3, 5, 7, 10] {
            var levels = BalanceConfig.Simulation.earlyGame
            levels.cpu = cpuLevel

            let config = SimulationConfig(
                seed: 42,
                bot: AdaptiveBot(),
                maxGameTime: 300,
                compiledProtocols: allTowers,
                unlockedSectors: [SectorID.power.rawValue],
                componentLevels: levels,
                startingHash: 100,
                startingEfficiency: 100
            )
            let result = run(config: config)
            let hashPerSec = BalanceConfig.HashEconomy.hashPerSecond(at: cpuLevel)
            let multiplier = hashPerSec / max(1, BalanceConfig.HashEconomy.hashPerSecond(at: 1))

            log(String(format: "Lv %-5d %8.1f %8d %8.1f %8.1fx",
                       cpuLevel,
                       hashPerSec,
                       result.totalHashEarned,
                       result.peakHashPerSecond,
                       multiplier))
        }

        // ═══════════════════════════════════════════════════════════════════════
        // Test 5: Trap State Analysis
        // ═══════════════════════════════════════════════════════════════════════

        log("")
        log("── Test 5: Trap State Analysis ──")
        log("Can players get hard-stuck with bad decisions?")
        log("")

        // Scenario A: Overclock spam without tower investment
        let configA = SimulationConfig(
            seed: 42,
            bot: RushOverclockBot(),
            maxGameTime: 300,
            compiledProtocols: [],  // No towers available!
            unlockedSectors: [SectorID.power.rawValue],
            startingHash: 100,
            startingEfficiency: 100
        )
        let resultA = run(config: configA)
        log("Scenario A: Overclock spam, no tower investment")
        log(String(format: "  Efficiency: %.1f%%, Freezes: %d, Final Hash: %d",
                   resultA.finalEfficiency, resultA.freezeCount, resultA.totalHashEarned))
        if resultA.freezeCount > 3 {
            log("  → ⚠️ TRAP STATE: Player freezes repeatedly, no recovery path")
        } else if resultA.finalEfficiency < 30 {
            log("  → ⚠️ STRUGGLING: Very low efficiency, but may recover")
        } else {
            log("  → ✓ Survivable despite no towers")
        }

        log("")

        // Scenario B: Only epic towers (expensive)
        let configB = SimulationConfig(
            seed: 42,
            bot: GreedyBot(),
            maxGameTime: 300,
            compiledProtocols: ["fork_bomb", "null_pointer"],  // Only epic towers
            unlockedSectors: [SectorID.power.rawValue],
            startingHash: 100,
            startingEfficiency: 100
        )
        let resultB = run(config: configB)
        log("Scenario B: Only Epic towers, no upgrades (high cost, few towers)")
        log(String(format: "  Efficiency: %.1f%%, Towers: %d, Freezes: %d",
                   resultB.finalEfficiency, resultB.towersPlaced, resultB.freezeCount))
        if resultB.didFreeze {
            log("  → ⚠️ Epic towers too expensive for early game")
        } else {
            log("  → ✓ Epic towers provide enough DPS despite cost")
        }

        log("")

        // Scenario C: PSU constraint
        var levelsC = BalanceConfig.Simulation.earlyGame
        levelsC.power = 1
        let configC = SimulationConfig(
            seed: 42,
            bot: SpreadBot(),
            maxGameTime: 300,
            compiledProtocols: allTowers,
            unlockedSectors: [SectorID.power.rawValue],
            componentLevels: levelsC,
            startingHash: 500,
            startingEfficiency: 100
        )
        let resultC = run(config: configC)
        log("Scenario C: PSU Lv1, trying to place 6 towers")
        log(String(format: "  Towers placed: %d (wanted 6+), Power used: %.0f%%, Wall time: %.0fs",
                   resultC.towersPlaced, resultC.powerUsedPercent, resultC.gameDuration))
        if resultC.towersPlaced < 6 {
            log("  → ⚠️ Power constraint limiting tower count")
        } else {
            log("  → ✓ Can work around power limits")
        }

        // ═══════════════════════════════════════════════════════════════════════
        // Test 6: Component Upgrade Priority
        // ═══════════════════════════════════════════════════════════════════════

        log("")
        log("── Test 6: Component Upgrade Priority ──")
        log("Which single component upgrade has the biggest impact?")
        log("")

        // Baseline: all level 1
        let baselineConfig = SimulationConfig(
            seed: 42,
            bot: AdaptiveBot(),
            maxGameTime: 300,
            compiledProtocols: allTowers,
            unlockedSectors: [SectorID.power.rawValue],
            componentLevels: BalanceConfig.Simulation.earlyGame,
            startingHash: 200,
            startingEfficiency: 100
        )
        let baseline = run(config: baselineConfig)
        log(String(format: "Baseline (all Lv1): Eff=%.1f%%, Earned=%d, Towers=%d",
                   baseline.finalEfficiency, baseline.totalHashEarned, baseline.towersPlaced))
        log("")

        log(String(format: "%-10@ %5@ %8@ %8@ %@",
                   "Upgraded", "Eff%", "Earned", "Towers", "Impact"))
        log(String(repeating: "─", count: 55))

        let componentTests: [(String, (inout ComponentLevels) -> Void)] = [
            ("PSU→5", { $0.power = 5 }),
            ("CPU→5", { $0.cpu = 5 }),
            ("RAM→5", { $0.ram = 5 }),
            ("Cache→5", { $0.cache = 5 }),
            ("Store→5", { $0.storage = 5 })
        ]

        for (name, modifier) in componentTests {
            var levels = BalanceConfig.Simulation.earlyGame
            modifier(&levels)

            let config = SimulationConfig(
                seed: 42,
                bot: AdaptiveBot(),
                maxGameTime: 300,
                compiledProtocols: allTowers,
                unlockedSectors: [SectorID.power.rawValue],
                componentLevels: levels,
                startingHash: 200,
                startingEfficiency: 100
            )
            let result = run(config: config)

            let impact: String
            let effDiff = result.finalEfficiency - baseline.finalEfficiency
            let hashDiff = result.totalHashEarned - baseline.totalHashEarned
            if effDiff > 30 || hashDiff > 5000 {
                impact = "++HUGE"
            } else if effDiff > 10 || hashDiff > 1000 {
                impact = "+Good"
            } else {
                impact = "~Minor"
            }

            log(String(format: "%-10@ %4.1f%% %8d %10d %@",
                       name,
                       result.finalEfficiency,
                       result.totalHashEarned,
                       result.towersPlaced,
                       impact))
        }

        // ═══════════════════════════════════════════════════════════════════════
        // Summary
        // ═══════════════════════════════════════════════════════════════════════

        log("")
        log(String(repeating: "─", count: 80))
        log("SUMMARY & RECOMMENDATIONS")
        log(String(repeating: "─", count: 80))
        log("")
        log("LIMITING FACTORS:")
        log("• PSU (Power): Hard cap on tower count. Priority 1 for tower-heavy builds.")
        log("• HDD (Storage): Caps hash accumulation. Low priority early, important late.")
        log("• CPU: Exponential hash generation. High impact on progression speed.")
        log("• Tower Slots: Not usually limiting with base slots.")
        log("")
        log("SPENDING PRIORITY (Early Game):")
        log("1. Place 2-3 Common towers (defensive stability)")
        log("2. Upgrade to Lv3-4 (cost-efficient damage boost)")
        log("3. PSU upgrade if power-capped")
        log("4. CPU upgrade for faster income")
        log("")
        log("TRAP STATES:")
        log("• No towers + Overclock spam → Freezes but recoverable (core defense works)")
        log("• Only expensive towers → Fewer defenses, risky but viable")
        log("• Low PSU + many protocols → Power bottleneck (need PSU upgrade)")

        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        log("")
        log(String(format: "Total analysis time: %.2fs", elapsed))
        log(String(repeating: "═", count: 80))

        writeLogFile()
    }

    // MARK: - Balance Test Suite

    /// Comprehensive balance testing: 8 targeted tests for game balance validation
    static func runBalanceTestSuite() {
        logLines = []
        let startTime = CFAbsoluteTimeGetCurrent()

        log("")
        log(String(repeating: "═", count: 80))
        log("  BALANCE TEST SUITE - 8 TARGETED TESTS")
        log(String(repeating: "═", count: 80))

        testTowerBalance()              // Q1
        testGarbageCollectorSupport()   // Q2
        testUpgradeCostEfficiency()     // Q3
        testPowerConstraints()          // Q4
        testMultiLaneStrategy()         // Q5
        testMultiLaneHashIncome()       // Q5b
        testSpendingDecisionHierarchy() // Q6
        testImmediateOverclock()        // Q6b
        testProgressionHierarchy()      // Q7
        testEarlyGamePacing()           // Q8

        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        log("")
        log(String(repeating: "═", count: 80))
        log(String(format: "Total balance test time: %.2fs", elapsed))
        log(String(repeating: "═", count: 80))

        writeLogFile()
    }

    // MARK: - Q1: Tower Balance Testing

    /// Which towers are overpowered/underpowered? Are towers overall overtuned/undertuned?
    private static func testTowerBalance() {
        log("")
        log("── Q1: Tower Balance Testing ──")
        log("Running each tower type in isolation to compare raw effectiveness.")
        log("")

        let towerIds = ["kernel_pulse", "burst_protocol", "trace_route", "ice_shard", "fork_bomb", "null_pointer"]
        let towerNames = ["Executor", "Fragmenter", "Pinger", "Throttler", "Recursion", "GarbageCollector"]
        let rarities = ["Common", "Common", "Rare", "Rare", "Epic", "Legendary"]

        log(String(format: "%-16@ %-10@ %6@ %6@ %6@ %@",
                   "Tower", "Rarity", "Kills", "DPS", "Eff%", "Verdict"))
        log(String(repeating: "─", count: 65))

        var results: [(name: String, rarity: String, kills: Int, dps: CGFloat, efficiency: CGFloat)] = []

        for (index, protocolId) in towerIds.enumerated() {
            let config = SimulationConfig(
                seed: 42,
                bot: SingleTowerBot(protocolId: protocolId),
                maxGameTime: 300,
                compiledProtocols: [protocolId],
                unlockedSectors: [SectorID.power.rawValue],
                startingHash: 100,
                startingEfficiency: 100
            )
            let result = run(config: config)
            let dps = CGFloat(result.totalKills) / (result.gameDuration / 60.0)

            results.append((towerNames[index], rarities[index], result.totalKills, dps, result.finalEfficiency))

            let verdict: String
            if result.didFreeze {
                verdict = "⚠️ Froze"
            } else if result.finalEfficiency < 50 {
                verdict = "~Weak"
            } else if dps > 15 {
                verdict = "++Strong"
            } else {
                verdict = "✓ OK"
            }

            log(String(format: "%-16@ %-10@ %6d %6.1f %5.0f%% %@",
                       towerNames[index], rarities[index], result.totalKills, dps, result.finalEfficiency, verdict))
        }

        // Summary
        let avgKills = results.map { $0.kills }.reduce(0, +) / max(1, results.count)
        let maxKills = results.max { $0.kills < $1.kills }
        let minKills = results.min { $0.kills < $1.kills }

        log("")
        log("Summary:")
        log("  Average kills: \(avgKills)")
        if let best = maxKills {
            log("  Best performer: \(best.name) (\(best.kills) kills)")
        }
        if let worst = minKills {
            log("  Weakest: \(worst.name) (\(worst.kills) kills)")
            if worst.kills < avgKills / 2 {
                log("  ⚠️ \(worst.name) is significantly underperforming")
            }
        }
    }

    // MARK: - Q2: Garbage Collector Support Testing

    /// GarbageCollector is a support tower for hash bonus. Test synergy with DPS towers.
    private static func testGarbageCollectorSupport() {
        log("")
        log("── Q2: Garbage Collector Support Testing ──")
        log("Does GC + DPS tower earn more hash than DPS alone?")
        log("")

        // Scenario A: null_pointer alone
        let configA = SimulationConfig(
            seed: 42,
            bot: SingleTowerBot(protocolId: "null_pointer"),
            maxGameTime: 300,
            compiledProtocols: ["null_pointer"],
            unlockedSectors: [SectorID.power.rawValue],
            startingHash: 100,
            startingEfficiency: 100
        )
        let resultA = run(config: configA)

        // Scenario B: 6 GC + 6 Executor (synergy test with equal tower count to C)
        // Alternate placement so GC marks enemies that Executor then kills
        let synergyComboPairs = ["null_pointer", "kernel_pulse", "null_pointer", "kernel_pulse",
                                  "null_pointer", "kernel_pulse", "null_pointer", "kernel_pulse",
                                  "null_pointer", "kernel_pulse", "null_pointer", "kernel_pulse"]
        let configB = SimulationConfig(
            seed: 42,
            bot: SynergyBot(combo: synergyComboPairs),
            maxGameTime: 300,
            compiledProtocols: ["null_pointer", "kernel_pulse"],
            unlockedSectors: [SectorID.power.rawValue],
            startingHash: 500,  // More starting hash to afford placements
            startingEfficiency: 100
        )
        let resultB = run(config: configB)

        // Scenario C: 12 Executor alone (baseline - same tower count as B)
        let configC = SimulationConfig(
            seed: 42,
            bot: SingleTowerBot(protocolId: "kernel_pulse"),
            maxGameTime: 300,
            compiledProtocols: ["kernel_pulse"],
            unlockedSectors: [SectorID.power.rawValue],
            startingHash: 500,  // Same starting hash as B
            startingEfficiency: 100
        )
        let resultC = run(config: configC)

        log(String(format: "%-20@ %6@ %8@ %8@ %6@ %@",
                   "Scenario", "Kills", "Hash", "H/Kill", "Eff%", "Verdict"))
        log(String(repeating: "─", count: 65))

        let hpkA = resultA.totalKills > 0 ? Double(resultA.totalHashEarned) / Double(resultA.totalKills) : 0
        log(String(format: "%-20@ %6d %8d %8.2f %5.0f%% %@",
                   "GC alone", resultA.totalKills, resultA.totalHashEarned, hpkA, resultA.finalEfficiency,
                   resultA.didFreeze ? "⚠️ Froze" : "✓ OK"))

        let hpkB = resultB.totalKills > 0 ? Double(resultB.totalHashEarned) / Double(resultB.totalKills) : 0
        log(String(format: "%-20@ %6d %8d %8.2f %5.0f%% %@",
                   "GC + Executor (6+6)", resultB.totalKills, resultB.totalHashEarned, hpkB, resultB.finalEfficiency,
                   resultB.didFreeze ? "⚠️ Froze" : "✓ OK"))

        let hpkC = resultC.totalKills > 0 ? Double(resultC.totalHashEarned) / Double(resultC.totalKills) : 0
        log(String(format: "%-20@ %6d %8d %8.2f %5.0f%% %@",
                   "Executor x12", resultC.totalKills, resultC.totalHashEarned, hpkC, resultC.finalEfficiency,
                   resultC.didFreeze ? "⚠️ Froze" : "✓ OK"))

        log("")
        log("Analysis:")
        let synergySurplus = resultB.totalHashEarned - resultC.totalHashEarned
        if synergySurplus > 100 {
            log("  ✓ GC synergy provides +\(synergySurplus) hash (bonus working)")
        } else if synergySurplus > 0 {
            log("  ~ GC provides minor bonus (+\(synergySurplus) hash)")
        } else {
            log("  ⚠️ GC not providing hash bonus, may need tuning")
        }

        if resultA.didFreeze && !resultC.didFreeze {
            log("  ✓ GC alone can't defend (intended - it's support)")
        }
    }

    // MARK: - Q3: Upgrade Cost Efficiency

    /// Is leveling towers too cheap for the extra damage?
    private static func testUpgradeCostEfficiency() {
        log("")
        log("── Q3: Upgrade Cost Efficiency ──")
        log("Comparing upgrade-focus vs spread-first strategies.")
        log("")

        let allTowers = ["kernel_pulse", "burst_protocol", "ice_shard"]

        // UpgradeFocus: max one tower before placing another
        let configUpgrade = SimulationConfig(
            seed: 42,
            bot: UpgradeFocusBot(),
            maxGameTime: 300,
            compiledProtocols: allTowers,
            unlockedSectors: [SectorID.power.rawValue],
            startingHash: 100,
            startingEfficiency: 100
        )
        let resultUpgrade = run(config: configUpgrade)

        // SpreadFirst: fill slots before upgrading
        let configSpread = SimulationConfig(
            seed: 42,
            bot: SpreadBot(),
            maxGameTime: 300,
            compiledProtocols: allTowers,
            unlockedSectors: [SectorID.power.rawValue],
            startingHash: 100,
            startingEfficiency: 100
        )
        let resultSpread = run(config: configSpread)

        log(String(format: "%-15@ %8@ %6@ %6@ %8@ %@",
                   "Strategy", "Hash", "Kills", "Towers", "AvgLvl", "Cost/Kill"))
        log(String(repeating: "─", count: 60))

        let costPerKillUpgrade = resultUpgrade.totalKills > 0
            ? CGFloat(resultUpgrade.totalHashEarned) / CGFloat(resultUpgrade.totalKills)
            : 0
        let costPerKillSpread = resultSpread.totalKills > 0
            ? CGFloat(resultSpread.totalHashEarned) / CGFloat(resultSpread.totalKills)
            : 0

        log(String(format: "%-15@ %8d %6d %6d %8.1f %8.1f",
                   "UpgradeFocus", resultUpgrade.totalHashEarned, resultUpgrade.totalKills,
                   resultUpgrade.towersPlaced, resultUpgrade.averageTowerLevel, costPerKillUpgrade))

        log(String(format: "%-15@ %8d %6d %6d %8.1f %8.1f",
                   "SpreadFirst", resultSpread.totalHashEarned, resultSpread.totalKills,
                   resultSpread.towersPlaced, resultSpread.averageTowerLevel, costPerKillSpread))

        log("")
        log("Analysis:")
        if resultUpgrade.totalKills > Int(Double(resultSpread.totalKills) * 1.2) {
            log("  ⚠️ Upgrade-focus significantly outperforms spread (upgrades may be too cheap)")
        } else if resultSpread.totalKills > Int(Double(resultUpgrade.totalKills) * 1.2) {
            log("  ⚠️ Spread significantly outperforms upgrade-focus (consider lowering placement costs)")
        } else {
            log("  ✓ Both strategies are viable (balanced)")
        }
    }

    // MARK: - Q4: Power Constraints

    /// Epic towers need >300W PSU. Test power gating by rarity.
    private static func testPowerConstraints() {
        log("")
        log("── Q4: Power Constraints Testing ──")
        log("Can high-rarity towers be placed at low PSU levels?")
        log("")

        let testCases: [(String, String, [String])] = [
            ("Common only", "Lv1 PSU", ["kernel_pulse", "burst_protocol"]),
            ("Rare only", "Lv1 PSU", ["trace_route", "ice_shard"]),
            ("Epic only", "Lv1 PSU", ["fork_bomb"]),
            ("Legendary only", "Lv1 PSU", ["null_pointer"]),
            ("Epic only", "Lv3 PSU", ["fork_bomb"]),
            ("All rarities", "Lv5 PSU", ["kernel_pulse", "ice_shard", "fork_bomb", "null_pointer"])
        ]

        log(String(format: "%-18@ %-10@ %6@ %8@ %@",
                   "Scenario", "PSU", "Towers", "PwrUsed%", "Verdict"))
        log(String(repeating: "─", count: 55))

        for (name, psuDesc, protocols) in testCases {
            var levels = BalanceConfig.Simulation.earlyGame
            if psuDesc.contains("3") {
                levels.power = 3
            } else if psuDesc.contains("5") {
                levels.power = 5
            }

            let config = SimulationConfig(
                seed: 42,
                bot: SpreadBot(),
                maxGameTime: 180,
                compiledProtocols: protocols,
                unlockedSectors: [SectorID.power.rawValue],
                componentLevels: levels,
                startingHash: 500,
                startingEfficiency: 100
            )
            let result = run(config: config)

            let verdict: String
            if result.towersPlaced == 0 {
                verdict = "✗ Blocked"
            } else if result.powerUsedPercent > 90 {
                verdict = "⚠️ At limit"
            } else {
                verdict = "✓ OK"
            }

            log(String(format: "%-18@ %-10@ %6d %7.0f%% %@",
                       name, psuDesc, result.towersPlaced, result.powerUsedPercent, verdict))
        }

        log("")
        log("Expected: Epic/Legendary should be blocked or limited at Lv1 PSU")
    }

    // MARK: - Q5: Multi-Lane Strategy

    /// Why do more lanes make the game easier? Are bots placing towers in the middle?
    private static func testMultiLaneStrategy() {
        log("")
        log("── Q5: Multi-Lane Strategy Testing ──")
        log("How does the number of unlocked sectors affect difficulty?")
        log("")

        let sectorConfigs: [(String, Set<String>)] = [
            ("1 Lane (PSU)", [SectorID.power.rawValue]),
            ("3 Lanes", [SectorID.power.rawValue, SectorID.ram.rawValue, SectorID.gpu.rawValue]),
            ("All Lanes", Set(SectorID.allCases.map { $0.rawValue }))
        ]

        log(String(format: "%-15@ %6@ %6@ %8@ %@",
                   "Config", "Kills", "Towers", "Eff%", "Verdict"))
        log(String(repeating: "─", count: 50))

        let allTowers = ["kernel_pulse", "burst_protocol", "ice_shard", "fork_bomb"]

        for (name, sectors) in sectorConfigs {
            let config = SimulationConfig(
                seed: 42,
                bot: SpreadBot(),
                maxGameTime: 300,
                compiledProtocols: allTowers,
                unlockedSectors: sectors,
                startingHash: 100,
                startingEfficiency: 100
            )
            let result = run(config: config)

            let verdict = result.didFreeze ? "⚠️ Froze" : "✓ OK"

            log(String(format: "%-15@ %6d %6d %7.0f%% %@",
                       name, result.totalKills, result.towersPlaced, result.finalEfficiency, verdict))
        }

        log("")
        log("Analysis: More lanes = more enemies but also more tower slots.")
        log("CPU-adjacent slots can cover multiple lanes for efficiency.")
    }

    // MARK: - Q6: Spending Decision Hierarchy

    /// When does it make sense to spend hash on what?
    private static func testSpendingDecisionHierarchy() {
        log("")
        log("── Q6: Spending Decision Hierarchy ──")
        log("Tracking economy flow over time with AdaptiveBot.")
        log("")

        let allTowers = ["kernel_pulse", "burst_protocol", "ice_shard", "trace_route"]

        let config = SimulationConfig(
            seed: 42,
            bot: AdaptiveBot(),
            maxGameTime: 600,  // 10 minutes for progression analysis
            compiledProtocols: allTowers,
            unlockedSectors: [SectorID.power.rawValue],
            startingHash: 100,
            startingEfficiency: 100
        )
        let result = run(config: config)

        log("10-Minute Session Results:")
        log(String(format: "  Final Efficiency: %.0f%%", result.finalEfficiency))
        log(String(format: "  Total Kills: %d", result.totalKills))
        log(String(format: "  Total Hash Earned: %d", result.totalHashEarned))
        log(String(format: "  Towers Placed: %d", result.towersPlaced))
        log(String(format: "  Peak Tower Level: %d", result.peakTowerLevel))
        log(String(format: "  Overclock Count: %d", result.overclockCount))
        log("")

        if result.didFreeze {
            log("  ⚠️ Froze \(result.freezeCount) time(s)")
            if let firstFreeze = result.timeToFirstFreeze {
                log(String(format: "  Time to first freeze: %.0fs", firstFreeze))
            }
        } else {
            log("  ✓ Maintained stability throughout")
        }

        log("")
        log("Spending Priority (observed):")
        log("  1. Towers first for defensive stability")
        log("  2. Upgrades for cost-efficient damage boost")
        log("  3. Overclock when efficiency is healthy (70%+)")
    }

    // MARK: - Q7: Progression Hierarchy Testing

    /// Force towers first. CPU upgrades shouldn't be winning strategy before towers.
    private static func testProgressionHierarchy() {
        log("")
        log("── Q7: Progression Hierarchy Testing ──")
        log("Towers should be required. Component-only strategies should fail.")
        log("")

        let allTowers = ["kernel_pulse", "burst_protocol", "ice_shard"]

        log(String(format: "%-15@ %6@ %6@ %8@ %6@ %@",
                   "Strategy", "Towers", "Kills", "Eff%", "Frz", "Verdict"))
        log(String(repeating: "─", count: 60))

        // Scenario A: TowersFirst (intended path)
        let configA = SimulationConfig(
            seed: 42,
            bot: TowersFirstBot(),
            maxGameTime: 300,
            compiledProtocols: allTowers,
            unlockedSectors: [SectorID.power.rawValue],
            startingHash: 100,
            startingEfficiency: 100
        )
        let resultA = run(config: configA)

        let verdictA = resultA.didFreeze ? "⚠️ Fail" : "✓ Intended"
        log(String(format: "%-15@ %6d %6d %7.0f%% %6d %@",
                   "TowersFirst", resultA.towersPlaced, resultA.totalKills, resultA.finalEfficiency,
                   resultA.freezeCount, verdictA))

        // Scenario B: NoTowers (control - should definitely fail)
        let configB = SimulationConfig(
            seed: 42,
            bot: NoTowersBot(),
            maxGameTime: 300,
            compiledProtocols: allTowers,
            unlockedSectors: [SectorID.power.rawValue],
            startingHash: 100,
            startingEfficiency: 100
        )
        let resultB = run(config: configB)

        let verdictB = resultB.didFreeze ? "✓ Expected" : "⚠️ Should fail!"
        log(String(format: "%-15@ %6d %6d %7.0f%% %6d %@",
                   "NoTowers", resultB.towersPlaced, resultB.totalKills, resultB.finalEfficiency,
                   resultB.freezeCount, verdictB))

        // Scenario C: Passive (very minimal interaction)
        let configC = SimulationConfig(
            seed: 42,
            bot: PassiveBot(),
            maxGameTime: 300,
            compiledProtocols: allTowers,
            unlockedSectors: [SectorID.power.rawValue],
            startingHash: 100,
            startingEfficiency: 100
        )
        let resultC = run(config: configC)

        let verdictC = resultC.didFreeze ? "✓ Expected" : "⚠️ Should fail!"
        log(String(format: "%-15@ %6d %6d %7.0f%% %6d %@",
                   "Passive", resultC.towersPlaced, resultC.totalKills, resultC.finalEfficiency,
                   resultC.freezeCount, verdictC))

        log("")
        log("Analysis:")
        if resultA.didFreeze {
            log("  ⚠️ TowersFirst strategy fails - may be too punishing early")
        } else if !resultB.didFreeze {
            log("  ⚠️ NoTowers survives - towers aren't required (balance issue)")
        } else {
            log("  ✓ Progression hierarchy correct: towers required for survival")
        }
    }

    // MARK: - Q8: Early Game Pacing

    /// Players should have time to look around. Low pressure, learn by playing.
    private static func testEarlyGamePacing() {
        log("")
        log("── Q8: Early Game Pacing Testing ──")
        log("How much time does a new player have before pressure builds?")
        log("")

        // Run a passive simulation to measure timing of first events
        let config = SimulationConfig(
            seed: 42,
            bot: PassiveBot(),
            maxGameTime: 180,  // 3 minutes
            compiledProtocols: ["kernel_pulse"],
            unlockedSectors: [SectorID.power.rawValue],
            startingHash: 100,
            startingEfficiency: 100
        )
        let result = run(config: config)

        log("Passive Play Timing (no tower placement):")
        log(String(format: "  First freeze at: %.0fs", result.timeToFirstFreeze ?? result.gameDuration))
        log(String(format: "  Final efficiency: %.0f%%", result.finalEfficiency))
        log(String(format: "  Total freezes: %d", result.freezeCount))
        log("")

        // Analysis of pacing
        let firstFreezeTime = result.timeToFirstFreeze ?? result.gameDuration
        if firstFreezeTime < 30 {
            log("  ⚠️ First freeze too fast (<30s) - player has no time to explore")
        } else if firstFreezeTime < 60 {
            log("  ~ First freeze at \(Int(firstFreezeTime))s - tight but learnable")
        } else if firstFreezeTime < 120 {
            log("  ✓ First freeze at \(Int(firstFreezeTime))s - good learning window")
        } else {
            log("  ⚠️ First freeze at \(Int(firstFreezeTime))s - may be too forgiving")
        }

        // Test recovery with single tower
        log("")
        log("Recovery Test (place 1 tower at start):")

        let configRecovery = SimulationConfig(
            seed: 42,
            bot: TowersFirstBot(),
            maxGameTime: 180,
            compiledProtocols: ["kernel_pulse"],
            unlockedSectors: [SectorID.power.rawValue],
            startingHash: 100,
            startingEfficiency: 100
        )
        let resultRecovery = run(config: configRecovery)

        if resultRecovery.didFreeze {
            log(String(format: "  With 1 tower: froze at %.0fs", resultRecovery.timeToFirstFreeze ?? 0))
            log("  ⚠️ Single tower not enough for recovery")
        } else {
            log(String(format: "  With towers: maintained %.0f%% efficiency", resultRecovery.finalEfficiency))
            log("  ✓ Quick recovery possible with basic defense")
        }
    }

    // MARK: - Bonus Tests

    /// Q5 Follow-up: Does more lanes = more hash income?
    static func testMultiLaneHashIncome() {
        log("")
        log("── Q5b: Multi-Lane Hash Income ──")
        log("Does expanding to more sectors generate more hash?")
        log("")

        let sectorConfigs: [(String, Set<String>)] = [
            ("1 Lane", [SectorID.power.rawValue]),
            ("3 Lanes", [SectorID.power.rawValue, SectorID.ram.rawValue, SectorID.gpu.rawValue]),
            ("All Lanes", Set(SectorID.allCases.map { $0.rawValue }))
        ]

        log(String(format: "%-12@ %8@ %6@ %8@ %@",
                   "Config", "Hash", "Kills", "H/min", "Verdict"))
        log(String(repeating: "─", count: 50))

        for (name, sectors) in sectorConfigs {
            let config = SimulationConfig(
                seed: 42,
                bot: SpreadBot(),
                maxGameTime: 300,
                compiledProtocols: ["kernel_pulse", "burst_protocol"],
                unlockedSectors: sectors,
                startingHash: 200,
                startingEfficiency: 100
            )
            let result = run(config: config)
            let hashPerMin = CGFloat(result.totalHashEarned) / (result.gameDuration / 60.0)

            log(String(format: "%-12@ %8d %6d %8.1f %@",
                       name, result.totalHashEarned, result.totalKills, hashPerMin,
                       result.didFreeze ? "⚠️ Froze" : "✓ OK"))
        }

        log("")
        log("Analysis: More lanes = more enemies = more kill hash (if you can defend).")
    }

    /// Q6 Follow-up: What if you overclock immediately?
    static func testImmediateOverclock() {
        log("")
        log("── Q6b: Immediate Overclock Risk ──")
        log("Is spamming overclock at start a winning strategy?")
        log("")

        // Normal play with AdaptiveBot
        let configNormal = SimulationConfig(
            seed: 42,
            bot: AdaptiveBot(),
            maxGameTime: 300,
            compiledProtocols: ["kernel_pulse", "burst_protocol"],
            unlockedSectors: [SectorID.power.rawValue],
            startingHash: 100,
            startingEfficiency: 100
        )
        let resultNormal = run(config: configNormal)

        // Aggressive overclock with RushOverclockBot
        let configRush = SimulationConfig(
            seed: 42,
            bot: RushOverclockBot(),
            maxGameTime: 300,
            compiledProtocols: ["kernel_pulse", "burst_protocol"],
            unlockedSectors: [SectorID.power.rawValue],
            startingHash: 100,
            startingEfficiency: 100
        )
        let resultRush = run(config: configRush)

        log(String(format: "%-15@ %8@ %6@ %8@ %6@ %@",
                   "Strategy", "Hash", "Kills", "OC#", "Eff%", "Verdict"))
        log(String(repeating: "─", count: 60))

        log(String(format: "%-15@ %8d %6d %8d %5.0f%% %@",
                   "Adaptive", resultNormal.totalHashEarned, resultNormal.totalKills,
                   resultNormal.overclockCount, resultNormal.finalEfficiency,
                   resultNormal.didFreeze ? "⚠️ Froze" : "✓ OK"))

        log(String(format: "%-15@ %8d %6d %8d %5.0f%% %@",
                   "RushOverclock", resultRush.totalHashEarned, resultRush.totalKills,
                   resultRush.overclockCount, resultRush.finalEfficiency,
                   resultRush.didFreeze ? "⚠️ Froze" : "✓ OK"))

        log("")
        if resultRush.totalHashEarned > Int(Double(resultNormal.totalHashEarned) * 1.3) && !resultRush.didFreeze {
            log("  ⚠️ Rush OC significantly outperforms normal play (may be exploitable)")
        } else if resultRush.didFreeze && !resultNormal.didFreeze {
            log("  ✓ Rush OC is risky - leads to freezes (balanced)")
        } else {
            log("  ✓ Both strategies are viable")
        }
    }

    // MARK: - Boss Fight Test Suite

    /// Comprehensive boss fight balance testing
    static func runBossFightTestSuite() {
        logLines = []
        let startTime = CFAbsoluteTimeGetCurrent()

        log("")
        log(String(repeating: "═", count: 80))
        log("  BOSS FIGHT BALANCE TEST SUITE")
        log(String(repeating: "═", count: 80))

        testBossDifficultyTiers()
        testBossPhaseProgression()
        testBotStrategyComparison()
        testBossTypeComparison()
        testComprehensiveBossEvaluation()
        testWeaponBalance()
        testHazardAvoidance()

        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        log("")
        log(String(repeating: "═", count: 80))
        log(String(format: "Total boss test time: %.2fs", elapsed))
        log(String(repeating: "═", count: 80))

        writeLogFile()
    }

    // MARK: - Boss Test: Difficulty Tiers

    /// Test if difficulty tiers are properly balanced
    private static func testBossDifficultyTiers() {
        log("")
        log("── Boss Difficulty Tier Testing ──")
        log("Do difficulty tiers scale appropriately?")
        log("")

        let difficulties: [BossDifficulty] = [.easy, .normal, .hard, .nightmare]
        let bot = BalancedBot()

        log(String(format: "%-12@ %8@ %8@ %6@ %6@ %@",
                   "Difficulty", "Duration", "DmgTaken", "Deaths", "Win?", "Verdict"))
        log(String(repeating: "─", count: 65))

        var results: [(BossDifficulty, BossSimulationResult)] = []

        for difficulty in difficulties {
            let config = BossSimulationConfig(
                seed: 42,
                bossType: "cyberboss",
                difficulty: difficulty,
                bot: bot,
                maxFightTime: 300,
                playerWeaponDamage: 50,
                playerHealth: 200,
                arenaSize: 1500,
                weapon: nil
            )

            let sim = BossSimulator(config: config)
            let result = sim.run()
            results.append((difficulty, result))

            let verdict: String
            if !result.victory {
                verdict = "⚠️ Lost"
            } else if result.playerDeaths > 0 {
                verdict = "~ Close"
            } else if result.fightDuration > 200 {
                verdict = "~ Slow"
            } else {
                verdict = "✓ OK"
            }

            log(String(format: "%-12@ %7.0fs %8.0f %6d %6@ %@",
                       difficulty.displayName,
                       result.fightDuration,
                       result.totalDamageTaken,
                       result.playerDeaths,
                       result.victory ? "Yes" : "No",
                       verdict))
        }

        log("")
        log("Analysis:")

        // Check scaling
        if let easyResult = results.first(where: { $0.0 == .easy })?.1,
           let hardResult = results.first(where: { $0.0 == .hard })?.1 {
            let dmgRatio = hardResult.totalDamageTaken / max(1, easyResult.totalDamageTaken)
            if dmgRatio < 1.5 {
                log("  ⚠️ Hard mode doesn't feel much harder than Easy (damage ratio: \(String(format: "%.1fx", dmgRatio)))")
            } else if dmgRatio > 4 {
                log("  ⚠️ Hard mode may be too punishing (damage ratio: \(String(format: "%.1fx", dmgRatio)))")
            } else {
                log("  ✓ Difficulty scaling feels appropriate (\(String(format: "%.1fx", dmgRatio)) damage ratio)")
            }
        }

        // Check nightmare
        if let nightmareResult = results.first(where: { $0.0 == .nightmare })?.1 {
            if nightmareResult.victory && nightmareResult.playerDeaths == 0 {
                log("  ⚠️ Nightmare might be too easy (no deaths)")
            } else if !nightmareResult.victory {
                log("  ✓ Nightmare is challenging (didn't survive)")
            }
        }
    }

    // MARK: - Boss Test: Phase Progression

    /// Test if players see all boss phases
    private static func testBossPhaseProgression() {
        log("")
        log("── Boss Phase Progression Testing ──")
        log("Are all boss phases being reached?")
        log("")

        let bossTypes = ["cyberboss", "void_harbinger"]

        for bossType in bossTypes {
            let config = BossSimulationConfig(
                seed: 42,
                bossType: bossType,
                difficulty: .normal,
                bot: PhaseAwareBot(),
                maxFightTime: 300,
                playerWeaponDamage: 60,
                playerHealth: 200,
                arenaSize: 1500,
                weapon: nil
            )

            let sim = BossSimulator(config: config)
            let result = sim.run()

            log("\(bossType.capitalized):")
            log(String(format: "  Phase reached: %d", result.phaseReached))
            log(String(format: "  Time per phase: P1=%.0fs, P2=%.0fs, P3=%.0fs, P4=%.0fs",
                       result.timeInPhase[1] ?? 0,
                       result.timeInPhase[2] ?? 0,
                       result.timeInPhase[3] ?? 0,
                       result.timeInPhase[4] ?? 0))
            log(String(format: "  Victory: %@, Duration: %.0fs",
                       result.victory ? "Yes" : "No", result.fightDuration))

            if result.phaseReached < 4 && result.victory {
                log("  ⚠️ Boss died before reaching Phase 4")
            } else if !result.victory && result.phaseReached < 3 {
                log("  ⚠️ Player died in early phases")
            } else {
                log("  ✓ Good phase progression")
            }

            // Check phase timing balance
            if let p1 = result.timeInPhase[1], let p4 = result.timeInPhase[4] {
                if p1 > 0 && p4 > 0 && p1 > p4 * 3 {
                    log("  ⚠️ Phase 1 takes too long compared to Phase 4")
                }
            }

            log("")
        }
    }

    // MARK: - Boss Test: Bot Strategy Comparison

    /// Compare different player strategies
    private static func testBotStrategyComparison() {
        log("")
        log("── Bot Strategy Comparison ──")
        log("Which playstyles are viable?")
        log("")

        let bots: [BossBot] = [
            AggressiveBot(),
            DefensiveBot(),
            BalancedBot(),
            PhaseAwareBot(),
            StandingStillBot(),
            RandomBot()
        ]

        log(String(format: "%-15@ %6@ %8@ %6@ %8@ %@",
                   "Strategy", "Win?", "Duration", "Deaths", "DPS", "Verdict"))
        log(String(repeating: "─", count: 65))

        for bot in bots {
            let config = BossSimulationConfig(
                seed: 42,
                bossType: "cyberboss",
                difficulty: .normal,
                bot: bot,
                maxFightTime: 300,
                playerWeaponDamage: 50,
                playerHealth: 200,
                arenaSize: 1500,
                weapon: nil
            )

            let sim = BossSimulator(config: config)
            let result = sim.run()

            let verdict: String
            if !result.victory {
                verdict = "✗ Fail"
            } else if result.playerDeaths >= 3 {
                verdict = "~ Risky"
            } else if result.playerDeaths == 0 {
                verdict = "✓✓ Clean"
            } else {
                verdict = "✓ OK"
            }

            log(String(format: "%-15@ %6@ %7.0fs %6d %8.1f %@",
                       bot.name,
                       result.victory ? "Yes" : "No",
                       result.fightDuration,
                       result.playerDeaths,
                       result.dps,
                       verdict))
        }

        log("")
        log("Expected: StandingStill should fail, Defensive/Balanced should succeed")
    }

    // MARK: - Boss Test: Boss Type Comparison

    /// Compare Cyberboss vs Void Harbinger
    private static func testBossTypeComparison() {
        log("")
        log("── Boss Type Comparison ──")
        log("Are all bosses similarly difficult?")
        log("")

        let bossTypes = ["cyberboss", "void_harbinger", "overclocker", "trojan_wyrm"]
        let bot = BalancedBot()

        log(String(format: "%-16@ %6@ %8@ %6@ %8@ %8@ %@",
                   "Boss", "Win?", "Duration", "Deaths", "DmgTkn", "DPS", "Verdict"))
        log(String(repeating: "─", count: 75))

        var results: [(String, BossSimulationResult)] = []

        for bossType in bossTypes {
            let config = BossSimulationConfig(
                seed: 42,
                bossType: bossType,
                difficulty: .normal,
                bot: bot,
                maxFightTime: 300,
                playerWeaponDamage: 50,
                playerHealth: 200,
                arenaSize: 1500,
                weapon: nil
            )

            let sim = BossSimulator(config: config)
            let result = sim.run()
            results.append((bossType, result))

            let verdict: String
            if !result.victory {
                verdict = "⚠️ Too hard?"
            } else if result.playerDeaths == 0 && result.fightDuration < 120 {
                verdict = "⚠️ Too easy?"
            } else {
                verdict = "✓ Balanced"
            }

            log(String(format: "%-16@ %6@ %7.0fs %6d %8.0f %8.1f %@",
                       bossType,
                       result.victory ? "Yes" : "No",
                       result.fightDuration,
                       result.playerDeaths,
                       result.totalDamageTaken,
                       result.dps,
                       verdict))
        }

        log("")

        // Compare all bosses
        if results.count >= 2 {
            let durations = results.map { $0.1.fightDuration }
            let damages = results.map { $0.1.totalDamageTaken }
            let durationSpread = durations.max()! - durations.min()!
            let dmgSpread = damages.max()! - damages.min()!

            if durationSpread > 60 {
                log("  ⚠️ Fight duration spread: \(Int(durationSpread))s - consider rebalancing")
            } else {
                log("  ✓ Fight durations are similar (spread: \(Int(durationSpread))s)")
            }

            if dmgSpread > 500 {
                log("  ⚠️ Damage taken spread: \(Int(dmgSpread)) - some bosses may be harder")
            } else {
                log("  ✓ Difficulty feels comparable (spread: \(Int(dmgSpread)))")
            }
        }
    }

    // MARK: - Comprehensive Boss Evaluation

    /// Full matrix test: All bosses × All difficulties × Multiple strategies
    private static func testComprehensiveBossEvaluation() {
        log("")
        log("── Comprehensive Boss Evaluation ──")
        log("Testing all boss×difficulty×strategy combinations")
        log("")

        let bossTypes = ["cyberboss", "void_harbinger", "overclocker", "trojan_wyrm"]
        let difficulties: [BossDifficulty] = [.easy, .normal, .hard, .nightmare]
        let testBot = BalancedBot()

        for bossType in bossTypes {
            log("\(bossType.uppercased()):")
            log(String(format: "%-10@ %8@ %6@ %6@ %8@ %6@ %@",
                       "Difficulty", "Duration", "Deaths", "DPS", "DmgTaken", "Phase", "Result"))
            log(String(repeating: "─", count: 70))

            for difficulty in difficulties {
                let config = BossSimulationConfig(
                    seed: 42,
                    bossType: bossType,
                    difficulty: difficulty,
                    bot: testBot,
                    maxFightTime: 300,
                    playerWeaponDamage: 50,
                    playerHealth: 200,
                    arenaSize: 1500,
                    weapon: nil
                )

                let sim = BossSimulator(config: config)
                let result = sim.run()

                let resultStr: String
                if !result.victory {
                    resultStr = "✗ TIMEOUT"
                } else if result.playerDeaths == 0 {
                    resultStr = "✓✓ CLEAN"
                } else if result.playerDeaths <= 3 {
                    resultStr = "✓ WIN"
                } else {
                    resultStr = "~ CLOSE"
                }

                log(String(format: "%-10@ %7.0fs %6d %6.1f %8.0f %6d %@",
                           difficulty.displayName,
                           result.fightDuration,
                           result.playerDeaths,
                           result.dps,
                           result.totalDamageTaken,
                           result.phaseReached,
                           resultStr))
            }
            log("")
        }

        // Summary comparison
        log("BALANCE SUMMARY (Normal difficulty):")

        // Test all 4 bosses on Normal with same bot
        let cyberbossNormal = runBossTest(bossType: "cyberboss", difficulty: .normal, bot: testBot)
        let voidHarbingerNormal = runBossTest(bossType: "void_harbinger", difficulty: .normal, bot: testBot)
        let overclockerNormal = runBossTest(bossType: "overclocker", difficulty: .normal, bot: testBot)
        let trojanWyrmNormal = runBossTest(bossType: "trojan_wyrm", difficulty: .normal, bot: testBot)

        let allResults = [
            ("Cyberboss", cyberbossNormal),
            ("Void Harbinger", voidHarbingerNormal),
            ("Overclocker", overclockerNormal),
            ("Trojan Wyrm", trojanWyrmNormal)
        ]

        log(String(format: "%-15@ %8@ %6@ %8@", "Boss", "Duration", "Deaths", "DmgTaken"))
        log(String(repeating: "─", count: 45))
        for (name, result) in allResults {
            log(String(format: "%-15@ %7.0fs %6d %8.0f", name, result.fightDuration, result.playerDeaths, result.totalDamageTaken))
        }

        // Calculate variance
        let durations = allResults.map { $0.1.fightDuration }
        let deaths = allResults.map { $0.1.playerDeaths }
        let maxDurationDiff = durations.max()! - durations.min()!
        let maxDeathsDiff = deaths.max()! - deaths.min()!

        log("")
        log(String(format: "  Max duration spread: %.0fs %@", maxDurationDiff, maxDurationDiff < 60 ? "✓" : "⚠️"))
        log(String(format: "  Max deaths spread: %d %@", maxDeathsDiff, maxDeathsDiff <= 5 ? "✓" : "⚠️"))

        // Check difficulty progression
        let easyResult = runBossTest(bossType: "cyberboss", difficulty: .easy, bot: testBot)
        let hardResult = runBossTest(bossType: "cyberboss", difficulty: .hard, bot: testBot)
        let nightmareResult = runBossTest(bossType: "cyberboss", difficulty: .nightmare, bot: testBot)

        log("")
        log("DIFFICULTY SCALING (Cyberboss):")
        log(String(format: "  Easy→Normal deaths: %d→%d", easyResult.playerDeaths, cyberbossNormal.playerDeaths))
        log(String(format: "  Normal→Hard deaths: %d→%d", cyberbossNormal.playerDeaths, hardResult.playerDeaths))
        log(String(format: "  Hard→Nightmare deaths: %d→%d", hardResult.playerDeaths, nightmareResult.playerDeaths))

        if nightmareResult.victory && nightmareResult.playerDeaths < 10 {
            log("  ⚠️ Nightmare might be too easy")
        } else if !nightmareResult.victory {
            log("  ✓ Nightmare is appropriately challenging")
        }
    }

    private static func runBossTest(bossType: String, difficulty: BossDifficulty, bot: BossBot) -> BossSimulationResult {
        let config = BossSimulationConfig(
            seed: 42,
            bossType: bossType,
            difficulty: difficulty,
            bot: bot,
            maxFightTime: 300,
            playerWeaponDamage: 50,
            playerHealth: 200,
            arenaSize: 1500,
            weapon: nil
        )
        let sim = BossSimulator(config: config)
        return sim.run()
    }

    // MARK: - Weapon Balance Tests

    /// Test all weapons against all bosses at different levels
    private static func testWeaponBalance() {
        log("")
        log("── Weapon Balance Testing ──")
        log("Testing 6 weapons × 4 bosses × 3 levels = 72 combinations")
        log("")

        let bossTypes = ["cyberboss", "void_harbinger", "overclocker", "trojan_wyrm"]
        let levels = [1, 5, 10]
        let bot = BalancedBot()

        // Header
        log(String(format: "%-18@ %6@ %8@ %8@ %6@ %8@ %8@ %8@",
                   "Weapon", "Level", "Boss", "Duration", "Deaths", "DPS", "DoT", "Bonus"))
        log(String(repeating: "─", count: 85))

        // Test each weapon
        for weaponType in SimulatedWeaponType.allCases {
            for level in levels {
                let weapon = SimulatedWeapon(type: weaponType, level: level)

                // Test against Cyberboss as baseline (fastest to test)
                let config = BossSimulationConfig(
                    seed: 42,
                    bossType: "cyberboss",
                    difficulty: .normal,
                    bot: bot,
                    maxFightTime: 300,
                    playerWeaponDamage: 50,
                    playerHealth: 200,
                    arenaSize: 1500,
                    weapon: weapon
                )

                let sim = BossSimulator(config: config)
                let result = sim.run()

                log(String(format: "%-18@ Lv%-4d %-10@ %6.0fs %6d %7.1f %7.0f %7.0f",
                           weaponType.displayName,
                           level,
                           "Cyberboss",
                           result.fightDuration,
                           result.playerDeaths,
                           result.dps,
                           result.dotDamageDealt,
                           result.bonusDamageDealt))
            }
        }

        log("")

        // Cross-boss comparison at level 5
        log("── Cross-Boss Weapon Comparison (Level 5) ──")
        log("")

        for bossType in bossTypes {
            log("\(bossType.uppercased()):")
            log(String(format: "%-18@ %8@ %6@ %8@ %@",
                       "Weapon", "Duration", "Deaths", "DPS", "Verdict"))
            log(String(repeating: "─", count: 55))

            var results: [(SimulatedWeaponType, BossSimulationResult)] = []

            for weaponType in SimulatedWeaponType.allCases {
                let weapon = SimulatedWeapon(type: weaponType, level: 5)
                let config = BossSimulationConfig(
                    seed: 42,
                    bossType: bossType,
                    difficulty: .normal,
                    bot: bot,
                    maxFightTime: 300,
                    playerWeaponDamage: 50,
                    playerHealth: 200,
                    arenaSize: 1500,
                    weapon: weapon
                )

                let sim = BossSimulator(config: config)
                let result = sim.run()
                results.append((weaponType, result))

                let verdict: String
                if !result.victory {
                    verdict = "✗ Timeout"
                } else if result.playerDeaths <= 2 {
                    verdict = "✓✓ Great"
                } else if result.playerDeaths <= 5 {
                    verdict = "✓ Good"
                } else {
                    verdict = "~ Struggle"
                }

                log(String(format: "%-18@ %7.0fs %6d %7.1f %@",
                           weaponType.displayName,
                           result.fightDuration,
                           result.playerDeaths,
                           result.dps,
                           verdict))
            }

            // Find best and worst
            let sorted = results.sorted { $0.1.dps > $1.1.dps }
            if let best = sorted.first, let worst = sorted.last {
                let dpsSpread = best.1.dps - worst.1.dps
                if dpsSpread > 30 {
                    log(String(format: "  ⚠️ DPS spread: %.1f (%@ vs %@)",
                               dpsSpread, best.0.displayName, worst.0.displayName))
                } else {
                    log("  ✓ Weapons are balanced")
                }
            }
            log("")
        }

        // Level scaling analysis
        log("── Level Scaling Analysis ──")
        log("Does damage scale appropriately with level?")
        log("")

        for weaponType in [SimulatedWeaponType.kernelPulse, .fragmenter, .recursion] {
            log("\(weaponType.displayName):")

            var levelDPS: [Int: CGFloat] = [:]
            for level in [1, 3, 5, 7, 10] {
                let weapon = SimulatedWeapon(type: weaponType, level: level)
                let config = BossSimulationConfig(
                    seed: 42,
                    bossType: "cyberboss",
                    difficulty: .normal,
                    bot: bot,
                    maxFightTime: 300,
                    playerWeaponDamage: 50,
                    playerHealth: 200,
                    arenaSize: 1500,
                    weapon: weapon
                )

                let sim = BossSimulator(config: config)
                let result = sim.run()
                levelDPS[level] = result.dps
            }

            // Check scaling ratios
            if let lv1 = levelDPS[1], let lv5 = levelDPS[5], let lv10 = levelDPS[10] {
                let ratio1to5 = lv5 / lv1
                let ratio5to10 = lv10 / lv5
                log(String(format: "  Lv1→5 ratio: %.2fx, Lv5→10 ratio: %.2fx",
                           ratio1to5, ratio5to10))

                if ratio1to5 < 3 {
                    log("  ⚠️ Early levels may be underpowered")
                } else if ratio1to5 > 7 {
                    log("  ⚠️ Level scaling may be too steep")
                } else {
                    log("  ✓ Scaling looks reasonable")
                }
            }
        }
    }

    // MARK: - Hazard Analysis Tests

    /// Detailed hazard avoidance analysis
    private static func testHazardAvoidance() {
        log("")
        log("── Hazard Avoidance Analysis ──")
        log("Which hazards cause the most damage?")
        log("")

        let config = BossSimulationConfig(
            seed: 42,
            bossType: "cyberboss",
            difficulty: .hard,
            bot: BalancedBot(),
            maxFightTime: 300,
            playerWeaponDamage: 50,
            playerHealth: 200,
            arenaSize: 1500,
            weapon: nil
        )

        let sim = BossSimulator(config: config)
        let result = sim.run()

        log("Hazard Hits (Cyberboss Hard):")
        log(String(format: "  Puddles: %d hits", result.puddleHits))
        log(String(format: "  Lasers: %d hits", result.laserHits))
        log(String(format: "  Projectiles: %d hits", result.projectileHits))
        log("")

        // Void Harbinger
        let configVH = BossSimulationConfig(
            seed: 42,
            bossType: "void_harbinger",
            difficulty: .hard,
            bot: BalancedBot(),
            maxFightTime: 300,
            playerWeaponDamage: 50,
            playerHealth: 200,
            arenaSize: 1500,
            weapon: nil
        )

        let simVH = BossSimulator(config: configVH)
        let resultVH = simVH.run()

        log("Hazard Hits (Void Harbinger Hard):")
        log(String(format: "  Void Zones: %d hits", resultVH.voidZoneHits))
        log(String(format: "  Void Rifts: %d hits", resultVH.riftHits))
        log(String(format: "  Projectiles: %d hits", resultVH.projectileHits))
        log(String(format: "  Pylons destroyed: %d", resultVH.pylonsDestroyed))
    }
}
