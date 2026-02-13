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

// MARK: - Debug Arena (Active Mode Levels)

struct DebugArena: Identifiable, Codable, Equatable {
    let id: String                  // "ram", "drive", "gpu"
    let name: String                // "The RAM"
    let subtitle: String            // "Memory Banks"
    let description: String         // "Open arena, swarm survival"

    let difficulty: ArenaDifficulty
    let hashMultiplier: CGFloat     // 1.0, 1.5, 2.0, 3.0

    let unlockCost: Int             // Hash to unlock (0 = free)

    let layout: ArenaLayout
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
         difficulty: ArenaDifficulty, hashMultiplier: CGFloat, unlockCost: Int,
         layout: ArenaLayout, visualTheme: String, duration: TimeInterval,
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

enum ArenaDifficulty: String, Codable {
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

enum ArenaLayout: String, Codable {
    case arena                      // Open space, no walls
    case corridors                  // Narrow passages
    case mixed                      // Rooms connected by corridors
}

// MARK: - Debug Arena Library

struct DebugArenaLibrary {
    static let all: [DebugArena] = [
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

    static func get(_ id: String) -> DebugArena? {
        return all.first { $0.id == id }
    }

    /// Starting arena (always unlocked)
    /// Note: Must match PlayerProfile.defaultSectorId
    static let starterArenaId = "ram"

    // MARK: - Arena Definitions

    static let theRam = DebugArena(
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

    static let theDrive = DebugArena(
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

    static let theGpu = DebugArena(
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

    static let theBios = DebugArena(
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

    // MARK: - Dungeon Arenas (Room-based progression with boss fights)

    static let cathedral = DebugArena(
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

    static let frostCaverns = DebugArena(
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

    static let volcanicCore = DebugArena(
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

    static let heistVault = DebugArena(
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

    static let voidRaid = DebugArena(
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
