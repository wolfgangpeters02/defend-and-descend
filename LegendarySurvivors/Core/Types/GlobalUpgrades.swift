import Foundation
import CoreGraphics

// MARK: - Global Upgrades
// Purchased with Watts, affect both game modes

struct GlobalUpgrades: Codable, Equatable {
    var cpuLevel: Int = 1           // Affects Watts generation
    var ramLevel: Int = 1           // Affects max health & efficiency regen
    var coolingLevel: Int = 1       // Affects fire rate globally

    static let maxLevel = 10

    // Explicit CodingKeys to only encode stored properties
    enum CodingKeys: String, CodingKey {
        case cpuLevel, ramLevel, coolingLevel
    }

    // MARK: - CPU (Watts Generation)

    /// Watts per second at current CPU level
    var wattsPerSecond: CGFloat {
        return Self.wattsPerSecond(at: cpuLevel)
    }

    /// Watts per second at a given CPU level
    static func wattsPerSecond(at level: Int) -> CGFloat {
        // 10, 15, 22, 33, 50, 75, 112, 168, 252, 378
        let base: CGFloat = 10
        return base * pow(1.5, CGFloat(level - 1))
    }

    /// Cost to upgrade CPU to next level
    var cpuUpgradeCost: Int? {
        return Self.cpuUpgradeCost(at: cpuLevel)
    }

    static func cpuUpgradeCost(at level: Int) -> Int? {
        guard level < maxLevel else { return nil }
        // 1000, 2500, 5000, 10000, 20000, 40000, 80000, 160000, 320000
        return Int(1000 * pow(2.0, Double(level - 1)))
    }

    // MARK: - RAM (Health & Efficiency)

    /// Health bonus from RAM level (for Active mode)
    var healthBonus: CGFloat {
        return Self.healthBonus(at: ramLevel)
    }

    /// Health at a given RAM level
    static func healthBonus(at level: Int) -> CGFloat {
        // Base 100, then +20 per level: 100, 120, 140, 160, 180, 200, 220, 240, 260, 280
        return 100 + CGFloat(level - 1) * 20
    }

    /// Efficiency regen rate multiplier
    var efficiencyRegenMultiplier: CGFloat {
        return Self.efficiencyRegenMultiplier(at: ramLevel)
    }

    /// Efficiency regen multiplier at a given RAM level
    static func efficiencyRegenMultiplier(at level: Int) -> CGFloat {
        // 1.0, 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9
        return 1.0 + CGFloat(level - 1) * 0.1
    }

    /// Cost to upgrade RAM to next level
    var ramUpgradeCost: Int? {
        return Self.ramUpgradeCost(at: ramLevel)
    }

    static func ramUpgradeCost(at level: Int) -> Int? {
        guard level < maxLevel else { return nil }
        // 1500, 3500, 8000, 18000, 40000, 90000, 200000, 450000, 1000000
        return Int(1500 * pow(2.25, Double(level - 1)))
    }

    // MARK: - Cooling (Fire Rate)

    /// Global fire rate multiplier
    var fireRateMultiplier: CGFloat {
        return Self.fireRateMultiplier(at: coolingLevel)
    }

    /// Fire rate multiplier at a given Cooling level
    static func fireRateMultiplier(at level: Int) -> CGFloat {
        // 1.0, 1.05, 1.10, 1.15, 1.20, 1.25, 1.30, 1.35, 1.40, 1.45
        return 1.0 + CGFloat(level - 1) * 0.05
    }

    /// Cost to upgrade Cooling to next level
    var coolingUpgradeCost: Int? {
        return Self.coolingUpgradeCost(at: coolingLevel)
    }

    static func coolingUpgradeCost(at level: Int) -> Int? {
        guard level < maxLevel else { return nil }
        // 2000, 5000, 12000, 30000, 75000, 180000, 450000, 1100000, 2700000
        return Int(2000 * pow(2.5, Double(level - 1)))
    }

    // MARK: - Upgrade Actions

    /// Check if a specific upgrade can be afforded
    func canAfford(upgrade: GlobalUpgradeType, watts: Int) -> Bool {
        guard let cost = upgradeCost(for: upgrade) else { return false }
        return watts >= cost
    }

    /// Get the cost for a specific upgrade
    func upgradeCost(for upgrade: GlobalUpgradeType) -> Int? {
        switch upgrade {
        case .cpu: return cpuUpgradeCost
        case .ram: return ramUpgradeCost
        case .cooling: return coolingUpgradeCost
        }
    }

    /// Get the current level for a specific upgrade
    func level(for upgrade: GlobalUpgradeType) -> Int {
        switch upgrade {
        case .cpu: return cpuLevel
        case .ram: return ramLevel
        case .cooling: return coolingLevel
        }
    }

    /// Check if upgrade is at max level
    func isMaxed(_ upgrade: GlobalUpgradeType) -> Bool {
        return level(for: upgrade) >= Self.maxLevel
    }

    /// Apply an upgrade (call after deducting cost)
    mutating func upgrade(_ type: GlobalUpgradeType) {
        switch type {
        case .cpu:
            cpuLevel = min(cpuLevel + 1, Self.maxLevel)
        case .ram:
            ramLevel = min(ramLevel + 1, Self.maxLevel)
        case .cooling:
            coolingLevel = min(coolingLevel + 1, Self.maxLevel)
        }
    }
}

// MARK: - Global Upgrade Type

enum GlobalUpgradeType: String, CaseIterable, Codable {
    case cpu = "CPU Core"
    case ram = "RAM Module"
    case cooling = "Cooling System"

    var icon: String {
        switch self {
        case .cpu: return "cpu.fill"
        case .ram: return "memorychip.fill"
        case .cooling: return "fan.fill"
        }
    }

    var description: String {
        switch self {
        case .cpu: return "Increases passive Watts generation"
        case .ram: return "Increases max health and efficiency recovery"
        case .cooling: return "Increases fire rate for all Firewalls and Weapons"
        }
    }

    var color: String {
        switch self {
        case .cpu: return "#00d4ff"      // Cyan
        case .ram: return "#22c55e"      // Green
        case .cooling: return "#8b5cf6"  // Purple
        }
    }

    /// Get the current value description at a level
    func valueDescription(at level: Int) -> String {
        switch self {
        case .cpu:
            let watts = GlobalUpgrades.wattsPerSecond(at: level)
            return String(format: "%.0f Watts/sec", watts)
        case .ram:
            let hp = GlobalUpgrades.healthBonus(at: level)
            let regen = GlobalUpgrades.efficiencyRegenMultiplier(at: level)
            return String(format: "%.0f HP | +%.0f%% Regen", hp, (regen - 1) * 100)
        case .cooling:
            let rate = GlobalUpgrades.fireRateMultiplier(at: level)
            return String(format: "+%.0f%% Fire Rate", (rate - 1) * 100)
        }
    }

    /// Get the next level value description
    func nextValueDescription(at level: Int) -> String? {
        guard level < GlobalUpgrades.maxLevel else { return nil }
        return valueDescription(at: level + 1)
    }
}

// MARK: - Sector (Debug Mode Levels)

struct Sector: Identifiable, Codable, Equatable {
    let id: String                  // "ram", "drive", "gpu"
    let name: String                // "The RAM"
    let subtitle: String            // "Memory Banks"
    let description: String         // "Open arena, swarm survival"

    let difficulty: SectorDifficulty
    let dataMultiplier: CGFloat     // 1.0, 1.5, 2.0, 3.0

    let unlockCost: Int             // Data to unlock (0 = free)

    let layout: SectorLayout
    let visualTheme: String         // "ram", "drive", "gpu"

    let duration: TimeInterval      // How long to survive (180s = 3 min)

    /// Whether this sector is unlocked for a given data balance
    func canUnlock(withData data: Int) -> Bool {
        return data >= unlockCost
    }
}

enum SectorDifficulty: String, Codable {
    case easy
    case medium
    case hard
    case chaos

    var displayName: String {
        rawValue.capitalized
    }

    var color: String {
        switch self {
        case .easy: return "#22c55e"      // Green
        case .medium: return "#f59e0b"    // Amber
        case .hard: return "#ef4444"      // Red
        case .chaos: return "#a855f7"     // Purple
        }
    }
}

enum SectorLayout: String, Codable {
    case arena                      // Open space, no walls
    case corridors                  // Narrow passages
    case mixed                      // Rooms connected by corridors
}

// MARK: - Sector Library

struct SectorLibrary {
    static let all: [Sector] = [
        theRam,
        theDrive,
        theGpu,
        theBios
    ]

    static func get(_ id: String) -> Sector? {
        return all.first { $0.id == id }
    }

    /// Starting sector (always unlocked)
    /// Note: Must match PlayerProfile.defaultSectorId
    static let starterSectorId = "ram"

    // MARK: - Sector Definitions

    static let theRam = Sector(
        id: "ram",
        name: "The RAM",
        subtitle: "Memory Banks",
        description: "Open arena. Pure swarm survival.",
        difficulty: .easy,
        dataMultiplier: 1.0,
        unlockCost: 0,
        layout: .arena,
        visualTheme: "ram",
        duration: 180
    )

    static let theDrive = Sector(
        id: "drive",
        name: "The Drive",
        subtitle: "Data Storage",
        description: "Narrow corridors. Choke point tactics.",
        difficulty: .medium,
        dataMultiplier: 1.5,
        unlockCost: 100,
        layout: .corridors,
        visualTheme: "drive",
        duration: 180
    )

    static let theGpu = Sector(
        id: "gpu",
        name: "The GPU",
        subtitle: "Graphics Core",
        description: "Mixed terrain. Fast enemies.",
        difficulty: .hard,
        dataMultiplier: 2.0,
        unlockCost: 300,
        layout: .mixed,
        visualTheme: "gpu",
        duration: 180
    )

    static let theBios = Sector(
        id: "bios",
        name: "The BIOS",
        subtitle: "System Core",
        description: "Glitched chaos. Unpredictable spawns.",
        difficulty: .chaos,
        dataMultiplier: 3.0,
        unlockCost: 500,
        layout: .mixed,
        visualTheme: "bios",
        duration: 180
    )
}
