import Foundation
import CoreGraphics

// MARK: - Simulation Engine
// Models gameplay progression over time using BalanceConfig values.
// Supports passive (AFK), active (tower management), and speedrun scenarios.
// Tracks all 9 component levels: PSU, Storage, RAM, GPU, Cache, Expansion, I/O, Network, CPU.

struct SimulationState {
    var time: TimeInterval = 0
    var hash: Double = 0
    var threatLevel: Double = 1.0

    // Component levels (all 9)
    var psuLevel: Int = 1
    var storageLevel: Int = 1
    var ramLevel: Int = 1
    var gpuLevel: Int = 1
    var cacheLevel: Int = 1
    var expansionLevel: Int = 1
    var ioLevel: Int = 1
    var networkLevel: Int = 1
    var cpuLevel: Int = 1

    // CPU tier (separate from CPU component level)
    var cpuTier: Int = 1

    var towersPlaced: Int = 0
    var towerPowerUsed: Int = 0
    var unlockedSectors: Int = 1
    var efficiency: Double = 100
    var leakCounter: Int = 0
    var totalHashEarned: Double = 0
    var totalHashSpent: Double = 0
    var events: [String] = []

    /// Get current level for a component by id
    func level(for componentId: String) -> Int {
        switch componentId {
        case "psu": return psuLevel
        case "storage": return storageLevel
        case "ram": return ramLevel
        case "gpu": return gpuLevel
        case "cache": return cacheLevel
        case "expansion": return expansionLevel
        case "io": return ioLevel
        case "network": return networkLevel
        case "cpu": return cpuLevel
        default: return 1
        }
    }

    /// Increment level for a component by id
    mutating func incrementLevel(for componentId: String) {
        switch componentId {
        case "psu": psuLevel += 1
        case "storage": storageLevel += 1
        case "ram": ramLevel += 1
        case "gpu": gpuLevel += 1
        case "cache": cacheLevel += 1
        case "expansion": expansionLevel += 1
        case "io": ioLevel += 1
        case "network": networkLevel += 1
        case "cpu": cpuLevel += 1
        default: break
        }
    }
}

struct SimulationEngine {

    static func run(scenario: String, durationSeconds: Int) {
        printHeader("SCENARIO SIMULATION: \(scenario.uppercased())")

        switch scenario {
        case "passive":
            printCauseEffect("Player goes AFK", "Hash accumulates, threat grows, efficiency may drop from leaks")
            runSimulation(duration: durationSeconds, strategy: .passive)
        case "active":
            printCauseEffect("Player places towers, upgrades components", "Hash spent on towers & upgrades, efficiency maintained")
            runSimulation(duration: durationSeconds, strategy: .active)
        case "speedrun":
            printCauseEffect("Optimal play: PSU → CPU → Network → sectors", "Fastest path to full upgrade")
            runSimulation(duration: durationSeconds, strategy: .speedrun)
        default:
            print("  Unknown scenario: \(scenario)")
            print("  Available: passive, active, speedrun")
            return
        }
    }

    enum Strategy {
        case passive
        case active
        case speedrun
    }

    private static func runSimulation(duration: Int, strategy: Strategy) {
        var state = SimulationState()
        state.events.append("Start")

        let tickInterval: TimeInterval = 1.0  // Simulate every second
        let reportInterval: TimeInterval = 60  // Report every minute
        var nextReport: TimeInterval = 0

        // Print header
        printSubheader("Time Series")
        print("\n  Time     Hash       Threat  Efficiency  Towers  Power     Sectors  Event")
        print("  " + String(repeating: "-", count: 85))

        // Initial state
        printState(state)

        while state.time < Double(duration) {
            state.time += tickInterval
            state.events = []

            // 1. Hash income (CPU level + CPU tier + Network multiplier + efficiency)
            let hashPerSec = calculateHashPerSec(state: state)
            let income = hashPerSec * tickInterval
            state.hash += income
            state.totalHashEarned += income

            // Cap hash at storage capacity (Storage component)
            let storageCap = Double(BalanceConfig.Components.storageCapacity(at: state.storageLevel))
            if state.hash > storageCap {
                state.hash = storageCap
                if state.events.isEmpty { state.events.append("Hash capped") }
            }

            // 2. Threat growth
            let threatGrowth = Double(BalanceConfig.ThreatLevel.onlineThreatGrowthRate) * tickInterval
            let maxThreat = Double(BalanceConfig.ThreatLevel.maxThreatLevel)
            state.threatLevel = min(maxThreat, state.threatLevel + threatGrowth)

            // 3. Efficiency decay (simulate periodic leaks for passive)
            if strategy == .passive {
                // Leaks happen more frequently at higher threat
                let leakChance = BalanceConfig.Simulation.passiveLeakChancePerThreat * state.threatLevel
                if Double.random(in: 0...1) < leakChance {
                    state.leakCounter += 1
                    state.efficiency = efficiencyForLeaks(state.leakCounter)
                }
            }

            // 4. Leak decay (natural recovery, scaled by RAM level)
            let ramRegen = Double(BalanceConfig.Components.ramEfficiencyRegen(at: state.ramLevel))
            let effectiveDecayInterval = BalanceConfig.Efficiency.leakDecayInterval / ramRegen
            if state.leakCounter > 0 && state.time.truncatingRemainder(dividingBy: effectiveDecayInterval) < tickInterval {
                state.leakCounter = max(0, state.leakCounter - 1)
                state.efficiency = efficiencyForLeaks(state.leakCounter)
            }

            // 5. Strategy-specific actions
            switch strategy {
            case .passive:
                break  // No actions

            case .active:
                tryPlaceTower(state: &state)
                tryUpgradeComponent(state: &state, priority: ["psu", "gpu", "cache", "cpu", "ram", "storage", "network", "io", "expansion"])

            case .speedrun:
                tryUpgradeComponent(state: &state, priority: ["psu", "cpu", "network", "storage", "gpu", "cache", "ram", "io", "expansion"])
                tryPlaceTower(state: &state)
                tryUnlockSector(state: &state)
            }

            // 6. Check milestones
            checkMilestones(state: &state)

            // Report at intervals
            if state.time >= nextReport {
                if !state.events.isEmpty {
                    printState(state)
                }
                nextReport = state.time + reportInterval
            }

            // Also report on events even outside interval
            if !state.events.isEmpty && state.time < nextReport - reportInterval + tickInterval {
                printState(state)
            }
        }

        // Final state
        state.events = ["End"]
        printState(state)

        // Summary
        printSubheader("Summary")
        printRow("Total Duration", formatTime(Double(duration)))
        printRow("Total Hash Earned", formatNumber(state.totalHashEarned))
        printRow("Total Hash Spent", formatNumber(state.totalHashSpent))
        printRow("Final Hash Balance", formatNumber(state.hash))
        printRow("Final Threat Level", String(format: "%.1f", state.threatLevel))
        printRow("Final Efficiency", String(format: "%.0f%%", state.efficiency))
        printRow("Towers Placed", "\(state.towersPlaced)")
        printRow("Sectors Unlocked", "\(state.unlockedSectors)")

        printSubheader("Component Levels")
        printRow("PSU", "Lv\(state.psuLevel) (\(BalanceConfig.Components.psuCapacity(at: state.psuLevel))W)")
        printRow("Storage", "Lv\(state.storageLevel) (\(formatNumber(Double(BalanceConfig.Components.storageCapacity(at: state.storageLevel)))) cap)")
        printRow("RAM", "Lv\(state.ramLevel) (\(String(format: "%.2fx", Double(BalanceConfig.Components.ramEfficiencyRegen(at: state.ramLevel)))) recovery)")
        printRow("GPU", "Lv\(state.gpuLevel) (\(String(format: "%.2fx", Double(BalanceConfig.Components.gpuDamageMultiplier(at: state.gpuLevel)))) tower dmg)")
        printRow("Cache", "Lv\(state.cacheLevel) (\(String(format: "%.2fx", Double(BalanceConfig.Components.cacheAttackSpeedMultiplier(at: state.cacheLevel)))) atk speed)")
        printRow("Expansion", "Lv\(state.expansionLevel) (+\(BalanceConfig.Components.expansionExtraSlots(at: state.expansionLevel)) slots)")
        printRow("I/O", "Lv\(state.ioLevel) (\(String(format: "%.2fx", Double(BalanceConfig.Components.ioPickupRadiusMultiplier(at: state.ioLevel)))) pickup)")
        printRow("Network", "Lv\(state.networkLevel) (\(String(format: "%.2fx", Double(BalanceConfig.Components.networkHashMultiplier(at: state.networkLevel)))) hash mult)")
        printRow("CPU", "Lv\(state.cpuLevel) (\(String(format: "%.1f", Double(BalanceConfig.Components.cpuHashPerSecond(at: state.cpuLevel)))) H/s)")
        printRow("CPU Tier", "\(state.cpuTier) (\(Double(BalanceConfig.CPU.multiplier(tier: state.cpuTier)))x)")

        // Effective rates
        printSubheader("Effective Rates (Final)")
        let effectiveHPS = calculateHashPerSec(state: state)
        printRow("Hash/sec", String(format: "%.2f", effectiveHPS))
        printRow("Hash/min", formatNumber(effectiveHPS * 60))
        printRow("Hash/hour", formatNumber(effectiveHPS * 3600))
        let gpuMult = Double(BalanceConfig.Components.gpuDamageMultiplier(at: state.gpuLevel))
        let cacheMult = Double(BalanceConfig.Components.cacheAttackSpeedMultiplier(at: state.cacheLevel))
        printRow("Tower DPS Multiplier", String(format: "%.2fx dmg × %.2fx speed = %.2fx", gpuMult, cacheMult, gpuMult * cacheMult))
    }

    // MARK: - Helpers

    private static func calculateHashPerSec(state: SimulationState) -> Double {
        let baseRate = Double(BalanceConfig.HashEconomy.hashPerSecond(at: state.cpuLevel))
        let cpuTierMult = Double(BalanceConfig.CPU.multiplier(tier: state.cpuTier))
        let networkMult = Double(BalanceConfig.Components.networkHashMultiplier(at: state.networkLevel))
        return baseRate * cpuTierMult * networkMult * (state.efficiency / 100.0)
    }

    private static func efficiencyForLeaks(_ leaks: Int) -> Double {
        // Mirror BalanceConfig.TDSession.efficiencyForLeakCount
        return max(0, 100.0 - Double(leaks) * Double(BalanceConfig.TDSession.efficiencyLossPerLeak))
    }

    private static func tryPlaceTower(state: inout SimulationState) {
        let commonCost = Double(BalanceConfig.Towers.placementCosts[.common] ?? 50)
        let commonPower = BalanceConfig.TowerPower.powerDraw(for: .common)
        let powerBudget = BalanceConfig.Components.psuCapacity(at: state.psuLevel)
        let powerAvailable = powerBudget - state.towerPowerUsed

        // Expansion component provides extra tower slots
        let baseSlots = powerBudget / commonPower  // Power-limited
        let extraSlots = BalanceConfig.Components.expansionExtraSlots(at: state.expansionLevel)
        let maxTowers = baseSlots + extraSlots

        if state.hash >= commonCost && powerAvailable >= commonPower && state.towersPlaced < maxTowers {
            state.hash -= commonCost
            state.totalHashSpent += commonCost
            state.towersPlaced += 1
            state.towerPowerUsed += commonPower
            state.events.append("Placed tower #\(state.towersPlaced)")
        }
    }

    private static func tryUpgradeComponent(state: inout SimulationState, priority: [String]) {
        for component in priority {
            let currentLevel = state.level(for: component)

            guard currentLevel < BalanceConfig.Components.maxLevel else { continue }
            let baseCost = BalanceConfig.Components.baseCost(for: component)
            let cost = Double(BalanceConfig.exponentialUpgradeCost(baseCost: baseCost, currentLevel: currentLevel))

            if state.hash >= cost {
                state.hash -= cost
                state.totalHashSpent += cost
                state.incrementLevel(for: component)
                let newLevel = state.level(for: component)
                state.events.append("\(component.uppercased()) → Lv\(newLevel)")
                return  // One upgrade per tick
            }
        }

        // Try CPU tier upgrade
        if let cost = BalanceConfig.CPU.upgradeCost(currentTier: state.cpuTier) {
            if state.hash >= Double(cost) {
                state.hash -= Double(cost)
                state.totalHashSpent += Double(cost)
                state.cpuTier += 1
                state.events.append("CPU Tier → \(state.cpuTier)")
            }
        }
    }

    private static func tryUnlockSector(state: inout SimulationState) {
        let order = BalanceConfig.SectorUnlock.unlockOrder
        let costs = BalanceConfig.SectorUnlock.hashCosts
        let nextIdx = state.unlockedSectors

        guard nextIdx < order.count, nextIdx < costs.count else { return }
        let cost = Double(costs[nextIdx])

        if state.hash >= cost {
            state.hash -= cost
            state.totalHashSpent += cost
            state.unlockedSectors += 1
            state.events.append("Unlocked \(order[nextIdx].uppercased())")
        }
    }

    private static func checkMilestones(state: inout SimulationState) {
        let fastThreshold = Double(BalanceConfig.ThreatLevel.fastEnemyThreshold)
        let tankThreshold = Double(BalanceConfig.ThreatLevel.tankEnemyThreshold)
        let bossThreshold = Double(BalanceConfig.ThreatLevel.bossEnemyThreshold)

        if state.threatLevel >= fastThreshold && state.threatLevel < fastThreshold + 0.01 {
            state.events.append("Fast enemies unlock")
        }
        if state.threatLevel >= tankThreshold && state.threatLevel < tankThreshold + 0.01 {
            state.events.append("Tank enemies unlock")
        }
        if state.threatLevel >= bossThreshold && state.threatLevel < bossThreshold + 0.01 {
            state.events.append("Mini-boss unlock")
        }
    }

    private static func printState(_ state: SimulationState) {
        let timeStr = formatTime(state.time).padding(toLength: 7, withPad: " ", startingAt: 0)
        let hashStr = formatNumber(state.hash).padding(toLength: 9, withPad: " ", startingAt: 0)
        let threatStr = String(format: "%5.1f", state.threatLevel)
        let effStr = String(format: "%5.0f%%", state.efficiency)
        let towerStr = String(format: "%4d", state.towersPlaced)
        let powerBudget = BalanceConfig.Components.psuCapacity(at: state.psuLevel)
        let powerStr = "\(state.towerPowerUsed)/\(powerBudget)W".padding(toLength: 9, withPad: " ", startingAt: 0)
        let sectorStr = String(format: "%4d", state.unlockedSectors)
        let eventStr = state.events.joined(separator: ", ")

        print("  \(timeStr) \(hashStr) \(threatStr)   \(effStr)       \(towerStr)    \(powerStr) \(sectorStr)     \(eventStr)")
    }
}
