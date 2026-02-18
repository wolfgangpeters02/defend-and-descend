import Foundation
import CoreGraphics

// MARK: - Tutorial Spawn System
// Creates scripted enemy waves for the FTUE camera tutorial.
// Batch 1: Invulnerable fast enemies that leak to CPU (teaches consequence)
// Batch 2: Weak mixed enemies that die instantly to first tower (teaches reward)

struct TutorialSpawnSystem {

    // MARK: - Batch 1 (Immune leak wave)

    /// Create batch 1 enemies: fast, high-HP, immune — guaranteed to leak to CPU
    static func createBatch1Enemies(spawnPoint: CGPoint, pathIndex: Int) -> [TDEnemy] {
        (0..<BalanceConfig.Tutorial.batch1Count).map { _ in
            TDEnemy(
                id: RandomUtils.generateId(),
                type: EnemyID.basic.rawValue,
                x: spawnPoint.x,
                y: spawnPoint.y,
                pathIndex: pathIndex,
                health: BalanceConfig.Tutorial.batch1Health,
                maxHealth: BalanceConfig.Tutorial.batch1Health,
                speed: BalanceConfig.Tutorial.batch1Speed,
                damage: BalanceConfig.Tutorial.batch1Damage,
                hashValue: 0,
                xpValue: 0,
                size: BalanceConfig.Tutorial.batch1Size,
                color: "#ff4444",
                shape: "circle",
                immuneToTowers: true
            )
        }
    }

    // MARK: - Batch 2 (First kills wave)

    /// Create batch 2 enemies: mixed types, all one-shottable by Kernel Pulse (25 dmg)
    static func createBatch2Enemies(spawnPoint: CGPoint, pathIndex: Int) -> [TDEnemy] {
        let configs: [(type: String, hp: CGFloat, speed: CGFloat, size: CGFloat, color: String, shape: String)] = [
            (EnemyID.basic.rawValue, 21, 80, 12, "#ff4444", "circle"),
            (EnemyID.fast.rawValue, 11, 150, 8, "#ff8800", "triangle"),
            (EnemyID.basic.rawValue, 21, 80, 12, "#ff4444", "circle"),
            (EnemyID.tank.rawValue, BalanceConfig.Tutorial.batch2TankHealth, 40, 20, "#8844ff", "square"),
            (EnemyID.fast.rawValue, 11, 150, 8, "#ff8800", "triangle"),
        ]

        return configs.map { c in
            TDEnemy(
                id: RandomUtils.generateId(),
                type: c.type,
                x: spawnPoint.x,
                y: spawnPoint.y,
                pathIndex: pathIndex,
                health: c.hp,
                maxHealth: c.hp,
                speed: c.speed,
                damage: BalanceConfig.Tutorial.batch1Damage,
                hashValue: 1,
                xpValue: 1,
                size: c.size,
                color: c.color,
                shape: c.shape,
                laneId: "lane_psu"
            )
        }
    }
}
