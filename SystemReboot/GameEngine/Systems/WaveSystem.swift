import Foundation
import CoreGraphics

// MARK: - Wave System
// Handles wave spawning and progression in TD mode

class WaveSystem {

    // MARK: - Wave Generation

    /// Generate waves for a game session
    static func generateWaves(totalWaves: Int = 20) -> [TDWave] {
        var waves: [TDWave] = []

        for waveNum in 1...totalWaves {
            waves.append(generateWave(number: waveNum))
        }

        return waves
    }

    /// Generate a single wave
    static func generateWave(number: Int) -> TDWave {
        var enemies: [WaveEnemy] = []

        // Base enemy count scales with wave number
        let baseCount = BalanceConfig.Waves.baseEnemyCount + number * BalanceConfig.Waves.enemiesPerWave

        // Health and speed multipliers scale with wave
        let healthMult = BalanceConfig.waveHealthMultiplier(waveNumber: number)
        let speedMult = BalanceConfig.waveSpeedMultiplier(waveNumber: number)

        // Composition changes based on wave number
        if number <= BalanceConfig.Waves.earlyWaveMax {
            // Early waves: only basic enemies
            enemies.append(WaveEnemy(
                type: EnemyID.basic.rawValue,
                count: baseCount,
                healthMultiplier: healthMult,
                speedMultiplier: speedMult
            ))
        } else if number <= BalanceConfig.Waves.midEarlyWaveMax {
            // Mid-early: basic + fast
            enemies.append(WaveEnemy(
                type: EnemyID.basic.rawValue,
                count: baseCount / 2,
                healthMultiplier: healthMult,
                speedMultiplier: speedMult
            ))
            enemies.append(WaveEnemy(
                type: EnemyID.fast.rawValue,
                count: baseCount / 2,
                healthMultiplier: healthMult,
                speedMultiplier: speedMult
            ))
        } else if number <= BalanceConfig.Waves.midWaveMax {
            // Mid: basic + fast + tank (remainder goes to tank)
            let basicCount = baseCount / 3
            let fastCount = baseCount / 3
            let tankCount = baseCount - basicCount - fastCount
            enemies.append(WaveEnemy(
                type: EnemyID.basic.rawValue,
                count: basicCount,
                healthMultiplier: healthMult,
                speedMultiplier: speedMult
            ))
            enemies.append(WaveEnemy(
                type: EnemyID.fast.rawValue,
                count: fastCount,
                healthMultiplier: healthMult,
                speedMultiplier: speedMult
            ))
            enemies.append(WaveEnemy(
                type: EnemyID.tank.rawValue,
                count: tankCount,
                healthMultiplier: healthMult,
                speedMultiplier: speedMult
            ))
        } else {
            // Late: all types with bosses (remainder goes to fast)
            let basicCount = baseCount / 4
            let tankCount = baseCount / 4
            let fastCount = baseCount - basicCount - tankCount
            enemies.append(WaveEnemy(
                type: EnemyID.basic.rawValue,
                count: basicCount,
                healthMultiplier: healthMult,
                speedMultiplier: speedMult
            ))
            enemies.append(WaveEnemy(
                type: EnemyID.fast.rawValue,
                count: fastCount,
                healthMultiplier: healthMult,
                speedMultiplier: speedMult
            ))
            enemies.append(WaveEnemy(
                type: EnemyID.tank.rawValue,
                count: tankCount,
                healthMultiplier: healthMult,
                speedMultiplier: speedMult
            ))
        }

        // Boss waves every N waves
        if number % BalanceConfig.Waves.bossWaveInterval == 0 {
            enemies.append(WaveEnemy(
                type: EnemyID.boss.rawValue,
                count: 1,
                healthMultiplier: healthMult * BalanceConfig.Waves.bossHealthMultiplier,
                speedMultiplier: speedMult * BalanceConfig.Waves.bossSpeedMultiplier
            ))
        }

        // Bonus Hash increases with wave number
        let bonusHash = number * BalanceConfig.Waves.hashBonusPerWave

        return TDWave(
            waveNumber: number,
            enemies: enemies,
            delayBetweenSpawns: BalanceConfig.spawnDelay(waveNumber: number),
            bonusHash: bonusHash
        )
    }

    // MARK: - Wave Execution

    /// Start a wave
    static func startWave(state: inout TDGameState, wave: TDWave) {
        state.waveInProgress = true
        state.currentWave = wave.waveNumber
        state.waveEnemiesRemaining = wave.totalEnemies
        state.waveEnemiesSpawned = 0
    }

    /// Spawn next enemy in wave
    static func spawnNextEnemy(
        state: inout TDGameState,
        wave: TDWave,
        currentTime: TimeInterval,
        unlockedSectorIds: Set<String>? = nil
    ) -> TDEnemy? {
        // Get available lanes for spawning
        let lanes = getAvailableLanes(state: state, unlockedSectorIds: unlockedSectorIds)
        guard !lanes.isEmpty else { return nil }

        // Find next enemy to spawn
        var spawnedSoFar = 0
        for waveEnemy in wave.enemies {
            let countToSpawn = waveEnemy.count
            let spawnedFromThisType = max(0, state.waveEnemiesSpawned - spawnedSoFar)

            if spawnedFromThisType < countToSpawn {
                // Select a lane for this enemy (rotate through available lanes)
                let laneIndex = state.waveEnemiesSpawned % lanes.count
                let selectedLane = lanes[laneIndex]

                // Path index must match the lane index in state.paths
                // (paths are ordered the same as lanes in MotherboardLaneConfig)
                let pathIndex = laneIndex % max(1, state.paths.count)

                // Spawn this type from the selected lane
                let enemy = createEnemy(
                    type: waveEnemy.type,
                    pathIndex: pathIndex,
                    healthMult: waveEnemy.healthMultiplier,
                    speedMult: waveEnemy.speedMultiplier,
                    spawnPoint: selectedLane.spawnPoint,
                    laneId: selectedLane.id
                )

                state.waveEnemiesSpawned += 1
                return enemy
            }

            spawnedSoFar += countToSpawn
        }

        return nil
    }

    /// Get available lanes for spawning based on unlocked sectors
    static func getAvailableLanes(state: TDGameState, unlockedSectorIds: Set<String>? = nil) -> [SectorLane] {
        // For motherboard maps, use the 8-lane system
        if state.map.theme == "motherboard" {
            let allLanes = MotherboardLaneConfig.createAllLanes()
            let unlocked = unlockedSectorIds ?? Set([SectorID.power.rawValue])

            // Return only unlocked lanes
            return allLanes.filter { lane in
                lane.isStarterLane || unlocked.contains(lane.sectorId)
            }
        }

        // Fallback for non-motherboard maps: create a single lane from first spawn point
        guard let firstSpawnPoint = state.map.spawnPoints.first else { return [] }

        let fallbackLane = SectorLane(
            id: "fallback",
            sectorId: "fallback",
            displayName: "Main",
            path: EnemyPath(id: "fallback_path", waypoints: [firstSpawnPoint, CGPoint(x: 2100, y: 2100)]),
            spawnPoint: firstSpawnPoint,
            themeColorHex: "#4488ff",
            unlockCost: 0,
            unlockOrder: 0,
            prerequisites: []
        )
        return [fallbackLane]
    }

    /// Create enemy from config
    static func createEnemy(
        type: String,
        pathIndex: Int,
        healthMult: CGFloat,
        speedMult: CGFloat,
        spawnPoint: CGPoint,
        laneId: String? = nil
    ) -> TDEnemy {
        let config = GameConfigLoader.shared
        let enemyConfig = config.getEnemy(type)

        let baseHealth = CGFloat(enemyConfig?.health ?? BalanceConfig.EnemyDefaults.health)
        let baseSpeed = CGFloat(enemyConfig?.speed ?? BalanceConfig.EnemyDefaults.speed)
        let baseDamage = CGFloat(enemyConfig?.damage ?? BalanceConfig.EnemyDefaults.damage)

        return TDEnemy(
            id: RandomUtils.generateId(),
            type: type,
            x: spawnPoint.x,
            y: spawnPoint.y,
            pathIndex: pathIndex,
            pathProgress: 0,
            health: baseHealth * healthMult,
            maxHealth: baseHealth * healthMult,
            speed: baseSpeed * speedMult,
            damage: baseDamage,
            hashValue: enemyConfig?.hashValue ?? BalanceConfig.EnemyDefaults.hashValue,
            xpValue: enemyConfig?.hashValue ?? BalanceConfig.EnemyDefaults.hashValue,
            size: CGFloat(enemyConfig?.size ?? BalanceConfig.EnemyDefaults.size),
            color: enemyConfig?.color ?? BalanceConfig.EnemyDefaults.color,
            shape: enemyConfig?.shape ?? BalanceConfig.EnemyDefaults.shape,
            isBoss: enemyConfig?.isBoss ?? false,
            laneId: laneId
        )
    }

    /// Check if wave is complete
    static func isWaveComplete(state: TDGameState) -> Bool {
        // Wave complete when all enemies spawned and killed/reached core
        return state.waveEnemiesSpawned >= state.waveEnemiesRemaining &&
               state.enemies.allSatisfy { $0.isDead || $0.reachedCore }
    }

    /// Complete wave and award bonus
    static func completeWave(state: inout TDGameState, wave: TDWave) {
        state.waveInProgress = false
        state.wavesCompleted += 1
        state.stats.wavesCompleted += 1

        // Award wave completion bonus (subject to Hash storage cap)
        let actualBonus = state.addHash(wave.bonusHash)
        state.stats.hashEarned += actualBonus

        AnalyticsService.shared.trackWaveCompleted(waveNumber: state.wavesCompleted)

        // Countdown to next wave
        state.nextWaveCountdown = BalanceConfig.Waves.waveCooldown
    }

    /// Update wave countdown
    static func updateWaveCountdown(state: inout TDGameState, deltaTime: TimeInterval) {
        if !state.waveInProgress && state.nextWaveCountdown > 0 {
            state.nextWaveCountdown -= deltaTime
        }
    }

    // MARK: - Wave Info

    /// Get wave preview info
    static func getWavePreview(wave: TDWave) -> [String: Int] {
        var counts: [String: Int] = [:]
        for enemy in wave.enemies {
            counts[enemy.type, default: 0] += enemy.count
        }
        return counts
    }

    /// Check if all waves completed (victory condition)
    static func checkVictory(state: TDGameState, totalWaves: Int) -> Bool {
        return state.wavesCompleted >= totalWaves && !state.waveInProgress
    }
}
