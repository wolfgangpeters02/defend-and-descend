import Foundation
import CoreGraphics

// MARK: - TD Boss System
// Integrated boss encounters that spawn at threat milestones
// Bosses are "super viruses" immune to tower damage
// Player must manually engage or let them pass (20% efficiency loss)

struct TDBossSystem {

    // MARK: - Constants

    /// Efficiency loss when boss reaches CPU (ignored)
    static let efficiencyLossOnIgnore: Int = 4  // 4 leak = 20% efficiency loss

    /// Boss walk speed (slower than normal enemies)
    static let bossWalkSpeed: CGFloat = 25

    /// Time for boss to reach CPU (gives player time to engage)
    static let bossPathDuration: TimeInterval = 60  // ~60 seconds to reach CPU

    // MARK: - District Boss Mapping

    /// Get the boss type for a given district
    static func bossTypeForDistrict(_ districtId: String) -> String {
        // Alternate between Cyberboss and Void Harbinger
        switch districtId {
        case SectorID.power.rawValue: return "cyberboss"      // PSU
        case SectorID.ram.rawValue: return "void_harbinger"   // RAM
        case SectorID.gpu.rawValue: return "cyberboss"        // GPU
        case SectorID.cache.rawValue: return "void_harbinger" // Cache
        case SectorID.expansion.rawValue: return "cyberboss"  // Expansion
        case SectorID.storage.rawValue: return "void_harbinger" // Storage
        case SectorID.network.rawValue: return "cyberboss"    // Network
        case SectorID.io.rawValue: return "void_harbinger"    // I/O
        default: return "cyberboss"
        }
    }

    /// Get the next district to unlock after defeating a boss
    static func nextDistrictAfterDefeat(_ currentDistrictId: String) -> String? {
        // Unlock order: PSU -> RAM -> GPU -> Cache -> Expansion -> Storage -> Network -> I/O
        switch currentDistrictId {
        case SectorID.power.rawValue: return SectorID.ram.rawValue
        case SectorID.ram.rawValue: return SectorID.gpu.rawValue
        case SectorID.gpu.rawValue: return SectorID.cache.rawValue
        case SectorID.cache.rawValue: return SectorID.expansion.rawValue
        case SectorID.expansion.rawValue: return SectorID.storage.rawValue
        case SectorID.storage.rawValue: return SectorID.network.rawValue
        case SectorID.network.rawValue: return SectorID.io.rawValue
        case SectorID.io.rawValue: return nil  // Last district
        default: return nil
        }
    }

    /// Get the previous district (the one whose boss must be defeated to make this visible)
    static func previousDistrict(forDistrict districtId: String) -> String? {
        // Reverse lookup: what boss must be defeated to see this district?
        switch districtId {
        case SectorID.power.rawValue: return nil  // Starter, always visible
        case SectorID.ram.rawValue: return SectorID.power.rawValue
        case SectorID.gpu.rawValue: return SectorID.ram.rawValue
        case SectorID.cache.rawValue: return SectorID.gpu.rawValue
        case SectorID.expansion.rawValue: return SectorID.cache.rawValue
        case SectorID.storage.rawValue: return SectorID.expansion.rawValue
        case SectorID.network.rawValue: return SectorID.storage.rawValue
        case SectorID.io.rawValue: return SectorID.network.rawValue
        default: return nil
        }
    }

    // MARK: - Update

    /// Update boss state - check if threat milestone reached, update boss movement
    /// Called from TD game loop
    static func update(state: inout TDGameState, deltaTime: TimeInterval) -> TDBossUpdateResult {
        var result = TDBossUpdateResult()

        // Don't update if game is paused or over
        guard !state.isPaused && !state.isGameOver else { return result }

        // Check if we should spawn a boss
        if state.shouldSpawnBoss {
            spawnBoss(state: &state)
            result.bossSpawned = true
            result.spawnedBossType = state.activeBossType
        }

        // Update active boss (if not engaged, let it walk toward CPU)
        if state.bossActive && !state.bossEngaged {
            updateBossMovement(state: &state, deltaTime: deltaTime)

            // Check if boss reached CPU
            if let bossId = state.activeBossId,
               let bossIndex = state.enemies.firstIndex(where: { $0.id == bossId }) {
                if state.enemies[bossIndex].reachedCore {
                    // Boss reached CPU - apply efficiency loss
                    result.bossReachedCPU = true
                    onBossReachedCPU(state: &state)
                }
            }
        }

        // Check if boss was killed (shouldn't happen - immune to towers)
        if state.bossActive && !state.isBossAlive && !state.bossEngaged {
            // Boss died somehow (cheats?) - reset state
            resetBossState(state: &state)
        }

        return result
    }

    // MARK: - Spawn Boss

    /// Spawn a boss at the current threat milestone
    static func spawnBoss(state: inout TDGameState) {
        // Pick the lane/district with highest threat or random
        let activeLanes = state.paths
        guard let lane = activeLanes.randomElement(), !lane.waypoints.isEmpty else {
            return
        }

        let startPos = lane.waypoints[0]

        // Determine boss type based on which district spawned it
        let districtId = lane.sectorId ?? SectorID.power.rawValue  // Fallback to PSU if not set
        let bossType = bossTypeForDistrict(districtId)

        // Create boss enemy
        var boss = TDEnemy(
            id: "td_boss_\(RandomUtils.generateId())",
            type: bossType,
            x: startPos.x,
            y: startPos.y,
            pathIndex: 0,
            pathProgress: 0,
            health: 99999,          // Very high - immune to towers anyway
            maxHealth: 99999,
            speed: bossWalkSpeed,
            damage: 0,              // No direct damage - just efficiency loss on reach
            goldValue: 0,           // Reward comes from boss fight
            xpValue: 0,
            size: 80,               // Large boss visual
            color: bossType == "cyberboss" ? "#ff4444" : "#8844ff",
            shape: "boss",
            isBoss: true
        )
        boss.isZeroDay = false
        boss.immuneToTowers = true  // Cannot be damaged by Firewalls

        state.enemies.append(boss)
        state.activeBossId = boss.id
        state.activeBossType = bossType
        state.activeBossDistrictId = districtId
        state.bossActive = true
        state.bossEngaged = false
        state.bossSelectedDifficulty = nil
        state.lastBossThreatMilestone = state.nextBossThreatMilestone  // Record the milestone that triggered this spawn

        print("[TDBossSystem] Spawned \(bossType) at threat \(state.idleThreatLevel)")
    }

    // MARK: - Boss Movement

    /// Update boss movement along path (when not engaged)
    private static func updateBossMovement(state: inout TDGameState, deltaTime: TimeInterval) {
        guard let bossId = state.activeBossId,
              let bossIndex = state.enemies.firstIndex(where: { $0.id == bossId }),
              !state.enemies[bossIndex].reachedCore else {
            return
        }

        var boss = state.enemies[bossIndex]

        // Move boss along path
        guard boss.pathIndex < state.paths.count else { return }
        let path = state.paths[boss.pathIndex]

        // Calculate progress along path
        let pathLength = calculatePathLength(path)
        let progressPerSecond = boss.speed / pathLength
        boss.pathProgress += CGFloat(deltaTime) * progressPerSecond

        // Update position based on progress
        if boss.pathProgress >= 1.0 {
            // Boss reached CPU
            boss.reachedCore = true
            boss.pathProgress = 1.0
            if let lastWaypoint = path.waypoints.last {
                boss.x = lastWaypoint.x
                boss.y = lastWaypoint.y
            }
        } else {
            // Interpolate position along path
            let position = interpolatePathPosition(path: path, progress: boss.pathProgress)
            boss.x = position.x
            boss.y = position.y
        }

        state.enemies[bossIndex] = boss
    }

    /// Calculate total path length
    private static func calculatePathLength(_ path: EnemyPath) -> CGFloat {
        var length: CGFloat = 0
        for i in 0..<path.waypoints.count - 1 {
            let dx = path.waypoints[i + 1].x - path.waypoints[i].x
            let dy = path.waypoints[i + 1].y - path.waypoints[i].y
            length += sqrt(dx * dx + dy * dy)
        }
        return max(length, 1)  // Avoid division by zero
    }

    /// Interpolate position along path based on progress (0.0 to 1.0)
    private static func interpolatePathPosition(path: EnemyPath, progress: CGFloat) -> CGPoint {
        guard path.waypoints.count > 1 else {
            return path.waypoints.first ?? .zero
        }

        let totalLength = calculatePathLength(path)
        var targetDistance = progress * totalLength
        var currentLength: CGFloat = 0

        for i in 0..<path.waypoints.count - 1 {
            let start = path.waypoints[i]
            let end = path.waypoints[i + 1]
            let dx = end.x - start.x
            let dy = end.y - start.y
            let segmentLength = sqrt(dx * dx + dy * dy)

            if currentLength + segmentLength >= targetDistance {
                // Position is within this segment
                let segmentProgress = (targetDistance - currentLength) / segmentLength
                return CGPoint(
                    x: start.x + dx * segmentProgress,
                    y: start.y + dy * segmentProgress
                )
            }

            currentLength += segmentLength
        }

        // At end of path
        return path.waypoints.last ?? .zero
    }

    // MARK: - Boss Reached CPU

    /// Called when boss reaches CPU (player ignored it)
    private static func onBossReachedCPU(state: inout TDGameState) {
        // Apply efficiency loss (20% = 4 leaks)
        state.leakCounter += efficiencyLossOnIgnore

        // Remove boss from enemies
        if let bossId = state.activeBossId {
            state.enemies.removeAll { $0.id == bossId }
        }

        print("[TDBossSystem] Boss reached CPU - efficiency loss applied")

        resetBossState(state: &state)
    }

    // MARK: - Engage Boss

    /// Called when player taps to engage the boss
    /// Returns the boss type and current state for transitioning to boss fight
    static func engageBoss(state: inout TDGameState, difficulty: BossDifficulty) -> TDBossEngagement? {
        guard state.bossActive, let bossType = state.activeBossType else {
            return nil
        }

        state.bossEngaged = true
        state.bossSelectedDifficulty = difficulty

        // Pause board (will be handled by container view)
        // Boss enemy stays in place while fight happens

        return TDBossEngagement(
            bossType: bossType,
            difficulty: difficulty,
            districtId: state.activeBossDistrictId ?? SectorID.power.rawValue
        )
    }

    // MARK: - Boss Fight Results

    /// Called when boss fight is won
    static func onBossFightWon(state: inout TDGameState, districtId: String) -> TDBossFightReward {
        guard let difficulty = state.bossSelectedDifficulty else {
            return TDBossFightReward(hashReward: 0, blueprintDropped: false, nextDistrictUnlocked: nil)
        }

        // Calculate rewards
        let hashReward = difficulty.hashReward
        let blueprintChance = difficulty.blueprintChance
        let blueprintDropped = CGFloat.random(in: 0...1) < blueprintChance

        // Check for first defeat of this district's boss
        var nextDistrictUnlocked: String?
        if !state.defeatedDistrictBosses.contains(districtId) {
            state.defeatedDistrictBosses.insert(districtId)
            nextDistrictUnlocked = nextDistrictAfterDefeat(districtId)
            print("[TDBossSystem] First defeat of \(districtId) boss - unlocked visibility of \(nextDistrictUnlocked ?? "none")")
        }

        // Remove boss from enemies
        if let bossId = state.activeBossId {
            state.enemies.removeAll { $0.id == bossId }
        }

        // Add hash reward
        state.addHash(hashReward)

        resetBossState(state: &state)

        return TDBossFightReward(
            hashReward: hashReward,
            blueprintDropped: blueprintDropped,
            nextDistrictUnlocked: nextDistrictUnlocked
        )
    }

    /// Called when boss fight is lost and player chooses to let boss pass
    static func onBossFightLostLetPass(state: inout TDGameState) {
        // Apply efficiency loss
        state.leakCounter += efficiencyLossOnIgnore

        // Remove boss
        if let bossId = state.activeBossId {
            state.enemies.removeAll { $0.id == bossId }
        }

        resetBossState(state: &state)
    }

    // MARK: - Reset State

    /// Reset boss state after fight or ignore
    private static func resetBossState(state: inout TDGameState) {
        state.bossActive = false
        state.activeBossId = nil
        state.activeBossType = nil
        state.activeBossDistrictId = nil
        state.bossEngaged = false
        state.bossSelectedDifficulty = nil
    }

    // MARK: - Helper: Check Boss Immunity

    /// Check if an enemy is a TD boss (immune to towers)
    static func isTDBoss(enemy: TDEnemy) -> Bool {
        return enemy.immuneToTowers && enemy.isBoss && !enemy.isZeroDay
    }
}

// MARK: - Result Types

struct TDBossUpdateResult {
    var bossSpawned: Bool = false
    var spawnedBossType: String?
    var bossReachedCPU: Bool = false
}

struct TDBossEngagement {
    let bossType: String
    let difficulty: BossDifficulty
    let districtId: String
}

struct TDBossFightReward {
    let hashReward: Int
    let blueprintDropped: Bool
    let nextDistrictUnlocked: String?  // District ID that became visible (for first defeat)
}
