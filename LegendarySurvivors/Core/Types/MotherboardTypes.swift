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

// MARK: - District

struct MotherboardDistrict: Identifiable, Codable {
    var id: String
    var name: String
    var description: String

    // Position and size in world coordinates
    var x: CGFloat
    var y: CGFloat
    var width: CGFloat
    var height: CGFloat

    // Components in this district
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

    var districts: [MotherboardDistrict]
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

// MARK: - Factory Methods

extension MotherboardConfig {
    /// Create the default motherboard configuration for System: Reboot
    static func createDefault() -> MotherboardConfig {
        // Create districts
        let districts = [
            MotherboardDistrict(
                id: "cpu_district",
                name: "CPU District",
                description: "The core processing unit - defend at all costs",
                x: 1800, y: 1800, width: 400, height: 400,
                componentIds: ["cpu_main"],
                primaryColor: MotherboardColors.cpuCore,
                secondaryColor: MotherboardColors.activeGlow
            ),
            MotherboardDistrict(
                id: "ram_district",
                name: "RAM District",
                description: "Memory modules - boost tower performance",
                x: 1600, y: 3000, width: 800, height: 600,
                componentIds: ["ram_1", "ram_2", "ram_3", "ram_4"],
                primaryColor: MotherboardColors.ramSlots,
                secondaryColor: MotherboardColors.activeGlow
            ),
            MotherboardDistrict(
                id: "gpu_district",
                name: "GPU District",
                description: "Graphics processing - massive damage boost",
                x: 1600, y: 400, width: 800, height: 600,
                componentIds: ["gpu_main"],
                primaryColor: MotherboardColors.gpuSlot,
                secondaryColor: MotherboardColors.powerSurge
            ),
            MotherboardDistrict(
                id: "storage_district",
                name: "Storage Bay",
                description: "SSD and HDD - save your progress",
                x: 3000, y: 1600, width: 600, height: 800,
                componentIds: ["ssd_1", "hdd_1"],
                primaryColor: MotherboardColors.storage,
                secondaryColor: MotherboardColors.activeGlow
            ),
            MotherboardDistrict(
                id: "io_district",
                name: "I/O Panel",
                description: "External ports - virus entry points",
                x: 400, y: 1600, width: 600, height: 800,
                componentIds: ["usb_1", "usb_2", "lan_1"],
                primaryColor: MotherboardColors.ioPorts,
                secondaryColor: MotherboardColors.activeGlow
            )
        ]

        // Create components
        let components = [
            // CPU - always installed
            MotherboardComponent(
                id: "cpu_main",
                componentType: .cpu,
                displayName: "Central Processing Unit",
                gridX: 18, gridY: 18,
                gridWidth: 4, gridHeight: 4,
                isInstalled: true,
                isPowered: true,
                powerRequirement: 0,
                installCost: 0,
                bonus: nil,
                spawnPointOffset: nil
            ),
            // RAM slots
            MotherboardComponent(
                id: "ram_1",
                componentType: .ramSlot,
                displayName: "DDR5 Slot 1",
                gridX: 17, gridY: 32,
                gridWidth: 2, gridHeight: 4,
                isInstalled: false,
                isPowered: false,
                powerRequirement: 50,
                installCost: 2000,
                bonus: .cacheBoost(multiplier: 1.1),
                spawnPointOffset: nil
            ),
            MotherboardComponent(
                id: "ram_2",
                componentType: .ramSlot,
                displayName: "DDR5 Slot 2",
                gridX: 19, gridY: 32,
                gridWidth: 2, gridHeight: 4,
                isInstalled: false,
                isPowered: false,
                powerRequirement: 50,
                installCost: 3000,
                bonus: .cacheBoost(multiplier: 1.1),
                spawnPointOffset: nil
            ),
            MotherboardComponent(
                id: "ram_3",
                componentType: .ramSlot,
                displayName: "DDR5 Slot 3",
                gridX: 21, gridY: 32,
                gridWidth: 2, gridHeight: 4,
                isInstalled: false,
                isPowered: false,
                powerRequirement: 50,
                installCost: 4000,
                bonus: .cacheBoost(multiplier: 1.1),
                spawnPointOffset: nil
            ),
            MotherboardComponent(
                id: "ram_4",
                componentType: .ramSlot,
                displayName: "DDR5 Slot 4",
                gridX: 23, gridY: 32,
                gridWidth: 2, gridHeight: 4,
                isInstalled: false,
                isPowered: false,
                powerRequirement: 50,
                installCost: 5000,
                bonus: .cacheBoost(multiplier: 1.1),
                spawnPointOffset: nil
            ),
            // GPU
            MotherboardComponent(
                id: "gpu_main",
                componentType: .gpuSlot,
                displayName: "PCIe x16 Graphics",
                gridX: 17, gridY: 6,
                gridWidth: 6, gridHeight: 3,
                isInstalled: false,
                isPowered: false,
                powerRequirement: 200,
                installCost: 10000,
                bonus: .renderBoost(multiplier: 1.5),
                spawnPointOffset: nil
            ),
            // Storage
            MotherboardComponent(
                id: "ssd_1",
                componentType: .ssdBay,
                displayName: "NVMe SSD",
                gridX: 32, gridY: 18,
                gridWidth: 3, gridHeight: 2,
                isInstalled: false,
                isPowered: false,
                powerRequirement: 20,
                installCost: 5000,
                bonus: .storageCapacity(slots: 3),
                spawnPointOffset: nil
            ),
            MotherboardComponent(
                id: "hdd_1",
                componentType: .hddBay,
                displayName: "Archive HDD",
                gridX: 32, gridY: 21,
                gridWidth: 3, gridHeight: 3,
                isInstalled: false,
                isPowered: false,
                powerRequirement: 30,
                installCost: 3000,
                bonus: .storageCapacity(slots: 5),
                spawnPointOffset: nil
            ),
            // I/O Ports (spawn points)
            MotherboardComponent(
                id: "usb_1",
                componentType: .usbPort,
                displayName: "USB Port 1",
                gridX: 4, gridY: 18,
                gridWidth: 2, gridHeight: 2,
                isInstalled: true,  // Start with one port open
                isPowered: true,
                powerRequirement: 5,
                installCost: 0,
                bonus: nil,
                spawnPointOffset: CGPoint(x: -50, y: 0)
            ),
            MotherboardComponent(
                id: "usb_2",
                componentType: .usbPort,
                displayName: "USB Port 2",
                gridX: 4, gridY: 21,
                gridWidth: 2, gridHeight: 2,
                isInstalled: false,
                isPowered: false,
                powerRequirement: 5,
                installCost: 1000,
                bonus: nil,
                spawnPointOffset: CGPoint(x: -50, y: 0)
            ),
            MotherboardComponent(
                id: "lan_1",
                componentType: .lanPort,
                displayName: "Ethernet Port",
                gridX: 4, gridY: 24,
                gridWidth: 2, gridHeight: 2,
                isInstalled: false,
                isPowered: false,
                powerRequirement: 10,
                installCost: 2000,
                bonus: .bandwidthLimit(reduction: 0.1),
                spawnPointOffset: CGPoint(x: -50, y: 0)
            )
        ]

        // Create buses
        let buses = [
            SystemBus(
                id: "west_bus",
                busType: .west,
                width: 64,
                isActive: true,
                segments: [
                    BusSegment(start: CGPoint(x: 600, y: 2000),
                              end: CGPoint(x: 1800, y: 2000),
                              direction: .east)
                ],
                connectedComponentIds: ["cpu_main", "usb_1", "usb_2", "lan_1"]
            ),
            SystemBus(
                id: "north_bus",
                busType: .north,
                width: 64,
                isActive: false,
                segments: [
                    BusSegment(start: CGPoint(x: 2000, y: 2200),
                              end: CGPoint(x: 2000, y: 3000),
                              direction: .north)
                ],
                connectedComponentIds: ["cpu_main", "ram_1", "ram_2", "ram_3", "ram_4"]
            ),
            SystemBus(
                id: "south_bus",
                busType: .south,
                width: 128,  // Wider for GPU
                isActive: false,
                segments: [
                    BusSegment(start: CGPoint(x: 2000, y: 1800),
                              end: CGPoint(x: 2000, y: 1000),
                              direction: .south)
                ],
                connectedComponentIds: ["cpu_main", "gpu_main"]
            ),
            SystemBus(
                id: "east_bus",
                busType: .east,
                width: 32,
                isActive: false,
                segments: [
                    BusSegment(start: CGPoint(x: 2200, y: 2000),
                              end: CGPoint(x: 3200, y: 2000),
                              direction: .east)
                ],
                connectedComponentIds: ["cpu_main", "ssd_1", "hdd_1"]
            )
        ]

        return MotherboardConfig(
            canvasWidth: 4200,  // 3 sectors × 1400
            canvasHeight: 4200,
            districts: districts,
            components: components,
            buses: buses,
            starterComponentIds: ["cpu_main", "usb_1"],
            basePowerBudget: 1000,
            maxPowerBudget: 10000
        )
    }
}
