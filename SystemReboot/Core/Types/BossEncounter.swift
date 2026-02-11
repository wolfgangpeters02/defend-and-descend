import Foundation

// MARK: - Boss Encounter Model

struct BossEncounter: Identifiable {
    let id: String
    let name: String
    let subtitle: String
    let description: String
    let iconName: String
    let color: String
    let bossId: String  // Maps to boss AI type
    let rewards: [String]  // Protocol IDs that can drop
    let unlockCost: Int

    static let all: [BossEncounter] = [
        BossEncounter(
            id: "rogue_process",
            name: "ROGUE PROCESS",
            subtitle: "Cyberboss",
            description: "A corrupted system process. Spawns minions and fires laser beams.",
            iconName: "bolt.shield.fill",
            color: "#ff4444",
            bossId: "cyberboss",
            rewards: ["burst_protocol", "trace_route"],
            unlockCost: 0
        ),
        BossEncounter(
            id: "memory_leak",
            name: "MEMORY LEAK",
            subtitle: "Void Harbinger",
            description: "A void entity consuming memory. Creates gravity wells and shrinking arenas.",
            iconName: "tornado",
            color: "#a855f7",
            bossId: "void_harbinger",
            rewards: ["fork_bomb", "overflow"],
            unlockCost: 200
        ),
        BossEncounter(
            id: "thermal_runaway",
            name: "THERMAL RUNAWAY",
            subtitle: "Overclocker",
            description: "An overheated PSU gone rogue. Rotating blades, lava floors, and deadly vacuum.",
            iconName: "flame.fill",
            color: "#ff6600",
            bossId: "overclocker",
            rewards: ["ice_shard", "null_pointer"],
            unlockCost: 400
        ),
        BossEncounter(
            id: "packet_worm",
            name: "PACKET WORM",
            subtitle: "Trojan Wyrm",
            description: "A network worm burrowing through the system. Sweeps as a firewall, splits into sub-worms, and constricts with deadly force.",
            iconName: "link.circle.fill",
            color: "#00ff44",
            bossId: "trojan_wyrm",
            rewards: ["root_access"],
            unlockCost: 600
        )
    ]
}
