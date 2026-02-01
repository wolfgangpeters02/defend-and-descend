import Foundation
import CoreGraphics

// MARK: - Global Upgrades
// Purchased with Hash, affect both game modes

struct GlobalUpgrades: Codable, Equatable {
    var psuLevel: Int = 1           // Power capacity ceiling
    var cpuLevel: Int = 1           // Affects Hash generation
    var ramLevel: Int = 1           // Affects max health & efficiency regen
    var coolingLevel: Int = 1       // Affects fire rate globally
    var hddLevel: Int = 1           // Hash storage capacity

    static let maxLevel = 10

    // Explicit CodingKeys to only encode stored properties
    enum CodingKeys: String, CodingKey {
        case psuLevel, cpuLevel, ramLevel, coolingLevel, hddLevel
    }

    // MARK: - PSU (Power Capacity)

    /// Power capacity at current PSU level (in Watts)
    var powerCapacity: Int {
        return Self.powerCapacity(at: psuLevel)
    }

    /// Power capacity at a given PSU level
    static func powerCapacity(at level: Int) -> Int {
        // 450, 550, 650, 800, 1000, 1250, 1600, 2000, 2500, 3200
        let capacities = [450, 550, 650, 800, 1000, 1250, 1600, 2000, 2500, 3200]
        return capacities[min(level - 1, capacities.count - 1)]
    }

    /// PSU tier name
    static func psuTierName(at level: Int) -> String {
        let names = ["Basic", "Bronze", "Bronze+", "Silver", "Silver+", "Gold", "Gold+", "Platinum", "Platinum+", "Titanium"]
        return names[min(level - 1, names.count - 1)]
    }

    /// Cost to upgrade PSU to next level
    var psuUpgradeCost: Int? {
        return Self.psuUpgradeCost(at: psuLevel)
    }

    static func psuUpgradeCost(at level: Int) -> Int? {
        guard level < maxLevel else { return nil }
        // 15000, 35000, 75000, 150000, 300000, 600000, 1200000, 2400000, 5000000
        return Int(15000 * pow(2.0, Double(level - 1)))
    }

    // MARK: - HDD (Hash Storage)

    /// Hash storage capacity at current HDD level
    var hashStorageCapacity: Int {
        return Self.hashStorageCapacity(at: hddLevel)
    }

    /// Hash storage capacity at a given HDD level
    static func hashStorageCapacity(at level: Int) -> Int {
        // 25000, 50000, 100000, 200000, 400000, 800000, 1600000, 3200000, 6400000, 12800000
        return Int(25000 * pow(2.0, Double(level - 1)))
    }

    /// HDD tier name
    static func hddTierName(at level: Int) -> String {
        let names = ["500GB HDD", "1TB HDD", "2TB HDD", "500GB SSD", "1TB SSD", "2TB SSD", "1TB NVMe", "2TB NVMe", "4TB NVMe", "8TB NVMe"]
        return names[min(level - 1, names.count - 1)]
    }

    /// Cost to upgrade HDD to next level
    var hddUpgradeCost: Int? {
        return Self.hddUpgradeCost(at: hddLevel)
    }

    static func hddUpgradeCost(at level: Int) -> Int? {
        guard level < maxLevel else { return nil }
        // 10000, 25000, 60000, 140000, 320000, 700000, 1500000, 3200000, 7000000
        return Int(10000 * pow(2.3, Double(level - 1)))
    }

    // MARK: - CPU (Hash Generation)

    /// Hash per second at current CPU level
    var hashPerSecond: CGFloat {
        return Self.hashPerSecond(at: cpuLevel)
    }

    /// Hash per second at a given CPU level
    static func hashPerSecond(at level: Int) -> CGFloat {
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
    func canAfford(upgrade: GlobalUpgradeType, hash: Int) -> Bool {
        guard let cost = upgradeCost(for: upgrade) else { return false }
        return hash >= cost
    }

    /// Get the cost for a specific upgrade
    func upgradeCost(for upgrade: GlobalUpgradeType) -> Int? {
        switch upgrade {
        case .psu: return psuUpgradeCost
        case .cpu: return cpuUpgradeCost
        case .ram: return ramUpgradeCost
        case .cooling: return coolingUpgradeCost
        case .hdd: return hddUpgradeCost
        }
    }

    /// Get the current level for a specific upgrade
    func level(for upgrade: GlobalUpgradeType) -> Int {
        switch upgrade {
        case .psu: return psuLevel
        case .cpu: return cpuLevel
        case .ram: return ramLevel
        case .cooling: return coolingLevel
        case .hdd: return hddLevel
        }
    }

    /// Check if upgrade is at max level
    func isMaxed(_ upgrade: GlobalUpgradeType) -> Bool {
        return level(for: upgrade) >= Self.maxLevel
    }

    /// Apply an upgrade (call after deducting cost)
    mutating func upgrade(_ type: GlobalUpgradeType) {
        switch type {
        case .psu:
            psuLevel = min(psuLevel + 1, Self.maxLevel)
        case .cpu:
            cpuLevel = min(cpuLevel + 1, Self.maxLevel)
        case .ram:
            ramLevel = min(ramLevel + 1, Self.maxLevel)
        case .cooling:
            coolingLevel = min(coolingLevel + 1, Self.maxLevel)
        case .hdd:
            hddLevel = min(hddLevel + 1, Self.maxLevel)
        }
    }
}

// MARK: - Global Upgrade Type

enum GlobalUpgradeType: String, CaseIterable, Codable {
    case psu = "Power Supply"
    case cpu = "CPU Core"
    case ram = "RAM Module"
    case cooling = "Cooling System"
    case hdd = "Storage Drive"

    var icon: String {
        switch self {
        case .psu: return "bolt.fill"
        case .cpu: return "cpu.fill"
        case .ram: return "memorychip.fill"
        case .cooling: return "fan.fill"
        case .hdd: return "internaldrive.fill"
        }
    }

    var description: String {
        switch self {
        case .psu: return "Increases Power capacity for more towers"
        case .cpu: return "Increases passive Hash generation"
        case .ram: return "Increases max health and efficiency recovery"
        case .cooling: return "Increases fire rate for all Firewalls and Weapons"
        case .hdd: return "Increases max Hash storage capacity"
        }
    }

    var color: String {
        switch self {
        case .psu: return "#f59e0b"      // Amber (power)
        case .cpu: return "#00d4ff"      // Cyan
        case .ram: return "#22c55e"      // Green
        case .cooling: return "#8b5cf6"  // Purple
        case .hdd: return "#6366f1"      // Indigo
        }
    }

    /// Get the current value description at a level
    func valueDescription(at level: Int) -> String {
        switch self {
        case .psu:
            let capacity = GlobalUpgrades.powerCapacity(at: level)
            let name = GlobalUpgrades.psuTierName(at: level)
            return "\(name) | \(capacity)W"
        case .cpu:
            let hashRate = GlobalUpgrades.hashPerSecond(at: level)
            return String(format: "%.0f Ħ/sec", hashRate)
        case .ram:
            let hp = GlobalUpgrades.healthBonus(at: level)
            let regen = GlobalUpgrades.efficiencyRegenMultiplier(at: level)
            return String(format: "%.0f HP | +%.0f%% Regen", hp, (regen - 1) * 100)
        case .cooling:
            let rate = GlobalUpgrades.fireRateMultiplier(at: level)
            return String(format: "+%.0f%% Fire Rate", (rate - 1) * 100)
        case .hdd:
            let capacity = GlobalUpgrades.hashStorageCapacity(at: level)
            let name = GlobalUpgrades.hddTierName(at: level)
            return "\(name) | \(formatNumber(capacity)) Ħ"
        }
    }

    /// Format large numbers with K/M suffix
    private func formatNumber(_ value: Int) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000)
        } else if value >= 1_000 {
            return String(format: "%.0fK", Double(value) / 1_000)
        }
        return "\(value)"
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
    let hashMultiplier: CGFloat     // 1.0, 1.5, 2.0, 3.0

    let unlockCost: Int             // Hash to unlock (0 = free)

    let layout: SectorLayout
    let visualTheme: String         // "ram", "drive", "gpu"

    let duration: TimeInterval      // How long to survive (180s = 3 min)

    let gameMode: GameMode          // .arena or .dungeon
    let dungeonType: String?        // For dungeons: "cathedral", "frozen", "volcanic", "heist", "void_raid"

    /// Whether this sector is unlocked for a given Hash balance
    func canUnlock(withHash hash: Int) -> Bool {
        return hash >= unlockCost
    }

    /// Backwards compatible initializer (defaults to arena mode)
    init(id: String, name: String, subtitle: String, description: String,
         difficulty: SectorDifficulty, hashMultiplier: CGFloat, unlockCost: Int,
         layout: SectorLayout, visualTheme: String, duration: TimeInterval,
         gameMode: GameMode = .arena, dungeonType: String? = nil) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.description = description
        self.difficulty = difficulty
        self.hashMultiplier = hashMultiplier
        self.unlockCost = unlockCost
        self.layout = layout
        self.visualTheme = visualTheme
        self.duration = duration
        self.gameMode = gameMode
        self.dungeonType = dungeonType
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
        // Arena sectors
        theRam,
        theDrive,
        theGpu,
        theBios,
        // Dungeon sectors (with boss fights)
        cathedral,
        frostCaverns,
        volcanicCore,
        heistVault,
        voidRaid
    ]

    static let arenaSectors: [Sector] = [theRam, theDrive, theGpu, theBios]
    static let dungeonSectors: [Sector] = [cathedral, frostCaverns, volcanicCore, heistVault, voidRaid]

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
        hashMultiplier: 1.0,
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
        hashMultiplier: 1.5,
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
        hashMultiplier: 2.0,
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
        hashMultiplier: 3.0,
        unlockCost: 500,
        layout: .mixed,
        visualTheme: "bios",
        duration: 180
    )

    // MARK: - Dungeon Sectors (Room-based progression with boss fights)

    static let cathedral = Sector(
        id: "cathedral",
        name: "The Cathedral",
        subtitle: "Corrupted Sanctuary",
        description: "5 rooms. Fight the Void Harbinger.",
        difficulty: .hard,
        hashMultiplier: 2.5,
        unlockCost: 0,  // Free starter dungeon
        layout: .corridors,
        visualTheme: "drive",
        duration: 0,  // Dungeons don't have time limits
        gameMode: .dungeon,
        dungeonType: "cathedral"
    )

    static let frostCaverns = Sector(
        id: "frost_caverns",
        name: "Frost Caverns",
        subtitle: "Frozen Depths",
        description: "5 rooms. Defeat the Frost Titan.",
        difficulty: .hard,
        hashMultiplier: 2.5,
        unlockCost: 50,
        layout: .corridors,
        visualTheme: "ram",
        duration: 0,
        gameMode: .dungeon,
        dungeonType: "frozen"
    )

    static let volcanicCore = Sector(
        id: "volcanic_core",
        name: "Volcanic Core",
        subtitle: "Molten Depths",
        description: "5 rooms. Face the Inferno Lord.",
        difficulty: .hard,
        hashMultiplier: 3.0,
        unlockCost: 100,
        layout: .mixed,
        visualTheme: "gpu",
        duration: 0,
        gameMode: .dungeon,
        dungeonType: "volcanic"
    )

    static let heistVault = Sector(
        id: "heist_vault",
        name: "The Vault",
        subtitle: "High Security",
        description: "5 rooms. Hack the Cyberboss.",
        difficulty: .chaos,
        hashMultiplier: 4.0,
        unlockCost: 200,
        layout: .mixed,
        visualTheme: "bios",
        duration: 0,
        gameMode: .dungeon,
        dungeonType: "heist"
    )

    static let voidRaid = Sector(
        id: "void_raid",
        name: "Void Raid",
        subtitle: "Direct Assault",
        description: "Boss rush. Confront the Harbinger.",
        difficulty: .chaos,
        hashMultiplier: 5.0,
        unlockCost: 300,
        layout: .arena,
        visualTheme: "bios",
        duration: 0,
        gameMode: .dungeon,
        dungeonType: "void_raid"
    )
}
