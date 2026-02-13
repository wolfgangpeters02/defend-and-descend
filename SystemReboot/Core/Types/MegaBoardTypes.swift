import Foundation
import CoreGraphics

// MARK: - Mega-Board Types
// Multi-sector grid system for the expandable Motherboard map
// Players unlock sectors by spending Hash to decrypt encryption gates
//
// Dependencies:
// - SectorID from EntityIDs.swift

// MARK: - Sector Render Mode

/// Visual render state for a sector on the mega-board
enum SectorRenderMode {
    case locked       // Blueprint not found — corrupted data, mystery
    case unlockable   // Blueprint found — schematic/wireframe preview
    case unlocked     // Fully decrypted — full component rendering
}

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

    // MARK: - Lookup Methods

    /// Get sector by ID
    func sector(id: String) -> MegaBoardSector? {
        sectors.first { $0.id == id }
    }

    /// Get sector at grid position
    func sector(atGridX x: Int, gridY y: Int) -> MegaBoardSector? {
        sectors.first { $0.gridX == x && $0.gridY == y }
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
    /// Unlock order from BalanceConfig: PSU → RAM → GPU → Cache → Storage → Expansion → Network → I/O → CPU
    /// Sectors require: 1) Defeating previous boss (visibility) 2) Paying Hash (unlock)
    static func createDefault() -> MegaBoardConfig {
        // Grid layout (0,0 is bottom-left):
        // CPU in CENTER, PSU (mid-right) is STARTER
        //
        //   [io]      [cache]   [network]     (row 2 - top)
        //   [gpu]     [cpu]     [psu]         (row 1 - middle) <- PSU is STARTER
        //   [storage] [ram]     [expansion]   (row 0 - bottom)
        //
        // FIXED UNLOCK ORDER (from BalanceConfig.SectorUnlock):
        // PSU (0 Ħ) → RAM (25k Ħ) → GPU (50k Ħ) → Cache (75k Ħ) → Storage (100k Ħ)
        // → Expansion (150k Ħ) → Network (200k Ħ) → I/O (300k Ħ) → CPU (500k Ħ)

        let sectorWidth: CGFloat = 1400
        let sectorHeight: CGFloat = 1400

        // Helper to get prerequisite array from BalanceConfig
        func prereqs(for sectorId: String) -> [String] {
            if let prev = BalanceConfig.SectorUnlock.previousSector(for: sectorId) {
                return [prev]
            }
            return []
        }

        let sectors = [
            // Row 0 (bottom)
            MegaBoardSector(
                id: SectorID.storage.rawValue,
                displayName: "Storage Array",
                description: "SSD/HDD sector - Hash storage & offline earnings",
                gridX: 0, gridY: 0,
                width: sectorWidth, height: sectorHeight,
                theme: .storage,
                unlockCost: BalanceConfig.SectorUnlock.unlockCost(for: SectorID.storage.rawValue),
                prerequisiteSectorIds: prereqs(for: SectorID.storage.rawValue),
                isStarterSector: false,
                hasCore: false
            ),
            MegaBoardSector(
                id: SectorID.ram.rawValue,
                displayName: "Memory Banks",
                description: "RAM sector - efficiency recovery speed",
                gridX: 1, gridY: 0,
                width: sectorWidth, height: sectorHeight,
                theme: .memory,
                unlockCost: BalanceConfig.SectorUnlock.unlockCost(for: SectorID.ram.rawValue),
                prerequisiteSectorIds: prereqs(for: SectorID.ram.rawValue),
                isStarterSector: false,
                hasCore: false
            ),
            MegaBoardSector(
                id: SectorID.expansion.rawValue,
                displayName: "Expansion Bay",
                description: "PCIe expansion - extra tower slots per sector",
                gridX: 2, gridY: 0,
                width: sectorWidth, height: sectorHeight,
                theme: .io,
                unlockCost: BalanceConfig.SectorUnlock.unlockCost(for: SectorID.expansion.rawValue),
                prerequisiteSectorIds: prereqs(for: SectorID.expansion.rawValue),
                isStarterSector: false,
                hasCore: false
            ),

            // Row 1 (middle)
            MegaBoardSector(
                id: SectorID.gpu.rawValue,
                displayName: "Graphics Core",
                description: "GPU sector - global tower damage boost",
                gridX: 0, gridY: 1,
                width: sectorWidth, height: sectorHeight,
                theme: .graphics,
                unlockCost: BalanceConfig.SectorUnlock.unlockCost(for: SectorID.gpu.rawValue),
                prerequisiteSectorIds: prereqs(for: SectorID.gpu.rawValue),
                isStarterSector: false,
                hasCore: false
            ),
            MegaBoardSector(
                id: SectorID.cpu.rawValue,
                displayName: "CPU Core",
                description: "Central Processing Unit - Hash generation rate (final goal)",
                gridX: 1, gridY: 1,
                width: sectorWidth, height: sectorHeight,
                theme: .processing,
                unlockCost: BalanceConfig.SectorUnlock.unlockCost(for: SectorID.cpu.rawValue),
                prerequisiteSectorIds: prereqs(for: SectorID.cpu.rawValue),
                isStarterSector: false,
                hasCore: true
            ),
            MegaBoardSector(
                id: SectorID.power.rawValue,
                displayName: "Power Supply",
                description: "PSU sector - starter zone, power capacity for towers",
                gridX: 2, gridY: 1,
                width: sectorWidth, height: sectorHeight,
                theme: .power,
                unlockCost: BalanceConfig.SectorUnlock.unlockCost(for: SectorID.power.rawValue),
                prerequisiteSectorIds: prereqs(for: SectorID.power.rawValue),
                isStarterSector: BalanceConfig.SectorUnlock.isStarterSector(SectorID.power.rawValue),
                hasCore: false
            ),

            // Row 2 (top)
            MegaBoardSector(
                id: SectorID.io.rawValue,
                displayName: "I/O Controller",
                description: "Input/Output hub - pickup radius boost",
                gridX: 0, gridY: 2,
                width: sectorWidth, height: sectorHeight,
                theme: .io,
                unlockCost: BalanceConfig.SectorUnlock.unlockCost(for: SectorID.io.rawValue),
                prerequisiteSectorIds: prereqs(for: SectorID.io.rawValue),
                isStarterSector: false,
                hasCore: false
            ),
            MegaBoardSector(
                id: SectorID.cache.rawValue,
                displayName: "Cache Memory",
                description: "L3 Cache - global attack speed boost",
                gridX: 1, gridY: 2,
                width: sectorWidth, height: sectorHeight,
                theme: .memory,
                unlockCost: BalanceConfig.SectorUnlock.unlockCost(for: SectorID.cache.rawValue),
                prerequisiteSectorIds: prereqs(for: SectorID.cache.rawValue),
                isStarterSector: false,
                hasCore: false
            ),
            MegaBoardSector(
                id: SectorID.network.rawValue,
                displayName: "Network Interface",
                description: "NIC sector - global Hash multiplier (prestige)",
                gridX: 2, gridY: 2,
                width: sectorWidth, height: sectorHeight,
                theme: .network,
                unlockCost: BalanceConfig.SectorUnlock.unlockCost(for: SectorID.network.rawValue),
                prerequisiteSectorIds: prereqs(for: SectorID.network.rawValue),
                isStarterSector: false,
                hasCore: false
            )
        ]

        return MegaBoardConfig(
            gridColumns: 3,
            gridRows: 3,
            sectorWidth: sectorWidth,
            sectorHeight: sectorHeight,
            sectors: sectors
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
