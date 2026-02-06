import Foundation
import CoreGraphics

// MARK: - Bot Action

enum TDBotAction {
    case idle
    case placeTower(protocolId: String, slotId: String)
    case upgradeTower(towerId: String)
    case sellTower(towerId: String)
    case activateOverclock
    case engageBoss(difficulty: BossDifficulty)
    case ignoreBoss
}

// MARK: - Bot Protocol

protocol TDBot {
    var name: String { get }
    func decide(state: TDGameState, profile: PlayerProfile) -> TDBotAction
}

// MARK: - Passive Bot
// Never places towers. Baseline: how long does the core survive alone?

struct PassiveBot: TDBot {
    let name = "Passive"

    func decide(state: TDGameState, profile: PlayerProfile) -> TDBotAction {
        // Auto-engage bosses on easy if one spawns
        if state.bossActive && !state.bossEngaged {
            return .engageBoss(difficulty: .easy)
        }
        return .idle
    }
}

// MARK: - Greedy Bot
// Upgrades strongest tower first, places cheapest available protocol.

struct GreedyBot: TDBot {
    let name = "Greedy"

    func decide(state: TDGameState, profile: PlayerProfile) -> TDBotAction {
        // Handle boss
        if state.bossActive && !state.bossEngaged {
            return .engageBoss(difficulty: .normal)
        }

        // Try to upgrade the highest-level tower first (maximize single tower DPS)
        let upgradeable = state.towers
            .filter { $0.canUpgrade }
            .sorted { $0.level > $1.level }

        for tower in upgradeable {
            if state.hash >= tower.upgradeCost {
                return .upgradeTower(towerId: tower.id)
            }
        }

        // Place cheapest available protocol on empty slots
        let emptySlots = state.towerSlots.filter { !$0.occupied }
        guard !emptySlots.isEmpty else { return .idle }

        let compiled = profile.compiledProtocols
        guard !compiled.isEmpty else { return .idle }

        // Pick cheapest placement cost protocol
        let cheapest = compiled
            .compactMap { id -> (String, Int)? in
                guard let proto = ProtocolLibrary.get(id) else { return nil }
                let cost = BalanceConfig.Towers.placementCosts[proto.rarity] ?? 50
                return (id, cost)
            }
            .sorted { $0.1 < $1.1 }

        for (protoId, cost) in cheapest {
            guard let proto = ProtocolLibrary.get(protoId) else { continue }
            if state.hash >= cost && state.powerAvailable >= proto.firewallStats.powerDraw {
                if let slot = emptySlots.first {
                    return .placeTower(protocolId: protoId, slotId: slot.id)
                }
            }
        }

        return .idle
    }
}

// MARK: - Spread Bot
// Fills all slots before upgrading, round-robin across protocol types.

struct SpreadBot: TDBot {
    let name = "Spread"

    func decide(state: TDGameState, profile: PlayerProfile) -> TDBotAction {
        // Handle boss
        if state.bossActive && !state.bossEngaged {
            return .engageBoss(difficulty: .normal)
        }

        let emptySlots = state.towerSlots.filter { !$0.occupied }
        let compiled = profile.compiledProtocols

        // Phase 1: Fill all slots with round-robin protocol selection
        if !emptySlots.isEmpty && !compiled.isEmpty {
            // Count towers per protocol type
            var towerCounts: [String: Int] = [:]
            for protoId in compiled {
                towerCounts[protoId] = state.towers.filter { $0.weaponType == protoId }.count
            }

            // Pick the protocol with fewest placed towers
            let leastUsed = compiled
                .sorted { (towerCounts[$0] ?? 0) < (towerCounts[$1] ?? 0) }

            for protoId in leastUsed {
                guard let proto = ProtocolLibrary.get(protoId) else { continue }
                let cost = BalanceConfig.Towers.placementCosts[proto.rarity] ?? 50
                if state.hash >= cost && state.powerAvailable >= proto.firewallStats.powerDraw {
                    if let slot = emptySlots.first {
                        return .placeTower(protocolId: protoId, slotId: slot.id)
                    }
                }
            }
        }

        // Phase 2: Upgrade lowest-level tower
        let upgradeable = state.towers
            .filter { $0.canUpgrade }
            .sorted { $0.level < $1.level }

        if let tower = upgradeable.first, state.hash >= tower.upgradeCost {
            return .upgradeTower(towerId: tower.id)
        }

        return .idle
    }
}

// MARK: - Rush Overclock Bot
// Builds income towers, aggressively uses overclock for hash income.

struct RushOverclockBot: TDBot {
    let name = "RushOC"

    func decide(state: TDGameState, profile: PlayerProfile) -> TDBotAction {
        // Handle boss
        if state.bossActive && !state.bossEngaged {
            return .engageBoss(difficulty: .easy)
        }

        // Overclock whenever possible and efficiency is healthy
        if state.canOverclock && state.efficiency >= 70 {
            return .activateOverclock
        }

        let emptySlots = state.towerSlots.filter { !$0.occupied }
        let compiled = profile.compiledProtocols

        // Place towers focusing on high-damage types first
        let priorityOrder = ["burst_protocol", "fork_bomb", "ice_shard", "trace_route", "kernel_pulse"]
        if !emptySlots.isEmpty {
            for protoId in priorityOrder {
                guard compiled.contains(protoId),
                      let proto = ProtocolLibrary.get(protoId) else { continue }
                let cost = BalanceConfig.Towers.placementCosts[proto.rarity] ?? 50
                if state.hash >= cost && state.powerAvailable >= proto.firewallStats.powerDraw {
                    if let slot = emptySlots.first {
                        return .placeTower(protocolId: protoId, slotId: slot.id)
                    }
                }
            }
        }

        // Upgrade highest-DPS towers
        let upgradeable = state.towers
            .filter { $0.canUpgrade }
            .sorted { $0.damage > $1.damage }

        if let tower = upgradeable.first, state.hash >= tower.upgradeCost {
            return .upgradeTower(towerId: tower.id)
        }

        return .idle
    }
}

// MARK: - Adaptive Bot
// Smart bot with efficiency panic, power ceiling awareness, and hash reserve.
// Adjusts strategy dynamically based on game state.

struct AdaptiveBot: TDBot {
    let name = "Adaptive"

    func decide(state: TDGameState, profile: PlayerProfile) -> TDBotAction {
        let efficiency = state.efficiency
        let panicThreshold = BalanceConfig.Simulation.botPanicEfficiencyThreshold
        let powerCeiling = BalanceConfig.Simulation.botPowerCeilingThreshold
        let safeOCThreshold = BalanceConfig.Simulation.botSafeOverclockThreshold

        let isPanicking = efficiency < panicThreshold
        let powerUsagePercent = state.powerCapacity > 0
            ? CGFloat(state.powerUsed) / CGFloat(state.powerCapacity)
            : 0
        let atPowerCeiling = powerUsagePercent >= powerCeiling

        // Keep a hash reserve based on income rate (only if we have enough towers)
        let hashReserve = Int(state.hashPerSecond * BalanceConfig.Simulation.botHashReserveSeconds)
        let spendableHash = max(0, state.hash - hashReserve)

        // Boss decision: difficulty based on efficiency health
        if state.bossActive && !state.bossEngaged {
            if isPanicking {
                return .ignoreBoss  // Can't afford efficiency hit from a loss
            } else if efficiency > 85 {
                return .engageBoss(difficulty: .hard)
            } else {
                return .engageBoss(difficulty: .normal)
            }
        }

        // PANIC MODE: Efficiency dropping — prioritize getting ANY defense up
        if isPanicking {
            let emptySlots = state.towerSlots.filter { !$0.occupied }

            // First priority: Place a slow tower if we don't have one
            let slowTowers = state.towers.filter { $0.weaponType == "ice_shard" }
            if slowTowers.isEmpty && profile.compiledProtocols.contains("ice_shard") {
                if let slot = emptySlots.first,
                   let proto = ProtocolLibrary.get("ice_shard") {
                    let cost = BalanceConfig.Towers.placementCosts[proto.rarity] ?? 50
                    if state.hash >= cost && state.powerAvailable >= proto.firewallStats.powerDraw {
                        return .placeTower(protocolId: "ice_shard", slotId: slot.id)
                    }
                }
            }

            // Second priority: Place ANY tower - something is better than nothing in panic mode
            if !emptySlots.isEmpty {
                // Try all compiled protocols, prioritizing cheap ones
                let affordableTowers = profile.compiledProtocols
                    .compactMap { protoId -> (String, Int, Int)? in
                        guard let proto = ProtocolLibrary.get(protoId) else { return nil }
                        let cost = BalanceConfig.Towers.placementCosts[proto.rarity] ?? 50
                        let power = proto.firewallStats.powerDraw
                        return (protoId, cost, power)
                    }
                    .filter { state.hash >= $0.1 && state.powerAvailable >= $0.2 }
                    .sorted { $0.1 < $1.1 }  // Cheapest first

                if let (protoId, _, _) = affordableTowers.first,
                   let slot = emptySlots.first {
                    return .placeTower(protocolId: protoId, slotId: slot.id)
                }
            }

            // Third priority: Upgrade existing towers (prefer slows for stronger CC)
            let upgradeable = state.towers
                .filter { $0.canUpgrade }
                .sorted { tower1, tower2 in
                    // Prioritize slow towers, then by level (upgrade lowest first)
                    let isSlow1 = tower1.weaponType == "ice_shard"
                    let isSlow2 = tower2.weaponType == "ice_shard"
                    if isSlow1 != isSlow2 { return isSlow1 }
                    return tower1.level < tower2.level
                }

            // In panic mode, use ALL hash (no reserve) - survival is priority
            if let tower = upgradeable.first, state.hash >= tower.upgradeCost {
                return .upgradeTower(towerId: tower.id)
            }

            return .idle  // Save hash, don't overclock during panic
        }

        // NORMAL MODE: Balanced play

        // Overclock if safe
        if state.canOverclock && efficiency >= safeOCThreshold {
            return .activateOverclock
        }

        // Calculate available hash for spending:
        // - No reserve needed if we have fewer than 3 towers (get defenses up first!)
        // - Otherwise use normal hash reserve to maintain a buffer
        let minTowersForReserve = 3
        let hasEnoughTowers = state.towers.count >= minTowersForReserve
        let effectiveSpendableHash = hasEnoughTowers ? spendableHash : state.hash

        // If we have no towers, place one first (can't upgrade nothing)
        let emptySlots = state.towerSlots.filter { !$0.occupied }
        if state.towers.isEmpty && !emptySlots.isEmpty {
            // Balanced priority: DPS + utility
            let priorityOrder = ["burst_protocol", "ice_shard", "trace_route", "fork_bomb", "null_pointer", "kernel_pulse"]
            for protoId in priorityOrder {
                guard profile.compiledProtocols.contains(protoId),
                      let proto = ProtocolLibrary.get(protoId) else { continue }
                let cost = BalanceConfig.Towers.placementCosts[proto.rarity] ?? 50
                if effectiveSpendableHash >= cost && state.powerAvailable >= proto.firewallStats.powerDraw {
                    if let slot = emptySlots.first {
                        return .placeTower(protocolId: protoId, slotId: slot.id)
                    }
                }
            }
        }

        // UPGRADE FIRST: Tower levels are more cost-efficient than spreading
        // Upgrade lowest-level tower first for balanced coverage
        let upgradeable = state.towers
            .filter { $0.canUpgrade }
            .sorted { $0.level < $1.level }

        if let tower = upgradeable.first, effectiveSpendableHash >= tower.upgradeCost {
            return .upgradeTower(towerId: tower.id)
        }

        // THEN PLACE: Only place new towers after upgrading existing ones
        if !atPowerCeiling && !emptySlots.isEmpty {
            // Balanced priority: DPS + utility
            let priorityOrder = ["burst_protocol", "ice_shard", "trace_route", "fork_bomb", "null_pointer", "kernel_pulse"]
            for protoId in priorityOrder {
                guard profile.compiledProtocols.contains(protoId),
                      let proto = ProtocolLibrary.get(protoId) else { continue }
                let cost = BalanceConfig.Towers.placementCosts[proto.rarity] ?? 50
                if effectiveSpendableHash >= cost && state.powerAvailable >= proto.firewallStats.powerDraw {
                    if let slot = emptySlots.first {
                        return .placeTower(protocolId: protoId, slotId: slot.id)
                    }
                }
            }
        }

        return .idle
    }
}
