import Foundation
import CoreGraphics

// MARK: - Idle Spawn System
// Handles continuous enemy spawning for idle tower defense gameplay
// Enemies spawn at a steady rate and get stronger over time (threat level)

class IdleSpawnSystem {

    // MARK: - Main Update

    /// Update idle spawning - call this every frame
    /// Returns array of spawned enemies (scales with lane count)
    static func update(
        state: inout TDGameState,
        deltaTime: TimeInterval,
        currentTime: TimeInterval,
        unlockedSectorIds: Set<String>
    ) -> TDEnemy? {
        guard state.idleSpawnEnabled else { return nil }

        // Get available lanes for spawning
        let lanes = getAvailableLanes(state: state, unlockedSectorIds: unlockedSectorIds)
        guard !lanes.isEmpty else { return nil }

        // Don't spawn if at enemy cap
        let activeEnemies = state.enemies.filter { !$0.isDead && !$0.reachedCore }.count
        guard activeEnemies < state.idleMaxEnemiesOnScreen else { return nil }

        // Update threat level (increases over time, faster during overclock)
        // Capped at max to keep Lv10 towers viable
        let effectiveGrowthRate = OverclockSystem.getEffectiveThreatGrowthRate(state: state)
        state.idleThreatLevel = min(
            BalanceConfig.ThreatLevel.maxThreatLevel,
            state.idleThreatLevel + effectiveGrowthRate * CGFloat(deltaTime)
        )

        // Update spawn timer - scale by lane count so more lanes = proportionally more enemies
        // Each lane contributes its share to the spawn timer
        let laneCount = CGFloat(lanes.count)
        state.idleSpawnTimer += deltaTime * laneCount
        guard state.idleSpawnTimer >= state.idleCurrentSpawnInterval else { return nil }

        // Reset timer and spawn enemy
        state.idleSpawnTimer = 0

        // Select random lane
        let selectedLane = lanes.randomElement()!

        // Select enemy type based on threat level with weighted randomness
        let enemyType = selectEnemyType(threatLevel: state.idleThreatLevel)

        // Create enemy with threat-scaled stats
        let enemy = createEnemy(
            type: enemyType,
            lane: selectedLane,
            threatLevel: state.idleThreatLevel,
            pathIndex: lanes.firstIndex(where: { $0.id == selectedLane.id }) ?? 0
        )

        state.idleEnemiesSpawned += 1
        return enemy
    }

    // MARK: - Enemy Type Selection

    /// Select enemy type based on threat level with weighted probability
    private static func selectEnemyType(threatLevel: CGFloat) -> String {
        // Build weighted probability list
        var weights: [(type: String, weight: Int)] = [("basic", 100)]

        // Fast enemies - quick and moderately dangerous
        if threatLevel >= BalanceConfig.ThreatLevel.fastEnemyThreshold {
            let fastWeight = min(
                BalanceConfig.ThreatLevel.fastEnemyMaxWeight,
                Int((threatLevel - BalanceConfig.ThreatLevel.fastEnemyThreshold) * BalanceConfig.ThreatLevel.fastEnemyWeightPerThreat)
            )
            weights.append(("fast", fastWeight))
        }

        // Swarm enemies - weak but fast, come in groups (uses voidminion)
        if threatLevel >= BalanceConfig.ThreatLevel.swarmEnemyThreshold {
            let swarmWeight = min(
                BalanceConfig.ThreatLevel.swarmEnemyMaxWeight,
                Int((threatLevel - BalanceConfig.ThreatLevel.swarmEnemyThreshold) * BalanceConfig.ThreatLevel.swarmEnemyWeightPerThreat)
            )
            weights.append(("voidminion", swarmWeight))
        }

        // Tank enemies - slow but tough
        if threatLevel >= BalanceConfig.ThreatLevel.tankEnemyThreshold {
            let tankWeight = min(
                BalanceConfig.ThreatLevel.tankEnemyMaxWeight,
                Int((threatLevel - BalanceConfig.ThreatLevel.tankEnemyThreshold) * BalanceConfig.ThreatLevel.tankEnemyWeightPerThreat)
            )
            weights.append(("tank", tankWeight))
        }

        // Elite enemies - fast and tanky hybrid (uses fast enemy with boosted stats)
        if threatLevel >= BalanceConfig.ThreatLevel.eliteEnemyThreshold {
            let eliteWeight = min(
                BalanceConfig.ThreatLevel.eliteEnemyMaxWeight,
                Int((threatLevel - BalanceConfig.ThreatLevel.eliteEnemyThreshold) * BalanceConfig.ThreatLevel.eliteEnemyWeightPerThreat)
            )
            weights.append(("elite", eliteWeight))
        }

        // Boss enemies - rare and powerful
        if threatLevel >= BalanceConfig.ThreatLevel.bossEnemyThreshold {
            let bossWeight = min(
                BalanceConfig.ThreatLevel.bossEnemyMaxWeight,
                Int((threatLevel - BalanceConfig.ThreatLevel.bossEnemyThreshold) * BalanceConfig.ThreatLevel.bossEnemyWeightPerThreat)
            )
            weights.append(("boss", bossWeight))
        }

        // Calculate total weight and pick randomly
        let totalWeight = weights.reduce(0) { $0 + $1.weight }
        var roll = Int.random(in: 0..<totalWeight)

        for (type, weight) in weights {
            roll -= weight
            if roll < 0 {
                return type
            }
        }

        return "basic"
    }

    // MARK: - Lane Selection

    /// Get available lanes for spawning based on unlocked sectors
    /// Filters out paused sectors - no enemies spawn on paused lanes
    static func getAvailableLanes(state: TDGameState, unlockedSectorIds: Set<String>) -> [SectorLane] {
        // For motherboard maps, use the 8-lane system
        if state.map.theme == "motherboard" {
            let allLanes = MotherboardLaneConfig.createAllLanes()

            // Return only unlocked lanes that are NOT paused
            return allLanes.filter { lane in
                let isUnlocked = lane.isStarterLane || unlockedSectorIds.contains(lane.sectorId)
                let isNotPaused = !state.pausedSectorIds.contains(lane.sectorId)
                return isUnlocked && isNotPaused
            }
        }

        // Fallback for non-motherboard maps
        guard let firstSpawnPoint = state.map.spawnPoints.first else { return [] }

        let legacyLane = SectorLane(
            id: "legacy",
            sectorId: "legacy",
            displayName: "Main",
            path: EnemyPath(id: "legacy_path", waypoints: [firstSpawnPoint, CGPoint(x: 2100, y: 2100)]),
            spawnPoint: firstSpawnPoint,
            themeColorHex: "#4488ff",
            unlockCost: 0,
            unlockOrder: 0,
            prerequisites: []
        )
        return [legacyLane]
    }

    // MARK: - Enemy Creation

    /// Create enemy with stats scaled by threat level
    static func createEnemy(
        type: String,
        lane: SectorLane,
        threatLevel: CGFloat,
        pathIndex: Int
    ) -> TDEnemy {
        let config = GameConfigLoader.shared
        let enemyConfig = config.getEnemy(type)

        let baseHealth = CGFloat(enemyConfig?.health ?? BalanceConfig.EnemyDefaults.health)
        let baseSpeed = CGFloat(enemyConfig?.speed ?? BalanceConfig.EnemyDefaults.speed)
        let baseDamage = CGFloat(enemyConfig?.damage ?? BalanceConfig.EnemyDefaults.damage)

        // Scale stats by threat level using centralized config
        let healthMultiplier = BalanceConfig.threatHealthMultiplier(threatLevel: threatLevel)
        let speedMultiplier = BalanceConfig.threatSpeedMultiplier(threatLevel: threatLevel)
        let damageMultiplier = BalanceConfig.threatDamageMultiplier(threatLevel: threatLevel)

        // Apply sector hash bonus - later sectors give more hash (risk/reward)
        let baseGoldValue = enemyConfig?.coinValue ?? BalanceConfig.EnemyDefaults.coinValue
        let sectorMultiplier = BalanceConfig.SectorHashBonus.multiplier(for: lane.sectorId)
        let adjustedGoldValue = Int(CGFloat(baseGoldValue) * sectorMultiplier)

        return TDEnemy(
            id: RandomUtils.generateId(),
            type: type,
            x: lane.spawnPoint.x,
            y: lane.spawnPoint.y,
            pathIndex: pathIndex,
            pathProgress: 0,
            health: baseHealth * healthMultiplier,
            maxHealth: baseHealth * healthMultiplier,
            speed: baseSpeed * speedMultiplier,
            damage: baseDamage * damageMultiplier,
            goldValue: adjustedGoldValue,
            xpValue: adjustedGoldValue,  // XP also scales with sector
            size: CGFloat(enemyConfig?.size ?? BalanceConfig.EnemyDefaults.size),
            color: enemyConfig?.color ?? BalanceConfig.EnemyDefaults.color,
            shape: enemyConfig?.shape ?? BalanceConfig.EnemyDefaults.shape,
            isBoss: enemyConfig?.isBoss ?? false,
            laneId: lane.id
        )
    }

    // MARK: - Threat Level Info

    /// Get display info for current threat level
    static func getThreatLevelInfo(threatLevel: CGFloat) -> (name: String, color: String) {
        switch threatLevel {
        case 0..<BalanceConfig.ThreatDisplay.lowMax:
            return ("Low", BalanceConfig.ThreatDisplay.lowColor)
        case BalanceConfig.ThreatDisplay.lowMax..<BalanceConfig.ThreatDisplay.mediumMax:
            return ("Medium", BalanceConfig.ThreatDisplay.mediumColor)
        case BalanceConfig.ThreatDisplay.mediumMax..<BalanceConfig.ThreatDisplay.highMax:
            return ("High", BalanceConfig.ThreatDisplay.highColor)
        case BalanceConfig.ThreatDisplay.highMax..<BalanceConfig.ThreatDisplay.criticalMax:
            return ("Critical", BalanceConfig.ThreatDisplay.criticalColor)
        default:
            return ("Extreme", BalanceConfig.ThreatDisplay.extremeColor)
        }
    }

    /// Get enemy types available at a threat level (for UI display)
    static func getAvailableEnemyTypes(threatLevel: CGFloat) -> [String] {
        var types = ["basic"]
        if threatLevel >= BalanceConfig.ThreatLevel.fastEnemyThreshold { types.append("fast") }
        if threatLevel >= BalanceConfig.ThreatLevel.swarmEnemyThreshold { types.append("swarm") }
        if threatLevel >= BalanceConfig.ThreatLevel.tankEnemyThreshold { types.append("tank") }
        if threatLevel >= BalanceConfig.ThreatLevel.eliteEnemyThreshold { types.append("elite") }
        if threatLevel >= BalanceConfig.ThreatLevel.bossEnemyThreshold { types.append("boss") }
        return types
    }
}
