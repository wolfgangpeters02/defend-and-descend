import Foundation
import CoreGraphics

// MARK: - Mega-Board Types
// Multi-sector grid system for the expandable Motherboard map
// Players unlock sectors by spending Hash to decrypt encryption gates
//
// Dependencies:
// - BusDirection from MotherboardTypes.swift
// - SectorID from EntityIDs.swift

// MARK: - Sector Theme

/// Visual theme for a sector
enum SectorTheme: String, Codable, CaseIterable {
    case processing   // CPU/Cache - Blue tones
    case memory       // RAM - Green tones
    case graphics     // GPU - Red/Orange tones
    case storage      // SSD/HDD - Purple tones
    case io           // USB/LAN - Orange/Yellow tones
    case network      // Network - Cyan tones
    case power        // PSU - Yellow/Gold tones

    /// Primary color hex for the theme
    var primaryColorHex: String {
        switch self {
        case .processing: return "#4488ff"
        case .memory: return "#44ff88"
        case .graphics: return "#ff4444"
        case .storage: return "#8844ff"
        case .io: return "#ffaa00"
        case .network: return "#00ffff"
        case .power: return "#ffdd00"
        }
    }

    /// Glow color hex for active elements
    var glowColorHex: String {
        switch self {
        case .processing: return "#66aaff"
        case .memory: return "#66ffaa"
        case .graphics: return "#ff6666"
        case .storage: return "#aa66ff"
        case .io: return "#ffcc44"
        case .network: return "#44ffff"
        case .power: return "#ffee44"
        }
    }
}

// MARK: - Mega-Board Sector

/// A sector in the mega-board grid
/// Sectors can be locked (requiring decrypt) or unlocked
struct MegaBoardSector: Identifiable, Codable, Equatable {
    var id: String                          // Matches SectorID raw value
    var displayName: String
    var description: String

    // Grid position (0-based)
    var gridX: Int
    var gridY: Int

    // Size in world units
    var width: CGFloat
    var height: CGFloat

    // Visual theme
    var theme: SectorTheme

    // Unlock requirements
    var unlockCost: Int                     // Cost in Hash to decrypt
    var prerequisiteSectorIds: [String]     // Must unlock these first

    // Special flags
    var isStarterSector: Bool               // Free at start
    var hasCore: Bool                       // Contains the CPU core to defend

    // Computed: World position (based on grid and sector size)
    var worldX: CGFloat {
        CGFloat(gridX) * width
    }

    var worldY: CGFloat {
        CGFloat(gridY) * height
    }

    var bounds: CGRect {
        CGRect(x: worldX, y: worldY, width: width, height: height)
    }

    var center: CGPoint {
        CGPoint(x: worldX + width / 2, y: worldY + height / 2)
    }

    static func == (lhs: MegaBoardSector, rhs: MegaBoardSector) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Data Bus Connection

/// Connection between two sectors (enemy path)
struct DataBusConnection: Identifiable, Codable {
    var id: String
    var fromSectorId: String
    var toSectorId: String
    var direction: BusDirection             // Uses existing BusDirection from MotherboardTypes

    // Path segments (waypoints in world coordinates)
    var waypoints: [CGPoint]

    // Visual properties
    var busWidth: CGFloat = 32              // Width of the data bus trace

    /// Whether this connection is active (both sectors unlocked)
    func isActive(unlockedSectorIds: Set<String>) -> Bool {
        unlockedSectorIds.contains(fromSectorId) && unlockedSectorIds.contains(toSectorId)
    }
}

// MARK: - Encryption Gate

/// Gate that blocks access to a locked sector
/// Player must spend Hash to decrypt and unlock the sector
struct EncryptionGate: Identifiable, Codable {
    var id: String
    var sectorId: String                    // The sector this gate protects
    var position: CGPoint                   // World position of the gate

    // Gate state (computed at runtime, not persisted)
    var isDecrypted: Bool = false

    // Visual properties
    var gateWidth: CGFloat = 80
    var gateHeight: CGFloat = 120

    var bounds: CGRect {
        CGRect(
            x: position.x - gateWidth / 2,
            y: position.y - gateHeight / 2,
            width: gateWidth,
            height: gateHeight
        )
    }
}

// MARK: - Mega-Board Configuration

/// Complete configuration for the mega-board system
struct MegaBoardConfig: Codable {
    // Grid dimensions
    var gridColumns: Int = 3
    var gridRows: Int = 3

    // Sector size (all sectors same size for uniform grid)
    var sectorWidth: CGFloat = 1400
    var sectorHeight: CGFloat = 1400

    // Total canvas size (computed)
    var totalWidth: CGFloat {
        CGFloat(gridColumns) * sectorWidth
    }

    var totalHeight: CGFloat {
        CGFloat(gridRows) * sectorHeight
    }

    // Sectors in the grid
    var sectors: [MegaBoardSector]

    // Connections between sectors
    var connections: [DataBusConnection]

    // Encryption gates
    var gates: [EncryptionGate]

    // MARK: - Lookup Methods

    /// Get sector by ID
    func sector(id: String) -> MegaBoardSector? {
        sectors.first { $0.id == id }
    }

    /// Get sector at grid position
    func sector(atGridX x: Int, gridY y: Int) -> MegaBoardSector? {
        sectors.first { $0.gridX == x && $0.gridY == y }
    }

    /// Get gate for a sector
    func gate(forSectorId sectorId: String) -> EncryptionGate? {
        gates.first { $0.sectorId == sectorId }
    }

    /// Get all sectors adjacent to a given sector
    func adjacentSectors(to sectorId: String) -> [MegaBoardSector] {
        guard let sector = sector(id: sectorId) else { return [] }

        let adjacentPositions = [
            (sector.gridX - 1, sector.gridY),     // West
            (sector.gridX + 1, sector.gridY),     // East
            (sector.gridX, sector.gridY - 1),     // South
            (sector.gridX, sector.gridY + 1)      // North
        ]

        return adjacentPositions.compactMap { x, y in
            self.sector(atGridX: x, gridY: y)
        }
    }

    /// Get sectors visible in a camera rect (for culling)
    func visibleSectors(in cameraRect: CGRect) -> [MegaBoardSector] {
        sectors.filter { $0.bounds.intersects(cameraRect) }
    }
}

// MARK: - Sector Unlock State

/// Runtime state for sector unlocks (stored in PlayerProfile)
struct SectorUnlockProgress: Codable {
    var sectorId: String
    var isUnlocked: Bool
    var unlockedAt: Date?
}

// MARK: - Factory Methods

extension MegaBoardConfig {
    /// Create the default 3x3 mega-board configuration
    static func createDefault() -> MegaBoardConfig {
        // Grid layout (0,0 is bottom-left):
        // CPU in CENTER, PSU (mid-right) is STARTER
        //
        //   [io]      [cache]   [network]     (row 2 - top)
        //   [gpu]     [cpu]     [psu]         (row 1 - middle) <- PSU is STARTER
        //   [storage] [ram]     [expansion]   (row 0 - bottom)

        let sectorWidth: CGFloat = 1400
        let sectorHeight: CGFloat = 1400

        let sectors = [
            // Row 0 (bottom)
            MegaBoardSector(
                id: SectorID.storage.rawValue,
                displayName: "Storage Array",
                description: "SSD/HDD sector - persistent data storage",
                gridX: 0, gridY: 0,
                width: sectorWidth, height: sectorHeight,
                theme: .storage,
                unlockCost: 12000,
                prerequisiteSectorIds: [SectorID.gpu.rawValue],
                isStarterSector: false,
                hasCore: false
            ),
            MegaBoardSector(
                id: SectorID.ram.rawValue,
                displayName: "Memory Banks",
                description: "RAM sector - fast memory access",
                gridX: 1, gridY: 0,
                width: sectorWidth, height: sectorHeight,
                theme: .memory,
                unlockCost: 3000,
                prerequisiteSectorIds: [SectorID.power.rawValue],
                isStarterSector: false,
                hasCore: false
            ),
            MegaBoardSector(
                id: SectorID.expansion.rawValue,
                displayName: "Expansion Bay",
                description: "PCIe expansion slots for future upgrades",
                gridX: 2, gridY: 0,
                width: sectorWidth, height: sectorHeight,
                theme: .io,
                unlockCost: 10000,
                prerequisiteSectorIds: [SectorID.power.rawValue],
                isStarterSector: false,
                hasCore: false
            ),

            // Row 1 (middle)
            MegaBoardSector(
                id: SectorID.gpu.rawValue,
                displayName: "Graphics Core",
                description: "GPU sector - massive parallel processing power",
                gridX: 0, gridY: 1,
                width: sectorWidth, height: sectorHeight,
                theme: .graphics,
                unlockCost: 5000,
                prerequisiteSectorIds: [SectorID.power.rawValue],
                isStarterSector: false,
                hasCore: false
            ),
            MegaBoardSector(
                id: SectorID.cpu.rawValue,
                displayName: "CPU Core",
                description: "Central Processing Unit - the heart of the system to defend",
                gridX: 1, gridY: 1,
                width: sectorWidth, height: sectorHeight,
                theme: .processing,
                unlockCost: 0,
                prerequisiteSectorIds: [],
                isStarterSector: false,
                hasCore: true
            ),
            MegaBoardSector(
                id: SectorID.power.rawValue,
                displayName: "Power Supply",
                description: "PSU sector - starter zone, powers all components",
                gridX: 2, gridY: 1,
                width: sectorWidth, height: sectorHeight,
                theme: .power,
                unlockCost: 0,
                prerequisiteSectorIds: [],
                isStarterSector: true,
                hasCore: false
            ),

            // Row 2 (top)
            MegaBoardSector(
                id: SectorID.io.rawValue,
                displayName: "I/O Controller",
                description: "Input/Output hub - external connections",
                gridX: 0, gridY: 2,
                width: sectorWidth, height: sectorHeight,
                theme: .io,
                unlockCost: 25000,
                prerequisiteSectorIds: [SectorID.gpu.rawValue, SectorID.storage.rawValue],
                isStarterSector: false,
                hasCore: false
            ),
            MegaBoardSector(
                id: SectorID.cache.rawValue,
                displayName: "Cache Memory",
                description: "L3 Cache - ultra-fast temporary storage",
                gridX: 1, gridY: 2,
                width: sectorWidth, height: sectorHeight,
                theme: .memory,
                unlockCost: 8000,
                prerequisiteSectorIds: [SectorID.ram.rawValue],
                isStarterSector: false,
                hasCore: false
            ),
            MegaBoardSector(
                id: SectorID.network.rawValue,
                displayName: "Network Interface",
                description: "NIC sector - external network connections",
                gridX: 2, gridY: 2,
                width: sectorWidth, height: sectorHeight,
                theme: .network,
                unlockCost: 18000,
                prerequisiteSectorIds: [SectorID.cache.rawValue, SectorID.expansion.rawValue],
                isStarterSector: false,
                hasCore: false
            )
        ]

        // Data bus connections - simplified for new 8-lane system
        // Each non-CPU sector has a lane to the CPU, connections are visual only
        let connections: [DataBusConnection] = []

        // Gates are replaced by lock icons at spawn points in the new lane system
        let gates: [EncryptionGate] = []

        return MegaBoardConfig(
            gridColumns: 3,
            gridRows: 3,
            sectorWidth: sectorWidth,
            sectorHeight: sectorHeight,
            sectors: sectors,
            connections: connections,
            gates: gates
        )
    }
}

// MARK: - SectorID Extension

extension SectorID {
    /// Get theme for this sector
    var theme: SectorTheme {
        switch self {
        case .cpu, .cache: return .processing
        case .ram: return .memory
        case .gpu: return .graphics
        case .storage: return .storage
        case .io, .expansion: return .io
        case .network: return .network
        case .power: return .power
        }
    }
}
