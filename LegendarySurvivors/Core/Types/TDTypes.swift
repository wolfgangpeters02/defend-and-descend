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

    // Motherboard City (component-based map system)
    // Will be implemented in MotherboardTypes.swift
    // var motherboardConfig: MotherboardConfig?

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

    // Resources (System: Reboot currencies)
    var hash: Int = 100  // Hash (Ħ) - soft currency for purchases
    var lives: Int = 20  // Legacy - kept for compatibility, represents max efficiency baseline

    // Power System (System: Reboot - PSU Capacity)
    // Power is a CEILING, not consumed. Towers allocate power while placed.
    var powerCapacity: Int = 450    // PSU capacity (upgradeable)
    var powerUsed: Int {
        // Sum of all placed towers' power draw
        return towers.reduce(0) { $0 + $1.powerDraw }
    }
    var powerAvailable: Int {
        return max(0, powerCapacity - powerUsed)
    }

    // Hash Storage Cap (System: Reboot)
    var hashStorageCapacity: Int = 25000  // Set from player's HDD level

    /// Add hash with storage cap enforcement
    /// Returns the actual amount added
    @discardableResult
    mutating func addHash(_ amount: Int) -> Int {
        let spaceAvailable = max(0, hashStorageCapacity - hash)
        let actualAdded = min(amount, spaceAvailable)
        hash += actualAdded
        return actualAdded
    }

    // Efficiency System (System: Reboot core mechanic)
    // Efficiency determines Watts income rate - no death, just reduced income
    var leakCounter: Int = 0           // Increments when virus reaches CPU
    var leakDecayTimer: TimeInterval = 0  // Timer for leak counter decay
    var efficiency: CGFloat {
        // efficiency = max(0, 100 - leakCounter * 5)
        // Each leaked virus reduces efficiency by 5%
        return max(0, min(100, 100 - CGFloat(leakCounter) * 5))
    }
    var baseHashPerSecond: CGFloat = 10  // Base income rate at 100% efficiency
    var cpuMultiplier: CGFloat = 1.0      // CPU tier multiplier (1x, 2x, 4x, 8x, 16x)
    var cpuTier: Int = 1                  // Current CPU tier for display
    var efficiencyRegenMultiplier: CGFloat = 1.0  // RAM upgrade bonus to efficiency recovery
    var hashPerSecond: CGFloat {
        return baseHashPerSecond * cpuMultiplier * (efficiency / 100)
    }
    var hashAccumulator: CGFloat = 0  // Accumulates fractional hash

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

    // System Freeze (0% efficiency state)
    var isSystemFrozen: Bool = false    // True when efficiency hits 0%
    var freezeCount: Int = 0             // Number of times system has frozen this session

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

    // MARK: - System Breach (Zero-Day Boss)
    // Periodically spawns an unkillable boss that drains efficiency
    // Player must enter Active/Debugger mode to defeat it

    var zeroDayActive: Bool = false          // Is a Zero-Day boss currently active
    var zeroDayBossId: String?               // ID of the Zero-Day boss enemy
    var zeroDayTimer: TimeInterval = 120     // Timer until next Zero-Day (starts at 120s)
    var zeroDayEfficiencyDrain: CGFloat = 2  // Efficiency drain per second while active
    var zeroDayCooldown: TimeInterval = 180  // Cooldown after defeating Zero-Day (180s)

    // Zero-Day constants
    static let zeroDayMinSpawnTime: TimeInterval = 90    // Minimum time between spawns
    static let zeroDayMaxSpawnTime: TimeInterval = 180   // Maximum time between spawns
    static let zeroDayEfficiencyDrainRate: CGFloat = 2   // Efficiency drain per second

    /// Check if the Zero-Day boss is alive
    var isZeroDayAlive: Bool {
        guard let bossId = zeroDayBossId else { return false }
        return enemies.contains { $0.id == bossId && !$0.isDead && !$0.reachedCore }
    }
}

// MARK: - TD Session State (Lightweight Persistence)
// Persists towers and slots across app restarts

struct TDSessionState: Codable {
    var towers: [Tower]
    var towerSlots: [TowerSlot]
    var hash: Int
    var wavesCompleted: Int
    var efficiency: CGFloat
    var leakCounter: Int
    var lastSaveTime: TimeInterval

    /// Create session state from current game state
    static func from(gameState: TDGameState) -> TDSessionState {
        return TDSessionState(
            towers: gameState.towers,
            towerSlots: gameState.towerSlots,
            hash: gameState.hash,
            wavesCompleted: gameState.wavesCompleted,
            efficiency: gameState.efficiency,
            leakCounter: gameState.leakCounter,
            lastSaveTime: Date().timeIntervalSince1970
        )
    }

    /// Apply session state to game state
    func apply(to state: inout TDGameState) {
        state.towers = towers
        state.towerSlots = towerSlots
        state.hash = hash
        state.wavesCompleted = wavesCompleted
        state.leakCounter = leakCounter
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

struct Tower: Identifiable, Codable {
    var id: String
    var weaponType: String  // Links to WeaponTower
    var level: Int = 1
    var rarity: Rarity = .common  // Tower rarity for cost calculations

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

    // Power consumption (System: Reboot)
    var powerDraw: Int = 20  // Watts consumed while this tower is placed

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
            rarity: weapon.rarity,
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

    /// Create tower from Protocol (System: Reboot - Firewall mode)
    static func from(protocol proto: Protocol, at slot: TowerSlot, mergeLevel: Int = 1) -> Tower {
        let stats = proto.firewallStats
        return Tower(
            id: RandomUtils.generateId(),
            weaponType: proto.id,  // Use protocol ID as weapon type
            level: proto.level,
            rarity: proto.rarity,
            x: slot.x,
            y: slot.y,
            slotId: slot.id,
            damage: stats.damage,
            range: stats.range,
            attackSpeed: stats.fireRate,
            projectileCount: stats.projectileCount,
            pierce: stats.pierce,
            splash: stats.splash,
            homing: stats.special == .homing,
            slow: stats.slow > 0 ? stats.slow : nil,
            slowDuration: stats.slowDuration > 0 ? stats.slowDuration : nil,
            chain: stats.special == .chain ? 3 : nil,  // Chain hits 3 enemies
            color: proto.color,
            towerName: proto.name,
            powerDraw: stats.powerDraw,  // Power consumption from Protocol
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

    // Zero-Day (System Breach) properties
    var isZeroDay: Bool = false        // Is this a Zero-Day boss
    var immuneToTowers: Bool = false   // Cannot be damaged by Firewalls

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
    case insufficientPower(required: Int, available: Int)
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

        var state = TDGameState(
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

        // Apply Global Upgrades
        // PSU level determines power capacity
        state.powerCapacity = playerProfile.globalUpgrades.powerCapacity
        // HDD level determines hash storage capacity
        state.hashStorageCapacity = playerProfile.globalUpgrades.hashStorageCapacity
        // CPU level determines base Hash generation rate
        state.baseHashPerSecond = playerProfile.globalUpgrades.hashPerSecond
        state.cpuMultiplier = 1.0  // Level scaling is now in baseHashPerSecond
        state.cpuTier = playerProfile.globalUpgrades.cpuLevel
        // RAM level determines efficiency recovery speed
        state.efficiencyRegenMultiplier = playerProfile.globalUpgrades.efficiencyRegenMultiplier

        return state
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

    // MARK: - Motherboard City Map

    /// Create game state for the Motherboard City map (4000x4000 PCB canvas)
    static func createMotherboardGameState(
        playerProfile: PlayerProfile
    ) -> TDGameState? {
        // Create the motherboard configuration
        let mbConfig = MotherboardConfig.createDefault()

        // Create the map
        let map = TDMap(
            id: "motherboard",
            name: "Motherboard City",
            width: mbConfig.canvasWidth,
            height: mbConfig.canvasHeight,
            backgroundColor: MotherboardColors.substrate,
            theme: "motherboard",
            particleEffect: nil,
            obstacles: [],
            hazards: [],
            effectZones: [],
            spawnPoints: [CGPoint(x: 400, y: 2000), CGPoint(x: 2000, y: 3600)],
            corePosition: CGPoint(x: 2000, y: 2000),
            globalModifier: nil
        )

        // Create Manhattan-style paths (90-degree turns only)
        let paths = createMotherboardPaths()

        // Create core at CPU position (center of the board)
        let core = TDCore(
            x: 2000,
            y: 2000,
            health: 100,
            maxHealth: 100
        )

        // Create tower slots around the CPU district
        let slots = createMotherboardTowerSlots(avoiding: paths)

        // Create blocker slots at path turns
        let blockerSlots = createBlockerSlots(for: paths)

        var state = TDGameState(
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
            basePaths: paths
        )

        // Apply Global Upgrades
        state.baseHashPerSecond = playerProfile.globalUpgrades.hashPerSecond
        state.cpuMultiplier = 1.0
        state.cpuTier = playerProfile.globalUpgrades.cpuLevel
        state.efficiencyRegenMultiplier = playerProfile.globalUpgrades.efficiencyRegenMultiplier

        return state
    }

    /// Create Manhattan-style paths for the motherboard (90-degree turns only)
    /// Initially only ONE path is active - more paths unlock with sectors
    private static func createMotherboardPaths() -> [EnemyPath] {
        // Main path: From left edge (I/O area) to CPU District
        // CPU is centered at (2000, 2000) with size 300x300 (bounds: 1850-2150, 1850-2150)
        // Path enters from the left side of the CPU, stopping just inside the boundary
        let mainPath = EnemyPath(
            id: "main_bus",
            waypoints: [
                CGPoint(x: 100, y: 2100),     // Start at left edge (spawn point)
                CGPoint(x: 700, y: 2100),     // East along path
                CGPoint(x: 700, y: 1700),     // Turn south
                CGPoint(x: 1100, y: 1700),    // Turn east
                CGPoint(x: 1100, y: 2000),    // Turn north toward CPU level
                CGPoint(x: 1850, y: 2000),    // Continue east to CPU left edge
                CGPoint(x: 1900, y: 2000)     // End just inside CPU (not at center)
            ]
        )

        // Note: Additional paths will be added when sectors are unlocked:
        // - north_bus: From Cache sector (when Cache is unlocked)
        // - south_bus: From GPU sector (when GPU is unlocked)

        return [mainPath]
    }

    /// Create tower slots for the motherboard map dynamically along paths
    /// Slots are placed adjacent to paths (within range to hit enemies)
    /// Uses path-proximity algorithm for dynamic slot generation
    private static func createMotherboardTowerSlots(avoiding paths: [EnemyPath]) -> [TowerSlot] {
        var slots: [TowerSlot] = []
        let slotSpacing: CGFloat = 80     // Distance between slots along path
        let pathDistance: CGFloat = 100   // Max distance from path center to slot
        let slotSize: CGFloat = 60
        let minSlotDistance: CGFloat = 70 // Minimum distance between slots

        // CPU exclusion zone (don't place slots on the CPU)
        let cpuCenter = CGPoint(x: 2000, y: 2000)
        let cpuRadius: CGFloat = 200

        for path in paths {
            // Walk along each path segment
            guard path.waypoints.count > 1 else { continue }

            for i in 0..<path.waypoints.count - 1 {
                let start = path.waypoints[i]
                let end = path.waypoints[i + 1]

                // Calculate segment properties
                let dx = end.x - start.x
                let dy = end.y - start.y
                let segmentLength = sqrt(dx * dx + dy * dy)

                guard segmentLength > 0 else { continue }

                // Direction along segment (normalized)
                let dirX = dx / segmentLength
                let dirY = dy / segmentLength

                // Perpendicular direction (for placing slots on both sides)
                let perpX = -dirY
                let perpY = dirX

                // Walk along segment
                var distance: CGFloat = slotSpacing / 2  // Start slightly offset from corner
                while distance < segmentLength - slotSpacing / 2 {
                    // Center point on path at this distance
                    let centerX = start.x + dirX * distance
                    let centerY = start.y + dirY * distance

                    // Place slots on both sides of path
                    for side in [-1.0, 1.0] as [CGFloat] {
                        let slotX = centerX + perpX * pathDistance * side
                        let slotY = centerY + perpY * pathDistance * side
                        let slotCenter = CGPoint(x: slotX, y: slotY)

                        // Skip if too close to CPU
                        let cpuDist = sqrt(pow(slotX - cpuCenter.x, 2) + pow(slotY - cpuCenter.y, 2))
                        if cpuDist < cpuRadius {
                            continue
                        }

                        // Skip if too close to existing slots
                        if tooCloseToExisting(slotCenter, slots, minDistance: minSlotDistance) {
                            continue
                        }

                        // Skip if too close to the path itself (for safety)
                        var tooCloseToPath = false
                        for checkPath in paths {
                            for j in 0..<checkPath.waypoints.count - 1 {
                                let p1 = checkPath.waypoints[j]
                                let p2 = checkPath.waypoints[j + 1]
                                let dist = distanceToSegment(point: slotCenter, segStart: p1, segEnd: p2)
                                if dist < 60 {  // Minimum clearance from path
                                    tooCloseToPath = true
                                    break
                                }
                            }
                            if tooCloseToPath { break }
                        }

                        if tooCloseToPath { continue }

                        slots.append(TowerSlot(
                            id: "mb_slot_\(slots.count)",
                            x: slotX,
                            y: slotY,
                            size: slotSize
                        ))
                    }

                    distance += slotSpacing
                }
            }
        }

        // Add CPU defense area slots (around CPU perimeter)
        let cpuDefenseSlots: [(CGFloat, CGFloat)] = [
            (cpuCenter.x - 180, cpuCenter.y - 150),  // Left of CPU, lower
            (cpuCenter.x - 180, cpuCenter.y + 100),  // Left of CPU, upper
            (cpuCenter.x + 180, cpuCenter.y - 150),  // Right of CPU, lower
            (cpuCenter.x + 180, cpuCenter.y + 100),  // Right of CPU, upper
            (cpuCenter.x - 80, cpuCenter.y + 180),   // Above CPU (left)
            (cpuCenter.x + 80, cpuCenter.y + 180),   // Above CPU (right)
        ]

        for (x, y) in cpuDefenseSlots {
            let point = CGPoint(x: x, y: y)
            if !tooCloseToExisting(point, slots, minDistance: minSlotDistance) {
                slots.append(TowerSlot(
                    id: "mb_slot_\(slots.count)",
                    x: x,
                    y: y,
                    size: slotSize
                ))
            }
        }

        return slots
    }

    /// Check if a point is too close to existing slots
    private static func tooCloseToExisting(_ point: CGPoint, _ slots: [TowerSlot], minDistance: CGFloat) -> Bool {
        for slot in slots {
            let dx = point.x - slot.x
            let dy = point.y - slot.y
            let dist = sqrt(dx * dx + dy * dy)
            if dist < minDistance {
                return true
            }
        }
        return false
    }

    /// Calculate distance from a point to a line segment
    private static func distanceToSegment(point: CGPoint, segStart: CGPoint, segEnd: CGPoint) -> CGFloat {
        let dx = segEnd.x - segStart.x
        let dy = segEnd.y - segStart.y

        if dx == 0 && dy == 0 {
            // Segment is a point
            let px = point.x - segStart.x
            let py = point.y - segStart.y
            return sqrt(px * px + py * py)
        }

        // Calculate projection
        let t = max(0, min(1, ((point.x - segStart.x) * dx + (point.y - segStart.y) * dy) / (dx * dx + dy * dy)))
        let projX = segStart.x + t * dx
        let projY = segStart.y + t * dy

        let px = point.x - projX
        let py = point.y - projY
        return sqrt(px * px + py * py)
    }
}
