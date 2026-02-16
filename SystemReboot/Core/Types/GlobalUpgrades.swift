import Foundation
import CoreGraphics

// MARK: - Legacy Global Upgrades
// Minimal struct kept only for PlayerProfile Codable backward compatibility.
// All game logic uses ComponentLevels (see ComponentTypes.swift).

struct LegacyGlobalUpgrades: Codable, Equatable {
    var psuLevel: Int = 1
    var cpuLevel: Int = 1
    var ramLevel: Int = 1
    var coolingLevel: Int = 1
    var hddLevel: Int = 1
}
