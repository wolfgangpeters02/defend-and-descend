// TypeShims.swift
// Minimal type definitions required by BalanceConfig.swift
// These match the interfaces used in the app (GameTypes.swift, GlobalUpgrades.swift)
// but contain only what BalanceConfig needs to compile.

import Foundation
import CoreGraphics

// MARK: - Rarity (from GameTypes.swift)

enum Rarity: String, Codable, Hashable {
    case common
    case rare
    case epic
    case legendary
}

// MARK: - BossDifficulty (from GameTypes.swift)

enum BossDifficulty: String, Codable, CaseIterable, Hashable {
    case easy = "Easy"
    case normal = "Normal"
    case hard = "Hard"
    case nightmare = "Nightmare"
}

// MARK: - GlobalUpgrades (from GlobalUpgrades.swift)
// Only stored properties needed — BalanceConfig.Simulation uses the memberwise init.

struct GlobalUpgrades: Codable, Equatable {
    var psuLevel: Int = 1
    var cpuLevel: Int = 1
    var ramLevel: Int = 1
    var coolingLevel: Int = 1
    var hddLevel: Int = 1
}
