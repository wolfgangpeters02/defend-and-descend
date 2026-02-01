import Foundation

// MARK: - Sector Schematics
// Defines which protocols must be compiled to unlock each TD sector

/// Requirements to unlock a sector
struct SectorSchematic {
    let sectorId: String            // SectorID.gpu.rawValue
    let displayName: String         // "Graphics Core"
    let description: String         // Why these protocols are needed
    let requiredProtocols: [String] // Protocol IDs that must be compiled

    /// Check if a player meets the requirements
    func meetsRequirements(profile: PlayerProfile) -> Bool {
        let compiledSet = Set(profile.compiledProtocols)
        return requiredProtocols.allSatisfy { compiledSet.contains($0) }
    }

    /// Get list of missing protocols for a player
    func missingProtocols(profile: PlayerProfile) -> [String] {
        let compiledSet = Set(profile.compiledProtocols)
        return requiredProtocols.filter { !compiledSet.contains($0) }
    }

    /// Get display names of missing protocols
    func missingProtocolNames(profile: PlayerProfile) -> [String] {
        return missingProtocols(profile: profile).compactMap {
            ProtocolLibrary.get($0)?.name
        }
    }
}

// MARK: - Sector Schematic Library

struct SectorSchematicLibrary {

    // MARK: - Sector Definitions

    /// Power sector - Starter (no requirements)
    static let power = SectorSchematic(
        sectorId: SectorID.power.rawValue,
        displayName: "Power Supply",
        description: "Starter sector - no protocols required",
        requiredProtocols: []  // Always unlockable
    )

    /// RAM sector - Basic memory access
    static let ram = SectorSchematic(
        sectorId: SectorID.ram.rawValue,
        displayName: "Memory Banks",
        description: "Basic system access protocols",
        requiredProtocols: ["kernel_pulse"]  // Starter protocol
    )

    /// CPU sector - Core processing (hash cost only, final goal)
    static let cpu = SectorSchematic(
        sectorId: SectorID.cpu.rawValue,
        displayName: "CPU Core",
        description: "Core processing - Hash investment only",
        requiredProtocols: []  // No protocol requirements, just Hash
    )

    /// GPU sector - Parallel processing
    static let gpu = SectorSchematic(
        sectorId: SectorID.gpu.rawValue,
        displayName: "Graphics Core",
        description: "Parallel processing requires multi-target protocols",
        requiredProtocols: ["burst_protocol", "fork_bomb"]  // AoE/multi-shot
    )

    /// Storage sector - Data persistence
    static let storage = SectorSchematic(
        sectorId: SectorID.storage.rawValue,
        displayName: "Storage Array",
        description: "Long-range data access protocols",
        requiredProtocols: ["trace_route"]  // Sniper = persistence
    )

    /// Cache sector - Fast memory
    static let cache = SectorSchematic(
        sectorId: SectorID.cache.rawValue,
        displayName: "Cache Memory",
        description: "Speed and control protocols",
        requiredProtocols: ["kernel_pulse", "ice_shard"]  // Basic + slow
    )

    /// Expansion sector - PCIe slots
    static let expansion = SectorSchematic(
        sectorId: SectorID.expansion.rawValue,
        displayName: "Expansion Bay",
        description: "System privileges for expansion access",
        requiredProtocols: ["root_access"]  // Admin rights
    )

    /// I/O sector - External connections
    static let io = SectorSchematic(
        sectorId: SectorID.io.rawValue,
        displayName: "I/O Controller",
        description: "Multi-channel communication protocols",
        requiredProtocols: ["fork_bomb", "trace_route"]  // Multi + range
    )

    /// Network sector - Final sector, external access
    static let network = SectorSchematic(
        sectorId: SectorID.network.rawValue,
        displayName: "Network Interface",
        description: "Complete protocol mastery required",
        requiredProtocols: ["overflow", "null_pointer"]  // Both legendaries
    )

    // MARK: - Library Access

    /// All sector schematics
    static let all: [SectorSchematic] = [
        power,
        ram,
        cpu,
        gpu,
        storage,
        cache,
        expansion,
        io,
        network
    ]

    /// Get schematic for a sector ID
    static func schematic(for sectorId: String) -> SectorSchematic? {
        return all.first { $0.sectorId == sectorId }
    }

    /// Check if player meets requirements for a sector
    static func meetsRequirements(for sectorId: String, profile: PlayerProfile) -> Bool {
        guard let schematic = schematic(for: sectorId) else {
            return true  // No schematic = no requirements
        }
        return schematic.meetsRequirements(profile: profile)
    }

    /// Get missing protocol names for a sector
    static func missingProtocolNames(for sectorId: String, profile: PlayerProfile) -> [String] {
        guard let schematic = schematic(for: sectorId) else {
            return []
        }
        return schematic.missingProtocolNames(profile: profile)
    }

    /// Get all sectors requiring a specific protocol
    static func sectorsRequiring(_ protocolId: String) -> [String] {
        return all.filter { $0.requiredProtocols.contains(protocolId) }
            .map { $0.sectorId }
    }
}
