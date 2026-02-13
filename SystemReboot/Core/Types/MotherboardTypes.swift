import Foundation
import CoreGraphics

// MARK: - Motherboard City Types
// SimCity-style hardware expansion system where players socket components to expand

// MARK: - Component Type

enum ComponentType: String, Codable, CaseIterable {
    case cpu           // The core - always installed, center of the board
    case ramSlot       // Memory - boosts tower speed/cache
    case gpuSlot       // Graphics - global damage multiplier
    case ssdBay        // Storage - save/load game states
    case hddBay        // Archive - historical stats
    case usbPort       // I/O - virus spawn point
    case lanPort       // I/O - virus spawn point (network attacks)
    case powerSupply   // PSU - required for high-power components
    case coolingFan    // Thermal - prevents overheat debuffs

    var displayName: String {
        switch self {
        case .cpu: return "CPU"
        case .ramSlot: return "RAM Slot"
        case .gpuSlot: return "GPU Slot"
        case .ssdBay: return "SSD Bay"
        case .hddBay: return "HDD Bay"
        case .usbPort: return "USB Port"
        case .lanPort: return "LAN Port"
        case .powerSupply: return "Power Supply"
        case .coolingFan: return "Cooling Fan"
        }
    }

    var isSpawnPoint: Bool {
        switch self {
        case .usbPort, .lanPort: return true
        default: return false
        }
    }
}

// MARK: - Component Bonus

enum ComponentBonus: Codable, Equatable {
    case cacheBoost(multiplier: CGFloat)      // RAM: Tower fire rate boost
    case renderBoost(multiplier: CGFloat)     // GPU: Damage multiplier
    case storageCapacity(slots: Int)          // SSD: Save slots
    case bandwidthLimit(reduction: CGFloat)   // LAN: Slow virus spawn
    case powerOutput(watts: Int)              // PSU: Power budget increase
    case coolingEfficiency(bonus: CGFloat)    // Fan: Prevents overheat

    var description: String {
        switch self {
        case .cacheBoost(let mult):
            return "+\(Int((mult - 1) * 100))% Fire Rate"
        case .renderBoost(let mult):
            return "+\(Int((mult - 1) * 100))% Damage"
        case .storageCapacity(let slots):
            return "+\(slots) Save Slots"
        case .bandwidthLimit(let reduction):
            return "-\(Int(reduction * 100))% Spawn Rate"
        case .powerOutput(let watts):
            return "+\(watts)W Budget"
        case .coolingEfficiency(let bonus):
            return "+\(Int(bonus * 100))% Cooling"
        }
    }
}

// MARK: - Motherboard Component

struct MotherboardComponent: Identifiable, Codable {
    var id: String
    var componentType: ComponentType
    var displayName: String

    // Grid position (40x40 grid on 4000x4000 canvas)
    var gridX: Int
    var gridY: Int

    // Size in grid units
    var gridWidth: Int
    var gridHeight: Int

    // State
    var isInstalled: Bool = false
    var isPowered: Bool = false

    // Requirements
    var powerRequirement: Int  // Watts needed to operate
    var installCost: Int       // Watts to unlock/install

    // Gameplay effects
    var bonus: ComponentBonus?
    var spawnPointOffset: CGPoint?  // Offset from component center for spawn point

    // Computed properties
    var position: CGPoint {
        // Convert grid position to world position (100 units per grid cell)
        CGPoint(x: CGFloat(gridX) * 100 + CGFloat(gridWidth) * 50,
                y: CGFloat(gridY) * 100 + CGFloat(gridHeight) * 50)
    }

    var bounds: CGRect {
        CGRect(x: CGFloat(gridX) * 100,
               y: CGFloat(gridY) * 100,
               width: CGFloat(gridWidth) * 100,
               height: CGFloat(gridHeight) * 100)
    }

    var brightness: CGFloat {
        isInstalled ? 1.0 : 0.15  // Ghost mode at 15% brightness
    }
}

// MARK: - System Bus

enum BusDirection: String, Codable {
    case north, south, east, west
}

struct BusSegment: Codable {
    var start: CGPoint
    var end: CGPoint
    var direction: BusDirection

    // Computed property for segment midpoint
    var midpoint: CGPoint {
        CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
    }

    // Computed property for segment length
    var length: CGFloat {
        let dx = end.x - start.x
        let dy = end.y - start.y
        return sqrt(dx * dx + dy * dy)
    }
}

enum BusType: String, Codable {
    case north      // CPU to RAM
    case south      // CPU to GPU
    case east       // CPU to Storage
    case west       // CPU to I/O
    case pcie       // High-speed expansion
    case sata       // Storage connection
}

struct SystemBus: Identifiable, Codable {
    var id: String
    var busType: BusType
    var width: CGFloat        // Visual width (32, 64, 128 lanes)
    var isActive: Bool = false

    // Path segments (Manhattan geometry - 90 degrees only)
    var segments: [BusSegment]

    // Connected components
    var connectedComponentIds: [String]

    // Computed properties
    var totalLength: CGFloat {
        segments.reduce(0) { $0 + $1.length }
    }

    var startPoint: CGPoint? {
        segments.first?.start
    }

    var endPoint: CGPoint? {
        segments.last?.end
    }
}

// MARK: - Sector

struct MotherboardSector: Identifiable, Codable {
    var id: String
    var name: String
    var description: String

    // Position and size in world coordinates
    var x: CGFloat
    var y: CGFloat
    var width: CGFloat
    var height: CGFloat

    // Components in this sector
    var componentIds: [String]

    // Visual theme
    var primaryColor: String    // Hex color
    var secondaryColor: String  // Hex color for accents

    var bounds: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }

    var center: CGPoint {
        CGPoint(x: x + width / 2, y: y + height / 2)
    }
}

// MARK: - Motherboard Configuration

struct MotherboardConfig: Codable {
    var canvasWidth: CGFloat = 4200  // 3 sectors × 1400
    var canvasHeight: CGFloat = 4200

    var sectors: [MotherboardSector]
    var components: [MotherboardComponent]
    var buses: [SystemBus]

    // Starting state
    var starterComponentIds: [String]  // Components that are installed at start

    // Power budget
    var basePowerBudget: Int = 1000    // Starting watts budget
    var maxPowerBudget: Int = 10000    // Max achievable budget
}

// MARK: - Color Palette

struct MotherboardColors {
    // PCB Substrate
    static let substrate = "#1a1a2e"      // Dark blue-black

    // Copper Traces
    static let copperTrace = "#b87333"    // Copper
    static let copperHighlight = "#d4956a" // Lighter copper for highlights

    // Active/Powered
    static let activeGlow = "#00ff88"     // Neon green
    static let powerSurge = "#44ffff"     // Cyan for power animations

    // Ghost/Locked
    static let ghostMode = "#333344"      // Dark grey
    static let lockedText = "#666688"     // Muted text color

    // Component Colors
    static let cpuCore = "#4488ff"        // Blue
    static let ramSlots = "#44ff88"       // Green
    static let gpuSlot = "#ff4444"        // Red
    static let ioPorts = "#ffaa00"        // Orange
    static let storage = "#8844ff"        // Purple

    // Silkscreen (text labels on PCB)
    static let silkscreen = "#ffffff"     // White
}

