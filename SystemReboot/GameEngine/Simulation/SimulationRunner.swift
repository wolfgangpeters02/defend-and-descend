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
    var componentLevels: GlobalUpgrades = BalanceConfig.Simulation.earlyGame
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
            levels.psuLevel = psuLevel

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
            let watts = GlobalUpgrades.powerCapacity(at: psuLevel)
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
            levels.hddLevel = hddLevel

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
            let capacity = GlobalUpgrades.hashStorageCapacity(at: hddLevel)
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
            levels.cpuLevel = cpuLevel

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
            let hashPerSec = GlobalUpgrades.hashPerSecond(at: cpuLevel)
            let multiplier = hashPerSec / max(1, GlobalUpgrades.hashPerSecond(at: 1))

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
        levelsC.psuLevel = 1
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

        let componentTests: [(String, (inout GlobalUpgrades) -> Void)] = [
            ("PSU→5", { $0.psuLevel = 5 }),
            ("CPU→5", { $0.cpuLevel = 5 }),
            ("RAM→5", { $0.ramLevel = 5 }),
            ("Cool→5", { $0.coolingLevel = 5 }),
            ("HDD→5", { $0.hddLevel = 5 })
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
}
