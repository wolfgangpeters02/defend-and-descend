import Foundation
import CoreGraphics

// MARK: - Wave Definition

struct TDWave {
    var waveNumber: Int
    var enemies: [WaveEnemy]
    var delayBetweenSpawns: TimeInterval = 0.5
    var bonusHash: Int = 0

    /// Total enemies in wave
    var totalEnemies: Int {
        enemies.reduce(0) { $0 + $1.count }
    }
}

struct WaveEnemy {
    var type: String
    var count: Int
    var healthMultiplier: CGFloat = 1.0
    var speedMultiplier: CGFloat = 1.0
    var pathIndex: Int = 0  // Which path to use (for multi-path maps)
}

