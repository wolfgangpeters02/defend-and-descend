import Foundation
import CoreGraphics

// MARK: - Tower Defense Specific Types

// MARK: - TD Game State

struct TDGameState {
    // Session
    var sessionId: String
    var playerId: String
    var startTime: TimeInterval
    var gameTime: Double = 0

    // Map
    var map: TDMap
    var paths: [EnemyPath]

    // Core (The Guardian in TD mode)
    var core: TDCore

    // Towers (placed by player)
    var towers: [Tower]
    var towerSlots: [TowerSlot]

    // Enemies on the field
    var enemies: [TDEnemy]

    // Projectiles
    var projectiles: [Projectile]
    var particles: [Particle]

    // Wave system
    var currentWave: Int = 0
    var waveInProgress: Bool = false
    var waveEnemiesRemaining: Int = 0
    var waveEnemiesSpawned: Int = 0
    var nextWaveCountdown: TimeInterval = 0
    var wavesCompleted: Int = 0

    // Resources (System: Reboot - Watts currency)
    var gold: Int = 100  // Watts - primary currency
    var lives: Int = 20  // Legacy - kept for compatibility, represents max efficiency baseline

    // Efficiency System (System: Reboot core mechanic)
    // Efficiency determines Watts income rate - no death, just reduced income
    var leakCounter: Int = 0           // Increments when virus reaches CPU
    var leakDecayTimer: TimeInterval = 0  // Timer for leak counter decay
    var efficiency: CGFloat {
        // efficiency = max(0, 100 - leakCounter * 5)
        // Each leaked virus reduces efficiency by 5%
        return max(0, min(100, 100 - CGFloat(leakCounter) * 5))
    }
    var baseWattsPerSecond: CGFloat = 10  // Base income rate at 100% efficiency
    var wattsPerSecond: CGFloat {
        return baseWattsPerSecond * (efficiency / 100)
    }
    var wattsAccumulator: CGFloat = 0  // Accumulates fractional watts

    // Passive Data generation (soft-lock prevention)
    var virusesKilledTotal: Int = 0    // Total viruses killed by firewalls
    var dataFromKills: Int {
        return virusesKilledTotal / 1000  // 1 Data per 1000 kills
    }

    // Stats
    var stats: TDSessionStats = TDSessionStats()

    // UI state
    var isGameOver: Bool = false
    var isPaused: Bool = false
    var victory: Bool = false
    var selectedTowerSlot: String?  // Currently selected slot for placement
    var selectedTowerId: String?    // Currently selected tower for info/upgrade

    // Drag state for tower merging and placement
    var dragState: TowerDragState?

    // Blocker Nodes (System: Reboot - Path Control)
    // Player can place blockers to reroute viruses
    var blockerNodes: [BlockerNode] = []
    var blockerSlots: [BlockerSlot] = []
    var maxBlockerSlots: Int = 3  // Start with 3, upgradeable

    // Base paths (original paths without blockers)
    var basePaths: [EnemyPath] = []

    /// Number of available blocker slots
    var availableBlockerSlots: Int {
        return maxBlockerSlots - blockerNodes.count
    }

    /// Check if a blocker can be placed
    var canPlaceBlocker: Bool {
        return availableBlockerSlots > 0
    }
}

// MARK: - Tower Drag State

struct TowerDragState {
    enum DragSource {
        case existingTower(towerId: String, slotId: String)
        case deckWeapon(weaponType: String)
    }

    var source: DragSource
    var currentPosition: CGPoint
    var validMergeTargetId: String?      // Tower ID that can be merged with
    var validPlacementSlotId: String?    // Slot ID for valid placement
    var isValidDrop: Bool = false
}

// MARK: - Blocker Node (System: Reboot - Path Control)
// Player can place blockers at trace intersections to reroute viruses
// Start with 3 slots, upgradeable. Blockers are free to place/move.

struct BlockerNode: Identifiable, Codable {
    var id: String
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat = 30  // Visual size (octagon)

    var position: CGPoint {
        CGPoint(x: x, y: y)
    }

    /// Create a blocker at a position
    static func create(at position: CGPoint) -> BlockerNode {
        BlockerNode(
            id: RandomUtils.generateId(),
            x: position.x,
            y: position.y
        )
    }
}

// MARK: - Blocker Slot (Available placement positions for blockers)
// Slots are at trace intersections where viruses can be rerouted

struct BlockerSlot: Identifiable, Codable {
    var id: String
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat = 40  // Touch target size
    var occupied: Bool = false
    var blockerId: String?

    var position: CGPoint {
        CGPoint(x: x, y: y)
    }
}

// MARK: - TD Session Stats

struct TDSessionStats {
    var enemiesKilled: Int = 0
    var towersPlaced: Int = 0
    var towersUpgraded: Int = 0
    var goldEarned: Int = 0
    var goldSpent: Int = 0
    var damageDealt: CGFloat = 0
    var wavesCompleted: Int = 0
}

// MARK: - TD Map

struct TDMap {
    var id: String
    var name: String
    var width: CGFloat
    var height: CGFloat
    var backgroundColor: String
    var theme: String
    var particleEffect: String?

    var obstacles: [MapObstacle]
    var hazards: [MapHazard]
    var effectZones: [MapEffectZone]

    var spawnPoints: [CGPoint]  // Where enemies spawn
    var corePosition: CGPoint   // Where enemies are trying to reach

    var globalModifier: MapModifier?
}

// MARK: - Tower

struct Tower: Identifiable {
    var id: String
    var weaponType: String  // Links to WeaponTower
    var level: Int = 1

    // Position
    var x: CGFloat
    var y: CGFloat
    var slotId: String

    // Stats (derived from WeaponTower + level)
    var damage: CGFloat
    var range: CGFloat
    var attackSpeed: CGFloat
    var lastAttackTime: TimeInterval = 0

    // Special effects
    var projectileCount: Int = 1
    var pierce: Int = 0
    var splash: CGFloat = 0
    var homing: Bool = false
    var slow: CGFloat?
    var slowDuration: TimeInterval?
    var chain: Int?

    // Visual
    var color: String
    var rotation: CGFloat = 0  // Current facing angle
    var targetId: String?      // Current target enemy

    // Tower name for display
    var towerName: String

    // Merge system (1-3 stars)
    var mergeLevel: Int = 1

    var position: CGPoint {
        CGPoint(x: x, y: y)
    }

    /// Calculate upgrade cost
    var upgradeCost: Int {
        guard level < 10 else { return 0 }
        return 100 + (level * 50)
    }

    /// Check if can upgrade
    var canUpgrade: Bool {
        return level < 10
    }

    /// Check if tower can be merged (not max stars)
    var canMerge: Bool {
        return mergeLevel < 3
    }

    /// Check if this tower can merge with another
    func canMergeWith(_ other: Tower) -> Bool {
        return weaponType == other.weaponType &&
               mergeLevel == other.mergeLevel &&
               canMerge &&
               id != other.id
    }

    /// Create tower from WeaponTower
    static func from(weapon: WeaponTower, at slot: TowerSlot, mergeLevel: Int = 1) -> Tower {
        return Tower(
            id: RandomUtils.generateId(),
            weaponType: weapon.id,
            level: weapon.level,
            x: slot.x,
            y: slot.y,
            slotId: slot.id,
            damage: weapon.damage,
            range: weapon.range,
            attackSpeed: weapon.attackSpeed,
            projectileCount: weapon.projectileCount,
            pierce: weapon.pierce,
            splash: weapon.splash,
            homing: weapon.homing,
            slow: weapon.slow,
            slowDuration: weapon.slowDuration,
            chain: weapon.chain,
            color: weapon.color,
            towerName: weapon.towerName,
            mergeLevel: mergeLevel
        )
    }

    /// Apply level upgrade
    mutating func upgrade() {
        guard canUpgrade else { return }
        level += 1
        let multiplier: CGFloat = 1.1  // +10% per level
        damage *= multiplier
        range *= 1.05  // +5% range
        attackSpeed *= 1.03  // +3% speed
    }

    /// Apply merge upgrade (when another tower merges into this one)
    mutating func applyMerge() {
        guard canMerge else { return }
        mergeLevel += 1
        damage *= 1.5       // +50% damage
        range *= 1.1        // +10% range
        attackSpeed *= 1.1  // +10% attack speed
    }
}

// MARK: - Merge Result

enum TowerMergeResult {
    case success(mergedTower: Tower, freedSlotId: String)
    case cannotMerge
    case sameTower
    case differentTypes
    case differentMergeLevels
    case maxMergeLevel
}

// MARK: - TD Core (The Guardian)

struct TDCore {
    var x: CGFloat
    var y: CGFloat
    var health: CGFloat
    var maxHealth: CGFloat
    var armor: CGFloat = 0

    // Core can auto-attack (Guardian firing)
    var canAttack: Bool = true
    var damage: CGFloat = 10
    var range: CGFloat = 150
    var attackSpeed: CGFloat = 1.0
    var lastAttackTime: TimeInterval = 0

    var position: CGPoint {
        CGPoint(x: x, y: y)
    }

    var isDead: Bool {
        health <= 0
    }

    mutating func takeDamage(_ amount: CGFloat) {
        let reduced = amount * (1 - armor)
        health = max(0, health - reduced)
    }
}

// MARK: - TD Enemy

struct TDEnemy: Identifiable {
    var id: String
    var type: String

    // Position and movement
    var x: CGFloat
    var y: CGFloat
    var pathIndex: Int = 0      // Which path this enemy follows
    var pathProgress: CGFloat = 0  // Progress along path (0.0 to 1.0)

    // Stats
    var health: CGFloat
    var maxHealth: CGFloat
    var speed: CGFloat          // Units per second along path
    var damage: CGFloat         // Damage to core on arrival

    // Rewards
    var goldValue: Int
    var xpValue: Int

    // Visual
    var size: CGFloat
    var color: String
    var shape: String

    // Status effects
    var isSlowed: Bool = false
    var slowAmount: CGFloat = 0
    var slowEndTime: TimeInterval = 0

    // State
    var isDead: Bool = false
    var reachedCore: Bool = false
    var isBoss: Bool = false

    var position: CGPoint {
        CGPoint(x: x, y: y)
    }

    /// Current speed accounting for slow effects
    var currentSpeed: CGFloat {
        if isSlowed {
            return speed * (1 - slowAmount)
        }
        return speed
    }

    /// Apply slow effect
    mutating func applySlow(amount: CGFloat, duration: TimeInterval, currentTime: TimeInterval) {
        isSlowed = true
        slowAmount = max(slowAmount, amount)  // Keep strongest slow
        slowEndTime = max(slowEndTime, currentTime + duration)
    }

    /// Update slow status
    mutating func updateSlow(currentTime: TimeInterval) {
        if isSlowed && currentTime >= slowEndTime {
            isSlowed = false
            slowAmount = 0
        }
    }
}

// MARK: - Wave Definition

struct TDWave {
    var waveNumber: Int
    var enemies: [WaveEnemy]
    var delayBetweenSpawns: TimeInterval = 0.5
    var bonusGold: Int = 0

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

// MARK: - TD Wave Configuration

struct TDWaveConfig: Codable {
    var waves: [TDWaveDefinition]
    var bossWaveInterval: Int = 10  // Boss every N waves
    var infiniteMode: Bool = false  // Endless waves after config runs out
}

struct TDWaveDefinition: Codable {
    var waveNumber: Int
    var enemies: [TDWaveEnemyDef]
    var spawnDelay: Double
    var bonusGold: Int?
}

struct TDWaveEnemyDef: Codable {
    var type: String
    var count: Int
    var healthMultiplier: Double?
    var speedMultiplier: Double?
    var pathIndex: Int?
}

// MARK: - TD Action Types (for player input)

enum TDAction {
    case selectSlot(slotId: String)
    case placeTower(weaponType: String, slotId: String)
    case selectTower(towerId: String)
    case upgradeTower(towerId: String)
    case sellTower(towerId: String)
    case startWave
    case pause
    case resume
}

// MARK: - Tower Placement Result

enum TowerPlacementResult {
    case success(tower: Tower)
    case insufficientGold(required: Int, available: Int)
    case slotOccupied
    case weaponLocked
    case invalidSlot
}

// MARK: - TD Game Result

struct TDGameResult {
    var victory: Bool
    var wavesCompleted: Int
    var enemiesKilled: Int
    var goldEarned: Int
    var towersPlaced: Int
    var timePlayed: TimeInterval

    /// Calculate XP reward
    var xpReward: Int {
        var xp = wavesCompleted * 10
        xp += enemiesKilled
        if victory {
            xp += 50  // Victory bonus
        }
        return xp
    }

    /// Calculate gold reward
    var goldReward: Int {
        var gold = goldEarned / 10  // 10% of earned gold
        if victory {
            gold += wavesCompleted * 5
        }
        return gold
    }
}

// MARK: - TD State Factory

class TDGameStateFactory {

    /// Create initial TD game state
    static func createTDGameState(
        mapId: String,
        playerProfile: PlayerProfile
    ) -> TDGameState? {
        let config = GameConfigLoader.shared

        // Get arena config (arenas = TD maps)
        guard let arenaConfig = config.getArena(mapId) else {
            print("Arena/Map '\(mapId)' not found")
            return nil
        }

        // Create TD map from arena config
        let map = createTDMap(from: arenaConfig)

        // Create paths (for now, simple path from spawn to core)
        let paths = createDefaultPaths(for: map)

        // Create core at center bottom
        let core = TDCore(
            x: map.width / 2,
            y: map.height - 50,
            health: 100,
            maxHealth: 100
        )

        // Create tower slots around the map
        let slots = createTowerSlots(for: map, avoiding: paths)

        // Create blocker slots at path intersections (turns in the path)
        let blockerSlots = createBlockerSlots(for: paths)

        return TDGameState(
            sessionId: RandomUtils.generateId(),
            playerId: playerProfile.id,
            startTime: Date().timeIntervalSince1970,
            map: map,
            paths: paths,
            core: core,
            towers: [],
            towerSlots: slots,
            enemies: [],
            projectiles: [],
            particles: [],
            blockerSlots: blockerSlots,
            basePaths: paths  // Store original paths for rerouting
        )
    }

    /// Create blocker slots at path intersections (turns)
    /// Blockers can be placed here to reroute viruses
    private static func createBlockerSlots(for paths: [EnemyPath]) -> [BlockerSlot] {
        var slots: [BlockerSlot] = []

        for path in paths {
            // Create slots at each waypoint (except start and end)
            guard path.waypoints.count > 2 else { continue }

            for i in 1..<(path.waypoints.count - 1) {
                let waypoint = path.waypoints[i]
                slots.append(BlockerSlot(
                    id: "blocker_slot_\(path.id)_\(i)",
                    x: waypoint.x,
                    y: waypoint.y
                ))
            }
        }

        return slots
    }

    /// Create TD map from arena config
    private static func createTDMap(from config: ArenaConfig) -> TDMap {
        let obstacles = config.obstacles?.map { obs in
            MapObstacle(
                id: RandomUtils.generateId(),
                x: CGFloat(obs.x),
                y: CGFloat(obs.y),
                width: CGFloat(obs.width),
                height: CGFloat(obs.height),
                color: obs.color,
                type: obs.type
            )
        } ?? []

        let hazards = config.hazards?.map { haz in
            MapHazard(
                id: RandomUtils.generateId(),
                x: CGFloat(haz.x),
                y: CGFloat(haz.y),
                width: CGFloat(haz.width),
                height: CGFloat(haz.height),
                damage: CGFloat(haz.damage),
                type: haz.type
            )
        } ?? []

        let effectZones = config.effectZones?.map { zone in
            MapEffectZone(
                id: RandomUtils.generateId(),
                x: CGFloat(zone.x),
                y: CGFloat(zone.y),
                width: CGFloat(zone.width),
                height: CGFloat(zone.height),
                type: zone.type,
                speedMultiplier: zone.speedMultiplier.map { CGFloat($0) },
                healPerSecond: zone.healPerSecond.map { CGFloat($0) },
                visualEffect: zone.visualEffect
            )
        } ?? []

        let globalMod = config.globalModifier.map { mod in
            MapModifier(
                playerSpeedMultiplier: mod.playerSpeedMultiplier.map { CGFloat($0) },
                enemySpeedMultiplier: mod.enemySpeedMultiplier.map { CGFloat($0) },
                damageMultiplier: mod.damageMultiplier.map { CGFloat($0) },
                enemyDamageMultiplier: mod.enemyDamageMultiplier.map { CGFloat($0) },
                projectileSpeedMultiplier: mod.projectileSpeedMultiplier.map { CGFloat($0) },
                description: mod.description
            )
        }

        return TDMap(
            id: config.id,
            name: config.name,
            width: CGFloat(config.width),
            height: CGFloat(config.height),
            backgroundColor: config.backgroundColor,
            theme: config.theme,
            particleEffect: config.particleEffect,
            obstacles: obstacles,
            hazards: hazards,
            effectZones: effectZones,
            spawnPoints: [CGPoint(x: CGFloat(config.width) / 2, y: 40)],  // Top center spawn (below safe area)
            corePosition: CGPoint(x: CGFloat(config.width) / 2, y: CGFloat(config.height) - 80),  // Above tower deck
            globalModifier: globalMod
        )
    }

    /// Create default enemy paths
    private static func createDefaultPaths(for map: TDMap) -> [EnemyPath] {
        // TD-style zig-zag path that stays within screen bounds
        // Use 15% margin on sides to keep path visible
        let marginX: CGFloat = map.width * 0.15
        let leftX = marginX
        let rightX = map.width - marginX
        let centerX = map.width / 2

        // Vertical segments at 20% intervals
        let topY: CGFloat = 40  // Start below safe area
        let seg1Y = map.height * 0.2
        let seg2Y = map.height * 0.4
        let seg3Y = map.height * 0.6
        let seg4Y = map.height * 0.8
        let bottomY = map.height - 80  // End above tower deck

        // Classic TD zig-zag pattern
        let waypoints: [CGPoint] = [
            CGPoint(x: centerX, y: topY),       // Start top center
            CGPoint(x: centerX, y: seg1Y),      // Down to first turn
            CGPoint(x: rightX, y: seg1Y),       // Right
            CGPoint(x: rightX, y: seg2Y),       // Down
            CGPoint(x: leftX, y: seg2Y),        // Left
            CGPoint(x: leftX, y: seg3Y),        // Down
            CGPoint(x: rightX, y: seg3Y),       // Right
            CGPoint(x: rightX, y: seg4Y),       // Down
            CGPoint(x: centerX, y: seg4Y),      // Center
            CGPoint(x: centerX, y: bottomY)     // End at core
        ]

        return [EnemyPath(id: "path_main", waypoints: waypoints)]
    }

    /// Create tower placement slots
    private static func createTowerSlots(for map: TDMap, avoiding paths: [EnemyPath]) -> [TowerSlot] {
        var slots: [TowerSlot] = []
        let slotSize: CGFloat = 40
        let margin: CGFloat = 60

        // Create grid of potential slots
        let cols = Int((map.width - margin * 2) / slotSize)
        let rows = Int((map.height - margin * 2) / slotSize)

        for row in 0..<rows {
            for col in 0..<cols {
                let x = margin + CGFloat(col) * slotSize + slotSize / 2
                let y = margin + CGFloat(row) * slotSize + slotSize / 2
                let point = CGPoint(x: x, y: y)

                // Check if slot overlaps with path
                var tooCloseToPath = false
                for path in paths {
                    for waypoint in path.waypoints {
                        let dx = point.x - waypoint.x
                        let dy = point.y - waypoint.y
                        if sqrt(dx*dx + dy*dy) < 50 {
                            tooCloseToPath = true
                            break
                        }
                    }
                }

                // Check if slot overlaps with obstacles
                var overlapsObstacle = false
                for obs in map.obstacles {
                    if obs.rect.contains(point) {
                        overlapsObstacle = true
                        break
                    }
                }

                if !tooCloseToPath && !overlapsObstacle {
                    slots.append(TowerSlot(
                        id: "slot_\(row)_\(col)",
                        x: x,
                        y: y,
                        size: slotSize
                    ))
                }
            }
        }

        return slots
    }
}
