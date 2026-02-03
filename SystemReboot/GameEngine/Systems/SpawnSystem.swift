import Foundation
import CoreGraphics

// MARK: - Spawn System

class SpawnSystem {

    /// Update enemy spawning based on time elapsed
    static func update(state: inout GameState, context: FrameContext) {
        let config = GameConfigLoader.shared

        // Get max enemies on screen
        let maxEnemies = config.getMaxEnemiesOnScreen()
        if state.enemies.count >= maxEnemies {
            return
        }

        // Get spawn waves
        let waves = config.getSpawnWaves()
        guard !waves.isEmpty else { return }

        // Find current wave based on time
        var currentWave = waves[0]
        for wave in waves {
            if state.timeElapsed >= wave.startTime {
                currentWave = wave
            }
        }

        // Calculate spawn rate with survival event modifier
        let survivalSpawnModifier = Double(SurvivalArenaSystem.getSpawnRateModifier(state: state))
        let enemiesPerSecond = (currentWave.enemiesPerMinute / 60.0) * survivalSpawnModifier
        let spawnChance = enemiesPerSecond / 60.0 // Assuming 60fps

        if Double.random(in: 0...1) < spawnChance {
            // Pick random enemy type
            guard let enemyType = currentWave.enemyTypes.randomElement() else { return }

            // Get enemy config
            guard let enemyConfig = config.getEnemy(enemyType) else { return }

            // Spawn enemy
            let enemy = EnemySystem.spawnEnemy(state: &state, type: enemyType, config: enemyConfig)
            state.enemies.append(enemy)
        }
    }

    /// Spawn a wave of enemies
    static func spawnWave(state: inout GameState, count: Int, types: [String] = ["zombie", "runner"]) {
        let config = GameConfigLoader.shared

        for _ in 0..<count {
            guard let enemyType = types.randomElement(),
                  let enemyConfig = config.getEnemy(enemyType) else { continue }

            let enemy = EnemySystem.spawnEnemy(state: &state, type: enemyType, config: enemyConfig)
            state.enemies.append(enemy)
        }
    }

    /// Spawn a boss enemy
    static func spawnBoss(state: inout GameState, context: FrameContext? = nil, type: String = "boss") {
        let config = GameConfigLoader.shared

        guard let bossConfig = config.getEnemy(type) else { return }

        // Calculate boss HP with time-based scaling
        let minutesElapsed = state.timeElapsed / 60.0
        let timeScaling = 1 + (minutesElapsed * BalanceConfig.BossSurvivor.healthScalingPerMinute)

        // Create custom boss config with scaled health
        var scaledConfig = bossConfig
        scaledConfig.health = bossConfig.health * timeScaling * BalanceConfig.BossSurvivor.baseHealthMultiplier

        let boss = EnemySystem.spawnEnemy(state: &state, type: type, config: scaledConfig)
        state.enemies.append(boss)
        state.lastBossSpawnTime = state.timeElapsed

        // Boss spawn particles
        ParticleFactory.createExplosion(
            state: &state,
            x: boss.x,
            y: boss.y,
            color: "#ff00ff",
            count: 50,
            size: 30
        )
    }
}
