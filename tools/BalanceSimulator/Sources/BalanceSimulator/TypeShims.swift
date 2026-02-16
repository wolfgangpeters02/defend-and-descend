// TypeShims.swift
// Minimal type definitions required by BalanceConfig.swift
// These match the interfaces used in the app (GameTypes.swift, ComponentTypes.swift)
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

// MARK: - ComponentLevels (from ComponentTypes.swift)
// Only stored properties needed — BalanceConfig.Simulation uses the memberwise init.

struct ComponentLevels: Codable, Equatable {
    var power: Int = 1
    var psu: Int { power }  // Alias for power
    var storage: Int = 1
    var ram: Int = 1
    var gpu: Int = 1
    var cache: Int = 1
    var expansion: Int = 1
    var io: Int = 1
    var network: Int = 1
    var cpu: Int = 1

    /// Network hash multiplier (mirrors ComponentTypes.swift computed property)
    var hashMultiplier: CGFloat {
        BalanceConfig.Components.networkHashMultiplier(at: network)
    }
}

// MARK: - TDMapID (from GameTypes.swift)

enum TDMapID: String {
    case grasslands, volcano, iceCave, castle, space, temple
}
