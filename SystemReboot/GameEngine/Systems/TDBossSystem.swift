import Foundation
import CoreGraphics

// MARK: - TD Boss System
// Integrated boss encounters that spawn at threat milestones
// Bosses are "super viruses" immune to tower damage
// Player must manually engage or let them pass (20% efficiency loss)

struct TDBossSystem {

    // MARK: - Constants (from BalanceConfig)

    /// Efficiency loss when boss reaches CPU (ignored)
    static var efficiencyLossOnIgnore: Int { BalanceConfig.TDBoss.efficiencyLossOnIgnore }

    /// Boss walk speed (slower than normal enemies)
    static var bossWalkSpeed: CGFloat { BalanceConfig.TDBoss.walkSpeed }

    /// Time for boss to reach CPU (gives player time to engage)
    static var bossPathDuration: TimeInterval { BalanceConfig.TDBoss.pathDuration }

    // MARK: - District Boss Mapping

    /// Get the boss type for a given district
    /// Cycles through all 4 bosses: Cyberboss, Void Harbinger, Overclocker, Trojan Wyrm
    static func bossTypeForDistrict(_ districtId: String) -> String {
        guard let index = BalanceConfig.SectorUnlock.unlockIndex(for: districtId) else {
            return "cyberboss"
        }
        // 4-boss rotation cycle
        let bossCycle = ["cyberboss", "void_harbinger", "overclocker", "trojan_wyrm"]
        return bossCycle[index % bossCycle.count]
    }

    /// Get the color for a boss type
    static func bossColorForType(_ bossType: String) -> String {
        switch bossType {
        case "cyberboss": return "#ff4444"           // Red
        case "void_harbinger": return "#8844ff"      // Purple
        case "overclocker": return "#ff6600"         // Orange
        case "trojan_wyrm": return "#00ff44"         // Green
        default: return "#ff4444"
        }
    }

    /// Get the next district to unlock after defeating a boss
    /// Uses centralized order from BalanceConfig.SectorUnlock
    static func nextDistrictAfterDefeat(_ currentDistrictId: String) -> String? {
        return BalanceConfig.SectorUnlock.nextSector(after: currentDistrictId)
    }

    /// Get the previous district (the one whose boss must be defeated to make this visible)
    /// Uses centralized order from BalanceConfig.SectorUnlock
    static func previousDistrict(forDistrict districtId: String) -> String? {
        return BalanceConfig.SectorUnlock.previousSector(for: districtId)
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
            health: BalanceConfig.TDBoss.health,
            maxHealth: BalanceConfig.TDBoss.health,
            speed: bossWalkSpeed,
            damage: 0,              // No direct damage - just efficiency loss on reach
            goldValue: 0,           // Reward comes from boss fight
            xpValue: 0,
            size: BalanceConfig.TDBoss.bossSize,
            color: bossColorForType(bossType),
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
        }

        // Remove boss from enemies
        if let bossId = state.activeBossId {
            state.enemies.removeAll { $0.id == bossId }
        }

        // Add hash reward
        state.addHash(hashReward)

        // Reset threat level - defeating the boss clears the board pressure
        // This is the reward for engaging with bosses and prevents runaway difficulty
        state.idleThreatLevel = 0
        state.lastBossThreatMilestone = 0  // Reset milestone so next boss spawns at threat 6

        // Reset efficiency - boss victory clears all system stress
        state.leakCounter = 0

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
