import Foundation
import CoreGraphics

// MARK: - Game Config (Codable)

struct GameConfigData: Codable {
    var weapons: [String: WeaponConfig]?  // Optional - weapons now defined via Protocols
    var arenas: [String: ArenaConfig]
    var enemies: [String: EnemyConfig]
    var spawning: SpawnConfig
    var upgrades: UpgradePool
    var bossUpgrades: UpgradePool?  // Boss-only upgrades (lifesteal, thorns, phoenix, etc.)

    enum CodingKeys: String, CodingKey {
        case weapons, arenas, enemies, spawning, upgrades
        case bossUpgrades = "dungeonUpgrades"  // JSON key preserved for config compat
    }
}

// MARK: - Weapon Config

struct WeaponConfig: Codable {
    var id: String
    var name: String
    var description: String
    var rarity: String
    var icon: String
    var damage: Double
    var range: Double
    var attackSpeed: Double
    var projectileType: String
    var color: String
    var towerName: String?  // Tower name for TD mode (e.g., "Archer Tower")
    var special: WeaponSpecial?
}

struct WeaponSpecial: Codable {
    var projectileCount: Int?
    var pierce: Int?
    var splash: Double?
    var homing: Bool?
    var slow: Double?         // Slow amount for Ice weapons/towers
    var slowDuration: Double? // Duration of slow effect
    var chain: Int?           // Chain count for Lightning weapons/towers
}

// MARK: - Arena Config

struct ArenaConfig: Codable {
    var id: String
    var name: String
    var rarity: String
    var width: Double
    var height: Double
    var backgroundColor: String
    var theme: String
    var bossType: String?
    var particleEffect: String?
    var obstacles: [ObstacleConfig]?
    var hazards: [HazardConfig]?
    var effectZones: [EffectZoneConfig]?
    var events: [EventConfig]?
    var globalModifier: GlobalModifierConfig?

    enum CodingKeys: String, CodingKey {
        case id, name, rarity, width, height, backgroundColor, theme
        case bossType = "dungeonType"  // JSON key preserved for config compat
        case particleEffect, obstacles, hazards, effectZones, events, globalModifier
    }
}

struct ObstacleConfig: Codable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    var color: String
    var type: String
}

struct HazardConfig: Codable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    var damage: Double
    var type: String
}

struct EffectZoneConfig: Codable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    var type: String
    var speedMultiplier: Double?
    var healPerSecond: Double?
    var visualEffect: String?
}

struct EventConfig: Codable {
    var type: String
    var intervalMin: Double
    var intervalMax: Double
    var damage: Double?
    var radius: Double?
    var duration: Double?
}

struct GlobalModifierConfig: Codable {
    var playerSpeedMultiplier: Double?
    var enemySpeedMultiplier: Double?
    var damageMultiplier: Double?
    var enemyDamageMultiplier: Double?
    var projectileSpeedMultiplier: Double?
    var description: String
}

// MARK: - Enemy Config

struct EnemyConfig: Codable {
    var id: String
    var name: String
    var health: Double
    var speed: Double
    var damage: Double
    var hashValue: Int
    var size: Double
    var color: String
    var shape: String
    var isBoss: Bool?

    init(
        id: String,
        name: String,
        health: Double,
        speed: Double,
        damage: Double,
        hashValue: Int,
        size: Double,
        color: String,
        shape: String,
        isBoss: Bool? = nil
    ) {
        self.id = id
        self.name = name
        self.health = health
        self.speed = speed
        self.damage = damage
        self.hashValue = hashValue
        self.size = size
        self.color = color
        self.shape = shape
        self.isBoss = isBoss
    }
}

// MARK: - Spawn Config

struct SpawnConfig: Codable {
    var maxEnemiesOnScreen: Int?
    var waves: [WaveConfig]
}

struct WaveConfig: Codable {
    var startTime: Double
    var enemiesPerMinute: Double
    var enemyTypes: [String]
}

// MARK: - Upgrade Pool

struct UpgradePool: Codable {
    var common: [UpgradeConfig]
    var rare: [UpgradeConfig]
    var epic: [UpgradeConfig]
    var legendary: [UpgradeConfig]
}

struct UpgradeConfig: Codable {
    var id: String
    var name: String
    var description: String
    var icon: String
    var rarity: String
    var effect: UpgradeEffectConfig
}

struct UpgradeEffectConfig: Codable {
    var type: String
    var target: String
    var value: Double
    var isMultiplier: Bool?
}

// MARK: - Config Loader

class GameConfigLoader {
    static let shared = GameConfigLoader()

    private(set) var config: GameConfigData?

    private init() {
        loadConfig()
    }

    private func loadConfig() {
        guard let url = Bundle.main.url(forResource: "GameConfig", withExtension: "json") else {
            print("[GameConfigLoader] ERROR: GameConfig.json not found in bundle")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            config = try decoder.decode(GameConfigData.self, from: data)
        } catch {
            print("[GameConfigLoader] ERROR: Failed to decode GameConfig.json: \(error)")
        }
    }

    // MARK: - Convenience Methods

    func getArena(_ id: String) -> ArenaConfig? {
        return config?.arenas[id]
    }

    func getEnemy(_ id: String) -> EnemyConfig? {
        return config?.enemies[id]
    }

    func getSpawnWaves() -> [WaveConfig] {
        return config?.spawning.waves ?? []
    }

    func getMaxEnemiesOnScreen() -> Int {
        return config?.spawning.maxEnemiesOnScreen ?? 200
    }

    func getUpgrades(rarity: Rarity) -> [UpgradeConfig] {
        guard let pool = config?.upgrades else { return [] }
        switch rarity {
        case .common: return pool.common
        case .rare: return pool.rare
        case .epic: return pool.epic
        case .legendary: return pool.legendary
        }
    }

    /// Get boss-only upgrades (lifesteal, thorns, phoenix, etc.)
    func getBossUpgrades(rarity: Rarity) -> [UpgradeConfig] {
        guard let pool = config?.bossUpgrades else { return [] }
        switch rarity {
        case .common: return pool.common
        case .rare: return pool.rare
        case .epic: return pool.epic
        case .legendary: return pool.legendary
        }
    }

    // MARK: - Conversion Helpers

    func createArenaData(from config: ArenaConfig) -> ArenaData {
        return ArenaData(
            type: config.id,
            name: config.name,
            width: CGFloat(config.width),
            height: CGFloat(config.height),
            backgroundColor: config.backgroundColor,
            obstacles: config.obstacles?.map { obs in
                Obstacle(
                    id: RandomUtils.generateId(),
                    x: CGFloat(obs.x),
                    y: CGFloat(obs.y),
                    width: CGFloat(obs.width),
                    height: CGFloat(obs.height),
                    color: obs.color,
                    type: obs.type
                )
            } ?? [],
            hazards: config.hazards?.map { haz in
                Hazard(
                    id: RandomUtils.generateId(),
                    x: CGFloat(haz.x),
                    y: CGFloat(haz.y),
                    width: CGFloat(haz.width),
                    height: CGFloat(haz.height),
                    damage: CGFloat(haz.damage),
                    damageType: "generic",
                    type: haz.type
                )
            } ?? [],
            effectZones: config.effectZones?.map { zone in
                var effects: [String: CGFloat] = [:]
                if let speed = zone.speedMultiplier {
                    effects["speedMultiplier"] = CGFloat(speed)
                }
                if let heal = zone.healPerSecond {
                    effects["healPerSecond"] = CGFloat(heal)
                }
                return ArenaEffectZone(
                    id: RandomUtils.generateId(),
                    x: CGFloat(zone.x),
                    y: CGFloat(zone.y),
                    width: CGFloat(zone.width),
                    height: CGFloat(zone.height),
                    effects: effects,
                    type: zone.type,
                    speedMultiplier: zone.speedMultiplier.map { CGFloat($0) },
                    healPerSecond: zone.healPerSecond.map { CGFloat($0) },
                    visualEffect: zone.visualEffect
                )
            },
            events: config.events?.map { evt in
                ArenaEvent(
                    type: evt.type,
                    intervalMin: evt.intervalMin,
                    intervalMax: evt.intervalMax,
                    lastTriggered: 0,
                    nextTrigger: Double.random(in: evt.intervalMin...evt.intervalMax),
                    damage: evt.damage.map { CGFloat($0) },
                    radius: evt.radius.map { CGFloat($0) },
                    duration: evt.duration
                )
            },
            particleEffect: config.particleEffect,
            globalModifier: config.globalModifier.map { mod in
                GlobalArenaModifier(
                    playerSpeedMultiplier: mod.playerSpeedMultiplier.map { CGFloat($0) },
                    enemySpeedMultiplier: mod.enemySpeedMultiplier.map { CGFloat($0) },
                    damageMultiplier: mod.damageMultiplier.map { CGFloat($0) },
                    enemyDamageMultiplier: mod.enemyDamageMultiplier.map { CGFloat($0) },
                    projectileSpeedMultiplier: mod.projectileSpeedMultiplier.map { CGFloat($0) },
                    description: mod.description
                )
            },
            decorations: nil
        )
    }

    func createWeapon(from config: WeaponConfig) -> Weapon {
        return Weapon(
            type: config.id,
            level: 1,
            damage: CGFloat(config.damage),
            range: CGFloat(config.range),
            attackSpeed: CGFloat(config.attackSpeed),
            lastAttackTime: 0,
            projectileCount: config.special?.projectileCount ?? 1,
            pierce: config.special?.pierce,
            splash: config.special?.splash.map { CGFloat($0) },
            homing: config.special?.homing,
            slow: config.special?.slow.map { CGFloat($0) },
            slowDuration: config.special?.slowDuration,
            chain: config.special?.chain,
            color: config.color,
            particleEffect: nil,
            towerName: config.towerName
        )
    }
}
