import Foundation
import CoreGraphics

// MARK: - TD Session State (Lightweight Persistence)
// Persists towers and slots across app restarts

struct TDSessionState: Codable {
    // Preserved key for save backward compat
    enum CodingKeys: String, CodingKey {
        case towers, towerSlots, hash, wavesCompleted, efficiency, leakCounter, lastSaveTime
        case idleThreatLevel, idleEnemiesSpawned, pausedSectorIds, lastBossThreatMilestone
        case defeatedSectorBosses = "defeatedDistrictBosses"
    }

    var towers: [Tower]
    var towerSlots: [TowerSlot]
    var hash: Int
    var wavesCompleted: Int
    var efficiency: CGFloat
    var leakCounter: Int
    var lastSaveTime: TimeInterval

    // Idle TD state
    var idleThreatLevel: CGFloat?        // Current threat level (enemy scaling)
    var idleEnemiesSpawned: Int?         // Total enemies spawned

    // Sector pause state
    var pausedSectorIds: Set<String>?    // IDs of sectors currently paused

    // Boss progression state
    var lastBossThreatMilestone: Int?    // Last threat milestone that triggered a boss
    var defeatedSectorBosses: Set<String>?  // Sectors where boss was defeated

    /// Create session state from current game state
    static func from(gameState: TDGameState) -> TDSessionState {
        return TDSessionState(
            towers: gameState.towers,
            towerSlots: gameState.towerSlots,
            hash: gameState.hash,
            wavesCompleted: gameState.wavesCompleted,
            efficiency: gameState.efficiency,
            leakCounter: gameState.leakCounter,
            lastSaveTime: Date().timeIntervalSince1970,
            idleThreatLevel: gameState.idleThreatLevel,
            idleEnemiesSpawned: gameState.idleEnemiesSpawned,
            pausedSectorIds: gameState.pausedSectorIds.isEmpty ? nil : gameState.pausedSectorIds,
            lastBossThreatMilestone: gameState.lastBossThreatMilestone > 0 ? gameState.lastBossThreatMilestone : nil,
            defeatedSectorBosses: gameState.defeatedSectorBosses.isEmpty ? nil : gameState.defeatedSectorBosses
        )
    }

    /// Apply session state to game state
    /// Note: Does NOT overwrite towerSlots - those are generated fresh from lane config.
    /// Instead, we restore tower placements and mark slots as occupied.
    func apply(to state: inout TDGameState) {
        // Restore towers
        state.towers = towers

        // Instead of overwriting slots, mark existing slots as occupied based on restored towers
        // This ensures fresh slot generation is preserved while tower placements are restored
        for i in 0..<state.towerSlots.count {
            let slot = state.towerSlots[i]
            // Check if any restored tower is at this slot
            if let tower = towers.first(where: { $0.slotId == slot.id }) {
                state.towerSlots[i].occupied = true
                state.towerSlots[i].towerId = tower.id
            } else {
                state.towerSlots[i].occupied = false
                state.towerSlots[i].towerId = nil
            }
        }

        // Handle towers that reference slots that no longer exist (slot IDs changed)
        // Re-assign them to the nearest available slot
        for tower in towers {
            let slotExists = state.towerSlots.contains { $0.id == tower.slotId }
            if !slotExists {
                // Find nearest unoccupied slot to this tower's position
                var nearestSlot: TowerSlot?
                var nearestDistance: CGFloat = .infinity

                for slot in state.towerSlots where !slot.occupied {
                    let dx = slot.x - tower.x
                    let dy = slot.y - tower.y
                    let dist = sqrt(dx*dx + dy*dy)
                    if dist < nearestDistance {
                        nearestDistance = dist
                        nearestSlot = slot
                    }
                }

                // If we found a nearby slot, update the tower and slot
                if let slot = nearestSlot, nearestDistance < 200 {
                    if let towerIndex = state.towers.firstIndex(where: { $0.id == tower.id }),
                       let slotIndex = state.towerSlots.firstIndex(where: { $0.id == slot.id }) {
                        state.towers[towerIndex].slotId = slot.id
                        state.towers[towerIndex].x = slot.x
                        state.towers[towerIndex].y = slot.y
                        state.towerSlots[slotIndex].occupied = true
                        state.towerSlots[slotIndex].towerId = tower.id
                    }
                } else {
                    // No valid slot found - remove this orphaned tower
                    state.towers.removeAll { $0.id == tower.id }
                }
            }
        }

        state.hash = hash
        state.wavesCompleted = wavesCompleted
        state.leakCounter = leakCounter

        // Restore idle spawn state if present
        if let threatLevel = idleThreatLevel {
            state.idleThreatLevel = threatLevel
        }
        if let enemiesSpawned = idleEnemiesSpawned {
            state.idleEnemiesSpawned = enemiesSpawned
        }

        // Restore paused sectors if present
        if let paused = pausedSectorIds {
            state.pausedSectorIds = paused
        }

        // Restore boss progression state
        if let milestone = lastBossThreatMilestone {
            state.lastBossThreatMilestone = milestone
        }
        if let defeated = defeatedSectorBosses {
            state.defeatedSectorBosses = defeated
        }
    }
}

// MARK: - TD Session Stats

struct TDSessionStats {
    var enemiesKilled: Int = 0
    var towersPlaced: Int = 0
    var towersUpgraded: Int = 0
    var hashEarned: Int = 0
    var hashSpent: Int = 0
    var damageDealt: CGFloat = 0
    var wavesCompleted: Int = 0
}
