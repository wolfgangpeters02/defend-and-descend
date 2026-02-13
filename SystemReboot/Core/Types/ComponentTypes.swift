import Foundation
import CoreGraphics

// MARK: - Component Types
// Sector-based upgrade system - each sector has an upgradable component
// Fixed unlock order: PSU → Storage → RAM → GPU → Cache → Expansion → I/O → Network → CPU

// MARK: - Component Type Enum

/// All upgradable components in the game
enum UpgradeableComponent: String, CaseIterable, Codable, Identifiable {
    case psu = "psu"
    case storage = "storage"
    case ram = "ram"
    case gpu = "gpu"
    case cache = "cache"
    case expansion = "expansion"
    case io = "io"
    case network = "network"
    case cpu = "cpu"

    var id: String { rawValue }

    // MARK: - Display Properties

    /// Localized display name
    var displayName: String {
        switch self {
        case .psu: return L10n.Component.psuName
        case .storage: return L10n.Component.storageName
        case .ram: return L10n.Component.ramName
        case .gpu: return L10n.Component.gpuName
        case .cache: return L10n.Component.cacheName
        case .expansion: return L10n.Component.expansionName
        case .io: return L10n.Component.ioName
        case .network: return L10n.Component.networkName
        case .cpu: return L10n.Component.cpuName
        }
    }

    /// Localized effect description
    var effectDescription: String {
        switch self {
        case .psu: return L10n.Component.psuEffect
        case .storage: return L10n.Component.storageEffect
        case .ram: return L10n.Component.ramEffect
        case .gpu: return L10n.Component.gpuEffect
        case .cache: return L10n.Component.cacheEffect
        case .expansion: return L10n.Component.expansionEffect
        case .io: return L10n.Component.ioEffect
        case .network: return L10n.Component.networkEffect
        case .cpu: return L10n.Component.cpuEffect
        }
    }

    /// Associated sector ID for this component
    var sectorId: SectorID {
        switch self {
        case .psu: return .power
        case .storage: return .storage
        case .ram: return .ram
        case .gpu: return .gpu
        case .cache: return .cache
        case .expansion: return .expansion
        case .io: return .io
        case .network: return .network
        case .cpu: return .cpu
        }
    }

    /// UI color hex for this component
    var color: String {
        switch self {
        case .psu: return "#f59e0b"       // Amber (power)
        case .storage: return "#6366f1"   // Indigo
        case .ram: return "#22c55e"       // Green
        case .gpu: return "#ef4444"       // Red
        case .cache: return "#8b5cf6"     // Purple
        case .expansion: return "#14b8a6" // Teal
        case .io: return "#f97316"        // Orange
        case .network: return "#3b82f6"   // Blue
        case .cpu: return "#00d4ff"       // Cyan
        }
    }

    /// SF Symbol for this component
    var sfSymbol: String {
        switch self {
        case .psu: return "bolt.fill"
        case .storage: return "internaldrive.fill"
        case .ram: return "memorychip.fill"
        case .gpu: return "rectangle.3.group.fill"
        case .cache: return "cpu.fill"
        case .expansion: return "rectangle.expand.vertical"
        case .io: return "cable.connector"
        case .network: return "network"
        case .cpu: return "cpu"
        }
    }

    // MARK: - Unlock Order

    /// Fixed unlock order index (0 = starter, always unlocked)
    /// Must match BalanceConfig.SectorUnlock.unlockOrder
    var unlockOrder: Int {
        switch self {
        case .psu: return 0
        case .ram: return 1
        case .gpu: return 2
        case .cache: return 3
        case .storage: return 4
        case .expansion: return 5
        case .network: return 6
        case .io: return 7
        case .cpu: return 8
        }
    }

    /// Component that must be defeated to unlock this one (nil for starter)
    /// Must match BalanceConfig.SectorUnlock.unlockOrder
    var prerequisiteComponent: UpgradeableComponent? {
        switch self {
        case .psu: return nil        // Starter
        case .ram: return .psu
        case .gpu: return .ram
        case .cache: return .gpu
        case .storage: return .cache
        case .expansion: return .storage
        case .network: return .expansion
        case .io: return .network
        case .cpu: return .io
        }
    }

    /// Get component by unlock order
    static func byUnlockOrder(_ order: Int) -> UpgradeableComponent? {
        allCases.first { $0.unlockOrder == order }
    }

    // MARK: - Effect Calculations

    /// Get effect value at a given level
    func effectValue(at level: Int) -> String {
        switch self {
        case .psu:
            let watts = BalanceConfig.Components.psuCapacity(at: level)
            return L10n.Component.watts(watts)

        case .storage:
            let capacity = BalanceConfig.Components.storageCapacity(at: level)
            let offlineRate = Int(BalanceConfig.Components.storageOfflineRate(at: level) * 100)
            return "\(L10n.Component.hashCapacity(capacity)), \(L10n.Component.offlineRate(offlineRate))"

        case .ram:
            let multiplier = BalanceConfig.Components.ramEfficiencyRegen(at: level)
            return L10n.Component.multiplier(String(format: "%.1f", multiplier))

        case .gpu:
            let multiplier = BalanceConfig.Components.gpuDamageMultiplier(at: level)
            return L10n.Component.multiplier(String(format: "%.2f", multiplier))

        case .cache:
            let multiplier = BalanceConfig.Components.cacheAttackSpeedMultiplier(at: level)
            return L10n.Component.multiplier(String(format: "%.2f", multiplier))

        case .expansion:
            let slots = BalanceConfig.Components.expansionExtraSlots(at: level)
            return L10n.Component.extraSlots(slots)

        case .io:
            let multiplier = BalanceConfig.Components.ioPickupRadiusMultiplier(at: level)
            return L10n.Component.multiplier(String(format: "%.1f", multiplier))

        case .network:
            let multiplier = BalanceConfig.Components.networkHashMultiplier(at: level)
            return L10n.Component.multiplier(String(format: "%.2f", multiplier))

        case .cpu:
            let hashPerSec = BalanceConfig.Components.cpuHashPerSecond(at: level)
            return L10n.Component.hashPerSecond(String(format: "%.1f", hashPerSec))
        }
    }

    /// Get upgrade cost at a given level (nil if max level)
    func upgradeCost(at level: Int) -> Int? {
        BalanceConfig.Components.upgradeCost(for: rawValue, at: level)
    }

    /// Get base cost for this component
    var baseCost: Int {
        BalanceConfig.Components.baseCost(for: rawValue)
    }
}

// MARK: - Component Levels

/// Stores all component levels for a player
struct ComponentLevels: Codable, Equatable {
    var psu: Int = 1
    var storage: Int = 1
    var ram: Int = 1
    var gpu: Int = 1
    var cache: Int = 1
    var expansion: Int = 1
    var io: Int = 1
    var network: Int = 1
    var cpu: Int = 1

    static let maxLevel = BalanceConfig.Components.maxLevel

    // MARK: - Subscript Access

    /// Get/set level by component type
    subscript(_ type: UpgradeableComponent) -> Int {
        get {
            switch type {
            case .psu: return psu
            case .storage: return storage
            case .ram: return ram
            case .gpu: return gpu
            case .cache: return cache
            case .expansion: return expansion
            case .io: return io
            case .network: return network
            case .cpu: return cpu
            }
        }
        set {
            let clamped = min(max(newValue, 1), Self.maxLevel)
            switch type {
            case .psu: psu = clamped
            case .storage: storage = clamped
            case .ram: ram = clamped
            case .gpu: gpu = clamped
            case .cache: cache = clamped
            case .expansion: expansion = clamped
            case .io: io = clamped
            case .network: network = clamped
            case .cpu: cpu = clamped
            }
        }
    }

    // MARK: - Computed Effects

    /// Power capacity from PSU level
    var powerCapacity: Int {
        BalanceConfig.Components.psuCapacity(at: psu)
    }

    /// Hash storage capacity from Storage level
    var hashStorageCapacity: Int {
        BalanceConfig.Components.storageCapacity(at: storage)
    }

    /// Offline earning rate from Storage level
    var offlineEarningRate: CGFloat {
        BalanceConfig.Components.storageOfflineRate(at: storage)
    }

    /// Efficiency regen multiplier from RAM level
    var efficiencyRegenMultiplier: CGFloat {
        BalanceConfig.Components.ramEfficiencyRegen(at: ram)
    }

    /// Tower damage multiplier from GPU level
    var towerDamageMultiplier: CGFloat {
        BalanceConfig.Components.gpuDamageMultiplier(at: gpu)
    }

    /// Attack speed multiplier from Cache level
    var attackSpeedMultiplier: CGFloat {
        BalanceConfig.Components.cacheAttackSpeedMultiplier(at: cache)
    }

    /// Extra tower slots per sector from Expansion level
    var extraTowerSlots: Int {
        BalanceConfig.Components.expansionExtraSlots(at: expansion)
    }

    /// Pickup radius multiplier from I/O level
    var pickupRadiusMultiplier: CGFloat {
        BalanceConfig.Components.ioPickupRadiusMultiplier(at: io)
    }

    /// Global hash multiplier from Network level
    var hashMultiplier: CGFloat {
        BalanceConfig.Components.networkHashMultiplier(at: network)
    }

    /// Hash per second from CPU level
    var hashPerSecond: CGFloat {
        BalanceConfig.Components.cpuHashPerSecond(at: cpu)
    }

    /// Health bonus from RAM level (for Active/Boss mode)
    var healthBonus: CGFloat {
        BalanceConfig.Components.ramBaseHealth + CGFloat(ram - 1) * BalanceConfig.Components.ramHealthPerLevel
    }

    // MARK: - Tier Name Helpers

    /// PSU tier display name
    static func psuTierName(at level: Int) -> String {
        let names = ["Basic", "Bronze", "Bronze+", "Silver", "Silver+", "Gold", "Gold+", "Platinum", "Platinum+", "Titanium"]
        return names[min(level - 1, names.count - 1)]
    }

    /// Storage tier display name
    static func storageTierName(at level: Int) -> String {
        let names = ["500GB HDD", "1TB HDD", "2TB HDD", "500GB SSD", "1TB SSD", "2TB SSD", "1TB NVMe", "2TB NVMe", "4TB NVMe", "8TB NVMe"]
        return names[min(level - 1, names.count - 1)]
    }

    // MARK: - Upgrade Helpers

    /// Check if component can be upgraded
    func canUpgrade(_ type: UpgradeableComponent) -> Bool {
        self[type] < Self.maxLevel
    }

    /// Get upgrade cost for a component
    func upgradeCost(for type: UpgradeableComponent) -> Int? {
        type.upgradeCost(at: self[type])
    }

    /// Upgrade a component (mutating)
    mutating func upgrade(_ type: UpgradeableComponent) {
        guard canUpgrade(type) else { return }
        self[type] += 1
    }
}

// MARK: - Unlocked Components Tracker

/// Tracks which components have been unlocked via boss defeats
struct UnlockedComponents: Codable, Equatable {
    /// Number of sector bosses defeated (determines unlock progress)
    var defeatedBossCount: Int = 0

    /// Check if a component is unlocked
    func isUnlocked(_ type: UpgradeableComponent) -> Bool {
        // PSU (order 0) is always unlocked
        // Each subsequent component unlocks after defeating the previous boss
        return type.unlockOrder <= defeatedBossCount
    }

    /// Get all unlocked components
    var unlockedComponents: [UpgradeableComponent] {
        UpgradeableComponent.allCases.filter { isUnlocked($0) }
    }

    /// Get next component to unlock (nil if all unlocked)
    var nextToUnlock: UpgradeableComponent? {
        UpgradeableComponent.byUnlockOrder(defeatedBossCount + 1)
    }

    /// Record a boss defeat (unlocks next component)
    mutating func recordBossDefeat() {
        if defeatedBossCount < UpgradeableComponent.allCases.count - 1 {
            defeatedBossCount += 1
        }
    }
}
