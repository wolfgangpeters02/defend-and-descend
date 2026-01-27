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
        let baseCount = 5 + number * 2

        // Health and speed multipliers scale with wave
        let healthMult: CGFloat = 1.0 + CGFloat(number - 1) * 0.15  // +15% per wave
        let speedMult: CGFloat = 1.0 + CGFloat(number - 1) * 0.02   // +2% per wave

        // Composition changes based on wave number
        if number <= 3 {
            // Early waves: only basic enemies
            enemies.append(WaveEnemy(
                type: "basic",
                count: baseCount,
                healthMultiplier: healthMult,
                speedMultiplier: speedMult
            ))
        } else if number <= 6 {
            // Mid-early: basic + fast
            enemies.append(WaveEnemy(
                type: "basic",
                count: baseCount / 2,
                healthMultiplier: healthMult,
                speedMultiplier: speedMult
            ))
            enemies.append(WaveEnemy(
                type: "fast",
                count: baseCount / 2,
                healthMultiplier: healthMult,
                speedMultiplier: speedMult
            ))
        } else if number <= 10 {
            // Mid: basic + fast + tank
            enemies.append(WaveEnemy(
                type: "basic",
                count: baseCount / 3,
                healthMultiplier: healthMult,
                speedMultiplier: speedMult
            ))
            enemies.append(WaveEnemy(
                type: "fast",
                count: baseCount / 3,
                healthMultiplier: healthMult,
                speedMultiplier: speedMult
            ))
            enemies.append(WaveEnemy(
                type: "tank",
                count: baseCount / 4,
                healthMultiplier: healthMult,
                speedMultiplier: speedMult
            ))
        } else {
            // Late: all types with bosses
            enemies.append(WaveEnemy(
                type: "basic",
                count: baseCount / 4,
                healthMultiplier: healthMult,
                speedMultiplier: speedMult
            ))
            enemies.append(WaveEnemy(
                type: "fast",
                count: baseCount / 3,
                healthMultiplier: healthMult,
                speedMultiplier: speedMult
            ))
            enemies.append(WaveEnemy(
                type: "tank",
                count: baseCount / 4,
                healthMultiplier: healthMult,
                speedMultiplier: speedMult
            ))
        }

        // Boss waves every 5 waves
        if number % 5 == 0 {
            enemies.append(WaveEnemy(
                type: "boss",
                count: 1,
                healthMultiplier: healthMult * 2,
                speedMultiplier: speedMult * 0.8
            ))
        }

        // Bonus gold increases with wave number
        let bonusGold = number * 10

        return TDWave(
            waveNumber: number,
            enemies: enemies,
            delayBetweenSpawns: max(0.3, 0.8 - CGFloat(number) * 0.02),  // Gets faster
            bonusGold: bonusGold
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
        currentTime: TimeInterval
    ) -> TDEnemy? {
        // Find next enemy to spawn
        var spawnedSoFar = 0
        for waveEnemy in wave.enemies {
            let countToSpawn = waveEnemy.count
            let spawnedFromThisType = max(0, state.waveEnemiesSpawned - spawnedSoFar)

            if spawnedFromThisType < countToSpawn {
                // Spawn this type
                let enemy = createEnemy(
                    type: waveEnemy.type,
                    pathIndex: waveEnemy.pathIndex,
                    healthMult: waveEnemy.healthMultiplier,
                    speedMult: waveEnemy.speedMultiplier,
                    spawnPoint: state.map.spawnPoints.first ?? .zero
                )

                state.waveEnemiesSpawned += 1
                return enemy
            }

            spawnedSoFar += countToSpawn
        }

        return nil
    }

    /// Create enemy from config
    static func createEnemy(
        type: String,
        pathIndex: Int,
        healthMult: CGFloat,
        speedMult: CGFloat,
        spawnPoint: CGPoint
    ) -> TDEnemy {
        let config = GameConfigLoader.shared
        let enemyConfig = config.getEnemy(type)

        let baseHealth = CGFloat(enemyConfig?.health ?? 20)
        let baseSpeed = CGFloat(enemyConfig?.speed ?? 80)
        let baseDamage = CGFloat(enemyConfig?.damage ?? 10)

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
            goldValue: enemyConfig?.coinValue ?? 1,
            xpValue: enemyConfig?.coinValue ?? 1,
            size: CGFloat(enemyConfig?.size ?? 12),
            color: enemyConfig?.color ?? "#ff4444",
            shape: enemyConfig?.shape ?? "square",
            isBoss: enemyConfig?.isBoss ?? false
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
        let actualBonus = state.addHash(wave.bonusGold)
        state.stats.goldEarned += actualBonus

        // Countdown to next wave
        state.nextWaveCountdown = 10.0  // 10 seconds between waves
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
